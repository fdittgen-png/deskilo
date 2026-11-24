// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart';

import '../../l10n/app_localizations.dart';
import '../codes/dk_code.dart';
import '../codes/pg_code.dart';
import '../data/server_error.dart';
import 'feature_refusals.dart';

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

  /// #2571 (DKE01) — a destructive step over records still under retention:
  /// the server deleted nothing.
  retentionKept,

  /// #3278 (0666) — the workspace handles data requests itself: the member's
  /// own export and erasure are off and a rights request is filed instead.
  privacySelfServiceOff,

  /// #3811 — DKR01: this installation is a personal home and hosts no
  /// workspace.
  personalHomeHostsNoWorkspace,

  /// #4184 (0893) -- DKL01: an operation of the counter that the country, under the case the owner declared,
  /// does not support (nothing was numbered, nothing handed over).
  counterUnsupported,

  /// #4185 (0894) -- DKL02: something a receipt needs is missing or not acceptable; DKL04: not an open draft, or
  /// already issued for its source; DKL05: the business names a customer on every sale; DKL06: the tenders do not
  /// settle the sale, or one is not taken here; DKL08: a correction beyond what the original has left; DKL10: the
  /// receipt changed meanwhile.
  counterEssentials,
  counterNotOpen,
  counterCustomerNeeded,
  counterTenders,
  counterCorrectionBeyond,
  counterChanged,

  /// #4185 (0894, 0895) -- DKL07: goods cannot be sold or taken back here (the goods ledger is off, or there is no place to
  /// take them from or put them back); DKL11: a card authorization is open, unknown or already settled.
  counterGoods,
  counterTenderState,

  /// #4367 (0907, 0909) -- DKL12: the till or its session is not in the state the act needs; DKL13: a cash entry or a count
  /// that is not accepted; DKL14: the day cannot be closed; DKL15: a till is not opened on a day already closed.
  counterTill,
  counterCashEntry,
  counterDayClose,
  counterDayOpen,

  /// #4373 (0937) -- DKL16: a request id or a sequence number of an offline sale already holds another sale.
  counterOfflineConflict,

  /// #4008 (0782) — DKM01: a member who left comes back as a new member,
  /// never by changing their old row (for instance to paused).
  memberReturnsAsNew,
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



/// #3811 — the invoicing codes of 0740 and the installation's DKR01 (0559):
/// read by their code, never their sentence.
const Map<String, KnownRefusal> _codedRefusals = {
  DkCode.dki03: KnownRefusal.changedMeanwhile,
  DkCode.dki04: KnownRefusal.changedMeanwhile,
  DkCode.dki05: KnownRefusal.changedMeanwhile,
  DkCode.dki06: KnownRefusal.changedMeanwhile,
  DkCode.dkd01: KnownRefusal.alreadyDecided,
  DkCode.dkr01: KnownRefusal.personalHomeHostsNoWorkspace,
  // #3821 — a business refusal: this person may not do this (0745).
  DkCode.dkn01: KnownRefusal.permission,
  DkCode.dkl01: KnownRefusal.counterUnsupported,
  DkCode.dkl02: KnownRefusal.counterEssentials,
  DkCode.dkl04: KnownRefusal.counterNotOpen,
  DkCode.dkl05: KnownRefusal.counterCustomerNeeded,
  DkCode.dkl06: KnownRefusal.counterTenders,
  DkCode.dkl08: KnownRefusal.counterCorrectionBeyond,
  DkCode.dkl07: KnownRefusal.counterGoods,
  DkCode.dkl10: KnownRefusal.counterChanged,
  DkCode.dkl11: KnownRefusal.counterTenderState,
  DkCode.dkl12: KnownRefusal.counterTill,
  DkCode.dkl13: KnownRefusal.counterCashEntry,
  DkCode.dkl14: KnownRefusal.counterDayClose,
  DkCode.dkl15: KnownRefusal.counterDayOpen,
  DkCode.dkl16: KnownRefusal.counterOfflineConflict,
  // #4008 — a member who left (0782).
  DkCode.dkm01: KnownRefusal.memberReturnsAsNew,
};

