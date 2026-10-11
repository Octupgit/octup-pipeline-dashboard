import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! MERIDIAN - analog hybrid face.
//!
//! A proper analog dial with a thin data strip underneath, and Body Battery
//! wrapped around the outside as an arc. The second hand only runs while the
//! screen is awake; there is no point animating a hand nobody is looking at.
//!
//! The strip values carry no captions on purpose - this face is meant to look
//! like a watch rather than a readout, and the colours identify the metrics
//! once you have worn it for a day: green steps, red heart, white temperature,
//! grey battery.
//!
//! Layout is fixed to the Venu X1's 448 x 486 panel.
class MeridianView extends WatchUi.WatchFace {

    private const CENTER_X = 224;
    private const CENTER_Y = 196;

    private const DIAL_RADIUS = 168;
    private const BODY_ARC_RADIUS = 186;
    private const BODY_ARC_PEN = 8;
    private const NUMERAL_RADIUS = 130;

    private const HOUR_LENGTH   = 100;
    private const MINUTE_LENGTH = 150;
    private const SECOND_LENGTH = 162;

    private const DATE_Y    = 404;
    private const STRIP_Y   = 440;
    private const STATUS_Y  = 472;
    private const STRIP_X1  = 60;
    private const STRIP_X2  = 164;
    private const STRIP_X3  = 284;
    private const STRIP_X4  = 388;

    private var mAwake as Boolean = true;

    function initialize() {
        WatchFace.initialize();
    }

    function onExitSleep() as Void {
        mAwake = true;
    }

    function onEnterSleep() as Void {
        mAwake = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.antiAlias(dc);
        Draw.clearScreen(dc);

        drawBodyBatteryArc(dc);
        Draw.dialTicks(dc, CENTER_X, CENTER_Y, DIAL_RADIUS);
        drawNumerals(dc);
        drawHands(dc);
        drawStrip(dc);
    }

    private function drawBodyBatteryArc(dc as Graphics.Dc) as Void {
        Draw.ring(dc, CENTER_X, CENTER_Y, BODY_ARC_RADIUS,
            Metrics.ratio(Metrics.bodyBattery(), 100), Theme.BODY, BODY_ARC_PEN);
    }

    private function drawNumerals(dc as Graphics.Dc) as Void {
        var justify = Graphics.TEXT_JUSTIFY_CENTER;
        Draw.text(dc, CENTER_X, CENTER_Y - NUMERAL_RADIUS, Graphics.FONT_XTINY, "12",
            Theme.DIM, justify);
        Draw.text(dc, CENTER_X + NUMERAL_RADIUS, CENTER_Y, Graphics.FONT_XTINY, "3",
            Theme.DIM, justify);
        Draw.text(dc, CENTER_X, CENTER_Y + NUMERAL_RADIUS, Graphics.FONT_XTINY, "6",
            Theme.DIM, justify);
        Draw.text(dc, CENTER_X - NUMERAL_RADIUS, CENTER_Y, Graphics.FONT_XTINY, "9",
            Theme.DIM, justify);
    }

    private function drawHands(dc as Graphics.Dc) as Void {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        // The hour hand creeps with the minutes rather than jumping on the hour.
        var hourDegrees = ((now.hour % 12) + now.min / 60.0) * 30.0;
        var minuteDegrees = (now.min + now.sec / 60.0) * 6.0;

        Draw.hand(dc, CENTER_X, CENTER_Y, hourDegrees, HOUR_LENGTH, 34, 18, 9, Theme.TEXT);
        Draw.hand(dc, CENTER_X, CENTER_Y, minuteDegrees, MINUTE_LENGTH, 40, 13, 6, Theme.TEXT);

        if (mAwake) {
            Draw.hand(dc, CENTER_X, CENTER_Y, now.sec * 6.0, SECOND_LENGTH, 46, 4, 3, Theme.BODY);
        }

        // Centre cap, drawn last so the hands disappear under it.
        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(CENTER_X, CENTER_Y, 11);
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(CENTER_X, CENTER_Y, 5);
    }

    private function drawStrip(dc as Graphics.Dc) as Void {
        Draw.text(dc, CENTER_X, DATE_Y, Graphics.FONT_XTINY, Metrics.dateLine(),
            Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        var battery = Metrics.batteryPercent();
        Draw.text(dc, STRIP_X1, STRIP_Y, Graphics.FONT_SMALL,
            Metrics.compact(Metrics.steps()), Theme.STEPS, Graphics.TEXT_JUSTIFY_CENTER);
        Draw.text(dc, STRIP_X2, STRIP_Y, Graphics.FONT_SMALL,
            Metrics.text(Metrics.heartRate()), Theme.HR, Graphics.TEXT_JUSTIFY_CENTER);
        Draw.text(dc, STRIP_X3, STRIP_Y, Graphics.FONT_SMALL,
            Metrics.temperature(), Theme.WEATHER, Graphics.TEXT_JUSTIFY_CENTER);
        Draw.text(dc, STRIP_X4, STRIP_Y, Graphics.FONT_SMALL,
            battery.format("%d") + "%", Theme.battery(battery), Graphics.TEXT_JUSTIFY_CENTER);

        Draw.statusDots(dc, CENTER_X, STATUS_Y);
    }
}
