// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'prefs_stores.dart';

part 'booking_intent_store.g.dart';

/// #1855 — the bookings this device confirmed and has not yet seen
/// settled, as the JSON `BookingIntentLedger` writes: one string key, a
/// bounded list, each entry scoped to the account and server it was made
/// on. Never a token, never a name — ids, instants and a request id.
/// Widget tests and the Demo session swap in the in-memory store.
abstract class BookingIntentStore {
  Future<String?> read();
  Future<void> write(String? ledger);
}

class PrefsBookingIntentStore extends PrefsStringStore
    implements BookingIntentStore {
  const PrefsBookingIntentStore() : super('booking_intents_v1');
}

/// Test double and Demo copy. [writes] counts every write; [failWrites]
/// makes the device refuse to persist, which a safe send must notice.
class InMemoryBookingIntentStore implements BookingIntentStore {
  InMemoryBookingIntentStore([this.value]);

  String? value;
  int writes = 0;
  bool failWrites = false;
  bool failReads = false;

  /// Writes beyond this many fail: the save before a send succeeds, the
  /// bookkeeping after the answer does not.
  int? failWritesAfter;

  @override
  Future<String?> read() async {
    if (failReads) throw StateError('booking intent store unavailable');
    return value;
  }

  @override
  Future<void> write(String? ledger) async {
    writes++;
    if (failWrites || (failWritesAfter != null && writes > failWritesAfter!)) {
      throw StateError('booking intent store unavailable');
    }
    value = ledger;
  }
}

@Riverpod(keepAlive: true)
BookingIntentStore bookingIntentStore(Ref ref) =>
    const PrefsBookingIntentStore();
