// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 PR 2, first part — the writes the contract runs without a
// confirmation (`confirmation: none`), on the person's own things only:
// a favourite, a rating, and checking in, out of or cancelling one of
// their own bookings. Each goes through the same repository call the
// screens make (ADR 0042), never the MCP facade.
//
// One request_id is one intent: the same id with the same arguments
// answers the first outcome again and does nothing twice; the same id
// with other arguments is refused. `expected_state` is the state_digest an
// earlier answer of this page gave; a booking that moved since is a
// conflict, never a blind write.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/reservations/domain/place_feedback.dart';
import '../features/reservations/domain/reservation.dart';
import '../features/reservations/domain/reservation_repository.dart';
import '../features/reservations/providers/place_feedback_providers.dart';
import '../features/reservations/providers/reservation_providers.dart';
import '../features/workspace/providers/workspace_providers.dart';

/// A read or write the page refuses, in the facade's words.
class WebMcpRefused implements Exception {
  const WebMcpRefused(this.code, this.message);
  final String code;
  final String message;
}

typedef WebMcpWrite = Future<Map<String, Object?>> Function(
  Ref ref,
  Map<String, Object?> input,
);

/// The writes the page answers, by contract operation id.
final Map<String, WebMcpWrite> webMcpWriteRunners = {
  'set_favorite': _setFavorite,
  'rate_place': _ratePlace,
  'check_in': (ref, input) =>
      _onOwnBooking(ref, input, (repo, id) => repo.checkIn(id)),
  'check_out': (ref, input) =>
      _onOwnBooking(ref, input, (repo, id) => repo.checkOut(id)),
  'cancel_reservation': (ref, input) =>
      _onOwnBooking(ref, input, (repo, id) => repo.cancel(id)),
};

/// The outcomes of this page's intents, by scope and request_id.
class WebMcpIntents {
  final _seen = <String, (String, Future<Map<String, Object?>>)>{};

  /// Runs [write] once per (scope, request_id); a replay with the same
  /// arguments answers the first outcome, one with other arguments is
  /// refused.
  Future<Map<String, Object?>> once(
    String scope,
    Map<String, Object?> input,
    Future<Map<String, Object?>> Function() write,
  ) {
    final requestId = input['request_id'];
    if (requestId is! String || requestId.isEmpty || requestId.length > 100) {
      throw const WebMcpRefused(
        'validation_error',
        'request_id is required: a new random UUID per intent.',
      );
    }
    final args = jsonEncode({
      for (final key in input.keys.toList()..sort())
        if (key != 'request_id') key: input[key],
    });
    final key = '$scope|$requestId';
    final seen = _seen[key];
    if (seen != null) {
      if (seen.$1 != args) {
        throw const WebMcpRefused(
          'validation_error',
          'This request_id was used with other arguments: use a new one.',
        );
      }
      return seen.$2;
    }
    final outcome = write();
    _seen[key] = (args, outcome);
    // A write that failed may be tried again under the same id.
    unawaited(
      outcome.then<void>((_) {}, onError: (Object _) => _seen.remove(key)),
    );
    return outcome;
  }
}

final webMcpIntentsProvider = Provider<WebMcpIntents>((ref) => WebMcpIntents());

PlaceKind _kind(Map<String, Object?> input) {
  final raw = input['kind'];
  for (final kind in const [
    PlaceKind.seat,
    PlaceKind.desk,
    PlaceKind.office,
    PlaceKind.level,
  ]) {
    if (kind.name == raw) return kind;
  }
  throw const WebMcpRefused(
    'validation_error',
    'kind must be seat, desk, office or level.',
  );
}

String _resource(Map<String, Object?> input) {
  final raw = input['resource_id'];
  if (raw is! String || raw.isEmpty) {
    throw const WebMcpRefused('validation_error', 'resource_id is required.');
  }
  return raw;
}

Future<String> _workspaceId(Ref ref) async {
  final workspace = await ref.read(currentWorkspaceProvider.future);
  if (workspace == null) {
    throw const WebMcpRefused(
      'not_a_member',
      'This person is not a member of this workspace.',
    );
  }
  return workspace.id;
}

