// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/cache/cache_store.dart';
import '../../../core/instance/data/installation_tax_reference.dart';
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

  static const _prefix = taxReferenceCachePrefix;

  /// #2561 L4 -- the same read a workspace context makes of its host.
  @override
  Future<TaxReferenceSet> load({TaxDomain? domain, String? country}) =>
      readInstallationTaxReference(_client, _cache,
          domain: domain, country: country);

  @override
  Future<TaxReferenceRow> setVersion(TaxVersionDraft draft) async {
    final row = await _client.rpc<Object?>(
      'set_tax_reference',
      params: {
        'p_domain': draft.domain.wire,
        'p_country': draft.country,
        'p_key': draft.key,
        'p_value': draft.value.toJson(),
        'p_source': draft.source,
        'p_confirmed': draft.confirmed,
        'p_valid_from': draft.validFrom,
      },
    );
    await _cache.invalidatePrefix(_prefix);
    return TaxReferenceRow.fromJson(row);
  }

  @override
  Future<TaxReferenceRow> confirm(String id, {String? source}) async {
    final row = await _client.rpc<Object?>(
      'confirm_tax_reference',
      params: {'p_id': id, 'p_source': source},
    );
    await _cache.invalidatePrefix(_prefix);
    return TaxReferenceRow.fromJson(row);
  }

  @override
  Future<void> withdraw(String id, String reason) async {
    await _client.rpc<Object?>(
      'withdraw_tax_reference',
      params: {'p_id': id, 'p_reason': reason},
    );
    await _cache.invalidatePrefix(_prefix);
  }
}
