// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 C2 — the Overview's Next commitment section, and the frame every
// section shares. Each source has its own state: a read in progress, a
// failure with its own Try again, a host that did not answer said beside
// what the others answered. A successful empty answer is said for what it
// covers, never as "nothing at all".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/i18n/time_zones.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/personal_theme.dart';
import '../../../core/time/clock.dart';
import '../../../core/ui/personal_kit/me_notice.dart';
import '../application/personal_commitments.dart';
import '../application/personal_overview.dart';
import '../domain/personal_commitment.dart';
import 'commitment_words.dart';
import 'kit/me_status_chip.dart';
import 'me_data_tab.dart';

/// One section of the Overview: a titled surface, never a button itself.
class OverviewSection extends StatelessWidget {
  const OverviewSection({
    super.key,
    required this.sectionKey,
    required this.title,
    required this.expanded,
    required this.children,
  });

  final String sectionKey;
  final String title;
  final bool expanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = PersonalTheme.of(context);
    final theme = Theme.of(context);
    return Container(
      key: ValueKey(sectionKey),
      width: double.infinity,
      padding: EdgeInsets.all(expanded ? AppSpacing.xl : AppSpacing.lg),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: PersonalShellMetrics.cardRadiusAll,
        border: Border.all(color: tokens.decorativeBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(color: tokens.text),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

/// A source that is still being read.
class SectionLoading extends StatelessWidget {
  const SectionLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: LinearProgressIndicator(),
  );
}

/// A source that could not be read, with its own way to ask again.
class SourceUnavailable extends StatelessWidget {
  const SourceUnavailable({
    super.key,
    required this.text,
    required this.onRetry,
  });

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: MeNotice(
      text: text,
      retryLabel: context.l10n.commonRetry,
      onRetry: onRetry,
    ),
  );
}

/// The earliest own booking still to come, across every workspace host my
/// account names, in the window My reservations starts with.
class NextCommitmentSection extends ConsumerWidget {
  const NextCommitmentSection({super.key, required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final window = ref.watch(myReservationsWindowControllerProvider);
    final value = window.value;
    return OverviewSection(
      sectionKey: 'me-overview-next',
      title: l10n.meOverviewNextTitle,
      expanded: expanded,
      children: [
        if (value != null)
          _NextBody(window: value)
        else if (window.hasError)
          SourceUnavailable(
            key: const ValueKey('me-overview-next-unavailable'),
            text: l10n.meOverviewNextUnavailable,
            // The limits are read again too: a failed read of them is
            // what most often leaves the window without a value.
            onRetry: () => ref
              ..invalidate(myReservationsLimitsProvider)
              ..invalidate(myReservationsWindowControllerProvider),
          )
        else
          const SectionLoading(key: ValueKey('me-overview-next-loading')),
      ],
    );
  }
}

class _NextBody extends ConsumerWidget {
  const _NextBody({required this.window});

  final MyReservationsWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final query = MyReservationsQuery(from: window.from, to: window.to);
    final composed = ref.watch(myReservationsComposerProvider(query));
    final composition = composed.value;
    if (composition == null) {
      return composed.hasError
          ? SourceUnavailable(
              key: const ValueKey('me-overview-next-unavailable'),
              text: l10n.meOverviewNextUnavailable,
              onRetry: () =>
                  ref.invalidate(myReservationsComposerProvider(query)),
            )
          : const SectionLoading(key: ValueKey('me-overview-next-loading'));
    }
    final next = nextCommitmentOf(composition, ref.watch(clockProvider).now());
    final format = ref.watch(personalFormatProvider);
    final composer = ref.read(myReservationsComposerProvider(query).notifier);
    final commitment = next.commitment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slot in next.failed)
          SourceUnavailable(
            key: ValueKey('me-overview-next-failed-${slot.sourceId}'),
            text: l10n.meOverviewNextHostFailed(
              slot.labels.isEmpty
                  ? l10n.myReservationsSourceUnnamed
                  : slot.labels.join(', '),
            ),
            onRetry: () => composer.retry(slot.sourceId),
          ),
        if (next.reading)
          const SectionLoading(key: ValueKey('me-overview-next-loading'))
        else if (commitment != null)
          _Commitment(commitment: commitment, format: format, checkIn: composer.checkIn)
        else if (next.complete)
          const _NothingBooked(key: ValueKey('me-overview-next-none'))
        else if (next.failed.isEmpty)
          Text(
            l10n.meOverviewNextNotYet,
            key: const ValueKey('me-overview-next-not-yet'),
          ),
      ],
    );
  }
}

