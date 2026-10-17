// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/purchase.dart';

/// Purchase documents in memory. The server derives the totals and files a
/// member's expense as a receipt through the same bridge; the demo only keeps
/// what the dialog saved, replaying a request id as the server does.
class FakePurchaseRepository implements PurchaseRepository {
  final List<PurchaseDetail> _documents = [];
  final Map<String, String> _requests = {};

  @override
  Future<List<PurchaseSummary>> fetchPurchases(String workspaceId) async => [
    for (final d in _documents.reversed) d.summary,
  ];

  @override
  Future<PurchaseDetail> fetchDetail(
    String workspaceId,
    String purchaseId,
  ) async => _documents.firstWhere(
    (d) => d.summary.id == purchaseId,
    orElse: () => throw StateError('unknown purchase'),
  );

  @override
  Future<String> saveDraft(
    String workspaceId,
    String requestId,
    PurchaseBillDraft draft,
  ) async {
    final replay = _requests[requestId];
    if (replay != null) return replay;
    final id = draft.purchaseId ?? 'demo-purchase-${_documents.length + 1}';
    final tax = draft.taxCents;
    final detail = PurchaseDetail(
      summary: PurchaseSummary(
        id: id,
        kind: PurchaseKind.bill,
        state: PurchaseState.draft,
        category: '',
        reference: draft.reference,
        currency: '',
        receivedOn: draft.originalDate,
      ),
      revision: draft.expectedRevision + 1,
      lines: [
        PurchaseLine(
          lineNo: 1,
          description: draft.description,
          grossCents: draft.grossCents,
          netCents: tax == null ? null : draft.grossCents - tax,
          taxCents: tax,
        ),
      ],
      sources: const [],
      dueOn: draft.dueOn,
    );
    final i = _documents.indexWhere((d) => d.summary.id == id);
    if (i < 0) {
      _documents.add(detail);
    } else {
      _documents[i] = detail;
    }
    return _requests[requestId] = id;
  }
}
