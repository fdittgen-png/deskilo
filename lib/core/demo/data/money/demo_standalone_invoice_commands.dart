// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/money/domain/previewed_document.dart';
import 'package:deskilo/features/money/domain/standalone_invoice.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../codes/dk_code.dart';
import '../money_repository.dart';
import 'demo_document_numbering.dart';

/// #4165 -- the standalone invoice commands in the demo, answered from one
/// space's in-memory money store as the server answers them (0820): exact
/// decimals, the rate of the business's own VAT rates, half away from zero
/// per line in the currency's minor unit, a revision that guards a stale edit,
/// and an issue that replays under its request id. #4433 -- a goods line sells
/// an item of the business's goods ledger ([goods]): the preview names a line
/// the main store cannot serve, and the issue moves the goods out.
class DemoStandaloneInvoiceCommands implements StandaloneInvoiceCommands {
  DemoStandaloneInvoiceCommands(this._m);

  final FakeMoneyRepository _m;

  /// The goods ledger the invoices sell from; none refuses a goods line as the server does with the ledger off.
  DemoInvoiceGoods? goods;
  final Map<String, ({StandaloneDraft draft, int revision, String? invoiceId})>
  _drafts = {};
  var _next = 1;

  /// The business's currency, as the demo's invoices are issued in.
  String currency = 'EUR';

  PostgrestException _refused(String detail) => PostgrestException(
    message: 'invoice_essentials_missing',
    code: DkCode.dki01,
    details: detail,
  );

  @override
  Future<StandaloneSaved> saveDraft({
    required String workspaceId,
    required StandaloneDraft draft,
  }) async {
    final id = draft.draftId ?? 'demo-draft-${_next++}';
    final old = _drafts[id];
    if (draft.draftId != null) {
      if (old == null) throw _refused('draft_unknown');
      if (old.invoiceId != null) throw _refused('draft_closed');
      if (old.revision != draft.revision) throw _refused('draft_stale');
    }
    final lines = [
      for (final (i, l) in draft.lines.indexed)
        if (l.lineId != null) l else l.withLineId('demo-line-$id-$i'),
    ];
    final revision = (old?.revision ?? 0) + 1;
    _drafts[id] = (
      draft: StandaloneDraft(
        draftId: id,
        revision: revision,
        subjectMemberId: draft.subjectMemberId,
        serviceDate: draft.serviceDate,
        dueOn: draft.dueOn,
        buyerReference: draft.buyerReference,
        purchaseOrder: draft.purchaseOrder,
        lines: lines,
      ),
      revision: revision,
      invoiceId: null,
    );
    return StandaloneSaved(draftId: id, revision: revision, lines: lines);
  }

  /// The frozen line, or the facts it lacks.
  ({Map<String, Object?>? line, List<String> missing}) _line(
    int n,
    StandaloneLine l,
    double percent,
  ) {
    final missing = <String>[];
    final qty = parseCommercialDecimal(l.quantity);
    final price = parseCommercialDecimal(l.unitPrice, positive: false);
    final base = parseCommercialDecimal(l.baseQuantity);
    if (l.description.isEmpty) missing.add('line_${n}_description');
    if (qty.value == null) missing.add('line_${n}_quantity');
    if (price.value == null) missing.add('line_${n}_unit_price');
    if (base.value == null) missing.add('line_${n}_base_quantity');
    final sells = l.supply == 'goods';
    if (sells && goods == null) {
      missing.add('line_${n}_goods_off');
    } else if (sells && (l.itemId == null || !goods!.sells(l.itemId!))) {
      missing.add('line_${n}_item');
    } else if (sells && qty.value != null && goods!.inInventoryUnit(l.itemId!, l.unitCode, ExactQuantity.parse(l.quantity)) == null) {
      // a unit the item has no defined conversion from (0942: `unit`), never read as one
      missing.add('line_${n}_unit');
    } else if (!sells && l.supply != 'general' && l.supply != 'property') {
      missing.add('line_${n}_supply');
    }
    if (missing.isNotEmpty) return (line: null, missing: missing);
    final exp = Currencies.minorDigits(currency);
    // quantity x price / base, in minor units, half away from zero
    final q = qty.value!.value;
    final pr = price.value!.value;
    final b = base.value!.value;
    final num = q.units * pr.units * BigInt.from(10).pow(exp) * b.denominator;
    final den = q.denominator * pr.denominator * b.units;
    final rounded = (num * BigInt.two + den) ~/ (den * BigInt.two);
    final amount = rounded.toInt();
    final net = l.grossPrice
        ? (amount * 100.0 / (100 + percent)).round()
        : amount;
    final gross = l.grossPrice ? amount : amount + (net * percent / 100).round();
    final tax = gross - net;
    return (
      missing: const [],
      line: {
        'kind': sells ? 'goods' : 'service',
        'label': l.description,
        'quantity': 1,
        'amount_cents': gross,
        'vat_percent': percent,
        'vat_category': 'S',
        'supply': l.supply,
        if (sells) 'stock': {'item_id': l.itemId},
        'commercial': {
          'version': 1,
          'line_id': l.lineId,
          if (l.serviceId != null) 'service_id': l.serviceId,
          'quantity': qty.value!.text,
          'unit': {'code': l.unitCode, 'un_ece_code': l.unEceCode, 'label': l.unitLabel},
          'unit_price': {
            'amount': price.value!.text,
            'currency': currency,
            'basis': l.grossPrice ? 'gross' : 'net',
            'base_quantity': base.value!.text,
          },
          'supply': l.supply,
          'tax_facts': <String, Object?>{},
          'amounts': {
            'currency': currency,
            'net_minor': '$net',
            'tax_minor': '$tax',
            'gross_minor': '$gross',
            'rule': 'half_up_per_line',
          },
        },
      },
    );
  }

