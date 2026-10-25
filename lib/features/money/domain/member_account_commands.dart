// SPDX-License-Identifier: AGPL-3.0-or-later
import 'payment_method.dart';

/// #2591 — what is recorded against a member's account: a payment, a
/// consumed service, a bought package, and the requests to correct or
/// delete a usage record. Each creates what the server decides (often a
/// PENDING event); none of them reads.
abstract interface class MemberAccountCommands {
  /// Returns the pending event id. [method] is how the money moved
  /// (#154); null = not specified (renders method-less, like pre-#154
  /// events).
  ///
  /// [paidOn] is the day the money actually moved (0070) — recording on
  /// the 26th a transfer made on the 3rd must not date it the 26th; null
  /// = today. [period] is the month the payment SETTLES, which decides
  /// which bill and which invoice it lands on; null = the current month.
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note,
    PaymentMethod? method,
    DateTime? paidOn,
    String? period,
  });

  /// Records consumed services onto the monthly bill (#129, ADR 0008).
  /// Creates a PENDING service_charge event with a name+price snapshot —
  /// the ledger charge posts only on confirmation. Members self-report
  /// (subject = self); admins/owner may record for any member. [period]
  /// is 'yyyy-MM' and defaults server-side to the current month.
  Future<void> recordServiceCharge({
    required String workspaceId,
    required String subjectMemberId,
    required String serviceId,
    required int quantity,
    String? period,
  });

  /// Buys a package (RPC `buy_package`): raises the caller's cap for the
  /// current period and posts the price as a charge on their bill. Only a
  /// member whose over-consumption policy is 'package' may buy. Returns the
  /// quota-extension id.
  Future<String> buyPackage(String workspaceId, String packageId);

  /// #833 — "I left before the booking ended; bill the time I was
  /// actually here." Only the member concerned may ask, and never
  /// decides it themselves. Returns the event id.
  Future<String> requestUsageCorrection(String recordId, {String reason});

  /// #833 — an admin removing a record; the member concerned validates
  /// it when a rule says so. Returns the event id.
  Future<String> requestUsageRecordDelete(String recordId, {String reason});
}
