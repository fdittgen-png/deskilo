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
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/i18n/time_zones.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/theme/personal_theme.dart';
import '../../../core/time/clock.dart';
import '../../../core/ui/inline_banner.dart';
import '../../reservations/domain/my_reservations.dart';
import '../../reservations/domain/my_reservations_composition.dart';
import '../../reservations/presentation/widgets/my_reservations_body.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../application/personal_overview.dart';
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
    child: InlineBanner(
      icon: Icons.cloud_off_outlined,
      text: text,
      actionLabel: context.l10n.commonRetry,
      onAction: onRetry,
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
    final format = ref.watch(appFormatProvider);
    final composer = ref.read(myReservationsComposerProvider(query).notifier);
    final entry = next.entry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slot in next.failed)
          SourceUnavailable(
            key: ValueKey('me-overview-next-failed-${slot.installationId}'),
            text: l10n.meOverviewNextHostFailed(
              slot.source.labels.isEmpty
                  ? l10n.myReservationsSourceUnnamed
                  : slot.source.labels.join(', '),
            ),
            onRetry: () => composer.retry(slot.installationId),
          ),
        if (next.reading)
          const SectionLoading(key: ValueKey('me-overview-next-loading'))
        else if (entry != null)
          _Commitment(entry: entry, format: format)
        else if (next.complete)
          Text(
            l10n.meOverviewNextNone(
              format.date(window.from),
              format.date(window.lastDay),
            ),
            key: const ValueKey('me-overview-next-none'),
          )
        else if (next.failed.isEmpty)
          Text(
            l10n.meOverviewNextNotYet,
            key: const ValueKey('me-overview-next-not-yet'),
          ),
        if (!next.reading && (entry != null || !next.complete))
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              key: const ValueKey('me-overview-next-view'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, PersonalShellMetrics.minTarget),
              ),
              onPressed: () =>
                  context.go(meDataRoute(view: MeDataView.reservations)),
              child: Text(l10n.meOverviewView),
            ),
          ),
      ],
    );
  }
}

/// One booking: what and where, its day and hours in its workspace's own
/// zone (named when it is not the device's), and where it stands.
class _Commitment extends StatelessWidget {
  const _Commitment({required this.entry, required this.format});

  final MyReservationEntry entry;
  final AppFormat format;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = PersonalTheme.of(context);
    final item = entry.item;
    final zone = entry.zone;
    final known = zone != null && TimeZones.isKnown(zone);
    DateTime wall(DateTime instant) => known
        ? tz.TZDateTime.from(instant, tz.getLocation(zone))
        : instant.toLocal();
    final start = wall(item.startsAt);
    final end = wall(item.endsAt);
    final showZone =
        known && start.timeZoneOffset != item.startsAt.toLocal().timeZoneOffset;
    final place = item.placeLabel.isEmpty
        ? l10n.myReservationsUnnamedPlace
        : item.placeLabel;
    final day = DateFormat.MMMEd(format.locale).format(start);
    final secondary = theme.textTheme.bodySmall?.copyWith(
      color: tokens.secondaryText,
    );
    return Column(
      key: ValueKey('me-overview-next-${entry.source}-${item.id}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(myReservationKindIcon(item.placeKind), color: tokens.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(place, style: theme.textTheme.titleMedium?.strong),
            ),
            Text(
              myReservationStatusWords(l10n, item.status),
              style: theme.textTheme.labelLarge,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          '$day · ${format.wallTime(start)}–${format.wallTime(end)}',
          style: theme.textTheme.bodyLarge,
        ),
        Text(
          '${myReservationKindWords(l10n, item.placeKind)} · ${item.workspaceName}',
          style: secondary,
        ),
        if (showZone) Text(l10n.meOverviewNextZone(zone), style: secondary),
      ],
    );
  }
}
