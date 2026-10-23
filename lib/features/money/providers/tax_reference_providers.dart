// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/context_client_providers.dart';
import '../../../core/cache/cache_store.dart';
import '../../../core/instance/tax_reference_bundle_asset.dart';
import '../../../core/vat/tax_reference.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/tax_reference_commands.dart';
import '../data/supabase_tax_reference_repository.dart';

part 'tax_reference_providers.g.dart';

/// #2477 -- the tax reference store: read and (platform owners) written.
@Riverpod(keepAlive: true)
TaxReferenceStore taxReferenceRepository(Ref ref) =>
    SupabaseTaxReferenceRepository(
      ref.watch(personalClientProvider),
      ref.watch(cacheStoreProvider),
    );

/// Creating a new version (the form's decision).
@riverpod
TaxReferenceCommands taxReferenceCommands(Ref ref) =>
    TaxReferenceCommands(ref.watch(taxReferenceRepositoryProvider));

/// The store, falling back to the copy bundled with the app when the
/// installation cannot answer.
@Riverpod(keepAlive: true)
TaxReferenceSource taxReferenceSource(Ref ref) =>
    BundledFallbackTaxReferenceSource(
      ref.watch(taxReferenceRepositoryProvider),
      ref.watch(taxReferenceBundleLoaderProvider),
    );

/// Every version of every reference value, for the signed-in person on the
/// installation they are connected to. A different person re-reads it (the
/// provider watches the session); a write invalidates it.
@riverpod
Future<TaxReferenceSet> taxReferenceSet(Ref ref) async {
  final source = ref.watch(taxReferenceSourceProvider);
  final signedIn = ref.watch(authStateProvider).value != null;
  if (!signedIn) return const TaxReferenceSet([]);
  return source.load();
}
