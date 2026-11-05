// SPDX-License-Identifier: AGPL-3.0-or-later
// #3235 — a tab hint is not a session, identity, consent or return route.

enum DemoReloadMarkerState { absent, armed, invalid, unavailable }

/// A cold start with a tab hint must not mount an inner live route. Explicit
/// Demo links keep their validated parameters; authentication callbacks stay
/// available to the existing callback and route guards.
///
/// Only a marker that was actually read counts: a tab whose storage cannot
/// be read starts normally — `arm` fails there, so no Demo visit can start in
/// it. Known limit: storage that becomes unreadable AFTER a successful `arm`
/// (a browser policy changed during the visit) also reads as no marker, and
/// that reload starts at the requested live screen. An invitation
/// continuation keeps its destination.
bool needsDemoReloadEntry(DemoReloadMarkerState state, Uri route) {
  if (state == DemoReloadMarkerState.absent ||
      state == DemoReloadMarkerState.unavailable) {
    return false;
  }
  if (route.path == '/demo') return false;
  if (route.path == '/onboarding' && route.queryParameters['join'] == '1') {
    return false;
  }
  if (route.path == '/auth') {
    if (route.queryParameters['demo'] == '1') return false;
    if (route.queryParameters.keys.any(
      const {
        'code',
        'error',
        'access_token',
        'refresh_token',
        'token_hash',
      }.contains,
    )) {
      return false;
    }
  }
  if (route.scheme == 'deskilo' && route.host == 'join') return false;
  return true;
}

/// A tab-local storage adapter. Implementations may throw when unavailable.
abstract interface class DemoReloadMarkerStorage {
  String? read();
  void write(String value);
  void clear();
}

/// A marker contains no fixture data, credentials, identity or destination.
class DemoReloadMarker {
  const DemoReloadMarker(this.storage);
  final DemoReloadMarkerStorage storage;
  static const _armed = 'demo-visit-v1';

  DemoReloadMarkerState read() {
    try {
      return switch (storage.read()) {
        null => DemoReloadMarkerState.absent,
        _armed => DemoReloadMarkerState.armed,
        _ => DemoReloadMarkerState.invalid,
      };
    } on Object {
      return DemoReloadMarkerState.unavailable;
    }
  }

  /// Fail closed if a visit cannot be marked for a future reload.
  bool arm() {
    try {
      storage.write(_armed);
      return read() == DemoReloadMarkerState.armed;
    } on Object {
      return false;
    }
  }

  /// Failure leaves the next start requiring the safe entry flow.
  bool clear() {
    try {
      storage.clear();
      return read() == DemoReloadMarkerState.absent;
    } on Object {
      return false;
    }
  }
}
