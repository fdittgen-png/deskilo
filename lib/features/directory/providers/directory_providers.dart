// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/backend/context_client_providers.dart';
import '../../../core/backend/personal_home_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/directory_actions.dart';
import '../data/supabase_account_contact_repository.dart';
import '../data/supabase_directory_participant_repository.dart';
import '../data/supabase_public_discovery_repository.dart';
import '../data/supabase_publication_repository.dart';
import '../domain/discovery_paging.dart';
import '../domain/public_workspace.dart';

part 'directory_providers.g.dart';

/// #1847 — participant actions: register an installation, ask to join.
@riverpod
DirectoryActions directoryActions(Ref ref) =>
    DirectoryActions(ref.watch(directoryParticipantRepositoryProvider));

/// #1847 — the owner's publication editor (management).
@riverpod
PublicationActions publicationActions(Ref ref) =>
    PublicationActions(ref.watch(publicationRepositoryProvider));
@riverpod
AccountContactActions accountContactActions(Ref ref, {String source = ''}) =>
    AccountContactActions(
      ref.watch(accountContactRepositoryProvider(source: source)),
    );

/// #1847 — anonymous discovery. Holds publishable keys and no session:
/// the provider does not even watch the auth state.
///
/// #2561 L3 — the directory is the one the installation declares
/// ([directoryHomeProvider]); this device's own server is listed beside it.
///
/// #2555 — both come from the personal client alone: selecting a workspace
/// on another host never changes the source list.
@riverpod
PublicDiscoveryRepository publicDiscoveryRepository(Ref ref) =>
    SupabasePublicDiscoveryRepository(
      directoryHome: () => ref.read(directoryHomeProvider.future),
      local: ref.watch(personalEndpointProvider),
      transport: ref.watch(publicTransportProvider),
    );

@riverpod
PublicationRepository publicationRepository(Ref ref) {
  ref.watch(authStateProvider);
  return SupabasePublicationRepository(ref.watch(personalClientProvider));
}

@riverpod
DirectoryParticipantRepository directoryParticipantRepository(Ref ref) =>
    SupabaseDirectoryParticipantRepository(
      ref.watch(personalClientProvider),
      ref.watch(authStateProvider).value == null
          ? null
          : ref.watch(connectedInstallationsProvider),
      directoryHome: () => ref.read(directoryHomeProvider.future),
      transport: ref.watch(publicTransportProvider),
    );
/// #1847 — the card as its installation publishes it now; null once it is
/// withdrawn. Keyed by the card's identity on its own installation.
@riverpod
Future<PublicWorkspace?> publicWorkspaceDetail(
  Ref ref,
  String source,
  String key,
  String id,
) => ref
    .watch(publicDiscoveryRepositoryProvider)
    .detail(PublicWorkspace(id, source, key, const {}));
@riverpod
AccountContactRepository accountContactRepository(
  Ref ref, {
  String source = '',
}) {
  ref.watch(authStateProvider);
  return SupabaseAccountContactRepository(
    ref.watch(personalClientProvider),
    ref.watch(connectedInstallationsProvider),
    source,
  );
}

@riverpod
Future<bool> contactAvailability(Ref ref, {String source = ''}) =>
    ref.watch(accountContactRepositoryProvider(source: source)).availability();
@riverpod
Future<bool> adminVisibility(Ref ref, String workspace) =>
    ref.watch(accountContactRepositoryProvider()).adminVisibility(workspace);
@riverpod
Future<bool> employmentStatus(Ref ref, String member) =>
    ref.watch(accountContactRepositoryProvider()).employment(member);
@riverpod
Future<List<Map<String, dynamic>>> accountContacts(
  Ref ref,
  String query, {
  String source = '',
  String? before,
}) => ref
    .watch(accountContactRepositoryProvider(source: source))
    .search(query, before: before);
/// Who I can write to, by shared workspace.
@riverpod
Future<List<ReachablePerson>> reachablePeople(
  Ref ref, {
  String source = '',
}) => ref
    .watch(accountContactRepositoryProvider(source: source))
    .reachablePeople();
@riverpod
Future<List<Map<String, dynamic>>> accountConversations(
  Ref ref, {
  String source = '',
  DateTime? beforeAt,
  String? beforeId,
}) => ref
    .watch(accountContactRepositoryProvider(source: source))
    .conversations(beforeAt: beforeAt, beforeId: beforeId);
@riverpod
Future<List<Map<String, dynamic>>> accountMessages(
  Ref ref,
  String conversation, {
  String source = '',
  DateTime? beforeAt,
  String? beforeId,
}) => ref
    .watch(accountContactRepositoryProvider(source: source))
    .messages(conversation, beforeAt: beforeAt, beforeId: beforeId);
