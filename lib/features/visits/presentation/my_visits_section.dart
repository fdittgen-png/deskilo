// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1835 — Me › Home › My visits: the account's guest visits, every space,
// newest first, each saying in one line that it is a visit and not a
// membership. The guest's one action is to cancel what still lies ahead;
// the server answers, and the list re-reads what it holds.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/guest_participation.dart';
import '../providers/visits_providers.dart';

class MyVisitsSection extends ConsumerWidget {
  const MyVisitsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final visits =
        ref.watch(myGuestVisitsProvider).value ?? const <GuestParticipation>[];
    if (visits.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('me-visits'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.myVisitsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          l10n.myVisitsHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final visit in visits) _VisitCard(visit: visit),
      ],
    );
  }
}

class _VisitCard extends ConsumerStatefulWidget {
  const _VisitCard({required this.visit});

  final GuestParticipation visit;

  @override
  ConsumerState<_VisitCard> createState() => _VisitCardState();
}

class _VisitCardState extends ConsumerState<_VisitCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() => _busy = true);
    final l10n = context.l10n;
    GuestVisitCancelOutcome? outcome;
    await runGuarded(
      context,
      domain: 'visits',
      message: 'visit cancel failed',
      action: () async => outcome = await ref
          .read(guestVisitActionsProvider)
          .cancel(widget.visit.id),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (outcome == GuestVisitCancelOutcome.refused) {
      AppSnack.error(
        context,
        l10n.visitCancelFailed,
      );
    }
    // Whatever the server answered, the list shows what it holds now.
    ref.invalidate(myGuestVisitsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final visit = widget.visit;
    final material = MaterialLocalizations.of(context);
    final starts = visit.startsAt.toLocal();
    final ends = visit.endsAt.toLocal();
    final when =
        '${material.formatMediumDate(starts)} · '
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(starts))}–'
        '${material.formatTimeOfDay(TimeOfDay.fromDateTime(ends))}';
    final where = visit.siteName == null || visit.siteName!.isEmpty
        ? visit.workspaceName
        : '${visit.workspaceName} · ${visit.siteName}';
    final note = l10n.visitGuestNote;
    return Card(
      key: ValueKey('me-visit-${visit.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    where,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Chip(
                  key: ValueKey('me-visit-status-${visit.status.name}'),
                  label: Text(_guestVisitStatusLabel(l10n, visit.status)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(when),
            Text(note, style: Theme.of(context).textTheme.bodySmall),
            if (visit.status.cancellable)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  key: ValueKey('me-visit-cancel-${visit.id}'),
                  onPressed: _busy ? null : _cancel,
                  child: Text(l10n.visitCancel),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One word per status, in the reader's language; an unknown status is
/// shown as the server sent it, never as something it is not.
String _guestVisitStatusLabel(AppLocalizations l10n, GuestVisitStatus status) =>
    switch (status) {
      GuestVisitStatus.requested => l10n.visitStatusRequested,
      GuestVisitStatus.confirmed => l10n.visitStatusConfirmed,
      GuestVisitStatus.declined => l10n.visitStatusDeclined,
      GuestVisitStatus.cancelled => l10n.visitStatusCancelled,
      GuestVisitStatus.expired => l10n.visitStatusExpired,
      GuestVisitStatus.unknown => '?',
    };
