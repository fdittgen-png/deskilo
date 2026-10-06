// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../features/directory/domain/account_group.dart';
import '../../../features/directory/domain/group_details.dart';
import '../../../features/directory/domain/message_marks.dart';
import '../../../features/directory/domain/messenger.dart';
import '../../../features/directory/domain/messenger_repository.dart';

/// #1824 — the messenger on one in-memory server.
///
/// It keeps the rules the server keeps, because the widget tests read
/// their outcome from here: a forward copies the message into the target
/// with its origin, leaves a notice in the source and a `forwarded`
/// event on it; a locked message refuses; a capture leaves a notice.
class FakeMessengerRepository implements MessengerRepository {
  FakeMessengerRepository({DateTime? now, this.me = 'Me'})
    : now = now ?? DateTime.utc(2026, 7, 15, 9);
  final DateTime now;

  /// The name the fake signs the actor's notices with.
  final String me;

  /// `my_inbox` rows.
  final inboxRows = <Map<String, dynamic>>[];

  // ── groups of people (0384) ─────────────────────────────────────────
  final groups = <String, AccountGroupInfo>{};
  final groupRoster = <String, List<GroupMember>>{};
  final groupLog = <String>[];
  final groupSharedIn = <String, List<({String id, String name})>>{};
  GroupReach? groupReachResult;

  @override
  Future<String> createGroup(String title, List<String> users) async {
    _check();
    final id = 'g-${groups.length + 1}';
    groups[id] = AccountGroupInfo(
        id: id, title: title, memberCount: users.length + 1, iAmAdmin: true);
    groupRoster[id] = [
      const GroupMember(userId: 'me', name: 'Me', isAdmin: true),
      for (final u in users) GroupMember(userId: u, name: u),
    ];
    groupLog.add('create:$title');
    return id;
  }

  @override
  Future<AccountGroupInfo> groupInfo(String group) async {
    _check();
    return groups[group] ?? AccountGroupInfo(id: group, title: '');
  }

  @override
  Future<List<GroupMember>> groupMembers(String group) async {
    _check();
    return groupRoster[group] ?? const [];
  }

  @override
  Future<void> addGroupMember(String group, String user) async {
    _check();
    groupLog.add('add:$user');
    groupRoster[group] = [...?groupRoster[group], GroupMember(userId: user, name: user)];
  }

  @override
  Future<void> removeGroupMember(String group, String user) async {
    _check();
    groupLog.add('remove:$user');
    groupRoster[group] = [for (final m in groupRoster[group] ?? <GroupMember>[]) if (m.userId != user) m];
  }

  @override
  Future<void> leaveGroup(String group) async {
    _check();
    groupLog.add('leave');
  }

  @override
  Future<void> setGroupMeta(String group,
      {String? title, String? description, bool? announceOnly}) async {
    _check();
    final g = groups[group] ?? AccountGroupInfo(id: group, title: '');
    groups[group] = AccountGroupInfo(
      id: group,
      title: title ?? g.title,
      description: description ?? g.description,
      announceOnly: announceOnly ?? g.announceOnly,
      memberCount: g.memberCount,
      iAmAdmin: g.iAmAdmin,
    );
    groupLog.add('meta');
  }

  @override
  Future<void> setGroupAdmin(String group, String user, {required bool admin}) async {
    _check();
    groupLog.add('admin:$user:$admin');
  }

  @override
  Future<List<ContextMessage>> groupMessages(String group,
      {DateTime? beforeAt, String? beforeId}) async {
    _check();
    return threads[threadKey(MessageContextKind.accountGroup, group)] ?? const [];
  }

  @override
  Future<String> sendGroupMessage(String group, String body) async {
    _check();
    final key = threadKey(MessageContextKind.accountGroup, group);
    final id = 'gm-${++_ids}';
    threads[key] = [
      _message(body, kind: MessageKind.groupMessage),
      ...?threads[key],
    ];
    return id;
  }

  @override
  Future<void> markGroupRead(String group) async {
    _check();
    reads.add(group);
  }

  @override
  Future<void> deleteGroupMessage(String message) async {
    _check();
    deleted.add(message);
  }

  @override
  Future<GroupReach> groupReach(String message) async {
    _check();
    return groupReachResult ?? const GroupReach();
  }

  @override
  Future<List<({String id, String name})>> groupSharedWorkspaces(String group) async {
    _check();
    return groupSharedIn[group] ?? const [];
  }

  final details = <String, ConversationDetails>{};
  final adminChanges = <({String conversation, String member, bool admin})>[];
  MessageReach? reach;

  @override
  Future<ConversationDetails> conversationDetails(String id) async {
    _check();
    return details[id] ?? ConversationDetails.none;
  }

