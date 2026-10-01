// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/trace/trace_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/me_actions.dart';
import '../data/supabase_me_repository.dart';
import '../domain/me_repository.dart';
import '../domain/my_spaces.dart';
import '../domain/visibility.dart';

part 'me_providers.g.dart';

/// #1823 — the account layer's calls, this server's and the linked ones'.
@riverpod
MeRepository meRepository(Ref ref) => SupabaseMeRepository(
      Supabase.instance.client,
      ref.watch(authStateProvider).value == null
          ? null
          : ref.watch(connectedInstallationsProvider),
    );

@riverpod
MeActions meActions(Ref ref) => MeActions(ref.watch(meRepositoryProvider));

/// Who sees what of me, as the server holds it.
@riverpod
Future<MyVisibility> myVisibility(Ref ref) {
  if (ref.watch(authStateProvider).value == null) {
    return Future.value(MyVisibility.defaults);
  }
  return ref.watch(meRepositoryProvider).myVisibility();
}

/// "How others see me": what [audience] would read.
@riverpod
Future<AccountView> visibilityPreview(Ref ref, PreviewAudience audience) {
  // A change of any field re-asks the preview.
  ref.watch(myVisibilityProvider);
  return ref.watch(meRepositoryProvider).previewMyAccount(audience);
}

/// My spaces on every linked server. A server that does not answer is
/// reported as such — the list is then incomplete, never silently short.
@riverpod
Future<List<LinkedServerSpaces>> linkedServerSpaces(Ref ref) async {
  final repository = ref.watch(meRepositoryProvider);
  final sources = await ref.watch(connectedSourcesProvider.future);
  return [
    for (final source in sources)
      await () async {
        final url = source.endpoint.url;
        try {
          return LinkedServerSpaces(
            source: url,
            key: source.endpoint.key,
            spaces: await repository.spacesOn(url),
          );
        } catch (e, st) {
          TraceLogger.instance.warn('me', 'linked server spaces unavailable',
              error: e, stackTrace: st);
          return LinkedServerSpaces(
              source: url, key: source.endpoint.key, unavailable: true);
        }
      }(),
  ];
}
