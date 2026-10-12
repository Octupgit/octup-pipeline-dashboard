import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! MERIDIAN - analog hybrid, filling the shared dial.
//!
//! A proper analog dial with sixty ticks and a creeping hour hand, with Body
//! Battery wrapped around the outside. Data sits inside the dial as a watch
//! would place it: battery and date above the centre, three values below.
//! The hands are drawn last, so they pass over the text rather than under it.
//!
//! The second hand only runs while the screen is awake; there is no point
//! animating a hand nobody is looking at.
//!
//! Every Y below is the vertical centre of its element, in device pixels.
class MeridianView extends WatchUi.WatchFace {

    private const BODY_ARC_PEN = 8;
    private const DIAL_RADIUS    = 186;
    private const NUMERAL_RADIUS = 146;

    private const HOUR_LENGTH   = 110;
    private const MINUTE_LENGTH = 166;
    private const SECOND_LENGTH = 178;

    private const DATE_Y   = 152;
    private const STRIP_Y  = 326;
    private const STATUS_Y = 366;
    // Four columns, spaced to stay inside the dial at this height.
    private const STRIP_X_1 = 118;
    private const STRIP_X_2 = 185;
    private const STRIP_X_3 = 252;
    private const STRIP_X_4 = 319;

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

        Draw.ring(dc, Layout.CENTER_X, Layout.CENTER_Y, Layout.OUTER_R,
            Metrics.ratio(Metrics.bodyBattery(), 100), Theme.BODY, BODY_ARC_PEN);

        Draw.dialTicks(dc, Layout.CENTER_X, Layout.CENTER_Y, DIAL_RADIUS);
        drawNumerals(dc);
        drawData(dc);
        drawHands(dc);
    }

    private function drawNumerals(dc as Graphics.Dc) as Void {
        var centered = Graphics.TEXT_JUSTIFY_CENTER;
        Draw.text(dc, Layout.CENTER_X, Layout.CENTER_Y - NUMERAL_RADIUS,
            Graphics.FONT_XTINY, "12", Theme.DIM, centered);
        Draw.text(dc, Layout.CENTER_X + NUMERAL_RADIUS, Layout.CENTER_Y,
            Graphics.FONT_XTINY, "3", Theme.DIM, centered);
        Draw.text(dc, Layout.CENTER_X, Layout.CENTER_Y + NUMERAL_RADIUS,
            Graphics.FONT_XTINY, "6", Theme.DIM, centered);
        Draw.text(dc, Layout.CENTER_X - NUMERAL_RADIUS, Layout.CENTER_Y,
            Graphics.FONT_XTINY, "9", Theme.DIM, centered);
    }

    //! Values carry no captions on purpose: this face is meant to look like a
    //! watch rather than a readout, and the colours identify them once worn:
    //! green steps, red heart, white temperature, grey battery.
    private function drawData(dc as Graphics.Dc) as Void {
        Draw.text(dc, Layout.CENTER_X, DATE_Y, Graphics.FONT_XTINY, Metrics.dateLine(),
            Theme.DIM, Graphics.TEXT_JUSTIFY_CENTER);

        // Battery joins the row rather than sitting above the centre, where it
        // collided with the 12.
        var battery = Metrics.batteryPercent();
        Draw.text(dc, STRIP_X_1, STRIP_Y, Graphics.FONT_XTINY,
            Metrics.compact(Metrics.steps()), Theme.STEPS, Graphics.TEXT_JUSTIFY_CENTER);
        Draw.text(dc, STRIP_X_2, STRIP_Y, Graphics.FONT_XTINY,
            Metrics.text(Metrics.heartRate()), Theme.HR, Graphics.TEXT_JUSTIFY_CENTER);
        Draw.text(dc, STRIP_X_3, STRIP_Y, Graphics.FONT_XTINY,
            Metrics.temperature() + "°", Theme.WEATHER, Graphics.TEXT_JUSTIFY_CENTER);
        Draw.text(dc, STRIP_X_4, STRIP_Y, Graphics.FONT_XTINY,
            battery.format("%d") + "%", Theme.battery(battery), Graphics.TEXT_JUSTIFY_CENTER);

        Draw.statusDots(dc, Layout.CENTER_X, STATUS_Y);
    }

    private function drawHands(dc as Graphics.Dc) as Void {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        // The hour hand creeps with the minutes rather than jumping on the hour.
        var hourDegrees = ((now.hour % 12) + now.min / 60.0) * 30.0;
        var minuteDegrees = (now.min + now.sec / 60.0) * 6.0;

        Draw.hand(dc, Layout.CENTER_X, Layout.CENTER_Y, hourDegrees,
            HOUR_LENGTH, 36, 18, 9, Theme.TEXT);
        Draw.hand(dc, Layout.CENTER_X, Layout.CENTER_Y, minuteDegrees,
            MINUTE_LENGTH, 44, 13, 6, Theme.TEXT);

        if (mAwake) {
            Draw.hand(dc, Layout.CENTER_X, Layout.CENTER_Y, now.sec * 6.0,
                SECOND_LENGTH, 50, 4, 3, Theme.BODY);
        }

        // Centre cap, drawn last so the hands disappear under it.
        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(Layout.CENTER_X, Layout.CENTER_Y, 11);
        dc.setColor(Theme.BG, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(Layout.CENTER_X, Layout.CENTER_Y, 5);
    }
}
