// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2313 — the people side of the demo: the space's own identity (a
// French name, address, time zone and its colour, pattern and symbol),
// its own roles and who holds them, the questions it asks its members
// and their answers, badges (one revoked), shared documents, and the
// conversations of the week. Every value is invented, every link points
// at example.test (RFC 2606), every date follows the seeded instant.
import '../../../features/workspace/domain/conversation.dart';
import '../../../features/workspace/domain/member_badge.dart';
import '../../../features/workspace/domain/member_note.dart';
import '../../../features/workspace/domain/workspace_document.dart';
import '../../../features/workspace/domain/workspace_field.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import '../../../features/workspace/domain/workspace_role.dart';
import '../data/workspace_fields_repository.dart';
import '../data/workspace_repository.dart';
import '../data/workspace_roles_repository.dart';

/// The demo space's name, the one the guides show.
const demoSpaceName = 'Atelier du Marché';

/// Its postal address, on the space and on every bill it issues.
const demoSpaceAddress = '4 place du Marché\n34120 Pézenas';

/// The space itself: where it is and how it looks.
void seedDemoIdentity(FakeWorkspaceRepository workspaces) {
  final i = workspaces.workspaces.indexWhere((w) => w.id == 'ws-1');
  if (i < 0) return;
  workspaces.workspaces[i] = workspaces.workspaces[i].copyWith(
    name: demoSpaceName,
    countryCode: 'FR',
    timezone: 'Europe/Paris',
    address: demoSpaceAddress,
    // VAT-registered, so the rates, the VAT on bills and the
    // declarations (demo_commerce_seed.dart) all apply.
    vatRegime: 'vat_registered',
    branding: const {
      'seed_color': '#0F766E',
      'pattern': 'stripes',
      'symbol_text': 'AM',
      'symbol_color': '#0F766E',
    },
  );
}

/// Two roles of the space's own, and who holds them.
void seedDemoRoles(FakeWorkspaceRoles roles) {
  roles.roles.addAll(const [
    WorkspaceRole(
      id: 'demo-role-host',
      key: 'host',
      names: {
        'en': 'Host',
        'fr': 'Hôte',
        'de': 'Gastgeber',
        'es': 'Anfitrión',
        'it': 'Ospite',
      },
      permissions: {
        WorkspacePermission.manageReservations,
        WorkspacePermission.operateKiosk,
        WorkspacePermission.manageMembers,
        WorkspacePermission.viewCalendar,
      },
      sortOrder: 1,
    ),
    WorkspaceRole(
      id: 'demo-role-accountant',
      key: 'accountant',
      names: {
        'en': 'Accountant',
        'fr': 'Comptable',
        'de': 'Buchhaltung',
        'es': 'Contable',
        'it': 'Contabile',
      },
      permissions: {
        WorkspacePermission.viewFinances,
        WorkspacePermission.issueInvoices,
        WorkspacePermission.exportData,
        WorkspacePermission.viewAnalytics,
      },
      sortOrder: 2,
    ),
  ]);
  roles.assignments
    ..['demo-role-host'] = ['member-3']
    ..['demo-role-accountant'] = ['member-5'];
}

/// The questions the space asks, and what the cast answered.
void seedDemoFields(FakeWorkspaceFields fields) {
  fields.fields.addAll(const [
    WorkspaceField(
      id: 'demo-field-company',
      key: 'company',
      type: WorkspaceFieldType.text,
      labels: {
        'en': 'Company',
        'fr': 'Entreprise',
        'de': 'Firma',
        'es': 'Empresa',
        'it': 'Azienda',
      },
      personalData: false,
      visibility: WorkspaceFieldVisibility.managers,
      sortOrder: 0,
    ),
    WorkspaceField(
      id: 'demo-field-newsletter',
      key: 'newsletter',
      type: WorkspaceFieldType.boolean,
      labels: {
        'en': 'Monthly newsletter',
        'fr': 'Lettre mensuelle',
        'de': 'Monatlicher Newsletter',
        'es': 'Boletín mensual',
        'it': 'Newsletter mensile',
      },
      personalData: false,
      sortOrder: 1,
    ),
  ]);
  fields.answers
    ..['member-1'] = {'company': 'Lindqvist Design', 'newsletter': true}
    ..['member-2'] = {'company': 'Kessler Translations', 'newsletter': false}
    ..['member-3'] = {'company': 'Studio Rossi', 'newsletter': true};
}

