import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! TELEMETRY - console readout.
//!
//! A framed panel of key/value rows with a CRT raster behind them. The strip
//! at the bottom is a twenty-four cell day: one cell per hour, daylight lit
//! amber and the current hour in white.
class TelemetryView extends WatchUi.WatchFace {

    private const FRAME_X = 22;
    private const FRAME_Y = 22;
    private const FRAME_W = 404;
    private const FRAME_H = 430;

    private const PAD_X = 18;          // inside the frame
    private const HEADER_Y = 50;
    private const RULE_TOP_Y = 70;
    private const TIME_Y = 122;

    private const ROW_1_Y = 180;
    private const ROW_PITCH = 42;

    private const RULE_BOTTOM_Y = 376;
    private const SUN_Y = 398;
    private const BAR_Y = 420;
    private const BAR_H = 12;
    private const BAR_CELLS = 24;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.begin(dc);
        Draw.scanlines(dc, 3, Theme.SCANLINE);
        Draw.frame(dc, FRAME_X, FRAME_Y, FRAME_W, FRAME_H, 2, Theme.FAINT);

        var left = FRAME_X + PAD_X;
        var right = FRAME_X + FRAME_W - PAD_X;

        var battery = Metrics.batteryPercent();
        PixelFont.draw(dc, left, HEADER_Y, 2, Metrics.dateLine(), Theme.DIM);
        PixelFont.drawRight(dc, right, HEADER_Y, 2, battery.format("%d") + "%",
            Theme.battery(battery));
        Draw.rect(dc, left, RULE_TOP_Y, right - left, 1, Theme.FAINT);

        PixelFont.drawShadowedCentered(dc, Layout.CENTER_X, TIME_Y, 9,
            Lang.format("$1$:$2$", [Metrics.hours(), Metrics.minutes()]), Theme.TEXT, 3);

        row(dc, left, right, 0, "HR", Metrics.text(Metrics.heartRate()), Theme.HR);
        row(dc, left, right, 1, "BODY BATT", Metrics.text(Metrics.bodyBattery()), Theme.BODY);
        row(dc, left, right, 2, "STEPS", Metrics.text(Metrics.steps()), Theme.STEPS);
        row(dc, left, right, 3, "CALORIES", Metrics.text(Metrics.calories()), Theme.CALORIES);
        row(dc, left, right, 4, "FLOORS", Metrics.text(Metrics.floors()), Theme.FLOORS);

        Draw.rect(dc, left, RULE_BOTTOM_Y, right - left, 1, Theme.FAINT);
        PixelFont.draw(dc, left, SUN_Y, 2, "^ " + Solar.sunriseText(), Theme.STRESS);
        PixelFont.drawRight(dc, right, SUN_Y, 2, Solar.sunsetText() + " v", Theme.BODY);

        drawDayBar(dc, left, right - left);
    }

    private function row(dc as Graphics.Dc, left as Number, right as Number, index as Number,
                         label as String, value as String, color as Number) as Void {
        var y = ROW_1_Y + index * ROW_PITCH;
        PixelFont.draw(dc, left, y, 2, label, Theme.DIM);
        PixelFont.drawRight(dc, right, y, 4, value, color);
    }

    //! One cell per hour of the day. Reading the daylight window as a count
    //! of lit blocks is the point - it is a calendar strip, not a gauge.
    private function drawDayBar(dc as Graphics.Dc, x as Number, width as Number) as Void {
        var gap = 2;
        var cellWidth = (width - gap * (BAR_CELLS - 1)) / BAR_CELLS;
        var sunrise = Solar.sunriseMinutes();
        var sunset = Solar.sunsetMinutes();
        var nowHour = Solar.nowMinutes() / 60;

        for (var hour = 0; hour < BAR_CELLS; hour += 1) {
            var color = Theme.TRACK;
            if (sunrise != null && sunset != null
                    && hour >= sunrise / 60 && hour <= sunset / 60) {
                color = Theme.STRESS;
            }
            if (hour == nowHour) {
                color = Theme.TEXT;
            }
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + hour * (cellWidth + gap), BAR_Y, cellWidth, BAR_H);
        }
    }
}
