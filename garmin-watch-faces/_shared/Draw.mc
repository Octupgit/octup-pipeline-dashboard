import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;

//! Drawing primitives shared by the four faces. Everything here is stateless
//! and takes an explicit Dc so it can be called from any onUpdate.
module Draw {

    function antiAlias(dc as Graphics.Dc) as Void {
        if (dc has :setAntiAlias) {
            dc.setAntiAlias(true);
        }
    }

    function clearScreen(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_TRANSPARENT, Theme.BG);
        dc.clear();
    }

    //! Ring gauge: a dim full-circle track with the filled portion swept
    //! clockwise from 12 o'clock.
    function ring(dc as Graphics.Dc, centerX as Number, centerY as Number, radius as Number,
                  fraction as Float, color as Number, penWidth as Number) as Void {
        dc.setPenWidth(penWidth);
        dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX, centerY, radius);
        if (fraction <= 0.0) {
            return;
        }
        // An exactly-360-degree arc draws nothing, so a completed ring stops a
        // tenth of a degree short of its own start.
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(centerX, centerY, radius, Graphics.ARC_CLOCKWISE, 90, 90 - 359.9 * fraction);
    }

    function bar(dc as Graphics.Dc, x as Number, y as Number, width as Number, height as Number,
                 fraction as Float, color as Number) as Void {
        dc.setColor(Theme.TRACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, width, height);
        if (fraction <= 0.0) {
            return;
        }
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, (width * fraction).toNumber(), height);
    }

    //! A coloured value with a dim caption underneath, centred on x.
    function cell(dc as Graphics.Dc, x as Number, y as Number, font as Graphics.FontType,
                  value as String, label as String, color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, value,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Theme.DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + dc.getFontHeight(font) / 2 + 11, Graphics.FONT_XTINY, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function text(dc as Graphics.Dc, x as Number, y as Number, font as Graphics.FontType,
                  value as String, color as Number, justify as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, value, justify | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Status indicators as coloured dots rather than icon bitmaps: no image
    //! resources to carry, and the colours are learnable in a day.
    //! blue = unread notifications, amber = alarm set, purple = do not
    //! disturb, red = phone disconnected.
    function statusDots(dc as Graphics.Dc, centerX as Number, y as Number) as Void {
        var dots = [] as Array<Number>;
        if (Metrics.notifications() > 0) {
            dots.add(Theme.BODY);
        }
        if (Metrics.alarmSet()) {
            dots.add(Theme.STRESS);
        }
        if (Metrics.doNotDisturb()) {
            dots.add(Theme.FLOORS);
        }
        if (!Metrics.phoneConnected()) {
            dots.add(Theme.HR);
        }
        if (dots.size() == 0) {
            return;
        }
        var spacing = 20;
        var startX = centerX - (dots.size() - 1) * spacing / 2;
        for (var i = 0; i < dots.size(); i += 1) {
            dc.setColor(dots[i], Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(startX + i * spacing, y, 5);
        }
    }

    //! Small solid triangle, pointing up for sunrise and down for sunset.
    //! Cheaper and sharper at this size than carrying an icon bitmap.
    function caret(dc as Graphics.Dc, x as Number, y as Number, up as Boolean,
                   color as Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (up) {
            dc.fillPolygon([[x, y - 6], [x - 7, y + 5], [x + 7, y + 5]]);
        } else {
            dc.fillPolygon([[x, y + 6], [x - 7, y - 5], [x + 7, y - 5]]);
        }
    }

    //! Minute/hour/second ticks around an analog dial.
    function dialTicks(dc as Graphics.Dc, centerX as Number, centerY as Number,
                       radius as Number) as Void {
        for (var i = 0; i < 60; i += 1) {
            var isHour = i % 5 == 0;
            var radians = Math.toRadians(i * 6);
            var sin = Math.sin(radians);
            var cos = Math.cos(radians);
            var inner = isHour ? radius - 22 : radius - 9;
            dc.setPenWidth(isHour ? 4 : 2);
            dc.setColor(isHour ? Theme.TEXT : Theme.FAINT, Graphics.COLOR_TRANSPARENT);
            dc.drawLine(
                (centerX + inner * sin).toNumber(),
                (centerY - inner * cos).toNumber(),
                (centerX + radius * sin).toNumber(),
                (centerY - radius * cos).toNumber());
        }
    }

    //! Tapered clock hand, angle measured in degrees clockwise from 12 o'clock.
    function hand(dc as Graphics.Dc, centerX as Number, centerY as Number, degrees as Float,
                  length as Number, tail as Number, baseWidth as Number, tipWidth as Number,
                  color as Number) as Void {
        var radians = Math.toRadians(degrees);
        var sin = Math.sin(radians);
        var cos = Math.cos(radians);
        // Along the hand is (sin, -cos); across it is (cos, sin).
        var tipX = centerX + length * sin;
        var tipY = centerY - length * cos;
        var tailX = centerX - tail * sin;
        var tailY = centerY + tail * cos;
        var tipHalf = tipWidth / 2.0;
        var baseHalf = baseWidth / 2.0;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [(tipX + tipHalf * cos).toNumber(), (tipY + tipHalf * sin).toNumber()],
            [(tipX - tipHalf * cos).toNumber(), (tipY - tipHalf * sin).toNumber()],
            [(tailX - baseHalf * cos).toNumber(), (tailY - baseHalf * sin).toNumber()],
            [(tailX + baseHalf * cos).toNumber(), (tailY + baseHalf * sin).toNumber()]
        ]);
    }
}
