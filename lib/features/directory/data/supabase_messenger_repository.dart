// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connected_installations.dart';
import '../domain/group_details.dart';
import '../domain/message_marks.dart';
import '../domain/messenger.dart';
import '../domain/messenger_repository.dart';

/// #1824 — the messenger RPCs on one server, reached through that
/// server's own session ([ConnectedInstallations.use]); '' is this one.
class SupabaseMessengerRepository implements MessengerRepository {
  const SupabaseMessengerRepository(this.connections, this.source);
  final ConnectedInstallations connections;
  final String source;

  Future<T> _use<T>(Future<T> Function(SupabaseClient) action) =>
      connections.use(source, action);

  Future<T> _rpc<T>(String name, [Map<String, dynamic>? params]) =>
      _use((client) => client.rpc<T>(name, params: params));

  Future<List<Map<String, dynamic>>> _rows(
    String name, [
    Map<String, dynamic>? params,
  ]) async => [
    for (final row in (await _rpc<List<dynamic>?>(name, params)) ?? const [])
      Map<String, dynamic>.from(row as Map),
  ];

  String? _at(DateTime? at) => at?.toUtc().toIso8601String();

  @override
  Future<List<Map<String, dynamic>>> inbox() => _rows('my_inbox');

  @override
  Future<ConversationDetails> conversationDetails(String conversationId) async =>
      ConversationDetails.fromJson(Map<String, dynamic>.from(
        (await _rpc<dynamic>('conversation_details', {
              'p_conversation_id': conversationId,
            })) as Map? ??
            const <String, dynamic>{},
      ));

  @override
  Future<void> setConversationDetails(
    String conversationId, {
    required String description,
    required bool announceOnly,
  }) =>
      _rpc<dynamic>('set_conversation_details', {
        'p_conversation_id': conversationId,
        'p_description': description,
        'p_announce_only': announceOnly,
      });

  @override
  Future<void> setParticipantAdmin(
    String conversationId,
    String memberId, {
    required bool admin,
  }) =>
      _rpc<dynamic>('set_participant_admin', {
        'p_conversation_id': conversationId,
        'p_member_id': memberId,
        'p_admin': admin,
      });

  @override
  Future<MessageReach> messageReach(String messageId) async =>
      MessageReach.fromJson(Map<String, dynamic>.from(
        (await _rpc<dynamic>('message_info', {'p_message_id': messageId}))
            as Map,
      ));

  @override
  Future<MessageMarks> marks(String contextWire, String contextId) async =>
      MessageMarks.fromJson(Map<String, dynamic>.from(
        (await _rpc<dynamic>('message_marks_in', {
              'p_context_kind': contextWire,
              'p_context_id': contextId,
            })) as Map? ??
            const <String, dynamic>{},
      ));

  @override
  Future<void> react(MessageKind kind, String messageId, String? emoji) =>
      _rpc<dynamic>('react_to_message', {
        'p_kind': kind.wire,
        'p_message_id': messageId,
        'p_emoji': emoji,
      });

  @override
  Future<bool> toggleStar(MessageKind kind, String messageId) async =>
      (await _rpc<dynamic>('toggle_message_star', {
            'p_kind': kind.wire,
            'p_message_id': messageId,
          })) ==
          true;

  @override
  Future<void> edit(MessageKind kind, String messageId, String body) =>
      _rpc<dynamic>('edit_message', {
        'p_kind': kind.wire,
        'p_message_id': messageId,
        'p_body': body,
      });

  @override
  Future<List<StarredMessage>> starred() async => [
        for (final row in (await _rpc<List<dynamic>?>('my_starred_messages')) ?? const [])
          StarredMessage.fromJson(Map<String, dynamic>.from(row as Map)),
      ];

  @override
  Future<List<({String id, String name})>> sharedWorkspaces(String user) async => [
    for (final row in await _rows('shared_workspaces_with', {'p_user': user}))
      (id: row['id'] as String, name: row['name'] as String? ?? ''),
  ];

  @override
  Future<List<HostRosterEntry>> hostRoster(String workspace) async => [
    for (final row in await _rows('space_host_roster', {
      'p_workspace': workspace,
    }))
      HostRosterEntry.fromRow(row),
  ];

  @override
  Future<String> startInquiry(String workspace, String body) async =>
      (await _rpc<dynamic>('start_space_inquiry', {
        'p_workspace': workspace,
        'p_body': body,
      })).toString();

  @override
  Future<String> sendInquiryMessage(String inquiry, String body) async =>
      (await _rpc<dynamic>('send_inquiry_message', {
        'p_inquiry': inquiry,
        'p_body': body,
      })).toString();

