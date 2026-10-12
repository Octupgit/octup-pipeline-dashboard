import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! HORIZON - attitude indicator.
//!
//! The horizon is not decoration: its height is driven by where the sun
//! actually is, so the line sits low with a wide sky at midday and climbs
//! over the centre mark through the night. A rectangular panel suits this
//! better than a round one - real HUDs are rectangles.
//!
//! Needs a position for the sun times, which comes from the last weather
//! sync. With no fix the horizon parks level and says so.
class HorizonView extends WatchUi.WatchFace {

    private const TIME_Y = 66;
    private const STEP_BAR_Y = 104;

    // The horizon stops short of the side meters; running it edge to edge
    // puts a white line straight through both of them.
    private const HORIZON_X = 60;
    private const HORIZON_W = 328;
    private const HORIZON_SWING = 110;
    private const LADDER_STEP = 48;
    private const LADDER_INSET = 50;

    private const TAPE_TOP = 152;
    private const TAPE_HEIGHT = 196;
    private const TAPE_WIDTH = 20;
    private const TAPE_CELLS = 12;
    private const TAPE_LEFT_X  = 30;
    private const TAPE_RIGHT_X = 398;
    private const TAPE_LABEL_Y = 134;
    private const TAPE_VALUE_Y = 368;

    private const DATE_Y   = 416;
    private const STATUS_Y = 450;

    // Heart rate mapped over a range wide enough to cover rest to effort.
    private const HR_FLOOR = 40.0;
    private const HR_SPAN  = 140.0;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.begin(dc);

        PixelFont.drawShadowedCentered(dc, Layout.CENTER_X, TIME_Y, 6,
            Lang.format("[$1$:$2$]", [Metrics.hours(), Metrics.minutes()]), Theme.TEXT, 2);
        Draw.segBar(dc, Layout.LEFT, STEP_BAR_Y, Layout.INNER_W, 8, 20,
            Metrics.ratio(Metrics.steps(), Metrics.stepGoal()), Theme.STEPS);

        drawAttitude(dc);
        drawReference(dc);
        drawTapes(dc);

        PixelFont.drawCentered(dc, Layout.CENTER_X, DATE_Y, 2, Metrics.dateLine(), Theme.DIM);
        Draw.statusBlocks(dc, Layout.CENTER_X, STATUS_Y, 8);
    }

    private function drawAttitude(dc as Graphics.Dc) as Void {
        var altitude = Solar.altitudeFraction();
        var horizonY = Layout.CENTER_Y;
        if (altitude != null) {
            // More sun pushes the horizon down, opening up the sky.
            horizonY = Layout.CENTER_Y + (altitude * HORIZON_SWING).toNumber();
        }

        Draw.rect(dc, HORIZON_X, horizonY, HORIZON_W, 3, Theme.TEXT);

        // Rungs are tinted by which side of the horizon they fall on, which is
        // what makes the display readable at a glance: cool above, warm below,
        // the way a real attitude indicator colours sky and ground.
        rung(dc, horizonY - LADDER_STEP, 50, Theme.SKY);
        rung(dc, horizonY - 2 * LADDER_STEP, 34, Theme.SKY);
        rung(dc, horizonY - 3 * LADDER_STEP, 24, Theme.SKY);
        rung(dc, horizonY + LADDER_STEP, 50, Theme.GROUND);
        rung(dc, horizonY + 2 * LADDER_STEP, 34, Theme.GROUND);
        rung(dc, horizonY + 3 * LADDER_STEP, 24, Theme.GROUND);

        if (altitude == null) {
            PixelFont.drawCentered(dc, Layout.CENTER_X, horizonY - 30, 2, "NO FIX", Theme.FAINT);
        }
    }

    //! One rung of the pitch ladder: a pair of bars either side of centre.
    private function rung(dc as Graphics.Dc, y as Number, length as Number,
                          color as Number) as Void {
        if (y < 130 || y > 400) {
            return;   // would collide with the readouts above and below
        }
        Draw.rect(dc, Layout.CENTER_X - LADDER_INSET - length, y, length, 3, color);
        Draw.rect(dc, Layout.CENTER_X + LADDER_INSET, y, length, 3, color);
    }

    //! The fixed aircraft mark the horizon moves behind.
    private function drawReference(dc as Graphics.Dc) as Void {
        Draw.rect(dc, Layout.CENTER_X - 58, Layout.CENTER_Y - 3, 34, 6, Theme.STRESS);
        Draw.rect(dc, Layout.CENTER_X + 24, Layout.CENTER_Y - 3, 34, 6, Theme.STRESS);
        Draw.rect(dc, Layout.CENTER_X - 5, Layout.CENTER_Y - 5, 10, 10, Theme.STRESS);
    }

    private function drawTapes(dc as Graphics.Dc) as Void {
        var bodyBattery = Metrics.bodyBattery();
        Draw.segMeter(dc, TAPE_LEFT_X, TAPE_TOP, TAPE_WIDTH, TAPE_HEIGHT, TAPE_CELLS,
            Metrics.ratio(bodyBattery, 100), Theme.BODY);
        PixelFont.drawCentered(dc, TAPE_LEFT_X + TAPE_WIDTH / 2, TAPE_LABEL_Y, 2, "BB", Theme.DIM);
        PixelFont.drawCentered(dc, TAPE_LEFT_X + TAPE_WIDTH / 2, TAPE_VALUE_Y, 3,
            Metrics.text(bodyBattery), Theme.BODY);

        var heartRate = Metrics.heartRate();
        var heartFraction = 0.0;
        if (heartRate != null) {
            heartFraction = (heartRate.toFloat() - HR_FLOOR) / HR_SPAN;
        }
        Draw.segMeter(dc, TAPE_RIGHT_X, TAPE_TOP, TAPE_WIDTH, TAPE_HEIGHT, TAPE_CELLS,
            heartFraction, Theme.HR);
        PixelFont.drawCentered(dc, TAPE_RIGHT_X + TAPE_WIDTH / 2, TAPE_LABEL_Y, 2, "HR", Theme.DIM);
        PixelFont.drawCentered(dc, TAPE_RIGHT_X + TAPE_WIDTH / 2, TAPE_VALUE_Y, 3,
            Metrics.text(heartRate), Theme.HR);
    }
}