Map<String, Object?> _feedback(PlaceFeedback f) => {
  'favorite': f.favorite,
  'average': f.average,
  'count': f.count,
  'mine': f.mine,
};

Future<Map<String, Object?>> _setFavorite(
  Ref ref,
  Map<String, Object?> input,
) async {
  final kind = _kind(input);
  final id = _resource(input);
  final on = input['favorite'];
  if (on is! bool) {
    throw const WebMcpRefused(
      'validation_error',
      'favorite must be true or false.',
    );
  }
  final workspaceId = await _workspaceId(ref);
  final answer = await ref
      .read(placeFeedbackRepositoryProvider)
      .setFavorite(workspaceId, kind, id, on: on);
  ref
    ..invalidate(placeFeedbackProvider(kind, id))
    ..invalidate(myFavoritePlacesProvider);
  return _feedback(answer);
}

Future<Map<String, Object?>> _ratePlace(
  Ref ref,
  Map<String, Object?> input,
) async {
  final kind = _kind(input);
  final id = _resource(input);
  final clear = input['clear'] == true;
  final stars = input['stars'];
  if (!clear && (stars is! int || stars < 0 || stars > 5)) {
    throw const WebMcpRefused(
      'validation_error',
      'stars must be a whole number from 0 to 5, or clear true.',
    );
  }
  final workspaceId = await _workspaceId(ref);
  final answer = await ref
      .read(placeFeedbackRepositoryProvider)
      .setRating(workspaceId, kind, id, clear ? null : stars! as int);
  ref
    ..invalidate(placeFeedbackProvider(kind, id))
    ..invalidate(myFavoritePlacesProvider);
  return _feedback(answer);
}

/// What this page calls a booking's state: it changes whenever the
/// booking does, so an agent acting on a stale view is told so.
String _digest(Reservation r) => base64Url.encode(
  utf8.encode(
    '${r.status.name}|${r.startsAt.toUtc().toIso8601String()}|'
    '${r.endsAt.toUtc().toIso8601String()}|${r.checkedInAt?.toUtc().toIso8601String()}|'
    '${r.checkedOutAt?.toUtc().toIso8601String()}',
  ),
);

Map<String, Object?> _view(Reservation r) => {
  'reservation_id': r.id,
  'status': reservationStatusToDb(r.status),
  'starts_at': r.startsAt.toUtc().toIso8601String(),
  'ends_at': r.endsAt.toUtc().toIso8601String(),
  'seat_id': r.seatId,
  'desk_id': r.deskId,
  'office_id': r.officeId,
  'level_id': r.levelId,
  'checked_in_at': r.checkedInAt?.toUtc().toIso8601String(),
  'checked_out_at': r.checkedOutAt?.toUtc().toIso8601String(),
  'state_digest': _digest(r),
};

Future<Map<String, Object?>> _onOwnBooking(
  Ref ref,
  Map<String, Object?> input,
  Future<void> Function(ReservationRepository repo, String id) act,
) async {
  final id = input['reservation_id'];
  if (id is! String || id.isEmpty) {
    throw const WebMcpRefused(
      'validation_error',
      'reservation_id is required.',
    );
  }
  final workspaceId = await _workspaceId(ref);
  final me = await ref.read(myMemberProvider.future);
  final repo = ref.read(reservationRepositoryProvider);
  final before = await repo.fetchById(id);
  // Only the person's own booking in this workspace: an administrator's
  // wider rights are not the assistant's.
  if (before == null ||
      me == null ||
      before.memberId != me.id ||
      before.workspaceId != workspaceId) {
    throw const WebMcpRefused('not_found', 'No such booking of yours here.');
  }
  final expected = input['expected_state'];
  if (expected != null && expected != _digest(before)) {
    throw const WebMcpRefused(
      'conflict',
      'The booking changed since you read it: read it again first.',
    );
  }
  await act(repo, id);
  final after = await repo.fetchById(id);
  return _view(after ?? before);
}
