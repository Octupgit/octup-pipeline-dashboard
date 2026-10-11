import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! FLUX - data dashboard face.
//!
//! Six metrics in a grid plus weather, a step-goal bar and today's daylight
//! window. The point is to answer "how is my day going" without opening a
//! single glance widget. Time is left-aligned and smaller than on the other
//! faces, because here it is one field among several rather than the subject.
//!
//! Layout is fixed to the Venu X1's 448 x 486 panel.
class FluxView extends WatchUi.WatchFace {

    private const MARGIN_L = 28;
    private const MARGIN_R = 420;

    private const TOP_BAR_Y = 34;
    private const TIME_Y    = 110;
    private const TEMP_Y    = 94;
    private const COND_Y    = 136;
    private const RULE_Y    = 172;

    private const GRID_ROW_1 = 238;
    private const GRID_ROW_2 = 350;
    private const GRID_COL_1 = 96;
    private const GRID_COL_2 = 224;
    private const GRID_COL_3 = 352;

    private const GOAL_BAR_Y = 414;
    private const GOAL_BAR_H = 6;

    private const SUN_VALUE_Y = 446;
    private const SUN_LABEL_Y = 468;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.antiAlias(dc);
        Draw.clearScreen(dc);

        drawTopBar(dc);
        drawTimeAndWeather(dc);
        drawGrid(dc);
        drawFooter(dc);
    }

    private function drawTopBar(dc as Graphics.Dc) as Void {
        Draw.text(dc, MARGIN_L, TOP_BAR_Y, Graphics.FONT_XTINY, Metrics.dateLine(),
            Theme.DIM, Graphics.TEXT_JUSTIFY_LEFT);

        var battery = Metrics.batteryPercent();
        Draw.text(dc, MARGIN_R, TOP_BAR_Y, Graphics.FONT_XTINY, battery.format("%d") + "%",
            Theme.battery(battery), Graphics.TEXT_JUSTIFY_RIGHT);

        Draw.statusDots(dc, GRID_COL_2, TOP_BAR_Y);
    }

    private function drawTimeAndWeather(dc as Graphics.Dc) as Void {
        var time = Lang.format("$1$:$2$", [Metrics.hours(), Metrics.minutes()]);
        Draw.text(dc, MARGIN_L, TIME_Y, Graphics.FONT_NUMBER_HOT, time,
            Theme.TEXT, Graphics.TEXT_JUSTIFY_LEFT);

        Draw.text(dc, MARGIN_R, TEMP_Y, Graphics.FONT_NUMBER_MILD, Metrics.temperature(),
            Theme.WEATHER, Graphics.TEXT_JUSTIFY_RIGHT);

        // Condition word on top, today's low/high underneath it. Both are blank
        // rather than "--" when the phone has not synced weather recently.
        Draw.text(dc, MARGIN_R, COND_Y, Graphics.FONT_XTINY, Metrics.conditionWord(),
            Theme.DIM, Graphics.TEXT_JUSTIFY_RIGHT);
        Draw.text(dc, MARGIN_R, COND_Y + 22, Graphics.FONT_XTINY, Metrics.highLow(),
            Theme.DIM, Graphics.TEXT_JUSTIFY_RIGHT);

        dc.setPenWidth(1);
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(MARGIN_L, RULE_Y, MARGIN_R, RULE_Y);
    }

    private function drawGrid(dc as Graphics.Dc) as Void {
        Draw.cell(dc, GRID_COL_1, GRID_ROW_1, Graphics.FONT_MEDIUM,
            Metrics.compact(Metrics.steps()), "STEPS", Theme.STEPS);
        Draw.cell(dc, GRID_COL_2, GRID_ROW_1, Graphics.FONT_MEDIUM,
            Metrics.text(Metrics.heartRate()), "HEART", Theme.HR);
        Draw.cell(dc, GRID_COL_3, GRID_ROW_1, Graphics.FONT_MEDIUM,
            Metrics.text(Metrics.bodyBattery()), "BODY BATT", Theme.BODY);

        Draw.cell(dc, GRID_COL_1, GRID_ROW_2, Graphics.FONT_MEDIUM,
            Metrics.compact(Metrics.calories()), "CALS", Theme.CALORIES);
        Draw.cell(dc, GRID_COL_2, GRID_ROW_2, Graphics.FONT_MEDIUM,
            Metrics.text(Metrics.floors()), "FLOORS", Theme.FLOORS);
        // Weekly rather than daily intensity minutes - that is the number
        // Garmin scores against the 150-a-week guideline.
        Draw.cell(dc, GRID_COL_3, GRID_ROW_2, Graphics.FONT_MEDIUM,
            Metrics.text(Metrics.intensityMinutes()), "INT MIN", Theme.INTENSITY);
    }

    private function drawFooter(dc as Graphics.Dc) as Void {
        Draw.bar(dc, MARGIN_L, GOAL_BAR_Y, MARGIN_R - MARGIN_L, GOAL_BAR_H,
            Metrics.ratio(Metrics.steps(), Metrics.stepGoal()), Theme.STEPS);

        Draw.text(dc, MARGIN_L, SUN_VALUE_Y, Graphics.FONT_XTINY, Solar.sunriseText(),
            Theme.TEXT, Graphics.TEXT_JUSTIFY_LEFT);
        Draw.text(dc, MARGIN_L, SUN_LABEL_Y, Graphics.FONT_XTINY, "SUNRISE",
            Theme.DIM, Graphics.TEXT_JUSTIFY_LEFT);

        Draw.text(dc, MARGIN_R, SUN_VALUE_Y, Graphics.FONT_XTINY, Solar.sunsetText(),
            Theme.TEXT, Graphics.TEXT_JUSTIFY_RIGHT);
        Draw.text(dc, MARGIN_R, SUN_LABEL_Y, Graphics.FONT_XTINY, "SUNSET",
            Theme.DIM, Graphics.TEXT_JUSTIFY_RIGHT);

        // Move bar: five notches that fill as the watch decides you have been
        // sitting too long. Hidden entirely when it is clear.
        var level = Metrics.moveBar();
        if (level > 0) {
            var notchWidth = 14;
            var gap = 5;
            var totalWidth = 5 * notchWidth + 4 * gap;
            var x = GRID_COL_2 - totalWidth / 2;
            for (var i = 0; i < 5; i += 1) {
                dc.setColor(i < level ? Theme.STRESS : Theme.TRACK, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x + i * (notchWidth + gap), SUN_VALUE_Y + 2, notchWidth, 6);
            }
        }
    }
}