  ({Map<String, Object?>? preview, List<String> missing}) _build(String draftId) {
    final d = _drafts[draftId]!.draft;
    final missing = <String>[];
    if (d.lines.isEmpty) missing.add('lines');
    if (d.dueOn.isBefore(DateTime(_m.clock().year, _m.clock().month, _m.clock().day))) {
      missing.add('due_on_before_issue');
    }
    final lines = <Map<String, Object?>>[];
    for (final (i, l) in d.lines.indexed) {
      final rate = _m.vatRates.where((r) => r.id == l.vatRateId).firstOrNull;
      final built = _line(i + 1, l, rate?.percent ?? _m.defaultVatPercent);
      missing.addAll(built.missing);
      if (built.line != null) lines.add(built.line!);
    }
    final sold = missing.isEmpty ? _sold(d.lines) : const <({int n, String itemId, ExactQuantity quantity})>[];
    if (sold.isNotEmpty) {
      final short = goods!.shortLine([for (final s in sold) (itemId: s.itemId, quantity: s.quantity)]);
      if (short != null) missing.add('line_${sold[short].n}_stock_not_enough');
    }
    if (missing.isNotEmpty) return (preview: null, missing: missing);
    final byRate = <double, List<int>>{};
    for (final l in lines) {
      final a = (l['commercial']! as Map)['amounts']! as Map;
      final s = byRate.putIfAbsent((l['vat_percent']! as num).toDouble(), () => [0, 0]);
      s[0] += int.parse(a['net_minor']! as String);
      s[1] += int.parse(a['gross_minor']! as String);
    }
    return (
      missing: const [],
      preview: {
        'lines': lines,
        'vat_totals': [
          for (final e in byRate.entries)
            {
              'percent': e.key,
              'category': 'S',
              'net_cents': e.value[0],
              'gross_cents': e.value[1],
              'vat_cents': e.value[1] - e.value[0],
            },
        ],
        'total_cents': lines.fold<int>(0, (s, l) => s + (l['amount_cents']! as int)),
        'currency': currency,
      },
    );
  }

  @override
  Future<PreviewedDocument> preview({
    required String workspaceId,
    required String draftId,
    required int revision,
  }) async {
    final d = _drafts[draftId];
    if (d == null) return const PreviewedDocument(missing: ['draft_unknown']);
    if (d.revision != revision) return const PreviewedDocument(missing: ['draft_stale']);
    final built = _build(draftId);
    return PreviewedDocument.fromJson({
      'missing': built.missing,
      'preview': built.preview,
    });
  }

