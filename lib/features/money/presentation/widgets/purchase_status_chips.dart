// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2577 C2 — the three answers of a purchase document side by side, each in
// its own words: approved or not, settled or not, qualified or not.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/purchase.dart';
import '../../domain/purchase_status.dart';
import 'purchase_labels.dart';

String _settlement(AppLocalizations l10n, PurchaseSettlement s) => switch (s) {
  PurchaseSettlement.nothingOwed => l10n.purchaseSettlementNothingOwed,
  PurchaseSettlement.unpaid => l10n.purchaseSettlementUnpaid,
  PurchaseSettlement.partlySettled => l10n.purchaseSettlementPartly,
  PurchaseSettlement.settled => l10n.purchaseSettlementSettled,
};

String _qualification(AppLocalizations l10n, PurchaseQualification q) =>
    switch (q) {
      PurchaseQualification.qualified => l10n.purchaseQualified,
      PurchaseQualification.needsReview => l10n.purchaseNeedsReview,
      PurchaseQualification.taxNotQualified => l10n.purchaseTaxNotQualified,
      PurchaseQualification.unverified => l10n.purchaseUnverified,
    };

/// Document, settlement and accounting of [detail], as three chips.
class PurchaseStatusChips extends StatelessWidget {
  const PurchaseStatusChips({super.key, required this.detail});

  final PurchaseDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = purchaseStatusOf(detail);
    Widget chip(String key, IconData icon, String label) => Chip(
      key: ValueKey(key),
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
    return Wrap(
      key: const ValueKey('purchase-state'),
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        chip(
          'purchase-chip-approval',
          Icons.fact_check_outlined,
          purchaseStateLabel(l10n, detail.summary.state),
        ),
        chip(
          'purchase-chip-settlement',
          Icons.account_balance_wallet_outlined,
          _settlement(l10n, status.settlement),
        ),
        chip(
          'purchase-chip-qualification',
          Icons.rule_outlined,
          _qualification(l10n, status.qualification),
        ),
      ],
    );
  }
}
