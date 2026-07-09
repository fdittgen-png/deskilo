// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/share/share_launcher.dart';
import 'package:deskilo/core/trace/dev_mode.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';

import '../../helpers/mock_providers.dart';

/// In-memory [DevModeStore] so tests never touch SharedPreferences.
class InMemoryDevModeStore implements DevModeStore {
  InMemoryDevModeStore({this.enabled = false});

  bool enabled;

  @override
  Future<bool> read() async => enabled;

  @override
  Future<void> write(bool enabled) async => this.enabled = enabled;
}

TraceLogger seededLogger() {
  final logger = TraceLogger()
    ..log(TraceLevel.info, 'boot', 'older info entry')
    ..log(
      TraceLevel.warn,
      'push',
      'middle warning entry',
    )
    ..error(
      'money',
      'newest error entry',
      error: StateError('boom'),
      stackTrace: StackTrace.fromString('#0 first\n#1 second'),
    );
  return logger;
}

Future<void> pumpSettings(
  WidgetTester tester, {
  required TraceLogger logger,
  required InMemoryDevModeStore devMode,
  ShareLauncher? launcher,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(),
        traceLoggerProvider.overrideWithValue(logger),
        devModeStoreProvider.overrideWithValue(devMode),
        shareLauncherProvider.overrideWithValue(launcher ?? (_) async {}),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

Future<void> pumpDeveloper(
  WidgetTester tester, {
  required TraceLogger logger,
  ShareLauncher? launcher,
}) async {
  await pumpSettings(
    tester,
    logger: logger,
    devMode: InMemoryDevModeStore(enabled: true),
    launcher: launcher,
  );
  await tester.tap(find.text('Developer'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'settings shows the developer-mode toggle to everyone and reveals the '
      'Developer tile only when it is on', (tester) async {
    final store = InMemoryDevModeStore();
    await pumpSettings(
      tester,
      logger: TraceLogger(),
      devMode: store,
    );

    expect(find.text('Developer mode'), findsOneWidget);
    expect(find.text('Developer'), findsNothing);

    await tester.tap(find.text('Developer mode'));
    await tester.pumpAndSettle();

    expect(find.text('Developer'), findsOneWidget);
    expect(store.enabled, isTrue);
  });

  testWidgets('the trace list renders entries newest first', (tester) async {
    await pumpDeveloper(tester, logger: seededLogger());

    expect(find.text('newest error entry'), findsOneWidget);
    expect(find.text('middle warning entry'), findsOneWidget);
    expect(find.text('older info entry'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('newest error entry')).dy,
      lessThan(tester.getTopLeft(find.text('older info entry')).dy),
    );
    expect(
      tester.getTopLeft(find.text('middle warning entry')).dy,
      lessThan(tester.getTopLeft(find.text('older info entry')).dy),
    );
  });

  testWidgets('the level filter chips narrow the list', (tester) async {
    await pumpDeveloper(tester, logger: seededLogger());

    await tester.tap(find.text('Errors'));
    await tester.pumpAndSettle();
    expect(find.text('newest error entry'), findsOneWidget);
    expect(find.text('middle warning entry'), findsNothing);
    expect(find.text('older info entry'), findsNothing);

    await tester.tap(find.text('Warnings+'));
    await tester.pumpAndSettle();
    expect(find.text('newest error entry'), findsOneWidget);
    expect(find.text('middle warning entry'), findsOneWidget);
    expect(find.text('older info entry'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('older info entry'), findsOneWidget);
  });

  testWidgets(
      'Export shares the full trace as a timestamped text/plain .log file',
      (tester) async {
    final captured = <ShareParams>[];
    await pumpDeveloper(
      tester,
      logger: seededLogger(),
      launcher: (params) async => captured.add(params),
    );

    await tester.tap(find.byIcon(Icons.ios_share));
    await tester.pumpAndSettle();

    expect(captured, hasLength(1));
    expect(
      captured.single.fileNameOverrides!.single,
      matches(RegExp(r'^deskilo-trace-\d{8}-\d{4}\.log$')),
    );
    final file = captured.single.files!.single;
    expect(file.mimeType, 'text/plain');
    final content = String.fromCharCodes(await file.readAsBytes());
    expect(content, contains('INFO boot: older info entry'));
    expect(content, contains('ERROR money: newest error entry'));
    expect(content, contains(r'#0 first\n#1 second'));
  });

  testWidgets('Clear empties the list down to the placeholder',
      (tester) async {
    final logger = seededLogger();
    await pumpDeveloper(tester, logger: logger);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(logger.entries, isEmpty);
    expect(find.text('No trace entries yet.'), findsOneWidget);
    expect(find.text('newest error entry'), findsNothing);
  });
}
