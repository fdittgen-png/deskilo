// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3837 — what a revoked pass says of its invoice, in the table's State
// cell and in the revoke result: corrected or not yet, never which
// correction to make (a pass paid at the desk is corrected by a credit note
// and a refund, one not paid may be voided).
import '../../../../l10n/app_localizations.dart';
import '../../domain/guest_pass.dart';
import '../../domain/guest_pass_invoice.dart';

/// How a pass reads: its guest's name ([holder]), where its invoice stands
/// ([invoiceOf]), and the way to open one ([open]).
typedef PassReading = ({
  String Function(GuestPassRecord pass) holder,
  PassInvoice Function(GuestPassRecord pass) invoiceOf,
  void Function(String invoiceId) open,
});

/// The line for [read], or null when there is nothing to say (a free pass,
/// an invoice not read).
String? passInvoiceWords(AppLocalizations l10n, PassInvoice read) =>
    switch (read) {
      (state: PassInvoiceState.notCorrected, invoice: final i?) =>
        l10n.guestPassInvoiceNotCorrected(i.number),
      (state: final s, invoice: final i?) when s.corrected =>
        l10n.guestPassInvoiceCorrected(i.number),
      _ => null,
    };
