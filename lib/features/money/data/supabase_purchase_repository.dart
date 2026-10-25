// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';
import '../domain/purchase.dart';

/// The purchase documents and their RPCs (0461). The tables are read under
/// row level security (a member sees their own, a manager all); every write
/// goes through an RPC that derives actor, state and totals.
class SupabasePurchaseRepository implements PurchaseRepository {
  const SupabasePurchaseRepository(this._client);

  final SupabaseClient _client;

  static const _payablePageSize = 100;
  static const _maxPayablePages = 20;

  @override
  Future<List<PurchaseSummary>> fetchPurchases(String workspaceId) async {
    final rows = await _client
        .from('purchase_documents')
        .select(
          'id, kind, state, category, original_reference, currency, '
          'received_on, legacy_qualification, purchase_lines(gross_cents)',
        )
        .eq('workspace_id', workspaceId)
        .order('created_datetime', ascending: false);
    return [for (final r in rows) PurchaseSummary.fromRow(r)];
  }

  @override
  Future<PurchaseDetail> fetchDetail(
    String workspaceId,
    String purchaseId,
  ) async {
    final json = await _client.rpc<Object?>(
      'purchase_detail_v1',
      params: {'p_workspace_id': workspaceId, 'p_purchase_id': purchaseId},
    );
    return PurchaseDetail.fromJson(json);
  }

  @override
  Future<void> linkInboxDocument(
    String workspaceId,
    String purchaseId, {
    required int revision,
    required String documentId,
    required String requestId,
  }) => _client.rpc<Object?>(
    'link_purchase_source_v1',
    params: {
      'p_workspace_id': workspaceId,
      'p_purchase_id': purchaseId,
      'p_source_kind': 'inbox',
      'p_source_id': documentId,
      'p_revision': revision,
      'p_request_id': requestId,
    },
  );

  @override
  Future<String?> purchaseFiledFrom(
    String workspaceId, {
    required String sourceKind,
    required String sourceId,
  }) async {
    final row = await _client
        .from('purchase_sources')
        .select('purchase_id')
        .eq('workspace_id', workspaceId)
        .eq('source_kind', sourceKind)
        .eq('source_id', sourceId)
        .maybeSingle();
    return row == null
        ? null
        : JsonReader(row, context: 'purchase_sources').string('purchase_id');
  }

