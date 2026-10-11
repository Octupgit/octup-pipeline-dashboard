import Toybox.Graphics;
import Toybox.Lang;

//! Single palette shared by all four faces.
//!
//! Metrics are colour-coded so a dense face can be parsed without reading the
//! labels: once you learn "red = heart, blue = body battery, green = steps",
//! the numbers stop needing captions. The background is true black because the
//! Venu X1 is AMOLED - black pixels are simply off, which costs no battery.
module Theme {
    const BG        = 0x000000;
    const TEXT      = 0xFFFFFF;
    const DIM       = 0x8A8F98;  // labels, secondary text
    const FAINT     = 0x4A4F57;  // dial ticks, hairlines
    const TRACK     = 0x23272C;  // unfilled portion of a gauge

    const HR        = 0xFF4D4F;  // heart rate
    const BODY      = 0x5AC8FA;  // body battery
    const STEPS     = 0x4CD964;  // steps
    const CALORIES  = 0xFF7A45;  // calories
    const FLOORS    = 0xB18CFF;  // floors climbed
    const INTENSITY = 0xFF5CA8;  // intensity minutes
    const STRESS    = 0xFFB020;  // stress
    const WEATHER   = 0xE8EAED;  // temperature

    const BATT_OK   = 0x8A8F98;
    const BATT_LOW  = 0xFF4D4F;  // below BATT_LOW_PCT
    const BATT_LOW_PCT = 20;

    //! Battery colour, red once it is worth doing something about.
    function battery(pct as Number) as Number {
        return pct <= BATT_LOW_PCT ? BATT_LOW : BATT_OK;
    }
}
