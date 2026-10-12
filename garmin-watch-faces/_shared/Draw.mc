import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Blocky drawing kit.
//!
//! Everything here is built from filled rectangles and hard-edged arcs.
//! Antialiasing is turned off on purpose: a smoothed edge is the one thing
//! that stops pixel art reading as pixel art.
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
    function segBar(dc as Graphics.Dc, x as Number, y as Number, width as Number,
                    height as Number, cells as Number, fraction as Float,
                    color as Number) as Void {
        var gap = 3;
        var cellWidth = (width - gap * (cells - 1)) / cells;
        var lit = (fraction * cells).toNumber();
        for (var i = 0; i < cells; i += 1) {
            dc.setColor(i < lit ? color : Theme.TRACK, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x + i * (cellWidth + gap), y, cellWidth, height);
        }
    }

    //! Vertical meter, filling from the bottom like a VU display.
    function segMeter(dc as Graphics.Dc, x as Number, y as Number, width as Number,
                      height as Number, cells as Number, fraction as Float,
                      color as Number) as Void {
        var gap = 3;
        var cellHeight = (height - gap * (cells - 1)) / cells;
        var lit = (fraction * cells).toNumber();
        for (var i = 0; i < cells; i += 1) {
            var cellY = y + height - (i + 1) * cellHeight - i * gap;
            dc.setColor(i < lit ? color : Theme.TRACK, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, cellY, width, cellHeight);
        }
    }

    //! Ring built from discrete arc segments with gaps between them.
    function segRing(dc as Graphics.Dc, cx as Number, cy as Number, radius as Number,
                     segments as Number, fraction as Float, color as Number,
                     pen as Number) as Void {
        var lit = (fraction * segments).toNumber();
        var span = 360.0 / segments;
        var gap = span * 0.3;
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
        var cellWidth = width / count;
        if (cellWidth < 1) {
            cellWidth = 1;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var lastY = -1;
        for (var i = 0; i < count; i += 1) {
            var sampleY = y + height - (series[i] - low) * height / span;
            dc.fillRectangle(x + i * cellWidth, sampleY - 1, cellWidth, 3);
            if (lastY >= 0) {
                var top = lastY < sampleY ? lastY : sampleY;
                var bottom = lastY < sampleY ? sampleY : lastY;
                dc.fillRectangle(x + i * cellWidth, top, 3, bottom - top);
            }
            lastY = sampleY;
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
            dc.setColor(blocks[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(startX + i * pitch, y - size / 2, size, size);
        }
    }

    //! Twelve square markers instead of sixty hairlines - at this pixel size
    //! a minute track turns into a grey smear.
    function dialBlocks(dc as Graphics.Dc, cx as Number, cy as Number,
                        radius as Number) as Void {
        for (var i = 0; i < 12; i += 1) {
            var radians = Math.toRadians(i * 30);
            var quarter = i % 3 == 0;
            var size = quarter ? 14 : 8;
            dc.setColor(quarter ? Theme.TEXT : Theme.FAINT, Graphics.COLOR_TRANSPARENT);
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
