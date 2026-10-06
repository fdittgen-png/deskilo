// SPDX-License-Identifier: AGPL-3.0-or-later

/// #1824 — every message belongs to a context.
///
/// A person reads their conversations in ONE inbox, whichever server and
/// whichever space they live in. Each row names its context, because the
/// context decides who else can read it: the two people of an account
/// conversation, the participants of a space conversation, the requester
/// and the hosts of an inquiry.
///
/// Pure Dart: the rows are what `my_inbox`, `inquiry_messages` and
/// `message_history` answer; merging several servers into one list is a
/// decision, so it lives here and is tested without a widget.
library;

import '../../../core/data/system_columns.dart';

/// The context a conversation belongs to, on the wire `my_inbox` speaks.
enum MessageContextKind {
  /// A conversation inside a space (direct or group).
  space('space'),

  /// Person to person, across servers.
  account('account'),

  /// A group of people (0384): members of one workspace, several or none.
  accountGroup('account_group'),

  /// An inquiry I wrote to a space.
  inquiryOut('inquiry_out'),

  /// An inquiry a person wrote to a space I host.
  inquiryIn('inquiry_in');

  const MessageContextKind(this.wire);
  final String wire;

  static MessageContextKind? fromWire(Object? value) =>
      values.where((k) => k.wire == value).firstOrNull;

  /// The message table behind the context — what `forward_message`,
  /// `message_history` and the lock name as `p_kind`.
  MessageKind get messageKind => switch (this) {
    space => MessageKind.memberNote,
    account => MessageKind.accountMessage,
    accountGroup => MessageKind.groupMessage,
    inquiryOut || inquiryIn => MessageKind.inquiryMessage,
  };

  /// What `forward_message` calls a conversation of this context.
  String get targetWire => switch (this) {
    space => 'conversation',
    account => 'account_conversation',
    accountGroup => 'account_group',
    inquiryOut || inquiryIn => 'inquiry',
  };

  bool get isInquiry => this == inquiryOut || this == inquiryIn;
}

/// The three message tables, as the server names them.
enum MessageKind {
  memberNote('member_note'),
  accountMessage('account_message'),
  inquiryMessage('inquiry_message'),
  groupMessage('group_message');

  const MessageKind(this.wire);
  final String wire;

  static MessageKind? fromWire(Object? value) =>
      values.where((k) => k.wire == value).firstOrNull;
}