/// #3811 — the server's refusal code and its DETAIL, for a screen that reads
/// a code of its own (presentation never imports `data/`).
({String? code, String? details}) refusalCodeOf(Object error) =>
    (code: serverErrorCode(error), details: serverErrorDetails(error));

/// Whether the server ANSWERED with [error] (a refusal, even one with no sentence of its own), as against no answer
/// at all (a timeout, a lost connection): what an act that may have been made needs to know.
bool serverAnswered(Object error) => serverErrorCode(error) != null || serverErrorMessage(error) != null;

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
  if (serverErrorCode(error) == PgCode.insufficientPrivilege) return KnownRefusal.permission;
  if (serverErrorCode(error) == DkCode.dk423) return KnownRefusal.moneyLocaleLocked;
  if (serverErrorCode(error) == DkCode.dkv01) return KnownRefusal.vatRateVersioned;
  if (serverErrorCode(error) == DkCode.dke01) return KnownRefusal.retentionKept;
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
    _featureText(l10n, error) ??
    switch (knownRefusalOf(error)) {
      KnownRefusal.permission => l10n.refusalPermission,
      KnownRefusal.session => l10n.refusalSession,
      KnownRefusal.alreadyDecided => l10n.refusalAlreadyDecided,
      KnownRefusal.changedMeanwhile => l10n.refusalChangedMeanwhile,
      KnownRefusal.moneyLocaleLocked =>
        l10n.refusalMoneyLocaleLocked,
      KnownRefusal.vatRateVersioned =>
        l10n.refusalVatRateVersioned,
      KnownRefusal.retentionKept =>
        l10n.retentionResetRefused(l10n.retentionKeptReview),
      KnownRefusal.privacySelfServiceOff => l10n.privacySelfServiceOff,
      KnownRefusal.personalHomeHostsNoWorkspace =>
        l10n.refusalPersonalHomeHostsNoWorkspace,
      final KnownRefusal other => _counterRefusalText(l10n, other),
      null => null,
    };

/// #4184, #4185 -- the counter's refusals, and a member who left (#4008).
String? _counterRefusalText(AppLocalizations l10n, KnownRefusal refusal) => switch (refusal) {
      KnownRefusal.counterUnsupported => l10n.refusalCounterUnsupported,
      KnownRefusal.counterEssentials => l10n.refusalCounterEssentials,
      KnownRefusal.counterNotOpen => l10n.refusalCounterNotOpen,
      KnownRefusal.counterCustomerNeeded => l10n.refusalCounterCustomerNeeded,
      KnownRefusal.counterTenders => l10n.refusalCounterTenders,
      KnownRefusal.counterCorrectionBeyond => l10n.refusalCounterCorrectionBeyond,
      KnownRefusal.counterChanged => l10n.refusalCounterChanged,
      KnownRefusal.counterGoods => l10n.refusalCounterGoods,
      KnownRefusal.counterTenderState => l10n.refusalCounterTenderState,
      KnownRefusal.counterTill => l10n.refusalCounterTill,
      KnownRefusal.counterCashEntry => l10n.refusalCounterCashEntry,
      KnownRefusal.counterDayClose => l10n.refusalCounterDayClose,
      KnownRefusal.counterDayOpen => l10n.refusalCounterDayOpen,
      KnownRefusal.counterOfflineConflict => l10n.refusalCounterOfflineConflict,
      KnownRefusal.memberReturnsAsNew => l10n.refusalMemberReturnsAsNew,
      _ => null,
    };

/// #4413 -- a refusal code a feature owns, in that feature's words
/// (lib/core/trace/feature_refusals.dart).
String? _featureText(AppLocalizations l10n, Object error) {
  final code = serverErrorCode(error);
  return code == null
      ? null
      : FeatureRefusals.wordsFor(l10n, code, serverErrorDetails(error));
}

/// #4170 -- the page of the app a refusal points to, as the feature that
/// owns its code says, or null.
String? refusalLinkOf(Object error) {
  final code = serverErrorCode(error);
  return code == null
      ? null
      : FeatureRefusals.linkFor(code, serverErrorDetails(error));
}
