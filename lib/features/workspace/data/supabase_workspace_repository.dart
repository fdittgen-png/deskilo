// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/enum_wire.dart';
import '../../../core/data/system_columns.dart';
import '../../../core/time/date_text.dart';
import '../../../core/time/work_hours.dart';
import '../../../core/validation/pending_validation.dart';
import '../../money/domain/payment_terms.dart';
import '../../profile/domain/personal_info.dart';
import '../domain/booking_granularity.dart';
import '../domain/booking_policies.dart';
import '../domain/closure_day.dart';
import '../domain/feature_flags_write.dart';
import '../domain/invitation_answer.dart';
import '../domain/managed_access.dart';
import '../domain/member.dart';
import '../domain/member_badge.dart';
import '../domain/new_member_defaults.dart';
import '../domain/overage_policy.dart';
import '../domain/payment_instructions.dart';
import '../domain/public_holidays.dart';
import '../domain/site.dart';
import '../domain/workspace.dart';
import '../domain/workspace_branding.dart';
import '../domain/workspace_document.dart';
import '../domain/workspace_feature.dart';
import '../domain/workspace_overview.dart';
import '../domain/workspace_repository.dart';
import '../domain/workspace_settings_save.dart';
import 'conversation_api.dart';
import 'supabase_workspace_provenance.dart';
import 'supabase_workspace_templates.dart';

part 'supabase_workspace_repository_part1.dart';
part 'supabase_workspace_repository_part2.dart';
part 'supabase_workspace_repository_part3.dart';
part 'supabase_workspace_repository_part4.dart';

