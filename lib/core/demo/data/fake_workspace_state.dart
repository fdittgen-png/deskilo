// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2597 -- the state of the in-memory workspace repository: every recorded
// field the suite reads, and the `target` lookup. The operations are the
// per-capability mixins (`fake_workspace_*.dart`) composed in
// `FakeWorkspaceRepository`; they all reach the state through this class.
import 'dart:typed_data' show Uint8List;

import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/workspace/domain/invitation_answer.dart';
import 'package:deskilo/features/workspace/domain/managed_access.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_badge.dart';
import 'package:deskilo/features/workspace/domain/new_member_defaults.dart';
import 'package:deskilo/features/workspace/domain/payment_instructions.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/features/workspace/domain/template_publication.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_document.dart';
import 'package:deskilo/features/workspace/domain/workspace_overview.dart';
import 'package:deskilo/features/workspace/domain/workspace_settings_save.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';

abstract class FakeWorkspaceState {
  FakeWorkspaceState({
    List<Workspace>? workspaces,
    this.serverDefaultWorkspaceId,
  }) : workspaces = workspaces ?? [];

  final List<Workspace> workspaces;

  /// Server-side default workspace (#458).
  String? serverDefaultWorkspaceId;

  /// Membership returned by [fetchMyMember]; owner of ws-1 by default.
  Member myMember = const Member(
    id: 'member-1',
    workspaceId: 'ws-1',
    userId: 'user-1',
    isAdmin: true,
    isOwner: true,
    status: MemberStatus.active,
  );

  /// Personal invitations minted through [createInvitation] (0051), in
  /// mint order — tests read the codes and roles back from here.
  final List<
    ({
      String code,
      bool isAdmin,
      String firstName,
      String lastName,
      String? memberId,
      // #1119 — whether the invitation also grants the prod twin.
      bool alsoProd,
    })
  >
  mintedInvitations = [];

  int nextInviteCode = 1;

  int nextId = 1;

  /// #1650 — when set, [fetchMyWorkspaces] throws it: a server that could
  /// not answer, as opposed to one that answered "none".
  Exception? fetchFailure;

  /// #937 — the platform-owner view as the fake holds it.
  bool platformOwner = false;
  final allWorkspaces = <WorkspaceOverview>[];
  final ownersByWorkspace = <String, List<WorkspaceOwner>>{};
  final ownerReads = <String>[];

  /// #945 — the sites as the fake holds them.
  final sites = <Site>[];
  final siteWrites = <String>[];
  final homeSites = <String, String?>{};

  /// #1303 — every creation asked for, and the request ids it answered.
  final createRequests =
      <({String? requestId, String? templateId, bool withTwin})>[];
  final createdByRequest = <String, String>{};

  /// #1303 — the next creation throws this once (a lost response, say).
  Exception? createFailure;

  /// #917 — the last environment written, for assertions.
  String? lastEnvironment;

  /// #987 — the twin the fake created last, and how many.
  final List<String> twinsCreated = [];

  /// (0052) member id → last join decision, for assertions.
  final joinDecisions = <String, bool>{};
  final joinComments = <String, String>{};

  /// (0052) Whether the fake's joins land pending (the server default).
  /// Tests that predate the validation flow keep instant-active joins.
  bool joinsArePending = false;

  /// (0051) codes already redeemed — a second use is refused like the
  /// server's atomic latch.
  final redeemedInvitations = <String>{};

  /// #1652 — answers a test fixes for a code (expired, revoked, paused…);
  /// they win over everything below, for the preview and the join alike.
  final invitationAnswers = <String, InvitationAnswer>{};

  /// #1652 — code → the workspace a join by that code made.
  final joinedByCode = <String, String>{};
  int previewCalls = 0, joinByInvitationCalls = 0;

  /// (#153) Arguments of the last [updateWorkspaceLocale] call, for
  /// assertions: `[workspaceId, countryCode, currencyCode, timezone]`.
  List<String>? lastLocaleUpdate;

  /// (#155) The last saved instructions, for assertions.
  PaymentInstructions? lastPaymentInstructions;

  /// (#231) The last saved WhatsApp group link, for assertions.
  String? lastWhatsappGroup;

  /// (0049) The last saved invitation template, for assertions.
  String? lastInvitationTemplate;

  /// memberId → display name; seeded with the default member.
  Map<String, String> memberNames = {'member-1': 'Flo'};

  /// memberId → email; served only to admin/owner callers, mirroring
  /// the member_emails RPC gate (0078, #410).
  Map<String, String> memberEmails = {};

  /// Extra members beyond [myMember] for the management screen.
  final List<Member> otherMembers = [];

  /// #887 — managed members created through the fake, and the
  /// handovers revoked, for assertions.
  final List<String> revokedHandovers = [];
  int nextManagedId = 1;

  /// #915 — the identities behind the rule, as the gated table holds them.
  final managedIdentities = <String, PersonalInfo>{};

  /// #914 — the last rule written, for assertions.
  ManagedAccess? lastManagedAccess;

  /// My memberships across workspaces (profiles, #89); defaults to just
  /// [myMember]. Tests add more for multi-profile scenarios.
  final List<Member> extraMyMemberships = [];

  /// (0050) member id → last level-permission written, for assertions.
  final levelPermissions = <String, bool>{};

  /// Issued badges; tokens are deterministic 'badge-token-N'.
  final badges = <MemberBadge>[];

