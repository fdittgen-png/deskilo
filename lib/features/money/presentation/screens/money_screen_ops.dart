// SPDX-License-Identifier: AGPL-3.0-or-later




import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/statement.dart';
import 'money_member_documents.dart';
import 'money_online_payment.dart';
import 'money_payment_sheets.dart';

/// What the Money tab can DO, handed to the widgets that draw it (#2494).
///
/// The screen's [State] owns only the browsed month; everything else is a
/// decision the widgets below take from here: the month, the three groups of
/// operations (sheets, documents, online payment) and the month shifter. A
/// snapshot per build — a widget that holds it never reaches back into the
/// State.
class MoneyScreenOps {
  const MoneyScreenOps({
    required this.month,
    required this.nowPeriod,
    required this.shiftMonth,
    required this.sheets,
    required this.documents,
    required this.onlinePayment,
  });

  /// First day of the visible month; the bill shows this period.
  final DateTime month;

  /// The running month's period key — the ONE clock read both uses share.
  final String nowPeriod;
  final void Function(int delta) shiftMonth;
  final MoneySheets sheets;
  final MoneyMemberDocuments documents;
  final MoneyOnlinePayment onlinePayment;

  String get period => DateFormat('yyyy-MM').format(month);

  bool get isCurrentPeriod => period == nowPeriod;

  Future<void> memberDoc(String docId) => documents.memberDoc(docId, period);

  Future<void> exportBill(Statement statement) =>
      documents.exportBill(statement, month: month, nowPeriod: nowPeriod);

  Future<void> payOnline(int amountCents) =>
      onlinePayment.pay(amountCents, period);
}
