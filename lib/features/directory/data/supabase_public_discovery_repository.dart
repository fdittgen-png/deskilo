// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/backend_settings.dart';
import '../../../core/backend/connected_installations.dart';
import '../../../core/public_network/public_network_codec.dart';
import '../../../core/public_network/public_network_operations.dart';
import '../../../core/public_network/public_network_spec.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/discovery_paging.dart';
import '../domain/public_workspace.dart';

/// #1847 — the PUBLIC discovery interface. Every request is anonymous: a
/// fresh client per origin, behind [OriginOnlyClient], carrying only that
/// installation's publishable key. A signed-in user's session never
/// accompanies a catalogue request, including to this installation. What
/// it binds to and what it keeps are the generated contract's.
class SupabasePublicDiscoveryRepository implements PublicDiscoveryRepository {
  SupabasePublicDiscoveryRepository({
    required this.origin,
    required this.publishableKey,
    this.local,
    http.Client Function()? transport,
  }) : transport = transport ?? http.Client.new;

  /// The directory's origin and publishable key (#2343: the global
  /// directory on the reference deployment).
  final String origin, publishableKey;

  /// #2343 — this device's own server when it is not the directory's: its
  /// published spaces are listed whether or not it was linked.
  final BackendEndpoint? local;

  /// The raw HTTP client each anonymous client is built on.
  final http.Client Function() transport;

  static const _sources = PublicNetworkOperations.directorySourcesList;
  static const _search = PublicNetworkOperations.directoryWorkspacesSearch;
  static const _detail = PublicNetworkOperations.directoryWorkspacesDetail;

  SupabaseClient _anonymous(String url, String key) => SupabaseClient(
    url,
    key,
    httpClient: OriginOnlyClient(url, transport()),
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  PostgrestTransformBuilder<PostgrestList> _ordered(
    PostgrestTransformBuilder<PostgrestList> query,
    PublicOperationSpec op,
  ) {
    for (final term in op.order) {
      final parts = term.split('.');
      query = query.order(parts.first, ascending: parts.last == 'asc');
    }
    return query;
  }

  Future<PostgrestList> _read(
    PostgrestTransformBuilder<PostgrestList> query,
    PublicOperationSpec op,
  ) => query.timeout(Duration(seconds: op.timeoutSeconds ?? 12));

  @override
  Future<DirectorySourcesPage> sources({int page = 0}) async {
    final size = _sources.pageSize!;
    final home = _anonymous(origin, publishableKey);
    final PostgrestList rows;
    try {
      rows = await _read(
        _ordered(
          home.from(_sources.relation!).select(_sources.selectClause),
          _sources,
        ).range(page * size, page * size + size - 1),
        _sources,
      );
    } finally {
      await home.dispose();
    }
    // The directory and this device's own server lead the first page; a
    // later page lists only what the directory names.
    final endpoints = <String, String>{
      if (page == 0) origin: publishableKey,
      if (page == 0)
        if (local case final own?) own.url: own.key,
    };
    final refused = <String>[];
    for (final row in rows) {
      try {
        final source = decodePublicRecord(_sources.output!, row);
        endpoints.putIfAbsent(
          source['origin']! as String,
          () => source['publishable_key']! as String,
        );
      } on PublicContractRefusal {
        refused.add('${row['origin']}');
      }
    }
    final valid = <DirectorySource>[];
    for (final MapEntry(:key, :value) in endpoints.entries) {
      if (validateBackendEndpoint(key, value) == null) {
        valid.add(DirectorySource(key, value));
      } else {
        refused.add(key);
      }
    }
    return DirectorySourcesPage(
      valid,
      refused: refused,
      more: rows.length == size,
    );
  }

  @override
  Future<SourceCardsPage> workspaces(
    DirectorySource source,
    String query, {
    int page = 0,
  }) async {
    if (validateBackendEndpoint(source.origin, source.key) != null) {
      throw StateError('invalid public endpoint');
    }
    final size = _search.pageSize!;
    final client = _anonymous(source.origin, source.key);
    try {
      var request = client.from(_search.relation!).select(_search.selectClause);
      if (query.trim().isNotEmpty) {
        request = request.ilike(
          'search_text',
          '%${query.trim().replaceAll('%', '\\%').replaceAll('_', '\\_')}%',
        );
      }
      final rows = await _read(
        _ordered(request, _search).range(page * size, page * size + size - 1),
        _search,
      );
      final cards = <PublicWorkspace>[];
      var incompatible = false;
      for (final row in rows) {
        try {
          cards.add(_card(row, source.origin, source.key));
        } on PublicContractRefusal {
          incompatible = true;
        }
      }
      return SourceCardsPage(
        cards,
        incompatible: incompatible,
        more: rows.length == size,
      );
    } on Object catch (e, st) {
      // Never include remote request headers or response bodies in
      // diagnostics.
      TraceLogger.instance.warn(
        'directory',
        'public directory unavailable',
        error: e.runtimeType,
        stackTrace: st,
      );
      rethrow;
    } finally {
      await client.dispose();
    }
  }

  @override
  Future<PublicWorkspace?> detail(PublicWorkspace card) async {
    // A preview of one's own page has no source to ask.
    if (card.source.isEmpty) return card;
    if (validateBackendEndpoint(card.source, card.key) != null) {
      throw StateError('invalid public endpoint');
    }
    final client = _anonymous(card.source, card.key);
    try {
      final rows = await _read(
        _ordered(
          client
              .from(_detail.relation!)
              .select(_detail.selectClause)
              .eq('workspace_id', card.id),
          _detail,
        ).limit(_detail.pageSize!),
        _detail,
      );
      if (rows.isEmpty) return null;
      return _card(rows.single, card.source, card.key);
    } finally {
      await client.dispose();
    }
  }

  PublicWorkspace _card(Map<String, dynamic> row, String source, String key) {
    final card = decodePublicRecord(_search.output!, row);
    return PublicWorkspace(
      card['workspace_id']! as String,
      source,
      key,
      Map<String, dynamic>.from(card['document']! as Map),
    );
  }
}
