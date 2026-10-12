# Venu X1 pixel watch faces

Nine Connect IQ watch faces for the **Garmin Venu X1**, drawn entirely in a
5x7 pixel font with segmented bars and hard edges. Each is a separate app, so
wear a few and keep whichever fits.

The panel is a **square-cornered 448 x 486 rectangle** and the layouts use all
of it. (An earlier revision composed everything inside a circle; that was
wrong for this watch and cost a 37 px dead band top and bottom.)

| | Face | Idea | Best for |
|---|---|---|---|
| 01 | **Vanguard** | minimal | the time, at twenty-pixel blocks, and little else |
| 02 | **Flux** | dashboard | replacing two or three glance widgets |
| 03 | **Orbit** | segmented rings | chasing a step goal or watching Body Battery drain |
| 04 | **Meridian** | blocky analog | wanting a watch rather than a readout |
| 05 | **Telemetry** | console readout | numbers with no interpretation |
| 06 | **Horizon** | attitude indicator | reading the time of day as a shape |
| 07 | **Trace** | oscilloscope | the shape of your heart rate, not its value |
| 08 | **Caliper** | bar meters | three goals side by side at one scale |
| 09 | **Daily** | the stock layout, rebuilt | keeping the face you already use |

**Daily** mirrors the layout Garmin ships on the X1 - weekday strip with today
inverted, date, a Body Battery row, the activity histogram, a large gradient
clock, then steps, battery hours and temperature, and four ring complications.
Two departures from the original: the histogram plots recent heart rate,
because Connect IQ exposes no intraday step series to a watch face (the stock
strip draws something third-party apps cannot reach), and the rings are
segmented rather than smooth.

**Visual preview:** open `preview/venu-x1-faces.html` in a browser. It draws all
eight on canvas at the real panel size, with four switchable day states
including one where no sensor or weather data is available.

## The type

Garmin's built-in fonts are smooth grotesques. Nothing drawn with them reads as
8-bit, so `_shared/PixelFont.mc` carries a 5x7 font and draws every glyph
directly to the `Dc` as filled rectangles.

That avoids a bitmap font resource, which would cost memory and could not be
checked at all without the SDK. Each glyph row is a 5-bit mask stored as
`mask+48`, keeping the whole table in printable ASCII; horizontal runs of lit
pixels merge into one rectangle each.

- **8.8 rectangles per glyph** on average, 16 for the worst (`W`).
- A dense face is roughly **600 fills per redraw**, which a watch face updating
  once a minute has ample budget for.
- Sizes are a scale factor, not a font: the time on Vanguard is scale 20, so
  each "pixel" is a 20 px block and the digits stand 140 px tall. No built-in
  font reaches that.
- The table is ASCII-only, so `*` is the degree sign and `^` / `v` are the sun
  arrows. **Callers pass uppercase** - there are no lowercase glyphs, and
  running text through `toUpper()` would turn the `v` arrow into a letter V.

The same table is generated into the preview's JavaScript, so the mockup and
the device cannot drift: the glyphs in the preview are the glyphs the watch
will draw.

## What each face shows

| | 01 Van | 02 Flux | 03 Orbit | 04 Mer | 05 Tele | 06 Hor | 07 Trace | 08 Cal | 09 Daily |
|---|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|
| Steps + goal | bar | bar | **ring** | value | row | bar | bar | **meter** | value |
| Heart rate | - | yes | yes | yes | row | **meter** | **trace** | yes | **ring + histogram** |
| Body Battery | - | yes | **ring** | **ring** | row | **meter** | - | **meter** | row + **ring** |
| Stress | - | - | - | - | - | - | - | - | **ring** |
| Calories | - | yes | - | - | row | - | - | - | - |
| Floors | - | yes | - | - | row | - | - | - | - |
| Intensity min | - | yes | - | - | - | - | - | **meter** | **ring** |
| Temperature | yes | yes | yes | yes | - | - | - | yes | yes |
| Conditions | - | yes | - | - | - | - | - | - | - |
| Sunrise / sunset | - | yes | - | - | **24h strip** | drives horizon | - | - | - |
| Watch battery | yes | yes | yes | yes | yes | - | yes | yes | **hours** |

Status squares appear on every face: **blue** unread notifications, **amber**
alarm set, **purple** do not disturb, **red** phone disconnected. Nothing is
drawn when all four are clear.

Metric colours are consistent across all eight, pushed toward primaries so they
read as an instrument panel: green steps, red heart, blue Body Battery, orange
calories, purple floors, pink intensity minutes, amber daylight.

Three faces are worth a note on how they work:

- **Horizon** drives the horizon line from where the sun actually is, using the
  same solar calculation as the sunrise field. Low line and wide sky at midday,
  line above the centre mark through the night; rungs are tinted cool above and
  warm below. With no position fix it parks level and shows `NO FIX`.
- **Trace** plots heart-rate history as sample-and-hold steps. It autoscales,
  so the window's high and low are printed beside it - without them a flat
  resting stretch and a hard interval look identical.
- **Telemetry** ends in a twenty-four cell day: one cell per hour, daylight lit
  amber, the current hour white.

## Layout

