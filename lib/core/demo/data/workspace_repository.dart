// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ADR 0028 (#1373) — moved out of test/helpers/mock_providers.dart so the
// Demo environment can run the real app against it. The suite reaches it
// through the same import as before.

import 'dart:async';
import 'dart:typed_data' show Uint8List;

import 'package:deskilo/core/time/work_hours.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/workspace/domain/booking_granularity.dart';
import 'package:deskilo/features/workspace/domain/booking_policies.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:deskilo/features/workspace/domain/conversation.dart';
import 'package:deskilo/features/workspace/domain/feature_flags_write.dart';
import 'package:deskilo/features/workspace/domain/invitation_answer.dart';
import 'package:deskilo/features/workspace/domain/invite_uri.dart';
import 'package:deskilo/features/workspace/domain/managed_access.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/member_badge.dart';
import 'package:deskilo/features/workspace/domain/member_note.dart';
import 'package:deskilo/features/workspace/domain/new_member_defaults.dart';
import 'package:deskilo/features/workspace/domain/overage_policy.dart';
import 'package:deskilo/features/workspace/domain/payment_instructions.dart';
import 'package:deskilo/features/workspace/domain/public_holidays.dart';
import 'package:deskilo/features/workspace/domain/site.dart';
import 'package:deskilo/features/workspace/domain/template_inspection.dart';
import 'package:deskilo/features/workspace/domain/template_outline.dart';
import 'package:deskilo/features/workspace/domain/template_preview.dart';
import 'package:deskilo/features/workspace/domain/template_publication.dart';
import 'package:deskilo/features/workspace/domain/work_hours_provenance.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo/features/workspace/domain/workspace_branding.dart';
import 'package:deskilo/features/workspace/domain/workspace_document.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_overview.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/domain/workspace_repository.dart';
import 'package:deskilo/features/workspace/domain/workspace_settings_save.dart';
import 'package:deskilo/features/workspace/domain/workspace_template.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../time/date_text.dart';
import 'fixture_clock.dart';

part 'workspace_repository_part1.dart';
part 'workspace_repository_part2.dart';
part 'workspace_repository_part3.dart';
part 'workspace_repository_part4.dart';

/// In-memory [WorkspaceRepository] for tests.
class FakeWorkspaceRepository implements WorkspaceRepository {
  FakeWorkspaceRepository({List<Workspace>? workspaces})
      : workspaces = workspaces ?? [];

  /// One seeded workspace; [featureFlags] seeds its feature overrides
  /// (#146) over the platform features that ship on (#2566).
  FakeWorkspaceRepository.withWorkspace({
    Map<String, dynamic> featureFlags = const {},
  }) : workspaces = [
          Workspace(
            id: 'ws-1',
            rolePermissions: everydayMatrix(),
            name: 'Test Space',
            countryCode: 'DE',
            currencyCode: 'EUR',
            timezone: 'Europe/Berlin',
            inviteCode: 'GOODCODE22',
            featureFlags: {...platformFeaturesOnByDefault, ...featureFlags},
            // #917 — the shared fixture is a PRODUCTION workspace, so the
            // development strip does not steal a row from every layout
            // assertion in the suite. The strip has its own tests
            // (environment_banner_test.dart), which pump the whole app on
            // a development one and walk a pushed route under it; a test
            // that is about the environment says so by setting it.
            environment: 'prod',
          ),
        ], serverDefaultWorkspaceId = 'ws-1'; // #1823: the fixture opens in ws-1, not on Me

