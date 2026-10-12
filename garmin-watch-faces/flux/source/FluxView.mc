import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! FLUX - data dashboard, packed into the shared dial.
//!
//! Six metrics in two rows of three, weather on one line, and today's daylight
//! window at the bottom. The rows narrow as they approach the bottom of the
//! circle, so the lower row sits slightly tighter than the upper one and the
//! captions down there are kept short.
//!
//! Every Y below is the vertical centre of its element, in device pixels.
class FluxView extends WatchUi.WatchFace {

    private const RING_PEN = 8;

    private const STATUS_Y  = 70;
    private const DATE_Y    = 106;
    private const TIME_Y    = 168;
    private const WEATHER_Y = 222;

    private const ROW_1_Y = 278;
    private const ROW_2_Y = 356;
    // The lower row sits where the dial has curved in, so its outer columns
    // pull toward the centre to keep "INT MIN" clear of the rim.
    private const ROW_1_COL_1 = 112;
    private const ROW_2_COL_1 = 120;
    private const COL_CENTER  = 224;
    private const ROW_2_COL_3 = 328;
    private const ROW_1_COL_3 = 336;

    private const SUN_Y          = 424;
    private const SUNRISE_MARK_X = 150;
    private const SUNRISE_TEXT_X = 164;
    private const SUNSET_MARK_X  = 298;
    private const SUNSET_TEXT_X  = 284;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.antiAlias(dc);
        Draw.clearScreen(dc);

        Draw.ring(dc, Layout.CENTER_X, Layout.CENTER_Y, Layout.OUTER_R,
            Metrics.ratio(Metrics.steps(), Metrics.stepGoal()), Theme.STEPS, RING_PEN);

        Draw.statusDots(dc, Layout.CENTER_X, STATUS_Y);

        Draw.text(dc, Layout.CENTER_X, DATE_Y, Graphics.FONT_XTINY, Metrics.dateLine(),
            Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        Draw.text(dc, Layout.CENTER_X, TIME_Y, Graphics.FONT_NUMBER_HOT,
            Lang.format("$1$:$2$", [Metrics.hours(), Metrics.minutes()]),
            Theme.TEXT, Graphics.TEXT_JUSTIFY_CENTER);

        Draw.text(dc, Layout.CENTER_X, WEATHER_Y, Graphics.FONT_XTINY, weatherLine(),
            Theme.WEATHER, Graphics.TEXT_JUSTIFY_CENTER);

        drawGrid(dc);
        drawDaylight(dc);
    }

    //! Temperature, conditions and today's range on one line, with whichever
    //! parts the phone has actually synced.
    private function weatherLine() as String {
        var parts = Metrics.temperature() + "°";
        var condition = Metrics.conditionWord();
        if (!condition.equals("")) {
            parts = parts + "  " + condition;
        }
        var range = Metrics.highLow();
        if (!range.equals("")) {
            parts = parts + "  " + range;
        }
        return parts;
    }

    private function drawGrid(dc as Graphics.Dc) as Void {
        Draw.cell(dc, ROW_1_COL_1, ROW_1_Y, Graphics.FONT_MEDIUM,
            Metrics.compact(Metrics.steps()), "STEPS", Theme.STEPS);
        Draw.cell(dc, COL_CENTER, ROW_1_Y, Graphics.FONT_MEDIUM,
            Metrics.text(Metrics.heartRate()), "HEART", Theme.HR);
        Draw.cell(dc, ROW_1_COL_3, ROW_1_Y, Graphics.FONT_MEDIUM,
            Metrics.text(Metrics.bodyBattery()), "BODY", Theme.BODY);

        Draw.cell(dc, ROW_2_COL_1, ROW_2_Y, Graphics.FONT_MEDIUM,
            Metrics.compact(Metrics.calories()), "CALS", Theme.CALORIES);
        Draw.cell(dc, COL_CENTER, ROW_2_Y, Graphics.FONT_MEDIUM,
            Metrics.text(Metrics.floors()), "FLOORS", Theme.FLOORS);
        // Weekly rather than daily intensity minutes - that is the number
        // Garmin scores against the 150-a-week guideline.
        Draw.cell(dc, ROW_2_COL_3, ROW_2_Y, Graphics.FONT_MEDIUM,
            Metrics.text(Metrics.intensityMinutes()), "INT MIN", Theme.INTENSITY);
    }

    private function drawDaylight(dc as Graphics.Dc) as Void {
        Draw.caret(dc, SUNRISE_MARK_X, SUN_Y, true, Theme.STRESS);
        Draw.text(dc, SUNRISE_TEXT_X, SUN_Y, Graphics.FONT_XTINY, Solar.sunriseText(),
            Theme.TEXT, Graphics.TEXT_JUSTIFY_LEFT);

        Draw.caret(dc, SUNSET_MARK_X, SUN_Y, false, Theme.BODY);
        Draw.text(dc, SUNSET_TEXT_X, SUN_Y, Graphics.FONT_XTINY, Solar.sunsetText(),
            Theme.TEXT, Graphics.TEXT_JUSTIFY_RIGHT);
    }
}
