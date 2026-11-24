// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4373 (CS11) -- what the till knows about selling offline: the kit it is given (the device's queue, the server's port, the currency
// and the clock), what it shows (offline or not, how many sales wait, the sale just recorded, the answer of the last send) and the
// ways it says no (a line it holds no price for). The logic is `till_session_offline.dart`; the words are in `till_text.dart`.
import 'package:flutter/foundation.dart';

import '../../../core/failure/app_failure.dart' show TypedRefusal;

import '../domain/till_offline.dart';
import '../domain/till_offline_queue.dart';

/// Everything a till session needs to go on selling for cash when the connection is lost.
class TillOfflineKit {
  const TillOfflineKit({
    required this.queue,
    required this.port,
    required this.currency,
    required this.minorDigits,
    required this.now,
    this.reconnectEvery = kOfflineReconnectEvery,
  });

  final TillOfflineQueue queue;
  final TillOfflinePort port;
  final String currency;
  final int minorDigits;
  final DateTime Function() now;

  /// How often an offline till looks for its connection again (nothing a business sets: a technical interval).
  final Duration reconnectEvery;
}

/// A line the till has no price for on the device: nothing is guessed, the basket is not sold offline.
class TillOfflineNoPrice implements TypedRefusal {
  const TillOfflineNoPrice();
}

/// What came of sending the sales that waited: how many the server took, the ones it refused with their reason, the numbers it
/// finds missing, and the error of a send the server refused as a whole (a closed session): its sales stay on the device.
@immutable
class OfflineReport {
  const OfflineReport({required this.accepted, required this.refused, required this.gaps, this.failure, this.kept = 0});

  final int accepted;
  final List<OfflineSaleResult> refused;
  final List<int> gaps;
  final Object? failure;

  /// How many sales stay on the device after the send.
  final int kept;

  bool get clean => refused.isEmpty && gaps.isEmpty && failure == null && kept == 0;
}

/// What the till shows of its offline state.
@immutable
class TillOfflineStatus {
  const TillOfflineStatus({this.active = false, this.waiting = 0, this.sale, this.report, this.unreadable = false, this.syncing = false});

  /// The till is selling offline: cash only, at the prices it held.
  final bool active;

  /// How many sales wait on the device to be sent.
  final int waiting;

  /// The sale just recorded offline: its device number is what the receipt carries.
  final OfflineSale? sale;

  /// The answer of the last send, until it is dismissed.
  final OfflineReport? report;

  /// The offline state on the device could not be read: nothing is sold offline until someone decides.
  final bool unreadable;
  final bool syncing;

  TillOfflineStatus copyWith({
    bool? active,
    int? waiting,
    OfflineSale? Function()? sale,
    OfflineReport? Function()? report,
    bool? unreadable,
    bool? syncing,
  }) => TillOfflineStatus(
    active: active ?? this.active,
    waiting: waiting ?? this.waiting,
    sale: sale == null ? this.sale : sale(),
    report: report == null ? this.report : report(),
    unreadable: unreadable ?? this.unreadable,
    syncing: syncing ?? this.syncing,
  );
}
