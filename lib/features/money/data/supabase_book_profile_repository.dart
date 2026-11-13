// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/unreadable_rows.dart';
import '../domain/book_chart.dart';
import '../domain/book_profile_repository.dart';

/// #1869 — book profiles through their two definer functions (0335).
class SupabaseBookProfileRepository implements BookProfileRepository {
  SupabaseBookProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<BookProfile>> fetchBookProfiles(String workspaceId) async {
    final rows = await _client.rpc<dynamic>(
      'book_profiles',
      params: {'p_workspace_id': workspaceId},
    );
    return [
      for (final row in (rows as List? ?? const []))
        BookProfile.fromJson(Map<String, Object?>.from(row as Map)),
    ];
  }

  @override
  Future<BookProfile?> saveBookProfile(BookProfile p) async {
    try {
      final row = await _client.rpc<dynamic>(
        'save_book_profile',
        params: {
          'p_workspace_id': p.workspaceId,
          'p_issuer_site_id': p.issuerSiteId,
          'p_authority_mode': p.authority.wire,
          'p_external_system': p.externalSystem,
          'p_functional_currency': p.functionalCurrency,
          'p_fiscal_year_start_month': p.fiscalYearStartMonth,
          'p_fiscal_year_start_day': p.fiscalYearStartDay,
          'p_accounting_basis': p.basis.name,
          'p_effective_from': p.toJson()['effective_from'],
          'p_expected_revision': p.revision,
        },
      );
      return BookProfile.fromJson(Map<String, Object?>.from(row as Map));
    } on PostgrestException catch (e, st) {
      // trace-exempt: a stale save is an answer, anything else is rethrown
      // for the caller's runGuarded to trace.
      if (e.code == '40001') return null;
      Error.throwWithStackTrace(e, st);
    }
  }

  @override
  Future<({List<BookAccount> accounts, List<BookMapping> mappings})>
  fetchBookChart(String workspaceId) async {
    final row = await _client.rpc<dynamic>(
      'book_chart',
      params: {'p_workspace_id': workspaceId},
    );
    final read = bookChartFromJson(Map<String, Object?>.from(row as Map));
    UnreadableRows.instance
      ..record(booksAccountsArea(workspaceId), 'chart', read.unreadableAccounts)
      ..record(booksMappingsArea(workspaceId), 'chart', read.unreadableMappings);
    return (accounts: read.accounts, mappings: read.mappings);
  }

  @override
  Future<BookAccount?> saveBookAccount(BookAccount a) async {
    try {
      final row = await _client.rpc<dynamic>(
        'save_book_account',
        params: {
          'p_workspace_id': a.workspaceId,
          'p_issuer_site_id': a.issuerSiteId,
          'p_id': a.id.isEmpty ? null : a.id,
          'p_code': a.code,
          'p_name': a.name,
          'p_account_type': a.type.name,
          'p_is_posting': a.isPosting,
          'p_origin': a.origin.name,
          'p_expected_revision': a.revision,
        },
      );
      return BookAccount.fromJson(Map<String, Object?>.from(row as Map));
    } on PostgrestException catch (e, st) {
      // trace-exempt: a stale save is an answer, anything else is rethrown
      // for the caller's runGuarded to trace.
      if (e.code == '40001') return null;
      Error.throwWithStackTrace(e, st);
    }
  }

  @override
  Future<BookMapping?> saveBookMapping({
    required String workspaceId,
    required String issuerSiteId,
    required BookRole role,
    required String accountId,
    required DateTime effectiveFrom,
    required int expectedRevision,
    String? qualifier,
  }) async {
    try {
      final row = await _client.rpc<dynamic>(
        'save_book_mapping',
        params: {
          'p_workspace_id': workspaceId,
          'p_issuer_site_id': issuerSiteId,
          'p_role': qualifier == null ? role.wire : '${role.wire}:$qualifier',
          'p_account_id': accountId,
          'p_effective_from': bookDate(effectiveFrom),
          'p_expected_revision': expectedRevision,
        },
      );
      return BookMapping.fromJson(Map<String, Object?>.from(row as Map));
    } on PostgrestException catch (e, st) {
      // trace-exempt: a stale save is an answer, anything else is rethrown
      // for the caller's runGuarded to trace.
      if (e.code == '40001') return null;
      Error.throwWithStackTrace(e, st);
    }
  }

  @override
  Future<PostingSet> fetchPostings(
    String workspaceId,
    String issuerSiteId,
    DateTime from,
    DateTime to,
  ) async {
    final row = await _client.rpc<Object?>(
      'compute_postings',
      params: {
        'p_workspace_id': workspaceId,
        'p_issuer_site_id': issuerSiteId,
        'p_from': isoDay(from),
        'p_to': isoDay(to),
      },
    );
    final set = PostingSet.fromJson(Map<String, Object?>.from(row! as Map));
    UnreadableRows.instance.record(
      booksPostingsArea(workspaceId),
      '${isoDay(from)}|${isoDay(to)}',
      {
        for (final b in set.blockers)
          if (b.block == PostingBlock.unreadable)
            b.subject: 'posting role, kind, journal or block',
      },
    );
    return set;
  }

  @override
  Future<Map<String, PostingParty>> fetchPostingParties(
    String workspaceId,
    List<String> documentIds,
  ) async {
    final row = await _client.rpc<Object?>(
      'posting_parties',
      params: {'p_workspace_id': workspaceId, 'p_document_ids': documentIds},
    );
    return {
      for (final MapEntry(:key, :value)
          in Map<String, Object?>.from(row! as Map).entries)
        key: PostingParty.fromJson(Map<String, Object?>.from(value! as Map)),
    };
  }
}
