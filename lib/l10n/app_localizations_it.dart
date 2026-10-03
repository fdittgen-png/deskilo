// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get a11yClearDate => 'Cancella la data';

  @override
  String get a11yDecrease => 'Diminuisci';

  @override
  String get a11yFinishEditing => 'Termina la modifica';

  @override
  String get a11yIncrease => 'Aumenta';

  @override
  String get a11yMoveDown => 'Sposta giù';

  @override
  String get a11yMoveUp => 'Sposta su';

  @override
  String get a11yRecentre => 'Adatta la pianta allo schermo';

  @override
  String get a11ySeatBlocked => 'non disponibile';

  @override
  String get a11ySeatFree => 'libero';

  @override
  String get a11ySeatMine => 'il tuo posto';

  @override
  String get a11ySeatOccupied => 'occupato';

  @override
  String get a11ySeatReserved => 'prenotato';

  @override
  String get a11yZoomIn => 'Ingrandisci';

  @override
  String get a11yZoomOut => 'Riduci';

  @override
  String get aboutAttribution =>
      'Based on DesKilo by Florian DITTGEN — https://github.com/fdittgen-png/deskilo';

  @override
  String get aboutAttributionNote =>
      'Questa menzione deve restare visibile in ogni copia e in ogni versione modificata.';

  @override
  String get aboutOpenSource => 'Software libero (licenza AGPL-3.0)';

  @override
  String get aboutOpenSourceDesc => 'Codice sorgente su GitHub';

  @override
  String get aboutPrivacy => 'Informativa sulla privacy';

  @override
  String get aboutReportBug => 'Segnala un bug / suggerisci una funzione';

  @override
  String get aboutSupportBody =>
      'Questa app è gratuita, open source e senza pubblicità. Se la trovi utile, sostieni lo sviluppatore.';

  @override
  String get aboutSupportTitle => 'Sostieni questo progetto';

  @override
  String aboutVersion(String version) {
    return 'Versione $version';
  }

  @override
  String get accessKindNegotiations => 'Negoziazioni di prezzo';

  @override
  String get accessKindProfile => 'il vostro profilo';

  @override
  String get accessLogEmpty =>
      'Nessuno ha consultato le tue finanze o i tuoi messaggi.';

  @override
  String accessLogRow(String actor, String category, String subject) {
    return '$actor ha consultato $category di $subject';
  }

  @override
  String get accessLogTitle => 'Chi ha consultato i tuoi dati';

  @override
  String get accessNobodyElse => 'nessun altro';

  @override
  String get accessRuleEvents => 'Tu, il membro che ha agito e gli admin.';

  @override
  String accessRuleFinances(String people) {
    return 'Tu e chi ha il permesso finanze: $people.';
  }

  @override
  String accessRuleManagedProfile(String people) {
    return 'Finché questo profilo è stato gestito per voi: $people. Ogni consultazione o modifica da parte loro è registrata sotto.';
  }

  @override
  String get accessRuleMessages =>
      'Solo le persone nella conversazione — nessun ruolo può leggere una conversazione di cui non fa parte.';

  @override
  String accessRuleNegotiations(String people) {
    return 'Tu, i proprietari e gli admin finanze: $people. Ogni lettura da parte di altri è registrata qui sotto.';
  }

  @override
  String get accessRuleReminders => 'Solo tu.';

  @override
  String get accessRuleReservations =>
      'Ogni membro dello spazio — la piantina mostra l\'occupazione a tutti.';

  @override
  String get accessoriesActive => 'Attivo';

  @override
  String get accessoriesEdit => 'Modifica accessorio';

  @override
  String get accessoriesEmpty => 'Ancora nessun accessorio.';

  @override
  String get accessoriesInactive => 'Inattivo';

  @override
  String get accessoriesName => 'Nome';

  @override
  String get accessoriesNew => 'Nuovo accessorio';

  @override
  String get accessoriesNoSupplement => 'Nessun supplemento';

  @override
  String accessoriesPerHalfDay(String amount) {
    return '$amount / mezza giornata';
  }

  @override
  String get accessoriesSupplement => 'Supplemento per mezza giornata';

  @override
  String get accessoriesTitle => 'Accessori';

  @override
  String get accountActivityEmpty => 'Nessun dato da mostrare.';

  @override
  String get accountActivityFailed =>
      'Impossibile caricare la cronologia finanziaria. Tocca per riprovare.';

  @override
  String get accountActivityScope =>
      'Tutti i tuoi profili su questo server, comprese le iscrizioni precedenti. Le valute sono mostrate separatamente.';

  @override
  String get accountActivityTitle => 'I miei consumi e pagamenti';

  @override
  String get accountCardTitle => 'Il tuo conto';

  @override
  String get accountCredit => 'Credito disponibile';

  @override
  String get accountImputationHint =>
      'Il tuo credito può saldare le fatture aperte: lo spazio lo imputa durante la riconciliazione dei pagamenti.';

  @override
  String get accountInvoiceIssued => 'Fattura emessa';

  @override
  String get accountInvoiceRegrouped => 'Incluso in una fattura di conguaglio';

  @override
  String get accountInvoiceVoided => 'Fattura annullata';

  @override
  String get accountNet => 'Posizione netta';

  @override
  String accountOpenPartial(String period, String paid) {
    return '$period · $paid pagati';
  }

  @override
  String get accountPaymentAsk => 'Scegli al pagamento';

  @override
  String get accountPaymentConfirmed => 'Pagamento confermato';

  @override
  String get accountPaymentPreference => 'Pagamento online preferito';

  @override
  String get accountPaymentsTitle => 'Pagamenti';

  @override
  String get accountRefundDue => 'Rimborso dovuto dallo spazio';

  @override
  String get accountUsageCorrected => 'Consumo fatturabile corretto';

  @override
  String accountUsageMinutes(int minutes) {
    return '$minutes minuti';
  }

  @override
  String get accountingExportDevelopment =>
      'Spazio di sviluppo: il file è contrassegnato DEV e non è la contabilità reale.';

  @override
  String get addressCountryLabel => 'Paese';

  @override
  String get addressNone => 'Nessun indirizzo';

  @override
  String get addressSaved => 'Indirizzo salvato';

  @override
  String get addressTitle => 'Indirizzo';

  @override
  String get addressVatIdLabel => 'Partita IVA (se fatturi come impresa)';

  @override
  String get addressWindowCountry => 'Segui il paese';

  @override
  String get addressWindowLeft => 'Sinistra (DIN 5008)';

  @override
  String get addressWindowOff => 'Nessuna finestra';

  @override
  String get addressWindowRight => 'Destra (uso francese)';

  @override
  String get addressWindowSubtitle =>
      'Dove viene stampato il destinatario perché compaia nella finestra della busta. Il blocco misura 85 × 45 mm, a 45 mm dal bordo superiore.';

  @override
  String get addressWindowTitle => 'Finestra indirizzo';

  @override
  String get agreementExtraHalfDay => 'Mezza giornata extra';

  @override
  String get amenityDock => 'Docking station';

  @override
  String get amenityErgonomicChair => 'Sedia ergonomica';

  @override
  String get amenityMonitor => 'Monitor';

  @override
  String get amenityStandingDesk => 'Scrivania in piedi';

  @override
  String get amenityWindow => 'Vicino alla finestra';

  @override
  String get appTitle => 'DesKilo';

  @override
  String get applicationAcceptedVote => 'Ha approvato questa richiesta';

  @override
  String get applicationApproved => 'Approvata';

  @override
  String get applicationDecisionComment =>
      'Commento visibile alla persona richiedente';

  @override
  String get applicationDiscussionHint =>
      'Le richieste e le conversazioni con chi le valuta restano disponibili, anche dopo un rifiuto.';

  @override
  String get applicationNoMessages => 'Ancora nessun messaggio.';

  @override
  String get applicationPending => 'In attesa di approvazione';

  @override
  String get applicationRefused => 'Rifiutata';

  @override
  String get applicationRefusedVote => 'Ha rifiutato questa richiesta';

  @override
  String get applicationReplyFailed =>
      'Il messaggio non è stato inviato. La bozza è stata conservata; riprova.';

  @override
  String get applicationsEmpty => 'Nessuna richiesta di accesso.';

  @override
  String get applicationsLoadFailed =>
      'Impossibile caricare le richieste di accesso. Riprova.';

  @override
  String get applicationsTitle => 'Richieste di accesso';

  @override
  String get assistantPrefix => 'Assistente';

  @override
  String get assistantSetupActorConfigurer =>
      'Chi: chi gestisce la configurazione di questo spazio di lavoro';

  @override
  String get assistantSetupActorDatabaseAdministrator =>
      'Chi: un amministratore del database';

  @override
  String get assistantSetupActorInstanceOperator =>
      'Chi: il proprietario dell\'istanza o un delegato';

  @override
  String get assistantSetupActorIntegrations =>
      'Chi: chi gestisce le integrazioni di questo spazio di lavoro';

  @override
  String get assistantSetupActorYou => 'Chi: tu';

  @override
  String get assistantSetupAllDone =>
      'Tutto è configurato per questo spazio di lavoro.';

  @override
  String get assistantSetupApply => 'Applica';

  @override
  String get assistantSetupConnectHowTo =>
      '1. Nel tuo assistente, aggiungi un connettore personalizzato con questo URL.\n2. Accedi con il tuo account DesKilo quando richiesto.\n3. Approva questo spazio di lavoro e le operazioni che consenti.';

  @override
  String get assistantSetupCopied => 'URL del connettore copiato.';

  @override
  String get assistantSetupCopyUrl => 'Copia l\'URL del connettore';

  @override
  String get assistantSetupCustomise => 'Personalizza';

  @override
  String get assistantSetupFailed =>
      'Impossibile salvare. Non è cambiato nulla; riprova.';

  @override
  String assistantSetupInstanceNames(String names) {
    return 'Rispondono di questo database: $names.';
  }

  @override
  String get assistantSetupInstanceNobody =>
      'Nessuno risponde ancora di questo database.';

  @override
  String get assistantSetupInstanceYou =>
      'Rispondi tu di questo database: attiva gli assistenti dagli strumenti dell\'istanza.';

  @override
  String get assistantSetupIntro =>
      'Ciò che serve agli assistenti in questo spazio di lavoro, in ordine. Ogni passo indica chi lo compie.';

  @override
  String get assistantSetupLinkIdentity => 'Conferma la mia identità';

  @override
  String assistantSetupNextTodo(String step) {
    return 'Prossimo passo: $step.';
  }

  @override
  String assistantSetupNextWaiting(String step, String actor) {
    return 'Prossimo passo: $step. $actor.';
  }

  @override
  String get assistantSetupNoConnector =>
      'Questa app funziona senza server, quindi non c\'è un URL del connettore.';

  @override
  String get assistantSetupNoWorkspace => 'Scegli prima uno spazio di lavoro.';

  @override
  String get assistantSetupPreviewAdds => 'Aggiunte';

  @override
  String get assistantSetupPreviewNone =>
      'Nessuna modifica: lo spazio di lavoro offre già esattamente questa selezione.';

  @override
  String get assistantSetupPreviewNote =>
      'Solo i dati propri di un membro e le letture di disponibilità. Gli assistenti già collegati ottengono nuove operazioni solo dopo una nuova approvazione di ciascuna persona.';

  @override
  String get assistantSetupPreviewOwn =>
      'Gli assistenti vedono solo i dati propri di ciascun membro.';

  @override
  String get assistantSetupPreviewRemoves => 'Rimosse';

  @override
  String get assistantSetupPreviewTitle => 'Selezione consigliata';

  @override
  String get assistantSetupReasonConnect =>
      'Aggiungi il connettore nel tuo assistente, accedi e approva questo spazio di lavoro.';

  @override
  String get assistantSetupReasonEligibility =>
      'Gli amministratori di questo database approvano ogni persona una volta, per tutti i suoi spazi di lavoro.';

  @override
  String get assistantSetupReasonIdentity =>
      'Un assistente agisce a tuo nome, quindi questo database deve sapere che sei tu.';

  @override
  String get assistantSetupReasonInstallation =>
      'Il proprietario dell\'istanza o un delegato attiva gli assistenti per tutti gli spazi di lavoro di questo database.';

  @override
  String get assistantSetupReasonPolicy =>
      'Agli assistenti non viene offerto nulla finché qualcuno non sceglie le operazioni.';

  @override
  String get assistantSetupReasonWorkspace =>
      'Finché è disattivato, lo spazio di lavoro rifiuta ogni chiamata di assistente.';

  @override
  String get assistantSetupRecommended => 'Usa la selezione consigliata';

  @override
  String get assistantSetupRequest => 'Chiedi l\'accesso';

  @override
  String get assistantSetupReview => 'Esamina le richieste';

  @override
  String get assistantSetupSaved => 'Salvato.';

  @override
  String get assistantSetupStale =>
      'Qualcuno ha modificato l\'offerta nel frattempo. Controllala e riprova.';

  @override
  String get assistantSetupStateBlocked => 'Dopo i passi precedenti';

  @override
  String get assistantSetupStateDone => 'Fatto';

  @override
  String get assistantSetupStateTodo => 'Da fare';

  @override
  String get assistantSetupStateUnavailable => 'Impossibile da interrogare';

  @override
  String get assistantSetupStateWaiting => 'In attesa';

  @override
  String get assistantSetupStepConnect => 'Collega il tuo assistente';

  @override
  String get assistantSetupStepEligibility =>
      'Chiedi il tuo accesso agli assistenti';

  @override
  String get assistantSetupStepIdentity => 'Collega la tua identità';

  @override
  String get assistantSetupStepInstallation =>
      'Assistenti attivati per questo database';

  @override
  String get assistantSetupStepPolicy =>
      'Scegli cosa possono fare gli assistenti';

  @override
  String get assistantSetupStepWorkspace =>
      'Attiva gli assistenti per questo spazio di lavoro';

  @override
  String get assistantSetupTitle => 'Configurazione degli assistenti';

  @override
  String get assistantSetupTurnOn => 'Attiva';

  @override
  String get authAlreadyRegistered =>
      'Questo indirizzo non può essere usato per creare un account. Accedi o reimposta la password.';

  @override
  String get authConnectServer => 'Collegarsi al server di un\'organizzazione';

  @override
  String get authContinueWith => 'oppure continua con';

  @override
  String get authDisplayNameLabel => 'Nome visualizzato';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authEmailNotConfirmed =>
      'Conferma prima il tuo indirizzo e-mail: apri il messaggio che ti abbiamo inviato, poi accedi.';

  @override
  String get authFieldRequired => 'Obbligatorio';

  @override
  String get authForgotPassword => 'Password dimenticata?';

  @override
  String get authGenericError =>
      'Autenticazione non riuscita. Controlla le credenziali e riprova.';

  @override
  String get authHidePassword => 'Nascondi password';

  @override
  String get authJoinByInvitation => 'Entra con un invito';

  @override
  String get authJoinHint =>
      'Crea prima il tuo account o accedi: incollerai l\'invito subito dopo.';

  @override
  String get authNetworkError =>
      'Impossibile raggiungere il server. Controlla la connessione e riprova.';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordTooShort => 'Almeno 8 caratteri';

  @override
  String get authProviderDisabled =>
      'Questo metodo di accesso è disattivato su questo server.';

  @override
  String get authRateLimited =>
      'Troppi tentativi. Attendi un momento, poi riprova.';

  @override
  String get authRecoveryNotSaved =>
      'Il codice è stato accettato, ma la nuova password non è stata salvata. Riprova a salvarla.';

  @override
  String get authRecoveryRetryUpdate => 'Salva di nuovo la nuova password';

  @override
  String get authRecoverySessionLost =>
      'Quel codice non è più valido qui. Richiedine uno nuovo.';

  @override
  String get authResetCodeLabel => 'Codice ricevuto via e-mail';

  @override
  String get authResetCodeSent => 'Codice inviato — controlla la tua e-mail.';

  @override
  String get authResetDone => 'Password aggiornata — sei connesso.';

  @override
  String get authResetExplainer =>
      'Ti invieremo un codice monouso via e-mail. Usalo qui per impostare una nuova password.';

  @override
  String get authResetInvalidCode => 'Questo codice non è valido o è scaduto.';

  @override
  String get authResetNewPasswordLabel => 'Nuova password';

  @override
  String get authResetSendCode => 'Invia codice';

  @override
  String get authResetSubmit => 'Imposta la nuova password';

  @override
  String get authResetTitle => 'Reimposta la password';

  @override
  String get authShowPassword => 'Mostra password';

  @override
  String get authSignInButton => 'Accedi';

  @override
  String get authSignInTitle => 'Accedi';

  @override
  String get authSignOut => 'Esci';

  @override
  String get authSignUpButton => 'Crea account';

  @override
  String get authSignUpTitle => 'Crea account';

  @override
  String authSocialUnavailable(String provider) {
    return 'L\'accesso con $provider non è ancora disponibile — il server non lo ha abilitato.';
  }

  @override
  String get authToggleToSignIn => 'Hai già un account? Accedi';

  @override
  String get authToggleToSignUp => 'Nuovo qui? Crea un account';

  @override
  String get authVerifyBackToSignIn => 'Torna all\'accesso';

  @override
  String authVerifyBody(String email) {
    return 'Abbiamo inviato un link di conferma a $email. Aprilo su questo dispositivo per completare la creazione dell\'account.';
  }

  @override
  String get authVerifyChangeEmail => 'Usa un altro indirizzo';

  @override
  String get authVerifyHint =>
      'Ancora nulla? Controlla la cartella spam o invialo di nuovo.';

  @override
  String get authVerifyResend => 'Invia di nuovo l\'e-mail';

  @override
  String get authVerifyResendWait => 'Potrai inviarla di nuovo tra un minuto.';

  @override
  String get authVerifyResent => 'Inviata di nuovo.';

  @override
  String get authVerifyTitle => 'Controlla la tua e-mail';

  @override
  String get authWeakPassword => 'Scegli una password più robusta.';

  @override
  String get availabilityAddClosure => 'Aggiungi giorno di chiusura';

  @override
  String get availabilityClosureDays => 'Giorni di chiusura';

  @override
  String get availabilityClosureReason => 'Motivo (facoltativo)';

  @override
  String get availabilityFullDayHours => 'Ore fatturate come giornata intera';

  @override
  String get availabilityGranularity15 => 'Slot di 15 minuti';

  @override
  String get availabilityGranularity30 => 'Slot di 30 minuti';

  @override
  String get availabilityGranularity5 => 'Slot di 5 minuti';

  @override
  String get availabilityGranularity60 => 'Slot di 1 ora';

  @override
  String get availabilityGranularityDescription =>
      'Mezze giornate: le prenotazioni coprono la mattina, il pomeriggio o l\'intera giornata lavorativa — le finestre seguono l\'orario di lavoro configurato.';

  @override
  String get availabilityGranularityFlexible => 'Fascia oraria libera';

  @override
  String get availabilityGranularityFullDay => 'Solo giornate intere';

  @override
  String get availabilityGranularityHalfDay =>
      'Mezze giornate (mattina e pomeriggio)';

  @override
  String get availabilityGranularityHours =>
      'Orari reali (da–a esatto, mezze/giornate come scorciatoie)';

  @override
  String get availabilityGranularityTitle => 'Granularità delle prenotazioni';

  @override
  String get availabilityHalfBoundary => 'Limite di mezza giornata';

  @override
  String get availabilityHalfDayHours => 'Ore fatturate come mezza giornata';

  @override
  String availabilityHourOption(int count) {
    return '$count h';
  }

  @override
  String get availabilityLastOpenDay =>
      'Almeno un giorno della settimana deve restare aperto.';

  @override
  String get availabilityNoClosures => 'Nessun giorno di chiusura.';

  @override
  String get availabilityOpenWeekdays => 'Giorni di apertura';

  @override
  String get availabilityPoliciesTitle => 'Regole di prenotazione';

  @override
  String get availabilityTitle => 'Disponibilità';

  @override
  String get availabilityWorkEnd => 'Fine giornata';

  @override
  String get availabilityWorkHoursDescription =>
      'Le finestre di mezza giornata e giornata intera ovunque — prenotazioni, check-in e fatturazione — seguono questo orario.';

  @override
  String get availabilityWorkHoursInvalid =>
      'Deve valere: inizio < limite di mezza giornata < fine.';

  @override
  String get availabilityWorkHoursTitle => 'Orario di lavoro';

  @override
  String get availabilityWorkStart => 'Inizio giornata';

  @override
  String get backendCopyLink => 'Copia';

  @override
  String get backendCurrentTitle => 'Questo dispositivo usa';

  @override
  String get backendDescriptorInvalid =>
      'Questo non è un codice server DesKilo valido.';

  @override
  String get backendDescriptorLabel => 'Codice server';

  @override
  String backendDescriptorNamed(String label) {
    return 'Chiamato «$label» da chi lo ha condiviso — non verificato.';
  }

  @override
  String backendDestination(String host) {
    return 'Destinazione: $host';
  }

  @override
  String get backendErrorKeyConnectionString =>
      'Questa è una stringa di connessione al database. Non lascia mai il server — incolla qui la chiave pubblicabile del progetto.';

  @override
  String get backendErrorKeyEmpty => 'Inserisci la chiave pubblicabile.';

  @override
  String get backendErrorKeyNotSupabase =>
      'Questa non è una chiave pubblicabile Supabase (sb_publishable_…).';

  @override
  String get backendErrorKeyPersonalToken =>
      'Questo è un token di accesso personale. Resta al suo proprietario — incolla qui la chiave pubblicabile del progetto.';

  @override
  String get backendErrorKeySecret =>
      'Questa è una chiave segreta, non pubblicabile. Non condividerla mai: ruotala in Project Settings → API keys, poi incolla qui la chiave pubblicabile.';

  @override
  String get backendErrorKeyUserToken =>
      'Questo è un token di sessione o di identità, non una chiave di progetto. Incolla qui la chiave pubblicabile del progetto.';

  @override
  String get backendErrorUrlEmpty => 'Inserisci l\'URL del progetto.';

  @override
  String get backendErrorUrlNoHost => 'Questo non è un indirizzo completo.';

  @override
  String get backendErrorUrlNotCanonical =>
      'Indica solo l\'indirizzo del progetto (https://host), senza percorso, parametri o credenziali.';

  @override
  String get backendErrorUrlNotHttps => 'L\'URL deve iniziare con https://.';

  @override
  String get backendFacetNo => 'no';

  @override
  String get backendFacetUnknown => 'sconosciuto';

  @override
  String get backendFacetYes => 'sì';

  @override
  String backendFacets(
    String reachable,
    String key,
    String schema,
    String version,
  ) {
    return 'Raggiunto: $reachable · Chiave accettata: $key · Schema: $schema · Versione: $version';
  }

  @override
  String get backendFullCheckHint =>
      'Incollate un token di accesso personale per questo controllo. Serve solo a questo controllo e non viene mai salvato.';

  @override
  String get backendFullCheckTitle => 'Esegui un controllo completo';

  @override
  String get backendFullCheckUseToken => 'Usa questo token';

  @override
  String get backendHowTitle => 'Usare il tuo server';

  @override
  String get backendKeyLabel => 'Chiave pubblicabile';

  @override
  String backendLastOk(String time) {
    return 'Ultimo test riuscito: $time';
  }

  @override
  String get backendModeConnect => 'Collega un\'organizzazione esistente';

  @override
  String get backendModeConnectHint =>
      'Scansiona o incolla il codice server fornito dalla tua organizzazione. Non serve mai una chiave di amministratore.';

  @override
  String get backendModeDefault => 'Usa il servizio DesKilo';

  @override
  String get backendModeDefaultHint =>
      'Il servizio DesKilo non richiede configurazione. I membri di un\'organizzazione con un proprio server usano invece il suo codice.';

  @override
  String get backendModeOperator => 'Configura un server (operatori)';

  @override
  String get backendOpenDashboard => 'Apri in Supabase';

  @override
  String get backendOwnServer => 'Il vostro server';

  @override
  String get backendOwnership =>
      'Appartiene alla vostra organizzazione Supabase. DesKilo non conserva alcun accesso.';

  @override
  String get backendOwnershipOther =>
      'Appartiene a chi lo gestisce. DesKilo non conserva alcun accesso.';

  @override
  String get backendPaste => 'Incolla';

  @override
  String backendPendingBody(String active, String saved) {
    return 'Questa sessione gira ancora su $active. $saved subentrerà quando chiudi e riapri l\'app.';
  }

  @override
  String get backendPendingTitle => 'Salvato per il prossimo avvio';

  @override
  String get backendPendingUndo => 'Annulla';

  @override
  String get backendPendingUndone =>
      'Annullato — il server precedente è tornato.';

  @override
  String backendProjectRef(String ref) {
    return 'Il vostro progetto Supabase $ref';
  }

  @override
  String get backendResetDeviceOnly =>
      'Questo cambia solo questo dispositivo e non tocca mai il vostro progetto Supabase.';

  @override
  String get backendSaveNeedsTest =>
      'Prova prima la connessione. Solo un server verificato può essere salvato.';

  @override
  String get backendScan => 'Scansiona un QR del server';

  @override
  String get backendScanNothing => 'Questo QR non è un codice server DesKilo.';

  @override
  String backendServerCustom(Object host) {
    return 'Il tuo server ($host)';
  }

  @override
  String backendServerDefault(Object host) {
    return 'Il server dell\'app ($host)';
  }

  @override
  String get backendServerHint =>
      'Per impostazione predefinita l\'app usa il proprio server. Se la tua comunità gestisce un proprio progetto Supabase, inseriscilo qui — l\'app salverà tutto lì.';

  @override
  String get backendServerInUse => 'In uso su questo dispositivo';

  @override
  String get backendServerReset => 'Usa il server dell\'app';

  @override
  String get backendServerRestartHint =>
      'L\'app ti disconnette e applica la modifica al prossimo avvio.';

  @override
  String get backendServerSaved =>
      'Salvato. Chiudi e riapri l\'app per usare il nuovo server.';

  @override
  String get backendServerTitle => 'Server';

  @override
  String get backendShare => 'Condividi questo server';

  @override
  String get backendShareHint =>
      'I membri lo scansionano in Impostazioni → Server per puntare la loro app alla stessa istanza.';

  @override
  String get backendStep1 =>
      'Crea un progetto su supabase.com (il piano gratuito basta per iniziare).';

  @override
  String get backendStep2 =>
      'Installa lo schema dell\'app: esegui i file SQL in supabase/migrations del repository sorgente, in ordine.';

  @override
  String get backendStep3 =>
      'Nel pannello Supabase apri Project Settings → API keys e copia la Project URL e la chiave pubblicabile.';

  @override
  String get backendStep4 =>
      'Incollali qui sotto, prova la connessione e salva. I membri raggiungono la stessa istanza scansionando il QR qui sopra.';

  @override
  String get backendTest => 'Prova la connessione';

  @override
  String get backendTestAhead =>
      'Raggiunto. Il suo schema è più recente di questa app: funziona, ed è disponibile un\'app più recente.';

  @override
  String get backendTestAttention =>
      'Raggiunto, ma la risposta non è stata classificata. Controlla il server prima di usarlo.';

  @override
  String get backendTestBadKey =>
      'Raggiunto, ma la chiave è stata rifiutata. Ricopia la chiave pubblicabile da Project Settings → API keys.';

  @override
  String get backendTestBehind =>
      'Raggiunto, ma il suo schema DesKilo è più vecchio di quanto richiede questa app. Aggiorna il server prima di usarlo.';

  @override
  String get backendTestOk => 'Raggiunto — lo schema dell\'app è presente.';

  @override
  String get backendTestSchemaMissing =>
      'Raggiunto, ma mancano le tabelle DesKilo — esegui prima le migrazioni di supabase/migrations su quel progetto.';

  @override
  String get backendTestUnreachable =>
      'Impossibile raggiungere quell\'indirizzo. Controlla l\'URL e la rete.';

  @override
  String get backendTesting => 'Prova in corso…';

  @override
  String get backendUrlLabel => 'URL del progetto';

  @override
  String get backendVersionAhead =>
      'Il server è più recente di questa app: aggiornate l\'app appena possibile';

  @override
  String backendVersionBehind(int version) {
    return 'Serve un aggiornamento: questa app richiede lo schema $version';
  }

  @override
  String get backendVersionBehindHow =>
      'Il proprietario lo aggiorna con la procedura guidata o `dart run tool/instance.dart install`, che applica solo ciò che manca.';

  @override
  String backendVersionCurrent(int version) {
    return 'Aggiornato (schema $version)';
  }

  @override
  String get backendVersionShortAhead => 'più recente';

  @override
  String get backendVersionShortBehind => 'più vecchia';

  @override
  String get backendVersionShortCurrent => 'aggiornata';

  @override
  String get backendVersionUnknown =>
      'Al momento non è stato possibile verificare la versione';

  @override
  String get badgeAuthEnabledHint =>
      'Disattivo per impostazione predefinita: un badge che registra la tua entrata non ti fa accedere finché non lo decidi tu.';

  @override
  String get badgeAuthEnabledLabel => 'Mi fa accedere';

  @override
  String get badgeAuthNeedsPin =>
      'Imposta prima un PIN di accesso — il badge da solo non deve mai bastare.';

  @override
  String get badgeCardAlreadyRegistered => 'Questa tessera è già registrata.';

  @override
  String get badgeCardRegistered => 'Tessera registrata.';

  @override
  String get badgeDefaultLabel => 'Badge';

  @override
  String get badgeDeleteConfirm =>
      'Eliminare definitivamente questo badge revocato?';

  @override
  String get badgeIssue => 'Nuovo badge';

  @override
  String badgeIssuedOn(String date) {
    return 'Emesso il $date';
  }

  @override
  String get badgeNone => 'Ancora nessun badge.';

  @override
  String get badgePinChangeAction => 'Cambia PIN';

  @override
  String get badgePinClearAction => 'Rimuovi PIN';

  @override
  String get badgePinCleared =>
      'PIN rimosso. I tuoi badge non ti fanno più accedere.';

  @override
  String get badgePinConfirmLabel => 'Ripetilo';

  @override
  String get badgePinExplain =>
      'Il PIN ti permette di accedere scansionando il badge invece di digitare la tua e-mail. Solo tu puoi impostarlo e nessuno — nemmeno un proprietario — può rileggerlo.';

  @override
  String get badgePinMismatch => 'Le due voci non coincidono.';

  @override
  String get badgePinNewLabel => 'Nuovo PIN';

  @override
  String get badgePinNotSet => 'Nessun PIN';

  @override
  String get badgePinSaveFailed =>
      'Server irraggiungibile. Il tuo PIN non è stato modificato — riprova.';

  @override
  String get badgePinSaved => 'PIN salvato.';

  @override
  String get badgePinSectionTitle => 'Il mio PIN';

  @override
  String get badgePinSet => 'PIN impostato';

  @override
  String get badgePinSetAction => 'Imposta un PIN';

  @override
  String badgePinTooShort(int min) {
    return 'Usa almeno $min cifre.';
  }

  @override
  String get badgeRegisterCard => 'Registra tessera';

  @override
  String get badgeRevoke => 'Revoca';

  @override
  String get badgeRevoked => 'Revocato';

  @override
  String get badgeSavePdf => 'Salva come PDF';

  @override
  String get badgeSignInButton => 'Accedi';

  @override
  String get badgeSignInEntry => 'Accedi con un badge';

  @override
  String badgeSignInHello(String name) {
    return 'Ciao $name';
  }

  @override
  String get badgeSignInLocked =>
      'Troppi tentativi. Attendi qualche minuto, oppure accedi con la tua e-mail.';

  @override
  String get badgeSignInNoReader =>
      'Nessun lettore di badge disponibile su questo dispositivo.';

  @override
  String get badgeSignInPinLabel => 'Il tuo PIN';

  @override
  String get badgeSignInRefused =>
      'Non ha funzionato. Controlla il badge e il PIN, oppure accedi con la tua e-mail.';

  @override
  String get badgeSignInRetry => 'Riprova';

  @override
  String get badgeSignInTapPrompt => 'Avvicina il badge al telefono.';

  @override
  String get badgeSignInTitle => 'Accedi con il badge';

  @override
  String get badgeSignInUnavailable =>
      'L’accesso con badge non è raggiungibile ora. Accedi con la tua e-mail.';

  @override
  String get badgeSignInUseEmail => 'Usa la mia e-mail';

  @override
  String get badgeTapCardHint =>
      'Avvicina la tessera RFID/NFC al retro del dispositivo.';

  @override
  String get badgeTapCardTitle => 'Registra una tessera';

  @override
  String get badgeTokenOnce =>
      'Salva questo QR adesso — viene mostrato una sola volta.';

  @override
  String get biAreaCapacity => 'Spazi e capacità';

  @override
  String get biAreaFinance => 'Finanze';

  @override
  String get biAreaOperations => 'Operatività';

  @override
  String get biAreaOverview => 'Panoramica';

  @override
  String get biAreaPeople => 'Persone e attività';

  @override
  String get biAreaPlanning => 'Pianificazione';

  @override
  String get biAreaSaved => 'Analisi salvate';

  @override
  String get biAreaTreasury => 'Tesoreria';

  @override
  String biChangePoints(String value) {
    return '$value p.p.';
  }

  @override
  String get biColumnChange => 'Variazione';

  @override
  String get biColumnValue => 'Valore';

  @override
  String get biCompare => 'Confronta con';

  @override
  String get biCompareCustom => 'Un periodo che scelgo';

  @override
  String get biCompareNone => 'Niente';

  @override
  String get biComparePrevious => 'Il periodo precedente';

  @override
  String get biComparePreviousYear => 'Lo stesso periodo un anno prima';

  @override
  String biComparedLine(String period, String value, String change) {
    return '$period: $value ($change)';
  }

  @override
  String biComparedNotRecorded(String period, String since) {
    return '$period non è stato registrato (lo storico inizia il $since); nessun confronto.';
  }

  @override
  String biComparedPartial(String period) {
    return '$period è registrato solo in parte.';
  }

  @override
  String get biDimensionLevel => 'Piano';

  @override
  String get biExposureDiffers =>
      'I due periodi non hanno la stessa base; il tasso ne tiene conto, i valori grezzi non si confrontano direttamente.';

  @override
  String get biForbidden => 'Non puoi leggere questa analisi in questo spazio.';

  @override
  String get biGrain => 'Durata del periodo';

  @override
  String get biGrainMonth => 'Mese';

  @override
  String get biGrainQuarter => 'Trimestre';

  @override
  String get biGrainYear => 'Anno';

  @override
  String get biGroupBy => 'Raggruppa per';

  @override
  String get biGroupNone => 'Nessun raggruppamento';

  @override
  String get biInvalidAddress =>
      'Questo indirizzo chiede un’analisi che non esiste; non è stato letto nulla.';

  @override
  String get biNotOffered => 'non offerto dalle analisi mostrate';

  @override
  String get biOpenSource => 'Apri la fonte';

  @override
  String biQuarter(String quarter, String year) {
    return 'T$quarter $year';
  }

  @override
  String biRefusedBudget(String count) {
    return 'Ci sono più di $count gruppi; scegli «Nessun raggruppamento».';
  }

  @override
  String get biRefusedComparison =>
      'Questa analisi non può fare questo confronto.';

  @override
  String get biRefusedGrain =>
      'Questa analisi non è offerta per questa durata del periodo.';

  @override
  String get biRefusedGrouping =>
      'Questa analisi non può essere raggruppata così.';

  @override
  String get biRemainder => 'Fuori dai gruppi attuali';

  @override
  String get biReset => 'Mostra la vista standard';

  @override
  String get biSort => 'Ordine';

  @override
  String get biSortAscending => 'Prima il più basso';

  @override
  String get biSortDescending => 'Prima il più alto';

  @override
  String get biSortNatural => 'Come elencato';

  @override
  String get biSortUngrouped => 'Ordine (solo gruppi)';

  @override
  String get biSourceRestricted =>
      'I dati di origine sono visibili solo a chi li gestisce.';

  @override
  String get biTitle => 'Analisi aziendale';

  @override
  String get biTotal => 'Totale';

  @override
  String get biUnavailable => 'Non è stato possibile calcolare questa analisi.';

  @override
  String get biViewChart => 'Grafico';

  @override
  String get biViewTable => 'Tabella';

  @override
  String get billAccessorySupplements => 'Supplementi accessori';

  @override
  String get billBalance => 'Saldo';

  @override
  String billCreditNoteCard(String number) {
    return 'Nota di credito $number';
  }

  @override
  String get billCreditNoteDue =>
      'Lo spazio ti deve questo importo: non hai nulla da pagare.';

  @override
  String get billCreditNoteRefunded =>
      'Lo spazio ti ha rimborsato questo importo.';

  @override
  String billEntitlement(int used, int included, int openDays) {
    return '$used mezze giornate fatturate su $included ($openDays giorni di apertura)';
  }

  @override
  String billInvoiceCard(String number) {
    return 'Fattura $number';
  }

  @override
  String get billInvoicePaid => 'Già pagato';

  @override
  String get billInvoiceRemaining => 'Residuo da pagare';

  @override
  String get billInvoiceTotal => 'Totale fattura';

  @override
  String get billOpenPositions => 'Voci in sospeso';

  @override
  String get billOutstanding => 'Aperto';

  @override
  String billOverage(int extra) {
    return '$extra mezze giornate extra';
  }

  @override
  String get billPackages => 'Pacchetti di giorni';

  @override
  String billParticipation(int pct) {
    return 'Partecipazione $pct %';
  }

  @override
  String billParticipationMonth(String month, int pct) {
    return '$month $pct %';
  }

  @override
  String get billPaymentsCredits => 'Pagamenti e crediti';

  @override
  String get billPdfExport => 'Esporta la fattura come PDF';

  @override
  String get billPdfTitle => 'Fattura mensile';

  @override
  String get billPendingBadge => 'in attesa di convalida';

  @override
  String get billServices => 'Servizi consumati';

  @override
  String get billServicesTotal => 'Totale servizi';

  @override
  String get billSettled => 'Saldato';

  @override
  String billSubscription(int pct) {
    return 'Abbonamento $pct %';
  }

  @override
  String billSubscriptionMonth(String month, int pct) {
    return 'Abbonamento $month $pct %';
  }

  @override
  String get billingAddBand => 'Aggiungi fascia';

  @override
  String get billingAddLevel => 'Aggiungi livello';

  @override
  String get billingAddPackage => 'Aggiungi pacchetto';

  @override
  String get billingAdvanceDays => 'Giorni prima dell’inizio del mese';

  @override
  String get billingAllowCustom =>
      'Consenti un valore personalizzato concordato';

  @override
  String get billingBandFee => 'Canone mensile';

  @override
  String billingBandFrom(int from) {
    return 'da $from%';
  }

  @override
  String get billingBandOverage => 'Eccedenza';

  @override
  String get billingBandTo => 'Fino a %';

  @override
  String get billingBandsInvalid =>
      'Le fasce devono crescere e terminare al 100%.';

  @override
  String get billingFeeBands => 'Fasce tariffarie';

  @override
  String get billingLevelValue => 'Livello (1–100)';

  @override
  String get billingLevels => 'Livelli di abbonamento';

  @override
  String get billingNewPackage => 'Nuovo pacchetto';

  @override
  String get billingPackageDays => 'Giorni';

  @override
  String get billingPackageName => 'Nome';

  @override
  String get billingPackagePrice => 'Prezzo';

  @override
  String billingPackageSummary(int days, String price) {
    return '$days giorni · $price';
  }

  @override
  String get billingPackages => 'Pacchetti di giorni';

  @override
  String get billingPackagesHint =>
      'I membri con piano a pacchetto li acquistano quando finiscono i giorni.';

  @override
  String billingPricesVatHint(String rate) {
    return 'I prezzi sono lordi — l’IVA $rate (aliquota predefinita dello spazio) è inclusa.';
  }

  @override
  String get billingRemoveBand => 'Rimuovi fascia';

  @override
  String get billingRulesSaved => 'Calendario di fatturazione salvato.';

  @override
  String get billingRulesSubtitle =>
      'Quando escono le fatture di abbonamento e di fine mese';

  @override
  String get billingRulesTitle => 'Calendario di fatturazione';

  @override
  String get billingSaved => 'Salvato.';

  @override
  String get billingSubscriptionAuto => 'Emetti automaticamente';

  @override
  String get billingSubscriptionOff =>
      'Attiva «Fatture di abbonamento» in Funzionalità per usarlo.';

  @override
  String get billingSubscriptionSection => 'Abbonamento, in anticipo';

  @override
  String billingSubscriptionWhen(String day, String month) {
    return 'Emessa il $day per $month';
  }

  @override
  String billingTariffVatHint(String rate) {
    return 'I prezzi sono lordi — IVA $rate (aliquota delle tariffe) inclusa.';
  }

  @override
  String get billingTitle => 'Fatturazione';

  @override
  String get billingUsageAuto => 'Emetti automaticamente';

  @override
  String get billingUsageOff =>
      'Attiva «Fatture di fine mese» in Funzionalità per usarlo.';

  @override
  String get billingUsageSection => 'Il mese appena concluso';

  @override
  String get billingUsageWhenZero => 'Anche quando non c’è nulla da pagare';

  @override
  String get billingUsageWhenZeroHint =>
      'Invia un documento a zero, come conferma che l’abbonamento ha coperto tutto il mese.';

  @override
  String get bookAccountCode => 'Codice conto';

  @override
  String get bookAccountName => 'Nome del conto';

  @override
  String get bookAccountPosting => 'Riceve registrazioni';

  @override
  String get bookAuthorityExternal => 'Sistema esterno';

  @override
  String get bookAuthorityLocal => 'DesKilo tiene il libro';

  @override
  String get bookAuthorityPre => 'Precontabilità';

  @override
  String get bookBasisAccrual => 'Competenza';

  @override
  String get bookBasisCash => 'Cassa';

  @override
  String get bookChartSuggest => 'Aggiungi i conti suggeriti da verificare';

  @override
  String bookChartTitle(String site) {
    return 'Piano dei conti · $site';
  }

  @override
  String get bookCurrency => 'Valuta funzionale';

  @override
  String bookEffectiveFrom(String date) {
    return 'In vigore dal $date';
  }

  @override
  String get bookExternalSystem => 'Sistema che fa fede';

  @override
  String bookFiscalPreview(String label, String start, String end) {
    return 'Esercizio $label: $start – $end';
  }

  @override
  String get bookFiscalStart => 'L’esercizio inizia il';

  @override
  String get bookIssuer => 'Emittente';

  @override
  String get bookMappingsTitle => 'Il conto di ogni registrazione';

  @override
  String get bookProblemCurrency =>
      'Questa valuta non ha un numero di decimali verificato.';

  @override
  String get bookProblemExternal =>
      'Indica il sistema esterno che tiene i libri ufficiali.';

  @override
  String get bookProblemFiscal =>
      'Un esercizio inizia in un giorno che ogni anno ha (mai il 29 febbraio).';

  @override
  String bookProblemUnmapped(String roles) {
    return 'Associa questi conti prima di avviare un libro locale: $roles.';
  }

  @override
  String get bookRoleBank => 'Banca';

  @override
  String get bookRoleCustomers => 'Clienti (crediti)';

  @override
  String get bookRoleExpenses => 'Costi';

  @override
  String get bookRoleRevenue => 'Ricavi';

  @override
  String get bookRoleVatOutput => 'IVA a debito';

  @override
  String get bookSaveFailed =>
      'Il libro non è stato salvato. Controlla la connessione e riprova.';

  @override
  String get bookSaved => 'Libro salvato';

  @override
  String get bookSheetTitle => 'Libro contabile';

  @override
  String get bookStale =>
      'Qualcuno ha salvato questo libro da quando l’hai aperto. Chiudi e riapri per vedere la sua versione.';

  @override
  String get bookTileEmpty =>
      'Nessun libro: DesKilo tiene i saldi dei membri e le fatture (precontabilità).';

  @override
  String get bookTypeAsset => 'Attività';

  @override
  String get bookTypeEquity => 'Patrimonio netto';

  @override
  String get bookTypeExpense => 'Costo';

  @override
  String get bookTypeIncome => 'Ricavo';

  @override
  String get bookTypeLiability => 'Passività';

  @override
  String bookingCheckedInAtUntil(String space, String until) {
    return 'Check-in su $space fino alle $until.';
  }

  @override
  String get bookingCheckedInElsewhere =>
      'Hai fatto check-in altrove — fai prima il check-out lì.';

  @override
  String bookingCheckedInUntil(String until) {
    return 'Check-in fatto fino alle $until.';
  }

  @override
  String get bookingGateBlocked => 'Non prenotabile così';

  @override
  String bookingHorizonError(int days) {
    return 'Troppo lontano — le prenotazioni sono aperte con $days giorni di anticipo.';
  }

  @override
  String get bookingMembershipPaused =>
      'La tua iscrizione è sospesa — un amministratore la riattiva in Membri.';

  @override
  String get bookingModeCheckInNow => 'Check-in adesso';

  @override
  String get bookingMoreOptions => 'Altre opzioni';

  @override
  String get bookingNoLongerCheckedIn =>
      'Questa prenotazione non è più in corso — è stata chiusa nel frattempo.';

  @override
  String get bookingNotAMember =>
      'Non sei più membro di questo spazio — chiedi un invito a un amministratore.';

  @override
  String get bookingOnePlace =>
      'Hai già una prenotazione in quel periodo — un posto alla volta.';

  @override
  String get bookingOpenDetails => 'Dettagli';

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
  String get bookingOverlapsAnother =>
      'Il posto è già prenotato per parte di questo orario.';

  @override
  String get bookingPastError =>
      'Questa prenotazione è interamente nel passato.';

  @override
  String bookingReservedSpaceWhen(String space, String when) {
    return '$space prenotato: $when.';
  }

  @override
  String bookingReservedWhen(String when) {
    return 'Prenotato: $when.';
  }

  @override
  String get bookingSameDayError =>
      'Una prenotazione termina il giorno in cui inizia — prenota il giorno dopo separatamente.';

  @override
  String get bookingSpaceChainTaken =>
      'Questo spazio, o uno spazio che lo contiene, è già prenotato in quel periodo.';

  @override
  String bookingTooLongError(int minutes) {
    return 'Troppo lunga — una prenotazione dura al massimo $minutes minuti.';
  }

  @override
  String bookingTooShortError(int minutes) {
    return 'Troppo breve — una prenotazione dura almeno $minutes minuti.';
  }

  @override
  String get bookingWalkUpTodayError =>
      'Un check-in spontaneo deve iniziare oggi.';

  @override
  String get bootFailedBody =>
      'Il server o l\'archivio sicuro di questo dispositivo non ha risposto. Non è stato modificato nulla. Chiudi l\'app e riaprila; se continua a succedere, controlla la rete.';

  @override
  String get bootFailedTitle => 'DesKilo non è riuscito ad avviarsi';

  @override
  String get bootSlowBody =>
      'Continua a provare. Se non succede nulla, chiudi l\'app e riaprila.';

  @override
  String get bootSlowTitle => 'L\'avvio richiede più tempo del solito';

  @override
  String brandColorRefused(String color, String pair) {
    return 'Il colore $color non è stato applicato: $pair sarebbe illeggibile.';
  }

  @override
  String get buyPackageButton => 'Acquista un pacchetto';

  @override
  String buyPackageDays(int days) {
    return '$days giorni';
  }

  @override
  String get buyPackageDone => 'Giorni aggiunti — goditi il tempo extra.';

  @override
  String get buyPackageNone => 'Nessun pacchetto disponibile al momento.';

  @override
  String get buyPackageTitle => 'Acquista un pacchetto';

  @override
  String calendarAgendaEmpty(int days) {
    return 'Niente in programma nei prossimi $days giorni.';
  }

  @override
  String calendarAgendaRange(int days) {
    return 'Prossimi $days giorni';
  }

  @override
  String get calendarAllLevels => 'Tutti i piani';

  @override
  String get calendarCancelFollowing => 'Annulla questa e le successive';

  @override
  String get calendarCancelOccurrence => 'Annulla questa occorrenza';

  @override
  String get calendarClosedDay => 'Chiuso';

  @override
  String calendarClosedDayReason(String reason) {
    return 'Chiuso — $reason';
  }

  @override
  String get calendarDay => 'Giorno';

  @override
  String get calendarDayEmpty => 'Niente in questo giorno.';

  @override
  String calendarDueTitle(String number) {
    return 'Scadenza · $number';
  }

  @override
  String get calendarEventActionApproved => 'approvata';

  @override
  String get calendarEventActionCancelled => 'annullata';

  @override
  String get calendarEventActionCreated => 'creata';

  @override
  String get calendarEventActionModified => 'modificata';

  @override
  String get calendarEventActionRefused => 'rifiutato';

  @override
  String get calendarEventActionRejected => 'rifiutata';

  @override
  String get calendarEventActionSubmitted => 'inviata';

  @override
  String get calendarEventActionValidated => 'convalidato';

  @override
  String get calendarEventStatusExpired => 'scaduto';

  @override
  String get calendarEventStatusPending => 'in attesa di conferma';

  @override
  String get calendarEventStatusRejected => 'rifiutato';

  @override
  String calendarEventTitle(String label) {
    return 'Avviso: $label';
  }

  @override
  String get calendarEveryoneTab => 'Tutti';

  @override
  String get calendarGroupActivity => 'Avvisi e messaggi';

  @override
  String get calendarGroupBookings => 'Prenotazioni e presenza';

  @override
  String get calendarGroupMoney => 'Finanze';

  @override
  String calendarItemCount(int count) {
    return '$count elementi';
  }

  @override
  String get calendarKindCheckIn => 'Check-in';

  @override
  String get calendarKindCheckOut => 'Check-out';

  @override
  String get calendarKindConsumption => 'Consumi';

  @override
  String get calendarKindDue => 'Scadenze';

  @override
  String get calendarKindEvent => 'Avvisi';

  @override
  String get calendarKindInvoice => 'Fatture';

  @override
  String get calendarKindMessage => 'Messaggi';

  @override
  String get calendarKindPayment => 'Pagamenti';

  @override
  String get calendarKindReminder => 'Promemoria';

  @override
  String get calendarKindReservation => 'Prenotazioni';

  @override
  String get calendarKindScheduled => 'Spese programmate';

  @override
  String get calendarKindValidation => 'Convalide';

  @override
  String calendarLevelCollapsed(String level) {
    return '$level, compresso';
  }

  @override
  String calendarLevelExpanded(String level) {
    return '$level, espanso';
  }

  @override
  String get calendarListView => 'Vista elenco';

  @override
  String calendarLockedKinds(String kinds) {
    return 'Non visibile per questo membro: $kinds';
  }

  @override
  String get calendarMemberMe => 'Io';

  @override
  String get calendarMineTab => 'Le mie';

  @override
  String get calendarNext => 'Successivo';

  @override
  String get calendarNextMonth => 'Mese successivo';

  @override
  String get calendarNoReservations => 'Nessuna prenotazione in questo giorno.';

  @override
  String get calendarNothingHere => 'Niente in queste date.';

  @override
  String get calendarPrevious => 'Precedente';

  @override
  String get calendarPreviousMonth => 'Mese precedente';

  @override
  String get calendarRange => 'Periodo';

  @override
  String get calendarReservationActions => 'Azioni della prenotazione';

  @override
  String calendarScheduledTitle(String name) {
    return 'Spesa programmata · $name';
  }

  @override
  String get calendarShowOnPlan => 'Mostra sulla pianta';

  @override
  String get calendarTimelineAllEmpty =>
      'Nessuna prenotazione su nessun piano in questo giorno.';

  @override
  String get calendarTimelineEmpty =>
      'Nessuna prenotazione su questo piano in questo giorno.';

  @override
  String get calendarTimelineView => 'Vista cronologia';

  @override
  String get calendarToday => 'Oggi';

  @override
  String get calendarTomorrow => 'Domani';

  @override
  String calendarValidationRefused(String what) {
    return 'Rifiutato: $what';
  }

  @override
  String calendarValidationValidated(String what) {
    return 'Convalidato: $what';
  }

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarViewMonth => 'Mese';

  @override
  String get calendarViewWeek => 'Settimana';

  @override
  String get calendarWeekEmpty => 'Niente questa settimana.';

  @override
  String get calendarWhoCanSee => 'Chi può vedere questo';

  @override
  String get calendarYesterday => 'Ieri';

  @override
  String get capabilityBrowserPrefer => 'Preferisci';

  @override
  String get capabilityBrowserRequire => 'Richiedi';

  @override
  String get capabilityBrowserTitle => 'Sfoglia le funzioni';

  @override
  String get capabilityCreditPacks => 'Carnet';

  @override
  String get capabilityCustomMemberForm => 'Modulo socio personalizzato';

  @override
  String get capabilityMultiApproval => 'Due o più approvazioni';

  @override
  String get capabilityOpeningHours => 'Orari di apertura';

  @override
  String get capabilityPayAsYouGo => 'Pagamento a consumo';

  @override
  String get capabilityRefundApprovals => 'Due approvazioni per i rimborsi';

  @override
  String get capabilityStateConditional =>
      'Attivo solo se lo sono i prerequisiti';

  @override
  String get capabilityStateDisabled => 'Disattivo';

  @override
  String get capabilityStateEnabled => 'Attivo';

  @override
  String get capabilityStateIncompatible => 'Non applicabile qui';

  @override
  String get capabilityStateLocalInput => 'Richiede prima un valore locale';

  @override
  String get capabilityStateUnknown => 'Sconosciuto';

  @override
  String get capabilityStateUnspecified => 'Non impostato da questo modello';

  @override
  String get capabilitySubscriptionPlans => 'Piani di abbonamento';

  @override
  String capacityKpiAsOf(String time) {
    return 'Calcolato $time';
  }

  @override
  String get capacityKpiDefinition =>
      'Ore-posto prenotate negli orari di apertura, divise per le ore-posto offerte: ogni posto per le ore di apertura dei giorni aperti, meno i giorni di chiusura e i blocchi dei posti. Una scrivania, una sala o un piano interi contano ciascuno dei loro posti una volta; le prenotazioni annullate non contano.';

  @override
  String get capacityKpiExplain => 'Come viene calcolato?';

  @override
  String get capacityKpiForbidden =>
      'Non puoi consultare i dati di capacità di questo spazio.';

  @override
  String capacityKpiHistory(String date) {
    return 'Storia registrata dal $date';
  }

  @override
  String capacityKpiHistorySince(String date) {
    return 'Contato dal $date, quando è iniziata la storia di questo spazio; il tempo precedente non è noto e non viene contato.';
  }

  @override
  String get capacityKpiKnownZero => 'Misurato: non è stato prenotato nulla.';

  @override
  String capacityKpiNotRecorded(String date) {
    return 'Questo periodo precede l’inizio della storia dello spazio, il $date; non c’è nulla di registrato da contare.';
  }

  @override
  String capacityKpiOutside(String hours) {
    return 'Prenotato fuori dalle ore offerte: $hours ore-posto, escluse dal rapporto';
  }

  @override
  String capacityKpiOverlap(String hours) {
    return 'Prenotato due volte nello stesso momento: $hours ore-posto, contate una volta';
  }

  @override
  String capacityKpiPhysical(String hours) {
    return 'Capacità fisica: $hours ore-posto';
  }

  @override
  String capacityKpiRatio(String reserved, String offered) {
    return '$reserved su $offered ore-posto prenotate';
  }

  @override
  String get capacityKpiRetry => 'Riprova';

  @override
  String capacityKpiRooms(String count, String reserved, String offered) {
    return 'Sale senza posti: $count, $reserved su $offered ore-sala prenotate';
  }

  @override
  String get capacityKpiRoomsToday =>
      'Le sale senza posti sono lette come sono oggi.';

  @override
  String get capacityKpiTitle => 'Occupazione dei posti';

  @override
  String get capacityKpiUnattributed =>
      'Alcune prenotazioni del periodo riguardano un posto che non esiste più; non vengono contate.';

  @override
  String get capacityKpiUnavailable =>
      'Non è stato possibile calcolare l’occupazione dei posti.';

  @override
  String get capacityKpiUndefined =>
      'In questo periodo non è stato offerto tempo di posto, quindi non c’è occupazione da mostrare.';

  @override
  String get captureRecordingHidden =>
      'Nascosto mentre lo schermo viene registrato o duplicato.';

  @override
  String get captureWebNotice =>
      'Il tuo browser non può impedire gli screenshot di questa conversazione.';

  @override
  String get carnetAdd => 'Aggiungi carnet';

  @override
  String carnetBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mezze giornate rimaste',
      one: '1 mezza giornata rimasta',
      zero: 'Nessuna mezza giornata rimasta',
    );
    return '$_temp0';
  }

  @override
  String get carnetHalfDays => 'Mezze giornate';

  @override
  String get carnetName => 'Nome';

  @override
  String get carnetPrice => 'Prezzo';

  @override
  String get carnetSell => 'Vendi un carnet';

  @override
  String get carnetSold =>
      'Carnet venduto — addebitato una volta sulla fattura del mese.';

  @override
  String carnetSummary(int halfDays, String price) {
    return '$halfDays mezze giornate · $price';
  }

  @override
  String get carnetValidity => 'Validità (mesi, vuoto = non scade mai)';

  @override
  String get carnetsEmpty => 'Nessun carnet per ora.';

  @override
  String get carnetsTitle => 'Carnet';

  @override
  String get coOwnerAction => 'Comproprietà';

  @override
  String get coOwnerActivate => 'Promuovi a proprietario ora';

  @override
  String get coOwnerActive =>
      'Comproprietario attivo — permessi da proprietario subito, successione automatica';

  @override
  String get coOwnerNone => 'Nessuna comproprietà';

  @override
  String get coOwnerPassive =>
      'Successore — diventa proprietario all\'attivazione o quando il proprietario se ne va';

  @override
  String coloursApplied(String hex) {
    return '$hex applicato. L’app ne deriva i temi.';
  }

  @override
  String get coloursDark => 'Scuro';

  @override
  String get coloursHexHint =>
      'Sei cifre esadecimali. Lasciare vuoto per i colori del prodotto.';

  @override
  String get coloursHexLabel => 'Colore';

  @override
  String get coloursIntro =>
      'Un colore, e l’app ne deriva i temi chiaro e scuro. Tutto il resto mantiene la palette del prodotto.';

  @override
  String get coloursLight => 'Chiaro';

  @override
  String coloursMalformed(String text) {
    return '$text non è un colore: scrivetelo come #RRGGBB.';
  }

  @override
  String get coloursNeverTheirs =>
      'Il marchio DesKilo, i colori degli stati dei posti e il banner di produzione sono del prodotto, in ogni spazio.';

  @override
  String get coloursPreview => 'Come appare';

  @override
  String coloursRefused(String pair) {
    return 'Rifiutato: $pair sarebbe illeggibile con questo colore.';
  }

  @override
  String get coloursReset => 'Colori del prodotto';

  @override
  String get coloursResetDone => 'I colori del prodotto sono tornati.';

  @override
  String get coloursRooms => 'Colori delle sale';

  @override
  String get coloursRoomsAdd => 'Aggiungi un colore';

  @override
  String coloursRoomsOwn(int n) {
    return '$n colori vostri, in questo ordine.';
  }

  @override
  String get coloursRoomsProduct =>
      'La palette del prodotto. Aggiungete un colore per usare la vostra.';

  @override
  String coloursRoomsSaved(int n) {
    return '$n colori delle sale salvati.';
  }

  @override
  String get coloursSaveFailed =>
      'Non è stato possibile salvare il colore. Nulla è cambiato.';

  @override
  String get coloursTitle => 'Colori';

  @override
  String coloursTooMany(int most) {
    return 'La piantina dipinge al massimo $most colori delle sale.';
  }

  @override
  String get comingSoon => 'Prossimamente';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonCopy => 'Copia';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonDone => 'Fatto';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonSaveFailed => 'Impossibile salvare il file.';

  @override
  String commonSavedTo(String path) {
    return 'Salvato in $path';
  }

  @override
  String get commonShare => 'Condividi';

  @override
  String get commonStart => 'Avvia';

  @override
  String get compareAdd => 'Aggiungi al confronto';

  @override
  String get compareAll => 'Tutte le impostazioni';

  @override
  String compareCount(String shown, String total) {
    return '$shown di $total impostazioni';
  }

  @override
  String get compareCurrencies => 'Valute diverse: non confrontabile';

  @override
  String get compareDefault => 'Predefinito';

  @override
  String get compareDifferences => 'Differenze';

  @override
  String get compareEmpty => 'Vuoto';

  @override
  String get compareExport => 'Esporta in Excel';

  @override
  String get compareExported => 'Cartella di lavoro salvata.';

  @override
  String get compareInherits => 'Mantiene quello dello spazio';

  @override
  String compareLimit(String count) {
    return 'Si possono confrontare fino a $count modelli. Rimuovine prima uno.';
  }

  @override
  String get compareLocal => 'Da impostare localmente';

  @override
  String get compareMissing => 'Non in questo modello';

  @override
  String get compareNo => 'No';

  @override
  String get compareNotCarried => 'Non trasportato';

  @override
  String get compareNothing => 'Nessuna impostazione è diversa.';

  @override
  String compareOpen(String count) {
    return 'Confronta ($count)';
  }

  @override
  String get compareRemove => 'Rimuovi dal confronto';

  @override
  String get compareSearch => 'Cerca un\'impostazione';

  @override
  String get compareTitle => 'Confronta i modelli';

  @override
  String get compareUnavailable =>
      'Non è stato possibile leggere questi modelli per confrontarli. Non si afferma nulla.';

  @override
  String get compareUnknown => 'Sconosciuto';

  @override
  String get compareYes => 'Sì';

  @override
  String get composerAttach => 'Allega un riferimento';

  @override
  String composerCharsLeft(int count) {
    return '$count caratteri rimasti';
  }

  @override
  String get composerDraftKept => 'Bozza conservata';

  @override
  String get connectionCancelled =>
      'Nel frattempo l’account è cambiato, quindi questa risposta è stata scartata.';

  @override
  String get connectionChangedIdentity =>
      'Questo server non è più quello che hai connesso. Le sue azioni sono sospese finché non lo verifichi di nuovo.';

  @override
  String get connectionChecking => 'Verifica in corso…';

  @override
  String get connectionCurrentServer => 'Questo è il server che l’app usa già.';

  @override
  String get connectionDenied =>
      'Questo server ha rifiutato l’account. Controlla le credenziali o scollegalo.';

  @override
  String get connectionExpired =>
      'L’accesso a questo server è scaduto. Accedi di nuovo a questo server.';

  @override
  String get connectionInvalidEndpoint =>
      'Questo indirizzo o questa chiave non corrisponde a un server valido.';

  @override
  String get connectionMalformed =>
      'Questo server ha risposto qualcosa che l’app non sa leggere.';

  @override
  String get connectionNotConnected =>
      'Questo server non è connesso su questo dispositivo.';

  @override
  String get connectionRetry => 'Riprova';

  @override
  String get connectionSessionNotSaved =>
      'L’azione è stata eseguita, ma questo dispositivo non ha potuto salvare l’accesso al server. Potrebbe esserti chiesto di accedere di nuovo.';

  @override
  String get connectionSignInAgain => 'Accedi di nuovo';

  @override
  String get connectionUnavailable =>
      'Questo server al momento non risponde. Gli altri server non sono coinvolti.';

  @override
  String get connectionUnknownOutcome =>
      'La connessione si è interrotta dopo l’invio della richiesta. Potrebbe essere stata applicata: verifica prima di riprovare.';

  @override
  String get connectionUnsupported =>
      'Questa versione del server non può essere connessa da questa app. Aggiorna l’app o chiedi al gestore del server di aggiornarlo.';

  @override
  String get connectionUsable => 'Connesso';

  @override
  String get connectionVerifyAgain => 'Verifica di nuovo';

  @override
  String get consentAccept => 'Accetta e continua';

  @override
  String consentAcceptedOn(String date, String version) {
    return 'Accettato il $date ($version)';
  }

  @override
  String get consentCheckbox =>
      'Ho letto questo testo e accetto il modo in cui DesKilo tratta i miei dati.';

  @override
  String get consentControllerBody =>
      'Ogni spazio è gestito dal suo proprietario — la tua comunità — che decide membri, prezzi e fornitori di pagamento. L\'app è software libero (AGPL-3.0-or-later) ed è pubblicata da Florian Dittgen (Germania); il backend è Supabase nell\'UE. I pagamenti online passano dal fornitore attivato dal proprietario (PayPal, Stripe, Mollie, Wero) alle sue condizioni.';

  @override
  String get consentControllerTitle => 'Chi è responsabile';

  @override
  String get consentIntro =>
      'Prima di usare DesKilo, ecco cosa fa l\'app con i tuoi dati, chi può vederli e cosa puoi farci. Due minuti; non c\'è altro.';

  @override
  String get consentNotBody =>
      'Nessun tracciamento, nessuna analisi, nessuna pubblicità, nessuna vendita o condivisione di dati. Le notifiche push non portano contenuto — solo «hai un nuovo messaggio»; l\'app stessa scrive il testo. La versione F-Droid non ha alcun servizio Google.';

  @override
  String get consentNotTitle => 'Cosa DesKilo non fa mai';

  @override
  String get consentReadInHelp => 'Leggi nell\'aiuto';

  @override
  String get consentReadOnWiki => 'Leggi sul wiki';

  @override
  String get consentRetentionBody =>
      'Finché sei membro. Quando esci e cancelli, profilo e messaggi spariscono; i documenti contabili (fatture, pagamenti) restano per il periodo legale di conservazione, per identificativo e non per nome.';

  @override
  String get consentRetentionTitle => 'Per quanto tempo';

  @override
  String get consentReviewBody =>
      'Questo testo resta disponibile in Impostazioni → Privacy e dati, nell\'aiuto dell\'app (Privacy) e nel wiki del progetto. Una modifica del testo richiede di nuovo la tua accettazione.';

  @override
  String get consentReviewHint =>
      'Il testo che hai accettato, con la data — rileggilo quando vuoi.';

  @override
  String get consentReviewTitle => 'Rileggilo quando vuoi';

  @override
  String get consentRightsBody =>
      'Accesso, rettifica, esportazione (art. 20), cancellazione (art. 17) e opposizione — ciascuno è un pulsante in Impostazioni → Privacy e dati. Per il resto: fdittgen@gmail.com. Puoi revocare questo consenso in qualsiasi momento lasciando lo spazio e cancellando i tuoi dati.';

  @override
  String get consentRightsTitle => 'I tuoi diritti';

  @override
  String get consentTitle => 'I tuoi dati, i tuoi diritti';

  @override
  String get consentUnavailable =>
      'Impossibile caricare il tuo account, quindi non c’è ancora nulla da accettare.';

  @override
  String get consentVersion => 'Versione';

  @override
  String get consentWhatBody =>
      'Il tuo account (e-mail, nome visualizzato, password cifrata), il tuo profilo come lo compili (foto, stato, indirizzo, numero WhatsApp — ciascuno facoltativo), e ciò che fai in uno spazio: prenotazioni e check-in, messaggi, spese e consumi, il tuo abbonamento, fatture e pagamenti. Tutto è conservato nell\'UE (Supabase, eu-central-1).';

  @override
  String get consentWhatTitle => 'Cosa tratta DesKilo';

  @override
  String get consentWhoBody =>
      'L\'accesso segue i ruoli ed è applicato sul server: le prenotazioni le vede lo spazio (la pianta mostra l\'occupazione); i messaggi solo le persone della conversazione, qualunque sia il ruolo; le tue finanze e il tuo accordo commerciale solo tu, i proprietari e gli admin con il permesso corrispondente. Impostazioni → Privacy e dati nomina le persone ed elenca chi ha davvero guardato.';

  @override
  String get consentWhoTitle => 'Chi può vedere cosa';

  @override
  String get consumptionAdd => 'Aggiungi consumo';

  @override
  String consumptionAddForMember(String name) {
    return 'Aggiungi servizio per $name';
  }

  @override
  String get consumptionNoServices => 'Nessun servizio attivo da registrare.';

  @override
  String get consumptionPeriodLabel => 'Periodo di fatturazione (AAAA-MM)';

  @override
  String get consumptionQuantity => 'Quantità';

  @override
  String get consumptionRecorded =>
      'Consumo registrato — in attesa di conferma.';

  @override
  String get consumptionRefusedInactive =>
      'Questo servizio non è più offerto. Non è stato registrato nulla.';

  @override
  String get consumptionRefusedPeriod =>
      'Il periodo di fatturazione deve essere un mese (AAAA-MM). Non è stato registrato nulla.';

  @override
  String get consumptionRefusedQuantity =>
      'La quantità deve essere tra 1 e 999. Non è stato registrato nulla.';

  @override
  String get consumptionRefusedStock =>
      'Scorte insufficienti. Non è stato registrato nulla.';

  @override
  String get consumptionService => 'Servizio';

  @override
  String get conversationAddPeople => 'Aggiungi membri';

  @override
  String get conversationAdmin => 'Admin';

  @override
  String get conversationArchive => 'Archivia';

  @override
  String get conversationArchived => 'Conversazione archiviata.';

  @override
  String get conversationEmpty => 'Ancora nessun messaggio — saluta!';

  @override
  String get conversationGroup => 'Gruppo';

  @override
  String get conversationGroupInfo => 'Gruppo';

  @override
  String get conversationLeave => 'Esci dal gruppo';

  @override
  String get conversationLeaveConfirm =>
      'Uscire da questo gruppo? Non riceverai più i suoi messaggi; quelli già inviati restano.';

  @override
  String get conversationLeft => 'Uscito';

  @override
  String get conversationLoadEarlier => 'Carica messaggi precedenti';

  @override
  String get conversationMarkUnread => 'Segna come non letto';

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
  String get conversationMute => 'Silenzia le notifiche';

  @override
  String get conversationMutedBadge => 'Silenziosa';

  @override
  String get conversationPin => 'Fissa in alto';

  @override
  String get conversationRemove => 'Rimuovi';

  @override
  String get conversationSeeProfile => 'Vedi profilo';

  @override
  String get conversationToday => 'Oggi';

  @override
  String get conversationUnarchive => 'Ripristina dall\'archivio';

  @override
  String get conversationUnknownMember => 'Membro';

  @override
  String get conversationUnmute => 'Riattiva le notifiche';

  @override
  String get conversationUnpin => 'Sblocca';

  @override
  String get conversationYesterday => 'Ieri';

  @override
  String get conversationYou => 'Tu';

  @override
  String get countryNameAT => 'Austria';

  @override
  String get countryNameAU => 'Australia';

  @override
  String get countryNameBE => 'Belgio';

  @override
  String get countryNameBG => 'Bulgaria';

  @override
  String get countryNameCA => 'Canada';

  @override
  String get countryNameCH => 'Svizzera';

  @override
  String get countryNameCY => 'Cipro';

  @override
  String get countryNameCZ => 'Cechia';

  @override
  String get countryNameDE => 'Germania';

  @override
  String get countryNameDK => 'Danimarca';

  @override
  String get countryNameEE => 'Estonia';

  @override
  String get countryNameES => 'Spagna';

  @override
  String get countryNameFI => 'Finlandia';

  @override
  String get countryNameFR => 'Francia';

  @override
  String get countryNameGB => 'Regno Unito';

  @override
  String get countryNameGR => 'Grecia';

  @override
  String get countryNameHR => 'Croazia';

  @override
  String get countryNameHU => 'Ungheria';

  @override
  String get countryNameIE => 'Irlanda';

  @override
  String get countryNameIT => 'Italia';

  @override
  String get countryNameJP => 'Giappone';

  @override
  String get countryNameLT => 'Lituania';

  @override
  String get countryNameLU => 'Lussemburgo';

  @override
  String get countryNameLV => 'Lettonia';

  @override
  String get countryNameMT => 'Malta';

  @override
  String get countryNameMX => 'Messico';

  @override
  String get countryNameNL => 'Paesi Bassi';

  @override
  String get countryNameNO => 'Norvegia';

  @override
  String get countryNamePL => 'Polonia';

  @override
  String get countryNamePT => 'Portogallo';

  @override
  String get countryNameRO => 'Romania';

  @override
  String get countryNameSE => 'Svezia';

  @override
  String get countryNameSI => 'Slovenia';

  @override
  String get countryNameSK => 'Slovacchia';

  @override
  String get countryNameUS => 'Stati Uniti';

  @override
  String get courtesyHint =>
      'Stampata prima del nome sui documenti. «Nessuna» stampa solo il nome.';

  @override
  String get courtesyHintManaged =>
      'Stampata prima del loro nome sui documenti. «Nessuna» stampa solo il nome.';

  @override
  String get courtesyLabel => 'Formula di cortesia';

  @override
  String get courtesyMr => 'Sig.';

  @override
  String get courtesyMrs => 'Sig.ra';

  @override
  String get courtesyNone => 'Nessuna';

  @override
  String get datevAccountsIntro =>
      'I numeri di consulente e di cliente te li dà il commercialista. DATEV rifiuta un file con numeri non corrispondenti — ed è proprio questo che lo tiene fuori dai libri dell’azienda sbagliata.';

  @override
  String get datevAccountsTitle => 'Esportazione DATEV';

  @override
  String get datevClientNumber => 'Mandantennummer (n. cliente)';

  @override
  String get datevConsultantNumber => 'Beraternummer (n. consulente)';

  @override
  String get decisionSurfaceEmpty => 'Niente ti aspetta';

  @override
  String get decisionSurfaceEmptyDetail => 'È tutto sistemato.';

  @override
  String get defaultPeriodNone => 'Nessuna preferenza (giornata intera)';

  @override
  String get defaultPeriodTitle => 'Periodo di prenotazione predefinito';

  @override
  String get demoEntryAction => 'Esplora lo spazio dimostrativo';

  @override
  String get demoEntryBody =>
      'Tutto qui dentro è inventato: le persone, le prenotazioni e le fatture sono create per la dimostrazione. Nulla di ciò che fai raggiunge uno spazio reale, nulla lascia questo dispositivo e non serve alcun account. Il ripristino rimette tutto com\'era quando vuoi.';

  @override
  String get demoEntryStart => 'Inizia';

  @override
  String get demoEntryTitle => 'Uno spazio da guardare';

  @override
  String get demoPersonaAdmin => 'Un\'amministratrice';

  @override
  String get demoPersonaMember => 'Un membro';

  @override
  String get demoPersonaOwner => 'La proprietaria';

  @override
  String get demoSessionBadge => 'Demo';

  @override
  String get demoSessionBadgeHint =>
      'Stai esplorando uno spazio dimostrativo. Nulla di tutto questo lascia questo dispositivo.';

  @override
  String get demoSessionLeave => 'Esci dalla demo';

  @override
  String get demoSessionReset => 'Reimposta la demo';

  @override
  String get demoSessionResetDone => 'La demo è tornata come all\'inizio.';

  @override
  String get demoSessionViewAs => 'Vedi come';

  @override
  String get deployEntityAccessories => 'Accessori';

  @override
  String get deployEntityBookingRules => 'Regole di prenotazione';

  @override
  String get deployEntityBranding => 'Colori';

  @override
  String get deployEntityClosureDays => 'Giorni di chiusura';

  @override
  String get deployEntityCreditProducts => 'I carnet prepagati in vendita';

  @override
  String get deployEntityDocumentDesign => 'Modelli di documento';

  @override
  String get deployEntityDocumentLinks => 'Collegamenti ai documenti';

  @override
  String get deployEntityFeatures => 'Funzionalità';

  @override
  String get deployEntityFieldDefinitions => 'Le domande dello spazio';

  @override
  String get deployEntityFloorPlan =>
      'Planimetrie (piani, postazioni, immagini)';

  @override
  String get deployEntityIdentity => 'Identità e dati legali';

  @override
  String get deployEntityInvitations => 'Modelli di invito';

  @override
  String get deployEntityPackages => 'Pacchetti';

  @override
  String get deployEntityPaymentInstructions => 'Istruzioni di pagamento';

  @override
  String get deployEntityReminders => 'Regole di sollecito';

  @override
  String get deployEntityRoles => 'Matrice dei ruoli';

  @override
  String get deployEntityServices => 'Servizi';

  @override
  String get deployEntitySites => 'Sedi';

  @override
  String get deployEntityTariffs => 'Tariffe';

  @override
  String get deployEntityValidationRules => 'Regole di convalida';

  @override
  String get deployEntityVat => 'IVA';

  @override
  String get deployEntityWorkspaceRoles => 'I ruoli propri dello spazio';

  @override
  String get deploymentConfirm => 'Distribuisci';

  @override
  String get deploymentConfirmBody =>
      'Ciò che questo spazio contiene per le entità spuntate viene sostituito da ciò che ha il gemello. Il giornale conserva la via del ritorno.';

  @override
  String get deploymentConfirmTitleDev => 'Distribuire in questo DEV?';

  @override
  String get deploymentConfirmTitleProd => 'Distribuire in questo PROD?';

  @override
  String get deploymentDirectionToDev => 'In sviluppo';

  @override
  String get deploymentDirectionToProd => 'In produzione';

  @override
  String get deploymentDone => 'Distribuito. È nel giornale.';

  @override
  String get deploymentFlowFromDev => 'Da DEV';

  @override
  String get deploymentFlowFromProd => 'Da PROD';

  @override
  String get deploymentFlowToDev => 'In DEV';

  @override
  String get deploymentFlowToProd => 'In PROD';

  @override
  String get deploymentIntroFromDev =>
      'Sei sul lato produzione. Ciò che spunti qui sotto viene tirato dal gemello di sviluppo in questo spazio, dopo un\'anteprima.';

  @override
  String get deploymentIntroFromProd =>
      'Sei sul lato sviluppo. Ciò che spunti qui sotto viene tirato dal gemello di produzione in questo spazio, dopo un\'anteprima.';

  @override
  String get deploymentIntroToDev =>
      'Sei sul lato produzione. Ciò che spunti qui sotto viene distribuito al gemello di sviluppo, dopo un\'anteprima di ciò che cambia.';

  @override
  String get deploymentIntroToProd =>
      'Sei sul lato sviluppo. Ciò che spunti qui sotto viene distribuito al gemello di produzione, dopo un\'anteprima di ciò che cambia.';

  @override
  String get deploymentJournal => 'Giornale';

  @override
  String get deploymentJournalEmpty => 'Nulla è ancora stato distribuito.';

  @override
  String get deploymentKindConfiguration => 'Configurazione';

  @override
  String get deploymentKindMasterData => 'Dati anagrafici';

  @override
  String get deploymentKindReports => 'Report';

  @override
  String get deploymentNeedsDevPermission =>
      'Distribuire in sviluppo richiede il permesso «Distribuire in sviluppo».';

  @override
  String get deploymentNeedsProdPermission =>
      'Distribuire in produzione richiede il permesso «Distribuire in produzione».';

  @override
  String get deploymentNoChange => 'Nessuna modifica';

  @override
  String get deploymentNoTwin =>
      'Questo spazio non ha un gemello di cui tu sia membro.';

  @override
  String get deploymentNothingToDo =>
      'I due lati concordano già su queste entità.';

  @override
  String get deploymentPreviewToDev => 'Cosa cambia sul lato sviluppo';

  @override
  String get deploymentPreviewToProd => 'Cosa cambia sul lato produzione';

  @override
  String get deploymentPullFromDev => 'Tira da DEV…';

  @override
  String get deploymentPullFromProd => 'Tira da PROD…';

  @override
  String get deploymentRequires => 'richiede';

  @override
  String get deploymentRollback => 'Torna indietro';

  @override
  String get deploymentRolledBack => 'Annullata.';

  @override
  String get deploymentRolledBackLabel => 'annullata';

  @override
  String get deploymentTitle => 'Distribuzione';

  @override
  String get deploymentToDev => 'Distribuisci in DEV…';

  @override
  String get deploymentToProd => 'Distribuisci in PROD…';

  @override
  String get deskDetail => 'Tavolo intero';

  @override
  String get deskSupplementLabel => 'Prenotazioni di tavolo';

  @override
  String get developerClear => 'Svuota registro';

  @override
  String get developerEmpty => 'Ancora nessuna voce nel registro.';

  @override
  String get developerExport => 'Esporta registro';

  @override
  String get developerExportReservations => 'Esporta le prenotazioni';

  @override
  String get developerExportReservationsHint =>
      'Tutte le prenotazioni e i check-in — passati, presenti e futuri, in ogni stato — in CSV, per analisi e debug.';

  @override
  String get developerExportReservationsOwnHint =>
      'Le tue prenotazioni e i tuoi check-in, in ogni stato, in CSV — esportare tutto lo spazio richiede il permesso di esportazione dati.';

  @override
  String get developerFilterAll => 'Tutto';

  @override
  String get developerFilterErrors => 'Errori';

  @override
  String get developerFilterWarnings => 'Avvisi+';

  @override
  String get developerMode => 'Modalità sviluppatore';

  @override
  String get developerModeWorkspaceHint =>
      'Vale per tutti i membri di questo spazio.';

  @override
  String get developerTitle => 'Sviluppatore';

  @override
  String get developmentBanner => 'Spazio di sviluppo — qui nulla è reale';

  @override
  String get developmentWatermark => 'SVILUPPO';

  @override
  String get directoryCheckedIn => 'Presente';

  @override
  String directoryCheckedInSeat(String seat) {
    return 'Presente · $seat';
  }

  @override
  String get directoryClose => 'Chiudi';

  @override
  String get directoryEmpty => 'Ancora nessun membro.';

  @override
  String directoryLastSeenDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Visto $days giorni fa',
      one: 'Visto 1 giorno fa',
    );
    return '$_temp0';
  }

  @override
  String directoryLastSeenHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Visto $hours ore fa',
      one: 'Visto 1 ora fa',
    );
    return '$_temp0';
  }

  @override
  String directoryLastSeenMinutes(int minutes) {
    return 'Visto $minutes min fa';
  }

  @override
  String get directoryNoUpcoming => 'Nessuna prenotazione in arrivo';

  @override
  String get directoryOnline => 'Online';

  @override
  String get directoryOpenGroup => 'Apri il gruppo WhatsApp';

  @override
  String get directoryReservationsHeading => 'Prenotazioni';

  @override
  String get directoryReservedNow => 'Prenotato ora';

  @override
  String directoryReservedNowSeat(String seat) {
    return 'Prenotato ora · $seat';
  }

  @override
  String get directoryReservedToday => 'Prenotato oggi';

  @override
  String get directoryTitle => 'Membri';

  @override
  String get directoryWhatsapp => 'Chatta su WhatsApp';

  @override
  String get documentsAdd => 'Aggiungi un documento';

  @override
  String get documentsCategoryFinance => 'Bilanci';

  @override
  String get documentsCategoryGuides => 'Guide e manuali';

  @override
  String get documentsCategoryLabel => 'Categoria';

  @override
  String get documentsCategoryMinutes => 'Verbali';

  @override
  String get documentsCategoryOther => 'Altri documenti';

  @override
  String get documentsCategoryStatutes => 'Statuto e legale';

  @override
  String get documentsDelete => 'Rimuovere il documento?';

  @override
  String get documentsEmpty =>
      'Nessun documento. Collega statuto, guide e bilanci da qualsiasi drive.';

  @override
  String get documentsInvalid =>
      'Un documento richiede un titolo e un link https://.';

  @override
  String get documentsProviderLabel => 'Archiviato su';

  @override
  String get documentsRoleAdmin => 'Admin e proprietari';

  @override
  String get documentsRoleLabel => 'Visibile a';

  @override
  String get documentsRoleMember => 'Tutti i membri';

  @override
  String get documentsRoleOwner => 'Solo proprietari';

  @override
  String get documentsTitle => 'Documenti';

  @override
  String get documentsTitleLabel => 'Titolo';

  @override
  String get documentsUrlHelper =>
      'Incolla il link di condivisione del tuo drive — i permessi restano gestiti lì.';

  @override
  String get documentsUrlLabel => 'Link (https://…)';

  @override
  String get dunningAutomatic => 'Solleciti automatici';

  @override
  String get dunningAutomaticHint =>
      'Una volta al giorno, le fatture oltre la scadenza registrata passano da sole al livello di sollecito successivo — per l\'importo ancora dovuto, mai mentre un pagamento è in attesa o la fattura è sospesa. Le fatture senza scadenza registrata restano a te. Disattivato: invii tu ogni sollecito.';

  @override
  String get dunningBetweenDays => 'Giorni tra i solleciti';

  @override
  String dunningDueChip(int level) {
    return 'Sollecito $level da inviare';
  }

  @override
  String get dunningFirstAfterDays => 'Giorni fino al primo promemoria';

  @override
  String get dunningLevels => 'Numero di livelli di sollecito';

  @override
  String get dunningSaved => 'Regole di sollecito salvate.';

  @override
  String get dunningSettingsTitle => 'Regole di sollecito';

  @override
  String get eInvoiceGapBuyerLegalIdAdvisable =>
      'Manca il SIREN dell\'acquirente. Una piattaforma francese instrada in base ad esso: inseritelo nel profilo del membro prima di trasmettere. Non è un rifiuto — il file è valido senza.';

  @override
  String get eInvoiceGapMissingBuyerLegalId =>
      'L\'acquirente è un\'impresa francese senza SIREN — inserisci il suo identificativo legale nel profilo del socio.';

  @override
  String get eInvoiceGapMixedNotSubjectLines =>
      'Una riga non soggetta (cauzione) compare accanto a righe tassate — la norma EN 16931 rifiuta la combinazione; emetti la cauzione su un documento separato.';

  @override
  String get editorAccessoriesLabel => 'Accessori';

  @override
  String get editorAddLevel => 'Aggiungi piano';

  @override
  String get editorAmenitiesLabel => 'Dotazioni';

  @override
  String get editorBackgroundImage => 'Immagine di sfondo';

  @override
  String get editorBackgroundRemove => 'Rimuovi immagine di sfondo';

  @override
  String get editorBackgroundReplace => 'Sostituisci immagine di sfondo';

  @override
  String get editorBackgroundSet => 'Imposta immagine di sfondo';

  @override
  String get editorBlockedLabel => 'Bloccato (manutenzione)';

  @override
  String get editorBookableAsWhole => 'Prenotabile per intero';

  @override
  String get editorBookableAsWholeHint =>
      'Qualcuno può prenotarla per intero, con tutto quello che contiene.';

  @override
  String get editorCanvasSemantics => 'Area di disegno della pianta';

  @override
  String get editorChairLabel => 'Tipo di sedia';

  @override
  String get editorDeleteElementConfirm =>
      'Eliminare questo elemento? Anche tutto ciò che vi è posizionato sopra verrà rimosso.';

  @override
  String get editorDeleteElementConfirmAudit =>
      'Eliminare questo elemento? Anche tutto ciò che vi è collocato viene rimosso. Le prenotazioni che vi fanno riferimento conservano un\'istantanea di testo per gli audit; le prenotazioni aperte vengono annullate.';

  @override
  String get editorDeleteLevelConfirm =>
      'Eliminare questo piano? Tutti gli uffici, le scrivanie e i posti su di esso verranno rimossi.';

  @override
  String get editorDeleteLevelConfirmAudit =>
      'Eliminare questo piano? Tutti gli uffici, i tavoli e i posti su di esso vengono rimossi. Le prenotazioni che vi fanno riferimento conservano un\'istantanea di testo per gli audit; le prenotazioni aperte vengono annullate.';

  @override
  String get editorDeskFull => 'Non c’è più posto su questo tavolo.';

  @override
  String get editorDeskNameDefault => 'Scrivania';

  @override
  String get editorDeskNameLabel => 'Nome della scrivania';

  @override
  String get editorDeskProperties => 'Scrivania';

  @override
  String get editorDuplicate => 'Duplica';

  @override
  String get editorEmptyFloorAction => 'Disegna la prima stanza';

  @override
  String get editorEmptyFloorBody =>
      'Tutto sta dentro una stanza: disegnane una, mettici dei tavoli e poi i posti sui tavoli.';

  @override
  String get editorEmptyFloorTitle => 'Questo piano è vuoto';

  @override
  String get editorHintDesk =>
      'Trascina dentro una stanza per disegnare un tavolo';

  @override
  String get editorHintImage => 'Tocca dove va l\'immagine';

  @override
  String get editorHintOffice => 'Trascina per disegnare una stanza';

  @override
  String get editorHintSeat => 'Tocca un tavolo per aggiungere un posto';

  @override
  String get editorLevelActions => 'Azioni del piano';

  @override
  String get editorLevelBookableOff => 'Non prenotabile per intero';

  @override
  String get editorLevelBookableOn => 'Prenotabile per intero';

  @override
  String get editorLevelNameLabel => 'Nome del piano';

  @override
  String get editorMediaSaving => 'Salvataggio dell\'immagine…';

  @override
  String get editorMediaWriteFailed =>
      'Non è stato possibile confermare il salvataggio dell\'immagine. Riprovare non la aggiunge mai due volte.';

  @override
  String get editorNewOffice => 'Nuovo ufficio';

  @override
  String get editorNoAccessories =>
      'Ancora nessun accessorio — aggiungili in Impostazioni → Accessori.';

  @override
  String get editorNoAccessoriesAction => 'Nessun accessorio — configurali';

  @override
  String get editorNoLevels =>
      'Ancora nessun piano. Aggiungi il primo piano del tuo spazio.';

  @override
  String get editorOfficeNameDefault => 'Ufficio';

  @override
  String get editorOfficeNameLabel => 'Nome dell\'ufficio';

  @override
  String get editorOfficeProperties => 'Ufficio';

  @override
  String get editorOpenTooltip => 'Modifica spazio';

  @override
  String get editorOrientationHint =>
      'Da che parte guarda la sedia sulla pianta.';

  @override
  String get editorOrientationLabel => 'Direzione di seduta';

  @override
  String get editorPlacementOutside =>
      'Deve trovarsi completamente all\'interno di un ufficio.';

  @override
  String get editorPlacementOverlap => 'Si sovrappone a un elemento esistente.';

  @override
  String get editorProperties => 'Proprietà';

  @override
  String get editorRenameLevel => 'Rinomina';

  @override
  String get editorSeatNameDefault => 'Posto';

  @override
  String get editorSeatNameLabel => 'Nome del posto';

  @override
  String get editorSeatNfcDuplicate =>
      'Questo tag è già collegato a un\'altra sedia.';

  @override
  String get editorSeatNfcHelp =>
      'UID del tag in esadecimale — lasciare vuoto per nessun tag.';

  @override
  String get editorSeatNfcLabel => 'Tag NFC/RFID';

  @override
  String get editorSeatNfcRead => 'Leggi un tag ora';

  @override
  String get editorSeatNfcReadFailed =>
      'Impossibile avviare il lettore di tag.';

  @override
  String get editorSeatNoDesk =>
      'I posti possono essere collocati solo su una scrivania.';

  @override
  String get editorSeatProperties => 'Posto';

  @override
  String get editorTitle => 'Editor dello spazio';

  @override
  String get editorToolDesk => 'Scrivania';

  @override
  String get editorToolErase => 'Cancella';

  @override
  String get editorToolImage => 'Immagine';

  @override
  String get editorToolOffice => 'Ufficio';

  @override
  String get editorToolSeat => 'Posto';

  @override
  String get editorToolSelect => 'Seleziona';

  @override
  String get einvoiceConfigClear => 'Rimuovi la piattaforma';

  @override
  String get einvoiceConfigCleared => 'Piattaforma rimossa.';

  @override
  String get einvoiceConfigEndpoint => 'URL di caricamento';

  @override
  String get einvoiceConfigField =>
      'Nome del campo file (file per impostazione predefinita)';

  @override
  String get einvoiceConfigHeader =>
      'Header di autenticazione (Authorization per impostazione predefinita)';

  @override
  String get einvoiceConfigIntro =>
      'Dove DesKilo deposita le tue fatture. Va bene qualsiasi piattaforma che accetti un upload con un token — una piattaforma accreditata, un access point Peppol, una piattaforma nazionale. Il token resta sul server e non torna mai indietro.';

  @override
  String get einvoiceConfigSaved => 'Piattaforma salvata.';

  @override
  String get einvoiceConfigTitle => 'Piattaforma di fatturazione elettronica';

  @override
  String get einvoiceConfigToken => 'Token o credenziale';

  @override
  String get einvoiceConfigTokenSet =>
      'Un token è salvato (digitane uno nuovo per sostituirlo).';

  @override
  String get einvoiceConfigUnavailable =>
      'Impossibile caricare la configurazione della piattaforma. Controlla la connessione e riprova.';

  @override
  String get einvoiceCustomerSectionHelp =>
      'Dove vanno le fatture per il cliente: il suo punto di accesso Peppol, il portale o l’API concordata — separato dalla piattaforma governativa.';

  @override
  String get einvoiceCustomerSectionTitle => 'Servizio di recapito al cliente';

  @override
  String get einvoiceDevEndpoint => 'URL di caricamento Dev';

  @override
  String get einvoiceDevToken => 'Token o credenziale Dev';

  @override
  String get einvoiceEnvDev => 'Dev (piattaforma di prova)';

  @override
  String get einvoiceEnvProd => 'Produzione';

  @override
  String get einvoiceEnvProdHint => 'La trasmissione reale.';

  @override
  String get einvoiceEnvTestHint =>
      'Una prova — registrata come invio di test.';

  @override
  String get einvoiceEnvTitle => 'Inviare a quale piattaforma?';

  @override
  String get einvoiceEnvUat => 'UAT (piattaforma di prova)';

  @override
  String get einvoiceTestEnvsHelp =>
      'Endpoint e token separati per le prove. La scelta appare all’invio solo con la modalità sviluppatore attiva.';

  @override
  String get einvoiceTestEnvsTitle => 'Ambienti di prova (UAT / Dev)';

  @override
  String get einvoiceUatEndpoint => 'URL di caricamento UAT';

  @override
  String get einvoiceUatToken => 'Token o credenziale UAT';

  @override
  String get emblemChoose => 'Scegli un’immagine';

  @override
  String get emblemFailed =>
      'Non è stato possibile salvare l’emblema. Nulla è cambiato.';

  @override
  String get emblemHint =>
      'Una piccola immagine mostrata sotto il nome dell’app nel menu. Viene ridisegnata a un massimo di 512 pixel e salvata senza i metadati del file.';

  @override
  String get emblemNotAnImage => 'Quel file non è un’immagine.';

  @override
  String get emblemRemove => 'Rimuovi';

  @override
  String get emblemRemoved => 'Emblema rimosso.';

  @override
  String get emblemSaved => 'Emblema salvato.';

  @override
  String get emblemTitle => 'Emblema';

  @override
  String get emblemTooHeavy =>
      'Quell’immagine è troppo pesante per un segno mostrato a 28 pixel.';

  @override
  String get entitlementBlockedFull =>
      'Hai usato tutti i tuoi giorni questo mese. Chiedine altri a un amministratore o richiedi mezze giornate extra qui sotto.';

  @override
  String entitlementDaysLeft(String left) {
    return '$left giorni rimasti';
  }

  @override
  String entitlementDaysUsed(String used, String total) {
    return '$used di $total giorni usati';
  }

  @override
  String get entitlementPackageFull =>
      'Hai usato tutti i tuoi giorni questo mese. Acquista un pacchetto per continuare a prenotare.';

  @override
  String entitlementPaygRate(String rate) {
    return 'I giorni oltre il tuo piano costano $rate ciascuno.';
  }

  @override
  String get entitlementTitle => 'Questo mese';

  @override
  String get environmentDev => 'Sviluppo — per provare';

  @override
  String get environmentHint =>
      'Uno spazio di sviluppo lo dichiara su ogni schermata e filigrana ogni documento. Dichiaratelo di produzione solo quando le fatture che ne escono sono davvero dovute.';

  @override
  String get environmentLabel => 'Tipo di spazio';

  @override
  String get environmentPairsCreateTwin => 'Crea il suo gemello';

  @override
  String get environmentPairsCreateTwinDesc =>
      'Uno spazio di sviluppo e uno di produzione con lo stesso nome; la configurazione è copiata una volta.';

  @override
  String get environmentPairsPairedDev =>
      'Accoppiato al suo gemello di sviluppo';

  @override
  String get environmentPairsPairedProd =>
      'Accoppiato al suo gemello di produzione';

  @override
  String get environmentPairsTwinCreated => 'Il gemello è creato.';

  @override
  String get environmentProd => 'Produzione — le fatture sono dovute';

  @override
  String get environmentProdConfirmAction => 'Dichiarare di produzione';

  @override
  String get environmentProdConfirmBody =>
      'Il banner sparisce e i documenti perdono la filigrana. Le fatture già emesse non cambiano: mantengono la filigrana che portavano al momento dell’emissione.';

  @override
  String get environmentProdConfirmTitle =>
      'Dichiarare questo spazio di produzione?';

  @override
  String get environmentSaved => 'Tipo di spazio salvato.';

  @override
  String get erasurePreviewKept => 'Conservato, e perché';

  @override
  String get erasurePreviewOutside => 'Fuori da questa installazione';

  @override
  String get erasurePreviewRemoved => 'Cancellato';

  @override
  String get erasurePreviewTitle => 'Cosa fa qui la cancellazione';

  @override
  String get erasureStoreAccounts =>
      'Fatture e registro — prova contabile, conservata per il periodo di legge; i documenti emessi non vengono riscritti';

  @override
  String get erasureStoreAnswers => 'Le tue risposte alle domande dello spazio';

  @override
  String get erasureStoreBackups =>
      'Backup del gestore — scadono secondo la loro rotazione';

  @override
  String get erasureStoreDeviceCaches =>
      'Copie sui tuoi dispositivi — cancellate quando esci da ciascuno';

  @override
  String get erasureStoreHeldAnswers =>
      'Risposte soggette a un obbligo di conservazione documentato dallo spazio';

  @override
  String get erasureStoreMembership =>
      'La riga di iscrizione — collega i dati conservati; pseudonima, non anonima';

  @override
  String get erasureStoreMessages => 'Messaggi che hai inviato';

  @override
  String get erasureStoreOpenBookings => 'Prenotazioni aperte — annullate';

  @override
  String get erasureStoreOtherInstallations =>
      'Un\'altra installazione DesKilo è un titolare distinto — rivolgiti direttamente a lei';

  @override
  String get erasureStorePastBookings =>
      'Prenotazioni passate — lo storico di occupazione dello spazio';

  @override
  String get erasureStoreProfile =>
      'Il tuo profilo (se è il tuo ultimo spazio)';

  @override
  String get errorOffline =>
      'Nessuna connessione: non è stato inviato nulla. Riprova quando sei di nuovo online.';

  @override
  String get eventAccept => 'Accetta';

  @override
  String get eventAutoValidated => 'Convalidato automaticamente';

  @override
  String eventExpenseDeviation(Object reason, Object scheduled) {
    return 'validato $scheduled — $reason';
  }

  @override
  String eventExpenseRepartitionLine(
    String actor,
    String title,
    String amount,
    int count,
  ) {
    return '$actor ripartisce «$title»: $amount tra $count membri';
  }

  @override
  String eventExpenseScheduleLine(Object actor, Object amount, Object title) {
    return '$actor programma «$title» — $amount ricorrente';
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
  String eventInvoicePaid(String number, String amount) {
    return 'Fattura $number pagata — $amount';
  }

  @override
  String eventInvoiceReminderLine(String number, int level, String amount) {
    return 'Sollecito $level: fattura $number — $amount ancora dovuti';
  }

  @override
  String eventInvoiceWriteoffLine(String actor, String number, String amount) {
    return '$actor chiede di annullare il saldo di $number — $amount';
  }

  @override
  String eventPaymentSubmitted(String actor, String amount) {
    return '$actor ha registrato un pagamento di $amount';
  }

  @override
  String eventPaymentTermsChangeLine(String actor, String terms) {
    return '$actor chiede di fissare le condizioni di pagamento: $terms';
  }

  @override
  String eventPriceNegotiationItems(int count) {
    return '$count articoli';
  }

  @override
  String eventPriceNegotiationLine(String actor, String member, String terms) {
    return '$actor propone condizioni per $member: $terms';
  }

  @override
  String eventQuotaRequested(String actor, int halfDays, String period) {
    return '$actor richiede $halfDays mezze giornate extra per $period';
  }

  @override
  String get eventReject => 'Rifiuta';

  @override
  String eventRejectedBy(String name, String when) {
    return 'Rifiutato da $name · $when';
  }

  @override
  String eventReservationCancelled(String actor, String target) {
    return '$actor ha annullato la prenotazione di $target';
  }

  @override
  String eventReservationCreated(String actor, String target) {
    return '$actor ha prenotato $target';
  }

  @override
  String get eventReservationDeleteCheckedIn => 'con check-in';

  @override
  String eventReservationDeleteLine(String actor, String date, String state) {
    return '$actor chiede di eliminare la prenotazione del $date ($state)';
  }

  @override
  String get eventReservationDeleteUnused => 'mai usata';

  @override
  String eventReservationModified(String actor, String target) {
    return '$actor ha modificato la prenotazione di $target';
  }

  @override
  String eventRoleDemote(String actor) {
    return '$actor chiede di revocare il ruolo Amministratore';
  }

  @override
  String eventRoleGiven(String actor, String role, String member) {
    return '$actor dà il ruolo $role a $member';
  }

  @override
  String eventRolePromote(String actor) {
    return '$actor chiede di dare il ruolo Amministratore';
  }

  @override
  String eventRoleTakenBack(String actor, String role, String member) {
    return '$actor revoca il ruolo $role a $member';
  }

  @override
  String eventServiceChargeTitle(String name, int quantity, String amount) {
    return '$name ×$quantity — $amount';
  }

  @override
  String get eventSystemDecider => 'Sistema';

  @override
  String get eventTypeAdjustment => 'Rettifica';

  @override
  String get eventTypeExpense => 'Spesa';

  @override
  String get eventTypeExpenseRepartition => 'Spesa condivisa';

  @override
  String get eventTypeExpenseSchedule => 'Spesa programmata';

  @override
  String get eventTypeInvoiceIssue => 'Emissione fattura';

  @override
  String get eventTypeInvoicePayment => 'Pagamento fattura';

  @override
  String get eventTypeInvoiceReminder => 'Promemoria di pagamento';

  @override
  String get eventTypeInvoiceVoid => 'Annullamento fattura';

  @override
  String get eventTypeInvoiceWriteoff => 'Annullamento del saldo';

  @override
  String get eventTypeMatrixChange => 'Modifica della matrice dei permessi';

  @override
  String get eventTypeMemberJoin => 'Nuovo membro';

  @override
  String get eventTypeMemberStatusChange => 'Cambio di adesione';

  @override
  String get eventTypePayment => 'Pagamento';

  @override
  String get eventTypePaymentTermsChange => 'Condizioni di pagamento';

  @override
  String get eventTypePriceNegotiation => 'Negoziazione di prezzo';

  @override
  String get eventTypeQuota => 'Mezze giornate extra';

  @override
  String get eventTypeRefund => 'Rimborso';

  @override
  String get eventTypeReservation => 'Prenotazione';

  @override
  String get eventTypeReservationDelete => 'Eliminazione prenotazione';

  @override
  String get eventTypeRoleChange => 'Cambio di ruolo';

  @override
  String get eventTypeServiceCharge => 'Servizio';

  @override
  String get eventTypeSpaceReservation => 'Prenotazioni di spazi interi';

  @override
  String get eventTypeSubscriptionChange => 'Cambio di abbonamento';

  @override
  String get eventTypeUnknown => 'Attività';

  @override
  String get eventTypeUsageCorrection => 'Uscita anticipata';

  @override
  String get eventTypeUsageRecordDelete => 'Rimozione del rilevamento';

  @override
  String eventUsageCorrectionLine(String actor, String from, String to) {
    return '$actor chiede di essere fatturato $to invece di $from';
  }

  @override
  String eventUsageRecordDeleteLine(String actor, String space) {
    return '$actor chiede di rimuovere un rilevamento ($space)';
  }

  @override
  String eventValidatedBy(String name, String when) {
    return 'Convalidato da $name · $when';
  }

  @override
  String eventValidationStage(int stage, int required) {
    return 'Convalida $stage su $required richiesta';
  }

  @override
  String eventValidations(int current, int required) {
    return '$current/$required convalide';
  }

  @override
  String get eventsEmpty => 'Ancora nessun evento.';

  @override
  String get eventsFilterAll => 'Tutti';

  @override
  String get eventsMessagesHeader => 'Messaggi';

  @override
  String get eventsPendingHeader => 'In attesa della tua conferma';

  @override
  String get expenseCategoryCoffee => 'Caffè e cucina';

  @override
  String get expenseCategoryEquipment => 'Attrezzatura';

  @override
  String get expenseCategoryOther => 'Altro';

  @override
  String get expenseCategorySupplies => 'Materiale';

  @override
  String get expenseInvalidAmount => 'Inserisci un importo maggiore di zero.';

  @override
  String get expenseInvalidSupplyQuantity => 'Inserisci almeno un\'unità.';

  @override
  String get expenseInvalidUnitPrice =>
      'Inserisci un prezzo unitario valido o lascialo vuoto.';

  @override
  String get expenseMissingSupplyName => 'Dai un nome al nuovo articolo.';

  @override
  String get expenseSupplyHint =>
      'Capsule di caffè, sacchetti per aspirapolvere… Una volta convalidato, l\'articolo va sullo scaffale come servizio consumabile: chi lo usa lo paga.';

  @override
  String get expenseSupplyItem => 'Articolo';

  @override
  String get expenseSupplyNewItem => 'Nuovo articolo';

  @override
  String get expenseSupplyQuantity => 'Quantità';

  @override
  String get expenseSupplyToggle => 'È una scorta per lo spazio';

  @override
  String get expenseSupplyUnitPrice =>
      'Prezzo unitario (quanto costa un consumo)';

  @override
  String get expenseSupplyUnitPriceHint =>
      'Precompilato con importo ÷ quantità; arrotonda se vuoi.';

  @override
  String get exportClaimExchange =>
      'Perché il tuo commercialista lo importi e lo verifichi — non è una dichiarazione.';

  @override
  String get exportClaimRegulatory =>
      'Il formato richiesto dalla tua amministrazione fiscale.';

  @override
  String get exportClaimSubset =>
      'Solo fatture e pagamenti, senza libro mastro. Il file lo dichiara nella propria intestazione.';

  @override
  String get exportUncertifiedSoftware =>
      'Prodotto secondo la specifica pubblicata, ma DesKilo non è software certificato in questo paese — verifica con il tuo commercialista se ti è richiesto.';

  @override
  String get featureAccessorySupplements => 'Supplementi accessori';

  @override
  String get featureAccessorySupplementsDesc =>
      'Fattura gli accessori del posto con prezzo per mezza giornata prenotata. Vale per le prenotazioni dall\'attivazione in poi.';

  @override
  String get featureAccountingBookDesc =>
      'Chi tiene i libri ufficiali di ogni emittente: Deskilo come precontabilità, un libro locale o un sistema contabile esterno che fa fede. Ogni emittente indica valuta, esercizio e base contabile. Disattivato: i saldi dei membri e le fatture funzionano come prima.';

  @override
  String get featureAccountingBookTitle => 'Libro contabile';

  @override
  String get featureAdminInvoicing => 'Gli admin emettono fatture';

  @override
  String get featureAdminInvoicingDesc =>
      'Anche gli admin emettono fatture. Il proprietario può sempre.';

  @override
  String get featureAdminLevelAssign => 'Gli admin possono assegnare piani';

  @override
  String get featureAdminLevelAssignDesc =>
      'Gli admin assegnano prenotazioni di piano ai membri. Il proprietario può sempre.';

  @override
  String get featureAdminSeatBlocking => 'Gli admin possono bloccare i posti';

  @override
  String get featureAdminSeatBlockingDesc =>
      'Gli admin contrassegnano i posti come non prenotabili per manutenzione. Il proprietario può sempre.';

  @override
  String featureAlsoEnabled(String features) {
    return 'Attivato anche: $features';
  }

  @override
  String featureAlsoEnables(String features) {
    return 'Attivando questa si abilita anche $features';
  }

  @override
  String get featureAutoCheckInOut => 'Check-in/out automatico a fine giornata';

  @override
  String get featureAutoCheckInOutDesc =>
      'Le prenotazioni senza check-in o check-out si completano da sole una volta trascorso il loro orario.';

  @override
  String get featureBadgeSignInDesc =>
      'I membri possono accedere scansionando il proprio badge e inserendo il PIN, invece di digitare un\'e-mail su un tablet condiviso. Ogni membro imposta il proprio PIN e attiva il proprio badge.';

  @override
  String get featureBadgeSignInTitle => 'Accesso con badge';

  @override
  String get featureBookForOthers => 'Prenota per altri';

  @override
  String get featureBookForOthersDesc =>
      'Admin e proprietari prenotano posti per altri membri.';

  @override
  String get featureBookingGateDesc =>
      'Ogni superficie di prenotazione — piano, viste giorno, settimana e mese, foglio di prenotazione, chiosco, scansione QR o NFC — verifica i parametri di disponibilità prima di offrire una fascia e nomina il motivo quando non può; i giorni chiusi si mostrano chiusi in ogni vista, una legenda nomina gli stati dei posti, e gli admin possono fare il check-out di un membro dove la regola lo consente.';

  @override
  String get featureBookingGateTitle => 'Controllo prenotazione';

  @override
  String get featureBookingPoliciesDesc =>
      'Comportamento di prenotazione configurabile: prenotazioni passate, prenotazioni al minuto fuori orario e check-out da parte degli amministratori.';

  @override
  String get featureBookingPoliciesTitle => 'Regole di prenotazione';

  @override
  String get featureCalendarFileExportDesc =>
      'Permette a un membro di salvare una delle proprie prenotazioni come file calendario standard (.ics) per il calendario che già usa. Il file contiene solo l’orario, lo spazio prenotato e il nome dello spazio di coworking — nessun importo, nessun nome, nessuna nota, nessun link — ed è un’istantanea: una modifica successiva della prenotazione non aggiorna un file già salvato. Non viene scritto nulla in alcun calendario e nulla si sincronizza. Disattivata, nasconde il pulsante.';

  @override
  String get featureCalendarFileExportTitle =>
      'File calendario di una prenotazione';

  @override
  String get featureCalendarHubDesc =>
      'Il calendario mostra tutto ciò che ha una data — prenotazioni, check-in, avvisi, messaggi, fatture, pagamenti, consumi, promemoria — per un giorno o un periodo, ogni riga apre la sua origine. Disattivato: solo prenotazioni.';

  @override
  String get featureCalendarHubTitle => 'Calendario centrale';

  @override
  String get featureCalendarTab => 'Scheda Calendario';

  @override
  String get featureCalendarTabDesc =>
      'Panoramica mensile di prenotazioni e giorni di chiusura.';

  @override
  String get featureCalendarValidationsDesc =>
      'Ogni decisione presa su un evento compare nel calendario nel momento in cui è stata presa, non in quello dell’evento: chi ha convalidato o rifiutato che cosa, e quando. Toccandola si apre la cronologia. Disattivato: il calendario non porta decisioni.';

  @override
  String get featureCalendarValidationsTitle => 'Convalide nel calendario';

  @override
  String get featureCalendarViewsDesc =>
      'La scheda Calendario come agenda, settimana e mese: indicatori per giorno secondo il tipo, giorni chiusi mostrati chiusi, intestazioni Oggi / Domani, scadenze di pagamento e spese programmate nel feed. Disattivato: il semplice selettore giorno o intervallo sopra il feed.';

  @override
  String get featureCalendarViewsTitle => 'Viste del calendario';

  @override
  String get featureCapacityKpiDesc =>
      'Mostra ai proprietari e a chi gestisce le prenotazioni quanta parte del tempo di posto offerto è stata prenotata in un mese, come viene calcolata e cosa la cifra non può sapere.';

  @override
  String get featureCapacityKpiTitle => 'Occupazione dei posti';

  @override
  String get featureCaptureProtectionDesc =>
      'Le schermate dei messaggi rifiutano screenshot e registrazioni dello schermo quando il dispositivo lo consente, nascondono il contenuto durante una registrazione e annunciano uno screenshot nella conversazione quando può solo essere rilevato. Un browser non può bloccare gli screenshot; lì la conversazione viene sfocata quando la scheda perde il focus.';

  @override
  String get featureCaptureProtectionTitle =>
      'Protezione dalle catture dello schermo';

  @override
  String get featureCarnetsDesc =>
      'Vendere carnet di mezze giornate, consumati nell\'arco dei mesi quando un membro prenota oltre il suo abbonamento, addebitati una sola volta alla vendita.';

  @override
  String get featureCarnetsTitle => 'Carnet';

  @override
  String get featureCoOwner => 'Comproprietari';

  @override
  String get featureCoOwnerDesc =>
      'Nominare comproprietari: permessi da proprietario subito (attivo) o successione in attesa (passivo).';

  @override
  String get featureConfigurationTransfer =>
      'Configurazione nel file dello spazio';

  @override
  String get featureConfigurationTransferDesc =>
      'Il file dello spazio (XML) porta l\'intera configurazione — tariffe, identità legale, regole di prenotazione e convalida, ruoli, layout dei documenti, sedi, giorni di chiusura — e l\'importazione la applica, anche su uno spazio che ha già prenotazioni. Disattivato: il file porta solo impostazioni e planimetria.';

  @override
  String get featureCustomFieldsDesc =>
      'Lo spazio può porre le proprie domande dentro il modulo d\'identità: un incarico nel direttivo, una data di adesione, un contatto d\'emergenza. Le risposte appartengono all\'iscrizione, quindi una domanda posta qui non segue nessuno altrove.';

  @override
  String get featureCustomFieldsTitle => 'Le domande di questo spazio';

  @override
  String get featureCustomRolesDesc =>
      'Lo spazio può definire ruoli propri — un tesoriere, un segretario — che aggiungono permessi a quelli del ruolo di un membro. Non ne tolgono mai, e un proprietario li mantiene tutti.';

  @override
  String get featureCustomRolesTitle => 'Ruoli definiti da questo spazio';

  @override
  String get featureDataAccessLogDesc =>
      'Ogni membro vede chi ha consultato le sue finanze e quando (scritto dal server, mai aggirabile). Disattivato: la riga è nascosta, il registro resta.';

  @override
  String get featureDataAccessLogTitle => 'Registro degli accessi ai dati';

  @override
  String get featureDataExport => 'Esportazione dati (Excel)';

  @override
  String get featureDataExportDesc =>
      'Scaricare tutti i dati dello spazio in una cartella Excel.';

  @override
  String get featureDecisionSurfaceDesc =>
      'Un solo posto che risponde a «c’è qualcosa che mi aspetta?», ordinato per quanto costa il ritardo: prima il denaro che se ne va, poi qualcuno che aspetta una risposta. Una riga appare solo se una persona deve decidere o agire; un numero su cui nessuno può agire resta sullo schermo che lo possiede.';

  @override
  String get featureDecisionSurfaceTitle => 'Cosa ti aspetta';

  @override
  String get featureDeletionRequests =>
      'Richieste di eliminazione prenotazioni';

  @override
  String get featureDeletionRequestsDesc =>
      'I membri possono RICHIEDERE l\'eliminazione di una prenotazione passata o con check-in; un proprietario/admin convalida. Disattivato, tali prenotazioni non sono eliminabili.';

  @override
  String get featureDemoMode => 'Lo spazio dimostrativo';

  @override
  String get featureDemoModeDesc =>
      'Uno spazio inventato che chiunque può aprire dalla schermata di accesso, con le proprie persone, prenotazioni e fatture. Nulla di ciò che vi si fa raggiunge uno spazio reale o lascia il dispositivo, e non serve alcun account. Spento: la proposta non compare.';

  @override
  String get featureDeployments => 'Distribuzioni';

  @override
  String get featureDeploymentsDesc =>
      'Configurazione e dati anagrafici distribuiti tra i due lati di una coppia, entità per entità, con un\'anteprima di ciò che cambia e un giornale che sa tornare indietro. Disattivato: i gemelli si regolano a mano, ciascuno per sé.';

  @override
  String get featureDetailChange => 'Modificala tra gli interruttori';

  @override
  String featureDetailGrantsPermission(String permission) {
    return 'Concede agli amministratori il permesso «$permission».';
  }

  @override
  String featureDetailHeldBack(String feature) {
    return 'Attivata, ma bloccata: richiede $feature, che è disattivata.';
  }

  @override
  String get featureDetailKey => 'Chiave tecnica';

  @override
  String get featureDetailNone => 'Niente.';

  @override
  String get featureDetailOff => 'Disattivata.';

  @override
  String get featureDetailOn => 'Attivata.';

  @override
  String featureDetailOnNeededBy(String names) {
    return 'Attivata e necessaria per $names.';
  }

  @override
  String get featureDetailProvides => 'Offre';

  @override
  String get featureDetailRequires => 'Richiede';

  @override
  String get featureDetailTechnical => 'Dettagli tecnici';

  @override
  String get featureDetailUsedBy => 'Usata da';

  @override
  String get featureDocuments => 'Biblioteca documenti';

  @override
  String get featureDocumentsDesc =>
      'La biblioteca documenti dello spazio: statuto, guide, bilanci, verbali — collegati da qualsiasi drive, visibili per ruolo.';

  @override
  String get featureDunning => 'Solleciti di pagamento';

  @override
  String get featureDunningDesc =>
      'Livelli e scadenze di sollecito configurabili, una lettera per livello e avvisi «Sollecito dovuto» sulle fatture in ritardo. L\'invio resta manuale, salvo con i Solleciti di pagamento automatici.';

  @override
  String get featureEinvoiceCustomerDeliveryDesc =>
      'Un secondo canale di invio accanto alla piattaforma governativa: trasmettere la fattura emessa direttamente al servizio di fatturazione del cliente.';

  @override
  String get featureEinvoiceCustomerDeliveryTitle =>
      'Recapito delle fatture al cliente';

  @override
  String get featureEnvironmentPairs => 'Coppie di ambienti';

  @override
  String get featureEnvironmentPairsDesc =>
      'Uno spazio e il suo gemello — il lato sviluppo e il lato produzione — come una coppia: una scheda in Profili con un interruttore, e il gemello creato su richiesta con la configurazione copiata. Disattivato: due voci senza legame.';

  @override
  String get featureEventsTab => 'Scheda Eventi';

  @override
  String get featureEventsTabDesc =>
      'Cronologia delle attività e conferme in sospeso.';

  @override
  String get featureExpenseRepartitionDesc =>
      'Una spesa comune (pulizie, potenziamento internet, una sedia rotta) ripartita tra i membri — quote uguali, in proporzione all\'abbonamento, in proporzione all\'utilizzo o una chiave per membro — con ogni quota in anteprima prima della registrazione. Le quote diventano righe della prossima fattura di utilizzo; uno storno genera note di credito. Passa dalle regole di convalida. Disattivato: nessuna ripartizione.';

  @override
  String get featureExpenseRepartitionTitle => 'Spese condivise';

  @override
  String get featureExpenseRepartitionWizard => 'Assistente di ripartizione';

  @override
  String get featureExpenseRepartitionWizardDesc =>
      'Una ripartizione guidata: una spesa comune proposta in base alla percentuale di abbonamento, ogni quota modificabile, e la regola modificata ricordata per il mese successivo. Disattivato: solo la scheda di ripartizione di una spesa.';

  @override
  String get featureFinanceFacesDesc =>
      'La scheda Finanze si legge in quattro viste — Estratto, Pagamenti, Fatture, Documenti — sotto un unico selettore di mese, ognuna con la sua guida. Disattivato: una sola colonna.';

  @override
  String get featureFinanceFacesTitle => 'Finanze in quattro viste';

  @override
  String get featureFormHelpHintsDesc =>
      'Un carosello di suggerimenti richiudibile su ogni schermata principale, e un piccolo ? accanto a ogni parametro e campo — un tocco apre la guida alla sezione giusta. Ripristinabile dalle impostazioni.';

  @override
  String get featureFormHelpHintsTitle => 'Suggerimenti di aiuto';

  @override
  String get featureHeldBack =>
      'In attesa della funzione qui sopra: attivala e anche questa torna a funzionare.';

  @override
  String get featureHolidayImportDesc =>
      'Un proprietario importa i giorni festivi del paese, e di una regione, da una fonte di dati aperti, deseleziona i giorni in cui lo spazio resta aperto e importa gli altri come giorni di chiusura. I mesi già fatturati vengono saltati e indicati.';

  @override
  String get featureHolidayImportTitle => 'Importa i giorni festivi';

  @override
  String get featureInstanceWizard => 'Assistente istanza';

  @override
  String get featureInstanceWizardDesc =>
      'Nella schermata Server, un assistente crea un nuovo progetto Supabase, installa lo schema dell\'app, distribuisce le sue funzioni e punta questo dispositivo su di esso — un token di accesso, nessun terminale. Disattivato: solo i passi manuali.';

  @override
  String get featureIntakeStoppedNote =>
      'Disattivato: non inizia nulla di nuovo; ciò che è già aperto può ancora essere gestito e chiuso.';

  @override
  String get featureInvoiceAddressWindow => 'Finestra indirizzo';

  @override
  String get featureInvoiceAddressWindowDesc =>
      'Colloca il destinatario dove lo mostra una busta a finestra, così una fattura stampata può essere piegata e spedita. Il lato segue il paese ed è modificabile.';

  @override
  String get featureInvoiceJourneyDesc =>
      'Ogni fattura mostra dove si trova — Emessa, Pagamento, Conferma, Chiusa — e a chi tocca: il membro paga, un admin conferma il pagamento dichiarato, l\'emittente lo abbina, i validatori decidono. L\'hub degli emittenti aggiunge una barra delle fasi con i contatori e una spiegazione «Come funziona».';

  @override
  String get featureInvoiceJourneyTitle => 'Il percorso di una fattura';

  @override
  String get featureInvoicePdfTemplate => 'Modello PDF della fattura';

  @override
  String get featureInvoicePdfTemplateDesc =>
      'Introduzione e piè di pagina scritti dal proprietario sul PDF della fattura. Non tocca mai l\'XML della fattura elettronica.';

  @override
  String get featureInvoiceSettlementDesc =>
      'Più fatture aperte di un membro possono essere raggruppate in una sola da pagare. Le originali restano nell\'archivio, tracciabili voce per voce, e non vengono più sollecitate separatamente.';

  @override
  String get featureInvoiceSettlementTitle => 'Raggruppa le fatture';

  @override
  String get featureInvoicing => 'Fatture';

  @override
  String get featureInvoicingDesc =>
      'Fatture immutabili e firmate in un archivio — scarica o condividi in PDF.';

  @override
  String get featureInvoicingWizardDesc =>
      'Un processo guidato di chiusura mensile per chi cura le finanze: un giro di inizio mese per gli abbonamenti pagati in anticipo e uno di fine mese per consumi e costi aggiuntivi — revisione, emissione in blocco, invio, solleciti dovuti, registrazione e convalida dei pagamenti, abbinamento alle fatture, raggruppamento, stralcio o rimborso, e un riepilogo con ciò che resta aperto e a chi tocca. Disattivato: le schermate separate.';

  @override
  String get featureInvoicingWizardTitle => 'Assistente di fatturazione';

  @override
  String get featureKioskMemberPhotosDesc =>
      'La ricevuta del chiosco mostra la foto del profilo del membro — il controllo visivo del badge sbagliato.';

  @override
  String get featureKioskMemberPhotosTitle => 'Foto dei membri al chiosco';

  @override
  String get featureKioskMode => 'Modalità chiosco';

  @override
  String get featureKioskModeDesc =>
      'Account tablet a parete bloccati sulla piantina live; i membri agiscono col badge.';

  @override
  String get featureLess => 'Meno';

  @override
  String get featureLetterStandard => 'Standard lettera per ogni documento';

  @override
  String get featureLetterStandardDesc =>
      'Fatture, proforma, estratti, accordi, report di pagamenti e consumi e solleciti senza layout si stampano come lettera standard: intestazione, destinatario nella finestra della busta, corpo da 90 mm, piè di pagina fisso.';

  @override
  String get featureLevelBooking => 'Prenotazioni di tavolo, ufficio e piano';

  @override
  String get featureLevelBookingDesc =>
      'Prenota un intero tavolo, ufficio o piano come un\'unica prenotazione, con prezzo per mezza giornata. Concedi il diritto per membro.';

  @override
  String get featureLifecycleActive => 'Attiva';

  @override
  String get featureLifecycleDeprecated => 'Deprecata';

  @override
  String get featureLifecycleRetired => 'Ritirata';

  @override
  String get featureManagedProfileAccess => 'Chi amministra un profilo';

  @override
  String get featureManagedProfileAccessDesc =>
      'Ogni profilo gestito indica chi può amministrarlo — per ruolo, per persone indicate, o entrambi. Disattivato: ogni proprietario e ogni admin può, come prima. L\'identità è protetta in entrambi i casi, e ogni consultazione è registrata per la persona che riprenderà il profilo.';

  @override
  String get featureManagedProfiles => 'Profili gestiti';

  @override
  String get featureManagedProfilesDesc =>
      'Gli admin creano membri senza account, prenotano e fatturano per loro e consegnano il profilo con un codice personale che la persona riscatta quando entra.';

  @override
  String get featureMaturityAlpha => 'Alfa';

  @override
  String get featureMaturityBeta => 'Beta';

  @override
  String get featureMaturityFilterAll => 'Tutte le fasi';

  @override
  String get featureMaturityFilterLabel => 'Maturità';

  @override
  String featureMaturitySemantics(String maturity, String lifecycle) {
    return 'Maturità $maturity, $lifecycle';
  }

  @override
  String get featureMaturityStable => 'Stabile';

  @override
  String get featureMaturityUnreviewed => 'Non valutata';

  @override
  String get featureMcpAccessDesc =>
      'Rende disponibile l’interfaccia MCP per questo spazio, così che un assistente IA possa essere collegato a DesKilo. Solo disponibilità: attivarla non concede nulla a nessuno. Ogni persona ha ancora bisogno di un’autorizzazione che il proprietario configura e l’amministratore dell’istanza approva, e ogni operazione continua a rispondere ai permessi e alle regole che l’app già applica. Disattivata, nasconde i punti di ingresso MCP e rifiuta le chiamate; le autorizzazioni esistenti restano visibili e revocabili.';

  @override
  String get featureMcpAccessTitle => 'Interfaccia MCP';

  @override
  String get featureMemberAccountMenuDesc =>
      'Un membro che non amministra nulla incontra Il mio account invece di Impostazioni — la stessa schermata, che già gli mostra solo il suo account, la sua adesione e le sue preferenze, con il nome che lo dice. Chi ha un ruolo che concede amministrazione conserva Impostazioni e tutto ciò che apre. Questo rinomina una voce; non concede e non toglie nulla.';

  @override
  String get featureMemberAccountMenuTitle => 'I membri vedono Il mio account';

  @override
  String get featureMemberDataExportDesc =>
      'Ogni membro può esportare i propri dati in un file (GDPR art. 20) e lasciare lo spazio con i dati personali cancellati (art. 17) da Impostazioni → Privacy e dati.';

  @override
  String get featureMemberDataExportTitle => 'Esportazione e cancellazione';

  @override
  String get featureMemberEnvironmentsDesc =>
      'Quando invitate qualcuno, scegliete se raggiunge anche lo spazio di produzione. Entra comunque nello spazio di prova, e il ruolo deve comunque permettere l\'accesso alla produzione.';

  @override
  String get featureMemberEnvironmentsTitle =>
      'Scegliere gli ambienti su cui una persona è attivata';

  @override
  String get featureMemberGettingStartedDesc =>
      'Dopo essersi unito a uno spazio o averlo creato, un membro vede una scheda compatta nell’hub Prenota: in quale spazio si trova e un passo successivo suggerito — scegliere un orario da prenotare, vedere la propria iscrizione o aprire l’aiuto — solo dove le funzioni e i suoi permessi lo consentono. Non ora la nasconde; le Impostazioni possono mostrarla di nuovo. Non prenota, non paga e non approva mai nulla. Per chi configura lo spazio, le impostazioni mostrano anche, sezione per sezione, cosa manca a una prima prenotazione. Disattivata, nasconde la scheda e quell’elenco e non cambia altro.';

  @override
  String get featureMemberGettingStartedTitle => 'Scheda Primi passi';

  @override
  String get featureMemberNotifications => 'Notifiche tra membri';

  @override
  String get featureMemberNotificationsDesc =>
      'Messaggistica tra membri: conversazioni private e di gruppo, conferme di lettura, link a una prenotazione o a uno spazio; gli admin possono notificare tutti gli admin, proprietario incluso.';

  @override
  String get featureMemberOriginDesc =>
      'Una riga discreta su un membro che dice come è iniziata la sua adesione: ha fondato lo spazio, si è unito su invito, o un amministratore gli ha creato il profilo. Non è uno stato.';

  @override
  String get featureMemberOriginTitle => 'Come è arrivato ogni membro';

  @override
  String get featureMemberPageDesc =>
      'Una pagina per membro: foto e presenza, ultimo accesso, prenotazioni in corso e prossime, azioni rapide (messaggio, WhatsApp, e-mail), schede contatto e finanze e, per gli admin, ogni impostazione raggruppata per tema con il valore attuale. Disattivato: il foglio profilo e il foglio azioni di Membri e piani.';

  @override
  String get featureMemberPageTitle => 'Scheda membro';

  @override
  String get featureMemberPaymentTerms => 'Condizioni di pagamento per membro';

  @override
  String get featureMemberPaymentTermsDesc =>
      'Lo spazio definisce le condizioni di pagamento predefinite; un membro può avere le proprie, visibili a lui, modificate solo tramite una richiesta convalidata di un admin autorizzato.';

  @override
  String get featureMemberReports => 'Report dei membri';

  @override
  String get featureMemberReportsDesc =>
      'L\'accordo finanziario e il report mensile dei pagamenti — self-service per i membri, inviabili per membro.';

  @override
  String get featureMembersDirectory => 'Elenco dei membri';

  @override
  String get featureMembersDirectoryDesc =>
      'La scheda comunità: chi c\'è, stati, presenza.';

  @override
  String get featureMessageForwardingDesc =>
      'Un messaggio può essere inoltrato in un’altra conversazione a cui partecipa chi lo inoltra. La copia indica la provenienza e l’autore, la conversazione originale viene informata di chi l’ha inoltrato e dove, e un autore può bloccare l’inoltro di un messaggio. Disattivato, nessun inoltro esce da questo spazio.';

  @override
  String get featureMessageForwardingTitle => 'Inoltro dei messaggi';

  @override
  String get featureMessageGesturesDesc =>
      'Scorri un messaggio verso destra per citarlo nella risposta; verso sinistra per ritirare il tuo messaggio finché nessuno l\'ha letto, previa conferma. Disattivato: i messaggi si eliminano tenendoli premuti.';

  @override
  String get featureMessageGesturesTitle => 'Scorri per citare o ritirare';

  @override
  String get featureMessagesHubDesc =>
      'Una sola barra della posta (Tutti / Non letti / Archiviati e ricerca), fissare, silenziare, archiviare e segnare come non letto un thread, la conversazione a pagina intera con separatori di data, un menu allega e una bozza conservata nel compositore, una persona aperta con un tocco. Disattivato: la posta a due barre e il thread in foglio.';

  @override
  String get featureMessagesHubTitle => 'Messaggi, rinnovati';

  @override
  String get featureMoneyTab => 'Scheda Finanze';

  @override
  String get featureMoneyTabDesc => 'Fatture mensili, pagamenti e spese.';

  @override
  String get featureMore => 'Altro';

  @override
  String get featureMultiSite => 'Sedi';

  @override
  String get featureMultiSiteDesc =>
      'Più indirizzi: i piani sono raggruppati per sede, ogni sede ha il proprio indirizzo e la propria registrazione, ogni socio una sede di riferimento, e i documenti indicano la sede interessata. Disattivato: un solo indirizzo per tutto lo spazio.';

  @override
  String get featureNavigationStyle => 'Scelta della navigazione';

  @override
  String get featureNavigationStyleDesc =>
      'Ogni membro sceglie nelle impostazioni come naviga l\'app: la barra inferiore classica con il pulsante rotondo Prenota, o il menu come sul web. Disattivato: ogni dispositivo mantiene il valore predefinito della sua piattaforma.';

  @override
  String get featureNfcBadges => 'Badge RFID / NFC';

  @override
  String get featureNfcBadgesDesc =>
      'I membri fanno check-in a un chiosco avvicinando una tessera RFID/NFC. Richiede un dispositivo Android con NFC.';

  @override
  String get featureNfcSeatTagsDesc =>
      'Un tag NFC/RFID fisico su una sedia porta al suo posto come la scheda QR stampata; il campo si compila avvicinando il chip.';

  @override
  String get featureNfcSeatTagsTitle => 'Tag NFC/RFID delle sedie';

  @override
  String get featureNotificationGroupingDesc =>
      'I membri possono raggruppare il feed delle notifiche per tipo, giorno o membro; toccando il simbolo del gruppo si torna all\'elenco piatto.';

  @override
  String get featureNotificationGroupingTitle =>
      'Raggruppamento delle notifiche';

  @override
  String get featureNumberSequences => 'Serie di numerazione';

  @override
  String get featureNumberSequencesDesc =>
      'Come ogni registro numera i suoi documenti — prefisso, anno o mese, cifre, azzeramento del contatore — in una sola schermata per tutte le serie. I numeri sono assegnati nel database, senza buchi, attivato o no; attivato, il proprietario cambia il formato per ciò che segue.';

  @override
  String get featureOnlinePayments => 'Pagamenti online';

  @override
  String get featureOnlinePaymentsDesc =>
      'Consenti ai membri di pagare la fattura online (PayPal). Richiede la configurazione del fornitore di pagamento sul server.';

  @override
  String featureOptInBody(String features) {
    return 'Non ancora valutata come stabile: $features. Può cambiare e ha limiti noti. Attivala solo se questo spazio lo accetta.';
  }

  @override
  String get featureOptInConfirm => 'Attiva';

  @override
  String get featureOptInTitle => 'Attivare una funzione sperimentale?';

  @override
  String get featurePaymentRemindersDesc =>
      'Le fatture aperte oltre il termine configurato ricevono i livelli di sollecito automaticamente — un avviso nel feed del membro e una notifica, una volta al giorno. Disattivato: sollecitare resta un gesto manuale.';

  @override
  String get featurePaymentRemindersTitle =>
      'Solleciti di pagamento automatici';

  @override
  String get featurePdfExport => 'Esportazione PDF';

  @override
  String get featurePdfExportDesc => 'Esporta la fattura mensile come PDF.';

  @override
  String get featurePersonalInfo => 'Dati personali';

  @override
  String get featurePersonalInfoDesc =>
      'I membri inseriscono nome, indirizzo postale, telefono, e-mail e identificativi nelle Impostazioni; fatture e lettere li stampano nel blocco indirizzo standard.';

  @override
  String get featurePlanMemberPhotosDesc =>
      'I posti occupati nella scheda Piantina e nel hub Prenota mostrano la foto del profilo al posto dell’iniziale.';

  @override
  String get featurePlanMemberPhotosTitle => 'Foto dei membri sulla piantina';

  @override
  String get featurePlanObjectDeleteDesc =>
      'I proprietari possono eliminare piani, uffici, tavoli e posti anche se prenotazioni passate vi fanno riferimento: le prenotazioni conservano un\'istantanea di testo per audit e report.';

  @override
  String get featurePlanObjectDeleteTitle => 'Eliminare spazi con cronologia';

  @override
  String get featurePriceNegotiationsDesc =>
      'La tariffa è il valore predefinito; un membro può avere condizioni proprie — canone mensile, tariffa di superamento, sconto sui supplementi, prezzi unitari per servizio e pacchetto, percentuale di occupazione — proposte da chi detiene «Gestire gli accordi commerciali» e validate secondo le regole. Le vedono il membro, i proprietari e chi ha «Consultare gli accordi commerciali»; ogni consultazione è registrata.';

  @override
  String get featurePriceNegotiationsTitle => 'Negoziazioni di prezzo';

  @override
  String get featurePublicHolidaysDesc =>
      'Il proprietario sceglie un anno, vede i giorni festivi che diventerebbero giorni di chiusura e conferma. Rilanciare un anno non aggiunge nulla, e un mese già fatturato viene saltato e nominato: generare i festivi non cambia mai una fattura già emessa.';

  @override
  String get featurePublicHolidaysTitle => 'Giorni festivi';

  @override
  String get featurePublicListings => 'Scheda pubblica dello spazio';

  @override
  String get featurePublicListingsDesc =>
      'Pubblica solo informazioni e planimetrie scelte, con proprietari visibili e contatti degli amministratori facoltativi.';

  @override
  String get featurePushNotifications => 'Notifiche push';

  @override
  String get featurePushNotificationsDesc =>
      'Consegna le conferme in sospeso sui dispositivi dei membri.';

  @override
  String get featureQrBadgesDesc =>
      'Schede badge QR stampabili per il chiosco, accanto alle carte NFC/RFID.';

  @override
  String get featureQrBadgesTitle => 'Badge QR';

  @override
  String get featureRecordingPrivacyDesc =>
      'Per filmare o fotografare questo spazio. Ogni nome, indirizzo e-mail, numero di telefono, indirizzo postale e fotografia viene sostituito da una persona inventata prima di arrivare sullo schermo, mentre la piantina, le prenotazioni e gli importi restano quelli veri. Un avviso lo segnala su ogni schermata, e i moduli di identità rifiutano di salvare finché è attiva.';

  @override
  String get featureRecordingPrivacyTitle => 'Modalità ripresa';

  @override
  String get featureRegionalFormatsDesc =>
      'Ogni membro sceglie come vedere numeri, date, orologio e fuso orario. Disattivato: tutti leggono nella regione della lingua dell\'app, 24 ore, ora dello spazio.';

  @override
  String get featureRegionalFormatsTitle => 'Regione e formati';

  @override
  String get featureReportDesignExchangeDesc =>
      'Ogni modello di report può essere scritto in un file che si descrive da sé e riletto. Il file porta il modello e inoltre il significato dei campi, il markup ammesso e i segnaposto esistenti, così una persona o uno strumento può modificarlo fuori dall’app e restituirlo. Un file di un altro report, o di una versione più recente, viene rifiutato con la motivazione. Disattivato: i modelli si modificano solo nell’editor.';

  @override
  String get featureReportDesignExchangeTitle =>
      'Esporta e importa i modelli di report';

  @override
  String get featureReportDesignerDesc =>
      'L\'editor dei report a schermo intero: elementi modificati sul posto nella loro vera tipografia, trascinare per riordinare, una tavolozza di inserimento, un selettore di campi con ricerca, annulla e ripeti, dimensione e allineamento delle immagini, una protezione prima di scartare, modelli e ripristino dietro una conferma, l\'errore del modello spiegato, progettazione e anteprima affiancate su schermo largo. Disattivato: l\'editor in foglio.';

  @override
  String get featureReportDesignerTitle => 'Designer di report';

  @override
  String get featureReportLayouts => 'Layout di report posizionati';

  @override
  String get featureReportLayoutsDesc =>
      'Progetta un report indicando dove si trova ogni elemento, in mm, cm, px o %; il PDF stampa esattamente questo. Un documento con layout lo usa, gli altri mantengono le loro bande.';

  @override
  String get featureReportTexts => 'Testi dei report';

  @override
  String get featureReportTextsDesc =>
      'Il proprietario scrive testi (saluto, nota, paragrafo legale) per lingua e li colloca in qualsiasi report come text.chiave — la formulazione cambia senza toccare il design.';

  @override
  String featureRequires(String feature) {
    return 'Richiede $feature';
  }

  @override
  String get featureRichMessageRefsDesc =>
      'Un messaggio può puntare a un avviso, alla cronologia delle convalide dietro di esso e a una fattura, un pagamento o un rimborso: ogni riferimento è un link che apre ciò che nomina. Ogni selettore filtra mentre scrivi. Disattivato: si possono referenziare solo prenotazioni e spazi.';

  @override
  String get featureRichMessageRefsTitle => 'Riferimenti nei messaggi';

  @override
  String get featureRoleAssignmentDesc =>
      'Mostra una sezione Ruoli nella pagina di ogni membro per dare o revocare un ruolo, i membri di ogni ruolo, e permette a ogni membro di vedere cosa può fare qui.';

  @override
  String get featureRoleAssignmentTitle => 'Assegnazione dei ruoli';

  @override
  String get featureRoleManagement => 'Gestione dei ruoli';

  @override
  String get featureRoleManagementDesc =>
      'La matrice centrale ruolo→permesso: il proprietario decide quale permesso spetta a quale ruolo; gli altri leggono i propri. Disattivata, valgono semplicemente i valori predefiniti.';

  @override
  String get featureScheduledExpensesDesc =>
      'Spese ricorrenti (internet, telefono, elettricità): ogni membro ne programma una con la sua regola (ogni X giorni/settimane/mesi/anni, X volte o fino a una data); la programmazione è validata una volta, e ogni scadenza è presentata al membro — l’importo validato conta subito, un importo diverso si spiega e passa la validazione delle spese.';

  @override
  String get featureScheduledExpensesTitle => 'Spese programmate';

  @override
  String get featureSeatDayTimeline => 'La giornata di una postazione';

  @override
  String get featureSeatDayTimelineDesc =>
      'Una postazione prenotata solo per parte della giornata è disegnata parzialmente piena sulla piantina, e una postazione condivisa da più persone apre la giornata: chi la occupa, quando e quali fasce restano libere.';

  @override
  String get featureSeriesBooking => 'Prenotazione in serie';

  @override
  String get featureSeriesBookingDesc =>
      'Ripeti una prenotazione ogni giorno, ogni settimana o nei giorni feriali.';

  @override
  String get featureServices => 'Servizi';

  @override
  String get featureServicesDesc =>
      'Catalogo dei servizi e registrazione dei consumi.';

  @override
  String get featureSettlementFoldDesc =>
      'Le fatture raggruppate in una scompaiono dalle liste come pari e si annidano sotto la fattura di raggruppamento, che porta tutte le loro righe. Su una fattura raggruppata ogni operazione è disattivata; resta solo il suo PDF, timbrato con il numero in cui è stata raggruppata. Disattivato: le fatture raggruppate restano elencate accanto a quella di raggruppamento.';

  @override
  String get featureSettlementFoldTitle => 'Fatture raggruppate ripiegate';

  @override
  String get featureSingleRoomLevelNamesDesc =>
      'Quando un piano ha una sola stanza, le viste di prenotazione indicano il piano invece della stanza — «2° piano · Tavolo 3», non «Ufficio 1 · Tavolo 3». Una seconda stanza riporta entrambi i nomi; l’editor della planimetria mostra sempre le stanze.';

  @override
  String get featureSingleRoomLevelNamesTitle =>
      'Chiamare con il piano un piano a stanza unica';

  @override
  String get featureSiteDocuments => 'Sedi sui documenti';

  @override
  String get featureSiteDocumentsDesc =>
      'I documenti indicano la sede interessata: l\'indirizzo e la registrazione della sede di riferimento del socio come venditore, e le altre sedi frequentate nel mese nel dettaglio. Disattivato: l\'indirizzo dello spazio su tutti i documenti.';

  @override
  String get featureSpaceInquiriesDesc =>
      'Una persona connessa che trova la pagina pubblicata può scrivere agli host: i proprietari e gli amministratori che hanno scelto di essere contatti pubblici. Gli host vengono nominati prima di scrivere, e solo quella persona e gli host leggono la conversazione. Disattivato, il pulsante e la vista Richieste scompaiono, quindi nessuno apre una nuova richiesta; quelle aperte restano nella posta degli host per rispondere e chiuderle.';

  @override
  String get featureSpaceInquiriesTitle => 'Scrivi agli host';

  @override
  String get featureSpaceQrCodes => 'Codici QR degli spazi';

  @override
  String get featureSpaceQrCodesDesc =>
      'Schede QR stampabili per postazione, tavolo, ufficio e piano — scansiona per prenotare o fare check-in.';

  @override
  String get featureSubscriptionInvoicesDesc =>
      'La quota è fatturata prima del mese che paga, in una data scelta da te. Disattivato: la quota resta sulla fattura del mese.';

  @override
  String get featureSubscriptionInvoicesTitle => 'Fatture di abbonamento';

  @override
  String get featureSupplyExpensesDesc =>
      'Una spesa può essere una scorta per lo spazio (capsule di caffè, sacchetti per aspirapolvere…): convalidata, rifornisce o crea un servizio consumabile con prezzo unitario, e i consumi scalano la scorta.';

  @override
  String get featureSupplyExpensesTitle => 'Scorte dalle spese';

  @override
  String get featureSurfaceCalendarHint =>
      'Che cosa succede, per giorno e per mese.';

  @override
  String get featureSurfaceDocumentsHint =>
      'I file che lo spazio conserva e condivide.';

  @override
  String get featureSurfaceEverywhere => 'Tutta l\'app';

  @override
  String get featureSurfaceEverywhereHint =>
      'Cambia il comportamento dell\'app, ovunque tu sia.';

  @override
  String get featureSurfaceKioskHint =>
      'Il tablet all\'ingresso, i badge e le scansioni.';

  @override
  String get featureSurfaceMembersHint =>
      'Chi c\'è nello spazio, i loro profili e i loro ruoli.';

  @override
  String get featureSurfaceMessagesHint =>
      'Conversazioni, avvisi e ciò che arriva sul telefono.';

  @override
  String get featureSurfaceMoneyHint =>
      'Estratti conto, pagamenti, fatture e di che cosa sono fatti.';

  @override
  String get featureSurfaceReports => 'Documenti da stampare';

  @override
  String get featureSurfaceReportsHint =>
      'Fatture, estratti conto e lettere, e come appaiono su carta.';

  @override
  String get featureSurfaceReserveHint =>
      'Prenotare un posto, la pianta, l\'arrivo.';

  @override
  String get featureSurfaceSettingsHint =>
      'Come è configurato lo spazio stesso.';

  @override
  String get featureTaskRecorderDesc =>
      'Consente di registrare i passaggi di un\'attività sulle schermate di questo spazio, sul proprio dispositivo, rivederli ed esportare un file senza alcun valore digitato. Nulla viene inviato. Disattivato: qui nessuno registra.';

  @override
  String get featureTaskRecorderTitle => 'Registratore di attività';

  @override
  String get featureTierCore => 'Essenziale';

  @override
  String get featureTierCoreDesc =>
      'Ciò di cui ogni spazio ha bisogno. Attivo dal primo giorno.';

  @override
  String get featureTierPlatform => 'Piattaforma';

  @override
  String get featureTierPlatformDesc =>
      'Richiesto, mai presunto. Attivate ciò che questo spazio fa davvero.';

  @override
  String get featureUiAnimationsDesc =>
      'Transizioni fluide e animazioni di stato in tutta l\'app. Disattivato, ogni cambiamento è istantaneo; l\'impostazione di riduzione del movimento del dispositivo prevale sempre.';

  @override
  String get featureUiAnimationsTitle => 'Animazioni dell\'interfaccia';

  @override
  String get featureUniqueMonogramsDesc =>
      'Un avatar senza foto mostra iniziali che appartengono a un solo membro: iniziale del nome e del cognome, una lettera in più in caso di conflitto, numeri solo come ultima risorsa. Disattivato: solo la prima lettera, uguale per tutti quelli che la condividono.';

  @override
  String get featureUniqueMonogramsTitle => 'Iniziali avatar distinte';

  @override
  String get featureUsageInvoicesDesc =>
      'Finito il mese, quanto è realmente costato oltre l\'abbonamento — eccedenze, supplementi, servizi — è fatturato a parte. Disattivato: resta sulla fattura del mese.';

  @override
  String get featureUsageInvoicesTitle => 'Fatture di fine mese';

  @override
  String get featureUsageRecordsDesc =>
      'Ogni prenotazione conteggiata lascia un rilevamento: la finestra prenotata, il tempo realmente presente e ciò che viene fatturato. Una prenotazione a cui non è venuto nessuno è fatturata per intero. Chi esce prima può chiedere che il tempo non usato non sia fatturato, e decide qualcun altro, mai chi chiede. Disattivato: nessun rilevamento e nessuna correzione.';

  @override
  String get featureUsageRecordsTitle => 'Rilevamenti di utilizzo';

  @override
  String get featureUsageReport => 'Report dei consumi';

  @override
  String get featureUsageReportDesc =>
      'A fine mese il membro riceve ciò che la sua partecipazione ha pagato, ciò che ha realmente consumato e ciò che resta o eccede — dai record di utilizzo, come lettera.';

  @override
  String get featureValidationChainDesc =>
      'Una regola di convalida può chiedere le sue convalide una dopo l\'altra, ogni passo richiesto quando il precedente è passato, e può consentire alla proprietà — mai a un admin — di convalidare il proprio atto. Disattivato: tutto è chiesto in una volta e nessuno convalida il proprio evento.';

  @override
  String get featureValidationChainTitle => 'Convalide concatenate';

  @override
  String get featureValidationScopesDesc =>
      'Ogni regola di convalida indica chi convalida: gli admin, persone designate di qualsiasi ruolo, o tutti i membri — e quanti. Disattivato: proprietario e admin come prima.';

  @override
  String get featureValidationScopesTitle =>
      'Convalidatori per ruolo o persona';

  @override
  String get featureVatCounterparty => 'IVA secondo il cliente';

  @override
  String get featureVatCounterpartyDesc =>
      'Chi è l\'acquirente ai fini IVA, impostato su ogni membro: IVA nazionale, inversione contabile, fuori UE o esente con il motivo stampato. Disattivato: solo la regola automatica.';

  @override
  String get featureVatDeclarationsDesc =>
      'Genera la dichiarazione IVA periodica dalle fatture emesse, mappala sul modulo ufficiale e trasmettila o esportala.';

  @override
  String get featureVatDeclarationsTitle => 'Dichiarazioni IVA';

  @override
  String get featureVatGroups => 'Gruppi IVA';

  @override
  String get featureVatGroupsDesc =>
      'Ogni aliquota IVA porta il gruppo fiscale di ciò che tassa — ordinaria, intermedia, ridotta, super-ridotta, zero, esente, non soggetta, cauzione rimborsabile, con accise — con la categoria e la dicitura di esenzione che il gruppo implica. Disattivato: semplici percentuali.';

  @override
  String get featureVatManagementDesc =>
      'L\'editor delle aliquote IVA e i selettori di aliquota su servizi, pacchetti, accessori e tariffe. Disattivato nasconde la configurazione; le aliquote salvate continuano ad applicarsi.';

  @override
  String get featureVatManagementTitle => 'Gestione IVA';

  @override
  String get featureVatRateHistory => 'Versioni delle aliquote IVA';

  @override
  String get featureVatRateHistoryDesc =>
      'Un\'aliquota è una famiglia di versioni datate: una modifica per legge aggiunge il nuovo valore dalla sua data, il vecchio resta su ogni prestazione precedente e nulla viene riassegnato. Disattivato: un valore per aliquota.';

  @override
  String get featureVatReport => 'Report IVA';

  @override
  String get featureVatReportDesc =>
      'Ogni posizione imponibile di un mese o periodo — documento, cliente, imponibile, aliquota, IVA, totale, categoria — con subtotali per aliquota, come lettera e come CSV per il commercialista.';

  @override
  String get featureWhatsappIntegration => 'Integrazione WhatsApp';

  @override
  String get featureWhatsappIntegrationDesc =>
      'I membri condividono il loro numero WhatsApp nel profilo; un tocco su un membro apre la chat; il link del gruppo nella rubrica. Nessuna integrazione WhatsApp lato server.';

  @override
  String get featureWorkingHours => 'Orario di lavoro';

  @override
  String get featureWorkingHoursDesc =>
      'Configura la giornata lavorativa e offri prenotazioni a orari esatti; disattivato valgono i valori 8:00–17:00.';

  @override
  String get featureWorkspaceBrandingDesc =>
      'Lo spazio sceglie un colore del marchio da cui l’app deriva i temi chiaro e scuro, e i colori di riempimento delle sue sale. Un colore che renderebbe l’app illeggibile viene rifiutato con la motivazione; la palette del prodotto resta quella predefinita.';

  @override
  String get featureWorkspaceBrandingTitle => 'Colori dello spazio';

  @override
  String get featureWorkspaceLibraryDesc =>
      'Salvate la pianta di questo spazio e il suo funzionamento come modello, scegliete chi può vederla, invitate persone via e-mail e partite da ciò che altri offrono.';

  @override
  String get featureWorkspaceLibraryTitle => 'Biblioteca degli spazi';

  @override
  String get featureWorkspaceStatus => 'Situazione dello spazio';

  @override
  String get featureWorkspaceStatusDesc =>
      'Ciò che lo spazio ha fatturato, incassato, rimborsato e ripartito in un periodo, socio per socio — a schermo per proprietari e admin, e come rapporto stampabile. Disattivato: nessuna vista della situazione.';

  @override
  String get featureWorkspaceVocabularyDesc =>
      'Lo spazio può rinominare, per lingua, un piccolo insieme approvato di parole del prodotto: un posto, le etichette della legenda, le schede. Tutto il resto mantiene la formulazione del prodotto, e uno spazio che non rinomina nulla appare esattamente come prima.';

  @override
  String get featureWorkspaceVocabularyTitle => 'Lessico dello spazio';

  @override
  String get featuresFilterChanged => 'Modificate';

  @override
  String get featuresNoMatch => 'Nessuna funzionalità corrisponde.';

  @override
  String get featuresSearchLabel => 'Cerca funzionalità';

  @override
  String get featuresTitle => 'Funzionalità';

  @override
  String get featuresViewProcesses => 'Processi';

  @override
  String get featuresViewSwitches => 'Interruttori';

  @override
  String get fecAccountBank => 'Banca';

  @override
  String get fecAccountCustomers => 'Clienti';

  @override
  String get fecAccountExpenses => 'Spese';

  @override
  String get fecAccountRevenue => 'Ricavi';

  @override
  String get fecAccountVat => 'IVA incassata';

  @override
  String get fecAccountsIntro =>
      'Un FEC è fatto di scritture contabili, quindi richiede numeri di conto. Questi sono i conti del piano contabile francese — sostituiscili con quelli del tuo commercialista.';

  @override
  String get fecAccountsTitle => 'Conti da utilizzare';

  @override
  String get fecMissingSiren =>
      'Il FEC prende il nome dal numero di registrazione — inseriscilo prima in Identità legale.';

  @override
  String get federationActionExistingAccount =>
      'Accedi al mio account esistente';

  @override
  String get federationActionReviewServer => 'Verifica il server';

  @override
  String get federationCancel => 'Annulla';

  @override
  String get federationClose => 'Chiudi';

  @override
  String get federationContinue => 'Continua con Deskilo';

  @override
  String federationDetailAuthority(String host) {
    return 'Autorità di identità: $host';
  }

  @override
  String federationDetailServer(String host) {
    return 'Server: $host';
  }

  @override
  String get federationDetails => 'Dettagli tecnici';

  @override
  String get federationFailureBrowser =>
      'Impossibile aprire il browser. Verifica che sia disponibile un browser, poi riprova.';

  @override
  String get federationFailureExpired =>
      'Questo accesso ha richiesto troppo tempo ed è scaduto. Ricomincialo.';

  @override
  String get federationFailureIncompatible =>
      'Questo server non accetta questo accesso Deskilo. Controlla l\'indirizzo del server o chiedi al suo amministratore.';

  @override
  String get federationFailureNetwork =>
      'Il server non è raggiungibile, quindi l\'accesso non è stato completato. Controlla la connessione, poi riprova.';

  @override
  String get federationFailureProviderMissing =>
      'L\'accesso con Deskilo non è configurato su questo server. Chiedi al suo amministratore di attivarlo.';

  @override
  String get federationFailureRefused =>
      'L\'accesso è stato annullato o rifiutato nel browser. Non è cambiato nulla; puoi riprovare.';

  @override
  String get federationFailureUnlinked =>
      'Questo account Deskilo corrisponde a un account qui non ancora collegato. Accedi a quell\'account, poi collega Deskilo in Account collegati. Nulla viene unito finché il server non lo conferma.';

  @override
  String get federationFailureWrongAccount =>
      'Il browser ha effettuato l\'accesso con un altro account Deskilo. Cambia account nel browser, poi riprova.';

  @override
  String federationPurpose(String server) {
    return 'Il browser conferma il tuo account Deskilo e poi ti riporta a $server. Le tue adesioni e la tua cronologia qui restano invariate.';
  }

  @override
  String get federationRetry => 'Riprova';

  @override
  String get federationStageCompleting => 'Completamento dell\'accesso…';

  @override
  String get federationStageOpening => 'Apertura dell\'accesso…';

  @override
  String get federationStageWaiting => 'In attesa dell\'accesso nel browser…';

  @override
  String get fieldProblemNotAChoice => 'Scegli dalla lista.';

  @override
  String get fieldProblemNotADate => 'Una data, per favore.';

  @override
  String get fieldProblemNotANumber => 'Un numero, per favore.';

  @override
  String get fieldProblemNotAPhone => 'Non è un numero di telefono.';

  @override
  String get fieldProblemNotAUrl => 'Non è un indirizzo web.';

  @override
  String get fieldProblemNotAnEmail => 'Non è un indirizzo e-mail.';

  @override
  String get fieldProblemNotWhole => 'Un numero intero, per favore.';

  @override
  String get fieldProblemRequired => 'Rispondi, per favore.';

  @override
  String fieldProblemTooEarly(String date) {
    return 'Non prima del $date.';
  }

  @override
  String fieldProblemTooLarge(String max) {
    return 'Al massimo $max.';
  }

  @override
  String fieldProblemTooLate(String date) {
    return 'Non dopo il $date.';
  }

  @override
  String fieldProblemTooLong(int count) {
    return 'Al massimo $count caratteri.';
  }

  @override
  String fieldProblemTooShort(int count) {
    return 'Almeno $count caratteri.';
  }

  @override
  String fieldProblemTooSmall(String min) {
    return 'Almeno $min.';
  }

  @override
  String get gettingStartedActionChooseDay => 'Scegli un altro giorno';

  @override
  String get gettingStartedActionChooseTime => 'Scegli un orario da prenotare';

  @override
  String get gettingStartedActionFinishSetup => 'Completa la configurazione';

  @override
  String get gettingStartedActionHelp => 'Aiuto per questo spazio';

  @override
  String get gettingStartedActionMembership => 'Vedi la mia iscrizione';

  @override
  String gettingStartedAllowance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Puoi tenere $count prenotazioni alla volta.',
      one: 'Puoi tenere una prenotazione alla volta.',
    );
    return '$_temp0';
  }

  @override
  String get gettingStartedAvailabilityUnknown =>
      'Impossibile caricare la disponibilità. L’aiuto spiega come funziona la prenotazione qui.';

  @override
  String gettingStartedBooked(String id, String state) {
    return 'La tua prenotazione $id è $state. La tua iscrizione mostra cos’altro è incluso.';
  }

  @override
  String get gettingStartedClosedToday =>
      'Lo spazio è chiuso nel giorno selezionato. Scegli un altro giorno per vedere cosa è libero.';

  @override
  String get gettingStartedEnvDev => 'Spazio di sviluppo';

  @override
  String get gettingStartedEnvProd => 'Spazio di produzione';

  @override
  String get gettingStartedMembershipUnknown =>
      'Impossibile caricare la tua iscrizione al momento. L’aiuto spiega come funziona questo spazio.';

  @override
  String get gettingStartedNoSpaces =>
      'Qui non si può ancora prenotare nulla. La tua iscrizione mostra cosa comprende il tuo accesso.';

  @override
  String get gettingStartedNotNow => 'Non ora';

  @override
  String get gettingStartedReadyToBook =>
      'Lo spazio è aperto in questo giorno. Scegli un orario e un posto sulla pianta — nulla viene prenotato finché non confermi.';

  @override
  String get gettingStartedReopen => 'Primi passi';

  @override
  String get gettingStartedSemantics =>
      'Primi passi: un passo successivo suggerito';

  @override
  String gettingStartedSetupIncomplete(String step) {
    return 'Prima che qualcuno possa prenotare qui: $step.';
  }

  @override
  String get gettingStartedStandingAdmin => 'Sei amministratore qui.';

  @override
  String get gettingStartedStandingMember => 'Sei membro qui.';

  @override
  String get gettingStartedStandingOwner =>
      'Sei proprietario di questo spazio.';

  @override
  String get gettingStartedStateCancelled => 'annullata';

  @override
  String get gettingStartedStateCheckedIn => 'registrata';

  @override
  String get gettingStartedStateCompleted => 'completata';

  @override
  String get gettingStartedStateReleased => 'rilasciata';

  @override
  String get gettingStartedStateReserved => 'prenotata';

  @override
  String gettingStartedTitle(String workspace) {
    return 'Primi passi in $workspace';
  }

  @override
  String handoffAmountOutOfRange(String number) {
    return '$number: un totale troppo grande per essere trasmesso esattamente';
  }

  @override
  String get handoffBlocked =>
      'Questo file non può essere consegnato finché la fonte non è corretta.';

  @override
  String get handoffChanged =>
      'Le fatture sono cambiate durante la revisione. Esporta di nuovo per vedere i conti attuali.';

  @override
  String handoffDuplicate(String number) {
    return '$number: compare due volte nella fonte';
  }

  @override
  String handoffExcludedSettlements(String count) {
    return '$count riepilogo/i di saldo escluso/i: le loro fatture sono già elencate';
  }

  @override
  String handoffIncluded(String count) {
    return '$count documento/i nel file';
  }

  @override
  String get handoffIssued => 'Emesse';

  @override
  String handoffMissingCurrency(String number) {
    return '$number: nessuna valuta';
  }

  @override
  String handoffOrphanMatch(String key) {
    return 'Un pagamento ($key) non appartiene ad alcun documento di questa esportazione';
  }

  @override
  String handoffOverpaid(String number) {
    return '$number: pagato più dell’importo fatturato';
  }

  @override
  String handoffPayments(String confirmed, String pending) {
    return 'Pagato: $confirmed confermato, $pending in attesa';
  }

  @override
  String handoffRowMismatch(String detail) {
    return 'Le righe del file non corrispondono ai documenti ($detail)';
  }

  @override
  String get handoffSave => 'Salva file e rapporto';

  @override
  String get handoffTitle => 'Prima di salvare';

  @override
  String handoffUnsupportedCurrency(String number) {
    return '$number: la sua valuta non ha un numero di decimali verificato';
  }

  @override
  String get handoffVoided => 'Annullate';

  @override
  String get helpContents => 'Indice';

  @override
  String get helpDotTooltip => 'Apri la guida';

  @override
  String get helpHintAvailability =>
      'Imposta i giorni di apertura e gli orari, e aggiungi giorni di chiusura che nessuno può prenotare.';

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
  String get helpHintAvailabilityTopic => 'Disponibilità';

  @override
  String get helpHintBadges =>
      'Emetti un badge QR stampabile o registra una tessera NFC; revoca i badge persi in qualsiasi momento.';

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
  String get helpHintBadgesTopic => 'badge RFID';

  @override
  String get helpHintCalendar =>
      'Scegli un giorno o un periodo: tutto ciò che ha una data e che puoi vedere, in un elenco, ogni riga apre la sua origine.';

  @override
  String get helpHintCalendarTip2 =>
      'Passa da Giorno a Periodo per vedere una settimana o un mese intero — le frecce avanzano della dimensione della selezione.';

  @override
  String get helpHintCalendarTip3 =>
      'Tocca un chip di tipo per vedere solo quello: prenotazioni, avvisi, messaggi, fatture, pagamenti, consumi, promemoria.';

  @override
  String get helpHintCalendarTip4 =>
      'Ogni riga apre la sua origine — la prenotazione, la conversazione, l\'avviso, la fattura o quel mese in Finanze.';

  @override
  String get helpHintCalendarTip4Topic => 'Come si comporta la prenotazione';

  @override
  String get helpHintCalendarTip5 =>
      'Lo scudo mostra chi può vedere ogni tipo e chi ha davvero consultato le tue finanze.';

  @override
  String get helpHintCalendarTip5Topic => 'Privacy';

  @override
  String get helpHintCalendarTopic => 'Calendario';

  @override
  String get helpHintDismiss => 'Nascondi suggerimento';

  @override
  String get helpHintEditor =>
      'Disegna stanze e scrivanie, timbra i posti — tocca due volte un posto per modificarne le proprietà.';

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
  String get helpHintEditorTopic => 'editor dello spazio';

  @override
  String get helpHintEvents =>
      'Tutto quello che è successo, in un unico feed. Le decisioni in attesa stanno in alto; i filtri restringono il resto.';

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
  String get helpHintEventsTopic => 'Eventi';

  @override
  String get helpHintFeatures =>
      'Attiva o disattiva le funzionalità dello spazio: l\'app di ogni membro si aggiorna subito.';

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
  String get helpHintFeaturesTopic => 'Funzionalità';

  @override
  String get helpHintLearnMore => 'Scopri di più';

  @override
  String get helpHintMembers =>
      'Invita membri, imposta piano e ruolo, e gestisci i loro badge.';

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
  String get helpHintMembersTipNegotiation =>
      'I prezzi propri di un membro: apri la sua scheda → Negoziazione di prezzo, indica quota, eccedenza o sconto concordati, e i convalidatori della regola confermano.';

  @override
  String get helpHintMembersTipNegotiationTopic => 'Negoziazioni di prezzo';

  @override
  String get helpHintMembersTopic => 'Membri e piani';

  @override
  String get helpHintMessages =>
      'Tutte le conversazioni in un elenco, la più recente in alto. Tocca la matita per scrivere a qualcuno o creare un gruppo.';

  @override
  String get helpHintMessagesTip2 =>
      'Scegli una persona per una chat privata, o più per creare un gruppo — il campo del nome compare da due in poi, e quel nome è unico qui: nessuno deve indovinare a quale «Team» sta scrivendo.';

  @override
  String get helpHintMessagesTip3 =>
      'Tocca un nome in cima a una chat per vedere il profilo: la prenotazione di oggi, se ha fatto il check-in e come raggiungerlo.';

  @override
  String get helpHintMessagesTip4 =>
      'La ricerca trova membri, gruppi e le parole nei messaggi — un risultato ti porta direttamente lì.';

  @override
  String get helpHintMessagesTip5 =>
      'Inserisci una prenotazione o uno spazio nel messaggio invece di descriverlo; chi legge lo tocca e arriva a quello giusto.';

  @override
  String get helpHintMessagesTopic => 'Messaggi';

  @override
  String get helpHintMoney =>
      'Il conto mensile: sfoglia i mesi con le frecce; paga, esporta o condividi da qui.';

  @override
  String get helpHintMoneyDocuments =>
      'Le tue carte: le tue condizioni, il report dei pagamenti, l\'estratto del mese in PDF, la libreria dei documenti.';

  @override
  String get helpHintMoneyDocumentsTip3 =>
      'Le mie condizioni è il tuo accordo finanziario in vigore — piano, tariffa, extra — reso come documento da conservare.';

  @override
  String get helpHintMoneyDocumentsTopic => 'La vista Documenti';

  @override
  String get helpHintMoneyInvoices =>
      'Le tue fatture: cosa è aperto e per quando, ogni fattura emessa a tuo nome con il suo stato, un tocco al dettaglio e al pagamento.';

  @override
  String get helpHintMoneyInvoicesTip2 =>
      'Oltre il termine di pagamento dello spazio, una fattura aperta si legge qui come scaduta, e i livelli di sollecito configurati dal proprietario arrivano da soli — nel feed e come notifica.';

  @override
  String get helpHintMoneyInvoicesTip2Topic =>
      'Solleciti di pagamento automatici';

  @override
  String get helpHintMoneyInvoicesTopic => 'La vista Fatture';

  @override
  String get helpHintMoneyPayments =>
      'Regolare e chiedere: il saldo, come regolarlo o pagare online, registrare un pagamento — e inviare una spesa, chiedere mezze giornate o aggiungere un consumo.';

  @override
  String get helpHintMoneyPaymentsTip2 =>
      'Registra un pagamento con la data del movimento e il mese che salda — l\'altra parte conferma.';

  @override
  String get helpHintMoneyPaymentsTip3 =>
      'Pagare online salda il dovuto subito; la scheda istruzioni mostra la via manuale con il riferimento da indicare.';

  @override
  String get helpHintMoneyPaymentsTip3Topic => 'pagamenti online';

  @override
  String get helpHintMoneyPaymentsTipSupply =>
      'Hai comprato capsule o sacchetti per aspirapolvere per lo spazio? Invia la spesa come scorta: convalidata, va sullo scaffale come consumabile che gli altri pagano, e tu vieni rimborsato.';

  @override
  String get helpHintMoneyPaymentsTipSupplyTopic => 'Servizi e Accessori';

  @override
  String get helpHintMoneyPaymentsTopic => 'La vista Pagamenti';

  @override
  String get helpHintMoneyStatement =>
      'Il mese così com\'è: il tuo conto, giorni usati e rimasti, abbonamento, servizi, pacchetti, posizioni aperte, crediti e il saldo. Scorri i mesi con le frecce.';

  @override
  String get helpHintMoneyStatementTip2 =>
      'Una mattina prenotata conta mezza giornata; i giorni fuori orario seguono la politica fuori-orario dello spazio.';

  @override
  String get helpHintMoneyStatementTip2Topic =>
      'Come si comporta la prenotazione';

  @override
  String get helpHintMoneyStatementTip3 =>
      'Giorni finiti? Chiedi mezze giornate extra, compra un pacchetto o continua a prenotare a consumo — secondo il tuo piano.';

  @override
  String get helpHintMoneyStatementTipNegotiation =>
      'Condizioni negoziate? La scheda mostra i tuoi prezzi accanto alla tariffa, da quando, e chi può vederli — i proprietari e gli admin finanze, ogni lettura registrata.';

  @override
  String get helpHintMoneyStatementTipNegotiationTopic =>
      'Negoziazioni di prezzo';

  @override
  String get helpHintMoneyStatementTopic => 'La vista Estratto';

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
  String get helpHintMoneyTopic => 'Denaro';

  @override
  String get helpHintNextTip => 'Suggerimento successivo';

  @override
  String get helpHintPlan =>
      'La piantina dal vivo: tocca un posto libero per prenotare, tocca la tua prenotazione per fare il check-in.';

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
  String get helpHintPlanTopic => 'Piantina';

  @override
  String get helpHintPrevTip => 'Suggerimento precedente';

  @override
  String get helpHintPrivacy =>
      'Vedi chi può leggere i tuoi dati e chi l\'ha fatto, esporta tutto in un file o esci con i dati personali cancellati.';

  @override
  String get helpHintPrivacyTip2 =>
      'I messaggi li leggono solo le persone della conversazione, qualunque sia il ruolo; il denaro solo tu e il permesso finanze.';

  @override
  String get helpHintPrivacyTip3 =>
      'Ogni lettura delle tue finanze da parte di altri è registrata dal server — il registro non si può aggirare né modificare.';

  @override
  String get helpHintPrivacyTopic => 'Privacy';

  @override
  String get helpHintReserve =>
      'Scegli un giorno e una fascia oraria, poi tocca un posto libero per prenotarlo.';

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
  String get helpHintReserveTopic => 'hub Prenota';

  @override
  String get helpHintRestoreTitle => 'Mostra di nuovo i suggerimenti di aiuto';

  @override
  String get helpHintRestored =>
      'I suggerimenti di aiuto saranno mostrati di nuovo.';

  @override
  String get helpHintValidation =>
      'Decidi quali azioni richiedono conferma, chi conferma e quante approvazioni servono.';

  @override
  String get helpHintValidationTip2 =>
      'Una scheda per tipo di evento, ognuna eredita dalla regola predefinita finché non la modifichi: pagamenti, spese, cambi di ruolo e altro.';

  @override
  String get helpHintValidationTip3 =>
      'Nessuno convalida mai il proprio evento, e una richiesta senza risposta scade dopo 7 giorni: nulla viene concesso in silenzio.';

  @override
  String get helpHintValidationTipScopes =>
      'Chi convalida è l\'ambito della regola: gli admin, persone designate di qualsiasi ruolo, o tutti i membri — e quanti. Il proprietario può sempre; nessuno convalida il proprio evento.';

  @override
  String get helpHintValidationTipScopesTopic => 'Gestione dei ruoli';

  @override
  String get helpHintValidationTopic => 'conferme';

  @override
  String get helpHintWorkspace =>
      'Paese, valuta, lingua e dati di fatturazione: documenti e imposte seguono queste impostazioni.';

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
  String get helpHintWorkspaceTopic => 'Impostazioni dello spazio';

  @override
  String get helpTitle => 'Aiuto';

  @override
  String get helpTopicAccounting => 'Esportazioni contabili';

  @override
  String get helpTopicBilling => 'Fatturazione';

  @override
  String get helpTopicBookingLimits => 'Limiti di prenotazione';

  @override
  String get helpTopicBookingPolicies => 'Regole di prenotazione';

  @override
  String get helpTopicDeployment => 'Distribuire';

  @override
  String get helpTopicDocumentLibrary => 'biblioteca documenti';

  @override
  String get helpTopicEinvoice => 'fattura elettronica';

  @override
  String get helpTopicEnvironments => 'Ambienti';

  @override
  String get helpTopicInstances => 'Istanze';

  @override
  String get helpTopicKiosk => 'Modalità chiosco';

  @override
  String get helpTopicLegalIdentity => 'Identità legale';

  @override
  String get helpTopicReadiness => 'ammissibilità';

  @override
  String get helpTopicReportEditor => 'editor di report';

  @override
  String get helpTopicReportLayout => 'I layout posizionati';

  @override
  String get helpTopicScheduledExpenses => 'Spese programmate';

  @override
  String get helpTopicServer => 'il tuo server';

  @override
  String get helpTopicSettings => 'Impostazioni e profilo';

  @override
  String get helpTopicTrace => 'Il registro';

  @override
  String get helpTopicVat => 'IVA';

  @override
  String get helpTopicWindowEnvelope => 'Il contratto della busta a finestra';

  @override
  String get helpTopicWorkingHours => 'Orari di lavoro';

  @override
  String get helpTopicWorkspaceId => 'ID spazio';

  @override
  String get holidayAllSaints => 'Ognissanti';

  @override
  String get holidayArmistice => 'Armistizio 1918';

  @override
  String get holidayAscension => 'Ascensione';

  @override
  String get holidayAssumption => 'Assunzione';

  @override
  String get holidayBoxingDay => 'Santo Stefano';

  @override
  String get holidayChristmas => 'Natale';

  @override
  String get holidayEasterMonday => 'Lunedì dell\'Angelo';

  @override
  String get holidayGermanUnity => 'Giorno dell\'Unità tedesca';

  @override
  String get holidayGoodFriday => 'Venerdì Santo';

  @override
  String get holidayImportAction => 'Importa i giorni festivi (dati aperti)';

  @override
  String holidayImportConfirm(int count) {
    return 'Importa $count giorni di chiusura';
  }

  @override
  String get holidayImportFailed =>
      'Non è stato possibile verificare né importare i giorni festivi. Non è stato modificato nulla.';

  @override
  String get holidayImportNationwide => 'Solo festività nazionali';

  @override
  String get holidayImportRegion => 'Regione';

  @override
  String get holidayImportRetry => 'Riprova';

  @override
  String holidayImportSource(String source) {
    return 'Fonte: $source';
  }

  @override
  String get holidayImportUnavailable =>
      'La fonte dei giorni festivi non è raggiungibile al momento. Riprova più tardi o usa «Aggiungi i giorni festivi».';

  @override
  String get holidayLabourDay => 'Festa del Lavoro';

  @override
  String get holidayNationalDay => 'Festa nazionale francese';

  @override
  String get holidayNewYear => 'Capodanno';

  @override
  String get holidayVictory1945 => 'Vittoria 1945';

  @override
  String get holidayWhitMonday => 'Lunedì di Pentecoste';

  @override
  String identityConsentAsks(String host) {
    return 'Usa la tua identità Deskilo per accedere a $host.';
  }

  @override
  String get identityConsentCompleting => 'Salvataggio della scelta…';

  @override
  String get identityConsentPurpose =>
      'L’accesso agli spazi e agli assistenti viene approvato separatamente.';

  @override
  String get identityConsentReturnFailed =>
      'Impossibile aprire la destinazione.';

  @override
  String get identityConsentReturning => 'Ritorno all’accesso…';

  @override
  String get identityConsentTitle => 'Continua con Deskilo';

  @override
  String get identityConsentUnavailable =>
      'Questa richiesta di accesso non è disponibile. Torna alla destinazione e ricomincia.';

  @override
  String get inboxAlertsTab => 'Avvisi';

  @override
  String get inboxChatsTab => 'Chat';

  @override
  String get inboxFilterAll => 'Tutti';

  @override
  String get inboxFilterArchived => 'Archiviati';

  @override
  String get inboxFilterUnread => 'Non letti';

  @override
  String get inboxNoArchived => 'Nessuna conversazione archiviata.';

  @override
  String get inboxNoUnread => 'Niente da leggere — sei aggiornato.';

  @override
  String get inboxRetry => 'Riprova';

  @override
  String get instanceAccountIntro =>
      'Create un account gratuito su supabase.com, poi un token di accesso personale (Account → Access Tokens) e incollatelo qui. L\'assistente lo usa per creare e configurare il progetto; non viene mai salvato.';

  @override
  String get instanceAdminsHelp =>
      'Decidono chi può usare gli assistenti. Si possono scegliere solo persone che hanno confermato la propria identità per gli assistenti.';

  @override
  String get instanceAdminsTitle => 'Amministratori della base';

  @override
  String get instanceApplySignIn => 'Applica le impostazioni di accesso';

  @override
  String get instanceApprove => 'Approva';

  @override
  String instanceAttentionForeign(String tables) {
    return 'Il suo schema public contiene tabelle che DesKilo non crea ($tables). L\'installazione lì è rifiutata; usate un progetto vuoto.';
  }

  @override
  String get instanceAttentionNotHealthy =>
      'Supabase non segnala il progetto come operativo. Attendete che lo sia, oppure ripristinatelo nella dashboard.';

  @override
  String get instanceAttentionOtherTooling =>
      'Le sue migrazioni sono state registrate da un altro strumento, quindi non si può sapere da dove DesKilo riprenderebbe. Usate un progetto vuoto.';

  @override
  String instanceAttentionPostgres(int found, int supported) {
    return 'Usa Postgres $found; DesKilo è pensato per Postgres $supported.';
  }

  @override
  String get instanceAttentionUnrecorded =>
      'Le tabelle di DesKilo ci sono, ma nessuna migrazione è stata registrata. Registrate prima ciò che contiene con `dart run tool/instance.dart record`.';

  @override
  String get instanceBlock => 'Blocca';

  @override
  String get instanceBlockerNoAdmin => 'un amministratore della base';

  @override
  String get instanceBlockers => 'Manca ancora:';

  @override
  String get instanceCheckToken => 'Verifica il token';

  @override
  String get instanceChooseAnother => 'Scegli un altro progetto';

  @override
  String get instanceClaimBody =>
      'Hai creato questa istanza e non è definito alcun proprietario. Assumendo la proprietà ne diventi il responsabile.';

  @override
  String get instanceClaimButton => 'Assumi la proprietà';

  @override
  String get instanceClaimDone => 'Ora sei il proprietario dell\'istanza.';

  @override
  String get instanceClaimFailed =>
      'Non è stato possibile assumere la proprietà.';

  @override
  String get instanceClaimTitle => 'Assumi la proprietà';

  @override
  String get instanceClientApproved => 'Approvato';

  @override
  String get instanceClientBlocked => 'Bloccato';

  @override
  String get instanceClientWaiting => 'In attesa di approvazione';

  @override
  String get instanceClientsHelp =>
      'Un assistente si registra da solo alla prima connessione; funziona solo dopo l\'approvazione qui.';

  @override
  String get instanceClientsTitle => 'Client degli assistenti';

  @override
  String get instanceConfirmSecondFactor => 'Conferma con il mio autenticatore';

  @override
  String get instanceCreateButton => 'Crea una nuova istanza';

  @override
  String get instanceCreateProject => 'Crea il progetto';

  @override
  String get instanceDatabasePassword =>
      'Password del database, scelta per voi — copiatela in un posto sicuro; l\'app non ne ha più bisogno.';

  @override
  String get instanceDelegateAdd => 'Delega il ruolo';

  @override
  String get instanceDelegateAlreadyOwner =>
      'Il proprietario non ha bisogno di una delega.';

  @override
  String get instanceDelegateFieldLabel => 'Indirizzo e-mail di un account';

  @override
  String get instanceDelegateNoAccount =>
      'Nessun account usa questo indirizzo e-mail.';

  @override
  String get instanceDelegateUnavailable =>
      'Questo server non permette ancora di delegare.';

  @override
  String get instanceDelegateUnchanged => 'Questa persona è già delegata.';

  @override
  String get instanceDelegateUnconfirmed =>
      'Questo account non ha ancora confermato il suo indirizzo e-mail.';

  @override
  String get instanceDelegateWithdraw => 'Revoca la delega';

  @override
  String get instanceDelegateWithdrawBody =>
      'La persona perde subito l\'accesso alla configurazione dell\'installazione.';

  @override
  String get instanceDelegateWithdrawConfirm => 'Revoca';

  @override
  String get instanceDelegateWithdrawTitle => 'Revocare questa delega?';

  @override
  String get instanceDelegated => 'Ruolo delegato.';

  @override
  String get instanceDelegatesHelp =>
      'Un delegato può eseguire la configurazione degli assistenti per l\'intera installazione. Non può delegare a sua volta e non vede altri spazi.';

  @override
  String get instanceDelegatesNone => 'Nessun delegato.';

  @override
  String get instanceDelegatesTitle => 'Delegati';

  @override
  String get instanceDelegationWithdrawn => 'Delega revocata.';

  @override
  String instanceDeployFunctions(int count) {
    return 'Distribuisci le funzioni: pagamenti, fatture elettroniche, push, badge ($count).';
  }

  @override
  String get instanceDoctorAttention => 'Richiede attenzione';

  @override
  String get instanceDoctorIntro =>
      'Prima che questo dispositivo la usi, il controllo di sicurezza deve passare: un allarme tiene il pulsante disattivato finché non è risolto.';

  @override
  String instanceDoctorPassed(int count) {
    return '$count controlli superati';
  }

  @override
  String get instanceDoctorProtected => 'Protetto';

  @override
  String get instanceDoctorRun => 'Avvia il controllo di sicurezza';

  @override
  String get instanceDoctorRunAgain => 'Controlla di nuovo';

  @override
  String get instanceDoneIntro =>
      'L\'istanza è pronta. Usatela su questo dispositivo, poi condividete il QR del server dalla schermata Server perché i membri si uniscano alla stessa.';

  @override
  String instanceInstallSchema(int count) {
    return 'Installa lo schema: ogni migrazione dell\'app, in ordine ($count).';
  }

  @override
  String get instanceIntro =>
      'Impostazioni valide per tutti gli spazi di lavoro di questa installazione. Solo l\'operatore dell\'istanza vede questa pagina; ogni modifica richiede il secondo fattore e viene registrata.';

  @override
  String get instanceMakeAdmin => 'Nomina amministratore';

  @override
  String get instanceNoCandidates =>
      'Nessun altro ha ancora confermato la propria identità.';

  @override
  String get instanceNotOperator =>
      'Solo l\'operatore dell\'istanza gestisce gli assistenti dell\'installazione.';

  @override
  String get instanceOrganisationLabel => 'Organizzazione';

  @override
  String get instanceOwnerClaimIntro =>
      'Di chi è questa istanza? Inserisci l\'e-mail con cui ti registrerai. Dopo aver confermato l\'indirizzo, rivendica la titolarità da Impostazioni → Proprietario dell\'istanza.';

  @override
  String get instanceOwnerClaimLabel => 'E-mail del titolare';

  @override
  String get instanceOwnerCopied => 'Indirizzo e-mail copiato.';

  @override
  String get instanceOwnerCopyEmail => 'Copia l\'indirizzo e-mail';

  @override
  String get instanceOwnerHelp =>
      'Questa installazione è condivisa da tutti i suoi spazi. Il proprietario dell\'istanza ne risponde: contattalo per tutto ciò che riguarda l\'intera installazione, come gli assistenti.';

  @override
  String get instanceOwnerNone =>
      'Non è ancora stato definito un proprietario dell\'istanza.';

  @override
  String get instanceOwnerTitle => 'Proprietario dell\'istanza';

  @override
  String instanceProgress(int done, int total, String current) {
    return '$done / $total · $current';
  }

  @override
  String get instanceProjectName => 'Nome del progetto';

  @override
  String instanceProjectReady(String ref) {
    return 'Progetto pronto: $ref';
  }

  @override
  String instanceProjectStatus(String status) {
    return 'Stato del progetto: $status';
  }

  @override
  String get instanceReadyAttention =>
      'Questo progetto richiede attenzione: non è stato installato nulla.';

  @override
  String instanceReadyCurrent(int version) {
    return 'La versione $version di DesKilo è installata e aggiornata: lo schema non richiede nulla.';
  }

  @override
  String get instanceReadyInstall =>
      'Il progetto è vuoto: verrà installato tutto.';

  @override
  String instanceReadyResume(int pending) {
    return 'Un\'installazione di DesKilo si è fermata a metà: restano $pending migrazioni e verranno eseguite solo quelle.';
  }

  @override
  String instanceReadyUpgrade(int version, int pending) {
    return 'La versione $version di DesKilo è installata: verranno eseguite solo le $pending migrazioni mancanti.';
  }

  @override
  String get instanceRegion => 'Regione (la più vicina allo spazio)';

  @override
  String get instanceRemoveAdmin => 'Rimuovi';

  @override
  String get instanceRetry => 'Riprova da dove si è fermato';

  @override
  String get instanceRevokeToken =>
      'Ora potete revocare il token di accesso: DesKilo non ne ha conservato alcuna copia.';

  @override
  String get instanceRuntimeOff => 'Disattivati';

  @override
  String get instanceRuntimeOn => 'Attivi';

  @override
  String get instanceRuntimeTitle => 'Assistenti su questa installazione';

  @override
  String get instanceSecondFactorNeeded =>
      'Le modifiche qui richiedono il secondo fattore in questa sessione.';

  @override
  String get instanceSignInExplain =>
      'Impostazioni di accesso: conferma via e-mail attiva (una registrazione deve cliccare il link ricevuto), e i link dell\'app consentiti per reimpostare la password e i magic link.';

  @override
  String get instanceStepAccount => 'Account';

  @override
  String get instanceStepDone => 'Fatto';

  @override
  String instanceStepFailed(String item, String message) {
    return 'Fermato a $item: $message';
  }

  @override
  String get instanceStepFunctions => 'Funzioni';

  @override
  String get instanceStepProject => 'Progetto';

  @override
  String get instanceStepSchema => 'Schema';

  @override
  String get instanceStepSignIn => 'Accesso';

  @override
  String get instanceTitle => 'Installazione: assistenti';

  @override
  String get instanceTokenLabel => 'Token di accesso personale';

  @override
  String get instanceTokenReach =>
      'Un token di accesso personale apre tutto il vostro account Supabase finché esiste. La procedura guidata lo tiene solo in memoria e vi dice quando potete revocarlo.';

  @override
  String get instanceTokenRefused =>
      'Supabase ha rifiutato il token. Createne uno in Account → Access Tokens e incollatelo per intero.';

  @override
  String get instanceTurnOff => 'Disattiva';

  @override
  String get instanceTurnOn => 'Attiva per tutti gli spazi';

  @override
  String get instanceTurnOnConfirm =>
      'Gli assistenti diventano utilizzabili in ogni spazio che li offre. Puoi disattivarli in qualsiasi momento.';

  @override
  String get instanceUseExisting => 'Oppure usa un progetto esistente:';

  @override
  String get instanceUseHere => 'Usa questa istanza su questo dispositivo';

  @override
  String get instanceWizardTitle => 'Crea una nuova istanza';

  @override
  String get instanceYou => 'tu';

  @override
  String get instanceYouAreDelegate =>
      'Sei un delegato del proprietario dell\'istanza.';

  @override
  String get instanceYouAreOwner => 'Sei il proprietario dell\'istanza.';

  @override
  String invitationAlreadyMember(String workspace) {
    return 'Sei già membro di $workspace.';
  }

  @override
  String get invitationApprovalRequired =>
      'Un amministratore approva i nuovi membri prima che lo spazio si apra.';

  @override
  String get invitationApprovalUnknown =>
      'Non è noto se un amministratore debba approvare.';

  @override
  String get invitationBadServer =>
      'Il server di questo invito non è valido. Chiedi un nuovo invito.';

  @override
  String get invitationChangeAccount => 'Cambia account';

  @override
  String get invitationCheckAnother => 'Usa un altro invito';

  @override
  String get invitationCheckFailed =>
      'Impossibile controllare l’invito — stato non aggiornato. Non è cambiato nulla; riprova.';

  @override
  String get invitationContinue => 'Continua verso questo spazio';

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
  String get invitationEnvironmentProduction => 'Spazio di produzione';

  @override
  String get invitationEnvironmentTest => 'Spazio di prova';

  @override
  String get invitationExpired =>
      'Questo invito è scaduto. Chiedine uno nuovo a chi te l’ha inviato.';

  @override
  String invitationInvalid(String host) {
    return 'Nessuno spazio su $host conosce questo invito. Controllalo o chiedi all’organizzatore il link del suo server.';
  }

  @override
  String get invitationJoinButton => 'Aderisci allo spazio';

  @override
  String get invitationJoinUnconfirmed =>
      'Impossibile confermare il risultato. Aderisci di nuovo per controllare — l’invito non viene usato due volte.';

  @override
  String invitationJoiningAs(String account) {
    return 'Aderisci come $account';
  }

  @override
  String get invitationNewerVersion =>
      'Questo invito è stato creato da una versione più recente di DesKilo. Aggiorna l’app e riaprila.';

  @override
  String invitationOtherServer(String host) {
    return 'Questo invito è per un altro server: $host.';
  }

  @override
  String get invitationPasteButton => 'Incolla';

  @override
  String invitationPaused(String workspace) {
    return 'La tua adesione a $workspace è sospesa. Solo un amministratore dello spazio può riprenderla.';
  }

  @override
  String get invitationReviewButton => 'Controlla l’invito';

  @override
  String get invitationReviewTitle => 'Controlla prima di aderire';

  @override
  String get invitationRevoked =>
      'Questo codice dello spazio è stato sostituito. Chiedi quello attuale a chi te l’ha inviato.';

  @override
  String get invitationRoleAdmin => 'Ruolo offerto: amministratore';

  @override
  String get invitationRoleMember => 'Ruolo offerto: membro';

  @override
  String get invitationRoleUnknown => 'Ruolo offerto: non ancora noto';

  @override
  String invitationServerLabel(String label) {
    return 'Chiamato «$label» da chi l’ha condiviso';
  }

  @override
  String invitationServerRow(String host) {
    return 'Server: $host';
  }

  @override
  String get invitationTemplateHelp =>
      'Inviato quando inviti qualcuno via WhatsApp, SMS o condivisione. Lascia vuoto per usare il messaggio integrato nella lingua scelta. Tag disponibili:';

  @override
  String get invitationTemplateHint =>
      'Messaggio d\'invito personalizzato con i tag qui sopra…';

  @override
  String get invitationTemplateLanguage => 'Lingua del messaggio';

  @override
  String get invitationTemplateTitle => 'Messaggio d\'invito';

  @override
  String invitationThisDevice(String host) {
    return 'Questo dispositivo usa $host. Un invito viene controllato solo sul proprio server.';
  }

  @override
  String get invitationUnknownAnswer =>
      'Il server ha dato una risposta che questa versione dell’app non sa leggere. Non è cambiato nulla.';

  @override
  String get invitationUseServer => 'Usa questo server';

  @override
  String get invitationWrongAccount =>
      'Questo invito è già stato usato da un altro account. Se era per te, accedi con quell’account.';

  @override
  String get inviteAdminExplainer =>
      'Questo codice è monouso: ammette UNA persona come admin, poi scade. Consegnalo solo alla persona a cui è destinato.';

  @override
  String get inviteAdminNewCode => 'Nuovo codice amministratore';

  @override
  String get inviteAlsoProdSubtitle =>
      'La persona entra comunque nello spazio di prova. Il ruolo deve comunque permettere l\'accesso alla produzione.';

  @override
  String get inviteAlsoProdTitle => 'Dare anche accesso alla produzione';

  @override
  String get inviteCreateFailed =>
      'Impossibile creare l\'invito. Controlla la connessione e riprova.';

  @override
  String get inviteFirstNameLabel => 'Nome (facoltativo)';

  @override
  String get inviteLanguageLabel => 'Lingua del messaggio';

  @override
  String get inviteLastNameLabel => 'Cognome (facoltativo)';

  @override
  String get inviteOwnerNote =>
      'Non esiste un invito proprietario — solo un proprietario può concedere la proprietà, in Membri e piani.';

  @override
  String get invitePhoneLabel => 'Telefono (facoltativo, con prefisso)';

  @override
  String get inviteRoleAdmin => 'Invito amministratore';

  @override
  String get inviteRoleMember => 'Invito membro';

  @override
  String get inviteSectionTitle => 'Invita qualcuno';

  @override
  String get inviteSendFailed =>
      'Impossibile aprire l\'app di invio. Il messaggio è stato copiato al suo posto.';

  @override
  String get inviteViaShare => 'Condividi…';

  @override
  String get inviteViaSms => 'SMS';

  @override
  String get inviteViaWhatsapp => 'WhatsApp';

  @override
  String get invoiceAccountingExport => 'Esportazione contabile';

  @override
  String get invoiceAccountingExportEmpty =>
      'Niente da esportare per questo periodo.';

  @override
  String get invoiceAllCaughtUp => 'Tutto in ordine — niente da fatturare.';

  @override
  String get invoiceAlreadyInvoiced =>
      'Questo mese è già fatturato per questo membro.';

  @override
  String invoiceAnnexSummary(int movements, int checkIns) {
    return 'Allegato: $movements movimenti, $checkIns check-in';
  }

  @override
  String get invoiceBalance => 'Saldo';

  @override
  String get invoiceBuyerReference => 'Codice servizio';

  @override
  String get invoiceBuyerReferenceHint =>
      'Acquirente pubblico (Chorus Pro): il code service exécutant.';

  @override
  String invoiceCountShown(int count) {
    return '$count fatture';
  }

  @override
  String get invoiceCreate => 'Nuova fattura';

  @override
  String get invoiceDetailedToggle =>
      'Includi l\'allegato dettagliato (presenze, servizi, pagamenti)';

  @override
  String get invoiceDownload => 'Scarica PDF';

  @override
  String get invoiceEInvoiceAction => 'Fattura elettronica (XML)';

  @override
  String get invoiceEInvoiceBlockedTitle =>
      'Un validatore rifiuterebbe questo file:';

  @override
  String invoiceEInvoiceBusinessRoute(String channel, String format) {
    return 'Clienti business: inviala tramite $channel nel formato $format.';
  }

  @override
  String get invoiceEInvoiceDownload => 'Scarica fattura elettronica (XML)';

  @override
  String get invoiceEInvoiceExplain =>
      'La fattura EN 16931 leggibile dalle macchine — il file richiesto dalle amministrazioni e dai clienti business.';

  @override
  String get invoiceEInvoiceFixIdentity => 'Completare l\'identità legale';

  @override
  String invoiceEInvoiceFormatMismatch(String channel, String format) {
    return '$channel accetta solo $format: questo file EN 16931 serve per Peppol, la pubblica amministrazione e i clienti esteri — il resto lo converte la tua piattaforma.';
  }

  @override
  String get invoiceEInvoiceIncompleteTitle =>
      'Valido, ma i profili nazionali più severi chiedono anche:';

  @override
  String invoiceEInvoicePublicRoute(String channel) {
    return 'Clienti della pubblica amministrazione: $channel.';
  }

  @override
  String get invoiceEInvoiceReady =>
      'Pronto — questo file soddisfa la EN 16931.';

  @override
  String get invoiceEInvoiceShare => 'Condividi fattura elettronica (XML)';

  @override
  String get invoiceEInvoiceStaleIdentity =>
      'La tua identità legale ora è completa, ma questa fattura è stata firmata prima e conserva ciò con cui è stata emessa. Segnala come errata ed emetti una sostitutiva perché porti la nuova identità.';

  @override
  String get invoiceEInvoiceTransportAccredited =>
      'Una piattaforma accreditata trasporta la fattura e comunica i dati all\'amministrazione fiscale per te.';

  @override
  String get invoiceEInvoiceTransportBilateral =>
      'Nessun canale è imposto: e-mail, un portale o Peppol — come concordato con il cliente.';

  @override
  String get invoiceEInvoiceTransportClearance =>
      'La piattaforma nazionale riceve prima la fattura e la inoltra — inviarla direttamente al cliente non è possibile.';

  @override
  String get invoiceEInvoiceTransportPeppol =>
      'Un access point la consegna al cliente — nessuna piattaforma pubblica nel percorso.';

  @override
  String get invoiceExportAccountantCsv => 'CSV contabile';

  @override
  String get invoiceExportAuditTrail => 'Pista di controllo';

  @override
  String get invoiceExportBundle => 'Archivio dell\'esercizio (zip)';

  @override
  String get invoiceExportChoose => 'Esportazione contabile';

  @override
  String get invoiceExportDatev => 'DATEV (Buchungsstapel)';

  @override
  String get invoiceExportFec => 'FEC (Francia, richiesto in caso di verifica)';

  @override
  String get invoiceExportSafT => 'SAF-T (XML, internazionale)';

  @override
  String get invoiceExportSafTPt => 'SAF-T (Portogallo)';

  @override
  String get invoiceExportSage => 'Sage 50 (giornale di audit)';

  @override
  String get invoiceFacturXDownload => 'Scarica Factur-X (PDF)';

  @override
  String get invoiceFacturXExplain =>
      'Un unico file: la fattura che legge una persona, con l\'XML leggibile dalle macchine al suo interno. È ciò che si aspettano la maggior parte delle piattaforme.';

  @override
  String get invoiceFacturXShare => 'Condividi Factur-X (PDF)';

  @override
  String get invoiceFilterAllMembers => 'Tutti i membri';

  @override
  String get invoiceFilterAllMonths => 'Tutti i mesi';

  @override
  String get invoiceFilterClear => 'Azzera i filtri';

  @override
  String get invoiceFilterMonthLabel => 'Mese';

  @override
  String get invoiceFilterNoMatch =>
      'Nessuna fattura corrisponde a questi filtri.';

  @override
  String get invoiceGapBuyerVatIdFormat =>
      'La partita IVA del cliente non ha la forma del suo paese — verificala.';

  @override
  String get invoiceGapCreditNoteWithPayments =>
      'Questa nota di credito compensa anche dei pagamenti, cosa che una nota di credito EN 16931 non può esprimere. Emetti l\'accredito su un documento a parte.';

  @override
  String get invoiceGapMissingBuyerCountry => 'Manca il paese del cliente.';

  @override
  String get invoiceGapMissingBuyerVatId =>
      'Manca la partita IVA del cliente — una fattura in inversione contabile deve indicarla.';

  @override
  String get invoiceGapMissingExemptionReason =>
      'Manca il motivo per cui non si applica l\'IVA.';

  @override
  String get invoiceGapMissingLegalId =>
      'Manca il numero di registrazione (SIREN, HRB, CIF…) — nulla ti identifica sulla fattura.';

  @override
  String get invoiceGapMissingSellerCity =>
      'la città dell\'indirizzo dello spazio';

  @override
  String get invoiceGapMissingSellerCountry => 'Manca il paese dello spazio.';

  @override
  String get invoiceGapMissingSellerPostalCode =>
      'il codice postale dell\'indirizzo dello spazio';

  @override
  String get invoiceGapMissingVatId =>
      'Manca la partita IVA — un venditore esente deve indicarla.';

  @override
  String get invoiceGapNoChargeLines =>
      'Questa fattura non ha righe di addebito — il mese era interamente coperto dai pagamenti, quindi non c’è nulla da trasmettere.';

  @override
  String get invoiceGapPublicSectorRefs =>
      'Destinata a una piattaforma pubblica senza numero di impegno né codice servizio — Chorus Pro rifiuta la maggior parte dei depositi senza uno dei due.';

  @override
  String get invoiceGapVatNotSupported =>
      'Lo spazio applica l\'IVA ma questa fattura non porta alcuna aliquota — aggiungi le aliquote ed emettila di nuovo.';

  @override
  String invoiceHeldNote(String reason) {
    return 'Solleciti sospesi: $reason';
  }

  @override
  String get invoiceHoldAction => 'Sospendi i solleciti';

  @override
  String get invoiceHoldConfirm => 'Sospendi';

  @override
  String get invoiceHoldExplain =>
      'Nessun sollecito viene inviato per questa fattura, né a mano né automaticamente, finché la sospensione non viene revocata.';

  @override
  String get invoiceHoldFailed =>
      'Non è stato possibile modificare la sospensione dei solleciti. Riprova.';

  @override
  String get invoiceHoldNote => 'Nota (facoltativa)';

  @override
  String get invoiceHoldPlaced =>
      'I solleciti per questa fattura sono sospesi.';

  @override
  String get invoiceHoldReasonDispute => 'Il membro la contesta';

  @override
  String get invoiceHoldReasonIdentity =>
      'Persona sbagliata o errore d\'identità';

  @override
  String get invoiceHoldReasonInsolvency => 'Procedura di insolvenza';

  @override
  String get invoiceHoldReasonOther => 'Un\'altra ragione';

  @override
  String get invoiceHoldReleaseAction => 'Revoca la sospensione dei solleciti';

  @override
  String get invoiceHoldReleased =>
      'I solleciti per questa fattura possono riprendere.';

  @override
  String get invoiceHoldTitle => 'Perché sospendere i solleciti?';

  @override
  String get invoiceIntegrityAltered => 'Modificata dopo l\'emissione';

  @override
  String get invoiceIntegrityUnverifiable =>
      'Emessa prima dei controlli di integrità';

  @override
  String get invoiceIntegrityVerified => 'Integrità verificata';

  @override
  String get invoiceIssue => 'Emetti fattura';

  @override
  String get invoiceIssueAll => 'Fattura tutto';

  @override
  String invoiceIssueAllConfirm(int count, String month, String total) {
    return 'Emettere $count fatture per $month, $total in totale? Una fattura emessa non si modifica più — un errore si corregge con una sostituzione.';
  }

  @override
  String get invoiceIssueOne => 'Fattura';

  @override
  String get invoiceIssued => 'Fattura emessa.';

  @override
  String invoiceIssuedCount(int count) {
    return '$count fatture emesse.';
  }

  @override
  String invoiceIssuedPartial(int issued, int failed) {
    return '$issued emesse, $failed non riuscite.';
  }

  @override
  String get invoiceKindFull => 'Mese intero';

  @override
  String get invoiceKindSettlement => 'Fatture raggruppate';

  @override
  String get invoiceKindSubscription => 'Abbonamento, in anticipo';

  @override
  String get invoiceKindUsage => 'Gli extra del mese';

  @override
  String get invoiceLegalAssociationHint =>
      'Le clausole di mora, recupero crediti e sconto vengono stampate solo se compilate — sono obbligatorie solo tra professionisti.';

  @override
  String get invoiceLegalAssociationReasonHint =>
      'es. «TVA non applicable, art. 293 B du CGI» — o «Exonération de TVA, art. 261, 7-1° du CGI» per i servizi ai membri';

  @override
  String get invoiceLegalEscompteDefault =>
      'Nessuno sconto per pagamento anticipato.';

  @override
  String get invoiceLegalEscompteField => 'Sconto per pagamento anticipato';

  @override
  String get invoiceLegalFormField => 'Forma giuridica e capitale';

  @override
  String get invoiceLegalFormHint => 'es. SARL au capital de 7 500 €';

  @override
  String get invoiceLegalFormHintAssociation => 'es. Association loi 1901';

  @override
  String get invoiceLegalInsuranceField => 'Assicurazione professionale';

  @override
  String get invoiceLegalIntro =>
      'Le menzioni legali stampate su fatture e solleciti. Le clausole di pagamento vuote usano i testi legali predefiniti.';

  @override
  String get invoiceLegalKindAssociation => 'Associazione (non profit)';

  @override
  String get invoiceLegalKindCompany => 'Impresa';

  @override
  String get invoiceLegalKindField => 'Tipo di organizzazione';

  @override
  String get invoiceLegalLatePenaltyDefault =>
      'Penale di mora: tre volte il tasso di interesse legale.';

  @override
  String get invoiceLegalLatePenaltyField => 'Penale di mora';

  @override
  String get invoiceLegalPaymentTermsDefault => 'Pagamento al ricevimento.';

  @override
  String get invoiceLegalPaymentTermsField => 'Termini di pagamento';

  @override
  String get invoiceLegalRecoveryDefault =>
      'Indennità forfettaria per costi di recupero: 40 €.';

  @override
  String get invoiceLegalRecoveryField => 'Indennità di recupero crediti';

  @override
  String get invoiceLegalRegistrationField => 'Registro delle imprese';

  @override
  String get invoiceLegalRegistrationHint => 'es. RCS Saint-Brieuc 680 357 910';

  @override
  String get invoiceLegalRegistrationHintAssociation =>
      'es. RNA W123456789 · SIRET se assegnato';

  @override
  String get invoiceLegalSection => 'Menzioni di fatturazione';

  @override
  String get invoiceLegalSpecialField => 'Menzioni particolari';

  @override
  String get invoiceLineAdjustment => 'Rettifica';

  @override
  String get invoiceMatchAction => 'Segna come pagata';

  @override
  String get invoiceMatchCreditNote =>
      'Crea una nota di credito per l\'eccedenza';

  @override
  String get invoiceMatchForce => 'Accetta comunque (motivare)';

  @override
  String get invoiceMatchNoPayments =>
      'Nessun pagamento registrato da riconciliare — registralo o confermalo prima.';

  @override
  String get invoiceMatchNoteLabel => 'Nota';

  @override
  String get invoiceMatchNoteRequired => 'È richiesta una nota.';

  @override
  String invoiceMatchOver(String excess) {
    return 'Il membro ha pagato $excess in più.';
  }

  @override
  String get invoiceMatchPendingBadge => 'In attesa di convalida';

  @override
  String get invoiceMatchPickPayment => 'Seleziona il pagamento registrato';

  @override
  String invoiceMatchSummary(String amount, String date) {
    return 'Pagata $amount il $date';
  }

  @override
  String invoiceMatchUnder(String missing) {
    return 'Il membro ha pagato $missing in meno — accettare richiede una nota.';
  }

  @override
  String get invoiceMatched => 'Fattura riconciliata.';

  @override
  String get invoiceMatchedBadge => 'Pagata';

  @override
  String get invoiceMaturityReview =>
      'Per questa fattura non è stata registrata una scadenza concordata: nessun sollecito automatico finché non la verifichi.';

  @override
  String get invoiceMemberLabel => 'Membro';

  @override
  String get invoiceNoOpen => 'Nessuna fattura aperta.';

  @override
  String get invoiceNothingToInvoice =>
      'Nessun dato registrato per questo mese — niente da fatturare.';

  @override
  String invoiceOpenAge(int days) {
    return '$days giorni';
  }

  @override
  String get invoicePdfActivity => 'Movimenti e pagamenti';

  @override
  String get invoicePdfAnnex => 'Allegato — dettagli';

  @override
  String get invoicePdfAttendance => 'Presenze';

  @override
  String get invoicePdfBilledTo => 'Intestata a';

  @override
  String get invoicePdfBuyerReference => 'Servizio';

  @override
  String get invoicePdfCharges => 'Addebiti';

  @override
  String get invoicePdfCopy => 'Copia';

  @override
  String get invoicePdfCreditNote => 'Nota di credito';

  @override
  String get invoicePdfDescription => 'Descrizione';

  @override
  String get invoicePdfDueOn => 'Scadenza';

  @override
  String get invoicePdfIssuedBy => 'Emessa da';

  @override
  String get invoicePdfIssuedOn => 'Emessa il';

  @override
  String get invoicePdfPage => 'Pagina';

  @override
  String get invoicePdfPayments => 'Pagamenti';

  @override
  String get invoicePdfProforma => 'Proforma';

  @override
  String get invoicePdfPurchaseOrder => 'Riferimento d\'ordine';

  @override
  String get invoicePdfReplaces => 'Sostituisce';

  @override
  String get invoicePdfReserved => 'riservato';

  @override
  String invoicePdfSettledIn(String number) {
    return 'Raggruppata in $number';
  }

  @override
  String get invoicePdfSignature => 'Firma digitale (SHA-256)';

  @override
  String get invoicePdfTitle => 'Fattura';

  @override
  String get invoicePdfVoided => 'ERRATA — annullata il';

  @override
  String get invoicePickMember =>
      'Scegli un membro per vedere cosa ha registrato il suo mese.';

  @override
  String get invoiceProformaAction => 'Fattura proforma';

  @override
  String get invoiceProformaNothing =>
      'Nessun dato registrato per questo mese — nessuna proforma da inviare.';

  @override
  String get invoiceProformaShared => 'Proforma condivisa.';

  @override
  String get invoicePublicBuyer => 'Acquirente pubblico (Chorus Pro)';

  @override
  String get invoicePurchaseOrder => 'N. impegno';

  @override
  String get invoicePurchaseOrderHint =>
      'Acquirente pubblico (Chorus Pro): il numéro d\'engagement.';

  @override
  String get invoiceRefundButton => 'Registra il rimborso';

  @override
  String invoiceRefundExplain(String amount) {
    return 'Questa nota di credito significa che lo SPAZIO deve $amount al membro. Registra il rimborso versato — l\'importo viene imputato al saldo del membro e il documento si chiude come Rimborsata.';
  }

  @override
  String get invoiceRefundLabel => 'Da rimborsare';

  @override
  String get invoiceRefunded => 'Rimborso registrato.';

  @override
  String get invoiceRegisterAllYears => 'Tutti gli anni';

  @override
  String get invoiceRegisterAmount => 'Importo';

  @override
  String get invoiceRegisterDate => 'Data';

  @override
  String get invoiceRegisterName => 'Nome';

  @override
  String get invoiceRegisterTitle => 'Registro fatture';

  @override
  String get invoiceRegisterTotal => 'Totale';

  @override
  String get invoiceRegisterYear => 'Anno';

  @override
  String get invoiceRemainingLabel => 'Residuo';

  @override
  String get invoiceRemindAction => 'Invia un promemoria';

  @override
  String get invoiceReminded => 'Promemoria registrato.';

  @override
  String invoiceRemindedBadge(int count) {
    return 'Sollecitato ×$count';
  }

  @override
  String invoiceRemindedLast(String date) {
    return 'ultimo sollecito $date';
  }

  @override
  String invoiceReminderMessage(String number, String amount) {
    return 'Promemoria: fattura $number — saldo dovuto $amount.';
  }

  @override
  String get invoiceReminderNotSent =>
      'Non è stato inviato nulla, quindi non è stato registrato nulla.';

  @override
  String get invoiceReplaceAction => 'Emetti sostitutiva';

  @override
  String invoiceReplacedBy(String number) {
    return 'Sostituita da $number';
  }

  @override
  String get invoiceRunningMonth =>
      'Questo mese è ancora in corso — le sue voci possono cambiare, e un mese si fattura una sola volta.';

  @override
  String get invoiceSendAccepted => 'Inviata — la piattaforma l’ha accettata.';

  @override
  String invoiceSendAcceptedTest(String env) {
    return 'Invio di test accettato ($env).';
  }

  @override
  String get invoiceSendAction => 'Invia alla piattaforma governativa';

  @override
  String get invoiceSendCustomerAccepted =>
      'Inviata — il servizio del cliente l’ha accettata.';

  @override
  String get invoiceSendCustomerAction => 'Invia al servizio del cliente';

  @override
  String get invoiceSendRejected => 'La piattaforma l’ha rifiutata.';

  @override
  String get invoiceSendStatusAccepted => 'accettata';

  @override
  String get invoiceSendStatusFailed => 'non trasmessa';

  @override
  String get invoiceSendStatusRejected => 'rifiutata';

  @override
  String invoiceSentOn(String date, String status) {
    return 'Inviata il $date · $status';
  }

  @override
  String get invoiceSentTestChip => 'test';

  @override
  String get invoiceShare => 'Condividi PDF';

  @override
  String get invoiceShowCancelled => 'Mostra annullate';

  @override
  String get invoiceSortByMember => 'Per membro';

  @override
  String get invoiceSortByMonth => 'Per mese';

  @override
  String get invoiceSortNewest => 'Più recenti prima';

  @override
  String get invoiceSortTooltip => 'Ordina';

  @override
  String get invoiceStatusOpen => 'Aperta';

  @override
  String get invoiceStatusPartiallyPaid => 'Parzialmente pagata';

  @override
  String get invoiceStatusRefunded => 'Rimborsata';

  @override
  String get invoiceStatusRemainderCancelled =>
      'Parzialmente pagata · saldo annullato';

  @override
  String invoiceSummaryOpen(int count, String amount) {
    return '$count aperte · $amount in sospeso';
  }

  @override
  String invoiceSummaryToInvoice(int count) {
    return '$count da fatturare';
  }

  @override
  String invoiceSummaryToRefund(int count, String amount) {
    return '$count da rimborsare · $amount';
  }

  @override
  String get invoiceTabArchive => 'Archivio';

  @override
  String get invoiceTabOpen => 'Aperte';

  @override
  String get invoiceTabToInvoice => 'Da fatturare';

  @override
  String get invoiceTemplateBodyLabel =>
      'Banda del corpo (le righe della fattura)';

  @override
  String get invoiceTemplateDocInvoice => 'Fattura';

  @override
  String invoiceTemplateDocReminder(int level) {
    return 'Sollecito $level';
  }

  @override
  String get invoiceTemplateDocStatement => 'Estratto';

  @override
  String get invoiceTemplateDownload => 'Scarica PDF';

  @override
  String get invoiceTemplateFooterLabel =>
      'Piè di pagina (sotto i totali — condizioni di pagamento, menzioni legali)';

  @override
  String get invoiceTemplateHeaderLabel => 'Banda di intestazione';

  @override
  String get invoiceTemplateHint =>
      'Tre bande di report rese sul PDF — l\'XML della fattura elettronica non viene mai toccato. Condizioni e cicli Liquid, poi markup di riga:';

  @override
  String get invoiceTemplateIntroLabel =>
      'Introduzione (sopra il blocco del destinatario)';

  @override
  String get invoiceTemplateNoPreview =>
      'Emetti prima una fattura — l\'anteprima usa la più recente.';

  @override
  String get invoiceTemplatePresets => 'Modelli';

  @override
  String get invoiceTemplatePreview => 'Anteprima';

  @override
  String get invoiceTemplateQuickPreview => 'Anteprima rapida';

  @override
  String get invoiceTemplateReset => 'Ripristina il modello predefinito';

  @override
  String get invoiceTemplateSaved => 'Modello di fattura salvato.';

  @override
  String get invoiceTemplateShare => 'Condividi PDF';

  @override
  String get invoiceTemplateTitle => 'Modello PDF della fattura';

  @override
  String get invoiceVoidAction => 'Segna come errata';

  @override
  String invoiceVoidConfirm(String number) {
    return 'Segnare la fattura $number come errata? L\'operazione è irreversibile.';
  }

  @override
  String get invoiceVoided => 'Fattura contrassegnata come errata.';

  @override
  String get invoiceVoidedChip => 'Errata';

  @override
  String get invoiceWizardAction => 'Assistente di chiusura mensile';

  @override
  String get invoiceWriteoffButton => 'Annulla il saldo residuo';

  @override
  String get invoiceWriteoffExplain =>
      'Il saldo non pagato di questa fattura verrà annullato e la fattura archiviata come parzialmente pagata — una volta confermata la convalida. Fino ad allora resta aperta e dovuta.';

  @override
  String get invoiceWriteoffRequested =>
      'Annullamento richiesto — in attesa di convalida.';

  @override
  String get invoicesEmpty => 'Ancora nessuna fattura.';

  @override
  String get invoicesManage => 'Gestire le fatture';

  @override
  String get invoicesTitle => 'Fatture';

  @override
  String journeyClosedPaid(String date) {
    return 'Pagata il $date — chiusa';
  }

  @override
  String journeyClosedRefunded(String date) {
    return 'Rimborsata il $date — chiusa';
  }

  @override
  String journeyClosedRemainder(String date) {
    return 'Chiusa — residuo cancellato il $date';
  }

  @override
  String journeyClosedReplaced(String number) {
    return 'Annullata — sostituita da $number';
  }

  @override
  String get journeyClosedSettled =>
      'Raggruppata in un\'altra fattura — è quella a essere dovuta e sollecitata';

  @override
  String get journeyHowButton => 'Come funziona';

  @override
  String get journeyHowClosedMember =>
      'Il mese si legge saldato e la fattura resta leggibile per sempre: anteprima, PDF, condivisione.';

  @override
  String get journeyHowClosedWorkspace =>
      'Pagata, residuo cancellato o rimborsata: la fattura passa in archivio. Una fattura sbagliata è segnata come errata e sostituita — prima del pagamento, mai dopo.';

  @override
  String get journeyHowConfirmationMember =>
      'Niente da fare — a meno che lo spazio abbia registrato il pagamento per lui: allora lo conferma in Eventi.';

  @override
  String get journeyHowConfirmationWorkspace =>
      'Un altro admin conferma il pagamento dichiarato; l\'emittente abbina poi il pagamento registrato alla fattura (Segna come pagata) — una regola di validazione può affidare l\'abbinamento ai validatori. Pagato di più? Una nota di credito. Di meno? Parzialmente pagata, il resto dovuto fino al pagamento o alla cancellazione.';

  @override
  String get journeyHowIntro =>
      'Quattro passi, gli stessi per ogni fattura. Ognuno dice a chi tocca.';

  @override
  String get journeyHowIssuedMember =>
      'La trova nella vista Fatture: voci, saldo, scadenza.';

  @override
  String get journeyHowIssuedWorkspace =>
      'Emette la fattura dai dati tracciati del mese — numerata, firmata, immutabile — e condivide il PDF o invia la fattura elettronica.';

  @override
  String get journeyHowMemberLabel => 'Membro';

  @override
  String get journeyHowPaymentMember =>
      'Paga online (saldato subito) o con bonifico, poi registra il pagamento perché lo spazio lo sappia.';

  @override
  String get journeyHowPaymentWorkspace =>
      'Aspetta il denaro. Scaduto il termine invia i livelli di sollecito configurati — a mano o automaticamente.';

  @override
  String get journeyHowTitle => 'Come funziona la fatturazione';

  @override
  String get journeyHowWorkspaceLabel => 'Spazio';

  @override
  String journeyIssuerAdminConfirms(String name, String amount) {
    return '$name ha dichiarato un pagamento di $amount — un altro admin lo conferma in Eventi';
  }

  @override
  String journeyIssuerMatches(String amount) {
    return 'Un pagamento di $amount è registrato — abbinalo a questa fattura';
  }

  @override
  String journeyIssuerMemberConfirms(String name, String amount) {
    return 'È stato registrato un pagamento di $amount — $name lo conferma in Eventi';
  }

  @override
  String journeyIssuerMemberPays(String name, String amount, String date) {
    return 'In attesa del pagamento di $name: $amount — scadenza $date';
  }

  @override
  String journeyIssuerMemberPaysOverdue(String name, String amount, int days) {
    return '$name deve $amount — in ritardo di $days giorni';
  }

  @override
  String journeyIssuerMemberPaysRemainder(String name, String amount) {
    return '$name deve ancora $amount dopo un pagamento parziale';
  }

  @override
  String journeyIssuerRefunds(String name, String amount) {
    return 'Nota di credito — rimborsa $amount a $name e registralo';
  }

  @override
  String get journeyIssuerReplaces =>
      'Annullata — emetti la fattura sostitutiva';

  @override
  String journeyMemberConfirms(String amount) {
    return 'Tocca a te: conferma in Eventi il pagamento di $amount registrato per te';
  }

  @override
  String journeyMemberDeclared(String amount) {
    return 'Hai dichiarato $amount — lo spazio lo sta confermando';
  }

  @override
  String journeyMemberPays(String amount, String date) {
    return 'Tocca a te: paga $amount entro il $date';
  }

  @override
  String journeyMemberPaysOverdue(String amount, int days) {
    return 'Tocca a te: paga $amount — in ritardo di $days giorni';
  }

  @override
  String journeyMemberPaysRemainder(String amount) {
    return 'Tocca a te: paga il residuo di $amount';
  }

  @override
  String journeyMemberRefund(String amount) {
    return 'Lo spazio ti deve $amount — niente da pagare';
  }

  @override
  String journeyMemberRegistered(String amount) {
    return 'Il tuo pagamento di $amount è registrato — lo spazio lo abbina a questa fattura';
  }

  @override
  String get journeyMemberReplaces =>
      'Annullata — segue una fattura sostitutiva';

  @override
  String get journeyMemberValidators =>
      'Pagamento abbinato — in attesa di validazione';

  @override
  String get journeyMemberWriteoff =>
      'Lo spazio ha chiesto di cancellare il residuo — in attesa di validazione';

  @override
  String journeyOutstanding(String amount) {
    return '$amount in sospeso';
  }

  @override
  String journeyOverdueCount(int count) {
    return '$count in ritardo';
  }

  @override
  String get journeyPrimaryConfirmInEvents => 'Apri Eventi';

  @override
  String journeyPrimaryRemind(int level) {
    return 'Invia sollecito $level';
  }

  @override
  String get journeyStageClosed => 'Chiuse';

  @override
  String get journeyStageCollect => 'Da incassare';

  @override
  String get journeyStageConfirm => 'Da confermare';

  @override
  String get journeyStageIssue => 'Da emettere';

  @override
  String get journeyStageStripLabel =>
      'Il processo di fatturazione: emettere, incassare, confermare, chiudere';

  @override
  String get journeyStepClosed => 'Chiusa';

  @override
  String get journeyStepConfirmation => 'Conferma';

  @override
  String get journeyStepIssued => 'Emessa';

  @override
  String get journeyStepPayment => 'Pagamento';

  @override
  String get journeyTimelineTitle => 'Cronologia';

  @override
  String get journeyValidatorsMatch =>
      'Pagamento abbinato — in attesa della decisione dei validatori';

  @override
  String get journeyValidatorsWriteoff =>
      'Richiesta cancellazione del residuo — in attesa dei validatori';

  @override
  String get kioskBadgeConfirm => 'Conferma';

  @override
  String get kioskBadgeFieldLabel => 'Codice badge';

  @override
  String get kioskBadgeHint =>
      'Scansiona il QR del badge o digita il suo codice.';

  @override
  String get kioskBadgeHintNfc =>
      'Avvicina la tessera, scansiona il QR o digita il codice.';

  @override
  String get kioskBadgeRejected => 'Badge non riconosciuto.';

  @override
  String kioskBasis(String granularity, String hours) {
    return 'Regola: $granularity · oggi $hours';
  }

  @override
  String kioskBlockedContactHint(String name) {
    return 'Occupato da $name — puoi scrivergli dall\'app sul tuo telefono.';
  }

  @override
  String get kioskCheckIn => 'Check-in';

  @override
  String get kioskCheckInRightAway => 'Check-in immediato';

  @override
  String get kioskCheckInRightAwayHint =>
      'Sei qui: la prenotazione parte già registrata.';

  @override
  String get kioskCheckOut => 'Check-out';

  @override
  String get kioskClosedToday =>
      'Lo spazio è chiuso oggi — check-in e prenotazioni non sono possibili.';

  @override
  String get kioskConfirmAction => 'Conferma';

  @override
  String get kioskDone => 'Fatto — è tutto a posto.';

  @override
  String get kioskGateBody =>
      'Questo account è configurato come chiosco dello spazio. In modalità chiosco il tablet mostra solo la piantina per il check-in con badge — non si può aprire altro. Per uscire dalla modalità chiosco, riavvia il tablet.';

  @override
  String get kioskGateReject => 'Non ora — apri l\'app normalmente';

  @override
  String get kioskGateStart => 'Avvia la modalità chiosco';

  @override
  String get kioskGateTitle => 'Avviare la modalità chiosco?';

  @override
  String get kioskLevelButton => 'Questo piano';

  @override
  String get kioskNfcFailed =>
      'Il lettore RFID non si è avviato — riavvia l\'app e riprova.';

  @override
  String get kioskNfcOff =>
      'L\'NFC è disattivato nelle impostazioni Android di questo tablet — attivalo per leggere le carte RFID.';

  @override
  String get kioskNfcUnsupported =>
      'Questo tablet non ha un lettore NFC — scansiona il badge QR.';

  @override
  String get kioskNotCheckedIn =>
      'Nessun check-in attivo trovato — la planimetria potrebbe essersi appena aggiornata.';

  @override
  String get kioskPeriodCheckInHint =>
      'Fino a quando resti? Il check-in inizia adesso.';

  @override
  String get kioskPeriodReserveHint => 'Scegli il periodo: solo oggi.';

  @override
  String get kioskPresentBadge => 'Presenta il tuo badge';

  @override
  String get kioskPresentBadgeNext => 'Presenta il badge';

  @override
  String get kioskRejectAction => 'Rifiuta';

  @override
  String get kioskReserve => 'Prenota';

  @override
  String get kioskReserveAndCheckIn => 'Prenota e fai check-in';

  @override
  String get kioskRestOfDay => 'Resto della giornata';

  @override
  String get kioskRevertDesc =>
      'Questo profilo è configurato come chiosco dello spazio. Ripristinalo come membro normale per non vedere più la domanda chiosco all\'avvio.';

  @override
  String get kioskRevertDone => 'Questo profilo è di nuovo un membro normale.';

  @override
  String get kioskRevertTitle => 'Dispositivo chiosco';

  @override
  String get kioskScanQr => 'Scansiona il badge QR';

  @override
  String get kioskTapHint => 'Tocca un posto per fare check-in';

  @override
  String get languageNameCS => 'Ceco';

  @override
  String get languageNameDA => 'Danese';

  @override
  String get languageNameDE => 'Tedesco';

  @override
  String get languageNameEL => 'Greco';

  @override
  String get languageNameEN => 'Inglese';

  @override
  String get languageNameES => 'Spagnolo';

  @override
  String get languageNameFI => 'Finlandese';

  @override
  String get languageNameFR => 'Francese';

  @override
  String get languageNameHU => 'Ungherese';

  @override
  String get languageNameIT => 'Italiano';

  @override
  String get languageNameJA => 'Giapponese';

  @override
  String get languageNameNB => 'Norvegese';

  @override
  String get languageNameNL => 'Olandese';

  @override
  String get languageNamePL => 'Polacco';

  @override
  String get languageNamePT => 'Portoghese';

  @override
  String get languageNameRO => 'Rumeno';

  @override
  String get languageNameSV => 'Svedese';

  @override
  String get languageSystemDefault => 'Predefinita di sistema';

  @override
  String get languageTitle => 'Lingua';

  @override
  String get ledgerCategoryAdjustment => 'Rettifica';

  @override
  String get ledgerCategoryExpense => 'Rimborso spesa';

  @override
  String get ledgerCategoryOverage => 'Eccedenza';

  @override
  String get ledgerCategoryPayment => 'Pagamento';

  @override
  String get ledgerCategoryService => 'Servizio';

  @override
  String get ledgerCategorySubscription => 'Abbonamento';

  @override
  String get legalIdentityAssociationRegime =>
      'Un\'associazione senza attività commerciale non è soggetta a IVA: scegliete «Fuori campo IVA», non «Esente». Il regime di esenzione richiede una partita IVA che non avete, e la fattura elettronica verrebbe respinta. Fuori campo, è il vostro numero di registro a identificare l\'associazione.';

  @override
  String get legalIdentityCity => 'Città';

  @override
  String get legalIdentityExemptionReason =>
      'Motivo del mancato addebito dell\'IVA';

  @override
  String get legalIdentityIntro =>
      'Ciò che una fattura elettronica EN 16931 deve dichiarare su di te. Le fatture già emesse conservano l’identità con cui sono state firmate.';

  @override
  String get legalIdentityLegalId => 'Numero di registrazione';

  @override
  String get legalIdentityPostalCode => 'Codice postale';

  @override
  String get legalIdentityRegime => 'Regime IVA';

  @override
  String get legalIdentityRegimeExempt => 'Esente IVA (regime forfettario)';

  @override
  String get legalIdentityRegimeHint =>
      'Il regime decide quale numero richiede la norma: un numero di registrazione fuori campo IVA, una partita IVA se esente.';

  @override
  String get legalIdentityRegimeNotSubject =>
      'Fuori dal campo di applicazione dell\'IVA';

  @override
  String get legalIdentityRegimeVatRegistered => 'Soggetto IVA (applica IVA)';

  @override
  String get legalIdentitySaved => 'Identità legale salvata.';

  @override
  String get legalIdentityStreet => 'Via';

  @override
  String get legalIdentitySubtitle =>
      'Regime IVA, identificativi e le condizioni di pagamento predefinite dello spazio';

  @override
  String get legalIdentityTitle => 'Identità legale e fatturazione elettronica';

  @override
  String get legalIdentityVatId => 'Partita IVA';

  @override
  String get legalIdentityVatWarning =>
      'Questo spazio applica l\'IVA ma non è configurata alcuna aliquota: le fatture non espongono imposta e l\'export XML resta disattivato.';

  @override
  String get legendBlocked => 'Bloccata';

  @override
  String get legendClosed => 'Giorno chiuso';

  @override
  String get legendFree => 'Libera';

  @override
  String get legendMine => 'Mia';

  @override
  String get legendOccupied => 'Con check-in';

  @override
  String get legendProfileFull => 'Tutti gli stati';

  @override
  String get legendProfileFullDesc =>
      'Libero · Riservato · Presente · Il mio · Bloccato: si vede chi è arrivato.';

  @override
  String get legendProfileSimple => 'Meno stati';

  @override
  String get legendProfileSimpleDesc =>
      'Libero · Riservato · Il mio · Non disponibile. Un posto riservato e uno dove qualcuno è arrivato si assomigliano.';

  @override
  String get legendProfileTitle => 'Cosa distingue la pianta';

  @override
  String get legendReserved => 'Prenotata';

  @override
  String get legendUnavailable => 'Non disponibile';

  @override
  String get levelAssignMember => 'Per il membro';

  @override
  String get levelAssignMyself => 'Io stesso';

  @override
  String get levelBookableDesc =>
      'L\'intero piano può essere prenotato come un\'unica prenotazione.';

  @override
  String get levelBookableToggle => 'Prenotabile per intero';

  @override
  String get levelConflict => 'Il piano ha prenotazioni in quel periodo.';

  @override
  String get levelDetail => 'Intero piano';

  @override
  String get levelFeatureOff =>
      'Le prenotazioni di ufficio e piano sono disattivate nelle Funzionalità.';

  @override
  String get levelNotAllowed =>
      'Non sei autorizzato a prenotare un tavolo, ufficio o piano intero.';

  @override
  String get levelPermissionAllowed =>
      'Può prenotare un tavolo, ufficio o piano intero';

  @override
  String get levelPermissionDenied =>
      'Non può prenotare un tavolo, ufficio o piano intero';

  @override
  String get levelPermissionTile => 'Prenotazioni del piano';

  @override
  String get levelPriceLabel => 'Prezzo per mezza giornata';

  @override
  String get levelReorderStale =>
      'I livelli sono cambiati nel frattempo. Non è stato salvato nulla; viene mostrato l\'ordine attuale.';

  @override
  String get levelReserveButton => 'Prenota il piano';

  @override
  String get levelReserveTitle => 'Prenotare l\'intero piano';

  @override
  String get levelSupplementLabel => 'Prenotazioni del piano';

  @override
  String get libraryApplied => 'Modello applicato.';

  @override
  String libraryAppliedChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modifiche applicate.',
      one: '1 modifica applicata.',
    );
    return '$_temp0';
  }

  @override
  String get libraryApply => 'Applica a questo spazio';

  @override
  String libraryApplyChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Applica $count modifiche',
      one: 'Applica 1 modifica',
      zero: 'Niente selezionato',
    );
    return '$_temp0';
  }

  @override
  String get libraryApplyConfirmBody =>
      'La pianta viene aggiunta o aggiornata per nome, e le impostazioni del modello vengono unite. Nulla di ciò che avete già viene rimosso.';

  @override
  String libraryApplyConfirmTitle(String name) {
    return 'Applicare « $name »?';
  }

  @override
  String get libraryCarriesSettings => 'con le sue impostazioni';

  @override
  String libraryConfirmSensitive(String groups) {
    return 'Questo modifica: $groups. Applicare?';
  }

  @override
  String libraryCounts(int levels, int desks, int seats) {
    return '$levels livelli · $desks scrivanie · $seats posti';
  }

  @override
  String get libraryCustomizedHere => 'Personalizzato qui';

  @override
  String get libraryDelete => 'Elimina modello';

  @override
  String libraryDeleteConfirm(String name) {
    return 'Eliminare « $name »? Le persone con cui lo avete condiviso perdono l\'accesso.';
  }

  @override
  String get libraryEmpty =>
      'Ancora niente qui. Salvate questo spazio come modello, o aspettate che qualcuno ne condivida uno con voi.';

  @override
  String libraryFeatureNeeds(String feature, String prerequisite) {
    return '$feature richiede $prerequisite, che resta disattivato: non funzionerà ancora.';
  }

  @override
  String get libraryGroupAppearance => 'Aspetto';

  @override
  String get libraryGroupCalendarNavigation => 'Calendario e chiusure';

  @override
  String get libraryGroupDocumentsOperations => 'Documenti e funzionamento';

  @override
  String get libraryGroupForms => 'Moduli';

  @override
  String get libraryGroupHoursBooking => 'Orari e prenotazioni';

  @override
  String get libraryGroupPricingCredits => 'Prezzi e crediti';

  @override
  String get libraryGroupRolesAccess => 'Ruoli e accesso';

  @override
  String get libraryGroupSpace => 'Spazio e pianta';

  @override
  String get libraryGroupUnknown =>
      'Altro — questa versione non può applicarlo';

  @override
  String get libraryGroupWording => 'Terminologia';

  @override
  String get libraryInvitationTexts => 'Testi di invito';

  @override
  String libraryInvitationTextsHint(String tag) {
    return 'Solo testi scritti con segnaposto come $tag; un testo che nomina il tuo spazio o le sue persone viene rifiutato.';
  }

  @override
  String get libraryInvitationTextsRefused =>
      'Un testo di invito nomina ancora il tuo spazio o le sue persone. Sostituiscili con segnaposto nelle impostazioni di invito, oppure deseleziona i testi di invito.';

  @override
  String get libraryNeverDocumentDesign => 'Impaginazione dei documenti';

  @override
  String get libraryNeverDocumentLinks => 'Collegamenti ai vostri documenti';

  @override
  String get libraryNeverIdentity =>
      'Il vostro indirizzo, identificativi legali, menzioni legali e gruppo WhatsApp';

  @override
  String get libraryNeverInvitations => 'Testi di invito';

  @override
  String get libraryNeverPayment => 'Dati bancari';

  @override
  String get libraryNeverPublished => 'Mai pubblicato';

  @override
  String get libraryNeverSites => 'Le sedi e i loro indirizzi';

  @override
  String get libraryNotSupported =>
      'Questo modello non può essere applicato qui.';

  @override
  String get libraryNothingToApply =>
      'Tutto ciò che porta questo modello è già qui.';

  @override
  String get libraryPartial =>
      'Una parte di questo modello non può essere applicata qui e viene esclusa.';

  @override
  String libraryPlanNames(String names) {
    return 'Questi nomi viaggiano con la pianta: $names';
  }

  @override
  String get libraryPreviewChanges => 'Vedi le modifiche';

  @override
  String get libraryPreviewFailed =>
      'Non è stato possibile mostrare le modifiche. Non è stato applicato nulla.';

  @override
  String libraryPreviewTitle(String name) {
    return 'Cosa cambierebbe « $name »';
  }

  @override
  String libraryProcessOff(String feature) {
    return '$feature disattivata';
  }

  @override
  String libraryProcessOn(String feature) {
    return '$feature attiva';
  }

  @override
  String get libraryProcessTechnical => 'Tecnico';

  @override
  String get libraryPublishGroups => 'Cosa viaggia';

  @override
  String get libraryPublishNothing => 'Scegliete almeno un gruppo.';

  @override
  String get libraryReasonFeeSchedule =>
      'La vostra scala di commissioni verrebbe sostituita per intero.';

  @override
  String get librarySave => 'Salva questo spazio come modello';

  @override
  String get librarySaveDescription => 'Descrizione (facoltativa)';

  @override
  String get librarySaveName => 'Nome del modello';

  @override
  String get librarySaveTags => 'Etichette, separate da virgole';

  @override
  String get librarySaved => 'Salvato nei vostri modelli.';

  @override
  String librarySearchCapabilities(String capabilities) {
    return 'Modelli configurati per: $capabilities';
  }

  @override
  String get librarySearchHint => 'Cerca modelli';

  @override
  String librarySearchSuggestion(String word) {
    return 'Intendevi «$word»?';
  }

  @override
  String get librarySearchUnavailable =>
      'Non è stato possibile verificare le impostazioni dei modelli, quindi nessuno è mostrato come corrispondente. Riprova.';

  @override
  String get libraryShare => 'Condividi…';

  @override
  String get libraryShareAdd => 'Invita';

  @override
  String get libraryShareEmail => 'Indirizzo e-mail';

  @override
  String get libraryShareHint =>
      'Invitate via e-mail. L\'invito funziona non appena quell\'indirizzo accede — non viene rivelato se esiste già un account.';

  @override
  String get libraryShareNobody => 'Nessuno invitato per ora.';

  @override
  String libraryShareTitle(String name) {
    return 'Condividi « $name »';
  }

  @override
  String get libraryStartFrom => 'Partire dalla biblioteca';

  @override
  String get libraryStateAttention => 'Richiede attenzione';

  @override
  String get libraryStateChange => 'Cambia ciò che avete';

  @override
  String get libraryStateMatching => 'Già uguale';

  @override
  String get libraryStateNew => 'Nuovo';

  @override
  String get libraryTitle => 'Biblioteca degli spazi';

  @override
  String get libraryVisibility => 'Chi può vederlo';

  @override
  String get libraryVisibilityBuiltin => 'Integrato';

  @override
  String get libraryVisibilityPrivate => 'Solo io';

  @override
  String get libraryVisibilityPublic => 'Tutti (la biblioteca)';

  @override
  String get libraryVisibilityShared => 'Le persone che invito';

  @override
  String get libraryYours => 'I vostri modelli';

  @override
  String get linkedAccountsIntro =>
      'Accedi a questo account con un’identità collegata. I provider disponibili dipendono dal tuo server.';

  @override
  String get linkedAccountsLink => 'Collega';

  @override
  String get linkedAccountsLinkStarted =>
      'Continua nel browser per completare il collegamento.';

  @override
  String get linkedAccountsLinked => 'Collegato';

  @override
  String get linkedAccountsTitle => 'Account collegati';

  @override
  String get linkedAccountsUnlink => 'Scollega';

  @override
  String listCoversSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posti',
      one: '1 posto',
    );
    return '$_temp0';
  }

  @override
  String listCoversTables(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tavoli',
      one: '1 tavolo',
    );
    return '$_temp0';
  }

  @override
  String get listWholeReservable => 'Prenotabile per intero';

  @override
  String get localGapsTitle =>
      'Per completare la configurazione di questo spazio';

  @override
  String get localNeedsTitle =>
      'Li aggiungerai tu; un modello non li trasporta mai:';

  @override
  String get localSlotEinvoicePlatform =>
      'Il tuo account sulla piattaforma di fatturazione elettronica';

  @override
  String get localSlotLegalIdentity =>
      'La tua identità legale e il tuo indirizzo (per le fatture)';

  @override
  String localSlotNamedValidators(String type) {
    return 'Chi convalida: $type';
  }

  @override
  String get localSlotOpen => 'Configura';

  @override
  String get localSlotPaymentDetails =>
      'Come ti pagano i membri (coordinate bancarie)';

  @override
  String get localSlotPaymentProvider => 'Un fornitore di pagamenti online';

  @override
  String get localSlotRecommended => 'Consigliato';

  @override
  String get localSlotSite => 'Almeno una sede';

  @override
  String get managedAccessAdmins => 'Admin';

  @override
  String get managedAccessDefault => 'Ogni proprietario e ogni admin';

  @override
  String get managedAccessHint =>
      'Predefinito: ogni proprietario e ogni admin. Restringete per ruolo, per persona o entrambi. Il proprietario può sempre cambiare questa regola — altrimenti un profilo diventerebbe inamministrabile — ma accede ai dati solo se la regola lo nomina.';

  @override
  String get managedAccessOwners => 'Proprietari';

  @override
  String get managedAccessPeople => 'Persone indicate';

  @override
  String get managedAccessSaved => 'Regola salvata.';

  @override
  String get managedAccessTitle => 'Chi può amministrare questo profilo';

  @override
  String get managedProfileAdd => 'Aggiungi un profilo gestito';

  @override
  String get managedProfileChip => 'Gestito';

  @override
  String get managedProfileCreated => 'Profilo gestito creato';

  @override
  String get managedProfileEdit => 'Modifica identità';

  @override
  String get managedProfileHandOver => 'Consegna alla persona';

  @override
  String get managedProfileHandOverHint =>
      'Genera un codice personale legato a questo profilo. Chi lo riscatta prende il profilo — prenotazioni, fatture, abbonamento — appena approvi l\'adesione.';

  @override
  String get managedProfileIdentityUnavailable =>
      'Non è stato possibile leggere questi dati, quindi non c\'è ancora nulla da modificare. Non è stato cambiato nulla.';

  @override
  String get managedProfileIntro =>
      'Questa persona non ha ancora un account. Prenoti, fatturi e gestisci per lei; consegnale il profilo quando entra.';

  @override
  String get managedProfileRevoke => 'Revoca la consegna';

  @override
  String get managedProfileRevoked => 'Consegna revocata';

  @override
  String get managedProfileSaved => 'Identità salvata';

  @override
  String get managedProfileTitle => 'Profilo gestito';

  @override
  String get mcpApiReference => 'Riferimento API';

  @override
  String get mcpApiReferenceHint =>
      'Cosa può chiamare un assistente e come viene autorizzato';

  @override
  String get mcpAssistantsTitle => 'Assistenti';

  @override
  String get mcpAssistantsUnavailable =>
      'Impossibile caricare il tuo accesso agli assistenti. Riprova più tardi.';

  @override
  String get mcpCancel => 'Annulla';

  @override
  String get mcpConfirmAccept => 'Conferma';

  @override
  String get mcpConfirmApprove => 'La tua risposta: approva';

  @override
  String mcpConfirmClient(String client) {
    return 'Richiesto da: $client';
  }

  @override
  String get mcpConfirmConsequence =>
      'Confermando, l\'assistente può inviare questa esatta richiesta una sola volta. Le regole di validazione dello spazio restano valide.';

  @override
  String get mcpConfirmDecline => 'Rifiuta';

  @override
  String get mcpConfirmDeclined => 'Rifiutato. Non è stato fatto nulla.';

  @override
  String get mcpConfirmDone =>
      'Confermato. L\'assistente ora può inviare la richiesta.';

  @override
  String get mcpConfirmExpired =>
      'Questa richiesta è scaduta. Chiedi all\'assistente di inviarla di nuovo.';

  @override
  String mcpConfirmNewShare(String pct) {
    return 'Nuova quota di abbonamento: $pct %';
  }

  @override
  String mcpConfirmNewStatus(String status) {
    return 'Nuovo stato: $status';
  }

  @override
  String get mcpConfirmNotFound =>
      'Non c\'è nessuna richiesta di questo tipo per te.';

  @override
  String mcpConfirmPeriod(String period) {
    return 'Periodo: $period';
  }

  @override
  String get mcpConfirmRefuse => 'La tua risposta: rifiuta';

  @override
  String get mcpConfirmStale =>
      'Questa richiesta non corrisponde più ai dati attuali o al tuo accesso. Non è stato fatto nulla.';

  @override
  String get mcpConfirmTitle => 'Conferma una richiesta dell\'assistente';

  @override
  String get mcpConfirmUnavailable =>
      'Impossibile caricare questa richiesta. Riprova dal link.';

  @override
  String mcpConfirmWorkspace(String workspace) {
    return 'Spazio: $workspace';
  }

  @override
  String get mcpConnectedNoWorkspace =>
      'Nessuno spazio: questo assistente non può fare nulla qui.';

  @override
  String get mcpConnectedNone =>
      'Nessun assistente collegato. Collegane uno dall\'assistente stesso.';

  @override
  String get mcpConnectedTitle => 'Assistenti collegati';

  @override
  String get mcpConsentAlready =>
      'Questo assistente è già collegato. Ritorno all\'assistente.';

  @override
  String get mcpConsentApprove => 'Collega';

  @override
  String mcpConsentAsks(String client) {
    return '$client chiede di agire per te in Deskilo.';
  }

  @override
  String get mcpConsentChoose =>
      'Scegli ogni spazio e cosa l\'assistente può fare lì. Nulla è scelto al posto tuo.';

  @override
  String get mcpConsentConnected => 'Collegato. Ritorno all\'assistente.';

  @override
  String get mcpConsentDenied => 'Rifiutato. L\'assistente non ottiene nulla.';

  @override
  String get mcpConsentDeny => 'Rifiuta';

  @override
  String get mcpConsentFieldsExplain =>
      'Dettagli che può vedere anche qui. Lasciali deselezionati per mantenere le sue risposte minimizzate.';

  @override
  String get mcpConsentNoWorkspace =>
      'Nessuno dei tuoi spazi ammette assistenti. Non si può collegare nulla.';

  @override
  String get mcpConsentNotEligible =>
      'Questo database non ha ancora approvato gli assistenti per te. Chiedi l\'approvazione, poi collega di nuovo.';

  @override
  String get mcpConsentPartial =>
      'L\'assistente è stato approvato ma il collegamento non è ancora utilizzabile. Collega di nuovo dall\'assistente.';

  @override
  String get mcpConsentRequestEligibility => 'Chiedi l\'approvazione';

  @override
  String get mcpConsentRequested =>
      'Approvazione richiesta. Un amministratore del database la esaminerà.';

  @override
  String get mcpConsentTitle => 'Collega un assistente';

  @override
  String get mcpConsentUnavailable =>
      'Impossibile caricare questa richiesta di collegamento. Ricomincia dall\'assistente.';

  @override
  String get mcpDisclosureMaximumExplain =>
      'Il massimo che i proprietari di questo database possono far vedere agli assistenti. Non amplia mai la politica di uno spazio né il consenso di una persona.';

  @override
  String get mcpDisclosureMaximumLocked =>
      'Conferma con il tuo secondo fattore per vedere e modificare il massimo.';

  @override
  String get mcpDisclosureMaximumRefused =>
      'Il massimo non è stato salvato. Serve il tuo secondo fattore.';

  @override
  String get mcpDisclosureMaximumSave => 'Salva il massimo';

  @override
  String get mcpDisclosureMaximumSaved => 'Massimo salvato.';

  @override
  String get mcpDisclosureNoneAllowed =>
      'Questo database non consente di mostrare alcun dettaglio facoltativo agli assistenti.';

  @override
  String get mcpDisclosurePolicyExplain =>
      'Gli assistenti ricevono risposte minimizzate. Scegli i dettagli che possono vedere anche qui; ogni persona sceglie comunque per sé.';

  @override
  String get mcpDisclosurePreviewDetailed => 'Risposta dettagliata';

  @override
  String get mcpDisclosurePreviewMinimised => 'Risposta minimizzata';

  @override
  String get mcpDisclosurePreviewNote =>
      'Una risposta fittizia, per mostrare cosa vedrebbero gli assistenti.';

  @override
  String get mcpDisclosureTitle => 'Dettagli facoltativi';

  @override
  String get mcpDisclosureUnlock => 'Conferma';

  @override
  String get mcpDisconnect => 'Scollega';

  @override
  String get mcpDisconnectBody =>
      'L\'assistente perde l\'accesso a tutti gli spazi di questo database. Ciò che ha già letto non viene ripreso.';

  @override
  String mcpDisconnectTitle(String client) {
    return 'Scollegare $client?';
  }

  @override
  String get mcpEligibleExpired =>
      'La tua approvazione è scaduta. Richiedila di nuovo per continuare a usare gli assistenti.';

  @override
  String get mcpEligibleNoIdentity =>
      'La tua identità non è ancora confermata per gli assistenti su questa base.';

  @override
  String get mcpEligibleNot =>
      'Questo database non ha approvato gli assistenti per te.';

  @override
  String get mcpEligibleRequested =>
      'Hai chiesto l\'approvazione. Un amministratore del database la esaminerà.';

  @override
  String get mcpEligibleWithdraw =>
      'Rinuncia all\'accesso degli assistenti su questo database';

  @override
  String get mcpEligibleYes =>
      'Questo database ti consente di usare gli assistenti.';

  @override
  String get mcpFieldName => 'Nomi degli spazi e dei posti';

  @override
  String get mcpFieldNameSample => 'Scrivania finestra 12';

  @override
  String get mcpGroupFinancial => 'Richieste finanziarie';

  @override
  String get mcpGroupMembership => 'Richieste di iscrizione';

  @override
  String get mcpGroupOwn => 'Prenotazioni e conto personali';

  @override
  String get mcpGroupValidations => 'Convalide';

  @override
  String get mcpIdentityConflict =>
      'Un altro account detiene già questa identità qui: un amministratore della base può risolverlo.';

  @override
  String get mcpIdentityIneligible =>
      'Questo account non può ancora essere confermato: conferma prima il tuo indirizzo e-mail o accedi con un provider.';

  @override
  String get mcpNextAwaitEligibility =>
      'Prossimo passo: un amministratore del database decide la tua richiesta.';

  @override
  String get mcpNextConsent =>
      'Prossimo passo: collega un assistente dall\'assistente stesso e approva questo spazio di lavoro.';

  @override
  String get mcpNextLinkGoogle =>
      'Gli assistenti usano il tuo accesso Google. Collega prima Google a questo account; senza, l\'account non può usare assistenti.';

  @override
  String get mcpNextLinkIdentity =>
      'Prossimo passo: conferma la tua identità per gli assistenti su questa base, con un tocco qui sotto.';

  @override
  String get mcpNextOwnerExposes =>
      'Prossimo passo: il titolare dello spazio di lavoro offre operazioni agli assistenti.';

  @override
  String get mcpNextReady =>
      'Pronto: un assistente collegato può agire per te in questo spazio di lavoro, entro quanto hai approvato.';

  @override
  String get mcpNextRequestEligibility =>
      'Prossimo passo: chiedi l\'approvazione agli amministratori di questo database.';

  @override
  String get mcpNextRoleDenied =>
      'Il tuo ruolo qui non lascia alcuna operazione. Il titolare dello spazio di lavoro decide cosa può fare ogni ruolo.';

  @override
  String get mcpNextSignInGoogle =>
      'Gli assistenti usano il tuo accesso Google. Accedi con Google per continuare.';

  @override
  String get mcpNextUnavailable =>
      'Il server non ha potuto rispondere. Non si presume nulla; riprova più tardi.';

  @override
  String get mcpOpAvailability => 'Vedere i posti liberi';

  @override
  String get mcpOpCapabilities => 'Vedere cosa può fare lì';

  @override
  String get mcpOpCheckIn => 'Registrare il tuo arrivo';

  @override
  String get mcpOpCheckOut => 'Registrare la tua uscita';

  @override
  String get mcpOpCreateReservation => 'Prenotare un posto per te';

  @override
  String get mcpOpGetValidation => 'Leggere una richiesta di convalida';

  @override
  String get mcpOpInvoiceIssue => 'Emettere una fattura';

  @override
  String get mcpOpInvoiceVoid => 'Annullare una fattura';

  @override
  String get mcpOpListWorkspaces => 'Vedere quali spazi può usare';

  @override
  String get mcpOpMemberStatus => 'Modificare lo stato di un membro';

  @override
  String get mcpOpMyInvoices => 'Vedere le tue fatture';

  @override
  String get mcpOpMyReservations => 'Vedere le tue prenotazioni';

  @override
  String get mcpOpMyStatement => 'Vedere il tuo estratto conto';

  @override
  String get mcpOpPendingValidations =>
      'Vedere le richieste di convalida in sospeso';

  @override
  String get mcpOpRefund => 'Rimborsare una fattura';

  @override
  String get mcpOpReservationDeletion =>
      'Chiedere l\'eliminazione di una prenotazione';

  @override
  String get mcpOpRespond => 'Rispondere a una richiesta di validazione';

  @override
  String get mcpOpSubscription =>
      'Modificare la quota di abbonamento di un membro';

  @override
  String get mcpOpUpdateReservation => 'Modificare le tue prenotazioni';

  @override
  String get mcpOverviewTitle => 'Altri database collegati';

  @override
  String get mcpOverviewUnavailable =>
      'Non è stato possibile interrogarlo ora.';

  @override
  String get mcpPolicyBroadening =>
      'Gli assistenti già collegati non ricevono i servizi aggiunti: ogni persona deve aggiungerli quando si ricollega.';

  @override
  String get mcpPolicyCeiling => 'Dati su cui un assistente può agire';

  @override
  String get mcpPolicyCeilingOwn => 'Solo i propri dati';

  @override
  String get mcpPolicyCeilingWorkspace => 'Tutto lo spazio';

  @override
  String get mcpPolicyConflict =>
      'Il salvataggio è stato rifiutato. Controlla le impostazioni attuali e salva di nuovo.';

  @override
  String get mcpPolicyEnabled => 'Offri i servizi per assistenti';

  @override
  String get mcpPolicyExplain =>
      'Scegli cosa possono fare gli assistenti in questo spazio. Un membro ha comunque bisogno dell\'approvazione di questo database, del ruolo adatto, e deve scegliere questo spazio quando collega il suo assistente.';

  @override
  String get mcpPolicyFeatureOff =>
      'Gli assistenti sono disattivati nelle funzioni di questo spazio. Puoi comunque restringere o disattivare i servizi qui sotto.';

  @override
  String get mcpPolicySave => 'Salva';

  @override
  String get mcpPolicySaved => 'Salvato.';

  @override
  String get mcpPolicyStale =>
      'Qualcuno ha modificato queste impostazioni nel frattempo. Controlla quelle attuali e salva di nuovo.';

  @override
  String get mcpPolicySwitched =>
      'Hai cambiato spazio. Riapri questa pagina per modificare l\'altro spazio.';

  @override
  String get mcpPolicyTitle => 'Accesso degli assistenti';

  @override
  String get mcpPolicyUnavailable =>
      'Impossibile caricare le impostazioni degli assistenti. Riprova più tardi.';

  @override
  String get mcpRemoveWorkspace => 'Rimuovi questo spazio';

  @override
  String get mcpReviewApprove => 'Approva';

  @override
  String get mcpReviewChanged =>
      'Questa richiesta è cambiata o un altro amministratore ha deciso prima. Non è stato fatto nulla.';

  @override
  String get mcpReviewDone => 'Decisione registrata.';

  @override
  String get mcpReviewEmpty => 'Nessuna richiesta in attesa.';

  @override
  String get mcpReviewExplain =>
      'Approvare consente a una persona di collegare assistenti su questo database, negli spazi i cui proprietari lo permettono. Non concede iscrizione né ruolo.';

  @override
  String get mcpReviewNotAdmin =>
      'Solo gli amministratori di questo database esaminano le approvazioni.';

  @override
  String get mcpReviewRefused => 'La decisione è stata rifiutata.';

  @override
  String get mcpReviewReject => 'Rifiuta';

  @override
  String get mcpReviewSecondFactor =>
      'Quel database richiede il tuo secondo fattore nella propria sessione. Non è stato deciso nulla.';

  @override
  String get mcpReviewTitle => 'Approvazioni degli assistenti';

  @override
  String get mcpReviewUnavailable =>
      'Impossibile caricare le richieste. Un esame richiede il tuo secondo fattore; riprova.';

  @override
  String get mcpStateAfterPrevious => 'Dopo il passaggio precedente';

  @override
  String get mcpStateAllowed => 'Consentito';

  @override
  String get mcpStateApproved => 'Approvata';

  @override
  String get mcpStateAvailable => 'Raggiungibile';

  @override
  String get mcpStateCurrent => 'Dato';

  @override
  String get mcpStateDenied => 'Nulla per il tuo ruolo';

  @override
  String get mcpStateDisabled => 'Nulla offerto';

  @override
  String get mcpStateExposed => 'Operazioni offerte';

  @override
  String get mcpStateGoogleMissing => 'Google non collegato';

  @override
  String get mcpStateGoogleOtherSession => 'Accesso effettuato in altro modo';

  @override
  String get mcpStateGoogleReady => 'Accesso con Google effettuato';

  @override
  String get mcpStateIncompatible => 'Versione incompatibile';

  @override
  String get mcpStateMissing => 'Non dato';

  @override
  String get mcpStateNotRequested => 'Non richiesta';

  @override
  String get mcpStatePending => 'In attesa di una decisione';

  @override
  String get mcpStateRevoked => 'Scaduta o ritirata';

  @override
  String get mcpStateUnavailable => 'Sconosciuto';

  @override
  String get mcpStateUnlinked => 'Non confermata';

  @override
  String get mcpStateVerified => 'Verificata';

  @override
  String get mcpStatusBackend => 'Server';

  @override
  String get mcpStatusConfirmIdentity => 'Conferma la mia identità';

  @override
  String get mcpStatusConsent => 'Il tuo consenso';

  @override
  String get mcpStatusEligibility => 'Approvazione del database';

  @override
  String get mcpStatusExposure => 'Offerta dello spazio di lavoro';

  @override
  String get mcpStatusGoogle => 'Accesso con Google';

  @override
  String get mcpStatusIdentity => 'Identità per gli assistenti';

  @override
  String get mcpStatusLinkGoogle => 'Collega Google';

  @override
  String get mcpStatusOpenLinkedAccounts => 'Apri gli account collegati';

  @override
  String get mcpStatusRole => 'Il tuo ruolo';

  @override
  String get mcpStatusSignInGoogle => 'Accedi con Google';

  @override
  String get mcpStatusTitle => 'A che punto sei qui';

  @override
  String get mcpUsageApplied => 'Applicate';

  @override
  String mcpUsageLastUsed(String when) {
    return 'Ultimo uso $when';
  }

  @override
  String get mcpUsageMineTitle => 'Il tuo uso degli assistenti oggi';

  @override
  String get mcpUsageNone =>
      'Nessun assistente ha ancora usato il tuo accesso.';

  @override
  String get mcpUsagePending => 'In attesa di convalida';

  @override
  String get mcpUsageRefusals => 'Rifiutate';

  @override
  String get mcpUsageRequests => 'Richieste';

  @override
  String get mcpUsageUnavailable =>
      'Non è stato possibile caricare l\'utilizzo.';

  @override
  String get mcpUsageWorkspaceTitle => 'Uso degli assistenti, ultimi 30 giorni';

  @override
  String get meAccountInMe => 'Il mio account è in Io';

  @override
  String get meAccountInMeBody =>
      'Foto, lingua, tema e accessi sono tuoi in ogni spazio.';

  @override
  String get meAddressSaveFailed =>
      'Impossibile salvare il tuo indirizzo. Riprova.';

  @override
  String get meCreateSpace => 'Crea uno spazio';

  @override
  String get meFindSpace => 'Trova uno spazio';

  @override
  String get meGroupInstallations => 'Installazioni collegate';

  @override
  String get meGroupProfile => 'Il mio profilo';

  @override
  String get meGroupWorkspaces => 'I miei spazi di lavoro';

  @override
  String get meHeaderOwned => 'Il tuo account · appartiene solo a te';

  @override
  String get meHomeTitle => 'Home';

  @override
  String get meJoinSpace => 'Entra con un codice';

  @override
  String get meLeaveAction => 'Lascia questo spazio';

  @override
  String get meLeaveBody =>
      'Smetti di essere membro. Prenotazioni, fatture e messaggi restano nello spazio. Per cancellare anche i tuoi dati, usa Privacy.';

  @override
  String meLeaveDone(String name) {
    return 'Hai lasciato $name.';
  }

  @override
  String get meLeaveFailed => 'Impossibile lasciare lo spazio. Riprova.';

  @override
  String get meLeaveOwner =>
      'I proprietari cedono lo spazio prima di lasciarlo';

  @override
  String meLeaveTitle(String name) {
    return 'Lasciare $name?';
  }

  @override
  String meLinkedOpen(String host) {
    return 'Apri su $host';
  }

  @override
  String meLinkedOpenBody(String host) {
    return 'Questo spazio si trova su $host. L\'app lavora con un server alla volta: aprirlo passa a quel server e ti chiede di accedere lì.';
  }

  @override
  String meLinkedPendingOn(String host) {
    return 'In attesa di approvazione · $host';
  }

  @override
  String meLinkedUnavailable(String host) {
    return '$host non ha risposto: questo elenco potrebbe essere incompleto.';
  }

  @override
  String get meManageSpaces => 'Gestisci i miei spazi';

  @override
  String get meMySpaces => 'I miei spazi';

  @override
  String get meNoSpaceBody =>
      'Trovane uno vicino a te, entra con un codice di invito o creane uno tuo.';

  @override
  String get meNoSpaceTitle => 'Non sei ancora in nessuno spazio';

  @override
  String get meSectionMine => 'Cronologia e dati personali';

  @override
  String get meSpaceException => 'In questo spazio';

  @override
  String get meSpaceLastUsed => 'Ultimo usato';

  @override
  String get meSpacePending => 'In attesa di approvazione';

  @override
  String get meTabDiscover => 'Scopri';

  @override
  String get meTabHome => 'Home';

  @override
  String get meTabMe => 'Io';

  @override
  String get meTabMessages => 'Messaggi';

  @override
  String get meWhereSpacesLive => 'Dove si trovano i miei spazi';

  @override
  String get memberAccountTitle => 'Il mio account';

  @override
  String get memberAllAdmins => 'tutti gli admin';

  @override
  String get memberApprove => 'Approva l\'adesione';

  @override
  String memberBadgesTitle(String name) {
    return 'Badge — $name';
  }

  @override
  String get memberBadgesTooltip => 'Badge';

  @override
  String get memberCoOwnerChip => 'Comproprietario';

  @override
  String get memberCoOwnerPassiveChip => 'Successore';

  @override
  String get memberContactHeading => 'Contatti';

  @override
  String get memberHomeSiteDefault => 'Indirizzo dello spazio';

  @override
  String get memberHomeSiteLabel => 'Sede di riferimento';

  @override
  String memberInvoiceOpen(String amount) {
    return '$amount da pagare';
  }

  @override
  String get memberInvoicePaid => 'Pagata';

  @override
  String get memberInvoiceVoided => 'Annullata';

  @override
  String get memberKioskLabel => 'Chiosco';

  @override
  String get memberMakeAdmin => 'Dai il ruolo Amministratore';

  @override
  String get memberMakeKiosk => 'Trasforma in chiosco';

  @override
  String get memberMakeMember => 'Revoca il ruolo Amministratore';

  @override
  String get memberMessagesAction => 'Messaggi';

  @override
  String get memberMoneySettled => 'Nulla in sospeso.';

  @override
  String get memberMoneyUnavailable =>
      'Impossibile caricare le finanze. Trascina per aggiornare.';

  @override
  String get memberMonthInProgress => 'Questo mese';

  @override
  String memberMoreInvoices(int count) {
    return '+$count altre';
  }

  @override
  String get memberNoActions =>
      'Solo il proprietario dello spazio può modificare questo membro.';

  @override
  String get memberNoSubscription => 'Senza abbonamento';

  @override
  String get memberNoSubscriptionPaygHint =>
      'Senza abbonamento non è possibile con il pagamento a consumo: scegliete prima blocca o un pacchetto.';

  @override
  String get memberNoteDelete => 'Elimina';

  @override
  String get memberNoteDeleteConfirm =>
      'Eliminare questo messaggio? Non si può annullare.';

  @override
  String get memberNoteDeleteNotMine =>
      'Solo il mittente può ritirare un messaggio.';

  @override
  String get memberNoteDeleteRead =>
      'Già letto: questo messaggio non può più essere ritirato.';

  @override
  String get memberNoteDeleted => 'Messaggio eliminato.';

  @override
  String get memberNoteHint => 'Il tuo messaggio';

  @override
  String memberNoteReceived(String name) {
    return 'Messaggio da $name';
  }

  @override
  String get memberNoteReply => 'Rispondi';

  @override
  String get memberNoteSend => 'Invia';

  @override
  String get memberNoteSent => 'Notifica inviata.';

  @override
  String memberNoteTitle(String name) {
    return 'Notifica $name';
  }

  @override
  String memberNoteTo(String name) {
    return 'A $name';
  }

  @override
  String get memberNoteToAllAdmins => 'A tutti gli admin';

  @override
  String get memberNotifyAction => 'Invia notifica';

  @override
  String get memberNotifyAllAdmins => 'Notifica tutti gli admin';

  @override
  String get memberNumberLabel => 'N. socio';

  @override
  String get memberOriginDelegated => 'Profilo creato da un amministratore';

  @override
  String get memberOriginFounder => 'Ha fondato questo spazio';

  @override
  String get memberOriginHeading => 'Come è iniziata questa adesione';

  @override
  String get memberOriginInvited => 'Si è unito su invito';

  @override
  String get memberOveragePolicyLabel => 'Quando i giorni finiscono';

  @override
  String get memberOveragePolicyTooltip => 'Consumo extra';

  @override
  String get memberPageAddService => 'Aggiungi un servizio';

  @override
  String memberPageCheckedIn(String seat, String time) {
    return 'Check-in · $seat · dalle $time';
  }

  @override
  String get memberPageEmailAction => 'E-mail';

  @override
  String get memberPageGroupAccess => 'Badge e accesso';

  @override
  String get memberPageGroupBilling => 'Fatturazione';

  @override
  String get memberPageGroupBooking => 'Regole di prenotazione';

  @override
  String get memberPageGroupMembership => 'Iscrizione';

  @override
  String get memberPageLevelTitle => 'Prenotazioni di uno spazio intero';

  @override
  String get memberPageManageHeading => 'Gestisci';

  @override
  String get memberPageNeverSeen => 'Mai visto';

  @override
  String memberPageNext(String label) {
    return 'Prossima: $label';
  }

  @override
  String get memberPageNone => 'Nessuno';

  @override
  String get memberPageNowHeading => 'In questo momento';

  @override
  String memberPageReservedNow(String seat, String time) {
    return 'Prenotato ora · $seat · fino alle $time';
  }

  @override
  String memberPageSince(String date) {
    return 'Membro dal $date';
  }

  @override
  String get memberPageStatusActive => 'Attivo';

  @override
  String memberPageWorkspaceDefaultValue(int count) {
    return 'Predefinito dello spazio ($count)';
  }

  @override
  String memberPageYou(String name) {
    return '$name (tu)';
  }

  @override
  String get memberPause => 'Sospendi l\'iscrizione';

  @override
  String get memberPayments => 'Pagamenti';

  @override
  String memberPlanShare(String pct) {
    return 'Piano $pct%';
  }

  @override
  String get memberReactivate => 'Riattiva l\'iscrizione';

  @override
  String get memberRejectJoin => 'Rifiuta l\'adesione';

  @override
  String memberReservationLimitChip(int n) {
    return 'max $n';
  }

  @override
  String get memberReservationLimitCustom => 'Personalizzato (1–100)';

  @override
  String get memberReservationLimitExplainer =>
      'Quante prenotazioni aperte questo membro può avere contemporaneamente.';

  @override
  String get memberReservationLimitLabel => 'Limite di prenotazioni';

  @override
  String get memberReservationLimitNone => 'Nessun limite';

  @override
  String get memberReservationLimitTooltip => 'Limite di prenotazioni';

  @override
  String get memberRoleAdmin => 'Amministratore';

  @override
  String get memberRoleChangeRequested =>
      'Cambio di ruolo inviato per la convalida.';

  @override
  String get memberRoleMember => 'Membro';

  @override
  String get memberRoleOwner => 'Proprietario';

  @override
  String get memberRolesAdd => 'Aggiungi un ruolo';

  @override
  String get memberRolesNone =>
      'Nessun ruolo: tutto ciò che può fare un membro.';

  @override
  String get memberRolesTitle => 'Ruoli';

  @override
  String get memberRolesWhatTheyCanDo => 'Cosa può fare qui questa persona';

  @override
  String get memberSendAgreement => 'Invia l\'accordo finanziario';

  @override
  String memberSimultaneousLimitChip(int n) {
    return '$n alla volta';
  }

  @override
  String get memberSimultaneousLimitDefault => 'Valore dello spazio';

  @override
  String get memberSimultaneousLimitExplainer =>
      'Quante prenotazioni questo membro può avere nello stesso periodo. Non impostato: vale il valore predefinito dello spazio.';

  @override
  String get memberSimultaneousLimitLabel => 'Prenotazioni simultanee';

  @override
  String get memberStatusActive => 'Attivo';

  @override
  String get memberStatusExited => 'Uscito';

  @override
  String get memberStatusPaused => 'In pausa';

  @override
  String get memberStatusPending => 'In attesa';

  @override
  String get memberSubscriptionCustom => 'Personalizzato (1–100)';

  @override
  String get memberSubscriptionLabel => 'Abbonamento';

  @override
  String get memberUnmakeKiosk => 'Riporta il chiosco a membro';

  @override
  String get memberVatTreatmentExplainer =>
      'Chi è questo membro ai fini IVA: la regola automatica (inversione contabile per un\'impresa di un altro Stato UE), IVA nazionale in ogni caso, inversione contabile, fuori UE o un acquirente esente con il motivo stampato sulla fattura.';

  @override
  String get memberVatTreatmentLabel => 'Trattamento IVA';

  @override
  String get membersInvite => 'Invita un membro';

  @override
  String get membersPlanNone => 'Nessun piano';

  @override
  String get membersTitle => 'Membri e piani';

  @override
  String get messageSearchGroups => 'Gruppi';

  @override
  String get messageSearchHint => 'Membri, gruppi, messaggi';

  @override
  String get messageSearchMessages => 'Messaggi';

  @override
  String get messageSearchNothing => 'Nessun risultato.';

  @override
  String get messageSearchPeople => 'Membri';

  @override
  String get messageSearchPrompt =>
      'Cerca membri, gruppi e ciò che è stato detto.';

  @override
  String get messageSearchTitle => 'Cerca';

  @override
  String get messagesEmpty => 'Ancora nessuna conversazione.';

  @override
  String get messagesTitle => 'Messaggi';

  @override
  String get messengerContextAccount => 'Da persona a persona';

  @override
  String messengerContextInquiryIn(String space) {
    return 'Richiesta a $space';
  }

  @override
  String messengerContextInquiryOut(String space) {
    return 'La tua richiesta a $space';
  }

  @override
  String messengerContextSpace(String space) {
    return 'In $space';
  }

  @override
  String get messengerDelete => 'Elimina messaggio';

  @override
  String get messengerDeleteConfirm =>
      'Eliminare questo messaggio per tutti i partecipanti alla conversazione?';

  @override
  String get messengerDeleted => 'Messaggio eliminato.';

  @override
  String get messengerDelivered => 'Consegnato';

  @override
  String messengerEventCaptured(String actor) {
    return 'Screenshot di $actor';
  }

  @override
  String messengerEventDeleted(String actor) {
    return 'Eliminato da $actor';
  }

  @override
  String messengerEventForwarded(String actor, String target) {
    return 'Inoltrato da $actor a $target';
  }

  @override
  String messengerEventForwardedFrom(String actor, String context) {
    return 'Scritto originariamente da $actor in $context';
  }

  @override
  String messengerEventForwardedPrivate(String actor) {
    return 'Inoltrato da $actor in una conversazione personale';
  }

  @override
  String messengerEventOther(String event, String actor) {
    return '$event · $actor';
  }

  @override
  String messengerEventRead(String actor) {
    return 'Letto da $actor';
  }

  @override
  String messengerEventSent(String actor) {
    return 'Inviato da $actor';
  }

  @override
  String get messengerForward => 'Inoltra';

  @override
  String get messengerForwardExplain =>
      'Tutti i partecipanti della conversazione originale, per primo l’autore, vengono informati di chi l’ha inoltrato, quando e dove.';

  @override
  String get messengerForwardLocked =>
      'L’autore ha bloccato l’inoltro di questo messaggio.';

  @override
  String get messengerForwardNoTargets =>
      'Nessun’altra conversazione su questo server in cui inoltrare.';

  @override
  String get messengerForwardTitle => 'Inoltra a';

  @override
  String messengerForwarded(String target) {
    return 'Inoltrato a $target.';
  }

  @override
  String messengerForwardedFrom(String context, String author) {
    return 'Inoltrato da $context · scritto da $author';
  }

  @override
  String get messengerHistory => 'Cosa è successo';

  @override
  String get messengerHistoryEmpty =>
      'Ancora nulla di registrato per questo messaggio.';

  @override
  String get messengerHostsIntro =>
      'Il tuo messaggio viene letto da questi gestori dello spazio:';

  @override
  String get messengerHostsNone =>
      'In questo spazio nessuno risponde ai messaggi al momento.';

  @override
  String messengerInboxUnavailable(String servers) {
    return 'Non raggiungibile al momento: $servers. Le sue conversazioni mancano da questo elenco.';
  }

  @override
  String get messengerInquiriesEmpty => 'Ancora nessuna richiesta.';

  @override
  String get messengerInquiriesTitle => 'Richieste';

  @override
  String get messengerInquiryClose => 'Chiudi richiesta';

  @override
  String get messengerInquiryClosed => 'Richiesta chiusa.';

  @override
  String messengerInquiryFrom(String name) {
    return 'Da $name';
  }

  @override
  String get messengerInquirySend => 'Invia richiesta';

  @override
  String get messengerLock => 'Blocca l’inoltro';

  @override
  String get messengerMessageActions => 'Azioni sul messaggio';

  @override
  String messengerNoticeCaptured(String actor) {
    return '$actor ha fatto uno screenshot di questa conversazione.';
  }

  @override
  String messengerNoticeForwarded(String actor, String target) {
    return '$actor ha inoltrato un messaggio di questa conversazione a $target.';
  }

  @override
  String messengerNoticeForwardedPrivate(String actor) {
    return '$actor ha inoltrato un messaggio di questa conversazione in una conversazione personale.';
  }

  @override
  String messengerOnServer(String server) {
    return 'su $server';
  }

  @override
  String get messengerRead => 'Letto';

  @override
  String get messengerRefusedClosed => 'Questa richiesta è chiusa.';

  @override
  String get messengerRefusedForwardingOff =>
      'Questo spazio non consente di inoltrare i suoi messaggi.';

  @override
  String get messengerRefusedLimit => 'Troppi in una volta. Attendi un minuto.';

  @override
  String get messengerRefusedTooLong =>
      'Questo messaggio è troppo lungo per quella conversazione.';

  @override
  String get messengerRefusedUnavailable =>
      'Questo spazio non accetta richieste al momento.';

  @override
  String get messengerUnlock => 'Consenti l’inoltro';

  @override
  String get messengerWriteToHosts => 'Scrivi ai gestori';

  @override
  String get mfaCode => 'Codice a sei cifre';

  @override
  String get mfaEnroll =>
      'Scansiona questo codice con un\'app di autenticazione, o inserisci la chiave, poi digita le sei cifre mostrate.';

  @override
  String get mfaTitle => 'Conferma con la tua app di autenticazione';

  @override
  String get mfaVerify => 'Verifica';

  @override
  String get mfaWrong =>
      'Quel codice non è stato accettato. Prova quello attuale.';

  @override
  String get moneyAmountLabel => 'Importo';

  @override
  String get moneyBalance => 'Saldo';

  @override
  String get moneyBaseFee => 'Abbonamento base';

  @override
  String get moneyCredits => 'Pagamenti e crediti';

  @override
  String get moneyDescriptionLabel => 'Descrizione';

  @override
  String get moneyDocumentLibrary => 'Libreria dei documenti';

  @override
  String moneyDueIn(int days) {
    return 'Scade tra $days giorni';
  }

  @override
  String get moneyExpenseCategoryLabel => 'Categoria';

  @override
  String get moneyExpensePending =>
      'Spesa inviata — in attesa di approvazione.';

  @override
  String get moneyFaceDocuments => 'Documenti';

  @override
  String get moneyFaceInvoices => 'Fatture';

  @override
  String get moneyFacePayments => 'Pagamenti';

  @override
  String get moneyFaceStatement => 'Estratto';

  @override
  String get moneyFaceUsage => 'Utilizzo';

  @override
  String get moneyLedgerEmpty => 'Ancora nessuna registrazione.';

  @override
  String get moneyLedgerHeader => 'Registro';

  @override
  String get moneyMyAgreement => 'Le mie condizioni';

  @override
  String get moneyNoInvoicesYet =>
      'Nessuna fattura ancora — lo spazio fattura il mese una volta chiuso.';

  @override
  String get moneyNoteLabel => 'Nota (facoltativa)';

  @override
  String get moneyNothingOpen => 'Niente di aperto — sei in regola.';

  @override
  String moneyOpenInvoicesSummary(int count, String amount) {
    return '$count aperte · $amount dovuti';
  }

  @override
  String get moneyOpenInvoicesTitle => 'Fatture aperte';

  @override
  String moneyOverage(int count) {
    return 'Eccedenza ($count mezze giornate extra)';
  }

  @override
  String moneyOverdueBanner(int count, String amount) {
    return '$count scadute — $amount da regolare';
  }

  @override
  String moneyOverdueBy(int days) {
    return 'Scaduta da $days giorni';
  }

  @override
  String get moneyPayNow => 'Paga ora';

  @override
  String get moneyPaymentDateLabel => 'Data del pagamento';

  @override
  String get moneyPaymentPending =>
      'Pagamento inviato — in attesa di conferma.';

  @override
  String get moneyPaymentPeriodLabel => 'Si applica a';

  @override
  String get moneyRecordPayment => 'Registra un pagamento';

  @override
  String moneyRemindedTimes(int count) {
    return 'Sollecitata ×$count';
  }

  @override
  String get moneySectionDocuments => 'Documenti';

  @override
  String get moneySectionPay => 'Pagare';

  @override
  String get moneySectionRequests => 'Richieste';

  @override
  String get moneyStatementOpen => 'Aperto';

  @override
  String get moneyStatementPdf => 'Estratto del mese (PDF)';

  @override
  String get moneyStatementSettled => 'Saldato';

  @override
  String get moneySubmitExpense => 'Invia una spesa';

  @override
  String get moneySubmitPayment => 'Invia per conferma';

  @override
  String moneySubscriptionPct(int pct) {
    return 'Abbonamento $pct %';
  }

  @override
  String moneyUsage(int used, int included) {
    return '$used mezze giornate usate su $included';
  }

  @override
  String moneyUsageUnlimited(int used) {
    return '$used mezze giornate usate';
  }

  @override
  String monthFreeCount(int free, int total) {
    return '$free/$total';
  }

  @override
  String get myBadgeTitle => 'Il mio badge';

  @override
  String get navigationClassic =>
      'Classica: la barra inferiore e il pulsante rotondo';

  @override
  String get navigationDefault => 'Predefinito per questo dispositivo';

  @override
  String get navigationMenu => 'Menu: l\'hamburger, come sul web';

  @override
  String get navigationTitle => 'Navigazione';

  @override
  String negotiationActiveSince(String month) {
    return 'Le tue condizioni si applicano da $month.';
  }

  @override
  String get negotiationCardTitle => 'I miei prezzi negoziati';

  @override
  String get negotiationDefaultColumn => 'Tariffa';

  @override
  String get negotiationDiscount => 'Sconto sui supplementi';

  @override
  String get negotiationFee => 'Quota mensile';

  @override
  String get negotiationItems => 'Servizi e pacchetti';

  @override
  String get negotiationItemsHint =>
      'Un prezzo unitario per questo membro; vuoto mantiene il catalogo.';

  @override
  String get negotiationKeepCurrent => 'Mantieni attuale';

  @override
  String get negotiationMineColumn => 'Le mie';

  @override
  String get negotiationNote => 'Nota';

  @override
  String get negotiationOccupation => 'Occupazione';

  @override
  String get negotiationOccupationHint =>
      'La quota di giorni di apertura inclusa ogni mese; applicata al membro una volta convalidata.';

  @override
  String get negotiationOnTariff => 'Sei alla tariffa dello spazio.';

  @override
  String get negotiationOverage => 'Eccedenza per mezza giornata';

  @override
  String get negotiationPending => 'Delle condizioni attendono convalida.';

  @override
  String get negotiationPendingBadge => 'in attesa di convalida';

  @override
  String negotiationPercent(int value) {
    return '$value %';
  }

  @override
  String get negotiationProposeHint =>
      'Lascia un campo vuoto per mantenere la tariffa. Le condizioni passano dalla convalida prima di applicarsi.';

  @override
  String get negotiationProposeTitle => 'Negoziazione di prezzo';

  @override
  String get negotiationProposed =>
      'Condizioni proposte — in attesa di convalida.';

  @override
  String get negotiationReadOnly => 'Sola lettura';

  @override
  String get negotiationSubmit => 'Proponi per la convalida';

  @override
  String get negotiationValidFrom => 'Si applica da';

  @override
  String get negotiationWhoCanSee => 'Chi può vederlo';

  @override
  String get newConversationGroupSwitch => 'Gruppo';

  @override
  String get newConversationNoMembers => 'Ancora nessun altro qui.';

  @override
  String get newConversationSearch => 'Cerca membri';

  @override
  String get newConversationStart => 'Avvia chat';

  @override
  String get newConversationTapToOpen =>
      'Tocca una persona per aprire la chat; attiva Gruppo per sceglierne più di una.';

  @override
  String get newConversationTitle => 'Nuova conversazione';

  @override
  String get newGroupCreate => 'Crea gruppo';

  @override
  String get newGroupName => 'Nome del gruppo';

  @override
  String get newGroupNameTaken =>
      'Esiste già un gruppo con questo nome. Scegline un altro.';

  @override
  String get newMemberDefaultsConfigured => 'Con cosa inizia chi si unisce.';

  @override
  String get newMemberDefaultsTitle => 'Nuovi membri';

  @override
  String get newMemberDefaultsUnavailable =>
      'Non è stato possibile leggerli ora. Il salvataggio li lascia invariati.';

  @override
  String get newMemberDefaultsUnset =>
      'Niente scelto: i nuovi membri iniziano al 100 % e le prenotazioni si bloccano una volta esaurito il monte ore.';

  @override
  String get newMemberOverageBlocked => 'Bloccato una volta esaurito';

  @override
  String get newMemberOveragePackage => 'Deve acquistare un pacchetto';

  @override
  String get newMemberOveragePayg => 'Paga a consumo';

  @override
  String get newMemberSubscription => 'Abbonamento';

  @override
  String get newMemberSubscriptionLess => 'Abbonamento più piccolo';

  @override
  String get newMemberSubscriptionMore => 'Abbonamento più grande';

  @override
  String newMemberSubscriptionValue(int percent) {
    return '$percent %';
  }

  @override
  String get nfcConfigChecking => 'Verifica…';

  @override
  String get nfcConfigDeviceOff =>
      'L\'NFC è disattivato nelle impostazioni Android di questo dispositivo — attivalo per leggere le carte RFID.';

  @override
  String get nfcConfigDeviceReady => 'NFC disponibile e attivo';

  @override
  String get nfcConfigDeviceStatus => 'Questo dispositivo';

  @override
  String get nfcConfigDeviceUnavailable =>
      'Nessun NFC qui — serve un dispositivo Android con NFC attivo (gli iPad non hanno NFC). I badge QR funzionano comunque.';

  @override
  String get nfcConfigEnable => 'Abilita il check-in con badge NFC';

  @override
  String get nfcConfigEnableDesc =>
      'Mostra l\'opzione di avvicinare la tessera su chioschi e nel gestore badge.';

  @override
  String get nfcConfigIntro =>
      'I membri fanno check-in a un chiosco a parete avvicinando una tessera RFID/NFC. Registra la tessera di ogni membro in Membri e piani; al chiosco la avvicinano per prenotare o fare check-in.';

  @override
  String get nfcConfigTitle => 'Badge RFID / NFC';

  @override
  String get noteRefAlert => 'Avviso';

  @override
  String noteRefFilterCount(int shown, int total) {
    return '$shown su $total';
  }

  @override
  String get noteRefFilterEmpty => 'Nessun risultato.';

  @override
  String get noteRefFilterLabel => 'Filtra';

  @override
  String get noteRefGone => 'Questa prenotazione non esiste più.';

  @override
  String get noteRefInvoice => 'Fattura';

  @override
  String get noteRefNoReservations =>
      'Nessuna prenotazione futura da collegare.';

  @override
  String get noteRefNone => 'Niente da referenziare per ora.';

  @override
  String get noteRefPayment => 'Pagamento';

  @override
  String get noteRefPickAlert => 'Quale avviso?';

  @override
  String get noteRefPickInvoice => 'Quale fattura?';

  @override
  String get noteRefPickPayment => 'Quale pagamento?';

  @override
  String get noteRefPickValidation => 'Quale convalida?';

  @override
  String get noteRefRefund => 'Rimborso';

  @override
  String get noteRefReservation => 'Collega una prenotazione';

  @override
  String get noteRefSpace => 'Collega uno spazio';

  @override
  String get noteRefValidation => 'Convalida';

  @override
  String get noteRefWholeLevel => 'piano intero';

  @override
  String get notesFilterEmpty => 'Nessun messaggio non letto — tutto in pari.';

  @override
  String get notesFilterRead => 'Letti';

  @override
  String get notesFilterUnread => 'Non letti';

  @override
  String get notifCategoryCheckIns => 'Check-in';

  @override
  String get notifCategoryMembers => 'Membri';

  @override
  String get notifCategoryMoney => 'Finanze';

  @override
  String get notifGroupBy => 'Raggruppa per';

  @override
  String get notifGroupByDate => 'Data';

  @override
  String get notifGroupByType => 'Tipo';

  @override
  String get notifGroupByUser => 'Membro';

  @override
  String get notifSortByDate => 'Ordina per data';

  @override
  String get notifUngroup => 'Rimuovi raggruppamento';

  @override
  String get notificationsSystemOff =>
      'Android sta bloccando le notifiche di DesKilo';

  @override
  String get notificationsSystemOffHint =>
      'Consentile in Impostazioni di sistema → App → DesKilo → Notifiche — il badge dell\'icona ne ha bisogno.';

  @override
  String get numberSequenceDateNone => 'Nessuna';

  @override
  String get numberSequenceDatePart => 'Data';

  @override
  String get numberSequenceDateRemovalBlocked =>
      'Sono già stati emessi numeri con la data. Toglierla potrebbe ripeterne uno: cambia anche il prefisso o il suffisso.';

  @override
  String get numberSequenceDateYear => 'Anno';

  @override
  String get numberSequenceDateYearMonth => 'Anno-mese';

  @override
  String get numberSequenceDigits => 'Cifre';

  @override
  String get numberSequenceGapless => 'Senza buchi — garantito';

  @override
  String get numberSequenceJournalCreditNote => 'Note di credito';

  @override
  String get numberSequenceJournalInvoice => 'Fatture';

  @override
  String get numberSequenceJournalMember => 'Soci';

  @override
  String get numberSequenceJournalPayment => 'Pagamenti';

  @override
  String get numberSequenceJournalVatDeclaration => 'Dichiarazioni IVA';

  @override
  String get numberSequenceNext => 'Prossimo numero';

  @override
  String get numberSequencePrefix => 'Prefisso';

  @override
  String get numberSequenceReset => 'Azzeramento';

  @override
  String get numberSequenceResetLimited =>
      'Un numero ricomincia al massimo tanto spesso quanto mostra la sua data, altrimenti ristamperebbe un numero già emesso.';

  @override
  String get numberSequenceResetMonthly => 'Ogni mese';

  @override
  String get numberSequenceResetNever => 'Mai';

  @override
  String get numberSequenceResetWasInvalid =>
      'Questa serie ricominciava più spesso di quanto mostri la data. Salva per mantenere un azzeramento che non ripete alcun numero.';

  @override
  String get numberSequenceResetYearly => 'Ogni anno';

  @override
  String get numberSequenceSaved => 'Serie salvata.';

  @override
  String get numberSequenceSuffix => 'Suffisso';

  @override
  String get numberSequencesIntro =>
      'Una serie per registro, senza buchi: il numero è preso nel database al momento dell’emissione, e un documento che fallisce non consuma nulla. Cambiare il formato non tocca mai un documento già emesso.';

  @override
  String get numberSequencesSubtitle =>
      'Come sono numerate fatture e note di credito.';

  @override
  String get numberSequencesTitle => 'Serie di numerazione';

  @override
  String get occurrenceAdded => 'Aggiunto alle tue spese.';

  @override
  String get occurrenceConfirm => 'Conferma questa spesa';

  @override
  String get occurrenceReasonLabel => 'Perché differisce (obbligatorio)';

  @override
  String get occurrenceReasonMissing =>
      'Un importo diverso richiede una spiegazione.';

  @override
  String get occurrenceRejected =>
      'I validatori l’hanno rifiutata — correggi l’importo o la descrizione e reinvia.';

  @override
  String get occurrenceResend => 'Reinvia in validazione';

  @override
  String occurrenceScheduledAmount(Object amount) {
    return 'Validato: $amount';
  }

  @override
  String get occurrenceSentForValidation =>
      'Inviato ai validatori — conterà una volta confermato.';

  @override
  String get officeSupplementLabel => 'Prenotazioni di ufficio';

  @override
  String get onboardingConfirmIntro => 'Ecco cosa verrà creato:';

  @override
  String get onboardingCreateButton => 'Crea spazio';

  @override
  String get onboardingCreateTab => 'Crea uno spazio';

  @override
  String get onboardingCreateWithoutTemplate => 'Crea senza modello';

  @override
  String get onboardingCurrencyUnknown =>
      'Inserisci un codice valuta supportato, ad esempio EUR';

  @override
  String get onboardingDiscardDraft =>
      'I dati inseriti andranno persi. Questo non annulla una richiesta già inviata.';

  @override
  String get onboardingIntentChanged =>
      'La richiesta precedente potrebbe essere già stata creata. Riprovala esattamente come inviata prima di cambiare qualcosa.';

  @override
  String get onboardingIntentResumed =>
      'Una creazione precedente potrebbe essere andata a buon fine. Riprova per verificare la stessa richiesta.';

  @override
  String get onboardingJoinButton => 'Unisciti';

  @override
  String get onboardingJoinTab => 'Unisciti a uno spazio';

  @override
  String get onboardingRetryAsSent => 'Riprova com\'era';

  @override
  String get onboardingScanButton => 'Scansiona codice QR';

  @override
  String get onboardingShapeLabel => 'Cosa creare';

  @override
  String get onboardingShapePair => 'Una coppia collegata di prova e reale';

  @override
  String get onboardingShapeReal => 'Uno spazio reale';

  @override
  String get onboardingShapeRealHint =>
      'Per l\'attività reale: le fatture emesse sono dovute.';

  @override
  String get onboardingShapeTest => 'Uno spazio di prova';

  @override
  String get onboardingShapeTestHint =>
      'Sicuro per provare: ogni schermata e documento indica che è una prova. Nessuna fatturazione reale.';

  @override
  String get onboardingStartEmpty => 'Spazio vuoto';

  @override
  String get onboardingStartEmptyDesc =>
      'Disegnate la vostra pianta su una tela vuota.';

  @override
  String get onboardingStartFrom => 'Partire da';

  @override
  String get onboardingStepConfirm => 'Conferma';

  @override
  String get onboardingStepName => 'Nome';

  @override
  String get onboardingStepWhere => 'Dove';

  @override
  String get onboardingSummaryBillingOff =>
      'Nessuna fatturazione reale: i documenti sono contrassegnati come prova.';

  @override
  String get onboardingSummaryBillingOn =>
      'La fatturazione reale è possibile: le sue fatture sono dovute.';

  @override
  String onboardingSummaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Crea $count spazi',
      one: 'Crea uno spazio',
    );
    return '$_temp0';
  }

  @override
  String onboardingSummaryServer(String host) {
    return 'Sul server $host';
  }

  @override
  String onboardingTemplateSetsUp(String groups) {
    return 'Configura: $groups';
  }

  @override
  String get onboardingTemplatesFailedEmpty =>
      'Non è stato possibile caricare i modelli, quindi questo spazio partirebbe vuoto. Torni indietro per riprovare.';

  @override
  String get onboardingTitle => 'Benvenuto su DesKilo';

  @override
  String get onboardingUnconfirmed =>
      'Impossibile confermare il risultato. I dati inseriti sono conservati. Riprova per verificare la stessa richiesta.';

  @override
  String get onboardingUseSuggested => 'Usa le impostazioni proposte';

  @override
  String get onboardingWithTwin => 'Crea la coppia sviluppo e produzione';

  @override
  String get onboardingWithTwinHint =>
      'Due spazi con lo stesso nome: uno per provare, uno reale. Entrambi sono tuoi.';

  @override
  String get overagePolicyBlocked => 'Blocca ulteriori prenotazioni';

  @override
  String get overagePolicyPackage => 'Richiedi l\'acquisto di un pacchetto';

  @override
  String get overagePolicyPayg => 'Addebita l\'extra (a consumo)';

  @override
  String get payConfigConfigured => 'Configurato';

  @override
  String get payConfigIntro =>
      'Inserisci ogni fornitore di pagamento da offrire. Le chiavi sono salvate in sicurezza sul server e non vengono più mostrate.';

  @override
  String get payConfigNotConfigured => 'Non configurato';

  @override
  String get payConfigOpen => 'Configura';

  @override
  String get payConfigRemove => 'Rimuovi';

  @override
  String get payConfigRemoved => 'Rimosso.';

  @override
  String get payConfigSaved => 'Salvato.';

  @override
  String get payConfigSecretSet => 'Impostato — lascia vuoto per mantenere';

  @override
  String get payConfigTitle => 'Pagamenti online';

  @override
  String get payFieldApiKey => 'Chiave API';

  @override
  String get payFieldClientId => 'Client ID';

  @override
  String get payFieldEnv => 'Ambiente';

  @override
  String get payFieldReturnUrl => 'URL di ritorno';

  @override
  String get payFieldSecret => 'Secret';

  @override
  String get payFieldSecretKey => 'Chiave segreta';

  @override
  String get payFieldWebhookId => 'ID webhook';

  @override
  String get payFieldWebhookSecret => 'Segreto di firma webhook';

  @override
  String get payOnlineButton => 'Paga online';

  @override
  String get payOnlineChooseTitle => 'Paga online';

  @override
  String get payOnlineDiagHint => 'Sul server manca questa configurazione:';

  @override
  String get payOnlineDiagTitle => 'Pagamenti online — non configurati';

  @override
  String payOnlineFailedDetail(
    String reference,
    String amount,
    String provider,
  ) {
    return 'Il pagamento $reference ($amount tramite $provider) non è stato completato — nulla è stato accreditato; il saldo resta dovuto.';
  }

  @override
  String get payOnlineFailedTitle => 'Pagamento online non riuscito';

  @override
  String get payOnlineNotConfigured =>
      'I pagamenti online non sono ancora configurati. Chiedi al proprietario dello spazio.';

  @override
  String payOnlinePendingDetail(
    String reference,
    String amount,
    String provider,
  ) {
    return 'Il pagamento $reference ($amount tramite $provider) non è ancora stato confermato dal fornitore, quindi il saldo mostra ancora quanto dovuto. Cita questo riferimento se non va a buon fine.';
  }

  @override
  String get payOnlinePendingTitle => 'Pagamento online in sospeso';

  @override
  String get paymentAccountNumberLabel => 'Numero di conto';

  @override
  String get paymentBankCodeLabel => 'Codice banca';

  @override
  String get paymentBankNameLabel => 'Nome della banca';

  @override
  String get paymentBicLabel => 'BIC / SWIFT';

  @override
  String get paymentCopied => 'Copiato.';

  @override
  String get paymentInstructionsHelper =>
      'Mostrate ai membri su un estratto non saldato. Lascia vuoto per non mostrare nulla.';

  @override
  String get paymentInstructionsIbanCopied => 'IBAN copiato.';

  @override
  String get paymentInstructionsIbanTitle => 'IBAN';

  @override
  String get paymentInstructionsLydiaLabel =>
      'Numero di telefono o nome utente Lydia';

  @override
  String get paymentInstructionsPaypalLabel => 'Link o nome PayPal.me';

  @override
  String get paymentInstructionsReferenceLabel => 'Indicazione della causale';

  @override
  String get paymentInstructionsTitle => 'Istruzioni di pagamento';

  @override
  String get paymentInstructionsValueCopied => 'Copiato negli appunti.';

  @override
  String get paymentInstructionsWeroLabel => 'Numero di telefono Wero';

  @override
  String get paymentInstructionsWiseLabel => 'Wisetag o link di pagamento Wise';

  @override
  String get paymentMethodBankTransfer => 'Bonifico';

  @override
  String get paymentMethodCard => 'Carta';

  @override
  String get paymentMethodCash => 'Contanti';

  @override
  String get paymentMethodLydia => 'Lydia';

  @override
  String get paymentMethodOther => 'Altro';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTwint => 'TWINT';

  @override
  String get paymentMethodWero => 'Wero';

  @override
  String get paymentMethodWise => 'Wise';

  @override
  String get paymentMethodsSubtitle =>
      'IBAN, PayPal, Wero, Lydia, Wise e la causale di pagamento';

  @override
  String get paymentProviderMollie => 'Mollie — iDEAL, Bancontact…';

  @override
  String get paymentProviderStripe => 'Carta di credito (Stripe)';

  @override
  String get paymentProviderWero => 'Wero (tramite Mollie)';

  @override
  String get paymentRoutingNumberLabel => 'Routing number';

  @override
  String get paymentSortCodeLabel => 'Sort code';

  @override
  String get paymentTermsEdit => 'Richiedi una modifica';

  @override
  String get paymentTermsFieldEscompte => 'Sconto per pagamento anticipato';

  @override
  String get paymentTermsFieldLatePenalty => 'Penale di ritardo';

  @override
  String get paymentTermsFieldRecovery => 'Indennità di recupero';

  @override
  String get paymentTermsFieldTerms => 'Condizioni di pagamento';

  @override
  String get paymentTermsInherit => 'quelle predefinite dello spazio';

  @override
  String get paymentTermsInherited => 'Predefinite dello spazio';

  @override
  String get paymentTermsMemberNote =>
      'Queste condizioni sono fissate dallo spazio; una modifica passa dalla sua convalida.';

  @override
  String get paymentTermsNone => 'Nessuna condizione scritta';

  @override
  String get paymentTermsOverridden => 'Proprie del membro';

  @override
  String get paymentTermsReason => 'Motivo (facoltativo)';

  @override
  String get paymentTermsRequestHint =>
      'Lascia un campo vuoto per mantenere la formulazione dello spazio. La modifica si applica dopo la convalida.';

  @override
  String get paymentTermsRequestTitle =>
      'Richiedi una modifica delle condizioni di pagamento';

  @override
  String get paymentTermsRequested =>
      'Modifica richiesta — in attesa di convalida';

  @override
  String get paymentTermsSubmit => 'Invia richiesta';

  @override
  String get paymentTermsTitle => 'Condizioni di pagamento';

  @override
  String get paymentTermsUseDefault =>
      'Torna alle condizioni predefinite dello spazio';

  @override
  String get paymentTransitNumberLabel => 'Transito · istituzione';

  @override
  String get paymentsPendingTag => 'in attesa di convalida';

  @override
  String pendingApprovalBody(String workspace) {
    return 'Ti sei unito a $workspace. Un amministratore deve approvare la tua adesione prima che tu possa usare lo spazio — avrai accesso appena confermata.';
  }

  @override
  String get pendingApprovalRefresh => 'Controlla di nuovo';

  @override
  String get pendingApprovalTitle =>
      'Adesione allo spazio in attesa di approvazione';

  @override
  String get pendingAvailable =>
      'Mentre aspetti, gli altri spazi, il tuo account e l’aiuto restano disponibili.';

  @override
  String get pendingHelp => 'Aiuto';

  @override
  String pendingLastChecked(String time) {
    return 'Ultimo controllo $time';
  }

  @override
  String get pendingNotUpdated =>
      'Stato non aggiornato — server non raggiungibile. La tua richiesta resta invariata.';

  @override
  String get pendingStillWaiting => 'Ancora in attesa di approvazione.';

  @override
  String get pendingSwitchWorkspace => 'Cambia spazio';

  @override
  String percentValue(int value) {
    return '$value%';
  }

  @override
  String get permAccessProd => 'Entrare nello spazio di produzione';

  @override
  String get permApproveExpenses => 'Approvare le spese';

  @override
  String get permDeployToDev => 'Distribuire in sviluppo';

  @override
  String get permDeployToProd => 'Distribuire in produzione';

  @override
  String get permDesignDocuments => 'Progettare i documenti';

  @override
  String get permExportData => 'Esportare contabilità e dati';

  @override
  String get permIssueInvoices => 'Emettere fatture e riconciliare pagamenti';

  @override
  String get permManageBilling => 'Gestire tariffe e regole di fatturazione';

  @override
  String get permManageConfiguration => 'Gestire la configurazione';

  @override
  String get permManageDocuments => 'Gestire la libreria dei documenti';

  @override
  String get permManageIntegrations => 'Gestire le integrazioni';

  @override
  String get permManageMembers => 'Gestire i membri';

  @override
  String get permManageNegotiations => 'Gestire gli accordi commerciali';

  @override
  String get permManageReservations => 'Gestire le prenotazioni degli altri';

  @override
  String get permManageRoles => 'Gestire ruoli e permessi';

  @override
  String get permManageServices => 'Gestire servizi e pacchetti';

  @override
  String get permManageSites => 'Gestire sedi e piani';

  @override
  String get permManageValidation => 'Configurare le regole di convalida';

  @override
  String get permOperateKiosk => 'Operare il chiosco e i badge';

  @override
  String get permPaymentTermsEdit =>
      'Richiedere modifiche alle condizioni di pagamento';

  @override
  String get permViewAnalytics => 'Consultare i dati dello spazio';

  @override
  String get permViewFinances => 'Consultare le finanze dello spazio';

  @override
  String get permViewNegotiations => 'Consultare gli accordi commerciali';

  @override
  String get permViewPersonalData => 'Consultare i dati personali dei membri';

  @override
  String get permWorkspaceSettings => 'Modificare le impostazioni dello spazio';

  @override
  String get personalInfoCity => 'Città';

  @override
  String get personalInfoCompany => 'Società (facoltativo)';

  @override
  String get personalInfoCountry => 'Paese';

  @override
  String get personalInfoEmail => 'E-mail per i documenti';

  @override
  String get personalInfoFirstName => 'Nome';

  @override
  String get personalInfoLastName => 'Cognome';

  @override
  String get personalInfoLegalId => 'Identificativo società (facoltativo)';

  @override
  String get personalInfoNone => 'Non ancora compilati';

  @override
  String get personalInfoPhone => 'Telefono';

  @override
  String get personalInfoPostalCode => 'CAP';

  @override
  String get personalInfoPreview => 'Sui tuoi documenti';

  @override
  String get personalInfoSave => 'Salva';

  @override
  String get personalInfoSaved => 'Dati personali salvati';

  @override
  String get personalInfoStreet => 'Via e numero';

  @override
  String get personalInfoSubtitle =>
      'Stampati su fatture e lettere. Il cognome è scritto in maiuscolo, come nella posta ufficiale.';

  @override
  String get personalInfoTitle => 'Dati personali';

  @override
  String get personalInfoVatId => 'Partita IVA (facoltativo)';

  @override
  String get planAccessorySupplementHint =>
      'I supplementi si applicano per mezza giornata.';

  @override
  String get planActiveLabel => 'Attivo';

  @override
  String get planAfternoonChip => 'Pomeriggio';

  @override
  String get planAvailabilityLoading => 'Verifica dei giorni di apertura…';

  @override
  String get planBaseFeeLabel => 'Canone mensile base';

  @override
  String get planBookForLabel => 'Prenota per';

  @override
  String planBookedForPending(String name) {
    return 'Inviato a $name per conferma.';
  }

  @override
  String get planCancelReservationButton => 'Annulla prenotazione';

  @override
  String planCappedByNext(String time) {
    return 'Il posto è prenotato dalle $time.';
  }

  @override
  String get planCheckInButton => 'Check-in';

  @override
  String get planCheckInFailed =>
      'Check-in non riuscito — il posto potrebbe essere appena stato occupato.';

  @override
  String planCheckInFor(String name) {
    return 'Fai il check-in di $name';
  }

  @override
  String get planCheckInNotYetError =>
      'Il check-in apre 15 minuti prima dell\'inizio.';

  @override
  String planCheckInOpensAt(String time) {
    return 'Il check-in apre alle $time';
  }

  @override
  String planCheckInOpensOn(String date) {
    return 'Il check-in apre il $date';
  }

  @override
  String get planCheckInOverError =>
      'Questa prenotazione è terminata — il check-in non è più possibile.';

  @override
  String get planCheckInTitle => 'Check-in';

  @override
  String get planCheckOutButton => 'Check-out';

  @override
  String planCheckOutFor(String name) {
    return 'Check-out di $name';
  }

  @override
  String get planClosedDay => 'Chiuso in questo giorno';

  @override
  String get planClosedDayError => 'Lo spazio è chiuso quel giorno.';

  @override
  String planClosedDayShowNext(String day) {
    return 'Mostra $day';
  }

  @override
  String get planDurationLabel => 'Durata';

  @override
  String get planEndBeforeStart =>
      'La fine deve essere successiva all\'inizio.';

  @override
  String get planFromLabel => 'Dalle';

  @override
  String get planFullDayChip => 'Giornata';

  @override
  String get planFullDayError =>
      'Qui le prenotazioni coprono l\'intera giornata.';

  @override
  String get planHalfDayError => 'Qui le prenotazioni sono per mezza giornata.';

  @override
  String get planIncludedHelper => 'Lascia vuoto per illimitato';

  @override
  String get planIncludedLabel => 'Mezze giornate incluse';

  @override
  String get planLevelLabel => 'Piano';

  @override
  String get planLevelTooltip => 'Piano';

  @override
  String get planListViewTooltip => 'Vista elenco';

  @override
  String get planMakeNotReservable => 'Rendi non prenotabile';

  @override
  String get planMakeReservable => 'Rendi prenotabile';

  @override
  String get planMapViewTooltip => 'Vista piantina';

  @override
  String get planMorningChip => 'Mattina';

  @override
  String get planNameLabel => 'Nome';

  @override
  String get planNoLevels => 'Lo spazio non ha ancora una piantina.';

  @override
  String get planNoSeats => 'Questo piano non ha ancora posti.';

  @override
  String get planNowButton => 'Adesso';

  @override
  String planOccupiedBy(String name) {
    return 'Occupato da $name';
  }

  @override
  String get planOverageLabel => 'Prezzo per mezza giornata extra';

  @override
  String planOverruleDone(String name) {
    return 'Prenotazione rimossa — $name è stato avvisato.';
  }

  @override
  String planOverruleHint(String name) {
    return '$name e tutti gli admin saranno avvisati.';
  }

  @override
  String get planOverruleRemove => 'Rimuovi la prenotazione (scavalca)';

  @override
  String get planRepeatLabel => 'Ripeti';

  @override
  String get planReservationsEmpty => 'Nessuna prenotazione per questo giorno.';

  @override
  String get planReserveButton => 'Prenota';

  @override
  String planReservedBy(String name) {
    return 'Prenotato da $name';
  }

  @override
  String get planSeatBlocked => 'Questo posto è bloccato per manutenzione.';

  @override
  String get planSendForConfirmation => 'Invia per conferma';

  @override
  String planSlotError(int minutes) {
    return 'Le prenotazioni devono iniziare e finire sulla griglia di $minutes minuti.';
  }

  @override
  String get planStartNow => 'Inizia adesso';

  @override
  String planStartsAt(String time) {
    return 'Inizia alle $time';
  }

  @override
  String get planStateFree => 'Libero';

  @override
  String get planStateYours => 'Tuo';

  @override
  String get planToLabel => 'Alle';

  @override
  String planUntil(String time) {
    return 'fino alle $time';
  }

  @override
  String get planUntilDateLabel => 'Ripeti fino al';

  @override
  String get planUntilLabel => 'Fino alle';

  @override
  String get planYourSeat => 'Il tuo posto';

  @override
  String get plansEditorEdit => 'Modifica piano';

  @override
  String get plansEditorInactive => 'Inattivo';

  @override
  String get plansEditorNew => 'Nuovo piano';

  @override
  String plansEditorPerExtra(String price) {
    return '$price/mezza giornata extra';
  }

  @override
  String plansEditorQuota(int count) {
    return '$count mezze giornate';
  }

  @override
  String get plansEditorTitle => 'Piani';

  @override
  String get plansEditorUnlimited => 'mezze giornate illimitate';

  @override
  String get policyAdminCheckoutDesc =>
      'Un amministratore può terminare il check-in in corso di un membro.';

  @override
  String get policyAdminCheckoutTitle =>
      'Gli amministratori possono fare il check-out dei membri';

  @override
  String get policyAllowPastDesc =>
      'I membri possono registrare una prenotazione già terminata.';

  @override
  String get policyAllowPastTitle => 'Consenti prenotazioni passate';

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
  String get policyDurationConflict =>
      'Il minimo non può superare il massimo — nessuna prenotazione verrebbe accettata.';

  @override
  String get policyHorizonDesc =>
      'Quanti giorni prima può iniziare una prenotazione. Oltre, viene rifiutata.';

  @override
  String get policyHorizonTitle => 'Orizzonte di prenotazione';

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
  String get policyLimitsDesc =>
      'Con quanto anticipo si può prenotare e quale durata è accettata. Valgono su ogni granularità.';

  @override
  String get policyLimitsTitle => 'Limiti di prenotazione';

  @override
  String get policyMaxDurationDesc =>
      'La prenotazione più lunga accettata. Una prenotazione finisce nel giorno in cui inizia, quindi la giornata intera è il tetto.';

  @override
  String get policyMaxDurationTitle => 'Durata massima';

  @override
  String get policyMinDurationDesc =>
      'La prenotazione più breve accettata. Per questo arrivare alle 11:45 per il limite delle 12:00 viene rifiutato: troppo corta.';

  @override
  String get policyMinDurationTitle => 'Durata minima';

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
  String get policyOutsideHoursCharged => 'A pagamento';

  @override
  String get policyOutsideHoursChargedDesc =>
      'Consentito e contato come uso normale, salvo nei giorni in cui il membro ha già una prenotazione normale.';

  @override
  String get policyOutsideHoursDesc =>
      'Che cosa è possibile fuori dalla giornata lavorativa: una sola risposta, per tutte le granularità. Una prenotazione che tocca gli orari di lavoro è una prenotazione normale.';

  @override
  String get policyOutsideHoursFree => 'Gratis';

  @override
  String get policyOutsideHoursFreeDesc =>
      'Consentito, mai contato né addebitato: pura informazione di presenza.';

  @override
  String get policyOutsideHoursOff => 'Vietato';

  @override
  String get policyOutsideHoursOffDesc =>
      'Niente fuori dagli orari: né prenotazioni in anticipo, né check-in spontanei, e anche una prenotazione che sfora la fine della giornata viene rifiutata.';

  @override
  String get policyOutsideHoursTitle => 'Fuori dagli orari di apertura';

  @override
  String get policyOutsideHoursWalkUp => 'Solo spontaneo';

  @override
  String get policyOutsideHoursWalkUpDesc =>
      'I check-in spontanei restano possibili, straordinari serali compresi; prenotare in anticipo fuori dagli orari viene rifiutato.';

  @override
  String get policySimultaneousDesc =>
      'Quante prenotazioni sovrapposte può avere un membro. 1 mantiene un solo posto alla volta.';

  @override
  String get policySimultaneousTitle => 'Prenotazioni simultanee per membro';

  @override
  String get portalActionFailed => 'Impossibile salvare la modifica. Riprova.';

  @override
  String get portalActionNotNegotiated =>
      'Questa azione non è disponibile tra questa app e quel server. Aggiornare l’app può aiutare.';

  @override
  String get portalAddress => 'Indirizzo pubblico';

  @override
  String get portalAdmin => 'Amministratore';

  @override
  String get portalAdminVisible => 'Mostrami come amministratore pubblico';

  @override
  String get portalAssociation => 'Associazione';

  @override
  String get portalAvailable =>
      'Consenti agli utenti di trovare il mio account e scrivermi';

  @override
  String get portalChat => 'Chat';

  @override
  String get portalCompany => 'Impresa';

  @override
  String get portalConnect => 'Collega un server';

  @override
  String get portalConnectionFailed =>
      'Connessione non riuscita. Controlla il server e le credenziali.';

  @override
  String get portalConnections => 'Server collegati';

  @override
  String get portalConnectionsHint =>
      'Ogni server usa il proprio accesso. Disconnetterlo rimuove l’accesso salvato per questo account sul dispositivo.';

  @override
  String get portalCopyEmail => 'Copia l\'e-mail';

  @override
  String get portalCustomised => 'Personalizzato';

  @override
  String get portalDescription => 'Descrizione';

  @override
  String get portalDirectoryIncompatible =>
      'Alcuni spazi richiedono una versione più recente dell’app e non vengono mostrati.';

  @override
  String get portalDirectoryUnavailable =>
      'Alcune directory non sono raggiungibili. I risultati sono incompleti.';

  @override
  String get portalDisconnect => 'Disconnetti';

  @override
  String get portalDiscover => 'Trova uno spazio di lavoro';

  @override
  String get portalEmail => 'Email pubblica';

  @override
  String get portalEmailCode => 'Codice di accesso via email';

  @override
  String get portalEmailCopied => 'E-mail copiata';

  @override
  String get portalEmployed => 'Dipendente di questo spazio';

  @override
  String get portalEmploymentHint =>
      'Il rapporto di lavoro non modifica accessi o abbonamenti. I pagamenti degli stipendi non sono abilitati.';

  @override
  String get portalEnterSpace => 'Entra';

  @override
  String get portalFindPeople => 'Trova persone disponibili';

  @override
  String get portalFollowsWorkspace => 'Dalle informazioni dello spazio';

  @override
  String get portalImage => 'URL dell’immagine dello spazio';

  @override
  String get portalLatitude => 'Latitudine';

  @override
  String get portalList => 'Elenco';

  @override
  String get portalLongitude => 'Longitudine';

  @override
  String get portalMap => 'Mappa';

  @override
  String get portalMessenger => 'Messaggi dell’account';

  @override
  String get portalMoreDirectories => 'Altre directory';

  @override
  String get portalNoLongerPublished => 'Questo spazio non è più pubblicato.';

  @override
  String get portalNoWorkspaces => 'Nessuno spazio pubblicato trovato.';

  @override
  String get portalOpenMe => 'Io: il mio account e i miei spazi';

  @override
  String get portalOwner => 'Proprietario';

  @override
  String get portalPerson => 'Privato';

  @override
  String get portalPhone => 'Telefono pubblico';

  @override
  String get portalPlans => 'Piani e prezzi';

  @override
  String get portalPreview => 'Vista esterna';

  @override
  String get portalPublicPlan => 'Planimetria pubblica';

  @override
  String get portalPublication => 'Pagina pubblica dello spazio';

  @override
  String get portalPublished => 'Visibile nella directory pubblica';

  @override
  String get portalRegisterDirectory => 'Pubblica un server nella directory';

  @override
  String get portalRequestProfile => 'Richiedi un profilo nello spazio';

  @override
  String get portalRequestSent =>
      'Richiesta inviata. Lo spazio esaminerà il tuo profilo.';

  @override
  String get portalResetAll =>
      'Ripristina tutti i dati pubblici dalle informazioni dello spazio';

  @override
  String get portalResetAllBody =>
      'I valori pubblici di ogni campo che ha un’informazione nello spazio vengono sostituiti da essa. I campi senza corrispondenza nello spazio mantengono ciò che hai scritto.';

  @override
  String get portalResetAllConfirm => 'Ripristina';

  @override
  String get portalSavePreview => 'Salva e mostra la vista esterna';

  @override
  String get portalSearch => 'Cerca spazi';

  @override
  String get portalSendCode => 'Invia codice di accesso';

  @override
  String get portalSourceUnavailable =>
      'Un server non è disponibile. La panoramica è incompleta. Tocca per riprovare.';

  @override
  String get portalThisServer => 'Questo server';

  @override
  String get portalUseCode => 'Usa un codice via email';

  @override
  String get portalUseWorkspaceInfo => 'Usa le informazioni dello spazio';

  @override
  String get portalVisibilityLink => 'Chi può trovarmi e scrivermi';

  @override
  String get portalVisibilityLinkBody => 'Si sceglie in Io, sotto Chi mi vede.';

  @override
  String get portalWebsite => 'Sito web';

  @override
  String get preferencesSaveFailed =>
      'Impossibile salvare le preferenze. Riprova.';

  @override
  String get preferencesScopeHint =>
      'Lingua, aspetto e formati regionali. Disattivato: modifica i miei valori predefiniti.';

  @override
  String get preferencesUseDefaults => 'Usa i miei valori predefiniti';

  @override
  String get preferencesWorkspaceOnly => 'Solo per questo spazio';

  @override
  String get priceGrossHint =>
      'Prezzo lordo — ciò che paga il membro; l’IVA è compresa.';

  @override
  String priceVatIncluded(String rate) {
    return 'IVA $rate incl.';
  }

  @override
  String get privacyErase => 'Lasciare questo spazio e cancellare i miei dati';

  @override
  String get privacyEraseConfirmButton => 'Cancella';

  @override
  String privacyEraseConfirmHint(String phrase) {
    return 'Non si può annullare. Digita $phrase per confermare.';
  }

  @override
  String get privacyEraseConfirmPhrase => 'CANCELLA';

  @override
  String get privacyEraseHint =>
      'Annulla le tue prenotazioni, svuota i tuoi messaggi, cancella il tuo profilo. I documenti contabili restano per la conservazione legale, per id, non per nome (art. 17).';

  @override
  String get privacyEraseOwner =>
      'Un proprietario prima cede lo spazio (Membri e piani → Comproprietà).';

  @override
  String get privacyErased => 'I tuoi dati sono stati cancellati.';

  @override
  String get privacyExport => 'Esporta i miei dati';

  @override
  String get privacyExportHint =>
      'Tutto ciò di cui sei l\'interessato, in un file JSON (art. 20).';

  @override
  String get privacyExportShareText => 'La mia esportazione dati DesKilo';

  @override
  String get privacyIntro =>
      'I tuoi dati non vengono mai tracciati né venduti e sono leggibili solo dai ruoli indicati dalle regole qui sotto; dove sono ospitati è indicato nell\'informativa privacy di questa installazione. Questi sono i tuoi diritti secondo il GDPR — ognuno è un pulsante.';

  @override
  String privacyNoticeController(String name, String contact) {
    return 'Titolare del trattamento: $name — $contact';
  }

  @override
  String get privacyNoticeEssential => 'Necessario per l\'account e lo spazio';

  @override
  String get privacyNoticeNotRecorded => 'non indicato dal gestore';

  @override
  String get privacyNoticeOptional => 'Facoltativo — puoi usare l\'app senza';

  @override
  String privacyNoticeRegion(String region) {
    return 'Regione: $region';
  }

  @override
  String privacyNoticeRights(String contact) {
    return 'I tuoi diritti: $contact';
  }

  @override
  String get privacyNoticeRightsRoute => 'I tuoi diritti e il contatto';

  @override
  String get privacyNoticeTitle => 'Chi tratta i tuoi dati';

  @override
  String privacyNoticeTransfer(String mechanism) {
    return 'Garanzia per il trasferimento: $mechanism';
  }

  @override
  String get privacyPolicy => 'Informativa sulla privacy';

  @override
  String get privacyPushOnDevice => 'Notifiche push su questo dispositivo';

  @override
  String get privacyPushOnDeviceFailed =>
      'Non è stato possibile salvare la scelta. Riprova.';

  @override
  String get privacyPushOnDeviceHint =>
      'Facoltativo. Attivo, l\'indirizzo di questo dispositivo e ogni notifica passano dal servizio push; disattivo, l\'app continua a funzionare e a questo dispositivo non viene inviato nulla.';

  @override
  String get privacySpaceNotice => 'L\'informativa privacy di questo spazio';

  @override
  String get privacySpaceNoticeAcknowledge => 'Ho letto questa informativa';

  @override
  String get privacySpaceNoticeFailed =>
      'Non è stato possibile registrare la presa visione. Riprova.';

  @override
  String get privacySpaceNoticeRead => 'Hai preso visione di questa versione.';

  @override
  String get privacySpaceNoticeUnread => 'Non ancora letta — leggila qui.';

  @override
  String get privacyTitle => 'Privacy e dati';

  @override
  String get privacyWhoCanSee => 'Chi può vedere i miei dati';

  @override
  String get privacyWhoCanSeeHint =>
      'La regola per categoria, le persone che nomina oggi e chi ha guardato davvero.';

  @override
  String processAlsoNeeds(String features) {
    return 'Attivare tutto richiede anche: $features';
  }

  @override
  String processApplied(int count) {
    return '$count funzionalità modificate.';
  }

  @override
  String get processBillingPayments => 'Fatturazione e pagamenti';

  @override
  String get processBillingPaymentsDesc =>
      'Fatturare le attività e riconciliare gli importi dovuti.';

  @override
  String processBlockedIntro(String feature, String features) {
    return '$feature è ancora necessaria per: $features';
  }

  @override
  String get processChangeFailed =>
      'Non è stato possibile modificare le funzionalità. Non è stato scritto nulla; riprovate.';

  @override
  String processConfirmOff(int count) {
    return 'Disattiva $count funzionalità';
  }

  @override
  String processConfirmOn(int count) {
    return 'Attiva $count funzionalità';
  }

  @override
  String get processConflict =>
      'Qualcuno ha modificato le funzionalità nel frattempo. Questa è l\'anteprima aggiornata: controllatela di nuovo.';

  @override
  String get processCoordination => 'Calendario e coordinamento';

  @override
  String get processCoordinationDesc =>
      'Coordinare attività, messaggi e decisioni.';

  @override
  String get processDocumentsInformation => 'Documenti e informazioni';

  @override
  String get processDocumentsInformationDesc =>
      'Creare, condividere ed esportare informazioni dello spazio.';

  @override
  String processFeatureCount(int enabled, int total) {
    return '$enabled di $total funzionalità attive';
  }

  @override
  String get processFeatureOff => 'Disattivata';

  @override
  String get processFeatureOn => 'Attiva';

  @override
  String processFeatureWaiting(String feature) {
    return 'Attiva, in attesa di $feature';
  }

  @override
  String get processFilterAll => 'Tutti';

  @override
  String get processFilterEmpty =>
      'Nessun processo corrisponde a questo filtro.';

  @override
  String processHeldBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count funzionalità sono attive ma attendono un prerequisito disattivato',
      one: '1 funzionalità è attiva ma attende un prerequisito disattivato',
    );
    return '$_temp0';
  }

  @override
  String processInProcess(String process) {
    return 'in $process';
  }

  @override
  String get processIntegrations => 'Integrazioni e automazione';

  @override
  String get processIntegrationsDesc =>
      'Inviare notifiche e documenti tramite servizi esterni.';

  @override
  String get processKeepDependants =>
      'Disattiva comunque, conserva le impostazioni';

  @override
  String get processMembershipCommerce => 'Offerte per i membri';

  @override
  String get processMembershipCommerceDesc =>
      'Definire prezzi dei servizi e accordi con i membri.';

  @override
  String processNeededBy(String features) {
    return 'necessaria per $features';
  }

  @override
  String get processNothingToDo => 'È già così: niente da cambiare.';

  @override
  String get processOperations => 'Operazioni e amministrazione';

  @override
  String get processOperationsDesc =>
      'Gestire la configurazione e l’utilizzo dell’applicazione.';

  @override
  String processRemoveDependants(int count) {
    return 'Disattiva anche le $count funzionalità dipendenti';
  }

  @override
  String get processReservationsUsage => 'Prenotazioni e utilizzo';

  @override
  String get processReservationsUsageDesc =>
      'Prenotare posti e registrarne l’utilizzo.';

  @override
  String get processSearchLabel => 'Cerca processi e funzionalità';

  @override
  String get processSectionAlreadyOn => 'Già attive';

  @override
  String get processSectionAlsoNeeded => 'Necessarie anche';

  @override
  String get processSectionAlsoOff => 'Disattivate anche';

  @override
  String get processSectionKeptWaiting =>
      'Smettono di funzionare; l\'impostazione resta';

  @override
  String get processSectionSwitchedOff => 'Disattivate';

  @override
  String get processSectionSwitchedOn => 'Attivate';

  @override
  String get processSectionWorksAgain => 'Tornano a funzionare';

  @override
  String processSheetTitleOff(String name) {
    return 'Disattiva $name';
  }

  @override
  String processSheetTitleOn(String name) {
    return 'Attiva $name';
  }

  @override
  String get processSpaceManagement => 'Gestione degli spazi';

  @override
  String get processSpaceManagementDesc =>
      'Organizzare gli spazi disponibili e i loro orari.';

  @override
  String get processStateActive => 'Attivo';

  @override
  String get processStateAvailable => 'Disponibile';

  @override
  String get processStateNeedsAttention => 'Da verificare';

  @override
  String get processStatePartial => 'Parziale';

  @override
  String processSubprocessCount(int active, int total) {
    return '$active di $total sottoprocessi attivi';
  }

  @override
  String get processSwitchHint =>
      'Tocca una funzionalità per cambiarla tra gli interruttori.';

  @override
  String get processSwitchOff => 'Disattiva';

  @override
  String get processSwitchOn => 'Attiva';

  @override
  String get processUnconfirmed =>
      'La modifica è stata scritta, ma l\'app non ha potuto confermarla. Chiudete e riaprite le funzionalità per vedere lo stato attuale.';

  @override
  String get processWorkspaceAccess => 'Spazio e accesso';

  @override
  String get processWorkspaceAccessDesc =>
      'Gestire adesioni, ruoli e accesso allo spazio.';

  @override
  String get profilePhotoChoose => 'Scegli una foto';

  @override
  String get profilePhotoFileType => 'Immagine';

  @override
  String get profilePhotoNone => 'Tocca per aggiungere una foto';

  @override
  String get profilePhotoRemove => 'Rimuovi foto';

  @override
  String get profilePhotoRemoved => 'Foto rimossa';

  @override
  String get profilePhotoSaveFailed => 'Impossibile aggiornare la foto';

  @override
  String get profilePhotoSaved => 'Foto aggiornata';

  @override
  String get profilePhotoSet => 'Tocca per cambiare';

  @override
  String get profilePhotoTitle => 'Foto';

  @override
  String get profileStatusFieldLabel => 'Stato';

  @override
  String get profileStatusHelper =>
      'Facoltativo. Visibile ai membri dei tuoi spazi nell\'elenco dei membri. Lascia vuoto per cancellarlo.';

  @override
  String get profileStatusHint => 'In chiamata · torno alle 14:00';

  @override
  String get profileStatusNone => 'Nessuno stato';

  @override
  String get profileStatusSaveFailed => 'Impossibile salvare lo stato';

  @override
  String get profileStatusSaved => 'Stato salvato';

  @override
  String get profileStatusTitle => 'Stato';

  @override
  String get profilesActive => 'Profilo attivo';

  @override
  String get profilesAdd => 'Aggiungi un profilo';

  @override
  String get profilesAllWorkspaces =>
      'Tutti gli spazi (operatore della piattaforma)';

  @override
  String get profilesCopyEmail => 'Copia e-mail';

  @override
  String get profilesDefault => 'Predefinito all\'avvio';

  @override
  String get profilesEmailCopied => 'E-mail copiata.';

  @override
  String get profilesMakeDefault => 'Usa come predefinito all\'avvio';

  @override
  String profilesNotMember(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membri',
      one: '1 membro',
    );
    return 'Non membro · $_temp0';
  }

  @override
  String get profilesOwnersNone => 'Nessun proprietario.';

  @override
  String profilesOwnersOf(String name) {
    return 'Proprietari di $name';
  }

  @override
  String get profilesPairDev => 'DEV';

  @override
  String get profilesPairProd => 'PROD';

  @override
  String profilesSiteLine(String site) {
    return 'Sede: $site';
  }

  @override
  String get profilesSitePick => 'Cambia sede';

  @override
  String get profilesTitle => 'Profili';

  @override
  String get profilesUnavailable =>
      'Impossibile caricare i tuoi spazi di lavoro.';

  @override
  String provenanceFromTemplate(String name) {
    return 'Dal modello «$name»';
  }

  @override
  String get provenanceProductDefault => 'Valore predefinito del prodotto';

  @override
  String get provenanceResetToDefault => 'Ripristina il valore predefinito';

  @override
  String get provenanceResetToTemplate => 'Ripristina il modello';

  @override
  String get provenanceWorkspaceSetting => 'Impostazione dello spazio';

  @override
  String get publicHolidaysAction => 'Aggiungi i giorni festivi';

  @override
  String publicHolidaysConfirm(int count) {
    return 'Crea $count giorni di chiusura';
  }

  @override
  String get publicHolidaysCountry => 'Paese';

  @override
  String publicHolidaysCreated(int count) {
    return '$count giorni di chiusura creati';
  }

  @override
  String get publicHolidaysLocked => 'Mese fatturato — non creato';

  @override
  String publicHolidaysLockedMonths(String months) {
    return 'Saltati, già fatturati: $months';
  }

  @override
  String get publicHolidaysNothingToCreate =>
      'Niente da creare: tutti i giorni ci sono già.';

  @override
  String get publicHolidaysPresent => 'Già un giorno di chiusura';

  @override
  String get publicHolidaysPreviewNone =>
      'Nessun giorno festivo per quest\'anno.';

  @override
  String get publicHolidaysSheetTitle => 'Giorni festivi';

  @override
  String get publicHolidaysYear => 'Anno';

  @override
  String get pushCancelledBody =>
      'Una prenotazione è stata rimossa da un admin.';

  @override
  String get pushCancelledTitle => 'Prenotazione rimossa';

  @override
  String get pushPendingBody => 'Qualcuno attende la tua conferma.';

  @override
  String get pushPendingTitle => 'DesKilo';

  @override
  String get pushStatusNoTransport => 'Questa versione non ha notifiche push';

  @override
  String get pushStatusNoTransportHint =>
      'Le notifiche arrivano nell\'app e come notifiche locali su questo dispositivo.';

  @override
  String get pushStatusNotConfigured =>
      'Le notifiche push non sono ancora configurate';

  @override
  String get pushStatusNotConfiguredHint =>
      'Il proprietario completa la configurazione Firebase (guida push-setup).';

  @override
  String get pushStatusRegistered => 'Le notifiche push sono attive';

  @override
  String get questionEditorActive => 'Posta adesso';

  @override
  String get questionEditorChoices => 'Scelte, una per riga';

  @override
  String get questionEditorContextJoin => 'All\'iscrizione';

  @override
  String get questionEditorContextManaged =>
      'Le informazioni di un membro gestito';

  @override
  String get questionEditorContextProfile => 'Le informazioni del membro';

  @override
  String get questionEditorContexts => 'Dove viene posta';

  @override
  String get questionEditorKey => 'Chiave';

  @override
  String get questionEditorKeyHelp =>
      'Minuscole, cifre e trattini bassi. Non cambia mai: le risposte vi si appoggiano.';

  @override
  String questionEditorLabelFor(String locale) {
    return 'Etichetta ($locale)';
  }

  @override
  String get questionEditorMax => 'Numero massimo';

  @override
  String get questionEditorMaxLength => 'Risposta più lunga (caratteri)';

  @override
  String get questionEditorMin => 'Numero minimo';

  @override
  String get questionEditorNotPersonalWarning =>
      'Resta personale: la risposta è legata a un membro, quindi viene esportata e cancellata con l\'iscrizione qualunque sia questa impostazione. Solo un obbligo di conservazione documentato può mantenerla.';

  @override
  String get questionEditorPersonal => 'È un dato personale';

  @override
  String get questionEditorPersonalHelp =>
      'Ogni risposta è legata a un membro, quindi è un dato personale: è inclusa nella sua esportazione dei dati e viene cancellata quando esce.';

  @override
  String get questionEditorPreview => 'Come apparirà';

  @override
  String get questionEditorRequired => 'Deve essere risposta';

  @override
  String get questionEditorSave => 'Salva la domanda';

  @override
  String get questionEditorSaveFailed => 'La domanda non è stata salvata.';

  @override
  String get questionEditorType => 'Tipo di risposta';

  @override
  String get questionEditorVisibility => 'Chi vede la risposta';

  @override
  String get questionEditorVisibilityManagers =>
      'Il membro, e chi può vedere i dati personali';

  @override
  String get questionEditorVisibilityMembers => 'Tutti i membri dello spazio';

  @override
  String get questionEditorVisibilitySelf => 'Solo il membro';

  @override
  String get questionTypeBoolean => 'Sì o no';

  @override
  String get questionTypeDate => 'Una data';

  @override
  String get questionTypeDecimal => 'Un numero';

  @override
  String get questionTypeInteger => 'Un numero intero';

  @override
  String get questionTypeLongText => 'Una risposta lunga';

  @override
  String get questionTypeMultiChoice => 'Diverse di un elenco';

  @override
  String get questionTypeSingleChoice => 'Una di un elenco';

  @override
  String get questionTypeText => 'Una risposta breve';

  @override
  String get questionsAdd => 'Aggiungi una domanda';

  @override
  String get questionsEmpty => 'Ancora nessuna domanda.';

  @override
  String get questionsInactive => 'Messa da parte';

  @override
  String get questionsSubtitle =>
      'Compaiono dentro le informazioni personali, sotto il nome del tuo spazio.';

  @override
  String get questionsTitle => 'Le domande di questo spazio';

  @override
  String get quotaExceededError =>
      'Quota mensile di mezze giornate raggiunta — richiedi mezze giornate extra dalla scheda Finanze.';

  @override
  String get quotaRequestButton => 'Richiedi mezze giornate extra';

  @override
  String get quotaRequestCountLabel => 'Numero di mezze giornate';

  @override
  String quotaRequestExplainer(String period) {
    return 'Le tue prenotazioni sono limitate dal tuo abbonamento. Le mezze giornate extra per $period si applicano dopo la convalida.';
  }

  @override
  String get quotaRequestPending =>
      'Richiesta inviata — in attesa di convalida.';

  @override
  String get quotaRequestTitle => 'Richiedi mezze giornate extra';

  @override
  String readinessActor(String who) {
    return 'Chi: $who';
  }

  @override
  String get readinessActorAdministrator => 'Un amministratore del database';

  @override
  String get readinessActorOperator => 'L’operatore del server';

  @override
  String get readinessActorOwner => 'Lei';

  @override
  String readinessAll(String ready, String total) {
    return 'Tutte le sezioni ($ready su $total pronte)';
  }

  @override
  String get readinessAreaAssistant => 'Accesso degli assistenti (facoltativo)';

  @override
  String get readinessAreaBackend => 'Server e versione del database';

  @override
  String get readinessAreaFirstBooking => 'Una prima prenotazione';

  @override
  String get readinessAreaInvitations => 'Invitare i primi membri';

  @override
  String get readinessAreaLocalSetup =>
      'Dati richiesti dalle funzioni (identità, banca, piattaforme)';

  @override
  String get readinessAreaPayments => 'Come pagano i membri';

  @override
  String get readinessAreaPricing => 'Piani di iscrizione e tariffe';

  @override
  String get readinessAreaRecovery => 'Esportazione e ripristino';

  @override
  String get readinessAreaRegionRules =>
      'Giorni di apertura, fuso orario e valuta';

  @override
  String get readinessAreaResources => 'Posti prenotabili sulla planimetria';

  @override
  String get readinessAreaRolesValidation =>
      'Ruoli e chi convalida le richieste';

  @override
  String readinessBlocked(String step) {
    return 'Prima di una prima prenotazione: $step';
  }

  @override
  String get readinessFirstBookingReady => 'Pronto per una prima prenotazione';

  @override
  String get readinessLater => 'Necessario più avanti';

  @override
  String get readinessNeededFirst => 'Necessario per una prima prenotazione';

  @override
  String readinessNext(String step) {
    return 'Poi: $step';
  }

  @override
  String get readinessReasonEligibilityExpired =>
      'La sua abilitazione agli assistenti è scaduta';

  @override
  String get readinessReasonEligibilityMissing =>
      'Nessun amministratore del database l’ha abilitata agli assistenti';

  @override
  String get readinessReasonEligibilityNoIdentity =>
      'Acceda prima con la sua identità verificata';

  @override
  String get readinessReasonEligibilityRequested =>
      'La sua richiesta attende un amministratore del database';

  @override
  String get readinessReasonNoEvidence =>
      'Nessuna esportazione o ripristino registrato';

  @override
  String get readinessReasonNoPolicies =>
      'Nessuna richiesta attende un validatore';

  @override
  String get readinessReasonNotExposed =>
      'Questo spazio non espone ancora nulla agli assistenti';

  @override
  String get readinessReasonRecentExport =>
      'È registrata un’esportazione recente';

  @override
  String get readinessReasonStaleExport =>
      'L’ultima esportazione registrata risale a più di 90 giorni fa';

  @override
  String get readinessReasonTooFewValidators =>
      'Una regola richiede più validatori di quanti ne abbia questo spazio';

  @override
  String get readinessSetAside => 'Rimandato a più tardi';

  @override
  String get readinessSetAsideAction => 'Più tardi';

  @override
  String get readinessSetAsideFailed => 'Impossibile salvare. Riprova.';

  @override
  String get readinessSetAsideUndo => 'Annulla';

  @override
  String get readinessStateNeeds => 'Da configurare';

  @override
  String get readinessStateNeedsOperator => 'In attesa di un’altra persona';

  @override
  String get readinessStateNotApplicable => 'Non necessario qui';

  @override
  String get readinessStateReady => 'Pronto';

  @override
  String get readinessStateUnavailable => 'Impossibile leggere';

  @override
  String get readinessStateUnverified => 'Non ancora verificato';

  @override
  String get readinessTitle => 'Configurazione di questo spazio';

  @override
  String get recordingPrivacyBadge => 'Modalità ripresa — persone inventate';

  @override
  String get recordingPrivacyBadgeHint =>
      'La modalità ripresa è attiva: ogni nome, indirizzo e-mail, numero di telefono, indirizzo e fotografia sullo schermo appartiene a una persona inventata. La piantina, le prenotazioni e gli importi sono davvero quelli di questo spazio. Disattivala nelle Impostazioni quando hai finito di riprendere.';

  @override
  String get recordingPrivacyWriteRefused =>
      'Non mentre la modalità ripresa è attiva: questo modulo mostra una persona inventata, e salvarlo sovrascriverebbe i dati reali di qualcuno. Disattiva prima la modalità ripresa.';

  @override
  String get refusalAlreadyDecided =>
      'Qualcuno ha già deciso. L\'elenco mostra l\'esito.';

  @override
  String get refusalChangedMeanwhile =>
      'Nel frattempo è cambiato. Riaprilo per vedere a che punto è.';

  @override
  String get refusalPermission =>
      'Non hai il permesso per farlo. Un proprietario dello spazio può concederlo in Gestione dei ruoli.';

  @override
  String get refusalSession =>
      'La tua sessione è scaduta. Accedi di nuovo, poi riprova.';

  @override
  String get regionalClock => 'Orologio';

  @override
  String get regionalClock12h => '12h';

  @override
  String get regionalClock24h => '24h';

  @override
  String get regionalClockAuto => 'Auto';

  @override
  String get regionalDeviceZone => 'Mostra gli orari nel mio fuso';

  @override
  String get regionalDeviceZoneHint =>
      'Disattivato: gli orari nel fuso dello spazio, quello delle prenotazioni. Attivato: quello del tuo dispositivo, segnalato dove differisce.';

  @override
  String get regionalFollowLanguage => 'Automatico';

  @override
  String get regionalFormatLocale => 'Numeri e date';

  @override
  String regionalFormatLocaleAuto(String locale) {
    return 'Segue la lingua dell\'app ($locale)';
  }

  @override
  String get regionalFormatsTitle => 'Regione e formati';

  @override
  String get registerPaymentAmount => 'Importo';

  @override
  String get registerPaymentDate => 'Pagato il';

  @override
  String get registerPaymentDone =>
      'Pagamento registrato: il membro lo conferma dalla sua parte.';

  @override
  String get registerPaymentHint =>
      'Un pagamento arrivato allo spazio: il membro lo conferma, poi può essere abbinato a una fattura.';

  @override
  String get registerPaymentMember => 'Membro';

  @override
  String get registerPaymentMethod => 'Metodo';

  @override
  String get registerPaymentNote => 'Nota';

  @override
  String get registerPaymentSubmit => 'Registra';

  @override
  String get registerPaymentTitle => 'Registra un pagamento';

  @override
  String reminderBody(String target, String time) {
    return '$target inizia alle $time';
  }

  @override
  String reminderHistoryLine(int level, String origin, String date) {
    return 'Livello $level · $origin · $date';
  }

  @override
  String get reminderHistoryRefresh => 'Verifica di nuovo l\'invio';

  @override
  String get reminderHistoryTitle => 'Cronologia dei solleciti';

  @override
  String get reminderOriginAutomatic => 'automatico';

  @override
  String get reminderOriginLegacy => 'precedente';

  @override
  String get reminderOriginManual => 'a mano';

  @override
  String get reminderPdfClosing => 'Se hai già pagato, ignora questa lettera.';

  @override
  String get reminderPdfDays => 'giorni';

  @override
  String get reminderPdfDaysOpen => 'Aperta da';

  @override
  String get reminderPdfLevelLabel => 'Livello di sollecito';

  @override
  String get reminderPdfOpeningFirm =>
      'nonostante il nostro sollecito precedente, la fattura qui sotto risulta ancora non pagata. Ti preghiamo di saldare l\'importo senza indugio.';

  @override
  String get reminderPdfOpeningFriendly =>
      'questo è un promemoria amichevole: la fattura qui sotto è ancora aperta. Probabilmente una semplice svista — nessun problema.';

  @override
  String get reminderPdfTitleFirm => 'Sollecito';

  @override
  String get reminderPdfTitleFriendly => 'Promemoria di pagamento';

  @override
  String get reminderStatusAccepted =>
      'Accettato dal servizio di notifiche — non prova che sia stato letto';

  @override
  String get reminderStatusDeclared =>
      'Condiviso dal mittente — una sua dichiarazione, non una ricevuta';

  @override
  String get reminderStatusFailed => 'Non consegnato';

  @override
  String get reminderStatusLegacy =>
      'Registrato prima del tracciamento degli invii — sconosciuto';

  @override
  String get reminderStatusPrepared => 'Preparato';

  @override
  String get reminderStatusQueued => 'Affidato al servizio di notifiche';

  @override
  String get reminderStatusUnknown =>
      'Nessuna risposta dal servizio di notifiche';

  @override
  String get reminderTitle => 'Check-in a breve';

  @override
  String get repartitionAction => 'Ripartisci una spesa';

  @override
  String get repartitionAmount => 'Importo totale';

  @override
  String get repartitionAmountLabel => 'Importo';

  @override
  String get repartitionBooked => 'Ripartizione registrata.';

  @override
  String get repartitionExclude => 'Escludere';

  @override
  String get repartitionFiled =>
      'Quote registrate: compariranno sulla prossima fattura di utilizzo.';

  @override
  String get repartitionFiledPending =>
      'Quote depositate: saranno registrate dopo la convalida.';

  @override
  String get repartitionHint =>
      'Ripartisci un costo comune tra i membri. Le quote diventano righe della prossima fattura di utilizzo di ciascuno; uno storno restituisce il denaro come note di credito.';

  @override
  String get repartitionHistory => 'Ripartizioni';

  @override
  String get repartitionHistoryEmpty => 'Nessuna ripartizione per ora.';

  @override
  String get repartitionMethod => 'Ripartire per';

  @override
  String get repartitionMethodCustom => 'Chiave personalizzata';

  @override
  String get repartitionMethodEqual => 'Quote uguali';

  @override
  String get repartitionMethodSubscription => 'Abbonamento';

  @override
  String get repartitionMethodUsage => 'Utilizzo';

  @override
  String get repartitionNoShares =>
      'Nessuno porta una quota: controlla la chiave.';

  @override
  String get repartitionPeriod => 'Imputato a';

  @override
  String get repartitionPeriodLabel => 'Mese';

  @override
  String get repartitionPreview => 'Quote';

  @override
  String get repartitionRememberRule => 'Ricorda questa regola';

  @override
  String get repartitionReverse => 'Storno — restituire come note di credito';

  @override
  String get repartitionRuleHint =>
      'Ogni quota è proposta in base alla percentuale di abbonamento. Deseleziona un socio per escluderlo; con il metodo «chiave», indica il suo peso. La regola modificata sarà proposta il mese prossimo.';

  @override
  String get repartitionRuleNotSaved =>
      'La regola non è stata salvata, quindi non è stato ripartito nulla. Riprova.';

  @override
  String get repartitionSharesTotal => 'Totale delle quote';

  @override
  String get repartitionStatusConfirmed => 'Registrata';

  @override
  String get repartitionStatusExpired => 'Scaduta';

  @override
  String get repartitionStatusPending => 'In attesa di convalida';

  @override
  String get repartitionStatusRejected => 'Rifiutata';

  @override
  String get repartitionStepBook => 'Registrare';

  @override
  String get repartitionStepCost => 'La spesa';

  @override
  String get repartitionStepExpense => 'La spesa';

  @override
  String get repartitionStepRule => 'La regola';

  @override
  String get repartitionSubmit => 'Registra le quote';

  @override
  String repartitionSum(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membri · $amount',
      one: '1 membro · $amount',
    );
    return '$_temp0';
  }

  @override
  String get repartitionTitle => 'Ripartisci una spesa';

  @override
  String get repartitionTitleField => 'Causale';

  @override
  String get repartitionTitleLabel => 'Descrizione';

  @override
  String get repartitionWeight => 'Chiave';

  @override
  String get repartitionWizardSubtitle =>
      'Proporre in base all\'abbonamento, modificare, registrare';

  @override
  String get repartitionWizardTitle => 'Ripartire una spesa';

  @override
  String get repartitionWizardWeight => 'Peso';

  @override
  String get repeatDaily => 'Ogni giorno';

  @override
  String get repeatNone => 'Non si ripete';

  @override
  String get repeatWeekdays => 'Ogni giorno feriale';

  @override
  String get repeatWeekly => 'Ogni settimana';

  @override
  String get reportBadgesFooter =>
      'Un badge perso va revocato in Membri e piani, non semplicemente sostituito.';

  @override
  String get reportBadgesIntro =>
      'Taglia lungo le linee. Ogni tessera porta il codice badge di un membro — mostrala al chiosco per il check-in.';

  @override
  String get reportBadgesTitle => 'Badge dei membri';

  @override
  String get reportCoaAccounts => 'Conti suggeriti';

  @override
  String get reportCoaDisclaimer =>
      'Solo un\'anteprima. DesKilo non tiene un libro mastro e non fa la tua contabilità — il piano del tuo commercialista prevale sempre.';

  @override
  String get reportCoaIntro =>
      'Un suggerimento, non la tua contabilità. Sono i conti che un contabile del tuo paese userebbe di solito per uno spazio come il tuo.';

  @override
  String get reportCoaLabel => 'Denominazione';

  @override
  String get reportCoaNumber => 'Conto';

  @override
  String get reportCoaTitle => 'Piano dei conti — anteprima';

  @override
  String get reportColQty => 'Qtà';

  @override
  String get reportColTotal => 'Totale';

  @override
  String get reportColUnitPrice => 'Prezzo unit.';

  @override
  String get reportDesignEmpty => 'Banda vuota — aggiungi un elemento sotto.';

  @override
  String get reportDesignErrorInvalidDesign =>
      'Questo file non contiene alcun modello leggibile.';

  @override
  String get reportDesignErrorMalformed => 'Questo file non è JSON leggibile.';

  @override
  String get reportDesignErrorNotADesign =>
      'Questo file non è un modello di report DesKilo.';

  @override
  String get reportDesignErrorUnknownKind =>
      'Questo modello riguarda un report che questo spazio non ha.';

  @override
  String get reportDesignErrorVersion =>
      'Questo modello viene da una versione più recente di DesKilo.';

  @override
  String get reportDesignErrorWrongKind =>
      'Questo modello appartiene a un altro report. Aprilo e importalo lì.';

  @override
  String get reportDesignExport => 'Esporta questo modello';

  @override
  String get reportDesignFileTypeLabel => 'JSON';

  @override
  String get reportDesignImport => 'Importa un modello';

  @override
  String get reportDesignImported =>
      'Modello importato. Salva per conservarlo.';

  @override
  String get reportDesignerDesign => 'Progetto';

  @override
  String get reportDesignerDiscard => 'Scarta';

  @override
  String get reportDesignerDiscardBody =>
      'Le modifiche ai modelli non sono salvate.';

  @override
  String get reportDesignerDiscardTitle => 'Uscire senza salvare?';

  @override
  String get reportDesignerDrag => 'Trascina per riordinare';

  @override
  String reportDesignerError(String message) {
    return 'Il modello non si genera — $message';
  }

  @override
  String get reportDesignerFields => 'Campi';

  @override
  String get reportDesignerFieldsSearch => 'Cerca un campo';

  @override
  String get reportDesignerInsert => 'Inserisci elemento';

  @override
  String get reportDesignerKeepEditing => 'Continua a modificare';

  @override
  String get reportDesignerMoveTo => 'Sposta nella banda';

  @override
  String reportDesignerPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pagine',
      one: '1 pagina',
    );
    return '$_temp0';
  }

  @override
  String get reportDesignerPreview => 'Anteprima';

  @override
  String get reportDesignerRedo => 'Ripeti';

  @override
  String get reportDesignerReplace => 'Sostituisci';

  @override
  String get reportDesignerReplaceBody =>
      'Le bande di questo documento vengono sostituite. Annulla le riporta.';

  @override
  String get reportDesignerReplaceTitle => 'Sostituire il layout attuale?';

  @override
  String get reportDesignerSideBySide => 'Progettazione e anteprima affiancate';

  @override
  String get reportDesignerUndo => 'Annulla';

  @override
  String get reportDesignerZoom => 'Zoom';

  @override
  String get reportDesignerZoomFit => 'Adatta alla larghezza';

  @override
  String get reportDocAgreement => 'Accordo finanziario';

  @override
  String get reportDocBadges => 'Badge dei membri';

  @override
  String get reportDocCoa => 'Piano dei conti';

  @override
  String get reportDocPayments => 'Report dei pagamenti';

  @override
  String get reportDocSpaceCodes => 'Schede QR degli spazi';

  @override
  String get reportDocStatus => 'Situazione dello spazio';

  @override
  String get reportDocUsage => 'Report dei consumi';

  @override
  String get reportDocVat => 'Report IVA';

  @override
  String get reportDocWorkspace => 'Report dello spazio';

  @override
  String get reportDocWorkspaceSubtitle =>
      'Tutto sullo spazio — tramite il modello spazio dell\'editor di report';

  @override
  String get reportEditorMarkup => 'Markup';

  @override
  String get reportEditorTitle => 'Editor dei report';

  @override
  String get reportEditorVisual => 'Visuale';

  @override
  String get reportFieldGroupBank => 'Coordinate bancarie';

  @override
  String get reportFieldGroupDocument => 'Documento';

  @override
  String get reportFieldGroupLegal => 'Menzioni legali';

  @override
  String get reportFieldGroupLoops => 'Cicli righe e IVA';

  @override
  String get reportFieldGroupMember => 'Membro e spazio';

  @override
  String get reportFieldGroupMoney => 'Importi';

  @override
  String get reportFieldGroupSeller => 'Venditore';

  @override
  String get reportFieldGroupSites => 'Sedi';

  @override
  String get reportFieldGroupStatus => 'Situazione dello spazio';

  @override
  String get reportFieldGroupTexts => 'I tuoi testi';

  @override
  String get reportFieldGroupUsage => 'Rapporto di consumo';

  @override
  String get reportFieldGroupVat => 'Rapporto IVA';

  @override
  String get reportFieldMeaningAccountHolder => 'L\'intestatario del conto';

  @override
  String get reportFieldMeaningBankAccount => 'Il numero di conto';

  @override
  String get reportFieldMeaningBankCode => 'Il codice bancario';

  @override
  String get reportFieldMeaningBankName => 'Il nome della banca';

  @override
  String get reportFieldMeaningBic => 'Il BIC della banca';

  @override
  String get reportFieldMeaningBuyerReference =>
      'Il riferimento proprio dell\'acquirente (settore pubblico)';

  @override
  String get reportFieldMeaningCharges => 'Gli addebiti prima dei pagamenti';

  @override
  String get reportFieldMeaningClientAddress => 'Il blocco postale del cliente';

  @override
  String get reportFieldMeaningClientCompany => 'L\'azienda del cliente';

  @override
  String get reportFieldMeaningClientEmail => 'L\'e-mail del cliente';

  @override
  String get reportFieldMeaningClientLegalId =>
      'L\'identificativo legale del cliente';

  @override
  String get reportFieldMeaningClientMemberNumber =>
      'Il numero di socio del cliente';

  @override
  String get reportFieldMeaningClientName => 'Il nome completo del cliente';

  @override
  String get reportFieldMeaningClientPhone => 'Il telefono del cliente';

  @override
  String get reportFieldMeaningClientVatId => 'La partita IVA del cliente';

  @override
  String get reportFieldMeaningCopy => 'Vero su un duplicato';

  @override
  String get reportFieldMeaningCreditNote => 'Vero su una nota di credito';

  @override
  String get reportFieldMeaningDueDate => 'La data di scadenza';

  @override
  String get reportFieldMeaningEscompte =>
      'La dicitura dello sconto per pagamento anticipato';

  @override
  String get reportFieldMeaningExemptionReason =>
      'La dicitura di esenzione IVA';

  @override
  String get reportFieldMeaningHasVat => 'Vero quando si applica l\'IVA';

  @override
  String get reportFieldMeaningIban => 'L\'IBAN del conto';

  @override
  String get reportFieldMeaningInsurance =>
      'La dicitura dell\'assicurazione professionale';

  @override
  String get reportFieldMeaningIssued => 'La data di emissione';

  @override
  String get reportFieldMeaningIssuedBy => 'Chi ha emesso il documento';

  @override
  String get reportFieldMeaningLatePenalty =>
      'La dicitura delle penali di ritardo';

  @override
  String get reportFieldMeaningLines => 'Le righe della fattura — un ciclo';

  @override
  String get reportFieldMeaningMember => 'Il nome visualizzato del membro';

  @override
  String get reportFieldMeaningNetTotal => 'Il totale senza IVA';

  @override
  String get reportFieldMeaningNumber => 'Il numero del documento';

  @override
  String get reportFieldMeaningPaymentReference => 'La causale del pagamento';

  @override
  String get reportFieldMeaningPaymentTerms =>
      'La dicitura delle condizioni di pagamento';

  @override
  String get reportFieldMeaningPaymentTermsSource =>
      'Da dove vengono le condizioni (membro o spazio)';

  @override
  String get reportFieldMeaningPayments => 'I pagamenti già ricevuti';

  @override
  String get reportFieldMeaningPendingExpensesTotal =>
      'Spese ancora da convalidare';

  @override
  String get reportFieldMeaningPendingPaymentsTotal =>
      'Pagamenti ancora da confermare';

  @override
  String get reportFieldMeaningPeriod => 'Il mese coperto dal documento';

  @override
  String get reportFieldMeaningPeriodMonth =>
      'Il mese del periodo, per nome («Settembre»)';

  @override
  String get reportFieldMeaningPeriodYear => 'L\'anno del periodo';

  @override
  String get reportFieldMeaningProforma => 'Vero su una proforma';

  @override
  String get reportFieldMeaningPurchaseOrder =>
      'Il riferimento dell\'ordine d\'acquisto';

  @override
  String get reportFieldMeaningRecoveryIndemnity =>
      'La dicitura dell\'indennità di recupero';

  @override
  String get reportFieldMeaningRefundTotal => 'L\'importo rimborsato';

  @override
  String get reportFieldMeaningReplaces => 'Il numero della fattura sostituita';

  @override
  String get reportFieldMeaningSellerLegalForm =>
      'La forma giuridica del venditore';

  @override
  String get reportFieldMeaningSellerLegalId =>
      'L\'identificativo legale del venditore';

  @override
  String get reportFieldMeaningSellerRegistration =>
      'La registrazione del venditore';

  @override
  String get reportFieldMeaningSellerVatId => 'La partita IVA del venditore';

  @override
  String get reportFieldMeaningSiteAddress =>
      'L\'indirizzo della sede del documento';

  @override
  String get reportFieldMeaningSiteName => 'Il nome della sede del documento';

  @override
  String get reportFieldMeaningSpecialMentions =>
      'Le diciture particolari dello spazio';

  @override
  String get reportFieldMeaningStatusCreditNotes => 'Le note di credito emesse';

  @override
  String get reportFieldMeaningStatusCredits => 'I crediti concessi';

  @override
  String get reportFieldMeaningStatusFrom =>
      'Il primo giorno del periodo di situazione';

  @override
  String get reportFieldMeaningStatusInvoiced =>
      'Quanto lo spazio ha fatturato';

  @override
  String get reportFieldMeaningStatusMembers =>
      'Le righe per membro — un ciclo';

  @override
  String get reportFieldMeaningStatusNet => 'Entrate meno uscite';

  @override
  String get reportFieldMeaningStatusPayments => 'Quanto è stato incassato';

  @override
  String get reportFieldMeaningStatusReimbursed => 'Quanto è stato rimborsato';

  @override
  String get reportFieldMeaningStatusRepartitioned =>
      'Quanto è stato ripartito';

  @override
  String get reportFieldMeaningStatusTo =>
      'L\'ultimo giorno del periodo di situazione';

  @override
  String get reportFieldMeaningTotal => 'L\'importo dovuto, tutto compreso';

  @override
  String get reportFieldMeaningUsageExtraHalfDays =>
      'Mezze giornate oltre l\'abbonamento';

  @override
  String get reportFieldMeaningUsageIncludedHalfDays =>
      'Mezze giornate incluse nell\'abbonamento';

  @override
  String get reportFieldMeaningUsageOverage => 'L\'eccedenza addebitata';

  @override
  String get reportFieldMeaningUsagePaid =>
      'Quanto è costato il consumo del mese';

  @override
  String get reportFieldMeaningUsageRecords =>
      'Ogni registrazione di consumo — un ciclo';

  @override
  String get reportFieldMeaningUsageRemainingHalfDays =>
      'Mezze giornate rimanenti';

  @override
  String get reportFieldMeaningUsageSites => 'Le altre sedi del mese';

  @override
  String get reportFieldMeaningUsageSupplements =>
      'I supplementi per accessori';

  @override
  String get reportFieldMeaningUsageUsedHalfDays => 'Mezze giornate usate';

  @override
  String get reportFieldMeaningVat => 'L\'IVA per aliquota — un ciclo';

  @override
  String get reportFieldMeaningVatBasisNote =>
      'Se il periodo conta l\'incassato o l\'emesso';

  @override
  String get reportFieldMeaningVatExigibilityMention =>
      'Quando l\'IVA è esigibile, per esteso';

  @override
  String get reportFieldMeaningVatPeriod => 'Il periodo IVA dichiarato';

  @override
  String get reportFieldMeaningVatPeriodGross => 'Il totale lordo del periodo';

  @override
  String get reportFieldMeaningVatPeriodNet => 'Il totale netto del periodo';

  @override
  String get reportFieldMeaningVatPeriodVat => 'L\'IVA del periodo';

  @override
  String get reportFieldMeaningVatPositions =>
      'Ogni fattura del periodo IVA — un ciclo';

  @override
  String get reportFieldMeaningVatRateTotals =>
      'I totali del periodo per aliquota — un ciclo';

  @override
  String get reportFieldMeaningVatTotal => 'L\'IVA totale';

  @override
  String get reportFieldMeaningVoided => 'Vero quando la fattura è annullata';

  @override
  String get reportFieldMeaningWorkspace => 'Il nome dello spazio';

  @override
  String get reportFieldMeaningWorkspaceAddress =>
      'L\'indirizzo dello spazio, o quello della sede del documento';

  @override
  String get reportGuideInsertField => 'Inserisci un campo…';

  @override
  String reportGuideInsertedInto(String band) {
    return 'Inserito in $band';
  }

  @override
  String get reportGuideIntro =>
      'Tre bande compongono il PDF: intestazione, corpo, piè di pagina. Scrivete testo, mettete un campo dove va un valore e un segno di marcatura a inizio riga per lo stile. L\'XML della fattura elettronica non viene mai toccato.';

  @override
  String get reportGuideMarkupTitle => 'Marcatura di riga';

  @override
  String get reportGuideSnippetIf => 'Una riga solo se il valore esiste';

  @override
  String get reportGuideSnippetLoop => 'Una riga per ogni riga di fattura';

  @override
  String get reportGuideSnippetTitle =>
      'Il titolo: fattura, nota di credito o proforma';

  @override
  String get reportGuideSnippetsTitle => 'Pezzi pronti';

  @override
  String get reportGuideTitle => 'Campi e marcatura';

  @override
  String get reportImageAlign => 'Allineamento';

  @override
  String get reportImageAlignCenter => 'Centro';

  @override
  String get reportImageAlignLeft => 'Sinistra';

  @override
  String get reportImageAlignRight => 'Destra';

  @override
  String get reportImageSize => 'Dimensione';

  @override
  String get reportImageSizeLarge => 'Grande';

  @override
  String get reportImageSizeMedium => 'Media';

  @override
  String get reportImageSizeSmall => 'Piccola';

  @override
  String get reportImageUpload => 'Carica immagine';

  @override
  String get reportImagesEmpty =>
      'Nessuna immagine — carica il tuo logo, un timbro o una firma e riferiscila con ![nome].';

  @override
  String get reportImagesTitle => 'Immagini dei report';

  @override
  String get reportInsertImage => 'Inserisci immagine';

  @override
  String get reportLanguageAmbiguous =>
      'Questo paese ha più lingue — imposta prima la lingua dello spazio nelle Impostazioni dello spazio.';

  @override
  String get reportLayoutActive => 'Layout attivo';

  @override
  String get reportLayoutBands => 'Bande';

  @override
  String get reportLayoutExport => 'Esporta XML';

  @override
  String get reportLayoutFileTypeLabel => 'XML';

  @override
  String get reportLayoutImport => 'Importa XML';

  @override
  String get reportLayoutImported => 'Layout importato. Salva per conservarlo.';

  @override
  String get reportLayoutPreview => 'Anteprima pagina';

  @override
  String get reportLayoutRemove => 'Rimuovi il layout (bande)';

  @override
  String get reportLayoutSubtitle =>
      'Un layout indica dove si trova ogni elemento, in mm, cm, px o %. Esportalo, modificalo, verificalo con `dart run tool/report.dart check`, reimportalo. Quando esiste un layout è quello che si stampa; rimuovilo e tornano a stamparsi le bande.';

  @override
  String get reportLayoutTitle => 'Layout posizionato (XML)';

  @override
  String get reportLineBoldRow => 'Riga in grassetto';

  @override
  String get reportLineColumns => 'Inizio/fine colonne';

  @override
  String get reportLineColumnsSplit => 'Interruzione di colonna';

  @override
  String get reportLineDivider => 'Divisore';

  @override
  String get reportLineImage => 'Immagine';

  @override
  String get reportLineLogic => 'Logica';

  @override
  String get reportLineRow => 'Riga di tabella';

  @override
  String get reportLineSection => 'Sezione';

  @override
  String get reportLineSmall => 'Testo piccolo';

  @override
  String get reportLineSpacer => 'Spaziatura';

  @override
  String get reportLineText => 'Testo';

  @override
  String get reportLineTitle => 'Titolo';

  @override
  String get reportMarkupBoldRow => 'Una riga di tabella in grassetto';

  @override
  String get reportMarkupColumns => 'Colonne affiancate, separate da |||';

  @override
  String get reportMarkupHeading => 'Un titolo grande';

  @override
  String get reportMarkupImage =>
      'Un\'immagine della libreria: dimensione s/m/l, allineamento left/center/right';

  @override
  String get reportMarkupRule => 'Una linea orizzontale';

  @override
  String get reportMarkupSection => 'Un titolo di sezione';

  @override
  String get reportMarkupSmall => 'Testo piccolo e discreto';

  @override
  String get reportMarkupTable => 'Una riga di tabella, una cella per |';

  @override
  String get reportPaymentsPeriodTotal => 'Pagamenti del periodo';

  @override
  String get reportPendingExpenses => 'Spese in attesa';

  @override
  String get reportPendingPayments => 'Pagamenti in attesa';

  @override
  String get reportPresetClassic => 'Classico';

  @override
  String get reportPresetFormalLetter => 'Lettera formale';

  @override
  String get reportPresetSimple => 'Semplice';

  @override
  String get reportPresetVerbose => 'Dettagliato';

  @override
  String get reportPreviewFit => 'Adatta alla larghezza';

  @override
  String get reportPreviewSimulated => 'Anteprima rapida — dati di esempio';

  @override
  String get reportPreviewTitle =>
      'Anteprima rapida — la tua fattura più recente';

  @override
  String get reportPreviewZoomIn => 'Ingrandisci';

  @override
  String get reportPreviewZoomOut => 'Riduci';

  @override
  String get reportQuickView => 'Anteprima rapida';

  @override
  String get reportRegards => 'Cordiali saluti';

  @override
  String get reportSectionFeatures => 'Funzionalità';

  @override
  String get reportSectionPrices => 'Prezzi';

  @override
  String get reportSpaceCodesFooter =>
      'Una scheda che non corrisponde più al suo spazio inganna chi la scansiona: ristampa il foglio dopo aver spostato o rinominato uno spazio.';

  @override
  String get reportSpaceCodesIntro =>
      'Una tessera per postazione, tavolo, sala e piano. Attaccala sul suo spazio: scansionarla apre la stessa scheda del chiosco.';

  @override
  String get reportSpaceCodesTitle => 'Codici degli spazi';

  @override
  String get reportSubject => 'Oggetto';

  @override
  String get reportTemplateClearOverlay =>
      'Usa il predefinito per questa lingua';

  @override
  String get reportTemplateLangDefault => 'Predefinito (tutte le lingue)';

  @override
  String get reportTemplateLangInherits => 'Eredita il predefinito';

  @override
  String get reportTemplateLangOverridden => 'Modello proprio';

  @override
  String get reportTextsAdd => 'Aggiungi un testo';

  @override
  String get reportTextsHint =>
      'Le tue formulazioni, collocate in qualsiasi banda o layout come text.chiave. Ogni lingua può avere il proprio valore; uno vuoto ricade sulla lingua predefinita.';

  @override
  String get reportTextsInherited => 'Lingua predefinita';

  @override
  String get reportTextsKey => 'Chiave';

  @override
  String get reportTextsKeyExists => 'Questa chiave esiste già.';

  @override
  String get reportTextsKeyHint =>
      'Lettere, cifre e trattini bassi, es. saluto';

  @override
  String get reportTextsKeyInvalid =>
      'Solo lettere, cifre e trattini bassi, iniziando con una lettera.';

  @override
  String get reportTextsRemove => 'Rimuovi testo';

  @override
  String get reportTextsTitle => 'Testi';

  @override
  String get reportVisualAddLine => 'Aggiungi riga';

  @override
  String get reservationCalendarFileButton => 'Salva file calendario';

  @override
  String get reservationCalendarFileContents => 'Contenuto del file';

  @override
  String get reservationCalendarFileEvent => 'Evento';

  @override
  String get reservationCalendarFileLocation => 'Luogo';

  @override
  String get reservationCalendarFileName => 'File';

  @override
  String get reservationCalendarFileRefused =>
      'Questa prenotazione non può essere esportata: non è tua, oppure non esiste più.';

  @override
  String get reservationCalendarFileSnapshotNote =>
      'Questo file è un’istantanea della prenotazione così com’è ora. Se in seguito viene spostata o annullata, un file già salvato o condiviso non cambia — e un file condiviso non può essere ritirato.';

  @override
  String get reservationCalendarFileStale =>
      'La prenotazione è cambiata da questa anteprima. Controllala di nuovo prima di salvare.';

  @override
  String get reservationCalendarFileStatus => 'Stato';

  @override
  String get reservationCalendarFileStatusCancelled => 'Annullata';

  @override
  String get reservationCalendarFileStatusConfirmed => 'Confermata';

  @override
  String get reservationCalendarFileTitle => 'File calendario';

  @override
  String get reservationCalendarFileWhen => 'Quando';

  @override
  String get reservationCancelledSnack => 'Prenotazione annullata.';

  @override
  String get reservationDeleteReasonLabel => 'Motivo (facoltativo)';

  @override
  String get reservationDeleteRequestButton => 'Richiedi eliminazione';

  @override
  String get reservationDeleteRequestExplain =>
      'Le prenotazioni passate o con check-in non vengono eliminate direttamente. Un proprietario o admin deciderà: il check-in è stato semplicemente dimenticato (la prenotazione resta) o non è mai stata usata (viene rimossa)?';

  @override
  String get reservationDeleteSubmit => 'Invia richiesta';

  @override
  String get reservationDeleteSubmitted =>
      'Eliminazione richiesta — un proprietario o admin deciderà.';

  @override
  String get reservationEditTimes => 'Modifica orario';

  @override
  String get reservationEndEarlyAheadOnly =>
      'Scegli un orario ancora futuro e precedente alla fine attuale.';

  @override
  String get reservationEndEarlyButton => 'Terminare prima';

  @override
  String get reservationExtendButton => 'Restare più a lungo';

  @override
  String get reservationExtendLaterOnly =>
      'Scegli un orario dopo la fine attuale.';

  @override
  String get reservationLimitError =>
      'Limite di prenotazioni raggiunto — hai già il numero massimo di prenotazioni aperte.';

  @override
  String get reservationRecurring => 'Prenotazione ricorrente';

  @override
  String get reservationUpdatedSnack => 'Prenotazione aggiornata.';

  @override
  String get reserveBackToNow => 'Torna ad adesso';

  @override
  String get reserveBookingFailed =>
      'Prenotazione non riuscita — il posto potrebbe essere appena stato occupato.';

  @override
  String get reserveClosedShort => 'Chiuso';

  @override
  String get reserveDayView => 'Giorno';

  @override
  String get reserveFullDayChip => 'Giornata intera';

  @override
  String get reserveMonthView => 'Mese';

  @override
  String get reservePickDateTooltip => 'Scegli una data';

  @override
  String reserveStaleAvailability(String time) {
    return 'Offline — disponibilità delle $time. Un posto mostrato libero potrebbe essere stato preso nel frattempo.';
  }

  @override
  String get reserveStaleRetry => 'Riprova';

  @override
  String get reserveViewMenu => 'Vista';

  @override
  String get reserveWeekView => 'Settimana';

  @override
  String get reverseChargeSubtitle =>
      'Un cliente con partita IVA in un altro Stato membro è fatturato senza imposta e la assolve lui (art. 196). Disattiva se non fatturi mai imprese all\'estero.';

  @override
  String get reverseChargeTitle => 'Inversione contabile per imprese UE';

  @override
  String get rightsKindAccess => 'Avere una copia dei miei dati';

  @override
  String get rightsKindErasure => 'Cancellare i miei dati';

  @override
  String get rightsKindObjection => 'Oppormi a un uso dei miei dati';

  @override
  String get rightsKindPortability =>
      'Portare altrove i miei dati (leggibili da macchina)';

  @override
  String get rightsKindRectification => 'Rettificare i miei dati';

  @override
  String get rightsKindRestriction => 'Limitare l\'uso dei miei dati';

  @override
  String get rightsRequestAsk => 'Cosa chiedi allo spazio?';

  @override
  String get rightsRequestDetails => 'Dettagli (facoltativo)';

  @override
  String get rightsRequestFailed =>
      'Non è stato possibile inviare la richiesta. Riprova.';

  @override
  String get rightsRequestNew => 'Fai una richiesta';

  @override
  String get rightsRequestSend => 'Invia la richiesta';

  @override
  String rightsRequestSent(String date) {
    return 'Richiesta inviata — lo spazio risponde entro il $date.';
  }

  @override
  String get rightsRequestsEmpty => 'Nessuna richiesta per ora.';

  @override
  String get rightsRequestsHint =>
      'Chiedi allo spazio una copia, una rettifica, una limitazione o la cancellazione — risposta entro un mese di calendario.';

  @override
  String get rightsRequestsTitle => 'Le mie richieste di esercizio dei diritti';

  @override
  String get rightsStatusCompleted =>
      'Evasa — lo spazio ha registrato cosa ha fatto';

  @override
  String rightsStatusExtended(String date, String reason) {
    return 'Prorogata al $date: $reason';
  }

  @override
  String rightsStatusReceived(String date) {
    return 'Ricevuta — risposta entro il $date';
  }

  @override
  String rightsStatusRefused(String reason) {
    return 'Respinta: $reason';
  }

  @override
  String get roleAdmin => 'Amministratore';

  @override
  String get roleAssignImmediateHint => 'Ha effetto subito.';

  @override
  String get roleAssignNothing => 'Non resta nessun ruolo da dare.';

  @override
  String get roleAssignQuorumHint => 'Ha effetto una volta convalidato.';

  @override
  String roleAssignSheetTitle(String name) {
    return 'Dai un ruolo a $name';
  }

  @override
  String get roleEditorActive => 'In uso';

  @override
  String get roleEditorHolders => 'Membri con questo ruolo';

  @override
  String get roleEditorKey => 'Chiave';

  @override
  String get roleEditorKeyHelp =>
      'Minuscole, cifre e trattini bassi. Non cambia mai: le persone che hanno il ruolo vi si appoggiano.';

  @override
  String roleEditorNameFor(String locale) {
    return 'Nome ($locale)';
  }

  @override
  String get roleEditorNobody => 'Ancora nessuno.';

  @override
  String get roleEditorNotYourself => 'Non puoi darti un ruolo da sola.';

  @override
  String get roleEditorPermissions => 'Cosa aggiunge';

  @override
  String get roleEditorSave => 'Salva il ruolo';

  @override
  String get roleEditorSaveFailed => 'Il ruolo non è stato salvato.';

  @override
  String get roleGiveFailed => 'Il ruolo non è stato assegnato.';

  @override
  String get roleGiven => 'Ruolo assegnato.';

  @override
  String get roleHoldersAdd => 'Aggiungi un membro';

  @override
  String get roleMember => 'Tutti i membri';

  @override
  String get roleOwner => 'Proprietario';

  @override
  String get roleRefusalExceedsYours =>
      'Questo ruolo può fare cose che tu non puoi, quindi solo il proprietario lo dà.';

  @override
  String get roleRefusalNotAssignable =>
      'Questo membro non può avere questo ruolo.';

  @override
  String get roleRefusalNotPermitted =>
      'Solo chi gestisce i ruoli può dare questo.';

  @override
  String get roleRefusalOwnerOnly =>
      'Solo il proprietario dà un ruolo che gestisce i ruoli.';

  @override
  String get roleTakeBackFailed => 'Il ruolo non è stato revocato.';

  @override
  String get roleTakenBack => 'Ruolo revocato.';

  @override
  String get rolesIntroEditor =>
      'Qui tutti sono membri. Un ruolo aggiunge ciò che i suoi titolari possono fare e non toglie mai nulla. Il proprietario detiene sempre tutti i permessi; un comproprietario può averne meno.';

  @override
  String get rolesIntroReadOnly =>
      'Sola lettura: questi sono i permessi di ogni ruolo. Il tuo ruolo è evidenziato.';

  @override
  String get rolesOfSpaceAdd => 'Aggiungi un ruolo';

  @override
  String get rolesOfSpaceEmpty => 'Ancora nessun ruolo.';

  @override
  String get rolesOfSpaceInactive => 'Messo da parte';

  @override
  String get rolesOfSpaceSubtitle =>
      'Ognuno aggiunge permessi a ciò che i suoi titolari possono già fare. Nessuno toglie nulla, e la proprietaria mantiene sempre tutti i permessi.';

  @override
  String get rolesOfSpaceTitle => 'I ruoli di questo spazio';

  @override
  String get rolesOwnRolesLink => 'I ruoli di questo spazio';

  @override
  String get rolesTitle => 'Ruoli';

  @override
  String get rolesYourRole => 'Il tuo ruolo';

  @override
  String get saftDocumentsOnly => 'Solo documenti';

  @override
  String get saftLedgerIntro =>
      'Con i numeri di conto il file porta scritture in partita doppia che il tuo commercialista può importare invece di digitare. Coprono le vendite e i relativi incassi — non l’intera contabilità.';

  @override
  String get saftLedgerTitle => 'Includere le scritture?';

  @override
  String get saftWithPostings => 'Con le scritture';

  @override
  String get sageAccountsIntro =>
      'I valori predefiniti sono i conti che Sage fornisce di serie. Il codice IVA decide su quale dichiarazione finiscono queste scritture: verificalo con il commercialista se non sei all’aliquota ordinaria.';

  @override
  String get sageAccountsTitle => 'Esportazione Sage';

  @override
  String get sageTaxCode => 'Codice IVA (T1 / T0 / T9)';

  @override
  String get scanCameraWebUnavailable =>
      'La scansione con fotocamera non è disponibile nel browser — digita il codice o avvicina un tag NFC al dispositivo (Chrome su Android).';

  @override
  String get scanJoinHelp =>
      'Inquadra il QR d’invito con la fotocamera — vedrai lo spazio prima di aderire.';

  @override
  String get scanJoinNotAnInvite =>
      'Questo QR non è un invito DesKilo — scansiona quello del messaggio d’invito.';

  @override
  String get scanJoinTitle => 'Scansiona il QR dello spazio';

  @override
  String get scheduleCancel => 'Termina questa programmazione';

  @override
  String get scheduleDaily => 'giornaliera';

  @override
  String get scheduleEndsOn => 'Fino al (facoltativo)';

  @override
  String scheduleEveryDays(Object count) {
    return 'ogni $count giorni';
  }

  @override
  String get scheduleEveryLabel => 'Ogni';

  @override
  String scheduleEveryMonths(Object count) {
    return 'ogni $count mesi';
  }

  @override
  String scheduleEveryWeeks(Object count) {
    return 'ogni $count settimane';
  }

  @override
  String get scheduleMissingFields => 'Servono il nome e l’importo.';

  @override
  String get scheduleMonthly => 'mensile';

  @override
  String get scheduleNew => 'Programma una spesa ricorrente';

  @override
  String scheduleNextDue(Object date) {
    return 'prossima: $date';
  }

  @override
  String get scheduleNoEnd => 'Nessuna data di fine';

  @override
  String get schedulePending =>
      'Programmato — in attesa della conferma dei validatori.';

  @override
  String get scheduleStartsOn => 'Prima scadenza';

  @override
  String get scheduleStatusActive => 'Attiva';

  @override
  String get scheduleStatusEnded => 'Terminata';

  @override
  String get scheduleStatusPending => 'In attesa di validazione';

  @override
  String get scheduleStatusRejected => 'Rifiutata';

  @override
  String get scheduleSubmit => 'Programma';

  @override
  String scheduleTimes(Object count) {
    return '$count volte';
  }

  @override
  String get scheduleTimesLabel =>
      'Ripetizioni (vuoto = fino alla data di fine)';

  @override
  String get scheduleTitleLabel => 'Cosa (es. Internet)';

  @override
  String get scheduleUnitDays => 'giorni';

  @override
  String get scheduleUnitLabel => 'Unità';

  @override
  String get scheduleUnitMonths => 'mesi';

  @override
  String get scheduleUnitWeeks => 'settimane';

  @override
  String get scheduleUnitYears => 'anni';

  @override
  String scheduleUntil(Object date) {
    return 'fino al $date';
  }

  @override
  String get scheduleValidationHint =>
      'La programmazione passa prima dai validatori. Ogni scadenza ti viene poi presentata: confermata a questo importo conta subito; un importo diverso si spiega e torna in validazione.';

  @override
  String get scheduleWeekly => 'settimanale';

  @override
  String get scheduleYearly => 'annuale';

  @override
  String get scheduledAwaitingTitle => 'Spese programmate da confermare';

  @override
  String get scheduledExpensesEmpty => 'Nessuna spesa programmata per ora.';

  @override
  String scheduledExpensesFinished(int count) {
    return 'Terminate e rifiutate ($count)';
  }

  @override
  String get scheduledExpensesIntro =>
      'Gli abbonamenti che lo spazio paga — internet, telefono, elettricità. La programmazione è validata una volta; ogni scadenza ti viene presentata prima di contare.';

  @override
  String get scheduledExpensesTitle => 'Spese programmate';

  @override
  String schemaUpdateBody(int version) {
    return 'Questa app richiede la versione $version dello schema DesKilo, e il server a cui si collega ne esegue una più vecchia. Finché il server non viene aggiornato, l\'app fallirebbe in modi che non saprebbe spiegare, quindi si ferma qui.';
  }

  @override
  String get schemaUpdateMember =>
      'Altrimenti: avvisa la persona che gestisce il tuo spazio. Nulla di ciò che hai inserito va perso.';

  @override
  String get schemaUpdateOperator =>
      'Se gestisci questo server: applica le migrazioni mancanti con `dart run tool/instance.dart install --ref <progetto>`. Viene eseguito solo ciò che manca.';

  @override
  String get schemaUpdateRetry => 'Controlla di nuovo';

  @override
  String get schemaUpdateServer => 'Impostazioni del server';

  @override
  String get schemaUpdateTitle => 'Questo server deve essere aggiornato';

  @override
  String get seatDayAhead => 'Più tardi';

  @override
  String get seatDayFree => 'Libera — prenota';

  @override
  String get seatDayMine => 'Tu';

  @override
  String get seatDayNow => 'Ora';

  @override
  String get seatDayPast => 'Finito';

  @override
  String get seatDaySomeone => 'Un membro';

  @override
  String get seatDaySubtitle =>
      'Chi occupa questa postazione, e quando. Tocca una prenotazione per aprirla, o una fascia libera per prenderla.';

  @override
  String seatDayTitle(String seat) {
    return 'Postazione $seat oggi';
  }

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
  String get serviceOutOfStock => 'Esaurito';

  @override
  String get serviceOutOfStockHint =>
      'Niente più sullo scaffale — la prossima scorta lo rifornisce.';

  @override
  String serviceStockCount(int count) {
    return '$count in scorta';
  }

  @override
  String get servicesActive => 'Attivo';

  @override
  String get servicesEdit => 'Modifica servizio';

  @override
  String get servicesEmpty => 'Ancora nessun servizio.';

  @override
  String get servicesInactive => 'Inattivo';

  @override
  String get servicesName => 'Nome';

  @override
  String get servicesNew => 'Nuovo servizio';

  @override
  String get servicesPrice => 'Prezzo';

  @override
  String get servicesTitle => 'Servizi';

  @override
  String get settingsBillingReports => 'Fatturazione e report';

  @override
  String get settingsFrontCamera => 'Scansiona con la fotocamera frontale';

  @override
  String get settingsFrontCameraDesc =>
      'I badge vengono letti con la fotocamera lato schermo — disattiva per usare la fotocamera posteriore.';

  @override
  String get settingsSectionAccount => 'Il mio account';

  @override
  String get settingsSectionAdministration => 'Amministrazione';

  @override
  String get settingsSectionAdvanced => 'Avanzate';

  @override
  String get settingsSectionGovernance => 'Governance';

  @override
  String get settingsSectionHelpAbout => 'Aiuto e informazioni';

  @override
  String get settingsSectionMembership => 'La mia iscrizione';

  @override
  String get settingsSectionWorkspace => 'Questo spazio';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settlementAction => 'Raggruppa in una fattura';

  @override
  String get settlementAnnexAlone => 'Solo questa fattura';

  @override
  String settlementAnnexBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Le $count fatture che questa sostituisce possono seguirla, ognuna su pagine proprie e timbrata come raggruppata.',
      one: 'La fattura che questa sostituisce può seguirla, su pagine proprie e timbrata come raggruppata.',
    );
    return '$_temp0';
  }

  @override
  String get settlementAnnexTitle => 'Allegare le fatture raggruppate?';

  @override
  String get settlementAnnexWith => 'Allegale';

  @override
  String settlementConfirm(int count, String amount) {
    return 'Raggruppare $count fatture in una da $amount?';
  }

  @override
  String get settlementDocumentationOnly =>
      'Solo documentazione: ogni operazione avviene sulla fattura di raggruppamento.';

  @override
  String settlementDone(String number) {
    return 'Raggruppate in $number.';
  }

  @override
  String settlementFoldedIn(String number) {
    return 'Raggruppata in $number';
  }

  @override
  String get settlementNeedsTwo =>
      'Scegli almeno due fatture aperte dello stesso membro.';

  @override
  String settlementPaidThrough(String number) {
    return 'Pagata tramite $number';
  }

  @override
  String get settlementRegroups => 'Questa fattura raggruppa';

  @override
  String settlementRegroupsNumbers(String numbers) {
    return 'Raggruppa $numbers';
  }

  @override
  String get settlementSettledBy =>
      'Raggruppata in un’altra fattura: è quella a essere dovuta e sollecitata.';

  @override
  String get settlementSourcePdf => 'PDF (raggruppata)';

  @override
  String get settlementStepPick => 'Scegli le fatture';

  @override
  String get settlementSummaryHint =>
      'Queste fatture vengono raggruppate in un documento di saldo; ognuna resta leggibile dietro di esso.';

  @override
  String get settlementVatNote =>
      'Le righe e la loro IVA sono riprese dalle fatture raggruppate; la dichiarazione IVA conta gli originali una sola volta.';

  @override
  String get shellBarHiddenAnnounce => 'Barra di navigazione nascosta';

  @override
  String get shellBarHideHint => 'Tieni premuto per la vista a schermo intero';

  @override
  String get shellBarShowHint =>
      'Tieni premuto per mostrare la barra di navigazione';

  @override
  String get shellBarShownAnnounce => 'Barra di navigazione visibile';

  @override
  String shellPendingDecisions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count decisioni ti aspettano',
      one: '1 decisione ti aspetta',
    );
    return '$_temp0';
  }

  @override
  String get shellReserveButton => 'Prenota';

  @override
  String get shellSwipeCoachMark =>
      'Scorri la barra verso il basso per la vista a schermo intero. Scorri verso l’alto, o tieni premuto il pulsante Prenota, per riportarla.';

  @override
  String get siteCity => 'Città';

  @override
  String get siteCountry => 'Paese (codice)';

  @override
  String get siteDelete => 'Elimina questa sede';

  @override
  String get siteDeleteHint =>
      'I suoi piani e soci tornano alla sede predefinita.';

  @override
  String get siteExemptionReason => 'Dicitura di esenzione (questa entità)';

  @override
  String get siteLegalId => 'Registrazione dell\'unità locale';

  @override
  String get siteName => 'Nome della sede';

  @override
  String get sitePostalCode => 'CAP';

  @override
  String get siteRegistrationHint =>
      'Solo se la sede è un\'entità giuridica distinta — di solito è uno spazio separato. Vuoto: valgono i numeri dello spazio.';

  @override
  String get siteSaved => 'Sede salvata.';

  @override
  String get siteStreet => 'Via';

  @override
  String get siteVatId => 'Partita IVA (questa entità)';

  @override
  String get sitesAdd => 'Aggiungi una sede';

  @override
  String get sitesDefault => 'Sede predefinita';

  @override
  String get sitesIntro =>
      'Ogni piano appartiene a una sede; la sede predefinita porta l\'indirizzo dello spazio. Un socio ha una sede di riferimento: è l\'indirizzo sui suoi documenti.';

  @override
  String get sitesLevels => 'Piani';

  @override
  String get sitesSubtitle =>
      'Indirizzi, i piani di ciascuna e la sede di ogni socio';

  @override
  String get sitesTitle => 'Sedi';

  @override
  String get spaceAlreadyCheckedInHere =>
      'Siete già registrati qui. Scegliete « Registra l\'uscita » per liberare il posto.';

  @override
  String get spaceBackToMe => 'Torna a Io';

  @override
  String get spaceBlockedByYou => 'Hai già questo spazio per quel periodo.';

  @override
  String get spaceCardInfoLabel => 'Informazioni sulla scheda';

  @override
  String get spaceCardInfoWorkspace => 'Spazio di lavoro';

  @override
  String get spaceCardSizeLabel => 'Dimensione della scheda';

  @override
  String get spaceCardSizeLarge => 'Grande';

  @override
  String get spaceCardSizeMedium => 'Media';

  @override
  String get spaceCardSizeSmall => 'Piccola';

  @override
  String get spaceChipTooltip => 'Cambia spazio';

  @override
  String get spaceCodesDesc =>
      'Una scheda QR stampabile per postazione, tavolo, ufficio e piano — i membri la scansionano per prenotare o fare check-in.';

  @override
  String get spaceCodesTitle => 'Codici QR degli spazi (PDF)';

  @override
  String get spaceKindDesk => 'Tavolo';

  @override
  String get spaceKindLevel => 'Piano';

  @override
  String get spaceKindOffice => 'Ufficio';

  @override
  String get spaceKindSeat => 'Postazione';

  @override
  String get spaceManageMyBooking => 'Gestisci la mia prenotazione';

  @override
  String spaceMessageReserver(String name) {
    return 'Scrivi a $name';
  }

  @override
  String get spaceNotBookable =>
      'Questo spazio non è configurato per le prenotazioni intere.';

  @override
  String get spaceNotWholeBookable =>
      'Questo spazio non è configurato per la prenotazione intera — il proprietario attiva \"Prenotabile per intero\" nell\'editor.';

  @override
  String get spaceQrSizeLabel => 'Dimensione del codice QR';

  @override
  String get spaceScanField => 'Codice';

  @override
  String get spaceScanHint =>
      'Inquadra la scheda di una postazione, tavolo, ufficio o piano — oppure digita il codice.';

  @override
  String get spaceScanInvalid => 'Non è un codice spazio di questo workspace.';

  @override
  String get spaceScanNfcHint =>
      '…oppure avvicina il telefono al tag NFC di una sedia.';

  @override
  String get spaceScanTitle => 'Scansiona un codice spazio';

  @override
  String get spaceScanUnknown =>
      'Questo codice non corrisponde più a nessuno spazio qui.';

  @override
  String get spaceScanUnknownTag =>
      'Questo tag non è collegato a nessuna sedia.';

  @override
  String get spaceSeatTaken => 'Occupato';

  @override
  String get spaceYoursCheckedIn =>
      'Hai effettuato il check-in qui per questa fascia.';

  @override
  String get spaceYoursNow => 'Riservato da te per questa fascia.';

  @override
  String get statusAwaiting => 'In attesa';

  @override
  String get statusCreditNotes => 'Note di credito';

  @override
  String get statusCredits => 'Crediti concessi';

  @override
  String get statusFrom => 'Dal';

  @override
  String get statusInvoiced => 'Fatturato';

  @override
  String get statusMembers => 'Soci';

  @override
  String get statusNet => 'Netto';

  @override
  String get statusPaymentsMatched => 'Pagamenti abbinati';

  @override
  String get statusPaymentsReceived => 'Pagamenti ricevuti';

  @override
  String get statusPrint => 'Stampa la situazione';

  @override
  String get statusReimbursed => 'Spese rimborsate';

  @override
  String get statusRepartitioned => 'Spese ripartite';

  @override
  String get statusSubtitle => 'Entrate, spese e soci in un periodo';

  @override
  String get statusTitle => 'Situazione dello spazio';

  @override
  String get statusTo => 'Al';

  @override
  String get subprocessAttendance => 'Presenze e utilizzo';

  @override
  String get subprocessAttendanceDesc =>
      'Registrare presenze e chiudere gli ingressi a fine giornata.';

  @override
  String get subprocessAvailability => 'Giorni e orari di apertura';

  @override
  String get subprocessAvailabilityDesc =>
      'Definire orari e generare giorni di chiusura.';

  @override
  String get subprocessCalendar => 'Viste del calendario';

  @override
  String get subprocessCalendarDesc =>
      'Visualizzare prenotazioni e decisioni in sospeso nel tempo.';

  @override
  String get subprocessCollection => 'Incasso dei pagamenti';

  @override
  String get subprocessCollectionDesc =>
      'Incassare pagamenti e sollecitare fatture scadute.';

  @override
  String get subprocessCommunication => 'Comunicazione tra membri';

  @override
  String get subprocessCommunicationDesc =>
      'Scambiare messaggi e seguire gli aggiornamenti.';

  @override
  String get subprocessConfiguration => 'Configurazione e distribuzione';

  @override
  String get subprocessConfigurationDesc =>
      'Trasferire configurazioni, usare modelli e gestire istanze.';

  @override
  String get subprocessDecisions => 'Decisioni e approvazioni';

  @override
  String get subprocessDecisionsDesc =>
      'Esaminare le azioni e registrare le approvazioni richieste.';

  @override
  String get subprocessDelivery => 'Invio esterno';

  @override
  String get subprocessDeliveryDesc =>
      'Collegare notifiche push, WhatsApp e invio delle fatture elettroniche.';

  @override
  String get subprocessDocuments => 'Pubblicazione dei documenti';

  @override
  String get subprocessDocumentsDesc =>
      'Pubblicare documenti e generare file stampabili.';

  @override
  String get subprocessExpenses => 'Spese condivise';

  @override
  String get subprocessExpensesDesc =>
      'Ripartire costi, rifornire materiali e pianificare spese ricorrenti.';

  @override
  String get subprocessExperience => 'Utilizzo dell’applicazione';

  @override
  String get subprocessExperienceDesc =>
      'Adattare guida, navigazione e preferenze di visualizzazione.';

  @override
  String get subprocessInvoicing => 'Fatturazione';

  @override
  String get subprocessInvoicingDesc =>
      'Emettere e seguire fatture immutabili fino al saldo.';

  @override
  String get subprocessPeople => 'Persone e adesioni';

  @override
  String get subprocessPeopleDesc =>
      'Identificare i membri e gestirne adesioni e permessi.';

  @override
  String get subprocessPhysicalAccess => 'Accesso fisico';

  @override
  String get subprocessPhysicalAccessDesc =>
      'Usare badge, tag delle postazioni e il chiosco condiviso.';

  @override
  String get subprocessPresentation => 'Presentazione dello spazio';

  @override
  String get subprocessPresentationDesc =>
      'Aiutare a riconoscere persone e luoghi sulla planimetria.';

  @override
  String get subprocessPricing => 'Servizi e prezzi';

  @override
  String get subprocessPricingDesc =>
      'Definire prezzi di servizi e accessori e concordare le condizioni.';

  @override
  String get subprocessPrivacy => 'Accesso ai dati ed esportazioni';

  @override
  String get subprocessPrivacyDesc =>
      'Consultare gli accessi ai dati personali ed esportare i dati.';

  @override
  String get subprocessRecords => 'Registrazioni finanziarie';

  @override
  String get subprocessRecordsDesc =>
      'Comprendere saldi, pagamenti ed estratti dei membri.';

  @override
  String get subprocessReportDesign => 'Progettazione dei rapporti';

  @override
  String get subprocessReportDesignDesc =>
      'Progettare rapporti e gestirne testi e impaginazioni.';

  @override
  String get subprocessReservations => 'Prenotare postazioni e spazi';

  @override
  String get subprocessReservationsDesc =>
      'Prenotare posti o interi spazi secondo le regole.';

  @override
  String get subprocessStructure => 'Struttura dello spazio';

  @override
  String get subprocessStructureDesc =>
      'Gestire sedi e disponibilità degli elementi della planimetria.';

  @override
  String get subprocessTax => 'Gestione dell’IVA';

  @override
  String get subprocessTaxDesc =>
      'Gestire gruppi, aliquote e dichiarazioni IVA.';

  @override
  String get supportChanged =>
      'Il contesto è cambiato. Prepara una nuova anteprima.';

  @override
  String get supportDay => 'Ultime 24 ore';

  @override
  String get supportDemo => 'Demo: contesto locale simulato';

  @override
  String get supportFailed => 'Impossibile preparare i dettagli. Riprova.';

  @override
  String get supportHour => 'Ultima ora';

  @override
  String get supportPrepare => 'Prepara anteprima';

  @override
  String get supportPrivacy =>
      'Sono inclusi solo conteggi limitati di questo dispositivo e verifiche note. Sono esclusi identità, indirizzi del server, credenziali, dati aziendali e registri grezzi. Le verifiche sconosciute non sono disponibili; un operatore può eseguire doctor --support-json separatamente. I file condivisi non possono essere revocati.';

  @override
  String get supportSaved => 'Salvato localmente';

  @override
  String supportSize(int bytes) {
    final intl.NumberFormat bytesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String bytesString = bytesNumberFormat.format(bytes);

    return 'Anteprima: $bytesString byte';
  }

  @override
  String get supportTitle => 'Dettagli per l’assistenza';

  @override
  String get tabCalendar => 'Calendario';

  @override
  String get tabEvents => 'Eventi';

  @override
  String get tabMoney => 'Finanze';

  @override
  String get tabPlan => 'Piantina';

  @override
  String get taskExportActionBack => 'Torna indietro.';

  @override
  String get taskExportActionCancelReview =>
      'Annulla il riepilogo senza prenotare.';

  @override
  String taskExportActionChangeField(String field) {
    return 'Modifica il campo: $field.';
  }

  @override
  String get taskExportActionConfirmBooking => 'Conferma la prenotazione.';

  @override
  String get taskExportActionOpenReserve => 'Apri la schermata Prenota.';

  @override
  String get taskExportActionSelectDate => 'Scegli la data.';

  @override
  String get taskExportActionSelectPeriod => 'Scegli il periodo.';

  @override
  String get taskExportActionSelectResource => 'Scegli un posto.';

  @override
  String get taskExportActionSwitchView => 'Cambia la vista.';

  @override
  String get taskExportActionUnknown =>
      'Un\'azione che questa versione non sa descrivere.';

  @override
  String get taskExportActionViewDetails =>
      'Apri il dettaglio della prenotazione.';

  @override
  String get taskExportAuthored =>
      'Aggiunto durante la modifica: non osservato dal registratore.';

  @override
  String get taskExportCompletenessComplete =>
      'Completa: la registrazione è stata fermata dalla persona e ogni comando ha ricevuto una risposta.';

  @override
  String get taskExportCompletenessInterrupted =>
      'Interrotta: l\'app si è chiusa durante la registrazione.';

  @override
  String get taskExportCompletenessPartial =>
      'Parziale: la registrazione è terminata prima o un comando non ha ricevuto risposta.';

  @override
  String taskExportDetail(String field, String value) {
    return '$field: $value';
  }

  @override
  String get taskExportDocFallbackTitle => 'Procedura dell\'attività';

  @override
  String taskExportDuration(int minutes, int seconds) {
    return 'Durata: $minutes min $seconds s';
  }

  @override
  String get taskExportEndInterrupted => 'Fermata perché l\'app si è chiusa.';

  @override
  String get taskExportEndLimitReached =>
      'Fermata perché è stato raggiunto un limite di passaggi, dimensione o durata.';

  @override
  String get taskExportEndScopeChanged =>
      'Fermata perché l\'account, lo spazio o l\'installazione sono cambiati.';

  @override
  String get taskExportEndStopped =>
      'Fermata dalla persona che l\'ha registrata.';

  @override
  String get taskExportEndStorageFailed =>
      'Fermata perché la scrittura della registrazione non è riuscita.';

  @override
  String taskExportExcluded(String category) {
    return 'È stata visitata una schermata protetta ($category); non vi è stato registrato nulla.';
  }

  @override
  String get taskExportFieldAccessories => 'Accessori';

  @override
  String get taskExportFieldCheckIn => 'Check-in';

  @override
  String get taskExportFieldDateRelation => 'Data';

  @override
  String get taskExportFieldForWhom => 'Per chi';

  @override
  String get taskExportFieldPeriod => 'Periodo';

  @override
  String get taskExportFieldRefusal => 'Motivo';

  @override
  String get taskExportFieldRepeat => 'Ripetizione';

  @override
  String get taskExportFieldResourceKind => 'Tipo di posto';

  @override
  String get taskExportFieldSeriesResult => 'Serie';

  @override
  String get taskExportFieldTime => 'Orario';

  @override
  String get taskExportFieldUnknown =>
      'un campo che questa versione non sa descrivere';

  @override
  String get taskExportFieldViewMode => 'Vista';

  @override
  String taskExportFooter(String page, String pages) {
    return 'Pagina $page di $pages';
  }

  @override
  String get taskExportIllustrationNotApproved =>
      'Illustrazione non inclusa: non è stata approvata.';

  @override
  String get taskExportIncludeIllustrations =>
      'Includi le illustrazioni approvate';

  @override
  String get taskExportIntro =>
      'Questo documento descrive, passo dopo passo, un\'attività registrata in DesKilo. È documentazione: non riproduce l\'attività e non dimostra che sia riuscita. Solo ciò che la registrazione ha osservato è indicato come osservato.';

  @override
  String get taskExportKindEdited =>
      'Procedura modificata: derivata da una registrazione e modificata da una persona.';

  @override
  String get taskExportKindSource =>
      'Acquisizione originale: i passaggi sono stati osservati dal registratore.';

  @override
  String get taskExportLimitEdited =>
      'I passaggi segnati come aggiunti durante la modifica sono stati scritti da una persona, non osservati.';

  @override
  String get taskExportLimitIncomplete =>
      'La registrazione è incompleta: non si sa cosa sia successo dopo l\'ultimo passaggio mostrato.';

  @override
  String get taskExportLimitNoIllustrations =>
      'Questo documento non contiene illustrazioni.';

  @override
  String get taskExportLimitNotRunnable =>
      'Alcuni passaggi provengono da una versione più recente e non possono essere descritti qui.';

  @override
  String get taskExportLimitRecreated =>
      'Le illustrazioni sono ricreate dai dati sicuri della registrazione, con nomi di posti inventati; non sono screenshot dello schermo.';

  @override
  String get taskExportLimitValues =>
      'I valori digitati o scelti non vengono mai registrati: appare solo il loro tipo, e «non registrato» sostituisce tutto il resto.';

  @override
  String get taskExportNoResult =>
      'Per questo comando non è stato registrato alcun risultato.';

  @override
  String taskExportNote(String note) {
    return 'Nota scritta dalla persona che ha registrato (parole sue): $note';
  }

  @override
  String get taskExportNoteOmitted =>
      'Una nota personale è stata esclusa da questo documento.';

  @override
  String taskExportOnScreen(String screen) {
    return 'Schermata: $screen';
  }

  @override
  String get taskExportOutcomeConfirmed => 'la prenotazione è stata confermata';

  @override
  String get taskExportOutcomeRefused => 'la prenotazione è stata rifiutata';

  @override
  String get taskExportOutcomeRequested =>
      'la prenotazione è stata richiesta e attende una decisione';

  @override
  String get taskExportOutcomeSeriesBooked => 'la serie è stata prenotata';

  @override
  String get taskExportOutcomeUnknown =>
      'nessuna risposta ha potuto essere confermata; il risultato è sconosciuto';

  @override
  String get taskExportOutcomeUnregistered =>
      'un risultato che questa versione non sa descrivere';

  @override
  String taskExportPauses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pause',
      one: 'Una pausa',
      zero: 'Nessuna pausa',
    );
    return '$_temp0';
  }

  @override
  String taskExportPlatform(String platform) {
    return 'Registrata su: $platform';
  }

  @override
  String get taskExportPrereqBookablePlace => 'Almeno un posto è prenotabile.';

  @override
  String get taskExportPrereqSignedIn => 'Hai effettuato l\'accesso.';

  @override
  String taskExportPrereqStartsOn(String screen) {
    return 'Inizia da $screen.';
  }

  @override
  String get taskExportPrereqUnknown =>
      'Una condizione che questa versione non sa descrivere.';

  @override
  String get taskExportPrereqWorkspaceMember => 'Sei membro dello spazio.';

  @override
  String get taskExportProtectedAuthentication => 'accesso';

  @override
  String get taskExportProtectedIdentity => 'identità';

  @override
  String get taskExportProtectedMessenger => 'messaggi';

  @override
  String get taskExportProtectedOperator => 'operatore';

  @override
  String get taskExportProtectedPayment => 'pagamento';

  @override
  String get taskExportProtectedProvider => 'fornitore';

  @override
  String get taskExportProtectedSecrets => 'segreti';

  @override
  String get taskExportRefused =>
      'Questa registrazione non può essere esportata come documento Word.';

  @override
  String taskExportResult(String outcome) {
    return 'Risultato: $outcome';
  }

  @override
  String taskExportRevision(String revision) {
    return 'Revisione del contenuto: $revision';
  }

  @override
  String get taskExportSaveFailed =>
      'Impossibile salvare il documento Word. La registrazione è invariata.';

  @override
  String taskExportSaved(String file) {
    return 'Documento Word salvato: $file';
  }

  @override
  String taskExportSceneAlt(String screen, String step) {
    return 'Illustrazione: $screen – $step';
  }

  @override
  String get taskExportSceneBookingTitle => 'Prenota un posto';

  @override
  String get taskExportSceneCancel => 'Annulla';

  @override
  String get taskExportSceneConfirm => 'Conferma';

  @override
  String get taskExportSceneDetailTitle => 'Prenotazione';

  @override
  String get taskExportSceneLater => 'Più avanti';

  @override
  String get taskExportSceneProvenance =>
      'Illustrazione ricreata dalla registrazione, non uno screenshot';

  @override
  String get taskExportSectionAbout => 'Informazioni su questa registrazione';

  @override
  String get taskExportSectionBefore => 'Prima di iniziare';

  @override
  String get taskExportSectionLimits => 'Limiti';

  @override
  String get taskExportSectionSteps => 'Passaggi';

  @override
  String get taskExportStale =>
      'Lo storyboard appartiene a un\'altra versione di questa registrazione. Rivedilo prima di esportare.';

  @override
  String get taskExportStoryboardApprove => 'Approva l\'illustrazione';

  @override
  String get taskExportStoryboardGap =>
      'Lacuna: qui non è stato registrato nulla';

  @override
  String get taskExportStoryboardInclude => 'Includi';

  @override
  String get taskExportStoryboardLeftOut =>
      'Passaggio escluso durante la revisione.';

  @override
  String get taskExportStoryboardMoveDown => 'Sposta giù';

  @override
  String get taskExportStoryboardMoveUp => 'Sposta su';

  @override
  String get taskExportStoryboardOrderRefused =>
      'Un risultato non può precedere il comando a cui risponde.';

  @override
  String get taskExportStoryboardRenderFailed =>
      'Impossibile disegnare l\'illustrazione; questo passaggio resta testo.';

  @override
  String get taskExportStoryboardSourceExcluded =>
      'Schermata protetta: non illustrata';

  @override
  String get taskExportStoryboardSourceScene =>
      'Illustrazione ricreata (non uno screenshot)';

  @override
  String get taskExportStoryboardSourceText => 'Diapositiva di testo';

  @override
  String get taskExportSurfaceAny => 'qualsiasi schermata';

  @override
  String get taskExportSurfaceBookingSheet => 'la scheda di prenotazione';

  @override
  String get taskExportSurfaceReservationDetail =>
      'il dettaglio della prenotazione';

  @override
  String get taskExportSurfaceReserve => 'la schermata Prenota';

  @override
  String get taskExportSurfaceUnknown =>
      'una schermata che questa versione non sa descrivere';

  @override
  String get taskExportUnrecorded =>
      'Un passaggio che questa versione non sa descrivere.';

  @override
  String get taskExportValueAfternoon => 'pomeriggio';

  @override
  String get taskExportValueAllBooked => 'tutto prenotato';

  @override
  String get taskExportValueClosed => 'lo spazio era chiuso';

  @override
  String get taskExportValueConflict => 'il posto era già occupato';

  @override
  String get taskExportValueCustom => 'personalizzato';

  @override
  String get taskExportValueDesk => 'una scrivania';

  @override
  String get taskExportValueFullDay => 'giornata intera';

  @override
  String get taskExportValueHours => 'a ore';

  @override
  String get taskExportValueLater => 'più avanti';

  @override
  String get taskExportValueLaterThisWeek => 'più avanti questa settimana';

  @override
  String get taskExportValueList => 'elenco';

  @override
  String get taskExportValueMorning => 'mattina';

  @override
  String get taskExportValueNo => 'no';

  @override
  String get taskExportValueOffline => 'nessuna connessione';

  @override
  String get taskExportValueOnce => 'una volta';

  @override
  String get taskExportValueOtherMember => 'un altro membro';

  @override
  String get taskExportValueOtherPlace => 'un altro tipo di posto';

  @override
  String get taskExportValueOtherReason => 'un altro motivo';

  @override
  String get taskExportValuePartiallyBooked => 'prenotato in parte';

  @override
  String get taskExportValuePast => 'un giorno passato';

  @override
  String get taskExportValuePermission => 'un\'autorizzazione mancante';

  @override
  String get taskExportValuePlan => 'planimetria';

  @override
  String get taskExportValuePolicy => 'una regola di prenotazione';

  @override
  String get taskExportValueQuota => 'una quota';

  @override
  String get taskExportValueRoom => 'una sala';

  @override
  String get taskExportValueSelf => 'me stesso';

  @override
  String get taskExportValueSeries => 'come serie';

  @override
  String get taskExportValueToday => 'oggi';

  @override
  String get taskExportValueTomorrow => 'domani';

  @override
  String get taskExportValueWithheld => 'non registrato';

  @override
  String get taskExportValueYes => 'sì';

  @override
  String taskExportVersion(int schema, int contract) {
    return 'Formato di registrazione $schema, contratto delle azioni $contract';
  }

  @override
  String get taskExportVideoBusy =>
      'Un altro video è ancora in fase di creazione.';

  @override
  String get taskExportVideoCancel => 'Annulla il video';

  @override
  String get taskExportVideoCancelled =>
      'Creazione del video annullata. Non è stato salvato nulla.';

  @override
  String get taskExportVideoEmpty =>
      'Tutti i passaggi sono stati esclusi: non c\'è nulla da mostrare in un video.';

  @override
  String get taskExportVideoFailed =>
      'Impossibile creare il video. Non è stato salvato nulla.';

  @override
  String get taskExportVideoGenerate => 'Crea il video';

  @override
  String taskExportVideoGenerating(int percent) {
    return 'Creazione del video: $percent %';
  }

  @override
  String get taskExportVideoIntro =>
      'Un tutorial ricreato da un\'attività registrata. Mostra i passaggi, non la prova che l\'attività sia riuscita.';

  @override
  String get taskExportVideoLandscape => 'Orizzontale';

  @override
  String taskExportVideoLeftOut(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passaggi sono stati esclusi durante la revisione.',
      one: 'Un passaggio è stato escluso durante la revisione.',
    );
    return '$_temp0';
  }

  @override
  String get taskExportVideoPortrait => 'Verticale';

  @override
  String taskExportVideoSaved(String file) {
    return 'Video salvato con sottotitoli e trascrizione: $file';
  }

  @override
  String taskExportVideoStepHeading(int number, String title) {
    return 'Passaggio $number: $title';
  }

  @override
  String get taskExportVideoSummary => 'Riepilogo';

  @override
  String get taskExportVideoTooLong =>
      'Il video supererebbe la durata consentita. Accorcia le durate o escludi dei passaggi.';

  @override
  String get taskExportVideoUnsupported =>
      'Questo dispositivo non può creare un video. Esporta il file di registrazione e aprilo su un dispositivo supportato: macOS, iOS, Android o un browser recente in grado di codificare video H.264.';

  @override
  String get taskExportWordButton => 'Esporta come documento Word';

  @override
  String get taskGuideCreate => 'Crea una bozza di guida';

  @override
  String get taskGuideEditText => 'Scrivi il testo';

  @override
  String get taskGuideIntro =>
      'Ogni passaggio come lo seguirà un lettore. Un passaggio che prenota attende la risposta reale; nulla viene fatto al posto del lettore.';

  @override
  String get taskGuideManual => 'Esegua questo passaggio da sé';

  @override
  String taskGuideManualProtected(String category) {
    return 'Esegua questo passaggio da sé, su una schermata protetta: $category';
  }

  @override
  String get taskGuideNoText => 'Un\'istruzione ancora da scrivere';

  @override
  String get taskGuideOptional => 'Il lettore può saltarlo';

  @override
  String get taskGuideRecovery =>
      'Se viene rifiutato: scelga un altro posto, giorno o periodo, poi confermi di nuovo.';

  @override
  String get taskGuideSave => 'Salva la guida';

  @override
  String get taskGuideTitle => 'Bozza di guida';

  @override
  String taskGuideWaitsFor(String outcomes) {
    return 'Attende: $outcomes';
  }

  @override
  String get taskOutputBusy => 'Questo risultato è già in creazione.';

  @override
  String get taskOutputCaptions => 'Sottotitoli';

  @override
  String get taskOutputDocument => 'Documento Word';

  @override
  String get taskOutputFailed => 'Non è stato possibile creare il risultato.';

  @override
  String get taskOutputMake => 'Crea';

  @override
  String get taskOutputMissingMedia =>
      'Questa attività non ha immagini o video da usare.';

  @override
  String get taskOutputStale =>
      'Le illustrazioni sono state riviste per una versione precedente.';

  @override
  String get taskOutputStoryboard => 'Storyboard';

  @override
  String get taskOutputTooLong =>
      'Questa attività è troppo lunga per questo formato.';

  @override
  String get taskOutputUnsupportedPlatform =>
      'Non disponibile su questo dispositivo.';

  @override
  String get taskOutputVideo => 'Video';

  @override
  String get taskRecorderActionBack => 'È tornato indietro';

  @override
  String get taskRecorderActionCancelReview =>
      'Ha chiuso la prenotazione senza prenotare';

  @override
  String get taskRecorderActionChangeField =>
      'Ha modificato un dettaglio della prenotazione';

  @override
  String get taskRecorderActionConfirmBooking =>
      'Ha confermato la prenotazione';

  @override
  String get taskRecorderActionOpenReserve => 'Ha aperto Prenota';

  @override
  String get taskRecorderActionSelectDate => 'Ha scelto il giorno';

  @override
  String get taskRecorderActionSelectPeriod => 'Ha scelto il periodo';

  @override
  String get taskRecorderActionSelectResource => 'Ha scelto un posto';

  @override
  String get taskRecorderActionSwitchView => 'Ha cambiato vista';

  @override
  String get taskRecorderActionViewDetails => 'Ha aperto la prenotazione';

  @override
  String get taskRecorderAddNote => 'Aggiungi una nota';

  @override
  String get taskRecorderCompletenessComplete => 'Completa';

  @override
  String get taskRecorderCompletenessInterrupted => 'Interrotta';

  @override
  String get taskRecorderCompletenessPartial => 'Parziale';

  @override
  String get taskRecorderDelete => 'Elimina da questo dispositivo';

  @override
  String get taskRecorderDeleteConfirm =>
      'Eliminare questa registrazione da questo dispositivo? I file esportati non sono toccati e nulla cambia nello spazio.';

  @override
  String get taskRecorderDiscard => 'Scarta';

  @override
  String get taskRecorderDisclosureBody =>
      'Il registratore annota i passaggi che compie sulle schermate di questo spazio — quale schermata, quale azione, cosa ha risposto l\'app — solo su questo dispositivo. Non conserva mai ciò che digita, né nomi, importi, messaggi, codici o password. Accesso, pagamento, messaggi e altre schermate protette lasciano solo un segno. Nulla viene inviato: decide lei cosa esportare.';

  @override
  String get taskRecorderDisclosureTitle => 'Prima di registrare';

  @override
  String taskRecorderEditedNote(int count) {
    return 'Copia modificata: $count passaggi esclusi. La registrazione su questo dispositivo resta invariata.';
  }

  @override
  String get taskRecorderEndInterrupted =>
      'Interrotta: l\'app si è fermata durante la registrazione';

  @override
  String get taskRecorderEndLimitReached =>
      'Terminata: è stato raggiunto un limite';

  @override
  String get taskRecorderEndScopeChanged =>
      'Terminata: è cambiato l\'account o lo spazio';

  @override
  String get taskRecorderEndStopped => 'Fermata da lei';

  @override
  String get taskRecorderEndStorageFailed =>
      'Terminata: non è stato possibile salvarla su questo dispositivo';

  @override
  String get taskRecorderExport => 'Esporta un file';

  @override
  String get taskRecorderExportPackage => 'Esporta un pacchetto dell\'attività';

  @override
  String get taskRecorderExportPreview => 'Cosa conterrà il file';

  @override
  String get taskRecorderFieldAccessories => 'accessori';

  @override
  String get taskRecorderFieldCheckIn => 'check-in';

  @override
  String get taskRecorderFieldForWhom => 'per chi';

  @override
  String get taskRecorderFieldRepeat => 'ripetizione';

  @override
  String get taskRecorderFieldTime => 'orario';

  @override
  String taskRecorderIndicator(int count) {
    return 'Registrazione di un\'attività: $count passaggi';
  }

  @override
  String get taskRecorderLeaveOut => 'Escludi dall\'esportazione';

  @override
  String taskRecorderLimits(int steps, int minutes, int days) {
    return 'Fino a $steps passaggi o $minutes minuti per registrazione. Le registrazioni vengono eliminate da questo dispositivo dopo $days giorni; un file esportato è suo e resta dove lo ha salvato.';
  }

  @override
  String get taskRecorderMyRecordings =>
      'Le mie registrazioni su questo dispositivo';

  @override
  String get taskRecorderNoOutcome => 'Nessuna risposta registrata';

  @override
  String get taskRecorderNoRecordings =>
      'Nessuna registrazione su questo dispositivo.';

  @override
  String get taskRecorderNoteHint => 'Le sue parole, conservate come le scrive';

  @override
  String get taskRecorderOpenRecorder => 'Apri il registratore di attività';

  @override
  String get taskRecorderOutcomeConfirmed => 'Prenotato';

  @override
  String get taskRecorderOutcomeRefused => 'Rifiutato';

  @override
  String get taskRecorderOutcomeRequested => 'Inviato per conferma';

  @override
  String get taskRecorderOutcomeSeries => 'Serie prenotata';

  @override
  String get taskRecorderOutcomeUnknown => 'Nessuna risposta ricevuta';

  @override
  String get taskRecorderPause => 'Pausa';

  @override
  String get taskRecorderPaused => 'In pausa';

  @override
  String get taskRecorderProtectedAuthentication => 'accesso';

  @override
  String get taskRecorderProtectedIdentity => 'identità';

  @override
  String get taskRecorderProtectedMessenger => 'messaggi';

  @override
  String get taskRecorderProtectedOperator => 'operatore dell\'installazione';

  @override
  String get taskRecorderProtectedPayment => 'pagamento';

  @override
  String get taskRecorderProtectedProvider => 'schermata di un fornitore';

  @override
  String get taskRecorderProtectedSecrets => 'chiavi e segreti';

  @override
  String get taskRecorderPutBack => 'Reinserisci';

  @override
  String get taskRecorderRecordThisTask => 'Registra questa attività';

  @override
  String get taskRecorderRecording => 'Registrazione in corso';

  @override
  String get taskRecorderResume => 'Riprendi';

  @override
  String get taskRecorderSaveFailed => 'Non è stato possibile salvare il file.';

  @override
  String get taskRecorderSaveNoPath =>
      'Il file è stato consegnato al browser o al dispositivo, che non ha detto dove è finito.';

  @override
  String taskRecorderSaved(String path) {
    return 'Salvato: $path';
  }

  @override
  String taskRecorderSavedPrivately(String path) {
    return 'Conservato solo nell\'app: $path';
  }

  @override
  String get taskRecorderSegmentGap => 'In pausa qui';

  @override
  String get taskRecorderSignedOut => 'Accedi per registrare un\'attività.';

  @override
  String get taskRecorderStart => 'Avvia registrazione';

  @override
  String get taskRecorderStartFailed =>
      'La registrazione non è potuta partire su questo dispositivo.';

  @override
  String taskRecorderStepCount(int count) {
    return '$count passaggi';
  }

  @override
  String get taskRecorderStepExcluded =>
      'Una schermata protetta — non registrata';

  @override
  String get taskRecorderStepNote => 'La sua nota';

  @override
  String get taskRecorderStepUnrecorded =>
      'Un passaggio che il registratore non sa descrivere';

  @override
  String get taskRecorderStop => 'Ferma';

  @override
  String get taskRecorderTitle => 'Registratore di attività';

  @override
  String get taskRecorderUnavailable =>
      'La registrazione non è attivata in questo spazio.';

  @override
  String get taskRecorderUnreadable =>
      'Questa registrazione non è leggibile. Può eliminarla.';

  @override
  String get taskRecorderUntitled => 'Attività senza titolo';

  @override
  String get taskRecorderValueAfternoon => 'pomeriggio';

  @override
  String get taskRecorderValueAllBooked => 'tutte le date prenotate';

  @override
  String get taskRecorderValueCheckIn => 'con check-in';

  @override
  String get taskRecorderValueClosed => 'chiuso';

  @override
  String get taskRecorderValueConflict => 'già occupato';

  @override
  String get taskRecorderValueCustom => 'orari personalizzati';

  @override
  String get taskRecorderValueDesk => 'una scrivania';

  @override
  String get taskRecorderValueFullDay => 'giornata intera';

  @override
  String get taskRecorderValueHours => 'a ore';

  @override
  String get taskRecorderValueLater => 'un giorno successivo';

  @override
  String get taskRecorderValueLaterThisWeek => 'più avanti questa settimana';

  @override
  String get taskRecorderValueList => 'elenco';

  @override
  String get taskRecorderValueMorning => 'mattina';

  @override
  String get taskRecorderValueNoCheckIn => 'senza check-in';

  @override
  String get taskRecorderValueOffline => 'offline';

  @override
  String get taskRecorderValueOnce => 'una volta';

  @override
  String get taskRecorderValueOther => 'altro';

  @override
  String get taskRecorderValueOtherMember => 'per un altro membro';

  @override
  String get taskRecorderValuePartiallyBooked => 'alcune date rifiutate';

  @override
  String get taskRecorderValuePast => 'un giorno passato';

  @override
  String get taskRecorderValuePermission => 'un\'autorizzazione';

  @override
  String get taskRecorderValuePlan => 'pianta';

  @override
  String get taskRecorderValuePolicy => 'una regola di prenotazione';

  @override
  String get taskRecorderValueQuota => 'una quota';

  @override
  String get taskRecorderValueRoom => 'una sala';

  @override
  String get taskRecorderValueSelf => 'per me';

  @override
  String get taskRecorderValueSeries => 'ripetuta';

  @override
  String get taskRecorderValueToday => 'oggi';

  @override
  String get taskRecorderValueTomorrow => 'domani';

  @override
  String get taskRecorderValueWithheld => 'non registrato';

  @override
  String taskWorkbenchAccepted(int megabytes) {
    return 'Accettati: .json e .deskilo-task.zip, fino a $megabytes MB.';
  }

  @override
  String get taskWorkbenchChoose => 'Scegli un file di attività';

  @override
  String taskWorkbenchClaim(String key, String value) {
    return 'Il file indica $key: $value';
  }

  @override
  String get taskWorkbenchEdited =>
      'Una copia modificata di una registrazione.';

  @override
  String get taskWorkbenchFileType => 'File di attività';

  @override
  String get taskWorkbenchIntro =>
      'Apra un file di attività salvato. Viene letto solo su questo dispositivo; nulla viene inviato e non serve accedere.';

  @override
  String get taskWorkbenchOpen => 'Apri un file di attività';

  @override
  String get taskWorkbenchRefusedDamaged =>
      'Questo file è danneggiato o è stato modificato dopo la creazione.';

  @override
  String get taskWorkbenchRefusedInvalid =>
      'Questo file non contiene un\'attività valida.';

  @override
  String get taskWorkbenchRefusedNewer =>
      'Questo file è stato creato da una versione più recente dell\'app.';

  @override
  String get taskWorkbenchRefusedTooLarge =>
      'Questo file è più grande di quanto il laboratorio legga.';

  @override
  String get taskWorkbenchRefusedUnsafe =>
      'Questo file è costruito in modo non sicuro da aprire.';

  @override
  String get taskWorkbenchRefusedUnsupported =>
      'Questo non è un file di attività.';

  @override
  String get taskWorkbenchReviewIllustrations => 'Rivedi le illustrazioni';

  @override
  String get taskWorkbenchTitle => 'Laboratorio delle attività';

  @override
  String get taskWorkbenchTranscriptOnly =>
      'Alcuni passaggi provengono da una versione più recente: mostrati solo come trascrizione.';

  @override
  String get taskWorkbenchUntrusted =>
      'Una bozza privata da un file: nulla al suo interno è considerato affidabile né inviato.';

  @override
  String get templateApplyConflict =>
      'Questa richiesta è già stata usata per altro. Non è stato applicato nulla.';

  @override
  String get templateChangedSinceReview =>
      'Questo modello è cambiato da quando l\'hai esaminato. Non è stato applicato nulla; riaprilo per esaminare la nuova versione.';

  @override
  String get templateClearFilters => 'Cancella la ricerca';

  @override
  String get templateDetailNone => 'Nessuna impostazione corrisponde.';

  @override
  String get templateDetailSearch => 'Trova un’impostazione in questo modello';

  @override
  String get templateDetails => 'Cosa contiene';

  @override
  String templateExportResults(String count) {
    return 'Esporta questi risultati ($count)';
  }

  @override
  String templateExportTooMany(String max) {
    return 'Al massimo $max modelli per cartella. Restringi prima la ricerca.';
  }

  @override
  String get templateNoMatch =>
      'Nessun modello corrisponde. Cambia le parole, un’etichetta o un requisito.';

  @override
  String templatePrefer(String capability) {
    return 'Preferisci: $capability';
  }

  @override
  String templatePreferredChip(String capability) {
    return 'Preferito: $capability';
  }

  @override
  String get templatePricesOtherCurrency =>
      'I prezzi del modello sono in un\'altra valuta, quindi i prezzi qui non sono stati modificati.';

  @override
  String get templateProfileFull => 'Profilo di configurazione completo';

  @override
  String templateProfileSelected(String chosen, String total) {
    return 'Gruppi scelti: $chosen su $total';
  }

  @override
  String get templatePublishLocalNeeds =>
      'Uno spazio che lo applica li configurerà da sé:';

  @override
  String templateRegionSuggested(String values) {
    return 'Questo modello è stato creato per $values. La tua scelta resta, a meno che tu non usi i suoi valori.';
  }

  @override
  String get templateRegionUse => 'Usa la regione del modello';

  @override
  String templateRequire(String capability) {
    return 'Richiedi: $capability';
  }

  @override
  String get templateRequirementRemove => 'Rimuovi il requisito';

  @override
  String get templateRequirementsReset => 'Azzera';

  @override
  String templateResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modelli mostrati',
      one: '1 modello mostrato',
      zero: 'Nessun modello mostrato',
    );
    return '$_temp0';
  }

  @override
  String templateValidatorsToChoose(String types) {
    return 'Scegli chi convalida $types nelle impostazioni di convalida; quelle regole sono rimaste com\'erano.';
  }

  @override
  String get templateWhy => 'Perché corrisponde';

  @override
  String get templateWhyHide => 'Nascondi il perché';

  @override
  String get templateWidenConfirm => 'Rendi leggibile';

  @override
  String templateWidenCount(String count) {
    return '$count impostazioni diventano leggibili, esattamente come il modello le contiene ora.';
  }

  @override
  String templateWidenExcluded(String count) {
    return '$count tipi di valori non escono mai con esso (coordinate bancarie, sedi, indirizzi…).';
  }

  @override
  String templateWidenTitle(String audience) {
    return 'Rendere questo modello leggibile da: $audience?';
  }

  @override
  String get templatesLoadFailed => 'Non è stato possibile caricare i modelli.';

  @override
  String get themeDark => 'Scuro';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeSystem => 'Predefinito di sistema';

  @override
  String get themeTitle => 'Tema';

  @override
  String get usageAsk => 'Fattura il tempo in cui c’ero';

  @override
  String usageAskExplain(String booked, String present, String saved) {
    return 'Hai prenotato $booked e sei stato $present. Chiedi che le $saved non usate non siano fatturate. Decide qualcun altro, mai tu.';
  }

  @override
  String get usageAskSubmit => 'Chiedi';

  @override
  String get usageAskSubmitted => 'Richiesto. Decide qualcun altro.';

  @override
  String get usageBilled => 'Fatturato';

  @override
  String get usageBooked => 'Prenotato';

  @override
  String get usageCorrected => 'Corretto';

  @override
  String get usageDelete => 'Rimuovi questo rilevamento';

  @override
  String get usageDeleteSubmitted => 'Rimozione richiesta.';

  @override
  String get usageEmpty => 'Nessun utilizzo questo mese.';

  @override
  String get usageLeftEarly => 'Uscito prima';

  @override
  String get usageMember => 'Membro';

  @override
  String get usageMemberAll => 'Tutti';

  @override
  String get usageNoShow =>
      'Non è venuto nessuno: la prenotazione è fatturata per intero';

  @override
  String get usagePresent => 'Presente';

  @override
  String get usageReasonLabel => 'Perché (facoltativo)';

  @override
  String get usageReportButton => 'Report dei consumi del mese';

  @override
  String get usageReportExtra => 'Mezze giornate extra';

  @override
  String get usageReportIncluded => 'Mezze giornate incluse';

  @override
  String get usageReportOverage => 'Eccedenza riportata sulla prossima fattura';

  @override
  String get usageReportPaid => 'Pagato in anticipo (partecipazione)';

  @override
  String get usageReportRecordsHeading => 'Cosa è stato consumato';

  @override
  String get usageReportRemaining => 'Mezze giornate rimanenti';

  @override
  String get usageReportSupplements =>
      'Supplementi (accessori, scrivanie, uffici)';

  @override
  String get usageReportUsed => 'Mezze giornate consumate';

  @override
  String get usageTitle => 'Utilizzo';

  @override
  String usageWas(String before) {
    return 'era $before';
  }

  @override
  String get validationAdminsMay => 'Gli admin possono validare';

  @override
  String get validationAllAdmins => 'Tutti gli admin';

  @override
  String get validationAutoValidateAdmin =>
      'Gli admin eliminano senza validazione';

  @override
  String get validationAutoValidateDesc =>
      'La loro richiesta di eliminazione si risolve da sola e resta segnata come auto-validata.';

  @override
  String get validationAutoValidateOwner =>
      'I proprietari eliminano senza validazione';

  @override
  String get validationCustomized => 'Personalizzata';

  @override
  String get validationDefaultPolicy => 'Regola predefinita';

  @override
  String get validationInherited => 'Eredita la predefinita';

  @override
  String get validationMinAmount => 'Solo oltre questo importo';

  @override
  String get validationMinAmountDesc =>
      'Al di sotto, l\'atto si applica subito. Vuoto: qualsiasi importo.';

  @override
  String get validationNoSelfDesc =>
      'Chi crea un evento non lo convalida mai. Attende qualcun altro, oppure scade senza decisione.';

  @override
  String get validationNoSelfShort => 'Mai il proprio';

  @override
  String get validationNoSelfTitle => 'Nessuno convalida il proprio';

  @override
  String get validationNotEnough => 'Validatori idonei insufficienti.';

  @override
  String get validationOwnerOnly => 'Solo il proprietario';

  @override
  String get validationOwnerRequired => 'Il proprietario deve sempre validare';

  @override
  String get validationOwnerSelf => 'La proprietà può convalidare il proprio';

  @override
  String get validationOwnerSelfDesc =>
      'L’unica eccezione, ed è della sola proprietà: un admin non convalida mai il proprio atto.';

  @override
  String get validationOwnerSelfShort =>
      'La proprietà può convalidare il proprio';

  @override
  String get validationPickPersons => 'Scegli le persone';

  @override
  String get validationRequiredCount => 'Validazioni richieste';

  @override
  String get validationSaved => 'Regola di validazione salvata.';

  @override
  String get validationScopeAdmins => 'Gli admin';

  @override
  String get validationScopeHint =>
      'Il proprietario può sempre. Admin: tutti gli admin, o quelli elencati. Designate: esattamente queste persone, qualunque sia il ruolo. Tutti i membri: chiunque sia attivo.';

  @override
  String get validationScopeLabel => 'Chi convalida';

  @override
  String get validationScopeListed => 'Persone designate';

  @override
  String get validationScopeMembers => 'Tutti i membri';

  @override
  String get validationSentForApproval =>
      'Inviato in convalida — si applica una volta approvato.';

  @override
  String get validationSequential => 'Una dopo l’altra';

  @override
  String get validationSequentialDesc =>
      'La convalida successiva è chiesta quando la precedente è passata, e la cronologia numera ogni passo.';

  @override
  String get validationSpecificAdmins => 'Admin specifici';

  @override
  String get validationStepApplies => 'diventa effettivo';

  @override
  String get validationStepOwnerToo => 'e la proprietaria, sempre';

  @override
  String validationStepQuorum(int count, String who) {
    return '$who — $count qualsiasi';
  }

  @override
  String get validationStepRaised => 'Qualcuno chiede';

  @override
  String validationStepSequential(int count, String who) {
    return '$who — $count in sequenza';
  }

  @override
  String get validationThresholdNote =>
      'Gli importi minori si applicano subito.';

  @override
  String get validationTitle => 'Regole di validazione';

  @override
  String validationTrailAwaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Mancano $count convalide.',
      one: 'Manca 1 convalida.',
    );
    return '$_temp0';
  }

  @override
  String get validationTrailNone => 'Nessuna decisione finora.';

  @override
  String validationTrailStep(int order) {
    return 'Passo $order';
  }

  @override
  String get validationTrailTitle => 'Cronologia delle convalide';

  @override
  String get validationWorkflowBookings => 'Prenotazioni';

  @override
  String get validationWorkflowBookingsStake =>
      'Finché non è accettato, il posto resta com’era.';

  @override
  String get validationWorkflowMoneyStake =>
      'Finché non è accettato, l\'importo non conta su nessun estratto conto.';

  @override
  String get validationWorkflowPeople => 'Persone e ruoli';

  @override
  String get validationWorkflowPeopleStake =>
      'Finché non è accettato, la persona mantiene gli accessi che ha.';

  @override
  String get vatAccountField => 'Conto IVA';

  @override
  String get vatAccountHint =>
      'Conto su cui l\'esportazione contabile registra l\'IVA incassata. Vuoto = 445710.';

  @override
  String get vatAddRate => 'Aggiungi un\'aliquota';

  @override
  String get vatChangeByLaw => 'Modifica per legge';

  @override
  String get vatChangeByLawExplainer =>
      'Un nuovo valore da una data: il vecchio resta su ogni prestazione precedente, il nuovo si applica da quel giorno. Nulla viene riassegnato.';

  @override
  String get vatChangeInvalid =>
      'Servono una percentuale tra 0 e 99,99 e una data successiva all\'inizio dell\'aliquota.';

  @override
  String get vatChangeNeedsSave =>
      'Salva prima l\'aliquota; poi modificala per legge.';

  @override
  String get vatDeclBox => 'Rigo';

  @override
  String get vatDeclBoxes => 'Righe del modulo ufficiale';

  @override
  String get vatDeclDisclaimer =>
      'Generata dalle fatture emesse del periodo. Verificare con la contabilità prima dell’invio — un aiuto alla dichiarazione, non consulenza fiscale.';

  @override
  String get vatDeclDraft => 'Bozza';

  @override
  String get vatDeclEmpty =>
      'Nessuna dichiarazione — scegli un periodo e genera la prima.';

  @override
  String get vatDeclGenerate => 'Genera';

  @override
  String get vatDeclInvoices => 'Fatture';

  @override
  String get vatDeclMarkFiled => 'Segna come inviata';

  @override
  String get vatDeclMarkFiledConfirm =>
      'Conferma di aver inviato questa dichiarazione tu stesso (portale dell’agenzia o il tuo commercialista). Diventa immutabile.';

  @override
  String get vatDeclNet => 'Imponibile';

  @override
  String get vatDeclPdf => 'PDF';

  @override
  String get vatDeclPeriod => 'Periodo';

  @override
  String get vatDeclRate => 'Aliquota';

  @override
  String get vatDeclRegimeGate =>
      'Le dichiarazioni esistono solo sotto il regime soggetto a IVA — configuralo nelle impostazioni IVA.';

  @override
  String get vatDeclRejected => 'La piattaforma ha rifiutato la dichiarazione.';

  @override
  String get vatDeclSeller => 'Venditore';

  @override
  String get vatDeclSent => 'Dichiarazione trasmessa.';

  @override
  String get vatDeclStatus => 'Stato';

  @override
  String get vatDeclSubmitted => 'Inviata';

  @override
  String get vatDeclTitle => 'Dichiarazione IVA';

  @override
  String get vatDeclTotals => 'Totali';

  @override
  String get vatDeclTransmit => 'Trasmetti';

  @override
  String get vatDeclVat => 'IVA';

  @override
  String get vatDeclVatId => 'Partita IVA';

  @override
  String get vatDeclXml => 'Esporta XML';

  @override
  String get vatDeclarationBasisInvoice =>
      'Base: fatture (IVA sui documenti emessi nel periodo).';

  @override
  String get vatDeclarationBasisPayment =>
      'Base: incassi (IVA sui pagamenti ricevuti nel periodo).';

  @override
  String get vatEffectiveDate => 'Data di effetto (AAAA-MM-GG)';

  @override
  String get vatEmpty => 'Nessuna aliquota — le fatture non espongono IVA.';

  @override
  String get vatExemptionReasonField => 'Dicitura di esenzione';

  @override
  String get vatExigibilityInvoice => 'Alla fattura (criterio ordinario)';

  @override
  String get vatExigibilityPayment => 'All\'incasso (IVA per cassa)';

  @override
  String get vatExigibilitySubtitle =>
      'All\'incasso, un periodo dichiara ciò che i clienti hanno pagato al suo interno; alla fattura, ciò che avete emesso. La scelta è stampata su ogni fattura.';

  @override
  String get vatExigibilityTitle => 'Esigibilità dell’IVA';

  @override
  String get vatGroupDeposit => 'Cauzione (fuori IVA)';

  @override
  String get vatGroupExamples => 'Cosa rientra in ogni gruppo';

  @override
  String get vatGroupExcise => 'Con accise';

  @override
  String get vatGroupExempt => 'Esente';

  @override
  String get vatGroupIntermediate => 'Intermedia';

  @override
  String get vatGroupLabel => 'Gruppo';

  @override
  String get vatGroupNotSubject => 'Non soggetta';

  @override
  String get vatGroupReduced => 'Ridotta';

  @override
  String get vatGroupStandard => 'Ordinaria';

  @override
  String get vatGroupSuperReduced => 'Super-ridotta';

  @override
  String get vatGroupZero => 'Aliquota zero';

  @override
  String get vatIntro =>
      'In DesKilo i prezzi sono IVA inclusa. Aggiungere aliquote non cambia nulla di ciò che i membri pagano: l\'imposta viene estratta dal prezzo già applicato e mostrata in fattura.';

  @override
  String get vatKeptRate =>
      'Un\'aliquota ancora usata da una fattura o da un servizio viene conservata, disattivata.';

  @override
  String get vatNeedsDefault =>
      'Segna esattamente un\'aliquota come predefinita.';

  @override
  String get vatNewPercent => 'Nuova aliquota %';

  @override
  String get vatPdfNet => 'Imponibile';

  @override
  String get vatPdfVat => 'IVA';

  @override
  String get vatRateDefaultTooltip =>
      'Aliquota predefinita — usata dagli abbonamenti e da tutto ciò che non ne ha una propria';

  @override
  String get vatRateIncomplete =>
      'Ogni aliquota richiede un nome e una percentuale tra 0 e 99,99.';

  @override
  String get vatRateLabelField => 'Nome';

  @override
  String get vatRatePercentField => 'Aliquota %';

  @override
  String get vatRateRemoveTooltip => 'Rimuovi';

  @override
  String get vatRatesTile => 'Aliquote IVA';

  @override
  String get vatRegimeHint =>
      'Questo spazio non è dichiarato soggetto a IVA, quindi le fatture non la espongono. Si cambia in Identità legale.';

  @override
  String get vatReportByRate => 'Totali per aliquota';

  @override
  String get vatReportCsv => 'Report IVA (CSV)';

  @override
  String get vatReportPdf => 'Report IVA (PDF)';

  @override
  String get vatReportPositions => 'Posizioni';

  @override
  String get vatReportTotals => 'Totali del periodo';

  @override
  String get vatSaved => 'Aliquote IVA salvate.';

  @override
  String get vatSeed => 'Usa le aliquote consuete';

  @override
  String get vatServiceRate => 'Aliquota IVA';

  @override
  String get vatServiceRateDefault => 'Predefinita dello spazio';

  @override
  String vatShareAmount(String amount) {
    return 'IVA incl. $amount';
  }

  @override
  String get vatSince => 'dal';

  @override
  String get vatTitle => 'IVA';

  @override
  String get vatTreatmentAuto => 'Automatico';

  @override
  String get vatTreatmentDomestic => 'IVA nazionale';

  @override
  String get vatTreatmentExempt => 'Acquirente esente';

  @override
  String get vatTreatmentExport => 'Fuori UE';

  @override
  String get vatTreatmentReasonField =>
      'Motivo di esenzione (stampato sulla fattura)';

  @override
  String get vatTreatmentReverseCharge => 'Inversione contabile';

  @override
  String get vatUntil => 'fino al';

  @override
  String get visibilityAbout => 'Professione e biografia';

  @override
  String get visibilityAboutEmpty =>
      'Aggiungi la tua professione e qualche parola';

  @override
  String get visibilityAboutMe => 'Su di me';

  @override
  String get visibilityAboutSaveFailed =>
      'Impossibile salvare professione e biografia. Riprova.';

  @override
  String get visibilityBio => 'Qualche parola su di te';

  @override
  String visibilityChosenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Membri di $count spazi scelti',
      one: 'Membri di 1 spazio scelto',
    );
    return '$_temp0';
  }

  @override
  String get visibilityChosenSpaces => 'Membri di spazi scelti';

  @override
  String get visibilityContact => 'WhatsApp ed e-mail';

  @override
  String get visibilityIdentity => 'Nome e foto';

  @override
  String get visibilityIntro =>
      'Ogni parte del tuo account sceglie il proprio pubblico. Niente è pubblico se non lo scegli.';

  @override
  String get visibilityMySpaces => 'Membri dei miei spazi';

  @override
  String get visibilityNobody => 'Nessuno';

  @override
  String get visibilityPresence => 'Oggi nello spazio';

  @override
  String get visibilityPreviewCanWrite =>
      'Può iniziare una conversazione con te';

  @override
  String get visibilityPreviewCannotWrite =>
      'Non può iniziare una conversazione con te';

  @override
  String get visibilityPreviewFailed => 'Impossibile caricare l\'anteprima.';

  @override
  String get visibilityPreviewMySpaces => 'Un membro dei miei spazi';

  @override
  String get visibilityPreviewNobody => 'Solo io';

  @override
  String get visibilityPreviewNothing => 'Non vedono nulla di te.';

  @override
  String get visibilityPreviewSignedIn =>
      'Chiunque abbia effettuato l\'accesso';

  @override
  String get visibilityPreviewTitle => 'Come mi vedono gli altri';

  @override
  String get visibilityProfession => 'Professione';

  @override
  String get visibilityReachability =>
      'Chi può iniziare una conversazione con me';

  @override
  String get visibilitySaveFailed =>
      'Impossibile salvare chi lo vede. Riprova.';

  @override
  String get visibilitySignedIn => 'Chiunque abbia effettuato l\'accesso';

  @override
  String get visibilityTitle => 'Chi mi vede';

  @override
  String whatTheyCanDoTitle(String name) {
    return 'Cosa può fare qui $name';
  }

  @override
  String get whatYouCanDoFromAdministrator => 'Dal ruolo Amministratore';

  @override
  String get whatYouCanDoFromCoOwner => 'Come comproprietario';

  @override
  String get whatYouCanDoFromEveryMember => 'Come tutti i membri';

  @override
  String get whatYouCanDoFromOwner => 'Come proprietario: tutto';

  @override
  String whatYouCanDoFromRole(String role) {
    return 'Dal ruolo $role';
  }

  @override
  String get whatYouCanDoIntro =>
      'Qui tutti sono membri: prenotare, fare il check-in, i messaggi e il proprio account. I ruoli aggiungono il resto.';

  @override
  String get whatYouCanDoNothingMore => 'Niente più di un membro.';

  @override
  String get whatYouCanDoTitle => 'Cosa puoi fare qui';

  @override
  String get whatsappFieldLabel => 'Numero WhatsApp';

  @override
  String get whatsappHelper =>
      'Facoltativo. Visibile ai membri dei tuoi spazi per contattarti su WhatsApp. Lascia vuoto per smettere di condividerlo.';

  @override
  String get whatsappHint => '+39 333 123 4567';

  @override
  String get whatsappNotShared => 'Non condiviso';

  @override
  String get whatsappSaveFailed => 'Impossibile salvare il numero WhatsApp';

  @override
  String get whatsappSaved => 'Numero WhatsApp salvato';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get wizardBack => 'Indietro';

  @override
  String get wizardCardHint =>
      'Emettere, inviare, sollecitare, registrare e convalidare i pagamenti, abbinare e chiudere: un solo processo guidato.';

  @override
  String get wizardCloseHint =>
      'Un membro con più fatture aperte può pagarne UNA; a una fattura pagata in parte si può stralciare il resto; una nota di credito viene rimborsata. Ognuna passa dalla convalida.';

  @override
  String get wizardCloseNone =>
      'Niente da raggruppare, stralciare o rimborsare.';

  @override
  String get wizardFinish => 'Fine';

  @override
  String wizardIssueAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Emetti $count fatture',
      one: 'Emetti 1 fattura',
    );
    return '$_temp0';
  }

  @override
  String wizardIssueFailed(String name) {
    return 'Emissione impossibile per $name.';
  }

  @override
  String get wizardIssueHint =>
      'Deseleziona un membro per escluderlo da questo blocco. I membri già coperti compaiono come fatti.';

  @override
  String get wizardIssueNothing => 'Niente da emettere per questo periodo.';

  @override
  String wizardIssuedChip(String number) {
    return 'Emessa $number';
  }

  @override
  String get wizardMatchAction => 'Abbina';

  @override
  String wizardMatchCredit(String amount) {
    return 'Credito disponibile: $amount';
  }

  @override
  String get wizardMatchHint =>
      'Una fattura è pagata quando le viene abbinato un pagamento reale. Le righe con credito sul conto del membro sono pronte.';

  @override
  String get wizardMatchNoCredit => 'Nessun pagamento sul conto per ora';

  @override
  String get wizardMatchNone => 'Tutte le fatture sono pagate o chiuse.';

  @override
  String get wizardMatchPending => 'In attesa di convalida';

  @override
  String get wizardNext => 'Avanti';

  @override
  String get wizardPaymentAccept => 'Conferma';

  @override
  String get wizardPaymentReject => 'Rifiuta';

  @override
  String get wizardPaymentsHint =>
      'Ciò che i membri hanno dichiarato attende la tua conferma qui sotto. Un pagamento arrivato sul conto senza dichiarazione si registra qui; il membro lo conferma poi.';

  @override
  String get wizardPaymentsNone =>
      'Nessun pagamento dichiarato attende la tua decisione.';

  @override
  String wizardPeriodLabel(String period) {
    return 'Periodo: $period';
  }

  @override
  String get wizardRefund => 'Rimborsa';

  @override
  String wizardRemindAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Invia $count solleciti',
      one: 'Invia 1 sollecito',
    );
    return '$_temp0';
  }

  @override
  String get wizardRemindHint =>
      'In ritardo secondo le tue regole di sollecito. Un tocco registra ogni sollecito e avvisa i membri; la lettera si apre per riga.';

  @override
  String wizardRemindLevel(int level) {
    return 'sollecito $level';
  }

  @override
  String get wizardRemindNone =>
      'Nessun sollecito dovuto secondo le tue regole.';

  @override
  String get wizardRemindOne => 'Lettera di sollecito';

  @override
  String get wizardReviewIssued => 'Già emesse';

  @override
  String get wizardReviewOpen => 'Fatture aperte';

  @override
  String get wizardReviewOverdue => 'Solleciti dovuti';

  @override
  String get wizardReviewPending => 'Pagamenti da convalidare';

  @override
  String get wizardReviewToIssue => 'Da emettere';

  @override
  String get wizardRunEnd => 'Fine mese';

  @override
  String get wizardRunEndHint =>
      'Ciò che è costato il mese appena finito: utilizzo, consumi e costi aggiuntivi. Emettere, inviare, sollecitare; poi registrare, convalidare e abbinare i pagamenti, e chiudere.';

  @override
  String get wizardRunStart => 'Inizio mese';

  @override
  String get wizardRunStartHint =>
      'Gli abbonamenti pagati in anticipo: emetterli per il mese prossimo, inviarli, pianificare i solleciti; poi la parte pagamenti.';

  @override
  String get wizardSendDownload => 'Scarica il PDF';

  @override
  String get wizardSendHint =>
      'Consegna ogni fattura al suo membro: condividi il PDF o scaricalo per inviarlo a modo tuo.';

  @override
  String get wizardSendNone =>
      'Ancora nessuna fattura di questo giro da inviare.';

  @override
  String get wizardSendShare => 'Condividi il PDF';

  @override
  String wizardSettle(int count) {
    return 'Raggruppa $count';
  }

  @override
  String get wizardStepClose => 'Chiudi';

  @override
  String get wizardStepCompleted => 'Completato';

  @override
  String get wizardStepIssue => 'Emetti';

  @override
  String get wizardStepMatch => 'Abbina';

  @override
  String get wizardStepPayments => 'Pagamenti';

  @override
  String get wizardStepRemind => 'Sollecita';

  @override
  String get wizardStepReview => 'Revisione';

  @override
  String get wizardStepSend => 'Invia';

  @override
  String get wizardStepSkipped => 'Saltato — impostazioni suggerite';

  @override
  String get wizardStepSummary => 'Riepilogo';

  @override
  String get wizardStepUnavailable => 'Non ancora disponibile';

  @override
  String get wizardSubmitting => 'Invio in corso';

  @override
  String get wizardSummaryHint => 'Cosa ha fatto questo giro';

  @override
  String get wizardTallyDecided => 'Pagamenti confermati o rifiutati';

  @override
  String get wizardTallyIssued => 'Fatture emesse';

  @override
  String get wizardTallyMatched => 'Fatture abbinate';

  @override
  String get wizardTallyNothing => 'Non è stato cambiato nulla.';

  @override
  String get wizardTallyRefunds => 'Rimborsi';

  @override
  String get wizardTallyRegistered => 'Pagamenti registrati';

  @override
  String get wizardTallyReminded => 'Solleciti inviati';

  @override
  String get wizardTallySettled => 'Raggruppamenti';

  @override
  String get wizardTallyShared => 'PDF condivisi o scaricati';

  @override
  String get wizardTallyWriteoffs => 'Stralci richiesti';

  @override
  String get wizardTitle => 'Assistente di fatturazione';

  @override
  String get wizardTodoHeading => 'Ancora aperto: a chi tocca';

  @override
  String get wizardTodoNone => 'Non resta nulla di aperto.';

  @override
  String get wizardWhoValidators => 'Convalidatori';

  @override
  String get wizardWhoYou => 'Tu';

  @override
  String get wizardWriteoff => 'Stralcia';

  @override
  String get wordingChangedOnly => 'Solo modificati';

  @override
  String get wordingDefaultLabel => 'Parola del prodotto';

  @override
  String get wordingIntro =>
      'Rinomina un piccolo insieme approvato di parole del prodotto. Tutto il resto mantiene la formulazione del prodotto, e un termine non rinominato appare esattamente come prima.';

  @override
  String get wordingLocale => 'Lingua';

  @override
  String get wordingNone => 'Nessun termine corrisponde.';

  @override
  String get wordingReset => 'Reimposta';

  @override
  String get wordingResetHint =>
      'Reimposta rimuove la tua parola e ripristina quella del prodotto.';

  @override
  String get wordingRow => 'Lessico';

  @override
  String get wordingRowHint =>
      'Le parole che questo spazio usa per un posto, la legenda e le schede.';

  @override
  String get wordingSavedOne => 'Salvato';

  @override
  String get wordingSearch => 'Cerca una parola';

  @override
  String get wordingSurfaceBooking => 'Prenotazione';

  @override
  String get wordingSurfaceLegend => 'Legenda';

  @override
  String get wordingSurfaceNavigation => 'Navigazione';

  @override
  String get wordingSurfacePlan => 'Lo spazio';

  @override
  String get wordingTitle => 'Lessico';

  @override
  String get workbookExportBuilding => 'Creazione della cartella di lavoro…';

  @override
  String get workbookExportCancelled =>
      'Esportazione annullata. Non è stato salvato nulla.';

  @override
  String workbookExportReading(String done, String total) {
    return 'Lettura dei modelli: $done di $total';
  }

  @override
  String get workbookExportSaving => 'Scelga dove salvarla…';

  @override
  String get workbookExportTitle => 'Esportazione della cartella di lavoro';

  @override
  String get workbookNote =>
      'Un’istantanea di definizioni di modelli. Modificare questo file non cambia nulla in DesKilo, e non è il backup di alcuno spazio: non contiene membri, prenotazioni, fatture né credenziali.';

  @override
  String get workbookStateDefault =>
      'il modello non lo dice; vale il predefinito';

  @override
  String get workbookStateExcluded => 'deliberatamente mai pubblicato';

  @override
  String get workbookStateInherit =>
      'il modello non lo dice; la destinazione mantiene il proprio';

  @override
  String get workbookStateLocal => 'da impostare localmente';

  @override
  String get workbookStatePresent => 'il modello imposta questo valore';

  @override
  String get workbookStateUnknown => 'non leggibile; non si afferma nulla';

  @override
  String get workbookWide =>
      'Catalogs, RolePermissions, Validations e Fields mostrano un valore dove il modello lo imposta, altrimenti il suo stato';

  @override
  String get workspaceAddressLabel => 'Indirizzo dello spazio';

  @override
  String get workspaceCodeCopied => 'Copiato';

  @override
  String get workspaceCodeCopy => 'Copia ID';

  @override
  String get workspaceCodeEdit => 'Cambia l\'ID dello spazio';

  @override
  String get workspaceCodeExplainer =>
      'I coworker scansionano questo codice QR — o digitano l\'ID — per unirsi a questo spazio.';

  @override
  String get workspaceCodeHint => '4–20 lettere o cifre, univoco';

  @override
  String get workspaceCodeLabel => 'ID dello spazio';

  @override
  String get workspaceCodeRejected =>
      'ID rifiutato — deve avere 4–20 lettere o cifre e non essere già in uso.';

  @override
  String get workspaceCodeSharePng => 'Condividi come PNG';

  @override
  String get workspaceCodeTitle => 'ID dello spazio e QR';

  @override
  String get workspaceConfigAvailability => 'Disponibilità';

  @override
  String get workspaceConfigBookableWhole => 'prenotabile per intero';

  @override
  String get workspaceConfigClosures => 'Chiusure';

  @override
  String get workspaceConfigColName => 'Nome';

  @override
  String get workspaceConfigColRole => 'Ruolo';

  @override
  String get workspaceConfigColStatus => 'Stato';

  @override
  String get workspaceConfigEmptyLevel => 'Nessuna sala';

  @override
  String get workspaceConfigFeatures => 'Funzioni attive';

  @override
  String get workspaceConfigFloorPlan => 'Pianta';

  @override
  String get workspaceConfigGranularity => 'Granularità di prenotazione';

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
  String get workspaceConfigInvitations => 'Inviti';

  @override
  String get workspaceConfigMembersSection => 'Membri';

  @override
  String get workspaceConfigNone => 'Nessuno';

  @override
  String get workspaceConfigOpenDays => 'Giorni di apertura';

  @override
  String get workspaceConfigOverview => 'Panoramica';

  @override
  String get workspaceConfigPdfExport => 'Esporta configurazione (PDF)';

  @override
  String get workspaceConfigPdfExportSubtitle =>
      'Istantanea completa: impostazioni, tutti i membri e la pianta.';

  @override
  String workspaceConfigPdfGeneratedOn(String date) {
    return 'Generato il $date';
  }

  @override
  String get workspaceConfigPdfTitle => 'Configurazione dello spazio';

  @override
  String get workspaceConfigSeats => 'Posti';

  @override
  String get workspaceCountryLabel => 'Paese';

  @override
  String get workspaceCurrencyLabel => 'Valuta';

  @override
  String get workspaceDangerZone => 'Zona pericolosa';

  @override
  String workspaceDeskOpacityValue(int percent) {
    return 'Opacità: $percent%';
  }

  @override
  String get workspaceDeskTransparencyHelper =>
      'Riduci l\'opacità dei tavoli per far trasparire la foto di sfondo del piano.';

  @override
  String get workspaceDeskTransparencyTitle => 'Trasparenza dei tavoli';

  @override
  String get workspaceExcelExport => 'Esporta i dati (Excel)';

  @override
  String get workspaceExcelExportSubtitle =>
      'Uno ZIP: tutti i dati in una cartella (prenotazioni, pagamenti, fatture, membri, piantina — una scheda ciascuno), un manifesto che ne conta le righe e i file salvati dello spazio.';

  @override
  String get workspaceFieldsOptional => 'facoltativo';

  @override
  String get workspaceFieldsPersonalNote =>
      'Le tue risposte sono dati personali: fanno parte della tua esportazione dei dati e vengono cancellate quando lasci questo spazio, salvo un obbligo legale di conservazione documentato dallo spazio.';

  @override
  String get workspaceFieldsSaveFailed =>
      'Le tue risposte alle domande di questo spazio non sono state salvate. Il resto dei tuoi dati sì.';

  @override
  String workspaceFieldsTitle(String workspace) {
    return 'Domande di $workspace';
  }

  @override
  String get workspaceGenericError => 'Qualcosa è andato storto. Riprova.';

  @override
  String get workspaceInviteCodeInvalid =>
      'Nessun ID trovato — incolla l\'invito o digita l\'ID.';

  @override
  String get workspaceInviteCodeLabel => 'Codice di invito';

  @override
  String get workspaceInvitePasteHint =>
      'Incolla l\'intero messaggio d\'invito — l\'ID viene trovato automaticamente.';

  @override
  String get workspaceLanguageHelper =>
      'Gli inviti sono scritti per impostazione predefinita in questa lingua. La lingua della tua app si imposta nelle Impostazioni.';

  @override
  String get workspaceLanguageLabel => 'Lingua dello spazio';

  @override
  String get workspaceLanguageUnset => 'Lingua dell\'app del mittente';

  @override
  String get workspaceNameLabel => 'Nome dello spazio';

  @override
  String get workspacePaymentsBillingTitle => 'Pagamenti e fatturazione';

  @override
  String get workspaceResetConfirmButton => 'Reimposta lo spazio';

  @override
  String workspaceResetConfirmLabel(String phrase) {
    return 'Digita «$phrase» per confermare';
  }

  @override
  String get workspaceResetConfirmPhrase => 'Accetto';

  @override
  String get workspaceResetDialogTitle => 'Reimpostare questo spazio?';

  @override
  String get workspaceResetDone => 'Spazio reimpostato.';

  @override
  String get workspaceResetSubtitle =>
      'Elimina tutte le prenotazioni, la contabilità e la pianta. Mantiene impostazioni e membri.';

  @override
  String get workspaceResetTitle => 'Reimposta lo spazio';

  @override
  String get workspaceResetWarning =>
      'Questo elimina definitivamente tutte le prenotazioni, tutti i dati contabili e di registro, il flusso attività e l\'intera pianta — piani, stanze, tavoli, posti e immagini. Le impostazioni dello spazio, le fasce tariffarie, la disponibilità, le funzioni, i cataloghi e i membri vengono mantenuti. Operazione irreversibile.';

  @override
  String get workspaceSettingsConflict =>
      'Qualcuno ha modificato queste impostazioni mentre le stavate modificando. Non è stato salvato nulla; le vostre modifiche sono ancora qui.';

  @override
  String get workspaceSettingsCurrencyHelper =>
      'Proposta in base al paese — modificala se la tua community fattura in un’altra valuta.';

  @override
  String get workspaceSettingsSaved => 'Spazio salvato.';

  @override
  String get workspaceSettingsTitle => 'Spazio di coworking';

  @override
  String get workspaceTimezoneHint => 'Europe/Rome';

  @override
  String get workspaceTimezoneLabel => 'Fuso orario';

  @override
  String get workspaceTimezoneUnknown => 'Scegli un fuso orario dall\'elenco';

  @override
  String get workspaceWhatsappGroupHelper =>
      'Mostrato ai membri perché possano unirsi al gruppo WhatsApp della community. Incolla il link di invito del gruppo (https://chat.whatsapp.com/…). Lascia vuoto per non mostrare nulla.';

  @override
  String get workspaceWhatsappGroupInvalid =>
      'Deve essere un link di invito chat.whatsapp.com';

  @override
  String get workspaceWhatsappGroupLabel => 'Link del gruppo WhatsApp';

  @override
  String get workspaceWhatsappGroupTitle => 'Gruppo WhatsApp';

  @override
  String get workspaceXmlErrorInvalidPlan =>
      'La planimetria nel file non è valida: stanze, scrivanie o postazioni si sovrappongono o escono dalla loro area.';

  @override
  String get workspaceXmlErrorInvalidValue =>
      'Il file contiene un valore non valido e non può essere importato.';

  @override
  String get workspaceXmlErrorMalformed => 'Il file non è un XML leggibile.';

  @override
  String get workspaceXmlErrorMissingAttribute =>
      'Il file è incompleto — manca un valore obbligatorio.';

  @override
  String get workspaceXmlErrorMissingElement =>
      'Il file è incompleto — manca una sezione obbligatoria.';

  @override
  String get workspaceXmlErrorUnsupportedVersion =>
      'Il file è stato esportato da una versione più recente di DesKilo e non può essere importato.';

  @override
  String get workspaceXmlErrorWrongRoot =>
      'Questo non è un file di spazio DesKilo.';

  @override
  String get workspaceXmlExport => 'Esporta lo spazio (XML)';

  @override
  String get workspaceXmlExportSubtitle =>
      'Impostazioni e planimetria in un file condivisibile. Senza membri, prenotazioni o dati finanziari.';

  @override
  String get workspaceXmlFileTypeLabel => 'XML';

  @override
  String get workspaceXmlImport => 'Importa lo spazio (XML)';

  @override
  String get workspaceXmlImportConfigurationOnly =>
      'La configurazione è stata applicata. La planimetria è stata mantenuta: questo spazio ha già prenotazioni, la sua planimetria non può essere sostituita.';

  @override
  String get workspaceXmlImportConfirm => 'Sostituisci e importa';

  @override
  String get workspaceXmlImportPartial =>
      'Una parte dell’importazione è stata applicata prima di fermarsi: controlla le impostazioni e la pianta qui sotto.';

  @override
  String workspaceXmlImportPreviewAccessories(int count) {
    return 'Accessori: $count';
  }

  @override
  String workspaceXmlImportPreviewConfiguration(
    int settings,
    int tables,
    int rows,
  ) {
    return 'Configurazione: $settings impostazioni, $rows righe in $tables tabelle';
  }

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
  String get workspaceXmlImportPreviewTitle => 'Sostituire la planimetria?';

  @override
  String get workspaceXmlImportPreviewWarning =>
      'La planimetria attuale verrà eliminata e sostituita e le impostazioni dello spazio verranno sovrascritte. L\'operazione non può essere annullata.';

  @override
  String get workspaceXmlImportReservationsError =>
      'Questo spazio ha già delle prenotazioni, quindi la planimetria non può essere sostituita. L\'importazione è possibile solo prima della prima prenotazione.';

  @override
  String get workspaceXmlImportSubtitle =>
      'Ripristina impostazioni e planimetria da un file esportato. Sostituisce la planimetria attuale.';

  @override
  String get workspaceXmlImportSuccess => 'Spazio importato.';
}
