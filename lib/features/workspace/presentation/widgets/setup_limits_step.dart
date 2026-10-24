// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "booking limits": how many places a member holds at once,
// how far ahead they book, and the shortest and the longest booking — the
// availability screen's own rows, prefilled with the stored rules (or the
// values the server falls back to) and saved together through
// [SaveBookingLimits]. The preview is what a member reads: the limits in
// plain sentences, as they will meet them when they book.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../application/save_booking_limits.dart';
import '../../domain/booking_policies.dart';
import '../../domain/workspace.dart';
import '../../providers/workspace_providers.dart';
import 'availability_tiles.dart';
import 'setup_limit_row.dart';

class SetupLimitsStep extends ConsumerStatefulWidget {
  const SetupLimitsStep({super.key, required this.workspace});

  final Workspace workspace;

  @override
  ConsumerState<SetupLimitsStep> createState() => _SetupLimitsStepState();
}

class _SetupLimitsStepState extends ConsumerState<SetupLimitsStep> {
  /// What the owner set on this page; null until they touch a row, so the
  /// rows show the stored limits until then.
  final _draft = ValueNotifier<BookingPolicies?>(null);
  final _busy = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _draft.dispose();
    _busy.dispose();
    super.dispose();
  }

  Future<void> _save(BookingPolicies stored, BookingPolicies limits) async {
    final l10n = context.l10n;
    _busy.value = true;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'setup booking limits failed',
      errorText: l10n.setupLimitsSaveFailed,
      action: () => ref
          .read(saveBookingLimitsProvider)
          .save(widget.workspace.id, from: stored, to: limits),
    );
    ref.invalidate(bookingPoliciesProvider);
    if (!mounted) return;
    _busy.value = false;
    if (!ok) return;
    _draft.value = null;
    AppSnack.success(context, l10n.workspaceSettingsSaved);
  }

  @override
  Widget build(BuildContext context) =>
      switch (ref.watch(bookingPoliciesProvider)) {
        AsyncValue(hasValue: true, :final value?) => ListenableBuilder(
          listenable: Listenable.merge([_draft, _busy]),
          builder: (context, _) {
            final limits = _draft.value ?? value;
            return SetupStepLayout(
              form: _form(context, stored: value, limits: limits),
              preview: _Preview(limits: limits),
            );
          },
        ),
        AsyncError() => Padding(
          padding: AppSpacing.lgAll,
          child: InlineBanner(
            key: const ValueKey('setup-limits-failed'),
            icon: Icons.error_outline,
            text: context.l10n.setupStepLoadFailed,
            actionLabel: context.l10n.commonRetry,
            onAction: () => ref.invalidate(bookingPoliciesProvider),
          ),
        ),
        _ => const LoadingView(),
      };

  Widget _form(
    BuildContext context, {
    required BookingPolicies stored,
    required BookingPolicies limits,
  }) {
    final l10n = context.l10n;
    final busy = _busy.value;
    void edit(BookingPolicies next) {
      if (!busy) _draft.value = next;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupStepHint('limits')),
        const SizedBox(height: AppSpacing.md),
        SetupLimitRow(
          key: const ValueKey('setup-limits-simultaneous'),
          icon: Icons.event_seat_outlined,
          title: l10n.policySimultaneousTitle,
          description: l10n.policySimultaneousDesc,
          control: _Stepper(
            key: const ValueKey('setup-limits-simultaneous-stepper'),
            value: limits.simultaneousReservations,
            onChanged: (v) =>
                edit(limits.copyWith(simultaneousReservations: v)),
          ),
        ),
        SetupLimitRow(
          key: const ValueKey('setup-limits-horizon'),
          icon: Icons.event_available_outlined,
          title: l10n.policyHorizonTitle,
          description: l10n.policyHorizonDesc,
          control: SetupLimitDropdown(
            dropdownKey: 'setup-limits-horizon-dropdown',
            value: limits.advanceHorizonDays,
            options: horizonOptions,
            format: l10n.policyDaysValue,
            onChanged: (v) => edit(limits.copyWith(advanceHorizonDays: v)),
          ),
        ),
        SetupLimitRow(
          key: const ValueKey('setup-limits-min-duration'),
          icon: Icons.hourglass_bottom_outlined,
          title: l10n.policyMinDurationTitle,
          description: l10n.policyMinDurationDesc,
          control: SetupLimitDropdown(
            dropdownKey: 'setup-limits-min-duration-dropdown',
            value: limits.minDurationMinutes,
            options: durationOptions,
            format: (v) => formatDuration(l10n, v),
            onChanged: (v) => edit(limits.copyWith(minDurationMinutes: v)),
          ),
        ),
        SetupLimitRow(
          key: const ValueKey('setup-limits-max-duration'),
          icon: Icons.hourglass_top_outlined,
          title: l10n.policyMaxDurationTitle,
          description: l10n.policyMaxDurationDesc,
          control: SetupLimitDropdown(
            dropdownKey: 'setup-limits-max-duration-dropdown',
            value: limits.maxDurationMinutes,
            options: durationOptions,
            format: (v) => formatDuration(l10n, v),
            onChanged: (v) => edit(limits.copyWith(maxDurationMinutes: v)),
          ),
        ),
        if (!limits.durationsAreCoherent)
          Text(
            l10n.policyDurationConflict,
            key: const ValueKey('setup-limits-conflict'),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.setupLimitsPerMember,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            key: const ValueKey('setup-limits-save'),
            onPressed:
                busy || _draft.value == null || !limits.durationsAreCoherent
                ? null
                : () => _save(stored, limits),
            child: Text(l10n.commonSave),
          ),
        ),
      ],
    );
  }
}

/// The limits as a member meets them when they book.
class _Preview extends StatelessWidget {
  const _Preview({required this.limits});

  final BookingPolicies limits;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: const ValueKey('setup-limits-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.setupLimitsPreviewAhead(limits.advanceHorizonDays),
          key: const ValueKey('setup-limits-preview-ahead'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.setupLimitsPreviewLength(
            formatDuration(l10n, limits.minDurationMinutes),
            formatDuration(l10n, limits.maxDurationMinutes),
          ),
          key: const ValueKey('setup-limits-preview-length'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.setupLimitsPreviewAtOnce(limits.simultaneousReservations),
          key: const ValueKey('setup-limits-preview-at-once'),
        ),
      ],
    );
  }
}

/// How many places a member holds at once, one more or one fewer, within
/// the bounds the server checks.
class _Stepper extends StatelessWidget {
  const _Stepper({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const ValueKey('setup-limits-simultaneous-minus'),
          tooltip: l10n.a11yDecrease,
          icon: const Icon(Icons.remove),
          onPressed: value > BookingPolicies.defaultSimultaneous
              ? () => onChanged(value - 1)
              : null,
        ),
        Text(
          NumberFormat.decimalPattern(
            Localizations.localeOf(context).toLanguageTag(),
          ).format(value),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        IconButton(
          key: const ValueKey('setup-limits-simultaneous-plus'),
          tooltip: l10n.a11yIncrease,
          icon: const Icon(Icons.add),
          onPressed: value < BookingPolicies.maxSimultaneous
              ? () => onChanged(value + 1)
              : null,
        ),
      ],
    );
  }
}
