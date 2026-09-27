// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_info.dart';
import '../../../../core/backend/backend_settings.dart';
import '../../../../core/backend/schema_version.dart';
import '../../../../core/files/file_saver.dart';
import '../../../../core/instance/schema_compatibility.dart';
import '../../../../core/support/support_bundle.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// The windows a person may report on.
const supportBundleWindows = [
  Duration(hours: 1),
  Duration(hours: 24),
  Duration(days: 7),
];

/// #1642 — "Prepare support details": choose a window, see the exact
/// bytes, save them on this device. Nothing is sent anywhere; the saved
/// file goes wherever the person later decides.
Future<void> showSupportBundleSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const SupportBundleSheet(),
    );

class SupportBundleSheet extends ConsumerStatefulWidget {
  const SupportBundleSheet({super.key});

  @override
  ConsumerState<SupportBundleSheet> createState() => _SupportBundleSheetState();
}

class _SupportBundleSheetState extends ConsumerState<SupportBundleSheet> {
  Duration _window = supportBundleWindows[1];
  bool _includeBackend = false;
  late final String? _workspaceAtOpen = ref
      .read(currentWorkspaceProvider)
      .value
      ?.id;
  late final String? _accountAtOpen = ref.read(currentAccountIdProvider);

  SupportBundle _build() {
    final now = ref.read(clockProvider).now();
    final enabled = ref.read(enabledFeaturesSyncProvider);
    final compat = ref.read(schemaCompatibilityProvider).value;
    return buildSupportBundle(
      SupportBundleInput(
        createdAt: now,
        from: now.subtract(_window),
        to: now,
        appVersion: ref.read(appVersionProvider).value ?? '',
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
        requiredSchema: requiredSchemaVersion,
        traces: TraceLogger.instance.entries,
        features: {
          for (final f in WorkspaceFeature.values) f.dbKey: enabled.contains(f),
        },
        checks: {
          'schema': switch (compat) {
            SchemaCompatibility.current || SchemaCompatibility.ahead => 'ok',
            SchemaCompatibility.behind => 'failing',
            _ => 'unknown',
          },
        },
        backendUrl: ref.read(activeBackendProvider).value?.url,
        includeBackendHost: _includeBackend,
        workspaceId: _workspaceAtOpen,
      ),
    );
  }

  Future<void> _save(SupportBundle bundle) async {
    final l10n = AppLocalizations.of(context);
    // The person, or the space, changed while the sheet was open: what is
    // on screen no longer describes where they are. Discard it.
    if (ref.read(currentWorkspaceProvider).value?.id != _workspaceAtOpen ||
        ref.read(currentAccountIdProvider) != _accountAtOpen) {
      AppSnack.error(
        context,
        l10n?.supportBundleStale ??
            'The account or workspace changed. Prepare the details again.',
      );
      Navigator.of(context).pop();
      return;
    }
    final day = ref
        .read(clockProvider)
        .now()
        .toIso8601String()
        .split('T')
        .first;
    await runGuarded(
      context,
      domain: 'support',
      message: 'support bundle save failed',
      errorText:
          l10n?.supportBundleSaveFailed ?? 'The file could not be saved.',
      action: () async {
        await ref.read(fileSaverProvider)(
          bytes: Uint8List.fromList(utf8.encode(bundle.text)),
          fileName: 'deskilo-support-$day.json',
        );
        if (!mounted) return;
        AppSnack.success(
          context,
          l10n?.supportBundleSaved ?? 'Saved on this device. Nothing was sent.',
        );
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bundle = _build();
    String windowLabel(Duration d) => switch (d.inHours) {
      1 => l10n?.supportBundleLastHour ?? 'Last hour',
      24 => l10n?.supportBundleLastDay ?? 'Last 24 hours',
      _ => l10n?.supportBundleLastWeek ?? 'Last 7 days',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        key: const ValueKey('support-bundle-sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n?.supportBundleTitle ?? 'Prepare support details',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n?.supportBundleIntro ??
                'Versions, features, checks and safe error codes only — no '
                    'message, name, amount, password or address. You see '
                    'exactly what is saved. A file you send cannot be '
                    'taken back.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final w in supportBundleWindows)
                ChoiceChip(
                  key: ValueKey('support-window-${w.inHours}'),
                  label: Text(windowLabel(w)),
                  selected: _window == w,
                  onSelected: (_) => setState(() => _window = w),
                ),
            ],
          ),
          SwitchListTile(
            key: const ValueKey('support-include-backend'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n?.supportBundleIncludeBackend ?? 'Include the server address',
            ),
            subtitle: Text(
              l10n?.supportBundleIncludeBackendHint ??
                  'Its name can identify your installation. Off by default.',
            ),
            value: _includeBackend,
            onChanged: (v) => setState(() => _includeBackend = v),
          ),
          Text(
            l10n?.supportBundleSize('${bundle.bytes}') ??
                '${bundle.bytes} bytes',
            key: const ValueKey('support-bundle-size'),
            style: textTheme.labelSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: SelectableText(
                bundle.text,
                key: const ValueKey('support-bundle-preview'),
                style: textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.xs,
            children: [
              TextButton(
                key: const ValueKey('support-bundle-cancel'),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n?.commonCancel ?? 'Cancel'),
              ),
              FilledButton(
                key: const ValueKey('support-bundle-save'),
                onPressed: () => _save(bundle),
                child: Text(l10n?.supportBundleSave ?? 'Save on this device'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
