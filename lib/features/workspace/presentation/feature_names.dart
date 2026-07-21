// SPDX-License-Identifier: MIT
import '../../../l10n/app_localizations.dart';
import '../domain/workspace_feature.dart';

/// Localized display name for a [WorkspaceFeature] (#146) — shared by the
/// owner Features screen and the configuration-PDF export so both read
/// from one source of truth.
String featureName(AppLocalizations? l10n, WorkspaceFeature feature) =>
    switch (feature) {
      WorkspaceFeature.calendarTab => l10n?.featureCalendarTab ?? 'Calendar tab',
      WorkspaceFeature.eventsTab => l10n?.featureEventsTab ?? 'Events tab',
      WorkspaceFeature.moneyTab => l10n?.featureMoneyTab ?? 'Money tab',
      WorkspaceFeature.services => l10n?.featureServices ?? 'Services',
      WorkspaceFeature.pdfExport => l10n?.featurePdfExport ?? 'PDF export',
      WorkspaceFeature.seriesBooking =>
        l10n?.featureSeriesBooking ?? 'Series booking',
      WorkspaceFeature.bookForOthers =>
        l10n?.featureBookForOthers ?? 'Book for others',
      WorkspaceFeature.pushNotifications =>
        l10n?.featurePushNotifications ?? 'Push notifications',
      WorkspaceFeature.adminSeatBlocking =>
        l10n?.featureAdminSeatBlocking ?? 'Admins can block seats',
      WorkspaceFeature.accessorySupplements =>
        l10n?.featureAccessorySupplements ?? 'Accessory supplements',
      WorkspaceFeature.onlinePayments =>
        l10n?.featureOnlinePayments ?? 'Online payments',
      WorkspaceFeature.nfcBadges =>
        l10n?.featureNfcBadges ?? 'RFID / NFC badges',
    };
