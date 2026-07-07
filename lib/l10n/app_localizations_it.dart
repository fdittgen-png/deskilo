// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get authSignInTitle => 'Accedi';

  @override
  String get authSignUpTitle => 'Crea account';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authDisplayNameLabel => 'Nome visualizzato';

  @override
  String get authSignInButton => 'Accedi';

  @override
  String get authSignUpButton => 'Crea account';

  @override
  String get authToggleToSignUp => 'Nuovo qui? Crea un account';

  @override
  String get authToggleToSignIn => 'Hai già un account? Accedi';

  @override
  String get authFieldRequired => 'Obbligatorio';

  @override
  String get authPasswordTooShort => 'Almeno 8 caratteri';

  @override
  String get authGenericError =>
      'Autenticazione non riuscita. Controlla le credenziali e riprova.';

  @override
  String get authSignOut => 'Esci';

  @override
  String get calendarMineTab => 'Le mie';

  @override
  String get calendarEveryoneTab => 'Tutti';

  @override
  String get calendarNoReservations => 'Nessuna prenotazione in questo giorno.';

  @override
  String get calendarCancelOccurrence => 'Annulla questa occorrenza';

  @override
  String get calendarCancelFollowing => 'Annulla questa e le successive';

  @override
  String get calendarPreviousMonth => 'Mese precedente';

  @override
  String get calendarNextMonth => 'Mese successivo';

  @override
  String get calendarReservationActions => 'Azioni della prenotazione';

  @override
  String get appTitle => 'DesKilo';

  @override
  String get tabPlan => 'Piantina';

  @override
  String get tabCalendar => 'Calendario';

  @override
  String get tabEvents => 'Eventi';

  @override
  String get tabMoney => 'Finanze';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get comingSoon => 'Prossimamente';

  @override
  String get editorTitle => 'Editor dello spazio';

  @override
  String get editorOpenTooltip => 'Modifica spazio';

  @override
  String get editorAddLevel => 'Aggiungi piano';

  @override
  String get editorNoLevels =>
      'Ancora nessun piano. Aggiungi il primo piano del tuo spazio.';

  @override
  String get editorLevelNameLabel => 'Nome del piano';

  @override
  String get editorRenameLevel => 'Rinomina';

  @override
  String get editorLevelActions => 'Azioni del piano';

  @override
  String get editorDeleteLevelConfirm =>
      'Eliminare questo piano? Tutti gli uffici, le scrivanie e i posti su di esso verranno rimossi.';

  @override
  String get editorToolSelect => 'Seleziona';

  @override
  String get editorToolOffice => 'Ufficio';

  @override
  String get editorToolDesk => 'Scrivania';

  @override
  String get editorToolErase => 'Cancella';

  @override
  String get editorNewOffice => 'Nuovo ufficio';

  @override
  String get editorOfficeNameLabel => 'Nome dell\'ufficio';

  @override
  String get editorOfficeNameDefault => 'Ufficio';

  @override
  String get editorDeskNameDefault => 'Scrivania';

  @override
  String get editorDeskNameLabel => 'Nome della scrivania';

  @override
  String get editorPlacementOverlap => 'Si sovrappone a un elemento esistente.';

  @override
  String get editorPlacementOutside =>
      'Deve trovarsi completamente all\'interno di un ufficio.';

  @override
  String get editorOfficeProperties => 'Ufficio';

  @override
  String get editorDeskProperties => 'Scrivania';

  @override
  String get editorBookableAsWhole => 'Prenotabile per intero';

  @override
  String get editorDeleteElementConfirm =>
      'Eliminare questo elemento? Anche tutto ciò che vi è posizionato sopra verrà rimosso.';

  @override
  String get editorToolSeat => 'Posto';

  @override
  String get editorSeatProperties => 'Posto';

  @override
  String get editorSeatNameLabel => 'Nome del posto';

  @override
  String get editorSeatNameDefault => 'Posto';

  @override
  String get editorOrientationLabel => 'Direzione di seduta';

  @override
  String get editorChairLabel => 'Tipo di sedia';

  @override
  String get editorAmenitiesLabel => 'Dotazioni';

  @override
  String get editorBlockedLabel => 'Bloccato (manutenzione)';

  @override
  String get editorSeatNoDesk =>
      'I posti possono essere collocati solo su una scrivania.';

  @override
  String get amenityMonitor => 'Monitor';

  @override
  String get amenityStandingDesk => 'Scrivania in piedi';

  @override
  String get amenityWindow => 'Vicino alla finestra';

  @override
  String get amenityDock => 'Docking station';

  @override
  String get amenityErgonomicChair => 'Sedia ergonomica';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get eventsPendingHeader => 'In attesa della tua conferma';

  @override
  String get eventAccept => 'Accetta';

  @override
  String get eventReject => 'Rifiuta';

  @override
  String get eventsEmpty => 'Ancora nessun evento.';

  @override
  String get eventsFilterAll => 'Tutti';

  @override
  String get eventTypeReservation => 'Prenotazione';

  @override
  String get eventTypePayment => 'Pagamento';

  @override
  String get eventTypeExpense => 'Spesa';

  @override
  String get eventTypeAdjustment => 'Rettifica';

  @override
  String eventReservationCreated(String actor, String target) {
    return '$actor ha prenotato $target';
  }

  @override
  String eventReservationModified(String actor, String target) {
    return '$actor ha modificato la prenotazione di $target';
  }

  @override
  String eventReservationCancelled(String actor, String target) {
    return '$actor ha annullato la prenotazione di $target';
  }

  @override
  String eventPaymentSubmitted(String actor, String amount) {
    return '$actor ha registrato un pagamento di $amount';
  }

  @override
  String eventExpenseSubmitted(String actor, String amount) {
    return '$actor ha inviato una spesa di $amount';
  }

  @override
  String eventForSubject(String name) {
    return 'per $name';
  }

  @override
  String get membersTitle => 'Membri e piani';

  @override
  String get membersPlanNone => 'Nessun piano';

  @override
  String get memberRoleOwner => 'Proprietario';

  @override
  String get memberRoleAdmin => 'Admin';

  @override
  String get memberStatusPaused => 'In pausa';

  @override
  String get memberStatusExited => 'Uscito';

  @override
  String get moneyBaseFee => 'Abbonamento base';

  @override
  String moneyUsage(int used, int included) {
    return '$used mezze giornate usate su $included';
  }

  @override
  String moneyUsageUnlimited(int used) {
    return '$used mezze giornate usate';
  }

  @override
  String moneyOverage(int count) {
    return 'Eccedenza ($count mezze giornate extra)';
  }

  @override
  String get moneyCredits => 'Pagamenti e crediti';

  @override
  String get moneyBalance => 'Saldo';

  @override
  String get moneyStatementSettled => 'Saldato';

  @override
  String get moneyStatementOpen => 'Aperto';

  @override
  String get moneyRecordPayment => 'Registra un pagamento';

  @override
  String get moneyAmountLabel => 'Importo';

  @override
  String get moneyNoteLabel => 'Nota (facoltativa)';

  @override
  String get moneySubmitPayment => 'Invia per conferma';

  @override
  String get moneyPaymentPending =>
      'Pagamento inviato — in attesa di conferma.';

  @override
  String get moneyLedgerHeader => 'Registro';

  @override
  String get moneyLedgerEmpty => 'Ancora nessuna registrazione.';

  @override
  String get moneySubmitExpense => 'Invia una spesa';

  @override
  String get moneyExpenseCategoryLabel => 'Categoria';

  @override
  String get moneyDescriptionLabel => 'Descrizione';

  @override
  String get moneyExpensePending =>
      'Spesa inviata — in attesa di approvazione.';

  @override
  String get expenseCategoryCoffee => 'Caffè e cucina';

  @override
  String get expenseCategorySupplies => 'Materiale';

  @override
  String get expenseCategoryEquipment => 'Attrezzatura';

  @override
  String get expenseCategoryOther => 'Altro';

  @override
  String get ledgerCategorySubscription => 'Abbonamento';

  @override
  String get ledgerCategoryOverage => 'Eccedenza';

  @override
  String get ledgerCategoryExpense => 'Rimborso spesa';

  @override
  String get ledgerCategoryPayment => 'Pagamento';

  @override
  String get ledgerCategoryAdjustment => 'Rettifica';

  @override
  String get planNoLevels => 'Lo spazio non ha ancora una piantina.';

  @override
  String get planLevelLabel => 'Piano';

  @override
  String get planCheckInTitle => 'Check-in';

  @override
  String get planStartNow => 'Inizia adesso';

  @override
  String get planUntilLabel => 'Fino alle';

  @override
  String get planCheckInButton => 'Check-in';

  @override
  String get planCheckOutButton => 'Check-out';

  @override
  String get planCancelReservationButton => 'Annulla prenotazione';

  @override
  String get planSeatBlocked => 'Questo posto è bloccato per manutenzione.';

  @override
  String planReservedBy(String name) {
    return 'Prenotato da $name';
  }

  @override
  String planOccupiedBy(String name) {
    return 'Occupato da $name';
  }

  @override
  String planUntil(String time) {
    return 'fino alle $time';
  }

  @override
  String planCappedByNext(String time) {
    return 'Il posto è prenotato dalle $time.';
  }

  @override
  String get planCheckInFailed =>
      'Check-in non riuscito — il posto potrebbe essere appena stato occupato.';

  @override
  String get planYourSeat => 'Il tuo posto';

  @override
  String get planListViewTooltip => 'Vista elenco';

  @override
  String get planMapViewTooltip => 'Vista piantina';

  @override
  String get planNowButton => 'Adesso';

  @override
  String get planReserveButton => 'Prenota';

  @override
  String get planReservationsEmpty => 'Nessuna prenotazione per questo giorno.';

  @override
  String planStartsAt(String time) {
    return 'Inizia alle $time';
  }

  @override
  String get planRepeatLabel => 'Ripeti';

  @override
  String get repeatNone => 'Non si ripete';

  @override
  String get repeatDaily => 'Ogni giorno';

  @override
  String get repeatWeekdays => 'Ogni giorno feriale';

  @override
  String get repeatWeekly => 'Ogni settimana';

  @override
  String get planUntilDateLabel => 'Ripeti fino al';

  @override
  String seriesBookedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prenotazioni create',
      one: '1 prenotazione creata',
    );
    return '$_temp0';
  }

  @override
  String get seriesSkippedTitle => 'Saltate (già occupate):';

  @override
  String get commonOk => 'OK';

  @override
  String get onboardingTitle => 'Benvenuto su DesKilo';

  @override
  String get onboardingCreateTab => 'Crea uno spazio';

  @override
  String get onboardingJoinTab => 'Unisciti a uno spazio';

  @override
  String get workspaceNameLabel => 'Nome dello spazio';

  @override
  String get workspaceCountryLabel => 'Paese';

  @override
  String get workspaceCurrencyLabel => 'Valuta';

  @override
  String get workspaceTimezoneLabel => 'Fuso orario';

  @override
  String get onboardingCreateButton => 'Crea spazio';

  @override
  String get workspaceInviteCodeLabel => 'Codice di invito';

  @override
  String get onboardingJoinButton => 'Unisciti';

  @override
  String get workspaceGenericError => 'Qualcosa è andato storto. Riprova.';

  @override
  String get countryNameDE => 'Germania';

  @override
  String get countryNameAT => 'Austria';

  @override
  String get countryNameCH => 'Svizzera';

  @override
  String get countryNameFR => 'Francia';

  @override
  String get countryNameIT => 'Italia';

  @override
  String get countryNameES => 'Spagna';

  @override
  String get countryNamePT => 'Portogallo';

  @override
  String get countryNameNL => 'Paesi Bassi';

  @override
  String get countryNameBE => 'Belgio';

  @override
  String get countryNameLU => 'Lussemburgo';

  @override
  String get countryNameGB => 'Regno Unito';

  @override
  String get countryNameUS => 'Stati Uniti';
}
