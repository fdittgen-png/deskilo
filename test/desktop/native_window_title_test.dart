// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3621 — the program window's title follows the page through the runner's one
// channel: sent once per change, never where the runner does not listen, and a
// runner without the handler (an older build) is left alone.
import 'package:deskilo/core/window/native_window_title.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(NativeWindowTitle.channelName);
  final heard = <Object?>[];

  setUp(() {
    heard.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'setTitle') heard.add(call.arguments);
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a title is sent once, again only when it changes', () async {
    final title = NativeWindowTitle(supported: () => true);
    await title.set('Bookings — Studio — DesKilo');
    await title.set('Bookings — Studio — DesKilo');
    await title.set('DesKilo');
    expect(heard, ['Bookings — Studio — DesKilo', 'DesKilo']);
  });

  test('nothing is sent where the runner does not listen', () async {
    // The default is the Windows runner alone; tests run as another platform.
    await NativeWindowTitle().set('DesKilo');
    expect(heard, isEmpty);
  });

  test('a runner without the handler is left alone', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    final title = NativeWindowTitle(supported: () => true);
    await expectLater(title.set('DesKilo'), completes);
  });
}
