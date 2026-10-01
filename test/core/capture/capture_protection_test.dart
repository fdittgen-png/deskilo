// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1824 — screen-capture protection, proved at the channel boundary.
//
// The invariant: the window is protected exactly while at least one
// thread holds it — the FIRST hold sends `enable` over `deskilo/capture`
// and the LAST release sends `disable`, never more; what the platform
// reports back (a screenshot, a recording starting) arrives as a signal.
// The native halves (FLAG_SECURE, sharingType, display affinity, the iOS
// observers) cannot run in a unit test; they are verified on devices.
import 'dart:async';

import 'package:deskilo/core/capture/capture_protection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(CaptureProtection.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<String> calls;
  Object? enableAnswer;

  setUp(() {
    calls = [];
    enableAnswer = false;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'enable' ? enableAnswer : null;
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  /// The platform calling INTO Dart, the way a runner does.
  Future<void> fromNative(String method, [Object? arguments]) async {
    await messenger.handlePlatformMessage(
      CaptureProtection.channelName,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
  }

  test(
    'the first hold enables and the last release disables — once each',
    () async {
      final protection = CaptureProtection(web: false);
      await protection.enable();
      await protection.enable();
      expect(calls, ['enable']);
      expect(protection.holders, 2);
      await protection.disable();
      expect(calls, ['enable'], reason: 'a thread is still open');
      await protection.disable();
      expect(calls, ['enable', 'disable']);
      await protection.disable();
      expect(calls, [
        'enable',
        'disable',
      ], reason: 'a release without a hold reaches no platform');
    },
  );

  test('a screenshot reported by the platform becomes a signal', () async {
    final protection = CaptureProtection(web: false);
    final signals = <CaptureSignal>[];
    final sub = protection.signals.listen(signals.add);
    await protection.enable();
    await fromNative('screenshot');
    await pumpEventQueue();
    expect(signals, [CaptureSignal.screenshot]);
    await sub.cancel();
  });

  test('recording starts and stops as the platform reports it, and a '
      'screen already captured at enable counts', () async {
    enableAnswer = true;
    final protection = CaptureProtection(web: false);
    final signals = <CaptureSignal>[];
    final sub = protection.signals.listen(signals.add);
    await protection.enable();
    expect(protection.captured, isTrue);
    await fromNative('captured', false);
    await pumpEventQueue();
    expect(protection.captured, isFalse);
    expect(signals, [
      CaptureSignal.recordingStarted,
      CaptureSignal.recordingStopped,
    ]);
    await sub.cancel();
  });

  test('a runner without the channel is traced, not thrown', () async {
    messenger.setMockMethodCallHandler(channel, null);
    final protection = CaptureProtection(web: false);
    await expectLater(protection.enable(), completes);
    await expectLater(protection.disable(), completes);
  });

  test('a platform error is traced, and the count stays true', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });
    final protection = CaptureProtection(web: false);
    await expectLater(protection.enable(), completes);
    expect(protection.holders, 1);
  });

  test('the web sends nothing over the channel and reports obscured '
      'changes from the page', () async {
    final page = StreamController<bool>.broadcast();
    final protection = CaptureProtection(web: true, webObscured: page.stream);
    expect(protection.canBlock, isFalse);
    final seen = <bool>[];
    final sub = protection.obscured.listen(seen.add);
    await protection.enable();
    page
      ..add(true)
      ..add(false);
    await pumpEventQueue();
    expect(calls, isEmpty);
    expect(seen, [true, false]);
    await sub.cancel();
    await page.close();
  });

  test('the inert protection (tests, Demo) touches no platform', () async {
    final protection = CaptureProtection.inert();
    await protection.enable();
    await protection.disable();
    expect(calls, isEmpty);
  });
}
