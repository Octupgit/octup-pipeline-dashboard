import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

//! DAILY - the stock Venu X1 layout, rebuilt in blocks.
//!
//! Same furniture and the same reading order as the face it replaces: a
//! weekday strip with today inverted, the date beside it, a Body Battery
//! row, the little activity histogram, a large gradient clock, then steps,
//! battery hours and temperature, and four ring complications along the
//! bottom.
//!
//! Two departures from the original. The histogram plots recent heart rate,
//! because Connect IQ exposes no intraday step series to a watch face - the
//! stock strip is drawing something apps cannot reach. And the rings are
//! segmented rather than smooth, to match the rest of the set.
class DailyView extends WatchUi.WatchFace {

    private const WEEKDAYS = "SMTWTFS";
    private const SAMPLES = 40;

    // Weekday strip and date.
    private const STRIP_Y = 32;
    private const STRIP_H = 34;
    private const STRIP_W = 268;
    private const DATE_X  = 298;
    private const DATE_W  = 128;

    // Body Battery row.
    private const BODY_ROW_Y = 74;
    private const BODY_ROW_H = 34;

    // Activity histogram.
    private const HIST_X = 24;
    private const HIST_Y = 118;
    private const HIST_W = 400;
    private const HIST_H = 34;

    private const TIME_Y = 210;
    private const TIME_SCALE = 14;

    // Steps, battery and temperature.
    // Tall enough for a caption stacked over a scale-4 value without either
    // touching the frame.
    private const INFO_Y = 272;
    private const INFO_H = 60;
    private const INFO_LABEL_DY = 16;
    private const INFO_VALUE_DY = 40;
    private const STEPS_W = 196;
    private const BATT_X  = 240;

    // Ring complications.
    private const RING_Y = 400;
    private const RING_R = 42;
    private const RING_PEN = 8;
    private const RING_SEGMENTS = 16;
    private const RING_LABEL_Y = 456;
    private const RING_X1 = 70;
    private const RING_X2 = 172;
    private const RING_X3 = 274;
    private const RING_X4 = 376;

    // Heart rate mapped over a range wide enough to cover rest to effort.
    private const HR_FLOOR = 40.0;
    private const HR_SPAN  = 140.0;

    function initialize() {
        WatchFace.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Draw.begin(dc);

        drawHeader(dc);
        drawBodyRow(dc);
        var series = Metrics.heartRateSeries(SAMPLES);
        if (series.size() > 0) {
            Draw.histogram(dc, HIST_X, HIST_Y, HIST_W, HIST_H, series, Theme.HR);
        } else {
            // Say so rather than leaving a band of nothing.
            PixelFont.drawCentered(dc, Layout.CENTER_X, HIST_Y + HIST_H / 2, 2,
                "NO HR HISTORY", Theme.FAINT);
        }

        // Amber into green, stepped once per digit.
        PixelFont.drawGradientCentered(dc, Layout.CENTER_X, TIME_Y, TIME_SCALE,
            Lang.format("$1$:$2$", [Metrics.hours(), Metrics.minutes()]),
            Theme.STRESS, Theme.STEPS);

        drawInfoRow(dc);
        drawRings(dc);
    }

    //! S M T W T F S with today's cell inverted, and the date beside it.
    private function drawHeader(dc as Graphics.Dc) as Void {
        Draw.frame(dc, Layout.LEFT, STRIP_Y, STRIP_W, STRIP_H, 2, Theme.FAINT);
        var today = Metrics.weekdayIndex();
        var cell = STRIP_W / 7;
        var centerY = STRIP_Y + STRIP_H / 2;
        for (var i = 0; i < 7; i += 1) {
            var cellX = Layout.LEFT + i * cell;
            var color = Theme.DIM;
            if (i == today) {
                Draw.rect(dc, cellX + 3, STRIP_Y + 3, cell - 6, STRIP_H - 6, Theme.STRESS);
                color = Theme.BG;
            }
            PixelFont.drawCentered(dc, cellX + cell / 2, centerY, 2,
                WEEKDAYS.substring(i, i + 1), color);
        }

        Draw.frame(dc, DATE_X, STRIP_Y, DATE_W, STRIP_H, 2, Theme.FAINT);
        PixelFont.drawCentered(dc, DATE_X + DATE_W / 2, centerY, 2,
            Metrics.dayAndMonth(), Theme.TEXT);
    }

