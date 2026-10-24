// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/connected_installations.dart';
import '../../../core/backend/connected_pool_host_resolver.dart';
import '../../../core/backend/context_client_providers.dart';
import '../../../core/backend/context_clients.dart'
    show ActiveInstallationHostResolver;
import '../../../core/trace/trace_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../application/account_favorite.dart';
import '../application/me_actions.dart';
import '../application/my_reservation_sources.dart';
import '../application/workspace_exports.dart';
import '../data/host_workspace_access_repository.dart';
import '../data/host_workspace_export_repository.dart';
import '../data/supabase_linked_me_repository.dart';
import '../data/supabase_me_repository.dart';
import '../domain/linked_me_repository.dart';
import '../domain/me_repository.dart';
import '../domain/my_spaces.dart';
import '../domain/personal_export.dart';
import '../domain/personal_workspace_refs.dart';
import '../domain/visibility.dart';
import '../domain/workspace_access_repository.dart';
import '../domain/workspace_export.dart';
import 'me_read_retry.dart';
import 'space_prefs_provider.dart';

part 'me_providers.g.dart';

/// #1823 — the account layer's calls on this server.
/// #2561 C1 — the own-profile reads and writes go to the PERSONAL client (P),
/// never to the process-wide client or to a workspace host.
@riverpod
MeRepository meRepository(Ref ref) =>
    SupabaseMeRepository(ref.watch(personalClientProvider));

/// #2563 C1 — the account's calls inside a workspace (leaving it), on the
/// verified host of that workspace, never on the personal client.
@riverpod
WorkspaceAccessRepository workspaceAccessRepository(Ref ref) =>
    HostWorkspaceAccessRepository(ref.watch(workspaceHostResolverProvider));

/// The account layer's calls on the linked servers, each with that server's
/// own session. The readers below ask it nothing while no server is linked.
@riverpod
LinkedMeRepository linkedMeRepository(Ref ref) =>
    SupabaseLinkedMeRepository(ref.watch(connectedInstallationsProvider));

@riverpod
MeActions meActions(Ref ref) => MeActions(
      ref.watch(meRepositoryProvider),
      ref.watch(linkedMeRepositoryProvider),
      ref.watch(workspaceAccessRepositoryProvider),
    );

/// Who sees what of me, as the personal home holds it. #2558 — read on the
/// personal client with no workspace involved; a failure is an error the
/// editor names, never the defaults shown as if they were saved.
@Riverpod(retry: meReadRetry)
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

/// #2563 C1 — the workspaces my account names by qualified reference, read
/// on my personal home with no workspace selected; none while signed out.
/// A refusal or a malformed answer is final: no silent retries.
@Riverpod(retry: personalRefsRetry)
Future<PersonalWorkspaceRefs> personalWorkspaceRefs(Ref ref) {
  if (ref.watch(authStateProvider).value == null) {
    return Future.value(PersonalWorkspaceRefs.none);
  }
  return ref.watch(meRepositoryProvider).myWorkspaceRefs();
}

/// No retry for [personalWorkspaceRefsProvider] (#2339): the section says
/// it is unavailable at once rather than after ten attempts.
Duration? personalRefsRetry(int retryCount, Object error) => null;

/// What [answer] may show of the account signed in now. A reload is the
/// read started again because the account or its personal home changed:
/// what the previous read holds belongs to that other context and is not
/// shown. A refresh of the same account (Try again) keeps it on screen.
PersonalWorkspaceRefs? refsOfCurrentAccount(
  AsyncValue<PersonalWorkspaceRefs> answer,
) =>
    answer.isReloading ? null : answer.value;

/// #2553 C2 -- My reservations reads every host my personal account names,
/// not only the selected workspace's. The composition root puts it in its
/// scope's overrides (reservations sits below me in the feature graph).
final Override myReservationsSourcesFromMe =
    myReservationsSourcesProvider.overrideWith((ref) async {
  final refs = await ref.watch(personalWorkspaceRefsProvider.future);
  return myReservationSourcesOf(refs);
});

/// #2557 C2 — the personal part of my data, read on my personal home while
/// My data's personal view shows it; dropped when it closes, so each visit
/// reads what the home holds now. Signed out there is nothing to read.
@Riverpod(retry: personalRefsRetry)
Future<PersonalExport> personalExport(Ref ref) {
  if (ref.watch(authStateProvider).value == null) {
    return Future.error(
        const PersonalExportRefused(PersonalExportFailure.forbidden));
  }
  return ref.watch(meRepositoryProvider).exportMyPersonalData();
}

/// #2557 C3 — a workspace's own-data export, asked on that workspace's
/// verified host with its own client: the installation the app is signed
/// in to, or the connected installation the source names. Demo overrides
/// it with the fixture's spaces.
@riverpod
WorkspaceExportRepository workspaceExportRepository(Ref ref) =>
    HostWorkspaceExportRepository(
      hostOf: (source) => resolveWorkspaceExportHost(
        source,
        connected: () => ref.read(connectedSourcesProvider.future),
        resolverFor: (origin) => ConnectedPoolHostResolver(
          active: ActiveInstallationHostResolver(
            ref.read(personalClientProvider),
            ref.read(installationIdReaderProvider),
          ),
          root: ref.read(personalClientProvider),
          pool: () => ref.read(connectedInstallationsProvider),
          sourceOf: (_) => origin,
        ),
      ),
    );

/// #2557 C3 — the workspaces whose own records I may export, from the
/// workspaces my personal account names; none while signed out.
@Riverpod(retry: personalRefsRetry)
Future<List<WorkspaceExportSource>> myWorkspaceExportSources(Ref ref) async {
  final refs = await ref.watch(personalWorkspaceRefsProvider.future);
  return workspaceExportSourcesOf(refs);
}

/// #2557 C3 — the export command. The card that offers the exports
/// watches it, and hands in the signed-in account it reads.
@riverpod
WorkspaceExportCommand workspaceExportCommand(Ref ref) =>
    WorkspaceExportCommand(
      repository: ref.watch(workspaceExportRepositoryProvider),
    );

/// #2554 — the heart of My spaces: kept on the account by reference, this
/// device's copy shown at once and kept when the home refuses or is out of
/// reach. The card that shows the heart watches it.
@riverpod
AccountFavoriteCommand accountFavoriteCommand(Ref ref) =>
    AccountFavoriteCommand(
      repository: ref.watch(meRepositoryProvider),
      keepOnDevice: ref.read(spacePrefsProvider.notifier).setFavorite,
      reloadAccount: () => ref.refresh(personalWorkspaceRefsProvider.future),
    );
