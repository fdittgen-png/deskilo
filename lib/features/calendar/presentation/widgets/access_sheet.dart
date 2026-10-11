// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/calendar/calendar_item.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/loading_view.dart';
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
    showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AccessSheet(),
    );

class _AccessSheet extends ConsumerWidget {
  const _AccessSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
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
        ? (l10n.accessNobodyElse)
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
                l10n.calendarWhoCanSee,
                style: theme.textTheme.titleMedium,
              ),
            ),
            switch (access) {
              AsyncData(:final value) => Column(children: [
                  rule(
                    CalendarKind.reservation,
                    l10n.accessRuleReservations,
                  ),
                  rule(
                    CalendarKind.event,
                    l10n.accessRuleEvents,
                  ),
                  rule(
                    CalendarKind.message,
                    l10n.accessRuleMessages,
                  ),
                  rule(
                    CalendarKind.invoice,
                    l10n.accessRuleFinances(people(value.finances)),
                  ),
                  // #914 — who administers my profile, while it is
                  // still a managed one. Once it is mine the list is
                  // empty and the row says so, which is the answer.
                  if (value.profile.isNotEmpty)
                    ListTile(
                      key: const ValueKey('access-rule-profile'),
                      leading: const Icon(Icons.contact_mail_outlined),
                      title: Text(l10n.accessKindProfile),
                      subtitle: Text(
                        l10n.accessRuleManagedProfile(
                                people(value.profile)),
                      ),
                    ),
                  if (negotiationsOn)
                    ListTile(
                      key: const ValueKey('access-rule-negotiations'),
                      leading: const Icon(Icons.handshake_outlined),
                      title: Text(l10n.accessKindNegotiations),
                      subtitle: Text(
                        l10n.accessRuleNegotiations(
                                people(value.negotiations)),
                      ),
                    ),
                  rule(
                    CalendarKind.reminder,
                    l10n.accessRuleReminders,
                  ),
                ]),
              AsyncError() => Padding(
                  padding: AppSpacing.lgAll,
                  child: Text(l10n.workspaceGenericError),
                ),
              _ => const LoadingView(),
            },
            if (logOn) ...[
              const Divider(),
              Padding(
                padding: AppSpacing.lgAll,
                child: Text(
                  l10n.accessLogTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              switch (log) {
                AsyncData(value: final entries) when entries.isEmpty => Padding(
                    padding: AppSpacing.lgH,
                    child: Text(
                      l10n.accessLogEmpty,
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
                          l10n.accessLogRow(
                                names[e.actorMemberId] ?? '',
                                switch (e.category) {
                                  'negotiations' =>
                                    l10n.accessKindNegotiations,
                                  // #914 — a read of a managed profile.
                                  'profile' => l10n.accessKindProfile,
                                  _ => e.category,
                                },
                                names[e.subjectMemberId] ?? '',
                              ),
                        ),
                        subtitle: Text(format.dateTime(e.at)),
                      ),
                  ]),
                AsyncError() => Padding(
                    padding: AppSpacing.lgH,
                    child: Text(l10n.workspaceGenericError),
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
