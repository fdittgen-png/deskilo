// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- customer quotes over the RPCs of 0828. A server refusal
// becomes a typed [QuoteRefusal]; a transport failure passes through untouched
// (a write is never retried here: the screen offers the retry).
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/dk_code.dart';
import '../../../core/data/pg_code.dart';
import '../domain/customer_quote.dart';

class SupabaseCustomerQuoteRepository implements CustomerQuoteRepository {
  const SupabaseCustomerQuoteRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<CustomerQuote>> quotes(String workspaceId) async {
    final rows = await _asRefusal(
      () => _client.rpc<Object?>(
        'customer_quotes_v1',
        params: {'p_workspace_id': workspaceId},
      ),
    );
    if (rows is! List) return const [];
    return [for (final row in rows) CustomerQuote.fromJson(row)];
  }

  @override
  Future<CustomerQuote> quote(String workspaceId, String quoteId) async =>
      CustomerQuote.fromJson(
        await _asRefusal(
          () => _client.rpc<Object?>(
            'customer_quote_v1',
            params: {'p_workspace_id': workspaceId, 'p_quote_id': quoteId},
          ),
        ),
      );

  @override
  Future<QuoteSaved> saveDraft(
    String workspaceId, {
    required QuoteDraftInput input,
    String? quoteId,
    int? expectedVersion,
  }) async => QuoteSaved.fromJson(
    await _asRefusal(
      () => _client.rpc<Object?>(
        'save_customer_quote_draft_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_quote_id': quoteId,
          'p_expected_version': expectedVersion,
          'p_subject': input.subjectId,
          'p_issued_on': input.issuedOn == null ? null : isoDay(input.issuedOn!),
          'p_valid_until': input.validUntil == null ? null : isoDay(input.validUntil!),
          'p_buyer_reference': input.buyerReference,
          'p_purchase_order': input.purchaseOrder,
          'p_notes': input.notes,
          'p_lines': [for (final l in input.lines) l.toWire()],
        },
      ),
    ),
  );

  @override
  Future<QuoteSaved> amend(String workspaceId, String quoteId) async =>
      QuoteSaved.fromJson(
        await _asRefusal(
          () => _client.rpc<Object?>(
            'amend_customer_quote_v1',
            params: {'p_workspace_id': workspaceId, 'p_quote_id': quoteId},
          ),
        ),
      );

  @override
  Future<QuoteSent> send(
    String workspaceId,
    String quoteId, {
    required int revision,
    required int version,
  }) async => QuoteSent.fromJson(
    await _asRefusal(
      () => _client.rpc<Object?>(
        'send_customer_quote_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_quote_id': quoteId,
          'p_revision': revision,
          'p_expected_version': version,
        },
      ),
    ),
  );

  @override
  Future<void> recordDecision(
    String workspaceId,
    String quoteId,
    QuoteDecisionInput decision,
  ) async {
    await _asRefusal(
      () => _client.rpc<Object?>(
        'record_customer_quote_decision_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_quote_id': quoteId,
          'p_revision': decision.revision,
          'p_decision': decision.accepted ? 'accepted' : 'declined',
          'p_decided_on': isoDay(decision.decidedOn),
          'p_source': decision.source,
          'p_evidence': decision.evidence,
        },
      ),
    );
  }

  @override
  Future<QuoteConversionPrep> prepareConversion(
    String workspaceId,
    String quoteId, {
    required DateTime serviceDate,
    required DateTime dueOn,
  }) async => QuoteConversionPrep.fromJson(
    await _asRefusal(
      () => _client.rpc<Object?>(
        'prepare_quote_conversion_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_quote_id': quoteId,
          'p_service_date': isoDay(serviceDate),
          'p_due_on': isoDay(dueOn),
        },
      ),
    ),
  );

  @override
  Future<QuoteConverted> convert(
    String workspaceId,
    String quoteId, {
    required int draftRevision,
    required String requestId,
    String? reviewedDigest,
  }) async => QuoteConverted.fromJson(
    await _asRefusal(
      () => _client.rpc<Object?>(
        'convert_customer_quote_v1',
        params: {
          'p_workspace_id': workspaceId,
          'p_quote_id': quoteId,
          'p_draft_revision': draftRevision,
          'p_request_id': requestId,
          'p_reviewed_digest': reviewedDigest,
        },
      ),
    ),
  );

  @override
  Future<void> cancel(String workspaceId, String quoteId) async {
    await _asRefusal(
      () => _client.rpc<Object?>(
        'cancel_customer_quote_v1',
        params: {'p_workspace_id': workspaceId, 'p_quote_id': quoteId},
      ),
    );
  }

  @override
  Future<void> discardDraft(String workspaceId, String quoteId) async {
    await _asRefusal(
      () => _client.rpc<Object?>(
        'discard_customer_quote_draft_v1',
        params: {'p_workspace_id': workspaceId, 'p_quote_id': quoteId},
      ),
    );
  }

  /// The server's refusals of 0828 by code: DKQ02 stale, DKQ03 state, DKQ06 and
  /// DKI01 an incomplete quote (the detail names the facts), DKQ10 switched off,
  /// DKN01 and DKQ07 not allowed.
  Future<T> _asRefusal<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e, st) {
      // trace-exempt: a refusal is rethrown typed with its cause and stack; a
      // failure that is not one passes through untouched.
      final kind = switch (e.code) {
        DkCode.dkq02 => QuoteRefusalKind.stale,
        DkCode.dkq03 || DkCode.dkq05 => QuoteRefusalKind.state,
        DkCode.dkq04 => QuoteRefusalKind.expired,
        DkCode.dkq08 => QuoteRefusalKind.needsReview,
        DkCode.dkq06 || DkCode.dki01 => QuoteRefusalKind.incomplete,
        DkCode.dkq10 => QuoteRefusalKind.featureOff,
        DkCode.dkn01 || DkCode.dkq07 || PgCode.invalidAuthorization => QuoteRefusalKind.notAllowed,
        _ => null,
      };
      if (kind == null) rethrow;
      final detail = e.details?.toString() ?? '';
      Error.throwWithStackTrace(
        QuoteRefusal(
          kind,
          missing: detail.isEmpty || kind == QuoteRefusalKind.needsReview
              ? const []
              : detail.split(','),
          detail: kind == QuoteRefusalKind.needsReview ? detail : '',
        ),
        st,
      );
    }
  }
}
