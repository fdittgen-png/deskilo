// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "approvals": the preset "the owner or an administrator
// approves" becomes the workspace's default rule through
// [ApplyApprovalsPreset], with the number of approvals the owner asks for.
// The flow is drawn in words (request, who approves, outcome) beside the
// number of people who can approve; a number above them is refused with
// the reason, because such a rule holds its requests forever. The preview
// is what a member reads once a request is sent, and follows the count.
// The rules a request type has of its own are listed below, each with
// whether it can be satisfied, and are changed in the rule editor: a
// short one keeps the step open on the server until it is fixed there.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../application/apply_approvals_preset.dart';
import '../../domain/approvals_preset.dart';
import '../../domain/rule_reach.dart';
import '../../domain/validation_policy.dart';
import '../../providers/event_providers.dart';
import 'setup_approvals_flow.dart';
import 'setup_approvals_own_rules.dart';

/// The most approvals the step offers, as the rule editor does.
const int _maxRequired = 10;

class SetupApprovalsStep extends ConsumerWidget {
  const SetupApprovalsStep({
    super.key,
    required this.workspaceId,
    required this.members,
  });

  final String workspaceId;

  /// The active members.
  final List<Decider> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(validationPoliciesProvider)) {
        AsyncValue(hasValue: true, :final value) => _ApprovalsPage(
          workspaceId: workspaceId,
          preset: ApprovalsPreset(
            owners: members.where((m) => m.isOwner).length,
            admins: members.where((m) => m.isAdmin && !m.isOwner).length,
          ),
          stored: value?.where((p) => p.eventType == null).firstOrNull,
          ownRules: [
            for (final p in value ?? const <ValidationPolicy>[])
              if (p.eventType != null) p,
          ],
          members: members,
        ),
        AsyncError() => Padding(
          padding: AppSpacing.lgAll,
          child: InlineBanner(
            key: const ValueKey('setup-approvals-failed'),
            icon: Icons.error_outline,
            text: context.l10n.setupStepLoadFailed,
          ),
        ),
        _ => const LoadingView(),
      };
}

class _ApprovalsPage extends ConsumerStatefulWidget {
  const _ApprovalsPage({
    required this.workspaceId,
    required this.preset,
    required this.stored,
    required this.ownRules,
    required this.members,
  });

  final String workspaceId;
  final ApprovalsPreset preset;

  /// The stored default rule; null while the built-in one applies.
  final ValidationPolicy? stored;

  /// The stored rules of a request type of their own.
  final List<ValidationPolicy> ownRules;
  final List<Decider> members;

  @override
  ConsumerState<_ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends ConsumerState<_ApprovalsPage> {
  late final _required = ValueNotifier<int>(
    (widget.stored?.requiredCount ?? 1).clamp(1, _maxRequired),
  );
  final _busy = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _required.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final l10n = context.l10n;
    _busy.value = true;
    final ok = await runGuarded(
      context,
      domain: 'events',
      message: 'setup approvals preset failed',
      errorText: l10n.setupApprovalsApplyFailed,
      action: () => ref
          .read(applyApprovalsPresetProvider)
          .apply(
            widget.workspaceId,
            widget.preset,
            stored: widget.stored,
            requiredCount: _required.value,
          ),
    );
    ref.invalidate(validationPoliciesProvider);
    if (!mounted) return;
    _busy.value = false;
    if (ok) AppSnack.success(context, l10n.validationSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SetupStepLayout(
      form: ListenableBuilder(
        listenable: Listenable.merge([_required, _busy]),
        builder: (context, _) {
          final count = _required.value;
          final reachable = widget.preset.reachable(count);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.setupStepHint('approvals')),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.setupApprovalsPresetTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.setupApprovalsPresetBody),
              const SizedBox(height: AppSpacing.md),
              SetupApprovalsFlow(preset: widget.preset, required: count),
              const SizedBox(height: AppSpacing.md),
              _QuorumField(
                key: const ValueKey('setup-approvals-quorum'),
                count: count,
                busy: _busy.value,
                onChanged: (n) => _required.value = n,
              ),
              Text(
                l10n.setupApprovalsPeople(widget.preset.people),
                key: const ValueKey('setup-approvals-people'),
              ),
              if (!reachable) ...[
                const SizedBox(height: AppSpacing.sm),
                InlineBanner(
                  key: const ValueKey('setup-approvals-too-many'),
                  icon: Icons.group_off_outlined,
                  text: l10n.setupApprovalsTooMany(count, widget.preset.people),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton(
                  key: const ValueKey('setup-approvals-apply'),
                  onPressed: reachable && !_busy.value ? _apply : null,
                  child: Text(l10n.setupApprovalsApply),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SetupApprovalsOwnRules(
                rules: widget.ownRules,
                members: widget.members,
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('setup-approvals-open-rules'),
                  onPressed: () => context.push('/validation'),
                  child: Text(l10n.setupApprovalsOpenRules),
                ),
              ),
            ],
          );
        },
      ),
      preview: ValueListenableBuilder<int>(
        valueListenable: _required,
        builder: (context, count, _) =>
            SetupApprovalsMemberView(required: count),
      ),
    );
  }
}

/// How many approvals a request needs, one step at a time.
class _QuorumField extends StatelessWidget {
  const _QuorumField({
    super.key,
    required this.count,
    required this.busy,
    required this.onChanged,
  });

  final int count;
  final bool busy;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(child: Text(l10n.validationRequiredCount)),
        IconButton(
          key: const ValueKey('setup-approvals-decrease'),
          tooltip: l10n.a11yDecrease,
          icon: const Icon(Icons.remove),
          onPressed: !busy && count > 1 ? () => onChanged(count - 1) : null,
        ),
        Text(
          '$count',
          key: const ValueKey('setup-approvals-count'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          key: const ValueKey('setup-approvals-increase'),
          tooltip: l10n.a11yIncrease,
          icon: const Icon(Icons.add),
          onPressed: !busy && count < _maxRequired
              ? () => onChanged(count + 1)
              : null,
        ),
      ],
    );
  }
}
