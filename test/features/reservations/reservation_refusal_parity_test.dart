// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4316 -- the parity the fake could not give: a booking write of the repository port answers a
// server's refusal with the SAME type in the Demo and in the real adapter, and a write that ended
// without an answer is not a refusal in the adapter. The Demo and the fake raised the typed
// refusal themselves, so a gap in the real adapter (a command left outside the conversion) showed
// the right sentence everywhere but on the device.
import 'dart:convert';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/codes/pg_code.dart';
import 'package:deskilo/core/demo/data/reservation_repository.dart';
import 'package:deskilo/core/demo/data/stores.dart';
import 'package:deskilo/features/reservations/data/supabase_reservation_repository.dart';
import 'package:deskilo/features/reservations/domain/reservation_refusal.dart';
import 'package:deskilo/features/reservations/domain/reservation_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

SupabaseReservationRepository _adapter(Future<http.Response> Function(http.Request) handle) =>
    SupabaseReservationRepository(
      SupabaseClient(
        'http://127.0.0.1:54321',
        'sb_publishable_test',
        httpClient: MockClient(handle),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
      InMemoryCacheStore(),
    );

Future<http.Response> _refusal(http.Request r) async => http.Response(
  jsonEncode({'code': DkCode.dkk19, 'message': 'you already have a reservation in that period', 'details': null, 'hint': null}),
  400,
  request: r,
  headers: {'content-type': 'application/json'},
);

Future<http.Response> _gateway(http.Request r) async => http.Response('<html>504</html>', 504, request: r);

/// Every booking write of the port that takes only an id or a token, by name.
final _writes = <String, Future<Object?> Function(ReservationRepository)>{
  'checkIn': (r) => r.checkIn('res-1'),
  'checkOut': (r) => r.checkOut('res-1'),
  'cancel': (r) => r.cancel('res-1'),
  'cancelSeries': (r) => r.cancelSeries('series-1'),
  'kioskIdentify': (r) => r.kioskIdentify(workspaceId: 'ws-1', badgeToken: 'b'),
  'kioskAct': (r) => r.kioskAct(workspaceId: 'ws-1', badgeToken: 'b', action: 'check-out'),
};

Future<Object?> _caught(Future<Object?> Function() call) async {
  try {
    await call();
    return null;
  } on Object catch (e) {
    return e;
  }
}

void main() {
  for (final entry in _writes.entries) {
    test('${entry.key}: a refusal of the server is the typed refusal in the real adapter; a gateway '
        'error is not', () async {
      expect(await _caught(() => entry.value(_adapter(_refusal))), isA<ReservationRefused>());
      final lost = await _caught(() => entry.value(_adapter(_gateway)));
      expect(lost, isNotNull);
      expect(lost, isNot(isA<ReservationRefused>()), reason: 'the outcome is unknown, not refused');
    });
  }

  test('the Demo raises the same type and kind for an unknown badge as the real adapter', () async {
    final demo = await _caught(
      () => FakeReservationRepository().kioskIdentify(workspaceId: 'ws-1', badgeToken: 'bad-badge'),
    );
    final real = await _caught(
      () => _adapter(
        (r) async => http.Response(
          jsonEncode({'code': PgCode.raiseException, 'message': 'badge not recognized', 'details': null, 'hint': null}),
          400,
          request: r,
          headers: {'content-type': 'application/json'},
        ),
      ).kioskIdentify(workspaceId: 'ws-1', badgeToken: 'bad-badge'),
    );
    expect(demo, isA<ReservationRefused>());
    expect(real, isA<ReservationRefused>());
    expect(
      (real! as ReservationRefused).refusal.kind,
      (demo! as ReservationRefused).refusal.kind,
      reason: 'the same refusal kind on both',
    );
  });
}
