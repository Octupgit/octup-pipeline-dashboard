import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! FLUX - dashboard.
//!
//! Six metrics on a rectangular grid, which is what the panel actually is,
//! plus weather, a twenty-cell step bar and today's daylight window. Time is
//! left-aligned and smaller here because on this face it is one field among
//! several rather than the subject.
class FluxView extends WatchUi.WatchFace {

    private const TOP_Y  = 44;
    private const TIME_Y = 104;
    private const TEMP_Y = 90;
    private const COND_Y = 138;
    private const RULE_Y = 148;
    private const TIME_SCALE = 7;

    private const ROW_1_Y = 214;
    private const ROW_2_Y = 306;
    private const COL_1 = 97;
    private const COL_2 = 224;
    private const COL_3 = 351;

    private const STEP_BAR_Y = 378;
    private const SUN_Y      = 422;
    private const MOVE_BAR_Y = 452;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.begin(dc);

        var battery = Metrics.batteryPercent();
        PixelFont.draw(dc, Layout.LEFT, TOP_Y, 2, Metrics.dateLine(), Theme.DIM);
        PixelFont.drawRight(dc, Layout.RIGHT, TOP_Y, 2, battery.format("%d") + "%",
            Theme.battery(battery));
        Draw.statusBlocks(dc, Layout.CENTER_X, TOP_Y, 8);

        // Scale 7, not 8: at 8 the clock runs into the condition text.
        PixelFont.drawShadowed(dc, Layout.LEFT, TIME_Y, TIME_SCALE,
            Lang.format("$1$:$2$", [Metrics.hours(), Metrics.minutes()]), Theme.TEXT, 3);
        PixelFont.drawRight(dc, Layout.RIGHT, TEMP_Y, 4, Metrics.temperatureGlyph(),
            Theme.WEATHER);
        PixelFont.drawRight(dc, Layout.RIGHT, COND_Y, 2, Metrics.conditionWord(), Theme.DIM);

        Draw.rect(dc, Layout.LEFT, RULE_Y, Layout.INNER_W, 2, Theme.FAINT);

        Draw.field(dc, COL_1, ROW_1_Y, Metrics.compact(Metrics.steps()),
            "STEPS", Theme.STEPS, 4, 2);
        Draw.field(dc, COL_2, ROW_1_Y, Metrics.text(Metrics.heartRate()),
            "HEART", Theme.HR, 4, 2);
        Draw.field(dc, COL_3, ROW_1_Y, Metrics.text(Metrics.bodyBattery()),
            "BODY", Theme.BODY, 4, 2);
        Draw.field(dc, COL_1, ROW_2_Y, Metrics.compact(Metrics.calories()),
            "CALS", Theme.CALORIES, 4, 2);
        Draw.field(dc, COL_2, ROW_2_Y, Metrics.text(Metrics.floors()),
            "FLOORS", Theme.FLOORS, 4, 2);
        // Weekly rather than daily intensity minutes - that is the number
        // Garmin scores against the 150-a-week guideline.
        Draw.field(dc, COL_3, ROW_2_Y, Metrics.text(Metrics.intensityMinutes()),
            "INT MIN", Theme.INTENSITY, 4, 2);

        Draw.segBar(dc, Layout.LEFT, STEP_BAR_Y, Layout.INNER_W, 12, 20,
            Metrics.ratio(Metrics.steps(), Metrics.stepGoal()), Theme.STEPS);

        // '^' and 'v' are glyphs in the pixel font, so the sun markers cost
        // nothing extra to draw.
        PixelFont.draw(dc, Layout.LEFT, SUN_Y, 3, "^ " + Solar.sunriseText(), Theme.STRESS);
        PixelFont.drawRight(dc, Layout.RIGHT, SUN_Y, 3, Solar.sunsetText() + " v", Theme.BODY);

        var move = Metrics.moveBar();
        if (move > 0) {
            Draw.segBar(dc, 152, MOVE_BAR_Y, 144, 10, 5, move / 5.0, Theme.STRESS);
        }
    }
}
