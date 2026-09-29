// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import '../../../directory/presentation/account_portal_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../providers/workspace_providers.dart';
import '../widgets/application_requests_entry.dart';

/// The waiting room (0052): a freshly joined member is PENDING until the
/// workspace's validators approve. They see only the workspace name here
/// — no plan, no directory, no money — plus a re-check button, the
/// profile switcher (they may be active elsewhere) and sign-out.
///
/// #1652 — a usable state, not a spinner: it says WORKSPACE MEMBERSHIP
/// approval (not an assistant's or a database's), what stays available,
/// when it was last checked, and a failed check reads "not updated" —
/// never approved, never rejected. Checking only reads: it never asks
/// for admission again, and there is no countdown, because nobody set a
/// deadline. An approval is followed by the router's own rule.
class PendingApprovalScreen extends ConsumerStatefulWidget {
  const PendingApprovalScreen({super.key});

  @override
  ConsumerState<PendingApprovalScreen> createState() => _PendingApprovalScreenState();
}

class _PendingApprovalScreenState extends ConsumerState<PendingApprovalScreen> {
  bool _checking = false;
  DateTime? _lastChecked;

  /// null before the first check; true when the last one failed.
  bool? _notUpdated;

  /// #572 — the tap that follows an approval must refetch EVERYTHING the
  /// pending horizon hid, and the plan's disk cache FIRST (awaited), or
  /// the rebuild re-serves the cached emptiness and the workspace stays
  /// blank.
  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    var failed = false;
    try {
      await ref.read(floorPlanRepositoryProvider).invalidateCache();
      ref
        ..invalidate(myWorkspacesProvider)
        ..invalidate(myMemberProvider)
        ..invalidate(levelsProvider)
        ..invalidate(floorPlanProvider)
        ..invalidate(targetNamesProvider);
      await ref.read(myMemberProvider.future);
    } catch (e, st) {
      // Shown as "not updated"; the request itself is untouched.
      TraceLogger.instance.warn('workspace', 'pending status not updated',
          error: e, stackTrace: st);
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _notUpdated = failed;
      if (!failed) _lastChecked = ref.read(clockProvider).now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final name = workspace?.name ?? '';
    final checked = _lastChecked;
    final notUpdated = _notUpdated;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.pendingApprovalTitle ?? 'Workspace membership awaiting approval'),
        actions: const [ApplicationRequestsEntry(), AccountPortalEntry()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.xlAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.hourglass_top_outlined, size: 64,
                      color: theme.colorScheme.primary),
                ),
                const SizedBox(height: AppSpacing.lg),
                Semantics(
                  header: true,
                  child: Text(name, key: const ValueKey('pending-workspace'),
                      style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n?.pendingApprovalBody(name) ??
                      'You have joined $name. An administrator must approve your '
                          'membership before you can use the workspace — you will '
                          'get access as soon as they confirm.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n?.pendingAvailable ??
                      'While you wait, your other workspaces, your account and the help stay available.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                // Announced when it CHANGES only: the same answer twice is
                // not news, and the time below is outside the live region.
                if (notUpdated != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      notUpdated
                          ? l10n?.pendingNotUpdated ??
                              'Status not updated — the server could not be reached. Your request is unchanged.'
                          : l10n?.pendingStillWaiting ?? 'Still awaiting approval.',
                      key: const ValueKey('pending-status'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (checked != null)
                  Text(
                    l10n?.pendingLastChecked(MaterialLocalizations.of(context)
                            .formatTimeOfDay(TimeOfDay.fromDateTime(checked))) ??
                        'Last checked',
                    key: const ValueKey('pending-last-checked'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  key: const ValueKey('pending-refresh'),
                  onPressed: _checking ? null : _check,
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n?.pendingApprovalRefresh ?? 'Check again'),
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    TextButton.icon(
                      key: const ValueKey('pending-switch'),
                      onPressed: () => context.push('/profiles'),
                      icon: const Icon(Icons.switch_account_outlined),
                      label: Text(l10n?.pendingSwitchWorkspace ?? 'Switch workspace'),
                    ),
                    TextButton.icon(
                      key: const ValueKey('pending-help'),
                      onPressed: () => context.push('/help'),
                      icon: const Icon(Icons.help_outline),
                      label: Text(l10n?.pendingHelp ?? 'Help'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