  @override
  Future<List<InquirySummary>> myInquiries() async => [
    for (final row in await _rows('my_inquiries')) InquirySummary.fromRow(row),
  ];

  @override
  Future<List<InquirySummary>> workspaceInquiries(String workspace) async => [
    for (final row in await _rows('workspace_inquiries', {
      'p_workspace': workspace,
    }))
      InquirySummary.fromRow(row),
  ];

  @override
  Future<List<ContextMessage>> inquiryMessages(
    String inquiry, {
    DateTime? beforeAt,
    String? beforeId,
  }) async => [
    for (final row in await _rows('inquiry_messages', {
      'p_inquiry': inquiry,
      'p_before_at': _at(beforeAt),
      'p_before_id': beforeId,
    }))
      ContextMessage.fromRow(row, kind: MessageKind.inquiryMessage),
  ];

  @override
  Future<void> markInquiryRead(String inquiry) =>
      _rpc<void>('mark_inquiry_read', {'p_inquiry': inquiry});

  @override
  Future<void> closeInquiry(String inquiry) =>
      _rpc<void>('close_space_inquiry', {'p_inquiry': inquiry});

  @override
  Future<String> forward({
    required MessageKind kind,
    required String messageId,
    required MessageContextKind targetKind,
    required String targetId,
  }) => _use(
    (client) async => (await client.rpc<dynamic>(
      'forward_message',
      params: {
        'p_kind': kind.wire,
        'p_message_id': messageId,
        'p_target_kind': targetKind.targetWire,
        'p_target_id': targetId,
        // The account the forwarder believes they are: a session that
        // changed between the tap and the call is refused, not obeyed.
        'p_expected_account': client.auth.currentUser?.id,
      },
    )).toString(),
  );

  @override
  Future<void> setForwardLock(
    MessageKind kind,
    String messageId,
    bool locked,
  ) => _rpc<void>('set_message_forward_lock', {
    'p_kind': kind.wire,
    'p_message_id': messageId,
    'p_locked': locked,
  });

  @override
  Future<List<MessageEvent>> history(
    MessageKind kind,
    String messageId,
  ) async => [
    for (final row in await _rows('message_history', {
      'p_kind': kind.wire,
      'p_message_id': messageId,
    }))
      MessageEvent.fromRow(row),
  ];

  @override
  Future<void> recordScreenCapture(MessageContextKind kind, String contextId) =>
      _rpc<void>('record_screen_capture', {
        'p_kind': kind.targetWire,
        'p_context_id': contextId,
      });

  @override
  Future<List<ContextMessage>> accountMessages(
    String conversation, {
    DateTime? beforeAt,
    String? beforeId,
  }) async => [
    for (final row in await _rows('my_account_messages', {
      'p_conversation': conversation,
      'p_before_at': _at(beforeAt),
      'p_before_id': beforeId,
    }))
      ContextMessage.fromRow(row, kind: MessageKind.accountMessage),
  ];

  @override
  Future<String> sendAccountMessage(String recipient, String body) => _use(
    (client) async => (await client.rpc<dynamic>(
      'send_account_message',
      params: {
        'p_recipient': recipient,
        'p_body': body,
        'p_expected_account': client.auth.currentUser?.id,
      },
    )).toString(),
  );

  @override
  Future<void> markAccountConversationRead(String conversation) => _rpc<void>(
    'mark_account_conversation_read',
    {'p_conversation': conversation},
  );

  @override
  Future<void> deleteAccountMessage(String message) =>
      _rpc<void>('delete_account_message', {'p_message': message});

  @override
  Future<List<ContextMessage>> spaceMessages(String conversation) =>
      _use((client) async {
        final user = client.auth.currentUser?.id;
        // My member rows on THAT server say which bubbles are mine; the
        // member id of this server means nothing there.
        final mine = user == null
            ? const <String>{}
            : {
                for (final row
                    in await client
                        .from('members')
                        .select('id')
                        .eq('user_id', user))
                  row['id'] as String,
              };
        final rows = await client
            .from('member_notes')
            .select()
            .eq('conversation_id', conversation)
            .order('created_at', ascending: false)
            .limit(MessengerRules.pageSize);
        return [
          // Newest first, like every other thread page this repository returns.
          for (final row in rows)
            ContextMessage.fromRow(
              row,
              kind: MessageKind.memberNote,
              mine: mine.contains(row['from_member_id']),
            ),
        ];
      });

  @override
  Future<void> sendSpaceMessage(String conversation, String body) => _rpc<void>(
    'send_conversation_message',
    {'p_conversation_id': conversation, 'p_body': body},
  );

  @override
  Future<void> markSpaceConversationRead(String conversation) =>
      _rpc<void>('mark_conversation_read', {'p_conversation_id': conversation});
}
