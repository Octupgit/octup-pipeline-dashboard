import Toybox.Lang;

//! One dial geometry shared by all four faces.
//!
//! The Venu X1 panel is 448 x 486 and square-cornered, so a circle is a design
//! choice rather than the shape of the hardware. Committing to it means every
//! face is composed inside the same circle, with matching unused bands above
//! and below; on an AMOLED panel those bands are simply off pixels.
module Layout {
    const WIDTH  = 448;
    const HEIGHT = 486;

    const CENTER_X = 224;
    const CENTER_Y = 243;

    //! Largest circle the panel holds, less a small margin.
    const OUTER_R = 206;
}
