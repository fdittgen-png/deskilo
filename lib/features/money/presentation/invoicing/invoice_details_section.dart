// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 train 2, part C -- the page's one collapsed "Details" section: the
// old invoice sheet's own sections, kept reachable from the page.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../application/invoice_detail_facts.dart';
import '../../providers/money_providers.dart';
import '../period_label.dart';
import '../widgets/invoice_detail_sections.dart';

/// Everything the old sheet said that the page does not say in its own words,
/// in one collapsed section: who issued it and to whom it is billed, what kind
/// and which period, the amounts net / VAT / total with paid and remaining,
/// the settlement trail, and the e-invoice's transmission status. It reuses the
/// sheet's own sections, so the two can never disagree.
class InvoiceDetailsSection extends ConsumerWidget {
  const InvoiceDetailsSection({
    super.key,
    required this.invoice,
    this.replacedByNumber = '',
  });

  final Invoice invoice;

  /// The credit note that superseded this invoice, when one did.
  final String replacedByNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final match = ref.watch(invoiceMatchesProvider).value?[invoice.id];
    final facts = InvoiceDetailFacts.of(
      invoice,
      match,
      canIssue: true,
      showMemberName: true,
    );
    final sections = InvoiceDetailSections(
      invoice: invoice,
      canIssue: true,
      isEu: false,
      reminder: ref.watch(invoiceRemindersProvider).value?[invoice.id],
      replacedByNumber: replacedByNumber,
      transmission: ref.watch(invoiceTransmissionsProvider).value?[invoice.id],
      journey: null,
    );
    final association = ref.watch(sellerIsAssociationProvider);
    final dates = appFormatOf(context).dates(DateShape.date);
    Widget line(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    return KitCard(
      key: const ValueKey('invoice-page-details'),
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        // Collapsed: the page keeps its own words first.
        title: Text(l.bookingOpenDetails),
        shape: const Border(),
        collapsedShape: const Border(),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [
          line(
            '${l.invoicePdfIssuedOn} ${dates.format(invoice.issuedAt)}'
            '${invoice.issuerName.isEmpty ? '' : ' · ${l.invoicePdfIssuedBy} ${invoice.issuerName}'}',
          ),
          line('${l.invoicePdfBilledTo}: ${facts.billedTo}'),
          if (facts.showKindRow) sections.kindRow(context),
          line(invoicePeriodLabel(context, invoice)),
          ...sections.amounts(context, association: association),
          if (facts.showSettlementTrail)
            ...sections.settlementTrail(context, association: association),
          ...sections.timeline(context, facts.standingMatch),
        ],
      ),
    );
  }
}
