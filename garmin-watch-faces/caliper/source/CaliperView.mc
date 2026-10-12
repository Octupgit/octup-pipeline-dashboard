import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! CALIPER - bar meters.
//!
//! Three vertical meters of fourteen cells each. A lit-cell count is read as
//! a height without parsing a number, and stepped cells say plainly that the
//! reading is quantised - which it is, since all three come from counters.
class CaliperView extends WatchUi.WatchFace {

    private const STATUS_Y = 46;
    private const TIME_Y   = 92;
    private const DATE_Y   = 132;

    private const METER_Y = 168;
    private const METER_H = 206;
    private const METER_W = 54;
    private const METER_CELLS = 14;
    private const METER_X1 = 63;
    private const METER_X2 = 197;
    private const METER_X3 = 331;

    private const LABEL_Y = 394;
    private const VALUE_Y = 420;

    private const FOOTER_Y = 454;
    private const FOOTER_X1 = 112;
    private const FOOTER_X2 = 224;
    private const FOOTER_X3 = 336;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.begin(dc);

        Draw.statusBlocks(dc, Layout.CENTER_X, STATUS_Y, 8);
        PixelFont.drawCentered(dc, Layout.CENTER_X, TIME_Y, 9,
            Lang.format("$1$:$2$", [Metrics.hours(), Metrics.minutes()]), Theme.TEXT);
        PixelFont.drawCentered(dc, Layout.CENTER_X, DATE_Y, 2, Metrics.dateLine(), Theme.DIM);

        var steps = Metrics.steps();
        var bodyBattery = Metrics.bodyBattery();
        var intensity = Metrics.intensityMinutes();

        meter(dc, METER_X1, Metrics.ratio(steps, Metrics.stepGoal()),
            "STEPS", Metrics.compact(steps), Theme.STEPS);
        meter(dc, METER_X2, Metrics.ratio(bodyBattery, 100),
            "BODY", Metrics.text(bodyBattery), Theme.BODY);
        meter(dc, METER_X3, Metrics.ratio(intensity, Metrics.intensityGoal()),
            "INT MIN", Metrics.text(intensity), Theme.INTENSITY);

        var battery = Metrics.batteryPercent();
        PixelFont.drawCentered(dc, FOOTER_X1, FOOTER_Y, 2,
            Metrics.text(Metrics.heartRate()) + " BPM", Theme.HR);
        PixelFont.drawCentered(dc, FOOTER_X2, FOOTER_Y, 2,
            Metrics.temperatureGlyph(), Theme.WEATHER);
        PixelFont.drawCentered(dc, FOOTER_X3, FOOTER_Y, 2,
            battery.format("%d") + "%", Theme.battery(battery));
    }

    private function meter(dc as Graphics.Dc, x as Number, fraction as Float,
                           label as String, value as String, color as Number) as Void {
        Draw.segMeter(dc, x, METER_Y, METER_W, METER_H, METER_CELLS, fraction, color);
        var centerX = x + METER_W / 2;
        PixelFont.drawCentered(dc, centerX, LABEL_Y, 2, label, Theme.DIM);
        PixelFont.drawCentered(dc, centerX, VALUE_Y, 3, value, color);
    }
}
