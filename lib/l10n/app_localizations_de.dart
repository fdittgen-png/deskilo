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
      'Halbe Tage: Buchungen umfassen den Vormittag, den Nachmittag oder den ganzen Arbeitstag — die Fenster folgen den konfigurierten Arbeitszeiten.';

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
  String get availabilityGranularityHours =>
      'Echte Uhrzeiten (exakt von–bis, Halb-/Ganztage als Schnellwahl)';

  @override
  String get availabilityWorkHoursTitle => 'Arbeitszeiten';

  @override
  String get availabilityWorkHoursDescription =>
      'Die Halbtags- und Ganztagsfenster überall — Reservierungen, Check-in und Abrechnung — folgen diesen Zeiten.';

  @override
  String get availabilityWorkStart => 'Tagesbeginn';

  @override
  String get availabilityHalfBoundary => 'Halbtagsgrenze';

  @override
  String get availabilityWorkEnd => 'Tagesende';

  @override
  String get availabilityHalfDayHours => 'Stunden, die als halber Tag gelten';

  @override
  String get availabilityFullDayHours => 'Stunden, die als ganzer Tag gelten';

  @override
  String availabilityHourOption(int count) {
    return '$count h';
  }

  @override
  String get availabilityWorkHoursInvalid =>
      'Es muss gelten: Beginn < Halbtagsgrenze < Ende.';

  @override
  String get myBadgeTitle => 'Mein Badge';

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
  String billInvoiceCard(String number) {
    return 'Rechnung $number';
  }

  @override
  String billCreditNoteCard(String number) {
    return 'Gutschrift $number';
  }

  @override
  String get billInvoiceTotal => 'Rechnungsbetrag';

  @override
  String get billInvoicePaid => 'Bereits bezahlt';

  @override
  String get billInvoiceRemaining => 'Restbetrag';

  @override
  String get billCreditNoteDue =>
      'Der Space schuldet dir diesen Betrag — du musst nichts zahlen.';

  @override
  String get billCreditNoteRefunded =>
      'Der Space hat dir diesen Betrag erstattet.';

  @override
  String get accountCardTitle => 'Dein Konto';

  @override
  String get accountCredit => 'Guthaben auf dem Konto';

  @override
  String get accountRefundDue => 'Erstattung vom Space ausstehend';

  @override
  String get accountNet => 'Nettoposition';

  @override
  String accountOpenPartial(String period, String paid) {
    return '$period · $paid bezahlt';
  }

  @override
  String get accountImputationHint =>
      'Dein Guthaben kann offene Rechnungen begleichen — der Space rechnet es beim Zuordnen der Zahlungen an.';

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
  String get commonRetry => 'Erneut versuchen';

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
  String get coOwnerAction => 'Mit-Inhaberschaft';

  @override
  String get coOwnerNone => 'Keine Mit-Inhaber-Rolle';

  @override
  String get coOwnerActive =>
      'Aktive Mit-Inhaberin — Inhaber-Rechte sofort, automatische Nachfolge';

  @override
  String get coOwnerPassive =>
      'Passive Mit-Inhaberin — wird Inhaberin bei Aktivierung oder wenn der Inhaber geht';

  @override
  String get coOwnerActivate => 'Jetzt zur Inhaberin machen';

  @override
  String get memberCoOwnerChip => 'Mit-Inhaberin';

  @override
  String get memberCoOwnerPassiveChip => 'Mit-Inhaberin (passiv)';

  @override
  String get developerMode => 'Entwicklermodus';

  @override
  String get developerModeWorkspaceHint =>
      'Gilt für alle Mitglieder dieses Workspace.';

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
  String get pushStatusRegistered => 'Push-Benachrichtigungen sind aktiv';

  @override
  String get pushStatusNotConfigured =>
      'Push-Benachrichtigungen sind noch nicht eingerichtet';

  @override
  String get pushStatusNotConfiguredHint =>
      'Die Inhaberin schließt die Firebase-Einrichtung ab (push-setup-Anleitung).';

  @override
  String get notificationsSystemOff =>
      'Android blockiert DesKilo-Benachrichtigungen';

  @override
  String get notificationsSystemOffHint =>
      'Erlaube sie unter System-Einstellungen → Apps → DesKilo → Benachrichtigungen — das Icon-Badge braucht sie.';

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
  String get pushCancelledTitle => 'Reservierung entfernt';

  @override
  String get pushCancelledBody =>
      'Eine Reservierung wurde von einem Admin entfernt.';

  @override
  String get eventTypeReservationDelete => 'Buchungslöschung';

  @override
  String eventReservationDeleteLine(String actor, String date, String state) {
    return '$actor bittet um Löschung der Buchung vom $date ($state)';
  }

  @override
  String get eventReservationDeleteCheckedIn => 'eingecheckt';

  @override
  String get eventReservationDeleteUnused => 'nie genutzt';

  @override
  String get reservationDeleteRequestButton => 'Löschung beantragen';

  @override
  String get reservationDeleteRequestExplain =>
      'Vergangene oder eingecheckte Buchungen werden nicht direkt gelöscht. Inhaber oder Admin entscheiden: wurde der Check-in nur vergessen (die Buchung bleibt), oder wurde sie nie genutzt (sie wird entfernt)?';

  @override
  String get reservationDeleteReasonLabel => 'Grund (optional)';

  @override
  String get reservationDeleteSubmit => 'Anfrage senden';

  @override
  String get reservationDeleteSubmitted =>
      'Löschung beantragt — Inhaber oder Admin entscheiden.';

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
  String get featureLevelBooking => 'Tisch-, Büro- & Etagen-Reservierungen';

  @override
  String get featureLevelBookingDesc =>
      'Einen ganzen Tisch, ein Büro oder eine Etage als eine Buchung reservieren, je Halbtag bepreist. Das Recht wird pro Mitglied vergeben.';

  @override
  String get featureAdminLevelAssign => 'Admins können Etagen zuweisen';

  @override
  String get featureAdminLevelAssignDesc =>
      'Admins weisen Mitgliedern Etagen-Reservierungen zu. Die Inhaberin kann es immer.';

  @override
  String get featureKioskMode => 'Kiosk-Modus';

  @override
  String get featureKioskModeDesc =>
      'Wandtablet-Konten, verriegelt auf den Live-Plan; Mitglieder handeln per Badge.';

  @override
  String get featureMembersDirectory => 'Mitgliederverzeichnis';

  @override
  String get featureMembersDirectoryDesc =>
      'Der Community-Tab: wer da ist, Status, Präsenz.';

  @override
  String get featureWhatsappIntegration => 'WhatsApp-Integration';

  @override
  String get featureWhatsappIntegrationDesc =>
      'Mitglieder per WhatsApp anschreiben und die Community-Gruppe verlinken.';

  @override
  String get featureSpaceQrCodes => 'Raum-QR-Codes';

  @override
  String get featureSpaceQrCodesDesc =>
      'Druckbare QR-Karten je Platz, Tisch, Büro und Etage — scannen zum Reservieren oder Einchecken.';

  @override
  String featureRequires(String feature) {
    return 'Benötigt $feature';
  }

  @override
  String get featureCoOwner => 'Mit-Inhaberinnen';

  @override
  String get featureCoOwnerDesc =>
      'Mit-Inhaber ernennen: Inhaber-Rechte sofort (aktiv) oder wartende Nachfolge (passiv).';

  @override
  String get featureAutoCheckInOut => 'Auto-Check-in/-out am Tagesende';

  @override
  String get featureDataExport => 'Datenexport (Excel)';

  @override
  String get featureAutoCheckInOutDesc =>
      'Reservierungen ohne Check-in oder Check-out schließen sich selbst, sobald ihre Zeit vorbei ist.';

  @override
  String get featureDataExportDesc =>
      'Alle Daten des Spaces als Excel-Arbeitsmappe herunterladen.';

  @override
  String get featureWorkingHours => 'Arbeitszeiten';

  @override
  String get featureWorkingHoursDesc =>
      'Arbeitstag konfigurieren und Buchung nach exakten Uhrzeiten anbieten; aus = Standard 8–17 Uhr.';

  @override
  String get featureInvoicePdfTemplate => 'Rechnungs-PDF-Vorlage';

  @override
  String get featureInvoicePdfTemplateDesc =>
      'Vom Inhaber verfasste Einleitung und Fußtext auf dem Rechnungs-PDF. Das E-Rechnungs-XML bleibt unberührt.';

  @override
  String get featureMemberNotifications => 'Mitglieder-Benachrichtigungen';

  @override
  String get featureMemberNotificationsDesc =>
      'Kurze Benachrichtigung an ein anderes Mitglied senden; Admins können alle Admins inkl. Inhaber benachrichtigen.';

  @override
  String get featureDunning => 'Mahnwesen';

  @override
  String get featureDunningDesc =>
      'Parametrierbare Mahnregeln und „Mahnung fällig“-Hinweise auf überfälligen Rechnungen. Nichts wird je automatisch versendet.';

  @override
  String get featureMemberReports => 'Mitgliederberichte';

  @override
  String get featureMemberReportsDesc =>
      'Die Finanzvereinbarung und der monatliche Zahlungsbericht — Self-Service für Mitglieder, pro Mitglied versendbar.';

  @override
  String get featureDeletionRequests => 'Lösch-Anträge für Buchungen';

  @override
  String get featureDeletionRequestsDesc =>
      'Mitglieder können die Löschung einer vergangenen oder eingecheckten Buchung BEANTRAGEN; Inhaber/Admin validieren. Aus: solche Buchungen sind gar nicht löschbar.';

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
  String get invoicesTitle => 'Rechnungen';

  @override
  String get invoicesEmpty => 'Noch keine Rechnungen.';

  @override
  String get invoiceCreate => 'Neue Rechnung';

  @override
  String get invoiceMemberLabel => 'Mitglied';

  @override
  String get invoiceIssue => 'Rechnung ausstellen';

  @override
  String get invoiceIssued => 'Rechnung ausgestellt.';

  @override
  String get invoiceDownload => 'PDF herunterladen';

  @override
  String get invoiceShare => 'PDF teilen';

  @override
  String get invoicePdfTitle => 'Rechnung';

  @override
  String get invoicePdfIssuedOn => 'Ausgestellt am';

  @override
  String get invoicePdfIssuedBy => 'Ausgestellt von';

  @override
  String get invoicePdfBilledTo => 'Rechnung an';

  @override
  String get invoicePdfSignature => 'Digitale Signatur (SHA-256)';

  @override
  String get addressTitle => 'Adresse';

  @override
  String get addressNone => 'Keine Adresse';

  @override
  String get addressSaved => 'Adresse gespeichert';

  @override
  String get workspaceAddressLabel => 'Adresse des Workspace';

  @override
  String get featureInvoicing => 'Rechnungen';

  @override
  String get featureInvoicingDesc =>
      'Unveränderliche, signierte Rechnungen im Archiv — als PDF herunterladen oder teilen.';

  @override
  String get featureAdminInvoicing => 'Admins stellen Rechnungen aus';

  @override
  String get featureAdminInvoicingDesc =>
      'Auch Admins stellen Rechnungen aus. Die Inhaberin kann es immer.';

  @override
  String get invoiceVoidedChip => 'Fehlerhaft';

  @override
  String get invoiceVoidAction => 'Als fehlerhaft markieren';

  @override
  String invoiceVoidConfirm(String number) {
    return 'Rechnung $number als fehlerhaft markieren? Das kann nicht rückgängig gemacht werden.';
  }

  @override
  String get invoiceVoided => 'Rechnung als fehlerhaft markiert.';

  @override
  String get invoiceReplaceAction => 'Ersatzrechnung ausstellen';

  @override
  String get invoicePdfVoided => 'FEHLERHAFT — storniert am';

  @override
  String get invoicePdfReplaces => 'Ersetzt';

  @override
  String get invoiceNothingToInvoice =>
      'Für diesen Monat wurde nichts erfasst — nichts zu berechnen.';

  @override
  String get invoiceLineAdjustment => 'Anpassung';

  @override
  String get invoiceFilterAllMembers => 'Alle Mitglieder';

  @override
  String get invoiceFilterAllMonths => 'Alle Monate';

  @override
  String get invoiceFilterMonthLabel => 'Monat';

  @override
  String get invoiceSortTooltip => 'Sortieren';

  @override
  String get invoiceSortNewest => 'Neueste zuerst';

  @override
  String get invoiceSortByMember => 'Nach Mitglied';

  @override
  String get invoiceSortByMonth => 'Nach Monat';

  @override
  String get invoiceBalance => 'Saldo';

  @override
  String get invoiceDetailedToggle =>
      'Detaillierten Anhang aufnehmen (Check-ins, Services, Zahlungen)';

  @override
  String get invoicePdfDescription => 'Beschreibung';

  @override
  String get invoicePdfCharges => 'Posten';

  @override
  String get invoicePdfPayments => 'Zahlungen';

  @override
  String get invoicePdfAnnex => 'Anhang — Details';

  @override
  String get invoicePdfAttendance => 'Check-ins';

  @override
  String get invoicePdfActivity => 'Buchungen & Zahlungen';

  @override
  String get invoicePdfReserved => 'reserviert';

  @override
  String get invoicePdfPage => 'Seite';

  @override
  String get invoiceRemindAction => 'Zahlungserinnerung senden';

  @override
  String get invoiceReminded => 'Erinnerung erfasst.';

  @override
  String invoiceRemindedBadge(int count) {
    return 'Erinnert ×$count';
  }

  @override
  String invoiceReminderMessage(String number, String amount) {
    return 'Freundliche Erinnerung: Rechnung $number — offener Saldo $amount.';
  }

  @override
  String get invoiceEInvoiceDownload => 'E-Rechnung herunterladen (XML)';

  @override
  String get invoiceEInvoiceShare => 'E-Rechnung teilen (XML)';

  @override
  String get invoiceTabToInvoice => 'Zu berechnen';

  @override
  String get invoiceTabOpen => 'Offen';

  @override
  String get invoiceTabArchive => 'Archiv';

  @override
  String get invoiceIssueAll => 'Alle berechnen';

  @override
  String get invoiceIssueOne => 'Berechnen';

  @override
  String get invoiceAllCaughtUp => 'Alles erledigt — nichts zu berechnen.';

  @override
  String get invoiceNoOpen => 'Keine offenen Rechnungen.';

  @override
  String invoiceSummaryToInvoice(int count) {
    return '$count zu berechnen';
  }

  @override
  String invoiceSummaryOpen(int count, String amount) {
    return '$count offen · $amount ausstehend';
  }

  @override
  String invoiceOpenAge(int days) {
    return '$days Tage';
  }

  @override
  String invoiceIssuedCount(int count) {
    return '$count Rechnungen ausgestellt.';
  }

  @override
  String get eventTypeInvoicePayment => 'Rechnungszahlung';

  @override
  String eventInvoicePaid(String number, String amount) {
    return 'Rechnung $number bezahlt — $amount';
  }

  @override
  String get invoiceMatchAction => 'Als bezahlt markieren';

  @override
  String get invoiceMatchNoteLabel => 'Notiz';

  @override
  String get invoiceMatchNoteRequired => 'Eine Notiz ist erforderlich.';

  @override
  String invoiceMatchOver(String excess) {
    return 'Das Mitglied hat $excess mehr gezahlt.';
  }

  @override
  String get invoiceMatchCreditNote =>
      'Gutschrift über den Überschuss erstellen';

  @override
  String get invoiceMatchForce => 'Trotzdem akzeptieren (mit Begründung)';

  @override
  String invoiceMatchUnder(String missing) {
    return 'Das Mitglied hat $missing weniger gezahlt — Akzeptieren erfordert eine Notiz.';
  }

  @override
  String get invoiceMatched => 'Rechnung abgeglichen.';

  @override
  String get invoiceMatchPendingBadge => 'Wartet auf Validierung';

  @override
  String get invoiceMatchedBadge => 'Bezahlt';

  @override
  String get invoiceAlreadyInvoiced =>
      'Dieser Monat ist für dieses Mitglied bereits berechnet.';

  @override
  String get invoiceMatchPickPayment => 'Registrierte Zahlung auswählen';

  @override
  String get invoiceMatchNoPayments =>
      'Keine registrierte Zahlung zum Abgleich — zuerst erfassen oder bestätigen.';

  @override
  String get invoiceStatusOpen => 'Offen';

  @override
  String invoiceCountShown(int count) {
    return '$count Rechnungen';
  }

  @override
  String get invoiceFilterNoMatch =>
      'Keine Rechnung entspricht diesen Filtern.';

  @override
  String get invoiceFilterClear => 'Filter zurücksetzen';

  @override
  String get invoiceShowCancelled => 'Stornierte anzeigen';

  @override
  String invoiceReplacedBy(String number) {
    return 'Ersetzt durch $number';
  }

  @override
  String invoiceMatchSummary(String amount, String date) {
    return 'Bezahlt $amount am $date';
  }

  @override
  String invoiceRemindedLast(String date) {
    return 'letzte Mahnung $date';
  }

  @override
  String invoiceAnnexSummary(int movements, int checkIns) {
    return 'Anhang: $movements Bewegungen, $checkIns Check-ins';
  }

  @override
  String get invoicePickMember =>
      'Ein Mitglied wählen, um zu sehen, was dieser Monat erfasst hat.';

  @override
  String get invoiceRunningMonth =>
      'Dieser Monat läuft noch — seine Positionen können sich noch ändern, und ein Monat lässt sich nur einmal abrechnen.';

  @override
  String invoiceIssueAllConfirm(int count, String month, String total) {
    return '$count Rechnungen für $month über insgesamt $total ausstellen? Eine ausgestellte Rechnung lässt sich nicht mehr ändern — ein Fehler wird durch eine Ersatzrechnung korrigiert.';
  }

  @override
  String invoiceIssuedPartial(int issued, int failed) {
    return '$issued ausgestellt, $failed fehlgeschlagen.';
  }

  @override
  String get invoiceEInvoiceAction => 'E-Rechnung (XML)';

  @override
  String get invoiceEInvoiceExplain =>
      'Die maschinenlesbare EN-16931-Rechnung — die Datei, die Finanzverwaltungen und Geschäftskunden verlangen.';

  @override
  String invoiceEInvoiceBusinessRoute(String channel, String format) {
    return 'Geschäftskunden: über $channel als $format übermitteln.';
  }

  @override
  String invoiceEInvoicePublicRoute(String channel) {
    return 'Öffentliche Auftraggeber: $channel.';
  }

  @override
  String get invoiceEInvoiceTransportPeppol =>
      'Ein Access Point liefert sie an den Kunden — keine staatliche Plattform dazwischen.';

  @override
  String get invoiceEInvoiceTransportClearance =>
      'Die nationale Plattform erhält die Rechnung zuerst und leitet sie weiter — ein direkter Versand an den Kunden ist nicht möglich.';

  @override
  String get invoiceEInvoiceTransportAccredited =>
      'Eine zugelassene Plattform übermittelt die Rechnung und meldet die Daten an die Finanzverwaltung.';

  @override
  String get invoiceEInvoiceTransportBilateral =>
      'Kein Kanal ist vorgeschrieben: E-Mail, Portal oder Peppol — wie mit dem Kunden vereinbart.';

  @override
  String invoiceEInvoiceFormatMismatch(String channel, String format) {
    return '$channel akzeptiert nur $format: Diese EN-16931-Datei dient für Peppol, öffentliche Auftraggeber und ausländische Kunden — den Rest konvertiert die Plattform.';
  }

  @override
  String get invoiceEInvoiceReady => 'Bereit — diese Datei erfüllt EN 16931.';

  @override
  String get invoiceEInvoiceBlockedTitle =>
      'Ein Validator würde diese Datei ablehnen:';

  @override
  String get invoiceEInvoiceIncompleteTitle =>
      'Gültig, doch die strengen nationalen Profile wollen zusätzlich:';

  @override
  String get invoiceGapVatNotSupported =>
      'Der Space verlangt Mehrwertsteuer, diese Rechnung trägt aber keinen Satz — Sätze anlegen und die Rechnung neu ausstellen.';

  @override
  String get invoiceGapMissingVatId =>
      'Die Umsatzsteuer-Identifikationsnummer fehlt — ein steuerbefreiter Verkäufer muss sie angeben.';

  @override
  String get invoiceGapMissingLegalId =>
      'Die Registernummer fehlt (SIREN, HRB, CIF…) — nichts identifiziert dich auf der Rechnung.';

  @override
  String get invoiceGapMissingExemptionReason =>
      'Der Grund für die Steuerbefreiung fehlt.';

  @override
  String get invoiceGapMissingSellerCountry => 'Das Land des Workspace fehlt.';

  @override
  String get invoiceGapMissingBuyerCountry => 'Das Land des Kunden fehlt.';

  @override
  String get invoiceGapNoChargeLines =>
      'Diese Rechnung hat keine Belastungsposition — ihr Monat war vollständig durch Zahlungen gedeckt, es gibt nichts zu übermitteln.';

  @override
  String get invoiceGapMissingSellerCity => 'die Stadt der Workspace-Adresse';

  @override
  String get invoiceGapMissingSellerPostalCode =>
      'die Postleitzahl der Workspace-Adresse';

  @override
  String get invoiceEInvoiceFixIdentity =>
      'Rechtliche Identität vervollständigen';

  @override
  String get legalIdentityTitle => 'Rechtliche Identität & E-Rechnung';

  @override
  String get legalIdentitySubtitle =>
      'Steuerregime und Registernummern — von der E-Rechnung verlangt';

  @override
  String get legalIdentityIntro =>
      'Was eine EN-16931-E-Rechnung über dich aussagen muss. Bereits ausgestellte Rechnungen behalten die Identität, mit der sie signiert wurden.';

  @override
  String get legalIdentityRegime => 'Steuerregime';

  @override
  String get legalIdentityRegimeNotSubject =>
      'Nicht der Umsatzsteuer unterliegend';

  @override
  String get legalIdentityRegimeExempt =>
      'Umsatzsteuerfrei (Kleinunternehmerregelung)';

  @override
  String get legalIdentityRegimeVatRegistered =>
      'Umsatzsteuerpflichtig (berechnet USt.)';

  @override
  String get legalIdentityRegimeHint =>
      'Das Regime entscheidet, welche Nummer die Norm verlangt: eine Registernummer außerhalb der Umsatzsteuer, eine USt-IdNr. bei Steuerbefreiung.';

  @override
  String get legalIdentityVatId => 'Umsatzsteuer-ID';

  @override
  String get legalIdentityLegalId => 'Registernummer';

  @override
  String get legalIdentityExemptionReason => 'Grund der Steuerbefreiung';

  @override
  String get legalIdentityStreet => 'Straße';

  @override
  String get legalIdentityCity => 'Stadt';

  @override
  String get legalIdentityPostalCode => 'Postleitzahl';

  @override
  String get legalIdentitySaved => 'Rechtliche Identität gespeichert.';

  @override
  String get legalIdentityVatWarning =>
      'Dieser Space verlangt Mehrwertsteuer, es ist aber kein Satz angelegt: Rechnungen weisen keine Steuer aus und der XML-Export bleibt deaktiviert.';

  @override
  String get addressCountryLabel => 'Land';

  @override
  String get addressVatIdLabel =>
      'Umsatzsteuer-ID (wenn du als Unternehmen abrechnest)';

  @override
  String get invoiceProformaAction => 'Proforma-Rechnung';

  @override
  String get invoicePdfProforma => 'Proforma';

  @override
  String get invoiceProformaShared => 'Proforma geteilt.';

  @override
  String get invoiceProformaNothing =>
      'Für diesen Monat wurde nichts erfasst — keine Proforma zu senden.';

  @override
  String get invoicePdfCopy => 'Kopie';

  @override
  String get invoiceStatusPartiallyPaid => 'Teilweise bezahlt';

  @override
  String get invoiceRegisterTitle => 'Rechnungsregister';

  @override
  String get invoiceRegisterDate => 'Datum';

  @override
  String get invoiceRegisterName => 'Name';

  @override
  String get invoiceRegisterAmount => 'Betrag';

  @override
  String get invoiceRegisterTotal => 'Gesamt';

  @override
  String get invoiceFacturXDownload => 'Factur-X (PDF) herunterladen';

  @override
  String get invoiceFacturXShare => 'Factur-X (PDF) teilen';

  @override
  String get invoiceFacturXExplain =>
      'Eine Datei: die Rechnung für Menschen, mit dem maschinenlesbaren XML darin. Das erwarten die meisten Plattformen.';

  @override
  String get invoiceSendAction => 'An die Plattform senden';

  @override
  String get invoiceSendAccepted =>
      'Gesendet — die Plattform hat sie angenommen.';

  @override
  String get invoiceSendRejected => 'Die Plattform hat sie abgelehnt.';

  @override
  String invoiceSentOn(String date, String status) {
    return 'Gesendet am $date · $status';
  }

  @override
  String get invoiceSendStatusAccepted => 'angenommen';

  @override
  String get invoiceSendStatusRejected => 'abgelehnt';

  @override
  String get invoiceSendStatusFailed => 'nicht übermittelt';

  @override
  String get einvoiceConfigTitle => 'E-Rechnungs-Plattform';

  @override
  String get einvoiceConfigIntro =>
      'Wohin DesKilo deine Rechnungen sendet. Jede Plattform, die einen Upload mit Token annimmt, funktioniert — eine zugelassene Plattform, ein Peppol Access Point, eine nationale Plattform. Das Token liegt serverseitig und kommt nie zurück.';

  @override
  String get einvoiceConfigEndpoint => 'Upload-URL';

  @override
  String get einvoiceConfigToken => 'Token oder Zugangsdaten';

  @override
  String get einvoiceConfigHeader => 'Auth-Header (Standard Authorization)';

  @override
  String get einvoiceConfigField => 'Feldname der Datei (Standard file)';

  @override
  String get einvoiceConfigSaved => 'Plattform gespeichert.';

  @override
  String get einvoiceConfigCleared => 'Plattform entfernt.';

  @override
  String get einvoiceConfigClear => 'Plattform entfernen';

  @override
  String get einvoiceConfigTokenSet =>
      'Ein Token ist gespeichert (neues eingeben, um es zu ersetzen).';

  @override
  String get invoiceAccountingExport => 'Buchhaltungs-Export (SAF-T)';

  @override
  String get invoiceAccountingExportEmpty =>
      'Für diesen Zeitraum gibt es nichts zu exportieren.';

  @override
  String get invoiceRegisterYear => 'Jahr';

  @override
  String get invoiceRegisterAllYears => 'Alle Jahre';

  @override
  String get invoiceExportSafT => 'SAF-T (XML, international)';

  @override
  String get invoiceExportFec => 'FEC (Frankreich, im Prüfungsfall verlangt)';

  @override
  String get invoiceExportChoose => 'Buchhaltungs-Export';

  @override
  String get fecAccountsTitle => 'Zu buchende Konten';

  @override
  String get fecAccountsIntro =>
      'Ein FEC besteht aus Buchungen und braucht daher Kontonummern. Dies sind die Standardkonten des französischen Kontenrahmens — ersetze sie durch die deiner Buchhaltung.';

  @override
  String get fecAccountCustomers => 'Kunden';

  @override
  String get fecAccountRevenue => 'Erlöse';

  @override
  String get fecAccountBank => 'Bank';

  @override
  String get fecMissingSiren =>
      'Der FEC-Dateiname enthält die Registernummer — trage sie zuerst unter Rechtliche Identität ein.';

  @override
  String get invoiceEInvoiceStaleIdentity =>
      'Ihre rechtliche Identität ist jetzt vollständig, diese Rechnung wurde aber vorher signiert und behält, womit sie ausgestellt wurde. Als fehlerhaft markieren und eine Ersatzrechnung ausstellen, damit sie die neue Identität trägt.';

  @override
  String get einvoiceConfigUnavailable =>
      'Die Plattform-Einstellungen konnten nicht geladen werden. Verbindung prüfen und erneut versuchen.';

  @override
  String get einvoiceEnvTitle => 'An welche Plattform senden?';

  @override
  String get einvoiceEnvProd => 'Produktion';

  @override
  String get einvoiceEnvUat => 'UAT (Testplattform)';

  @override
  String get einvoiceEnvDev => 'Dev (Testplattform)';

  @override
  String get einvoiceEnvProdHint => 'Die echte Übermittlung.';

  @override
  String get einvoiceEnvTestHint =>
      'Eine Probe — als Testversand protokolliert.';

  @override
  String invoiceSendAcceptedTest(String env) {
    return 'Testversand angenommen ($env).';
  }

  @override
  String get einvoiceTestEnvsTitle => 'Testumgebungen (UAT / Dev)';

  @override
  String get einvoiceTestEnvsHelp =>
      'Eigene Endpunkte und Token für Proben. Die Auswahl erscheint beim Senden nur bei aktivem Entwicklermodus.';

  @override
  String get einvoiceUatEndpoint => 'UAT-Upload-URL';

  @override
  String get einvoiceUatToken => 'UAT-Token oder Zugangsdaten';

  @override
  String get einvoiceDevEndpoint => 'Dev-Upload-URL';

  @override
  String get einvoiceDevToken => 'Dev-Token oder Zugangsdaten';

  @override
  String get invoiceSentTestChip => 'Test';

  @override
  String get invoiceTemplateTitle => 'Rechnungs-PDF-Vorlage';

  @override
  String get invoiceTemplateHint =>
      'Drei Berichtsbänder auf dem PDF — das E-Rechnungs-XML bleibt unangetastet. Liquid-Bedingungen und -Schleifen, dann Zeilen-Markup:';

  @override
  String get invoiceTemplateIntroLabel =>
      'Einleitung (über dem Empfängerblock)';

  @override
  String get invoiceTemplateFooterLabel =>
      'Fußtext (unter den Summen — Zahlungsbedingungen, Pflichtangaben)';

  @override
  String get invoiceTemplateSaved => 'Rechnungsvorlage gespeichert.';

  @override
  String get invoiceTemplateHeaderLabel => 'Kopfband';

  @override
  String get invoiceTemplateBodyLabel => 'Rumpfband (die Rechnungszeilen)';

  @override
  String get invoiceTemplateReset => 'Auf Standard zurücksetzen';

  @override
  String get invoiceTemplatePreview => 'Vorschau';

  @override
  String get invoiceTemplateNoPreview =>
      'Stelle zuerst eine Rechnung aus — die Vorschau rendert die neueste.';

  @override
  String get reminderPdfTitleFriendly => 'Zahlungserinnerung';

  @override
  String get reminderPdfTitleFirm => 'Mahnung';

  @override
  String get reminderPdfOpeningFriendly =>
      'dies ist eine freundliche Erinnerung: die untenstehende Rechnung ist noch offen. Sicher nur übersehen — kein Problem.';

  @override
  String get reminderPdfOpeningFirm =>
      'trotz unserer vorherigen Mahnung ist die untenstehende Rechnung weiterhin unbezahlt. Bitte begleichen Sie den Betrag umgehend.';

  @override
  String get reminderPdfDaysOpen => 'Offen seit';

  @override
  String get reminderPdfDays => 'Tagen';

  @override
  String get reminderPdfLevelLabel => 'Mahnstufe';

  @override
  String get reminderPdfClosing =>
      'Sollten Sie bereits gezahlt haben, betrachten Sie dieses Schreiben bitte als gegenstandslos.';

  @override
  String get dunningSettingsTitle => 'Mahnregeln';

  @override
  String get dunningLevels => 'Anzahl der Mahnstufen';

  @override
  String get dunningFirstAfterDays => 'Tage bis zur ersten Erinnerung';

  @override
  String get dunningBetweenDays => 'Tage zwischen den Mahnungen';

  @override
  String get dunningSaved => 'Mahnregeln gespeichert.';

  @override
  String dunningDueChip(int level) {
    return 'Mahnstufe $level fällig';
  }

  @override
  String get invoiceTemplateDocInvoice => 'Rechnung';

  @override
  String invoiceTemplateDocReminder(int level) {
    return 'Mahnung $level';
  }

  @override
  String get reportPreviewTitle => 'Schnellvorschau — deine neueste Rechnung';

  @override
  String get reportPreviewSimulated => 'Schnellvorschau — Beispieldaten';

  @override
  String get reportPresetClassic => 'Klassisch';

  @override
  String get reportPresetFormalLetter => 'Formeller Brief';

  @override
  String get reportSubject => 'Betreff';

  @override
  String get reportRegards => 'Mit freundlichen Grüßen';

  @override
  String get invoiceTemplatePresets => 'Vorlagen';

  @override
  String get invoiceTemplateQuickPreview => 'Schnellvorschau';

  @override
  String get invoiceTemplateDownload => 'PDF herunterladen';

  @override
  String get invoiceTemplateShare => 'PDF teilen';

  @override
  String get invoiceTemplateDocStatement => 'Abrechnung';

  @override
  String get reportPresetSimple => 'Einfach';

  @override
  String get reportPresetVerbose => 'Ausführlich';

  @override
  String get invoiceLegalSection => 'Rechnungsangaben';

  @override
  String get invoiceLegalIntro =>
      'Die Pflichtangaben auf Rechnungen und Mahnungen. Leere Zahlungsklauseln verwenden die gesetzlichen Standardtexte.';

  @override
  String get invoiceLegalFormField => 'Rechtsform & Kapital';

  @override
  String get invoiceLegalFormHint => 'z. B. SARL au capital de 7 500 €';

  @override
  String get invoiceLegalRegistrationField => 'Handelsregister';

  @override
  String get invoiceLegalRegistrationHint =>
      'z. B. RCS Saint-Brieuc 680 357 910';

  @override
  String get invoiceLegalPaymentTermsField => 'Zahlungsbedingungen';

  @override
  String get invoiceLegalLatePenaltyField => 'Verzugszinsen';

  @override
  String get invoiceLegalRecoveryField => 'Pauschale für Beitreibungskosten';

  @override
  String get invoiceLegalEscompteField => 'Skonto';

  @override
  String get invoiceLegalInsuranceField => 'Berufshaftpflicht';

  @override
  String get invoiceLegalSpecialField => 'Besondere Angaben';

  @override
  String get invoiceLegalPaymentTermsDefault => 'Zahlbar sofort nach Erhalt.';

  @override
  String get invoiceLegalLatePenaltyDefault =>
      'Verzugszinsen: dreifacher gesetzlicher Zinssatz.';

  @override
  String get invoiceLegalRecoveryDefault =>
      'Pauschale für Beitreibungskosten: 40 €.';

  @override
  String get invoiceLegalEscompteDefault =>
      'Kein Skonto bei vorzeitiger Zahlung.';

  @override
  String get reportColUnitPrice => 'Einzelpreis';

  @override
  String get reportColQty => 'Menge';

  @override
  String get reportColTotal => 'Gesamt';

  @override
  String get invoiceLegalKindField => 'Organisationsform';

  @override
  String get invoiceLegalKindCompany => 'Unternehmen';

  @override
  String get invoiceLegalKindAssociation => 'Verein (gemeinnützig)';

  @override
  String get invoiceLegalAssociationHint =>
      'Verzugszins-, Beitreibungs- und Skonto-Klauseln werden nur gedruckt, wenn ausgefüllt — sie sind nur zwischen Unternehmen Pflicht.';

  @override
  String get invoiceLegalFormHintAssociation =>
      'z. B. Association loi 1901 / e. V.';

  @override
  String get invoiceLegalRegistrationHintAssociation =>
      'z. B. RNA W123456789 · SIRET falls vergeben';

  @override
  String get invoiceLegalAssociationReasonHint =>
      'z. B. „TVA non applicable, art. 293 B du CGI“ — oder „Exonération de TVA, art. 261, 7-1° du CGI“ für Leistungen an Mitglieder';

  @override
  String get reportEditorMarkup => 'Markup';

  @override
  String get reportEditorVisual => 'Visuell';

  @override
  String get reportInsertImage => 'Bild einfügen';

  @override
  String get reportImagesTitle => 'Berichtsbilder';

  @override
  String get reportImagesEmpty =>
      'Noch kein Bild — laden Sie Ihr Logo, einen Stempel oder eine Unterschrift hoch und referenzieren Sie es mit ![name].';

  @override
  String get reportImageUpload => 'Bild hochladen';

  @override
  String get reportVisualAddLine => 'Zeile hinzufügen';

  @override
  String get reportLineTitle => 'Titel';

  @override
  String get reportLineSection => 'Abschnitt';

  @override
  String get reportLineText => 'Text';

  @override
  String get reportLineSmall => 'Kleingedrucktes';

  @override
  String get reportLineRow => 'Tabellenzeile';

  @override
  String get reportLineBoldRow => 'Fette Zeile';

  @override
  String get reportLineDivider => 'Trenner';

  @override
  String get reportLineSpacer => 'Abstand';

  @override
  String get reportLineImage => 'Bild';

  @override
  String get reportLineColumns => 'Spalten Anfang/Ende';

  @override
  String get reportLineColumnsSplit => 'Spaltenumbruch';

  @override
  String get reportLineLogic => 'Logik';

  @override
  String get reportDocAgreement => 'Finanzvereinbarung';

  @override
  String get reportDocPayments => 'Zahlungsbericht';

  @override
  String get reportDocWorkspace => 'Arbeitsbereichsbericht';

  @override
  String get agreementExtraHalfDay => 'Zusätzlicher halber Tag';

  @override
  String get paymentsPendingTag => 'wartet auf Validierung';

  @override
  String get reportSectionFeatures => 'Funktionen';

  @override
  String get reportSectionPrices => 'Preise';

  @override
  String get moneyMyAgreement => 'Meine Konditionen';

  @override
  String get memberSendAgreement => 'Finanzvereinbarung senden';

  @override
  String get reportQuickView => 'Schnellansicht';

  @override
  String get reportDocWorkspaceSubtitle =>
      'Alles über den Arbeitsbereich — über die Arbeitsbereichsvorlage des Berichtseditors';

  @override
  String get reportTemplateLangDefault => 'Standard (alle Sprachen)';

  @override
  String get reportLanguageAmbiguous =>
      'Dieses Land hat mehrere Sprachen — legen Sie zuerst die Arbeitsbereichssprache in den Einstellungen fest.';

  @override
  String get reportDesignEmpty =>
      'Leeres Band — fügen Sie unten ein Element hinzu.';

  @override
  String get invoiceStatusRemainderCancelled =>
      'Teilweise bezahlt · Restbetrag storniert';

  @override
  String get invoiceRemainingLabel => 'Restbetrag';

  @override
  String get invoiceWriteoffButton => 'Restbetrag stornieren';

  @override
  String get invoiceWriteoffExplain =>
      'Der offene Restbetrag dieser Rechnung wird storniert und die Rechnung als teilweise bezahlt archiviert — sobald die Validierung bestätigt. Bis dahin bleibt sie offen und geschuldet.';

  @override
  String get invoiceWriteoffRequested =>
      'Stornierung beantragt — wartet auf Validierung.';

  @override
  String get eventTypeInvoiceWriteoff => 'Restbetrag-Stornierung';

  @override
  String eventInvoiceWriteoffLine(String actor, String number, String amount) {
    return '$actor bittet um Stornierung des Restbetrags von $number — $amount';
  }

  @override
  String get invoicePdfCreditNote => 'Gutschrift';

  @override
  String get invoiceStatusRefunded => 'Erstattet';

  @override
  String get invoiceRefundLabel => 'Zu erstatten';

  @override
  String get invoiceRefundButton => 'Erstattung erfassen';

  @override
  String invoiceRefundExplain(String amount) {
    return 'Diese Gutschrift bedeutet: der ARBEITSBEREICH schuldet dem Mitglied $amount. Erfassen Sie die ausgezahlte Erstattung — der Betrag wird gegen das Mitgliedskonto gebucht und das Dokument schließt als Erstattet.';
  }

  @override
  String get invoiceRefunded => 'Erstattung erfasst.';

  @override
  String invoiceSummaryToRefund(int count, String amount) {
    return '$count zu erstatten · $amount';
  }

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
  String get kioskConfirmAction => 'Bestätigen';

  @override
  String get kioskRejectAction => 'Ablehnen';

  @override
  String get kioskGateTitle => 'Kiosk-Modus starten?';

  @override
  String get kioskGateBody =>
      'Dieses Konto ist als Kiosk des Workspace eingerichtet. Im Kiosk-Modus zeigt das Tablet nur den Raumplan für das Einchecken per Badge — sonst lässt sich nichts öffnen. Zum Verlassen des Kiosk-Modus das Tablet neu starten.';

  @override
  String get kioskGateStart => 'Kiosk-Modus starten';

  @override
  String get kioskGateReject => 'Jetzt nicht — App normal öffnen';

  @override
  String get settingsFrontCamera => 'Mit der Frontkamera scannen';

  @override
  String get settingsFrontCameraDesc =>
      'Badges werden mit der Kamera auf der Bildschirmseite gelesen — ausschalten für die Rückkamera.';

  @override
  String get kioskNfcOff =>
      'NFC ist in den Android-Einstellungen dieses Tablets ausgeschaltet — zum Lesen von RFID-Karten einschalten.';

  @override
  String get kioskNfcUnsupported =>
      'Dieses Tablet hat keinen NFC-Leser — stattdessen den QR-Badge scannen.';

  @override
  String get kioskNfcFailed =>
      'Der RFID-Leser ist nicht gestartet — App neu starten und erneut versuchen.';

  @override
  String get nfcConfigDeviceOff =>
      'NFC ist in den Android-Einstellungen dieses Geräts ausgeschaltet — zum Lesen von RFID-Karten einschalten.';

  @override
  String get kioskScanQr => 'QR-Badge scannen';

  @override
  String get kioskRevertTitle => 'Kiosk-Gerät';

  @override
  String get kioskRevertDesc =>
      'Dieses Profil ist als Kiosk des Workspace eingerichtet. Als reguläres Mitglied zurücksetzen, damit die Kiosk-Frage beim Start nicht mehr erscheint.';

  @override
  String get kioskRevertDone =>
      'Dieses Profil ist wieder ein reguläres Mitglied.';

  @override
  String get memberNoActions =>
      'Nur der Inhaber des Workspace kann dieses Mitglied ändern.';

  @override
  String get kioskNotCheckedIn =>
      'Kein aktiver Check-in gefunden — der Plan hat sich womöglich gerade aktualisiert.';

  @override
  String get kioskRestOfDay => 'Rest des Tages';

  @override
  String get kioskPeriodCheckInHint =>
      'Bis wann bleibst du? Das Einchecken beginnt jetzt.';

  @override
  String get kioskPeriodReserveHint => 'Wähle den Zeitraum — nur heute.';

  @override
  String get kioskCheckInRightAway => 'Sofort einchecken';

  @override
  String get kioskCheckInRightAwayHint =>
      'Du bist da — die Reservierung startet eingecheckt.';

  @override
  String get kioskPresentBadgeNext => 'Badge vorzeigen';

  @override
  String get kioskReserveAndCheckIn => 'Reservieren & einchecken';

  @override
  String get badgeDeleteConfirm =>
      'Dieses widerrufene Badge endgültig löschen?';

  @override
  String get kioskClosedToday =>
      'Der Workspace ist heute geschlossen — Check-in und Reservierungen sind nicht möglich.';

  @override
  String kioskBasis(String granularity, String hours) {
    return 'Regel: $granularity · heute $hours';
  }

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
  String get levelPermissionAllowed =>
      'Darf einen ganzen Tisch, ein Büro oder eine Etage reservieren';

  @override
  String get levelPermissionDenied =>
      'Darf keinen ganzen Tisch, kein Büro und keine Etage reservieren';

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
  String get levelNotAllowed =>
      'Sie dürfen keinen ganzen Tisch, kein Büro und keine ganze Etage reservieren.';

  @override
  String get levelConflict =>
      'Die Etage hat Reservierungen in diesem Zeitraum.';

  @override
  String get bookingOnePlace =>
      'Du hast in diesem Zeitraum bereits eine Buchung — ein Platz zur Zeit.';

  @override
  String get bookingCheckedInElsewhere =>
      'Du bist woanders eingecheckt — checke dort zuerst aus.';

  @override
  String get spaceNotWholeBookable =>
      'Dieser Bereich ist nicht für Ganzbuchung eingerichtet — die Inhaberin aktiviert dafür „Als Ganzes buchbar“ im Editor.';

  @override
  String get levelFeatureOff =>
      'Büro- & Etagen-Reservierungen sind in den Funktionen ausgeschaltet.';

  @override
  String get levelDetail => 'Ganze Etage';

  @override
  String get kioskLevelButton => 'Diese Etage';

  @override
  String get officeSupplementLabel => 'Büro-Reservierungen';

  @override
  String get eventTypeSpaceReservation => 'Ganzraum-Reservierungen';

  @override
  String get deskDetail => 'Ganzer Tisch';

  @override
  String get deskSupplementLabel => 'Tisch-Reservierungen';

  @override
  String get editorLevelBookableOn => 'Als Ganzes buchbar';

  @override
  String get editorLevelBookableOff => 'Nicht als Ganzes buchbar';

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
  String get noteRefGone => 'Diese Reservierung existiert nicht mehr.';

  @override
  String get memberNoteDelete => 'Löschen';

  @override
  String get memberNoteDeleteConfirm =>
      'Diese Nachricht löschen? Das lässt sich nicht rückgängig machen.';

  @override
  String get memberNoteReply => 'Antworten';

  @override
  String get noteRefReservation => 'Reservierung verknüpfen';

  @override
  String get noteRefSpace => 'Raum verknüpfen';

  @override
  String get noteRefNoReservations =>
      'Keine kommenden Reservierungen zum Verknüpfen.';

  @override
  String get noteRefWholeLevel => 'ganze Etage';

  @override
  String get memberMessagesAction => 'Nachrichten';

  @override
  String get conversationEmpty => 'Noch keine Nachrichten — sag hallo!';

  @override
  String get whatsappNotesTitle => 'Nachrichten auf WhatsApp erhalten';

  @override
  String get whatsappNotesSubtitle =>
      'Mitglieder-Nachrichten kommen auch auf WhatsApp an, samt Links — der DesKilo-Link öffnet die Unterhaltung in der App.';

  @override
  String get messageLinkGone => 'Diese Nachricht liegt in deinem Posteingang.';

  @override
  String get whatsappNotesUnconfigured =>
      'Der WhatsApp-Kanal des Space ist noch nicht konfiguriert (Inhaber: WHATSAPP_TOKEN + WHATSAPP_PHONE_ID) — bis dahin kommen Nachrichten nur in der App und per Push an.';

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
  String get moneyPaymentDateLabel => 'Zahlungsdatum';

  @override
  String get moneyPaymentPeriodLabel => 'Gilt für';

  @override
  String get moneySectionPay => 'Zahlen';

  @override
  String get moneySectionRequests => 'Anträge';

  @override
  String get moneySectionDocuments => 'Dokumente';

  @override
  String get vatDeclTitle => 'Umsatzsteuer-Voranmeldung';

  @override
  String get vatDeclPeriod => 'Zeitraum';

  @override
  String get vatDeclSeller => 'Verkäufer';

  @override
  String get vatDeclVatId => 'USt-IdNr.';

  @override
  String get vatDeclRate => 'Steuersatz';

  @override
  String get vatDeclNet => 'Bemessungsgrundlage';

  @override
  String get vatDeclVat => 'USt';

  @override
  String get vatDeclInvoices => 'Rechnungen';

  @override
  String get vatDeclTotals => 'Summen';

  @override
  String get vatDeclBoxes => 'Kennzahlen des amtlichen Formulars';

  @override
  String get vatDeclBox => 'Kz';

  @override
  String get vatDeclStatus => 'Status';

  @override
  String get vatDeclDisclaimer =>
      'Aus den ausgestellten Rechnungen des Zeitraums erzeugt. Vor der Abgabe mit der Buchhaltung abgleichen — eine Abgabehilfe, keine Steuerberatung.';

  @override
  String get vatDeclGenerate => 'Erstellen';

  @override
  String get vatDeclEmpty =>
      'Noch keine Voranmeldungen — Zeitraum wählen und die erste erstellen.';

  @override
  String get vatDeclDraft => 'Entwurf';

  @override
  String get vatDeclSubmitted => 'Übermittelt';

  @override
  String get vatDeclTransmit => 'Übermitteln';

  @override
  String get vatDeclMarkFiled => 'Als abgegeben markieren';

  @override
  String get vatDeclMarkFiledConfirm =>
      'Bestätige, dass du diese Voranmeldung selbst abgegeben hast (ELSTER/Portal oder Steuerberater). Sie wird unveränderlich.';

  @override
  String get vatDeclXml => 'XML-Export';

  @override
  String get vatDeclPdf => 'PDF';

  @override
  String get vatDeclSent => 'Voranmeldung übermittelt.';

  @override
  String get vatDeclRejected => 'Die Plattform hat die Voranmeldung abgelehnt.';

  @override
  String get vatDeclRegimeGate =>
      'Voranmeldungen gibt es nur unter dem umsatzsteuerpflichtigen Regime — in den USt-Einstellungen konfigurieren.';

  @override
  String get featureVatDeclarationsTitle => 'USt-Voranmeldungen';

  @override
  String get featureVatDeclarationsDesc =>
      'Die periodische USt-Voranmeldung aus den Rechnungen erzeugen, auf das amtliche Formular abbilden und übermitteln oder exportieren.';

  @override
  String priceVatIncluded(String rate) {
    return 'inkl. $rate USt';
  }

  @override
  String billingPricesVatHint(String rate) {
    return 'Preise sind brutto — die USt $rate (Standardsatz des Space) ist enthalten.';
  }

  @override
  String get billingNewPackage => 'Neues Paket';

  @override
  String get priceGrossHint =>
      'Bruttopreis — was das Mitglied zahlt; die USt steckt darin.';

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
  String get planCheckInNotYetError =>
      'Einchecken ist ab 15 Minuten vor Beginn möglich.';

  @override
  String get planCheckInOverError =>
      'Diese Reservierung ist vorbei — Einchecken ist nicht mehr möglich.';

  @override
  String planCheckInOpensAt(String time) {
    return 'Einchecken ab $time möglich';
  }

  @override
  String planCheckInFor(String name) {
    return '$name einchecken';
  }

  @override
  String get planOverruleRemove => 'Reservierung entfernen (übersteuern)';

  @override
  String planOverruleHint(String name) {
    return '$name und alle Admins werden benachrichtigt.';
  }

  @override
  String planOverruleDone(String name) {
    return 'Reservierung entfernt — $name wurde benachrichtigt.';
  }

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
  String get a11ySeatFree => 'frei';

  @override
  String get a11ySeatReserved => 'reserviert';

  @override
  String get a11ySeatOccupied => 'besetzt';

  @override
  String get a11ySeatMine => 'dein Platz';

  @override
  String get a11ySeatBlocked => 'nicht verfügbar';

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
  String get settingsBillingReports => 'Abrechnung & Berichte';

  @override
  String get profilesDefault => 'Standard beim Start';

  @override
  String get profilesMakeDefault => 'Beim Start als Standard verwenden';

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
  String get memberNotifyAction => 'Benachrichtigung senden';

  @override
  String get memberNotifyAllAdmins => 'Alle Admins benachrichtigen';

  @override
  String get memberAllAdmins => 'alle Admins';

  @override
  String memberNoteTitle(String name) {
    return '$name benachrichtigen';
  }

  @override
  String get memberNoteHint => 'Deine Nachricht';

  @override
  String get memberNoteSend => 'Senden';

  @override
  String get memberNoteSent => 'Benachrichtigung gesendet.';

  @override
  String memberNoteReceived(String name) {
    return 'Nachricht von $name';
  }

  @override
  String get eventsMessagesHeader => 'Nachrichten';

  @override
  String memberNoteTo(String name) {
    return 'An $name';
  }

  @override
  String get memberNoteToAllAdmins => 'An alle Admins';

  @override
  String get memberNoteDeleted => 'Nachricht gelöscht.';

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
  String get spaceScanTitle => 'Raumcode scannen';

  @override
  String get spaceScanHint =>
      'Kamera auf die Karte eines Platzes, Tischs, Büros oder einer Etage richten — oder den Code eintippen.';

  @override
  String get spaceScanField => 'Code';

  @override
  String get spaceScanInvalid => 'Kein Raumcode dieses Workspace.';

  @override
  String get spaceScanUnknown => 'Dieser Code passt zu keinem Raum mehr.';

  @override
  String get spaceSeatTaken => 'Belegt';

  @override
  String get spaceNotBookable =>
      'Dieser Raum ist nicht für Ganzraum-Reservierungen eingerichtet.';

  @override
  String get spaceCodesTitle => 'Raum-QR-Codes (PDF)';

  @override
  String get spaceCodesDesc =>
      'Eine druckbare QR-Karte je Platz, Tisch, Büro und Etage — Mitglieder scannen sie zum Reservieren oder Einchecken.';

  @override
  String get spaceKindDesk => 'Tisch';

  @override
  String get spaceKindOffice => 'Büro';

  @override
  String get spaceKindLevel => 'Etage';

  @override
  String get spaceKindSeat => 'Platz';

  @override
  String get spaceYoursNow => 'Von dir für dieses Zeitfenster reserviert.';

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
  String get vatTitle => 'Mehrwertsteuer';

  @override
  String get vatIntro =>
      'Preise in DesKilo sind Bruttopreise. Sätze anzulegen ändert nichts daran, was Mitglieder zahlen — die Steuer wird aus dem bestehenden Preis herausgerechnet und auf der Rechnung ausgewiesen.';

  @override
  String get vatRegimeHint =>
      'Dieser Space ist nicht als umsatzsteuerpflichtig deklariert, Rechnungen weisen daher keine Steuer aus. Das ändert sich unter Rechtliche Identität.';

  @override
  String get vatEmpty =>
      'Noch kein Satz — Rechnungen weisen keine Mehrwertsteuer aus.';

  @override
  String get vatSeed => 'Übliche Sätze übernehmen';

  @override
  String get vatAddRate => 'Satz hinzufügen';

  @override
  String get vatRateLabelField => 'Name';

  @override
  String get vatRatePercentField => 'Satz %';

  @override
  String get vatRateDefaultTooltip =>
      'Standardsatz — gilt für Abos und alles ohne eigenen Satz';

  @override
  String get vatRateRemoveTooltip => 'Entfernen';

  @override
  String get vatSaved => 'Steuersätze gespeichert.';

  @override
  String get vatNeedsDefault => 'Genau einen Satz als Standard markieren.';

  @override
  String get vatRateIncomplete =>
      'Jeder Satz braucht einen Namen und einen Prozentwert zwischen 0 und 99,99.';

  @override
  String get vatRatesTile => 'Steuersätze';

  @override
  String get vatAccountField => 'Steuerkonto';

  @override
  String get vatAccountHint =>
      'Konto, auf das der Buchhaltungsexport die vereinnahmte Steuer bucht. Leer = 445710.';

  @override
  String get vatServiceRate => 'Steuersatz';

  @override
  String get vatServiceRateDefault => 'Standard des Spaces';

  @override
  String get vatPdfNet => 'Netto';

  @override
  String get vatPdfVat => 'MwSt.';

  @override
  String get fecAccountVat => 'Vereinnahmte Steuer';

  @override
  String get vatKeptRate =>
      'Ein Satz, den eine Rechnung oder eine Leistung noch nutzt, bleibt erhalten und wird deaktiviert.';

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
  String get workspaceExcelExport => 'Daten exportieren (Excel)';

  @override
  String get workspaceExcelExportSubtitle =>
      'Alle Daten in einer Arbeitsmappe: Buchungen, Zahlungen, Rechnungen, Mitglieder und Plan — je ein Tab.';

  @override
  String get workspaceLanguageLabel => 'Sprache des Arbeitsbereichs';

  @override
  String get workspaceLanguageHelper =>
      'Einladungen werden standardmäßig in dieser Sprache verfasst.';

  @override
  String get workspaceLanguageUnset => 'App-Sprache des Absenders';

  @override
  String get workspacePaymentsBillingTitle => 'Zahlungen & Abrechnung';

  @override
  String get paymentMethodsSubtitle =>
      'IBAN, PayPal, Wero, Lydia, Wise und der Verwendungszweck';

  @override
  String get featureDocuments => 'Dokumentbibliothek';

  @override
  String get featureDocumentsDesc =>
      'Die Dokumentbibliothek des Arbeitsbereichs: Satzung, Anleitungen, Finanzberichte, Protokolle — aus jedem Drive verlinkt, sichtbar je nach Rolle.';

  @override
  String get documentsTitle => 'Dokumente';

  @override
  String get documentsAdd => 'Dokument hinzufügen';

  @override
  String get documentsTitleLabel => 'Titel';

  @override
  String get documentsUrlLabel => 'Link (https://…)';

  @override
  String get documentsUrlHelper =>
      'Fügen Sie den Freigabelink Ihres Drives ein — die Zugriffsrechte bleiben dort verwaltet.';

  @override
  String get documentsProviderLabel => 'Gespeichert auf';

  @override
  String get documentsCategoryLabel => 'Kategorie';

  @override
  String get documentsRoleLabel => 'Sichtbar für';

  @override
  String get documentsRoleMember => 'Alle Mitglieder';

  @override
  String get documentsRoleAdmin => 'Admins und Inhaber';

  @override
  String get documentsRoleOwner => 'Nur Inhaber';

  @override
  String get documentsCategoryStatutes => 'Satzung & Rechtliches';

  @override
  String get documentsCategoryGuides => 'Anleitungen & Handbücher';

  @override
  String get documentsCategoryFinance => 'Finanzberichte';

  @override
  String get documentsCategoryMinutes => 'Protokolle';

  @override
  String get documentsCategoryOther => 'Weitere Dokumente';

  @override
  String get documentsEmpty =>
      'Noch kein Dokument. Verlinken Sie Satzung, Anleitungen und Berichte aus jedem Drive.';

  @override
  String get documentsDelete => 'Dokument entfernen?';

  @override
  String get documentsInvalid =>
      'Ein Dokument braucht einen Titel und einen https://-Link.';

  @override
  String get featureRoleManagement => 'Rollenverwaltung';

  @override
  String get featureRoleManagementDesc =>
      'Die zentrale Rolle→Berechtigung-Matrix: Die Inhaberin entscheidet, welche Rolle welche Berechtigung hält; alle anderen lesen ihre eigenen. Aus: Es gelten einfach die Standardwerte.';

  @override
  String get rolesTitle => 'Rollenverwaltung';

  @override
  String get rolesIntroEditor =>
      'Die Inhaberin hält immer alle Berechtigungen. Lege hier fest, was die anderen Rollen dürfen — ein Co-Inhaber kann weniger halten als ein Inhaber.';

  @override
  String get rolesIntroReadOnly =>
      'Nur lesen: Das sind die Berechtigungen jeder Rolle. Deine Rolle ist hervorgehoben.';

  @override
  String get rolesYourRole => 'Deine Rolle';

  @override
  String get roleOwner => 'Inhaber';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleMember => 'Mitglied';

  @override
  String get permManageRoles => 'Rollen & Berechtigungen verwalten';

  @override
  String get permManageMembers => 'Mitglieder verwalten';

  @override
  String get permManageValidation => 'Validierungsregeln konfigurieren';

  @override
  String get permWorkspaceSettings => 'Workspace-Einstellungen bearbeiten';

  @override
  String get permIssueInvoices => 'Rechnungen ausstellen & Zahlungen zuordnen';

  @override
  String get permViewFinances => 'Workspace-Finanzen einsehen';

  @override
  String get permManageDocuments => 'Dokumentbibliothek verwalten';

  @override
  String get permManageServices => 'Services & Pakete verwalten';

  @override
  String get permApproveExpenses => 'Ausgaben genehmigen';

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
