import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! ORBIT - segmented goal rings.
//!
//! Two rings built from thirty-six discrete blocks each rather than a smooth
//! sweep, so progress reads as a count of lit segments. Steps against today's
//! goal outside, Body Battery inside.
class OrbitView extends WatchUi.WatchFace {

    private const CENTER_Y = 228;
    private const RING_OUTER = 186;
    private const RING_INNER = 158;
    private const RING_PEN = 16;
    private const SEGMENTS = 48;

    private const STATUS_Y = 148;
    private const TIME_Y   = 196;
    private const DATE_Y   = 246;
    private const HR_Y     = 280;

    private const FOOTER_Y = 436;
    private const FOOTER_X1 = 78;
    private const FOOTER_X2 = 176;
    private const FOOTER_X3 = 272;
    private const FOOTER_X4 = 370;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.begin(dc);

        var steps = Metrics.steps();
        var bodyBattery = Metrics.bodyBattery();

        Draw.segRing(dc, Layout.CENTER_X, CENTER_Y, RING_OUTER, SEGMENTS,
            Metrics.ratio(steps, Metrics.stepGoal()), Theme.STEPS, RING_PEN);
        // Body Battery is already a percentage, so its goal is a flat 100.
        Draw.segRing(dc, Layout.CENTER_X, CENTER_Y, RING_INNER, SEGMENTS,
            Metrics.ratio(bodyBattery, 100), Theme.BODY, RING_PEN);

        Draw.statusBlocks(dc, Layout.CENTER_X, STATUS_Y, 8);
        PixelFont.drawShadowedCentered(dc, Layout.CENTER_X, TIME_Y, 8,
            Lang.format("$1$:$2$", [Metrics.hours(), Metrics.minutes()]), Theme.TEXT, 3);
        PixelFont.drawCentered(dc, Layout.CENTER_X, DATE_Y, 2, Metrics.dateLine(), Theme.DIM);
        Draw.field(dc, Layout.CENTER_X, HR_Y, Metrics.text(Metrics.heartRate()),
            "BPM", Theme.HR, 4, 2);

        var battery = Metrics.batteryPercent();
        Draw.field(dc, FOOTER_X1, FOOTER_Y, Metrics.compact(steps), "STEPS", Theme.STEPS, 3, 2);
        Draw.field(dc, FOOTER_X2, FOOTER_Y, Metrics.text(bodyBattery), "BODY", Theme.BODY, 3, 2);
        Draw.field(dc, FOOTER_X3, FOOTER_Y, Metrics.temperatureGlyph(), "TEMP", Theme.WEATHER, 3, 2);
        Draw.field(dc, FOOTER_X4, FOOTER_Y, battery.format("%d"), "BATT",
            Theme.battery(battery), 3, 2);
    }
}
