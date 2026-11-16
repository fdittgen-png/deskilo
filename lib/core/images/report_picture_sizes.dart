// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3984 — the sizes a report picture is stored at, and why.
//
// A picture in a document prints at most 182 mm across (the printable width
// of the widest sheet) and at 300 dpi that is about 2150 pixels. The PDF
// writer embeds a JPEG as it is but unpacks a PNG or a WebP to raw pixels at
// their full pixel size, so a picture stored larger than it prints only adds
// weight: two 4000 x 3000 pictures made a 26 MB invoice.

/// The longest edge, in pixels, of a picture without transparency: 300 dpi
/// across the widest printable width (182 mm), rounded up. Never enlarged.
const int reportPictureMaxEdge = 2200;

/// The longest edge of a picture that uses transparency. It stays a PNG, which
/// the PDF writer unpacks to raw pixels (four bytes each), so it is kept to a
/// stamp or a logo's size: 1200 x 900 px is 4 MB of pixels, not 48 MB.
const int reportPictureMaxEdgeTransparent = 1200;

/// The heaviest a stored picture may be: 500 KiB. A header and a footer
/// picture then add up to about 1 MB, far below the 5 MiB an invoice's kept
/// original may weigh.
const int reportPictureMaxBytes = 500 * 1024;

/// The first JPEG quality: visually lossless at print size.
const int reportPictureJpegQuality = 85;

/// The lowest JPEG quality tried before the picture is scaled down instead.
const int reportPictureJpegQualityFloor = 65;

/// How much the quality drops at each try while the picture is too heavy.
const int reportPictureJpegQualityStep = 5;

/// Each scaling step keeps this share of the edge (85 %): small enough to
/// converge in a few steps, large enough to lose no more than needed.
const double reportPictureScaleStep = 0.85;

/// A picture is never scaled below this edge: past it a picture is not a
/// picture any more, and even a noisy one of this size is a few tens of KiB.
const int reportPictureMinEdge = 200;