class SupabaseWorkspaceRepository
    with ConversationApi, SupabaseWorkspaceTemplates, SupabaseWorkspaceProvenance
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
  @override Future<void> setDevMode(String workspaceId, bool enabled) => _setDevModeImpl(workspaceId, enabled);
  @override Future<List<Member>> fetchMembers(String workspaceId) => _fetchMembersImpl(workspaceId);
  @override Future<void> updateMemberSubscription(String memberId, int pct) => _updateMemberSubscriptionImpl(memberId, pct);
  @override Future<void> updateMemberOveragePolicy(String memberId, OveragePolicy policy) => _updateMemberOveragePolicyImpl(memberId, policy);
  @override Future<void> setMemberReservationLimit(String memberId, int? limit) => _setMemberReservationLimitImpl(memberId, limit);
  @override Future<void> setMemberSimultaneousLimit(String memberId, int? limit) => _setMemberSimultaneousLimitImpl(memberId, limit);
  @override Future<void> setMemberVatTreatment(String memberId, String treatment, String reason) => _setMemberVatTreatmentImpl(memberId, treatment, reason);
  @override Future<void> setMemberCustomerCapacity(String memberId, String? capacity) => _setMemberCustomerCapacityImpl(memberId, capacity);
  @override Future<void> setMemberLevelPermission(String memberId, {required bool allowed}) => _setMemberLevelPermissionImpl(memberId, allowed: allowed);
  @override Future<void> setMemberKiosk(String memberId, {required bool isKiosk}) => _setMemberKioskImpl(memberId, isKiosk: isKiosk);
  @override Future<List<MemberBadge>> fetchMemberBadges(String workspaceId) => _fetchMemberBadgesImpl(workspaceId);
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
  @override Future<List<int>> fetchOpenWeekdays(String workspaceId) => _fetchOpenWeekdaysImpl(workspaceId);
  @override Future<void> setOpenWeekdays(String workspaceId, List<int> weekdays) => _setOpenWeekdaysImpl(workspaceId, weekdays);
  @override Future<String?> fetchDefaultPeriod(String workspaceId) => _fetchDefaultPeriodImpl(workspaceId);
  @override Future<void> setDefaultPeriod(String workspaceId, String? wire) => _setDefaultPeriodImpl(workspaceId, wire);
  @override Future<BookingGranularity> fetchBookingGranularity(String workspaceId) => _fetchBookingGranularityImpl(workspaceId);
  @override Future<void> setBookingGranularity(String workspaceId, BookingGranularity granularity) => _setBookingGranularityImpl(workspaceId, granularity);
  @override Future<WorkHours> fetchWorkHours(String workspaceId) => _fetchWorkHoursImpl(workspaceId);
  @override Future<BookingPolicies> fetchBookingPolicies(String workspaceId) => _fetchBookingPoliciesImpl(workspaceId);
  @override Future<NewMemberDefaults> fetchNewMemberDefaults(String workspaceId) => _fetchNewMemberDefaultsImpl(workspaceId);
  @override Future<void> setNewMemberDefaults(String workspaceId, NewMemberDefaults defaults) => _setNewMemberDefaultsImpl(workspaceId, defaults);
  @override Future<Map<String, dynamic>> fetchLexicon(String workspaceId) => _fetchLexiconImpl(workspaceId);
  @override Future<void> setLexiconTerm(String workspaceId, String locale, String key, String? text) => _setLexiconTermImpl(workspaceId, locale, key, text);
  @override Future<void> setWorkspaceEmblem(String workspaceId, Uint8List png) => _setWorkspaceEmblemImpl(workspaceId, png);
  @override Future<Uint8List?> fetchWorkspaceEmblem(String workspaceId) => _fetchWorkspaceEmblemImpl(workspaceId);
  @override Future<void> clearWorkspaceEmblem(String workspaceId) => _clearWorkspaceEmblemImpl(workspaceId);
  @override Future<Map<String, dynamic>> setWorkspaceBranding(String workspaceId, Map<String, dynamic> delta) => _setWorkspaceBrandingImpl(workspaceId, delta);
  @override Future<void> setBookingPolicy(String workspaceId, String key, {required bool enabled}) => _setBookingPolicyImpl(workspaceId, key, enabled: enabled);
  @override Future<void> setLegendProfile(String workspaceId, LegendProfile profile) => _setLegendProfileImpl(workspaceId, profile);
  @override Future<void> setOutsideHoursMode(String workspaceId, OutsideHoursMode mode) => _setOutsideHoursModeImpl(workspaceId, mode);
  @override Future<void> setSimultaneousReservations(String workspaceId, int value) => _setSimultaneousReservationsImpl(workspaceId, value);
  @override Future<void> setBookingLimit(String workspaceId, String key, int value) => _setBookingLimitImpl(workspaceId, key, value);
  @override Future<void> setWorkHours(String workspaceId, WorkHours hours) => _setWorkHoursImpl(workspaceId, hours);
  @override Future<String?> fetchDefaultWorkspaceId() => _fetchDefaultWorkspaceIdImpl();
  @override Future<void> setDefaultWorkspaceId(String? workspaceId) => _setDefaultWorkspaceIdImpl(workspaceId);
  @override Future<List<ClosureDay>> fetchClosureDays(String workspaceId) => _fetchClosureDaysImpl(workspaceId);
  @override Future<HolidayGeneration> generateClosureDays(String workspaceId, {required String country, required int year, bool apply = false}) => _generateClosureDaysImpl(workspaceId, country: country, year: year, apply: apply);
  @override Future<HolidayGeneration> importClosureDays(String workspaceId, {required List<({DateTime day, String name})> days, bool apply = false}) => _importClosureDaysImpl(workspaceId, days: days, apply: apply);
  @override Future<ClosureDay> addClosureDay(String workspaceId, DateTime day, String reason) => _addClosureDayImpl(workspaceId, day, reason);
  @override Future<void> removeClosureDay(String closureDayId) => _removeClosureDayImpl(closureDayId);
  @override Future<Workspace> saveWorkspaceSettings(String workspaceId, WorkspaceSettingsSave save) => _saveWorkspaceSettingsImpl(workspaceId, save);
  @override Future<void> setDeskOpacity(String workspaceId, int opacity) => _setDeskOpacityImpl(workspaceId, opacity);
  @override Future<void> resetWorkspace(String workspaceId) => _resetWorkspaceImpl(workspaceId);

}
