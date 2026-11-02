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
    this.next,
  });

  factory PurchaseApprovalPage.fromJson(Object? raw) {
    final json = JsonReader.of(raw, context: 'purchase_approval_page_v1');
    final cursor = json.objectOrNull('next');
    return PurchaseApprovalPage(
      rows: [for (final row in json.list('rows')) PurchaseSummary.fromRow(row)],
      count: json.integer('count'),
      next: cursor == null
          ? null
          : (created: cursor.string('created'), id: cursor.string('id')),
    );
  }

  final List<PurchaseSummary> rows;
  final int count;
  final PurchaseApprovalCursor? next;
}

/// A pending bill and the actions the current approver may perform now.
class PurchaseApprovalDetail {
  const PurchaseApprovalDetail({
    required this.detail,
    required this.canApprove,
    required this.canReject,
  });

  factory PurchaseApprovalDetail.fromJson(Object? raw) {
    final json = JsonReader.of(raw, context: 'purchase_approval_detail_v1');
    return PurchaseApprovalDetail(
      detail: PurchaseDetail.fromJson(json.raw('detail')),
      canApprove: json.boolOr('can_approve', fallback: false),
      canReject: json.boolOr('can_reject', fallback: false),
    );
  }

  final PurchaseDetail detail;
  final bool canApprove;
  final bool canReject;
}

abstract interface class PurchaseApprovalReads {
  Future<PurchaseApprovalPage> page(
    String workspaceId, {
    PurchaseApprovalCursor? after,
  });
  Future<PurchaseApprovalDetail> detail(String workspaceId, String purchaseId);
}
