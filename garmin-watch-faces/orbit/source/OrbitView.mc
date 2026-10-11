import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! ORBIT - goal rings face.
//!
//! Two concentric gauges: steps against today's goal on the outside, Body
//! Battery on the inside. Both are things you read as "how full am I", which is
//! what a ring is good at and what a number is bad at. The numbers still appear
//! along the bottom, colour-matched to their ring, so the gauges stay legible.
//!
//! Layout is fixed to the Venu X1's 448 x 486 panel.
class OrbitView extends WatchUi.WatchFace {

    private const CENTER_X = 224;
    private const CENTER_Y = 206;

    private const RING_OUTER = 186;
    private const RING_INNER = 164;
    private const RING_PEN   = 14;

    private const TIME_Y   = 178;
    private const DATE_Y   = 252;
    private const HR_Y     = 292;
    private const STATUS_Y = 348;

    private const FOOTER_Y  = 430;
    private const FOOTER_X1 = 60;
    private const FOOTER_X2 = 164;
    private const FOOTER_X3 = 284;
    private const FOOTER_X4 = 388;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.antiAlias(dc);
        Draw.clearScreen(dc);

        var steps = Metrics.steps();
        var bodyBattery = Metrics.bodyBattery();

        Draw.ring(dc, CENTER_X, CENTER_Y, RING_OUTER,
            Metrics.ratio(steps, Metrics.stepGoal()), Theme.STEPS, RING_PEN);
        // Body Battery is already a percentage, so its goal is a flat 100.
        Draw.ring(dc, CENTER_X, CENTER_Y, RING_INNER,
            Metrics.ratio(bodyBattery, 100), Theme.BODY, RING_PEN);

        // One size down from the largest font: "14:32" at THAI_HOT is wider
        // than the clear space inside the inner ring.
        Draw.text(dc, CENTER_X, TIME_Y, Graphics.FONT_NUMBER_HOT,
            Lang.format("$1$:$2$", [Metrics.hours(), Metrics.minutes()]),
            Theme.TEXT, Graphics.TEXT_JUSTIFY_CENTER);

        Draw.text(dc, CENTER_X, DATE_Y, Graphics.FONT_XTINY, Metrics.dateLine(),
            Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        Draw.cell(dc, CENTER_X, HR_Y, Graphics.FONT_SMALL,
            Metrics.text(Metrics.heartRate()), "BPM", Theme.HR);

        Draw.statusDots(dc, CENTER_X, STATUS_Y);

        var battery = Metrics.batteryPercent();
        Draw.cell(dc, FOOTER_X1, FOOTER_Y, Graphics.FONT_SMALL,
            Metrics.compact(steps), "STEPS", Theme.STEPS);
        Draw.cell(dc, FOOTER_X2, FOOTER_Y, Graphics.FONT_SMALL,
            Metrics.text(bodyBattery), "BODY", Theme.BODY);
        Draw.cell(dc, FOOTER_X3, FOOTER_Y, Graphics.FONT_SMALL,
            Metrics.temperature(), "TEMP", Theme.WEATHER);
        Draw.cell(dc, FOOTER_X4, FOOTER_Y, Graphics.FONT_SMALL,
            battery.format("%d"), "BATT", Theme.battery(battery));
    }
}
