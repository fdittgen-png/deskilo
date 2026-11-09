// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/enum_wire.dart';
import '../../../core/validation/pending_validation.dart';
import '../../profile/domain/personal_info.dart';
import '../domain/feature_flags_write.dart';
import '../domain/invitation_answer.dart';
import '../domain/managed_access.dart';
import '../domain/member.dart';
import '../domain/member_badge.dart';
import '../domain/new_member_defaults.dart';
import '../domain/overage_policy.dart';
import '../domain/payment_instructions.dart';
import '../domain/site.dart';
import '../domain/workspace.dart';
import '../domain/workspace_branding.dart';
import '../domain/workspace_document.dart';
import '../domain/workspace_feature.dart';
import '../domain/workspace_overview.dart';
import '../domain/workspace_repository.dart';
import '../domain/workspace_settings_save.dart';
import 'supabase_booking_rules.dart';
import 'supabase_conversations.dart';
import 'supabase_workspace_provenance.dart';
import 'supabase_workspace_templates.dart';

part 'supabase_workspace_repository_part1.dart';
part 'supabase_workspace_repository_part2.dart';
part 'supabase_workspace_repository_part3.dart';

class SupabaseWorkspaceRepository
    with SupabaseConversations, SupabaseBookingRules, SupabaseWorkspaceTemplates, SupabaseWorkspaceProvenance
    implements WorkspaceRepository {
  SupabaseWorkspaceRepository(this._client);

  final SupabaseClient _client;

  /// The one place the emblem's path is written down.
  static String emblemPath(String workspaceId) =>
      '$workspaceId/brand/emblem.png';

  // #2386 — the operations; each body is in a part file.
  @override SupabaseClient get client => _clientImpl;
  @override SupabaseClient get conversationClient => _conversationClientImpl;
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
  @override Future<String> joinWorkspace(String inviteCode) => _joinWorkspaceImpl(inviteCode);
  @override Future<InvitationAnswer> previewInvitation(String inviteCode) => _previewInvitationImpl(inviteCode);
  @override Future<InvitationAnswer> joinByInvitation(String inviteCode) => _joinByInvitationImpl(inviteCode);
  @override Future<String> createInvitation(String workspaceId, {required bool isAdmin, String firstName = '', String lastName = '', String? memberId, bool alsoProd = false}) => _createInvitationImpl(workspaceId, isAdmin: isAdmin, firstName: firstName, lastName: lastName, memberId: memberId, alsoProd: alsoProd);
  @override Future<String> createManagedMember(String workspaceId, PersonalInfo identity, {ManagedAccess access = ManagedAccess.unnarrowed}) => _createManagedMemberImpl(workspaceId, identity, access: access);
  @override Future<PersonalInfo> managedIdentityOf(String memberId) => _managedIdentityOfImpl(memberId);
  @override Future<void> setManagedAccess(String memberId, ManagedAccess access) => _setManagedAccessImpl(memberId, access);
  @override Future<void> updateManagedIdentity(String memberId, PersonalInfo identity) => _updateManagedIdentityImpl(memberId, identity);
  @override Future<void> revokeHandover(String memberId) => _revokeHandoverImpl(memberId);
  @override Future<void> updateWorkspaceLocale(String workspaceId, {required String countryCode, required String currencyCode, required String timezone}) => _updateWorkspaceLocaleImpl(workspaceId, countryCode: countryCode, currencyCode: currencyCode, timezone: timezone);
  @override Future<void> setPaymentInstructions(String workspaceId, PaymentInstructions instructions) => _setPaymentInstructionsImpl(workspaceId, instructions);
  @override Future<void> setLegalIdentity(String workspaceId, {required String vatRegime, required String vatId, required String legalId, required String taxExemptionReason, required String street, required String city, required String postalCode, required String vatAccount, required Map<String, Object?> invoiceLegal}) => _setLegalIdentityImpl(workspaceId, vatRegime: vatRegime, vatId: vatId, legalId: legalId, taxExemptionReason: taxExemptionReason, street: street, city: city, postalCode: postalCode, vatAccount: vatAccount, invoiceLegal: invoiceLegal);
  @override Future<void> setSubscriptionVatRate(String workspaceId, String vatRateId) => _setSubscriptionVatRateImpl(workspaceId, vatRateId);
  @override Future<List<WorkspaceDocument>> fetchDocuments(String workspaceId) => _fetchDocumentsImpl(workspaceId);
  @override Future<void> addDocument(WorkspaceDocument document) => _addDocumentImpl(document);
  @override Future<void> deleteDocument(String documentId) => _deleteDocumentImpl(documentId);
  @override Future<void> setWorkspaceLanguage(String workspaceId, String locale) => _setWorkspaceLanguageImpl(workspaceId, locale);
  @override Future<void> setInvitationTemplates(String workspaceId, Map<String, String> templates) => _setInvitationTemplatesImpl(workspaceId, templates);
  @override @override Future<void> setWorkspaceAddress(String workspaceId, String address) => _setWorkspaceAddressImpl(workspaceId, address);
  @override Future<void> setWhatsappGroup(String workspaceId, String link) => _setWhatsappGroupImpl(workspaceId, link);
  @override Future<void> setInvitationTemplate(String workspaceId, String template) => _setInvitationTemplateImpl(workspaceId, template);
  @override Future<void> decideMemberJoin(String memberId, {required bool approve, String comment = '', String? expectedAccount}) => _decideMemberJoinImpl(memberId, approve: approve, comment: comment, expectedAccount: expectedAccount);
  @override Future<Member?> fetchMyMember(String workspaceId) => _fetchMyMemberImpl(workspaceId);
  @override Future<Map<String, String>> fetchMemberEmails(String workspaceId) => _fetchMemberEmailsImpl(workspaceId);
  @override Future<Map<String, String>> fetchMemberNames(String workspaceId) => _fetchMemberNamesImpl(workspaceId);
  @override Future<void> setRolePermission(String workspaceId, String role, String permission, {required bool enabled}) => _setRolePermissionImpl(workspaceId, role, permission, enabled: enabled);
  @override Future<void> setRolePermissions(String workspaceId, String role, List<String> permissions) => _setRolePermissionsImpl(workspaceId, role, permissions);
  @override Future<void> setFeatureFlags(String workspaceId, Map<String, bool> flags, {Map<String, bool>? expected}) => _setFeatureFlagsImpl(workspaceId, flags, expected: expected);
  @override Future<void> setDevMode(String workspaceId, {required bool enabled}) => _setDevModeImpl(workspaceId, enabled);
  @override Future<List<Member>> fetchMembers(String workspaceId) => _fetchMembersImpl(workspaceId);
  @override Future<void> updateMemberSubscription(String memberId, int pct) => _updateMemberSubscriptionImpl(memberId, pct);
  @override Future<void> updateMemberOveragePolicy(String memberId, OveragePolicy policy) => _updateMemberOveragePolicyImpl(memberId, policy);
  @override Future<void> setMemberReservationLimit(String memberId, int? limit) => _setMemberReservationLimitImpl(memberId, limit);
  @override Future<void> setMemberSimultaneousLimit(String memberId, int? limit) => _setMemberSimultaneousLimitImpl(memberId, limit);
  @override Future<void> setMemberVatTreatment(String memberId, String treatment, String reason) => _setMemberVatTreatmentImpl(memberId, treatment, reason);
  @override Future<void> setMemberCustomerCapacity(String memberId, String? capacity) => _setMemberCustomerCapacityImpl(memberId, capacity);
  @override Future<void> setMemberEInvoiceAddress(String memberId, {required String endpointId, required String endpointScheme, required String subdivision}) => _setMemberEInvoiceAddressImpl(memberId, endpointId: endpointId, endpointScheme: endpointScheme, subdivision: subdivision);
  @override Future<void> setMemberLevelPermission(String memberId, {required bool allowed}) => _setMemberLevelPermissionImpl(memberId, allowed: allowed);
  @override Future<void> setMemberKiosk(String memberId, {required bool isKiosk}) => _setMemberKioskImpl(memberId, isKiosk: isKiosk);
  @override Future<List<MemberBadge>> fetchMemberBadges(String workspaceId) => _fetchMemberBadgesImpl(workspaceId);
  @override Future<bool> badgePinNeedsReview(String workspaceId, String memberId) async =>
      await _client.rpc<bool>('badge_pin_needs_review', params: {
        'p_workspace_id': workspaceId, 'p_member_id': memberId,
      });
  @override Future<IssuedBadge> issueMemberBadge(String workspaceId, String memberId, {String label = ''}) => _issueMemberBadgeImpl(workspaceId, memberId, label: label);
  @override Future<IssuedBadge> issueMyBadge(String workspaceId, {String label = ''}) => _issueMyBadgeImpl(workspaceId, label: label);
  @override Future<void> registerMyNfcBadge(String workspaceId, {required String uid, String label = ''}) => _registerMyNfcBadgeImpl(workspaceId, uid: uid, label: label);
  @override Future<void> revokeMyBadge(String badgeId) => _revokeMyBadgeImpl(badgeId);
  @override Future<void> deleteRevokedBadge(String badgeId) => _deleteRevokedBadgeImpl(badgeId);
  @override Future<void> setCoOwner(String memberId, CoOwnerStatus status) => _setCoOwnerImpl(memberId, status);
  @override Future<void> activateCoOwner(String memberId) => _activateCoOwnerImpl(memberId);
  @override Future<void> unsetMyKiosk(String workspaceId) => _unsetMyKioskImpl(workspaceId);
  @override Future<void> registerNfcBadge(String workspaceId, String memberId, {required String uid, String label = ''}) => _registerNfcBadgeImpl(workspaceId, memberId, uid: uid, label: label);
  @override Future<void> revokeMemberBadge(String badgeId) => _revokeMemberBadgeImpl(badgeId);
  @override Future<void> updateMemberStatus(String memberId, MemberStatus status) => _updateMemberStatusImpl(memberId, status);
  @override Future<List<Member>> fetchMyMembers() => _fetchMyMembersImpl();
  @override Future<void> requestRoleChange(String workspaceId, {required String memberId, required bool makeAdmin}) => _requestRoleChangeImpl(workspaceId, memberId: memberId, makeAdmin: makeAdmin);
  @override Future<String> setWorkspaceCode(String workspaceId, String code) => _setWorkspaceCodeImpl(workspaceId, code);
  @override Future<NewMemberDefaults> fetchNewMemberDefaults(String workspaceId) => _fetchNewMemberDefaultsImpl(workspaceId);
  @override Future<void> setNewMemberDefaults(String workspaceId, NewMemberDefaults defaults) => _setNewMemberDefaultsImpl(workspaceId, defaults);
  @override Future<Map<String, dynamic>> fetchLexicon(String workspaceId) => _fetchLexiconImpl(workspaceId);
  @override Future<void> setLexiconTerm(String workspaceId, String locale, String key, String? text) => _setLexiconTermImpl(workspaceId, locale, key, text);
  @override Future<void> setWorkspaceEmblem(String workspaceId, Uint8List png) => _setWorkspaceEmblemImpl(workspaceId, png);
  @override Future<Uint8List?> fetchWorkspaceEmblem(String workspaceId) => _fetchWorkspaceEmblemImpl(workspaceId);
  @override Future<void> clearWorkspaceEmblem(String workspaceId) => _clearWorkspaceEmblemImpl(workspaceId);
  @override Future<Map<String, dynamic>> setWorkspaceBranding(String workspaceId, Map<String, dynamic> delta) => _setWorkspaceBrandingImpl(workspaceId, delta);
  @override Future<String?> fetchDefaultWorkspaceId() => _fetchDefaultWorkspaceIdImpl();
  @override Future<void> setDefaultWorkspaceId(String? workspaceId) => _setDefaultWorkspaceIdImpl(workspaceId);
  @override Future<Workspace> saveWorkspaceSettings(String workspaceId, WorkspaceSettingsSave save) => _saveWorkspaceSettingsImpl(workspaceId, save);
  @override Future<void> setDeskOpacity(String workspaceId, int opacity) => _setDeskOpacityImpl(workspaceId, opacity);
  @override Future<void> resetWorkspace(String workspaceId) => _resetWorkspaceImpl(workspaceId);

  Member _memberFromRow(Map<String, dynamic> row) => Member(
        system: SystemColumns.fromRow(row),
        id: row['id'] as String,
        workspaceId: row['workspace_id'] as String,
        // #887 — a managed member has no user yet.
        userId: row['user_id'] as String? ?? '', personId: row['person_id'] as String?,
        preferredLocaleOverride: row['preferred_locale_override'] as String?,
        isAdmin: row['is_admin'] as bool,
        isOwner: row['is_owner'] as bool,
        coOwner: CoOwnerStatus.fromWire(row['co_owner'] as String?),
        // #1148 — an unknown status reads as PAUSED: visible, never a
        // grant. A throw here emptied the whole member list.
        status: enumOr(MemberStatus.values, row['status'] as String?,
            MemberStatus.paused, area: 'members'),
        subscriptionPct: row['subscription_pct'] as int? ?? 100,
        managedIdentity: PersonalInfo.fromDb(
          (row['managed_identity'] as Map?)?.cast<String, dynamic>() ??
              const {},
        ),
        // #914/#915 — the name is a column now, and the rule rides
        // beside it; the contact fields arrive through the RPC.
        managedName: row['managed_name'] as String? ?? '',
        memberNumber: row['member_number'] as String? ?? '',
        homeSiteId: row['home_site_id'] as String?,
        managedAccess:
            (row['managed_access'] as Map?)?.cast<String, dynamic>() ??
                const {},
        paymentTerms: row['payment_terms'] is Map
            ? PaymentTerms.fromJson(row['payment_terms'] as Map)
            : null,
        claimedAt: row['claimed_at'] == null
            ? null
            : DateTime.parse(row['claimed_at'] as String),
        origin: MemberOrigin.fromDb(row['origin'] as String?),
        joinedAt: row['joined_at'] == null
            ? null
            : DateTime.parse(row['joined_at'] as String).toUtc(),
        overagePolicy:
            OveragePolicy.fromName(row['overage_policy'] as String?),
        isKiosk: row['is_kiosk'] as bool? ?? false,
        maxActiveReservations: row['max_active_reservations'] as int?,
        maxSimultaneousReservations:
            row['max_simultaneous_reservations'] as int?,
        canReserveLevel: row['can_reserve_level'] as bool? ?? false,
        vatTreatment: row['vat_treatment'] as String? ?? 'auto',
        vatExemptionReason: row['vat_exemption_reason'] as String? ?? '',
        customerCapacity: row['customer_capacity'] as String?,
        einvoiceEndpointId: JsonReader.of(row).stringOr('einvoice_endpoint_id'),
        einvoiceEndpointScheme:
            JsonReader.of(row).stringOr('einvoice_endpoint_scheme'),
        billingSubdivision: JsonReader.of(row).stringOr('billing_subdivision'),
      );
}