DateTime _at(Object? value) {
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  // The epoch sorts an unreadable stamp to the bottom of a newest-first
  // list rather than over what somebody actually just wrote.
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? _atOrNull(Object? value) => value == null ? null : _at(value);

String _text(Object? value) => value is String ? value : '';

/// One row of the unified inbox: a conversation on ONE server.
class InboxEntry {
  const InboxEntry({
    required this.source,
    required this.kind,
    required this.contextId,
    required this.lastAt,
    this.workspaceId,
    this.workspaceName = '',
    this.title = '',
    this.lastBody = '',
    this.unread = 0,
    this.peerId,
  });

  /// [source] is the server's origin; '' is this server.
  static InboxEntry? fromRow(Map<String, dynamic> row, {String source = ''}) {
    final kind = MessageContextKind.fromWire(row['context_kind']);
    final id = row['context_id'];
    // A context this client does not know is left out rather than shown
    // as something it is not: opening it could only go wrong.
    if (kind == null || id is! String) return null;
    return InboxEntry(
      source: source,
      kind: kind,
      contextId: id,
      workspaceId: row['workspace_id'] as String?,
      workspaceName: _text(row['workspace_name']),
      title: _text(row['title']),
      lastBody: _text(row['last_body']),
      lastAt: _at(row['last_at']),
      unread: (row['unread'] as num?)?.toInt() ?? 0,
      peerId: row['peer_id'] as String?,
    );
  }

  final String source;
  final MessageContextKind kind;
  final String contextId;
  final String? workspaceId;
  final String workspaceName;
  final String title;
  final String lastBody;
  final DateTime lastAt;
  final int unread;

  /// The other person of an account conversation, when the server says.
  final String? peerId;

  bool get isRemote => source.isNotEmpty;

  /// The same conversation, whichever list it was found in.
  String get key => '$source|${kind.wire}|$contextId';
}

/// The merged inbox and the servers that did not answer.
class UnifiedInbox {
  const UnifiedInbox(this.entries, {this.unavailable = const []});
  final List<InboxEntry> entries;
  final List<String> unavailable;

  int get unread => entries.fold(0, (sum, e) => sum + e.unread);
}

/// Several servers' inboxes as ONE list, newest activity first.
///
/// A server that failed is NAMED in [unavailable] instead of making the
/// whole inbox fail: one unreachable self-hosted space must not hide the
/// conversations on every other server. Duplicates (the same context
/// answered twice) keep the first answer.
UnifiedInbox mergeInboxes(
  Map<String, List<Map<String, dynamic>>> bySource, {
  List<String> unavailable = const [],
}) {
  final seen = <String>{};
  final entries = <InboxEntry>[];
  for (final source in bySource.entries) {
    for (final row in source.value) {
      final entry = InboxEntry.fromRow(row, source: source.key);
      if (entry == null || !seen.add(entry.key)) continue;
      entries.add(entry);
    }
  }
  entries.sort((a, b) {
    final byTime = b.lastAt.compareTo(a.lastAt);
    return byTime != 0 ? byTime : a.key.compareTo(b.key);
  });
  return UnifiedInbox(entries, unavailable: unavailable);
}

/// Where a forwarded message came from — the origin line the copy
/// carries, so its readers see the context and the original author.
class ForwardOrigin {
  const ForwardOrigin({
    required this.contextLabel,
    required this.authorName,
    this.contextKind,
    this.sentAt,
    this.messageId,
    this.kind,
  });

  static ForwardOrigin? fromJson(Object? value) {
    if (value is! Map) return null;
    final map = Map<String, dynamic>.from(value);
    return ForwardOrigin(
      kind: MessageKind.fromWire(map['kind']),
      messageId: map['message_id'] as String?,
      contextKind: MessageContextKind.fromWire(map['context_kind']),
      contextLabel: _text(map['context_label']),
      authorName: _text(map['author_name']),
      sentAt: _atOrNull(map['sent_at']),
    );
  }

  final MessageKind? kind;
  final String? messageId;
  final MessageContextKind? contextKind;
  final String contextLabel;
  final String authorName;
  final DateTime? sentAt;
}

/// What a system line in a conversation says happened.
enum NoticeKind { forwarded, captured }

/// A system line: somebody forwarded a message of this conversation, or
/// took a screenshot of it. Never offered actions — it is not a message
/// anybody wrote.
class MessageNotice {
  const MessageNotice({
    required this.kind,
    this.actorName = '',
    this.targetLabel = '',
  });

  static MessageNotice? fromJson(Object? value) {
    if (value is! Map) return null;
    final kind = switch (value['kind']) {
      'forwarded' => NoticeKind.forwarded,
      'captured' => NoticeKind.captured,
      _ => null,
    };
    if (kind == null) return null;
    return MessageNotice(
      kind: kind,
      actorName: _text(value['actor_name']),
      targetLabel: _text(value['target_label']),
    );
  }

  final NoticeKind kind;
  final String actorName;
  final String targetLabel;
}

/// One message of an account conversation, an inquiry or a space
/// conversation read from another server — one shape for all three, so
/// the bubble, the receipts and the actions are drawn once.
class ContextMessage implements SystemStamped {
  const ContextMessage({
    required this.id,
    required this.kind,
    required this.body,
    required this.mine,
    required this.createdAt,
    this.authorName = '',
    this.readAt,
    this.noForward = false,
    this.forwardedFrom,
    this.notice,
    this.system = SystemColumns.none,
  });

  factory ContextMessage.fromRow(
    Map<String, dynamic> row, {
    required MessageKind kind,
    bool? mine,
  }) => ContextMessage(
    system: SystemColumns.fromRow(row),
    id: row['id'] as String,
    kind: kind,
    body: _text(row['body']),
    mine: mine ?? row['is_mine'] == true,
    authorName: _text(row['author_name']),
    createdAt: _at(row['created_at']),
    readAt: _atOrNull(row['read_at']),
    noForward: row['no_forward'] == true,
    forwardedFrom: ForwardOrigin.fromJson(row['forwarded_from']),
    notice: MessageNotice.fromJson(row['notice']),
  );

  @override
  final SystemColumns system;
  final String id;
  final MessageKind kind;
  final String body;
  final bool mine;
  final String authorName;
  final DateTime createdAt;

  /// When the other side read it; null = delivered only.
  final DateTime? readAt;

  /// The author locked it against forwarding.
  final bool noForward;
  final ForwardOrigin? forwardedFrom;
  final MessageNotice? notice;

  bool get isNotice => notice != null;

  /// Whether the forward action is offered at all: never on a system
  /// line, never on a locked message. The server re-checks both.
  bool get forwardable => !isNotice && !noForward;
}

/// One line of the "What happened" sheet.
class MessageEvent {
  const MessageEvent({
    required this.event,
    required this.at,
    this.actorName = '',
    this.detail = const {},
  });

  factory MessageEvent.fromRow(Map<String, dynamic> row) => MessageEvent(
    event: _text(row['event']),
    at: _at(row['at']),
    actorName: _text(row['actor_name']),
    detail: row['detail'] is Map
        ? Map<String, dynamic>.from(row['detail'] as Map)
        : const {},
  );

  /// `sent | read | forwarded | deleted | captured` — kept as text so a
  /// server that learns a new event still shows the line.
  final String event;
  final DateTime at;
  final String actorName;
  final Map<String, dynamic> detail;

  /// The context a forward went to, from the event's detail.
  String get targetLabel =>
      _text(detail['target_label'] ?? detail['context_label']);
}

/// Somebody who answers inquiries to a space — shown to the person
/// BEFORE they write, so they know who will read it.
class HostRosterEntry {
  const HostRosterEntry({required this.name, required this.role});

  factory HostRosterEntry.fromRow(Map<String, dynamic> row) =>
      HostRosterEntry(name: _text(row['name']), role: _text(row['role']));

  final String name;

  /// `owner` or `admin`.
  final String role;

  bool get isOwner => role == 'owner';
}

/// An inquiry, as the requester (`my_inquiries`) or a host
/// (`workspace_inquiries`) lists it.
class InquirySummary implements SystemStamped {
  const InquirySummary({
    required this.id,
    required this.workspaceId,
    required this.lastAt,
    this.workspaceName = '',
    this.requesterName = '',
    this.lastBody = '',
    this.unread = 0,
    this.closed = false,
    this.system = SystemColumns.none,
  });

  factory InquirySummary.fromRow(Map<String, dynamic> row) => InquirySummary(
    system: SystemColumns.fromRow(row),
    id: row['id'] as String,
    workspaceId: _text(row['workspace_id']),
    workspaceName: _text(row['workspace_name']),
    requesterName: _text(row['requester_name']),
    lastBody: _text(row['last_body']),
    lastAt: _at(row['last_at']),
    unread: (row['unread'] as num?)?.toInt() ?? 0,
    closed: row['closed_at'] != null,
  );

  @override
  final SystemColumns system;
  final String id;
  final String workspaceId;
  final String workspaceName;
  final String requesterName;
  final String lastBody;
  final DateTime lastAt;
  final int unread;
  final bool closed;
}

/// Shared with the server's checks; pinned by test.
abstract final class MessengerRules {
  /// `space_inquiry_messages.body` and `account_messages.body`.
  static const int maxBody = 4000;

  /// `inquiry_messages` pages.
  static const int pageSize = 50;
}

/// The conversations a message may be forwarded INTO: the ones the
/// forwarder takes part in on the SAME server (a forward is one
/// transaction there), never the conversation it came from.
List<InboxEntry> forwardTargets(
  Iterable<InboxEntry> inbox, {
  required String source,
  required MessageContextKind fromKind,
  required String fromContextId,
}) => [
  for (final entry in inbox)
    if (entry.source == source &&
        !(entry.contextId == fromContextId &&
            entry.kind.targetWire == fromKind.targetWire))
      entry,
];

/// A refusal the server states in words a person can act on (0316),
/// told apart from a fault so the thread can say WHY instead of "try
/// again". Unknown messages stay faults.
enum MessengerRefusal {
  locked,
  forwardingOff,
  tooLong,
  closed,
  unavailable,
  limit;

  static MessengerRefusal? of(String? serverMessage) =>
      switch (serverMessage?.trim()) {
        'the author locked this message' ||
        'a notice cannot be forwarded' => locked,
        'forwarding is off in this space' => forwardingOff,
        'message too long for this conversation' => tooLong,
        'inquiry closed' => closed,
        'inquiries unavailable' ||
        'workspace not published' ||
        'inquiry unavailable' => unavailable,
        'message limit reached' => limit,
        _ => null,
      };
}
