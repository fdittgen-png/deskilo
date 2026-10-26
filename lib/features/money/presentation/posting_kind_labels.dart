// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The words of a posting's event, as the transfers list and the Swiss
// journal's Text column name it.
import '../../../l10n/app_localizations.dart';
import '../domain/posting.dart';

/// The words of [kind].
String postingKindLabel(AppLocalizations l10n, PostingKind kind) =>
    switch (kind) {
      PostingKind.invoice => l10n.acctKindInvoice,
      PostingKind.creditNote => l10n.acctKindCreditNote,
      PostingKind.receipt => l10n.acctKindReceipt,
      PostingKind.refund => l10n.acctKindRefund,
      PostingKind.writeOff => l10n.acctKindWriteOff,
      PostingKind.expense => l10n.acctKindExpense,
      PostingKind.supplierBill => l10n.acctKindSupplierBill,
      PostingKind.supplierCreditNote => l10n.acctKindSupplierCreditNote,
      PostingKind.supplierPayment => l10n.acctKindSupplierPayment,
      PostingKind.vatRelease => l10n.acctKindVatRelease,
      PostingKind.memberReceipt => l10n.acctKindMemberReceipt,
      PostingKind.reimbursement => l10n.acctKindReimbursement,
    };
