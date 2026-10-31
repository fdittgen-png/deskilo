// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3102 (PERF-9) — a booking made on this device refreshes its providers at
// once (`invalidateBookingData`), and the realtime echo of the same write
// arrives a debounce later and refreshed them all again. The ledger
// remembers what this device just refreshed itself, so the echo skips
// those providers for [AppDurations.ownEchoWindow]. A resync is never
// skipped.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../time/clock.dart';
import '../ui/app_durations.dart';

class OwnRefreshLedger {
  OwnRefreshLedger(this._clock);

  final Clock _clock;
  final _refreshedAt = <ProviderOrFamily, DateTime>{};

  /// [providers] were just refreshed by this device's own write.
  void mark(Iterable<ProviderOrFamily> providers) {
    final now = _clock.now();
    for (final p in providers) {
      _refreshedAt[p] = now;
    }
  }

  /// Whether [provider] was refreshed by this device within the window, so
  /// an echo of the same write would only fetch it twice.
  bool isFresh(ProviderOrFamily provider) {
    final at = _refreshedAt[provider];
    if (at == null) return false;
    if (_clock.now().difference(at) < AppDurations.ownEchoWindow) return true;
    _refreshedAt.remove(provider);
    return false;
  }
}

final ownRefreshLedgerProvider = Provider<OwnRefreshLedger>(
  (ref) => OwnRefreshLedger(ref.watch(clockProvider)),
);
