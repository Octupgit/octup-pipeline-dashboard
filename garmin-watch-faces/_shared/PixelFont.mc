import Toybox.Graphics;
import Toybox.Lang;

//! A 6x8 pixel font drawn as filled blocks.
//!
//! Garmin's built-in fonts are smooth grotesques - nothing drawn with them
//! reads as 8-bit. The alternative to this would be a bitmap font resource,
//! which costs memory and cannot be checked without the SDK, so every glyph
//! here is drawn straight to the Dc instead.
//!
//! Each glyph row is a 6-bit mask stored as mask+48, which keeps the entire
//! table inside printable ASCII. Horizontal runs of lit pixels merge into one
//! rectangle, which works out at 9.8 rectangles per glyph - about 700 for a
//! dense face, well inside a watch face's redraw budget.
//!
//! This replaced a 5x7 table. Doubling the ink area costs 11% more rectangles
//! and buys letterforms with real shoulders and bowls rather than five
//! columns suggesting them.
//!
//! The table is ASCII-only, so '*' carries the degree sign.
//!
//! Callers pass UPPERCASE: there are no lowercase glyphs, and `v` is the
//! down-arrow, so running text through toUpper() would break it.
module PixelFont {

    const CELL_W = 6;
    const CELL_H = 8;
    const GAP = 1;

    const CHARS = "0123456789:.-/% *^v[]ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const ROWS = "NccccccN<L<<<<<NNc36<H`oNc3>33cN6>Nfo666o``n33cN>H`ncccNo36<HHHHNccNcccNNcccO36L0<<00<<0000000<<000N0000336<H``0ac6<HcS000000000LffL00000<No00000000oN<0NHHHHHHNN666666NNcccocccnccncccnNc````cNlfccccflo``l```oo``l````Nc``gccNcccoccccN<<<<<<N76666ffLcflhlfcc```````ocoocccccckogccccNccccccNncccn```NccccgfMnccnhfccNc`N33cNo<<<<<<<cccccccNcccccN<<ccccooccccN<<NccccN<<<<<o36<H``o";

    var mChars as Array<Char>? = null;
    var mRows as Array<Char>? = null;

    //! Width in device pixels, including the gap between glyphs but not after
    //! the last one.
    function width(text as String, scale as Number) as Number {
        var count = text.length();
        if (count == 0) {
            return 0;
        }
        return count * (CELL_W + GAP) * scale - GAP * scale;
    }

    function height(scale as Number) as Number {
        return CELL_H * scale;
    }

    //! Left edge at x, vertical centre at y.
    function draw(dc as Graphics.Dc, x as Number, y as Number, scale as Number,
                  text as String, color as Number) as Void {
        if (mChars == null) {
            mChars = CHARS.toCharArray();
            mRows = ROWS.toCharArray();
        }
        var table = mRows;
        var index = mChars;
        var glyphs = text.toCharArray();
        var top = y - CELL_H * scale / 2;
        var pen = x;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var g = 0; g < glyphs.size(); g += 1) {
            var slot = -1;
            for (var i = 0; i < index.size(); i += 1) {
                if (index[i] == glyphs[g]) {
                    slot = i;
                    break;
                }
            }
            if (slot >= 0) {
                var base = slot * CELL_H;
                for (var r = 0; r < CELL_H; r += 1) {
                    var mask = table[base + r].toNumber() - 48;
                    if (mask != 0) {
                        var runStart = -1;
                        for (var c = 0; c <= CELL_W; c += 1) {
                            var lit = c < CELL_W && ((mask >> (CELL_W - 1 - c)) & 1) == 1;
                            if (lit && runStart < 0) {
                                runStart = c;
                            } else if (!lit && runStart >= 0) {
                                dc.fillRectangle(pen + runStart * scale, top + r * scale,
                                    (c - runStart) * scale, scale);
                                runStart = -1;
                            }
                        }
                    }
                }
            }
            pen += (CELL_W + GAP) * scale;
        }
    }

    //! Text with an offset copy behind it. A drop shadow is the staple trick
    //! for lifting 16-bit UI type off its background rather than letting it
    //! sit flat in it.
    function drawShadowed(dc as Graphics.Dc, x as Number, y as Number, scale as Number,
                          text as String, color as Number, offset as Number) as Void {
        draw(dc, x + offset, y + offset, scale, text, Theme.SHADOW);
        draw(dc, x, y, scale, text, color);
    }

    function drawShadowedCentered(dc as Graphics.Dc, centerX as Number, y as Number,
                                  scale as Number, text as String, color as Number,
                                  offset as Number) as Void {
        drawShadowed(dc, centerX - width(text, scale) / 2, y, scale, text, color, offset);
    }

    //! Per-glyph colour ramp. A true gradient would mean a colour change per
    //! column; stepping it once per character is far cheaper and, at this
    //! glyph size, the stepping is the point.
    function drawGradient(dc as Graphics.Dc, x as Number, y as Number, scale as Number,
                          text as String, fromColor as Number, toColor as Number) as Void {
        var count = text.length();
        if (count == 0) {
            return;
        }
        var glyphs = text.toCharArray();
        var pen = x;
        for (var i = 0; i < count; i += 1) {
            var mixed = count == 1 ? fromColor : mix(fromColor, toColor, i * 100 / (count - 1));
            draw(dc, pen, y, scale, glyphs[i].toString(), mixed);
            pen += (CELL_W + GAP) * scale;
        }
    }

    function drawGradientCentered(dc as Graphics.Dc, centerX as Number, y as Number,
                                  scale as Number, text as String, fromColor as Number,
                                  toColor as Number) as Void {
        drawGradient(dc, centerX - width(text, scale) / 2, y, scale, text, fromColor, toColor);
    }

    //! Blend two packed RGB colours, with `percent` running 0 to 100.
    function mix(from as Number, to as Number, percent as Number) as Number {
        var red = ((from >> 16) & 0xFF) + ((((to >> 16) & 0xFF) - ((from >> 16) & 0xFF)) * percent) / 100;
        var green = ((from >> 8) & 0xFF) + ((((to >> 8) & 0xFF) - ((from >> 8) & 0xFF)) * percent) / 100;
        var blue = (from & 0xFF) + (((to & 0xFF) - (from & 0xFF)) * percent) / 100;
        return (red << 16) | (green << 8) | blue;
    }

    function drawCentered(dc as Graphics.Dc, centerX as Number, y as Number, scale as Number,
                          text as String, color as Number) as Void {
        draw(dc, centerX - width(text, scale) / 2, y, scale, text, color);
    }

    function drawRight(dc as Graphics.Dc, rightX as Number, y as Number, scale as Number,
                       text as String, color as Number) as Void {
        draw(dc, rightX - width(text, scale), y, scale, text, color);
    }
}
