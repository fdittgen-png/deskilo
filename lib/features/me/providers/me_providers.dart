// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/connected_installations.dart';
import '../../../core/backend/context_client_providers.dart';
import '../../../core/trace/trace_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/me_actions.dart';
import '../data/supabase_linked_me_repository.dart';
import '../data/supabase_me_repository.dart';
import '../domain/linked_me_repository.dart';
import '../domain/me_repository.dart';
import '../domain/my_spaces.dart';
import '../domain/visibility.dart';

part 'me_providers.g.dart';

/// #1823 — the account layer's calls on this server.
/// #2561 C1 — the own-profile reads and writes go to the PERSONAL client (P),
/// never to the process-wide client or to a workspace host.
@riverpod
MeRepository meRepository(Ref ref) =>
    SupabaseMeRepository(ref.watch(personalClientProvider));

/// The account layer's calls on the linked servers, each with that server's
/// own session. The readers below ask it nothing while no server is linked.
@riverpod
LinkedMeRepository linkedMeRepository(Ref ref) =>
    SupabaseLinkedMeRepository(ref.watch(connectedInstallationsProvider));

@riverpod
MeActions meActions(Ref ref) => MeActions(
      ref.watch(meRepositoryProvider),
      ref.watch(linkedMeRepositoryProvider),
    );

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

/// #2211 — who sees what of me on the linked server [source]; the
/// defaults while no server is linked.
@riverpod
Future<MyVisibility> linkedVisibility(Ref ref, String source) async {
  final repository = ref.watch(linkedMeRepositoryProvider);
  final sources = await ref.watch(connectedSourcesProvider.future);
  if (sources.isEmpty) return MyVisibility.defaults;
  return repository.visibility(source);
}

/// My spaces on every linked server, all servers asked at once. A server
/// that does not answer is reported as such — the list is then incomplete,
/// never silently short — and does not hold up the others.
@riverpod
Future<List<LinkedServerSpaces>> linkedServerSpaces(Ref ref) async {
  final repository = ref.watch(linkedMeRepositoryProvider);
  final sources = await ref.watch(connectedSourcesProvider.future);
  if (sources.isEmpty) return const [];
  Future<LinkedServerSpaces> read(ConnectedInstallation source) async {
    final url = source.endpoint.url;
    try {
      return LinkedServerSpaces(
        source: url,
        key: source.endpoint.key,
        spaces: await repository.spaces(url),
      );
    } on Object catch (e, st) {
      TraceLogger.instance.warn('me', 'linked server spaces unavailable',
          error: e, stackTrace: st);
      return LinkedServerSpaces(
          source: url, key: source.endpoint.key, unavailable: true);
    }
  }

  return Future.wait(sources.map(read));
}
