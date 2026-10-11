import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Lang;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Weather;

//! Every reader here returns null (or "--") rather than throwing when the
//! metric is unavailable: no phone paired, sensor still warming up, the
//! simulator with no fake data loaded. Watch faces are redrawn constantly, so
//! one unguarded null is a face that shows nothing at all.
module Metrics {

    const NO_VALUE = "--";

    // ---------------------------------------------------------------- clock

    //! Hours already converted to the watch's 12/24h setting.
    function hours() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var hour = info.hour;
        if (System.getDeviceSettings().is24Hour) {
            return hour.format("%02d");
        }
        hour = hour % 12;
        if (hour == 0) {
            hour = 12;
        }
        return hour.format("%d");
    }

    function minutes() as String {
        return Gregorian.info(Time.now(), Time.FORMAT_SHORT).min.format("%02d");
    }

    function seconds() as Number {
        return Gregorian.info(Time.now(), Time.FORMAT_SHORT).sec;
    }

    //! "SAT 11 OCT"
    function dateLine() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        return Lang.format("$1$ $2$ $3$", [
            info.day_of_week.toUpper(),
            info.day.format("%d"),
            info.month.toUpper()
        ]);
    }

    //! True when the watch is in 24h mode - layouts need the extra digit width.
    function is24Hour() as Boolean {
        return System.getDeviceSettings().is24Hour;
    }

    // ------------------------------------------------------------- activity

    function steps() as Number? {
        var info = ActivityMonitor.getInfo();
        return info == null ? null : info.steps;
    }

    function stepGoal() as Number? {
        var info = ActivityMonitor.getInfo();
        if (info == null || info.stepGoal == null || info.stepGoal <= 0) {
            return null;
        }
        return info.stepGoal;
    }

    function calories() as Number? {
        var info = ActivityMonitor.getInfo();
        return info == null ? null : info.calories;
    }

    function floors() as Number? {
        var info = ActivityMonitor.getInfo();
        if (info == null || !(info has :floorsClimbed)) {
            return null;
        }
        return info.floorsClimbed;
    }

    function floorGoal() as Number? {
        var info = ActivityMonitor.getInfo();
        if (info == null || !(info has :floorsClimbedGoal) || info.floorsClimbedGoal == null
                || info.floorsClimbedGoal <= 0) {
            return null;
        }
        return info.floorsClimbedGoal;
    }

    //! Intensity minutes for the week, which is how Garmin scores the 150/week
    //! guideline - the daily number is too noisy to be worth a slot.
    function intensityMinutes() as Number? {
        var info = ActivityMonitor.getInfo();
        if (info == null || !(info has :activeMinutesWeek) || info.activeMinutesWeek == null) {
            return null;
        }
        return info.activeMinutesWeek.total;
    }

    function intensityGoal() as Number? {
        var info = ActivityMonitor.getInfo();
        if (info == null || !(info has :activeMinutesWeekGoal)
                || info.activeMinutesWeekGoal == null || info.activeMinutesWeekGoal <= 0) {
            return null;
        }
        return info.activeMinutesWeekGoal;
    }

    //! 0 (sitting is fine) to 5 (move now).
    function moveBar() as Number {
        var info = ActivityMonitor.getInfo();
        if (info == null || info.moveBarLevel == null) {
            return 0;
        }
        return info.moveBarLevel;
    }

    // -------------------------------------------------------------- sensors

    function heartRate() as Number? {
        // The live reading is fresher, but it is only populated while the
        // optical sensor is actually sampling.
        var activity = Activity.getActivityInfo();
        if (activity != null && activity.currentHeartRate != null) {
            return activity.currentHeartRate;
        }
        if (!(ActivityMonitor has :getHeartRateHistory)) {
            return null;
        }
        var iterator = ActivityMonitor.getHeartRateHistory(1, true);
        if (iterator == null) {
            return null;
        }
        var sample = iterator.next();
        if (sample == null || sample.heartRate == null
                || sample.heartRate == ActivityMonitor.INVALID_HR_SAMPLE) {
            return null;
        }
        return sample.heartRate;
    }

    function bodyBattery() as Number? {
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getBodyBatteryHistory)) {
            return null;
        }
        return newestSample(SensorHistory.getBodyBatteryHistory({
            :period => 1,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        }));
    }

    function stress() as Number? {
        if (!(Toybox has :SensorHistory) || !(SensorHistory has :getStressHistory)) {
            return null;
        }
        return newestSample(SensorHistory.getStressHistory({
            :period => 1,
            :order => SensorHistory.ORDER_NEWEST_FIRST
        }));
    }

    function newestSample(iterator as SensorHistory.SensorHistoryIterator?) as Number? {
        if (iterator == null) {
            return null;
        }
        var sample = iterator.next();
        if (sample == null || sample.data == null) {
            return null;
        }
        return sample.data.toNumber();
    }

    // -------------------------------------------------------------- weather

    //! Temperature in the watch's own unit, e.g. "18 degrees" -> "18".
    function temperature() as String {
        var conditions = currentConditions();
        if (conditions == null || conditions.temperature == null) {
            return NO_VALUE;
        }
        var celsius = conditions.temperature.toFloat();
        if (System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE) {
            return (celsius * 9.0 / 5.0 + 32.0).toNumber().format("%d");
        }
        return celsius.toNumber().format("%d");
    }

    //! Today's forecast range, e.g. "12/21". Empty when the phone has not synced.
    function highLow() as String {
        var conditions = currentConditions();
        if (conditions == null || !(conditions has :highTemperature)
                || conditions.highTemperature == null || conditions.lowTemperature == null) {
            return "";
        }
        var statute = System.getDeviceSettings().temperatureUnits == System.UNIT_STATUTE;
        return Lang.format("$1$/$2$", [
            scaleTemp(conditions.lowTemperature, statute),
            scaleTemp(conditions.highTemperature, statute)
        ]);
    }

    function scaleTemp(celsius as Numeric, statute as Boolean) as String {
        var value = celsius.toFloat();
        if (statute) {
            value = value * 9.0 / 5.0 + 32.0;
        }
        return value.toNumber().format("%d");
    }

    //! Short condition word. Deliberately a small set - the full enum is ~50
    //! values and most of them never show up in one city.
    function conditionWord() as String {
        var conditions = currentConditions();
        if (conditions == null || conditions.condition == null) {
            return "";
        }
        switch (conditions.condition) {
            case Weather.CONDITION_CLEAR:
            case Weather.CONDITION_FAIR:
                return "CLEAR";
            case Weather.CONDITION_PARTLY_CLOUDY:
            case Weather.CONDITION_MOSTLY_CLEAR:
            case Weather.CONDITION_THIN_CLOUDS:
                return "PART CLOUD";
            case Weather.CONDITION_CLOUDY:
            case Weather.CONDITION_MOSTLY_CLOUDY:
                return "CLOUDY";
            case Weather.CONDITION_RAIN:
            case Weather.CONDITION_SHOWERS:
            case Weather.CONDITION_SCATTERED_SHOWERS:
            case Weather.CONDITION_HEAVY_RAIN:
                return "RAIN";
            case Weather.CONDITION_LIGHT_RAIN:
            case Weather.CONDITION_DRIZZLE:
                return "DRIZZLE";
            case Weather.CONDITION_SNOW:
            case Weather.CONDITION_LIGHT_SNOW:
            case Weather.CONDITION_HEAVY_SNOW:
                return "SNOW";
            case Weather.CONDITION_THUNDERSTORMS:
            case Weather.CONDITION_SCATTERED_THUNDERSTORMS:
                return "STORMS";
            case Weather.CONDITION_FOG:
            case Weather.CONDITION_MIST:
            case Weather.CONDITION_HAZY:
                return "FOG";
            case Weather.CONDITION_WINDY:
                return "WINDY";
            default:
                return "";
        }
    }

    function currentConditions() as Weather.CurrentConditions? {
        if (!(Toybox has :Weather)) {
            return null;
        }
        return Weather.getCurrentConditions();
    }

    // --------------------------------------------------------------- system

    function batteryPercent() as Number {
        return System.getSystemStats().battery.toNumber();
    }

    function notifications() as Number {
        var settings = System.getDeviceSettings();
        return settings.notificationCount == null ? 0 : settings.notificationCount;
    }

    function phoneConnected() as Boolean {
        return System.getDeviceSettings().phoneConnected;
    }

    function doNotDisturb() as Boolean {
        var settings = System.getDeviceSettings();
        if (!(settings has :doNotDisturb) || settings.doNotDisturb == null) {
            return false;
        }
        return settings.doNotDisturb;
    }

    function alarmSet() as Boolean {
        var settings = System.getDeviceSettings();
        return settings.alarmCount != null && settings.alarmCount > 0;
    }

    // ----------------------------------------------------------- formatting

    function text(value as Number?) as String {
        return value == null ? NO_VALUE : value.format("%d");
    }

    //! 8420 -> "8.4k", so a five-digit step count never overflows its cell.
    function compact(value as Number?) as String {
        if (value == null) {
            return NO_VALUE;
        }
        if (value < 10000) {
            return value.format("%d");
        }
        return (value / 1000.0).format("%.1f") + "k";
    }

    //! Fraction of a goal, clamped to 0..1. Null goal or value means no bar.
    function ratio(value as Number?, goal as Number?) as Float {
        if (value == null || goal == null || goal <= 0) {
            return 0.0;
        }
        var fraction = value.toFloat() / goal.toFloat();
        if (fraction < 0.0) { return 0.0; }
        if (fraction > 1.0) { return 1.0; }
        return fraction;
    }
}