  @override
  Future<StandaloneIssued> issue({
    required String workspaceId,
    required String draftId,
    required int revision,
    required String requestId,
  }) async {
    final key = '$workspaceId|$requestId';
    final known = _m.invoiceReceipts[key];
    if (known != null) {
      final number = _m.invoices.firstWhere((i) => i.id == known).number;
      return StandaloneIssued(invoiceId: known, number: number, replayed: true);
    }
    final d = _drafts[draftId];
    if (d == null) throw _refused('draft_unknown');
    if (d.revision != revision) throw _refused('draft_stale');
    if (d.invoiceId != null) throw _refused('draft_closed');
    final built = _build(draftId);
    if (built.missing.isNotEmpty) throw _refused(built.missing.join(','));
    final p = built.preview!;
    final series = demoSeriesOf(_m, 'invoice');
    final counter = series.nextValue;
    final number = series.format(counter, _m.clock());
    final buyer = _m.invoiceQueries.buyers.of?.call(d.draft.subjectMemberId) ??
        (name: d.draft.subjectMemberId, address: '');
    final id = 'inv-${_m.nextInvoiceNumber}';
    final invoiceLines = [for (final l in p['lines']! as List) invoiceLineFromSnapshot(l as Map)];
    // #4433, #4436 -- the goods leave the store, and what each line took is frozen with the invoice
    final sold = _sold(d.draft.lines);
    final took = sold.isEmpty ? const <int, List<LineTrack>>{} : await goods!.sellOnInvoice(id, sold);
    _m.invoices.insert(
      0,
      Invoice(
        id: id,
        workspaceId: workspaceId,
        memberId: d.draft.subjectMemberId,
        number: number,
        issuedAt: _m.clock(),
        title: d.draft.serviceDay,
        lines: invoiceLines,
        lineTracks: {
          for (final MapEntry(:key, :value) in took.entries)
            if (invoiceLines[key - 1].commercialLineId case final lineId? when value.isNotEmpty) lineId: value,
        },
        totalCents: p['total_cents']! as int,
        currency: currency,
        memberName: buyer.name,
        memberAddress: buyer.address,
        workspaceName: 'Test Space',
        workspaceAddress: '2 Place du Marché, 34120 Pézenas',
        issuerName: 'Flo',
        signature: 'f' * 64,
        keepsOriginal: true,
      ),
    );
    _m.nextInvoiceNumber =
        (counter > _m.nextInvoiceNumber ? counter : _m.nextInvoiceNumber) + 1;
    if (series.stored) {
      _m.numberSequences['invoice'] = series.copyWith(nextValue: counter + 1);
    }
    _drafts[draftId] = (draft: d.draft, revision: d.revision, invoiceId: id);
    _m.invoiceReceipts[key] = id;
    return StandaloneIssued(invoiceId: id, number: number, replayed: false);
  }

  /// The goods lines of [lines]: their number on the invoice, the item and the exact quantity.
  List<({int n, String itemId, ExactQuantity quantity})> _sold(List<StandaloneLine> lines) => [
    for (final (i, l) in lines.indexed)
      // the ledger moves the item's inventory unit: a carton of 12 leaves 12 pieces (0942 stock_to_inventory)
      if (l.supply == 'goods' && l.itemId != null)
        (n: i + 1, itemId: l.itemId!, quantity: goods?.inInventoryUnit(l.itemId!, l.unitCode, ExactQuantity.parse(l.quantity)) ?? ExactQuantity.parse(l.quantity)),
  ];
}

/// #4433 -- the Demo's goods ledger, as the invoices sell from it.
abstract interface class DemoInvoiceGoods {
  /// Whether [itemId] is an item the ledger keeps.
  bool sells(String itemId);

  /// #4479 -- [quantity] counted in [unit] as the item's inventory unit, or null when no conversion is defined.
  ExactQuantity? inInventoryUnit(String itemId, String unit, ExactQuantity quantity);

  /// The index of the first line the main store cannot serve, or null.
  int? shortLine(List<({String itemId, ExactQuantity quantity})> lines);

  /// Moves the goods of an issued invoice out of the main store, linked to it, and answers the track IDs each line took
  /// (by the line's number on the invoice): the lots it was taken from, as received. A line that took nothing traced has
  /// none.
  Future<Map<int, List<LineTrack>>> sellOnInvoice(String invoiceId, List<({int n, String itemId, ExactQuantity quantity})> lines);
}
