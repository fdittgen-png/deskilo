// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 C2 — the Overview's three sections as pure functions of what was
// loaded: the next commitment out of My reservations' composition (#2553),
// what needs attention out of my own documents, conversations and
// requests, each record once, and the first spaces of My spaces. Nothing
// here reads a server; a source that was not read is the caller's state to
// say, never an empty list here.
import '../../directory/domain/messenger.dart';
import '../../reservations/domain/my_reservations_composition.dart';
import '../../reservations/domain/reservation.dart';
import '../domain/personal_workspace_refs.dart';

/// Where the search for the next commitment stands.
class NextCommitment {
  const NextCommitment({
    required this.entry,
    required this.reading,
    required this.complete,
    required this.failed,
  });

  /// The earliest own booking that is still to come and stands — neither
  /// cancelled, released nor over; null while none was found.
  final MyReservationEntry? entry;

  /// A host's first page is still being read: an earlier booking may come.
  final bool reading;

  /// Every host answered and none has a further page: an empty answer is
  /// "none in this period", nothing more.
  final bool complete;

  /// The hosts whose bookings could not be read.
  final List<MyReservationsSlot> failed;
}

/// A booking that still holds its place: what a person has to turn up for.
bool _stands(ReservationStatus status) =>
    status == ReservationStatus.reserved ||
    status == ReservationStatus.checkedIn;

NextCommitment nextCommitmentOf(
  MyReservationsComposition composition,
  DateTime now,
) {
  MyReservationEntry? entry;
  for (final e in composition.visible) {
    if (_stands(e.item.status) && e.item.endsAt.isAfter(now)) {
      entry = e;
      break;
    }
  }
  return NextCommitment(
    entry: entry,
    reading: composition.reading,
    complete: composition.slots.every(
      (s) => s.state == MyReservationsSlotState.read && !s.hasMore,
    ),
    failed: composition.failed,
  );
}

/// One of my unpaid documents as the Overview needs it: which, where, what
/// remains in its own currency and whether it is past its due day. Read
/// from my own finance overview, production documents only; a reminder is
/// the same debt as its invoice and is not a document of its own here.
class OwedDocument {
  const OwedDocument({
    required this.id,
    required this.workspaceId,
    required this.workspaceName,
    required this.number,
    required this.remainingCents,
    required this.currency,
    this.overdue = false,
  });

  final String id, workspaceId, workspaceName, number, currency;
  final int remainingCents;
  final bool overdue;
}

/// What one item of Needs attention is about.
enum AttentionKind { document, application, conversation }

/// One thing that waits for me, keyed by its qualified source, kind and
/// record: the same record read twice is one item.
class AttentionItem {
  const AttentionItem.document(OwedDocument this.document)
    : kind = AttentionKind.document,
      conversation = null,
      application = null;

  const AttentionItem.application(PersonalWorkspaceRef this.application)
    : kind = AttentionKind.application,
      document = null,
      conversation = null;

  const AttentionItem.conversation(InboxEntry this.conversation)
    : kind = AttentionKind.conversation,
      document = null,
      application = null;

  final AttentionKind kind;
  final OwedDocument? document;
  final PersonalWorkspaceRef? application;
  final InboxEntry? conversation;

  /// A document past its due day.
  bool get overdue => document?.overdue ?? false;

  String get key => switch (kind) {
    AttentionKind.document =>
      'document|${document!.workspaceId}|${document!.id}',
    AttentionKind.application => 'application|${application!.networkId}',
    AttentionKind.conversation =>
      'conversation|${conversation!.source}'
          '|${conversation!.kind.name}|${conversation!.contextId}',
  };
}

/// My unpaid documents, my requests still undecided where
/// the host itself says so, and my conversations with unread messages that
/// I did not mute or archive — overdue documents first, each record once.
/// A null source was not read and adds nothing.
List<AttentionItem> attentionItems({
  List<OwedDocument>? documents,
  PersonalWorkspaceRefs? refs,
  UnifiedInbox? inbox,
}) {
  final owed = documents ?? const <OwedDocument>[];
  final items = <AttentionItem>[
    for (final d in owed)
      if (d.overdue) AttentionItem.document(d),
    for (final d in owed)
      if (!d.overdue) AttentionItem.document(d),
    for (final r in refs?.refs ?? const <PersonalWorkspaceRef>[])
      if (r.status == RefStatus.pending && r.freshness == RefFreshness.local)
        AttentionItem.application(r),
    for (final e in inbox?.entries ?? const <InboxEntry>[])
      if (e.unread > 0 &&
          !(e.flags?.muted ?? false) &&
          !(e.flags?.archived ?? false))
        AttentionItem.conversation(e),
  ];
  final seen = <String>{};
  return List.unmodifiable([
    for (final item in items)
      if (seen.add(item.key)) item,
  ]);
}
