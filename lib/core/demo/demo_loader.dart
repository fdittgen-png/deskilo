// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3848 — the seam between the app and the Demo's deferred library.
//
// The one place that imports `demo_runtime.dart` (`deferred as runtime`):
// on the web the Demo's code and seed data are a separate download, fetched
// when the Demo is entered. On the other platforms a deferred library is
// part of the binary and `loadLibrary()` completes at once, so tests need
// no loader of their own.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../l10n/app_localizations.dart';
import '../l10n/context_l10n.dart';
import 'demo_persona.dart';
import 'demo_runtime.dart' deferred as runtime;

bool _loaded = false;
Future<void>? _loading;

/// Fetches the deferred library (once; a failed fetch is asked for again).
@visibleForTesting
Future<void> loadDemoLibrary() async {
  // A flag, not the finished future: a future keeps the zone it completed
  // in, and a test's zone is gone by the next test.
  if (_loaded) return;
  try {
    await (_loading ??= runtime.loadLibrary());
    _loaded = true;
  } on Object {
    _loading = null;
    rethrow;
  }
}

/// How the Demo's library is fetched. Tests override it to hold or fail the
/// fetch; the default is the deferred import.
@visibleForTesting
final demoLibraryLoaderProvider = Provider<Future<void> Function()>(
  (ref) => loadDemoLibrary,
);

/// Fetches the Demo's library, then builds the session's fixture, looking
/// through [persona] when one is named. The entry sheet calls it before
/// anything is committed, so a Demo that cannot start changes nothing.
Future<void> startDemoSession(WidgetRef ref, DemoPersona? persona) async {
  await ref.read(demoLibraryLoaderProvider)();
  runtime.startDemoSession(ref, persona);
}

/// The Demo environment around [child], once its library is fetched.
///
/// Meanwhile the app's own loading state shows; a failed fetch says so and
/// offers to try again.
class DemoGate extends ConsumerStatefulWidget {
  const DemoGate({required this.child, super.key});

  static const Key loadingKey = Key('demo-gate-loading');
  static const Key failedKey = Key('demo-gate-failed');
  static const Key retryKey = Key('demo-gate-retry');

  final Widget child;

  @override
  ConsumerState<DemoGate> createState() => _DemoGateState();
}

class _DemoGateState extends ConsumerState<DemoGate> {
  late Future<void> _load = ref.read(demoLibraryLoaderProvider)();

  void _retry() {
    final again = ref.read(demoLibraryLoaderProvider)();
    setState(() {
      _load = again;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const _GateFrame(
          child: Center(
            child: CircularProgressIndicator(key: DemoGate.loadingKey),
          ),
        );
      }
      if (snapshot.hasError) {
        return _GateFrame(
          child: Builder(
            builder: (context) => Center(
              key: DemoGate.failedKey,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.demoEntryFailed,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      key: DemoGate.retryKey,
                      onPressed: _retry,
                      child: Text(context.l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return runtime.buildDemoWorkspace(widget.child);
    },
  );
}

/// The app's frame while the Demo's library is not there yet: the app's theme
/// and the device's language, nothing of the Demo. It reads no provider: the
/// container below the entry flag is the live app's, and a read here would
/// start its repositories for a visitor who is leaving them.
class _GateFrame extends StatelessWidget {
  const _GateFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    theme: DeskiloTheme.light(),
    darkTheme: DeskiloTheme.dark(),
    home: Scaffold(body: child),
  );
}