/// Badges: QR and NFC, one signing its holder in, one revoked.
void seedDemoBadges(FakeWorkspaceRepository workspaces, DateTime now) {
  workspaces.badges.addAll([
    MemberBadge(
      id: 'demo-badge-ada',
      workspaceId: 'ws-1',
      memberId: 'member-1',
      label: 'Ada · QR',
      createdAt: now.subtract(const Duration(days: 400)),
      authEnabled: true,
    ),
    MemberBadge(
      id: 'demo-badge-bruno',
      workspaceId: 'ws-1',
      memberId: 'member-2',
      label: 'Bruno · card',
      kind: BadgeKind.nfc,
      createdAt: now.subtract(const Duration(days: 300)),
    ),
    MemberBadge(
      id: 'demo-badge-chiara-lost',
      workspaceId: 'ws-1',
      memberId: 'member-3',
      label: 'Chiara · old card',
      kind: BadgeKind.nfc,
      createdAt: now.subtract(const Duration(days: 200)),
      revokedAt: now.subtract(const Duration(days: 30)),
    ),
    MemberBadge(
      id: 'demo-badge-chiara',
      workspaceId: 'ws-1',
      memberId: 'member-3',
      label: 'Chiara · QR',
      createdAt: now.subtract(const Duration(days: 29)),
    ),
  ]);
}

/// The space's shared paperwork, each a link the visitor can follow.
void seedDemoDocuments(FakeWorkspaceRepository workspaces) {
  workspaces.documents.addAll(const [
    WorkspaceDocument(
      id: 'demo-doc-rules',
      workspaceId: 'ws-1',
      title: 'House rules',
      category: 'statutes',
      url: 'https://example.test/atelier/house-rules.pdf',
    ),
    WorkspaceDocument(
      id: 'demo-doc-wifi',
      workspaceId: 'ws-1',
      title: 'Wi-Fi and printer guide',
      category: 'guides',
      url: 'https://example.test/atelier/wifi.pdf',
    ),
    WorkspaceDocument(
      id: 'demo-doc-insurance',
      workspaceId: 'ws-1',
      title: 'Insurance certificate',
      category: 'other',
      url: 'https://example.test/atelier/insurance.pdf',
      minRole: 'admin',
    ),
  ]);
}

/// The week's conversations: a direct thread with Bruno, one message
/// unread, and the studio's group.
void seedDemoConversations(FakeWorkspaceRepository workspaces, DateTime now) {
  MemberNote note(
    String id,
    String conv,
    String from,
    String? to,
    String body,
    int hoursAgo, {
    bool read = true,
  }) => MemberNote(
    id: id,
    workspaceId: 'ws-1',
    fromMemberId: from,
    toMemberId: to,
    body: body,
    createdAt: now.subtract(Duration(hours: hoursAgo)),
    readAt: read ? now.subtract(Duration(hours: hoursAgo - 1)) : null,
    conversationId: conv,
  );

  final direct = [
    note(
      'demo-msg-1',
      'demo-conv-bruno',
      'member-2',
      'member-1',
      'Could I swap my Tuesday morning for Thursday next week?',
      26,
    ),
    note(
      'demo-msg-2',
      'demo-conv-bruno',
      'member-1',
      'member-2',
      'Yes — Thursday morning is free, I moved it for you.',
      25,
    ),
    note(
      'demo-msg-3',
      'demo-conv-bruno',
      'member-2',
      'member-1',
      'Thank you! I will bring the coffee.',
      2,
      read: false,
    ),
  ];
  final group = [
    note(
      'demo-msg-4',
      'demo-conv-studio',
      'member-3',
      null,
      'The meeting room is booked on Friday afternoon for the client visit.',
      30,
    ),
    note(
      'demo-msg-5',
      'demo-conv-studio',
      'member-1',
      null,
      'Perfect, I will set up the screen.',
      29,
    ),
  ];
  workspaces.conversations.addAll([
    Conversation(
      id: 'demo-conv-bruno',
      kind: ConversationKind.direct,
      lastAt: direct.last.createdAt,
      otherMemberId: 'member-2',
      lastBody: direct.last.body,
      lastFromMemberId: 'member-2',
      unread: 1,
      participantCount: 2,
    ),
    Conversation(
      id: 'demo-conv-studio',
      kind: ConversationKind.group,
      title: 'Studio team',
      lastAt: group.last.createdAt,
      lastBody: group.last.body,
      lastFromMemberId: 'member-1',
      participantCount: 3,
    ),
  ]);
  workspaces.conversationMessages
    ..['demo-conv-bruno'] = direct
    ..['demo-conv-studio'] = group;
  workspaces.participants['demo-conv-studio'] = const [
    ConversationParticipant(memberId: 'member-1', isAdmin: true),
    ConversationParticipant(memberId: 'member-2', isAdmin: false),
    ConversationParticipant(memberId: 'member-3', isAdmin: true),
  ];
  workspaces.memberNotes.addAll([...direct, ...group]);
}
