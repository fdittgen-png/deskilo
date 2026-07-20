// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final enabled = ref.watch(enabledFeaturesSyncProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n?.featuresTitle ?? 'Features')),
      body: workspace == null
          ? const LoadingView()
          : ListView(
              children: [
                for (final entry in featureManifest.values)
                  SwitchListTile(
                    title: Text(_name(l10n, entry.feature)),
                    subtitle: Text(_description(l10n, entry.feature)),
                    value: enabled.contains(entry.feature),
                    onChanged: (value) => _toggle(
                      context,
                      ref,
                      workspace,
                      enabled,
                      entry.feature,
                      value,
                    ),
                  ),
              ],
            ),
    );
  }
}