    private function drawBodyRow(dc as Graphics.Dc) as Void {
        Draw.frame(dc, Layout.LEFT, BODY_ROW_Y, Layout.INNER_W, BODY_ROW_H, 2, Theme.FAINT);
        var centerY = BODY_ROW_Y + BODY_ROW_H / 2;
        var bodyBattery = Metrics.bodyBattery();
        PixelFont.draw(dc, Layout.LEFT + 12, centerY, 2, "BODY BATT", Theme.DIM);
        PixelFont.drawRight(dc, Layout.RIGHT - 12, centerY, 3,
            Metrics.text(bodyBattery), Theme.BODY);
        // A short bar between the two, so the row carries a shape as well as
        // a number.
        Draw.segBar(dc, Layout.LEFT + 150, centerY - 5, 150, 10, 10,
            Metrics.ratio(bodyBattery, 100), Theme.BODY);
    }

    private function drawInfoRow(dc as Graphics.Dc) as Void {
        Draw.frame(dc, Layout.LEFT, INFO_Y, STEPS_W, INFO_H, 2, Theme.FAINT);
        PixelFont.draw(dc, Layout.LEFT + 12, INFO_Y + INFO_LABEL_DY, 2, "STEPS", Theme.DIM);
        PixelFont.drawRight(dc, Layout.LEFT + STEPS_W - 12, INFO_Y + INFO_VALUE_DY, 4,
            Metrics.text(Metrics.steps()), Theme.STEPS);

        var hours = Metrics.batteryHours();
        PixelFont.draw(dc, BATT_X, INFO_Y + INFO_LABEL_DY, 2, "BATT", Theme.DIM);
        PixelFont.draw(dc, BATT_X, INFO_Y + INFO_VALUE_DY + 2, 3,
            hours == null ? Metrics.text(null) : hours.format("%d") + "H",
            Theme.battery(Metrics.batteryPercent()));

        PixelFont.drawRight(dc, Layout.RIGHT, INFO_Y + 32, 6,
            Metrics.temperatureGlyph(), Theme.WEATHER);
    }

    private function drawRings(dc as Graphics.Dc) as Void {
        var heartRate = Metrics.heartRate();
        var heartFraction = 0.0;
        if (heartRate != null) {
            heartFraction = (heartRate.toFloat() - HR_FLOOR) / HR_SPAN;
        }
        ring(dc, RING_X1, Metrics.ratio(Metrics.bodyBattery(), 100),
            Metrics.text(Metrics.bodyBattery()), "BODY", Theme.BODY);
        ring(dc, RING_X2, Metrics.ratio(Metrics.stress(), 100),
            Metrics.text(Metrics.stress()), "STRESS", Theme.STRESS);
        ring(dc, RING_X3, Metrics.ratio(Metrics.intensityMinutes(), Metrics.intensityGoal()),
            Metrics.text(Metrics.intensityMinutes()), "MINS", Theme.INTENSITY);
        ring(dc, RING_X4, heartFraction, Metrics.text(heartRate), "HR", Theme.HR);
    }

    private function ring(dc as Graphics.Dc, x as Number, fraction as Float, value as String,
                          label as String, color as Number) as Void {
        Draw.segRing(dc, x, RING_Y, RING_R, RING_SEGMENTS, fraction, color, RING_PEN);
        PixelFont.drawCentered(dc, x, RING_Y, 3, value, color);
        PixelFont.drawCentered(dc, x, RING_LABEL_Y, 2, label, Theme.DIM);
    }
}
