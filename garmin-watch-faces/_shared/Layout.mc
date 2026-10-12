import Toybox.Lang;

//! The panel, as it actually is: a square-cornered 448 x 486 rectangle.
//!
//! An earlier revision of these faces composed everything inside a circle.
//! That was wrong for this watch - the Venu X1 is Garmin's rectangular
//! model - and it cost a 37 px dead band top and bottom. Layouts now use the
//! whole panel.
module Layout {
    const WIDTH  = 448;
    const HEIGHT = 486;

    const CENTER_X = 224;
    const CENTER_Y = 243;

    //! Safe inset from the glass edge.
    const MARGIN = 22;
    const LEFT   = MARGIN;
    const RIGHT  = WIDTH - MARGIN;
    const TOP    = MARGIN;
    const BOTTOM = HEIGHT - MARGIN;

    const INNER_W = RIGHT - LEFT;
}
