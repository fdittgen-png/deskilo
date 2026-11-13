// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart';
import '../../l10n/app_localizations.dart';
import '../data/server_error.dart';

/// #1305 S2 — the refusals every surface can meet, whatever it was doing.
///
/// `runGuarded` used to show its caller's `errorText` for any failure —
/// 180 call sites passing "Something went wrong. Please try again." A
/// member refused for lack of a permission read that as a fault to retry,
/// and retried. These four families are not faults and not domain
/// specific: the server said *who may*, *who you are*, *it already
/// happened*, or *the thing moved*. Each gets its own sentence, once, at
/// the single point every guarded action passes through.
///
/// Booking refusals keep their own mapper (`bookingErrorText`), which
/// knows the booking vocabulary; this one knows only what any screen can
/// hit. Substrings are pinned against the migrations by
/// `test/core/trace/refusal_text_test.dart` — a server message that stops
/// being raised fails there, not silently in front of a member.
enum KnownRefusal {
  permission,
  session,
  alreadyDecided,
  changedMeanwhile,

  /// #2332 (0399, DK423) — the currency or country of a space that has
  /// already issued a document or recorded money.
  moneyLocaleLocked,

  /// #2356 (DKV01) — a new percent on a VAT rate already on issued
  /// invoices: the change is a new version from a date.
  vatRateVersioned,

  /// #2370 (DKA02) — an accounting connection closed for the change: it was
  /// revoked, or it delivered and its token stays.
  accountingConnectionClosed,

  /// #2370 (DKA03) — a value of an accounting connection the server refused
  /// (a token, a mapping key, an issuer, a file).
  accountingValueRefused,

  /// #2380 (DKB01) — a bank movement decided meanwhile: matched,
  /// reconciled or reviewed by another press or another person.
  bankLineDecided,

  /// #2380 (DKB02) — a bank movement and what it was confirmed against do
  /// not go together (direction, currency, amount, state, workspace).
  bankLineRefused,

  /// #2380 (DKB03) — a bank statement file the server refuses whole.
  bankFileRefused,

  /// #2380 (DKB04) — a match of money in that did more than link a payment
  /// (a credit note, a settlement, a write-off): not undone here.
  bankMatchBeyondLink,

  /// #2380 (DKB05) — the invoice's payments cannot be restated without
  /// guessing (0657, 0660): they do not add up to the match (one may await
  /// its validation), or two share their submission time.
  bankMatchSeveralPayments,

  /// #2380 (DKB06) — the payment is dated inside a closed period of the
  /// books: its match is not undone.
  bankMatchClosedPeriod,

  /// #2380 (DKB07, 0660) — the invoice's first payment is undone last: the
  /// later payments go first.
  bankMatchUndoLaterFirst,

  /// #2571 (DKE01) — a destructive step over records still under retention:
  /// the server deleted nothing.
  retentionKept,

  /// #3278 (0666) — the workspace handles data requests itself: the member's
  /// own export and erasure are off and a rights request is filed instead.
  privacySelfServiceOff,

  /// #3811 — DKR01: this installation is a personal home and hosts no
  /// workspace.
  personalHomeHostsNoWorkspace,

  /// #3824 (0747) — the goods ledger's refusals, DKG01-DKG07: stock
  /// management off, a unit the item does not list, not that much on hand,
  /// not a stock item, a place that is not the business's or not in use, a
  /// lot of another item, a move not recordable as given.
  stockOff,
  stockUnit,
  stockNotEnough,
  stockItem,
  stockLocation,
  stockLot,
  stockMove,

  /// #3824 (0747) — DKG08: an item with stock movements, or a movement,
  /// is kept: the item is deactivated instead.
  stockHistory,
}

/// Substrings of server refusals that mean "you may not".
@visibleForTesting
const List<String> permissionRefusalSubstrings = [
  // #3821 — every business permission refusal carries DKN01 since 0745 and
  // is read by its code; what is left is Postgres's own words.
  'violates row-level security policy',
];

/// Substrings that mean the session is gone.
@visibleForTesting
const List<String> sessionRefusalSubstrings = [
  'not authenticated',
  'jwt expired',
];

/// #3278 — the refusal of a member's own export or erasure when the workspace
/// turned direct access off (it carries errcode 42501, so it is read first).
@visibleForTesting
const List<String> privacySelfServiceOffSubstrings = [
  'privacy_self_service_off',
];



/// #2380 — the bank statement codes of 0603 and 0650.
const Map<String, KnownRefusal> _bankRefusals = {
  'DKB01': KnownRefusal.bankLineDecided,
  'DKB02': KnownRefusal.bankLineRefused,
  'DKB03': KnownRefusal.bankFileRefused,
  'DKB04': KnownRefusal.bankMatchBeyondLink,
  'DKB05': KnownRefusal.bankMatchSeveralPayments,
  'DKB06': KnownRefusal.bankMatchClosedPeriod,
  'DKB07': KnownRefusal.bankMatchUndoLaterFirst,
};

/// #3811 — the invoicing codes of 0740 and the installation's DKR01 (0559):
/// read by their code, never their sentence.
const Map<String, KnownRefusal> _codedRefusals = {
  'DKI03': KnownRefusal.changedMeanwhile,
  'DKI04': KnownRefusal.changedMeanwhile,
  'DKI05': KnownRefusal.changedMeanwhile,
  'DKI06': KnownRefusal.changedMeanwhile,
  'DKD01': KnownRefusal.alreadyDecided,
  'DKR01': KnownRefusal.personalHomeHostsNoWorkspace,
  // #3821 — a business refusal: this person may not do this (0745).
  'DKN01': KnownRefusal.permission,
  // #3824 — the goods ledger (0747).
  'DKG01': KnownRefusal.stockOff,
  'DKG02': KnownRefusal.stockUnit,
  'DKG03': KnownRefusal.stockNotEnough,
  'DKG04': KnownRefusal.stockItem,
  'DKG05': KnownRefusal.stockLocation,
  'DKG06': KnownRefusal.stockLot,
  'DKG07': KnownRefusal.stockMove,
  'DKG08': KnownRefusal.stockHistory,
};

