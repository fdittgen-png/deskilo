// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1824 — the shield holds the window's capture protection for exactly
// as long as a thread is on screen, and turns what the platform reports
// into what the thread does: a screenshot is announced, a recording
// hides the thread, the web says it cannot block and blurs when the page
// is not being looked at.
import 'dart:async';

import 'package:deskilo/core/capture/capture_protection.dart';
import 'package:deskilo/core/capture/capture_providers.dart';
import 'package:deskilo/core/capture/capture_shield.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel(CaptureProtection.channelName);
  late List<String> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return call.method == 'enable' ? false : null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<void> pump(
    WidgetTester tester,
    CaptureProtection protection, {
    bool enabled = true,
    bool shown = true,
    VoidCallback? onScreenshot,
    String reader = '',
  }) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        captureProtectionProvider.overrideWithValue(protection),
        captureReaderNameProvider.overrideWithValue(reader),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: shown
              ? CaptureShield(
                  enabled: enabled,
                  onScreenshot: onScreenshot,
                  child: const Text('secret thread'),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ),
  );

  Future<void> fromNative(
    WidgetTester tester,
    String method, [
    Object? arguments,
  ]) async {
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          CaptureProtection.channelName,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall(method, arguments),
          ),
          (_) {},
        );
    await tester.pumpAndSettle();
  }

  testWidgets('entering a thread enables, leaving it disables', (tester) async {
    final protection = CaptureProtection(web: false);
    await pump(tester, protection);
    await tester.pumpAndSettle();
    expect(calls, ['enable']);
    expect(find.text('secret thread'), findsOneWidget);
    await pump(tester, protection, shown: false);
    await tester.pumpAndSettle();
    expect(calls, ['enable', 'disable']);
  });

  testWidgets('a workspace that switched protection off is left alone', (
    tester,
  ) async {
    final protection = CaptureProtection(web: false);
    await pump(tester, protection, enabled: false);
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    // Switched on while open — it holds from then on.
    await pump(tester, protection);
    await tester.pumpAndSettle();
    expect(calls, ['enable']);
  });

  testWidgets('a screenshot is handed to the thread to announce', (
    tester,
  ) async {
    final protection = CaptureProtection(web: false);
    var announced = 0;
    await pump(tester, protection, onScreenshot: () => announced++);
    await tester.pumpAndSettle();
    await fromNative(tester, 'screenshot');
    expect(announced, 1);
  });

  testWidgets('a recording hides the thread until it stops', (tester) async {
    final protection = CaptureProtection(web: false);
    await pump(tester, protection);
    await tester.pumpAndSettle();
    await fromNative(tester, 'captured', true);
    expect(
      find.byKey(const ValueKey('capture-recording-hidden')),
      findsOneWidget,
    );
    expect(find.text('secret thread'), findsNothing);
    await fromNative(tester, 'captured', false);
    expect(find.text('secret thread'), findsOneWidget);
  });

  testWidgets('the web says it cannot block, watermarks with the reader '
      'and blurs while the page is not looked at', (tester) async {
    final page = StreamController<bool>.broadcast();
    final protection = CaptureProtection(web: true, webObscured: page.stream);
    await pump(tester, protection, reader: 'Florian D.');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capture-web-notice')), findsOneWidget);
    expect(find.byKey(const ValueKey('capture-watermark')), findsOneWidget);
    expect(find.byKey(const ValueKey('capture-blur-false')), findsOneWidget);
    page.add(true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capture-blur-true')), findsOneWidget);
    page.add(false);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('capture-blur-false')), findsOneWidget);
    expect(calls, isEmpty, reason: 'the web has no channel to call');
    await page.close();
  });
}
