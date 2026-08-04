// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get accessoriesTitle => 'Accessoires';

  @override
  String get accessoriesEmpty => 'Aucun accessoire pour l’instant.';

  @override
  String get accessoriesNew => 'Nouvel accessoire';

  @override
  String get accessoriesEdit => 'Modifier l’accessoire';

  @override
  String get accessoriesName => 'Nom';

  @override
  String get accessoriesSupplement => 'Supplément par demi-journée';

  @override
  String accessoriesPerHalfDay(String amount) {
    return '$amount / demi-journée';
  }

  @override
  String get accessoriesNoSupplement => 'Sans supplément';

  @override
  String get accessoriesInactive => 'Inactif';

  @override
  String get accessoriesActive => 'Actif';

  @override
  String get authSignInTitle => 'Connexion';

  @override
  String get authSignUpTitle => 'Créer un compte';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authShowPassword => 'Afficher le mot de passe';

  @override
  String get authHidePassword => 'Masquer le mot de passe';

  @override
  String get authDisplayNameLabel => 'Nom affiché';

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authResetTitle => 'Réinitialiser le mot de passe';

  @override
  String get authResetExplainer =>
      'Nous vous enverrons un code à usage unique par e-mail. Utilisez-le ici pour définir un nouveau mot de passe.';

  @override
  String get authResetSendCode => 'Envoyer le code';

  @override
  String get authResetCodeSent => 'Code envoyé — vérifiez vos e-mails.';

  @override
  String get authResetCodeLabel => 'Code reçu par e-mail';

  @override
  String get authResetNewPasswordLabel => 'Nouveau mot de passe';

  @override
  String get authResetSubmit => 'Définir le nouveau mot de passe';

  @override
  String get authResetDone => 'Mot de passe mis à jour — vous êtes connecté.';

  @override
  String get authResetInvalidCode => 'Ce code est invalide ou a expiré.';

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
  String get availabilityGranularityTitle => 'Granularité des réservations';

  @override
  String get availabilityGranularityDescription =>
      'Demi-journées : les réservations couvrent le matin (jusqu\'à 13 h), l\'après-midi (à partir de 13 h) ou la journée entière.';

  @override
  String get availabilityGranularityFlexible => 'Plage horaire libre';

  @override
  String get availabilityGranularityHalfDay =>
      'Demi-journées (matin et après-midi)';

  @override
  String get availabilityGranularity5 => 'Créneaux de 5 minutes';

  @override
  String get availabilityGranularity15 => 'Créneaux de 15 minutes';

  @override
  String get availabilityGranularity30 => 'Créneaux de 30 minutes';

  @override
  String get availabilityGranularity60 => 'Créneaux d\'une heure';

  @override
  String get availabilityGranularityFullDay => 'Journées entières uniquement';

  @override
  String planSlotError(int minutes) {
    return 'Les réservations doivent commencer et finir sur la grille de $minutes minutes.';
  }

  @override
  String get planFullDayError =>
      'Ici, les réservations couvrent la journée entière.';

  @override
  String get myBadgeTitle => 'Mon badge';

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
  String get billAccessorySupplements => 'Suppléments d\'accessoires';

  @override
  String get entitlementTitle => 'Ce mois-ci';

  @override
  String entitlementDaysUsed(String used, String total) {
    return '$used sur $total jours utilisés';
  }

  @override
  String entitlementDaysLeft(String left) {
    return '$left jours restants';
  }

  @override
  String get entitlementBlockedFull =>
      'Vous avez utilisé tous vos jours ce mois-ci. Demandez-en plus à un administrateur ou demandez des demi-journées supplémentaires ci-dessous.';

  @override
  String entitlementPaygRate(String rate) {
    return 'Les jours au-delà de votre forfait sont facturés $rate chacun.';
  }

  @override
  String get entitlementPackageFull =>
      'Vous avez utilisé tous vos jours ce mois-ci. Achetez un forfait pour continuer à réserver.';

  @override
  String get billPackages => 'Forfaits de jours';

  @override
  String get payOnlineButton => 'Payer en ligne';

  @override
  String get payOnlineNotConfigured =>
      'Les paiements en ligne ne sont pas encore configurés. Demandez au propriétaire de l\'espace.';

  @override
  String get payOnlineChooseTitle => 'Payer en ligne';

  @override
  String get paymentProviderStripe => 'Carte bancaire (Stripe)';

  @override
  String get paymentProviderMollie => 'Mollie — iDEAL, Bancontact…';

  @override
  String get payOnlineDiagTitle => 'Paiements en ligne — non configurés';

  @override
  String get payOnlineDiagHint =>
      'Il manque cette configuration côté serveur (docs/design/payments-integration.md) :';

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
  String get memberOveragePolicyLabel => 'Quand les jours sont épuisés';

  @override
  String get memberOveragePolicyTooltip => 'Dépassement';

  @override
  String get overagePolicyBlocked => 'Bloquer toute réservation';

  @override
  String get overagePolicyPayg => 'Facturer le dépassement (à l\'usage)';

  @override
  String get overagePolicyPackage => 'Exiger l\'achat d\'un forfait';

  @override
  String get billingPackages => 'Forfaits de jours';

  @override
  String get billingPackagesHint =>
      'Les membres au plan forfait les achètent quand leurs jours sont épuisés.';

  @override
  String billingPackageSummary(int days, String price) {
    return '$days jours · $price';
  }

  @override
  String get billingPackageName => 'Nom';

  @override
  String get billingPackageDays => 'Jours';

  @override
  String get billingPackagePrice => 'Prix';

  @override
  String get billingAddPackage => 'Ajouter un forfait';

  @override
  String get buyPackageButton => 'Acheter un forfait';

  @override
  String get buyPackageTitle => 'Acheter un forfait';

  @override
  String buyPackageDays(int days) {
    return '$days jours';
  }

  @override
  String get buyPackageNone => 'Aucun forfait disponible pour l\'instant.';

  @override
  String get buyPackageDone => 'Jours ajoutés — profitez-en.';

  @override
  String get payConfigTitle => 'Paiements en ligne';

  @override
  String get payConfigOpen => 'Configurer';

  @override
  String get payConfigIntro =>
      'Saisissez chaque prestataire de paiement à proposer. Les clés sont stockées en sécurité sur le serveur et ne sont plus affichées. Voir docs/design/payments-integration.md.';

  @override
  String get payConfigConfigured => 'Configuré';

  @override
  String get payConfigNotConfigured => 'Non configuré';

  @override
  String get payConfigSecretSet => 'Défini — laisser vide pour conserver';

  @override
  String get payConfigSaved => 'Enregistré.';

  @override
  String get payConfigRemove => 'Supprimer';

  @override
  String get payConfigRemoved => 'Supprimé.';

  @override
  String get payFieldClientId => 'Client ID';

  @override
  String get payFieldSecret => 'Secret';

  @override
  String get payFieldEnv => 'Environnement';

  @override
  String get payFieldWebhookId => 'ID du webhook';

  @override
  String get payFieldReturnUrl => 'URL de retour';

  @override
  String get payFieldSecretKey => 'Clé secrète';

  @override
  String get payFieldWebhookSecret => 'Secret de signature du webhook';

  @override
  String get payFieldApiKey => 'Clé API';

  @override
  String get paymentProviderWero => 'Wero (via Mollie)';

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
  String get calendarShowOnPlan => 'Voir sur le plan';

  @override
  String get calendarListView => 'Vue liste';

  @override
  String get calendarTimelineView => 'Vue chronologique';

  @override
  String get calendarTimelineEmpty =>
      'Aucune réservation à cet étage ce jour-là.';

  @override
  String get calendarAllLevels => 'Tous les étages';

  @override
  String get calendarTimelineAllEmpty =>
      'Aucune réservation à aucun étage ce jour-là.';

  @override
  String calendarLevelCollapsed(String level) {
    return '$level, réduit';
  }

  @override
  String calendarLevelExpanded(String level) {
    return '$level, déplié';
  }

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
  String get settingsSectionAdministration => 'Administration';

  @override
  String get settingsSectionPreferences => 'Préférences';

  @override
  String get settingsSectionAdvanced => 'Avancé';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get shellReserveButton => 'Réserver';

  @override
  String commonSavedTo(String path) {
    return 'Enregistré dans $path';
  }

  @override
  String get commonSaveFailed => 'Impossible d\'enregistrer le fichier.';

  @override
  String get commonRetry => 'Réessayer';

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
  String get coOwnerAction => 'Copropriété';

  @override
  String get coOwnerNone => 'Aucun rôle de copropriétaire';

  @override
  String get coOwnerActive =>
      'Copropriétaire actif — permissions de propriétaire immédiates, succession automatique';

  @override
  String get coOwnerPassive =>
      'Copropriétaire passif — devient propriétaire à l\'activation ou au départ du propriétaire';

  @override
  String get coOwnerActivate => 'Promouvoir propriétaire maintenant';

  @override
  String get memberCoOwnerChip => 'Copropriétaire';

  @override
  String get memberCoOwnerPassiveChip => 'Copropriétaire (passif)';

  @override
  String get developerMode => 'Mode développeur';

  @override
  String get developerModeWorkspaceHint =>
      'S\'applique à tous les membres de cet espace.';

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
  String get pushStatusRegistered => 'Les notifications push sont actives';

  @override
  String get pushStatusNoDistributor =>
      'Les notifications push nécessitent une app distributrice';

  @override
  String get pushStatusNoDistributorHint =>
      'Installez ntfy (F-Droid ou Play Store), puis rouvrez l\'app.';

  @override
  String get directoryTitle => 'Membres';

  @override
  String get directoryEmpty => 'Aucun membre pour l\'instant.';

  @override
  String get directoryCheckedIn => 'Sur place';

  @override
  String directoryCheckedInSeat(String seat) {
    return 'Sur place · $seat';
  }

  @override
  String get directoryOnline => 'En ligne';

  @override
  String get directoryReservedToday => 'Réservé aujourd\'hui';

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
    return '$days j';
  }

  @override
  String get directoryWhatsapp => 'Discuter sur WhatsApp';

  @override
  String get directoryOpenGroup => 'Ouvrir le groupe WhatsApp';

  @override
  String get directoryClose => 'Fermer';

  @override
  String get directoryReservedNow => 'Réservé maintenant';

  @override
  String directoryReservedNowSeat(String seat) {
    return 'Réservé maintenant · $seat';
  }

  @override
  String get directoryReservationsHeading => 'Réservations';

  @override
  String get directoryNoUpcoming => 'Aucune réservation à venir';

  @override
  String get editorBackgroundImage => 'Image de fond';

  @override
  String get editorBackgroundSet => 'Définir l\'image de fond';

  @override
  String get editorBackgroundReplace => 'Remplacer l\'image de fond';

  @override
  String get editorBackgroundRemove => 'Supprimer l\'image de fond';

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
  String get editorToolImage => 'Image';

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
  String get editorAccessoriesLabel => 'Accessoires';

  @override
  String get editorNoAccessories =>
      'Aucun accessoire pour l\'instant — ajoutez-les dans Réglages → Accessoires.';

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
  String get pushCancelledTitle => 'Réservation retirée';

  @override
  String get pushCancelledBody => 'Une réservation a été retirée par un admin.';

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
  String get featureAdminSeatBlocking =>
      'Les admins peuvent bloquer des places';

  @override
  String get featureAdminSeatBlockingDesc =>
      'Les admins marquent des places comme non réservables pour maintenance. Le propriétaire le peut toujours.';

  @override
  String get featureAccessorySupplements => 'Suppléments d\'accessoires';

  @override
  String get featureAccessorySupplementsDesc =>
      'Facturer les accessoires de place tarifés par demi-journée réservée. S\'applique aux réservations à partir de l\'activation.';

  @override
  String get featureOnlinePayments => 'Paiements en ligne';

  @override
  String get featureOnlinePaymentsDesc =>
      'Permettre aux membres de payer leur facture en ligne (PayPal). Nécessite la configuration du prestataire de paiement sur le serveur.';

  @override
  String get featureNfcBadges => 'Badges RFID / NFC';

  @override
  String get featureNfcBadgesDesc =>
      'Les membres pointent à une borne en approchant une carte RFID/NFC. Nécessite un appareil Android avec NFC.';

  @override
  String get featureLevelBooking => 'Réservations de table, bureau et niveau';

  @override
  String get featureLevelBookingDesc =>
      'Réserver une table, un bureau ou un étage entier en une seule réservation, tarifé par demi-journée. Accordez le droit par membre.';

  @override
  String get featureAdminLevelAssign =>
      'Les admins peuvent attribuer des niveaux';

  @override
  String get featureAdminLevelAssignDesc =>
      'Les admins attribuent des réservations de niveau aux membres. Le propriétaire le peut toujours.';

  @override
  String get featureKioskMode => 'Mode borne';

  @override
  String get featureKioskModeDesc =>
      'Comptes tablette murale verrouillés sur le plan en direct ; les membres agissent par badge.';

  @override
  String get featureMembersDirectory => 'Annuaire des membres';

  @override
  String get featureMembersDirectoryDesc =>
      'L\'onglet communauté : qui est là, statuts, présence.';

  @override
  String get featureWhatsappIntegration => 'Intégration WhatsApp';

  @override
  String get featureWhatsappIntegrationDesc =>
      'Écrire aux membres sur WhatsApp et lier le groupe de la communauté.';

  @override
  String get featureSpaceQrCodes => 'Codes QR des espaces';

  @override
  String get featureSpaceQrCodesDesc =>
      'Cartes QR imprimables par poste, table, bureau et niveau — scanner pour réserver ou pointer.';

  @override
  String featureRequires(String feature) {
    return 'Nécessite $feature';
  }

  @override
  String get featureCoOwner => 'Copropriétaires';

  @override
  String get featureCoOwnerDesc =>
      'Nommer des copropriétaires : permissions de propriétaire immédiates (actif) ou succession en attente (passif).';

  @override
  String get featureAutoCheckInOut => 'Arrivée/départ auto en fin de journée';

  @override
  String get featureDataExport => 'Export des données (Excel)';

  @override
  String get featureAutoCheckInOutDesc =>
      'Les réservations sans arrivée ou départ enregistrés se clôturent seules une fois leur créneau passé.';

  @override
  String get featureDataExportDesc =>
      'Télécharger toutes les données de l’espace dans un classeur Excel.';

  @override
  String get helpTitle => 'Aide';

  @override
  String get helpContents => 'Sommaire';

  @override
  String get inviteSectionTitle => 'Inviter quelqu\'un';

  @override
  String get inviteViaWhatsapp => 'WhatsApp';

  @override
  String get inviteViaSms => 'SMS';

  @override
  String get inviteViaShare => 'Partager…';

  @override
  String get inviteFirstNameLabel => 'Prénom (facultatif)';

  @override
  String get inviteLastNameLabel => 'Nom (facultatif)';

  @override
  String get invitePhoneLabel => 'Téléphone (facultatif, avec indicatif)';

  @override
  String get inviteLanguageLabel => 'Langue du message';

  @override
  String get inviteSendFailed =>
      'Impossible d\'ouvrir l\'application d\'envoi. Le message a été copié à la place.';

  @override
  String get inviteCreateFailed =>
      'Impossible de créer l\'invitation. Vérifiez votre connexion et réessayez.';

  @override
  String invitationDefaultTemplate(
    String firstName,
    String workspaceName,
    String workspaceId,
    String downloadUrl,
    String inviteLink,
  ) {
    return 'Bonjour$firstName ! Vous êtes invité·e à rejoindre notre espace de coworking « $workspaceName » sur DesKilo.\n\n1. Téléchargez l\'application :\n$downloadUrl\n\n2. Ouvrez-la, créez votre compte (e-mail + mot de passe) et connectez-vous.\n\n3. Choisissez « Rejoindre un espace » et saisissez votre code d\'invitation personnel :\n$workspaceId\n(lien d\'invitation : $inviteLink)\n\nAstuce : copiez simplement ce message entier et collez-le dans l\'application — le code est détecté automatiquement. Votre code est personnel, à usage unique et valable 14 jours.\n\nÀ bientôt chez $workspaceName !';
  }

  @override
  String get invitationTemplateTitle => 'Message d\'invitation';

  @override
  String get invitationTemplateHelp =>
      'Envoyé quand vous invitez quelqu\'un par WhatsApp, SMS ou partage. Laissez vide pour utiliser le message intégré dans la langue choisie. Balises disponibles :';

  @override
  String get invitationTemplateHint =>
      'Message d\'invitation personnalisé utilisant les balises ci-dessus…';

  @override
  String get workspaceInvitePasteHint =>
      'Collez le message d\'invitation entier — l\'identifiant est trouvé automatiquement.';

  @override
  String get workspaceInviteCodeInvalid =>
      'Aucun identifiant trouvé — collez l\'invitation ou saisissez l\'identifiant.';

  @override
  String get invoicesTitle => 'Factures';

  @override
  String get invoicesEmpty => 'Aucune facture pour l\'instant.';

  @override
  String get invoiceCreate => 'Nouvelle facture';

  @override
  String get invoiceMemberLabel => 'Membre';

  @override
  String get invoiceIssue => 'Émettre la facture';

  @override
  String get invoiceIssued => 'Facture émise.';

  @override
  String get invoiceDownload => 'Télécharger le PDF';

  @override
  String get invoiceShare => 'Partager le PDF';

  @override
  String get invoicePdfTitle => 'Facture';

  @override
  String get invoicePdfIssuedOn => 'Émise le';

  @override
  String get invoicePdfIssuedBy => 'Émise par';

  @override
  String get invoicePdfBilledTo => 'Facturé à';

  @override
  String get invoicePdfSignature => 'Signature numérique (SHA-256)';

  @override
  String get addressTitle => 'Adresse';

  @override
  String get addressNone => 'Aucune adresse';

  @override
  String get addressSaved => 'Adresse enregistrée';

  @override
  String get workspaceAddressLabel => 'Adresse de l\'espace';

  @override
  String get featureInvoicing => 'Factures';

  @override
  String get featureInvoicingDesc =>
      'Factures immuables et signées dans une archive — à télécharger ou partager en PDF.';

  @override
  String get featureAdminInvoicing => 'Les admins émettent des factures';

  @override
  String get featureAdminInvoicingDesc =>
      'Les admins émettent aussi des factures. Le propriétaire le peut toujours.';

  @override
  String get invoiceVoidedChip => 'Erronée';

  @override
  String get invoiceVoidAction => 'Marquer comme erronée';

  @override
  String invoiceVoidConfirm(String number) {
    return 'Marquer la facture $number comme erronée ? Cette action est irréversible.';
  }

  @override
  String get invoiceVoided => 'Facture marquée comme erronée.';

  @override
  String get invoiceReplaceAction => 'Émettre un remplacement';

  @override
  String get invoicePdfVoided => 'ERRONÉE — annulée le';

  @override
  String get invoicePdfReplaces => 'Remplace';

  @override
  String get invoiceNothingToInvoice =>
      'Rien de suivi pour ce mois — rien à facturer.';

  @override
  String get invoiceLineAdjustment => 'Ajustement';

  @override
  String get invoiceFilterAllMembers => 'Tous les membres';

  @override
  String get invoiceFilterAllMonths => 'Tous les mois';

  @override
  String get invoiceFilterMonthLabel => 'Mois';

  @override
  String get invoiceSortTooltip => 'Trier';

  @override
  String get invoiceSortNewest => 'Plus récentes d\'abord';

  @override
  String get invoiceSortByMember => 'Par membre';

  @override
  String get invoiceSortByMonth => 'Par mois';

  @override
  String get invoiceBalance => 'Solde';

  @override
  String get invoiceDetailedToggle =>
      'Inclure l\'annexe détaillée (présences, services, paiements)';

  @override
  String get invoicePdfDescription => 'Description';

  @override
  String get invoicePdfCharges => 'Charges';

  @override
  String get invoicePdfPayments => 'Paiements';

  @override
  String get invoicePdfAnnex => 'Annexe — détails';

  @override
  String get invoicePdfAttendance => 'Présences';

  @override
  String get invoicePdfActivity => 'Mouvements & paiements';

  @override
  String get invoicePdfReserved => 'réservé';

  @override
  String get invoicePdfPage => 'Page';

  @override
  String get invoiceRemindAction => 'Envoyer un rappel';

  @override
  String get invoiceReminded => 'Rappel enregistré.';

  @override
  String invoiceRemindedBadge(int count) {
    return 'Rappelé ×$count';
  }

  @override
  String invoiceReminderMessage(String number, String amount) {
    return 'Rappel amical : facture $number — solde dû $amount.';
  }

  @override
  String get invoiceEInvoiceDownload =>
      'Télécharger la facture électronique (XML)';

  @override
  String get invoiceEInvoiceShare => 'Partager la facture électronique (XML)';

  @override
  String get invoiceTabToInvoice => 'À facturer';

  @override
  String get invoiceTabOpen => 'En cours';

  @override
  String get invoiceTabArchive => 'Archives';

  @override
  String get invoiceIssueAll => 'Tout facturer';

  @override
  String get invoiceIssueOne => 'Facturer';

  @override
  String get invoiceAllCaughtUp => 'Tout est à jour — rien à facturer.';

  @override
  String get invoiceNoOpen => 'Aucune facture en cours.';

  @override
  String invoiceSummaryToInvoice(int count) {
    return '$count à facturer';
  }

  @override
  String invoiceSummaryOpen(int count, String amount) {
    return '$count en cours · $amount dus';
  }

  @override
  String invoiceOpenAge(int days) {
    return '$days jours';
  }

  @override
  String invoiceIssuedCount(int count) {
    return '$count factures émises.';
  }

  @override
  String get eventTypeInvoicePayment => 'Paiement de facture';

  @override
  String eventInvoicePaid(String number, String amount) {
    return 'Facture $number payée — $amount';
  }

  @override
  String get invoiceMatchAction => 'Marquer comme payée';

  @override
  String get invoiceMatchNoteLabel => 'Note';

  @override
  String get invoiceMatchNoteRequired => 'Une note est obligatoire.';

  @override
  String invoiceMatchOver(String excess) {
    return 'Le membre a payé $excess de plus.';
  }

  @override
  String get invoiceMatchCreditNote => 'Créer un avoir pour l\'excédent';

  @override
  String get invoiceMatchForce => 'Accepter quand même (justifier)';

  @override
  String invoiceMatchUnder(String missing) {
    return 'Le membre a payé $missing de moins — accepter exige une note.';
  }

  @override
  String get invoiceMatched => 'Facture rapprochée.';

  @override
  String get invoiceMatchPendingBadge => 'En attente de validation';

  @override
  String get invoiceMatchedBadge => 'Payée';

  @override
  String get invoiceAlreadyInvoiced =>
      'Ce mois est déjà facturé pour ce membre.';

  @override
  String get invoiceMatchPickPayment => 'Sélectionner le paiement enregistré';

  @override
  String get invoiceMatchNoPayments =>
      'Aucun paiement enregistré à rapprocher — enregistrez-le ou confirmez-le d\'abord.';

  @override
  String get invoiceStatusOpen => 'En cours';

  @override
  String invoiceCountShown(int count) {
    return '$count factures';
  }

  @override
  String get invoiceFilterNoMatch =>
      'Aucune facture ne correspond à ces filtres.';

  @override
  String get invoiceFilterClear => 'Réinitialiser les filtres';

  @override
  String invoiceReplacedBy(String number) {
    return 'Remplacée par $number';
  }

  @override
  String invoiceMatchSummary(String amount, String date) {
    return 'Payée $amount le $date';
  }

  @override
  String invoiceRemindedLast(String date) {
    return 'dernière relance $date';
  }

  @override
  String invoiceAnnexSummary(int movements, int checkIns) {
    return 'Annexe : $movements mouvements, $checkIns pointages';
  }

  @override
  String get invoicePickMember =>
      'Choisissez un membre pour voir ce que son mois a enregistré.';

  @override
  String get invoiceRunningMonth =>
      'Ce mois est en cours — ses positions peuvent encore changer, et un mois ne se facture qu\'une seule fois.';

  @override
  String invoiceIssueAllConfirm(int count, String month, String total) {
    return 'Émettre $count factures pour $month, $total au total ? Une facture émise ne se modifie plus — une erreur se corrige par un remplacement.';
  }

  @override
  String invoiceIssuedPartial(int issued, int failed) {
    return '$issued émises, $failed en échec.';
  }

  @override
  String get invoiceEInvoiceAction => 'Facture électronique (XML)';

  @override
  String get invoiceEInvoiceExplain =>
      'La facture EN 16931 lisible par machine — le fichier que réclament les administrations et les clients professionnels.';

  @override
  String invoiceEInvoiceBusinessRoute(String channel, String format) {
    return 'Clients professionnels : transmettez-la via $channel au format $format.';
  }

  @override
  String invoiceEInvoicePublicRoute(String channel) {
    return 'Clients du secteur public : $channel.';
  }

  @override
  String get invoiceEInvoiceTransportPeppol =>
      'Un point d\'accès la livre au client — aucune plateforme publique dans le circuit.';

  @override
  String get invoiceEInvoiceTransportClearance =>
      'La plateforme nationale reçoit la facture d\'abord et la transmet — l\'envoi direct au client n\'est pas possible.';

  @override
  String get invoiceEInvoiceTransportAccredited =>
      'Une plateforme agréée transporte la facture et transmet les données à l\'administration fiscale pour vous.';

  @override
  String get invoiceEInvoiceTransportBilateral =>
      'Aucun canal imposé : e-mail, portail ou Peppol — comme convenu avec le client.';

  @override
  String invoiceEInvoiceFormatMismatch(String channel, String format) {
    return '$channel n\'accepte que le format $format : ce fichier EN 16931 sert pour Peppol, les acheteurs publics et les clients étrangers — votre plateforme ou votre comptable convertit le reste.';
  }

  @override
  String get invoiceEInvoiceReady =>
      'Prêt — ce fichier satisfait la norme EN 16931.';

  @override
  String get invoiceEInvoiceBlockedTitle =>
      'Un validateur rejetterait ce fichier :';

  @override
  String get invoiceEInvoiceIncompleteTitle =>
      'Valide, mais les profils nationaux stricts demandent aussi :';

  @override
  String get invoiceGapVatNotSupported =>
      'L\'espace facture la TVA mais cette facture ne porte aucun taux — ajoutez vos taux de TVA, puis émettez-la à nouveau.';

  @override
  String get invoiceGapMissingVatId =>
      'Le numéro de TVA manque — un vendeur exonéré doit l\'indiquer.';

  @override
  String get invoiceGapMissingLegalId =>
      'Le numéro d\'immatriculation manque (SIREN, HRB, CIF…) — rien ne vous identifie sur la facture.';

  @override
  String get invoiceGapMissingExemptionReason =>
      'Le motif de non-assujettissement à la TVA manque.';

  @override
  String get invoiceGapMissingSellerCountry => 'Le pays de l\'espace manque.';

  @override
  String get invoiceGapMissingBuyerCountry => 'Le pays du client manque.';

  @override
  String get invoiceGapNoChargeLines =>
      'Cette facture n\'a aucune ligne de charge — son mois était entièrement couvert par des paiements, il n\'y a donc rien à transmettre.';

  @override
  String get invoiceGapMissingSellerCity =>
      'la ville de l\'adresse de l\'espace';

  @override
  String get invoiceGapMissingSellerPostalCode =>
      'le code postal de l\'adresse de l\'espace';

  @override
  String get invoiceEInvoiceFixIdentity => 'Compléter l\'identité légale';

  @override
  String get legalIdentityTitle =>
      'Identité légale et facturation électronique';

  @override
  String get legalIdentitySubtitle =>
      'Régime de TVA et numéros d\'immatriculation — exigés par la facture électronique';

  @override
  String get legalIdentityIntro =>
      'Ce qu\'une facture électronique EN 16931 doit indiquer à votre sujet. Les factures déjà émises conservent l\'identité avec laquelle elles ont été signées.';

  @override
  String get legalIdentityRegime => 'Régime de TVA';

  @override
  String get legalIdentityRegimeNotSubject => 'Hors du champ de la TVA';

  @override
  String get legalIdentityRegimeExempt => 'Exonéré de TVA (franchise en base)';

  @override
  String get legalIdentityRegimeVatRegistered =>
      'Assujetti à la TVA (facture la TVA)';

  @override
  String get legalIdentityRegimeHint =>
      'Le régime détermine le numéro exigé par la norme : un numéro d’immatriculation hors champ de la TVA, un numéro de TVA en franchise.';

  @override
  String get legalIdentityVatId => 'Numéro de TVA';

  @override
  String get legalIdentityLegalId => 'Numéro d\'immatriculation';

  @override
  String get legalIdentityExemptionReason =>
      'Motif de non-application de la TVA';

  @override
  String get legalIdentityStreet => 'Rue';

  @override
  String get legalIdentityCity => 'Ville';

  @override
  String get legalIdentityPostalCode => 'Code postal';

  @override
  String get legalIdentitySaved => 'Identité légale enregistrée.';

  @override
  String get legalIdentityVatWarning =>
      'Cet espace facture la TVA mais aucun taux n\'est configuré : les factures n\'affichent pas de taxe et l\'export XML reste désactivé tant qu\'il n\'y en a pas.';

  @override
  String get addressCountryLabel => 'Pays';

  @override
  String get addressVatIdLabel =>
      'Numéro de TVA (si vous facturez en tant que professionnel)';

  @override
  String get invoiceProformaAction => 'Facture proforma';

  @override
  String get invoicePdfProforma => 'Proforma';

  @override
  String get invoiceProformaShared => 'Proforma partagée.';

  @override
  String get invoiceProformaNothing =>
      'Rien de suivi pour ce mois — aucune proforma à envoyer.';

  @override
  String get invoicePdfCopy => 'Copie';

  @override
  String get invoiceStatusPartiallyPaid => 'Partiellement payée';

  @override
  String get invoiceRegisterTitle => 'Registre des factures';

  @override
  String get invoiceRegisterDate => 'Date';

  @override
  String get invoiceRegisterName => 'Nom';

  @override
  String get invoiceRegisterAmount => 'Montant';

  @override
  String get invoiceRegisterTotal => 'Total';

  @override
  String get invoiceFacturXDownload => 'Télécharger le Factur-X (PDF)';

  @override
  String get invoiceFacturXShare => 'Partager le Factur-X (PDF)';

  @override
  String get invoiceFacturXExplain =>
      'Un seul fichier : la facture qu\'un humain lit, avec le XML lisible par machine à l\'intérieur. C\'est ce qu\'attendent la plupart des plateformes.';

  @override
  String get invoiceSendAction => 'Envoyer à la plateforme';

  @override
  String get invoiceSendAccepted => 'Envoyée — la plateforme l’a acceptée.';

  @override
  String get invoiceSendRejected => 'La plateforme l’a refusée.';

  @override
  String invoiceSentOn(String date, String status) {
    return 'Envoyée le $date · $status';
  }

  @override
  String get invoiceSendStatusAccepted => 'acceptée';

  @override
  String get invoiceSendStatusRejected => 'refusée';

  @override
  String get invoiceSendStatusFailed => 'non transmise';

  @override
  String get einvoiceConfigTitle => 'Plateforme de facturation électronique';

  @override
  String get einvoiceConfigIntro =>
      'Là où DesKilo dépose vos factures. Toute plateforme acceptant un envoi avec un jeton fonctionne — une plateforme agréée, un point d\'accès Peppol, une plateforme nationale. Le jeton est stocké côté serveur et n\'en ressort jamais.';

  @override
  String get einvoiceConfigEndpoint => 'URL de dépôt';

  @override
  String get einvoiceConfigToken => 'Jeton ou identifiant';

  @override
  String get einvoiceConfigHeader =>
      'En-tête d’authentification (Authorization par défaut)';

  @override
  String get einvoiceConfigField => 'Nom du champ fichier (file par défaut)';

  @override
  String get einvoiceConfigSaved => 'Plateforme enregistrée.';

  @override
  String get einvoiceConfigCleared => 'Plateforme supprimée.';

  @override
  String get einvoiceConfigClear => 'Supprimer la plateforme';

  @override
  String get einvoiceConfigTokenSet =>
      'Un jeton est enregistré (saisissez-en un nouveau pour le remplacer).';

  @override
  String get invoiceAccountingExport => 'Export comptable (SAF-T)';

  @override
  String get invoiceAccountingExportEmpty =>
      'Rien à exporter pour cette période.';

  @override
  String get invoiceRegisterYear => 'Année';

  @override
  String get invoiceRegisterAllYears => 'Toutes les années';

  @override
  String get invoiceExportSafT => 'SAF-T (XML, international)';

  @override
  String get invoiceExportFec => 'FEC (France, exigé en cas de contrôle)';

  @override
  String get invoiceExportChoose => 'Export comptable';

  @override
  String get fecAccountsTitle => 'Comptes à utiliser';

  @override
  String get fecAccountsIntro =>
      'Un FEC est fait d\'écritures comptables : il lui faut des numéros de compte. Voici les comptes du plan comptable général — remplacez-les par ceux de votre comptable si besoin.';

  @override
  String get fecAccountCustomers => 'Clients';

  @override
  String get fecAccountRevenue => 'Ventes';

  @override
  String get fecAccountBank => 'Banque';

  @override
  String get fecMissingSiren =>
      'Le FEC porte le nom de votre numéro d\'immatriculation — renseignez-le d\'abord dans Identité légale.';

  @override
  String get invoiceEInvoiceStaleIdentity =>
      'Votre identité légale est complète, mais cette facture a été signée avant et conserve ce avec quoi elle a été émise. Marquez-la erronée puis émettez un remplacement pour porter la nouvelle identité.';

  @override
  String get einvoiceConfigUnavailable =>
      'Impossible de charger la configuration de la plateforme. Vérifiez votre connexion et réessayez.';

  @override
  String get einvoiceEnvTitle => 'Envoyer vers quelle plateforme ?';

  @override
  String get einvoiceEnvProd => 'Production';

  @override
  String get einvoiceEnvUat => 'UAT (plateforme de test)';

  @override
  String get einvoiceEnvDev => 'Dev (plateforme de test)';

  @override
  String get einvoiceEnvProdHint => 'La transmission réelle.';

  @override
  String get einvoiceEnvTestHint =>
      'Une répétition — journalisée comme envoi de test.';

  @override
  String invoiceSendAcceptedTest(String env) {
    return 'Envoi de test accepté ($env).';
  }

  @override
  String get einvoiceTestEnvsTitle => 'Environnements de test (UAT / Dev)';

  @override
  String get einvoiceTestEnvsHelp =>
      'Points d\'accès et jetons distincts pour les répétitions. Le choix apparaît à l\'envoi uniquement quand le mode développeur est actif.';

  @override
  String get einvoiceUatEndpoint => 'URL d’envoi UAT';

  @override
  String get einvoiceUatToken => 'Jeton ou identifiant UAT';

  @override
  String get einvoiceDevEndpoint => 'URL d’envoi Dev';

  @override
  String get einvoiceDevToken => 'Jeton ou identifiant Dev';

  @override
  String get invoiceSentTestChip => 'test';

  @override
  String get eventTypeMemberJoin => 'Nouveau membre';

  @override
  String get memberStatusPending => 'En attente';

  @override
  String get pendingApprovalTitle => 'En attente d\'approbation';

  @override
  String pendingApprovalBody(String workspace) {
    return 'Vous avez rejoint $workspace. Un administrateur doit approuver votre adhésion avant que vous puissiez utiliser l\'espace — vous aurez accès dès sa confirmation.';
  }

  @override
  String get pendingApprovalRefresh => 'Vérifier à nouveau';

  @override
  String get memberApprove => 'Approuver l\'adhésion';

  @override
  String get memberRejectJoin => 'Refuser l\'adhésion';

  @override
  String get workspaceConfigInvitations => 'Invitations';

  @override
  String get workspaceConfigInvitationCustom =>
      'Message d\'invitation personnalisé configuré';

  @override
  String get workspaceConfigInvitationDefault =>
      'Message d\'invitation intégré (toutes les langues)';

  @override
  String get workspaceConfigInvitationSingleUse =>
      'Les codes d\'invitation personnels sont à usage unique et expirent après 14 jours ; les nouveaux membres doivent être approuvés par un admin';

  @override
  String get memberKioskLabel => 'Borne';

  @override
  String get memberMakeKiosk => 'Transformer en borne';

  @override
  String get memberUnmakeKiosk => 'Rétablir comme membre';

  @override
  String get memberBadgesTooltip => 'Badges';

  @override
  String memberBadgesTitle(String name) {
    return 'Badges — $name';
  }

  @override
  String get badgeIssue => 'Nouveau badge';

  @override
  String get badgeTokenOnce =>
      'Enregistrez ce QR maintenant — il n\'est affiché qu\'une seule fois.';

  @override
  String get badgeNone => 'Aucun badge pour l\'instant.';

  @override
  String get badgeDefaultLabel => 'Badge';

  @override
  String get badgeRevoke => 'Révoquer';

  @override
  String get badgeRevoked => 'Révoqué';

  @override
  String get commonClose => 'Fermer';

  @override
  String get kioskCheckIn => 'Arrivée';

  @override
  String get kioskReserve => 'Réserver';

  @override
  String get kioskCheckOut => 'Départ';

  @override
  String get kioskPresentBadge => 'Présentez votre badge';

  @override
  String get kioskBadgeHint =>
      'Scannez le QR de votre badge, ou saisissez son code.';

  @override
  String get kioskBadgeFieldLabel => 'Code du badge';

  @override
  String get kioskBadgeConfirm => 'Confirmer';

  @override
  String get kioskBadgeRejected => 'Badge non reconnu.';

  @override
  String get kioskDone => 'C\'est fait — tout est en ordre.';

  @override
  String get kioskTapHint => 'Touchez une place pour pointer';

  @override
  String get badgeSavePdf => 'Enregistrer en PDF';

  @override
  String get badgeRegisterCard => 'Enregistrer une carte';

  @override
  String get badgeTapCardTitle => 'Enregistrer une carte';

  @override
  String get badgeTapCardHint =>
      'Approchez la carte RFID/NFC de l\'arrière de l\'appareil.';

  @override
  String get badgeCardRegistered => 'Carte enregistrée.';

  @override
  String get badgeCardAlreadyRegistered => 'Cette carte est déjà enregistrée.';

  @override
  String get kioskBadgeHintNfc =>
      'Approchez votre carte, scannez votre QR, ou saisissez le code.';

  @override
  String get nfcConfigTitle => 'Badges RFID / NFC';

  @override
  String get nfcConfigIntro =>
      'Les membres pointent à une borne murale en approchant une carte RFID/NFC. Enregistrez la carte de chaque membre dans Membres & forfaits ; à la borne, ils approchent la carte pour réserver ou pointer.';

  @override
  String get nfcConfigEnable => 'Activer le pointage par badge NFC';

  @override
  String get nfcConfigEnableDesc =>
      'Afficher l\'option « approcher la carte » sur les bornes et dans le gestionnaire de badges.';

  @override
  String get nfcConfigDeviceStatus => 'Cet appareil';

  @override
  String get nfcConfigChecking => 'Vérification…';

  @override
  String get nfcConfigDeviceReady => 'NFC disponible et activé';

  @override
  String get nfcConfigDeviceUnavailable =>
      'Pas de NFC ici — un appareil Android avec NFC activé est nécessaire (les iPad n\'ont pas de NFC). Les badges QR fonctionnent toujours.';

  @override
  String get kioskConfirmAction => 'Confirmer';

  @override
  String get kioskRejectAction => 'Rejeter';

  @override
  String get kioskGateTitle => 'Démarrer le mode borne ?';

  @override
  String get kioskGateBody =>
      'Ce compte est configuré comme borne de l\'espace. En mode borne, la tablette n\'affiche que le plan pour le pointage par badge — rien d\'autre ne peut être ouvert. Pour quitter le mode borne, redémarrez la tablette.';

  @override
  String get kioskGateStart => 'Démarrer le mode borne';

  @override
  String get kioskGateReject => 'Pas maintenant — ouvrir l\'appli normalement';

  @override
  String get settingsFrontCamera => 'Scanner avec la caméra avant';

  @override
  String get settingsFrontCameraDesc =>
      'Les badges sont lus avec la caméra côté écran — désactivez pour utiliser la caméra arrière.';

  @override
  String get kioskNfcOff =>
      'Le NFC est désactivé dans les paramètres Android de cette tablette — activez-le pour lire les cartes RFID.';

  @override
  String get kioskNfcUnsupported =>
      'Cette tablette n\'a pas de lecteur NFC — scannez le badge QR à la place.';

  @override
  String get kioskNfcFailed =>
      'Le lecteur RFID n\'a pas démarré — redémarrez l\'application et réessayez.';

  @override
  String get nfcConfigDeviceOff =>
      'Le NFC est désactivé dans les paramètres Android de cet appareil — activez-le pour lire les cartes RFID.';

  @override
  String get kioskScanQr => 'Scanner le badge QR';

  @override
  String get kioskRevertTitle => 'Appareil borne';

  @override
  String get kioskRevertDesc =>
      'Ce profil est configuré comme borne de l\'espace. Rétablissez-le comme membre pour que la question borne ne s\'affiche plus au démarrage.';

  @override
  String get kioskRevertDone => 'Ce profil est de nouveau un membre normal.';

  @override
  String get memberNoActions =>
      'Seul le propriétaire de l\'espace peut modifier ce membre.';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageSystemDefault => 'Par défaut du système';

  @override
  String get levelReserveButton => 'Réserver le niveau';

  @override
  String get levelReserveTitle => 'Réserver le niveau entier';

  @override
  String get levelPermissionTile => 'Réservations de niveau';

  @override
  String get levelPermissionAllowed =>
      'Peut réserver une table, un bureau ou un niveau entier';

  @override
  String get levelPermissionDenied =>
      'Ne peut pas réserver une table, un bureau ou un niveau entier';

  @override
  String get levelBookableToggle => 'Réservable en entier';

  @override
  String get levelBookableDesc =>
      'L\'étage entier peut être réservé en une seule réservation.';

  @override
  String get levelPriceLabel => 'Prix par demi-journée';

  @override
  String get levelAssignMember => 'Pour le membre';

  @override
  String get levelAssignMyself => 'Moi-même';

  @override
  String get levelSupplementLabel => 'Réservations de niveau';

  @override
  String get levelNotAllowed =>
      'Vous n\'êtes pas autorisé à réserver une table, un bureau ou un niveau entier.';

  @override
  String get levelConflict => 'Le niveau a des réservations sur cette période.';

  @override
  String get bookingOnePlace =>
      'Vous avez déjà une réservation sur cette période — une place à la fois.';

  @override
  String get bookingCheckedInElsewhere =>
      'Vous êtes pointé ailleurs — partez d\'abord là-bas.';

  @override
  String get spaceNotWholeBookable =>
      'Cet espace n\'est pas configuré pour la réservation entière — le propriétaire active « Réservable en entier » dessus dans l\'éditeur.';

  @override
  String get levelFeatureOff =>
      'Les réservations de bureau et de niveau sont désactivées dans les fonctionnalités.';

  @override
  String get levelDetail => 'Niveau entier';

  @override
  String get kioskLevelButton => 'Ce niveau';

  @override
  String get officeSupplementLabel => 'Réservations de bureau';

  @override
  String get eventTypeSpaceReservation => 'Réservations d\'espaces entiers';

  @override
  String get deskDetail => 'Table entière';

  @override
  String get deskSupplementLabel => 'Réservations de table';

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
  String get membersInvite => 'Inviter un membre';

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
  String get paymentMethodWero => 'Wero';

  @override
  String get paymentMethodLydia => 'Lydia';

  @override
  String get paymentMethodWise => 'Wise';

  @override
  String get moneyPaymentDateLabel => 'Date du paiement';

  @override
  String get moneyPaymentPeriodLabel => 'S’applique à';

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
  String get planCheckInNotYetError =>
      'L\'arrivée ouvre 15 minutes avant le début.';

  @override
  String get planCheckInOverError =>
      'Cette réservation est terminée — s\'installer n\'est plus possible.';

  @override
  String planCheckInOpensAt(String time) {
    return 'L\'arrivée ouvre à $time';
  }

  @override
  String planCheckInFor(String name) {
    return 'Installer $name';
  }

  @override
  String get planOverruleRemove => 'Retirer la réservation (outrepasser)';

  @override
  String planOverruleHint(String name) {
    return '$name et tous les admins seront notifiés.';
  }

  @override
  String planOverruleDone(String name) {
    return 'Réservation retirée — $name a été notifié.';
  }

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
  String get planLevelTooltip => 'Étage';

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
  String get planMakeNotReservable => 'Rendre non réservable';

  @override
  String get planMakeReservable => 'Rendre réservable';

  @override
  String get planAccessorySupplementHint =>
      'Les suppléments s\'appliquent par demi-journée.';

  @override
  String get planFromLabel => 'De';

  @override
  String get planToLabel => 'À';

  @override
  String get planEndBeforeStart => 'La fin doit être après le début.';

  @override
  String get planClosedDay => 'Fermé ce jour-là';

  @override
  String get planClosedDayError => 'L\'espace est fermé ce jour-là.';

  @override
  String get planMorningChip => 'Matin';

  @override
  String get planAfternoonChip => 'Après-midi';

  @override
  String get planFullDayChip => 'Journée';

  @override
  String get planHalfDayError =>
      'Ici, les réservations se font par demi-journée.';

  @override
  String get a11ySeatFree => 'libre';

  @override
  String get a11ySeatReserved => 'réservé';

  @override
  String get a11ySeatOccupied => 'occupé';

  @override
  String get a11ySeatMine => 'votre place';

  @override
  String get a11ySeatBlocked => 'indisponible';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get whatsappNotShared => 'Non partagé';

  @override
  String get whatsappFieldLabel => 'Numéro WhatsApp';

  @override
  String get whatsappHint => '+33 6 12 34 56 78';

  @override
  String get whatsappHelper =>
      'Facultatif. Visible par les membres de vos espaces pour vous joindre sur WhatsApp. Laissez vide pour ne plus le partager.';

  @override
  String get whatsappSaved => 'Numéro WhatsApp enregistré';

  @override
  String get whatsappSaveFailed =>
      'Impossible d\'enregistrer le numéro WhatsApp';

  @override
  String get profileStatusTitle => 'Statut';

  @override
  String get profileStatusNone => 'Aucun statut';

  @override
  String get profileStatusFieldLabel => 'Statut';

  @override
  String get profileStatusHint => 'En appel · de retour à 14h00';

  @override
  String get profileStatusHelper =>
      'Facultatif. Visible par les membres de vos espaces dans l\'annuaire des membres. Laissez vide pour l\'effacer.';

  @override
  String get profileStatusSaved => 'Statut enregistré';

  @override
  String get profileStatusSaveFailed => 'Impossible d\'enregistrer le statut';

  @override
  String get profilePhotoTitle => 'Photo';

  @override
  String get profilePhotoSet => 'Toucher pour changer';

  @override
  String get profilePhotoNone => 'Toucher pour ajouter une photo';

  @override
  String get profilePhotoChoose => 'Choisir une photo';

  @override
  String get profilePhotoRemove => 'Supprimer la photo';

  @override
  String get profilePhotoSaved => 'Photo mise à jour';

  @override
  String get profilePhotoRemoved => 'Photo supprimée';

  @override
  String get profilePhotoSaveFailed => 'Impossible de mettre à jour la photo';

  @override
  String get profilePhotoFileType => 'Image';

  @override
  String get profilesDefault => 'Profil par défaut au démarrage';

  @override
  String get profilesMakeDefault => 'Utiliser par défaut au démarrage';

  @override
  String get eventTypeRoleChange => 'Changement de rôle';

  @override
  String eventRolePromote(String actor) {
    return '$actor promeut un membre en admin';
  }

  @override
  String eventRoleDemote(String actor) {
    return '$actor rétrograde un admin en membre';
  }

  @override
  String get memberMakeAdmin => 'Nommer admin';

  @override
  String get memberMakeMember => 'Rendre membre simple';

  @override
  String get memberRoleChangeRequested =>
      'Changement de rôle envoyé pour validation.';

  @override
  String get eventTypeQuota => 'Demi-journées supplémentaires';

  @override
  String eventQuotaRequested(String actor, int halfDays, String period) {
    return '$actor demande $halfDays demi-journées supplémentaires pour $period';
  }

  @override
  String get quotaExceededError =>
      'Quota mensuel de demi-journées atteint — demandez des demi-journées supplémentaires depuis l\'onglet Finances.';

  @override
  String get quotaRequestButton => 'Demander des demi-journées';

  @override
  String get quotaRequestTitle => 'Demander des demi-journées supplémentaires';

  @override
  String quotaRequestExplainer(String period) {
    return 'Vos réservations sont plafonnées par votre abonnement. Les demi-journées supplémentaires pour $period s\'appliquent une fois validées.';
  }

  @override
  String get quotaRequestCountLabel => 'Nombre de demi-journées';

  @override
  String get quotaRequestPending =>
      'Demande envoyée — en attente de validation.';

  @override
  String get memberReservationLimitTooltip => 'Limite de réservations';

  @override
  String get memberReservationLimitLabel => 'Limite de réservations';

  @override
  String get memberReservationLimitExplainer =>
      'Combien de réservations ouvertes ce membre peut détenir en même temps.';

  @override
  String get memberReservationLimitNone => 'Sans limite';

  @override
  String get memberReservationLimitCustom => 'Personnalisé (1–100)';

  @override
  String memberReservationLimitChip(int n) {
    return 'max $n';
  }

  @override
  String get reservationLimitError =>
      'Limite de réservations atteinte — vous détenez déjà le maximum de réservations ouvertes.';

  @override
  String get memberPause => 'Mettre l\'adhésion en pause';

  @override
  String get memberReactivate => 'Réactiver l\'adhésion';

  @override
  String get reserveMonthView => 'Mois';

  @override
  String monthFreeCount(int free, int total) {
    return '$free/$total';
  }

  @override
  String get reservationRecurring => 'Réservation récurrente';

  @override
  String get reservationEditTimes => 'Modifier l\'horaire';

  @override
  String get reservationUpdatedSnack => 'Réservation mise à jour.';

  @override
  String get reservationCancelledSnack => 'Réservation annulée.';

  @override
  String get reserveDayView => 'Jour';

  @override
  String get reserveWeekView => 'Semaine';

  @override
  String get reserveFullDayChip => 'Journée entière';

  @override
  String get reservePickDateTooltip => 'Choisir une date';

  @override
  String get reserveBookingFailed =>
      'Réservation impossible — la place vient peut-être d\'être prise.';

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
  String get authContinueWith => 'ou continuer avec';

  @override
  String authSocialUnavailable(String provider) {
    return 'La connexion $provider n\'est pas encore disponible — le serveur ne l\'a pas activée.';
  }

  @override
  String get linkedAccountsTitle => 'Comptes liés';

  @override
  String get linkedAccountsIntro =>
      'Connectez-vous à ce compte avec n\'importe lequel d\'entre eux. Ajoutez Google, Microsoft, Apple ou Facebook pour vous connecter sans mot de passe.';

  @override
  String get linkedAccountsLink => 'Lier';

  @override
  String get linkedAccountsUnlink => 'Délier';

  @override
  String get linkedAccountsLinked => 'Lié';

  @override
  String get linkedAccountsLinkStarted =>
      'Continuez dans le navigateur pour terminer la liaison.';

  @override
  String get spaceScanTitle => 'Scanner un code d\'espace';

  @override
  String get spaceScanHint =>
      'Visez la carte d\'un poste, d\'une table, d\'un bureau ou d\'un niveau — ou saisissez son code.';

  @override
  String get spaceScanField => 'Code';

  @override
  String get spaceScanInvalid =>
      'Ce n\'est pas un code d\'espace de cet espace de travail.';

  @override
  String get spaceScanUnknown =>
      'Ce code ne correspond plus à aucun espace ici.';

  @override
  String get spaceSeatTaken => 'Occupée';

  @override
  String get spaceNotBookable =>
      'Cet espace n\'est pas configuré pour les réservations entières.';

  @override
  String get spaceCodesTitle => 'Codes QR des espaces (PDF)';

  @override
  String get spaceCodesDesc =>
      'Une carte QR imprimable par poste, table, bureau et niveau — les membres la scannent pour réserver ou pointer.';

  @override
  String get spaceKindDesk => 'Table';

  @override
  String get spaceKindOffice => 'Bureau';

  @override
  String get spaceKindLevel => 'Niveau';

  @override
  String get spaceKindSeat => 'Poste';

  @override
  String get spaceYoursNow => 'Réservé par vous pour ce créneau.';

  @override
  String get themeTitle => 'Thème';

  @override
  String get themeSystem => 'Par défaut du système';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

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
  String get vatTitle => 'TVA';

  @override
  String get vatIntro =>
      'Dans DesKilo les prix sont TTC. Ajouter des taux ne change rien à ce que les membres paient : la taxe est extraite du prix déjà facturé et affichée sur la facture.';

  @override
  String get vatRegimeHint =>
      'Cet espace n\'est pas déclaré assujetti à la TVA : les factures n\'en affichent aucune. Cela se change dans Identité légale.';

  @override
  String get vatEmpty => 'Aucun taux — les factures n\'affichent pas de TVA.';

  @override
  String get vatSeed => 'Utiliser les taux usuels';

  @override
  String get vatAddRate => 'Ajouter un taux';

  @override
  String get vatRateLabelField => 'Nom';

  @override
  String get vatRatePercentField => 'Taux %';

  @override
  String get vatRateDefaultTooltip =>
      'Taux par défaut — utilisé par les abonnements et par tout ce qui n\'a pas son propre taux';

  @override
  String get vatRateRemoveTooltip => 'Supprimer';

  @override
  String get vatSaved => 'Taux de TVA enregistrés.';

  @override
  String get vatNeedsDefault =>
      'Marquez exactement un taux comme taux par défaut.';

  @override
  String get vatRateIncomplete =>
      'Chaque taux demande un nom et un pourcentage entre 0 et 99,99.';

  @override
  String get vatRatesTile => 'Taux de TVA';

  @override
  String get vatAccountField => 'Compte de TVA';

  @override
  String get vatAccountHint =>
      'Compte où l\'export comptable enregistre la TVA collectée. Vide = 445710.';

  @override
  String get vatServiceRate => 'Taux de TVA';

  @override
  String get vatServiceRateDefault => 'Taux par défaut de l\'espace';

  @override
  String get vatPdfNet => 'Total HT';

  @override
  String get vatPdfVat => 'TVA';

  @override
  String get fecAccountVat => 'TVA collectée';

  @override
  String get vatKeptRate =>
      'Un taux encore utilisé par une facture ou un service est conservé, désactivé.';

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
  String get inviteRoleMember => 'Invitation membre';

  @override
  String get inviteRoleAdmin => 'Invitation admin';

  @override
  String get inviteAdminExplainer =>
      'Ce code est à usage unique : il admet UNE personne comme admin, puis expire. Ne le remettez qu\'à la personne à qui il est destiné.';

  @override
  String get inviteAdminNewCode => 'Nouveau code admin';

  @override
  String get inviteOwnerNote =>
      'Il n\'existe pas d\'invitation propriétaire — seul un propriétaire peut accorder la propriété, dans Membres & forfaits.';

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

  @override
  String get paymentInstructionsWeroLabel => 'Numéro de téléphone Wero';

  @override
  String get paymentInstructionsLydiaLabel =>
      'Numéro de téléphone ou identifiant Lydia';

  @override
  String get paymentInstructionsWiseLabel => 'Wisetag ou lien de paiement Wise';

  @override
  String get paymentInstructionsValueCopied => 'Copié dans le presse-papiers.';

  @override
  String get workspaceWhatsappGroupTitle => 'Groupe WhatsApp';

  @override
  String get workspaceWhatsappGroupHelper =>
      'Affiché aux membres pour qu\'ils puissent rejoindre le groupe WhatsApp de la communauté. Collez le lien d\'invitation du groupe (https://chat.whatsapp.com/…). Laisser vide pour ne rien afficher.';

  @override
  String get workspaceWhatsappGroupLabel => 'Lien du groupe WhatsApp';

  @override
  String get workspaceWhatsappGroupInvalid =>
      'Doit être un lien d\'invitation chat.whatsapp.com';

  @override
  String get memberStatusActive => 'Actif';

  @override
  String get workspaceConfigPdfExport => 'Exporter la configuration (PDF)';

  @override
  String get workspaceConfigPdfExportSubtitle =>
      'Instantané complet : réglages, tous les membres et le plan.';

  @override
  String get workspaceConfigPdfTitle => 'Configuration de l\'espace';

  @override
  String workspaceConfigPdfGeneratedOn(String date) {
    return 'Généré le $date';
  }

  @override
  String get workspaceConfigOverview => 'Aperçu';

  @override
  String get workspaceConfigMembersSection => 'Membres';

  @override
  String get workspaceConfigFeatures => 'Fonctionnalités activées';

  @override
  String get workspaceConfigAvailability => 'Disponibilité';

  @override
  String get workspaceConfigFloorPlan => 'Plan';

  @override
  String get workspaceConfigGranularity => 'Granularité de réservation';

  @override
  String get workspaceConfigColName => 'Nom';

  @override
  String get workspaceConfigColRole => 'Rôle';

  @override
  String get workspaceConfigColStatus => 'Statut';

  @override
  String get workspaceConfigOpenDays => 'Jours d\'ouverture';

  @override
  String get workspaceConfigClosures => 'Fermetures';

  @override
  String get workspaceConfigBookableWhole => 'réservable en entier';

  @override
  String get workspaceConfigSeats => 'Places';

  @override
  String get workspaceConfigEmptyLevel => 'Aucune salle';

  @override
  String get workspaceConfigNone => 'Aucun';

  @override
  String get workspaceDeskTransparencyTitle => 'Transparence des tables';

  @override
  String get workspaceDeskTransparencyHelper =>
      'Réduisez l\'opacité des tables pour laisser transparaître la photo de fond de l\'étage.';

  @override
  String workspaceDeskOpacityValue(int percent) {
    return 'Opacité : $percent %';
  }

  @override
  String get workspaceDangerZone => 'Zone de danger';

  @override
  String get workspaceResetTitle => 'Réinitialiser l\'espace';

  @override
  String get workspaceResetSubtitle =>
      'Supprime toutes les réservations, la comptabilité et le plan. Conserve les réglages et les membres.';

  @override
  String get workspaceResetDialogTitle => 'Réinitialiser cet espace ?';

  @override
  String get workspaceResetWarning =>
      'Cela supprime définitivement toutes les réservations, toute la comptabilité et le grand livre, le fil d\'activité, ainsi que l\'intégralité du plan — étages, salles, tables, places et images. Les réglages de l\'espace, les paliers tarifaires, les disponibilités, les fonctionnalités, les catalogues et les membres sont conservés. Action irréversible.';

  @override
  String get workspaceResetConfirmPhrase => 'J\'accepte';

  @override
  String workspaceResetConfirmLabel(String phrase) {
    return 'Saisissez « $phrase » pour confirmer';
  }

  @override
  String get workspaceResetConfirmButton => 'Réinitialiser l\'espace';

  @override
  String get workspaceResetDone => 'Espace réinitialisé.';

  @override
  String get workspaceExcelExport => 'Exporter les données (Excel)';

  @override
  String get workspaceExcelExportSubtitle =>
      'Toutes les données dans un classeur : réservations, paiements, factures, membres et plan — un onglet chacun.';

  @override
  String get workspaceXmlExport => 'Exporter l\'espace (XML)';

  @override
  String get workspaceXmlExportSubtitle =>
      'Paramètres et plan des locaux dans un fichier partageable. Sans membres, réservations ni données financières.';

  @override
  String get workspaceXmlImport => 'Importer l\'espace (XML)';

  @override
  String get workspaceXmlImportSubtitle =>
      'Restaurer les paramètres et le plan des locaux depuis un fichier exporté. Remplace le plan actuel.';

  @override
  String get workspaceXmlFileTypeLabel => 'XML';

  @override
  String get workspaceXmlImportPreviewTitle => 'Remplacer le plan des locaux ?';

  @override
  String workspaceXmlImportPreviewCounts(
    int levels,
    int offices,
    int desks,
    int seats,
  ) {
    return 'Étages : $levels · Salles : $offices · Bureaux : $desks · Places : $seats';
  }

  @override
  String workspaceXmlImportPreviewAccessories(int count) {
    return 'Accessoires : $count';
  }

  @override
  String get workspaceXmlImportPreviewWarning =>
      'Le plan actuel sera supprimé et remplacé, et les paramètres de l\'espace seront écrasés. Cette action est irréversible.';

  @override
  String get workspaceXmlImportConfirm => 'Remplacer et importer';

  @override
  String get workspaceXmlImportSuccess => 'Espace importé.';

  @override
  String get workspaceXmlErrorMalformed =>
      'Le fichier n\'est pas un XML lisible.';

  @override
  String get workspaceXmlErrorWrongRoot =>
      'Ce n\'est pas un fichier d\'espace DesKilo.';

  @override
  String get workspaceXmlErrorUnsupportedVersion =>
      'Le fichier a été exporté par une version plus récente de DesKilo et ne peut pas être importé.';

  @override
  String get workspaceXmlErrorMissingElement =>
      'Le fichier est incomplet — une section requise est manquante.';

  @override
  String get workspaceXmlErrorMissingAttribute =>
      'Le fichier est incomplet — une valeur requise est manquante.';

  @override
  String get workspaceXmlErrorInvalidValue =>
      'Le fichier contient une valeur invalide et ne peut pas être importé.';

  @override
  String get workspaceXmlErrorInvalidPlan =>
      'Le plan des locaux du fichier est invalide : des salles, bureaux ou places se chevauchent ou dépassent de leur zone.';

  @override
  String get workspaceXmlImportReservationsError =>
      'Cet espace a déjà des réservations, son plan des locaux ne peut donc pas être remplacé. L\'import n\'est possible qu\'avant la première réservation.';
}
