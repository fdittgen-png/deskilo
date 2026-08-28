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
      'Mezze giornate: le prenotazioni coprono la mattina, il pomeriggio o l\'intera giornata lavorativa — le finestre seguono l\'orario di lavoro configurato.';

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
  String get availabilityGranularityHours =>
      'Orari reali (da–a esatto, mezze/giornate come scorciatoie)';

  @override
  String get availabilityWorkHoursTitle => 'Orario di lavoro';

  @override
  String get availabilityWorkHoursDescription =>
      'Le finestre di mezza giornata e giornata intera ovunque — prenotazioni, check-in e fatturazione — seguono questo orario.';

  @override
  String get availabilityWorkStart => 'Inizio giornata';

  @override
  String get availabilityHalfBoundary => 'Limite di mezza giornata';

  @override
  String get availabilityWorkEnd => 'Fine giornata';

  @override
  String get availabilityHalfDayHours => 'Ore fatturate come mezza giornata';

  @override
  String get availabilityFullDayHours => 'Ore fatturate come giornata intera';

  @override
  String availabilityHourOption(int count) {
    return '$count h';
  }

  @override
  String get availabilityWorkHoursInvalid =>
      'Deve valere: inizio < limite di mezza giornata < fine.';

  @override
  String get availabilityPoliciesTitle => 'Regole di prenotazione';

  @override
  String get policyAllowPastTitle => 'Consenti prenotazioni passate';

  @override
  String get policyAllowPastDesc =>
      'I membri possono registrare una prenotazione già terminata.';

  @override
  String get policyAdminCheckoutTitle =>
      'Gli amministratori possono fare il check-out dei membri';

  @override
  String get policyAdminCheckoutDesc =>
      'Un amministratore può terminare il check-in in corso di un membro.';

  @override
  String get policyOutsideHoursTitle => 'Fuori dagli orari di apertura';

  @override
  String get policyOutsideHoursDesc =>
      'Che cosa è possibile fuori dalla giornata lavorativa: una sola risposta, per tutte le granularità. Una prenotazione che tocca gli orari di lavoro è una prenotazione normale.';

  @override
  String get policyOutsideHoursOff => 'Vietato';

  @override
  String get policyOutsideHoursOffDesc =>
      'Niente fuori dagli orari: né prenotazioni in anticipo, né check-in spontanei, e anche una prenotazione che sfora la fine della giornata viene rifiutata.';

  @override
  String get policyOutsideHoursWalkUp => 'Solo spontaneo';

  @override
  String get policyOutsideHoursWalkUpDesc =>
      'I check-in spontanei restano possibili, straordinari serali compresi; prenotare in anticipo fuori dagli orari viene rifiutato.';

  @override
  String get policyOutsideHoursFree => 'Gratis';

  @override
  String get policyOutsideHoursFreeDesc =>
      'Consentito, mai contato né addebitato: pura informazione di presenza.';

  @override
  String get policyOutsideHoursCharged => 'A pagamento';

  @override
  String get policyOutsideHoursChargedDesc =>
      'Consentito e contato come uso normale, salvo nei giorni in cui il membro ha già una prenotazione normale.';

  @override
  String get policySimultaneousTitle => 'Prenotazioni simultanee per membro';

  @override
  String get policySimultaneousDesc =>
      'Quante prenotazioni sovrapposte può avere un membro. 1 mantiene un solo posto alla volta.';

  @override
  String get policyLimitsTitle => 'Limiti di prenotazione';

  @override
  String get policyLimitsDesc =>
      'Con quanto anticipo si può prenotare e quale durata è accettata. Valgono su ogni granularità.';

  @override
  String get policyHorizonTitle => 'Orizzonte di prenotazione';

  @override
  String get policyHorizonDesc =>
      'Quanti giorni prima può iniziare una prenotazione. Oltre, viene rifiutata.';

  @override
  String get policyMinDurationTitle => 'Durata minima';

  @override
  String get policyMinDurationDesc =>
      'La prenotazione più breve accettata. Per questo arrivare alle 11:45 per il limite delle 12:00 viene rifiutato: troppo corta.';

  @override
  String get policyMaxDurationTitle => 'Durata massima';

  @override
  String get policyMaxDurationDesc =>
      'La prenotazione più lunga accettata. Una prenotazione finisce nel giorno in cui inizia, quindi la giornata intera è il tetto.';

  @override
  String get policyDurationConflict =>
      'Il minimo non può superare il massimo — nessuna prenotazione verrebbe accettata.';

  @override
  String policyDaysValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String policyMinutesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuti',
      one: '1 minuto',
    );
    return '$_temp0';
  }

  @override
  String policyHoursValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ore',
      one: '1 ora',
    );
    return '$_temp0';
  }

  @override
  String get myBadgeTitle => 'Il mio badge';

  @override
  String get badgeSignInTitle => 'Accedi con il badge';

  @override
  String get badgeSignInTapPrompt => 'Avvicina il badge al telefono.';

  @override
  String get badgeSignInNoReader =>
      'Nessun lettore di badge disponibile su questo dispositivo.';

  @override
  String get badgeSignInRetry => 'Riprova';

  @override
  String badgeSignInHello(String name) {
    return 'Ciao $name';
  }

  @override
  String get badgeSignInPinLabel => 'Il tuo PIN';

  @override
  String get badgeSignInButton => 'Accedi';

  @override
  String get badgeSignInUseEmail => 'Usa la mia e-mail';

  @override
  String get badgeSignInRefused =>
      'Non ha funzionato. Controlla il badge e il PIN, oppure accedi con la tua e-mail.';

  @override
  String get badgeSignInLocked =>
      'Troppi tentativi. Attendi qualche minuto, oppure accedi con la tua e-mail.';

  @override
  String get badgeSignInUnavailable =>
      'L’accesso con badge non è raggiungibile ora. Accedi con la tua e-mail.';

  @override
  String get badgeSignInEntry => 'Accedi con un badge';

  @override
  String get badgePinSectionTitle => 'Il mio badge';

  @override
  String get badgePinSet => 'PIN impostato';

  @override
  String get badgePinNotSet => 'Nessun PIN';

  @override
  String get badgePinExplain =>
      'Il PIN ti permette di accedere scansionando il badge invece di digitare la tua e-mail. Solo tu puoi impostarlo e nessuno — nemmeno un proprietario — può rileggerlo.';

  @override
  String get badgePinSetAction => 'Imposta un PIN';

  @override
  String get badgePinChangeAction => 'Cambia PIN';

  @override
  String get badgePinClearAction => 'Rimuovi PIN';

  @override
  String get badgePinNewLabel => 'Nuovo PIN';

  @override
  String get badgePinConfirmLabel => 'Ripetilo';

  @override
  String get badgePinMismatch => 'Le due voci non coincidono.';

  @override
  String badgePinTooShort(int min) {
    return 'Usa almeno $min cifre.';
  }

  @override
  String get badgePinSaved => 'PIN salvato.';

  @override
  String get badgePinCleared =>
      'PIN rimosso. I tuoi badge non ti fanno più accedere.';

  @override
  String get badgeAuthEnabledLabel => 'Mi fa accedere';

  @override
  String get badgeAuthEnabledHint =>
      'Disattivo per impostazione predefinita: un badge che registra la tua entrata non ti fa accedere finché non lo decidi tu.';

  @override
  String get badgeAuthNeedsPin =>
      'Imposta prima un PIN di accesso — il badge da solo non deve mai bastare.';

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
  String billInvoiceCard(String number) {
    return 'Fattura $number';
  }

  @override
  String billCreditNoteCard(String number) {
    return 'Nota di credito $number';
  }

  @override
  String get billInvoiceTotal => 'Totale fattura';

  @override
  String get billInvoicePaid => 'Già pagato';

  @override
  String get billInvoiceRemaining => 'Residuo da pagare';

  @override
  String get billCreditNoteDue =>
      'Lo spazio ti deve questo importo: non hai nulla da pagare.';

  @override
  String get billCreditNoteRefunded =>
      'Lo spazio ti ha rimborsato questo importo.';

  @override
  String get accountCardTitle => 'Il tuo conto';

  @override
  String get accountCredit => 'Credito disponibile';

  @override
  String get accountRefundDue => 'Rimborso dovuto dallo spazio';

  @override
  String get accountNet => 'Posizione netta';

  @override
  String accountOpenPartial(String period, String paid) {
    return '$period · $paid pagati';
  }

  @override
  String get accountImputationHint =>
      'Il tuo credito può saldare le fatture aperte: lo spazio lo imputa durante la riconciliazione dei pagamenti.';

  @override
  String get invoiceExportSafTPt => 'SAF-T (Portogallo)';

  @override
  String get invoiceExportDatev => 'DATEV (Buchungsstapel)';

  @override
  String get invoiceExportSage => 'Sage 50 (giornale di audit)';

  @override
  String get invoiceExportAccountantCsv => 'CSV contabile';

  @override
  String get invoiceExportAuditTrail => 'Pista di controllo';

  @override
  String get exportClaimRegulatory =>
      'Il formato richiesto dalla tua amministrazione fiscale.';

  @override
  String get exportClaimExchange =>
      'Perché il tuo commercialista lo importi e lo verifichi — non è una dichiarazione.';

  @override
  String get exportClaimSubset =>
      'Solo fatture e pagamenti, senza libro mastro. Il file lo dichiara nella propria intestazione.';

  @override
  String get exportUncertifiedSoftware =>
      'Prodotto secondo la specifica pubblicata, ma DesKilo non è software certificato in questo paese — verifica con il tuo commercialista se ti è richiesto.';

  @override
  String get datevAccountsTitle => 'Esportazione DATEV';

  @override
  String get datevAccountsIntro =>
      'I numeri di consulente e di cliente te li dà il commercialista. DATEV rifiuta un file con numeri non corrispondenti — ed è proprio questo che lo tiene fuori dai libri dell’azienda sbagliata.';

  @override
  String get datevConsultantNumber => 'Beraternummer (n. consulente)';

  @override
  String get datevClientNumber => 'Mandantennummer (n. cliente)';

  @override
  String get sageAccountsTitle => 'Esportazione Sage';

  @override
  String get sageAccountsIntro =>
      'I valori predefiniti sono i conti che Sage fornisce di serie. Il codice IVA decide su quale dichiarazione finiscono queste scritture: verificalo con il commercialista se non sei all’aliquota ordinaria.';

  @override
  String get sageTaxCode => 'Codice IVA (T1 / T0 / T9)';

  @override
  String get saftLedgerTitle => 'Includere le scritture?';

  @override
  String get saftLedgerIntro =>
      'Con i numeri di conto il file porta scritture in partita doppia che il tuo commercialista può importare invece di digitare. Coprono le vendite e i relativi incassi — non l’intera contabilità.';

  @override
  String get saftDocumentsOnly => 'Solo documenti';

  @override
  String get saftWithPostings => 'Con le scritture';

  @override
  String get billPdfTitle => 'Fattura mensile';

  @override
  String get billPdfExport => 'Esporta la fattura come PDF';

  @override
  String get reportCoaTitle => 'Piano dei conti — anteprima';

  @override
  String get reportCoaIntro =>
      'Un suggerimento, non la tua contabilità. Sono i conti che un contabile del tuo paese userebbe di solito per uno spazio come il tuo.';

  @override
  String get reportCoaAccounts => 'Conti suggeriti';

  @override
  String get reportCoaNumber => 'Conto';

  @override
  String get reportCoaLabel => 'Denominazione';

  @override
  String get reportCoaDisclaimer =>
      'Solo un\'anteprima. DesKilo non tiene un libro mastro e non fa la tua contabilità — il piano del tuo commercialista prevale sempre.';

  @override
  String get reportBadgesTitle => 'Badge dei membri';

  @override
  String get reportBadgesIntro =>
      'Taglia lungo le linee. Ogni tessera porta il codice badge di un membro — mostrala al chiosco per il check-in.';

  @override
  String get reportBadgesFooter =>
      'Un badge perso va revocato in Membri e piani, non semplicemente sostituito.';

  @override
  String get reportSpaceCodesTitle => 'Codici degli spazi';

  @override
  String get reportSpaceCodesIntro =>
      'Una tessera per postazione, tavolo, sala e piano. Attaccala sul suo spazio: scansionarla apre la stessa scheda del chiosco.';

  @override
  String get reportSpaceCodesFooter =>
      'Una scheda che non corrisponde più al suo spazio inganna chi la scansiona: ristampa il foglio dopo aver spostato o rinominato uno spazio.';

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
  String get reservationExtendButton => 'Restare più a lungo';

  @override
  String get reservationExtendLaterOnly =>
      'Scegli un orario dopo la fine attuale.';

  @override
  String get reservationEndEarlyButton => 'Terminare prima';

  @override
  String get reservationEndEarlyAheadOnly =>
      'Scegli un orario ancora futuro e precedente alla fine attuale.';

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
  String get commonRetry => 'Riprova';

  @override
  String get settingsSectionAbout => 'Informazioni';

  @override
  String aboutVersion(String version) {
    return 'Versione $version';
  }

  @override
  String get aboutOpenSource => 'Open source (licenza 0BSD)';

  @override
  String get aboutOpenSourceDesc => 'Codice sorgente su GitHub';

  @override
  String get aboutPrivacy => 'Informativa sulla privacy';

  @override
  String get aboutReportBug => 'Segnala un bug / suggerisci una funzione';

  @override
  String get aboutSupportTitle => 'Sostieni questo progetto';

  @override
  String get aboutSupportBody =>
      'Questa app è gratuita, open source e senza pubblicità. Se la trovi utile, sostieni lo sviluppatore.';

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
  String get coOwnerAction => 'Comproprietà';

  @override
  String get coOwnerNone => 'Nessun ruolo di comproprietario';

  @override
  String get coOwnerActive =>
      'Comproprietario attivo — permessi da proprietario subito, successione automatica';

  @override
  String get coOwnerPassive =>
      'Comproprietario passivo — diventa proprietario all\'attivazione o quando il proprietario se ne va';

  @override
  String get coOwnerActivate => 'Promuovi a proprietario ora';

  @override
  String get memberCoOwnerChip => 'Comproprietario';

  @override
  String get memberCoOwnerPassiveChip => 'Comproprietario (passivo)';

  @override
  String get developerMode => 'Modalità sviluppatore';

  @override
  String get developerModeWorkspaceHint =>
      'Vale per tutti i membri di questo spazio.';

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
  String get pushStatusRegistered => 'Le notifiche push sono attive';

  @override
  String get pushStatusNotConfigured =>
      'Le notifiche push non sono ancora configurate';

  @override
  String get pushStatusNotConfiguredHint =>
      'Il proprietario completa la configurazione Firebase (guida push-setup).';

  @override
  String get notificationsSystemOff =>
      'Android sta bloccando le notifiche di DesKilo';

  @override
  String get notificationsSystemOffHint =>
      'Consentile in Impostazioni di sistema → App → DesKilo → Notifiche — il badge dell\'icona ne ha bisogno.';

  @override
  String get developerExportReservations => 'Esporta le prenotazioni';

  @override
  String get developerExportReservationsHint =>
      'Tutte le prenotazioni e i check-in — passati, presenti e futuri, in ogni stato — in CSV, per analisi e debug.';

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
  String get editorSeatNfcLabel => 'Tag NFC/RFID';

  @override
  String get editorSeatNfcHelp =>
      'UID del tag in esadecimale — lasciare vuoto per nessun tag.';

  @override
  String get editorSeatNfcRead => 'Leggi un tag ora';

  @override
  String get editorSeatNfcReadFailed =>
      'Impossibile avviare il lettore di tag.';

  @override
  String get editorSeatNfcDuplicate =>
      'Questo tag è già collegato a un\'altra sedia.';

  @override
  String get editorDeleteElementConfirmAudit =>
      'Eliminare questo elemento? Anche tutto ciò che vi è collocato viene rimosso. Le prenotazioni che vi fanno riferimento conservano un\'istantanea di testo per gli audit; le prenotazioni aperte vengono annullate.';

  @override
  String get editorDeleteLevelConfirmAudit =>
      'Eliminare questo piano? Tutti gli uffici, i tavoli e i posti su di esso vengono rimossi. Le prenotazioni che vi fanno riferimento conservano un\'istantanea di testo per gli audit; le prenotazioni aperte vengono annullate.';

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
  String get pushCancelledTitle => 'Prenotazione rimossa';

  @override
  String get pushCancelledBody =>
      'Una prenotazione è stata rimossa da un admin.';

  @override
  String get eventTypeReservationDelete => 'Eliminazione prenotazione';

  @override
  String eventReservationDeleteLine(String actor, String date, String state) {
    return '$actor chiede di eliminare la prenotazione del $date ($state)';
  }

  @override
  String get eventReservationDeleteCheckedIn => 'con check-in';

  @override
  String get eventReservationDeleteUnused => 'mai usata';

  @override
  String get eventAutoValidated => 'Convalidato automaticamente';

  @override
  String get reservationDeleteRequestButton => 'Richiedi eliminazione';

  @override
  String get reservationDeleteRequestExplain =>
      'Le prenotazioni passate o con check-in non vengono eliminate direttamente. Un proprietario o admin deciderà: il check-in è stato semplicemente dimenticato (la prenotazione resta) o non è mai stata usata (viene rimossa)?';

  @override
  String get reservationDeleteReasonLabel => 'Motivo (facoltativo)';

  @override
  String get reservationDeleteSubmit => 'Invia richiesta';

  @override
  String get reservationDeleteSubmitted =>
      'Eliminazione richiesta — un proprietario o admin deciderà.';

  @override
  String get notifCategoryCheckIns => 'Check-in';

  @override
  String get notifCategoryMoney => 'Finanze';

  @override
  String get notifCategoryMembers => 'Membri';

  @override
  String get notesFilterRead => 'Letti';

  @override
  String get notifSortByDate => 'Ordina per data';

  @override
  String get notifGroupBy => 'Raggruppa per';

  @override
  String get notifGroupByType => 'Tipo';

  @override
  String get notifGroupByDate => 'Data';

  @override
  String get notifGroupByUser => 'Membro';

  @override
  String get notifUngroup => 'Rimuovi raggruppamento';

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
  String get featureLevelBooking => 'Prenotazioni di tavolo, ufficio e piano';

  @override
  String get featureLevelBookingDesc =>
      'Prenota un intero tavolo, ufficio o piano come un\'unica prenotazione, con prezzo per mezza giornata. Concedi il diritto per membro.';

  @override
  String get featureAdminLevelAssign => 'Gli admin possono assegnare piani';

  @override
  String get featureAdminLevelAssignDesc =>
      'Gli admin assegnano prenotazioni di piano ai membri. Il proprietario può sempre.';

  @override
  String get featureKioskMode => 'Modalità chiosco';

  @override
  String get featureKioskModeDesc =>
      'Account tablet a parete bloccati sulla piantina live; i membri agiscono col badge.';

  @override
  String get featureMembersDirectory => 'Elenco dei membri';

  @override
  String get featureMembersDirectoryDesc =>
      'La scheda comunità: chi c\'è, stati, presenza.';

  @override
  String get featureWhatsappIntegration => 'Integrazione WhatsApp';

  @override
  String get featureWhatsappIntegrationDesc =>
      'Scrivere ai membri su WhatsApp e collegare il gruppo della comunità.';

  @override
  String get featureSpaceQrCodes => 'Codici QR degli spazi';

  @override
  String get featureSpaceQrCodesDesc =>
      'Schede QR stampabili per postazione, tavolo, ufficio e piano — scansiona per prenotare o fare check-in.';

  @override
  String featureRequires(String feature) {
    return 'Richiede $feature';
  }

  @override
  String get featureCoOwner => 'Comproprietari';

  @override
  String get featureCoOwnerDesc =>
      'Nominare comproprietari: permessi da proprietario subito (attivo) o successione in attesa (passivo).';

  @override
  String get featureAutoCheckInOut => 'Check-in/out automatico a fine giornata';

  @override
  String get featureDataExport => 'Esportazione dati (Excel)';

  @override
  String get featureAutoCheckInOutDesc =>
      'Le prenotazioni senza check-in o check-out si completano da sole una volta trascorso il loro orario.';

  @override
  String get featureDataExportDesc =>
      'Scaricare tutti i dati dello spazio in una cartella Excel.';

  @override
  String get featureWorkingHours => 'Orario di lavoro';

  @override
  String get featureWorkingHoursDesc =>
      'Configura la giornata lavorativa e offri prenotazioni a orari esatti; disattivato valgono i valori 8:00–17:00.';

  @override
  String get featureInvoicePdfTemplate => 'Modello PDF della fattura';

  @override
  String get featureInvoicePdfTemplateDesc =>
      'Introduzione e piè di pagina scritti dal proprietario sul PDF della fattura. Non tocca mai l\'XML della fattura elettronica.';

  @override
  String get featureMemberNotifications => 'Notifiche tra membri';

  @override
  String get featureMemberNotificationsDesc =>
      'Invia una breve notifica a un altro membro; gli admin possono notificare tutti gli admin, proprietario incluso.';

  @override
  String get featureDunning => 'Solleciti di pagamento (Mahnwesen)';

  @override
  String get featureDunningDesc =>
      'Regole di sollecito configurabili e avvisi «Sollecito dovuto» sulle fatture scadute. Nulla viene mai inviato automaticamente.';

  @override
  String get featureMemberReports => 'Report dei membri';

  @override
  String get featureMemberReportsDesc =>
      'L\'accordo finanziario e il report mensile dei pagamenti — self-service per i membri, inviabili per membro.';

  @override
  String get featureDeletionRequests =>
      'Richieste di eliminazione prenotazioni';

  @override
  String get featureDeletionRequestsDesc =>
      'I membri possono RICHIEDERE l\'eliminazione di una prenotazione passata o con check-in; un proprietario/admin convalida. Disattivato, tali prenotazioni non sono eliminabili.';

  @override
  String get featurePlanObjectDeleteTitle => 'Eliminare spazi con cronologia';

  @override
  String get featurePlanObjectDeleteDesc =>
      'I proprietari possono eliminare piani, uffici, tavoli e posti anche se prenotazioni passate vi fanno riferimento: le prenotazioni conservano un\'istantanea di testo per audit e report.';

  @override
  String get featureNotificationGroupingTitle =>
      'Raggruppamento delle notifiche';

  @override
  String get featureNotificationGroupingDesc =>
      'I membri possono raggruppare il feed delle notifiche per tipo, giorno o membro; toccando il simbolo del gruppo si torna all\'elenco piatto.';

  @override
  String get featureBookingPoliciesTitle => 'Regole di prenotazione';

  @override
  String get featureBookingPoliciesDesc =>
      'Comportamento di prenotazione configurabile: prenotazioni passate, prenotazioni al minuto fuori orario e check-out da parte degli amministratori.';

  @override
  String get featureNfcSeatTagsTitle => 'Tag NFC/RFID delle sedie';

  @override
  String get featureNfcSeatTagsDesc =>
      'Un tag NFC/RFID fisico su una sedia porta al suo posto come la scheda QR stampata; il campo si compila avvicinando il chip.';

  @override
  String get featureQrBadgesTitle => 'Badge QR';

  @override
  String get featureQrBadgesDesc =>
      'Schede badge QR stampabili per il chiosco, accanto alle carte NFC/RFID.';

  @override
  String get featureFormHelpHintsTitle => 'Suggerimenti di aiuto';

  @override
  String get featureFormHelpHintsDesc =>
      'Brevi suggerimenti richiudibili su moduli e schermate, ognuno collegato alla sezione corrispondente della guida.';

  @override
  String get featureUiAnimationsTitle => 'Animazioni dell\'interfaccia';

  @override
  String get featureUiAnimationsDesc =>
      'Transizioni fluide e animazioni di stato in tutta l\'app. Disattivato, ogni cambiamento è istantaneo; l\'impostazione di riduzione del movimento del dispositivo prevale sempre.';

  @override
  String get featureKioskMemberPhotosTitle => 'Foto dei membri al chiosco';

  @override
  String get featureKioskMemberPhotosDesc =>
      'La ricevuta del chiosco mostra la foto del profilo del membro — il controllo visivo del badge sbagliato.';

  @override
  String get featurePlanMemberPhotosTitle => 'Foto dei membri sulla piantina';

  @override
  String get featurePlanMemberPhotosDesc =>
      'I posti occupati nella scheda Piantina e nel hub Prenota mostrano la foto del profilo al posto dell’iniziale.';

  @override
  String get featureBadgeSignInTitle => 'Accesso con badge';

  @override
  String get featureBadgeSignInDesc =>
      'I membri possono accedere scansionando il proprio badge e inserendo il PIN, invece di digitare un\'e-mail su un tablet condiviso. Ogni membro imposta il proprio PIN e attiva il proprio badge.';

  @override
  String get helpTitle => 'Aiuto';

  @override
  String get helpContents => 'Indice';

  @override
  String get helpHintLearnMore => 'Scopri di più';

  @override
  String get helpHintDismiss => 'Nascondi suggerimento';

  @override
  String get helpHintPrevTip => 'Suggerimento precedente';

  @override
  String get helpHintNextTip => 'Suggerimento successivo';

  @override
  String get helpHintRestoreTitle => 'Mostra di nuovo i suggerimenti di aiuto';

  @override
  String get helpHintRestored =>
      'I suggerimenti di aiuto saranno mostrati di nuovo.';

  @override
  String get helpHintReserve =>
      'Scegli un giorno e una fascia oraria, poi tocca un posto libero per prenotarlo.';

  @override
  String get helpHintReserveTopic => 'hub Prenota';

  @override
  String get helpHintReserveTip2 =>
      'Le viste Settimana e Mese trovano una mezza giornata libera a colpo d\'occhio: tocca una cella o un giorno libero per prenotare al volo.';

  @override
  String get helpHintReserveTip3 =>
      'Tocca il pulsante di scansione e inquadra la tessera QR di uno spazio: la scheda mostra esattamente cosa puoi fare lì.';

  @override
  String get helpHintReserveTip3Topic => 'Scansionare un codice spazio';

  @override
  String get helpHintReserveTip4 =>
      'I chip mattina, pomeriggio e giornata intera fissano la fascia prima di scegliere il posto: una mattina prenotata vale mezza giornata.';

  @override
  String get helpHintReserveTip4Topic => 'Come si comporta la prenotazione';

  @override
  String get helpHintReserveTip5 =>
      'Imposta il tuo periodo di prenotazione predefinito nelle Impostazioni: l\'hub lo preseleziona a ogni visita.';

  @override
  String get helpHintReserveTip5Topic => 'Impostazioni e profilo';

  @override
  String get helpHintPlan =>
      'La piantina dal vivo: tocca un posto libero per prenotare, tocca la tua prenotazione per fare il check-in.';

  @override
  String get helpHintPlanTopic => 'Piantina';

  @override
  String get helpHintPlanTip2 =>
      'Sei davanti a un posto libero? Toccalo: la scheda propone da adesso fino alla chiusura, e confermando fai subito il check-in.';

  @override
  String get helpHintPlanTip3 =>
      'Sfoglia un altro momento con il chip della data e il selettore orario: la piantina mostra chi occupa cosa in qualsiasi istante futuro.';

  @override
  String get helpHintPlanTip4 =>
      'Tocca due volte una scrivania, una stanza o l\'intero piano — o l\'icona dei livelli sulla barra dei piani — per prenotare tutto lo spazio in una volta.';

  @override
  String get helpHintPlanTip5 =>
      'Tocca il tuo posto per aprire la sua scheda: check-in da 15 minuti prima dell\'inizio, check-out quando vai via.';

  @override
  String get helpHintPlanTip5Topic => 'Come si comporta la prenotazione';

  @override
  String get helpHintCalendar =>
      'Sfoglia le prenotazioni mese per mese; tocca un giorno per vedere e gestire le sue prenotazioni.';

  @override
  String get helpHintCalendarTopic => 'Calendario';

  @override
  String get helpHintCalendarTip2 =>
      'L\'interruttore Mie / Tutti mostra solo le tue prenotazioni o quelle di tutta la comunità: i punti rossi sono i tuoi, i blu degli altri.';

  @override
  String get helpHintCalendarTip3 =>
      'L\'interruttore di vista alterna la metà inferiore tra la griglia settimanale e l\'elenco agenda; i chip dei piani filtrano entrambe.';

  @override
  String get helpHintCalendarTip4 =>
      'Annullare un\'occorrenza di una serie offre «questa e le successive»: le occorrenze con check-in o completate conservano la loro storia.';

  @override
  String get helpHintCalendarTip4Topic => 'Come si comporta la prenotazione';

  @override
  String get helpHintEvents =>
      'Tutto quello che è successo, in un unico feed. Le decisioni in attesa stanno in alto; i filtri restringono il resto.';

  @override
  String get helpHintEventsTopic => 'Eventi';

  @override
  String get helpHintEventsTip2 =>
      'I chip di filtro ricordano la tua scelta da una visita all\'altra, e il chip Non letti riduce l\'elenco ai messaggi da leggere.';

  @override
  String get helpHintEventsTip3 =>
      'Raggruppa il feed per tipo, giorno o membro dal menu Raggruppa per; tocca il simbolo del gruppo per tornare all\'elenco piatto.';

  @override
  String get helpHintEventsTip4 =>
      'Le decisioni in sospeso restano fissate in alto con Accetta e rifiuta, e nessuno convalida mai il proprio evento.';

  @override
  String get helpHintEditor =>
      'Disegna stanze e scrivanie, timbra i posti — tocca due volte un posto per modificarne le proprietà.';

  @override
  String get helpHintEditorTopic => 'editor dello spazio';

  @override
  String get helpHintEditorTip2 =>
      'Scegli Ufficio o Tavolo nella barra degli strumenti e trascina sulla griglia per disegnarlo; Seleziona sposta e ridimensiona ciò che c\'è già.';

  @override
  String get helpHintEditorTip3 =>
      'Lo strumento Posto timbra i posti sulle scrivanie; la scheda di un posto imposta orientamento, tipo di sedia, accessori e un blocco per manutenzione.';

  @override
  String get helpHintEditorTip4 =>
      'Assegna a un posto il suo tag NFC/RFID dalla sua scheda: avvicina il chip al telefono e il campo si riempie da solo.';

  @override
  String get helpHintEditorTip5 =>
      'Stampa una tessera QR per ogni posto, scrivania, ufficio e piano: scegli la dimensione della tessera e cosa mostra prima di esportare.';

  @override
  String get helpHintEditorTip5Topic => 'Codici QR degli spazi';

  @override
  String get helpHintAvailability =>
      'Imposta i giorni di apertura e gli orari, e aggiungi giorni di chiusura che nessuno può prenotare.';

  @override
  String get helpHintAvailabilityTopic => 'Disponibilità';

  @override
  String get helpHintAvailabilityTip2 =>
      'La granularità di prenotazione decide la forma di una fascia: mezze giornate, giornate intere, griglie ai minuti oppure orari liberi.';

  @override
  String get helpHintAvailabilityTip3 =>
      'Inizio giornata, limite della mezza giornata e fine giornata guidano ogni fascia: prenotazione, check-in e fatturazione li seguono.';

  @override
  String get helpHintAvailabilityTip4 =>
      'Tre regole di prenotazione stringono o allentano le maglie: prenotazioni passate, minuti confinati all\'orario di lavoro, check-out da admin.';

  @override
  String get helpHintFeatures =>
      'Attiva o disattiva le funzionalità dello spazio: l\'app di ogni membro si aggiorna subito.';

  @override
  String get helpHintFeaturesTopic => 'Funzionalità';

  @override
  String get helpHintFeaturesTip2 =>
      'L\'elenco è gerarchico: una funzionalità che ne richiede un\'altra sta rientrata sotto di essa e si attenua finché il genitore è spento.';

  @override
  String get helpHintFeaturesTip3 =>
      'Spegnere un genitore toglie dall\'app l\'intero sottoalbero; le scelte salvate dei figli tornano intatte insieme al genitore.';

  @override
  String get helpHintFeaturesTip4 =>
      'La voce di impostazioni di una funzionalità compare solo mentre è attiva; la schermata Funzionalità, invece, resta sempre raggiungibile.';

  @override
  String get helpHintMembers =>
      'Invita membri, imposta piano e ruolo, e gestisci i loro badge.';

  @override
  String get helpHintMembersTopic => 'Membri e piani';

  @override
  String get helpHintMembersTip2 =>
      'Tocca un membro per la sua scheda di gestione: abbonamento, limite di prenotazioni, badge, servizi e altro in un unico posto.';

  @override
  String get helpHintMembersTip3 =>
      'I badge sono per membro: emetti un badge QR stampabile o registra la sua tessera NFC avvicinandola al dispositivo.';

  @override
  String get helpHintMembersTip3Topic => 'badge RFID';

  @override
  String get helpHintMembersTip4 =>
      'Nomina admin concede i permessi dopo la convalida; la matrice dei ruoli sotto Gestione dei ruoli decide cosa può fare ogni ruolo.';

  @override
  String get helpHintMembersTip4Topic => 'Gestione dei ruoli';

  @override
  String get helpHintMoney =>
      'Il conto mensile: sfoglia i mesi con le frecce; paga, esporta o condividi da qui.';

  @override
  String get helpHintMoneyTopic => 'Denaro';

  @override
  String get helpHintMoneyTip2 =>
      'Ogni documento offre le stesse tre azioni: anteprima rapida sullo schermo, download in PDF e condivisione con qualsiasi app.';

  @override
  String get helpHintMoneyTip2Topic => 'Anteprima rapida, scarica, condividi';

  @override
  String get helpHintMoneyTip3 =>
      'Registra un pagamento con la data del movimento e il mese che salda: l\'altra parte conferma.';

  @override
  String get helpHintMoneyTip4 =>
      'Una volta fatturato il mese, decide la fattura: il mese risulta saldato appena la sua fattura è pagata.';

  @override
  String get helpHintMoneyTip4Topic => 'decide la fattura';

  @override
  String get helpHintValidation =>
      'Decidi quali azioni richiedono conferma, chi conferma e quante approvazioni servono.';

  @override
  String get helpHintValidationTopic => 'conferme';

  @override
  String get helpHintValidationTip2 =>
      'Una scheda per tipo di evento, ognuna eredita dalla regola predefinita finché non la modifichi: pagamenti, spese, cambi di ruolo e altro.';

  @override
  String get helpHintValidationTip3 =>
      'Nessuno convalida mai il proprio evento, e una richiesta senza risposta scade dopo 7 giorni: nulla viene concesso in silenzio.';

  @override
  String get helpHintWorkspace =>
      'Paese, valuta, lingua e dati di fatturazione: documenti e imposte seguono queste impostazioni.';

  @override
  String get helpHintWorkspaceTopic => 'Impostazioni dello spazio';

  @override
  String get helpHintWorkspaceTip2 =>
      'Stampa le tessere QR degli spazi dalle Esportazioni: scegli la dimensione e le informazioni di ogni tessera, dieci per pagina A4.';

  @override
  String get helpHintWorkspaceTip2Topic => 'Codici QR degli spazi';

  @override
  String get helpHintWorkspaceTip3 =>
      'Esporta lo spazio in XML per farne una copia o un modello; il questionario di configurazione prepara uno spazio nuovo da cima a fondo.';

  @override
  String get helpHintWorkspaceTip4 =>
      'Ripristina lo spazio cancella prenotazioni, contabilità e piantina: impostazioni e membri sopravvivono, e una conferma digitata protegge l\'azione.';

  @override
  String get helpHintBadges =>
      'Emetti un badge QR stampabile o registra una tessera NFC; revoca i badge persi in qualsiasi momento.';

  @override
  String get helpHintBadgesTopic => 'badge RFID';

  @override
  String get helpHintBadgesTip2 =>
      'Registra una tessera avvicinandola al dispositivo: qualsiasi chip leggibile funziona, e la finestra indica lo spazio a cui si associa.';

  @override
  String get helpHintBadgesTip3 =>
      'Salva un badge QR come PDF per stampare dieci copie formato carta di credito su una pagina A4, scorte comprese.';

  @override
  String get helpHintBadgesTip4 =>
      'Revoca un badge perso in qualsiasi momento; scorri un badge revocato verso destra per eliminarlo definitivamente.';

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
  String get invoicesTitle => 'Fatture';

  @override
  String get invoicesEmpty => 'Ancora nessuna fattura.';

  @override
  String get invoiceCreate => 'Nuova fattura';

  @override
  String get invoiceMemberLabel => 'Membro';

  @override
  String get invoiceIssue => 'Emetti fattura';

  @override
  String get invoiceIssued => 'Fattura emessa.';

  @override
  String get invoiceDownload => 'Scarica PDF';

  @override
  String get invoiceShare => 'Condividi PDF';

  @override
  String get invoicePdfTitle => 'Fattura';

  @override
  String get invoicePdfIssuedOn => 'Emessa il';

  @override
  String get invoicePdfIssuedBy => 'Emessa da';

  @override
  String get invoicePdfBilledTo => 'Intestata a';

  @override
  String get invoicePdfSignature => 'Firma digitale (SHA-256)';

  @override
  String get addressTitle => 'Indirizzo';

  @override
  String get addressNone => 'Nessun indirizzo';

  @override
  String get addressSaved => 'Indirizzo salvato';

  @override
  String get workspaceAddressLabel => 'Indirizzo dello spazio';

  @override
  String get featureInvoicing => 'Fatture';

  @override
  String get featureInvoicingDesc =>
      'Fatture immutabili e firmate in un archivio — scarica o condividi in PDF.';

  @override
  String get featureAdminInvoicing => 'Gli admin emettono fatture';

  @override
  String get featureAdminInvoicingDesc =>
      'Anche gli admin emettono fatture. Il proprietario può sempre.';

  @override
  String get invoiceVoidedChip => 'Errata';

  @override
  String get invoiceVoidAction => 'Segna come errata';

  @override
  String invoiceVoidConfirm(String number) {
    return 'Segnare la fattura $number come errata? L\'operazione è irreversibile.';
  }

  @override
  String get invoiceVoided => 'Fattura contrassegnata come errata.';

  @override
  String get invoiceReplaceAction => 'Emetti sostitutiva';

  @override
  String get invoicePdfVoided => 'ERRATA — annullata il';

  @override
  String get invoicePdfReplaces => 'Sostituisce';

  @override
  String get invoiceNothingToInvoice =>
      'Nessun dato registrato per questo mese — niente da fatturare.';

  @override
  String get invoiceLineAdjustment => 'Rettifica';

  @override
  String get invoiceFilterAllMembers => 'Tutti i membri';

  @override
  String get invoiceFilterAllMonths => 'Tutti i mesi';

  @override
  String get invoiceFilterMonthLabel => 'Mese';

  @override
  String get invoiceSortTooltip => 'Ordina';

  @override
  String get invoiceSortNewest => 'Più recenti prima';

  @override
  String get invoiceSortByMember => 'Per membro';

  @override
  String get invoiceSortByMonth => 'Per mese';

  @override
  String get invoiceBalance => 'Saldo';

  @override
  String get invoiceDetailedToggle =>
      'Includi l\'allegato dettagliato (presenze, servizi, pagamenti)';

  @override
  String get invoicePdfDescription => 'Descrizione';

  @override
  String get invoicePdfCharges => 'Addebiti';

  @override
  String get invoicePdfPayments => 'Pagamenti';

  @override
  String get invoicePdfAnnex => 'Allegato — dettagli';

  @override
  String get invoicePdfAttendance => 'Presenze';

  @override
  String get invoicePdfActivity => 'Movimenti e pagamenti';

  @override
  String get invoicePdfReserved => 'riservato';

  @override
  String get invoicePdfPage => 'Pagina';

  @override
  String get invoiceRemindAction => 'Invia un promemoria';

  @override
  String get invoiceReminded => 'Promemoria registrato.';

  @override
  String invoiceRemindedBadge(int count) {
    return 'Sollecitato ×$count';
  }

  @override
  String invoiceReminderMessage(String number, String amount) {
    return 'Promemoria: fattura $number — saldo dovuto $amount.';
  }

  @override
  String get invoiceEInvoiceDownload => 'Scarica fattura elettronica (XML)';

  @override
  String get invoiceEInvoiceShare => 'Condividi fattura elettronica (XML)';

  @override
  String get invoiceTabToInvoice => 'Da fatturare';

  @override
  String get invoiceTabOpen => 'Aperte';

  @override
  String get invoiceTabArchive => 'Archivio';

  @override
  String get invoiceIssueAll => 'Fattura tutto';

  @override
  String get invoiceIssueOne => 'Fattura';

  @override
  String get invoiceAllCaughtUp => 'Tutto in ordine — niente da fatturare.';

  @override
  String get invoiceNoOpen => 'Nessuna fattura aperta.';

  @override
  String invoiceSummaryToInvoice(int count) {
    return '$count da fatturare';
  }

  @override
  String invoiceSummaryOpen(int count, String amount) {
    return '$count aperte · $amount in sospeso';
  }

  @override
  String invoiceOpenAge(int days) {
    return '$days giorni';
  }

  @override
  String invoiceIssuedCount(int count) {
    return '$count fatture emesse.';
  }

  @override
  String get eventTypeInvoicePayment => 'Pagamento fattura';

  @override
  String eventInvoicePaid(String number, String amount) {
    return 'Fattura $number pagata — $amount';
  }

  @override
  String get invoiceMatchAction => 'Segna come pagata';

  @override
  String get invoiceMatchNoteLabel => 'Nota';

  @override
  String get invoiceMatchNoteRequired => 'È richiesta una nota.';

  @override
  String invoiceMatchOver(String excess) {
    return 'Il membro ha pagato $excess in più.';
  }

  @override
  String get invoiceMatchCreditNote =>
      'Crea una nota di credito per l\'eccedenza';

  @override
  String get invoiceMatchForce => 'Accetta comunque (motivare)';

  @override
  String invoiceMatchUnder(String missing) {
    return 'Il membro ha pagato $missing in meno — accettare richiede una nota.';
  }

  @override
  String get invoiceMatched => 'Fattura riconciliata.';

  @override
  String get invoiceMatchPendingBadge => 'In attesa di convalida';

  @override
  String get invoiceMatchedBadge => 'Pagata';

  @override
  String get invoiceAlreadyInvoiced =>
      'Questo mese è già fatturato per questo membro.';

  @override
  String get invoiceMatchPickPayment => 'Seleziona il pagamento registrato';

  @override
  String get invoiceMatchNoPayments =>
      'Nessun pagamento registrato da riconciliare — registralo o confermalo prima.';

  @override
  String get invoiceStatusOpen => 'Aperta';

  @override
  String invoiceCountShown(int count) {
    return '$count fatture';
  }

  @override
  String get invoiceFilterNoMatch =>
      'Nessuna fattura corrisponde a questi filtri.';

  @override
  String get invoiceFilterClear => 'Azzera i filtri';

  @override
  String get invoiceShowCancelled => 'Mostra annullate';

  @override
  String invoiceReplacedBy(String number) {
    return 'Sostituita da $number';
  }

  @override
  String invoiceMatchSummary(String amount, String date) {
    return 'Pagata $amount il $date';
  }

  @override
  String invoiceRemindedLast(String date) {
    return 'ultimo sollecito $date';
  }

  @override
  String invoiceAnnexSummary(int movements, int checkIns) {
    return 'Allegato: $movements movimenti, $checkIns check-in';
  }

  @override
  String get invoicePickMember =>
      'Scegli un membro per vedere cosa ha registrato il suo mese.';

  @override
  String get invoiceRunningMonth =>
      'Questo mese è ancora in corso — le sue voci possono cambiare, e un mese si fattura una sola volta.';

  @override
  String invoiceIssueAllConfirm(int count, String month, String total) {
    return 'Emettere $count fatture per $month, $total in totale? Una fattura emessa non si modifica più — un errore si corregge con una sostituzione.';
  }

  @override
  String invoiceIssuedPartial(int issued, int failed) {
    return '$issued emesse, $failed non riuscite.';
  }

  @override
  String get invoiceEInvoiceAction => 'Fattura elettronica (XML)';

  @override
  String get invoiceEInvoiceExplain =>
      'La fattura EN 16931 leggibile dalle macchine — il file richiesto dalle amministrazioni e dai clienti business.';

  @override
  String invoiceEInvoiceBusinessRoute(String channel, String format) {
    return 'Clienti business: inviala tramite $channel nel formato $format.';
  }

  @override
  String invoiceEInvoicePublicRoute(String channel) {
    return 'Clienti della pubblica amministrazione: $channel.';
  }

  @override
  String get invoiceEInvoiceTransportPeppol =>
      'Un access point la consegna al cliente — nessuna piattaforma pubblica nel percorso.';

  @override
  String get invoiceEInvoiceTransportClearance =>
      'La piattaforma nazionale riceve prima la fattura e la inoltra — inviarla direttamente al cliente non è possibile.';

  @override
  String get invoiceEInvoiceTransportAccredited =>
      'Una piattaforma accreditata trasporta la fattura e comunica i dati all\'amministrazione fiscale per te.';

  @override
  String get invoiceEInvoiceTransportBilateral =>
      'Nessun canale è imposto: e-mail, un portale o Peppol — come concordato con il cliente.';

  @override
  String invoiceEInvoiceFormatMismatch(String channel, String format) {
    return '$channel accetta solo $format: questo file EN 16931 serve per Peppol, la pubblica amministrazione e i clienti esteri — il resto lo converte la tua piattaforma.';
  }

  @override
  String get invoiceEInvoiceReady =>
      'Pronto — questo file soddisfa la EN 16931.';

  @override
  String get invoiceEInvoiceBlockedTitle =>
      'Un validatore rifiuterebbe questo file:';

  @override
  String get invoiceEInvoiceIncompleteTitle =>
      'Valido, ma i profili nazionali più severi chiedono anche:';

  @override
  String get invoiceGapVatNotSupported =>
      'Lo spazio applica l\'IVA ma questa fattura non porta alcuna aliquota — aggiungi le aliquote ed emettila di nuovo.';

  @override
  String get invoiceGapMissingVatId =>
      'Manca la partita IVA — un venditore esente deve indicarla.';

  @override
  String get invoiceGapMissingLegalId =>
      'Manca il numero di registrazione (SIREN, HRB, CIF…) — nulla ti identifica sulla fattura.';

  @override
  String get invoiceGapMissingExemptionReason =>
      'Manca il motivo per cui non si applica l\'IVA.';

  @override
  String get invoiceGapMissingSellerCountry => 'Manca il paese dello spazio.';

  @override
  String get invoiceGapMissingBuyerCountry => 'Manca il paese del cliente.';

  @override
  String get invoiceGapNoChargeLines =>
      'Questa fattura non ha righe di addebito — il mese era interamente coperto dai pagamenti, quindi non c’è nulla da trasmettere.';

  @override
  String get invoiceGapMissingSellerCity =>
      'la città dell\'indirizzo dello spazio';

  @override
  String get invoiceGapMissingSellerPostalCode =>
      'il codice postale dell\'indirizzo dello spazio';

  @override
  String get invoiceEInvoiceFixIdentity => 'Completare l\'identità legale';

  @override
  String get legalIdentityTitle => 'Identità legale e fatturazione elettronica';

  @override
  String get legalIdentitySubtitle =>
      'Regime IVA e numeri di registrazione — richiesti dalla fattura elettronica';

  @override
  String get legalIdentityIntro =>
      'Ciò che una fattura elettronica EN 16931 deve dichiarare su di te. Le fatture già emesse conservano l’identità con cui sono state firmate.';

  @override
  String get legalIdentityRegime => 'Regime IVA';

  @override
  String get legalIdentityRegimeNotSubject =>
      'Fuori dal campo di applicazione dell\'IVA';

  @override
  String get legalIdentityRegimeExempt => 'Esente IVA (regime forfettario)';

  @override
  String get legalIdentityRegimeVatRegistered => 'Soggetto IVA (applica IVA)';

  @override
  String get legalIdentityRegimeHint =>
      'Il regime decide quale numero richiede la norma: un numero di registrazione fuori campo IVA, una partita IVA se esente.';

  @override
  String get legalIdentityVatId => 'Partita IVA';

  @override
  String get legalIdentityLegalId => 'Numero di registrazione';

  @override
  String get legalIdentityExemptionReason =>
      'Motivo del mancato addebito dell\'IVA';

  @override
  String get legalIdentityStreet => 'Via';

  @override
  String get legalIdentityCity => 'Città';

  @override
  String get legalIdentityPostalCode => 'Codice postale';

  @override
  String get legalIdentitySaved => 'Identità legale salvata.';

  @override
  String get legalIdentityVatWarning =>
      'Questo spazio applica l\'IVA ma non è configurata alcuna aliquota: le fatture non espongono imposta e l\'export XML resta disattivato.';

  @override
  String get addressCountryLabel => 'Paese';

  @override
  String get addressVatIdLabel => 'Partita IVA (se fatturi come impresa)';

  @override
  String get invoiceProformaAction => 'Fattura proforma';

  @override
  String get invoicePdfProforma => 'Proforma';

  @override
  String get invoiceProformaShared => 'Proforma condivisa.';

  @override
  String get invoiceProformaNothing =>
      'Nessun dato registrato per questo mese — nessuna proforma da inviare.';

  @override
  String get invoicePdfCopy => 'Copia';

  @override
  String get invoiceStatusPartiallyPaid => 'Parzialmente pagata';

  @override
  String get invoiceRegisterTitle => 'Registro fatture';

  @override
  String get invoiceRegisterDate => 'Data';

  @override
  String get invoiceRegisterName => 'Nome';

  @override
  String get invoiceRegisterAmount => 'Importo';

  @override
  String get invoiceRegisterTotal => 'Totale';

  @override
  String get invoiceFacturXDownload => 'Scarica Factur-X (PDF)';

  @override
  String get invoiceFacturXShare => 'Condividi Factur-X (PDF)';

  @override
  String get invoiceFacturXExplain =>
      'Un unico file: la fattura che legge una persona, con l\'XML leggibile dalle macchine al suo interno. È ciò che si aspettano la maggior parte delle piattaforme.';

  @override
  String get invoiceSendAction => 'Invia alla piattaforma governativa';

  @override
  String get invoiceSendAccepted => 'Inviata — la piattaforma l’ha accettata.';

  @override
  String get invoiceSendCustomerAction => 'Invia al servizio del cliente';

  @override
  String get invoiceSendCustomerAccepted =>
      'Inviata — il servizio del cliente l’ha accettata.';

  @override
  String get einvoiceCustomerSectionTitle => 'Servizio di recapito al cliente';

  @override
  String get einvoiceCustomerSectionHelp =>
      'Dove vanno le fatture per il cliente: il suo punto di accesso Peppol, il portale o l’API concordata — separato dalla piattaforma governativa.';

  @override
  String get invoiceSendRejected => 'La piattaforma l’ha rifiutata.';

  @override
  String invoiceSentOn(String date, String status) {
    return 'Inviata il $date · $status';
  }

  @override
  String get invoiceSendStatusAccepted => 'accettata';

  @override
  String get invoiceSendStatusRejected => 'rifiutata';

  @override
  String get invoiceSendStatusFailed => 'non trasmessa';

  @override
  String get einvoiceConfigTitle => 'Piattaforma di fatturazione elettronica';

  @override
  String get einvoiceConfigIntro =>
      'Dove DesKilo deposita le tue fatture. Va bene qualsiasi piattaforma che accetti un upload con un token — una piattaforma accreditata, un access point Peppol, una piattaforma nazionale. Il token resta sul server e non torna mai indietro.';

  @override
  String get einvoiceConfigEndpoint => 'URL di caricamento';

  @override
  String get einvoiceConfigToken => 'Token o credenziale';

  @override
  String get einvoiceConfigHeader =>
      'Header di autenticazione (Authorization per impostazione predefinita)';

  @override
  String get einvoiceConfigField =>
      'Nome del campo file (file per impostazione predefinita)';

  @override
  String get einvoiceConfigSaved => 'Piattaforma salvata.';

  @override
  String get einvoiceConfigCleared => 'Piattaforma rimossa.';

  @override
  String get einvoiceConfigClear => 'Rimuovi la piattaforma';

  @override
  String get einvoiceConfigTokenSet =>
      'Un token è salvato (digitane uno nuovo per sostituirlo).';

  @override
  String get invoiceAccountingExport => 'Esportazione contabile';

  @override
  String get invoiceAccountingExportEmpty =>
      'Niente da esportare per questo periodo.';

  @override
  String get invoiceRegisterYear => 'Anno';

  @override
  String get invoiceRegisterAllYears => 'Tutti gli anni';

  @override
  String get invoiceExportSafT => 'SAF-T (XML, internazionale)';

  @override
  String get invoiceExportFec => 'FEC (Francia, richiesto in caso di verifica)';

  @override
  String get invoiceExportChoose => 'Esportazione contabile';

  @override
  String get fecAccountsTitle => 'Conti da utilizzare';

  @override
  String get fecAccountsIntro =>
      'Un FEC è fatto di scritture contabili, quindi richiede numeri di conto. Questi sono i conti del piano contabile francese — sostituiscili con quelli del tuo commercialista.';

  @override
  String get fecAccountCustomers => 'Clienti';

  @override
  String get fecAccountRevenue => 'Ricavi';

  @override
  String get fecAccountBank => 'Banca';

  @override
  String get fecMissingSiren =>
      'Il FEC prende il nome dal numero di registrazione — inseriscilo prima in Identità legale.';

  @override
  String get invoiceEInvoiceStaleIdentity =>
      'La tua identità legale ora è completa, ma questa fattura è stata firmata prima e conserva ciò con cui è stata emessa. Segnala come errata ed emetti una sostitutiva perché porti la nuova identità.';

  @override
  String get einvoiceConfigUnavailable =>
      'Impossibile caricare la configurazione della piattaforma. Controlla la connessione e riprova.';

  @override
  String get einvoiceEnvTitle => 'Inviare a quale piattaforma?';

  @override
  String get einvoiceEnvProd => 'Produzione';

  @override
  String get einvoiceEnvUat => 'UAT (piattaforma di prova)';

  @override
  String get einvoiceEnvDev => 'Dev (piattaforma di prova)';

  @override
  String get einvoiceEnvProdHint => 'La trasmissione reale.';

  @override
  String get einvoiceEnvTestHint =>
      'Una prova — registrata come invio di test.';

  @override
  String invoiceSendAcceptedTest(String env) {
    return 'Invio di test accettato ($env).';
  }

  @override
  String get einvoiceTestEnvsTitle => 'Ambienti di prova (UAT / Dev)';

  @override
  String get einvoiceTestEnvsHelp =>
      'Endpoint e token separati per le prove. La scelta appare all’invio solo con la modalità sviluppatore attiva.';

  @override
  String get einvoiceUatEndpoint => 'URL di caricamento UAT';

  @override
  String get einvoiceUatToken => 'Token o credenziale UAT';

  @override
  String get einvoiceDevEndpoint => 'URL di caricamento Dev';

  @override
  String get einvoiceDevToken => 'Token o credenziale Dev';

  @override
  String get invoiceSentTestChip => 'test';

  @override
  String get invoiceTemplateTitle => 'Modello PDF della fattura';

  @override
  String get invoiceTemplateHint =>
      'Tre bande di report rese sul PDF — l\'XML della fattura elettronica non viene mai toccato. Condizioni e cicli Liquid, poi markup di riga:';

  @override
  String get invoiceTemplateIntroLabel =>
      'Introduzione (sopra il blocco del destinatario)';

  @override
  String get invoiceTemplateFooterLabel =>
      'Piè di pagina (sotto i totali — condizioni di pagamento, menzioni legali)';

  @override
  String get invoiceTemplateSaved => 'Modello di fattura salvato.';

  @override
  String get invoiceTemplateHeaderLabel => 'Banda di intestazione';

  @override
  String get invoiceTemplateBodyLabel =>
      'Banda del corpo (le righe della fattura)';

  @override
  String get invoiceTemplateReset => 'Ripristina il modello predefinito';

  @override
  String get invoiceTemplatePreview => 'Anteprima';

  @override
  String get invoiceTemplateNoPreview =>
      'Emetti prima una fattura — l\'anteprima usa la più recente.';

  @override
  String get reminderPdfTitleFriendly => 'Promemoria di pagamento';

  @override
  String get reminderPdfTitleFirm => 'Sollecito';

  @override
  String get reminderPdfOpeningFriendly =>
      'questo è un promemoria amichevole: la fattura qui sotto è ancora aperta. Probabilmente una semplice svista — nessun problema.';

  @override
  String get reminderPdfOpeningFirm =>
      'nonostante il nostro sollecito precedente, la fattura qui sotto risulta ancora non pagata. Ti preghiamo di saldare l\'importo senza indugio.';

  @override
  String get reminderPdfDaysOpen => 'Aperta da';

  @override
  String get reminderPdfDays => 'giorni';

  @override
  String get reminderPdfLevelLabel => 'Livello di sollecito';

  @override
  String get reminderPdfClosing => 'Se hai già pagato, ignora questa lettera.';

  @override
  String get dunningSettingsTitle => 'Regole di sollecito';

  @override
  String get dunningLevels => 'Numero di livelli di sollecito';

  @override
  String get dunningFirstAfterDays => 'Giorni fino al primo promemoria';

  @override
  String get dunningBetweenDays => 'Giorni tra i solleciti';

  @override
  String get dunningSaved => 'Regole di sollecito salvate.';

  @override
  String dunningDueChip(int level) {
    return 'Sollecito $level da inviare';
  }

  @override
  String get invoiceTemplateDocInvoice => 'Fattura';

  @override
  String invoiceTemplateDocReminder(int level) {
    return 'Sollecito $level';
  }

  @override
  String get reportPreviewTitle =>
      'Anteprima rapida — la tua fattura più recente';

  @override
  String get reportPreviewSimulated => 'Anteprima rapida — dati di esempio';

  @override
  String get reportPresetClassic => 'Classico';

  @override
  String get reportPresetFormalLetter => 'Lettera formale';

  @override
  String get reportSubject => 'Oggetto';

  @override
  String get reportRegards => 'Cordiali saluti';

  @override
  String get invoiceTemplatePresets => 'Modelli';

  @override
  String get invoiceTemplateQuickPreview => 'Anteprima rapida';

  @override
  String get invoiceTemplateDownload => 'Scarica PDF';

  @override
  String get invoiceTemplateShare => 'Condividi PDF';

  @override
  String get invoiceTemplateDocStatement => 'Estratto';

  @override
  String get reportPresetSimple => 'Semplice';

  @override
  String get reportPresetVerbose => 'Dettagliato';

  @override
  String get invoiceLegalSection => 'Menzioni di fatturazione';

  @override
  String get invoiceLegalIntro =>
      'Le menzioni legali stampate su fatture e solleciti. Le clausole di pagamento vuote usano i testi legali predefiniti.';

  @override
  String get invoiceLegalFormField => 'Forma giuridica e capitale';

  @override
  String get invoiceLegalFormHint => 'es. SARL au capital de 7 500 €';

  @override
  String get invoiceLegalRegistrationField => 'Registro delle imprese';

  @override
  String get invoiceLegalRegistrationHint => 'es. RCS Saint-Brieuc 680 357 910';

  @override
  String get invoiceLegalPaymentTermsField => 'Termini di pagamento';

  @override
  String get invoiceLegalLatePenaltyField => 'Penale di mora';

  @override
  String get invoiceLegalRecoveryField => 'Indennità di recupero crediti';

  @override
  String get invoiceLegalEscompteField => 'Sconto per pagamento anticipato';

  @override
  String get invoiceLegalInsuranceField => 'Assicurazione professionale';

  @override
  String get invoiceLegalSpecialField => 'Menzioni particolari';

  @override
  String get invoiceLegalPaymentTermsDefault => 'Pagamento al ricevimento.';

  @override
  String get invoiceLegalLatePenaltyDefault =>
      'Penale di mora: tre volte il tasso di interesse legale.';

  @override
  String get invoiceLegalRecoveryDefault =>
      'Indennità forfettaria per costi di recupero: 40 €.';

  @override
  String get invoiceLegalEscompteDefault =>
      'Nessuno sconto per pagamento anticipato.';

  @override
  String get reportColUnitPrice => 'Prezzo unit.';

  @override
  String get reportColQty => 'Qtà';

  @override
  String get reportColTotal => 'Totale';

  @override
  String get invoiceLegalKindField => 'Tipo di organizzazione';

  @override
  String get invoiceLegalKindCompany => 'Impresa';

  @override
  String get invoiceLegalKindAssociation => 'Associazione (non profit)';

  @override
  String get invoiceLegalAssociationHint =>
      'Le clausole di mora, recupero crediti e sconto vengono stampate solo se compilate — sono obbligatorie solo tra professionisti.';

  @override
  String get invoiceLegalFormHintAssociation => 'es. Association loi 1901';

  @override
  String get invoiceLegalRegistrationHintAssociation =>
      'es. RNA W123456789 · SIRET se assegnato';

  @override
  String get invoiceLegalAssociationReasonHint =>
      'es. «TVA non applicable, art. 293 B du CGI» — o «Exonération de TVA, art. 261, 7-1° du CGI» per i servizi ai membri';

  @override
  String get reportEditorMarkup => 'Markup';

  @override
  String get reportEditorVisual => 'Visuale';

  @override
  String get reportInsertImage => 'Inserisci immagine';

  @override
  String get reportImagesTitle => 'Immagini dei report';

  @override
  String get reportImagesEmpty =>
      'Nessuna immagine — carica il tuo logo, un timbro o una firma e riferiscila con ![nome].';

  @override
  String get reportImageUpload => 'Carica immagine';

  @override
  String get reportVisualAddLine => 'Aggiungi riga';

  @override
  String get reportLineTitle => 'Titolo';

  @override
  String get reportLineSection => 'Sezione';

  @override
  String get reportLineText => 'Testo';

  @override
  String get reportLineSmall => 'Testo piccolo';

  @override
  String get reportLineRow => 'Riga di tabella';

  @override
  String get reportLineBoldRow => 'Riga in grassetto';

  @override
  String get reportLineDivider => 'Divisore';

  @override
  String get reportLineSpacer => 'Spaziatura';

  @override
  String get reportLineImage => 'Immagine';

  @override
  String get reportLineColumns => 'Inizio/fine colonne';

  @override
  String get reportLineColumnsSplit => 'Interruzione di colonna';

  @override
  String get reportLineLogic => 'Logica';

  @override
  String get reportDocAgreement => 'Accordo finanziario';

  @override
  String get reportDocPayments => 'Report dei pagamenti';

  @override
  String get reportDocWorkspace => 'Report dello spazio';

  @override
  String get agreementExtraHalfDay => 'Mezza giornata extra';

  @override
  String get paymentsPendingTag => 'in attesa di convalida';

  @override
  String get reportSectionFeatures => 'Funzionalità';

  @override
  String get reportSectionPrices => 'Prezzi';

  @override
  String get moneyMyAgreement => 'Le mie condizioni';

  @override
  String get memberSendAgreement => 'Invia l\'accordo finanziario';

  @override
  String get reportQuickView => 'Anteprima rapida';

  @override
  String get reportDocWorkspaceSubtitle =>
      'Tutto sullo spazio — tramite il modello spazio dell\'editor di report';

  @override
  String get reportTemplateLangDefault => 'Predefinito (tutte le lingue)';

  @override
  String get reportLanguageAmbiguous =>
      'Questo paese ha più lingue — imposta prima la lingua dello spazio nelle Impostazioni dello spazio.';

  @override
  String get reportDesignEmpty => 'Banda vuota — aggiungi un elemento sotto.';

  @override
  String get invoiceStatusRemainderCancelled =>
      'Parzialmente pagata · saldo annullato';

  @override
  String get invoiceRemainingLabel => 'Residuo';

  @override
  String get invoiceWriteoffButton => 'Annulla il saldo residuo';

  @override
  String get invoiceWriteoffExplain =>
      'Il saldo non pagato di questa fattura verrà annullato e la fattura archiviata come parzialmente pagata — una volta confermata la convalida. Fino ad allora resta aperta e dovuta.';

  @override
  String get invoiceWriteoffRequested =>
      'Annullamento richiesto — in attesa di convalida.';

  @override
  String get eventTypeInvoiceWriteoff => 'Annullamento del saldo';

  @override
  String eventInvoiceWriteoffLine(String actor, String number, String amount) {
    return '$actor chiede di annullare il saldo di $number — $amount';
  }

  @override
  String get invoicePdfCreditNote => 'Nota di credito';

  @override
  String get invoiceStatusRefunded => 'Rimborsata';

  @override
  String get invoiceRefundLabel => 'Da rimborsare';

  @override
  String get invoiceRefundButton => 'Registra il rimborso';

  @override
  String invoiceRefundExplain(String amount) {
    return 'Questa nota di credito significa che lo SPAZIO deve $amount al membro. Registra il rimborso versato — l\'importo viene imputato al saldo del membro e il documento si chiude come Rimborsata.';
  }

  @override
  String get invoiceRefunded => 'Rimborso registrato.';

  @override
  String invoiceSummaryToRefund(int count, String amount) {
    return '$count da rimborsare · $amount';
  }

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
  String get kioskScanQr => 'Scansiona il badge QR';

  @override
  String get kioskRevertTitle => 'Dispositivo chiosco';

  @override
  String get kioskRevertDesc =>
      'Questo profilo è configurato come chiosco dello spazio. Ripristinalo come membro normale per non vedere più la domanda chiosco all\'avvio.';

  @override
  String get kioskRevertDone => 'Questo profilo è di nuovo un membro normale.';

  @override
  String get memberNoActions =>
      'Solo il proprietario dello spazio può modificare questo membro.';

  @override
  String get kioskNotCheckedIn =>
      'Nessun check-in attivo trovato — la planimetria potrebbe essersi appena aggiornata.';

  @override
  String get kioskRestOfDay => 'Resto della giornata';

  @override
  String get kioskPeriodCheckInHint =>
      'Fino a quando resti? Il check-in inizia adesso.';

  @override
  String get kioskPeriodReserveHint => 'Scegli il periodo: solo oggi.';

  @override
  String get kioskCheckInRightAway => 'Check-in immediato';

  @override
  String get kioskCheckInRightAwayHint =>
      'Sei qui: la prenotazione parte già registrata.';

  @override
  String get kioskPresentBadgeNext => 'Presenta il badge';

  @override
  String get kioskReserveAndCheckIn => 'Prenota e fai check-in';

  @override
  String get badgeDeleteConfirm =>
      'Eliminare definitivamente questo badge revocato?';

  @override
  String get kioskClosedToday =>
      'Lo spazio è chiuso oggi — check-in e prenotazioni non sono possibili.';

  @override
  String kioskBasis(String granularity, String hours) {
    return 'Regola: $granularity · oggi $hours';
  }

  @override
  String kioskBlockedContactHint(String name) {
    return 'Occupato da $name — puoi scrivergli dall\'app sul tuo telefono.';
  }

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
  String get levelPermissionAllowed =>
      'Può prenotare un tavolo, ufficio o piano intero';

  @override
  String get levelPermissionDenied =>
      'Non può prenotare un tavolo, ufficio o piano intero';

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
      'Non sei autorizzato a prenotare un tavolo, ufficio o piano intero.';

  @override
  String get levelConflict => 'Il piano ha prenotazioni in quel periodo.';

  @override
  String get bookingOnePlace =>
      'Hai già una prenotazione in quel periodo — un posto alla volta.';

  @override
  String get bookingCheckedInElsewhere =>
      'Hai fatto check-in altrove — fai prima il check-out lì.';

  @override
  String get spaceNotWholeBookable =>
      'Questo spazio non è configurato per la prenotazione intera — il proprietario attiva \"Prenotabile per intero\" nell\'editor.';

  @override
  String get levelFeatureOff =>
      'Le prenotazioni di ufficio e piano sono disattivate nelle Funzionalità.';

  @override
  String get levelDetail => 'Intero piano';

  @override
  String get kioskLevelButton => 'Questo piano';

  @override
  String get officeSupplementLabel => 'Prenotazioni di ufficio';

  @override
  String get eventTypeSpaceReservation => 'Prenotazioni di spazi interi';

  @override
  String get deskDetail => 'Tavolo intero';

  @override
  String get deskSupplementLabel => 'Prenotazioni di tavolo';

  @override
  String get editorLevelBookableOn => 'Prenotabile per intero';

  @override
  String get editorLevelBookableOff => 'Non prenotabile per intero';

  @override
  String get bookingPastError =>
      'Questa prenotazione è interamente nel passato.';

  @override
  String get bookingWalkUpTodayError =>
      'Un check-in spontaneo deve iniziare oggi.';

  @override
  String get bookingOutsideHoursError =>
      'Le prenotazioni devono restare negli orari di lavoro.';

  @override
  String get bookingOutsideOffError =>
      'Le prenotazioni fuori dagli orari di apertura non sono consentite.';

  @override
  String get bookingOutsideWalkUpError =>
      'Fuori dagli orari di apertura è possibile solo un check-in spontaneo, non una prenotazione in anticipo.';

  @override
  String get bookingSameDayError =>
      'Una prenotazione termina il giorno in cui inizia — prenota il giorno dopo separatamente.';

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
  String get noteRefGone => 'Questa prenotazione non esiste più.';

  @override
  String get memberNoteDelete => 'Elimina';

  @override
  String get memberNoteDeleteConfirm =>
      'Eliminare questo messaggio? Non si può annullare.';

  @override
  String get memberNoteReply => 'Rispondi';

  @override
  String get noteRefReservation => 'Collega una prenotazione';

  @override
  String get noteRefSpace => 'Collega uno spazio';

  @override
  String get noteRefNoReservations =>
      'Nessuna prenotazione futura da collegare.';

  @override
  String get noteRefWholeLevel => 'piano intero';

  @override
  String get memberMessagesAction => 'Messaggi';

  @override
  String get conversationEmpty => 'Ancora nessun messaggio — saluta!';

  @override
  String get whatsappNotesTitle => 'Ricevere i messaggi su WhatsApp';

  @override
  String get whatsappNotesSubtitle =>
      'I messaggi dei membri arrivano anche su WhatsApp.';

  @override
  String get messageLinkGone => 'Questo messaggio è nella tua casella.';

  @override
  String get whatsappNotesUnconfigured =>
      'Canale non configurato — i messaggi arrivano solo in app e via push.';

  @override
  String get whatsappChannelTitle => 'Canale WhatsApp';

  @override
  String get whatsappChannelConfigured =>
      'Canale configurato — i messaggi arrivano anche su WhatsApp, con i loro link; il link DesKilo apre la conversazione nell\'app.';

  @override
  String get whatsappChannelNotConfigured =>
      'Non configurato — i messaggi arrivano solo in app e via push.';

  @override
  String get whatsappChannelHelp =>
      '1. Crea un\'app (gratuita) su developers.facebook.com e aggiungi il prodotto WhatsApp.\n2. In WhatsApp → Configurazione API, copia il token di accesso permanente e l\'ID del numero di telefono.\n3. Incolla entrambi qui sotto — i messaggi dei membri partono da quel numero.\nNota: WhatsApp consegna solo entro 24 h dall\'ultimo messaggio WhatsApp del destinatario al tuo numero (la sua finestra di servizio).';

  @override
  String get whatsappChannelToken => 'Token di accesso';

  @override
  String get whatsappChannelPhoneId => 'ID del numero di telefono';

  @override
  String get whatsappChannelKeepHint =>
      'Lascia vuoto per mantenere il valore salvato.';

  @override
  String get whatsappChannelSaved => 'Canale WhatsApp salvato.';

  @override
  String get notesFilterUnread => 'Non letti';

  @override
  String get notesFilterEmpty => 'Nessun messaggio non letto — tutto in pari.';

  @override
  String get conversationGroup => 'Gruppo';

  @override
  String get conversationUnknownMember => 'Membro';

  @override
  String get conversationYesterday => 'Ieri';

  @override
  String get conversationYou => 'Tu';

  @override
  String get messagesTitle => 'Messaggi';

  @override
  String get messagesEmpty => 'Ancora nessuna conversazione.';

  @override
  String get messagesEmptyHint =>
      'Tocca la matita per scrivere a qualcuno, oppure crea un gruppo.';

  @override
  String conversationMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membri',
      one: '1 membro',
    );
    return '$_temp0';
  }

  @override
  String get newConversationTitle => 'Nuova conversazione';

  @override
  String get newConversationSearch => 'Cerca membri';

  @override
  String get newConversationStart => 'Avvia chat';

  @override
  String get newConversationNoMembers => 'Ancora nessun altro qui.';

  @override
  String get newGroupName => 'Nome del gruppo';

  @override
  String get newGroupCreate => 'Crea gruppo';

  @override
  String get conversationGroupInfo => 'Gruppo';

  @override
  String get conversationAddPeople => 'Aggiungi membri';

  @override
  String get conversationLeave => 'Esci dal gruppo';

  @override
  String get conversationLeaveConfirm =>
      'Uscire da questo gruppo? Non riceverai più i suoi messaggi; quelli già inviati restano.';

  @override
  String get conversationRemove => 'Rimuovi';

  @override
  String get conversationAdmin => 'Admin';

  @override
  String get conversationLeft => 'Uscito';

  @override
  String get messageSearchHint => 'Membri, gruppi, messaggi';

  @override
  String get messageSearchPrompt =>
      'Cerca membri, gruppi e ciò che è stato detto.';

  @override
  String get messageSearchNothing => 'Nessun risultato.';

  @override
  String get messageSearchPeople => 'Membri';

  @override
  String get messageSearchGroups => 'Gruppi';

  @override
  String get messageSearchMessages => 'Messaggi';

  @override
  String get messageSearchTitle => 'Cerca';

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
  String get moneyPaymentDateLabel => 'Data del pagamento';

  @override
  String get moneyPaymentPeriodLabel => 'Si applica a';

  @override
  String get moneySectionPay => 'Pagare';

  @override
  String get moneySectionRequests => 'Richieste';

  @override
  String get moneySectionDocuments => 'Documenti';

  @override
  String get vatDeclTitle => 'Dichiarazione IVA';

  @override
  String get vatDeclPeriod => 'Periodo';

  @override
  String get vatDeclSeller => 'Venditore';

  @override
  String get vatDeclVatId => 'Partita IVA';

  @override
  String get vatDeclRate => 'Aliquota';

  @override
  String get vatDeclNet => 'Imponibile';

  @override
  String get vatDeclVat => 'IVA';

  @override
  String get vatDeclInvoices => 'Fatture';

  @override
  String get vatDeclTotals => 'Totali';

  @override
  String get vatDeclBoxes => 'Righe del modulo ufficiale';

  @override
  String get vatDeclBox => 'Rigo';

  @override
  String get vatDeclStatus => 'Stato';

  @override
  String get vatDeclDisclaimer =>
      'Generata dalle fatture emesse del periodo. Verificare con la contabilità prima dell’invio — un aiuto alla dichiarazione, non consulenza fiscale.';

  @override
  String get vatDeclGenerate => 'Genera';

  @override
  String get vatDeclEmpty =>
      'Nessuna dichiarazione — scegli un periodo e genera la prima.';

  @override
  String get vatDeclDraft => 'Bozza';

  @override
  String get vatDeclSubmitted => 'Inviata';

  @override
  String get vatDeclTransmit => 'Trasmetti';

  @override
  String get vatDeclMarkFiled => 'Segna come inviata';

  @override
  String get vatDeclMarkFiledConfirm =>
      'Conferma di aver inviato questa dichiarazione tu stesso (portale dell’agenzia o il tuo commercialista). Diventa immutabile.';

  @override
  String get vatDeclXml => 'Esporta XML';

  @override
  String get vatDeclPdf => 'PDF';

  @override
  String get vatDeclSent => 'Dichiarazione trasmessa.';

  @override
  String get vatDeclRejected => 'La piattaforma ha rifiutato la dichiarazione.';

  @override
  String get vatDeclRegimeGate =>
      'Le dichiarazioni esistono solo sotto il regime soggetto a IVA — configuralo nelle impostazioni IVA.';

  @override
  String get featureVatManagementTitle => 'Gestione IVA';

  @override
  String get featureVatManagementDesc =>
      'L\'editor delle aliquote IVA e i selettori di aliquota su servizi, pacchetti, accessori e tariffe. Disattivato nasconde la configurazione; le aliquote salvate continuano ad applicarsi.';

  @override
  String get featureVatDeclarationsTitle => 'Dichiarazioni IVA';

  @override
  String get featureVatDeclarationsDesc =>
      'Genera la dichiarazione IVA periodica dalle fatture emesse, mappala sul modulo ufficiale e trasmettila o esportala.';

  @override
  String get featureEinvoiceCustomerDeliveryTitle =>
      'Recapito delle fatture al cliente';

  @override
  String get featureEinvoiceCustomerDeliveryDesc =>
      'Un secondo canale di invio accanto alla piattaforma governativa: trasmettere la fattura emessa direttamente al servizio di fatturazione del cliente.';

  @override
  String priceVatIncluded(String rate) {
    return 'IVA $rate incl.';
  }

  @override
  String billingPricesVatHint(String rate) {
    return 'I prezzi sono lordi — l’IVA $rate (aliquota predefinita dello spazio) è inclusa.';
  }

  @override
  String billingTariffVatHint(String rate) {
    return 'I prezzi sono lordi — IVA $rate (aliquota delle tariffe) inclusa.';
  }

  @override
  String get billingNewPackage => 'Nuovo pacchetto';

  @override
  String get priceGrossHint =>
      'Prezzo lordo — ciò che paga il membro; l’IVA è compresa.';

  @override
  String vatShareAmount(String amount) {
    return 'IVA incl. $amount';
  }

  @override
  String get reportDesignerDesign => 'Progetto';

  @override
  String get reportDesignerPreview => 'Anteprima';

  @override
  String get reportDesignerZoom => 'Zoom';

  @override
  String get reportDesignerZoomFit => 'Adatta alla larghezza';

  @override
  String get planDurationLabel => 'Durata';

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
  String get planCheckInNotYetError =>
      'Il check-in apre 15 minuti prima dell\'inizio.';

  @override
  String get planCheckInOverError =>
      'Questa prenotazione è terminata — il check-in non è più possibile.';

  @override
  String planCheckInOpensAt(String time) {
    return 'Il check-in apre alle $time';
  }

  @override
  String planCheckInOpensOn(String date) {
    return 'Il check-in apre il $date';
  }

  @override
  String planCheckInFor(String name) {
    return 'Fai il check-in di $name';
  }

  @override
  String get planOverruleRemove => 'Rimuovi la prenotazione (scavalca)';

  @override
  String planOverruleHint(String name) {
    return '$name e tutti gli admin saranno avvisati.';
  }

  @override
  String planOverruleDone(String name) {
    return 'Prenotazione rimossa — $name è stato avvisato.';
  }

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
  String get a11ySeatFree => 'libero';

  @override
  String get a11ySeatReserved => 'prenotato';

  @override
  String get a11ySeatOccupied => 'occupato';

  @override
  String get a11ySeatMine => 'il tuo posto';

  @override
  String get a11ySeatBlocked => 'non disponibile';

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
  String get settingsBillingReports => 'Fatturazione e report';

  @override
  String get defaultPeriodTitle => 'Periodo di prenotazione predefinito';

  @override
  String get defaultPeriodNone => 'Nessuna preferenza (giornata intera)';

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
  String get memberNotifyAction => 'Invia notifica';

  @override
  String get memberNotifyAllAdmins => 'Notifica tutti gli admin';

  @override
  String get memberAllAdmins => 'tutti gli admin';

  @override
  String memberNoteTitle(String name) {
    return 'Notifica $name';
  }

  @override
  String get memberNoteHint => 'Il tuo messaggio';

  @override
  String get memberNoteSend => 'Invia';

  @override
  String get memberNoteSent => 'Notifica inviata.';

  @override
  String memberNoteReceived(String name) {
    return 'Messaggio da $name';
  }

  @override
  String get eventsMessagesHeader => 'Messaggi';

  @override
  String memberNoteTo(String name) {
    return 'A $name';
  }

  @override
  String get memberNoteToAllAdmins => 'A tutti gli admin';

  @override
  String get memberNoteDeleted => 'Messaggio eliminato.';

  @override
  String get memberSimultaneousLimitLabel => 'Prenotazioni simultanee';

  @override
  String get memberSimultaneousLimitExplainer =>
      'Quante prenotazioni questo membro può avere nello stesso periodo. Non impostato: vale il valore predefinito dello spazio.';

  @override
  String get memberSimultaneousLimitDefault => 'Valore dello spazio';

  @override
  String memberSimultaneousLimitChip(int n) {
    return '$n alla volta';
  }

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
  String get spaceScanNfcHint =>
      '…oppure avvicina il telefono al tag NFC di una sedia.';

  @override
  String get spaceScanUnknownTag =>
      'Questo tag non è collegato a nessuna sedia.';

  @override
  String bookingCheckedInUntil(String until) {
    return 'Check-in fatto fino alle $until.';
  }

  @override
  String bookingCheckedInAtUntil(String space, String until) {
    return 'Check-in su $space fino alle $until.';
  }

  @override
  String bookingReservedWhen(String when) {
    return 'Prenotato: $when.';
  }

  @override
  String bookingReservedSpaceWhen(String space, String when) {
    return '$space prenotato: $when.';
  }

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
  String get spaceScanTitle => 'Scansiona un codice spazio';

  @override
  String get spaceScanHint =>
      'Inquadra la scheda di una postazione, tavolo, ufficio o piano — oppure digita il codice.';

  @override
  String get spaceScanField => 'Codice';

  @override
  String get spaceScanInvalid => 'Non è un codice spazio di questo workspace.';

  @override
  String get spaceScanUnknown =>
      'Questo codice non corrisponde più a nessuno spazio qui.';

  @override
  String get spaceSeatTaken => 'Occupato';

  @override
  String get spaceNotBookable =>
      'Questo spazio non è configurato per le prenotazioni intere.';

  @override
  String get spaceCodesTitle => 'Codici QR degli spazi (PDF)';

  @override
  String get spaceCodesDesc =>
      'Una scheda QR stampabile per postazione, tavolo, ufficio e piano — i membri la scansionano per prenotare o fare check-in.';

  @override
  String get spaceKindDesk => 'Tavolo';

  @override
  String get spaceKindOffice => 'Ufficio';

  @override
  String get spaceKindLevel => 'Piano';

  @override
  String get spaceKindSeat => 'Postazione';

  @override
  String get spaceYoursNow => 'Riservato da te per questa fascia.';

  @override
  String get spaceCardSizeLabel => 'Dimensione della scheda';

  @override
  String get spaceQrSizeLabel => 'Dimensione del codice QR';

  @override
  String get spaceCardSizeSmall => 'Piccola';

  @override
  String get spaceCardSizeMedium => 'Media';

  @override
  String get spaceCardSizeLarge => 'Grande';

  @override
  String get spaceCardInfoLabel => 'Informazioni sulla scheda';

  @override
  String get spaceCardInfoWorkspace => 'Spazio di lavoro';

  @override
  String spaceMessageReserver(String name) {
    return 'Scrivi a $name';
  }

  @override
  String get spaceYoursCheckedIn =>
      'Hai effettuato il check-in qui per questa fascia.';

  @override
  String get spaceBlockedByYou => 'Hai già questo spazio per quel periodo.';

  @override
  String get spaceManageMyBooking => 'Gestisci la mia prenotazione';

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
  String get validationAutoValidateOwner =>
      'I proprietari eliminano senza validazione';

  @override
  String get validationAutoValidateAdmin =>
      'Gli admin eliminano senza validazione';

  @override
  String get validationAutoValidateDesc =>
      'La loro richiesta di eliminazione si risolve da sola e resta segnata come auto-validata.';

  @override
  String get vatTitle => 'IVA';

  @override
  String get vatIntro =>
      'In DesKilo i prezzi sono IVA inclusa. Aggiungere aliquote non cambia nulla di ciò che i membri pagano: l\'imposta viene estratta dal prezzo già applicato e mostrata in fattura.';

  @override
  String get vatRegimeHint =>
      'Questo spazio non è dichiarato soggetto a IVA, quindi le fatture non la espongono. Si cambia in Identità legale.';

  @override
  String get vatEmpty => 'Nessuna aliquota — le fatture non espongono IVA.';

  @override
  String get vatSeed => 'Usa le aliquote consuete';

  @override
  String get vatAddRate => 'Aggiungi un\'aliquota';

  @override
  String get vatRateLabelField => 'Nome';

  @override
  String get vatRatePercentField => 'Aliquota %';

  @override
  String get vatRateDefaultTooltip =>
      'Aliquota predefinita — usata dagli abbonamenti e da tutto ciò che non ne ha una propria';

  @override
  String get vatRateRemoveTooltip => 'Rimuovi';

  @override
  String get vatSaved => 'Aliquote IVA salvate.';

  @override
  String get vatNeedsDefault =>
      'Segna esattamente un\'aliquota come predefinita.';

  @override
  String get vatRateIncomplete =>
      'Ogni aliquota richiede un nome e una percentuale tra 0 e 99,99.';

  @override
  String get vatRatesTile => 'Aliquote IVA';

  @override
  String get vatAccountField => 'Conto IVA';

  @override
  String get vatAccountHint =>
      'Conto su cui l\'esportazione contabile registra l\'IVA incassata. Vuoto = 445710.';

  @override
  String get vatServiceRate => 'Aliquota IVA';

  @override
  String get vatServiceRateDefault => 'Predefinita dello spazio';

  @override
  String get vatPdfNet => 'Imponibile';

  @override
  String get vatPdfVat => 'IVA';

  @override
  String get fecAccountVat => 'IVA incassata';

  @override
  String get vatKeptRate =>
      'Un\'aliquota ancora usata da una fattura o da un servizio viene conservata, disattivata.';

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
  String get scanJoinHelp =>
      'Inquadra il QR d’invito con la fotocamera — il codice viene acquisito e l’adesione avviene automaticamente.';

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
  String get workspaceExcelExport => 'Esporta i dati (Excel)';

  @override
  String get workspaceExcelExportSubtitle =>
      'Tutti i dati in una cartella: prenotazioni, pagamenti, fatture, membri e piantina — una scheda ciascuno.';

  @override
  String get workspaceLanguageLabel => 'Lingua dello spazio';

  @override
  String get workspaceLanguageHelper =>
      'Gli inviti sono scritti per impostazione predefinita in questa lingua.';

  @override
  String get workspaceLanguageUnset => 'Lingua dell\'app del mittente';

  @override
  String get workspacePaymentsBillingTitle => 'Pagamenti e fatturazione';

  @override
  String get paymentMethodsSubtitle =>
      'IBAN, PayPal, Wero, Lydia, Wise e la causale di pagamento';

  @override
  String get featureDocuments => 'Biblioteca documenti';

  @override
  String get featureDocumentsDesc =>
      'La biblioteca documenti dello spazio: statuto, guide, bilanci, verbali — collegati da qualsiasi drive, visibili per ruolo.';

  @override
  String get documentsTitle => 'Documenti';

  @override
  String get documentsAdd => 'Aggiungi un documento';

  @override
  String get documentsTitleLabel => 'Titolo';

  @override
  String get documentsUrlLabel => 'Link (https://…)';

  @override
  String get documentsUrlHelper =>
      'Incolla il link di condivisione del tuo drive — i permessi restano gestiti lì.';

  @override
  String get documentsProviderLabel => 'Archiviato su';

  @override
  String get documentsCategoryLabel => 'Categoria';

  @override
  String get documentsRoleLabel => 'Visibile a';

  @override
  String get documentsRoleMember => 'Tutti i membri';

  @override
  String get documentsRoleAdmin => 'Admin e proprietari';

  @override
  String get documentsRoleOwner => 'Solo proprietari';

  @override
  String get documentsCategoryStatutes => 'Statuto e legale';

  @override
  String get documentsCategoryGuides => 'Guide e manuali';

  @override
  String get documentsCategoryFinance => 'Bilanci';

  @override
  String get documentsCategoryMinutes => 'Verbali';

  @override
  String get documentsCategoryOther => 'Altri documenti';

  @override
  String get documentsEmpty =>
      'Nessun documento. Collega statuto, guide e bilanci da qualsiasi drive.';

  @override
  String get documentsDelete => 'Rimuovere il documento?';

  @override
  String get documentsInvalid =>
      'Un documento richiede un titolo e un link https://.';

  @override
  String get featureRoleManagement => 'Gestione dei ruoli';

  @override
  String get featureRoleManagementDesc =>
      'La matrice centrale ruolo→permesso: il proprietario decide quale permesso spetta a quale ruolo; gli altri leggono i propri. Disattivata, valgono semplicemente i valori predefiniti.';

  @override
  String get rolesTitle => 'Gestione dei ruoli';

  @override
  String get rolesIntroEditor =>
      'Il proprietario detiene sempre tutti i permessi. Decidi qui cosa possono fare gli altri ruoli: un comproprietario può averne meno di un proprietario.';

  @override
  String get rolesIntroReadOnly =>
      'Sola lettura: questi sono i permessi di ogni ruolo. Il tuo ruolo è evidenziato.';

  @override
  String get rolesYourRole => 'Il tuo ruolo';

  @override
  String get roleOwner => 'Proprietario';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleMember => 'Membro';

  @override
  String get permManageRoles => 'Gestire ruoli e permessi';

  @override
  String get permManageMembers => 'Gestire i membri';

  @override
  String get permManageValidation => 'Configurare le regole di convalida';

  @override
  String get permWorkspaceSettings => 'Modificare le impostazioni dello spazio';

  @override
  String get permIssueInvoices => 'Emettere fatture e riconciliare pagamenti';

  @override
  String get permViewFinances => 'Consultare le finanze dello spazio';

  @override
  String get permManageDocuments => 'Gestire la libreria dei documenti';

  @override
  String get permManageServices => 'Gestire servizi e pacchetti';

  @override
  String get permApproveExpenses => 'Approvare le spese';

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
