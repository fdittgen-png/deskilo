// SPDX-License-Identifier: AGPL-3.0-or-later
// #1648: a native launch failure cannot put OAuth codes/state into console or
// diagnostic logs, even when the platform exception repeats the full URI.
import 'package:deskilo/core/links/link_launcher.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('launches externally and logs no URI or platform error contents',
      (tester) async {
    const channel = MethodChannel('plugins.flutter.io/url_launcher');
    final uri = Uri.parse('https://target.example/auth/v1/callback'
        '?code=one_time_secret&state=correlation_secret');
    final debug = <String>[];
    final oldDebug = debugPrint;
    final oldTrace = TraceLogger.instance;
    final trace = TraceLogger();
    debugPrint = (message, {wrapWidth}) => debug.add(message ?? '');
    TraceLogger.instance = trace;
    addTearDown(() {
      debugPrint = oldDebug;
      TraceLogger.instance = oldTrace;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      expect(call.method, 'launch');
      expect((call.arguments as Map)['url'], uri.toString());
      expect((call.arguments as Map)['useWebView'], isFalse);
      throw PlatformException(code: 'launch_failed', message: uri.toString());
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    bool launched;
    try {
      launched = await container.read(linkLauncherProvider)(uri);
    } finally {
      // The widget binding checks debug globals before addTearDown runs.
      debugPrint = oldDebug;
    }
    expect(launched, isFalse);
    expect(trace.entries, hasLength(1));
    final logged = [
      ...debug,
      for (final entry in trace.entries)
        '${entry.message} ${entry.error} ${entry.stack}',
    ].join('\n');
    expect(logged, isNot(contains('one_time_secret')));
    expect(logged, isNot(contains('correlation_secret')));
    expect(logged, isNot(contains('target.example')));
  });
}
