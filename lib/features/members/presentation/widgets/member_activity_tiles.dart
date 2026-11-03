// SPDX-License-Identifier: AGPL-3.0-or-later
// #2494 — the money, booking, customer and billing rows and the quick actions
// of the member profile. Split out of member_page (was a part file).
import 'package:flutter/material.dart';
import '../../../../core/vat/vat_treatment.dart';
import '../../../money/presentation/widgets/consumption_sheet.dart';
import '../../../money/presentation/widgets/member_billing_tiles.dart';
import '../../../money/presentation/widgets/negotiation_card.dart';
import '../../../workspace/domain/booking_policies.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/overage_policy.dart';
import '../../../workspace/domain/site.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/presentation/member_admin_actions.dart';
import '../../../workspace/presentation/member_customer_capacity.dart';
import '../../../workspace/presentation/member_einvoice_address_tile.dart';
import '../../../workspace/presentation/member_vat_treatment.dart';
import '../../../workspace/presentation/widgets/open_conversation.dart';
import '../../../workspace/providers/workspace_providers.dart';
import 'member_admin_tiles.dart';
import 'member_page_context.dart';

List<Widget> memberMoneyTiles(
  Member m,
  Set<WorkspaceFeature> f,
  Set<WorkspacePermission> p,
) => [
  // carnets, VIES, certificates
  if (f.contains(WorkspaceFeature.carnets) && !m.isKiosk)
    MemberCarnetTile(
      memberId: m.id,
      canSell: p.contains(WorkspacePermission.issueInvoices),
    ), // #1279
  if (f.contains(WorkspaceFeature.viesVerification) &&
      !m.isKiosk &&
      p.contains(WorkspacePermission.issueInvoices))
    ViesCheckTile(workspaceId: m.workspaceId, memberId: m.id), // #2354
  if (f.contains(WorkspaceFeature.salesTax) &&
      !m.isKiosk &&
      p.contains(WorkspacePermission.manageBilling))
    MemberTaxCertificatesTile(
      workspaceId: m.workspaceId,
      memberId: m.id,
      canManage: true,
    ), // #2362
];
List<Widget> memberQuickActions(MemberPageContext c) {
  final context = c.context;
  final ref = c.ref;
  final member = c.member;
  final name = c.name;
  final l10n = c.l10n;
  final perms = c.perms;
  final email = c.email;
  final isSelf = c.isSelf;
  final active = c.active;
  final canAdmin = c.canAdmin;
  final whatsappUri = c.whatsappUri;
  final canMessage = c.canMessage;
  final servicesOn = c.servicesOn;
  final reportsOn = c.reportsOn;
  return <Widget>[
    if (canMessage)
      FilledButton.tonalIcon(
        key: const ValueKey('member-page-action-message'),
        icon: const Icon(Icons.chat_bubble_outline),
        label: Text(l10n.memberMessagesAction),
        onPressed: () =>
            openDirectConversation(context, ref, memberId: member.id),
      ),
    if (whatsappUri != null)
      FilledButton.tonalIcon(
        key: const ValueKey('member-page-action-wa'),
        icon: const Icon(Icons.chat_outlined),
        label: Text(l10n.directoryWhatsapp),
        onPressed: () => c.launch(whatsappUri),
      ),
    if (email.isNotEmpty && !isSelf)
      FilledButton.tonalIcon(
        key: const ValueKey('member-page-action-email'),
        icon: const Icon(Icons.mail_outline),
        label: Text(l10n.memberPageEmailAction),
        onPressed: () =>
            c.launch(Uri(scheme: 'mailto', path: email)),
      ),
    // #2137 — record_service_charge accepts manageServices too.
    if (servicesOn &&
        (canAdmin || perms.contains(WorkspacePermission.manageServices)) &&
        !member.isKiosk &&
        active)
      FilledButton.tonalIcon(
        key: const ValueKey('member-page-action-service'),
        icon: const Icon(Icons.room_service_outlined),
        label: Text(l10n.memberPageAddService),
        onPressed: () => showConsumptionSheet(
          context,
          ref,
          subjectMemberId: member.id,
          subjectName: name,
        ),
      ),
    if (reportsOn && canAdmin && !member.isKiosk && active)
      FilledButton.tonalIcon(
        key: const ValueKey('member-page-action-agreement'),
        icon: const Icon(Icons.handshake_outlined),
        label: Text(l10n.memberSendAgreement),
        onPressed: () => sendMemberAgreement(context, ref, member, name),
      ),
  ];
}

