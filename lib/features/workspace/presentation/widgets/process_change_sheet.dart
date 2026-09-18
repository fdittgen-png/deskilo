// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/process_activation.dart';
import '../../application/resolve_processes.dart';
import '../../domain/feature_flags_write.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_process.dart';
import '../../providers/workspace_providers.dart';
import '../feature_names.dart';
import '../process_names.dart';

/// #1329 — the ONE preview-and-apply surface for a process intent.
///
/// It reads the authoritative row (the workspace chain), plans through
/// `planProcessChange`, shows every effect the write will have — what is
/// switched, what is pulled in from elsewhere, what already works, what
/// comes back or stops — and writes through `applyProcessChange`, which
/// conditions the write on exactly what was shown. A conflict is not an
/// error here: the row is refetched, the preview recomputes from it, and
/// the owner is asked again. Success is announced only after the refetch.
///
/// Returns how many flags were written, or null when nothing was.
Future<int?> showProcessChangeSheet(
  BuildContext context, {
  required String processKey,
  required List<String> subprocessKeys,
  required bool activate,
}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ProcessChangeSheet(
        processKey: processKey,
        subprocessKeys: subprocessKeys,
        activate: activate,
      ),
    );

class ProcessChangeSheet extends ConsumerStatefulWidget {
  const ProcessChangeSheet({
    super.key,
    required this.processKey,
    required this.subprocessKeys,
    required this.activate,
  });

  final String processKey;
  final List<String> subprocessKeys;
  final bool activate;

  @override
  ConsumerState<ProcessChangeSheet> createState() => _ProcessChangeSheetState();
}

class _ProcessChangeSheetState extends ConsumerState<ProcessChangeSheet> {
  DeactivationMode _mode = DeactivationMode.refuse;
  bool _busy = false;
  bool _conflict = false;
  bool _unconfirmed = false;