  @override
  Future<void> setConversationDetails(
    String id, {
    required String description,
    required bool announceOnly,
  }) async {
    _check();
    details[id] = ConversationDetails(
        description: description, announceOnly: announceOnly);
  }

  @override
  Future<void> setParticipantAdmin(String id, String memberId,
      {required bool admin}) async {
    _check();
    adminChanges.add((conversation: id, member: memberId, admin: admin));
  }

  @override
  Future<MessageReach> messageReach(String messageId) async {
    _check();
    return reach ?? MessageReach(sentAt: now);
  }

  /// Marks by `<context wire>|<context id>`; the fake also records writes.
  final marksByContext = <String, MessageMarks>{};
  final reactions = <({MessageKind kind, String id, String? emoji})>[];
  final edits = <({MessageKind kind, String id, String body})>[];
  final starredIds = <String>{};

  @override
  Future<MessageMarks> marks(String contextWire, String contextId) async {
    _check();
    return marksByContext['$contextWire|$contextId'] ?? MessageMarks.none;
  }

  @override
  Future<void> react(MessageKind kind, String messageId, String? emoji) async {
    _check();
    reactions.add((kind: kind, id: messageId, emoji: emoji));
  }

  @override
  Future<bool> toggleStar(MessageKind kind, String messageId) async {
    _check();
    return starredIds.add(messageId) || !starredIds.remove(messageId);
  }

  @override
  Future<void> edit(MessageKind kind, String messageId, String body) async {
    _check();
    edits.add((kind: kind, id: messageId, body: body));
  }

  @override
  Future<List<StarredMessage>> starred() async {
    _check();
    return const [];
  }

  /// The workspaces shared with a person (0381), by user id.
  final shared = <String, List<({String id, String name})>>{};

  @override
  Future<List<({String id, String name})>> sharedWorkspaces(String user) async {
    _check();
    return shared[user] ?? const [];
  }

  /// Messages per `<context kind>|<context id>`, newest first.
  final threads = <String, List<ContextMessage>>{};
  final roster = <String, List<HostRosterEntry>>{};
  final inquiries = <InquirySummary>[];
  final events = <String, List<MessageEvent>>{};
  final reads = <String>[];
  final captures = <String>[];
  final forwards = <({String messageId, String target})>[];
  final deleted = <String>[];
  final closed = <String>[];
  bool fail = false;

  /// The server's refusal for the next forward, word for word (0316).
  String? refuseForward;
  int _ids = 0;

  static String threadKey(MessageContextKind kind, String id) =>
      '${kind.targetWire}|$id';

  void _check() {
    if (fail) throw StateError('messenger unavailable');
  }

  ({String key, int index})? _find(String messageId) {
    for (final entry in threads.entries) {
      final index = entry.value.indexWhere((m) => m.id == messageId);
      if (index >= 0) return (key: entry.key, index: index);
    }
    return null;
  }

  ContextMessage _message(
    String body, {
    required MessageKind kind,
    ForwardOrigin? origin,
    MessageNotice? notice,
  }) => ContextMessage(
    id: 'msg-${++_ids}',
    kind: kind,
    body: body,
    mine: true,
    authorName: me,
    createdAt: now.add(Duration(minutes: _ids)),
    forwardedFrom: origin,
    notice: notice,
  );

  void _post(String key, ContextMessage message) =>
      (threads[key] ??= []).insert(0, message);

  @override
  Future<List<Map<String, dynamic>>> inbox() async {
    _check();
    return inboxRows;
  }

  @override
  Future<List<HostRosterEntry>> hostRoster(String workspace) async {
    _check();
    return roster[workspace] ?? const [];
  }

  @override
  Future<String> startInquiry(String workspace, String body) async {
    _check();
    final id = 'inquiry-${++_ids}';
    _post(
      threadKey(MessageContextKind.inquiryOut, id),
      _message(body, kind: MessageKind.inquiryMessage),
    );
    inboxRows.insert(0, {
      'context_kind': MessageContextKind.inquiryOut.wire,
      'context_id': id,
      'workspace_id': workspace,
      'title': workspace,
      'last_body': body,
      'last_at': now.toIso8601String(),
      'unread': 0,
    });
    return id;
  }

  @override
  Future<String> sendInquiryMessage(String inquiry, String body) async {
    _check();
    final message = _message(body, kind: MessageKind.inquiryMessage);
    _post(threadKey(MessageContextKind.inquiryOut, inquiry), message);
    return message.id;
  }

  @override
  Future<List<InquirySummary>> myInquiries() async => inquiries;

  @override
  Future<List<InquirySummary>> workspaceInquiries(String workspace) async {
    _check();
    return [
      for (final i in inquiries)
        if (i.workspaceId == workspace) i,
    ];
  }