  final List<Workspace> workspaces;

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
        bool alsoProd
      })> mintedInvitations = [];

  var _nextInviteCode = 1;

  var _nextId = 1;

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
  final createRequests = <({String? requestId, String? templateId, bool withTwin})>[];
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
  var _nextManagedId = 1;

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

  /// Every flag map handed to [setFeatureFlags], in order (#963 pins
  /// that a toggle writes only what it changes).
  final List<Map<String, bool>> flagWrites = [];

  /// ISO open weekdays (1=Mon..7=Sun) per workspace; Mon–Fri when unseeded.
  final Map<String, List<int>> openWeekdays = {};

  /// Booking granularity per workspace (#200); flexible when unseeded —
  /// stored beside [openWeekdays] like the separate booking_rules keys.
  final Map<String, BookingGranularity> bookingGranularities = {};

  /// The #600 policy switches per workspace; all OFF when unseeded.
  final Map<String, BookingPolicies> bookingPolicies = {};

  /// #1294 — what each workspace says a new member starts with.
  final Map<String, NewMemberDefaults> newMemberDefaults = {};

  /// #1294 — the workspace's fallback default period, by workspace.
  final Map<String, String?> workspaceDefaultPeriods = {};

  /// #1277 — workspaceId -> locale -> key -> the workspace's word.
  /// #1289 — branding as the server would store it, by workspace id.
  final Map<String, Map<String, dynamic>> brandings = {};

  /// #1289 — the emblem's bytes by workspace id; absent is a space with
  /// no emblem, which is almost all of them.
  final Map<String, Uint8List> emblems = {};

  final Map<String, Map<String, Map<String, String>>> lexicons = {};

  /// Working day per workspace (#446); defaults like the real repo.
  final Map<String, WorkHours> workHours = {};

  /// Sent member notes (#456), newest last; myNotes returns them
  /// newest-first like the real query.
  final List<MemberNote> memberNotes = [];

  // ── conversations (#687) ────────────────────────────────────────────

  /// Threads the fake knows about, in no particular order — the fake
  /// SORTS on read, exactly as `my_conversations` does, so a test that
  /// depends on ordering exercises the ordering rather than the seed
  /// order.
  final List<Conversation> conversations = [];

  /// Messages per conversation id, oldest first.
  final Map<String, List<MemberNote>> conversationMessages = {};
  final Map<String, List<ConversationParticipant>> participants = {};

  final List<({String conversationId, String body})> sentMessages = [];
  final List<String> readConversations = [];
  final List<({String conversationId, String memberId})> addedParticipants = [];
  final List<({String conversationId, String memberId})> removedParticipants =
      [];
  final List<String> leftConversations = [];
  final List<({String id, String? title, String? avatarPath})> metaWrites = [];

  /// The id [createGroupConversation] hands back; tests that navigate on
  /// it need to know it in advance.
  String nextGroupId = 'conv-group';

  /// #821 — prefs writes and unread marks, in order.
  final List<({String id, bool? pinned, bool? muted, bool? archived})>
      prefsWrites = [];
  final List<String> unreadMarks = [];

  /// Ids passed to [deleteMemberNote], in order (#798).
  final List<String> deletedNotes = [];

  /// Server-side default workspace (#458).
  String? serverDefaultWorkspaceId;

  /// #1307 S4 — provenance per workspace; unset reads as the product default.
  final workHoursProvenance = <String, WorkHoursProvenance>{};
  final workHoursResets = <String>[];

  /// One-off closure days across workspaces (#127).
  final List<ClosureDay> closureDays = [];

  /// #1274 — what `generate_closure_days` hands back. Tests seed this;
  /// the fake never recomputes the calendar.
  HolidayGeneration holidayGeneration = HolidayGeneration.empty;

  /// Every generate call, in order, so a test can prove a preview did
  /// not write and an apply did.
  final holidayCalls =
      <({String country, int year, bool apply})>[];

  /// #2051 — months the fake treats as invoiced (`2026-07`), and every
  /// import call in order, so a test can prove which days were sent.
  final Set<String> invoicedMonths = {};
  final holidayImportCalls =
      <({List<({DateTime day, String name})> days, bool apply})>[];

  /// Workspace ids passed to [resetWorkspace], for assertions.
  final resetWorkspaceCalls = <String>[];

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
        <String, Object?>{'name': 'Ground', 'offices': <Object?>[<String, Object?>{'name': 'Room 1', 'desks': <Object?>[<String, Object?>{'name': 'Desk 1', 'seats': <Object?>[<String, Object?>{}, <String, Object?>{}]}, <String, Object?>{'name': 'Desk 2', 'seats': <Object?>[<String, Object?>{}, <String, Object?>{}]}]}]},
        <String, Object?>{'name': 'First', 'offices': <Object?>[<String, Object?>{'name': 'Room 2', 'desks': <Object?>[<String, Object?>{'name': 'Desk 3', 'seats': <Object?>[<String, Object?>{}, <String, Object?>{}]}, <String, Object?>{'name': 'Desk 4', 'seats': <Object?>[<String, Object?>{}, <String, Object?>{}]}]}]},
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
          stripped: ['address', 'vat_id']),
      PublishedEntity(entity: 'booking_rules', group: TemplateGroup.hoursBooking),
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
  // ignore: avoid_positional_boolean_parameters — #2389, an existing API; named when it next changes
  void applyDevMode(bool enabled) => _applyDevModeImpl(enabled);
  @override Future<void> setDevMode(String workspaceId, bool enabled) => _setDevModeImpl(workspaceId, enabled);
  @override Future<String> createInvitation(String workspaceId, {required bool isAdmin, String firstName = '', String lastName = '', String? memberId, bool alsoProd = false}) => _createInvitationImpl(workspaceId, isAdmin: isAdmin, firstName: firstName, lastName: lastName, memberId: memberId, alsoProd: alsoProd);
  @override Future<List<Workspace>> fetchMyWorkspaces() => _fetchMyWorkspacesImpl();
  @override Future<List<Site>> fetchSites(String workspaceId) => _fetchSitesImpl(workspaceId);
  @override Future<String> upsertSite(String workspaceId, Site site, {bool isNew = false}) => _upsertSiteImpl(workspaceId, site, isNew: isNew);
  @override Future<void> deleteSite(String siteId) => _deleteSiteImpl(siteId);
  @override Future<void> setMemberHomeSite(String memberId, String? siteId) => _setMemberHomeSiteImpl(memberId, siteId);
  @override Future<bool> isPlatformOwner() => _isPlatformOwnerImpl();
  @override Future<List<WorkspaceOverview>> fetchAllWorkspaces() => _fetchAllWorkspacesImpl();
  @override Future<List<WorkspaceOwner>> fetchWorkspaceOwners(String workspaceId) => _fetchWorkspaceOwnersImpl(workspaceId);
  @override Future<String> createWorkspace({required String name, required String countryCode, required String currencyCode, required String timezone, WorkspaceEnvironment environment = WorkspaceEnvironment.development, bool withTwin = true, String? requestId, String? templateId}) => _createWorkspaceImpl(name: name, countryCode: countryCode, currencyCode: currencyCode, timezone: timezone, environment: environment, withTwin: withTwin, requestId: requestId, templateId: templateId);
  @override Future<String> createWorkspaceTwin(String workspaceId) => _createWorkspaceTwinImpl(workspaceId);
  @override Future<void> setWorkspaceEnvironment(String workspaceId, WorkspaceEnvironment environment) => _setWorkspaceEnvironmentImpl(workspaceId, environment);
  @override Future<void> decideMemberJoin(String memberId, {required bool approve, String comment = '', String? expectedAccount}) => _decideMemberJoinImpl(memberId, approve: approve, comment: comment, expectedAccount: expectedAccount);
  @override Future<String> joinWorkspace(String inviteCode) => _joinWorkspaceImpl(inviteCode);
  @override Future<InvitationAnswer> previewInvitation(String inviteCode) => _previewInvitationImpl(inviteCode);
  @override Future<InvitationAnswer> joinByInvitation(String inviteCode) => _joinByInvitationImpl(inviteCode);
  @override Future<void> updateWorkspaceLocale(String workspaceId, {required String countryCode, required String currencyCode, required String timezone}) => _updateWorkspaceLocaleImpl(workspaceId, countryCode: countryCode, currencyCode: currencyCode, timezone: timezone);
  @override Future<void> setPaymentInstructions(String workspaceId, PaymentInstructions instructions) => _setPaymentInstructionsImpl(workspaceId, instructions);
  @override Future<void> setWhatsappGroup(String workspaceId, String link) => _setWhatsappGroupImpl(workspaceId, link);
  @override Future<void> setInvitationTemplate(String workspaceId, String template) => _setInvitationTemplateImpl(workspaceId, template);
  @override Future<Member?> fetchMyMember(String workspaceId) => _fetchMyMemberImpl(workspaceId);
  @override Future<Map<String, String>> fetchMemberNames(String workspaceId) => _fetchMemberNamesImpl(workspaceId);
  @override Future<Map<String, String>> fetchMemberEmails(String workspaceId) => _fetchMemberEmailsImpl(workspaceId);
  @override Future<String> createManagedMember(String workspaceId, PersonalInfo identity, {ManagedAccess access = ManagedAccess.unnarrowed}) => _createManagedMemberImpl(workspaceId, identity, access: access);
  @override Future<PersonalInfo> managedIdentityOf(String memberId) => _managedIdentityOfImpl(memberId);
  @override Future<void> setManagedAccess(String memberId, ManagedAccess access) => _setManagedAccessImpl(memberId, access);
  @override Future<void> updateManagedIdentity(String memberId, PersonalInfo identity) => _updateManagedIdentityImpl(memberId, identity);
  @override Future<void> revokeHandover(String memberId) => _revokeHandoverImpl(memberId);
  @override Future<List<Member>> fetchMembers(String workspaceId) => _fetchMembersImpl(workspaceId);
  @override Future<List<Member>> fetchMyMembers() => _fetchMyMembersImpl();
  @override Future<void> updateMemberSubscription(String memberId, int pct) => _updateMemberSubscriptionImpl(memberId, pct);
  @override Future<void> updateMemberOveragePolicy(String memberId, OveragePolicy policy) => _updateMemberOveragePolicyImpl(memberId, policy);
  @override Future<void> setMemberReservationLimit(String memberId, int? limit) => _setMemberReservationLimitImpl(memberId, limit);
  @override Future<void> setMemberCustomerCapacity(String memberId, String? capacity) => _setMemberCustomerCapacityImpl(memberId, capacity);
  @override Future<void> setMemberEInvoiceAddress(String memberId, {required String endpointId, required String endpointScheme, required String subdivision}) => _setMemberEInvoiceAddressImpl(memberId, endpointId: endpointId, endpointScheme: endpointScheme, subdivision: subdivision);
  @override Future<void> setMemberVatTreatment(String memberId, String treatment, String reason) => _setMemberVatTreatmentImpl(memberId, treatment, reason);
  @override Future<void> setMemberSimultaneousLimit(String memberId, int? limit) => _setMemberSimultaneousLimitImpl(memberId, limit);
  @override Future<void> setMemberLevelPermission(String memberId, {required bool allowed}) => _setMemberLevelPermissionImpl(memberId, allowed: allowed);
  @override Future<void> setMemberKiosk(String memberId, {required bool isKiosk}) => _setMemberKioskImpl(memberId, isKiosk: isKiosk);
  @override Future<List<MemberBadge>> fetchMemberBadges(String workspaceId) => _fetchMemberBadgesImpl(workspaceId);
  @override Future<IssuedBadge> issueMemberBadge(String workspaceId, String memberId, {String label = ''}) => _issueMemberBadgeImpl(workspaceId, memberId, label: label);
  @override Future<void> registerNfcBadge(String workspaceId, String memberId, {required String uid, String label = ''}) => _registerNfcBadgeImpl(workspaceId, memberId, uid: uid, label: label);
  @override Future<void> revokeMemberBadge(String badgeId) => _revokeMemberBadgeImpl(badgeId);
  @override Future<IssuedBadge> issueMyBadge(String workspaceId, {String label = ''}) => _issueMyBadgeImpl(workspaceId, label: label);
  @override Future<void> registerMyNfcBadge(String workspaceId, {required String uid, String label = ''}) => _registerMyNfcBadgeImpl(workspaceId, uid: uid, label: label);
  @override Future<void> revokeMyBadge(String badgeId) => _revokeMyBadgeImpl(badgeId);
  @override Future<void> deleteRevokedBadge(String badgeId) => _deleteRevokedBadgeImpl(badgeId);
  @override Future<void> setWorkspaceAddress(String workspaceId, String address) => _setWorkspaceAddressImpl(workspaceId, address);
  @override Future<void> setLegalIdentity(String workspaceId, {required String vatRegime, required String vatId, required String legalId, required String taxExemptionReason, required String street, required String city, required String postalCode, required String vatAccount, required Map<String, Object?> invoiceLegal}) => _setLegalIdentityImpl(workspaceId, vatRegime: vatRegime, vatId: vatId, legalId: legalId, taxExemptionReason: taxExemptionReason, street: street, city: city, postalCode: postalCode, vatAccount: vatAccount, invoiceLegal: invoiceLegal);
  @override Future<void> setSubscriptionVatRate(String workspaceId, String vatRateId) => _setSubscriptionVatRateImpl(workspaceId, vatRateId);
  @override Future<List<WorkspaceDocument>> fetchDocuments(String workspaceId) => _fetchDocumentsImpl(workspaceId);
  @override Future<void> addDocument(WorkspaceDocument document) => _addDocumentImpl(document);
  @override Future<void> deleteDocument(String documentId) => _deleteDocumentImpl(documentId);
  @override Future<void> setWorkspaceLanguage(String workspaceId, String locale) => _setWorkspaceLanguageImpl(workspaceId, locale);
  @override Future<void> setRolePermissions(String workspaceId, String role, List<String> permissions) => _setRolePermissionsImpl(workspaceId, role, permissions);
  @override Future<void> setRolePermission(String workspaceId, String role, String permission, {required bool enabled}) => _setRolePermissionImpl(workspaceId, role, permission, enabled: enabled);
  @override Future<void> setInvitationTemplates(String workspaceId, Map<String, String> templates) => _setInvitationTemplatesImpl(workspaceId, templates);
  @override Future<void> setCoOwner(String memberId, CoOwnerStatus status) => _setCoOwnerImpl(memberId, status);
  @override Future<void> activateCoOwner(String memberId) => _activateCoOwnerImpl(memberId);
  @override Future<void> unsetMyKiosk(String workspaceId) => _unsetMyKioskImpl(workspaceId);
  @override Future<void> requestRoleChange(String workspaceId, {required String memberId, required bool makeAdmin}) => _requestRoleChangeImpl(workspaceId, memberId: memberId, makeAdmin: makeAdmin);
  @override Future<String> setWorkspaceCode(String workspaceId, String code) => _setWorkspaceCodeImpl(workspaceId, code);
  @override Future<void> setFeatureFlags(String workspaceId, Map<String, bool> flags, {Map<String, bool>? expected}) => _setFeatureFlagsImpl(workspaceId, flags, expected: expected);
  @override Future<List<int>> fetchOpenWeekdays(String workspaceId) => _fetchOpenWeekdaysImpl(workspaceId);
  @override Future<void> setOpenWeekdays(String workspaceId, List<int> weekdays) => _setOpenWeekdaysImpl(workspaceId, weekdays);
  @override Future<BookingGranularity> fetchBookingGranularity(String workspaceId) => _fetchBookingGranularityImpl(workspaceId);
  @override Future<void> setBookingGranularity(String workspaceId, BookingGranularity granularity) => _setBookingGranularityImpl(workspaceId, granularity);
  @override Future<String?> fetchDefaultPeriod(String workspaceId) => _fetchDefaultPeriodImpl(workspaceId);
  @override Future<void> setDefaultPeriod(String workspaceId, String? wire) => _setDefaultPeriodImpl(workspaceId, wire);
  @override Future<NewMemberDefaults> fetchNewMemberDefaults(String workspaceId) => _fetchNewMemberDefaultsImpl(workspaceId);
  @override Future<void> setNewMemberDefaults(String workspaceId, NewMemberDefaults defaults) => _setNewMemberDefaultsImpl(workspaceId, defaults);
  @override Future<void> setWorkspaceEmblem(String workspaceId, Uint8List png) => _setWorkspaceEmblemImpl(workspaceId, png);
  @override Future<Uint8List?> fetchWorkspaceEmblem(String workspaceId) => _fetchWorkspaceEmblemImpl(workspaceId);
  @override Future<void> clearWorkspaceEmblem(String workspaceId) => _clearWorkspaceEmblemImpl(workspaceId);
  @override Future<Map<String, dynamic>> setWorkspaceBranding(String workspaceId, Map<String, dynamic> delta) => _setWorkspaceBrandingImpl(workspaceId, delta);
  @override Future<Map<String, dynamic>> fetchLexicon(String workspaceId) => _fetchLexiconImpl(workspaceId);
  @override Future<void> setLexiconTerm(String workspaceId, String locale, String key, String? text) => _setLexiconTermImpl(workspaceId, locale, key, text);
  @override Future<BookingPolicies> fetchBookingPolicies(String workspaceId) => _fetchBookingPoliciesImpl(workspaceId);
  @override Future<void> setBookingPolicy(String workspaceId, String key, {required bool enabled}) => _setBookingPolicyImpl(workspaceId, key, enabled: enabled);
  @override Future<void> setSimultaneousReservations(String workspaceId, int value) => _setSimultaneousReservationsImpl(workspaceId, value);
  @override Future<void> setBookingLimit(String workspaceId, String key, int value) => _setBookingLimitImpl(workspaceId, key, value);
  @override Future<void> setLegendProfile(String workspaceId, LegendProfile profile) => _setLegendProfileImpl(workspaceId, profile);
  @override Future<void> setOutsideHoursMode(String workspaceId, OutsideHoursMode mode) => _setOutsideHoursModeImpl(workspaceId, mode);
  @override Future<List<Conversation>> fetchConversations(String workspaceId, {bool includeArchived = false}) => _fetchConversationsImpl(workspaceId, includeArchived: includeArchived);
  @override Future<void> setConversationPrefs(String conversationId, {bool? pinned, bool? muted, bool? archived}) => _setConversationPrefsImpl(conversationId, pinned: pinned, muted: muted, archived: archived);
  @override Future<void> markConversationUnread(String conversationId) => _markConversationUnreadImpl(conversationId);
  @override Future<String> openDirectConversation(String workspaceId, {required String otherMemberId}) => _openDirectConversationImpl(workspaceId, otherMemberId: otherMemberId);
  @override Future<String> createGroupConversation(String workspaceId, {required String title, required List<String> memberIds}) => _createGroupConversationImpl(workspaceId, title: title, memberIds: memberIds);
  @override Future<List<ConversationParticipant>> fetchParticipants(String conversationId) => _fetchParticipantsImpl(conversationId);
  @override Future<void> addParticipant(String conversationId, String memberId) => _addParticipantImpl(conversationId, memberId);
  @override Future<void> removeParticipant(String conversationId, String memberId) => _removeParticipantImpl(conversationId, memberId);
  @override Future<void> leaveConversation(String conversationId) => _leaveConversationImpl(conversationId);
  @override Future<void> setConversationMeta(String conversationId, {String? title, String? avatarPath}) => _setConversationMetaImpl(conversationId, title: title, avatarPath: avatarPath);
  @override Future<void> sendConversationMessage(String conversationId, String body) => _sendConversationMessageImpl(conversationId, body);
  @override Future<List<MemberNote>> fetchConversationMessages(String conversationId, {int limit = 200, DateTime? before}) => _fetchConversationMessagesImpl(conversationId, limit: limit, before: before);
  @override Future<void> markConversationRead(String conversationId) => _markConversationReadImpl(conversationId);
  @override Future<List<MemberNote>> searchMessages(String workspaceId, String query) => _searchMessagesImpl(workspaceId, query);
  @override Future<void> sendMemberNote(String workspaceId, {required String? toMemberId, required String body}) => _sendMemberNoteImpl(workspaceId, toMemberId: toMemberId, body: body);
  @override Future<List<MemberNote>> fetchMyNotes(String workspaceId) => _fetchMyNotesImpl(workspaceId);
  @override Future<void> deleteMemberNote(String noteId) => _deleteMemberNoteImpl(noteId);
  @override Future<void> markMyNotesRead(String workspaceId, {String? fromMemberId}) => _markMyNotesReadImpl(workspaceId, fromMemberId: fromMemberId);
  @override Future<String?> fetchDefaultWorkspaceId() => _fetchDefaultWorkspaceIdImpl();
  @override Future<void> setDefaultWorkspaceId(String? workspaceId) => _setDefaultWorkspaceIdImpl(workspaceId);
  @override Future<WorkHours> fetchWorkHours(String workspaceId) => _fetchWorkHoursImpl(workspaceId);
  @override Future<void> setWorkHours(String workspaceId, WorkHours hours) => _setWorkHoursImpl(workspaceId, hours);
  @override Future<WorkHoursProvenance> fetchWorkHoursProvenance(String workspaceId) => _fetchWorkHoursProvenanceImpl(workspaceId);
  @override Future<void> resetWorkHoursToDefault(String workspaceId) => _resetWorkHoursToDefaultImpl(workspaceId);
  @override Future<List<ClosureDay>> fetchClosureDays(String workspaceId) => _fetchClosureDaysImpl(workspaceId);
  @override Future<HolidayGeneration> generateClosureDays(String workspaceId, {required String country, required int year, bool apply = false}) => _generateClosureDaysImpl(workspaceId, country: country, year: year, apply: apply);
  @override Future<HolidayGeneration> importClosureDays(String workspaceId, {required List<({DateTime day, String name})> days, bool apply = false}) => _importClosureDaysImpl(workspaceId, days: days, apply: apply);
  @override Future<ClosureDay> addClosureDay(String workspaceId, DateTime day, String reason) => _addClosureDayImpl(workspaceId, day, reason);
  @override Future<void> removeClosureDay(String closureDayId) => _removeClosureDayImpl(closureDayId);
  @override Future<void> resetWorkspace(String workspaceId) => _resetWorkspaceImpl(workspaceId);
  @override Future<Workspace> saveWorkspaceSettings(String workspaceId, WorkspaceSettingsSave save) => _saveWorkspaceSettingsImpl(workspaceId, save);
  @override Future<void> setDeskOpacity(String workspaceId, int opacity) => _setDeskOpacityImpl(workspaceId, opacity);
  @override Future<void> updateMemberStatus(String memberId, MemberStatus status) => _updateMemberStatusImpl(memberId, status);
  @override Future<List<WorkspaceTemplate>> fetchWorkspaceTemplates() => _fetchWorkspaceTemplatesImpl();
  @override Future<TemplateApplyResult> applyWorkspaceTemplate(String workspaceId, String templateId, {List<String>? groups, int? expectedVersion, String? requestId}) => _applyWorkspaceTemplateImpl(workspaceId, templateId, groups: groups, expectedVersion: expectedVersion, requestId: requestId);
  @override Future<TemplatePublication> templatePublicationPreview(String workspaceId, {List<String>? groups}) => _templatePublicationPreviewImpl(workspaceId, groups: groups);
  @override Future<TemplatePreview> previewWorkspaceTemplate(String workspaceId, String templateId, {List<String>? groups}) => _previewWorkspaceTemplateImpl(workspaceId, templateId, groups: groups);
  @override Future<TemplateInspection> inspectWorkspaceTemplate(String templateId) => _inspectWorkspaceTemplateImpl(templateId);
  @override Future<TemplateOutline> workspaceTemplateOutline(String templateId) => _workspaceTemplateOutlineImpl(templateId);
  @override Future<String> saveWorkspaceAsTemplate(String workspaceId, {required String key, required String name, String description = '', TemplateVisibility visibility = TemplateVisibility.private, List<String> tags = const [], List<String>? groups, String? requestId}) => _saveWorkspaceAsTemplateImpl(workspaceId, key: key, name: name, description: description, visibility: visibility, tags: tags, groups: groups, requestId: requestId);
  @override Future<void> setWorkspaceTemplateVisibility(String templateId, TemplateVisibility visibility) => _setWorkspaceTemplateVisibilityImpl(templateId, visibility);
  @override Future<void> deleteWorkspaceTemplate(String templateId) => _deleteWorkspaceTemplateImpl(templateId);
  @override Future<void> grantWorkspaceTemplate(String templateId, String email) => _grantWorkspaceTemplateImpl(templateId, email);
  @override Future<void> revokeWorkspaceTemplateGrant(String templateId, String email) => _revokeWorkspaceTemplateGrantImpl(templateId, email);
  @override Future<List<String>> workspaceTemplateGrantees(String templateId) => _workspaceTemplateGranteesImpl(templateId);

}
