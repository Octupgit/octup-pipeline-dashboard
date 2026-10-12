import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! VANGUARD - minimal.
//!
//! Hours over minutes at twenty-pixel blocks, which is far larger than any
//! built-in font reaches. Everything else is one row and one segmented bar.
class VanguardView extends WatchUi.WatchFace {

    private const STATUS_Y = 36;
    private const DATE_Y   = 66;
    private const HOUR_Y   = 160;
    private const MINUTE_Y = 316;

    private const BAR_X = 92;
    private const BAR_Y = 398;
    private const BAR_W = 264;
    private const BAR_H = 10;
    private const BAR_CELLS = 12;

    private const FOOTER_Y = 428;
    private const FOOTER_X_LEFT   = 84;
    private const FOOTER_X_CENTER = 224;
    private const FOOTER_X_RIGHT  = 364;

    private const TIME_SCALE = 20;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.begin(dc);

        Draw.statusBlocks(dc, Layout.CENTER_X, STATUS_Y, 10);
        PixelFont.drawCentered(dc, Layout.CENTER_X, DATE_Y, 3, Metrics.dateLine(), Theme.DIM);

        // Minutes take the accent colour so the time reads as two numbers
        // rather than one four-digit block.
        PixelFont.drawCentered(dc, Layout.CENTER_X, HOUR_Y, TIME_SCALE,
            Metrics.hours(), Theme.TEXT);
        PixelFont.drawCentered(dc, Layout.CENTER_X, MINUTE_Y, TIME_SCALE,
            Metrics.minutes(), Theme.BODY);

        Draw.segBar(dc, BAR_X, BAR_Y, BAR_W, BAR_H, BAR_CELLS,
            Metrics.ratio(Metrics.steps(), Metrics.stepGoal()), Theme.STEPS);

        var battery = Metrics.batteryPercent();
        Draw.field(dc, FOOTER_X_LEFT, FOOTER_Y, Metrics.compact(Metrics.steps()),
            "STEPS", Theme.STEPS, 4, 2);
        Draw.field(dc, FOOTER_X_CENTER, FOOTER_Y, Metrics.temperatureGlyph(),
            "TEMP", Theme.WEATHER, 4, 2);
        Draw.field(dc, FOOTER_X_RIGHT, FOOTER_Y, battery.format("%d"),
            "BATT", Theme.battery(battery), 4, 2);
    }
}