/// #3811 — the server's refusal code and its DETAIL, for a screen that reads
/// a code of its own (presentation never imports `data/`).
({String? code, String? details}) refusalCodeOf(Object error) =>
    (code: serverErrorCode(error), details: serverErrorDetails(error));

/// Which family [error] belongs to, or null when it is none of them.
KnownRefusal? knownRefusalOf(Object error) {
  // #3278 — a 42501 that carries its own words: read before the generic one.
  final said = serverErrorMessage(error)?.toLowerCase();
  if (said != null &&
      privacySelfServiceOffSubstrings.any(said.contains)) {
    return KnownRefusal.privacySelfServiceOff;
  }
  // 42501 is Postgres's own insufficient_privilege — an RLS refusal or a
  // revoked grant, which never carries one of our sentences.
  if (serverErrorCode(error) == '42501') return KnownRefusal.permission;
  if (serverErrorCode(error) == 'DK423') return KnownRefusal.moneyLocaleLocked;
  if (serverErrorCode(error) == 'DKV01') return KnownRefusal.vatRateVersioned;
  // #2370 — DKA01: the issuer was connected meanwhile, by someone else.
  if (serverErrorCode(error) == 'DKA01') return KnownRefusal.changedMeanwhile;
  if (serverErrorCode(error) == 'DKA02') {
    return KnownRefusal.accountingConnectionClosed;
  }
  if (serverErrorCode(error) == 'DKA03') return KnownRefusal.accountingValueRefused;
  if (serverErrorCode(error) == 'DKE01') return KnownRefusal.retentionKept;
  final bank = _bankRefusals[serverErrorCode(error)];
  if (bank != null) return bank;
  final coded = _codedRefusals[serverErrorCode(error)];
  if (coded != null) return coded;
  final message = serverErrorMessage(error)?.toLowerCase();
  if (message == null) return null;
  if (isAuthError(error) &&
      (message.contains('expired') || message.contains('refresh token'))) {
    return KnownRefusal.session;
  }
  bool any(List<String> needles) => needles.any(message.contains);
  if (any(sessionRefusalSubstrings)) return KnownRefusal.session;
  if (any(permissionRefusalSubstrings)) return KnownRefusal.permission;
  return null;
}

/// The sentence for [error] when it is a known refusal, else null — the
/// caller keeps its own text for everything else.
String? knownRefusalText(AppLocalizations l10n, Object error) =>
    switch (knownRefusalOf(error)) {
      KnownRefusal.permission => l10n.refusalPermission,
      KnownRefusal.session => l10n.refusalSession,
      KnownRefusal.alreadyDecided => l10n.refusalAlreadyDecided,
      KnownRefusal.changedMeanwhile => l10n.refusalChangedMeanwhile,
      KnownRefusal.moneyLocaleLocked =>
        l10n.refusalMoneyLocaleLocked,
      KnownRefusal.vatRateVersioned =>
        l10n.refusalVatRateVersioned,
      KnownRefusal.accountingConnectionClosed => l10n.refusalAccountingClosed,
      KnownRefusal.accountingValueRefused => l10n.refusalAccountingValue,
      KnownRefusal.bankLineDecided => l10n.refusalBankLineDecided,
      KnownRefusal.bankLineRefused => l10n.refusalBankLineRefused,
      KnownRefusal.bankFileRefused => l10n.refusalBankFileRefused,
      KnownRefusal.bankMatchBeyondLink => l10n.refusalBankMatchBeyondLink,
      KnownRefusal.bankMatchSeveralPayments =>
        l10n.refusalBankMatchSeveralPayments,
      KnownRefusal.bankMatchClosedPeriod => l10n.refusalBankMatchClosedPeriod,
      KnownRefusal.bankMatchUndoLaterFirst => l10n.refusalBankMatchUndoLaterFirst,
      KnownRefusal.retentionKept =>
        l10n.retentionResetRefused(l10n.retentionKeptReview),
      KnownRefusal.privacySelfServiceOff => l10n.privacySelfServiceOff,
      KnownRefusal.personalHomeHostsNoWorkspace =>
        l10n.refusalPersonalHomeHostsNoWorkspace,
      final KnownRefusal stock => _stockRefusalText(l10n, stock),
      null => null,
    };

/// #3824 — the goods ledger's words (DKG01-DKG08), apart from the other
/// families; null for a refusal of another family.
String? _stockRefusalText(AppLocalizations l10n, KnownRefusal refusal) =>
    switch (refusal) {
      KnownRefusal.stockOff => l10n.refusalStockOff,
      KnownRefusal.stockUnit => l10n.refusalStockUnit,
      KnownRefusal.stockNotEnough => l10n.refusalStockNotEnough,
      KnownRefusal.stockItem => l10n.refusalStockItem,
      KnownRefusal.stockLocation => l10n.refusalStockLocation,
      KnownRefusal.stockLot => l10n.refusalStockLot,
      KnownRefusal.stockMove => l10n.refusalStockMove,
      KnownRefusal.stockHistory => l10n.refusalStockHistory,
      _ => null,
    };
