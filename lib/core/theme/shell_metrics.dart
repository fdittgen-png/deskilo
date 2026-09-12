// SPDX-License-Identifier: 0BSD

/// The app's toolbar height, everywhere — every `AppBar` through the
/// theme. Material's 56 dp spent a status-bar-height gap plus a tall
/// toolbar above the content of every screen; 48 dp keeps the touch
/// targets (an `IconButton` is 48 dp) and gives the row back. The same
/// figure Sparkilo settled on (its #4082) — the two apps share one shell
/// idiom: 48 dp toolbar, 64 dp raised bottom bar, text-only tab rows.
const double kAppToolbarHeight = 48;