```
garmin-watch-faces/
  _shared/            used by every face
    PixelFont.mc      the 5x7 font and its block renderer
    Layout.mc         panel size, centre, safe margins
    Theme.mc          the palette
    Metrics.mc        every sensor and activity reader, null-safe
    Solar.mc          sunrise/sunset and sun height, computed locally
    Draw.mc           frames, segmented bars and meters, segmented rings,
                      step traces, scanlines, grids, status blocks,
                      dial blocks, staircase hands
  vanguard/  flux/  orbit/  meridian/
  telemetry/  horizon/  trace/  caliper/  daily/
    manifest.xml      app id, venux1 target, SensorHistory permission
    monkey.jungle     adds ../_shared to the source path
    source/           the App and the View
    resources/        app name + launcher icon
  preview/venu-x1-faces.html
```

Each folder is an independent Connect IQ app (Connect IQ has no concept of one
app containing several faces), but they share one copy of the data layer
through the jungle's `base.sourcePath`.

## Building

These were written without a compiler available, so **expect to fix a thing or
two on the first build** - see Known risks below.

1. Install the **Connect IQ SDK Manager** from
   <https://developer.garmin.com/connect-iq/sdk/>, then install the latest SDK
   and the **Venu X1** device profile.
2. Install **VS Code** and Garmin's official **Monkey C** extension.
3. Generate a developer key once - `Monkey C: Generate a Developer Key`, or:
   ```sh
   openssl genrsa -out developer_key.pem 4096
   openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem \
     -out developer_key.der -nocrypt
   ```
4. Open **one face folder** as the VS Code workspace root (not this directory -
   the jungle paths are relative to the project).
5. `Monkey C: Build for Device` -> Venu X1, or run in the simulator with F5.

### Sideloading

Build produces a `.prg`. Connect the watch over USB, copy it to `GARMIN/APPS/`,
eject, and pick the face from **Watch Face** on the watch.

## Known risks on the first build

- **Redraw time.** The pixel font trades memory for draw calls. If the
  simulator's profiler flags `onUpdate`, the cheapest fix is raising the scale
  of small captions (fewer glyphs at a larger size costs the same per glyph but
  lets you drop characters), or shortening labels. Telemetry and Flux are the
  two heaviest.
- **`Char` comparison.** `PixelFont.draw` finds a glyph by comparing `Char`
  values with `==`. If your SDK is unhappy with that, compare
  `glyphs[g].toNumber()` instead.
- **`Weather.CONDITION_*` constants.** `Metrics.conditionWord()` switches on a
  dozen of them. If the compiler rejects one as undefined, delete that `case` -
  the `default` already returns an empty string.
- **Launcher icon size.** The icons are 80 x 80. Check the Venu X1 row of the
  Connect IQ device reference and resize if the compiler complains.
- **`base.sourcePath = source;../_shared`.** If your toolchain objects to a
  source path outside the project folder, copy `_shared/*.mc` into each
  `<face>/source/` and drop that line from the jungle.
- **`ActivityMonitor.getHeartRateHistory`**, used by Trace through
  `Metrics.heartRateSeries`. If the signature differs, the fallback is
  `Toybox.SensorHistory.getHeartRateHistory({:period => n, :order => ...})`.
- **`minApiLevel` is 5.0.0**, fine for the Venu X1 but it will exclude older
  watches if you add more `<iq:product>` entries.

## What Connect IQ cannot do

- **Calendar events.** There is no calendar API, on any watch. Next-meeting
  faces from other platforms are not possible here.
- **Sleep score or stages.** Not exposed to Connect IQ. Body Battery on waking
  is the closest proxy.

Notification *count* is available and drives the blue status square.

Sunrise, sunset and the Horizon face all need a position. `Solar.mc` takes it
from the last weather observation, which the phone refreshes without waking the
GPS, so those fields read `--:--` (and Horizon shows `NO FIX`) until the watch
has synced weather at least once.

## Changing things

- **A colour:** `_shared/Theme.mc`. One change applies to every face.
- **A glyph:** the font table lives in `_shared/PixelFont.mc` as `CHARS` and
  `ROWS`. Each character owns seven consecutive bytes of `ROWS`; subtract 48
  from a byte to get its 5-bit row mask. Change both the Monkey C and the
  preview's `PF_ROWS` together, or they will disagree.
- **Text size:** every call passes a scale. Scale 2 is a caption, 4-5 a value,
  8-10 a clock, 20 the Vanguard time.
- **A metric in a slot:** the views are plain `onUpdate` calls, one line per
  element, with every coordinate a named `const` at the top.
- **Goals** come from the watch's own activity tracking, so change them in
  Garmin Connect, not here.

## Possible next steps

- **An always-on variant.** Not built, because the always-on display is off. If
  you turn it on, each face needs a dim, pixel-sparse `onPartialUpdate` path.
  Telemetry and Trace would need the most work - both light a lot of pixels.
- **A settings menu** so metric slots are configurable from the phone
  (`resources/settings/settings.xml` plus `Application.Properties`).
- **Lowercase glyphs and punctuation**, if any future label needs them.
- **Publishing to the Connect IQ store**, which needs store screenshots per
  device family and passes through Garmin review.
