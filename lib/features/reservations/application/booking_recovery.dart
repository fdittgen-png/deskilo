// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1855 — the interrupted booking, recovered from its original intent.
//
// `create_reservation_once` made a retry WITHIN one call safe (#1241): the
// request id lives outside the retried closure. It did nothing for the
// call that never returned — a lift, a restart, a tab the browser threw
// away. The member then had an intent the server may or may not have
// honoured, and the only thing the app offered was booking again.
//
// This command keeps the intent, durably and before the send, and makes
// the three honest answers reachable: KNOWN COMMIT (the booking, opened),
// KNOWN REFUSAL (the server's words, the input kept) and UNKNOWN (checked
// against the server by the original id, or resumed with the original
// payload — never a new request, never the workspace selected since).
//
// What it deliberately does not do: queue, resend on its own, or decide
// that a lost answer meant "no". A ledger entry is a question the member
// still has, and only the server answers it.
import 'dart:async';

import '../../../core/ids/request_id.dart';
import '../../../core/storage/booking_intent_store.dart';
import '../../../core/time/clock.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/booking_intent.dart';
import '../domain/reservation_repository.dart';
import 'book_seat.dart';

/// The device could not keep the intent, so nothing was sent: an
/// unprotected mutation is worse than no mutation.
final class BookingIntentNotSaved implements Exception {
  const BookingIntentNotSaved(this.cause);
  final Object cause;

  @override
  String toString() => 'BookingIntentNotSaved($cause)';
}

/// The request left the device and its answer did not come back. The
/// intent is kept; [intent] is what the member can check or resume.
final class BookingOutcomeUnknown implements Exception {
  const BookingOutcomeUnknown(this.intent, this.cause);
  final BookingIntent intent;
  final Object cause;

  @override
  String toString() => 'BookingOutcomeUnknown(${intent.requestId}: $cause)';
}

/// What a check of an open intent found.
sealed class RecoveryCheck {
  const RecoveryCheck(this.intent);
  final BookingIntent intent;
}

/// The server committed it: here is the booking. The ledger entry is
/// settled.
final class RecoveryCommitted extends RecoveryCheck {
  const RecoveryCommitted(super.intent, this.reservationId);
  final String reservationId;
}

/// The server is still working on it (a concurrent attempt holds the
/// claim). Ask again in a moment.
final class RecoveryInProgress extends RecoveryCheck {
  const RecoveryInProgress(super.intent);
}

/// The server has no claim for it and the intent is young enough that
/// it would: nothing was booked. Resume is safe; so is letting it go.
final class RecoveryNotCommitted extends RecoveryCheck {
  const RecoveryNotCommitted(super.intent);
}

/// The server has no claim and the intent is older than the server keeps
/// claims: absence proves nothing. The member resolves it by looking at
/// their bookings, not by resuming.
final class RecoveryUnresolved extends RecoveryCheck {
  const RecoveryUnresolved(super.intent);
}

/// The server could not be asked. The intent stays as it was.
final class RecoveryUnavailable extends RecoveryCheck {
  const RecoveryUnavailable(super.intent);
}

class BookingRecovery {
  const BookingRecovery({
    required ReservationRepository reservations,
    required BookingIntentStore store,
    required BookingIntentScope scope,
    required Clock clock,
    required int schemaVersion,
  }) : this._(reservations, store, scope, clock, schemaVersion);

  const BookingRecovery._(
    this._reservations,
    this._store,
    this._scope,
    this._clock,
    this._schemaVersion,
  );

  final ReservationRepository _reservations;
  final BookingIntentStore _store;
  final BookingIntentScope _scope;
  final Clock _clock;
  final int _schemaVersion;

  /// An intent still pending after this long was interrupted before or
  /// during its send (the app died): it reads as unknown, not as sending.
  static const Duration pendingGrace = Duration(seconds: 30);

  Future<BookingIntentLedger> _ledger() async =>
      BookingIntentLedger.decode(await _store.read());

  Future<void> _write(BookingIntentLedger ledger) =>
      _store.write(ledger.intents.isEmpty ? null : ledger.encode());

