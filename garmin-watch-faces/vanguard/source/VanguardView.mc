import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! VANGUARD - minimal typographic face.
//!
//! Hours over minutes at the largest size the device offers, which is roughly
//! three times the height of a stock digital face. Everything else is one
//! glance-sized row along the bottom. Use this when you want to read the time
//! without focusing on the watch.
//!
//! Layout is fixed to the Venu X1's 448 x 486 panel. All coordinates below are
//! the centre of the element.
class VanguardView extends WatchUi.WatchFace {

    private const CENTER_X = 224;

    private const STATUS_Y = 30;
    private const DATE_Y   = 64;
    private const HOUR_Y   = 168;
    private const MINUTE_Y = 318;

    private const FOOTER_Y = 420;
    private const FOOTER_X_LEFT   = 84;
    private const FOOTER_X_CENTER = 224;
    private const FOOTER_X_RIGHT  = 364;

    private const GOAL_BAR_X = 104;
    private const GOAL_BAR_Y = 470;
    private const GOAL_BAR_W = 240;
    private const GOAL_BAR_H = 4;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.antiAlias(dc);
        Draw.clearScreen(dc);

        Draw.statusDots(dc, CENTER_X, STATUS_Y);

        Draw.text(dc, CENTER_X, DATE_Y, Graphics.FONT_SMALL, Metrics.dateLine(),
            Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        // Minutes take the accent colour so the two halves of the time read as
        // separate numbers instead of one four-digit block.
        Draw.text(dc, CENTER_X, HOUR_Y, Graphics.FONT_NUMBER_THAI_HOT, Metrics.hours(),
            Theme.TEXT, Graphics.TEXT_JUSTIFY_CENTER);
        Draw.text(dc, CENTER_X, MINUTE_Y, Graphics.FONT_NUMBER_THAI_HOT, Metrics.minutes(),
            Theme.BODY, Graphics.TEXT_JUSTIFY_CENTER);

        var battery = Metrics.batteryPercent();
        Draw.cell(dc, FOOTER_X_LEFT, FOOTER_Y, Graphics.FONT_SMALL,
            Metrics.compact(Metrics.steps()), "STEPS", Theme.STEPS);
        Draw.cell(dc, FOOTER_X_CENTER, FOOTER_Y, Graphics.FONT_SMALL,
            Metrics.temperature(), Metrics.conditionWord(), Theme.WEATHER);
        Draw.cell(dc, FOOTER_X_RIGHT, FOOTER_Y, Graphics.FONT_SMALL,
            battery.format("%d"), "BATTERY", Theme.battery(battery));

        // One hairline for the step goal - enough to tell "nearly there" from
        // "barely started" without spending a whole row on it.
        Draw.bar(dc, GOAL_BAR_X, GOAL_BAR_Y, GOAL_BAR_W, GOAL_BAR_H,
            Metrics.ratio(Metrics.steps(), Metrics.stepGoal()), Theme.STEPS);
    }
}
