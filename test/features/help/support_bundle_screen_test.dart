// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Support preview bytes are saved only explicitly in the same context; cancellation, failures and switches cannot revive stale exports.
import 'dart:async';
import 'dart:convert';
import 'dart:ui' show SemanticsAction;

import 'package:deskilo/core/app_info.dart';
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/schema_version.dart';
import 'package:deskilo/core/demo/demo_entry.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/core/time/clock.dart';
import 'package:deskilo/core/trace/trace_logger.dart';
import 'package:deskilo/features/auth/providers/auth_providers.dart';
import 'package:deskilo/features/help/presentation/screens/help_screen.dart';
import 'package:deskilo/features/help/presentation/screens/support_bundle_screen.dart';
import 'package:deskilo/features/help/providers/help_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../helpers/test_clock.dart';

class _Backend extends ActiveBackend {
  @override
  Future<BackendEndpoint> build() async =>
      const BackendEndpoint('https://private-a.test', 'key-a');
  void change() => state = const AsyncData(
    BackendEndpoint('https://private-b.test', 'key-b'),
  );
}

class _Workspace extends ActiveWorkspaceId {
  @override
  Future<String?> build() async => 'workspace-private';
}

Future<ProviderContainer> mount(
  WidgetTester tester, {
  List<Override> overrides = const [],
  String locale = 'en',
  bool help = false,
  double scale = 1,
  bool workspace = false,
  bool auth = false,
  bool backend = false,
  Future<String>? version,
  Future<String> Function()? versionLoader,
}) async {
  final logger = TraceLogger()
    ..error('private-area', 'secret@example.org TOKEN');
  final container = ProviderContainer(
    overrides: [
      traceLoggerProvider.overrideWithValue(logger),
      appVersionProvider.overrideWith(
        (_) => versionLoader?.call() ?? version ?? Future.value('1.2.3+4'),
      ),
      clockProvider.overrideWithValue(FixedClock(kTestNow)),
      // Fails if support accidentally starts a server probe.
      schemaCompatibilityProvider.overrideWith(
        (_) => throw StateError('network forbidden'),
      ),
      helpContentProvider.overrideWith((_, _) async => '# Local help'),
      helpAnchorsProvider.overrideWith((_, _) async => {}),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  if (workspace) {
    await tester.runAsync(
      () => container.read(activeWorkspaceIdProvider.future),
    );
  }
  if (auth) container.listen(authStateProvider, (_, _) {});
  if (backend) {
    await tester.runAsync(() => container.read(activeBackendProvider.future));
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: help ? const HelpScreen() : const SupportBundleScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

String preview(WidgetTester tester) => tester
    .widget<SelectableText>(find.byKey(const ValueKey('support-preview')))
    .data!;

void main() {
  setUpAll(
    () => VisibilityDetectorController.instance.updateInterval = Duration.zero,
  );

  testWidgets(
    'Help opens support; only explicit Save exports exact preview bytes',
    (tester) async {
      final saved = <Uint8List>[];
      final container = await mount(
        tester,
        help: true,
        overrides: [
          fileSaverProvider.overrideWithValue(({
            required bytes,
            required fileName,
          }) async {
            expect(fileName, 'deskilo-support.json');
            saved.add(bytes);
            return 'private/local/path';
          }),
        ],
      );
      await tester.tap(find.byIcon(Icons.support_agent));
      await tester.pumpAndSettle();
      await tap(tester, 'support-prepare');
      final text = preview(tester);
      expect(text, isNot(contains('secret')));
      expect(text, isNot(contains('private')));
      expect(utf8.encode(text).length, lessThanOrEqualTo(16384));
      expect(saved, isEmpty);
      expect(container.exists(schemaCompatibilityProvider), isFalse);
      await tap(tester, 'support-save');
      expect(utf8.decode(saved.single), text);
      expect(find.text('Saved locally'), findsOneWidget);
      await tap(tester, 'support-cancel');
      expect(find.byType(SupportBundleScreen), findsNothing);
    },
  );

  testWidgets(
    'save failure retries same bytes; window change discards preview',
    (tester) async {
      final saved = <Uint8List>[];
      await mount(
        tester,
        overrides: [
          fileSaverProvider.overrideWithValue(({
            required bytes,
            required fileName,
          }) async {
            saved.add(bytes);
            if (saved.length == 1) throw StateError('/private/SECRET');
            return 'ok';
          }),
        ],
      );
      await tap(tester, 'support-prepare');
      final text = preview(tester);
      await tap(tester, 'support-save');
      expect(find.text('Could not save the file.'), findsOneWidget);
      await tap(tester, 'support-save');
      expect(saved.map(utf8.decode), [text, text]);
      await tap(tester, 'support-window');
      await tester.tap(find.text('Last 24 hours').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('support-preview')), findsNothing);
      await tap(tester, 'support-prepare');
      final json = jsonDecode(preview(tester)) as Map<String, dynamic>;
      expect(
        DateTime.parse(json['window']['until'] as String)
            .difference(DateTime.parse(json['window']['from'] as String)),
        const Duration(hours: 24),
      );
    },
  );

  testWidgets('workspace A-B-A invalidates pending collection', (tester) async {
    final version = Completer<String>();
    final container = await mount(
      tester,
      workspace: true,
      version: version.future,
      overrides: [activeWorkspaceIdProvider.overrideWith(_Workspace.new)],
    );
    await tester.tap(find.byKey(const ValueKey('support-prepare')));
    await tester.pump();
    container
        .read(activeWorkspaceIdProvider.notifier)
        .activate('other-private');
    container
        .read(activeWorkspaceIdProvider.notifier)
        .activate('workspace-private');
    await tester.pump();
    version.complete('1.2.3');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-preview')), findsNothing);
    expect(
      find.text('The context changed. Prepare a new preview.'),
      findsOneWidget,
    );
    await tap(tester, 'support-prepare');
    expect(find.byKey(const ValueKey('support-preview')), findsOneWidget);
  });

  testWidgets('account changes discard preview and pending save completion', (
    tester,
  ) async {
    final users = StreamController<String?>();
    addTearDown(() {
      unawaited(users.close());
    });
    final saving = Completer<String?>();
    final container = await mount(
      tester,
      auth: true,
      overrides: [
        authStateProvider.overrideWith((_) async* {
          yield 'a';
          yield* users.stream;
        }),
        fileSaverProvider.overrideWithValue(
          ({required bytes, required fileName}) => saving.future,
        ),
      ],
    );
    await tap(tester, 'support-prepare');
    await tester.ensureVisible(find.byKey(const ValueKey('support-save')));
    await tester.tap(find.byKey(const ValueKey('support-save')));
    await tester.pump();
    users.add('b');
    await tester.pump();
    saving.complete('private/path');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-preview')), findsNothing);
    expect(find.text('Saved locally'), findsNothing);
    expect(container.exists(schemaCompatibilityProvider), isFalse);
  });

  testWidgets('backend transition and Cancel discard frozen preview', (
    tester,
  ) async {
    final container = await mount(
      tester,
      help: true,
      backend: true,
      overrides: [activeBackendProvider.overrideWith(_Backend.new)],
    );
    await tester.tap(find.byIcon(Icons.support_agent));
    await tester.pumpAndSettle();
    await tap(tester, 'support-prepare');
    (container.read(activeBackendProvider.notifier) as _Backend).change();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-preview')), findsNothing);
    await tap(tester, 'support-cancel');
    await tester.tap(find.byIcon(Icons.support_agent));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-preview')), findsNothing);
  });

  testWidgets(
    'keyboard prepares; collection failure retries without stale data',
    (tester) async {
      final first = Completer<String>();
      var attempts = 0;
      final container = await mount(
        tester,
        versionLoader: () =>
            ++attempts == 1 ? first.future : Future.value('1.2.3'),
      );
      final label = find.descendant(
        of: find.byKey(const ValueKey('support-prepare')),
        matching: find.byType(Text),
      );
      Focus.of(tester.element(label)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      first.completeError(StateError('PRIVATE-ERROR'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not prepare support details. Try again.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('support-preview')), findsNothing);
      container.invalidate(appVersionProvider);
      await tap(tester, 'support-prepare');
      expect(preview(tester), isNot(contains('PRIVATE')));
    },
  );

  testWidgets('Cancel during collection never restores the pending preview', (
    tester,
  ) async {
    final version = Completer<String>();
    await mount(tester, help: true, version: version.future);
    await tester.tap(find.byIcon(Icons.support_agent));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('support-prepare')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('support-cancel')));
    await tester.tap(find.byKey(const ValueKey('support-cancel')));
    await tester.pumpAndSettle();
    version.complete('1.2.3');
    await tester.pumpAndSettle();
    expect(find.byType(SupportBundleScreen), findsNothing);
    await tester.tap(find.byIcon(Icons.support_agent));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('support-preview')), findsNothing);
  });

  for (final locale in ['en', 'fr', 'de', 'es', 'it']) {
    testWidgets('$locale narrow large-text preview stays usable in Demo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final container = await mount(tester, locale: locale, scale: 2);
      container.read(demoEntryProvider.notifier).enter();
      await tester.pumpAndSettle();
      await tap(tester, 'support-prepare');
      final json = jsonDecode(preview(tester)) as Map<String, dynamic>;
      expect(json['mode'], 'demo');
      expect((json['checks'] as Map).values.toSet(), {'unavailable'});
      expect(container.exists(schemaCompatibilityProvider), isFalse);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const ValueKey('support-save')));
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('support-save')))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      semantics.dispose();
    });
  }
}
