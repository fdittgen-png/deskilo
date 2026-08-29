// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_hint.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import '../feature_names.dart';

/// Owner-only feature management (#146): one switch per registry feature.
/// Toggling writes the full flags map to the workspace row (owner RLS)
/// and invalidates the workspace chain so the gates apply immediately —
/// other members pick the flags up on their next connect/refetch.
class FeaturesScreen extends ConsumerWidget {
  const FeaturesScreen({super.key});

  String _name(AppLocalizations? l10n, WorkspaceFeature feature) =>
      featureName(l10n, feature);

  String _description(AppLocalizations? l10n, WorkspaceFeature feature) =>
      switch (feature) {
        WorkspaceFeature.calendarTab => l10n?.featureCalendarTabDesc ??
            'Monthly overview of bookings and closures.',
        WorkspaceFeature.eventsTab => l10n?.featureEventsTabDesc ??
            'Activity feed and pending confirmations.',
        WorkspaceFeature.moneyTab => l10n?.featureMoneyTabDesc ??
            'Bills, payments, expenses and consumptions.',
        WorkspaceFeature.services => l10n?.featureServicesDesc ??
            'Service catalog and consumption tracking.',
        WorkspaceFeature.pdfExport => l10n?.featurePdfExportDesc ??
            'Export the monthly bill as a PDF.',
        WorkspaceFeature.seriesBooking => l10n?.featureSeriesBookingDesc ??
            'Repeat a reservation daily, weekly or on weekdays.',
        WorkspaceFeature.bookForOthers => l10n?.featureBookForOthersDesc ??
            'Admins and owners book seats for other members.',
        WorkspaceFeature.pushNotifications =>
          l10n?.featurePushNotificationsDesc ??
              'Deliver pending confirmations to members\' devices.',
        WorkspaceFeature.adminSeatBlocking =>
          l10n?.featureAdminSeatBlockingDesc ??
              'Admins mark seats not reservable for maintenance. '
                  'The owner always can.',
        WorkspaceFeature.accessorySupplements =>
          l10n?.featureAccessorySupplementsDesc ??
              'Bill priced seat accessories per booked half-day. '
                  'Applies to bookings from activation on.',
        WorkspaceFeature.onlinePayments =>
          l10n?.featureOnlinePaymentsDesc ??
              'Let members pay their bill online (PayPal). Needs the '
                  'payment provider configured on the server.',
        WorkspaceFeature.kioskMode =>
          l10n?.featureKioskModeDesc ??
              'Wall-tablet accounts locked to the live plan; members act '
                  'through badges.',
        WorkspaceFeature.nfcBadges =>
          l10n?.featureNfcBadgesDesc ??
              'Members check in at a kiosk by tapping an RFID/NFC card. '
                  'Needs an Android device with NFC.',
        WorkspaceFeature.levelBooking =>
          l10n?.featureLevelBookingDesc ??
              'Reserve a whole floor as one booking, priced per '
                  'half-day. Grant members the right per member.',
        WorkspaceFeature.membersDirectory =>
          l10n?.featureMembersDirectoryDesc ??
              'The community tab: who is here, statuses, presence.',
        WorkspaceFeature.whatsappIntegration =>
          l10n?.featureWhatsappIntegrationDesc ??
              'Message members on WhatsApp and link the community group.',
        WorkspaceFeature.spaceQrCodes =>
          l10n?.featureSpaceQrCodesDesc ??
              'Printable QR cards per seat, desk, office and level — '
                  'scan to reserve or check in.',
        WorkspaceFeature.coOwner =>
          l10n?.featureCoOwnerDesc ??
              'Appoint co-owners: owner permissions now (active) or '
                  'succession-in-waiting (passive).',
        WorkspaceFeature.invoicing =>
          l10n?.featureInvoicingDesc ??
              'Immutable, signed invoices in an archive — download or '
                  'share as PDF.',
        WorkspaceFeature.adminInvoicing =>
          l10n?.featureAdminInvoicingDesc ??
              'Admins issue invoices too. The owner always can.',
        WorkspaceFeature.autoCheckInOut =>
          l10n?.featureAutoCheckInOutDesc ??
              'Reservations never checked in or out complete themselves '
                  'once their time has passed.',
        WorkspaceFeature.dataExport =>
          l10n?.featureDataExportDesc ??
              'Download all workspace data as an Excel workbook.',
        WorkspaceFeature.adminLevelAssign =>
          l10n?.featureAdminLevelAssignDesc ??
              'Admins assign level reservations to members. '
                  'The owner always can.',
        WorkspaceFeature.workingHours =>
          l10n?.featureWorkingHoursDesc ??
              'Configure the working day and offer exact-hours booking; '
                  'off keeps the 8:00–17:00 defaults.',
        WorkspaceFeature.invoicePdfTemplate =>
          l10n?.featureInvoicePdfTemplateDesc ??
              'Owner-written intro and footer text on the invoice PDF. '
                  'Never touches the e-invoice XML.',
        WorkspaceFeature.memberNotifications =>
          l10n?.featureMemberNotificationsDesc ??
              'Send a short notification to another member; admins can '
                  'notify all admins including the owner.',
        WorkspaceFeature.documents => l10n?.featureDocumentsDesc ??
            'The workspace document library: statutes, guides, '
                'financial statements, minutes — linked from any drive, '
                'visible per role.',
        WorkspaceFeature.dunning => l10n?.featureDunningDesc ??
            'Configurable reminder rules and "Reminder due" '
                'suggestions on overdue invoices. Nothing is ever sent '
                'automatically.',
        WorkspaceFeature.memberReports =>
          l10n?.featureMemberReportsDesc ??
              'The financial agreement and the monthly payments report '
                  '— self-service for members, sendable per member.',
        WorkspaceFeature.deletionRequests =>
          l10n?.featureDeletionRequestsDesc ??
              'Members may REQUEST deletion of a past or checked-in '
                  'booking; an owner/admin validates. Off, such '
                  'bookings cannot be deleted at all.',
        WorkspaceFeature.roleManagement =>
          l10n?.featureRoleManagementDesc ??
              'The central role→permission matrix: the owner decides '
                  'which role holds which permission; everyone else '
                  'reads their own. Off, the defaults simply apply.',
        WorkspaceFeature.vatManagement =>
          l10n?.featureVatManagementDesc ??
              'The VAT rate editor and the rate pickers on services, '
                  'packs, accessories and the tariff. Off hides the '
                  'configuration; stored rates keep applying.',
        WorkspaceFeature.vatDeclarations =>
          l10n?.featureVatDeclarationsDesc ??
              'Generate the periodic VAT return from issued invoices, '
                  'map it to the official form and transmit or export '
                  'it.',
        WorkspaceFeature.einvoiceCustomerDelivery =>
          l10n?.featureEinvoiceCustomerDeliveryDesc ??
              "A second sending channel beside the government platform: "
                  "post the issued invoice straight to the customer's "
                  "own e-invoicing service.",
        WorkspaceFeature.planObjectDelete =>
          l10n?.featurePlanObjectDeleteDesc ??
              'Owners may delete levels, offices, desks and seats even '
                  'when past reservations reference them — the bookings '
                  'keep a text snapshot for audits and reports.',
        WorkspaceFeature.notificationGrouping =>
          l10n?.featureNotificationGroupingDesc ??
              'Members may fold the notification feed into groups by '
                  'type, day or member; tapping the group symbol '
                  'returns to the flat list.',
        WorkspaceFeature.bookingPolicies =>
          l10n?.featureBookingPoliciesDesc ??
              'Owner-configurable booking behavior: past bookings, '
                  'minute bookings outside the working hours, and '
                  'check-out by admins.',
        WorkspaceFeature.nfcSeatTags =>
          l10n?.featureNfcSeatTagsDesc ??
              'A physical NFC/RFID tag on a chair resolves to its seat '
                  'like the printed QR card; owners fill the tag field '
                  'by tapping the chip.',
        WorkspaceFeature.qrBadges =>
          l10n?.featureQrBadgesDesc ??
              'Printable QR badge cards for the kiosk, beside the '
                  'NFC/RFID cards.',
        WorkspaceFeature.formHelpHints =>
          l10n?.featureFormHelpHintsDesc ??
              'Short dismissible how-to hints on forms and screens, '
                  'each linking into the matching guide section.',
        WorkspaceFeature.uiAnimations =>
          l10n?.featureUiAnimationsDesc ??
              'Smooth transitions and state animations across the app. '
                  'Off means every change is instant; the device\'s '
                  'reduced-motion setting always wins.',
        WorkspaceFeature.kioskMemberPhotos =>
          l10n?.featureKioskMemberPhotosDesc ??
              "The kiosk receipt shows the member's profile photo — the "
                  'visual wrong-badge check.',
        WorkspaceFeature.planMemberPhotos =>
          l10n?.featurePlanMemberPhotosDesc ??
              'Occupied seats on the Plan tab and Reserve hub show the '
                  "occupant's profile photo instead of the initial.",
        WorkspaceFeature.regionalFormats =>
          l10n?.featureRegionalFormatsDesc ??
              'Members choose how numbers, dates, the clock and the time '
                  'zone are shown to them. Off: everyone reads in the app '
                  "language's home region, 24-hour, workspace time.",
        WorkspaceFeature.calendarHub =>
          l10n?.featureCalendarHubDesc ??
              'The calendar shows everything dated — bookings, check-ins, alerts, messages, invoices, payments, consumption, reminders — for a day or a range, each row opening its source. Off: reservations only.',
        WorkspaceFeature.financeFaces =>
          l10n?.featureFinanceFacesDesc ??
              'The Finances tab shows three faces — Payments, Consumption, Invoices — under one month chooser, each with its own help. Off: one column.',
        WorkspaceFeature.paymentReminders =>
          l10n?.featurePaymentRemindersDesc ??
              'Open invoices past the configured term get their reminder levels automatically — an alert in the member\'s feed and a push, once a day. Off: reminders stay a manual action.',
        WorkspaceFeature.supplyExpenses =>
          l10n?.featureSupplyExpensesDesc ??
              'An expense can be a supply for the space (coffee capsules, vacuum bags…): once validated it restocks or creates a consumable service with a unit price, and consumptions count the stock down.',
        WorkspaceFeature.validationScopes =>
          l10n?.featureValidationScopesDesc ??
              'Each validation rule names who validates: the admins, listed persons of any role, or every member — plus how many. Off: owner and admins as before.',
        WorkspaceFeature.dataAccessLog =>
          l10n?.featureDataAccessLogDesc ??
              'Members see who looked at their finances and when (written by the server, never skippable). Off hides the row; the log is still kept.',
        WorkspaceFeature.memberDataExport =>
          l10n?.featureMemberDataExportDesc ??
              'Every member can export their data as one file (GDPR art. 20) and leave the workspace with their personal data cleared (art. 17) from Settings → Privacy & data.',
        WorkspaceFeature.badgeSignIn =>
          l10n?.featureBadgeSignInDesc ??
              'Members can sign in by scanning their badge and entering '
                  'their PIN, instead of typing an e-mail on a shared '
                  'tablet. Each member sets their own PIN and arms their '
                  'own badge.',
      };

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Workspace workspace,
    Set<WorkspaceFeature> enabled,
    WorkspaceFeature feature,
    bool value,
  ) async {
    final l10n = AppLocalizations.of(context);
    // Always write the FULL map so the row is self-describing and a later
    // registry-default change never silently flips an owner's choice.
    final flags = {
      for (final f in featureManifest.keys)
        f.dbKey: f == feature ? value : enabled.contains(f),
    };
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'set feature flags failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
          await ref
              .read(workspaceRepositoryProvider)
              .setFeatureFlags(workspace.id, flags);
      },
    )) {
      return;
    }
    // The workspace chain re-derives enabledFeatures from the new row —
    // that applies the gates locally right away.
    ref.invalidate(myWorkspacesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    // The RAW stored set, not the effective one: a child's saved choice
    // must survive its parent being switched off (and its switch must
    // show that saved choice, greyed out).
    final raw = workspace == null
        ? const <WorkspaceFeature>{}
        : resolveEnabledFeatures(workspace.featureFlags);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.featuresTitle ?? 'Features')),
      body: workspace == null
          ? const LoadingView()
          : ListView(
              children: [
                // #606 — contextual how-to; gated inside the widget.
                const HelpHint(HelpHintId.features),
                for (final entry in featureManifest.values)
                  _FeatureTile(
                    entry: entry,
                    name: _name(l10n, entry.feature),
                    description: _description(l10n, entry.feature),
                    requiresLabel: entry.requires == null
                        ? null
                        : (l10n?.featureRequires(
                                featureName(l10n, entry.requires!)) ??
                            'Requires ${featureName(l10n, entry.requires!)}'),
                    value: raw.contains(entry.feature),
                    // A child is only editable while its parent chain is
                    // ON — the hierarchy made visible.
                    parentOn: entry.requires == null ||
                        effectiveFeatures(raw).contains(entry.requires),
                    onChanged: (value) => _toggle(
                      context,
                      ref,
                      workspace,
                      raw,
                      entry.feature,
                      value,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// One feature row: children indent under their parent, carry the
/// "Requires X" note, and grey out while the parent (chain) is off.
class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.entry,
    required this.name,
    required this.description,
    required this.requiresLabel,
    required this.value,
    required this.parentOn,
    required this.onChanged,
  });

  final FeatureManifestEntry entry;
  final String name;
  final String description;
  final String? requiresLabel;
  final bool value;
  final bool parentOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final child = entry.requires != null;
    return Padding(
      padding: EdgeInsets.only(left: child ? 24 : 0),
      child: SwitchListTile(
        key: ValueKey('feature-${entry.feature.name}'),
        title: Text(name),
        subtitle: Text(
          requiresLabel == null
              ? description
              : '$description\n$requiresLabel',
        ),
        value: value,
        onChanged: parentOn ? onChanged : null,
      ),
    );
  }
}
