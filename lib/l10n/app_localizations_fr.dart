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
      'Demi-journées : les réservations couvrent le matin, l\'après-midi ou la journée entière — les créneaux suivent les horaires de travail configurés.';

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
  String get availabilityGranularityHours =>
      'Heures réelles (de–à exact, demi/journées en raccourcis)';

  @override
  String get availabilityWorkHoursTitle => 'Horaires de travail';

  @override
  String get availabilityWorkHoursDescription =>
      'Les créneaux demi-journée et journée complète partout — réservations, check-in et facturation — suivent ces horaires.';

  @override
  String get availabilityWorkStart => 'Début de journée';

  @override
  String get availabilityHalfBoundary => 'Limite de demi-journée';

  @override
  String get availabilityWorkEnd => 'Fin de journée';

  @override
  String get availabilityHalfDayHours => 'Heures facturées comme demi-journée';

  @override
  String get availabilityFullDayHours =>
      'Heures facturées comme journée complète';

  @override
  String availabilityHourOption(int count) {
    return '$count h';
  }

  @override
  String get availabilityWorkHoursInvalid =>
      'La journée doit respecter début < limite de demi-journée < fin.';

  @override
  String get availabilityPoliciesTitle => 'Règles de réservation';

  @override
  String get policyAllowPastTitle => 'Autoriser les réservations passées';

  @override
  String get policyAllowPastDesc =>
      'Les membres peuvent enregistrer une réservation déjà terminée (rattrapage).';

  @override
  String get policyAdminCheckoutTitle =>
      'Les admins peuvent faire le check-out des membres';

  @override
  String get policyAdminCheckoutDesc =>
      'Un admin peut terminer le check-in en cours d\'un membre.';

  @override
  String get policyOutsideHoursTitle => 'En dehors des heures d\'ouverture';

  @override
  String get policyOutsideHoursDesc =>
      'Ce qui est possible en dehors de la journée de travail — une seule réponse, pour toutes les granularités. Une réservation qui touche les heures d\'ouverture reste une réservation normale.';

  @override
  String get policyOutsideHoursOff => 'Interdit';

  @override
  String get policyOutsideHoursOffDesc =>
      'Rien en dehors des heures : ni réservation à l\'avance, ni check-in spontané, et une réservation qui dépasse la fin de journée est refusée aussi.';

  @override
  String get policyOutsideHoursWalkUp => 'Spontané uniquement';

  @override
  String get policyOutsideHoursWalkUpDesc =>
      'Les check-ins spontanés restent possibles, heures supplémentaires du soir comprises ; réserver à l\'avance en dehors des heures est refusé.';

  @override
  String get policyOutsideHoursFree => 'Gratuit';

  @override
  String get policyOutsideHoursFreeDesc =>
      'Autorisé, jamais compté ni facturé — pure information de présence.';

  @override
  String get policyOutsideHoursCharged => 'Facturé';

  @override
  String get policyOutsideHoursChargedDesc =>
      'Autorisé et compté comme un usage normal — sauf les jours où le membre a déjà une réservation normale.';

  @override
  String get policySimultaneousTitle => 'Réservations simultanées par membre';

  @override
  String get policySimultaneousDesc =>
      'Combien de réservations qui se chevauchent un membre peut détenir. 1 garde une seule place à la fois.';

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
  String billInvoiceCard(String number) {
    return 'Facture $number';
  }

  @override
  String billCreditNoteCard(String number) {
    return 'Avoir $number';
  }

  @override
  String get billInvoiceTotal => 'Total de la facture';

  @override
  String get billInvoicePaid => 'Déjà réglé';

  @override
  String get billInvoiceRemaining => 'Restant dû';

  @override
  String get billCreditNoteDue =>
      'L\'espace vous doit ce montant — rien à payer de votre côté.';

  @override
  String get billCreditNoteRefunded => 'L\'espace vous a remboursé ce montant.';

  @override
  String get accountCardTitle => 'Votre compte';

  @override
  String get accountCredit => 'Avoir disponible';

  @override
  String get accountRefundDue => 'Remboursement dû par l\'espace';

  @override
  String get accountNet => 'Position nette';

  @override
  String accountOpenPartial(String period, String paid) {
    return '$period · $paid réglés';
  }

  @override
  String get accountImputationHint =>
      'Votre avoir peut solder les factures ouvertes — l\'espace l\'impute lors du rapprochement des paiements.';

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
  String get reservationExtendButton => 'Rester plus longtemps';

  @override
  String get reservationExtendLaterOnly =>
      'Choisissez une heure après la fin actuelle.';

  @override
  String get reservationEndEarlyButton => 'Terminer plus tôt';

  @override
  String get reservationEndEarlyAheadOnly =>
      'Choisissez une heure encore à venir et avant la fin actuelle.';

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
  String get settingsSectionAbout => 'À propos';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutOpenSource => 'Open source (licence 0BSD)';

  @override
  String get aboutOpenSourceDesc => 'Code source sur GitHub';

  @override
  String get aboutPrivacy => 'Politique de confidentialité';

  @override
  String get aboutReportBug => 'Signaler un bug / suggérer une fonctionnalité';

  @override
  String get aboutSupportTitle => 'Soutenir ce projet';

  @override
  String get aboutSupportBody =>
      'Cette application est gratuite, open source et sans publicité. Si vous la trouvez utile, soutenez le développeur.';

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
  String get pushStatusNotConfigured =>
      'Les notifications push ne sont pas encore configurées';

  @override
  String get pushStatusNotConfiguredHint =>
      'Le propriétaire termine la configuration Firebase (guide push-setup).';

  @override
  String get notificationsSystemOff =>
      'Android bloque les notifications de DesKilo';

  @override
  String get notificationsSystemOffHint =>
      'Autorisez-les dans Paramètres système → Applications → DesKilo → Notifications — le badge de l\'icône en a besoin.';

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
  String get editorSeatNfcLabel => 'Tag NFC/RFID';

  @override
  String get editorSeatNfcHelp =>
      'UID du tag en hexadécimal — laisser vide pour aucun tag.';

  @override
  String get editorSeatNfcRead => 'Lire un tag maintenant';

  @override
  String get editorSeatNfcReadFailed =>
      'Impossible de démarrer le lecteur de tag.';

  @override
  String get editorSeatNfcDuplicate =>
      'Ce tag est déjà associé à une autre chaise.';

  @override
  String get editorDeleteElementConfirmAudit =>
      'Supprimer cet élément ? Tout ce qui y est placé est également retiré. Les réservations qui y font référence gardent un instantané texte pour les audits ; les réservations ouvertes sont annulées.';

  @override
  String get editorDeleteLevelConfirmAudit =>
      'Supprimer ce niveau ? Tous les bureaux, tables et places qui s\'y trouvent sont retirés. Les réservations qui y font référence gardent un instantané texte pour les audits ; les réservations ouvertes sont annulées.';

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
  String get eventTypeReservationDelete => 'Suppression de réservation';

  @override
  String eventReservationDeleteLine(String actor, String date, String state) {
    return '$actor demande la suppression de la réservation du $date ($state)';
  }

  @override
  String get eventReservationDeleteCheckedIn => 'pointée';

  @override
  String get eventReservationDeleteUnused => 'jamais utilisée';

  @override
  String get eventAutoValidated => 'Validé automatiquement';

  @override
  String get reservationDeleteRequestButton => 'Demander la suppression';

  @override
  String get reservationDeleteRequestExplain =>
      'Les réservations passées ou pointées ne sont pas supprimées directement. Un propriétaire ou un admin décidera : le pointage a-t-il simplement été oublié (la réservation reste), ou n\'a-t-elle jamais été utilisée (elle est supprimée) ?';

  @override
  String get reservationDeleteReasonLabel => 'Motif (facultatif)';

  @override
  String get reservationDeleteSubmit => 'Envoyer la demande';

  @override
  String get reservationDeleteSubmitted =>
      'Suppression demandée — un propriétaire ou un admin décidera.';

  @override
  String get notifCategoryCheckIns => 'Check-ins';

  @override
  String get notifCategoryMoney => 'Finances';

  @override
  String get notifCategoryMembers => 'Membres';

  @override
  String get notesFilterRead => 'Lus';

  @override
  String get notifSortByDate => 'Trier par date';

  @override
  String get notifGroupBy => 'Grouper par';

  @override
  String get notifGroupByType => 'Type';

  @override
  String get notifGroupByDate => 'Date';

  @override
  String get notifGroupByUser => 'Membre';

  @override
  String get notifUngroup => 'Dégrouper';

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
  String get featureWorkingHours => 'Horaires de travail';

  @override
  String get featureWorkingHoursDesc =>
      'Configurer la journée de travail et proposer la réservation à l\'heure exacte ; désactivé, les valeurs par défaut 8h–17h s\'appliquent.';

  @override
  String get featureInvoicePdfTemplate => 'Modèle de PDF de facture';

  @override
  String get featureInvoicePdfTemplateDesc =>
      'Introduction et pied de page rédigés par le propriétaire sur le PDF de facture. Ne touche jamais au XML de facture électronique.';

  @override
  String get featureMemberNotifications => 'Notifications entre membres';

  @override
  String get featureMemberNotificationsDesc =>
      'Envoyer une courte notification à un autre membre ; les admins peuvent notifier tous les admins, propriétaire inclus.';

  @override
  String get featureDunning => 'Relances de paiement (Mahnwesen)';

  @override
  String get featureDunningDesc =>
      'Règles de relance paramétrables et suggestions « Relance due » sur les factures en retard. Rien n\'est jamais envoyé automatiquement.';

  @override
  String get featureMemberReports => 'Rapports des membres';

  @override
  String get featureMemberReportsDesc =>
      'L\'accord financier et le rapport mensuel des paiements — en libre-service pour les membres, envoyables par membre.';

  @override
  String get featureDeletionRequests =>
      'Demandes de suppression de réservation';

  @override
  String get featureDeletionRequestsDesc =>
      'Les membres peuvent DEMANDER la suppression d\'une réservation passée ou pointée ; un propriétaire/admin valide. Désactivé, ces réservations ne peuvent pas être supprimées.';

  @override
  String get featurePlanObjectDeleteTitle =>
      'Supprimer des espaces avec historique';

  @override
  String get featurePlanObjectDeleteDesc =>
      'Les propriétaires peuvent supprimer niveaux, bureaux, tables et places même si d\'anciennes réservations y font référence — les réservations gardent un instantané texte pour les audits et rapports.';

  @override
  String get featureNotificationGroupingTitle =>
      'Regroupement des notifications';

  @override
  String get featureNotificationGroupingDesc =>
      'Les membres peuvent regrouper le fil de notifications par type, jour ou membre ; toucher le symbole du groupe ramène à la liste plate.';

  @override
  String get featureBookingPoliciesTitle => 'Règles de réservation';

  @override
  String get featureBookingPoliciesDesc =>
      'Comportement de réservation configurable : réservations passées, réservations à la minute hors heures, check-out par un admin.';

  @override
  String get featureNfcSeatTagsTitle => 'Tags NFC/RFID des chaises';

  @override
  String get featureNfcSeatTagsDesc =>
      'Un tag NFC/RFID physique sur une chaise mène à sa place comme la carte QR imprimée ; le champ se remplit en approchant la puce.';

  @override
  String get featureQrBadgesTitle => 'Badges QR';

  @override
  String get featureQrBadgesDesc =>
      'Cartes badge QR imprimables pour le kiosque, à côté des cartes NFC/RFID.';

  @override
  String get featureFormHelpHintsTitle => 'Astuces d\'aide';

  @override
  String get featureFormHelpHintsDesc =>
      'Courtes astuces refermables sur les formulaires et écrans, chacune renvoyant à la section correspondante du guide.';

  @override
  String get featureUiAnimationsTitle => 'Animations de l\'interface';

  @override
  String get featureUiAnimationsDesc =>
      'Transitions fluides et animations d\'état dans toute l\'application. Désactivé, chaque changement est instantané ; le réglage « réduire les animations » de l\'appareil prime toujours.';

  @override
  String get featureKioskMemberPhotosTitle => 'Photos des membres à la borne';

  @override
  String get featureKioskMemberPhotosDesc =>
      'Le reçu de la borne affiche la photo de profil du membre — le contrôle visuel du mauvais badge.';

  @override
  String get featurePlanMemberPhotosTitle => 'Photos des membres sur le plan';

  @override
  String get featurePlanMemberPhotosDesc =>
      'Les places occupées de l\'onglet Plan et du hub Réserver affichent la photo de profil de l\'occupant au lieu de l\'initiale.';

  @override
  String get helpTitle => 'Aide';

  @override
  String get helpContents => 'Sommaire';

  @override
  String get helpHintLearnMore => 'En savoir plus';

  @override
  String get helpHintDismiss => 'Masquer l\'astuce';

  @override
  String get helpHintPrevTip => 'Astuce précédente';

  @override
  String get helpHintNextTip => 'Astuce suivante';

  @override
  String get helpHintRestoreTitle => 'Réafficher les astuces d\'aide';

  @override
  String get helpHintRestored =>
      'Les astuces d\'aide seront de nouveau affichées.';

  @override
  String get helpHintReserve =>
      'Choisissez un jour et un créneau, puis touchez une place libre pour la réserver.';

  @override
  String get helpHintReserveTopic => 'hub Réserver';

  @override
  String get helpHintReserveTip2 =>
      'Les vues Semaine et Mois repèrent une demi-journée libre d\'un coup d\'œil — touchez une case ou un jour libre pour réserver directement.';

  @override
  String get helpHintReserveTip3 =>
      'Touchez le bouton scan et visez la carte QR d\'un espace — la fiche montre exactement ce que vous pouvez y faire.';

  @override
  String get helpHintReserveTip3Topic => 'Scanner un code d\'espace';

  @override
  String get helpHintReserveTip4 =>
      'Les puces matin, après-midi et journée fixent votre créneau avant le choix de la place — un matin réservé compte pour une demi-journée.';

  @override
  String get helpHintReserveTip4Topic => 'Comment la réservation se comporte';

  @override
  String get helpHintReserveTip5 =>
      'Définissez votre période de réservation par défaut dans les Réglages — le hub la présélectionne à chaque visite.';

  @override
  String get helpHintReserveTip5Topic => 'Réglages et profil';

  @override
  String get helpHintPlan =>
      'Le plan en direct : touchez une place libre pour réserver, touchez votre réservation pour pointer votre arrivée.';

  @override
  String get helpHintPlanTopic => 'onglet Plan';

  @override
  String get helpHintPlanTip2 =>
      'Devant une place libre ? Touchez-la — la fiche propose de maintenant jusqu\'à la fermeture, et confirmer pointe votre arrivée sur-le-champ.';

  @override
  String get helpHintPlanTip3 =>
      'Parcourez un autre moment avec la puce de date et le curseur horaire — le plan montre qui occupe quoi à tout instant futur.';

  @override
  String get helpHintPlanTip4 =>
      'Touchez deux fois un bureau, une salle ou l\'étage — ou l\'icône calques de la barre des niveaux — pour réserver l\'espace entier d\'un coup.';

  @override
  String get helpHintPlanTip5 =>
      'Touchez votre propre place pour sa fiche : pointez votre arrivée dès 15 minutes avant le début, votre départ quand vous partez.';

  @override
  String get helpHintPlanTip5Topic => 'Comment la réservation se comporte';

  @override
  String get helpHintCalendar =>
      'Parcourez les réservations mois par mois ; touchez un jour pour voir et gérer ses réservations.';

  @override
  String get helpHintCalendarTopic => 'Calendrier';

  @override
  String get helpHintCalendarTip2 =>
      'Le bouton Moi / Tous montre vos seules réservations ou celles de toute la communauté — les points rouges sont à vous, les bleus aux autres.';

  @override
  String get helpHintCalendarTip3 =>
      'Le bouton d\'affichage bascule le bas entre la grille semaine et la liste agenda ; les puces d\'étage filtrent les deux.';

  @override
  String get helpHintCalendarTip4 =>
      'Annuler une occurrence d\'une série propose « celle-ci et les suivantes » — les occurrences pointées ou terminées gardent leur historique.';

  @override
  String get helpHintCalendarTip4Topic => 'Comment la réservation se comporte';

  @override
  String get helpHintEvents =>
      'Tout ce qui s\'est passé, dans un seul fil. Les décisions qui vous attendent sont en haut ; les filtres affinent le reste.';

  @override
  String get helpHintEventsTopic => 'Événements';

  @override
  String get helpHintEventsTip2 =>
      'Les puces de filtre retiennent votre choix d\'une visite à l\'autre — et la puce Non lus réduit la liste aux messages non lus.';

  @override
  String get helpHintEventsTip3 =>
      'Groupez le fil par type, jour ou membre depuis le menu Grouper par ; touchez le symbole de groupe pour revenir à la liste plate.';

  @override
  String get helpHintEventsTip4 =>
      'Les décisions en attente restent épinglées en haut avec Accepter et refuser — et personne ne valide jamais son propre événement.';

  @override
  String get helpHintEditor =>
      'Dessinez salles et bureaux, posez les places — touchez deux fois une place pour modifier ses propriétés.';

  @override
  String get helpHintEditorTopic => 'éditeur d\'espace';

  @override
  String get helpHintEditorTip2 =>
      'Choisissez Bureau ou Table dans la barre d\'outils et tracez sur la grille ; Sélection déplace et redimensionne l\'existant.';

  @override
  String get helpHintEditorTip3 =>
      'L\'outil Place pose les places sur les bureaux ; la fiche d\'une place règle son orientation, son type de chaise, ses accessoires et un blocage maintenance.';

  @override
  String get helpHintEditorTip4 =>
      'Donnez à une place son tag NFC/RFID depuis sa fiche — approchez la puce du téléphone et le champ se remplit tout seul.';

  @override
  String get helpHintEditorTip5 =>
      'Imprimez une carte QR pour chaque place, bureau, salle et étage — choisissez la taille de la carte et ce qu\'elle affiche avant l\'export.';

  @override
  String get helpHintEditorTip5Topic => 'Codes QR des espaces';

  @override
  String get helpHintAvailability =>
      'Définissez les jours d\'ouverture et les horaires, et ajoutez des jours de fermeture que personne ne peut réserver.';

  @override
  String get helpHintAvailabilityTopic => 'Disponibilité';

  @override
  String get helpHintAvailabilityTip2 =>
      'La granularité de réservation décide de la forme d\'un créneau : demi-journées, journées entières, grilles à la minute ou horaires libres.';

  @override
  String get helpHintAvailabilityTip3 =>
      'Début de journée, limite de demi-journée et fin de journée pilotent chaque créneau — réservation, pointage et facturation les suivent.';

  @override
  String get helpHintAvailabilityTip4 =>
      'Trois politiques de réservation resserrent ou assouplissent les règles : réservations passées, minutes confinées aux horaires, départ par un admin.';

  @override
  String get helpHintFeatures =>
      'Activez ou désactivez les fonctionnalités de l\'espace — l\'application de chaque membre suit immédiatement.';

  @override
  String get helpHintFeaturesTopic => 'Fonctionnalités';

  @override
  String get helpHintFeaturesTip2 =>
      'La liste est hiérarchique — une fonctionnalité qui en requiert une autre s\'indente dessous et se grise tant que son parent est désactivé.';

  @override
  String get helpHintFeaturesTip3 =>
      'Désactiver un parent retire toute sa branche de l\'application ; les choix mémorisés des enfants reviennent intacts avec le parent.';

  @override
  String get helpHintFeaturesTip4 =>
      'L\'entrée de réglages d\'une fonctionnalité n\'apparaît que si elle est activée — l\'écran Fonctionnalités, lui, reste toujours accessible.';

  @override
  String get helpHintMembers =>
      'Invitez des membres, réglez leur forfait et leur rôle, et gérez leurs badges.';

  @override
  String get helpHintMembersTopic => 'Membres et forfaits';

  @override
  String get helpHintMembersTip2 =>
      'Touchez un membre pour sa fiche de gestion — abonnement, limite de réservations, badges, services et plus, au même endroit.';

  @override
  String get helpHintMembersTip3 =>
      'Les badges sont par membre : émettez un badge QR imprimable, ou enregistrez sa carte NFC en l\'approchant de l\'appareil.';

  @override
  String get helpHintMembersTip3Topic => 'badges RFID';

  @override
  String get helpHintMembersTip4 =>
      'Nommer admin accorde les droits après validation ; la matrice des rôles sous Gestion des rôles décide de ce que chaque rôle peut faire.';

  @override
  String get helpHintMembersTip4Topic => 'Gestion des rôles';

  @override
  String get helpHintMoney =>
      'Votre relevé mensuel : parcourez les mois avec les flèches ; payez, exportez ou partagez d\'ici.';

  @override
  String get helpHintMoneyTopic => 'Argent';

  @override
  String get helpHintMoneyTip2 =>
      'Chaque document offre les trois mêmes actions : aperçu rapide à l\'écran, téléchargement en PDF et partage vers n\'importe quelle app.';

  @override
  String get helpHintMoneyTip2Topic => 'Aperçu rapide, enregistrer, partager';

  @override
  String get helpHintMoneyTip3 =>
      'Enregistrez un paiement avec la date du mouvement et le mois qu\'il solde — l\'autre partie confirme.';

  @override
  String get helpHintMoneyTip4 =>
      'Dès que le mois est facturé, c\'est la facture qui décide : le mois se lit soldé dès que sa facture est payée.';

  @override
  String get helpHintMoneyTip4Topic => 'la facture qui décide';

  @override
  String get helpHintValidation =>
      'Décidez quelles actions demandent confirmation, qui confirme et combien d\'approbations il faut.';

  @override
  String get helpHintValidationTopic => 'confirmations';

  @override
  String get helpHintValidationTip2 =>
      'Une carte par type d\'événement, chacune héritant de la règle par défaut tant que vous ne l\'éditez pas — paiements, dépenses, rôles et plus.';

  @override
  String get helpHintValidationTip3 =>
      'Personne ne valide jamais son propre événement, et une demande sans réponse expire après 7 jours — rien n\'est accordé en silence.';

  @override
  String get helpHintWorkspace =>
      'Pays, devise, langue et coordonnées de facturation — documents et taxes suivent ces réglages.';

  @override
  String get helpHintWorkspaceTopic => 'Réglages de l\'espace';

  @override
  String get helpHintWorkspaceTip2 =>
      'Imprimez les cartes QR des espaces depuis les Exports — choisissez la taille et les infos portées par chaque carte, dix par page A4.';

  @override
  String get helpHintWorkspaceTip2Topic => 'Codes QR des espaces';

  @override
  String get helpHintWorkspaceTip3 =>
      'Exportez l\'espace en XML pour le sauvegarder ou en faire un modèle ; le questionnaire de configuration prépare un espace neuf de bout en bout.';

  @override
  String get helpHintWorkspaceTip4 =>
      'Réinitialiser l\'espace efface réservations, comptabilité et plan — réglages et membres survivent, et une confirmation tapée protège l\'action.';

  @override
  String get helpHintBadges =>
      'Émettez un badge QR imprimable ou enregistrez une carte NFC ; révoquez un badge perdu à tout moment.';

  @override
  String get helpHintBadgesTopic => 'badges RFID';

  @override
  String get helpHintBadgesTip2 =>
      'Enregistrez une carte en l\'approchant de l\'appareil — toute puce lisible convient, et la boîte de dialogue nomme l\'espace concerné.';

  @override
  String get helpHintBadgesTip3 =>
      'Enregistrez un badge QR en PDF pour imprimer dix exemplaires format carte bancaire sur une page A4 — avec des exemplaires de rechange.';

  @override
  String get helpHintBadgesTip4 =>
      'Révoquez un badge perdu à tout moment ; glissez un badge révoqué vers la droite pour le supprimer définitivement.';

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
  String get invoiceShowCancelled => 'Afficher les annulées';

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
  String get invoiceSendAction => 'Envoyer à la plateforme gouvernementale';

  @override
  String get invoiceSendAccepted => 'Envoyée — la plateforme l’a acceptée.';

  @override
  String get invoiceSendCustomerAction => 'Envoyer au service du client';

  @override
  String get invoiceSendCustomerAccepted =>
      'Envoyée — le service du client l’a acceptée.';

  @override
  String get einvoiceCustomerSectionTitle => 'Service de remise au client';

  @override
  String get einvoiceCustomerSectionHelp =>
      'Où partent les factures destinées au client : son point d’accès Peppol, son portail ou l’API convenue — distinct de la plateforme gouvernementale.';

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
  String get invoiceTemplateTitle => 'Modèle de PDF de facture';

  @override
  String get invoiceTemplateHint =>
      'Trois bandes de rapport rendues sur le PDF — le XML de facture électronique n\'est jamais modifié. Conditions et boucles Liquid, puis balisage de ligne :';

  @override
  String get invoiceTemplateIntroLabel =>
      'Introduction (au-dessus du bloc destinataire)';

  @override
  String get invoiceTemplateFooterLabel =>
      'Pied de page (sous les totaux — conditions de paiement, mentions légales)';

  @override
  String get invoiceTemplateSaved => 'Modèle de facture enregistré.';

  @override
  String get invoiceTemplateHeaderLabel => 'Bande d\'en-tête';

  @override
  String get invoiceTemplateBodyLabel =>
      'Bande de corps (les lignes de la facture)';

  @override
  String get invoiceTemplateReset => 'Réinitialiser au modèle par défaut';

  @override
  String get invoiceTemplatePreview => 'Aperçu';

  @override
  String get invoiceTemplateNoPreview =>
      'Émettez d\'abord une facture — l\'aperçu rend la plus récente.';

  @override
  String get reminderPdfTitleFriendly => 'Rappel de paiement';

  @override
  String get reminderPdfTitleFirm => 'Relance';

  @override
  String get reminderPdfOpeningFriendly =>
      'petit rappel amical : la facture ci-dessous est encore ouverte. Un simple oubli, sans doute — pas d\'inquiétude.';

  @override
  String get reminderPdfOpeningFirm =>
      'malgré notre relance précédente, la facture ci-dessous reste impayée. Merci de régler le montant sans délai.';

  @override
  String get reminderPdfDaysOpen => 'Ouverte depuis';

  @override
  String get reminderPdfDays => 'jours';

  @override
  String get reminderPdfLevelLabel => 'Niveau de relance';

  @override
  String get reminderPdfClosing =>
      'Si vous avez déjà payé, veuillez ne pas tenir compte de ce courrier.';

  @override
  String get dunningSettingsTitle => 'Règles de relance';

  @override
  String get dunningLevels => 'Nombre de niveaux de relance';

  @override
  String get dunningFirstAfterDays => 'Jours avant la première relance';

  @override
  String get dunningBetweenDays => 'Jours entre les relances';

  @override
  String get dunningSaved => 'Règles de relance enregistrées.';

  @override
  String dunningDueChip(int level) {
    return 'Relance $level à envoyer';
  }

  @override
  String get invoiceTemplateDocInvoice => 'Facture';

  @override
  String invoiceTemplateDocReminder(int level) {
    return 'Relance $level';
  }

  @override
  String get reportPreviewTitle =>
      'Aperçu rapide — votre facture la plus récente';

  @override
  String get reportPreviewSimulated => 'Aperçu rapide — données d\'exemple';

  @override
  String get reportPresetClassic => 'Classique';

  @override
  String get reportPresetFormalLetter => 'Lettre formelle';

  @override
  String get reportSubject => 'Objet';

  @override
  String get reportRegards => 'Cordialement';

  @override
  String get invoiceTemplatePresets => 'Modèles';

  @override
  String get invoiceTemplateQuickPreview => 'Aperçu rapide';

  @override
  String get invoiceTemplateDownload => 'Télécharger le PDF';

  @override
  String get invoiceTemplateShare => 'Partager le PDF';

  @override
  String get invoiceTemplateDocStatement => 'Relevé';

  @override
  String get reportPresetSimple => 'Simple';

  @override
  String get reportPresetVerbose => 'Détaillé';

  @override
  String get invoiceLegalSection => 'Mentions de facturation';

  @override
  String get invoiceLegalIntro =>
      'Les mentions légales imprimées sur les factures et les relances. Les clauses de paiement laissées vides utilisent les mentions légales par défaut.';

  @override
  String get invoiceLegalFormField => 'Forme juridique et capital';

  @override
  String get invoiceLegalFormHint => 'ex. SARL au capital de 7 500 €';

  @override
  String get invoiceLegalRegistrationField => 'Registre du commerce (RCS)';

  @override
  String get invoiceLegalRegistrationHint => 'ex. RCS Saint-Brieuc 680 357 910';

  @override
  String get invoiceLegalPaymentTermsField => 'Modalités de règlement';

  @override
  String get invoiceLegalLatePenaltyField => 'Pénalités de retard';

  @override
  String get invoiceLegalRecoveryField => 'Indemnité de recouvrement';

  @override
  String get invoiceLegalEscompteField => 'Escompte';

  @override
  String get invoiceLegalInsuranceField => 'Assurance professionnelle';

  @override
  String get invoiceLegalSpecialField => 'Mentions particulières';

  @override
  String get invoiceLegalPaymentTermsDefault => 'Règlement à réception.';

  @override
  String get invoiceLegalLatePenaltyDefault =>
      'Pénalités de retard : trois fois le taux d\'intérêt légal.';

  @override
  String get invoiceLegalRecoveryDefault =>
      'Indemnité forfaitaire pour frais de recouvrement : 40 €.';

  @override
  String get invoiceLegalEscompteDefault =>
      'Aucun escompte pour paiement anticipé.';

  @override
  String get reportColUnitPrice => 'Prix unit.';

  @override
  String get reportColQty => 'Qté';

  @override
  String get reportColTotal => 'Total';

  @override
  String get invoiceLegalKindField => 'Type d\'organisation';

  @override
  String get invoiceLegalKindCompany => 'Entreprise';

  @override
  String get invoiceLegalKindAssociation => 'Association (loi 1901)';

  @override
  String get invoiceLegalAssociationHint =>
      'Les clauses de pénalités, d\'indemnité de recouvrement et d\'escompte ne sont imprimées que si renseignées — elles ne sont obligatoires qu\'entre professionnels.';

  @override
  String get invoiceLegalFormHintAssociation => 'ex. Association loi 1901';

  @override
  String get invoiceLegalRegistrationHintAssociation =>
      'ex. RNA W123456789 · SIRET si attribué';

  @override
  String get invoiceLegalAssociationReasonHint =>
      'ex. « TVA non applicable, art. 293 B du CGI » — ou « Exonération de TVA, art. 261, 7-1° du CGI » pour les services rendus aux membres';

  @override
  String get reportEditorMarkup => 'Balisage';

  @override
  String get reportEditorVisual => 'Visuel';

  @override
  String get reportInsertImage => 'Insérer une image';

  @override
  String get reportImagesTitle => 'Images des rapports';

  @override
  String get reportImagesEmpty =>
      'Aucune image — téléversez votre logo, un tampon ou une signature et référencez-la avec ![nom].';

  @override
  String get reportImageUpload => 'Téléverser une image';

  @override
  String get reportVisualAddLine => 'Ajouter une ligne';

  @override
  String get reportLineTitle => 'Titre';

  @override
  String get reportLineSection => 'Section';

  @override
  String get reportLineText => 'Texte';

  @override
  String get reportLineSmall => 'Petit texte';

  @override
  String get reportLineRow => 'Ligne de tableau';

  @override
  String get reportLineBoldRow => 'Ligne en gras';

  @override
  String get reportLineDivider => 'Séparateur';

  @override
  String get reportLineSpacer => 'Espacement';

  @override
  String get reportLineImage => 'Image';

  @override
  String get reportLineColumns => 'Début/fin de colonnes';

  @override
  String get reportLineColumnsSplit => 'Saut de colonne';

  @override
  String get reportLineLogic => 'Logique';

  @override
  String get reportDocAgreement => 'Accord financier';

  @override
  String get reportDocPayments => 'Rapport des paiements';

  @override
  String get reportDocWorkspace => 'Rapport de l\'espace';

  @override
  String get agreementExtraHalfDay => 'Demi-journée supplémentaire';

  @override
  String get paymentsPendingTag => 'en attente de validation';

  @override
  String get reportSectionFeatures => 'Fonctionnalités';

  @override
  String get reportSectionPrices => 'Tarifs';

  @override
  String get moneyMyAgreement => 'Mes conditions';

  @override
  String get memberSendAgreement => 'Envoyer l\'accord financier';

  @override
  String get reportQuickView => 'Aperçu rapide';

  @override
  String get reportDocWorkspaceSubtitle =>
      'Tout sur l\'espace — via le modèle « espace » de l\'éditeur de rapports';

  @override
  String get reportTemplateLangDefault => 'Par défaut (toutes langues)';

  @override
  String get reportLanguageAmbiguous =>
      'Ce pays a plusieurs langues — définissez d\'abord la langue de l\'espace dans les Réglages de l\'espace.';

  @override
  String get reportDesignEmpty => 'Bande vide — ajoutez un élément ci-dessous.';

  @override
  String get invoiceStatusRemainderCancelled =>
      'Partiellement payée · solde annulé';

  @override
  String get invoiceRemainingLabel => 'Restant dû';

  @override
  String get invoiceWriteoffButton => 'Annuler le solde restant';

  @override
  String get invoiceWriteoffExplain =>
      'Le solde impayé de cette facture sera annulé et la facture archivée comme partiellement payée — une fois la validation confirmée. D\'ici là elle reste ouverte et due.';

  @override
  String get invoiceWriteoffRequested =>
      'Annulation demandée — en attente de validation.';

  @override
  String get eventTypeInvoiceWriteoff => 'Annulation de solde';

  @override
  String eventInvoiceWriteoffLine(String actor, String number, String amount) {
    return '$actor demande l\'annulation du solde de $number — $amount';
  }

  @override
  String get invoicePdfCreditNote => 'Avoir';

  @override
  String get invoiceStatusRefunded => 'Remboursée';

  @override
  String get invoiceRefundLabel => 'À rembourser';

  @override
  String get invoiceRefundButton => 'Enregistrer le remboursement';

  @override
  String invoiceRefundExplain(String amount) {
    return 'Cet avoir signifie que L\'ESPACE doit $amount au membre. Enregistrez le remboursement versé — le montant est imputé au solde du membre et le document se clôt comme Remboursée.';
  }

  @override
  String get invoiceRefunded => 'Remboursement enregistré.';

  @override
  String invoiceSummaryToRefund(int count, String amount) {
    return '$count à rembourser · $amount';
  }

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
  String get kioskNotCheckedIn =>
      'Aucun pointage actif trouvé — le plan vient peut-être de se mettre à jour.';

  @override
  String get kioskRestOfDay => 'Reste de la journée';

  @override
  String get kioskPeriodCheckInHint =>
      'Jusqu\'à quand restez-vous ? Le pointage commence maintenant.';

  @override
  String get kioskPeriodReserveHint =>
      'Choisissez la période — aujourd\'hui uniquement.';

  @override
  String get kioskCheckInRightAway => 'Pointer tout de suite';

  @override
  String get kioskCheckInRightAwayHint =>
      'Vous êtes sur place — la réservation démarre pointée.';

  @override
  String get kioskPresentBadgeNext => 'Présenter le badge';

  @override
  String get kioskReserveAndCheckIn => 'Réserver et pointer';

  @override
  String get badgeDeleteConfirm =>
      'Supprimer définitivement ce badge révoqué ?';

  @override
  String get kioskClosedToday =>
      'L\'espace est fermé aujourd\'hui — pointage et réservations impossibles.';

  @override
  String kioskBasis(String granularity, String hours) {
    return 'Règle : $granularity · aujourd’hui $hours';
  }

  @override
  String kioskBlockedContactHint(String name) {
    return 'Occupé par $name — vous pouvez lui écrire depuis l\'application sur votre téléphone.';
  }

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
  String get editorLevelBookableOn => 'Réservable en entier';

  @override
  String get editorLevelBookableOff => 'Non réservable en entier';

  @override
  String get bookingPastError =>
      'Cette réservation est entièrement dans le passé.';

  @override
  String get bookingWalkUpTodayError =>
      'Un check-in spontané doit commencer aujourd\'hui.';

  @override
  String get bookingOutsideHoursError =>
      'Les réservations doivent rester dans les heures d\'ouverture.';

  @override
  String get bookingOutsideOffError =>
      'Les réservations en dehors des heures d\'ouverture ne sont pas autorisées.';

  @override
  String get bookingOutsideWalkUpError =>
      'En dehors des heures d\'ouverture, seul un check-in spontané est possible — pas une réservation à l\'avance.';

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
  String get noteRefGone => 'Cette réservation n\'existe plus.';

  @override
  String get memberNoteDelete => 'Supprimer';

  @override
  String get memberNoteDeleteConfirm =>
      'Supprimer ce message ? Cette action est irréversible.';

  @override
  String get memberNoteReply => 'Répondre';

  @override
  String get noteRefReservation => 'Lier une réservation';

  @override
  String get noteRefSpace => 'Lier un espace';

  @override
  String get noteRefNoReservations => 'Aucune réservation à venir à lier.';

  @override
  String get noteRefWholeLevel => 'niveau entier';

  @override
  String get memberMessagesAction => 'Messages';

  @override
  String get conversationEmpty => 'Pas encore de messages — dites bonjour !';

  @override
  String get whatsappNotesTitle => 'Recevoir les messages sur WhatsApp';

  @override
  String get whatsappNotesSubtitle =>
      'Les messages des membres arrivent aussi sur WhatsApp.';

  @override
  String get messageLinkGone =>
      'Ce message se trouve dans votre boîte de réception.';

  @override
  String get whatsappNotesUnconfigured =>
      'Canal non configuré — les messages arrivent dans l\'app et en push seulement.';

  @override
  String get whatsappChannelTitle => 'Canal WhatsApp';

  @override
  String get whatsappChannelConfigured =>
      'Canal configuré — les messages arrivent aussi sur WhatsApp, avec leurs liens ; le lien DesKilo ouvre la conversation dans l\'app.';

  @override
  String get whatsappChannelNotConfigured =>
      'Non configuré — les messages arrivent dans l\'app et en push seulement.';

  @override
  String get whatsappChannelHelp =>
      '1. Créez une app (gratuite) sur developers.facebook.com et ajoutez le produit WhatsApp.\n2. Sous WhatsApp → Configuration de l\'API, copiez le jeton d\'accès permanent et l\'ID du numéro de téléphone.\n3. Collez les deux ci-dessous — les messages des membres partent alors de ce numéro.\nNote : WhatsApp ne livre que dans les 24 h suivant le dernier message WhatsApp du destinataire vers votre numéro (sa fenêtre de service).';

  @override
  String get whatsappChannelToken => 'Jeton d\'accès';

  @override
  String get whatsappChannelPhoneId => 'ID du numéro de téléphone';

  @override
  String get whatsappChannelKeepHint =>
      'Laissez vide pour conserver la valeur enregistrée.';

  @override
  String get whatsappChannelSaved => 'Canal WhatsApp enregistré.';

  @override
  String get notesFilterUnread => 'Non lus';

  @override
  String get notesFilterEmpty => 'Aucun message non lu — vous êtes à jour.';

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
  String get moneySectionPay => 'Payer';

  @override
  String get moneySectionRequests => 'Demandes';

  @override
  String get moneySectionDocuments => 'Documents';

  @override
  String get vatDeclTitle => 'Déclaration de TVA';

  @override
  String get vatDeclPeriod => 'Période';

  @override
  String get vatDeclSeller => 'Vendeur';

  @override
  String get vatDeclVatId => 'N° TVA';

  @override
  String get vatDeclRate => 'Taux';

  @override
  String get vatDeclNet => 'Base HT';

  @override
  String get vatDeclVat => 'TVA';

  @override
  String get vatDeclInvoices => 'Factures';

  @override
  String get vatDeclTotals => 'Totaux';

  @override
  String get vatDeclBoxes => 'Lignes du formulaire officiel (CA3)';

  @override
  String get vatDeclBox => 'Ligne';

  @override
  String get vatDeclStatus => 'Statut';

  @override
  String get vatDeclDisclaimer =>
      'Générée à partir des factures émises de la période. Vérifiez avec votre comptabilité avant de déclarer — aide à la déclaration, pas un conseil fiscal.';

  @override
  String get vatDeclGenerate => 'Générer';

  @override
  String get vatDeclEmpty =>
      'Aucune déclaration — choisissez une période et générez la première.';

  @override
  String get vatDeclDraft => 'Brouillon';

  @override
  String get vatDeclSubmitted => 'Déposée';

  @override
  String get vatDeclTransmit => 'Télétransmettre';

  @override
  String get vatDeclMarkFiled => 'Marquer comme déposée';

  @override
  String get vatDeclMarkFiledConfirm =>
      'Confirmez avoir déposé cette déclaration vous-même (portail des impôts ou votre comptable). Elle devient immuable.';

  @override
  String get vatDeclXml => 'Export XML';

  @override
  String get vatDeclPdf => 'PDF';

  @override
  String get vatDeclSent => 'Déclaration télétransmise.';

  @override
  String get vatDeclRejected => 'La plateforme a refusé la déclaration.';

  @override
  String get vatDeclRegimeGate =>
      'Les déclarations n’existent que sous le régime assujetti à la TVA — configurez-le dans les réglages TVA.';

  @override
  String get featureVatManagementTitle => 'Gestion de la TVA';

  @override
  String get featureVatManagementDesc =>
      'L\'éditeur des taux de TVA et les sélecteurs de taux des services, forfaits, accessoires et paliers. Désactivé, la configuration disparaît ; les taux enregistrés continuent de s\'appliquer.';

  @override
  String get featureVatDeclarationsTitle => 'Déclarations de TVA';

  @override
  String get featureVatDeclarationsDesc =>
      'Générer la déclaration périodique de TVA depuis les factures émises, la rapprocher du formulaire officiel et la télétransmettre ou l’exporter.';

  @override
  String get featureEinvoiceCustomerDeliveryTitle =>
      'Remise des factures au client';

  @override
  String get featureEinvoiceCustomerDeliveryDesc =>
      'Un second canal d’envoi à côté de la plateforme gouvernementale : transmettre la facture émise directement au service de facturation du client.';

  @override
  String priceVatIncluded(String rate) {
    return 'dont TVA $rate';
  }

  @override
  String billingPricesVatHint(String rate) {
    return 'Les prix sont TTC — la TVA $rate (taux par défaut de l’espace) est incluse.';
  }

  @override
  String billingTariffVatHint(String rate) {
    return 'Les prix sont TTC — la TVA $rate (taux des paliers) est incluse.';
  }

  @override
  String get billingNewPackage => 'Nouveau forfait';

  @override
  String get priceGrossHint =>
      'Prix TTC — ce que paie le membre ; la TVA en fait partie.';

  @override
  String vatShareAmount(String amount) {
    return 'dont TVA $amount';
  }

  @override
  String get reportDesignerDesign => 'Conception';

  @override
  String get reportDesignerPreview => 'Aperçu';

  @override
  String get reportDesignerZoom => 'Zoom';

  @override
  String get reportDesignerZoomFit => 'Ajuster à la largeur';

  @override
  String get planDurationLabel => 'Durée';

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
  String planCheckInOpensOn(String date) {
    return 'Le check-in ouvre le $date';
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
  String get settingsBillingReports => 'Facturation & rapports';

  @override
  String get defaultPeriodTitle => 'Période de réservation par défaut';

  @override
  String get defaultPeriodNone => 'Sans préférence (journée complète)';

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
  String get memberNotifyAction => 'Envoyer une notification';

  @override
  String get memberNotifyAllAdmins => 'Notifier tous les admins';

  @override
  String get memberAllAdmins => 'tous les admins';

  @override
  String memberNoteTitle(String name) {
    return 'Notifier $name';
  }

  @override
  String get memberNoteHint => 'Votre message';

  @override
  String get memberNoteSend => 'Envoyer';

  @override
  String get memberNoteSent => 'Notification envoyée.';

  @override
  String memberNoteReceived(String name) {
    return 'Message de $name';
  }

  @override
  String get eventsMessagesHeader => 'Messages';

  @override
  String memberNoteTo(String name) {
    return 'À $name';
  }

  @override
  String get memberNoteToAllAdmins => 'À tous les admins';

  @override
  String get memberNoteDeleted => 'Message supprimé.';

  @override
  String get memberSimultaneousLimitLabel => 'Réservations simultanées';

  @override
  String get memberSimultaneousLimitExplainer =>
      'Combien de réservations ce membre peut détenir sur une même période. Non défini : le réglage de l\'espace s\'applique.';

  @override
  String get memberSimultaneousLimitDefault => 'Réglage de l\'espace';

  @override
  String memberSimultaneousLimitChip(int n) {
    return '$n à la fois';
  }

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
  String get spaceScanNfcHint =>
      '…ou approchez le téléphone du tag NFC d\'une chaise.';

  @override
  String get spaceScanUnknownTag => 'Ce tag n\'est associé à aucune chaise.';

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
  String get spaceCardSizeLabel => 'Taille de la carte';

  @override
  String get spaceQrSizeLabel => 'Taille du code QR';

  @override
  String get spaceCardSizeSmall => 'Petite';

  @override
  String get spaceCardSizeMedium => 'Moyenne';

  @override
  String get spaceCardSizeLarge => 'Grande';

  @override
  String get spaceCardInfoLabel => 'Informations sur la carte';

  @override
  String get spaceCardInfoWorkspace => 'Espace de travail';

  @override
  String spaceMessageReserver(String name) {
    return 'Écrire à $name';
  }

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
  String get validationAutoValidateOwner =>
      'Les propriétaires suppriment sans validation';

  @override
  String get validationAutoValidateAdmin =>
      'Les admins suppriment sans validation';

  @override
  String get validationAutoValidateDesc =>
      'Leur propre demande de suppression se règle d\'elle-même et reste marquée comme auto-validée.';

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
  String get scanJoinHelp =>
      'Visez le QR d’invitation avec la caméra — le code est repris et l’adhésion se fait automatiquement.';

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
  String get workspaceLanguageLabel => 'Langue de l\'espace';

  @override
  String get workspaceLanguageHelper =>
      'Les invitations sont rédigées par défaut dans cette langue.';

  @override
  String get workspaceLanguageUnset => 'Langue de l\'app de l\'expéditeur';

  @override
  String get workspacePaymentsBillingTitle => 'Paiements et facturation';

  @override
  String get paymentMethodsSubtitle =>
      'IBAN, PayPal, Wero, Lydia, Wise et la référence de paiement';

  @override
  String get featureDocuments => 'Bibliothèque de documents';

  @override
  String get featureDocumentsDesc =>
      'La bibliothèque de documents de l\'espace : statuts, guides, états financiers, comptes rendus — liés depuis n\'importe quel drive, visibles selon le rôle.';

  @override
  String get documentsTitle => 'Documents';

  @override
  String get documentsAdd => 'Ajouter un document';

  @override
  String get documentsTitleLabel => 'Titre';

  @override
  String get documentsUrlLabel => 'Lien (https://…)';

  @override
  String get documentsUrlHelper =>
      'Collez le lien de partage de votre drive — les droits d\'accès restent gérés là-bas.';

  @override
  String get documentsProviderLabel => 'Stocké sur';

  @override
  String get documentsCategoryLabel => 'Catégorie';

  @override
  String get documentsRoleLabel => 'Visible par';

  @override
  String get documentsRoleMember => 'Tous les membres';

  @override
  String get documentsRoleAdmin => 'Admins et propriétaires';

  @override
  String get documentsRoleOwner => 'Propriétaires uniquement';

  @override
  String get documentsCategoryStatutes => 'Statuts et juridique';

  @override
  String get documentsCategoryGuides => 'Guides et manuels';

  @override
  String get documentsCategoryFinance => 'États financiers';

  @override
  String get documentsCategoryMinutes => 'Comptes rendus';

  @override
  String get documentsCategoryOther => 'Autres documents';

  @override
  String get documentsEmpty =>
      'Aucun document. Liez vos statuts, guides et états depuis n\'importe quel drive.';

  @override
  String get documentsDelete => 'Retirer le document ?';

  @override
  String get documentsInvalid =>
      'Un document requiert un titre et un lien https://.';

  @override
  String get featureRoleManagement => 'Gestion des rôles';

  @override
  String get featureRoleManagementDesc =>
      'La matrice centrale rôle→permission : le propriétaire décide quelle permission revient à quel rôle ; les autres consultent les leurs. Désactivée, les valeurs par défaut s\'appliquent simplement.';

  @override
  String get rolesTitle => 'Gestion des rôles';

  @override
  String get rolesIntroEditor =>
      'Le propriétaire détient toujours toutes les permissions. Décidez ici ce que les autres rôles peuvent faire — un copropriétaire peut en détenir moins qu\'un propriétaire.';

  @override
  String get rolesIntroReadOnly =>
      'Lecture seule : voici les permissions de chaque rôle. Votre rôle est mis en évidence.';

  @override
  String get rolesYourRole => 'Votre rôle';

  @override
  String get roleOwner => 'Propriétaire';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleMember => 'Membre';

  @override
  String get permManageRoles => 'Gérer les rôles et permissions';

  @override
  String get permManageMembers => 'Gérer les membres';

  @override
  String get permManageValidation => 'Configurer les règles de validation';

  @override
  String get permWorkspaceSettings => 'Modifier les réglages de l\'espace';

  @override
  String get permIssueInvoices =>
      'Émettre les factures et rapprocher les paiements';

  @override
  String get permViewFinances => 'Consulter les finances de l\'espace';

  @override
  String get permManageDocuments => 'Gérer la bibliothèque de documents';

  @override
  String get permManageServices => 'Gérer les services et forfaits';

  @override
  String get permApproveExpenses => 'Approuver les dépenses';

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
