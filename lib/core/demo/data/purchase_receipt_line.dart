// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/vat_rate.dart';
import 'floor_plan_repository.dart';
import 'workspace_repository.dart';

/// A claim's receipt as the server reads it: one line, its claim.
PurchaseLine claimReceiptLine(PayableRow row, double? rate) {
  final gross = row.purchase.grossCents;
  if (rate == null) {
    return PurchaseLine(
      lineNo: 1,
      description: row.purchase.category,
      grossCents: gross,
    );
  }
  final split = vatSplit(gross, rate);
  return PurchaseLine(
    lineNo: 1,
    description: row.purchase.category,
    grossCents: gross,
    netCents: split.netCents,
    taxCents: split.vatCents,
    taxRatePercent: rate,
    recoverableTaxCents: split.vatCents,
  );
}

/// #2573 — the demonstration files no expense request as a document and
/// links no received invoice.
mixin NoFiledPurchases implements PurchaseRepository {
  @override
  Future<String?> purchaseFiledFrom(
    String workspaceId, {
    required String sourceKind,
    required String sourceId,
  }) async => null;

  /// Received invoices are not linked in the demonstration: refused, so
  /// the sheet says so instead of pretending.
  @override
  Future<void> linkInboxDocument(
    String workspaceId,
    String purchaseId, {
    required int revision,
    required String documentId,
    required String requestId,
  }) async => throw UnsupportedError('no inbox linking in the demonstration');
}

/// A draft as the server stores it under [id]: its lines numbered from 1,
/// the next revision, a draft of its kind. A bill names its currency when it
/// is not the space's; otherwise the demonstration names none.
PurchaseDetail demoDraftDetail(String id, PurchaseDraft draft) => PurchaseDetail(
  summary: PurchaseSummary(
    id: id,
    kind: draft.kind,
    state: PurchaseState.draft,
    category: draft.category,
    reference: draft.reference,
    currency: draft is PurchaseBillDraft ? draft.currency ?? '' : '',
    grossCents: draft.lines.fold(0, (sum, l) => sum + l.grossCents),
    receivedOn: draft.originalDate,
  ),
  revision: draft.expectedRevision + 1,
  lines: [
    for (final (i, l) in draft.lines.indexed) l.toLine(i + 1),
  ],
  sources: const [],
  dueOn: draft.dueOn,
);

/// #2573 — the places of [workspaceId] in the demonstration, read from its
/// own sites and plan: the sites first, each level followed by its offices.
List<PurchasePlace> demoPurchasePlaces(
  FakeWorkspaceRepository workspaces,
  FakeFloorPlanRepository plan,
  String workspaceId,
) => [
  for (final s in workspaces.sites)
    if (s.workspaceId == workspaceId)
      PurchasePlace(kind: 'site', id: s.id, name: s.name),
  for (final l in [
    for (final l in plan.levels)
      if (l.workspaceId == workspaceId) l,
  ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))) ...[
    PurchasePlace(kind: 'level', id: l.id, name: l.name),
    for (final o in plan.offices)
      if (o.levelId == l.id)
        PurchasePlace(kind: 'office', id: o.id, name: o.name),
  ],
];

/// The places a line can name in the demonstration; none until the demo
/// space hands its own over.
mixin DemoPurchasePlaces implements PurchaseRepository {
  List<PurchasePlace> Function(String workspaceId) placesOf = (_) => const [];

  @override
  Future<List<PurchasePlace>> fetchPlaces(String workspaceId) async =>
      placesOf(workspaceId);
}
