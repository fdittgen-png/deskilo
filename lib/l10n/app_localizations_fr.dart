// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get authSignInTitle => 'Connexion';

  @override
  String get authSignUpTitle => 'Créer un compte';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authDisplayNameLabel => 'Nom affiché';

  @override
  String get authSignInButton => 'Se connecter';

  @override
  String get authSignUpButton => 'Créer le compte';

  @override
  String get authToggleToSignUp => 'Nouveau ici ? Créez un compte';

  @override
  String get authToggleToSignIn => 'Déjà un compte ? Connectez-vous';

  @override
  String get authFieldRequired => 'Obligatoire';

  @override
  String get authPasswordTooShort => 'Au moins 8 caractères';

  @override
  String get authGenericError =>
      'Échec de l\'authentification. Vérifiez vos identifiants et réessayez.';

  @override
  String get authSignOut => 'Se déconnecter';

  @override
  String get authNetworkError =>
      'Impossible de joindre le serveur. Vérifiez votre connexion et réessayez.';

  @override
  String get availabilityTitle => 'Disponibilité';

  @override
  String get availabilityOpenWeekdays => 'Jours d\'ouverture';

  @override
  String get availabilityClosureDays => 'Jours de fermeture';

  @override
  String get availabilityAddClosure => 'Ajouter un jour de fermeture';

  @override
  String get availabilityClosureReason => 'Motif (facultatif)';

  @override
  String get availabilityLastOpenDay =>
      'Au moins un jour de la semaine doit rester ouvert.';

  @override
  String get availabilityNoClosures => 'Aucun jour de fermeture.';

  @override
  String billSubscription(int pct) {
    return 'Abonnement $pct %';
  }

  @override
  String billEntitlement(int used, int included, int openDays) {
    return '$used demi-journées utilisées sur $included ($openDays jours d\'ouverture)';
  }

  @override
  String billOverage(int extra) {
    return '$extra demi-journées supplémentaires';
  }

  @override
  String get billServices => 'Services consommés';

  @override
  String get billServicesTotal => 'Total des services';

  @override
  String get billOpenPositions => 'Postes en attente';

  @override
  String get billPendingBadge => 'en attente de validation';

  @override
  String get billPaymentsCredits => 'Paiements et crédits';

  @override
  String get billBalance => 'Solde';

  @override
  String get billSettled => 'Réglé';

  @override
  String get billOutstanding => 'À régler';

  @override
  String get billPdfTitle => 'Facture mensuelle';

  @override
  String get billPdfExport => 'Exporter la facture en PDF';

  @override
  String get billingTitle => 'Facturation';

  @override
  String get billingFeeBands => 'Paliers tarifaires';

  @override
  String billingBandFrom(int from) {
    return 'dès $from %';
  }

  @override
  String get billingBandTo => 'Jusqu\'à %';

  @override
  String get billingBandFee => 'Tarif mensuel';

  @override
  String get billingBandOverage => 'Dépassement';

  @override
  String get billingAddBand => 'Ajouter un palier';

  @override
  String get billingRemoveBand => 'Supprimer le palier';

  @override
  String get billingBandsInvalid =>
      'Les paliers doivent croître et se terminer à 100 %.';

  @override
  String get billingSaved => 'Enregistré.';

  @override
  String get billingLevels => 'Niveaux d\'abonnement';

  @override
  String get billingAddLevel => 'Ajouter un niveau';

  @override
  String get billingLevelValue => 'Niveau (1–100)';

  @override
  String get billingAllowCustom => 'Autoriser une valeur libre négociée';

  @override
  String get memberSubscriptionLabel => 'Abonnement';

  @override
  String get memberSubscriptionCustom => 'Personnalisé (1–100)';

  @override
  String moneySubscriptionPct(int pct) {
    return 'Abonnement $pct %';
  }

  @override
  String percentValue(int value) {
    return '$value %';
  }

  @override
  String get calendarMineTab => 'Les miennes';

  @override
  String get calendarEveryoneTab => 'Tout le monde';

  @override
  String get calendarNoReservations => 'Aucune réservation ce jour-là.';

  @override
  String get calendarCancelOccurrence => 'Annuler cette occurrence';

  @override
  String get calendarCancelFollowing => 'Annuler celle-ci et les suivantes';

  @override
  String get calendarPreviousMonth => 'Mois précédent';

  @override
  String get calendarNextMonth => 'Mois suivant';

  @override
  String get calendarReservationActions => 'Actions de la réservation';

  @override
  String get appTitle => 'DesKilo';

  @override
  String get tabPlan => 'Plan';

  @override
  String get tabCalendar => 'Calendrier';

  @override
  String get tabEvents => 'Événements';

  @override
  String get tabMoney => 'Finances';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get consumptionAdd => 'Ajouter une consommation';

  @override
  String consumptionAddForMember(String name) {
    return 'Ajouter un service pour $name';
  }

  @override
  String get consumptionService => 'Service';

  @override
  String get consumptionQuantity => 'Quantité';

  @override
  String get consumptionPeriodLabel => 'Période de facturation (AAAA-MM)';

  @override
  String get consumptionNoServices => 'Aucun service actif à enregistrer.';

  @override
  String get consumptionRecorded =>
      'Consommation enregistrée — en attente de confirmation.';

  @override
  String get eventTypeServiceCharge => 'Service';

  @override
  String eventServiceChargeTitle(String name, int quantity, String amount) {
    return '$name ×$quantity — $amount';
  }

  @override
  String get developerMode => 'Mode développeur';

  @override
  String get developerTitle => 'Développeur';

  @override
  String get developerExport => 'Exporter le journal';

  @override
  String get developerClear => 'Vider le journal';

  @override
  String get developerEmpty => 'Aucune entrée de journal pour l\'instant.';

  @override
  String get developerFilterAll => 'Tout';

  @override
  String get developerFilterErrors => 'Erreurs';

  @override
  String get developerFilterWarnings => 'Avertissements+';

  @override
  String get editorTitle => 'Éditeur d\'espace';

  @override
  String get editorOpenTooltip => 'Modifier l\'espace';

  @override
  String get editorAddLevel => 'Ajouter un étage';

  @override
  String get editorNoLevels =>
      'Aucun étage pour l\'instant. Ajoutez le premier étage de votre espace.';

  @override
  String get editorLevelNameLabel => 'Nom de l\'étage';

  @override
  String get editorRenameLevel => 'Renommer';

  @override
  String get editorLevelActions => 'Actions de l\'étage';

  @override
  String get editorDeleteLevelConfirm =>
      'Supprimer cet étage ? Tous les bureaux, tables et places qu\'il contient seront supprimés.';

  @override
  String get editorToolSelect => 'Sélection';

  @override
  String get editorToolOffice => 'Bureau';

  @override
  String get editorToolDesk => 'Table';

  @override
  String get editorToolErase => 'Effacer';

  @override
  String get editorNewOffice => 'Nouveau bureau';

  @override
  String get editorOfficeNameLabel => 'Nom du bureau';

  @override
  String get editorOfficeNameDefault => 'Bureau';

  @override
  String get editorDeskNameDefault => 'Table';

  @override
  String get editorDeskNameLabel => 'Nom de la table';

  @override
  String get editorPlacementOverlap => 'Chevauche un élément existant.';

  @override
  String get editorPlacementOutside =>
      'Doit être entièrement à l\'intérieur d\'un bureau.';

  @override
  String get editorOfficeProperties => 'Bureau';

  @override
  String get editorDeskProperties => 'Table';

  @override
  String get editorBookableAsWhole => 'Réservable en entier';

  @override
  String get editorDeleteElementConfirm =>
      'Supprimer cet élément ? Tout ce qui y est placé sera aussi supprimé.';

  @override
  String get editorToolSeat => 'Place';

  @override
  String get editorSeatProperties => 'Place';

  @override
  String get editorSeatNameLabel => 'Nom de la place';

  @override
  String get editorSeatNameDefault => 'Place';

  @override
  String get editorOrientationLabel => 'Sens d\'assise';

  @override
  String get editorChairLabel => 'Type de chaise';

  @override
  String get editorAmenitiesLabel => 'Équipements';

  @override
  String get editorBlockedLabel => 'Bloquée (maintenance)';

  @override
  String get editorSeatNoDesk =>
      'Les places ne peuvent être posées que sur une table.';

  @override
  String get amenityMonitor => 'Écran';

  @override
  String get amenityStandingDesk => 'Bureau debout';

  @override
  String get amenityWindow => 'Côté fenêtre';

  @override
  String get amenityDock => 'Station d\'accueil';

  @override
  String get amenityErgonomicChair => 'Chaise ergonomique';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get eventsPendingHeader => 'En attente de votre confirmation';

  @override
  String get eventAccept => 'Accepter';

  @override
  String get eventReject => 'Refuser';

  @override
  String get eventsEmpty => 'Aucun événement pour l\'instant.';

  @override
  String get eventsFilterAll => 'Tous';

  @override
  String get eventTypeReservation => 'Réservation';

  @override
  String get eventTypePayment => 'Paiement';

  @override
  String get eventTypeExpense => 'Dépense';

  @override
  String get eventTypeAdjustment => 'Ajustement';

  @override
  String eventReservationCreated(String actor, String target) {
    return '$actor a réservé $target';
  }

  @override
  String eventReservationModified(String actor, String target) {
    return '$actor a modifié la réservation de $target';
  }

  @override
  String eventReservationCancelled(String actor, String target) {
    return '$actor a annulé la réservation de $target';
  }

  @override
  String eventPaymentSubmitted(String actor, String amount) {
    return '$actor a enregistré un paiement de $amount';
  }

  @override
  String eventExpenseSubmitted(String actor, String amount) {
    return '$actor a soumis une dépense de $amount';
  }

  @override
  String eventForSubject(String name) {
    return 'pour $name';
  }

  @override
  String get pushPendingTitle => 'DesKilo';

  @override
  String get pushPendingBody => 'Quelqu\'un attend votre confirmation.';

  @override
  String get featuresTitle => 'Fonctionnalités';

  @override
  String get featureCalendarTab => 'Onglet Calendrier';

  @override
  String get featureCalendarTabDesc =>
      'Vue mensuelle des réservations et jours de fermeture.';

  @override
  String get featureEventsTab => 'Onglet Événements';

  @override
  String get featureEventsTabDesc =>
      'Fil d\'activité et confirmations en attente.';

  @override
  String get featureMoneyTab => 'Onglet Finances';

  @override
  String get featureMoneyTabDesc =>
      'Factures mensuelles, paiements et dépenses.';

  @override
  String get featureServices => 'Services';

  @override
  String get featureServicesDesc =>
      'Catalogue de services et suivi des consommations.';

  @override
  String get featurePdfExport => 'Export PDF';

  @override
  String get featurePdfExportDesc => 'Exporter la facture mensuelle en PDF.';

  @override
  String get featureSeriesBooking => 'Réservation en série';

  @override
  String get featureSeriesBookingDesc =>
      'Répéter une réservation chaque jour, chaque semaine ou en semaine.';

  @override
  String get featureBookForOthers => 'Réserver pour d\'autres';

  @override
  String get featureBookForOthersDesc =>
      'Les admins et propriétaires réservent des places pour d\'autres membres.';

  @override
  String get featurePushNotifications => 'Notifications push';

  @override
  String get featurePushNotificationsDesc =>
      'Livrer les confirmations en attente sur les appareils des membres.';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageSystemDefault => 'Par défaut du système';

  @override
  String get membersTitle => 'Membres et forfaits';

  @override
  String get membersPlanNone => 'Aucun forfait';

  @override
  String get memberRoleOwner => 'Propriétaire';

  @override
  String get memberRoleAdmin => 'Admin';

  @override
  String get memberStatusPaused => 'En pause';

  @override
  String get memberStatusExited => 'Parti';

  @override
  String get profilesTitle => 'Profils';

  @override
  String get profilesAdd => 'Ajouter un profil';

  @override
  String get profilesActive => 'Profil actif';

  @override
  String get memberRoleMember => 'Membre';

  @override
  String get moneyBaseFee => 'Abonnement de base';

  @override
  String moneyUsage(int used, int included) {
    return '$used demi-journées utilisées sur $included';
  }

  @override
  String moneyUsageUnlimited(int used) {
    return '$used demi-journées utilisées';
  }

  @override
  String moneyOverage(int count) {
    return 'Dépassement ($count demi-journées supplémentaires)';
  }

  @override
  String get moneyCredits => 'Paiements et crédits';

  @override
  String get moneyBalance => 'Solde';

  @override
  String get moneyStatementSettled => 'Réglé';

  @override
  String get moneyStatementOpen => 'À régler';

  @override
  String get moneyRecordPayment => 'Enregistrer un paiement';

  @override
  String get moneyAmountLabel => 'Montant';

  @override
  String get moneyNoteLabel => 'Note (facultatif)';

  @override
  String get moneySubmitPayment => 'Soumettre pour confirmation';

  @override
  String get moneyPaymentPending =>
      'Paiement soumis — en attente de confirmation.';

  @override
  String get moneyLedgerHeader => 'Grand livre';

  @override
  String get moneyLedgerEmpty => 'Aucune écriture pour l\'instant.';

  @override
  String get moneySubmitExpense => 'Soumettre une dépense';

  @override
  String get moneyExpenseCategoryLabel => 'Catégorie';

  @override
  String get moneyDescriptionLabel => 'Description';

  @override
  String get moneyExpensePending =>
      'Dépense soumise — en attente d\'approbation.';

  @override
  String get expenseCategoryCoffee => 'Café et cuisine';

  @override
  String get expenseCategorySupplies => 'Fournitures';

  @override
  String get expenseCategoryEquipment => 'Équipement';

  @override
  String get expenseCategoryOther => 'Autre';

  @override
  String get ledgerCategorySubscription => 'Abonnement';

  @override
  String get ledgerCategoryOverage => 'Dépassement';

  @override
  String get ledgerCategoryExpense => 'Remboursement de dépense';

  @override
  String get ledgerCategoryPayment => 'Paiement';

  @override
  String get ledgerCategoryAdjustment => 'Ajustement';

  @override
  String get ledgerCategoryService => 'Service';

  @override
  String get plansEditorTitle => 'Formules';

  @override
  String get plansEditorNew => 'Nouvelle formule';

  @override
  String get plansEditorEdit => 'Modifier la formule';

  @override
  String get plansEditorInactive => 'Inactive';

  @override
  String get plansEditorUnlimited => 'demi-journées illimitées';

  @override
  String plansEditorQuota(int count) {
    return '$count demi-journées';
  }

  @override
  String plansEditorPerExtra(String price) {
    return '$price/demi-journée suppl.';
  }

  @override
  String get planNameLabel => 'Nom';

  @override
  String get planBaseFeeLabel => 'Forfait mensuel';

  @override
  String get planIncludedLabel => 'Demi-journées incluses';

  @override
  String get planIncludedHelper => 'Laisser vide pour illimité';

  @override
  String get planOverageLabel => 'Prix par demi-journée supplémentaire';

  @override
  String get planActiveLabel => 'Active';

  @override
  String get paymentMethodBankTransfer => 'Virement';

  @override
  String get paymentMethodCash => 'Espèces';

  @override
  String get paymentMethodPaypal => 'PayPal';

  @override
  String get paymentMethodTwint => 'TWINT';

  @override
  String get paymentMethodCard => 'Carte';

  @override
  String get paymentMethodOther => 'Autre';

  @override
  String get planNoLevels => 'L\'espace n\'a pas encore de plan.';

  @override
  String get planLevelLabel => 'Étage';

  @override
  String get planCheckInTitle => 'Arrivée';

  @override
  String get planStartNow => 'Commence maintenant';

  @override
  String get planUntilLabel => 'Jusqu\'à';

  @override
  String get planCheckInButton => 'S\'installer';

  @override
  String get planCheckOutButton => 'Partir';

  @override
  String get planCancelReservationButton => 'Annuler la réservation';

  @override
  String get planSeatBlocked => 'Cette place est bloquée pour maintenance.';

  @override
  String planReservedBy(String name) {
    return 'Réservée par $name';
  }

  @override
  String planOccupiedBy(String name) {
    return 'Occupée par $name';
  }

  @override
  String planUntil(String time) {
    return 'jusqu\'à $time';
  }

  @override
  String planCappedByNext(String time) {
    return 'La place est réservée à partir de $time.';
  }

  @override
  String get planCheckInFailed =>
      'Impossible de s\'installer — la place vient peut-être d\'être prise.';

  @override
  String get planYourSeat => 'Votre place';

  @override
  String get planListViewTooltip => 'Vue liste';

  @override
  String get planMapViewTooltip => 'Vue plan';

  @override
  String get planNowButton => 'Maintenant';

  @override
  String get planReserveButton => 'Réserver';

  @override
  String get planReservationsEmpty => 'Aucune réservation pour ce jour.';

  @override
  String planStartsAt(String time) {
    return 'Commence à $time';
  }

  @override
  String get planRepeatLabel => 'Répéter';

  @override
  String get repeatNone => 'Ne se répète pas';

  @override
  String get repeatDaily => 'Tous les jours';

  @override
  String get repeatWeekdays => 'Tous les jours ouvrés';

  @override
  String get repeatWeekly => 'Chaque semaine';

  @override
  String get planUntilDateLabel => 'Répéter jusqu\'au';

  @override
  String seriesBookedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réservations créées',
      one: '1 réservation créée',
    );
    return '$_temp0';
  }

  @override
  String get seriesSkippedTitle => 'Ignorées (déjà prises) :';

  @override
  String get commonOk => 'OK';

  @override
  String get reminderTitle => 'Arrivée bientôt';

  @override
  String reminderBody(String target, String time) {
    return '$target commence à $time';
  }

  @override
  String get planNoSeats => 'Cet étage n\'a pas encore de places.';

  @override
  String get planStateFree => 'Libre';

  @override
  String get planStateYours => 'À vous';

  @override
  String get planBookForLabel => 'Réserver pour';

  @override
  String get planSendForConfirmation => 'Envoyer pour confirmation';

  @override
  String planBookedForPending(String name) {
    return 'Envoyé à $name pour confirmation.';
  }

  @override
  String get servicesTitle => 'Services';

  @override
  String get servicesEmpty => 'Aucun service pour l’instant.';

  @override
  String get servicesNew => 'Nouveau service';

  @override
  String get servicesEdit => 'Modifier le service';

  @override
  String get servicesName => 'Nom';

  @override
  String get servicesPrice => 'Prix';

  @override
  String get servicesInactive => 'Inactif';

  @override
  String get servicesActive => 'Actif';

  @override
  String eventValidations(int current, int required) {
    return '$current/$required validations';
  }

  @override
  String eventValidatedBy(String name, String when) {
    return 'Validé par $name · $when';
  }

  @override
  String eventRejectedBy(String name, String when) {
    return 'Refusé par $name · $when';
  }

  @override
  String get eventSystemDecider => 'Système';

  @override
  String get validationTitle => 'Règles de validation';

  @override
  String get validationDefaultPolicy => 'Règle par défaut';

  @override
  String get validationInherited => 'Hérite de la règle par défaut';

  @override
  String get validationCustomized => 'Personnalisée';

  @override
  String get validationRequiredCount => 'Validations requises';

  @override
  String get validationAdminsMay => 'Les admins peuvent valider';

  @override
  String get validationOwnerOnly => 'Propriétaire uniquement';

  @override
  String get validationAllAdmins => 'Tous les admins';

  @override
  String get validationSpecificAdmins => 'Admins spécifiques';

  @override
  String get validationOwnerRequired => 'Le propriétaire doit toujours valider';

  @override
  String get validationNotEnough => 'Pas assez de validateurs éligibles.';

  @override
  String get validationSaved => 'Règle de validation enregistrée.';

  @override
  String get onboardingTitle => 'Bienvenue sur DesKilo';

  @override
  String get onboardingCreateTab => 'Créer un espace';

  @override
  String get onboardingJoinTab => 'Rejoindre un espace';

  @override
  String get workspaceNameLabel => 'Nom de l\'espace';

  @override
  String get workspaceCountryLabel => 'Pays';

  @override
  String get workspaceCurrencyLabel => 'Devise';

  @override
  String get workspaceTimezoneLabel => 'Fuseau horaire';

  @override
  String get onboardingCreateButton => 'Créer l\'espace';

  @override
  String get workspaceInviteCodeLabel => 'Code d\'invitation';

  @override
  String get onboardingJoinButton => 'Rejoindre';

  @override
  String get workspaceGenericError =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get countryNameDE => 'Allemagne';

  @override
  String get countryNameAT => 'Autriche';

  @override
  String get countryNameCH => 'Suisse';

  @override
  String get countryNameFR => 'France';

  @override
  String get countryNameIT => 'Italie';

  @override
  String get countryNameES => 'Espagne';

  @override
  String get countryNamePT => 'Portugal';

  @override
  String get countryNameNL => 'Pays-Bas';

  @override
  String get countryNameBE => 'Belgique';

  @override
  String get countryNameLU => 'Luxembourg';

  @override
  String get countryNameGB => 'Royaume-Uni';

  @override
  String get countryNameUS => 'États-Unis';

  @override
  String get workspaceCodeTitle => 'ID de l\'espace et QR';

  @override
  String get workspaceCodeLabel => 'ID de l\'espace';

  @override
  String get workspaceCodeHint => '4 à 20 lettres ou chiffres, unique';

  @override
  String get workspaceCodeEdit => 'Changer l\'ID de l\'espace';

  @override
  String get workspaceCodeRejected =>
      'ID refusé — il doit comporter 4 à 20 lettres ou chiffres et ne pas être déjà pris.';

  @override
  String get workspaceCodeExplainer =>
      'Les coworkers scannent ce QR code — ou saisissent l\'ID — pour rejoindre cet espace.';

  @override
  String get workspaceCodeCopy => 'Copier l\'ID';

  @override
  String get workspaceCodeCopied => 'Copié';

  @override
  String get scanJoinTitle => 'Scanner le QR de l\'espace';

  @override
  String get onboardingScanButton => 'Scanner un QR code';

  @override
  String get workspaceCodeSharePng => 'Partager en PNG';

  @override
  String get workspaceSettingsTitle => 'Espace de coworking';

  @override
  String get workspaceSettingsSaved => 'Espace enregistré.';

  @override
  String get workspaceSettingsCurrencyHelper =>
      'Proposée d\'après le pays — modifiable si votre communauté facture dans une autre devise.';

  @override
  String get paymentInstructionsTitle => 'Instructions de paiement';

  @override
  String get paymentInstructionsHelper =>
      'Affichées aux membres sur un relevé impayé. Laisser vide pour ne rien afficher.';

  @override
  String get paymentInstructionsPaypalLabel => 'Lien ou identifiant PayPal.me';

  @override
  String get paymentInstructionsReferenceLabel =>
      'Indication de référence de paiement';

  @override
  String get paymentInstructionsIbanTitle => 'IBAN';

  @override
  String get paymentInstructionsIbanCopied => 'IBAN copié.';
}
