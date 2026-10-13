// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/cache/cached_fetch.dart';
import '../../../core/vat/tax_reference.dart';

/// #2477 — the tax reference store through its definer functions (0427).
///
/// Reads go through the scoped cache, whose keys already name the
/// installation and the signed-in person; the key adds the scope of the
/// read (domain, country) and a schema generation. The cache is a copy, not
/// an authority: every successful read replaces it, and a write drops it.
class SupabaseTaxReferenceRepository
    implements TaxReferenceStore {
  SupabaseTaxReferenceRepository(this._client, this._cache);

  final SupabaseClient _client;
  final CacheStore _cache;

  static const _prefix = 'tax_reference:v1:';
  static const _ttl = Duration(hours: 12);

  @override
  Future<TaxReferenceSet> load({TaxDomain? domain, String? country}) {
    final c = country?.trim().toUpperCase();
    return cachedFetch<TaxReferenceSet>(
      cache: _cache,
      key: '$_prefix${domain?.wire ?? '*'}:${c ?? '*'}',
      ttl: _ttl,
      // The network answers first; the cache only stands in for an outage.
      mode: CacheReadMode.networkFirst,
      fetchRaw: () => _client.rpc<Object?>(
        'tax_reference_history',
        params: {'p_domain': domain?.wire, 'p_country': c, 'p_key': null},
      ),
      parse: TaxReferenceSet.parse,
    );
  }

  @override
  Future<TaxReferenceRow> setVersion({
    required TaxDomain domain,
    required String country,
    required String key,
    required TaxValue value,
    required String source,
    required bool confirmed,
    required String validFrom,
  }) async {
    final row = await _client.rpc<Object?>(
      'set_tax_reference',
      params: {
        'p_domain': domain.wire,
        'p_country': country,
        'p_key': key,
        'p_value': value.toJson(),
        'p_source': source,
        'p_confirmed': confirmed,
        'p_valid_from': validFrom,
      },
    );
    await _cache.invalidatePrefix(_prefix);
    return TaxReferenceRow.fromJson(row);
  }
}
