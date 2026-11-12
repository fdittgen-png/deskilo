// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3774 — the words for why an e-mail was refused, the same for a purchase
// order and a payment reminder: a code this server writes becomes a
// sentence; anything else is quoted as it came.
import '../../../l10n/app_localizations.dart';
import '../domain/mail_refusal.dart';

/// The part of a refusal message that says why ([reason] as recorded).
String mailRefusalText(AppLocalizations l10n, String reason) =>
    switch (MailRefusal.of(reason)) {
      MailRefusalNoSender() => l10n.mailRefusalNoSender,
      MailRefusalInvalid() => l10n.mailRefusalInvalid,
      MailRefusalProvider(:final status) => l10n.mailRefusalProvider(status),
      MailRefusalOther(:final text) => l10n.mailRefusalOther(text),
    };
