// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/calendar_providers.dart';
import 'calendar_item_row.dart';

/// "Who can see this — and who did" (#719).
///
/// GDPR gives a member the right to know who may look at their data
/// and who actually did. Both answers live here, on the screen where
/// the data is: per kind, the RULE in a sentence and the concrete
/// PEOPLE it currently names; then the access log, newest first.
Future<void> showAccessSheet(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AccessSheet(),
    );

class AccessSheet extends ConsumerWidget {
  const AccessSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final access = ref.watch(whoCanAccessMeProvider);
    final log = ref.watch(dataAccessLogProvider);
    final format = ref.watch(appFormatProvider);
    final features = ref.watch(enabledFeaturesSyncProvider);
    final logOn = features.contains(WorkspaceFeature.dataAccessLog);
    final negotiationsOn =
        features.contains(WorkspaceFeature.priceNegotiations);

    String people(List<String> ids) => ids.isEmpty
        ? (l10n?.accessNobodyElse ?? 'nobody else')
        : ids.map((id) => names[id] ?? '').where((n) => n.isNotEmpty).join(', ');

    Widget rule(CalendarKind kind, String text) => ListTile(
          leading: Icon(calendarKindIcon(kind)),
          title: Text(calendarKindLabel(l10n, kind)),
          subtitle: Text(text),
        );

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: ListView(
          key: const ValueKey('access-sheet'),
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            Padding(
              padding: AppSpacing.lgAll,
              child: Text(
                l10n?.calendarWhoCanSee ?? 'Who can see this',
                style: theme.textTheme.titleMedium,
              ),
            ),
            switch (access) {
              AsyncData(:final value) => Column(children: [
                  rule(
                    CalendarKind.reservation,
                    l10n?.accessRuleReservations ??
                        'Every member of the workspace — the floor plan shows '
                            'occupancy to everyone.',
                  ),
                  rule(
                    CalendarKind.event,
                    l10n?.accessRuleEvents ??
                        'You, the member who acted, and the admins.',
                  ),
                  rule(
                    CalendarKind.message,
                    l10n?.accessRuleMessages ??
                        'Only the people in the conversation — no role can '
                            'read a conversation it is not part of.',
                  ),
                  rule(
                    CalendarKind.invoice,
                    l10n?.accessRuleFinances(people(value.finances)) ??
                        'You, and those with the finance permission: '
                            '${people(value.finances)}.',
                  ),
                  if (negotiationsOn)
                    ListTile(
                      key: const ValueKey('access-rule-negotiations'),
                      leading: const Icon(Icons.handshake_outlined),
                      title: Text(l10n?.accessKindNegotiations ??
                          'Price negotiations'),
                      subtitle: Text(
                        l10n?.accessRuleNegotiations(
                                people(value.negotiations)) ??
                            'You, the owners and the finance admins: '
                                '${people(value.negotiations)}. Every read '
                                'by someone else is on the record below.',
                      ),
                    ),
                  rule(
                    CalendarKind.reminder,
                    l10n?.accessRuleReminders ?? 'Only you.',
                  ),
                ]),
              AsyncError() => Padding(
                  padding: AppSpacing.lgAll,
                  child: Text(l10n?.workspaceGenericError ??
                      'Something went wrong. Please try again.'),
                ),
              _ => const LoadingView(),
            },
            if (logOn) ...[
              const Divider(),
              Padding(
                padding: AppSpacing.lgAll,
                child: Text(
                  l10n?.accessLogTitle ?? 'Who accessed your data',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              switch (log) {
                AsyncData(value: final entries) when entries.isEmpty => Padding(
                    padding: AppSpacing.lgH,
                    child: Text(
                      l10n?.accessLogEmpty ??
                          'Nobody has looked at your finances or messages.',
                      key: const ValueKey('access-log-empty'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                AsyncData(value: final entries) => Column(children: [
                    for (final e in entries.take(100))
                      ListTile(
                        key: ValueKey('access-log-${e.id}'),
                        dense: true,
                        leading: const Icon(Icons.visibility_outlined),
                        title: Text(
                          l10n?.accessLogRow(
                                names[e.actorMemberId] ?? '',
                                e.category == 'negotiations'
                                    ? l10n.accessKindNegotiations
                                    : e.category,
                                names[e.subjectMemberId] ?? '',
                              ) ??
                              '${names[e.actorMemberId] ?? ''} read '
                                  '${e.category} of ${names[e.subjectMemberId] ?? ''}',
                        ),
                        subtitle: Text(format.dateTime(e.at)),
                      ),
                  ]),
                AsyncError() => Padding(
                    padding: AppSpacing.lgH,
                    child: Text(l10n?.workspaceGenericError ??
                        'Something went wrong. Please try again.'),
                  ),
                _ => const LoadingView(),
              },
            ],
          ],
        ),
      ),
    );
  }
}