  @override
  Future<List<ContextMessage>> inquiryMessages(
    String inquiry, {
    DateTime? beforeAt,
    String? beforeId,
  }) async {
    _check();
    return threads[threadKey(MessageContextKind.inquiryOut, inquiry)] ??
        const [];
  }

  @override
  Future<void> markInquiryRead(String inquiry) async => reads.add(inquiry);

  @override
  Future<void> closeInquiry(String inquiry) async => closed.add(inquiry);

  @override
  Future<String> forward({
    required MessageKind kind,
    required String messageId,
    required MessageContextKind targetKind,
    required String targetId,
  }) async {
    _check();
    final refusal = refuseForward;
    if (refusal != null) throw PostgrestException(message: refusal);
    final target = inboxRows
        .where((r) => r['context_id'] == targetId)
        .map((r) => r['title'] as String? ?? '')
        .firstOrNull;
    forwards.add((messageId: messageId, target: targetId));
    (events[messageId] ??= []).add(
      MessageEvent(
        event: 'forwarded',
        at: now,
        actorName: me,
        detail: {'target_label': target ?? targetId},
      ),
    );
    final at = _find(messageId);
    // A space message lives in the workspace fake; the forward is still
    // recorded, the copy and the notice are that server's business.
    if (at == null) return 'forward-${forwards.length}';
    final source = threads[at.key]![at.index];
    if (source.noForward) {
      forwards.removeLast();
      events[messageId]!.removeLast();
      throw StateError('message is locked');
    }
    final copy = _message(
      source.body,
      kind: targetKind.messageKind,
      origin: ForwardOrigin(
        kind: kind,
        messageId: messageId,
        contextLabel: at.key,
        authorName: source.authorName,
        sentAt: source.createdAt,
      ),
    );
    _post(threadKey(targetKind, targetId), copy);
    _post(
      at.key,
      _message(
        '',
        kind: kind,
        notice: MessageNotice(
          kind: NoticeKind.forwarded,
          actorName: me,
          targetLabel: target ?? targetId,
        ),
      ),
    );
    return copy.id;
  }

  @override
  Future<void> setForwardLock(
    MessageKind kind,
    String messageId,
    bool locked,
  ) async {
    _check();
    final at = _find(messageId);
    if (at == null) return;
    final m = threads[at.key]![at.index];
    threads[at.key]![at.index] = ContextMessage(
      id: m.id,
      kind: m.kind,
      body: m.body,
      mine: m.mine,
      authorName: m.authorName,
      createdAt: m.createdAt,
      readAt: m.readAt,
      noForward: locked,
      forwardedFrom: m.forwardedFrom,
      notice: m.notice,
    );
  }

  @override
  Future<List<MessageEvent>> history(MessageKind kind, String messageId) async {
    _check();
    return events[messageId] ?? const [];
  }

  @override
  Future<void> recordScreenCapture(
    MessageContextKind kind,
    String contextId,
  ) async {
    captures.add(contextId);
    final key = threads.keys
        .where((k) => k.endsWith('|$contextId'))
        .firstOrNull;
    if (key == null) return;
    _post(
      key,
      _message(
        '',
        kind: kind.messageKind,
        notice: MessageNotice(kind: NoticeKind.captured, actorName: me),
      ),
    );
  }

  @override
  Future<List<ContextMessage>> accountMessages(
    String conversation, {
    DateTime? beforeAt,
    String? beforeId,
  }) async {
    _check();
    return threads[threadKey(MessageContextKind.account, conversation)] ??
        const [];
  }

  @override
  Future<String> sendAccountMessage(String recipient, String body) async {
    _check();
    final conversation =
        inboxRows
            .where((r) => r['peer_id'] == recipient)
            .map((r) => r['context_id'] as String)
            .firstOrNull ??
        recipient;
    _post(
      threadKey(MessageContextKind.account, conversation),
      _message(body, kind: MessageKind.accountMessage),
    );
    return conversation;
  }

  @override
  Future<void> markAccountConversationRead(String conversation) async =>
      reads.add(conversation);

  @override
  Future<void> deleteAccountMessage(String message) async {
    _check();
    deleted.add(message);
    final at = _find(message);
    if (at != null) threads[at.key]!.removeAt(at.index);
  }

  @override
  Future<List<ContextMessage>> spaceMessages(String conversation) async {
    _check();
    return threads[threadKey(MessageContextKind.space, conversation)] ??
        const [];
  }

  @override
  Future<void> sendSpaceMessage(String conversation, String body) async {
    _check();
    _post(
      threadKey(MessageContextKind.space, conversation),
      _message(body, kind: MessageKind.memberNote),
    );
  }

  @override
  Future<void> markSpaceConversationRead(String conversation) async =>
      reads.add(conversation);
}
