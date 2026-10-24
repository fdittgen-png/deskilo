// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1558 — the endpoint this connector registers IS the device token.
//
// `onNewEndpoint('fcm:\$token')` emitted the nine literal characters
// `fcm:$token` for every installation, on the first registration and on
// every refresh alike. The 0084 sender strips the `fcm:` prefix and
// hands the rest to FCM as `message.token`, so a configured deployment
// registered a token FCM has never heard of and no notification could
// be delivered — and the refresh path repeated the same value instead
// of correcting it.
//
// The app-side suite could not see this: it fakes `PushConnector` and
// hands `PushService` an already-formed `fcm:token-1`. These drive the
// REAL connector — its `register`, its refresh handler — through the
// injected token source, which is the only thing replaced.
//
// This suite lives in the package rather than the app's `test/` because
// the F-Droid build swaps `packages/deskilo_push` for the Google-free
// twin before running the app's suite (#716); a root test importing
// Firebase would not compile there.
import 'package:deskilo_push/src/firebase_push_connector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the first registration carries the token Firebase returned',
      () async {
    final endpoints = <String>[];
    final connector = FirebasePushConnector(
      tokenSource: () async => 'initial-device-token',
    )..wireEndpointsForTest(endpoints.add);

    await connector.register();

    expect(endpoints, <String>['fcm:initial-device-token']);
    expect(endpoints.single, isNot(contains(r'$token')));
  });

  test('a refreshed token is registered as itself, not as a placeholder',
      () {
    final endpoints = <String>[];
    FirebasePushConnector()
      ..wireEndpointsForTest(endpoints.add)
      ..publishToken('refreshed-device-token');

    expect(endpoints, <String>['fcm:refreshed-device-token']);
    expect(endpoints.single, isNot(contains(r'$token')));
  });

  test('what the sender strips leaves exactly the device token', () {
    final endpoints = <String>[];
    FirebasePushConnector()
      ..wireEndpointsForTest(endpoints.add)
      ..publishToken('initial-device-token');

    // supabase/functions/send-push: `ep.endpoint.slice(4)`.
    expect(endpoints.single.substring(4), 'initial-device-token');
  });

  test('no token, no endpoint — and nothing thrown', () async {
    final endpoints = <String>[];
    final connector = FirebasePushConnector(tokenSource: () async => null)
      ..wireEndpointsForTest(endpoints.add);

    await connector.register();

    expect(endpoints, isEmpty);
  });

  test('an unconfigured build never reaches Firebase', () async {
    // The committed firebase_options stub returns null, so initialize
    // answers false BEFORE Firebase.initializeApp — the path this suite
    // relies on for having no platform channel to mock.
    expect(
      await FirebasePushConnector().initialize(
        onNewEndpoint: (_) {},
        onUnregistered: () {},
        onMessage: (_) {},
      ),
      isFalse,
    );
  });

  test('#2559 C2 — a start never prompts and registers nothing when '
      'notifications are not allowed', () async {
    final endpoints = <String>[];
    final asked = <bool>[];
    final connector = FirebasePushConnector(
      tokenSource: () async => 'device-token',
      permission: ({required ask}) async {
        asked.add(ask);
        return ask; // allowed only once the person asked
      },
    )..wireEndpointsForTest(endpoints.add);

    expect(await connector.register(), isFalse);
    expect(endpoints, isEmpty);
    expect(asked, [false]);

    expect(await connector.register(ask: true), isTrue);
    expect(endpoints, ['fcm:device-token']);
    expect(asked, [false, true]);
  });

  test('#2559 C2 — a tapped message hands on its string data only', () {
    expect(
      FirebasePushConnector.openedData(
          {'kind': 'member_note', 'ws': 'w-1', 'n': 3, 'x': null}),
      {'kind': 'member_note', 'ws': 'w-1'},
    );
  });
}
