// SPDX-License-Identifier: 0BSD
//
// #791 — two field reports arrived with an EMPTY developer trace: a map
// check-in that "failed" while the seat QR worked, and an invite QR the
// scanner "could not recognise". Neither threw, so an error log had
// nothing to record; the app had simply DECIDED not to act, and the
// decision was the one thing nothing wrote down.
//
// These tests pin the decisions themselves: a refusal must leave a line,
// a scanned QR must say what it was without saying what it CONTAINED,
// and a QR the app cannot use must tell the person holding the phone
// instead of being swallowed.
import 'package:deskilo/core/trace/act_trace.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/features/workspace/domain/invite_uri.dart';
import 'package:deskilo/features/workspace/presentation/screens/scan_join_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'reserve_hub_test.dart' show pumpHub, pickHubDate, seatCenter;

/// The trace lines this test session produced, oldest first.
List<String> _lines() =>
    TraceLogger.instance.entries.reversed.map((e) => e.message).toList();

bool _has(String fragment) => _lines().any((l) => l.contains(fragment));

/// The camera cannot run in a widget test (the NfcUidReader idiom the
/// scan boxes already use): the shared fake renders a placeholder and
/// emits payloads on demand.
Future<FakeQrScanner> _pumpJoinScan(WidgetTester tester) async {
  final scanner = FakeQrScanner();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(qrScan: scanner),
      child: const MaterialApp(home: ScanJoinScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return scanner;
}

void main() {
  setUp(() {
    // Memory-only: a test must never write the developer log to disk.
    TraceLogger.instance = TraceLogger();
  });

  group('the line format', () {
    test('a null field is written, not dropped — null IS the finding', () {
      // "the member id was null" is the diagnosis in half these reports.
      // A field that disappears when it is null cannot report it.
      expect(
        ActTrace.line('seat-tap', {'member': null, 'live': true}),
        'seat-tap member=null live=true',
      );
    });

    test('values never contain spaces, so a line parses back apart', () {
      expect(
        ActTrace.line('act', {'reason': 'not an invite'}),
        'act reason=not_an_invite',
      );
    });
  });

  group('a scanned payload is recorded by shape, never by content', () {
    test('an invite QR reports its scheme and parameters, NOT the code', () {
      const secret = 'JOIN7X4Q2';
      final payload =
          InviteUriCodec.encode(code: secret, role: InviteRole.admin);
      final shape = ActTrace.payloadShape(payload);

      expect(shape, contains('deskilo://join'));
      expect(shape, contains('code'), reason: 'the PARAMETER is diagnostic');
      // An invite code admits someone to the workspace, and traces get
      // exported and mailed around. The value must never be in one.
      expect(shape, isNot(contains(secret)));
    });

    test('a foreign QR still reports enough to tell it apart', () {
      expect(
        ActTrace.payloadShape('https://example.com/promo?utm=1'),
        startsWith('https://example.com'),
      );
      expect(ActTrace.payloadShape('  '), 'empty');
    });
  });

  testWidgets('a QR that is not an invitation SAYS so — it used to be '
      'silently dropped, which reads as "the scanner cannot see it"',
      (tester) async {
    final scanner = await _pumpJoinScan(tester);
    scanner.emit('https://example.com/not-an-invite');
    await tester.pump();

    expect(
      find.textContaining('not a DesKilo invitation'),
      findsOneWidget,
      reason: 'the person holding the phone must learn the QR was READ '
          'and rejected, not that the camera failed',
    );
    expect(_has('join-qr'), isTrue);
    expect(_has('reason=not-an-invite'), isTrue);
    // The shape is on the record; the payload is not.
    expect(_has('shape=https://example.com'), isTrue);
  });

  testWidgets('a real invite QR still passes straight through',
      (tester) async {
    final scanner = await _pumpJoinScan(tester);
    scanner.emit(InviteUriCodec.encode(code: 'ABC123', role: InviteRole.user));
    await tester.pumpAndSettle();

    expect(find.textContaining('not a DesKilo invitation'), findsNothing);
    expect(_has('join-qr decoded'), isTrue);
    expect(_has('usable=true'), isTrue);
  });

  testWidgets('the map records WHY it refused a tap — the closed-day gate '
      'left nothing behind before', (tester) async {
    await pumpHub(tester, openWeekdays: const [1, 2, 3, 4, 5]);
    var saturday = kTestNow;
    while (saturday.weekday != DateTime.saturday) {
      saturday = DateTime(saturday.year, saturday.month, saturday.day + 1);
    }
    await pickHubDate(tester, saturday);

    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    expect(_has('reason=workspace-closed'), isTrue,
        reason: 'a refusal the member sees as "nothing happened" has to be '
            'readable afterwards');
  });

  testWidgets('an ordinary tap records the state the decision came from',
      (tester) async {
    await pumpHub(tester);
    await tester.tapAt(seatCenter(tester));
    await tester.pumpAndSettle();

    // seat, state, live, granularity and the member id: everything the
    // branch below it turns on, including the null member that makes a
    // member's own booking read as somebody else's.
    expect(_has('seat-tap seat='), isTrue);
    expect(_has('state=free'), isTrue);
    expect(_has('member='), isTrue);
  });

  test('an exported trace is stamped with where it came from', () async {
    final logger = TraceLogger();
    logger.log(TraceLevel.info, 'booking', 'check-in requested');
    final content = await logger.exportContent(header: [
      'DesKilo trace',
      'workspace: ws-1',
    ]);

    // A trace is read on a different device than the one that wrote it.
    expect(content, startsWith('# DesKilo trace\n# workspace: ws-1\n'));
    expect(content, contains('check-in requested'));
  });
}
