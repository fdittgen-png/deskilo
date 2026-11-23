// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3726 (K1) — the app's compatibility number and how an installation's
// floor judges it (ADR 0053, section 1).
//
// Pure Dart: the app, the doctor and the CLI judge with the same arithmetic.

/// This app's compatibility number: one integer, independent of the schema
/// number, raised by a release that an installation may need to require.
///
/// An app from before the number existed counts as the lowest. The number is
/// a courtesy for apps that know the floor, not a credential: an old contract
/// is ended by the server (ADR 0053).
const int appCompatibilityNumber = 1;

/// What an installation's floor says about this app.
enum AppFloorVerdict {
  /// No floor, or this app is at or above it.
  accepted,

  /// The installation accepts only newer apps: this one must be updated.
  below,

  /// The floor was never read: offline, a timeout. Never blocks.
  unknown,
}

/// Judges [floor] — the installation's answer, or null for "no floor" —
/// against [app].
AppFloorVerdict judgeAppFloor(int? floor, {int app = appCompatibilityNumber}) =>
    floor == null || app >= floor
    ? AppFloorVerdict.accepted
    : AppFloorVerdict.below;
