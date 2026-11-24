// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The Demo's search by track ID, answering as `stock_trace_find_v1` (0940) does from what the Demo keeps: the lots of its
// ledger and the dated lots it keeps for the expiry report (a lot code as received, compared without case), the gift
// basket's pieces by their tags, and the traced lines its till sold (the track IDs each froze). A receipt is named only to
// a reader who may see the money; a reader who may not read the stock is refused as the server refuses (DKN01). Another
// business's code answers nothing: the Demo's goods are its own.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../features/stock/domain/stock_trace_chain.dart';
import '../../../features/stock/domain/stock_track_find.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import '../../codes/dk_code.dart';
import 'demo_stock_expiry.dart';
import 'demo_stock_ledger.dart';
import 'demo_stock_tags.dart';
import 'demo_till.dart';

class DemoStockTrackFind implements StockTrackFinder {
  DemoStockTrackFind(
    this._ledger,
    this._expiry,
    this._tags, {
    required this.sold,
    required this.held,
  });

  final DemoStockLedger _ledger;
  final DemoStockExpiry _expiry;
  final DemoStockTags _tags;

  /// The traced lines the business's till sold.
  final List<DemoSoldLine> Function() sold;

  /// What the reader holds.
  final Set<WorkspacePermission> Function() held;

  @override
  Future<TrackFindAnswer> find(String workspaceId, String code) async {
    final rights = held();
    if (!rights.contains(WorkspacePermission.viewStock) &&
        !rights.contains(WorkspacePermission.manageStock)) {
      throw const PostgrestException(
        message: 'not allowed to read the trace',
        code: DkCode.dkn01,
      );
    }
    final wanted = code.trim();
    if (!_ledger.mine(workspaceId)) {
      return TrackFindAnswer(
        code: wanted,
        lots: const [],
        pieces: const [],
        sales: const [],
      );
    }
    final lower = wanted.toLowerCase();

    final lots = <String, TrackFindLot>{};
    for (final m in _ledger.movements) {
      if (m.lotId != null && m.lotCode?.toLowerCase() == lower) {
        lots.putIfAbsent(
          m.lotId!,
          () => TrackFindLot(
            id: m.lotId!,
            itemId: m.itemId,
            item: m.itemName,
            code: m.lotCode,
          ),
        );
      }
    }
    for (final l in _expiry.lots()) {
      if (l.lotCode.toLowerCase() == lower) {
        final id = 'demo-lot-${l.lotCode}';
        lots.putIfAbsent(
          id,
          () => TrackFindLot(
            id: id,
            itemId: l.itemId,
            item: l.itemName,
            code: l.lotCode,
            expiresOn: l.expiresOn,
          ),
        );
      }
    }

    final tag = DemoStockTags.normalise(wanted);
    final item = _tags.pieceItemOf(tag);
    final pieces = [
      if (item != null)
        for (final p in _tags.pieceTags(item))
          if (p.code == tag)
            TrackFindPiece(
              id: p.pieceId,
              itemId: item,
              item: _itemName(item),
              tag: p.code,
            ),
    ];

    final seesMoney = held().contains(WorkspacePermission.viewFinances);
    final sales = [
      for (final line in sold().reversed)
        if (_took(line, lower, tag) case final quantity?)
          TrackFindSale(
            at: line.at,
            quantity: quantity,
            document: seesMoney
                ? TraceDocument(
                    kind: TraceDocumentKind.counterReceipt,
                    id: line.receiptId,
                    label: line.number,
                  )
                : const TraceDocument(
                    kind: TraceDocumentKind.counterReceipt,
                    available: false,
                  ),
            lineId: seesMoney ? line.lineId : null,
          ),
    ];
    return TrackFindAnswer(
      code: wanted,
      lots: lots.values.toList(),
      pieces: pieces,
      sales: sales,
    );
  }

  /// What [line] took of the lot [lower] or the piece [tag]: the lot's quantity, one per piece; null when nothing.
  static ExactQuantity? _took(DemoSoldLine line, String lower, String tag) {
    var taken = ExactQuantity.zero;
    var any = false;
    for (final t in line.tracks) {
      if (t.kind == 'lot' && t.code.toLowerCase() == lower) {
        taken = taken + ExactQuantity.parse(t.quantity ?? '0');
        any = true;
      } else if (t.kind == 'piece' && t.code == tag) {
        taken = taken + ExactQuantity.parse('1');
        any = true;
      }
    }
    return any ? taken : null;
  }

  /// A piece's item by name: the Demo's lots of that item name it, else the ledger's movements.
  String _itemName(String itemId) =>
      _expiry.lots().where((l) => l.itemId == itemId).firstOrNull?.itemName ??
      _ledger.movements
          .where((m) => m.itemId == itemId)
          .firstOrNull
          ?.itemName ??
      itemId;
}
