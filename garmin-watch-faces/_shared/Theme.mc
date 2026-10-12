import Toybox.Graphics;
import Toybox.Lang;

//! Palette.
//!
//! Hues are pushed toward primaries rather than the softer tones a modern UI
//! would use: the set is meant to read as an instrument panel, and saturated
//! colour on true black is what sells that. True black also costs nothing on
//! an AMOLED panel, because those pixels are simply off.
module Theme {
    const BG        = 0x000000;
    const TEXT      = 0xFFFFFF;
    const DIM       = 0x889099;  // captions, secondary text
    const FAINT     = 0x3A4450;  // grids, rules, inactive ticks
    const TRACK     = 0x1E2430;  // unlit segment of a bar or meter
    const SCANLINE  = 0x0C1016;  // CRT raster, barely above black
    const SHADOW    = 0x0A0E14;  // drop shadow behind large type

    const HR        = 0xFF3333;  // heart rate
    const BODY      = 0x33CCFF;  // body battery
    const STEPS     = 0x44DD44;  // steps
    const CALORIES  = 0xFF8800;  // calories
    const FLOORS    = 0xAA66FF;  // floors climbed
    const INTENSITY = 0xFF44AA;  // intensity minutes
    const STRESS    = 0xFFCC00;  // stress, alarms, daylight
    const WEATHER   = 0xFFFFFF;  // temperature

    // Attitude-indicator tints, kept dark so the ladder orients without
    // competing with the readouts.
    const SKY    = 0x2E5A78;
    const GROUND = 0x785A2E;

    const BATT_OK  = 0x889099;
    const BATT_LOW = 0xFF3333;
    const BATT_LOW_PCT = 20;

    //! Scale a packed RGB colour's channels. Under 100 darkens, over 100
    //! lightens, both clamped. Used for the bevel on every lit segment -
    //! light along the top edge, dark along the bottom, which is what makes
    //! a flat block read as a raised one.
    function shade(color as Number, percent as Number) as Number {
        var red = ((color >> 16) & 0xFF) * percent / 100;
        var green = ((color >> 8) & 0xFF) * percent / 100;
        var blue = (color & 0xFF) * percent / 100;
        if (red > 255) { red = 255; }
        if (green > 255) { green = 255; }
        if (blue > 255) { blue = 255; }
        return (red << 16) | (green << 8) | blue;
    }

    function battery(pct as Number) as Number {
        return pct <= BATT_LOW_PCT ? BATT_LOW : BATT_OK;
    }
}
