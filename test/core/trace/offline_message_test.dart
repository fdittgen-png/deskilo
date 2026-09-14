// SPDX-License-Identifier: 0BSD
//
// #1241 — a dropped connection says so.
//
// "Something went wrong. Please try again." is the wrong sentence for a
// network that is not there. It reads as a fault in the app, it does not
// say the attempt never reached the server, and it withholds the one
// thing the reader can act on.
//
// There is no write queue yet — that needs the server-side idempotency
// work first. Saying it plainly is the part that ships without one, and
// it is the part that turns a lost booking from a mystery into a retry.
import 'package:deskilo/core/trace/guarded.dart';
import 'package:deskilo/features/reservations/domain/booking_error_text.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _offline = 'No connection — nothing was sent. Try again when you are '
    'back online.';

Future<void> pumpGuarded(WidgetTester tester, Object thrown) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => runGuarded(
              context,
              domain: 'test',
              message: 'thing failed',
              errorText: 'Something went wrong. Please try again.',
              action: () async => throw thrown,
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('every guarded action says it plainly when the network is '
      'gone', (tester) async {
    // The one place the whole app passes through, so one check covers it.
    await pumpGuarded(tester, const SocketException('Failed host lookup'));
    expect(find.text(_offline), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsNothing);
  });

  testWidgets('a real failure keeps its own message — a mis-classified '
      'fault is worse than a noisy list', (tester) async {
    await pumpGuarded(tester, StateError('the server refused'));
    expect(find.textContaining('Something went wrong'), findsOneWidget);
    expect(find.text(_offline), findsNothing);
  });

  test('the booking path says it too — a booking is the write that '
      'matters', () {
    expect(
      bookingErrorText(
        null,
        const SocketException('Connection refused'),
        'Something went wrong.',
      ),
      _offline,
    );
  });

  test('and a server refusal on that path still maps to its own rule', () {
    // Not a transport failure, so the fallback stands.
    expect(
      bookingErrorText(null, StateError('nope'), 'Something went wrong.'),
      'Something went wrong.',
    );
  });
}

/// A stand-in with the shape `isTransientNetworkFailure` matches: these
/// classify on the MESSAGE, because `http`'s ClientException and
/// `dart:io`'s SocketException both reduce to a sentence.
class SocketException implements Exception {
  const SocketException(this.message);
  final String message;
  @override
  String toString() => 'SocketException: $message';
}
