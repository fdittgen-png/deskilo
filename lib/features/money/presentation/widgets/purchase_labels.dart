// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../../l10n/app_localizations.dart';
import '../../domain/purchase.dart';

String purchaseKindLabel(AppLocalizations l10n, PurchaseKind kind) =>
    switch (kind) {
      PurchaseKind.bill => l10n.purchasesKindBill,
      PurchaseKind.creditNote => l10n.purchasesKindCreditNote,
      PurchaseKind.memberReceipt => l10n.purchasesKindReceipt,
    };

String purchaseStateLabel(AppLocalizations l10n, PurchaseState state) =>
    switch (state) {
      PurchaseState.draft => l10n.purchasesStateDraft,
      PurchaseState.pending => l10n.purchasesStatePending,
      PurchaseState.approved => l10n.purchasesStateApproved,
      PurchaseState.rejected => l10n.purchasesStateRejected,
      PurchaseState.cancelled => l10n.purchasesStateCancelled,
    };