/// One commitment: what and where, its day and hours in its business's own
/// zone (named when it is not the device's), and where it stands.
class _Commitment extends StatelessWidget {
  const _Commitment({
    required this.commitment,
    required this.format,
    required this.checkIn,
  });

  final PersonalCommitment commitment;
  final AppFormat format;
  final Future<void> Function(String source, String id) checkIn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = PersonalTheme.of(context);
    final c = commitment;
    final zone = c.zone;
    final known = zone != null && TimeZones.isKnown(zone);
    DateTime wall(DateTime instant) => known
        ? tz.TZDateTime.from(instant, tz.getLocation(zone))
        : personalFormatOf(context).wall(instant);
    final start = wall(c.startsAt);
    final end = wall(c.endsAt);
    final showZone =
        known && start.timeZoneOffset != personalFormatOf(context).wall(c.startsAt).timeZoneOffset;
    final place = c.label.isEmpty ? l10n.myReservationsUnnamedPlace : c.label;
    final day = format.dates(DateShape.weekdayMonthDay).format(start);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: tokens.secondaryText,
    );
    final kind = commitmentKindWords(l10n, c);
    return Column(
      key: ValueKey('me-overview-next-${c.source}-${c.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(commitmentIcon(c), color: tokens.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(place, style: theme.textTheme.titleMedium?.strong),
            ),
            MeStatusChip(
              kind: c.state == CommitmentState.ongoing
                  ? MeChipKind.ok
                  : MeChipKind.neutral,
              label: commitmentStateWords(l10n, c.state),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$day · ${format.wallTime(start)}–${format.wallTime(end)}',
          style: theme.textTheme.bodyLarge,
        ),
        Text(
          kind.isEmpty ? c.businessName : '$kind · ${c.businessName}',
          style: secondary,
        ),
        if (showZone) Text(l10n.meOverviewNextZone(zone), style: secondary),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: _NextAction(commitment: c, checkIn: checkIn),
        ),
      ],
    );
  }
}

/// The one filled action of Next up: "Check in" while the window is open
/// (and it checks in), else "Details" (the booking, in My reservations).
class _NextAction extends StatefulWidget {
  const _NextAction({required this.commitment, required this.checkIn});

  final PersonalCommitment commitment;
  final Future<void> Function(String source, String id) checkIn;

  @override
  State<_NextAction> createState() => _NextActionState();
}

class _NextActionState extends State<_NextAction> {
  bool _busy = false;

  Future<void> _checkIn() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final c = widget.commitment;
    setState(() => _busy = true);
    var done = false;
    try {
      await widget.checkIn(c.source, c.id);
      done = true;
    } on Object {
      // The host's refusal is said in words; My reservations says why.
    }
    messenger?.showSnackBar(SnackBar(
      content: Text(done
          ? l10n.myReservationsCheckInDone
          : l10n.myReservationsActionFailed),
    ));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final open = widget.commitment.canCheckIn;
    return FilledButton(
      key: const ValueKey('me-overview-next-action'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, PersonalShellMetrics.minTarget),
      ),
      onPressed: _busy
          ? null
          : open
              ? _checkIn
              : () => context.go(meDataRoute(view: MeDataView.reservations)),
      child: Text(open ? l10n.myReservationsCheckIn : l10n.bookingOpenDetails),
    );
  }
}

/// Nothing booked in the window: one quiet sentence and the one filled
/// action, which opens the places to book in (the Places tab; its rows
/// book one space each).
class _NothingBooked extends StatelessWidget {
  const _NothingBooked({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(child: Text(l10n.meNextNothingWeek)),
        FilledButton(
          key: const ValueKey('me-overview-next-book'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, PersonalShellMetrics.minTarget),
          ),
          onPressed: () => context.go('/me/spaces'),
          child: Text(l10n.meNextBook),
        ),
      ],
    );
  }
}
