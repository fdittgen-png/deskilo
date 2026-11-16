// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3674 — what a session knows of its customers beyond the business's month:
// a customer's own month, what their details leave missing for an invoice,
// and the buyer an issued invoice names. Empty in a test fake; the Demo sets
// them (demo_newcomers_seed.dart).
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../../features/money/domain/statement.dart';

class DemoBuyers {
  /// A customer's own month where it is not the business's (a newcomer
  /// without the subscription), keyed `member|period`.
  final months = <String, Statement>{};

  /// What the customer's own details leave missing, as the server reads the
  /// buyer; null: nothing beyond the session's own missing essentials.
  List<String> Function(String memberId)? missing;

  /// The buyer an issued invoice names, as the server snapshots it; null:
  /// the distinguishable placeholders the archive tests read.
  ({String name, String address}) Function(String memberId)? of;

  /// #4105 -- the parties an issue to [memberId] would store, as the server's
  /// draft answers them; null: the session says nothing about a channel.
  ({InvoiceParty seller, InvoiceParty buyer}) Function(String memberId)? parties;
}
