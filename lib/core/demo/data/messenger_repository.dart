// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

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