  Future<void> _apply(ProcessChangePlan plan) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() {
      _busy = true;
      _conflict = false;
    });
    try {
      final result =
          await applyProcessChange(ref, workspace: workspace, plan: plan);
      if (!mounted) return;
      Navigator.of(context).pop(
          result == ProcessApplyResult.applied ? plan.flags.length : null);
    } on FeatureFlagsConflict catch (e, st) {
      // The decision is stale, the row is untouched: read it again and
      // let the preview recompute from it. The old delta is not replayed.
      TraceLogger.instance.warn('workspace', 'process change conflicted',
          error: e, stackTrace: st);
      ref.invalidate(myWorkspacesProvider);
      try {
        await ref.read(myWorkspacesProvider.future);
      } catch (e, st) {
        TraceLogger.instance.warn('workspace',
            'refetch after a process-change conflict failed',
            error: e, stackTrace: st);
      }
      if (mounted) setState(() => _conflict = true);
    } on FeatureFlagsUnconfirmed catch (e, st) {
      TraceLogger.instance.warn('workspace', 'process change unconfirmed',
          error: e, stackTrace: st);
      if (mounted) setState(() => _unconfirmed = true);
    } catch (e, st) {
      TraceLogger.instance.error('workspace', 'process change failed',
          error: e, stackTrace: st);
      if (mounted) {
        AppSnack.error(
          context,
          AppLocalizations.of(context)?.processChangeFailed ??
              'The features could not be changed. Nothing was written; '
                  'try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (workspace == null) {
      return const SizedBox(height: 200, child: LoadingView());
    }
    // The authoritative current state, every build: after a refetch the
    // chain holds the new row and the preview below is recomputed from it.
    final raw = resolveEnabledFeatures(workspace.featureFlags);
    final plan = planProcessChange(
      raw: raw,
      subprocessKeys: widget.subprocessKeys,
      activate: widget.activate,
      mode: _mode,
    );
    final name = widget.subprocessKeys.length == 1
        ? processLabel(l10n, widget.subprocessKeys.single)
        : processLabel(l10n, widget.processKey);
    final title = widget.activate
        ? (l10n?.processSheetTitleOn(name) ?? 'Switch on $name')
        : (l10n?.processSheetTitleOff(name) ?? 'Switch off $name');
    final refused = plan.isBlocked && _mode == DeactivationMode.refuse;
    final canApply = !_busy && !_unconfirmed && !refused && !plan.nothingToDo;
    final count = plan.flags.length;

    return SafeArea(
      child: SingleChildScrollView(
        padding: AppSpacing.gutterAll,
        child: Column(
          key: const ValueKey('process-change-sheet'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            if (_conflict)
              InlineBanner(
                key: const ValueKey('process-change-conflict'),
                icon: Icons.sync_problem_outlined,
                severity: InlineBannerSeverity.info,
                text: l10n?.processConflict ??
                    'Someone changed the features meanwhile. This is the '
                        'updated preview — check it again.',
              ),
            if (_unconfirmed)
              InlineBanner(
                key: const ValueKey('process-change-unconfirmed'),
                icon: Icons.help_outline,
                text: l10n?.processUnconfirmed ??
                    'The change was written, but the app could not confirm '
                        'it. Close and reopen the features to see the '
                        'current state.',
              ),
            if (plan.nothingToDo)
              Text(
                l10n?.processNothingToDo ??
                    'Already the case — nothing to change.',
                key: const ValueKey('process-change-nothing'),
              )
            else if (widget.activate)
              ..._activation(l10n, plan)
            else
              ..._deactivation(l10n, plan),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const ValueKey('process-change-confirm'),
              onPressed: canApply ? () => _apply(plan) : null,
              child: Text(widget.activate
                  ? (l10n?.processConfirmOn(count) ??
                      'Switch on $count features')
                  : (l10n?.processConfirmOff(count) ??
                      'Switch off $count features')),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _activation(AppLocalizations? l10n, ProcessChangePlan plan) {
    final on = <ResolvedCapability>[];
    final needed = <ResolvedCapability>[];
    final already = <ResolvedCapability>[];
    for (final c in plan.changeSet.capabilities) {
      switch (c.reason) {
        case CapabilityReason.selected:
          on.add(c);
        case CapabilityReason.prerequisite:
          needed.add(c);
        case CapabilityReason.alreadyActive:
          already.add(c);
      }
    }
    return [
      _Section(
        keyName: 'on',
        title: l10n?.processSectionSwitchedOn ?? 'Switched on',
        rows: [for (final c in on) _row(l10n, c.feature)],
      ),
      _Section(
        keyName: 'needed',
        title: l10n?.processSectionAlsoNeeded ?? 'Also needed',
        rows: [
          for (final c in needed)
            _row(
              l10n,
              c.feature,
              detail: l10n?.processNeededBy(
                      c.neededBy.map((f) => featureName(l10n, f)).join(', ')) ??
                  'needed by ${c.neededBy.map((f) => featureName(l10n, f)).join(', ')}',
            ),
        ],
      ),
      _Section(
        keyName: 'works-again',
        title: l10n?.processSectionWorksAgain ?? 'Works again',
        rows: [for (final f in plan.revived) _row(l10n, f)],
      ),
      _Section(
        keyName: 'already',
        title: l10n?.processSectionAlreadyOn ?? 'Already on',
        rows: [for (final c in already) _row(l10n, c.feature)],
      ),
    ];
  }

  List<Widget> _deactivation(AppLocalizations? l10n, ProcessChangePlan plan) {
    final refused = plan.isBlocked && _mode == DeactivationMode.refuse;
    final dependants = {
      for (final b in plan.changeSet.blockedBy) ...b.orphans,
    }.length;
    return [
      if (refused) ...[
        for (final b in plan.changeSet.blockedBy)
          InlineBanner(
            key: ValueKey('process-change-blocked-${b.feature.name}'),
            icon: Icons.link,
            severity: InlineBannerSeverity.info,
            text: l10n?.processBlockedIntro(
                    featureName(l10n, b.feature),
                    b.orphans.map((f) => featureName(l10n, f)).join(', ')) ??
                '${featureName(l10n, b.feature)} is still needed by: '
                    '${b.orphans.map((f) => featureName(l10n, f)).join(', ')}',
          ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const ValueKey('process-change-keep'),
          onPressed: _busy
              ? null
              : () => setState(() => _mode = DeactivationMode.keepDependants),
          child: Text(l10n?.processKeepDependants ??
              'Switch off anyway, keep their settings'),
        ),
        OutlinedButton(
          key: const ValueKey('process-change-remove'),
          onPressed: _busy
              ? null
              : () =>
                  setState(() => _mode = DeactivationMode.removeDependants),
          child: Text(l10n?.processRemoveDependants(dependants) ??
              'Also switch off the $dependants dependants'),
        ),
      ] else ...[
        _Section(
          keyName: 'off',
          title: l10n?.processSectionSwitchedOff ?? 'Switched off',
          rows: [
            for (final f in plan.written)
              if (!plan.alsoOff.contains(f)) _row(l10n, f),
          ],
        ),
        _Section(
          keyName: 'kept',
          title: l10n?.processSectionKeptWaiting ??
              'Stops working; its setting is kept',
          rows: [for (final f in plan.heldBack) _row(l10n, f)],
        ),
        _Section(
          keyName: 'also-off',
          title: l10n?.processSectionAlsoOff ?? 'Also switched off',
          rows: [for (final f in plan.alsoOff) _row(l10n, f)],
        ),
      ],
    ];
  }

  Widget _row(AppLocalizations? l10n, WorkspaceFeature feature,
      {String? detail}) {
    final home = homeProcessOf(feature);
    final elsewhere = home != null && home != widget.processKey
        ? (l10n?.processInProcess(processLabel(l10n, home)) ??
            'in ${processLabel(l10n, home)}')
        : null;
    final subtitle = [?detail, ?elsewhere].join(' · ');
    return ListTile(
      key: ValueKey('process-change-${feature.name}'),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(elsewhere == null
          ? Icons.subdirectory_arrow_right
          : Icons.call_split_outlined),
      title: Text(featureName(l10n, feature)),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
    );
  }
}

/// A titled group of rows; nothing at all when the group is empty, so the
/// sheet never lists a heading with nothing under it.
class _Section extends StatelessWidget {
  const _Section({
    required this.keyName,
    required this.title,
    required this.rows,
  });

  final String keyName;
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      key: ValueKey('process-change-section-$keyName'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            '$title (${rows.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        ...rows,
      ],
    );
  }
}