  /// #500 — the in-memory document library.
  final List<WorkspaceDocument> documents = [];

  /// (workspaceId, memberId, makeAdmin) of the last role-change request.
  (String, String, bool)? lastRoleChange;

  /// #1329 — the read-set of every write (null for an unconditional one),
  /// and a switch to answer the next write with a conflict.
  final flagExpectations = <Map<String, bool>?>[];
  bool flagConflictNext = false;

  /// #3283 — the next flag write fails with this (a lost connection, or the
  /// server's refusal once the right was withdrawn); nothing is written.
  Exception? flagWriteErrorNext;

  /// Every flag map handed to [setFeatureFlags], in order (#963 pins
  /// that a toggle writes only what it changes).
  final List<Map<String, bool>> flagWrites = [];

  /// #1294 — what each workspace says a new member starts with.
  final Map<String, NewMemberDefaults> newMemberDefaults = {};

  /// #1277 — workspaceId -> locale -> key -> the workspace's word.
  /// #1289 — branding as the server would store it, by workspace id.
  final Map<String, Map<String, dynamic>> brandings = {};

  /// #1289 — the emblem's bytes by workspace id; absent is a space with
  /// no emblem, which is almost all of them.
  final Map<String, Uint8List> emblems = {};

  final Map<String, Map<String, Map<String, String>>> lexicons = {};

  /// Server-side default workspace (#458).

  /// Workspace ids passed to [resetWorkspace], for assertions.
  final resetWorkspaceCalls = <String>[];
  String? Function(String workspaceId)? booksKept; // #2571: the retention assessment (JSON) that refuses a reset, null when the books may go

  /// Last opacity passed to [setDeskOpacity]; also updates the seeded row.
  int? lastDeskOpacity;

  /// #1451 — every Save sent as one command, and a conflict to raise next.
  final settingsSaves = <WorkspaceSettingsSave>[];
  bool settingsConflictNext = false;
  Exception? settingsFailure;

  // ── #1120 — the workspace library, as the fake holds it ─────────
  final templates = <WorkspaceTemplate>[
    const WorkspaceTemplate(
      id: 'tpl-tiny',
      key: 'tiny',
      name: 'A tiny space',
      description: 'Two levels, four desks, eight seats.',
      visibility: TemplateVisibility.builtin,
      floorPlan: <Object?>[
        <String, Object?>{
          'name': 'Ground',
          'offices': <Object?>[
            <String, Object?>{
              'name': 'Room 1',
              'desks': <Object?>[
                <String, Object?>{
                  'name': 'Desk 1',
                  'seats': <Object?>[<String, Object?>{}, <String, Object?>{}],
                },
                <String, Object?>{
                  'name': 'Desk 2',
                  'seats': <Object?>[<String, Object?>{}, <String, Object?>{}],
                },
              ],
            },
          ],
        },
        <String, Object?>{
          'name': 'First',
          'offices': <Object?>[
            <String, Object?>{
              'name': 'Room 2',
              'desks': <Object?>[
                <String, Object?>{
                  'name': 'Desk 3',
                  'seats': <Object?>[<String, Object?>{}, <String, Object?>{}],
                },
                <String, Object?>{
                  'name': 'Desk 4',
                  'seats': <Object?>[<String, Object?>{}, <String, Object?>{}],
                },
              ],
            },
          ],
        },
      ],
    ),
  ];
  final templateGrants = <String, List<String>>{};
  final appliedTemplates =
      <({String workspaceId, String templateId, List<String>? groups})>[];

  TemplateApplyResult templateApplyResult = const TemplateApplyResult();

  /// #1280 S3 — the groups each save asked for (null = everything allowed).
  final savedTemplateGroups = <List<String>?>[];

  /// #1658 — publication request id → its arguments and template.
  final Map<String, ({String args, String id})> publishRequests = {};

  /// Tests: the next publication happens, and its answer is lost.
  bool loseNextPublishResponse = false;

  /// #1280 S3 — what the fake server says publishing would carry.
  TemplatePublication publication = const TemplatePublication(
    published: [
      PublishedEntity(entity: 'floor_plan', group: TemplateGroup.space),
      PublishedEntity(
        entity: 'identity',
        group: TemplateGroup.wording,
        stripped: ['address', 'vat_id'],
      ),
      PublishedEntity(
        entity: 'booking_rules',
        group: TemplateGroup.hoursBooking,
      ),
    ],
    neverPublished: [
      NeverPublished(entity: 'payment_instructions', reason: 'bank details'),
      NeverPublished(entity: 'sites', reason: 'addresses'),
    ],
    planNames: ['Ground floor', 'Desk 1'],
  );

  /// #1280 — the preview a test wants the server to answer, by template id.
  /// Without one, each entity group the template carries previews as new.
  final templatePreviews = <String, TemplatePreview>{};

  /// #1303 — outlines by template id; unset ids outline their plan.
  final templateOutlines = <String, TemplateOutline>{};

  /// #1655 — inspections by template id; unset ids inspect as a usable
  /// legacy plan whose outline is [workspaceTemplateOutline]'s.
  final templateInspections = <String, TemplateInspection>{};

  // #2386 — the operations; each body is in a part file.

  Workspace? target(String workspaceId) =>
      workspaces.where((w) => w.id == workspaceId).firstOrNull;
}
