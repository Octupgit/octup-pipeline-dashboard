#!/usr/bin/env python3
"""Consistency checks for the face set. Run from garmin-watch-faces/.

The preview page and the device code are written twice, by hand, from the same
design. That is the likeliest place for a bug to hide, because a divergence
looks correct in every render. These checks pin the parts that must agree.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PREVIEW = ROOT / "preview" / "venu-x1-faces.html"
SHARED = ROOT / "_shared"
fails = []


def check(label, ok, detail=""):
    print(("  ok   " if ok else "  FAIL ") + label + (" - " + detail if detail and not ok else ""))
    if not ok:
        fails.append(label)


def grab(text, pattern):
    m = re.search(pattern, text)
    return m.group(1) if m else None


print("font table parity")
mc = (SHARED / "PixelFont.mc").read_text()
js = PREVIEW.read_text()
mc_chars = grab(mc, r'const CHARS = "([^"]*)";')
mc_rows = grab(mc, r'const ROWS = "([^"]*)";')
js_chars = grab(js, r'var PF_CHARS = "([^"]*)";')
js_rows = grab(js, r'var PF_ROWS = "([^"]*)";')
check("CHARS match", mc_chars == js_chars)
check("ROWS match", mc_rows == js_rows)
mc_w = grab(mc, r"const CELL_W = (\d+);")
mc_h = grab(mc, r"const CELL_H = (\d+);")
js_w = grab(js, r"var PF_W = (\d+)")
js_h = grab(js, r"PF_H = (\d+)")
check("cell size matches", (mc_w, mc_h) == (js_w, js_h), f"{mc_w}x{mc_h} vs {js_w}x{js_h}")
check("ROWS length consistent",
      mc_rows is not None and mc_chars is not None
      and len(mc_rows) == int(mc_h) * len(mc_chars))

print("glyph coverage")
table = set(mc_chars or "")
# Every literal that can reach the pixel font, one per line so comments and
# multi-line calls cannot be swept up by a greedy match.
missing = {}
for path in sorted(ROOT.glob("*/source/*.mc")) + sorted(SHARED.glob("*.mc")):
    for lineno, line in enumerate(path.read_text().splitlines(), 1):
        stripped = line.lstrip()
        if stripped.startswith("//"):
            continue
        if stripped.startswith("const CHARS") or stripped.startswith("const ROWS"):
            continue                          # the font table is not rendered text
        for lit in re.findall(r'"([^"]*)"', line):
            if "$" in lit or "%" in lit:
                continue                      # format strings, not literal output
            for ch in lit:
                if ch not in table:
                    missing.setdefault(ch, []).append(f"{path.name}:{lineno}")
for ch, where in sorted(missing.items()):
    check(f"glyph {ch!r} exists", False, where[0])
check("all literals renderable", not missing)

print("editor control defaults")
# The preview exposes each face's constants as live controls. Those defaults
# are generated from the Monkey C; this asserts they still agree, so a knob
# cannot quietly edit a value the source no longer has.
import json
def brace_block(text, marker):
    """Extract the balanced {...} that follows `marker`."""
    i = text.find(marker)
    if i < 0:
        return None
    i = text.index("{", i)
    depth, j = 0, i
    while j < len(text):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                return text[i:j + 1]
        j += 1
    return None

defaults_blob = brace_block(js, "var DEFAULTS =")
if defaults_blob is None:
    check("DEFAULTS block found", False)
else:
    defaults = json.loads(defaults_blob)
    for face, knobs in sorted(defaults.items()):
        view = next((ROOT / face / "source").glob("*View.mc"), None)
        if view is None:
            check(f"{face} view found", False)
            continue
        src = view.read_text()
        actual = {k: int(v) for k, v in re.findall(r"private const (\w+)\s*=\s*(-?\d+);", src)}
        actual.pop("SAMPLES", None)
        drift = [f"{k} {knobs[k]}!={actual.get(k)}" for k in knobs if actual.get(k) != knobs[k]]
        extra = [k for k in actual if k not in knobs]
        check(f"{face} controls match source ({len(knobs)})", not drift and not extra,
              ", ".join(drift + ["missing control: " + e for e in extra]))

print("value formatting parity")
mc_metrics = (SHARED / "Metrics.mc").read_text()
mc_suffix = grab(mc_metrics, r'format\("%\.1f"\) \+ "(\w)"')
js_suffix = grab(js, r'toFixed\(1\) \+ "(\w)"')
check("compact() suffix matches", mc_suffix == js_suffix, f"{mc_suffix} vs {js_suffix}")
check("compact() suffix is uppercase", (mc_suffix or "").isupper(),
      "the font has no lowercase glyphs")

print("entry points")
for manifest in sorted(ROOT.glob("*/manifest.xml")):
    entry = grab(manifest.read_text(), r'entry="(\w+)"')
    check(f"{manifest.parent.name} entry {entry}",
          (manifest.parent / "source" / f"{entry}.mc").exists())

print("cross-module references")
defined = {}
for f in SHARED.glob("*.mc"):
    src = f.read_text()
    names = set()
    for pat in (r"^\s*function\s+(\w+)\s*\(", r"^\s*const\s+(\w+)", r"^\s*var\s+(m\w+)"):
        names |= {m.group(1) for m in re.finditer(pat, src, re.M)}
    defined[f.stem] = names
unknown = set()
for f in list(ROOT.glob("*/source/*.mc")) + list(SHARED.glob("*.mc")):
    for m in re.finditer(r"\b(Draw|PixelFont|Metrics|Solar|Layout|Theme)\.(\w+)", f.read_text()):
        if m.group(2) not in defined.get(m.group(1), set()):
            unknown.add(f"{m.group(1)}.{m.group(2)}")
check("all referenced symbols defined", not unknown, ", ".join(sorted(unknown)))

print("dead code")
allsrc = re.sub(r"//.*", "", "\n".join(
    p.read_text() for p in list(ROOT.glob("*/source/*.mc")) + list(SHARED.glob("*.mc"))))
dead = [f"{f.stem}.{m.group(1)}"
        for f in sorted(SHARED.glob("*.mc"))
        for m in re.finditer(r"^\s*function\s+(\w+)\s*\(", f.read_text(), re.M)
        if len(re.findall(r"\b" + re.escape(m.group(1)) + r"\s*\(", allsrc)) <= 1]
check("no unused shared functions", not dead, ", ".join(dead))

print()
print("FAILED: " + ", ".join(fails) if fails else "all checks passed")
sys.exit(1 if fails else 0)