  /// Every page, newest first. A workspace's claims are few; the cap stops a
  /// server that never ends its cursor.
  @override
  Future<List<PayableRow>> fetchPayables(
    String workspaceId, {
    CreditorKind? kind,
  }) async {
    final rows = <PayableRow>[];
    String? afterCreated;
    String? afterId;
    for (var page = 0; page < _maxPayablePages; page++) {
      final json = await _client.rpc<Object?>(
        'purchase_payables_page_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_creditor_kind': ?kind?.wire,
          'p_limit': _payablePageSize,
          'p_after_created': ?afterCreated,
          'p_after_id': ?afterId,
        },
      );
      final r = JsonReader.of(json, context: 'purchase_payables_page_v1');
      rows.addAll([for (final o in r.list('rows')) PayableRow.fromJson(o)]);
      final next = r.objectOrNull('next');
      if (next == null) return rows;
      afterCreated = next.string('created');
      afterId = next.string('id');
    }
    return rows;
  }

  @override
  Future<PurchaseObligation> recordReimbursement(
    String workspaceId,
    ReimbursementCommand command,
  ) async {
    final json = await _client.rpc<Object?>(
      command.creditorKind == CreditorKind.supplier
          ? 'record_supplier_payment_v1'
          : 'record_member_reimbursement_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_obligation_id': command.obligationId,
        'p_amount_cents': command.amountCents,
        'p_revision': command.revision,
        'p_request_id': command.requestId,
        'p_paid_on': isoDay(command.paidOn),
        'p_method': command.method.wire,
        'p_reference': command.reference,
      },
    );
    return PurchaseObligation.fromJson(
      JsonReader.of(
        json,
        context: 'record_member_reimbursement_v1',
      ).raw('obligation'),
    );
  }

  @override
  Future<PurchaseObligation> offsetClaim(
    String workspaceId,
    ClaimOffset offset,
  ) async {
    final json = await _client.rpc<Object?>(
      'offset_member_claim_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_obligation_id': offset.obligationId,
        'p_invoice_id': offset.invoiceId,
        'p_amount_cents': offset.amountCents,
        'p_revision': offset.revision,
        'p_request_id': offset.requestId,
        'p_note': offset.note,
      },
    );
    return PurchaseObligation.fromJson(
      JsonReader.of(json, context: 'offset_member_claim_v1').raw('obligation'),
    );
  }

  @override
  Future<PurchaseState> submitBill(
    String workspaceId,
    String purchaseId,
    int revision,
    String requestId,
  ) async {
    final json = await _client.rpc<Object?>(
      'submit_purchase_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_purchase_id': purchaseId,
        'p_revision': revision,
        'p_request_id': requestId,
      },
    );
    return PurchaseState.of(
      JsonReader.of(json, context: 'submit_purchase_v1').string('state'),
    );
  }

  @override
  Future<PurchaseState> decideBill(
    String workspaceId,
    String purchaseId,
    int revision, {
    required bool approve,
    required String reason,
    required String requestId,
  }) async {
    final json = await _client.rpc<Object?>(
      'decide_purchase_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_purchase_id': purchaseId,
        'p_revision': revision,
        'p_approve': approve,
        'p_reason': reason,
        'p_request_id': requestId,
      },
    );
    return PurchaseState.of(
      JsonReader.of(json, context: 'decide_purchase_v1').string('state'),
    );
  }

  @override
  Future<PurchaseState> applyCreditNote(
    String workspaceId,
    String purchaseId,
    int revision,
    String requestId,
  ) async {
    final json = await _client.rpc<Object?>(
      'apply_supplier_credit_note_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_credit_id': purchaseId,
        'p_revision': revision,
        'p_request_id': requestId,
      },
    );
    return PurchaseState.of(
      JsonReader.of(json, context: 'apply_supplier_credit_note_v1')
          .string('state'),
    );
  }

  @override
  Future<PurchaseObligation> reverseAllocation(
    String workspaceId, {
    required String allocationId,
    required int revision,
    required String reason,
    required String requestId,
  }) async {
    final json = await _client.rpc<Object?>(
      'reverse_purchase_allocation_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_allocation_id': allocationId,
        'p_revision': revision,
        'p_reason': reason,
        'p_request_id': requestId,
      },
    );
    return PurchaseObligation.fromJson(
      JsonReader.of(
        json,
        context: 'reverse_purchase_allocation_v1',
      ).raw('obligation'),
    );
  }

  @override
  Future<String> saveDraft(
    String workspaceId,
    String requestId,
    PurchaseDraft draft,
  ) async {
    final json = await _client.rpc<Object?>(
      'save_purchase_draft_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_request_id': requestId,
        'p_expected_revision': draft.expectedRevision,
        'p_payload': draft.toPayload(),
      },
    );
    return JsonReader.of(
      json,
      context: 'save_purchase_draft_v1',
    ).string('purchase_id');
  }

  /// Read under the tables' own policies: a member sees the space's plan.
  @override
  Future<List<PurchasePlace>> fetchPlaces(String workspaceId) async {
    final sites = await _client
        .from('sites')
        .select('id, name')
        .eq('workspace_id', workspaceId)
        .order('sort_order')
        .order('name');
    final levels = await _client
        .from('levels')
        .select('id, name, offices(id, name)')
        .eq('workspace_id', workspaceId)
        .order('sort_order')
        .order('name');
    PurchasePlace place(String kind, Object? row) {
      final r = JsonReader.of(row, context: kind);
      return PurchasePlace(kind: kind, id: r.string('id'), name: r.string('name'));
    }

    return [
      for (final s in sites) place('site', s),
      for (final l in levels) ...[
        place('level', l),
        for (final o in JsonReader.of(l, context: 'level').listOrAbsent('offices'))
          place('office', o),
      ],
    ];
  }

  @override
  Future<DocumentExchangeRate?> fetchExchangeRate(
    String workspaceId,
    String purchaseId,
  ) async {
    final row = await _client
        .from('document_exchange_rates')
        .select(_rateColumns)
        .eq('workspace_id', workspaceId)
        .eq('document_kind', 'purchase')
        .eq('document_id', purchaseId)
        .maybeSingle();
    return row == null ? null : DocumentExchangeRate.fromRow(row);
  }

  /// The rate as text: a numeric read as a JSON number would pass through a
  /// double.
  static const _rateColumns =
      'document_id, currency, functional_currency, rate::text, rate_date, '
      'source, revision';

  @override
  Future<DocumentExchangeRate> recordExchangeRate(
    String workspaceId,
    String purchaseId,
    ExchangeRateEntry entry,
  ) async {
    final json = await _client.rpc<Object?>(
      'record_purchase_exchange_rate_v1',
      params: {
        'p_workspace_id': workspaceId,
        'p_purchase_id': purchaseId,
        'p_rate': entry.rate.toString(),
        'p_rate_date': isoDay(entry.rateDate),
        'p_source': entry.source,
      },
    );
    return DocumentExchangeRate.fromRow(
      JsonReader.of(json, context: 'record_purchase_exchange_rate_v1').json,
    );
  }

  @override
  Future<List<String>> fetchExchangeRateSources() async {
    final rows = await _client
        .from('exchange_rate_sources')
        .select('code')
        .eq('active', true)
        .order('sort_order');
    return [
      for (final r in rows)
        JsonReader(r, context: 'exchange_rate_sources').string('code'),
    ];
  }
}
