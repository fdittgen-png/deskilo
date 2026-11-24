// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1916 / #4105 -- what stops the issue, each essential in words; when one is
// the business's own (its address, its region, its tax identity), the way to
// the legal identity where it is entered.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/issue_month_readiness.dart' show isBusinessEssential;
import '../../domain/invoice_issue_readiness.dart';
import '../../domain/invoice_missing.dart';
import '../invoice_issue_block_text.dart';
import 'invoice_missing_sales_tax.dart';

/// The essentials [missing] for an issue blocked as [block].
class InvoiceMissingBanner extends StatelessWidget {
  const InvoiceMissingBanner({
    super.key,
    required this.l10n,
    required this.block,
    required this.missing,
  });

  final AppLocalizations l10n;
  final InvoiceIssueBlock block;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final ownFacts = missing.any(
      (k) =>
          isBusinessEssential(k) &&
          InvoiceMissing.fromWire(k) != InvoiceMissing.invoiceFeatureDisabled,
    );
    return InlineBanner(
      key: const ValueKey('invoice-missing-essentials'),
      icon: Icons.rule_folder_outlined,
      text:
          '${invoiceIssueBlockTitle(l10n, block)}:\n'
          '${[for (final key in missing) '• ${invoiceMissingLabel(l10n, key)}'].join('\n')}',
      actionLabel: ownFacts ? l10n.invoiceEInvoiceGapsOpenIdentity : null,
      onAction: ownFacts ? () => context.push('/legal-identity') : null,
    );
  }
}
