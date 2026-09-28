// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connected_installations.dart';
import '../domain/public_workspace.dart';

class SupabaseAccountContactRepository implements AccountContactRepository {
  const SupabaseAccountContactRepository(
    this.active,
    this.connections,
    this.source,
  );
  final SupabaseClient active;
  final ConnectedInstallations connections;
  final String source;
  Future<T> _rpc<T>(String name, [Map<String, dynamic>? params]) =>
      connections.use(source, (client) => client.rpc<T>(name, params: params));
  @override
  Future<bool> availability() => _rpc('my_contact_availability');
  @override
  Future<void> setAvailability(bool value) =>
      _rpc('set_contact_availability', {'p_available': value});
  @override
  Future<bool> adminVisibility(String workspace, {bool? visible}) => _rpc(
    'my_admin_visibility',
    {'p_workspace': workspace, 'p_visible': visible},
  );
  @override
  Future<bool> employment(String member, {bool? employed}) => _rpc(
    'member_employment_status',
    {'p_member': member, 'p_employed': employed},
  );
  Future<List<Map<String, dynamic>>> _rows(
    String name,
    Map<String, dynamic> params,
  ) async => (await _rpc<List<dynamic>>(
    name,
    params,
  )).map((v) => Map<String, dynamic>.from(v as Map)).toList();
  @override
  Future<List<Map<String, dynamic>>> search(String query, {String? before}) =>
      _rows('search_available_accounts', {
        'p_query': query,
        'p_before': before,
      });
  @override
  Future<List<Map<String, dynamic>>> conversations({
    DateTime? beforeAt,
    String? beforeId,
  }) => _rows('my_account_conversations', {
    'p_before_at': beforeAt?.toUtc().toIso8601String(),
    'p_before_id': beforeId,
  });
  @override
  Future<List<Map<String, dynamic>>> messages(
    String conversation, {
    DateTime? beforeAt,
    String? beforeId,
  }) => _rows('my_account_messages', {
    'p_conversation': conversation,
    'p_before_at': beforeAt?.toUtc().toIso8601String(),
    'p_before_id': beforeId,
  });
  @override
  Future<String?> conversationWith(String recipient) =>
      _rpc('my_account_conversation_with', {'p_recipient': recipient});
  @override
  Future<String> send(String recipient, String body) => connections.use(
    source,
    (client) => client.rpc<String>(
      'send_account_message',
      params: {
        'p_recipient': recipient,
        'p_body': body,
        'p_expected_account': client.auth.currentUser?.id,
      },
    ),
  );
}
