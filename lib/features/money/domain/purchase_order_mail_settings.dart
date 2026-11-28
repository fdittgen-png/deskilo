// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — how the space e-mails its purchase orders, and the address check an order and its mail form share
// (`save_purchase_order_v1`, 0681; the mail settings, 0683). Split from purchase_order.dart (#4479).
//
// Pure Dart: no Flutter, no l10n.
library;

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// An address an order may be e-mailed to: one address, no line breaks,
/// nothing a mail header reads as a name or a list (0681, 0683).
bool isOrderEmail(String value) {
  final v = value.trim();
  return v.length <= 254 &&
      !value.contains(RegExp(r'[\r\n]')) &&
      RegExp(
        r'^[^\s@<>",;()\[\]\\]+@[^\s@<>",;()\[\]\\]+\.[^\s@<>",;()\[\]\\]+$',
      ).hasMatch(v);
}

/// How the space e-mails its orders: the sender, and whether a key is
/// stored. The key itself never reaches the app.
class PurchaseOrderMailSettings {
  const PurchaseOrderMailSettings({
    required this.senderEmail,
    required this.hasApiKey,
    required this.revision,
    this.senderName = '',
  });

  factory PurchaseOrderMailSettings.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'purchase order mail settings');
    return PurchaseOrderMailSettings(
      senderEmail: r.stringOr('sender_email'),
      senderName: r.stringOr('sender_name'),
      hasApiKey: r.isTrue('has_api_key'),
      revision: r.integer('revision'),
    );
  }

  final String senderEmail;
  final String senderName;
  final bool hasApiKey;
  final int revision;
}

/// What the mail settings form sends; an empty [apiKey] keeps the stored
/// one.
class PurchaseOrderMailDraft {
  const PurchaseOrderMailDraft({
    required this.senderEmail,
    this.senderName = '',
    this.apiKey = '',
    this.revision = 0,
  });

  final String senderEmail;
  final String senderName;
  final String apiKey;
  final int revision;

  /// Whether the form may be sent: a sender address, a name a mail header
  /// can carry, and a key on the first configuration.
  bool validFor(PurchaseOrderMailSettings? current) =>
      isOrderEmail(senderEmail) &&
      !senderName.contains(RegExp(r'[\r\n<>"]')) &&
      ((current?.hasApiKey ?? false) || apiKey.trim().isNotEmpty) &&
      (apiKey.trim().isEmpty ||
          RegExp(r'^[A-Za-z0-9_\-]{8,200}$').hasMatch(apiKey.trim()));
}
