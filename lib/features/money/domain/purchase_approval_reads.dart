// SPDX-License-Identifier: AGPL-3.0-or-later

import '../../../core/data/json_reader.dart';
import 'purchase.dart';

/// The keyset continuation is an ordering key, not a cross-request snapshot.
typedef PurchaseApprovalCursor = ({String created, String id});

/// One bounded page and the count at the time this page was read.
class PurchaseApprovalPage {
  const PurchaseApprovalPage({
    required this.rows,
    required this.count,
    required this.version,
    this.next,
  });

  factory PurchaseApprovalPage.fromJson(Object? raw) {
    final json = JsonReader.of(raw, context: 'purchase_approval_page_v1');
    final cursor = json.objectOrNull('next');
    return PurchaseApprovalPage(
      rows: [for (final row in json.list('rows')) PurchaseSummary.fromRow(row)],
      count: json.integer('count'),
      version: json.string('version'),
      next: cursor == null
          ? null
          : (created: cursor.string('created'), id: cursor.string('id')),
    );
  }

  final List<PurchaseSummary> rows;
  final int count;

  /// Detects changes between page requests; it cannot make them a snapshot.
  final String version;
  final PurchaseApprovalCursor? next;
}

/// Read-only rate information for this eligible purchase, or its absence.
enum PurchaseApprovalFxStatus { unavailable, sameCurrency, missing, recorded }

class PurchaseApprovalFx {
  const PurchaseApprovalFx({
    required this.status,
    this.currency,
    this.functionalCurrency,
    this.rate,
    this.rateDate,
    this.source,
  });

  factory PurchaseApprovalFx.fromJson(JsonReader json) {
    final status = switch (json.string('status')) {
      'same_currency' => PurchaseApprovalFxStatus.sameCurrency,
      'missing' => PurchaseApprovalFxStatus.missing,
      'recorded' => PurchaseApprovalFxStatus.recorded,
      _ => throw const FormatException('Unknown approval exchange rate state'),
    };
    return PurchaseApprovalFx(
      status: status,
      currency: json.string('currency'),
      functionalCurrency: json.string('functional_currency'),
      rate: status == PurchaseApprovalFxStatus.recorded ? json.string('rate') : null,
      rateDate: status == PurchaseApprovalFxStatus.recorded ? json.dateTime('rate_date') : null,
      source: status == PurchaseApprovalFxStatus.recorded ? json.string('source') : null,
    );
  }

  final PurchaseApprovalFxStatus status;
  final String? currency;
  final String? functionalCurrency;
  /// Exact decimal text from the server; never converted through a double.
  final String? rate;
  final DateTime? rateDate;
  final String? source;
}

/// A pending bill and the actions the current approver may perform now.
class PurchaseApprovalDetail {
  const PurchaseApprovalDetail({
    required this.detail,
    required this.canApprove,
    required this.canReject,
    this.fx = const PurchaseApprovalFx(status: PurchaseApprovalFxStatus.unavailable),
  });

  factory PurchaseApprovalDetail.fromJson(Object? raw) {
    final json = JsonReader.of(raw, context: 'purchase_approval_detail_v1');
    return PurchaseApprovalDetail(
      detail: PurchaseDetail.fromJson(json.raw('detail')),
      canApprove: json.boolOr('can_approve', fallback: false),
      canReject: json.boolOr('can_reject', fallback: false),
      fx: switch (json.objectOrNull('fx')) {
        final fx? => PurchaseApprovalFx.fromJson(fx),
        null => const PurchaseApprovalFx(status: PurchaseApprovalFxStatus.unavailable),
      },
    );
  }

  final PurchaseDetail detail;
  final bool canApprove;
  final bool canReject;
  final PurchaseApprovalFx fx;
}

abstract interface class PurchaseApprovalReads {
  Future<PurchaseApprovalPage> page(
    String workspaceId, {
    PurchaseApprovalCursor? after,
  });
  Future<PurchaseApprovalDetail> detail(String workspaceId, String purchaseId);
}
