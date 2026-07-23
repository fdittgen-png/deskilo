// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get accessoriesTitle => 'Accessori';

  @override
  String get accessoriesEmpty => 'Ancora nessun accessorio.';

  @override
  String get accessoriesNew => 'Nuovo accessorio';

  @override
  String get accessoriesEdit => 'Modifica accessorio';

  @override
  String get accessoriesName => 'Nome';

  @override
  String get accessoriesSupplement => 'Supplemento per mezza giornata';

  @override
  String accessoriesPerHalfDay(String amount) {
    return '$amount / mezza giornata';
  }

  @override
  String get accessoriesNoSupplement => 'Nessun supplemento';

  @override
  String get accessoriesInactive => 'Inattivo';

  @override
  String get accessoriesActive => 'Attivo';

  @override
  String get authSignInTitle => 'Accedi';

  @override
  String get authSignUpTitle => 'Crea account';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authShowPassword => 'Mostra password';

  @override
  String get authHidePassword => 'Nascondi password';

  @override
  String get authDisplayNameLabel => 'Nome visualizzato';

  @override
  String get authForgotPassword => 'Password dimenticata?';

  @override
  String get authResetTitle => 'Reimposta la password';

  @override
  String get authResetExplainer =>
      'Ti invieremo un codice monouso via e-mail. Usalo qui per impostare una nuova password.';

  @override
  String get authResetSendCode => 'Invia codice';

  @override
  String get authResetCodeSent => 'Codice inviato — controlla la tua e-mail.';

  @override
  String get authResetCodeLabel => 'Codice ricevuto via e-mail';

  @override
  String get authResetNewPasswordLabel => 'Nuova password';

  @override
  String get authResetSubmit => 'Imposta la nuova password';

  @override
  String get authResetDone => 'Password aggiornata — sei connesso.';

  @override
  String get authResetInvalidCode => 'Questo codice non è valido o è scaduto.';

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
  String get authNetworkError =>
      'Impossibile raggiungere il server. Controlla la connessione e riprova.';

  @override
  String get availabilityTitle => 'Disponibilità';

  @override
  String get availabilityOpenWeekdays => 'Giorni di apertura';

  @override
  String get availabilityClosureDays => 'Giorni di chiusura';

  @override
  String get availabilityAddClosure => 'Aggiungi giorno di chiusura';

  @override
  String get availabilityClosureReason => 'Motivo (facoltativo)';

  @override
  String get availabilityLastOpenDay =>
      'Almeno un giorno della settimana deve restare aperto.';

  @override
  String get availabilityNoClosures => 'Nessun giorno di chiusura.';

  @override
  String get availabilityGranularityTitle => 'Granularità delle prenotazioni';

  @override
  String get availabilityGranularityDescription =>
      'Mezze giornate: le prenotazioni coprono la mattina (fino alle 13), il pomeriggio (dalle 13) o l\'intera giornata.';

  @override
  String get availabilityGranularityFlexible => 'Fascia oraria libera';

  @override
  String get availabilityGranularityHalfDay =>
      'Mezze giornate (mattina e pomeriggio)';

  @override
  String get availabilityGranularity5 => 'Slot di 5 minuti';

  @override
  String get availabilityGranularity15 => 'Slot di 15 minuti';

  @override
  String get availabilityGranularity30 => 'Slot di 30 minuti';

  @override
  String get availabilityGranularity60 => 'Slot di 1 ora';

  @override
  String get availabilityGranularityFullDay => 'Solo giornate intere';

  @override
  String planSlotError(int minutes) {
    return 'Le prenotazioni devono iniziare e finire sulla griglia di $minutes minuti.';
  }

  @override
  String get planFullDayError =>
      'Qui le prenotazioni coprono l\'intera giornata.';

  @override
  String get myBadgeTitle => 'Il mio badge';

  @override
  String billSubscription(int pct) {
    return 'Abbonamento $pct %';
  }

  @override
  String billEntitlement(int used, int included, int openDays) {
    return '$used mezze giornate usate su $included ($openDays giorni di apertura)';
  }

  @override
  String billOverage(int extra) {
    return '$extra mezze giornate extra';
  }

  @override
  String get billServices => 'Servizi consumati';

  @override
  String get billServicesTotal => 'Totale servizi';

  @override
  String get billOpenPositions => 'Voci in sospeso';

  @override
  String get billPendingBadge => 'in attesa di convalida';

  @override
  String get billPaymentsCredits => 'Pagamenti e crediti';

  @override
  String get billBalance => 'Saldo';

  @override
  String get billSettled => 'Saldato';

  @override
  String get billOutstanding => 'Aperto';

  @override
  String get billAccessorySupplements => 'Supplementi accessori';

  @override
  String get entitlementTitle => 'Questo mese';

  @override
  String entitlementDaysUsed(String used, String total) {
    return '$used di $total giorni usati';
  }

  @override
  String entitlementDaysLeft(String left) {
    return '$left giorni rimasti';
  }

  @override
  String get entitlementBlockedFull =>
      'Hai usato tutti i tuoi giorni questo mese. Chiedine altri a un amministratore o richiedi mezze giornate extra qui sotto.';

  @override
  String entitlementPaygRate(String rate) {
    return 'I giorni oltre il tuo piano costano $rate ciascuno.';
  }

  @override
  String get entitlementPackageFull =>
      'Hai usato tutti i tuoi giorni questo mese. Acquista un pacchetto per continuare a prenotare.';

  @override
  String get billPackages => 'Pacchetti di giorni';

  @override
  String get payOnlineButton => 'Paga online';

  @override
  String get payOnlineNotConfigured =>
      'I pagamenti online non sono ancora configurati. Chiedi al proprietario dello spazio.';

  @override
  String get payOnlineChooseTitle => 'Paga online';

  @override
  String get paymentProviderStripe => 'Carta di credito (Stripe)';

  @override
  String get paymentProviderMollie => 'Mollie — iDEAL, Bancontact…';

  @override
  String get payOnlineDiagTitle => 'Pagamenti online — non configurati';

  @override
  String get payOnlineDiagHint =>
      'Sul server manca questa configurazione (docs/design/payments-integration.md):';

  @override
  String get billPdfTitle => 'Fattura mensile';

  @override
  String get billPdfExport => 'Esporta la fattura come PDF';

  @override
  String get billingTitle => 'Fatturazione';

  @override
  String get billingFeeBands => 'Fasce tariffarie';

  @override
  String billingBandFrom(int from) {
    return 'da $from%';
  }

  @override
  String get billingBandTo => 'Fino a %';

  @override
  String get billingBandFee => 'Canone mensile';

  @override
  String get billingBandOverage => 'Eccedenza';

  @override
  String get billingAddBand => 'Aggiungi fascia';

  @override
  String get billingRemoveBand => 'Rimuovi fascia';

  @override
  String get billingBandsInvalid =>
      'Le fasce devono crescere e terminare al 100%.';

  @override
  String get billingSaved => 'Salvato.';

  @override
  String get billingLevels => 'Livelli di abbonamento';

  @override
  String get billingAddLevel => 'Aggiungi livello';

  @override
  String get billingLevelValue => 'Livello (1–100)';

  @override
  String get billingAllowCustom =>
      'Consenti un valore personalizzato concordato';

  @override
  String get memberSubscriptionLabel => 'Abbonamento';

  @override
  String get memberSubscriptionCustom => 'Personalizzato (1–100)';

  @override
  String moneySubscriptionPct(int pct) {
    return 'Abbonamento $pct %';
  }

  @override
  String percentValue(int value) {
    return '$value%';
  }

  @override
  String get memberOveragePolicyLabel => 'Quando i giorni finiscono';

  @override
  String get memberOveragePolicyTooltip => 'Consumo extra';

  @override
  String get overagePolicyBlocked => 'Blocca ulteriori prenotazioni';

  @override
  String get overagePolicyPayg => 'Addebita l\'extra (a consumo)';

  @override
  String get overagePolicyPackage => 'Richiedi l\'acquisto di un pacchetto';

  @override
  String get billingPackages => 'Pacchetti di giorni';

  @override
  String get billingPackagesHint =>
      'I membri con piano a pacchetto li acquistano quando finiscono i giorni.';

  @override
  String billingPackageSummary(int days, String price) {
    return '$days giorni · $price';
  }

  @override
  String get billingPackageName => 'Nome';

  @override
  String get billingPackageDays => 'Giorni';

  @override
  String get billingPackagePrice => 'Prezzo';

  @override
  String get billingAddPackage => 'Aggiungi pacchetto';

  @override
  String get buyPackageButton => 'Acquista un pacchetto';

  @override
  String get buyPackageTitle => 'Acquista un pacchetto';

  @override
  String buyPackageDays(int days) {
    return '$days giorni';
  }

  @override
  String get buyPackageNone => 'Nessun pacchetto disponibile al momento.';

  @override
  String get buyPackageDone => 'Giorni aggiunti — goditi il tempo extra.';

  @override
  String get payConfigTitle => 'Pagamenti online';

  @override
  String get payConfigOpen => 'Configura';

  @override
  String get payConfigIntro =>
      'Inserisci ogni fornitore di pagamento da offrire. Le chiavi sono salvate in sicurezza sul server e non vengono più mostrate. Vedi docs/design/payments-integration.md.';

  @override
  String get payConfigConfigured => 'Configurato';

  @override
  String get payConfigNotConfigured => 'Non configurato';

  @override
  String get payConfigSecretSet => 'Impostato — lascia vuoto per mantenere';

  @override
  String get payConfigSaved => 'Salvato.';

  @override
  String get payConfigRemove => 'Rimuovi';

  @override
  String get payConfigRemoved => 'Rimosso.';

  @override
  String get payFieldClientId => 'Client ID';

  @override
  String get payFieldSecret => 'Secret';

  @override
  String get payFieldEnv => 'Ambiente';

  @override
  String get payFieldWebhookId => 'ID webhook';

  @override
  String get payFieldReturnUrl => 'URL di ritorno';

  @override
  String get payFieldSecretKey => 'Chiave segreta';

  @override
  String get payFieldWebhookSecret => 'Segreto di firma webhook';

  @override
  String get payFieldApiKey => 'Chiave API';

  @override
  String get paymentProviderWero => 'Wero (tramite Mollie)';

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
  String get calendarShowOnPlan => 'Mostra sulla pianta';

  @override
  String get calendarListView => 'Vista elenco';

  @override
  String get calendarTimelineView => 'Vista cronologia';

  @override
  String get calendarTimelineEmpty =>
      'Nessuna prenotazione su questo piano in questo giorno.';

  @override
  String get calendarAllLevels => 'Tutti i piani';

  @override
  String get calendarTimelineAllEmpty =>
      'Nessuna prenotazione su nessun piano in questo giorno.';

  @override
  String calendarLevelCollapsed(String level) {
    return '$level, compresso';
  }

  @override
  String calendarLevelExpanded(String level) {
    return '$level, espanso';
  }

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
  String get settingsSectionAdministration => 'Amministrazione';

  @override
  String get settingsSectionPreferences => 'Preferenze';

  @override
  String get settingsSectionAdvanced => 'Avanzate';

  @override
  String get comingSoon => 'Prossimamente';

  @override
  String get shellReserveButton => 'Prenota';

  @override
  String commonSavedTo(String path) {
    return 'Salvato in $path';
  }

  @override
  String get commonSaveFailed => 'Impossibile salvare il file.';

  @override
  String get consumptionAdd => 'Aggiungi consumo';

  @override
  String consumptionAddForMember(String name) {
    return 'Aggiungi servizio per $name';
  }

  @override
  String get consumptionService => 'Servizio';

  @override
  String get consumptionQuantity => 'Quantità';

  @override
  String get consumptionPeriodLabel => 'Periodo di fatturazione (AAAA-MM)';

  @override
  String get consumptionNoServices => 'Nessun servizio attivo da registrare.';

  @override
  String get consumptionRecorded =>
      'Consumo registrato — in attesa di conferma.';

  @override
  String get eventTypeServiceCharge => 'Servizio';

  @override
  String eventServiceChargeTitle(String name, int quantity, String amount) {
    return '$name ×$quantity — $amount';
  }

  @override
  String get developerMode => 'Modalità sviluppatore';

  @override
  String get developerTitle => 'Sviluppatore';

  @override
  String get developerExport => 'Esporta registro';

  @override
  String get developerClear => 'Svuota registro';

  @override
  String get developerEmpty => 'Ancora nessuna voce nel registro.';

  @override
  String get developerFilterAll => 'Tutto';

  @override
  String get developerFilterErrors => 'Errori';

  @override
  String get developerFilterWarnings => 'Avvisi+';

  @override
  String get directoryTitle => 'Membri';

  @override
  String get directoryEmpty => 'Ancora nessun membro.';

  @override
  String get directoryCheckedIn => 'Presente';

  @override
  String directoryCheckedInSeat(String seat) {
    return 'Presente · $seat';
  }

  @override
  String get directoryOnline => 'Online';

  @override
  String get directoryReservedToday => 'Prenotato oggi';

  @override
  String directoryLastSeenMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String directoryLastSeenHours(int hours) {
    return '$hours h';
  }

  @override
  String directoryLastSeenDays(int days) {
    return '$days g';
  }

  @override
  String get directoryWhatsapp => 'Chatta su WhatsApp';

  @override
  String get directoryOpenGroup => 'Apri il gruppo WhatsApp';

  @override
  String get directoryClose => 'Chiudi';

  @override
  String get directoryReservedNow => 'Prenotato ora';

  @override
  String directoryReservedNowSeat(String seat) {
    return 'Prenotato ora · $seat';
  }

  @override
  String get directoryReservationsHeading => 'Prenotazioni';

  @override
  String get directoryNoUpcoming => 'Nessuna prenotazione in arrivo';

  @override
  String get editorBackgroundImage => 'Immagine di sfondo';

  @override
  String get editorBackgroundSet => 'Imposta immagine di sfondo';

  @override
  String get editorBackgroundReplace => 'Sostituisci immagine di sfondo';

  @override
  String get editorBackgroundRemove => 'Rimuovi immagine di sfondo';

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
  String get editorToolImage => 'Immagine';

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
  String get editorAccessoriesLabel => 'Accessori';

  @override
  String get editorNoAccessories =>
      'Ancora nessun accessorio — aggiungili in Impostazioni → Accessori.';

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
  String get pushPendingTitle => 'DesKilo';

  @override
  String get pushPendingBody => 'Qualcuno attende la tua conferma.';

  @override
  String get featuresTitle => 'Funzionalità';

  @override
  String get featureCalendarTab => 'Scheda Calendario';

  @override
  String get featureCalendarTabDesc =>
      'Panoramica mensile di prenotazioni e giorni di chiusura.';

  @override
  String get featureEventsTab => 'Scheda Eventi';

  @override
  String get featureEventsTabDesc =>
      'Cronologia delle attività e conferme in sospeso.';

  @override
  String get featureMoneyTab => 'Scheda Finanze';

  @override
  String get featureMoneyTabDesc => 'Fatture mensili, pagamenti e spese.';

  @override
  String get featureServices => 'Servizi';

  @override
  String get featureServicesDesc =>
      'Catalogo dei servizi e registrazione dei consumi.';

  @override
  String get featurePdfExport => 'Esportazione PDF';

  @override
  String get featurePdfExportDesc => 'Esporta la fattura mensile come PDF.';

  @override
  String get featureSeriesBooking => 'Prenotazione in serie';

  @override
  String get featureSeriesBookingDesc =>
      'Ripeti una prenotazione ogni giorno, ogni settimana o nei giorni feriali.';

  @override
  String get featureBookForOthers => 'Prenota per altri';

  @override
  String get featureBookForOthersDesc =>
      'Admin e proprietari prenotano posti per altri membri.';

  @override
  String get featurePushNotifications => 'Notifiche push';

  @override
  String get featurePushNotificationsDesc =>
      'Consegna le conferme in sospeso sui dispositivi dei membri.';

  @override
  String get featureAdminSeatBlocking => 'Gli admin possono bloccare i posti';

  @override
  String get featureAdminSeatBlockingDesc =>
      'Gli admin contrassegnano i posti come non prenotabili per manutenzione. Il proprietario può sempre.';

  @override
  String get featureAccessorySupplements => 'Supplementi accessori';

  @override
  String get featureAccessorySupplementsDesc =>
      'Fattura gli accessori del posto con prezzo per mezza giornata prenotata. Vale per le prenotazioni dall\'attivazione in poi.';

  @override
  String get featureOnlinePayments => 'Pagamenti online';

  @override
  String get featureOnlinePaymentsDesc =>
      'Consenti ai membri di pagare la fattura online (PayPal). Richiede la configurazione del fornitore di pagamento sul server.';

  @override
  String get featureNfcBadges => 'Badge RFID / NFC';

  @override
  String get featureNfcBadgesDesc =>
      'I membri fanno check-in a un chiosco avvicinando una tessera RFID/NFC. Richiede un dispositivo Android con NFC.';

  @override
  String get featureLevelBooking => 'Prenotazione del piano';

  @override
  String get featureLevelBookingDesc =>
      'Prenotare un intero piano come un\'unica prenotazione, con prezzo per mezza giornata. Il permesso si concede membro per membro.';

  @override
  String get featureAdminLevelAssign => 'Gli admin possono assegnare piani';

  @override
  String get featureAdminLevelAssignDesc =>
      'Gli admin assegnano prenotazioni di piano ai membri. Il proprietario può sempre.';

  @override
  String get helpTitle => 'Aiuto';

  @override
  String get helpContents => 'Indice';

  @override
  String get inviteSectionTitle => 'Invita qualcuno';

  @override
  String get inviteViaWhatsapp => 'WhatsApp';

  @override
  String get inviteViaSms => 'SMS';

  @override
  String get inviteViaShare => 'Condividi…';

  @override
  String get inviteFirstNameLabel => 'Nome (facoltativo)';

  @override
  String get inviteLastNameLabel => 'Cognome (facoltativo)';

  @override
  String get invitePhoneLabel => 'Telefono (facoltativo, con prefisso)';

  @override
  String get inviteLanguageLabel => 'Lingua del messaggio';

  @override
  String get inviteSendFailed =>
      'Impossibile aprire l\'app di invio. Il messaggio è stato copiato al suo posto.';

  @override
  String get inviteCreateFailed =>
      'Impossibile creare l\'invito. Controlla la connessione e riprova.';

  @override
  String invitationDefaultTemplate(
    String firstName,
    String workspaceName,
    String workspaceId,
    String downloadUrl,
    String inviteLink,
  ) {
    return 'Ciao$firstName! Sei invitato a unirti al nostro spazio di coworking «$workspaceName» su DesKilo.\n\n1. Scarica l\'app:\n$downloadUrl\n\n2. Aprila, crea il tuo account (e-mail + password) e accedi.\n\n3. Scegli «Unisciti a uno spazio» e inserisci il tuo codice d\'invito personale:\n$workspaceId\n(link d\'invito: $inviteLink)\n\nSuggerimento: copia semplicemente questo intero messaggio e incollalo nell\'app — il codice viene rilevato automaticamente. Il tuo codice è personale, monouso e valido per 14 giorni.\n\nA presto da $workspaceName!';
  }

  @override
  String get invitationTemplateTitle => 'Messaggio d\'invito';

  @override
  String get invitationTemplateHelp =>
      'Inviato quando inviti qualcuno via WhatsApp, SMS o condivisione. Lascia vuoto per usare il messaggio integrato nella lingua scelta. Tag disponibili:';

  @override
  String get invitationTemplateHint =>
      'Messaggio d\'invito personalizzato con i tag qui sopra…';

  @override
  String get workspaceInvitePasteHint =>
      'Incolla l\'intero messaggio d\'invito — l\'ID viene trovato automaticamente.';

  @override
  String get workspaceInviteCodeInvalid =>
      'Nessun ID trovato — incolla l\'invito o digita l\'ID.';

  @override
  String get eventTypeMemberJoin => 'Nuovo membro';

  @override
  String get memberStatusPending => 'In attesa';

  @override
  String get pendingApprovalTitle => 'In attesa di approvazione';

  @override
  String pendingApprovalBody(String workspace) {
    return 'Ti sei unito a $workspace. Un amministratore deve approvare la tua adesione prima che tu possa usare lo spazio — avrai accesso appena confermata.';
  }

  @override
  String get pendingApprovalRefresh => 'Controlla di nuovo';

  @override
  String get memberApprove => 'Approva l\'adesione';

  @override
  String get memberRejectJoin => 'Rifiuta l\'adesione';

  @override
  String get workspaceConfigInvitations => 'Inviti';

  @override
  String get workspaceConfigInvitationCustom =>
      'Messaggio d\'invito personalizzato configurato';

  @override
  String get workspaceConfigInvitationDefault =>
      'Messaggio d\'invito integrato (tutte le lingue)';

  @override
  String get workspaceConfigInvitationSingleUse =>
      'I codici d\'invito personali sono monouso e scadono dopo 14 giorni; i nuovi membri richiedono l\'approvazione di un admin';

  @override
  String get memberKioskLabel => 'Chiosco';

  @override
  String get memberMakeKiosk => 'Trasforma in chiosco';

  @override
  String get memberUnmakeKiosk => 'Riporta il chiosco a membro';

  @override
  String get memberBadgesTooltip => 'Badge';

  @override
  String memberBadgesTitle(String name) {
    return 'Badge — $name';
  }

  @override
  String get badgeIssue => 'Nuovo badge';

  @override
  String get badgeTokenOnce =>
      'Salva questo QR adesso — viene mostrato una sola volta.';

  @override
  String get badgeNone => 'Ancora nessun badge.';

  @override
  String get badgeDefaultLabel => 'Badge';

  @override
  String get badgeRevoke => 'Revoca';

  @override
  String get badgeRevoked => 'Revocato';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get kioskCheckIn => 'Check-in';

  @override
  String get kioskReserve => 'Prenota';

  @override
  String get kioskCheckOut => 'Check-out';

  @override
  String get kioskPresentBadge => 'Presenta il tuo badge';

  @override
  String get kioskBadgeHint =>
      'Scansiona il QR del badge o digita il suo codice.';

  @override
  String get kioskBadgeFieldLabel => 'Codice badge';

  @override
  String get kioskBadgeConfirm => 'Conferma';

  @override
  String get kioskBadgeRejected => 'Badge non riconosciuto.';

  @override
  String get kioskDone => 'Fatto — è tutto a posto.';

  @override
  String get kioskTapHint => 'Tocca un posto per fare check-in';

  @override
  String get badgeSavePdf => 'Salva come PDF';

  @override
  String get badgeRegisterCard => 'Registra tessera';

  @override
  String get badgeTapCardTitle => 'Registra una tessera';

  @override
  String get badgeTapCardHint =>
      'Avvicina la tessera RFID/NFC al retro del dispositivo.';

  @override
  String get badgeCardRegistered => 'Tessera registrata.';

  @override
  String get badgeCardAlreadyRegistered => 'Questa tessera è già registrata.';

  @override
  String get kioskBadgeHintNfc =>
      'Avvicina la tessera, scansiona il QR o digita il codice.';

  @override
  String get nfcConfigTitle => 'Badge RFID / NFC';

  @override
  String get nfcConfigIntro =>
      'I membri fanno check-in a un chiosco a parete avvicinando una tessera RFID/NFC. Registra la tessera di ogni membro in Membri e piani; al chiosco la avvicinano per prenotare o fare check-in.';

  @override
  String get nfcConfigEnable => 'Abilita il check-in con badge NFC';

  @override
  String get nfcConfigEnableDesc =>
      'Mostra l\'opzione di avvicinare la tessera su chioschi e nel gestore badge.';

  @override
  String get nfcConfigDeviceStatus => 'Questo dispositivo';

  @override
  String get nfcConfigChecking => 'Verifica…';

  @override
  String get nfcConfigDeviceReady => 'NFC disponibile e attivo';

  @override
  String get nfcConfigDeviceUnavailable =>
      'Nessun NFC qui — serve un dispositivo Android con NFC attivo (gli iPad non hanno NFC). I badge QR funzionano comunque.';

  @override
  String get kioskConfirmAction => 'Conferma';

  @override
  String get kioskRejectAction => 'Rifiuta';

  @override
  String get kioskGateTitle => 'Avviare la modalità chiosco?';

  @override
  String get kioskGateBody =>
      'Questo account è configurato come chiosco dello spazio. In modalità chiosco il tablet mostra solo la piantina per il check-in con badge — non si può aprire altro. Per uscire dalla modalità chiosco, riavvia il tablet.';

  @override
  String get kioskGateStart => 'Avvia la modalità chiosco';

  @override
  String get kioskGateReject => 'Non ora — apri l\'app normalmente';

  @override
  String get settingsFrontCamera => 'Scansiona con la fotocamera frontale';

  @override
  String get settingsFrontCameraDesc =>
      'I badge vengono letti con la fotocamera lato schermo — disattiva per usare la fotocamera posteriore.';

  @override
  String get kioskNfcOff =>
      'L\'NFC è disattivato nelle impostazioni Android di questo tablet — attivalo per leggere le carte RFID.';

  @override
  String get kioskNfcUnsupported =>
      'Questo tablet non ha un lettore NFC — scansiona il badge QR.';

  @override
  String get kioskNfcFailed =>
      'Il lettore RFID non si è avviato — riavvia l\'app e riprova.';

  @override
  String get nfcConfigDeviceOff =>
      'L\'NFC è disattivato nelle impostazioni Android di questo dispositivo — attivalo per leggere le carte RFID.';

  @override
  String get languageTitle => 'Lingua';

  @override
  String get languageSystemDefault => 'Predefinita di sistema';

  @override
  String get levelReserveButton => 'Prenota il piano';

  @override
  String get levelReserveTitle => 'Prenotare l\'intero piano';

  @override
  String get levelPermissionTile => 'Prenotazioni del piano';

  @override
  String get levelPermissionAllowed => 'Può prenotare un intero piano';

  @override
  String get levelPermissionDenied => 'Non può prenotare un intero piano';

  @override
  String get levelBookableToggle => 'Prenotabile per intero';

  @override
  String get levelBookableDesc =>
      'L\'intero piano può essere prenotato come un\'unica prenotazione.';

  @override
  String get levelPriceLabel => 'Prezzo per mezza giornata';

  @override
  String get levelAssignMember => 'Per il membro';

  @override
  String get levelAssignMyself => 'Io stesso';

  @override
  String get levelSupplementLabel => 'Prenotazioni del piano';

  @override
  String get levelNotAllowed =>
      'Non sei autorizzato a prenotare un intero piano.';

  @override
  String get levelConflict => 'Il piano ha prenotazioni in quel periodo.';

  @override
  String get levelDetail => 'Intero piano';

  @override
  String get kioskLevelButton => 'Questo piano';

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
  String get membersInvite => 'Invita un membro';

  @override
  String get profilesTitle => 'Profili';

  @override
  String get profilesAdd => 'Aggiungi un profilo';

  @override
  String get profilesActive => 'Profilo attivo';

  @override
  String get memberRoleMember => 'Membro';

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
  String get ledgerCategoryService => 'Servizio';

  @override
  String get plansEditorTitle => 'Piani';

  @override
  String get plansEditorNew => 'Nuovo piano';

  @override
  String get plansEditorEdit => 'Modifica piano';

  @override
  String get plansEditorInactive => 'Inattivo';

  @override
  String get plansEditorUnlimited => 'mezze giornate illimitate';

  @override
  String plansEditorQuota(int count) {
    return '$count mezze giornate';
  }

  @override
  String plansEditorPerExtra(String price) {
    return '$price/mezza giornata extra';
  }

  @override
  String get planNameLabel => 'Nome';

  @override
  String get planBaseFeeLabel => 'Canone mensile base';

  @override
  String get planIncludedLabel => 'Mezze giornate incluse';

  @override
  String get planIncludedHelper => 'Lascia vuoto per illimitato';

  @override
  String get planOverageLabel => 'Prezzo per mezza giornata extra';

  @override
  String get planActiveLabel => 'Attivo';

  @override
  String get paymentMethodBankTransfer => 'Bonifico';

  @override
  String get paymentMethodCash => 'Contanti';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTwint => 'TWINT';

  @override
  String get paymentMethodCard => 'Carta';

  @override
  String get paymentMethodOther => 'Altro';

  @override
  String get paymentMethodWero => 'Wero';

  @override
  String get paymentMethodLydia => 'Lydia';

  @override
  String get paymentMethodWise => 'Wise';

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
  String get planLevelTooltip => 'Piano';

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
  String get reminderTitle => 'Check-in a breve';

  @override
  String reminderBody(String target, String time) {
    return '$target inizia alle $time';
  }

  @override
  String get planNoSeats => 'Questo piano non ha ancora posti.';

  @override
  String get planStateFree => 'Libero';

  @override
  String get planStateYours => 'Tuo';

  @override
  String get planBookForLabel => 'Prenota per';

  @override
  String get planSendForConfirmation => 'Invia per conferma';

  @override
  String planBookedForPending(String name) {
    return 'Inviato a $name per conferma.';
  }

  @override
  String get planMakeNotReservable => 'Rendi non prenotabile';

  @override
  String get planMakeReservable => 'Rendi prenotabile';

  @override
  String get planAccessorySupplementHint =>
      'I supplementi si applicano per mezza giornata.';

  @override
  String get planFromLabel => 'Dalle';

  @override
  String get planToLabel => 'Alle';

  @override
  String get planEndBeforeStart =>
      'La fine deve essere successiva all\'inizio.';

  @override
  String get planClosedDay => 'Chiuso in questo giorno';

  @override
  String get planClosedDayError => 'Lo spazio è chiuso quel giorno.';

  @override
  String get planMorningChip => 'Mattina';

  @override
  String get planAfternoonChip => 'Pomeriggio';

  @override
  String get planFullDayChip => 'Giornata';

  @override
  String get planHalfDayError => 'Qui le prenotazioni sono per mezza giornata.';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get whatsappNotShared => 'Non condiviso';

  @override
  String get whatsappFieldLabel => 'Numero WhatsApp';

  @override
  String get whatsappHint => '+39 333 123 4567';

  @override
  String get whatsappHelper =>
      'Facoltativo. Visibile ai membri dei tuoi spazi per contattarti su WhatsApp. Lascia vuoto per smettere di condividerlo.';

  @override
  String get whatsappSaved => 'Numero WhatsApp salvato';

  @override
  String get whatsappSaveFailed => 'Impossibile salvare il numero WhatsApp';

  @override
  String get profileStatusTitle => 'Stato';

  @override
  String get profileStatusNone => 'Nessuno stato';

  @override
  String get profileStatusFieldLabel => 'Stato';

  @override
  String get profileStatusHint => 'In chiamata · torno alle 14:00';

  @override
  String get profileStatusHelper =>
      'Facoltativo. Visibile ai membri dei tuoi spazi nell\'elenco dei membri. Lascia vuoto per cancellarlo.';

  @override
  String get profileStatusSaved => 'Stato salvato';

  @override
  String get profileStatusSaveFailed => 'Impossibile salvare lo stato';

  @override
  String get profilePhotoTitle => 'Foto';

  @override
  String get profilePhotoSet => 'Tocca per cambiare';

  @override
  String get profilePhotoNone => 'Tocca per aggiungere una foto';

  @override
  String get profilePhotoChoose => 'Scegli una foto';

  @override
  String get profilePhotoRemove => 'Rimuovi foto';

  @override
  String get profilePhotoSaved => 'Foto aggiornata';

  @override
  String get profilePhotoRemoved => 'Foto rimossa';

  @override
  String get profilePhotoSaveFailed => 'Impossibile aggiornare la foto';

  @override
  String get profilePhotoFileType => 'Immagine';

  @override
  String get profilesDefault => 'Predefinito all\'avvio';

  @override
  String get profilesMakeDefault => 'Usa come predefinito all\'avvio';

  @override
  String get eventTypeRoleChange => 'Cambio di ruolo';

  @override
  String eventRolePromote(String actor) {
    return '$actor promuove un membro ad admin';
  }

  @override
  String eventRoleDemote(String actor) {
    return '$actor declassa un admin a membro';
  }

  @override
  String get memberMakeAdmin => 'Rendi admin';

  @override
  String get memberMakeMember => 'Rendi membro normale';

  @override
  String get memberRoleChangeRequested =>
      'Cambio di ruolo inviato per la convalida.';

  @override
  String get eventTypeQuota => 'Mezze giornate extra';

  @override
  String eventQuotaRequested(String actor, int halfDays, String period) {
    return '$actor richiede $halfDays mezze giornate extra per $period';
  }

  @override
  String get quotaExceededError =>
      'Quota mensile di mezze giornate raggiunta — richiedi mezze giornate extra dalla scheda Finanze.';

  @override
  String get quotaRequestButton => 'Richiedi mezze giornate extra';

  @override
  String get quotaRequestTitle => 'Richiedi mezze giornate extra';

  @override
  String quotaRequestExplainer(String period) {
    return 'Le tue prenotazioni sono limitate dal tuo abbonamento. Le mezze giornate extra per $period si applicano dopo la convalida.';
  }

  @override
  String get quotaRequestCountLabel => 'Numero di mezze giornate';

  @override
  String get quotaRequestPending =>
      'Richiesta inviata — in attesa di convalida.';

  @override
  String get memberReservationLimitTooltip => 'Limite di prenotazioni';

  @override
  String get memberReservationLimitLabel => 'Limite di prenotazioni';

  @override
  String get memberReservationLimitExplainer =>
      'Quante prenotazioni aperte questo membro può avere contemporaneamente.';

  @override
  String get memberReservationLimitNone => 'Nessun limite';

  @override
  String get memberReservationLimitCustom => 'Personalizzato (1–100)';

  @override
  String memberReservationLimitChip(int n) {
    return 'max $n';
  }

  @override
  String get reservationLimitError =>
      'Limite di prenotazioni raggiunto — hai già il numero massimo di prenotazioni aperte.';

  @override
  String get memberPause => 'Sospendi l\'iscrizione';

  @override
  String get memberReactivate => 'Riattiva l\'iscrizione';

  @override
  String get reserveMonthView => 'Mese';

  @override
  String monthFreeCount(int free, int total) {
    return '$free/$total';
  }

  @override
  String get reservationRecurring => 'Prenotazione ricorrente';

  @override
  String get reservationEditTimes => 'Modifica orario';

  @override
  String get reservationUpdatedSnack => 'Prenotazione aggiornata.';

  @override
  String get reservationCancelledSnack => 'Prenotazione annullata.';

  @override
  String get reserveDayView => 'Giorno';

  @override
  String get reserveWeekView => 'Settimana';

  @override
  String get reserveFullDayChip => 'Giornata intera';

  @override
  String get reservePickDateTooltip => 'Scegli una data';

  @override
  String get reserveBookingFailed =>
      'Prenotazione non riuscita — il posto potrebbe essere appena stato occupato.';

  @override
  String get servicesTitle => 'Servizi';

  @override
  String get servicesEmpty => 'Ancora nessun servizio.';

  @override
  String get servicesNew => 'Nuovo servizio';

  @override
  String get servicesEdit => 'Modifica servizio';

  @override
  String get servicesName => 'Nome';

  @override
  String get servicesPrice => 'Prezzo';

  @override
  String get servicesInactive => 'Inattivo';

  @override
  String get servicesActive => 'Attivo';

  @override
  String get authContinueWith => 'oppure continua con';

  @override
  String authSocialUnavailable(String provider) {
    return 'L\'accesso con $provider non è ancora disponibile — il server non lo ha abilitato.';
  }

  @override
  String get linkedAccountsTitle => 'Account collegati';

  @override
  String get linkedAccountsIntro =>
      'Accedi a questo account con uno qualsiasi di essi. Aggiungi Google, Microsoft, Apple o Facebook per accedere senza password.';

  @override
  String get linkedAccountsLink => 'Collega';

  @override
  String get linkedAccountsUnlink => 'Scollega';

  @override
  String get linkedAccountsLinked => 'Collegato';

  @override
  String get linkedAccountsLinkStarted =>
      'Continua nel browser per completare il collegamento.';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeSystem => 'Predefinito di sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String eventValidations(int current, int required) {
    return '$current/$required convalide';
  }

  @override
  String eventValidatedBy(String name, String when) {
    return 'Convalidato da $name · $when';
  }

  @override
  String eventRejectedBy(String name, String when) {
    return 'Rifiutato da $name · $when';
  }

  @override
  String get eventSystemDecider => 'Sistema';

  @override
  String get validationTitle => 'Regole di validazione';

  @override
  String get validationDefaultPolicy => 'Regola predefinita';

  @override
  String get validationInherited => 'Eredita la predefinita';

  @override
  String get validationCustomized => 'Personalizzata';

  @override
  String get validationRequiredCount => 'Validazioni richieste';

  @override
  String get validationAdminsMay => 'Gli admin possono validare';

  @override
  String get validationOwnerOnly => 'Solo il proprietario';

  @override
  String get validationAllAdmins => 'Tutti gli admin';

  @override
  String get validationSpecificAdmins => 'Admin specifici';

  @override
  String get validationOwnerRequired => 'Il proprietario deve sempre validare';

  @override
  String get validationNotEnough => 'Validatori idonei insufficienti.';

  @override
  String get validationSaved => 'Regola di validazione salvata.';

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

  @override
  String get workspaceCodeTitle => 'ID dello spazio e QR';

  @override
  String get workspaceCodeLabel => 'ID dello spazio';

  @override
  String get workspaceCodeHint => '4–20 lettere o cifre, univoco';

  @override
  String get workspaceCodeEdit => 'Cambia l\'ID dello spazio';

  @override
  String get workspaceCodeRejected =>
      'ID rifiutato — deve avere 4–20 lettere o cifre e non essere già in uso.';

  @override
  String get workspaceCodeExplainer =>
      'I coworker scansionano questo codice QR — o digitano l\'ID — per unirsi a questo spazio.';

  @override
  String get workspaceCodeCopy => 'Copia ID';

  @override
  String get workspaceCodeCopied => 'Copiato';

  @override
  String get inviteRoleMember => 'Invito membro';

  @override
  String get inviteRoleAdmin => 'Invito admin';

  @override
  String get inviteAdminExplainer =>
      'Questo codice è monouso: ammette UNA persona come admin, poi scade. Consegnalo solo alla persona a cui è destinato.';

  @override
  String get inviteAdminNewCode => 'Nuovo codice admin';

  @override
  String get inviteOwnerNote =>
      'Non esiste un invito proprietario — solo un proprietario può concedere la proprietà, in Membri e piani.';

  @override
  String get scanJoinTitle => 'Scansiona il QR dello spazio';

  @override
  String get onboardingScanButton => 'Scansiona codice QR';

  @override
  String get workspaceCodeSharePng => 'Condividi come PNG';

  @override
  String get workspaceSettingsTitle => 'Spazio di coworking';

  @override
  String get workspaceSettingsSaved => 'Spazio salvato.';

  @override
  String get workspaceSettingsCurrencyHelper =>
      'Proposta in base al paese — modificala se la tua community fattura in un’altra valuta.';

  @override
  String get paymentInstructionsTitle => 'Istruzioni di pagamento';

  @override
  String get paymentInstructionsHelper =>
      'Mostrate ai membri su un estratto non saldato. Lascia vuoto per non mostrare nulla.';

  @override
  String get paymentInstructionsPaypalLabel => 'Link o nome PayPal.me';

  @override
  String get paymentInstructionsReferenceLabel => 'Indicazione della causale';

  @override
  String get paymentInstructionsIbanTitle => 'IBAN';

  @override
  String get paymentInstructionsIbanCopied => 'IBAN copiato.';

  @override
  String get paymentInstructionsWeroLabel => 'Numero di telefono Wero';

  @override
  String get paymentInstructionsLydiaLabel =>
      'Numero di telefono o nome utente Lydia';

  @override
  String get paymentInstructionsWiseLabel => 'Wisetag o link di pagamento Wise';

  @override
  String get paymentInstructionsValueCopied => 'Copiato negli appunti.';

  @override
  String get workspaceWhatsappGroupTitle => 'Gruppo WhatsApp';

  @override
  String get workspaceWhatsappGroupHelper =>
      'Mostrato ai membri perché possano unirsi al gruppo WhatsApp della community. Incolla il link di invito del gruppo (https://chat.whatsapp.com/…). Lascia vuoto per non mostrare nulla.';

  @override
  String get workspaceWhatsappGroupLabel => 'Link del gruppo WhatsApp';

  @override
  String get workspaceWhatsappGroupInvalid =>
      'Deve essere un link di invito chat.whatsapp.com';

  @override
  String get memberStatusActive => 'Attivo';

  @override
  String get workspaceConfigPdfExport => 'Esporta configurazione (PDF)';

  @override
  String get workspaceConfigPdfExportSubtitle =>
      'Istantanea completa: impostazioni, tutti i membri e la pianta.';

  @override
  String get workspaceConfigPdfTitle => 'Configurazione dello spazio';

  @override
  String workspaceConfigPdfGeneratedOn(String date) {
    return 'Generato il $date';
  }

  @override
  String get workspaceConfigOverview => 'Panoramica';

  @override
  String get workspaceConfigMembersSection => 'Membri';

  @override
  String get workspaceConfigFeatures => 'Funzioni attive';

  @override
  String get workspaceConfigAvailability => 'Disponibilità';

  @override
  String get workspaceConfigFloorPlan => 'Pianta';

  @override
  String get workspaceConfigGranularity => 'Granularità di prenotazione';

  @override
  String get workspaceConfigColName => 'Nome';

  @override
  String get workspaceConfigColRole => 'Ruolo';

  @override
  String get workspaceConfigColStatus => 'Stato';

  @override
  String get workspaceConfigOpenDays => 'Giorni di apertura';

  @override
  String get workspaceConfigClosures => 'Chiusure';

  @override
  String get workspaceConfigBookableWhole => 'prenotabile per intero';

  @override
  String get workspaceConfigSeats => 'Posti';

  @override
  String get workspaceConfigEmptyLevel => 'Nessuna sala';

  @override
  String get workspaceConfigNone => 'Nessuno';

  @override
  String get workspaceDeskTransparencyTitle => 'Trasparenza dei tavoli';

  @override
  String get workspaceDeskTransparencyHelper =>
      'Riduci l\'opacità dei tavoli per far trasparire la foto di sfondo del piano.';

  @override
  String workspaceDeskOpacityValue(int percent) {
    return 'Opacità: $percent%';
  }

  @override
  String get workspaceDangerZone => 'Zona pericolosa';

  @override
  String get workspaceResetTitle => 'Reimposta lo spazio';

  @override
  String get workspaceResetSubtitle =>
      'Elimina tutte le prenotazioni, la contabilità e la pianta. Mantiene impostazioni e membri.';

  @override
  String get workspaceResetDialogTitle => 'Reimpostare questo spazio?';

  @override
  String get workspaceResetWarning =>
      'Questo elimina definitivamente tutte le prenotazioni, tutti i dati contabili e di registro, il flusso attività e l\'intera pianta — piani, stanze, tavoli, posti e immagini. Le impostazioni dello spazio, le fasce tariffarie, la disponibilità, le funzioni, i cataloghi e i membri vengono mantenuti. Operazione irreversibile.';

  @override
  String get workspaceResetConfirmPhrase => 'Accetto';

  @override
  String workspaceResetConfirmLabel(String phrase) {
    return 'Digita «$phrase» per confermare';
  }

  @override
  String get workspaceResetConfirmButton => 'Reimposta lo spazio';

  @override
  String get workspaceResetDone => 'Spazio reimpostato.';

  @override
  String get workspaceXmlExport => 'Esporta lo spazio (XML)';

  @override
  String get workspaceXmlExportSubtitle =>
      'Impostazioni e planimetria in un file condivisibile. Senza membri, prenotazioni o dati finanziari.';

  @override
  String get workspaceXmlImport => 'Importa lo spazio (XML)';

  @override
  String get workspaceXmlImportSubtitle =>
      'Ripristina impostazioni e planimetria da un file esportato. Sostituisce la planimetria attuale.';

  @override
  String get workspaceXmlFileTypeLabel => 'XML';

  @override
  String get workspaceXmlImportPreviewTitle => 'Sostituire la planimetria?';

  @override
  String workspaceXmlImportPreviewCounts(
    int levels,
    int offices,
    int desks,
    int seats,
  ) {
    return 'Piani: $levels · Stanze: $offices · Scrivanie: $desks · Postazioni: $seats';
  }

  @override
  String workspaceXmlImportPreviewAccessories(int count) {
    return 'Accessori: $count';
  }

  @override
  String get workspaceXmlImportPreviewWarning =>
      'La planimetria attuale verrà eliminata e sostituita e le impostazioni dello spazio verranno sovrascritte. L\'operazione non può essere annullata.';

  @override
  String get workspaceXmlImportConfirm => 'Sostituisci e importa';

  @override
  String get workspaceXmlImportSuccess => 'Spazio importato.';

  @override
  String get workspaceXmlErrorMalformed => 'Il file non è un XML leggibile.';

  @override
  String get workspaceXmlErrorWrongRoot =>
      'Questo non è un file di spazio DesKilo.';

  @override
  String get workspaceXmlErrorUnsupportedVersion =>
      'Il file è stato esportato da una versione più recente di DesKilo e non può essere importato.';

  @override
  String get workspaceXmlErrorMissingElement =>
      'Il file è incompleto — manca una sezione obbligatoria.';

  @override
  String get workspaceXmlErrorMissingAttribute =>
      'Il file è incompleto — manca un valore obbligatorio.';

  @override
  String get workspaceXmlErrorInvalidValue =>
      'Il file contiene un valore non valido e non può essere importato.';

  @override
  String get workspaceXmlErrorInvalidPlan =>
      'La planimetria nel file non è valida: stanze, scrivanie o postazioni si sovrappongono o escono dalla loro area.';

  @override
  String get workspaceXmlImportReservationsError =>
      'Questo spazio ha già delle prenotazioni, quindi la planimetria non può essere sostituita. L\'importazione è possibile solo prima della prima prenotazione.';
}