  /// Best effort after the server has spoken: a bookkeeping failure is
  /// traced and never turns a known answer into another one.
  Future<void> _settle(String what, Future<void> Function() change) async {
    try {
      await change();
    } catch (e, st) {
      TraceLogger.instance.warn(
        'reservations',
        'booking intent ledger: $what failed; the server\'s answer stands',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Books [request] for the member with a durable intent. The intent is
  /// saved BEFORE the send (a save failure sends nothing), carries the one
  /// request id every attempt uses, and is settled by the server's answer.
  Future<Booked> book(BookingRequest request) async {
    final requestId = newRequestId();
    final intent = BookingIntent(
      requestId: requestId,
      scope: _scope,
      workspaceId: request.workspaceId,
      seatId: request.seatId,
      // The confirmed instants as given (a workspace-zoned time stays one);
      // the ledger writes them as UTC, the server compares epochs.
      startsAt: request.start,
      endsAt: request.end,
      checkIn: request.checkIn,
      schemaVersion: _schemaVersion,
      createdAt: _clock.now().toUtc(),
    );
    try {
      await _write((await _ledger()).upsert(intent));
    } catch (e, st) {
      TraceLogger.instance.warn(
        'reservations',
        'booking intent could not be saved; nothing was sent',
        error: e,
        stackTrace: st,
      );
      throw BookingIntentNotSaved(e);
    }
    return _send(intent);
  }

  /// Sends [intent] exactly as it was confirmed: same id, same payload,
  /// same server. A recovery after a lost answer calls this again.
  Future<Booked> _send(BookingIntent intent) async {
    final String reservationId;
    try {
      reservationId = await _reservations.create(
        workspaceId: intent.workspaceId,
        seatId: intent.seatId,
        deskId: intent.deskId,
        officeId: intent.officeId,
        levelId: intent.levelId,
        startsAt: intent.startsAt,
        endsAt: intent.endsAt,
        checkIn: intent.checkIn,
        requestId: intent.requestId,
      );
    } catch (e, st) {
      if (e is TimeoutException || isTransientNetworkFailure(e)) {
        // The request may have reached the server: the intent stays open.
        await _settle(
          'mark unknown',
          () async => _write(
            (await _ledger()).upsert(
              intent.copyWith(status: BookingIntentStatus.unknown),
            ),
          ),
        );
        throw BookingOutcomeUnknown(intent, e);
      }
      // A refusal is an answer: the server booked nothing, and says why.
      TraceLogger.instance.warn(
        'reservations',
        'booking refused; intent ${intent.requestId} closed',
        error: e,
        stackTrace: st,
      );
      await _settle(
        'close refused',
        () async => _write((await _ledger()).remove(intent.requestId)),
      );
      rethrow;
    }
    await _settle(
      'close committed',
      () async => _write((await _ledger()).remove(intent.requestId)),
    );
    return Booked(
      reservationId: reservationId,
      start: intent.startsAt,
      end: intent.endsAt,
      checkedIn: intent.checkIn,
    );
  }

  /// The open intents of this account on this server, oldest first; a
  /// pending one older than [pendingGrace] is reported as unknown.
  Future<List<BookingIntent>> unresolved({String? workspaceId}) async {
    final now = _clock.now().toUtc();
    final open = (await _ledger()).unresolvedFor(
      _scope,
      workspaceId: workspaceId,
    );
    open.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [
      for (final i in open)
        if (i.status == BookingIntentStatus.pending &&
            now.difference(i.createdAt) > pendingGrace)
          i.copyWith(status: BookingIntentStatus.unknown)
        else
          i,
    ];
  }

  /// Asks the server what became of [intent], by its original id.
  Future<RecoveryCheck> check(BookingIntent intent) async {
    if (intent.scope != _scope) return RecoveryUnavailable(intent);
    final RequestOutcome outcome;
    try {
      outcome = await _reservations.requestOutcome(
        intent.workspaceId,
        intent.requestId,
      );
    } catch (e, st) {
      TraceLogger.instance.warn(
        'reservations',
        'booking intent ${intent.requestId}: outcome lookup failed',
        error: e,
        stackTrace: st,
      );
      return RecoveryUnavailable(intent);
    }
    final now = _clock.now().toUtc();
    switch (outcome.status) {
      case RequestOutcomeStatus.committed:
        final settled = intent.copyWith(
          status: BookingIntentStatus.committed,
          reservationId: outcome.reservationId,
          lastCheckedAt: now,
        );
        await _settle(
          'close checked',
          () async => _write((await _ledger()).remove(intent.requestId)),
        );
        return RecoveryCommitted(settled, outcome.reservationId!);
      case RequestOutcomeStatus.inProgress:
        return RecoveryInProgress(intent);
      case RequestOutcomeStatus.absent:
        final checked = intent.copyWith(
          status: BookingIntentStatus.unknown,
          lastCheckedAt: now,
        );
        await _settle(
          'note check',
          () async => _write((await _ledger()).upsert(checked)),
        );
        final beyondRetention =
            now.difference(intent.createdAt) >
            Duration(days: outcome.retentionDays);
        return beyondRetention
            ? RecoveryUnresolved(checked)
            : RecoveryNotCommitted(checked);
      case RequestOutcomeStatus.unavailable:
        return RecoveryUnavailable(intent);
    }
  }

  /// Sends the original request again — same id, same payload, same
  /// server. The server returns the original booking if it had made it.
  Future<Booked> resume(BookingIntent intent) {
    if (intent.scope != _scope) {
      throw StateError('an intent is resumed only where it was made');
    }
    return _send(intent);
  }

  /// The member lets an open intent go (after a check said nothing was
  /// booked, or by choice). Nothing is sent.
  Future<void> discard(BookingIntent intent) async =>
      _write((await _ledger()).remove(intent.requestId));
}
