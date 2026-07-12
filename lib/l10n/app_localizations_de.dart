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
  String get authDisplayNameLabel => 'Anzeigename';

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
  String get languageTitle => 'Sprache';

  @override
  String get languageSystemDefault => 'Systemstandard';

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
