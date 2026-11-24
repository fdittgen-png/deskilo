// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- Me › Finances, the invoices a business made out to the account as
// a CUSTOMER, read through a billing-access grant (`access: billing_grant`).
// One card per business and financial subject: two debtors of one seller and
// one currency stay two cards, each with its own open amount per currency.
// None of it is counted with what the account owes as a member, and nothing
// here pays: the payment commands accept the grant later (#4165).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/finance_overview.dart';
import '../../providers/billing_customer_providers.dart';
import '../../providers/finance_overview_provider.dart';
import 'billing_access_accept_dialog.dart';
import 'finance_document_views.dart'
    show financeDueText, financePaymentStateText;

/// What closes the Outstanding tab: the documents read through a grant, when
/// there are any, and the door to a code a business handed out.
class BilledPart extends ConsumerWidget {
  const BilledPart({super.key, required this.groups, required this.now});

  final List<BilledSubject> groups;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (groups.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        BilledSection(groups: groups, now: now),
      ],
      const SizedBox(height: AppSpacing.md),
      OutlinedButton.icon(
        key: const ValueKey('billing-access-enter'),
        icon: const Icon(Icons.key_outlined),
        label: Text(context.l10n.billingAccessEnter),
        onPressed: () async {
          final accepted = await showBillingAccessAcceptDialog(
            context,
            commands: ref.read(billingAccessCommandProvider),
          );
          if (accepted) ref.invalidate(financeOverviewProvider);
        },
      ),
    ],
  );
}

class BilledSection extends StatelessWidget {
  const BilledSection({super.key, required this.groups, required this.now});

  final List<BilledSubject> groups;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('billed-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.billingAccessSectionTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            HelpDot(
              l10n.billingAccessSectionTitle,
              anchor: HelpAnchor.moneyBilledToYou,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.billingAccessSectionNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        for (final g in groups)
          _BilledCard(
            key: ValueKey('billed-${g.networkId}-${g.subjectId}'),
            group: g,
            now: now,
          ),
        Text(l10n.billingAccessPaymentSoon, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _BilledCard extends StatelessWidget {
  const _BilledCard({super.key, required this.group, required this.now});

  final BilledSubject group;
  final DateTime now;

  /// A short reference of the subject, so two accounts of one business differ.
  String get _ref {
    final id = group.subjectId;
    return id.length <= 6 ? id : id.substring(id.length - 6);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final money = personalFormatOf(context);
    final dates = money.dates(DateShape.date);
    final open = group.openByCurrency;
    return Card(
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.billingAccessGroupTitle(group.workspaceName, _ref),
              style: theme.textTheme.titleSmall,
            ),
            Text(
              open.isEmpty
                  ? l10n.billingAccessGroupSettled
                  : l10n.billingAccessGroupOpen(
                      [
                        for (final e in open.entries)
                          money.moneyNamed(e.key).formatMinor(e.value),
                      ].join(' · '),
                    ),
              key: ValueKey(
                'billed-open-${group.networkId}-${group.subjectId}',
              ),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final i in group.invoices)
              ListTile(
                key: ValueKey('billed-invoice-${i.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(i.number),
                subtitle: Text(
                  i.state.owed && i.dueOn != null
                      ? financeDueText(l10n, i, dates.format(i.dueOn!), now)
                      : financePaymentStateText(l10n, i),
                ),
                trailing: Text(
                  money
                      .moneyNamed(i.currency)
                      .formatMinor(
                        i.state.owed ? i.remainingCents : i.totalCents,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
