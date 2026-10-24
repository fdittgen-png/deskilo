// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L4 -- reading an installation's tax reference rows through ITS OWN
// client. The store (`features/money/data`) reads and writes the rows of the
// installation the app is signed in to; a workspace context reads the rows of
// the selected workspace's host with the same read, under the context's cache
// namespace, and falls back to the copy bundled with the app -- never to
// another installation's rows.
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../cache/cache_store.dart';
import '../../cache/cached_fetch.dart';
import '../../cache/target_cache_store.dart';
import '../../vat/tax_reference.dart';
import '../tax_reference_bundle_asset.dart';

part 'installation_tax_reference.g.dart';

/// The cache prefix of every tax reference read; a write drops it.
const taxReferenceCachePrefix = 'tax_reference:v1:';

/// The rows [client]'s installation holds (0427 `tax_reference_history`),
/// optionally of one [domain] / [country]. The network answers first; the
/// [cache] only stands in for an outage.
Future<TaxReferenceSet> readInstallationTaxReference(
  SupabaseClient client,
  CacheStore cache, {
  TaxDomain? domain,
  String? country,
}) {
  final c = country?.trim().toUpperCase();
  return cachedFetch<TaxReferenceSet>(
    cache: cache,
    key: '$taxReferenceCachePrefix${domain?.wire ?? '*'}:${c ?? '*'}',
    ttl: const Duration(hours: 12),
    mode: CacheReadMode.networkFirst,
    fetchRaw: () => client.rpc<Object?>(
      'tax_reference_history',
      params: {'p_domain': domain?.wire, 'p_country': c, 'p_key': null},
    ),
    parse: TaxReferenceSet.parse,
  );
}

/// How a workspace context reads the tax reference of its workspace's
/// installation: its host's [client], its cache namespace.
typedef WorkspaceTaxReferenceReader = Future<TaxReferenceSet> Function(
  SupabaseClient client,
  String cacheNamespace,
);

class _InstallationRows implements TaxReferenceSource {
  _InstallationRows(this._client, this._cache);

  final SupabaseClient _client;
  final CacheStore _cache;

  @override
  Future<TaxReferenceSet> load({TaxDomain? domain, String? country}) =>
      readInstallationTaxReference(_client, _cache,
          domain: domain, country: country);
}

/// The installation's rows; the bundled copy when it cannot answer or holds
/// none.
@Riverpod(keepAlive: true)
WorkspaceTaxReferenceReader workspaceTaxReferenceReader(Ref ref) {
  final cache = ref.watch(cacheStoreProvider);
  final bundled = ref.watch(taxReferenceBundleLoaderProvider);
  return (client, namespace) async {
    final set = await BundledFallbackTaxReferenceSource(
      _InstallationRows(client, TargetCacheStore(cache, namespace)),
      bundled,
    ).load();
    return set.isEmpty ? bundled() : set;
  };
}
