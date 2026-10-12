import Toybox.Activity;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

//! Sunrise and sunset times.
//!
//! Connect IQ has no sunrise API, so this is the standard sunrise equation
//! worked out locally. The position comes from the last weather observation,
//! which the phone refreshes without ever waking the GPS; if the watch has
//! never seen weather data the fields simply read "--:--".
//!
//! The result is cached per calendar day - this is far too much arithmetic to
//! redo on every redraw.
module Solar {

    const UNKNOWN = "--:--";

    var mCachedDate as Number = -1;
    var mSunrise as Number? = null;
    var mSunset as Number? = null;

    function sunriseText() as String {
        refresh();
        return formatMinutes(mSunrise);
    }

    function sunsetText() as String {
        refresh();
        return formatMinutes(mSunset);
    }

    function sunriseMinutes() as Number? {
        refresh();
        return mSunrise;
    }

    function sunsetMinutes() as Number? {
        refresh();
        return mSunset;
    }

    function nowMinutes() as Number {
        var clock = System.getClockTime();
        return clock.hour * 60 + clock.min;
    }

    //! Rough sun height: +1 at solar noon, 0 at sunrise and sunset, -1 in the
    //! middle of the night. A sine between the known crossings rather than a
    //! real elevation calculation - accurate enough to drive a horizon, and a
    //! fraction of the arithmetic. Null when the sun times are unknown.
    function altitudeFraction() as Float? {
        refresh();
        if (mSunrise == null || mSunset == null || mSunset <= mSunrise) {
            return null;
        }
        var now = nowMinutes();
        if (now >= mSunrise && now <= mSunset) {
            var dayProgress = (now - mSunrise).toFloat() / (mSunset - mSunrise).toFloat();
            return Math.sin(Math.PI * dayProgress).toFloat();
        }
        // Night wraps midnight, so measure forward from sunset.
        var nightLength = 1440 - (mSunset - mSunrise);
        var sinceSunset = now > mSunset ? now - mSunset : now + 1440 - mSunset;
        return -Math.sin(Math.PI * sinceSunset.toFloat() / nightLength.toFloat()).toFloat();
    }

    function refresh() as Void {
        var utc = Gregorian.utcInfo(Time.now(), Time.FORMAT_SHORT);
        var dateKey = utc.year * 10000 + utc.month * 100 + utc.day;
        if (dateKey == mCachedDate) {
            return;
        }
        var location = position();
        if (location == null) {
            // No fix yet. Leave the cache alone and try again on the next
            // redraw, keeping yesterday's times if we have them - they are
            // within a couple of minutes and that beats flickering to "--:--".
            return;
        }
        mCachedDate = dateKey;
        compute(utc.year, utc.month, utc.day, location[0], location[1]);
    }

    function compute(year as Number, month as Number, day as Number,
                     latitude as Double, longitude as Double) as Void {
        var julian = julianDayNumber(year, month, day) - 2451545.0 + 0.0008;
        // The textbook equation is written in degrees west of Greenwich.
        var meanSolarTime = julian - (-longitude) / 360.0;

        var anomaly = wrap360(357.5291 + 0.98560028 * meanSolarTime);
        var anomalyRad = Math.toRadians(anomaly);
        var center = 1.9148 * Math.sin(anomalyRad)
                   + 0.0200 * Math.sin(2.0 * anomalyRad)
                   + 0.0003 * Math.sin(3.0 * anomalyRad);
        // Ecliptic longitude = M + C + 180 + 102.9372.
        var eclipticRad = Math.toRadians(wrap360(anomaly + center + 282.9372));

        var transit = 2451545.0 + meanSolarTime
                    + 0.0053 * Math.sin(anomalyRad)
                    - 0.0069 * Math.sin(2.0 * eclipticRad);

        var declination = Math.asin(Math.sin(eclipticRad) * Math.sin(Math.toRadians(23.4397)));
        var latitudeRad = Math.toRadians(latitude);
        var denominator = Math.cos(latitudeRad) * Math.cos(declination);
        if (denominator == 0.0) {
            clear();
            return;
        }
        // -0.833 degrees accounts for refraction and the sun's own radius.
        var cosHourAngle = (Math.sin(Math.toRadians(-0.833))
                          - Math.sin(latitudeRad) * Math.sin(declination)) / denominator;
        if (cosHourAngle > 1.0 || cosHourAngle < -1.0) {
            // Polar day or polar night - the sun never crosses the horizon.
            clear();
            return;
        }
        var hourAngle = Math.toDegrees(Math.acos(cosHourAngle));

        mSunrise = localMinutes(transit - hourAngle / 360.0);
        mSunset = localMinutes(transit + hourAngle / 360.0);
    }

    function julianDayNumber(year as Number, month as Number, day as Number) as Double {
        // Integer arithmetic throughout - these are all Numbers, so "/" floors.
        var a = (14 - month) / 12;
        var y = year + 4800 - a;
        var m = month + 12 * a - 3;
        var jdn = day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045;
        return jdn.toDouble();
    }

    //! Julian date -> minutes past local midnight.
    function localMinutes(julianDate as Double) as Number {
        // Julian days begin at noon, so shifting by half a day gives the
        // fraction elapsed since UTC midnight.
        var shifted = julianDate + 0.5;
        var dayFraction = shifted - Math.floor(shifted);
        var minutes = dayFraction * 1440.0 + System.getClockTime().timeZoneOffset / 60.0;
        var wrapped = minutes.toNumber() % 1440;
        if (wrapped < 0) {
            wrapped += 1440;
        }
        return wrapped;
    }

    function formatMinutes(minutes as Number?) as String {
        if (minutes == null) {
            return UNKNOWN;
        }
        var hour = minutes / 60;
        var minute = minutes % 60;
        if (Metrics.is24Hour()) {
            // Zero-padded, so a sunrise row lines up with the clock above it.
            return Lang.format("$1$:$2$", [hour.format("%02d"), minute.format("%02d")]);
        }
        hour = hour % 12;
        if (hour == 0) {
            hour = 12;
        }
        return Lang.format("$1$:$2$", [hour.format("%d"), minute.format("%02d")]);
    }

    function position() as Array<Double>? {
        if (Toybox has :Weather) {
            var conditions = Weather.getCurrentConditions();
            if (conditions != null && (conditions has :observationLocationPosition)
                    && conditions.observationLocationPosition != null) {
                return conditions.observationLocationPosition.toDegrees();
            }
        }
        var activity = Activity.getActivityInfo();
        if (activity != null && activity.currentLocation != null) {
            return activity.currentLocation.toDegrees();
        }
        return null;
    }

    function wrap360(value as Double) as Double {
        return value - 360.0 * Math.floor(value / 360.0);
    }

    function clear() as Void {
        mSunrise = null;
        mSunset = null;
    }
}
