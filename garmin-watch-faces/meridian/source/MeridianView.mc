import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;

//! MERIDIAN - blocky analog.
//!
//! Twelve square markers instead of a sixty-tick track, hands drawn as
//! staircases of snapped blocks, and a segmented Body Battery ring outside. At this pixel size a
//! minute track turns into a grey smear, so it is left out.
//!
//! The second hand only runs while the screen is awake.
class MeridianView extends WatchUi.WatchFace {

    private const CENTER_Y = 210;
    private const ARC_RADIUS  = 192;
    private const ARC_PEN     = 10;
    private const ARC_SEGMENTS = 24;
    private const DIAL_RADIUS = 168;

    private const HOUR_LENGTH   = 104;
    private const MINUTE_LENGTH = 158;
    private const SECOND_LENGTH = 170;

    private const STATUS_Y = 76;
    private const DATE_Y   = 424;
    private const STRIP_Y  = 452;
    private const STRIP_X1 = 78;
    private const STRIP_X2 = 176;
    private const STRIP_X3 = 272;
    private const STRIP_X4 = 370;

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
        Draw.begin(dc);

        Draw.segRing(dc, Layout.CENTER_X, CENTER_Y, ARC_RADIUS, ARC_SEGMENTS,
            Metrics.ratio(Metrics.bodyBattery(), 100), Theme.BODY, ARC_PEN);
        Draw.dialBlocks(dc, Layout.CENTER_X, CENTER_Y, DIAL_RADIUS);
        Draw.statusBlocks(dc, Layout.CENTER_X, STATUS_Y, 8);

        drawStrip(dc);
        drawHands(dc);
    }

    //! Values carry no captions: this face is meant to look like a watch
    //! rather than a readout, and the colours identify them once worn -
    //! green steps, red heart, white temperature, grey battery.
    private function drawStrip(dc as Graphics.Dc) as Void {
        PixelFont.drawCentered(dc, Layout.CENTER_X, DATE_Y, 2, Metrics.dateLine(), Theme.DIM);

        var battery = Metrics.batteryPercent();
        PixelFont.drawCentered(dc, STRIP_X1, STRIP_Y, 3,
            Metrics.compact(Metrics.steps()), Theme.STEPS);
        PixelFont.drawCentered(dc, STRIP_X2, STRIP_Y, 3,
            Metrics.text(Metrics.heartRate()), Theme.HR);
        PixelFont.drawCentered(dc, STRIP_X3, STRIP_Y, 3,
            Metrics.temperatureGlyph(), Theme.WEATHER);
        PixelFont.drawCentered(dc, STRIP_X4, STRIP_Y, 3,
            battery.format("%d") + "%", Theme.battery(battery));
    }

    private function drawHands(dc as Graphics.Dc) as Void {
        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        // The hour hand creeps with the minutes rather than jumping on the hour.
        var hourDegrees = ((now.hour % 12) + now.min / 60.0) * 30.0;
        var minuteDegrees = (now.min + now.sec / 60.0) * 6.0;

        Draw.pixelHand(dc, Layout.CENTER_X, CENTER_Y, hourDegrees, HOUR_LENGTH, 30, 12, Theme.TEXT);
        Draw.pixelHand(dc, Layout.CENTER_X, CENTER_Y, minuteDegrees, MINUTE_LENGTH, 36, 8, Theme.TEXT);
        if (mAwake) {
            Draw.pixelHand(dc, Layout.CENTER_X, CENTER_Y, now.sec * 6.0, SECOND_LENGTH, 40, 4, Theme.BODY);
        }

        // Square centre cap, drawn last so the hands disappear under it.
        Draw.rect(dc, Layout.CENTER_X - 8, CENTER_Y - 8, 16, 16, Theme.TEXT);
        Draw.rect(dc, Layout.CENTER_X - 3, CENTER_Y - 3, 6, 6, Theme.BG);
    }
}