List<Widget> memberBookingTiles(MemberPageContext c) {
  final context = c.context;
  final ref = c.ref;
  final member = c.member;
  final l10n = c.l10n;
  final perms = c.perms;
  final policies = c.policies;
  final isSelf = c.isSelf;
  final active = c.active;
  final canAdmin = c.canAdmin;
  final levelOn = c.levelOn;
  return <Widget>[
    // #2137 — the booking allowances are also manageReservations'.
    if ((canAdmin || perms.contains(WorkspacePermission.manageReservations)) &&
        !isSelf &&
        !member.isKiosk &&
        active) ...[
      MemberManageTile(
        tileKey: const ValueKey('member-page-reservation-limit'),
        icon: Icons.stacked_bar_chart_outlined,
        title: l10n.memberReservationLimitLabel,
        subtitle: member.maxActiveReservations == null
            ? (l10n.memberReservationLimitNone)
            : '${member.maxActiveReservations}',
        onTap: () => pickMemberReservationLimit(context, ref, member),
      ),
      MemberManageTile(
        tileKey: const ValueKey('member-page-simultaneous'),
        icon: Icons.splitscreen_outlined,
        title: l10n.memberSimultaneousLimitLabel,
        subtitle: member.maxSimultaneousReservations == null
            ? (l10n.memberPageWorkspaceDefaultValue(
                BookingPolicies.allowanceFor(null, policies),
              ))
            : '${member.maxSimultaneousReservations}',
        onTap: () => pickMemberSimultaneousLimit(context, ref, member),
      ),
      ...memberCustomerTiles(c),
      if (levelOn)
        SwitchListTile(
          key: const ValueKey('member-page-level'),
          secondary: Icon(
            member.canReserveLevel ? Icons.layers : Icons.layers_outlined,
          ),
          title: Text(l10n.memberPageLevelTitle),
          subtitle: Text(
            member.canReserveLevel
                ? (l10n.levelPermissionAllowed)
                : (l10n.levelPermissionDenied),
          ),
          value: member.canReserveLevel,
          onChanged: (_) => toggleMemberLevelPermission(context, ref, member),
        ),
    ],
  ];
}

/// Who the member is as a customer: VAT treatment, business or consumer,

/// Who the member is as a customer: VAT treatment, business or consumer,
/// e-invoice address and the site their documents carry.
List<Widget> memberCustomerTiles(MemberPageContext c) {
  final invoicer = c.perms.contains(WorkspacePermission.issueInvoices) &&
      c.features.contains(WorkspaceFeature.invoicing);
  return <Widget>[
    // #985 — who this member is for VAT.
    if (c.canAdmin && c.features.contains(WorkspaceFeature.vatCounterparty))
      MemberManageTile(
        tileKey: const ValueKey('member-page-vat-treatment'),
        icon: Icons.account_balance_outlined,
        title: c.l10n.memberVatTreatmentLabel,
        subtitle: vatTreatmentName(
          c.l10n,
          VatTreatment.fromWire(c.member.vatTreatment),
        ),
        onTap: () => pickMemberVatTreatment(c.context, c.ref, c.member),
      ),
    // #1916 — whether this customer acts as a business or a consumer.
    if (invoicer)
      MemberManageTile(
        tileKey: const ValueKey('member-page-customer-capacity'),
        icon: Icons.storefront_outlined,
        title: c.l10n.customerCapacityLabel,
        subtitle: customerCapacityName(c.l10n, c.member.customerCapacity),
        onTap: () => pickMemberCustomerCapacity(c.context, c.ref, c.member),
      ),
    // #2358 — where this customer receives e-invoices.
    if (invoicer)
      MemberEInvoiceAddressTile(member: c.member),
    // #945 — the site whose address this member's documents carry.
    if (c.canAdmin && c.features.contains(WorkspaceFeature.multiSite))
      MemberManageTile(
        tileKey: const ValueKey('member-page-home-site'),
        icon: Icons.location_city_outlined,
        title: c.l10n.memberHomeSiteLabel,
        subtitle:
            (c.ref.watch(sitesProvider).value ?? const <Site>[])
                .where(
                  (s) => c.member.homeSiteId == null
                      ? s.isDefault
                      : s.id == c.member.homeSiteId,
                )
                .map((s) => s.name)
                .firstOrNull ??
            (c.l10n.memberHomeSiteDefault),
        onTap: () => pickMemberHomeSite(c.context, c.ref, c.member),
      ),
  ];
}

List<Widget> memberBillingTiles(MemberPageContext c) {
  final context = c.context;
  final ref = c.ref;
  final member = c.member;
  final name = c.name;
  final l10n = c.l10n;
  final features = c.features;
  final perms = c.perms;
  final active = c.active;
  final isOwner = c.isOwner;
  final negotiationVisible = c.negotiationVisible;
  return <Widget>[
    ...memberMoneyTiles(member, features, perms),
    if (isOwner && !member.isKiosk)
      MemberManageTile(
        tileKey: const ValueKey('member-page-subscription'),
        icon: Icons.percent,
        title: l10n.memberSubscriptionLabel,
        subtitle: subscriptionText(l10n, member.subscriptionPct),
        onTap: () => pickMemberSubscription(context, ref, member),
      ),
    if (isOwner && !member.isKiosk && active)
      MemberManageTile(
        tileKey: const ValueKey('member-page-overage'),
        icon: member.overagePolicy == OveragePolicy.blocked
            ? Icons.speed_outlined
            : Icons.speed,
        title: l10n.memberOveragePolicyLabel,
        subtitle: switch (member.overagePolicy) {
          OveragePolicy.blocked => l10n.overagePolicyBlocked,
          OveragePolicy.payg => l10n.overagePolicyPayg,
          OveragePolicy.package => l10n.overagePolicyPackage,
        },
        onTap: () => pickMemberOveragePolicy(context, ref, member),
      ),
    if (negotiationVisible && !member.isKiosk && active)
      MemberNegotiationTile(
        memberId: member.id,
        memberName: name,
        isOwner: isOwner,
      ),
  ];
}
