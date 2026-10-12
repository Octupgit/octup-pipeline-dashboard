import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! TRACE - oscilloscope.
//!
//! Recent heart-rate history as a sample-and-hold trace over a framed
//! graticule: a step per sample rather than a sloped line, which is both the
//! period-correct look and cheaper to draw.
//!
//! The trace autoscales, so the window's high and low are printed beside it.
//! Without them a flat resting stretch and a hard interval look identical.
class TraceView extends WatchUi.WatchFace {

    private const SAMPLES = 40;

    private const TIME_Y = 70;
    private const DATE_Y = 108;

    private const PLOT_X = 22;
    private const PLOT_Y = 140;
    private const PLOT_W = 404;
    private const PLOT_H = 180;
    private const PLOT_INSET = 6;
    private const GRID_STEP = 34;

    private const LABEL_TOP_Y    = 126;
    private const LABEL_BOTTOM_Y = 336;

    private const FOOTER_Y  = 376;
    private const FOOTER_X1 = 90;
    private const FOOTER_X2 = 224;
    private const FOOTER_X3 = 358;

    private const BAR_Y = 428;
    private const STATUS_Y = 458;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.begin(dc);

        PixelFont.drawCentered(dc, Layout.CENTER_X, TIME_Y, 8,
            Lang.format("$1$:$2$", [Metrics.hours(), Metrics.minutes()]), Theme.TEXT);
        PixelFont.drawCentered(dc, Layout.CENTER_X, DATE_Y, 2, Metrics.dateLine(), Theme.DIM);

        drawPlot(dc);

        var battery = Metrics.batteryPercent();
        Draw.field(dc, FOOTER_X1, FOOTER_Y, Metrics.compact(Metrics.steps()),
            "STEPS", Theme.STEPS, 4, 2);
        Draw.field(dc, FOOTER_X2, FOOTER_Y, Metrics.text(Metrics.heartRate()),
            "BPM", Theme.HR, 4, 2);
        Draw.field(dc, FOOTER_X3, FOOTER_Y, battery.format("%d"),
            "BATT", Theme.battery(battery), 4, 2);

        Draw.segBar(dc, Layout.LEFT, BAR_Y, Layout.INNER_W, 10, 20,
            Metrics.ratio(Metrics.steps(), Metrics.stepGoal()), Theme.STEPS);
        Draw.statusBlocks(dc, Layout.CENTER_X, STATUS_Y, 8);
    }

    private function drawPlot(dc as Graphics.Dc) as Void {
        Draw.grid(dc, PLOT_X, PLOT_Y, PLOT_W, PLOT_H, GRID_STEP, Theme.TRACK);
        Draw.frame(dc, PLOT_X, PLOT_Y, PLOT_W, PLOT_H, 2, Theme.FAINT);

        var series = Metrics.heartRateSeries(SAMPLES);
        PixelFont.draw(dc, Layout.LEFT, LABEL_TOP_Y, 2, "HR", Theme.DIM);

        if (series.size() < 2) {
            PixelFont.drawCentered(dc, Layout.CENTER_X, PLOT_Y + PLOT_H / 2, 3,
                "NO SIGNAL", Theme.FAINT);
            return;
        }

        Draw.stepTrace(dc, PLOT_X + PLOT_INSET, PLOT_Y + PLOT_INSET,
            PLOT_W - 2 * PLOT_INSET, PLOT_H - 2 * PLOT_INSET, series, Theme.HR);

        PixelFont.drawRight(dc, Layout.RIGHT, LABEL_TOP_Y, 2,
            Metrics.text(Metrics.seriesHigh(series)), Theme.DIM);
        PixelFont.drawRight(dc, Layout.RIGHT, LABEL_BOTTOM_Y, 2,
            Metrics.text(Metrics.seriesLow(series)), Theme.DIM);
        PixelFont.draw(dc, Layout.LEFT, LABEL_BOTTOM_Y, 2,
            series.size().format("%d") + " SAMPLES", Theme.FAINT);
    }
}
