// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/public_workspace.dart';
import '../data/supabase_directory_repository.dart';
import '../data/supabase_account_contact_repository.dart';
import '../application/directory_actions.dart';
part 'directory_providers.g.dart';

@riverpod
DirectoryActions directoryActions(Ref ref) =>
    DirectoryActions(ref.watch(directoryRepositoryProvider));
@riverpod
AccountContactActions accountContactActions(Ref ref, {String source = ''}) =>
    AccountContactActions(
      ref.watch(accountContactRepositoryProvider(source: source)),
    );

@riverpod
DirectoryRepository directoryRepository(Ref ref) => SupabaseDirectoryRepository(
  Supabase.instance.client,
  ref.watch(authStateProvider).value == null
      ? null
      : ref.watch(connectedInstallationsProvider),
);
@riverpod
Future<DirectoryPage> publicDirectory(
  Ref ref,
  String query, {
  int sourcePage = 0,
  int workspacePage = 0,
}) => ref
    .watch(directoryRepositoryProvider)
    .search(query, sourcePage: sourcePage, workspacePage: workspacePage);
@riverpod
AccountContactRepository accountContactRepository(
  Ref ref, {
  String source = '',
}) {
  ref.watch(authStateProvider);
  return SupabaseAccountContactRepository(
    Supabase.instance.client,
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
