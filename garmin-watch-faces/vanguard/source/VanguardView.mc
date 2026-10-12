import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! VANGUARD - minimal typographic face, composed inside the shared dial.
//!
//! Hours stacked over minutes at the largest size the device has a font for.
//! The dial edge is the step goal, so the one piece of progress tracking on
//! this face costs no space inside the circle at all.
//!
//! Every Y below is the vertical centre of its element, in device pixels.
class VanguardView extends WatchUi.WatchFace {

    private const RING_PEN = 6;

    private const STATUS_Y = 78;
    private const DATE_Y   = 120;
    private const HOUR_Y   = 200;
    private const MINUTE_Y = 306;

    private const FOOTER_Y = 380;
    private const FOOTER_X_LEFT   = 140;
    private const FOOTER_X_CENTER = 224;
    private const FOOTER_X_RIGHT  = 308;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.antiAlias(dc);
        Draw.clearScreen(dc);

        // The dial edge doubles as the step goal gauge.
        Draw.ring(dc, Layout.CENTER_X, Layout.CENTER_Y, Layout.OUTER_R,
            Metrics.ratio(Metrics.steps(), Metrics.stepGoal()), Theme.STEPS, RING_PEN);

        Draw.statusDots(dc, Layout.CENTER_X, STATUS_Y);

        Draw.text(dc, Layout.CENTER_X, DATE_Y, Graphics.FONT_SMALL, Metrics.dateLine(),
            Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        // Minutes take the accent colour so the time reads as two numbers
        // rather than one four-digit block.
        Draw.text(dc, Layout.CENTER_X, HOUR_Y, Graphics.FONT_NUMBER_THAI_HOT, Metrics.hours(),
            Theme.TEXT, Graphics.TEXT_JUSTIFY_CENTER);
        Draw.text(dc, Layout.CENTER_X, MINUTE_Y, Graphics.FONT_NUMBER_THAI_HOT, Metrics.minutes(),
            Theme.BODY, Graphics.TEXT_JUSTIFY_CENTER);

        // Short captions: anything longer would run outside the dial down here.
        var battery = Metrics.batteryPercent();
        Draw.cell(dc, FOOTER_X_LEFT, FOOTER_Y, Graphics.FONT_SMALL,
            Metrics.compact(Metrics.steps()), "STEP", Theme.STEPS);
        Draw.cell(dc, FOOTER_X_CENTER, FOOTER_Y, Graphics.FONT_SMALL,
            Metrics.temperature(), "TEMP", Theme.WEATHER);
        Draw.cell(dc, FOOTER_X_RIGHT, FOOTER_Y, Graphics.FONT_SMALL,
            battery.format("%d"), "BATT", Theme.battery(battery));
    }
}
