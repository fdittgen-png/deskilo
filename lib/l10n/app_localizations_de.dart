// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get accessoriesTitle => 'Zubehör';

  @override
  String get accessoriesEmpty => 'Noch kein Zubehör.';

  @override
  String get accessoriesNew => 'Neues Zubehör';

  @override
  String get accessoriesEdit => 'Zubehör bearbeiten';

  @override
  String get accessoriesName => 'Name';

  @override
  String get accessoriesSupplement => 'Aufpreis pro halbem Tag';

  @override
  String accessoriesPerHalfDay(String amount) {
    return '$amount / halber Tag';
  }

  @override
  String get accessoriesNoSupplement => 'Kein Aufpreis';

  @override
  String get accessoriesInactive => 'Inaktiv';

  @override
  String get accessoriesActive => 'Aktiv';

  @override
  String get authSignInTitle => 'Anmelden';

  @override
  String get authSignUpTitle => 'Konto erstellen';

  @override
  String get authEmailLabel => 'E-Mail';

  @override
  String get authPasswordLabel => 'Passwort';

  @override
  String get authShowPassword => 'Passwort anzeigen';

  @override
  String get authHidePassword => 'Passwort verbergen';

  @override
  String get authDisplayNameLabel => 'Anzeigename';

  @override
  String get authForgotPassword => 'Passwort vergessen?';

  @override
  String get authResetTitle => 'Passwort zurücksetzen';

  @override
  String get authResetExplainer =>
      'Wir senden dir einen Einmal-Code per E-Mail. Setze damit hier ein neues Passwort.';

  @override
  String get authResetSendCode => 'Code senden';

  @override
  String get authResetCodeSent => 'Code gesendet — prüfe deine E-Mails.';

  @override
  String get authResetCodeLabel => 'Code aus der E-Mail';

  @override
  String get authResetNewPasswordLabel => 'Neues Passwort';

  @override
  String get authResetSubmit => 'Neues Passwort setzen';

  @override
  String get authResetDone => 'Passwort aktualisiert — du bist angemeldet.';

  @override
  String get authResetInvalidCode =>
      'Dieser Code ist ungültig oder abgelaufen.';

  @override
  String get authSignInButton => 'Anmelden';

  @override
  String get authSignUpButton => 'Konto erstellen';

  @override
  String get authToggleToSignUp => 'Neu hier? Konto erstellen';

  @override
  String get authToggleToSignIn => 'Schon ein Konto? Anmelden';

  @override
  String get authFieldRequired => 'Pflichtfeld';

  @override
  String get authPasswordTooShort => 'Mindestens 8 Zeichen';

  @override
  String get authGenericError =>
      'Anmeldung fehlgeschlagen. Bitte Zugangsdaten prüfen und erneut versuchen.';

  @override
  String get authSignOut => 'Abmelden';

  @override
  String get authNetworkError =>
      'Server nicht erreichbar. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String get availabilityTitle => 'Verfügbarkeit';

  @override
  String get availabilityOpenWeekdays => 'Geöffnete Wochentage';

  @override
  String get availabilityClosureDays => 'Schließtage';

  @override
  String get availabilityAddClosure => 'Schließtag hinzufügen';

  @override
  String get availabilityClosureReason => 'Grund (optional)';

  @override
  String get availabilityLastOpenDay =>
      'Mindestens ein Wochentag muss geöffnet bleiben.';

  @override
  String get availabilityNoClosures => 'Keine Schließtage.';

  @override
  String get availabilityGranularityTitle => 'Buchungsraster';

  @override
  String get availabilityGranularityDescription =>
      'Halbe Tage: Buchungen umfassen den Vormittag (bis 13 Uhr), den Nachmittag (ab 13 Uhr) oder den ganzen Tag.';

  @override
  String get availabilityGranularityFlexible => 'Freier Zeitraum';

  @override
  String get availabilityGranularityHalfDay =>
      'Halbe Tage (Vormittag & Nachmittag)';

  @override
  String get availabilityGranularity5 => '5-Minuten-Slots';

  @override
  String get availabilityGranularity15 => '15-Minuten-Slots';

  @override
  String get availabilityGranularity30 => '30-Minuten-Slots';

  @override
  String get availabilityGranularity60 => '1-Stunden-Slots';

  @override
  String get availabilityGranularityFullDay => 'Nur ganze Tage';

  @override
  String planSlotError(int minutes) {
    return 'Buchungen müssen im $minutes-Minuten-Raster beginnen und enden.';
  }

  @override
  String get planFullDayError => 'Buchungen umfassen hier den ganzen Tag.';

  @override
  String billSubscription(int pct) {
    return 'Abo $pct %';
  }

  @override
  String billEntitlement(int used, int included, int openDays) {
    return '$used von $included halben Tagen genutzt ($openDays Öffnungstage)';
  }

  @override
  String billOverage(int extra) {
    return '$extra zusätzliche halbe Tage';
  }

  @override
  String get billServices => 'Bezogene Leistungen';

  @override
  String get billServicesTotal => 'Summe Leistungen';

  @override
  String get billOpenPositions => 'Offene Posten';

  @override
  String get billPendingBadge => 'Bestätigung ausstehend';

  @override
  String get billPaymentsCredits => 'Zahlungen & Gutschriften';

  @override
  String get billBalance => 'Saldo';

  @override
  String get billSettled => 'Beglichen';

  @override
  String get billOutstanding => 'Offen';

  @override
  String get billAccessorySupplements => 'Zubehör-Aufpreise';

  @override
  String get entitlementTitle => 'Diesen Monat';

  @override
  String entitlementDaysUsed(String used, String total) {
    return '$used von $total Tagen genutzt';
  }

  @override
  String entitlementDaysLeft(String left) {
    return 'Noch $left Tage';
  }

  @override
  String get entitlementBlockedFull =>
      'Du hast diesen Monat alle Tage aufgebraucht. Bitte eine Administratorin um mehr oder beantrage unten zusätzliche Halbtage.';

  @override
  String entitlementPaygRate(String rate) {
    return 'Tage über deinen Tarif hinaus kosten je $rate.';
  }

  @override
  String get entitlementPackageFull =>
      'Du hast diesen Monat alle Tage aufgebraucht. Kaufe ein Paket, um weiter zu buchen.';

  @override
  String get billPackages => 'Tagespakete';

  @override
  String get payOnlineButton => 'Online bezahlen';

  @override
  String get payOnlineNotConfigured =>
      'Online-Zahlungen sind noch nicht eingerichtet. Frag die Workspace-Inhaberin.';

  @override
  String get payOnlineChooseTitle => 'Online bezahlen';

  @override
  String get paymentProviderStripe => 'Kreditkarte (Stripe)';

  @override
  String get paymentProviderMollie => 'Mollie — iDEAL, Bancontact…';

  @override
  String get payOnlineDiagTitle => 'Online-Zahlungen — nicht konfiguriert';

  @override
  String get payOnlineDiagHint =>
      'Auf dem Server fehlt diese Konfiguration (docs/design/payments-integration.md):';

  @override
  String get billPdfTitle => 'Monatsrechnung';

  @override
  String get billPdfExport => 'Rechnung als PDF exportieren';

  @override
  String get billingTitle => 'Abrechnung';

  @override
  String get billingFeeBands => 'Gebührenbänder';

  @override
  String billingBandFrom(int from) {
    return 'ab $from %';
  }

  @override
  String get billingBandTo => 'Bis %';

  @override
  String get billingBandFee => 'Monatsgebühr';

  @override
  String get billingBandOverage => 'Mehrverbrauch';

  @override
  String get billingAddBand => 'Band hinzufügen';

  @override
  String get billingRemoveBand => 'Band entfernen';

  @override
  String get billingBandsInvalid =>
      'Die Bänder müssen ansteigen und bei 100 % enden.';

  @override
  String get billingSaved => 'Gespeichert.';

  @override
  String get billingLevels => 'Abo-Stufen';

  @override
  String get billingAddLevel => 'Stufe hinzufügen';

  @override
  String get billingLevelValue => 'Stufe (1–100)';

  @override
  String get billingAllowCustom => 'Individuell verhandelten Wert erlauben';

  @override
  String get memberSubscriptionLabel => 'Abo';

  @override
  String get memberSubscriptionCustom => 'Individuell (1–100)';

  @override
  String moneySubscriptionPct(int pct) {
    return 'Abo $pct %';
  }

  @override
  String percentValue(int value) {
    return '$value %';
  }

  @override
  String get memberOveragePolicyLabel => 'Wenn die Tage aufgebraucht sind';

  @override
  String get memberOveragePolicyTooltip => 'Mehrverbrauch';

  @override
  String get overagePolicyBlocked => 'Weitere Buchung sperren';

  @override
  String get overagePolicyPayg => 'Mehrverbrauch berechnen (nach Verbrauch)';

  @override
  String get overagePolicyPackage => 'Paketkauf verlangen';

  @override
  String get billingPackages => 'Tagespakete';

  @override
  String get billingPackagesHint =>
      'Mitglieder im Paket-Tarif kaufen diese, wenn ihre Tage aufgebraucht sind.';

  @override
  String billingPackageSummary(int days, String price) {
    return '$days Tage · $price';
  }

  @override
  String get billingPackageName => 'Name';

  @override
  String get billingPackageDays => 'Tage';

  @override
  String get billingPackagePrice => 'Preis';

  @override
  String get billingAddPackage => 'Paket hinzufügen';

  @override
  String get buyPackageButton => 'Paket kaufen';

  @override
  String get buyPackageTitle => 'Paket kaufen';

  @override
  String buyPackageDays(int days) {
    return '$days Tage';
  }

  @override
  String get buyPackageNone => 'Noch keine Pakete verfügbar.';

  @override
  String get buyPackageDone => 'Tage hinzugefügt — viel Spaß.';

  @override
  String get payConfigTitle => 'Online-Zahlungen';

  @override
  String get payConfigOpen => 'Einrichten';

  @override
  String get payConfigIntro =>
      'Gib jeden Zahlungsanbieter ein, den du anbieten willst. Schlüssel werden sicher auf dem Server gespeichert und nie wieder angezeigt. Siehe docs/design/payments-integration.md.';

  @override
  String get payConfigConfigured => 'Eingerichtet';

  @override
  String get payConfigNotConfigured => 'Nicht eingerichtet';

  @override
  String get payConfigSecretSet => 'Gesetzt — leer lassen zum Behalten';

  @override
  String get payConfigSaved => 'Gespeichert.';

  @override
  String get payConfigRemove => 'Entfernen';

  @override
  String get payConfigRemoved => 'Entfernt.';

  @override
  String get payFieldClientId => 'Client-ID';

  @override
  String get payFieldSecret => 'Secret';

  @override
  String get payFieldEnv => 'Umgebung';

  @override
  String get payFieldWebhookId => 'Webhook-ID';

  @override
  String get payFieldReturnUrl => 'Rückkehr-URL';

  @override
  String get payFieldSecretKey => 'Secret Key';

  @override
  String get payFieldWebhookSecret => 'Webhook-Signaturgeheimnis';

  @override
  String get payFieldApiKey => 'API-Schlüssel';

  @override
  String get paymentProviderWero => 'Wero (über Mollie)';

  @override
  String get calendarMineTab => 'Meine';

  @override
  String get calendarEveryoneTab => 'Alle';

  @override
  String get calendarNoReservations => 'Keine Reservierungen an diesem Tag.';

  @override
  String get calendarCancelOccurrence => 'Diesen Termin stornieren';

  @override
  String get calendarCancelFollowing => 'Diesen und folgende stornieren';

  @override
  String get calendarPreviousMonth => 'Vorheriger Monat';

  @override
  String get calendarNextMonth => 'Nächster Monat';

  @override
  String get calendarReservationActions => 'Aktionen zur Reservierung';

  @override
  String get calendarShowOnPlan => 'Auf dem Plan anzeigen';

  @override
  String get calendarListView => 'Listenansicht';

  @override
  String get calendarTimelineView => 'Zeitleistenansicht';

  @override
  String get calendarTimelineEmpty =>
      'Keine Reservierungen auf dieser Etage an diesem Tag.';

  @override
  String get calendarAllLevels => 'Alle Etagen';

  @override
  String get calendarTimelineAllEmpty =>
      'Auf keiner Etage gibt es an diesem Tag Reservierungen.';

  @override
  String calendarLevelCollapsed(String level) {
    return '$level, eingeklappt';
  }

  @override
  String calendarLevelExpanded(String level) {
    return '$level, ausgeklappt';
  }

  @override
  String get appTitle => 'DesKilo';

  @override
  String get tabPlan => 'Plan';

  @override
  String get tabCalendar => 'Kalender';

  @override
  String get tabEvents => 'Ereignisse';

  @override
  String get tabMoney => 'Finanzen';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSectionAdministration => 'Verwaltung';

  @override
  String get settingsSectionPreferences => 'Präferenzen';

  @override
  String get settingsSectionAdvanced => 'Erweitert';

  @override
  String get comingSoon => 'Demnächst verfügbar';

  @override
  String get shellReserveButton => 'Reservieren';

  @override
  String commonSavedTo(String path) {
    return 'Gespeichert unter $path';
  }

  @override
  String get commonSaveFailed => 'Datei konnte nicht gespeichert werden.';

  @override
  String get consumptionAdd => 'Verbrauch erfassen';

  @override
  String consumptionAddForMember(String name) {
    return 'Leistung für $name erfassen';
  }

  @override
  String get consumptionService => 'Leistung';

  @override
  String get consumptionQuantity => 'Menge';

  @override
  String get consumptionPeriodLabel => 'Abrechnungszeitraum (JJJJ-MM)';

  @override
  String get consumptionNoServices => 'Keine aktiven Leistungen vorhanden.';

  @override
  String get consumptionRecorded =>
      'Verbrauch erfasst — wartet auf Bestätigung.';

  @override
  String get eventTypeServiceCharge => 'Leistung';

  @override
  String eventServiceChargeTitle(String name, int quantity, String amount) {
    return '$name ×$quantity — $amount';
  }

  @override
  String get developerMode => 'Entwicklermodus';

  @override
  String get developerTitle => 'Entwickler';

  @override
  String get developerExport => 'Protokoll exportieren';

  @override
  String get developerClear => 'Protokoll leeren';

  @override
  String get developerEmpty => 'Noch keine Protokolleinträge.';

  @override
  String get developerFilterAll => 'Alle';

  @override
  String get developerFilterErrors => 'Fehler';

  @override
  String get developerFilterWarnings => 'Warnungen+';

  @override
  String get directoryTitle => 'Mitglieder';

  @override
  String get directoryEmpty => 'Noch keine Mitglieder.';

  @override
  String get directoryCheckedIn => 'Eingecheckt';

  @override
  String directoryCheckedInSeat(String seat) {
    return 'Eingecheckt · $seat';
  }

  @override
  String get directoryOnline => 'Online';

  @override
  String get directoryReservedToday => 'Heute reserviert';

  @override
  String directoryLastSeenMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String directoryLastSeenHours(int hours) {
    return '$hours Std.';
  }

  @override
  String directoryLastSeenDays(int days) {
    return '$days T.';
  }

  @override
  String get directoryWhatsapp => 'Auf WhatsApp schreiben';

  @override
  String get directoryOpenGroup => 'WhatsApp-Gruppe öffnen';

  @override
  String get directoryClose => 'Schließen';

  @override
  String get directoryReservedNow => 'Jetzt reserviert';

  @override
  String directoryReservedNowSeat(String seat) {
    return 'Jetzt reserviert · $seat';
  }

  @override
  String get directoryReservationsHeading => 'Reservierungen';

  @override
  String get directoryNoUpcoming => 'Keine anstehenden Reservierungen';

  @override
  String get editorBackgroundImage => 'Hintergrundbild';

  @override
  String get editorBackgroundSet => 'Hintergrundbild festlegen';

  @override
  String get editorBackgroundReplace => 'Hintergrundbild ersetzen';

  @override
  String get editorBackgroundRemove => 'Hintergrundbild entfernen';

  @override
  String get editorTitle => 'Workspace-Editor';

  @override
  String get editorOpenTooltip => 'Workspace bearbeiten';

  @override
  String get editorAddLevel => 'Etage hinzufügen';

  @override
  String get editorNoLevels =>
      'Noch keine Etagen. Füge die erste Etage deines Workspace hinzu.';

  @override
  String get editorLevelNameLabel => 'Name der Etage';

  @override
  String get editorRenameLevel => 'Umbenennen';

  @override
  String get editorLevelActions => 'Etagen-Aktionen';

  @override
  String get editorDeleteLevelConfirm =>
      'Diese Etage löschen? Alle Büros, Tische und Plätze darauf werden entfernt.';

  @override
  String get editorToolSelect => 'Auswahl';

  @override
  String get editorToolOffice => 'Büro';

  @override
  String get editorToolDesk => 'Tisch';

  @override
  String get editorToolImage => 'Bild';

  @override
  String get editorToolErase => 'Löschen';

  @override
  String get editorNewOffice => 'Neues Büro';

  @override
  String get editorOfficeNameLabel => 'Name des Büros';

  @override
  String get editorOfficeNameDefault => 'Büro';

  @override
  String get editorDeskNameDefault => 'Tisch';

  @override
  String get editorDeskNameLabel => 'Name des Tisches';

  @override
  String get editorPlacementOverlap => 'Überschneidet ein vorhandenes Element.';

  @override
  String get editorPlacementOutside =>
      'Muss vollständig innerhalb eines Büros liegen.';

  @override
  String get editorOfficeProperties => 'Büro';

  @override
  String get editorDeskProperties => 'Tisch';

  @override
  String get editorBookableAsWhole => 'Als Ganzes buchbar';

  @override
  String get editorDeleteElementConfirm =>
      'Dieses Element löschen? Alles darauf wird ebenfalls entfernt.';

  @override
  String get editorToolSeat => 'Platz';

  @override
  String get editorSeatProperties => 'Platz';

  @override
  String get editorSeatNameLabel => 'Name des Platzes';

  @override
  String get editorSeatNameDefault => 'Platz';

  @override
  String get editorOrientationLabel => 'Sitzrichtung';

  @override
  String get editorChairLabel => 'Stuhltyp';

  @override
  String get editorAmenitiesLabel => 'Ausstattung';

  @override
  String get editorBlockedLabel => 'Gesperrt (Wartung)';

  @override
  String get editorSeatNoDesk =>
      'Plätze können nur auf einem Tisch platziert werden.';

  @override
  String get amenityMonitor => 'Monitor';

  @override
  String get amenityStandingDesk => 'Stehpult';

  @override
  String get amenityWindow => 'Fensterplatz';

  @override
  String get amenityDock => 'Dockingstation';

  @override
  String get amenityErgonomicChair => 'Ergonomischer Stuhl';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get editorAccessoriesLabel => 'Zubehör';

  @override
  String get editorNoAccessories =>
      'Noch kein Zubehör — lege es unter Einstellungen → Zubehör an.';

  @override
  String get eventsPendingHeader => 'Wartet auf deine Bestätigung';

  @override
  String get eventAccept => 'Annehmen';

  @override
  String get eventReject => 'Ablehnen';

  @override
  String get eventsEmpty => 'Noch keine Ereignisse.';

  @override
  String get eventsFilterAll => 'Alle';

  @override
  String get eventTypeReservation => 'Reservierung';

  @override
  String get eventTypePayment => 'Zahlung';

  @override
  String get eventTypeExpense => 'Ausgabe';

  @override
  String get eventTypeAdjustment => 'Korrektur';

  @override
  String eventReservationCreated(String actor, String target) {
    return '$actor hat $target reserviert';
  }

  @override
  String eventReservationModified(String actor, String target) {
    return '$actor hat die Reservierung von $target geändert';
  }

  @override
  String eventReservationCancelled(String actor, String target) {
    return '$actor hat die Reservierung von $target storniert';
  }

  @override
  String eventPaymentSubmitted(String actor, String amount) {
    return '$actor hat eine Zahlung von $amount erfasst';
  }

  @override
  String eventExpenseSubmitted(String actor, String amount) {
    return '$actor hat eine Ausgabe von $amount eingereicht';
  }

  @override
  String eventForSubject(String name) {
    return 'für $name';
  }

  @override
  String get pushPendingTitle => 'DesKilo';

  @override
  String get pushPendingBody => 'Jemand wartet auf deine Bestätigung.';

  @override
  String get featuresTitle => 'Funktionen';

  @override
  String get featureCalendarTab => 'Kalender-Tab';

  @override
  String get featureCalendarTabDesc =>
      'Monatsübersicht über Buchungen und Schließtage.';

  @override
  String get featureEventsTab => 'Ereignis-Tab';

  @override
  String get featureEventsTabDesc =>
      'Aktivitätsverlauf und ausstehende Bestätigungen.';

  @override
  String get featureMoneyTab => 'Finanzen-Tab';

  @override
  String get featureMoneyTabDesc => 'Monatsrechnungen, Zahlungen und Ausgaben.';

  @override
  String get featureServices => 'Leistungen';

  @override
  String get featureServicesDesc => 'Leistungskatalog und Verbrauchserfassung.';

  @override
  String get featurePdfExport => 'PDF-Export';

  @override
  String get featurePdfExportDesc => 'Die Monatsrechnung als PDF exportieren.';

  @override
  String get featureSeriesBooking => 'Serienbuchung';

  @override
  String get featureSeriesBookingDesc =>
      'Eine Reservierung täglich, wöchentlich oder an Werktagen wiederholen.';

  @override
  String get featureBookForOthers => 'Für andere buchen';

  @override
  String get featureBookForOthersDesc =>
      'Admins und Inhaber buchen Plätze für andere Mitglieder.';

  @override
  String get featurePushNotifications => 'Push-Benachrichtigungen';

  @override
  String get featurePushNotificationsDesc =>
      'Ausstehende Bestätigungen auf die Geräte der Mitglieder zustellen.';

  @override
  String get featureAdminSeatBlocking => 'Admins können Plätze sperren';

  @override
  String get featureAdminSeatBlockingDesc =>
      'Admins markieren Plätze als nicht reservierbar für Wartung. Der Inhaber kann es immer.';

  @override
  String get featureAccessorySupplements => 'Zubehör-Aufpreise';

  @override
  String get featureAccessorySupplementsDesc =>
      'Bepreistes Platz-Zubehör pro gebuchtem Halbtag berechnen. Gilt für Buchungen ab der Aktivierung.';

  @override
  String get featureOnlinePayments => 'Online-Zahlungen';

  @override
  String get featureOnlinePaymentsDesc =>
      'Mitglieder zahlen ihre Rechnung online (PayPal). Erfordert die Einrichtung des Zahlungsanbieters auf dem Server.';

  @override
  String get featureNfcBadges => 'RFID-/NFC-Badges';

  @override
  String get featureNfcBadgesDesc =>
      'Mitglieder checken an einem Kiosk per RFID/NFC-Karte ein. Erfordert ein Android-Gerät mit NFC.';

  @override
  String get featureLevelBooking => 'Etagen-Reservierung';

  @override
  String get featureLevelBookingDesc =>
      'Eine ganze Etage als eine Buchung reservieren, bepreist je Halbtag. Das Recht wird pro Mitglied vergeben.';

  @override
  String get featureAdminLevelAssign => 'Admins können Etagen zuweisen';

  @override
  String get featureAdminLevelAssignDesc =>
      'Admins weisen Mitgliedern Etagen-Reservierungen zu. Die Inhaberin kann es immer.';

  @override
  String get helpTitle => 'Hilfe';

  @override
  String get helpContents => 'Inhalt';

  @override
  String get inviteSectionTitle => 'Jemanden einladen';

  @override
  String get inviteViaWhatsapp => 'WhatsApp';

  @override
  String get inviteViaSms => 'SMS';

  @override
  String get inviteViaShare => 'Teilen…';

  @override
  String get inviteFirstNameLabel => 'Vorname (optional)';

  @override
  String get inviteLastNameLabel => 'Nachname (optional)';

  @override
  String get invitePhoneLabel => 'Telefon (optional, mit Ländervorwahl)';

  @override
  String get inviteLanguageLabel => 'Sprache der Nachricht';

  @override
  String get inviteSendFailed =>
      'Die Sende-App ließ sich nicht öffnen. Die Nachricht wurde stattdessen kopiert.';

  @override
  String get inviteCreateFailed =>
      'Die Einladung konnte nicht erstellt werden. Prüfe deine Verbindung und versuche es erneut.';

  @override
  String invitationDefaultTemplate(
    String firstName,
    String workspaceName,
    String workspaceId,
    String downloadUrl,
    String inviteLink,
  ) {
    return 'Hallo$firstName! Du bist eingeladen, unserem Coworking-Space „$workspaceName“ auf DesKilo beizutreten.\n\n1. Lade die App herunter:\n$downloadUrl\n\n2. Öffne sie, lege dein Konto an (E-Mail + Passwort) und melde dich an.\n\n3. Wähle „Workspace beitreten“ und gib deinen persönlichen Einladungscode ein:\n$workspaceId\n(Einladungslink: $inviteLink)\n\nTipp: Kopiere einfach diese ganze Nachricht und füge sie in der App ein — der Code wird automatisch erkannt. Dein Code ist persönlich, einmalig nutzbar und 14 Tage gültig.\n\nBis bald bei $workspaceName!';
  }

  @override
  String get invitationTemplateTitle => 'Einladungsnachricht';

  @override
  String get invitationTemplateHelp =>
      'Wird gesendet, wenn du jemanden per WhatsApp, SMS oder Teilen einlädst. Leer lassen für die eingebaute Nachricht in der gewählten Sprache. Verfügbare Tags:';

  @override
  String get invitationTemplateHint =>
      'Eigene Einladungsnachricht mit den Tags oben…';

  @override
  String get workspaceInvitePasteHint =>
      'Füge die ganze Einladungsnachricht ein — die ID wird automatisch erkannt.';

  @override
  String get workspaceInviteCodeInvalid =>
      'Keine Workspace-ID gefunden — Einladung einfügen oder ID eintippen.';

  @override
  String get eventTypeMemberJoin => 'Neues Mitglied';

  @override
  String get memberStatusPending => 'Ausstehend';

  @override
  String get pendingApprovalTitle => 'Warten auf Freigabe';

  @override
  String pendingApprovalBody(String workspace) {
    return 'Du bist $workspace beigetreten. Ein Admin muss deine Mitgliedschaft bestätigen, bevor du den Workspace nutzen kannst — du erhältst Zugriff, sobald sie bestätigt ist.';
  }

  @override
  String get pendingApprovalRefresh => 'Erneut prüfen';

  @override
  String get memberApprove => 'Mitgliedschaft bestätigen';

  @override
  String get memberRejectJoin => 'Mitgliedschaft ablehnen';

  @override
  String get workspaceConfigInvitations => 'Einladungen';

  @override
  String get workspaceConfigInvitationCustom =>
      'Eigene Einladungsnachricht konfiguriert';

  @override
  String get workspaceConfigInvitationDefault =>
      'Eingebaute Einladungsnachricht (alle Sprachen)';

  @override
  String get workspaceConfigInvitationSingleUse =>
      'Persönliche Einladungscodes sind einmalig nutzbar und verfallen nach 14 Tagen; neue Mitglieder brauchen die Freigabe eines Admins';

  @override
  String get memberKioskLabel => 'Kiosk';

  @override
  String get memberMakeKiosk => 'Zum Kiosk-Gerät machen';

  @override
  String get memberUnmakeKiosk => 'Kiosk zu Mitglied zurücksetzen';

  @override
  String get memberBadgesTooltip => 'Badges';

  @override
  String memberBadgesTitle(String name) {
    return 'Badges — $name';
  }

  @override
  String get badgeIssue => 'Neuer Badge';

  @override
  String get badgeTokenOnce =>
      'Speichere diesen QR jetzt — er wird nur einmal angezeigt.';

  @override
  String get badgeNone => 'Noch keine Badges.';

  @override
  String get badgeDefaultLabel => 'Badge';

  @override
  String get badgeRevoke => 'Widerrufen';

  @override
  String get badgeRevoked => 'Widerrufen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get kioskCheckIn => 'Einchecken';

  @override
  String get kioskReserve => 'Reservieren';

  @override
  String get kioskCheckOut => 'Auschecken';

  @override
  String get kioskPresentBadge => 'Badge vorzeigen';

  @override
  String get kioskBadgeHint =>
      'Scanne den QR deines Badges oder tippe seinen Code ein.';

  @override
  String get kioskBadgeFieldLabel => 'Badge-Code';

  @override
  String get kioskBadgeConfirm => 'Bestätigen';

  @override
  String get kioskBadgeRejected => 'Badge nicht erkannt.';

  @override
  String get kioskDone => 'Fertig — alles erledigt.';

  @override
  String get kioskTapHint => 'Tippe einen Platz zum Einchecken';

  @override
  String get badgeSavePdf => 'Als PDF speichern';

  @override
  String get badgeRegisterCard => 'Karte registrieren';

  @override
  String get badgeTapCardTitle => 'Karte registrieren';

  @override
  String get badgeTapCardHint =>
      'Halte die RFID/NFC-Karte an die Rückseite des Geräts.';

  @override
  String get badgeCardRegistered => 'Karte registriert.';

  @override
  String get badgeCardAlreadyRegistered =>
      'Diese Karte ist bereits registriert.';

  @override
  String get kioskBadgeHintNfc =>
      'Karte auflegen, QR scannen oder Code eintippen.';

  @override
  String get nfcConfigTitle => 'RFID-/NFC-Badges';

  @override
  String get nfcConfigIntro =>
      'Mitglieder checken an einem Wandtablet per RFID/NFC-Karte ein. Registriere die Karte jedes Mitglieds unter Mitglieder & Tarife; am Kiosk halten sie die Karte an, um zu reservieren oder einzuchecken.';

  @override
  String get nfcConfigEnable => 'NFC-Badge-Check-in aktivieren';

  @override
  String get nfcConfigEnableDesc =>
      'Zeigt die Karten-Antipp-Option an Kiosken und im Badge-Manager.';

  @override
  String get nfcConfigDeviceStatus => 'Dieses Gerät';

  @override
  String get nfcConfigChecking => 'Prüfe…';

  @override
  String get nfcConfigDeviceReady => 'NFC verfügbar und aktiviert';

  @override
  String get nfcConfigDeviceUnavailable =>
      'Hier kein NFC — ein Android-Gerät mit aktiviertem NFC ist nötig (iPads haben kein NFC). QR-Badges funktionieren weiter.';

  @override
  String get languageTitle => 'Sprache';

  @override
  String get languageSystemDefault => 'Systemstandard';

  @override
  String get levelReserveButton => 'Etage reservieren';

  @override
  String get levelReserveTitle => 'Die ganze Etage reservieren';

  @override
  String get levelPermissionTile => 'Etagen-Reservierungen';

  @override
  String get levelPermissionAllowed => 'Darf eine ganze Etage reservieren';

  @override
  String get levelPermissionDenied => 'Darf keine ganze Etage reservieren';

  @override
  String get levelBookableToggle => 'Als Ganzes reservierbar';

  @override
  String get levelBookableDesc =>
      'Die ganze Etage kann als eine Buchung reserviert werden.';

  @override
  String get levelPriceLabel => 'Preis je Halbtag';

  @override
  String get levelAssignMember => 'Für Mitglied';

  @override
  String get levelAssignMyself => 'Mich selbst';

  @override
  String get levelSupplementLabel => 'Etagen-Reservierungen';

  @override
  String get levelNotAllowed => 'Du darfst keine ganze Etage reservieren.';

  @override
  String get levelConflict =>
      'Die Etage hat Reservierungen in diesem Zeitraum.';

  @override
  String get levelDetail => 'Ganze Etage';

  @override
  String get kioskLevelButton => 'Diese Etage';

  @override
  String get membersTitle => 'Mitglieder & Tarife';

  @override
  String get membersPlanNone => 'Kein Tarif';

  @override
  String get memberRoleOwner => 'Inhaber';

  @override
  String get memberRoleAdmin => 'Admin';

  @override
  String get memberStatusPaused => 'Pausiert';

  @override
  String get memberStatusExited => 'Ausgetreten';

  @override
  String get membersInvite => 'Mitglied einladen';

  @override
  String get profilesTitle => 'Profile';

  @override
  String get profilesAdd => 'Profil hinzufügen';

  @override
  String get profilesActive => 'Aktives Profil';

  @override
  String get memberRoleMember => 'Mitglied';

  @override
  String get moneyBaseFee => 'Basis-Abo';

  @override
  String moneyUsage(int used, int included) {
    return '$used von $included halben Tagen genutzt';
  }

  @override
  String moneyUsageUnlimited(int used) {
    return '$used halbe Tage genutzt';
  }

  @override
  String moneyOverage(int count) {
    return 'Mehrnutzung ($count zusätzliche halbe Tage)';
  }

  @override
  String get moneyCredits => 'Zahlungen & Gutschriften';

  @override
  String get moneyBalance => 'Saldo';

  @override
  String get moneyStatementSettled => 'Beglichen';

  @override
  String get moneyStatementOpen => 'Offen';

  @override
  String get moneyRecordPayment => 'Zahlung erfassen';

  @override
  String get moneyAmountLabel => 'Betrag';

  @override
  String get moneyNoteLabel => 'Notiz (optional)';

  @override
  String get moneySubmitPayment => 'Zur Bestätigung einreichen';

  @override
  String get moneyPaymentPending =>
      'Zahlung eingereicht — wartet auf Bestätigung.';

  @override
  String get moneyLedgerHeader => 'Kontobuch';

  @override
  String get moneyLedgerEmpty => 'Noch keine Buchungen.';

  @override
  String get moneySubmitExpense => 'Ausgabe einreichen';

  @override
  String get moneyExpenseCategoryLabel => 'Kategorie';

  @override
  String get moneyDescriptionLabel => 'Beschreibung';

  @override
  String get moneyExpensePending =>
      'Ausgabe eingereicht — wartet auf Freigabe.';

  @override
  String get expenseCategoryCoffee => 'Kaffee & Küche';

  @override
  String get expenseCategorySupplies => 'Verbrauchsmaterial';

  @override
  String get expenseCategoryEquipment => 'Ausstattung';

  @override
  String get expenseCategoryOther => 'Sonstiges';

  @override
  String get ledgerCategorySubscription => 'Abo';

  @override
  String get ledgerCategoryOverage => 'Mehrnutzung';

  @override
  String get ledgerCategoryExpense => 'Auslagenerstattung';

  @override
  String get ledgerCategoryPayment => 'Zahlung';

  @override
  String get ledgerCategoryAdjustment => 'Korrektur';

  @override
  String get ledgerCategoryService => 'Leistung';

  @override
  String get plansEditorTitle => 'Tarife';

  @override
  String get plansEditorNew => 'Neuer Tarif';

  @override
  String get plansEditorEdit => 'Tarif bearbeiten';

  @override
  String get plansEditorInactive => 'Inaktiv';

  @override
  String get plansEditorUnlimited => 'unbegrenzte Halbtage';

  @override
  String plansEditorQuota(int count) {
    return '$count Halbtage';
  }

  @override
  String plansEditorPerExtra(String price) {
    return '$price/zusätzl. Halbtag';
  }

  @override
  String get planNameLabel => 'Name';

  @override
  String get planBaseFeeLabel => 'Monatliche Grundgebühr';

  @override
  String get planIncludedLabel => 'Enthaltene Halbtage';

  @override
  String get planIncludedHelper => 'Leer lassen für unbegrenzt';

  @override
  String get planOverageLabel => 'Preis pro zusätzlichem Halbtag';

  @override
  String get planActiveLabel => 'Aktiv';

  @override
  String get paymentMethodBankTransfer => 'Überweisung';

  @override
  String get paymentMethodCash => 'Bar';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTwint => 'TWINT';

  @override
  String get paymentMethodCard => 'Karte';

  @override
  String get paymentMethodOther => 'Sonstiges';

  @override
  String get paymentMethodWero => 'Wero';

  @override
  String get paymentMethodLydia => 'Lydia';

  @override
  String get paymentMethodWise => 'Wise';

  @override
  String get planNoLevels => 'Der Workspace hat noch keinen Plan.';

  @override
  String get planLevelLabel => 'Etage';

  @override
  String get planCheckInTitle => 'Einchecken';

  @override
  String get planStartNow => 'Beginnt jetzt';

  @override
  String get planUntilLabel => 'Bis';

  @override
  String get planCheckInButton => 'Einchecken';

  @override
  String get planCheckOutButton => 'Auschecken';

  @override
  String get planCancelReservationButton => 'Reservierung stornieren';

  @override
  String get planSeatBlocked => 'Dieser Platz ist wegen Wartung gesperrt.';

  @override
  String planReservedBy(String name) {
    return 'Reserviert von $name';
  }

  @override
  String planOccupiedBy(String name) {
    return 'Besetzt von $name';
  }

  @override
  String planUntil(String time) {
    return 'bis $time';
  }

  @override
  String planCappedByNext(String time) {
    return 'Der Platz ist ab $time reserviert.';
  }

  @override
  String get planCheckInFailed =>
      'Einchecken nicht möglich — der Platz wurde eventuell gerade belegt.';

  @override
  String get planYourSeat => 'Dein Platz';

  @override
  String get planListViewTooltip => 'Listenansicht';

  @override
  String get planMapViewTooltip => 'Planansicht';

  @override
  String get planNowButton => 'Jetzt';

  @override
  String get planLevelTooltip => 'Etage';

  @override
  String get planReserveButton => 'Reservieren';

  @override
  String get planReservationsEmpty => 'Keine Reservierungen für diesen Tag.';

  @override
  String planStartsAt(String time) {
    return 'Beginnt um $time';
  }

  @override
  String get planRepeatLabel => 'Wiederholen';

  @override
  String get repeatNone => 'Keine Wiederholung';

  @override
  String get repeatDaily => 'Täglich';

  @override
  String get repeatWeekdays => 'Jeden Werktag';

  @override
  String get repeatWeekly => 'Wöchentlich';

  @override
  String get planUntilDateLabel => 'Wiederholen bis';

  @override
  String seriesBookedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Reservierungen erstellt',
      one: '1 Reservierung erstellt',
    );
    return '$_temp0';
  }

  @override
  String get seriesSkippedTitle => 'Übersprungen (bereits belegt):';

  @override
  String get commonOk => 'OK';

  @override
  String get reminderTitle => 'Bald einchecken';

  @override
  String reminderBody(String target, String time) {
    return '$target beginnt um $time';
  }

  @override
  String get planNoSeats => 'Diese Etage hat noch keine Plätze.';

  @override
  String get planStateFree => 'Frei';

  @override
  String get planStateYours => 'Deiner';

  @override
  String get planBookForLabel => 'Buchen für';

  @override
  String get planSendForConfirmation => 'Zur Bestätigung senden';

  @override
  String planBookedForPending(String name) {
    return 'Zur Bestätigung an $name gesendet.';
  }

  @override
  String get planMakeNotReservable => 'Nicht reservierbar machen';

  @override
  String get planMakeReservable => 'Reservierbar machen';

  @override
  String get planAccessorySupplementHint => 'Aufpreise gelten pro halbem Tag.';

  @override
  String get planFromLabel => 'Von';

  @override
  String get planToLabel => 'Bis';

  @override
  String get planEndBeforeStart => 'Das Ende muss nach dem Beginn liegen.';

  @override
  String get planClosedDay => 'An diesem Tag geschlossen';

  @override
  String get planClosedDayError =>
      'Der Workspace ist an diesem Tag geschlossen.';

  @override
  String get planMorningChip => 'Vormittag';

  @override
  String get planAfternoonChip => 'Nachmittag';

  @override
  String get planFullDayChip => 'Ganzer Tag';

  @override
  String get planHalfDayError => 'Buchungen erfolgen hier pro halbem Tag.';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get whatsappNotShared => 'Nicht geteilt';

  @override
  String get whatsappFieldLabel => 'WhatsApp-Nummer';

  @override
  String get whatsappHint => '+49 151 23456789';

  @override
  String get whatsappHelper =>
      'Optional. Für Mitglieder deiner Workspaces sichtbar, damit sie dich über WhatsApp erreichen. Leer lassen, um die Nummer nicht mehr zu teilen.';

  @override
  String get whatsappSaved => 'WhatsApp-Nummer gespeichert';

  @override
  String get whatsappSaveFailed =>
      'WhatsApp-Nummer konnte nicht gespeichert werden';

  @override
  String get profileStatusTitle => 'Status';

  @override
  String get profileStatusNone => 'Kein Status';

  @override
  String get profileStatusFieldLabel => 'Status';

  @override
  String get profileStatusHint => 'Im Call · zurück um 14:00';

  @override
  String get profileStatusHelper =>
      'Optional. Für Mitglieder deiner Workspaces im Mitgliederverzeichnis sichtbar. Leer lassen, um den Status zu löschen.';

  @override
  String get profileStatusSaved => 'Status gespeichert';

  @override
  String get profileStatusSaveFailed =>
      'Status konnte nicht gespeichert werden';

  @override
  String get profilePhotoTitle => 'Foto';

  @override
  String get profilePhotoSet => 'Zum Ändern tippen';

  @override
  String get profilePhotoNone => 'Zum Hinzufügen eines Fotos tippen';

  @override
  String get profilePhotoChoose => 'Foto auswählen';

  @override
  String get profilePhotoRemove => 'Foto entfernen';

  @override
  String get profilePhotoSaved => 'Foto aktualisiert';

  @override
  String get profilePhotoRemoved => 'Foto entfernt';

  @override
  String get profilePhotoSaveFailed => 'Foto konnte nicht aktualisiert werden';

  @override
  String get profilePhotoFileType => 'Bild';

  @override
  String get eventTypeRoleChange => 'Rollenwechsel';

  @override
  String eventRolePromote(String actor) {
    return '$actor befördert ein Mitglied zum Admin';
  }

  @override
  String eventRoleDemote(String actor) {
    return '$actor stuft einen Admin zum Mitglied zurück';
  }

  @override
  String get memberMakeAdmin => 'Zum Admin machen';

  @override
  String get memberMakeMember => 'Zum normalen Mitglied machen';

  @override
  String get memberRoleChangeRequested =>
      'Rollenwechsel zur Freigabe gesendet.';

  @override
  String get eventTypeQuota => 'Zusätzliche halbe Tage';

  @override
  String eventQuotaRequested(String actor, int halfDays, String period) {
    return '$actor beantragt $halfDays zusätzliche halbe Tage für $period';
  }

  @override
  String get quotaExceededError =>
      'Monatliches Halbtage-Kontingent erreicht — beantrage zusätzliche halbe Tage im Finanzen-Tab.';

  @override
  String get quotaRequestButton => 'Zusätzliche halbe Tage beantragen';

  @override
  String get quotaRequestTitle => 'Zusätzliche halbe Tage beantragen';

  @override
  String quotaRequestExplainer(String period) {
    return 'Deine Reservierungen sind durch dein Abo begrenzt. Zusätzliche halbe Tage für $period gelten nach der Freigabe.';
  }

  @override
  String get quotaRequestCountLabel => 'Anzahl halber Tage';

  @override
  String get quotaRequestPending => 'Antrag gesendet — wartet auf Freigabe.';

  @override
  String get memberReservationLimitTooltip => 'Reservierungslimit';

  @override
  String get memberReservationLimitLabel => 'Reservierungslimit';

  @override
  String get memberReservationLimitExplainer =>
      'Wie viele offene Reservierungen dieses Mitglied gleichzeitig halten darf.';

  @override
  String get memberReservationLimitNone => 'Kein Limit';

  @override
  String get memberReservationLimitCustom => 'Individuell (1–100)';

  @override
  String memberReservationLimitChip(int n) {
    return 'max. $n';
  }

  @override
  String get reservationLimitError =>
      'Reservierungslimit erreicht — du hältst bereits die maximale Zahl offener Reservierungen.';

  @override
  String get memberPause => 'Mitgliedschaft pausieren';

  @override
  String get memberReactivate => 'Mitgliedschaft reaktivieren';

  @override
  String get reserveMonthView => 'Monat';

  @override
  String monthFreeCount(int free, int total) {
    return '$free/$total';
  }

  @override
  String get reservationRecurring => 'Wiederkehrende Reservierung';

  @override
  String get reservationEditTimes => 'Zeit ändern';

  @override
  String get reservationUpdatedSnack => 'Reservierung aktualisiert.';

  @override
  String get reservationCancelledSnack => 'Reservierung storniert.';

  @override
  String get reserveDayView => 'Tag';

  @override
  String get reserveWeekView => 'Woche';

  @override
  String get reserveFullDayChip => 'Ganzer Tag';

  @override
  String get reservePickDateTooltip => 'Datum wählen';

  @override
  String get reserveBookingFailed =>
      'Reservieren nicht möglich — der Platz wurde eventuell gerade belegt.';

  @override
  String get servicesTitle => 'Leistungen';

  @override
  String get servicesEmpty => 'Noch keine Leistungen.';

  @override
  String get servicesNew => 'Neue Leistung';

  @override
  String get servicesEdit => 'Leistung bearbeiten';

  @override
  String get servicesName => 'Name';

  @override
  String get servicesPrice => 'Preis';

  @override
  String get servicesInactive => 'Inaktiv';

  @override
  String get servicesActive => 'Aktiv';

  @override
  String get authContinueWith => 'oder weiter mit';

  @override
  String authSocialUnavailable(String provider) {
    return 'Die $provider-Anmeldung ist noch nicht verfügbar — der Server hat sie nicht aktiviert.';
  }

  @override
  String get linkedAccountsTitle => 'Verknüpfte Konten';

  @override
  String get linkedAccountsIntro =>
      'Melde dich mit jedem davon an diesem Konto an. Füge Google, Microsoft, Apple oder Facebook hinzu, um dich ohne Passwort anzumelden.';

  @override
  String get linkedAccountsLink => 'Verknüpfen';

  @override
  String get linkedAccountsUnlink => 'Trennen';

  @override
  String get linkedAccountsLinked => 'Verknüpft';

  @override
  String get linkedAccountsLinkStarted =>
      'Fahre im Browser fort, um die Verknüpfung abzuschließen.';

  @override
  String get themeTitle => 'Design';

  @override
  String get themeSystem => 'Systemstandard';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String eventValidations(int current, int required) {
    return '$current/$required Bestätigungen';
  }

  @override
  String eventValidatedBy(String name, String when) {
    return 'Bestätigt von $name · $when';
  }

  @override
  String eventRejectedBy(String name, String when) {
    return 'Abgelehnt von $name · $when';
  }

  @override
  String get eventSystemDecider => 'System';

  @override
  String get validationTitle => 'Validierungsregeln';

  @override
  String get validationDefaultPolicy => 'Standardregel';

  @override
  String get validationInherited => 'Erbt den Standard';

  @override
  String get validationCustomized => 'Angepasst';

  @override
  String get validationRequiredCount => 'Erforderliche Validierungen';

  @override
  String get validationAdminsMay => 'Admins dürfen validieren';

  @override
  String get validationOwnerOnly => 'Nur Inhaber';

  @override
  String get validationAllAdmins => 'Alle Admins';

  @override
  String get validationSpecificAdmins => 'Bestimmte Admins';

  @override
  String get validationOwnerRequired => 'Inhaber muss immer validieren';

  @override
  String get validationNotEnough => 'Nicht genügend berechtigte Validierer.';

  @override
  String get validationSaved => 'Validierungsregel gespeichert.';

  @override
  String get onboardingTitle => 'Willkommen bei DesKilo';

  @override
  String get onboardingCreateTab => 'Workspace erstellen';

  @override
  String get onboardingJoinTab => 'Workspace beitreten';

  @override
  String get workspaceNameLabel => 'Name des Workspace';

  @override
  String get workspaceCountryLabel => 'Land';

  @override
  String get workspaceCurrencyLabel => 'Währung';

  @override
  String get workspaceTimezoneLabel => 'Zeitzone';

  @override
  String get onboardingCreateButton => 'Workspace erstellen';

  @override
  String get workspaceInviteCodeLabel => 'Einladungscode';

  @override
  String get onboardingJoinButton => 'Beitreten';

  @override
  String get workspaceGenericError =>
      'Etwas ist schiefgelaufen. Bitte erneut versuchen.';

  @override
  String get countryNameDE => 'Deutschland';

  @override
  String get countryNameAT => 'Österreich';

  @override
  String get countryNameCH => 'Schweiz';

  @override
  String get countryNameFR => 'Frankreich';

  @override
  String get countryNameIT => 'Italien';

  @override
  String get countryNameES => 'Spanien';

  @override
  String get countryNamePT => 'Portugal';

  @override
  String get countryNameNL => 'Niederlande';

  @override
  String get countryNameBE => 'Belgien';

  @override
  String get countryNameLU => 'Luxemburg';

  @override
  String get countryNameGB => 'Vereinigtes Königreich';

  @override
  String get countryNameUS => 'Vereinigte Staaten';

  @override
  String get workspaceCodeTitle => 'Workspace-ID & QR';

  @override
  String get workspaceCodeLabel => 'Workspace-ID';

  @override
  String get workspaceCodeHint => '4–20 Buchstaben oder Ziffern, eindeutig';

  @override
  String get workspaceCodeEdit => 'Workspace-ID ändern';

  @override
  String get workspaceCodeRejected =>
      'ID abgelehnt — sie muss 4–20 Buchstaben oder Ziffern haben und darf nicht vergeben sein.';

  @override
  String get workspaceCodeExplainer =>
      'Coworker scannen diesen QR-Code — oder tippen die ID ein — um diesem Workspace beizutreten.';

  @override
  String get workspaceCodeCopy => 'ID kopieren';

  @override
  String get workspaceCodeCopied => 'Kopiert';

  @override
  String get inviteRoleMember => 'Mitglieder-Einladung';

  @override
  String get inviteRoleAdmin => 'Admin-Einladung';

  @override
  String get inviteAdminExplainer =>
      'Dieser Code ist einmalig nutzbar: Er lässt EINE Person als Admin beitreten und verfällt dann. Gib ihn nur der Person, für die er bestimmt ist.';

  @override
  String get inviteAdminNewCode => 'Neuer Admin-Code';

  @override
  String get inviteOwnerNote =>
      'Es gibt keine Eigentümer-Einladung — nur ein Eigentümer kann Eigentum vergeben, unter Mitglieder & Pläne.';

  @override
  String get scanJoinTitle => 'Workspace-QR scannen';

  @override
  String get onboardingScanButton => 'QR-Code scannen';

  @override
  String get workspaceCodeSharePng => 'Als PNG teilen';

  @override
  String get workspaceSettingsTitle => 'Workspace';

  @override
  String get workspaceSettingsSaved => 'Workspace gespeichert.';

  @override
  String get workspaceSettingsCurrencyHelper =>
      'Wird vom Land vorbelegt — überschreiben, falls eure Community in einer anderen Währung abrechnet.';

  @override
  String get paymentInstructionsTitle => 'Zahlungshinweise';

  @override
  String get paymentInstructionsHelper =>
      'Wird Mitgliedern auf einer offenen Abrechnung angezeigt. Leer lassen, um nichts anzuzeigen.';

  @override
  String get paymentInstructionsPaypalLabel => 'PayPal.me-Link oder -Name';

  @override
  String get paymentInstructionsReferenceLabel =>
      'Hinweis zum Verwendungszweck';

  @override
  String get paymentInstructionsIbanTitle => 'IBAN';

  @override
  String get paymentInstructionsIbanCopied => 'IBAN kopiert.';

  @override
  String get paymentInstructionsWeroLabel => 'Wero-Telefonnummer';

  @override
  String get paymentInstructionsLydiaLabel =>
      'Lydia-Telefonnummer oder -Nutzername';

  @override
  String get paymentInstructionsWiseLabel => 'Wisetag oder Wise-Zahlungslink';

  @override
  String get paymentInstructionsValueCopied => 'In die Zwischenablage kopiert.';

  @override
  String get workspaceWhatsappGroupTitle => 'WhatsApp-Gruppe';

  @override
  String get workspaceWhatsappGroupHelper =>
      'Wird Mitgliedern angezeigt, damit sie der WhatsApp-Gruppe der Community beitreten können. Einladungslink der Gruppe einfügen (https://chat.whatsapp.com/…). Leer lassen, um nichts anzuzeigen.';

  @override
  String get workspaceWhatsappGroupLabel => 'Link zur WhatsApp-Gruppe';

  @override
  String get workspaceWhatsappGroupInvalid =>
      'Muss ein chat.whatsapp.com-Einladungslink sein';

  @override
  String get memberStatusActive => 'Aktiv';

  @override
  String get workspaceConfigPdfExport => 'Konfiguration exportieren (PDF)';

  @override
  String get workspaceConfigPdfExportSubtitle =>
      'Vollständige Momentaufnahme: Einstellungen, alle Mitglieder und der Plan.';

  @override
  String get workspaceConfigPdfTitle => 'Workspace-Konfiguration';

  @override
  String workspaceConfigPdfGeneratedOn(String date) {
    return 'Erstellt am $date';
  }

  @override
  String get workspaceConfigOverview => 'Übersicht';

  @override
  String get workspaceConfigMembersSection => 'Mitglieder';

  @override
  String get workspaceConfigFeatures => 'Aktivierte Funktionen';

  @override
  String get workspaceConfigAvailability => 'Verfügbarkeit';

  @override
  String get workspaceConfigFloorPlan => 'Grundriss';

  @override
  String get workspaceConfigGranularity => 'Buchungsgranularität';

  @override
  String get workspaceConfigColName => 'Name';

  @override
  String get workspaceConfigColRole => 'Rolle';

  @override
  String get workspaceConfigColStatus => 'Status';

  @override
  String get workspaceConfigOpenDays => 'Öffnungstage';

  @override
  String get workspaceConfigClosures => 'Schließtage';

  @override
  String get workspaceConfigBookableWhole => 'als Ganzes buchbar';

  @override
  String get workspaceConfigSeats => 'Plätze';

  @override
  String get workspaceConfigEmptyLevel => 'Keine Räume';

  @override
  String get workspaceConfigNone => 'Keine';

  @override
  String get workspaceDeskTransparencyTitle => 'Tisch-Transparenz';

  @override
  String get workspaceDeskTransparencyHelper =>
      'Verringere die Deckkraft der Tische, damit das Hintergrundfoto der Etage durchscheint.';

  @override
  String workspaceDeskOpacityValue(int percent) {
    return 'Deckkraft: $percent %';
  }

  @override
  String get workspaceDangerZone => 'Gefahrenzone';

  @override
  String get workspaceResetTitle => 'Workspace zurücksetzen';

  @override
  String get workspaceResetSubtitle =>
      'Löscht alle Buchungen, Finanzen und den Grundriss. Einstellungen und Mitglieder bleiben.';

  @override
  String get workspaceResetDialogTitle => 'Diesen Workspace zurücksetzen?';

  @override
  String get workspaceResetWarning =>
      'Dies löscht dauerhaft alle Reservierungen, sämtliche Finanz- und Buchungsdaten, den Aktivitätsverlauf und den gesamten Grundriss — Etagen, Räume, Tische, Plätze und Bilder. Workspace-Einstellungen, Gebührenstufen, Verfügbarkeit, Funktionen, Kataloge und Mitglieder bleiben erhalten. Nicht rückgängig zu machen.';

  @override
  String get workspaceResetConfirmPhrase => 'Ich stimme zu';

  @override
  String workspaceResetConfirmLabel(String phrase) {
    return 'Tippe „$phrase“ zum Bestätigen';
  }

  @override
  String get workspaceResetConfirmButton => 'Workspace zurücksetzen';

  @override
  String get workspaceResetDone => 'Workspace zurückgesetzt.';

  @override
  String get workspaceXmlExport => 'Workspace exportieren (XML)';

  @override
  String get workspaceXmlExportSubtitle =>
      'Einstellungen und Raumplan als teilbare Datei. Ohne Mitglieder, Buchungen oder Finanzdaten.';

  @override
  String get workspaceXmlImport => 'Workspace importieren (XML)';

  @override
  String get workspaceXmlImportSubtitle =>
      'Einstellungen und Raumplan aus einer exportierten Datei wiederherstellen. Ersetzt den aktuellen Raumplan.';

  @override
  String get workspaceXmlFileTypeLabel => 'XML';

  @override
  String get workspaceXmlImportPreviewTitle => 'Raumplan ersetzen?';

  @override
  String workspaceXmlImportPreviewCounts(
    int levels,
    int offices,
    int desks,
    int seats,
  ) {
    return 'Etagen: $levels · Räume: $offices · Tische: $desks · Plätze: $seats';
  }

  @override
  String workspaceXmlImportPreviewAccessories(int count) {
    return 'Zubehör: $count';
  }

  @override
  String get workspaceXmlImportPreviewWarning =>
      'Der aktuelle Raumplan wird gelöscht und ersetzt, die Workspace-Einstellungen werden überschrieben. Das kann nicht rückgängig gemacht werden.';

  @override
  String get workspaceXmlImportConfirm => 'Ersetzen und importieren';

  @override
  String get workspaceXmlImportSuccess => 'Workspace importiert.';

  @override
  String get workspaceXmlErrorMalformed => 'Die Datei ist kein lesbares XML.';

  @override
  String get workspaceXmlErrorWrongRoot =>
      'Das ist keine DesKilo-Workspace-Datei.';

  @override
  String get workspaceXmlErrorUnsupportedVersion =>
      'Die Datei wurde von einer neueren DesKilo-Version exportiert und kann nicht importiert werden.';

  @override
  String get workspaceXmlErrorMissingElement =>
      'Die Datei ist unvollständig — ein erforderlicher Abschnitt fehlt.';

  @override
  String get workspaceXmlErrorMissingAttribute =>
      'Die Datei ist unvollständig — ein erforderlicher Wert fehlt.';

  @override
  String get workspaceXmlErrorInvalidValue =>
      'Die Datei enthält einen ungültigen Wert und kann nicht importiert werden.';

  @override
  String get workspaceXmlErrorInvalidPlan =>
      'Der Raumplan in der Datei ist ungültig: Räume, Tische oder Plätze überlappen sich oder liegen außerhalb ihres Bereichs.';

  @override
  String get workspaceXmlImportReservationsError =>
      'Dieser Workspace hat bereits Reservierungen, daher kann sein Raumplan nicht ersetzt werden. Ein Import ist nur vor der ersten Buchung möglich.';
}
