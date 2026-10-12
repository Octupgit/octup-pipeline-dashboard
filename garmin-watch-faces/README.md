# Venu X1 watch faces

Four Connect IQ watch faces for the **Garmin Venu X1**, one per layout style, so you
can wear each for a day and keep the one that fits.

All four are composed inside **one circular dial**: centre (224, 243), radius 206,
the largest circle the panel holds. Note that the Venu X1 panel is square-cornered
and 448 x 486 - the circle is a deliberate design choice, not the shape of the
hardware, and it leaves a 37 px band unused above and below. On an AMOLED panel
those pixels are simply off, so the bands cost nothing but screen area.

| | Face | Style | Best for |
|---|---|---|---|
| 01 | **Vanguard** | minimal typographic | reading the time without focusing on the watch |
| 02 | **Flux** | data dashboard | replacing two or three glance widgets |
| 03 | **Orbit** | goal rings | chasing a step goal or watching Body Battery drain |
| 04 | **Meridian** | analog hybrid | wearing the X1 as a dress watch |

**Visual preview:** open `preview/venu-x1-faces.html` in a browser. It draws all four
faces on canvas at the real 448 x 486 panel size from the same coordinates as the
Monkey C, with four switchable day states including one where no sensor or weather
data is available. The composition is accurate; the type is approximated, because
Garmin's built-in fonts only exist on the device.

## What each face shows

|                        | Vanguard | Flux | Orbit | Meridian |
|------------------------|:--------:|:----:|:-----:|:--------:|
| Time                   | stacked, largest | centred, medium | centred in rings | analog hands |
| Date                   | yes | yes | yes | yes |
| Steps + goal           | value + **rim** | value + **rim** | **outer ring** | value |
| Heart rate             | - | yes | yes | yes |
| Body Battery           | - | yes | **inner ring** | **outer arc** |
| Calories               | - | yes | - | - |
| Floors                 | - | yes | - | - |
| Intensity minutes (wk) | - | yes | - | - |
| Temperature            | yes | yes | yes | yes |
| Conditions + low/high  | - | yes | - | - |
| Sunrise / sunset       | - | yes | - | - |
| Watch battery          | yes | - | yes | yes |
| Status dots            | yes | yes | yes | yes |

Status dots, in order: **blue** unread notifications, **amber** alarm set,
**purple** do not disturb, **red** phone disconnected. Nothing is drawn when
all four are clear.

Metric colours are consistent across all four faces, so the numbers stop needing
captions once you have worn one for a day: green steps, red heart, blue Body
Battery, orange calories, purple floors, pink intensity minutes, white weather.

## Layout

```
garmin-watch-faces/
  _shared/            data layer used by all four faces
    Layout.mc         the shared dial: centre and radius
    Theme.mc          the palette
    Metrics.mc        every sensor and activity reader, null-safe
    Solar.mc          sunrise/sunset, computed locally
    Draw.mc           rings, bars, cells, carets, dial ticks, clock hands
  vanguard/  flux/  orbit/  meridian/
    manifest.xml      app id, venux1 target, SensorHistory permission
    monkey.jungle     adds ../_shared to the source path
    source/           the App and the View
    resources/        app name + launcher icon
  preview/venu-x1-faces.html
```

Each folder is an independent Connect IQ app (Connect IQ has no concept of one
app containing four faces), but they share one copy of the data layer through
the jungle's `base.sourcePath`.

## Building

These were written without a compiler available, so **expect to fix a thing or
two on the first build** - see Known risks below.

1. Install the **Connect IQ SDK Manager** from
   <https://developer.garmin.com/connect-iq/sdk/>, then use it to install the
   latest SDK and the **Venu X1** device profile.
2. Install **VS Code** and Garmin's official **Monkey C** extension.
3. Generate a developer key once - `Monkey C: Generate a Developer Key` in the
   command palette, or:
   ```sh
   openssl genrsa -out developer_key.pem 4096
   openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem \
     -out developer_key.der -nocrypt
   ```
   Keep it safe; it is also your store identity.
