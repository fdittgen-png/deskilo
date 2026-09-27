// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_info.dart';
import '../../../../core/backend/backend_settings.dart';
import '../../../../core/backend/schema_version.dart';
import '../../../../core/demo/demo_entry.dart';
import '../../../../core/diagnostics/support_bundle.dart';
import '../../../../core/files/file_saver.dart';
import '../../../../core/instance/schema_compatibility.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// Own-device Help infrastructure, available even without a workspace or a
/// working server. No workspace feature/privileged data or management calls.
class SupportBundleScreen extends ConsumerStatefulWidget {
  const SupportBundleScreen({super.key});

  @override
  ConsumerState<SupportBundleScreen> createState() =>
      _SupportBundleScreenState();
}

class _SupportBundleScreenState extends ConsumerState<SupportBundleScreen> {
  SupportBundle? _bundle;
  List<Object?>? _context;
  int _generation = 0;
  int _hours = 1;
  bool _busy = false;
  String? _notice;

  // Peek only: preparing diagnostics must never start a repository request.
  List<Object?> _scope() {
    final container = ProviderScope.containerOf(context, listen: false);
    return [
      if (container.exists(authStateProvider)) ref.read(authStateProvider),
      if (container.exists(activeWorkspaceIdProvider))
        ref.read(activeWorkspaceIdProvider),
      if (container.exists(activeBackendProvider))
        ref.read(activeBackendProvider),
      ref.read(bootedBackendUrlProvider),
      ref.read(demoEntryProvider),
    ];
  }

  void _invalidate() {
    _generation++;
    if (!_busy && _bundle == null) return;
    setState(() {
      _busy = false;
      _bundle = null;
      _context = null;
      _notice =
          AppLocalizations.of(context)?.supportChanged ??
          'The context changed. Prepare a new preview.';
    });
  }

  Future<void> _prepare() async {
    final generation = ++_generation;
    final scope = _scope();
    final now = ref.read(clockProvider).now().toUtc();
    final from = now.subtract(Duration(hours: _hours));
    // Freeze counts before awaiting the local package metadata. Raw trace text
    // is never copied, inspected for redaction, or serialized.
    final counts = <SupportSeverity, int>{};
    for (final entry in ref.read(traceLoggerProvider).entries.take(500)) {
      if (entry.ts.isBefore(from) || entry.ts.isAfter(now)) continue;
      final severity = SupportSeverity.values.byName(entry.level.name);
      counts.update(severity, (n) => n + 1, ifAbsent: () => 1);
    }
    setState(() {
      _busy = true;
      _bundle = null;
      _notice = null;
    });
    try {
      final version = await ref
          .read(appVersionProvider.future)
          .timeout(const Duration(seconds: 3), onTimeout: () => '');
      if (!mounted || generation != _generation) return;
      if (!listEquals(scope, _scope())) {
        _invalidate();
        return;
      }
      final container = ProviderScope.containerOf(context, listen: false);
      final schema = container.exists(schemaCompatibilityProvider)
          ? ref.read(schemaCompatibilityProvider).value
          : null;
      final demo = ref.read(demoEntryProvider);
      final bundle = SupportBundle(
        from: from,
        until: now,
        mode: demo ? SupportMode.demo : SupportMode.local,
        platform: kIsWeb
            ? SupportPlatform.web
            : SupportPlatform.values.byName(defaultTargetPlatform.name),
        appVersion: version,
        // Compatibility alone cannot tell us an ahead/behind server's version.
        schemaVersion: !demo && schema == SchemaCompatibility.current
            ? requiredSchemaVersion
            : null,
        checks: {
          SupportCheck.schema: demo
              ? SupportStatus.unavailable
              : switch (schema) {
                  SchemaCompatibility.current => SupportStatus.ok,
                  SchemaCompatibility.behind ||
                  SchemaCompatibility.ahead => SupportStatus.attention,
                  _ => SupportStatus.unavailable,
                },
        },
        eventCounts: counts,
      );
      setState(() {
        _bundle = bundle;
        _context = scope;
        _busy = false;
      });
      // ignore: unused_catch_stack
    } catch (e, st) {
      // trace-exempt: export failures intentionally retain no raw error/path.
      if (!mounted || generation != _generation) return;
      setState(() {
        _busy = false;
        _notice =
            AppLocalizations.of(context)?.supportFailed ??
            'Could not prepare support details. Try again.';
      });
    }
  }

  Future<void> _save() async {
    final bundle = _bundle;
    if (bundle == null || _busy) return;
    if (!listEquals(_context, _scope())) {
      _invalidate();
      return;
    }
    final generation = _generation;
    setState(() => _busy = true);
    String? path;
    try {
      path = await ref.read(fileSaverProvider)(
        bytes: bundle.bytes,
        fileName: 'deskilo-support.json',
      );
      // ignore: unused_catch_stack
    } catch (e, st) {
      // trace-exempt: no filesystem paths/provider errors in support output.
    }
    if (!mounted || generation != _generation) return;
    if (!listEquals(_context, _scope())) {
      _invalidate();
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = false;
      _notice = path == null
          ? l10n?.commonSaveFailed ?? 'Could not save the file.'
          : l10n?.supportSaved ?? 'Saved locally';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    // Invalidate on each transition, including A -> B -> A while preparing.
    if (container.exists(authStateProvider)) {
      ref.listen(authStateProvider, (_, _) => _invalidate());
    }
    if (container.exists(activeWorkspaceIdProvider)) {
      ref.listen(activeWorkspaceIdProvider, (_, _) => _invalidate());
    }
    if (container.exists(activeBackendProvider)) {
      ref.listen(activeBackendProvider, (_, _) => _invalidate());
    }
    ref.listen(bootedBackendUrlProvider, (_, _) => _invalidate());
    ref.listen(demoEntryProvider, (_, _) => _invalidate());
    final demo = ref.watch(demoEntryProvider);
    final bundle = _bundle;
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.supportTitle ?? 'Support details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n?.supportPrivacy ?? 'Only local diagnostic counts are included. Shared files cannot be revoked.',
            ),
            if (demo)
              Text(l10n?.supportDemo ?? 'Demo: simulated local context'),
            const SizedBox(height: 16),
            DropdownButton<int>(
              key: const ValueKey('support-window'),
              value: _hours,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: 1,
                  child: Text(l10n?.supportHour ?? 'Last hour'),
                ),
                DropdownMenuItem(
                  value: 24,
                  child: Text(l10n?.supportDay ?? 'Last 24 hours'),
                ),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value == null) return;
                      _invalidate();
                      setState(() => _hours = value);
                    },
            ),
            FilledButton(
              key: const ValueKey('support-prepare'),
              onPressed: _busy ? null : _prepare,
              child: Text(l10n?.supportPrepare ?? 'Prepare preview'),
            ),
            if (_busy) const LinearProgressIndicator(),
            if (_notice != null)
              Text(_notice!, key: const ValueKey('support-notice')),
            if (bundle != null) ...[
              Text(
                l10n?.supportSize(bundle.bytes.length) ??
                    'Preview: ${bundle.bytes.length} bytes',
              ),
              SelectableText(
                bundle.preview,
                key: const ValueKey('support-preview'),
              ),
              FilledButton(
                key: const ValueKey('support-save'),
                onPressed: _busy ? null : _save,
                child: Text(l10n?.commonSave ?? 'Save'),
              ),
            ],
            TextButton(
              key: const ValueKey('support-cancel'),
              onPressed: () {
                _generation++;
                _bundle = null;
                Navigator.of(context).pop();
              },
              child: Text(l10n?.commonCancel ?? 'Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
