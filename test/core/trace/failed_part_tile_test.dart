// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4416 -- a part that fails to build shows the worded tile in a release
// build, and its failure is traced once by the global hook.
import 'package:deskilo/core/trace/trace_hooks.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/core/ui/failed_part_tile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

class _Breaks extends StatelessWidget {
  const _Breaks();
  @override
  Widget build(BuildContext context) => throw StateError('broken part');
}

void main() {
  testWidgets('a release build shows the worded tile and traces the failure '
      'once', (tester) async {
    final builder = ErrorWidget.builder;
    final onError = FlutterError.onError;
    final dispatcher = PlatformDispatcher.instance.onError;
    final logger = TraceLogger();
    // The hook wraps the test binding's own handler, which still records
    // the failure for takeException below.
    installGlobalTraceHooks(logger);
    installFailedPartTile(release: true);

    await pumpApp(tester, const Scaffold(body: _Breaks()));
    final thrown = tester.takeException();

    final shown = find.byKey(const ValueKey('failed-part')).evaluate().length;
    final words = find
        .text('This part could not be shown. Go back and open it again.')
        .evaluate()
        .length;
    final traced = [
      for (final e in logger.entries)
        if (e.area == 'flutter' && (e.error ?? '').contains('broken part')) e,
    ];
    // Restored before the body ends: the binding checks its handler then.
    ErrorWidget.builder = builder;
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = dispatcher;

    expect(thrown, isA<StateError>());
    expect(shown, 1);
    expect(words, 1);
    expect(traced, hasLength(1));
    expect(traced.single.level, TraceLevel.error);
  });

  test('a debug build keeps the framework box', () {
    final builder = ErrorWidget.builder;
    installFailedPartTile(); // a test runs as a debug build
    expect(ErrorWidget.builder, same(builder));
  });
}