4. Open **one face folder** as the VS Code workspace root (not this directory -
   the jungle paths are relative to the project).
5. `Monkey C: Build for Device` -> Venu X1, or run in the simulator with F5.

### Sideloading

Build produces a `.prg`. Connect the watch over USB and copy it to
`GARMIN/APPS/` on the device, then eject and pick the face from
**Watch Face** on the watch. Settings menus and the store are not involved.

## Known risks on the first build

Nothing here has been through the compiler, so these are the places to look if
a build fails:

- **`Weather.CONDITION_*` constants.** `Metrics.conditionWord()` switches on a
  dozen of them. If the compiler rejects one as undefined, delete that `case`
  line - the `default` branch already returns an empty string.
- **Launcher icon size.** The icons are 80 x 80. Check the Venu X1 row of the
  Connect IQ device reference and resize `resources/drawables/launcher_icon.png`
  if the compiler complains.
- **`base.sourcePath = source;../_shared`.** If your toolchain objects to a
  source path outside the project folder, copy `_shared/*.mc` into each
  `<face>/source/` and drop that line from the jungle.
- **Font metrics.** `Draw.cell` places a caption using
  `dc.getFontHeight(font) / 2 + 11`. If captions sit too close to their values
  on the device, change that `11`. This is also the most likely cause of text
  touching the dial rim: the lower rows of Flux and the tails of Orbit and
  Meridian are placed against a circle that narrows quickly, and were checked
  against approximated font widths rather than the device's real ones.
- **`minApiLevel` is 5.0.0**, which is fine for the Venu X1 but will exclude
  older watches if you add more `<iq:product>` entries.

## What Connect IQ cannot do

Two things from the day-planning list are simply not available to a watch face,
on any watch, regardless of code:

- **Calendar events.** There is no calendar API. Next-meeting faces you may have
  seen on other platforms are not possible here.
- **Sleep score or sleep stages.** Not exposed to Connect IQ. Body Battery on
  waking is the closest proxy, and all four faces carry it or can.

Notification *count* is available and drives the blue status dot.

Sunrise and sunset need a position. `Solar.mc` takes it from the last weather
observation, which the phone refreshes without waking the GPS, so the fields read
`--:--` until the watch has synced weather at least once.

## Changing things

- **A colour:** edit `_shared/Theme.mc`. One change applies to all four faces.
- **A metric in a slot:** the views are plain `onUpdate` calls, one line per
  element. In `flux/source/FluxView.mc`, swapping floors for stress is changing
  one `Draw.cell(...)` line to `Metrics.stress()` with `Theme.STRESS`.
- **Position of anything:** every coordinate is a named `const` at the top of
  each view, in device pixels, measured from the top left. 448 x 486, centre is
  (224, 243).
- **The dial itself:** `_shared/Layout.mc`. Raising `OUTER_R` past 206 runs the
  rim off the left and right edges, since the panel is only 448 px wide. To go
  back to rectangular layouts, ignore it and use the full panel - nothing else
  depends on the circle.
- **The step goal ring target:** goals come from the watch's own activity
  tracking (`Metrics.stepGoal()`), so change them in Garmin Connect, not here.

## Possible next steps

- **Bigger digits than the system fonts allow.** `FONT_NUMBER_THAI_HOT` is the
  largest built-in. A custom `.fnt` resource would let Vanguard go larger still.
- **A settings menu** so metric slots are configurable on the phone instead of
  in code (`resources/settings/settings.xml` plus `Application.Properties`).
- **An always-on variant.** Not built, because the always-on display is off.
  If you turn it on, each face needs a dim, pixel-sparse low-power path in
  `onPartialUpdate` to avoid burn-in and battery drain.
- **Publishing to the Connect IQ store**, which needs store screenshots per
  device family and passes through Garmin review.
