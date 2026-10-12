import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Blocky drawing kit.
//!
//! Everything here is built from filled rectangles and hard-edged arcs.
//! Antialiasing stays off: a smoothed edge is the one thing that stops pixel
//! art reading as pixel art.
//!
//! Lit segments are bevelled - a light band along the top edge, a dark one
//! along the bottom. Flat fills read as 8-bit; shaded ones read as 16-bit,
//! and it costs two extra rectangles per cell.
module Draw {

    //! Clears to black with antialiasing off. Every onUpdate starts here.
    function begin(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(false);
        }
        dc.setColor(Graphics.COLOR_TRANSPARENT, Theme.BG);
        dc.clear();
    }

    function rect(dc as Graphics.Dc, x as Number, y as Number, width as Number,
                  height as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, width, height);
    }

    //! Hollow rectangle, drawn as four fills so the thickness is exact.
    function frame(dc as Graphics.Dc, x as Number, y as Number, width as Number,
                   height as Number, thickness as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, width, thickness);
        dc.fillRectangle(x, y + height - thickness, width, thickness);
        dc.fillRectangle(x, y, thickness, height);
        dc.fillRectangle(x + width - thickness, y, thickness, height);
    }

    //! Horizontal bar divided into discrete cells. A segmented bar reads as a
    //! count rather than a length, which is the whole point of the style.
    //!
    //! Cell widths are handed the division remainder one pixel at a time, so
    //! the bar fills its declared width exactly instead of stopping a few
    //! pixels short of its own box.
    function segBar(dc as Graphics.Dc, x as Number, y as Number, width as Number,
                    height as Number, cells as Number, fraction as Float,
                    color as Number) as Void {
        var gap = 2;
        var span = width - gap * (cells - 1);
        var base = span / cells;
        var extra = span % cells;

        var clamped = clampFraction(fraction);
        var lit = litCells(clamped, cells);
        var met = clamped >= 1.0;
        // A met goal lights every cell a shade brighter, so a full bar is
        // visibly different from one clamped just short of full.
        var body = met ? Theme.shade(color, 130) : color;
        var highlight = Theme.shade(body, 155);
        var shadow = Theme.shade(body, 55);
        var bevel = height >= 8 ? 2 : 1;

        var cursor = x;
        for (var i = 0; i < cells; i += 1) {
            var cellWidth = base + (i < extra ? 1 : 0);
            if (i >= lit) {
                dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cursor, y, cellWidth, height);
            } else {
                dc.setColor(body, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cursor, y, cellWidth, height);
                dc.setColor(highlight, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cursor, y, cellWidth, bevel);
                dc.setColor(shadow, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(cursor, y + height - bevel, cellWidth, bevel);
            }
            cursor += cellWidth + gap;
        }
    }

    function clampFraction(fraction as Float) as Float {
        if (fraction < 0.0) { return 0.0; }
        if (fraction > 1.0) { return 1.0; }
        return fraction;
    }

    //! Lit cell count. Anything above zero lights at least one cell: a bar
    //! that is entirely dark reads as a broken element rather than as a day
    //! that has barely started.
    function litCells(fraction as Float, cells as Number) as Number {
        var lit = (fraction * cells).toNumber();
        if (lit == 0 && fraction > 0.0) {
            lit = 1;
        }
        return lit;
    }

    //! Vertical meter, filling from the bottom like a VU display. Same
    //! remainder handling and same goal-met behaviour as segBar.
    function segMeter(dc as Graphics.Dc, x as Number, y as Number, width as Number,
                      height as Number, cells as Number, fraction as Float,
                      color as Number) as Void {
        var gap = 2;
        var span = height - gap * (cells - 1);
        var base = span / cells;
        var extra = span % cells;

        var clamped = clampFraction(fraction);
        var lit = litCells(clamped, cells);
        var body = clamped >= 1.0 ? Theme.shade(color, 130) : color;
        var highlight = Theme.shade(body, 155);
        var shadow = Theme.shade(body, 55);

        var cursor = y + height;
        for (var i = 0; i < cells; i += 1) {
            var cellHeight = base + (i < extra ? 1 : 0);
            var cellY = cursor - cellHeight;
            var bevel = cellHeight >= 8 ? 2 : 1;
            if (i >= lit) {
                dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, cellY, width, cellHeight);
            } else {
                dc.setColor(body, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, cellY, width, cellHeight);
                dc.setColor(highlight, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, cellY, width, bevel);
                dc.setColor(shadow, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(x, cellY + cellHeight - bevel, width, bevel);
            }
            cursor -= cellHeight + gap;
        }
    }

    //! Ring built from discrete arc segments with gaps between them.
    function segRing(dc as Graphics.Dc, cx as Number, cy as Number, radius as Number,
                     segments as Number, fraction as Float, color as Number,
                     pen as Number) as Void {
        var lit = litCells(clampFraction(fraction), segments);
        var span = 360.0 / segments;
        var gap = span * 0.22;
        dc.setPenWidth(pen);
        for (var i = 0; i < segments; i += 1) {
            // Clock degrees run clockwise from 12; Garmin arc degrees run
            // counter-clockwise from 3 o'clock, so one maps to the other
            // as 90 - x, then wraps into range.
            var from = normalize(90.0 - (i * span + gap / 2));
            var to = normalize(90.0 - ((i + 1) * span - gap / 2));
            dc.setColor(i < lit ? color : Theme.TRACK, Graphics.COLOR_TRANSPARENT);
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, from, to);
        }
    }

    function normalize(degrees as Float) as Float {
        var value = degrees;
        while (value < 0.0) { value += 360.0; }
        while (value >= 360.0) { value -= 360.0; }
        return value;
    }

    //! Sample-and-hold trace: a step per sample rather than a sloped line,
    //! which is both the period-correct look and cheaper to draw.
    function stepTrace(dc as Graphics.Dc, x as Number, y as Number, width as Number,
                       height as Number, series as Array<Number>, color as Number) as Void {
        var count = series.size();
        if (count < 2) {
            return;
        }
        var low = series[0];
        var high = series[0];
        for (var i = 1; i < count; i += 1) {
            if (series[i] < low) { low = series[i]; }
            if (series[i] > high) { high = series[i]; }
        }
        var span = high - low;
        if (span < 1) {
            span = 1;   // a flat trace still has to land somewhere
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var lastY = -1;
        for (var i = 0; i < count; i += 1) {
            // Edges derive from the full width, so the trace reaches the
            // right-hand side of its frame instead of stopping short of it.
            var left = x + i * width / count;
            var cellWidth = x + (i + 1) * width / count - left;
            var sampleY = y + height - (series[i] - low) * height / span;
            dc.fillRectangle(left, sampleY - 1, cellWidth, 3);
            if (lastY >= 0) {
                var top = lastY < sampleY ? lastY : sampleY;
                var bottom = lastY < sampleY ? sampleY : lastY;
                dc.fillRectangle(left, top, 3, bottom - top);
            }
            lastY = sampleY;
        }
    }

    //! Blocky histogram, one bar per sample. Empty bars still draw a stub so
    //! the strip reads as a full-width axis rather than a ragged gap.
    function histogram(dc as Graphics.Dc, x as Number, y as Number, width as Number,
                       height as Number, series as Array<Number>, color as Number) as Void {
        var count = series.size();
        if (count < 1) {
            return;
        }
        var low = series[0];
        var high = series[0];
        for (var i = 1; i < count; i += 1) {
            if (series[i] < low) { low = series[i]; }
            if (series[i] > high) { high = series[i]; }
        }
        var span = high - low;
        if (span < 1) {
            span = 1;
        }
        var highlight = Theme.shade(color, 160);
        for (var i = 0; i < count; i += 1) {
            var barX = x + i * width / count;
            var barWidth = x + (i + 1) * width / count - barX - 2;
            if (barWidth < 1) {
                barWidth = 1;
            }
            var barHeight = (series[i] - low) * height / span;
            if (barHeight < 2) {
                barHeight = 2;
            }
            var barY = y + height - barHeight;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, barWidth, barHeight);
            dc.setColor(highlight, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, barWidth, 1);
        }
    }

    //! CRT raster. Costs one fill per line, so keep the step coarse.
    function scanlines(dc as Graphics.Dc, step as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var y = 0; y < Layout.HEIGHT; y += step) {
            dc.fillRectangle(0, y, Layout.WIDTH, 1);
        }
    }

    function grid(dc as Graphics.Dc, x as Number, y as Number, width as Number,
                  height as Number, step as Number, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var gx = x; gx <= x + width; gx += step) {
            dc.fillRectangle(gx, y, 1, height);
        }
        for (var gy = y; gy <= y + height; gy += step) {
            dc.fillRectangle(x, gy, width, 1);
        }
    }

    //! Status squares: blue unread notifications, amber alarm, purple do not
    //! disturb, red phone disconnected. Nothing drawn when all are clear.
    function statusBlocks(dc as Graphics.Dc, centerX as Number, y as Number,
                          size as Number) as Void {
        var blocks = [] as Array<Number>;
        if (Metrics.notifications() > 0) {
            blocks.add(Theme.BODY);
        }
        if (Metrics.alarmSet()) {
            blocks.add(Theme.STRESS);
        }
        if (Metrics.doNotDisturb()) {
            blocks.add(Theme.FLOORS);
        }
        if (!Metrics.phoneConnected()) {
            blocks.add(Theme.HR);
        }
        if (blocks.size() == 0) {
            return;
        }
        var pitch = size + 6;
        var startX = centerX - (blocks.size() * pitch - 6) / 2;
        for (var i = 0; i < blocks.size(); i += 1) {
            var blockX = startX + i * pitch;
            dc.setColor(blocks[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(blockX, y - size / 2, size, size);
            dc.setColor(Theme.shade(blocks[i], 160), Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(blockX, y - size / 2, size, 1);
        }
    }

    //! Twelve major blocks over a fine sixty-step minute track. The 8-bit
    //! revision dropped the minute track because at that block size it
    //! smeared; at two pixels it reads cleanly.
    function dialBlocks(dc as Graphics.Dc, cx as Number, cy as Number,
                        radius as Number) as Void {
        dc.setColor(Theme.FAINT, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < 60; i += 1) {
            if (i % 5 != 0) {
                var minuteAngle = Math.toRadians(i * 6);
                dc.fillRectangle(
                    (cx + radius * Math.sin(minuteAngle) - 1).toNumber(),
                    (cy - radius * Math.cos(minuteAngle) - 1).toNumber(), 3, 3);
            }
        }
        for (var i = 0; i < 12; i += 1) {
            var radians = Math.toRadians(i * 30);
            var quarter = i % 3 == 0;
            var size = quarter ? 12 : 7;
            dc.setColor(quarter ? Theme.TEXT : Theme.DIM, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(
                (cx + radius * Math.sin(radians) - size / 2).toNumber(),
                (cy - radius * Math.cos(radians) - size / 2).toNumber(),
                size, size);
        }
    }

    //! Clock hand drawn as a staircase of blocks snapped to a grid, so it
    //! steps like the rest of the face instead of laying a smooth diagonal
    //! across it. Samples overlap deliberately - that is what closes the
    //! gaps between cells on a steep angle.
    function pixelHand(dc as Graphics.Dc, cx as Number, cy as Number, degrees as Float,
                       length as Number, tail as Number, block as Number,
                       color as Number) as Void {
        var radians = Math.toRadians(degrees);
        var sin = Math.sin(radians);
        var cos = Math.cos(radians);
        var steps = (length + tail) * 2 / block + 1;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < steps; i += 1) {
            var distance = -tail + i * block / 2.0;
            var px = cx + distance * sin;
            var py = cy - distance * cos;
            dc.fillRectangle((px / block).toNumber() * block,
                             (py / block).toNumber() * block, block, block);
        }
    }

    //! A value with a caption under it, both in pixel type, centred on x.
    function field(dc as Graphics.Dc, centerX as Number, y as Number, value as String,
                   label as String, color as Number, valueScale as Number,
                   labelScale as Number) as Void {
        PixelFont.drawCentered(dc, centerX, y, valueScale, value, color);
        var labelY = y + PixelFont.height(valueScale) / 2 + 6
                   + PixelFont.height(labelScale) / 2;
        PixelFont.drawCentered(dc, centerX, labelY, labelScale, label, Theme.DIM);
    }
}
