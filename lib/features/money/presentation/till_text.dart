// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's words: what an operation of the counter is called, and what a refusal of the till says. A
// refusal is the server's (the counter's DKT codes have their sentences in `knownRefusalText`); what the till refuses
// by itself (cash short of the total) is said here.
import '../../../core/trace/refusal_text.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/counter_till.dart';
import '../domain/till_offline.dart';
import '../domain/till_offline_queue.dart';
import 'counter_lots_refusal.dart';
import 'till_drawer/drawer_text.dart';
import 'till_offline_mode.dart';
import 'till_price_refusal.dart';
import 'till_session.dart';

/// The name of a counter operation as a country's registry knows it.
String tillOperationName(AppLocalizations l10n, String operation) => switch (operation) {
  'issue_receipt' => l10n.tillOpIssueReceipt,
  'correct_receipt' => l10n.tillOpCorrectReceipt,
  'reconcile_tender' => l10n.tillOpReconcileTender,
  'sign_fiscal' => l10n.tillOpSignFiscal,
  'export_fiscal' => l10n.tillOpExportFiscal,
  _ => operation,
};

/// What the last act's [problem] says, in words: the till's own check, the server's refusal, or a plain failure.
String tillProblemText(AppLocalizations l10n, Object problem) {
  if (problem is String) return problem;
  if (problem is TillCashShort) return l10n.tillCashShort;
  if (problem is TillQuantityMissing) return l10n.tillWeighFirst;
  if (problem is TillReturnOffline) return l10n.tillReturnOffline;
  if (problem is TillCardDeclined) return l10n.counterSaleCardDeclined;
  if (problem is TillOfflineNoPrice) return l10n.tillOfflineNoPrice;
  if (problem is OfflineRecordRefused) {
    return switch (problem.refusal) {
      OfflineRefusal.cashShort => l10n.tillCashShort,
      OfflineRefusal.noPrice => l10n.tillOfflineNoPrice,
      _ => l10n.tillFailed,
    };
  }
  return drawerRefusalText(l10n, problem) ?? tillPriceRefusalText(l10n, problem) ?? counterLotsRefusalText(l10n, problem) ?? knownRefusalText(l10n, problem) ?? l10n.tillFailed;
}

/// #4436 -- the track IDs a sold line took, in words: each lot with its quantity, each piece by its tag.
String tillTracksText(AppLocalizations l10n, List<TillTrack> tracks) => [
  for (final t in tracks)
    if (t.isPiece) l10n.tillTrackPiece(t.code) else l10n.tillTrackLot(t.code, t.quantity ?? ''),
].join(' · ');

/// #4373 -- why the server refused an offline sale, in words (`reason` is what it answered; an unknown one is said plainly).
String tillOfflineReasonText(AppLocalizations l10n, String reason) => switch (reason) {
  'too_long' => l10n.tillOfflineReasonTooLong,
  'price' => l10n.tillOfflineReasonPrice,
  'item' => l10n.tillOfflineReasonItem,
  'cash' => l10n.tillOfflineReasonCash,
  'too_many' => l10n.tillOfflineReasonTooMany,
  'before_session' => l10n.tillOfflineReasonBeforeSession,
  'clock' => l10n.tillOfflineReasonClock,
  _ => l10n.tillOfflineReasonOther,
};
