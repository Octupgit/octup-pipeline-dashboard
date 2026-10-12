import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! ORBIT - goal rings, filling the shared dial.
//!
//! Two concentric gauges: steps against today's goal outside, Body Battery
//! inside. Both answer "how full am I", which a ring shows at a glance and a
//! number does not. Their numbers sit in the middle row in matching colours,
//! so the rings never become decoration.
//!
//! Every Y below is the vertical centre of its element, in device pixels.
class OrbitView extends WatchUi.WatchFace {

    private const RING_INNER = 182;
    private const RING_PEN   = 14;

    // Chosen so the whole text block centres on the dial rather than
    // hanging below it.
    private const STATUS_Y = 130;
    private const TIME_Y   = 192;
    private const DATE_Y   = 246;

    private const ROW_Y   = 288;
    private const ROW_X_LEFT   = 108;
    private const ROW_X_CENTER = 224;
    private const ROW_X_RIGHT  = 340;

    private const TAIL_Y = 356;
    private const TAIL_X_LEFT  = 176;
    private const TAIL_X_RIGHT = 272;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.antiAlias(dc);
        Draw.clearScreen(dc);

        var steps = Metrics.steps();
        var bodyBattery = Metrics.bodyBattery();

        Draw.ring(dc, Layout.CENTER_X, Layout.CENTER_Y, Layout.OUTER_R,
            Metrics.ratio(steps, Metrics.stepGoal()), Theme.STEPS, RING_PEN);
        // Body Battery is already a percentage, so its goal is a flat 100.
        Draw.ring(dc, Layout.CENTER_X, Layout.CENTER_Y, RING_INNER,
            Metrics.ratio(bodyBattery, 100), Theme.BODY, RING_PEN);

        Draw.statusDots(dc, Layout.CENTER_X, STATUS_Y);

        Draw.text(dc, Layout.CENTER_X, TIME_Y, Graphics.FONT_NUMBER_HOT,
            Lang.format("$1$:$2$", [Metrics.hours(), Metrics.minutes()]),
            Theme.TEXT, Graphics.TEXT_JUSTIFY_CENTER);

        Draw.text(dc, Layout.CENTER_X, DATE_Y, Graphics.FONT_XTINY, Metrics.dateLine(),
            Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        // The two ring values flank heart rate, each in its ring's colour.
        Draw.cell(dc, ROW_X_LEFT, ROW_Y, Graphics.FONT_SMALL,
            Metrics.compact(steps), "STEPS", Theme.STEPS);
        Draw.cell(dc, ROW_X_CENTER, ROW_Y, Graphics.FONT_SMALL,
            Metrics.text(Metrics.heartRate()), "BPM", Theme.HR);
        Draw.cell(dc, ROW_X_RIGHT, ROW_Y, Graphics.FONT_SMALL,
            Metrics.text(bodyBattery), "BODY", Theme.BODY);

        // No captions this low in the circle - there is no width for them.
        var battery = Metrics.batteryPercent();
        Draw.text(dc, TAIL_X_LEFT, TAIL_Y, Graphics.FONT_XTINY,
            Metrics.temperature() + "°", Theme.WEATHER, Graphics.TEXT_JUSTIFY_CENTER);
        Draw.text(dc, TAIL_X_RIGHT, TAIL_Y, Graphics.FONT_XTINY,
            battery.format("%d") + "%", Theme.battery(battery), Graphics.TEXT_JUSTIFY_CENTER);
    }
}
