// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get a11yClearDate => 'Effacer la date';

  @override
  String get a11yDecrease => 'Diminuer';

  @override
  String get a11yFinishEditing => 'Terminer la modification';

  @override
  String get a11yIncrease => 'Augmenter';

  @override
  String get a11yMoveDown => 'Descendre';

  @override
  String get a11yMoveUp => 'Monter';

  @override
  String get a11yRecentre => 'Ajuster le plan à l\'écran';

  @override
  String get a11ySeatBlocked => 'indisponible';

  @override
  String get a11ySeatFree => 'libre';

  @override
  String get a11ySeatMine => 'votre place';

  @override
  String get a11ySeatOccupied => 'occupé';

  @override
  String get a11ySeatReserved => 'réservé';

  @override
  String get a11yZoomIn => 'Zoom avant';

  @override
  String get a11yZoomOut => 'Zoom arrière';

  @override
  String get aboutAttribution =>
      'Based on DesKilo by Florian DITTGEN — https://github.com/fdittgen-png/deskilo';

  @override
  String get aboutAttributionNote =>
      'Cette mention doit rester visible dans toute copie et toute version modifiée.';

  @override
  String get aboutOpenSource => 'Logiciel libre (licence AGPL-3.0)';

  @override
  String get aboutOpenSourceDesc => 'Code source sur GitHub';

  @override
  String get aboutPrivacy => 'Politique de confidentialité';

  @override
  String get aboutReportBug => 'Signaler un bug / suggérer une fonctionnalité';

  @override
  String get aboutSupportBody =>
      'Cette application est gratuite, open source et sans publicité. Si vous la trouvez utile, soutenez le développeur.';

  @override
  String get aboutSupportTitle => 'Soutenir ce projet';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get accessKindNegotiations => 'Négociations tarifaires';

  @override
  String get accessKindProfile => 'votre fiche';

  @override
  String get accessLogEmpty =>
      'Personne n\'a consulté vos finances ni vos messages.';

  @override
  String accessLogRow(String actor, String category, String subject) {
    return '$actor a consulté $category de $subject';
  }

  @override
  String get accessLogTitle => 'Qui a consulté vos données';

  @override
  String get accessNobodyElse => 'personne d\'autre';

  @override
  String get accessRuleEvents => 'Vous, le membre qui a agi, et les admins.';

  @override
  String accessRuleFinances(String people) {
    return 'Vous, et ceux qui ont la permission finances : $people.';
  }

  @override
  String accessRuleManagedProfile(String people) {
    return 'Tant que ce profil était géré pour vous : $people. Chaque consultation ou modification par l\'un d\'eux figure ci-dessous.';
  }

  @override
  String get accessRuleMessages =>
      'Seulement les personnes de la conversation — aucun rôle ne peut lire une conversation dont il ne fait pas partie.';

  @override
  String accessRuleNegotiations(String people) {
    return 'Vous, les propriétaires et les admins finances : $people. Chaque consultation par quelqu\'un d\'autre est journalisée ci-dessous.';
  }

  @override
  String get accessRuleReminders => 'Vous seulement.';

  @override
  String get accessRuleReservations =>
      'Tous les membres de l\'espace — le plan montre l\'occupation à tout le monde.';

  @override
  String get accessoriesActive => 'Actif';

  @override
  String get accessoriesEdit => 'Modifier l’accessoire';

  @override
  String get accessoriesEmpty => 'Aucun accessoire pour l’instant.';

  @override
  String get accessoriesInactive => 'Inactif';

  @override
  String get accessoriesName => 'Nom';

  @override
  String get accessoriesNew => 'Nouvel accessoire';

  @override
  String get accessoriesNoSupplement => 'Sans supplément';

  @override
  String accessoriesPerHalfDay(String amount) {
    return '$amount / demi-journée';
  }

  @override
  String get accessoriesSupplement => 'Supplément par demi-journée';

  @override
  String get accessoriesTitle => 'Accessoires';

  @override
  String get accountActivityEmpty => 'Aucun enregistrement à afficher.';

  @override
  String get accountActivityFailed =>
      'Impossible de charger votre historique financier. Appuyez pour réessayer.';

  @override
  String get accountActivityScope =>
      'Tous vos profils sur ce serveur, y compris vos anciennes adhésions. Les devises restent séparées.';

  @override
  String get accountActivityTitle => 'Ma consommation et mes paiements';

  @override
  String get accountCardTitle => 'Votre compte';

  @override
  String get accountCredit => 'Avoir disponible';

  @override
  String get accountImputationHint =>
      'Votre avoir peut solder les factures ouvertes — l\'espace l\'impute lors du rapprochement des paiements.';

  @override
  String get accountInvoiceIssued => 'Facture émise';

  @override
  String get accountInvoiceRegrouped =>
      'Inclus dans une facture de regroupement';

  @override
  String get accountInvoiceVoided => 'Facture annulée';

  @override
  String get accountNet => 'Position nette';

  @override
  String accountOpenPartial(String period, String paid) {
    return '$period · $paid réglés';
  }

  @override
  String get accountPaymentAsk => 'Choisir au paiement';

  @override
  String get accountPaymentConfirmed => 'Paiement confirmé';

  @override
  String get accountPaymentPreference => 'Paiement en ligne préféré';

  @override
  String get accountPaymentsTitle => 'Paiements';

  @override
  String get accountRefundDue => 'Remboursement dû par l\'espace';

  @override
  String get accountUsageCorrected => 'Consommation facturable corrigée';

  @override
  String accountUsageMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get accountingExportDevelopment =>
      'Espace de développement : le fichier est marqué DEV et n\'est pas la comptabilité réelle.';

  @override
  String get addressCountryLabel => 'Pays';

  @override
  String get addressNone => 'Aucune adresse';

  @override
  String get addressSaved => 'Adresse enregistrée';

  @override
  String get addressTitle => 'Adresse';

  @override
  String get addressVatIdLabel =>
      'Numéro de TVA (si vous facturez en tant que professionnel)';

  @override
  String get addressWindowCountry => 'Suivre le pays';

  @override
  String get addressWindowLeft => 'Gauche (DIN 5008)';

  @override
  String get addressWindowOff => 'Sans fenêtre';

  @override
  String get addressWindowRight => 'Droite (usage français)';

  @override
  String get addressWindowSubtitle =>
      'Où le destinataire est imprimé pour apparaître dans la fenêtre de l\'enveloppe. Le bloc adresse mesure 85 × 45 mm, à 45 mm du haut de la feuille.';

  @override
  String get addressWindowTitle => 'Fenêtre d\'adresse';

  @override
  String get agreementExtraHalfDay => 'Demi-journée supplémentaire';

  @override
  String get amenityDock => 'Station d\'accueil';

  @override
  String get amenityErgonomicChair => 'Chaise ergonomique';

  @override
  String get amenityMonitor => 'Écran';

  @override
  String get amenityStandingDesk => 'Bureau debout';

  @override
  String get amenityWindow => 'Côté fenêtre';

  @override
  String get appTitle => 'DesKilo';

  @override
  String get applicationAcceptedVote => 'A accepté cette demande';

  @override
  String get applicationApproved => 'Acceptée';

  @override
  String get applicationDecisionComment =>
      'Commentaire visible par la personne qui a fait la demande';

  @override
  String get applicationDiscussionHint =>
      'Vos demandes et les échanges avec les personnes chargées de leur validation restent accessibles, même après un refus.';

  @override
  String get applicationNoMessages => 'Aucun message pour le moment.';

  @override
  String get applicationPending => 'En attente de validation';

  @override
  String get applicationRefused => 'Refusée';

  @override
  String get applicationRefusedVote => 'A refusé cette demande';

  @override
  String get applicationReplyFailed =>
      'Votre message n’a pas été envoyé. Votre brouillon est conservé ; veuillez réessayer.';

  @override
  String get applicationsEmpty => 'Aucune demande d’accès.';

  @override
  String get applicationsLoadFailed =>
      'Impossible de charger vos demandes d’accès. Veuillez réessayer.';

  @override
  String get applicationsTitle => 'Demandes d’accès';

  @override
  String get assistantPrefix => 'Assistant';

  @override
  String get assistantSetupActorConfigurer =>
      'Qui : une personne qui gère la configuration de cet espace de travail';

  @override
  String get assistantSetupActorDatabaseAdministrator =>
      'Qui : un administrateur de la base de données';

  @override
  String get assistantSetupActorInstanceOperator =>
      'Qui : le propriétaire de l\'instance ou un délégué';

  @override
  String get assistantSetupActorIntegrations =>
      'Qui : une personne qui gère les intégrations de cet espace de travail';

  @override
  String get assistantSetupActorYou => 'Qui : vous';

  @override
  String get assistantSetupAllDone =>
      'Tout est configuré pour cet espace de travail.';

  @override
  String get assistantSetupApply => 'Appliquer';

  @override
  String get assistantSetupConnectHowTo =>
      '1. Dans votre assistant, ajoutez un connecteur personnalisé avec cette URL.\n2. Connectez-vous avec votre compte DesKilo lorsque c\'est demandé.\n3. Approuvez cet espace de travail et les opérations que vous autorisez.';

  @override
  String get assistantSetupCopied => 'URL du connecteur copiée.';

  @override
  String get assistantSetupCopyUrl => 'Copier l\'URL du connecteur';

  @override
  String get assistantSetupCustomise => 'Personnaliser';

  @override
  String get assistantSetupFailed =>
      'Enregistrement impossible. Rien n\'a changé ; réessayez.';

  @override
  String assistantSetupInstanceNames(String names) {
    return 'Répondent de cette base de données : $names.';
  }

  @override
  String get assistantSetupInstanceNobody =>
      'Personne ne répond encore de cette base de données.';

  @override
  String get assistantSetupInstanceYou =>
      'Vous répondez de cette base de données : activez les assistants depuis les outils de l\'instance.';

  @override
  String get assistantSetupIntro =>
      'Ce dont les assistants ont besoin dans cet espace de travail, dans l\'ordre. Chaque étape indique qui s\'en charge.';

  @override
  String get assistantSetupLinkIdentity => 'Confirmer mon identité';

  @override
  String assistantSetupNextTodo(String step) {
    return 'Étape suivante : $step.';
  }

  @override
  String assistantSetupNextWaiting(String step, String actor) {
    return 'Étape suivante : $step. $actor.';
  }

  @override
  String get assistantSetupNoConnector =>
      'Cette application fonctionne sans serveur : il n\'y a donc pas d\'URL de connecteur.';

  @override
  String get assistantSetupNoWorkspace =>
      'Choisissez d\'abord un espace de travail.';

  @override
  String get assistantSetupPreviewAdds => 'Ajoutées';

  @override
  String get assistantSetupPreviewNone =>
      'Aucun changement : l\'espace de travail propose déjà exactement cette sélection.';

  @override
  String get assistantSetupPreviewNote =>
      'Uniquement les données propres d\'un membre et la consultation des disponibilités. Les assistants déjà connectés n\'obtiennent les nouvelles opérations qu\'après une nouvelle approbation de chaque personne.';

  @override
  String get assistantSetupPreviewOwn =>
      'Les assistants ne voient que les données propres de chaque membre.';

  @override
  String get assistantSetupPreviewRemoves => 'Retirées';

  @override
  String get assistantSetupPreviewTitle => 'Sélection recommandée';

  @override
  String get assistantSetupReasonConnect =>
      'Ajoutez le connecteur dans votre assistant, connectez-vous et approuvez cet espace de travail.';

  @override
  String get assistantSetupReasonEligibility =>
      'Les administrateurs de cette base de données approuvent chaque personne une fois, pour tous ses espaces de travail.';

  @override
  String get assistantSetupReasonIdentity =>
      'Un assistant agit en votre nom : cette base de données doit savoir que c\'est vous.';

  @override
  String get assistantSetupReasonInstallation =>
      'Le propriétaire de l\'instance ou un délégué active les assistants pour tous les espaces de travail de cette base de données.';

  @override
  String get assistantSetupReasonPolicy =>
      'Rien n\'est proposé aux assistants tant que personne n\'a choisi les opérations.';

  @override
  String get assistantSetupReasonWorkspace =>
      'Tant que c\'est désactivé, l\'espace de travail refuse tout appel d\'assistant.';

  @override
  String get assistantSetupRecommended => 'Utiliser la sélection recommandée';

  @override
  String get assistantSetupRequest => 'Demander l\'accès';

  @override
  String get assistantSetupReview => 'Examiner les demandes';

  @override
  String get assistantSetupSaved => 'Enregistré.';

  @override
  String get assistantSetupStale =>
      'Quelqu\'un a modifié l\'offre entre-temps. Vérifiez-la et réessayez.';

  @override
  String get assistantSetupStateBlocked => 'Après les étapes ci-dessus';

  @override
  String get assistantSetupStateDone => 'Fait';

  @override
  String get assistantSetupStateTodo => 'À faire';

  @override
  String get assistantSetupStateUnavailable => 'Impossible à interroger';

  @override
  String get assistantSetupStateWaiting => 'En attente';

  @override
  String get assistantSetupStepConnect => 'Connecter votre assistant';

  @override
  String get assistantSetupStepEligibility =>
      'Demander votre accès aux assistants';

  @override
  String get assistantSetupStepIdentity => 'Lier votre identité';

  @override
  String get assistantSetupStepInstallation =>
      'Assistants activés pour cette base de données';

  @override
  String get assistantSetupStepPolicy =>
      'Choisir ce que les assistants peuvent faire';

  @override
  String get assistantSetupStepWorkspace =>
      'Activer les assistants pour cet espace de travail';

  @override
  String get assistantSetupTitle => 'Configuration des assistants';

  @override
  String get assistantSetupTurnOn => 'Activer';

  @override
  String get authAlreadyRegistered =>
      'Cette adresse ne peut pas servir à créer un compte. Connectez-vous ou réinitialisez votre mot de passe.';

  @override
  String get authConnectServer => 'Se connecter au serveur d\'une organisation';

  @override
  String get authContinueWith => 'ou continuer avec';

  @override
  String get authDisplayNameLabel => 'Nom affiché';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authEmailNotConfirmed =>
      'Confirmez d\'abord votre adresse e-mail : ouvrez le message que nous vous avons envoyé, puis connectez-vous.';

  @override
  String get authFieldRequired => 'Obligatoire';

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authGenericError =>
      'Échec de l\'authentification. Vérifiez vos identifiants et réessayez.';

  @override
  String get authHidePassword => 'Masquer le mot de passe';

  @override
  String get authJoinByInvitation => 'Rejoindre sur invitation';

  @override
  String get authJoinHint =>
      'Créez d\'abord votre compte ou connectez-vous — vous collerez votre invitation juste après.';

  @override
  String authLinkAlreadyUsed(String provider) {
    return 'Cette identité $provider est déjà liée à un autre compte.';
  }

  @override
  String authLinkFailed(String provider, String code) {
    return 'L\'association de $provider a échoué ($code). Réessayez ; si cela persiste, communiquez ce code à l\'administrateur du serveur.';
  }

  @override
  String get authLinkManualDisabled =>
      'L\'association de comptes est désactivée sur ce serveur. Son administrateur doit activer « Autoriser l\'association manuelle » dans les paramètres d\'authentification.';

  @override
  String get authNetworkError =>
      'Impossible de joindre le serveur. Vérifiez votre connexion et réessayez.';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authPasswordTooShort => 'Au moins 8 caractères';

  @override
  String get authProviderDisabled =>
      'Cette méthode de connexion est désactivée sur ce serveur.';

  @override
  String get authRateLimited =>
      'Trop de tentatives. Patientez un instant, puis réessayez.';

  @override
  String get authRecoveryNotSaved =>
      'Votre code a été accepté, mais le nouveau mot de passe n\'a pas été enregistré. Réessayez de l\'enregistrer.';

  @override
  String get authRecoveryRetryUpdate => 'Réenregistrer le nouveau mot de passe';

  @override
  String get authRecoverySessionLost =>
      'Ce code n\'est plus valable ici. Demandez-en un nouveau.';

  @override
  String get authResetCodeLabel => 'Code reçu par e-mail';

  @override
  String get authResetCodeSent => 'Code envoyé — vérifiez vos e-mails.';

  @override
  String get authResetDone => 'Mot de passe mis à jour — vous êtes connecté.';

  @override
  String get authResetExplainer =>
      'Nous vous enverrons un code à usage unique par e-mail. Utilisez-le ici pour définir un nouveau mot de passe.';

  @override
  String get authResetInvalidCode => 'Ce code est invalide ou a expiré.';

  @override
  String get authResetNewPasswordLabel => 'Nouveau mot de passe';

  @override
  String get authResetSendCode => 'Envoyer le code';

  @override
  String get authResetSubmit => 'Définir le nouveau mot de passe';

  @override
  String get authResetTitle => 'Réinitialiser le mot de passe';

  @override
  String get authShowPassword => 'Afficher le mot de passe';

  @override
  String get authSignInButton => 'Se connecter';

  @override
  String get authSignInTitle => 'Connexion';

  @override
  String get authSignOut => 'Se déconnecter';

  @override
  String get authSignUpButton => 'Créer le compte';

  @override
  String get authSignUpTitle => 'Créer un compte';

  @override
  String authSocialUnavailable(String provider) {
    return 'La connexion $provider n\'est pas encore disponible — le serveur ne l\'a pas activée.';
  }

  @override
  String get authToggleToSignIn => 'Déjà un compte ? Connectez-vous';

  @override
  String get authToggleToSignUp => 'Nouveau ici ? Créez un compte';

  @override
  String get authVerifyBackToSignIn => 'Retour à la connexion';

  @override
  String authVerifyBody(String email) {
    return 'Nous avons envoyé un lien de confirmation à $email. Ouvrez-le sur cet appareil pour terminer la création de votre compte.';
  }

  @override
  String get authVerifyChangeEmail => 'Utiliser une autre adresse';

  @override
  String get authVerifyHint =>
      'Rien reçu ? Regardez dans les indésirables, ou renvoyez-le.';

  @override
  String get authVerifyResend => 'Renvoyer l\'e-mail';

  @override
  String get authVerifyResendWait =>
      'Vous pourrez le renvoyer dans une minute.';

  @override
  String get authVerifyResent => 'Renvoyé.';

  @override
  String get authVerifyTitle => 'Consultez vos e-mails';

  @override
  String get authWeakPassword => 'Choisissez un mot de passe plus robuste.';

  @override
  String get availabilityAddClosure => 'Ajouter un jour de fermeture';

  @override
  String get availabilityClosureDays => 'Jours de fermeture';

  @override
  String get availabilityClosureReason => 'Motif (facultatif)';

  @override
  String get availabilityFullDayHours =>
      'Heures facturées comme journée complète';

  @override
  String get availabilityGranularity15 => 'Créneaux de 15 minutes';

  @override
  String get availabilityGranularity30 => 'Créneaux de 30 minutes';

  @override
  String get availabilityGranularity5 => 'Créneaux de 5 minutes';

  @override
  String get availabilityGranularity60 => 'Créneaux d\'une heure';

  @override
  String get availabilityGranularityDescription =>
      'Demi-journées : les réservations couvrent le matin, l\'après-midi ou la journée entière — les créneaux suivent les horaires de travail configurés.';

  @override
  String get availabilityGranularityFlexible => 'Plage horaire libre';

  @override
  String get availabilityGranularityFullDay => 'Journées entières uniquement';

  @override
  String get availabilityGranularityHalfDay =>
      'Demi-journées (matin et après-midi)';

  @override
  String get availabilityGranularityHours =>
      'Heures réelles (de–à exact, demi/journées en raccourcis)';

  @override
  String get availabilityGranularityTitle => 'Granularité des réservations';

  @override
  String get availabilityHalfBoundary => 'Limite de demi-journée';

  @override
  String get availabilityHalfDayHours => 'Heures facturées comme demi-journée';

  @override
  String availabilityHourOption(int count) {
    return '$count h';
  }

  @override
  String get availabilityLastOpenDay =>
      'Au moins un jour de la semaine doit rester ouvert.';

  @override
  String get availabilityNoClosures => 'Aucun jour de fermeture.';

  @override
  String get availabilityOpenWeekdays => 'Jours d\'ouverture';

  @override
  String get availabilityPoliciesTitle => 'Règles de réservation';

  @override
  String get availabilityTitle => 'Disponibilité';

  @override
  String get availabilityWorkEnd => 'Fin de journée';

  @override
  String get availabilityWorkHoursDescription =>
      'Les créneaux demi-journée et journée complète partout — réservations, check-in et facturation — suivent ces horaires.';

  @override
  String get availabilityWorkHoursInvalid =>
      'La journée doit respecter début < limite de demi-journée < fin.';

  @override
  String get availabilityWorkHoursTitle => 'Horaires de travail';

  @override
  String get availabilityWorkStart => 'Début de journée';

  @override
  String get backendCopyLink => 'Copier';

  @override
  String get backendCurrentTitle => 'Cet appareil utilise';

  @override
  String get backendDescriptorInvalid =>
      'Ce n\'est pas un code serveur DesKilo valide.';

  @override
  String get backendDescriptorLabel => 'Code serveur';

  @override
  String backendDescriptorNamed(String label) {
    return 'Nommé « $label » par la personne qui l\'a partagé — non vérifié.';
  }

  @override
  String backendDestination(String host) {
    return 'Destination : $host';
  }

  @override
  String get backendErrorKeyConnectionString =>
      'C\'est une chaîne de connexion à la base de données. Elle ne quitte jamais le serveur — collez ici la clé publiable du projet.';

  @override
  String get backendErrorKeyEmpty => 'Saisissez la clé publiable.';

  @override
  String get backendErrorKeyNotSupabase =>
      'Ce n\'est pas une clé publiable Supabase (sb_publishable_…).';

  @override
  String get backendErrorKeyPersonalToken =>
      'C\'est un jeton d\'accès personnel. Il reste chez son propriétaire — collez ici la clé publiable du projet.';

  @override
  String get backendErrorKeySecret =>
      'C\'est une clé secrète, pas une clé publiable. Ne la partagez jamais : renouvelez-la dans Project Settings → API keys, puis collez ici la clé publiable.';

  @override
  String get backendErrorKeyUserToken =>
      'C\'est un jeton de session ou d\'identité, pas une clé de projet. Collez ici la clé publiable du projet.';

  @override
  String get backendErrorUrlEmpty => 'Saisissez l\'URL du projet.';

  @override
  String get backendErrorUrlNoHost => 'Ce n\'est pas une adresse complète.';

  @override
  String get backendErrorUrlNotCanonical =>
      'Indiquez seulement l\'adresse du projet (https://hôte), sans chemin, ni paramètres, ni identifiants.';

  @override
  String get backendErrorUrlNotHttps => 'L\'URL doit commencer par https://.';

  @override
  String get backendFacetNo => 'non';

  @override
  String get backendFacetUnknown => 'inconnu';

  @override
  String get backendFacetYes => 'oui';

  @override
  String backendFacets(
    String reachable,
    String key,
    String schema,
    String version,
  ) {
    return 'Atteint : $reachable · Clé acceptée : $key · Schéma : $schema · Version : $version';
  }

  @override
  String get backendFullCheckHint =>
      'Collez un jeton d\'accès personnel pour ce contrôle. Il ne sert qu\'à ce contrôle et n\'est jamais enregistré.';

  @override
  String get backendFullCheckTitle => 'Lancer un contrôle complet';

  @override
  String get backendFullCheckUseToken => 'Utiliser ce jeton';

  @override
  String get backendHowTitle => 'Utiliser votre propre serveur';

  @override
  String get backendKeyLabel => 'Clé publiable';

  @override
  String backendLastOk(String time) {
    return 'Dernier test réussi : $time';
  }

  @override
  String get backendModeConnect => 'Rejoindre une organisation existante';

  @override
  String get backendModeConnectHint =>
      'Scannez ou collez le code serveur transmis par votre organisation. Aucune clé d\'administrateur n\'est nécessaire.';

  @override
  String get backendModeDefault => 'Utiliser le service DesKilo';

  @override
  String get backendModeDefaultHint =>
      'Le service DesKilo ne demande aucune configuration. Les membres d\'une organisation qui exploite son propre serveur utilisent son code à la place.';

  @override
  String get backendModeOperator => 'Installer un serveur (opérateurs)';

  @override
  String get backendOpenDashboard => 'Ouvrir dans Supabase';

  @override
  String get backendOwnServer => 'Votre propre serveur';

  @override
  String get backendOwnership =>
      'Il appartient à votre organisation Supabase. DesKilo n\'y garde aucun accès.';

  @override
  String get backendOwnershipOther =>
      'Il appartient à qui l\'exploite. DesKilo n\'y garde aucun accès.';

  @override
  String get backendPaste => 'Coller';

  @override
  String backendPendingBody(String active, String saved) {
    return 'Cette session tourne encore sur $active. $saved prendra le relais quand vous fermerez et rouvrirez l\'app.';
  }

  @override
  String get backendPendingTitle => 'Enregistré pour le prochain démarrage';

  @override
  String get backendPendingUndo => 'Annuler';

  @override
  String get backendPendingUndone =>
      'Annulé — le serveur précédent est de retour.';

  @override
  String backendProjectRef(String ref) {
    return 'Votre projet Supabase $ref';
  }

  @override
  String get backendResetDeviceOnly =>
      'Cela ne change que cet appareil et ne touche jamais à votre projet Supabase.';

  @override
  String get backendSaveNeedsTest =>
      'Testez d\'abord la connexion. Seul un serveur vérifié peut être enregistré.';

  @override
  String get backendScan => 'Scanner un QR de serveur';

  @override
  String get backendScanNothing =>
      'Ce QR n\'est pas un code de serveur DesKilo.';

  @override
  String backendServerCustom(Object host) {
    return 'Votre propre serveur ($host)';
  }

  @override
  String backendServerDefault(Object host) {
    return 'Le serveur de l\'app ($host)';
  }

  @override
  String get backendServerHint =>
      'Par défaut, l\'app utilise son propre serveur. Si votre communauté fait tourner son propre projet Supabase, saisissez-le ici — l\'app y stockera alors tout.';

  @override
  String get backendServerInUse => 'Utilisé sur cet appareil';

  @override
  String get backendServerReset => 'Utiliser le serveur de l\'app';

  @override
  String get backendServerRestartHint =>
      'L\'app vous déconnecte et applique le changement au prochain démarrage.';

  @override
  String get backendServerSaved =>
      'Enregistré. Fermez puis rouvrez l\'app pour utiliser le nouveau serveur.';

  @override
  String get backendServerTitle => 'Serveur';

  @override
  String get backendShare => 'Partager ce serveur';

  @override
  String get backendShareHint =>
      'Les membres le scannent dans Réglages → Serveur pour pointer leur app sur la même instance.';

  @override
  String get backendStep1 =>
      'Créez un projet sur supabase.com (le palier gratuit suffit pour démarrer).';

  @override
  String get backendStep2 =>
      'Installez le schéma de l\'app : exécutez les fichiers SQL de supabase/migrations du dépôt source, dans l\'ordre.';

  @override
  String get backendStep3 =>
      'Dans le tableau de bord Supabase, ouvrez Project Settings → API keys et copiez le Project URL et la clé publiable.';

  @override
  String get backendStep4 =>
      'Collez-les ci-dessous, testez la connexion et enregistrez. Les membres rejoignent la même instance en scannant le QR ci-dessus.';

  @override
  String get backendTest => 'Tester la connexion';

  @override
  String get backendTestAhead =>
      'Contacté. Son schéma est plus récent que l\'application — cela fonctionne, et une version plus récente de l\'application est disponible.';

  @override
  String get backendTestAttention =>
      'Atteint, mais la réponse n\'a pas pu être classée. Vérifiez le serveur avant de l\'utiliser.';

  @override
  String get backendTestBadKey =>
      'Contacté, mais la clé a été refusée. Recopiez la clé publiable depuis Project Settings → API keys.';

  @override
  String get backendTestBehind =>
      'Contacté, mais son schéma DesKilo est plus ancien que ce dont l\'application a besoin. Mettez le serveur à jour avant de l\'utiliser.';

  @override
  String get backendTestOk => 'Contacté — le schéma de l\'app est bien là.';

  @override
  String get backendTestSchemaMissing =>
      'Contacté, mais les tables DesKilo manquent — exécutez d\'abord les migrations de supabase/migrations sur ce projet.';

  @override
  String get backendTestUnreachable =>
      'Impossible de joindre cette adresse. Vérifiez l\'URL et votre réseau.';

  @override
  String get backendTesting => 'Test en cours…';

  @override
  String get backendUrlLabel => 'URL du projet';

  @override
  String get backendVersionAhead =>
      'Le serveur est plus récent que cette app — mettez l\'app à jour dès que possible';

  @override
  String backendVersionBehind(int version) {
    return 'Mise à jour nécessaire : cette app a besoin du schéma $version';
  }

  @override
  String get backendVersionBehindHow =>
      'Son propriétaire le met à jour avec l\'assistant d\'installation ou `dart run tool/instance.dart install`, qui n\'applique que ce qui manque.';

  @override
  String backendVersionCurrent(int version) {
    return 'À jour (schéma $version)';
  }

  @override
  String get backendVersionShortAhead => 'plus récente';

  @override
  String get backendVersionShortBehind => 'plus ancienne';

  @override
  String get backendVersionShortCurrent => 'à jour';

  @override
  String get backendVersionUnknown =>
      'La version n\'a pas pu être vérifiée pour le moment';

  @override
  String get badgeAuthEnabledHint =>
      'Désactivé par défaut : un badge qui vous pointe ne vous connecte pas tant que vous ne l’avez pas décidé.';

  @override
  String get badgeAuthEnabledLabel => 'Me connecte';

  @override
  String get badgeAuthNeedsPin =>
      'Définissez d’abord un code de connexion — un badge seul ne doit jamais suffire.';

  @override
  String get badgeCardAlreadyRegistered => 'Cette carte est déjà enregistrée.';

  @override
  String get badgeCardRegistered => 'Carte enregistrée.';

  @override
  String get badgeDefaultLabel => 'Badge';

  @override
  String get badgeDeleteConfirm =>
      'Supprimer définitivement ce badge révoqué ?';

  @override
  String get badgeIssue => 'Nouveau badge';

  @override
  String badgeIssuedOn(String date) {
    return 'Émis le $date';
  }

  @override
  String get badgeNone => 'Aucun badge pour l\'instant.';

  @override
  String get badgePinChangeAction => 'Modifier le code';

  @override
  String get badgePinClearAction => 'Supprimer le code';

  @override
  String get badgePinCleared =>
      'Code supprimé. Vos badges ne vous connectent plus.';

  @override
  String get badgePinConfirmLabel => 'Répétez-le';

  @override
  String get badgePinExplain =>
      'Votre code vous permet de vous connecter en scannant votre badge au lieu de saisir votre e-mail. Vous seul pouvez le définir, et personne — pas même un propriétaire — ne peut le relire.';

  @override
  String get badgePinMismatch => 'Les deux saisies ne correspondent pas.';

  @override
  String get badgePinNewLabel => 'Nouveau code';

  @override
  String get badgePinNotSet => 'Pas encore de code';

  @override
  String get badgePinSaveFailed =>
      'Serveur injoignable. Votre code n\'a pas été modifié — réessayez.';

  @override
  String get badgePinSaved => 'Code enregistré.';

  @override
  String get badgePinSectionTitle => 'Mon code';

  @override
  String get badgePinSet => 'Code défini';

  @override
  String get badgePinSetAction => 'Définir un code';

  @override
  String badgePinTooShort(int min) {
    return 'Utilisez au moins $min chiffres.';
  }

  @override
  String get badgeRegisterCard => 'Enregistrer une carte';

  @override
  String get badgeRevoke => 'Révoquer';

  @override
  String get badgeRevoked => 'Révoqué';

  @override
  String get badgeSavePdf => 'Enregistrer en PDF';

  @override
  String get badgeSignInButton => 'Se connecter';

  @override
  String get badgeSignInEntry => 'Se connecter avec un badge';

  @override
  String badgeSignInHello(String name) {
    return 'Bonjour $name';
  }

  @override
  String get badgeSignInLocked =>
      'Trop de tentatives. Patientez quelques minutes, ou connectez-vous avec votre e-mail.';

  @override
  String get badgeSignInNoReader =>
      'Aucun lecteur de badge disponible sur cet appareil.';

  @override
  String get badgeSignInPinLabel => 'Votre code';

  @override
  String get badgeSignInRefused =>
      'Cela n’a pas fonctionné. Vérifiez le badge et le code, ou connectez-vous avec votre e-mail.';

  @override
  String get badgeSignInRetry => 'Réessayer';

  @override
  String get badgeSignInTapPrompt => 'Approchez votre badge du téléphone.';

  @override
  String get badgeSignInTitle => 'Se connecter avec son badge';

  @override
  String get badgeSignInUnavailable =>
      'La connexion par badge est injoignable pour le moment. Connectez-vous avec votre e-mail.';

  @override
  String get badgeSignInUseEmail => 'Utiliser mon e-mail à la place';

  @override
  String get badgeTapCardHint =>
      'Approchez la carte RFID/NFC de l\'arrière de l\'appareil.';

  @override
  String get badgeTapCardTitle => 'Enregistrer une carte';

  @override
  String get badgeTokenOnce =>
      'Enregistrez ce QR maintenant — il n\'est affiché qu\'une seule fois.';

  @override
  String get baseRoleNote =>
      'Chacun a exactement un rôle de base : Utilisateur, Administrateur, Copropriétaire ou Propriétaire. Les autres rôles s\'y ajoutent ; aucun ne retire quoi que ce soit.';

  @override
  String get baseRoleUser => 'Utilisateur';

  @override
  String get biAreaCapacity => 'Espaces et capacité';

  @override
  String get biAreaFinance => 'Finances';

  @override
  String get biAreaOperations => 'Exploitation';

  @override
  String get biAreaOverview => 'Vue d’ensemble';

  @override
  String get biAreaPeople => 'Personnes et activité';

  @override
  String get biAreaPlanning => 'Planification';

  @override
  String get biAreaSaved => 'Analyses enregistrées';

  @override
  String get biAreaTreasury => 'Trésorerie';

  @override
  String get biBookingBasis =>
      'La capacité réservée mesure les réservations, pas la présence réelle.';

  @override
  String get biCardDown => 'Descendre';

  @override
  String get biCardUp => 'Monter';

  @override
  String get biCards => 'Analyses affichées';

  @override
  String biCardsUnavailable(String count) {
    return '$count analyses de cette vue ne vous sont pas accessibles et sont omises.';
  }

  @override
  String biChangePoints(String value) {
    return '$value pts';
  }

  @override
  String get biCollectionCentre => 'de ce qui a été facturé';

  @override
  String get biCollectionCollected => 'Encaissé';

  @override
  String get biCollectionNoComposition =>
      'Les montants encaissés incluent ici des factures antérieures : ils ne sont pas une partie du total facturé de la période.';

  @override
  String get biCollectionOutstanding => 'Reste à encaisser';

  @override
  String get biColumnChange => 'Écart';

  @override
  String get biColumnValue => 'Valeur';

  @override
  String get biCompare => 'Comparer avec';

  @override
  String get biCompareCustom => 'Une période que je choisis';

  @override
  String get biCompareNone => 'Rien';

  @override
  String get biComparePrevious => 'La période précédente';

  @override
  String get biComparePreviousYear => 'La même période un an avant';

  @override
  String get biCompareTitle => 'Comparé au passé';

  @override
  String biComparedLine(String period, String value, String change) {
    return '$period : $value ($change)';
  }

  @override
  String biComparedNotRecorded(String period, String since) {
    return '$period n’a pas été enregistré (l’historique commence le $since) ; pas de comparaison.';
  }

  @override
  String biComparedPartial(String period) {
    return '$period n’est enregistré qu’en partie.';
  }

  @override
  String get biComparisonUnqualified =>
      'Évolution indisponible : une période contient des données partielles ou anciennes.';

  @override
  String get biCompositionTitle => 'Ce qui la compose';

  @override
  String biComputedWorkspaceTime(String date) {
    return 'Calculé le $date · heure de l’espace';
  }

  @override
  String get biCurrentBasis =>
      'La période entière est incluse. La comparaison avec une période terminée ne porte pas sur une base équivalente.';

  @override
  String get biDataNotApplicable => 'Aucune capacité applicable';

  @override
  String get biDataNotRecorded => 'Non enregistré';

  @override
  String get biDataPartial => 'Données partielles';

  @override
  String get biDataStale => 'Données anciennes';

  @override
  String get biDataUnavailable => 'Indisponible';

  @override
  String get biDeltaNone => 'Pas encore de comparaison';

  @override
  String get biDimensionLevel => 'Niveau';

  @override
  String get biEvolutionTitle => 'Évolution';

  @override
  String get biExportPdf => 'Exporter en PDF';

  @override
  String get biExposureDiffers =>
      'Les deux périodes n’offrent pas la même base ; le taux en tient compte, les chiffres bruts ne se comparent pas directement.';

  @override
  String get biFinanceCollected => 'Encaissé';

  @override
  String biFinanceCollectedBasis(String count) {
    return 'Sur $count paiements rapprochés de factures';
  }

  @override
  String get biFinanceCollectedDefinition =>
      'Paiements rapprochés de factures, selon le mois du rapprochement à l’heure de l’espace.';

  @override
  String get biFinanceCollectedZero => 'Mesuré : rien n’a été encaissé.';

  @override
  String biFinanceComputed(String date) {
    return 'Calculé le $date';
  }

  @override
  String get biFinanceCurrencyMix =>
      'Cette période contient des montants dans une autre devise ; des devises différentes ne s’additionnent pas, aucun montant n’est donc affiché.';

  @override
  String get biFinanceInvoiced => 'Facturé';

  @override
  String biFinanceInvoicedBasis(String count, String credit) {
    return 'Sur $count factures ; avoirs $credit, montrés à part';
  }

  @override
  String get biFinanceInvoicedDefinition =>
      'Factures de ces mois, hors factures annulées et règlements groupés (un règlement regroupe des factures déjà comptées) ; totaux positifs seulement.';

  @override
  String get biFinanceInvoicedZero => 'Mesuré : rien n’a été facturé.';

  @override
  String biFinanceLastChange(String date) {
    return 'Dernière modification de la source : $date';
  }

  @override
  String get biFinanceNotExact =>
      'Un montant est trop grand pour être affiché exactement ; il n’est donc pas affiché.';

  @override
  String get biFinanceNotProfit =>
      'Pas un bénéfice : aucun coût n’entre dans ce chiffre, et les deux chiffres ne se soustraient pas.';

  @override
  String get biFinancePartial =>
      'La période n’est pas terminée : ces chiffres vont encore changer.';

  @override
  String get biFinanceSameAsReport =>
      'Les mêmes règles que le rapport d’état de l’espace, calculées une fois sur le serveur.';

  @override
  String get biForbidden =>
      'Vous ne pouvez pas lire cette analyse dans cet espace.';

  @override
  String get biFutureBasis =>
      'Réservations existantes et horaires actuels ; ni prévision de demande ni utilisation garantie.';

  @override
  String get biGrain => 'Durée de la période';

  @override
  String get biGrainMonth => 'Mois';

  @override
  String get biGrainQuarter => 'Trimestre';

  @override
  String get biGrainYear => 'Année';

  @override
  String get biGroupBy => 'Regrouper par';

  @override
  String get biGroupNone => 'Sans regroupement';

  @override
  String get biInvalidAddress =>
      'Cette adresse demande une analyse qui n’existe pas ; rien n’a été lu.';

  @override
  String get biKindCurrent => 'Maintenant';

  @override
  String get biKindPrevious => 'Période précédente';

  @override
  String get biKindYearAgo => 'Même période l\'an dernier';

  @override
  String biNarrativeDown(String label, String change) {
    return 'Plus bas que $label ($change).';
  }

  @override
  String biNarrativeFlat(String label) {
    return 'À peu près comme $label.';
  }

  @override
  String biNarrativeUp(String label, String change) {
    return 'Plus haut que $label ($change).';
  }

  @override
  String get biNoDataLabel => 'pas de donnée';

  @override
  String get biNotOffered => 'non proposé par les analyses affichées';

  @override
  String get biOnPace => 'au rythme actuel';

  @override
  String get biOpenSource => 'Ouvrir la source';

  @override
  String get biPastBasis =>
      'Recalculé à partir des données disponibles aujourd’hui, et non des seules données connues à l’époque.';

  @override
  String get biPdfEstimateNote =>
      'Les lignes en pointillés et les zones ombrées sont des estimations tirées des périodes passées, pas des mesures.';

  @override
  String get biPdfFailed => 'Le PDF n\'a pas pu être créé.';

  @override
  String biPdfProduced(String date) {
    return 'Établi le $date';
  }

  @override
  String get biPdfTitle => 'Analyse d\'activité';

  @override
  String biProjectionBasis(int count) {
    return 'Une droite tracée sur les $count dernières périodes complètes, prolongée. La zone ombrée est la fourchette probable. Une estimation, pas une promesse.';
  }

  @override
  String get biProjectionLabel => 'Estimation';

  @override
  String biProjectionNotEnough(int have, int need) {
    return 'Pas encore assez d\'historique pour projeter : $have périodes complètes pour l\'instant, $need nécessaires.';
  }

  @override
  String get biProjectionTitle => 'Où cela va';

  @override
  String get biProvisionalNote =>
      'Provisoire : la période n\'est pas terminée, cette variation est une estimation.';

  @override
  String biQuarter(String quarter, String year) {
    return 'T$quarter $year';
  }

  @override
  String get biRecordedFuture => 'Période future · réservations enregistrées';

  @override
  String get biRecordedPast => 'Période passée · données actuelles';

  @override
  String get biRecordedPresent => 'Période en cours · dates futures incluses';

  @override
  String get biRefresh => 'Actualiser les données';

  @override
  String biRefusedBudget(String count) {
    return 'Il y a plus de $count groupes ; choisissez « Sans regroupement ».';
  }

  @override
  String get biRefusedComparison =>
      'Cette analyse ne peut pas faire cette comparaison.';

  @override
  String get biRefusedGrain =>
      'Cette analyse n’est pas proposée pour cette durée de période.';

  @override
  String get biRefusedGrouping =>
      'Cette analyse ne peut pas être regroupée ainsi.';

  @override
  String get biRemainder => 'Hors des groupes actuels';

  @override
  String get biReset => 'Afficher la vue standard';

  @override
  String biRunRate(String value) {
    return 'Au rythme actuel, cette période finirait autour de $value.';
  }

  @override
  String get biRunningLabel => 'en cours';

  @override
  String get biSeatCentre => 'du temps total des places';

  @override
  String get biSeatClosed => 'Hors heures d\'ouverture';

  @override
  String get biSeatFree => 'Libre pendant les heures d\'ouverture';

  @override
  String biSeatHoursBlocked(String hours) {
    return '$hours heures-sièges bloquées';
  }

  @override
  String biSeatHoursFree(String hours) {
    return '$hours heures-sièges non réservées';
  }

  @override
  String get biSeatReserved => 'Réservé';

  @override
  String get biShareByLevel => 'Temps réservé par étage';

  @override
  String get biSort => 'Ordre';

  @override
  String get biSortAscending => 'Le plus bas d’abord';

  @override
  String get biSortDescending => 'Le plus élevé d’abord';

  @override
  String get biSortNatural => 'Comme listé';

  @override
  String get biSortUngrouped => 'Ordre (groupes seulement)';

  @override
  String get biSourceRestricted =>
      'Les données sources ne sont montrées qu’à ceux qui les gèrent.';

  @override
  String get biTitle => 'Analyse d’activité';

  @override
  String get biTotal => 'Total';

  @override
  String get biUnavailable => 'Cette analyse n’a pas pu être calculée.';

  @override
  String get biViewChart => 'Graphique';

  @override
  String get biViewClearMyDefault => 'Ne plus ouvrir ma vue par défaut';

  @override
  String get biViewClearTeamDefault => 'Retirer la vue par défaut de l’équipe';

  @override
  String biViewCopyName(String name) {
    return '$name (copie)';
  }

  @override
  String get biViewDashboard => 'Tableau de bord';

  @override
  String get biViewDelete => 'Supprimer';

  @override
  String biViewDeleteConfirm(String name) {
    return 'Supprimer la vue « $name » ?';
  }

  @override
  String get biViewDuplicate => 'Dupliquer comme ma vue';

  @override
  String get biViewForbidden => 'Vous ne pouvez pas modifier cette vue.';

  @override
  String get biViewInvalid =>
      'Ce nom ou cette vue ne peut pas être enregistré.';

  @override
  String get biViewMakeMyDefault => 'Ouvrir cette vue par défaut';

  @override
  String get biViewMakeTeamDefault => 'En faire la vue par défaut de l’équipe';

  @override
  String get biViewModified => 'modifiée depuis l’ouverture';

  @override
  String get biViewName => 'Nom';

  @override
  String get biViewNameTaken => 'Une vue de ce nom existe déjà.';

  @override
  String biViewPeriodFixed(String period) {
    return 'Toujours $period';
  }

  @override
  String get biViewPeriodMoves => 'La période suit le jour de l’ouverture';

  @override
  String get biViewRename => 'Renommer…';

  @override
  String get biViewSave => 'Enregistrer';

  @override
  String get biViewSaveAs => 'Enregistrer comme nouvelle vue…';

  @override
  String get biViewScopePrivate => 'Moi seulement';

  @override
  String get biViewScopeTeam => 'L’équipe';

  @override
  String get biViewStale =>
      'Quelqu’un a enregistré cette vue depuis que vous l’avez ouverte. La liste a été relue ; réessayez.';

  @override
  String get biViewStandard => 'Vue standard';

  @override
  String get biViewTable => 'Tableau';

  @override
  String get biViewUnreadable =>
      'Cette vue ne peut pas être ouverte ici : elle a été enregistrée sous une forme que cette version ne lit pas, ou aucune de ses analyses ne vous est accessible.';

  @override
  String get biViews => 'Vues';

  @override
  String get biViewsMine => 'Mes vues';

  @override
  String get biViewsTeam => 'Vues de l’équipe';

  @override
  String get biVsPrevious => 'vs période précédente';

  @override
  String get biVsYearAgo => 'vs l\'an dernier';

  @override
  String get billAccessorySupplements => 'Suppléments d\'accessoires';

  @override
  String get billBalance => 'Solde';

  @override
  String billCreditNoteCard(String number) {
    return 'Avoir $number';
  }

  @override
  String get billCreditNoteDue =>
      'L\'espace vous doit ce montant — rien à payer de votre côté.';

  @override
  String get billCreditNoteRefunded => 'L\'espace vous a remboursé ce montant.';

  @override
  String billEntitlement(int used, int included, int openDays) {
    return '$used demi-journées facturées sur $included ($openDays jours d\'ouverture)';
  }

  @override
  String billInvoiceCard(String number) {
    return 'Facture $number';
  }

  @override
  String get billInvoicePaid => 'Déjà réglé';

  @override
  String get billInvoiceRemaining => 'Restant dû';

  @override
  String get billInvoiceTotal => 'Total de la facture';

  @override
  String get billOpenPositions => 'Postes en attente';

  @override
  String get billOutstanding => 'À régler';

  @override
  String billOverage(int extra) {
    return '$extra demi-journées supplémentaires';
  }

  @override
  String get billPackages => 'Forfaits de jours';

  @override
  String billParticipation(int pct) {
    return 'Participation $pct %';
  }

  @override
  String billParticipationMonth(String month, int pct) {
    return '$month $pct %';
  }

  @override
  String get billPaymentsCredits => 'Paiements et crédits';

  @override
  String get billPdfExport => 'Exporter la facture en PDF';

  @override
  String get billPdfTitle => 'Facture mensuelle';

  @override
  String get billPendingBadge => 'en attente de validation';

  @override
  String get billServices => 'Services consommés';

  @override
  String get billServicesTotal => 'Total des services';

  @override
  String get billSettled => 'Réglé';

  @override
  String billSubscription(int pct) {
    return 'Abonnement $pct %';
  }

  @override
  String billSubscriptionMonth(String month, int pct) {
    return 'Abonnement $month $pct %';
  }

  @override
  String get billingAddBand => 'Ajouter un palier';

  @override
  String get billingAddLevel => 'Ajouter un niveau';

  @override
  String get billingAddPackage => 'Ajouter un forfait';

  @override
  String get billingAdvanceDays => 'Jours avant le début du mois';

  @override
  String get billingAllowCustom => 'Autoriser une valeur libre négociée';

  @override
  String get billingBandFee => 'Tarif mensuel';

  @override
  String billingBandFrom(int from) {
    return 'dès $from %';
  }

  @override
  String get billingBandOverage => 'Dépassement';

  @override
  String get billingBandTo => 'Jusqu\'à %';

  @override
  String get billingBandsInvalid =>
      'Les paliers doivent croître et se terminer à 100 %.';

  @override
  String get billingFeeBands => 'Paliers tarifaires';

  @override
  String get billingLevelValue => 'Niveau (1–100)';

  @override
  String get billingLevels => 'Niveaux d\'abonnement';

  @override
  String get billingNewPackage => 'Nouveau forfait';

  @override
  String get billingPackageDays => 'Jours';

  @override
  String get billingPackageName => 'Nom';

  @override
  String get billingPackagePrice => 'Prix';

  @override
  String billingPackageSummary(int days, String price) {
    return '$days jours · $price';
  }

  @override
  String get billingPackages => 'Forfaits de jours';

  @override
  String get billingPackagesHint =>
      'Les membres au plan forfait les achètent quand leurs jours sont épuisés.';

  @override
  String billingPricesVatHint(String rate) {
    return 'Les prix sont TTC — la TVA $rate (taux par défaut de l’espace) est incluse.';
  }

  @override
  String get billingRemoveBand => 'Supprimer le palier';

  @override
  String get billingRulesSaved => 'Calendrier de facturation enregistré.';

  @override
  String get billingRulesSubtitle =>
      'Quand partent les factures d’abonnement et de fin de mois';

  @override
  String get billingRulesTitle => 'Calendrier de facturation';

  @override
  String get billingSaved => 'Enregistré.';

  @override
  String get billingSubscriptionAuto => 'Émettre automatiquement';

  @override
  String get billingSubscriptionOff =>
      'Activez « Factures d’abonnement » dans Fonctionnalités pour l’utiliser.';

  @override
  String get billingSubscriptionSection => 'Abonnement, à l’avance';

  @override
  String billingSubscriptionWhen(String day, String month) {
    return 'Émise le $day pour $month';
  }

  @override
  String billingTariffVatHint(String rate) {
    return 'Les prix sont TTC — la TVA $rate (taux des paliers) est incluse.';
  }

  @override
  String get billingTitle => 'Facturation';

  @override
  String get billingUsageAuto => 'Émettre automatiquement';

  @override
  String get billingUsageOff =>
      'Activez « Factures de fin de mois » dans Fonctionnalités pour l’utiliser.';

  @override
  String get billingUsageSection => 'Le mois qui vient de finir';

  @override
  String get billingUsageWhenZero => 'Même s’il n’y a rien à payer';

  @override
  String get billingUsageWhenZeroHint =>
      'Envoie un document à zéro, comme confirmation que l’abonnement a couvert tout le mois.';

  @override
  String get blockPersonAction => 'Bloquer cette personne';

  @override
  String blockPersonConfirm(String name) {
    return 'Bloquer $name ? Vous ne vous verrez plus et ne pourrez plus vous joindre. Vous pouvez annuler dans Moi.';
  }

  @override
  String get blockPersonDone => 'Bloqué.';

  @override
  String get blockedPeopleEmpty => 'Vous n\'avez bloqué personne.';

  @override
  String get blockedPeopleHint =>
      'Une personne bloquée ne peut ni vous voir ni vous écrire, et vous ne pouvez ni la voir ni la joindre.';

  @override
  String get blockedPeopleTitle => 'Personnes bloquées';

  @override
  String get bookAccountCode => 'Numéro de compte';

  @override
  String get bookAccountName => 'Intitulé du compte';

  @override
  String get bookAccountPosting => 'Reçoit des écritures';

  @override
  String get bookAuthorityExternal => 'Logiciel externe';

  @override
  String get bookAuthorityLocal => 'DesKilo tient le livre';

  @override
  String get bookAuthorityPre => 'Pré-comptabilité';

  @override
  String get bookBasisAccrual => 'Engagements';

  @override
  String get bookBasisCash => 'Encaissements';

  @override
  String get bookChartSuggest => 'Ajouter les comptes suggérés à vérifier';

  @override
  String bookChartTitle(String site) {
    return 'Plan comptable · $site';
  }

  @override
  String get bookCurrency => 'Devise de tenue';

  @override
  String bookEffectiveFrom(String date) {
    return 'En vigueur à partir du $date';
  }

  @override
  String get bookExternalSystem => 'Logiciel qui fait foi';

  @override
  String bookFiscalPreview(String label, String start, String end) {
    return 'Exercice $label : $start – $end';
  }

  @override
  String get bookFiscalStart => 'L’exercice commence le';

  @override
  String get bookIssuer => 'Émetteur';

  @override
  String get bookMappingsTitle => 'Le compte de chaque écriture';

  @override
  String get bookProblemCurrency =>
      'Cette devise n’a pas de nombre de décimales vérifié.';

  @override
  String get bookProblemExternal =>
      'Indiquez le logiciel externe qui tient les livres officiels.';

  @override
  String get bookProblemFiscal =>
      'Un exercice commence un jour que chaque année possède (jamais le 29 février).';

  @override
  String bookProblemUnmapped(String roles) {
    return 'Associez ces comptes avant de démarrer un livre local : $roles.';
  }

  @override
  String get bookRoleBank => 'Banque';

  @override
  String get bookRoleCustomers => 'Clients (créances)';

  @override
  String get bookRoleExpenses => 'Charges';

  @override
  String get bookRoleRevenue => 'Produits';

  @override
  String get bookRoleVatOutput => 'TVA collectée';

  @override
  String get bookSaveFailed =>
      'Le livre n’a pas été enregistré. Vérifiez la connexion et réessayez.';

  @override
  String get bookSaved => 'Livre enregistré';

  @override
  String get bookSheetTitle => 'Livre comptable';

  @override
  String get bookStale =>
      'Quelqu’un a enregistré ce livre depuis que vous l’avez ouvert. Fermez et rouvrez pour voir sa version.';

  @override
  String get bookTileEmpty =>
      'Aucun livre : DesKilo tient les soldes des membres et les factures (pré-comptabilité).';

  @override
  String get bookTypeAsset => 'Actif';

  @override
  String get bookTypeEquity => 'Capitaux propres';

  @override
  String get bookTypeExpense => 'Charge';

  @override
  String get bookTypeIncome => 'Produit';

  @override
  String get bookTypeLiability => 'Passif';

  @override
  String bookingCheckedInAtUntil(String space, String until) {
    return 'Pointé sur $space jusqu\'à $until.';
  }

  @override
  String get bookingCheckedInElsewhere =>
      'Vous êtes pointé ailleurs — partez d\'abord là-bas.';

  @override
  String bookingCheckedInUntil(String until) {
    return 'Pointé jusqu\'à $until.';
  }

  @override
  String get bookingGateBlocked => 'Non réservable ainsi';

  @override
  String bookingHorizonError(int days) {
    return 'Trop loin — les réservations sont ouvertes $days jours à l\'avance.';
  }

  @override
  String get bookingMembershipPaused =>
      'Votre adhésion est suspendue — un administrateur la réactive dans Membres.';

  @override
  String get bookingModeCheckInNow => 'S\'installer maintenant';

  @override
  String get bookingMoreOptions => 'Plus d\'options';

  @override
  String get bookingNoLongerCheckedIn =>
      'Cette réservation n\'est plus en cours — elle a été clôturée entre-temps.';

  @override
  String get bookingNotAMember =>
      'Vous n\'êtes plus membre de cet espace — demandez une invitation à un administrateur.';

  @override
  String get bookingOnePlace =>
      'Vous avez déjà une réservation sur cette période — une place à la fois.';

  @override
  String get bookingOpenDetails => 'Détails';

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
  String get bookingOverlapsAnother =>
      'La place est déjà réservée pendant une partie de ce créneau.';

  @override
  String get bookingPastError =>
      'Cette réservation est entièrement dans le passé.';

  @override
  String bookingRecordedPastSpaceWhen(String space, String when) {
    return '$space enregistré : $when. Cette période est déjà passée : la réservation est conservée comme une visite passée.';
  }

  @override
  String bookingRecordedPastWhen(String when) {
    return 'Enregistré : $when. Cette période est déjà passée : la réservation est conservée comme une visite passée.';
  }

  @override
  String get bookingRecoveryBanner =>
      'Une de vos demandes de réservation est restée sans réponse.';

  @override
  String get bookingRecoveryBannerAction => 'Vérifier';

  @override
  String get bookingRecoveryCheck => 'Vérifier le résultat';

  @override
  String get bookingRecoveryCommitted =>
      'La réservation existe — une seule, issue de votre demande d\'origine.';

  @override
  String get bookingRecoveryDiscard => 'Abandonner';

  @override
  String get bookingRecoveryInProgress =>
      'Le serveur traite encore cette demande. Vérifiez à nouveau dans un instant.';

  @override
  String get bookingRecoveryNotCommitted =>
      'Rien n\'a été réservé pour cette demande. Vous pouvez la reprendre telle quelle, ou l\'abandonner.';

  @override
  String get bookingRecoveryNotSaved =>
      'Cet appareil n\'a pas pu enregistrer votre demande de réservation ; rien n\'a été envoyé. Libérez de l\'espace ou réessayez.';

  @override
  String get bookingRecoveryResume => 'Reprendre la même demande';

  @override
  String get bookingRecoveryResumed =>
      'Reprise : votre demande d\'origine a été réservée une seule fois.';

  @override
  String get bookingRecoverySpaceFallback => 'L\'espace choisi';

  @override
  String get bookingRecoveryTitle => 'Votre demande de réservation';

  @override
  String get bookingRecoveryUnavailable =>
      'Le serveur n\'a pas pu être interrogé. Rien n\'a changé ; réessayez.';

  @override
  String get bookingRecoveryUnknown =>
      'La connexion a été coupée après l\'envoi de votre demande. La réservation existe peut-être, peut-être pas : vérifiez avant de réserver à nouveau.';

  @override
  String get bookingRecoveryUnresolved =>
      'Le serveur ne conserve plus de trace de cette demande et ne peut rien dire. Vérifiez vos réservations avant de réserver à nouveau.';

  @override
  String get bookingRecoveryView => 'Voir la réservation';

  @override
  String bookingRecoveryWindow(String space, String from, String to) {
    return '$space · $from – $to';
  }

  @override
  String bookingReservedSpaceWhen(String space, String when) {
    return '$space réservé : $when.';
  }

  @override
  String bookingReservedWhen(String when) {
    return 'Réservé : $when.';
  }

  @override
  String get bookingSameDayError =>
      'Une réservation se termine le jour où elle commence — réservez le lendemain séparément.';

  @override
  String get bookingSpaceChainTaken =>
      'Cet espace, ou un espace qui le contient, est déjà réservé sur cette période.';

  @override
  String bookingTooLongError(int minutes) {
    return 'Trop long — une réservation dure au plus $minutes minutes.';
  }

  @override
  String bookingTooShortError(int minutes) {
    return 'Trop court — une réservation dure au moins $minutes minutes.';
  }

  @override
  String get bookingWalkUpTodayError =>
      'Un check-in spontané doit commencer aujourd\'hui.';

  @override
  String get bootFailedBody =>
      'Le serveur ou le stockage sécurisé de cet appareil n\'a pas répondu. Rien n\'a été modifié. Fermez l\'application et rouvrez-la ; si cela se reproduit, vérifiez le réseau.';

  @override
  String get bootFailedTitle => 'DesKilo n\'a pas pu démarrer';

  @override
  String get bootSlowBody =>
      'Il continue d\'essayer. Si rien ne se passe, fermez l\'application et rouvrez-la.';

  @override
  String get bootSlowTitle =>
      'Le démarrage prend plus de temps que d\'habitude';

  @override
  String brandColorRefused(String color, String pair) {
    return 'La couleur $color n’a pas été appliquée : $pair serait illisible.';
  }

  @override
  String get buyPackageButton => 'Acheter un forfait';

  @override
  String buyPackageDays(int days) {
    return '$days jours';
  }

  @override
  String get buyPackageDone => 'Jours ajoutés — profitez-en.';

  @override
  String get buyPackageNone => 'Aucun forfait disponible pour l\'instant.';

  @override
  String get buyPackageTitle => 'Acheter un forfait';

  @override
  String calendarAgendaEmpty(int days) {
    return 'Rien de prévu dans les $days prochains jours.';
  }

  @override
  String calendarAgendaRange(int days) {
    return '$days prochains jours';
  }

  @override
  String get calendarAllLevels => 'Tous les étages';

  @override
  String get calendarCancelFollowing => 'Annuler celle-ci et les suivantes';

  @override
  String get calendarCancelOccurrence => 'Annuler cette occurrence';

  @override
  String get calendarClosedDay => 'Fermé';

  @override
  String calendarClosedDayReason(String reason) {
    return 'Fermé — $reason';
  }

  @override
  String get calendarDay => 'Jour';

  @override
  String get calendarDayEmpty => 'Rien ce jour-là.';

  @override
  String calendarDueTitle(String number) {
    return 'Échéance · $number';
  }

  @override
  String get calendarEventActionApproved => 'approuvée';

  @override
  String get calendarEventActionCancelled => 'annulée';

  @override
  String get calendarEventActionCreated => 'créée';

  @override
  String get calendarEventActionModified => 'modifiée';

  @override
  String get calendarEventActionRefused => 'refusé';

  @override
  String get calendarEventActionRejected => 'refusée';

  @override
  String get calendarEventActionSubmitted => 'soumise';

  @override
  String get calendarEventActionValidated => 'validé';

  @override
  String get calendarEventStatusExpired => 'expiré';

  @override
  String get calendarEventStatusPending => 'en attente de confirmation';

  @override
  String get calendarEventStatusRejected => 'refusé';

  @override
  String calendarEventTitle(String label) {
    return 'Alerte : $label';
  }

  @override
  String get calendarEveryoneTab => 'Tout le monde';

  @override
  String get calendarGroupActivity => 'Alertes et messages';

  @override
  String get calendarGroupBookings => 'Réservations et présence';

  @override
  String get calendarGroupMoney => 'Finances';

  @override
  String calendarItemCount(int count) {
    return '$count éléments';
  }

  @override
  String get calendarKindCheckIn => 'Pointages';

  @override
  String get calendarKindCheckOut => 'Départs';

  @override
  String get calendarKindConsumption => 'Consommations';

  @override
  String get calendarKindDue => 'Échéances';

  @override
  String get calendarKindEvent => 'Alertes';

  @override
  String get calendarKindInvoice => 'Factures';

  @override
  String get calendarKindMessage => 'Messages';

  @override
  String get calendarKindPayment => 'Paiements';

  @override
  String get calendarKindReminder => 'Rappels';

  @override
  String get calendarKindReservation => 'Réservations';

  @override
  String get calendarKindScheduled => 'Dépenses programmées';

  @override
  String get calendarKindValidation => 'Validations';

  @override
  String calendarLevelCollapsed(String level) {
    return '$level, réduit';
  }

  @override
  String calendarLevelExpanded(String level) {
    return '$level, déplié';
  }

  @override
  String get calendarListView => 'Vue liste';

  @override
  String calendarLockedKinds(String kinds) {
    return 'Non visible pour vous pour ce membre : $kinds';
  }

  @override
  String get calendarMemberMe => 'Moi';

  @override
  String get calendarMineTab => 'Les miennes';

  @override
  String get calendarNext => 'Suivant';

  @override
  String get calendarNextMonth => 'Mois suivant';

  @override
  String get calendarNoReservations => 'Aucune réservation ce jour-là.';

  @override
  String get calendarNothingHere => 'Rien à ces dates.';

  @override
  String get calendarPrevious => 'Précédent';

  @override
  String get calendarPreviousMonth => 'Mois précédent';

  @override
  String get calendarRange => 'Période';

  @override
  String get calendarReservationActions => 'Actions de la réservation';

  @override
  String calendarScheduledTitle(String name) {
    return 'Dépense programmée · $name';
  }

  @override
  String get calendarShowOnPlan => 'Voir sur le plan';

  @override
  String get calendarTimelineAllEmpty =>
      'Aucune réservation à aucun étage ce jour-là.';

  @override
  String get calendarTimelineEmpty =>
      'Aucune réservation à cet étage ce jour-là.';

  @override
  String get calendarTimelineView => 'Vue chronologique';

  @override
  String get calendarToday => 'Aujourd\'hui';

  @override
  String get calendarTomorrow => 'Demain';

  @override
  String calendarValidationRefused(String what) {
    return 'Refusé : $what';
  }

  @override
  String calendarValidationValidated(String what) {
    return 'Validé : $what';
  }

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarViewAlerts => 'Alertes';

  @override
  String get calendarViewMonth => 'Mois';

  @override
  String get calendarViewWeek => 'Semaine';

  @override
  String get calendarWeekEmpty => 'Rien cette semaine.';

  @override
  String get calendarWhoCanSee => 'Qui peut voir ceci';

  @override
  String get calendarYesterday => 'Hier';

  @override
  String get capabilityBrowserPrefer => 'Préférer';

  @override
  String get capabilityBrowserRequire => 'Exiger';

  @override
  String get capabilityBrowserTitle => 'Parcourir les fonctionnalités';

  @override
  String get capabilityCreditPacks => 'Carnets';

  @override
  String get capabilityCustomMemberForm =>
      'Formulaire d\'adhésion personnalisé';

  @override
  String get capabilityMultiApproval => 'Deux validations ou plus';

  @override
  String get capabilityOpeningHours => 'Horaires d\'ouverture';

  @override
  String get capabilityPayAsYouGo => 'Paiement à l\'usage';

  @override
  String get capabilityRefundApprovals =>
      'Deux validations pour les remboursements';

  @override
  String get capabilityStateConditional =>
      'Activé seulement si ses prérequis le sont';

  @override
  String get capabilityStateDisabled => 'Désactivé';

  @override
  String get capabilityStateEnabled => 'Activé';

  @override
  String get capabilityStateIncompatible => 'Inapplicable ici';

  @override
  String get capabilityStateLocalInput => 'Demande d’abord une valeur locale';

  @override
  String get capabilityStateUnknown => 'Inconnu';

  @override
  String get capabilityStateUnspecified => 'Non défini par ce modèle';

  @override
  String get capabilitySubscriptionPlans => 'Formules d\'abonnement';

  @override
  String capacityKpiAsOf(String time) {
    return 'Calculé $time';
  }

  @override
  String get capacityKpiDefinition =>
      'Heures-places réservées pendant les heures d\'ouverture, divisées par les heures-places offertes : chaque place multipliée par les heures d\'ouverture des jours ouverts, moins les jours de fermeture et les blocages de places. Un bureau, une salle ou un niveau entier compte chacune de ses places une fois ; les réservations annulées ne comptent pas.';

  @override
  String get capacityKpiExplain => 'Comment est-ce calculé ?';

  @override
  String get capacityKpiForbidden =>
      'Vous ne pouvez pas consulter les chiffres de capacité de cet espace.';

  @override
  String capacityKpiHistory(String date) {
    return 'Historique enregistré depuis le $date';
  }

  @override
  String capacityKpiHistorySince(String date) {
    return 'Compté à partir du $date, début de l\'historique de cet espace ; le temps antérieur n\'est pas connu et n\'est pas compté.';
  }

  @override
  String get capacityKpiKnownZero => 'Mesuré : rien n\'a été réservé.';

  @override
  String capacityKpiNotRecorded(String date) {
    return 'Cette période précède le début de l\'historique de l\'espace, le $date : rien n\'est enregistré à compter.';
  }

  @override
  String capacityKpiOutside(String hours) {
    return 'Réservé hors des heures offertes : $hours heures-places, hors du ratio';
  }

  @override
  String capacityKpiOverlap(String hours) {
    return 'Réservé deux fois en même temps : $hours heures-places, comptées une fois';
  }

  @override
  String capacityKpiPhysical(String hours) {
    return 'Capacité physique : $hours heures-places';
  }

  @override
  String capacityKpiRatio(String reserved, String offered) {
    return '$reserved sur $offered heures-places réservées';
  }

  @override
  String get capacityKpiRetry => 'Réessayer';

  @override
  String capacityKpiRooms(String count, String reserved, String offered) {
    return 'Salles sans place : $count, $reserved sur $offered heures-salles réservées';
  }

  @override
  String get capacityKpiRoomsToday =>
      'Les salles sans place sont lues telles qu\'elles sont aujourd\'hui.';

  @override
  String get capacityKpiTitle => 'Occupation des places';

  @override
  String get capacityKpiUnattributed =>
      'Certaines réservations de la période visent un emplacement qui n\'existe plus ; elles ne sont pas comptées.';

  @override
  String get capacityKpiUnavailable =>
      'L\'occupation des places n\'a pas pu être calculée.';

  @override
  String get capacityKpiUndefined =>
      'Aucun temps de place n\'a été offert sur cette période : il n\'y a pas d\'occupation à montrer.';

  @override
  String get captureRecordingHidden =>
      'Masqué pendant l’enregistrement ou la recopie de votre écran.';

  @override
  String get captureWebNotice =>
      'Votre navigateur ne peut pas empêcher les captures d’écran de cette conversation.';

  @override
  String get carnetAdd => 'Ajouter un carnet';

  @override
  String carnetBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count demi-journées restantes',
      one: '1 demi-journée restante',
      zero: 'Plus de demi-journée',
    );
    return '$_temp0';
  }

  @override
  String get carnetHalfDays => 'Demi-journées';

  @override
  String get carnetName => 'Nom';

  @override
  String get carnetPrice => 'Prix';

  @override
  String get carnetSell => 'Vendre un carnet';

  @override
  String get carnetSold =>
      'Carnet vendu — facturé une fois sur la facture du mois.';

  @override
  String carnetSummary(int halfDays, String price) {
    return '$halfDays demi-journées · $price';
  }

  @override
  String get carnetValidity => 'Validité (mois, vide = n\'expire jamais)';

  @override
  String get carnetsEmpty => 'Aucun carnet pour l\'instant.';

  @override
  String get carnetsTitle => 'Carnets';

  @override
  String get coOwnerAction => 'Copropriété';

  @override
  String get coOwnerActivate => 'Promouvoir propriétaire maintenant';

  @override
  String get coOwnerActive =>
      'Copropriétaire actif — permissions de propriétaire immédiates, succession automatique';

  @override
  String get coOwnerNone => 'Aucune copropriété';

  @override
  String get coOwnerPassive =>
      'Successeur — devient propriétaire à l\'activation ou au départ du propriétaire';

  @override
  String coloursApplied(String hex) {
    return '$hex appliquée. L’application en dérive ses thèmes.';
  }

  @override
  String get coloursDark => 'Sombre';

  @override
  String get coloursHexHint =>
      'Six chiffres hexadécimaux. Laissez vide pour les couleurs du produit.';

  @override
  String get coloursHexLabel => 'Couleur';

  @override
  String get coloursIntro =>
      'Une couleur, et l’application en dérive ses thèmes clair et sombre. Tout le reste conserve la palette du produit.';

  @override
  String get coloursLight => 'Clair';

  @override
  String coloursMalformed(String text) {
    return '$text n’est pas une couleur : écrivez-la #RRGGBB.';
  }

  @override
  String get coloursNeverTheirs =>
      'La marque DesKilo, les couleurs des états de place et le bandeau de production appartiennent au produit, dans chaque espace.';

  @override
  String get coloursPreview => 'Ce que cela donne';

  @override
  String coloursRefused(String pair) {
    return 'Refusée : $pair serait illisible avec cette couleur.';
  }

  @override
  String get coloursReset => 'Couleurs du produit';

  @override
  String get coloursResetDone => 'Les couleurs du produit sont de retour.';

  @override
  String get coloursRooms => 'Couleurs des salles';

  @override
  String get coloursRoomsAdd => 'Ajouter une couleur';

  @override
  String coloursRoomsOwn(int n) {
    return '$n couleurs à vous, dans cet ordre.';
  }

  @override
  String get coloursRoomsProduct =>
      'La palette du produit. Ajoutez une couleur pour utiliser la vôtre.';

  @override
  String coloursRoomsSaved(int n) {
    return '$n couleurs de salles enregistrées.';
  }

  @override
  String get coloursSaveFailed =>
      'La couleur n’a pas pu être enregistrée. Rien n’a changé.';

  @override
  String get coloursTitle => 'Couleurs';

  @override
  String coloursTooMany(int most) {
    return 'Le plan peint au plus $most couleurs de salles.';
  }

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonOk => 'OK';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonSaveFailed => 'Impossible d\'enregistrer le fichier.';

  @override
  String commonSavedTo(String path) {
    return 'Enregistré dans $path';
  }

  @override
  String get commonShare => 'Partager';

  @override
  String get commonStart => 'Démarrer';

  @override
  String get compareAdd => 'Ajouter à la comparaison';

  @override
  String get compareAll => 'Tous les réglages';

  @override
  String compareCount(String shown, String total) {
    return '$shown sur $total réglages';
  }

  @override
  String get compareCurrencies => 'Devises différentes : non comparable';

  @override
  String get compareDefault => 'Par défaut';

  @override
  String get compareDifferences => 'Différences';

  @override
  String get compareEmpty => 'Vide';

  @override
  String get compareExport => 'Exporter vers Excel';

  @override
  String get compareExported => 'Classeur enregistré.';

  @override
  String get compareInherits => 'Garde celui de l\'espace';

  @override
  String compareLimit(String count) {
    return 'Jusqu\'à $count modèles peuvent être comparés. Retirez-en un d\'abord.';
  }

  @override
  String get compareLocal => 'À définir localement';

  @override
  String get compareMissing => 'Absent de ce modèle';

  @override
  String get compareNo => 'Non';

  @override
  String get compareNotCarried => 'Non transporté';

  @override
  String get compareNothing => 'Aucun réglage ne diffère.';

  @override
  String compareOpen(String count) {
    return 'Comparer ($count)';
  }

  @override
  String get compareRemove => 'Retirer de la comparaison';

  @override
  String get compareSearch => 'Chercher un réglage';

  @override
  String get compareTitle => 'Comparer les modèles';

  @override
  String get compareUnavailable =>
      'Ces modèles n\'ont pas pu être lus pour les comparer. Rien n\'est affirmé.';

  @override
  String get compareUnknown => 'Inconnu';

  @override
  String get compareYes => 'Oui';

  @override
  String get composerAttach => 'Joindre une référence';

  @override
  String composerCharsLeft(int count) {
    return '$count caractères restants';
  }

  @override
  String get composerDraftKept => 'Brouillon conservé';

  @override
  String get composerMention => 'Mentionner quelqu’un';

  @override
  String get connectionCancelled =>
      'Le compte a changé entre-temps ; cette réponse a été ignorée.';

  @override
  String get connectionChangedIdentity =>
      'Ce serveur n’est plus celui que vous avez connecté. Ses actions sont suspendues jusqu’à une nouvelle vérification.';

  @override
  String get connectionChecking => 'Vérification…';

  @override
  String get connectionCurrentServer =>
      'C’est le serveur que cette application utilise déjà.';

  @override
  String get connectionDenied =>
      'Ce serveur a refusé le compte. Vérifiez vos identifiants, ou déconnectez-le.';

  @override
  String get connectionExpired =>
      'Votre connexion à ce serveur a expiré. Reconnectez-vous à ce serveur.';

  @override
  String get connectionInvalidEndpoint =>
      'Cette adresse ou cette clé n’est pas celle d’un serveur valide.';

  @override
  String get connectionMalformed =>
      'Ce serveur a répondu quelque chose que cette application ne sait pas lire.';

  @override
  String get connectionNotConnected =>
      'Ce serveur n’est pas connecté sur cet appareil.';

  @override
  String get connectionRetry => 'Réessayer';

  @override
  String get connectionSessionNotSaved =>
      'L’action a été effectuée, mais cet appareil n’a pas pu enregistrer la connexion au serveur. Il vous faudra peut-être vous reconnecter.';

  @override
  String get connectionSignInAgain => 'Se reconnecter';

  @override
  String get connectionUnavailable =>
      'Ce serveur ne répond pas pour le moment. Vos autres serveurs ne sont pas concernés.';

  @override
  String get connectionUnknownOutcome =>
      'La connexion s’est interrompue après l’envoi de la demande. Elle a peut-être été appliquée : vérifiez avant de réessayer.';

  @override
  String get connectionUnsupported =>
      'Cette version du serveur ne peut pas être connectée depuis cette application. Mettez l’application à jour, ou demandez à l’opérateur du serveur de le mettre à jour.';

  @override
  String get connectionUsable => 'Connecté';

  @override
  String get connectionVerifyAgain => 'Vérifier à nouveau';

  @override
  String get consentAccept => 'Accepter et continuer';

  @override
  String consentAcceptedOn(String date, String version) {
    return 'Accepté le $date ($version)';
  }

  @override
  String get consentCheckbox =>
      'J\'ai lu ce texte et j\'accepte la façon dont DesKilo traite mes données.';

  @override
  String get consentControllerBody =>
      'Chaque espace est exploité par son propriétaire — votre communauté — qui décide des membres, des prix et des prestataires de paiement. L\'app est un logiciel libre (AGPL-3.0-or-later) et publiée par Florian Dittgen (Allemagne) ; le backend est Supabase dans l\'UE. Les paiements en ligne passent par le prestataire activé par le propriétaire (PayPal, Stripe, Mollie, Wero) selon ses conditions.';

  @override
  String get consentControllerTitle => 'Qui est responsable';

  @override
  String get consentIntro =>
      'Avant d\'utiliser DesKilo, voici ce que l\'app fait de vos données, qui peut les voir et ce que vous pouvez en faire. Deux minutes ; il n\'y a rien de plus.';

  @override
  String get consentNotBody =>
      'Ni traçage, ni analytique, ni publicité, ni vente ou partage de données. Les notifications push ne portent aucun contenu — seulement « vous avez un nouveau message » ; l\'app elle-même écrit le texte. La version F-Droid n\'a aucun service Google.';

  @override
  String get consentNotTitle => 'Ce que DesKilo ne fait jamais';

  @override
  String get consentReadInHelp => 'Lire dans l\'aide';

  @override
  String get consentReadOnWiki => 'Lire sur le wiki';

  @override
  String get consentRetentionBody =>
      'Tant que vous êtes membre. Quand vous partez et effacez, votre profil et vos messages disparaissent ; les pièces comptables (factures, paiements) restent la durée légale de conservation, par identifiant et non par nom.';

  @override
  String get consentRetentionTitle => 'Combien de temps';

  @override
  String get consentReviewBody =>
      'Ce texte reste disponible dans Réglages → Confidentialité et données, dans l\'aide de l\'app (Confidentialité) et dans le wiki du projet. Un changement du texte redemande votre acceptation.';

  @override
  String get consentReviewHint =>
      'Le texte que vous avez accepté, avec la date — relisez-le quand vous voulez.';

  @override
  String get consentReviewTitle => 'Relisez-le quand vous voulez';

  @override
  String get consentRightsBody =>
      'Accès, rectification, export (art. 20), effacement (art. 17) et opposition — chacun est un bouton dans Réglages → Confidentialité et données. Pour le reste : fdittgen@gmail.com. Vous pouvez retirer ce consentement à tout moment en quittant l\'espace et en effaçant vos données.';

  @override
  String get consentRightsTitle => 'Vos droits';

  @override
  String get consentTitle => 'Vos données, vos droits';

  @override
  String get consentUnavailable =>
      'Votre compte n\'a pas pu être chargé ; il n\'y a donc rien à accepter pour l\'instant.';

  @override
  String get consentVersion => 'Version';

  @override
  String get consentWhatBody =>
      'Votre compte (e-mail, nom affiché, mot de passe haché), votre profil tel que vous le remplissez (photo, statut, adresse, numéro WhatsApp — chacun facultatif), et ce que vous faites dans un espace : réservations et pointages, messages, dépenses et consommations, votre abonnement, factures et paiements. Tout est stocké dans l\'UE (Supabase, eu-central-1).';

  @override
  String get consentWhatTitle => 'Ce que DesKilo traite';

  @override
  String get consentWhoBody =>
      'L\'accès suit les rôles et est appliqué côté serveur : les réservations sont visibles de l\'espace (le plan montre l\'occupation) ; les messages seulement des personnes de la conversation, quel que soit leur rôle ; vos finances et votre accord commercial seulement de vous, des propriétaires et des admins qui détiennent la permission correspondante. Réglages → Confidentialité et données nomme les personnes et liste qui a réellement consulté.';

  @override
  String get consentWhoTitle => 'Qui peut voir quoi';

  @override
  String get consumptionAdd => 'Ajouter une consommation';

  @override
  String consumptionAddForMember(String name) {
    return 'Ajouter un service pour $name';
  }

  @override
  String get consumptionNoServices => 'Aucun service actif à enregistrer.';

  @override
  String get consumptionPeriodLabel => 'Période de facturation (AAAA-MM)';

  @override
  String get consumptionQuantity => 'Quantité';

  @override
  String get consumptionRecorded =>
      'Consommation enregistrée — en attente de confirmation.';

  @override
  String get consumptionRefusedInactive =>
      'Ce service n\'est plus proposé. Rien n\'a été enregistré.';

  @override
  String get consumptionRefusedPeriod =>
      'La période de facturation doit être un mois (AAAA-MM). Rien n\'a été enregistré.';

  @override
  String get consumptionRefusedQuantity =>
      'La quantité doit être comprise entre 1 et 999. Rien n\'a été enregistré.';

  @override
  String get consumptionRefusedStock =>
      'Stock insuffisant. Rien n\'a été enregistré.';

  @override
  String get consumptionService => 'Service';

  @override
  String get conversationAddPeople => 'Ajouter des membres';

  @override
  String get conversationAdmin => 'Admin';

  @override
  String get conversationArchive => 'Archiver';

  @override
  String get conversationArchived => 'Conversation archivée.';

  @override
  String get conversationEmpty => 'Pas encore de messages — dites bonjour !';

  @override
  String get conversationGroup => 'Groupe';

  @override
  String get conversationGroupInfo => 'Groupe';

  @override
  String get conversationLeave => 'Quitter le groupe';

  @override
  String get conversationLeaveConfirm =>
      'Quitter ce groupe ? Vous ne recevrez plus ses messages ; ce que vous avez déjà envoyé reste.';

  @override
  String get conversationLeft => 'Parti';

  @override
  String get conversationLoadEarlier => 'Charger les messages plus anciens';

  @override
  String get conversationMarkUnread => 'Marquer comme non lu';

  @override
  String conversationMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return '$_temp0';
  }

  @override
  String get conversationMute => 'Couper les notifications';

  @override
  String get conversationMutedBadge => 'Silencieuse';

  @override
  String get conversationPin => 'Épingler en haut';

  @override
  String get conversationRemove => 'Retirer';

  @override
  String get conversationSeeProfile => 'Voir le profil';

  @override
  String get conversationToday => 'Aujourd\'hui';

  @override
  String get conversationUnarchive => 'Sortir des archives';

  @override
  String get conversationUnknownMember => 'Membre';

  @override
  String get conversationUnmute => 'Réactiver les notifications';

  @override
  String get conversationUnpin => 'Désépingler';

  @override
  String get conversationYesterday => 'Hier';

  @override
  String get conversationYou => 'Vous';

  @override
  String get countryNameAT => 'Autriche';

  @override
  String get countryNameAU => 'Australie';

  @override
  String get countryNameBE => 'Belgique';

  @override
  String get countryNameBG => 'Bulgarie';

  @override
  String get countryNameCA => 'Canada';

  @override
  String get countryNameCH => 'Suisse';

  @override
  String get countryNameCY => 'Chypre';

  @override
  String get countryNameCZ => 'Tchéquie';

  @override
  String get countryNameDE => 'Allemagne';

  @override
  String get countryNameDK => 'Danemark';

  @override
  String get countryNameEE => 'Estonie';

  @override
  String get countryNameES => 'Espagne';

  @override
  String get countryNameFI => 'Finlande';

  @override
  String get countryNameFR => 'France';

  @override
  String get countryNameGB => 'Royaume-Uni';

  @override
  String get countryNameGR => 'Grèce';

  @override
  String get countryNameHR => 'Croatie';

  @override
  String get countryNameHU => 'Hongrie';

  @override
  String get countryNameIE => 'Irlande';

  @override
  String get countryNameIT => 'Italie';

  @override
  String get countryNameJP => 'Japon';

  @override
  String get countryNameLT => 'Lituanie';

  @override
  String get countryNameLU => 'Luxembourg';

  @override
  String get countryNameLV => 'Lettonie';

  @override
  String get countryNameMT => 'Malte';

  @override
  String get countryNameMX => 'Mexique';

  @override
  String get countryNameNL => 'Pays-Bas';

  @override
  String get countryNameNO => 'Norvège';

  @override
  String get countryNamePL => 'Pologne';

  @override
  String get countryNamePT => 'Portugal';

  @override
  String get countryNameRO => 'Roumanie';

  @override
  String get countryNameSE => 'Suède';

  @override
  String get countryNameSI => 'Slovénie';

  @override
  String get countryNameSK => 'Slovaquie';

  @override
  String get countryNameUS => 'États-Unis';

  @override
  String get courtesyHint =>
      'Imprimée devant votre nom sur les documents. « Aucune » n\'imprime que le nom.';

  @override
  String get courtesyHintManaged =>
      'Imprimée devant leur nom sur les documents. « Aucune » n\'imprime que le nom.';

  @override
  String get courtesyLabel => 'Formule d’appel';

  @override
  String get courtesyMr => 'Monsieur';

  @override
  String get courtesyMrs => 'Madame';

  @override
  String get courtesyNone => 'Aucune';

  @override
  String get customerCapacityBusiness => 'Professionnel';

  @override
  String get customerCapacityConsumer => 'Consommateur';

  @override
  String get customerCapacityExplainer =>
      'Ce client agit-il pour une activité professionnelle (société, entrepreneur individuel, association agissant comme telle) ou comme consommateur ? Cela décide des clauses de paiement imprimées sur la facture ; un numéro de TVA seul ne le décide pas. Non précisée : la valeur par défaut de l\'espace s\'applique.';

  @override
  String get customerCapacityLabel => 'Qualité du client';

  @override
  String get customerCapacityNotStated => 'Non précisée';

  @override
  String get customerCapacitySaveError =>
      'La qualité du client n\'a pas été enregistrée.';

  @override
  String get datevAccountsIntro =>
      'Votre comptable vous donne les numéros de conseil et de dossier. DATEV refuse un fichier dont les numéros ne correspondent pas — c’est ce qui l’empêche d’atterrir dans les comptes d’une autre société.';

  @override
  String get datevAccountsTitle => 'Export DATEV';

  @override
  String get datevClientNumber => 'Mandantennummer (numéro de dossier)';

  @override
  String get datevConsultantNumber => 'Beraternummer (numéro de conseil)';

  @override
  String get decisionSurfaceEmpty => 'Rien ne vous attend';

  @override
  String get decisionSurfaceEmptyDetail => 'Tout est traité.';

  @override
  String get defaultPeriodNone => 'Sans préférence (journée complète)';

  @override
  String get defaultPeriodTitle => 'Période de réservation par défaut';

  @override
  String get demoEntryAction => 'Explorer l\'espace de démonstration';

  @override
  String get demoEntryBody =>
      'Tout y est inventé : les personnes, les réservations et les factures sont créées pour la démonstration. Rien de ce que vous y faites n\'atteint un espace réel, rien ne quitte cet appareil, et aucun compte n\'est nécessaire. La réinitialisation le remet en état quand vous voulez.';

  @override
  String get demoEntryStart => 'Commencer';

  @override
  String get demoEntryTitle => 'Un espace où regarder';

  @override
  String get demoPersonaAdmin => 'Un administrateur';

  @override
  String get demoPersonaMember => 'Un membre';

  @override
  String get demoPersonaOwner => 'Le propriétaire';

  @override
  String get demoSessionBadge => 'Démo';

  @override
  String get demoSessionBadgeHint =>
      'Vous explorez un espace de démonstration. Rien ici ne quitte cet appareil.';

  @override
  String get demoSessionLeave => 'Quitter la démo';

  @override
  String get demoSessionReset => 'Réinitialiser la démo';

  @override
  String get demoSessionResetDone => 'La démo est revenue à son état initial.';

  @override
  String get demoSessionViewAs => 'Voir en tant que';

  @override
  String get deployEntityAccessories => 'Accessoires';

  @override
  String get deployEntityBookingRules => 'Règles de réservation';

  @override
  String get deployEntityBranding => 'Couleurs';

  @override
  String get deployEntityClosureDays => 'Jours de fermeture';

  @override
  String get deployEntityCreditProducts => 'Les carnets prépayés en vente';

  @override
  String get deployEntityDocumentDesign => 'Conception des documents';

  @override
  String get deployEntityDocumentLinks => 'Liens de documents';

  @override
  String get deployEntityFeatures => 'Fonctionnalités';

  @override
  String get deployEntityFieldDefinitions => 'Les questions de l\'espace';

  @override
  String get deployEntityFloorPlan => 'Plans (étages, places, images)';

  @override
  String get deployEntityIdentity => 'Identité et mentions légales';

  @override
  String get deployEntityInvitations => 'Modèles d\'invitation';

  @override
  String get deployEntityPackages => 'Forfaits';

  @override
  String get deployEntityPaymentInstructions => 'Instructions de paiement';

  @override
  String get deployEntityReminders => 'Règles de relance';

  @override
  String get deployEntityRoles => 'Matrice des rôles';

  @override
  String get deployEntityServices => 'Services';

  @override
  String get deployEntitySites => 'Sites';

  @override
  String get deployEntityTariffs => 'Tarifs';

  @override
  String get deployEntityValidationRules => 'Règles de validation';

  @override
  String get deployEntityVat => 'TVA';

  @override
  String get deployEntityWorkspaceRoles => 'Les rôles propres à l\'espace';

  @override
  String get deploymentConfirm => 'Déployer';

  @override
  String get deploymentConfirmBody =>
      'Ce que cet espace contient pour les entités cochées est remplacé par ce qu\'a le jumeau. Le journal garde le retour arrière.';

  @override
  String get deploymentConfirmTitleDev => 'Déployer dans cette DEV ?';

  @override
  String get deploymentConfirmTitleProd => 'Déployer dans cette PROD ?';

  @override
  String get deploymentDirectionToDev => 'Vers le développement';

  @override
  String get deploymentDirectionToProd => 'Vers la production';

  @override
  String get deploymentDone => 'Déployé. Le journal l\'a.';

  @override
  String get deploymentFlowFromDev => 'Depuis la DEV';

  @override
  String get deploymentFlowFromProd => 'Depuis la PROD';

  @override
  String get deploymentFlowToDev => 'Vers la DEV';

  @override
  String get deploymentFlowToProd => 'Vers la PROD';

  @override
  String get deploymentIntroFromDev =>
      'Vous êtes du côté production. Ce que vous cochez ci-dessous est tiré du jumeau de développement vers cet espace, après un aperçu.';

  @override
  String get deploymentIntroFromProd =>
      'Vous êtes du côté développement. Ce que vous cochez ci-dessous est tiré du jumeau de production vers cet espace, après un aperçu.';

  @override
  String get deploymentIntroToDev =>
      'Vous êtes du côté production. Ce que vous cochez ci-dessous est déployé vers le jumeau de développement, après un aperçu de ce qui change.';

  @override
  String get deploymentIntroToProd =>
      'Vous êtes du côté développement. Ce que vous cochez ci-dessous est déployé vers le jumeau de production, après un aperçu de ce qui change.';

  @override
  String get deploymentJournal => 'Journal';

  @override
  String get deploymentJournalEmpty => 'Rien n\'a encore été déployé.';

  @override
  String get deploymentKindConfiguration => 'Configuration';

  @override
  String get deploymentKindMasterData => 'Données de base';

  @override
  String get deploymentKindReports => 'Rapports';

  @override
  String get deploymentNeedsDevPermission =>
      'Déployer en développement demande la permission « Déployer en développement ».';

  @override
  String get deploymentNeedsProdPermission =>
      'Déployer en production demande la permission « Déployer en production ».';

  @override
  String get deploymentNoChange => 'Aucun changement';

  @override
  String get deploymentNoTwin =>
      'Cet espace n\'a pas de jumeau dont vous soyez membre.';

  @override
  String get deploymentNothingToDo =>
      'Les deux côtés sont déjà d\'accord sur ces entités.';

  @override
  String get deploymentPreviewToDev => 'Ce qui change côté développement';

  @override
  String get deploymentPreviewToProd => 'Ce qui change côté production';

  @override
  String get deploymentPullFromDev => 'Tirer depuis la DEV…';

  @override
  String get deploymentPullFromProd => 'Tirer depuis la PROD…';

  @override
  String get deploymentRequires => 'nécessite';

  @override
  String get deploymentRollback => 'Revenir en arrière';

  @override
  String get deploymentRolledBack => 'Retour arrière effectué.';

  @override
  String get deploymentRolledBackLabel => 'annulé';

  @override
  String get deploymentTitle => 'Déploiement';

  @override
  String get deploymentToDev => 'Déployer en DEV…';

  @override
  String get deploymentToProd => 'Déployer en PROD…';

  @override
  String get deskDetail => 'Table entière';

  @override
  String get deskSupplementLabel => 'Réservations de table';

  @override
  String get developerClear => 'Vider le journal';

  @override
  String get developerEmpty => 'Aucune entrée de journal pour l\'instant.';

  @override
  String get developerExport => 'Exporter le journal';

  @override
  String get developerExportReservations => 'Exporter les réservations';

  @override
  String get developerExportReservationsHint =>
      'Toutes les réservations et arrivées — passées, présentes et futures, tous les états — en CSV, pour analyse et débogage.';

  @override
  String get developerExportReservationsOwnHint =>
      'Vos propres réservations et arrivées, tous états, en CSV — exporter tout l’espace demande la permission d’export de données.';

  @override
  String get developerFilterAll => 'Tout';

  @override
  String get developerFilterErrors => 'Erreurs';

  @override
  String get developerFilterWarnings => 'Avertissements+';

  @override
  String get developerMode => 'Mode développeur';

  @override
  String get developerModeWorkspaceHint =>
      'S\'applique à tous les membres de cet espace.';

  @override
  String get developerTitle => 'Développeur';

  @override
  String get developmentBanner =>
      'Espace de développement — rien ici n\'est réel';

  @override
  String get developmentWatermark => 'DÉVELOPPEMENT';

  @override
  String get directoryApproximate => 'Position approximative de l’adresse';

  @override
  String get directoryCheckedIn => 'Sur place';

  @override
  String directoryCheckedInSeat(String seat) {
    return 'Sur place · $seat';
  }

  @override
  String get directoryClose => 'Fermer';

  @override
  String get directoryEmpty => 'Aucun membre pour l\'instant.';

  @override
  String directoryLastSeenDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Vu il y a $days jours',
      one: 'Vu il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String directoryLastSeenHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Vu il y a $hours heures',
      one: 'Vu il y a 1 heure',
    );
    return '$_temp0';
  }

  @override
  String directoryLastSeenMinutes(int minutes) {
    return 'Vu il y a $minutes min';
  }

  @override
  String get directoryLocate => 'Localiser sur la carte';

  @override
  String get directoryLocating => 'Localisation de l’adresse publique…';

  @override
  String get directoryLocationMissing =>
      'Position indisponible. Le propriétaire peut publier des coordonnées précises.';

  @override
  String get directoryNoUpcoming => 'Aucune réservation à venir';

  @override
  String get directoryOnline => 'En ligne';

  @override
  String get directoryOpenGroup => 'Ouvrir le groupe WhatsApp';

  @override
  String get directoryReservationsHeading => 'Réservations';

  @override
  String get directoryReservedNow => 'Réservé maintenant';

  @override
  String directoryReservedNowSeat(String seat) {
    return 'Réservé maintenant · $seat';
  }

  @override
  String get directoryReservedToday => 'Réservé aujourd\'hui';

  @override
  String get directoryTitle => 'Membres';

  @override
  String get directoryWhatsapp => 'Discuter sur WhatsApp';

  @override
  String get documentsAdd => 'Ajouter un document';

  @override
  String get documentsCategoryFinance => 'États financiers';

  @override
  String get documentsCategoryGuides => 'Guides et manuels';

  @override
  String get documentsCategoryLabel => 'Catégorie';

  @override
  String get documentsCategoryMinutes => 'Comptes rendus';

  @override
  String get documentsCategoryOther => 'Autres documents';

  @override
  String get documentsCategoryStatutes => 'Statuts et juridique';

  @override
  String get documentsDelete => 'Retirer le document ?';

  @override
  String get documentsEmpty =>
      'Aucun document. Liez vos statuts, guides et états depuis n\'importe quel drive.';

  @override
  String get documentsInvalid =>
      'Un document requiert un titre et un lien https://.';

  @override
  String get documentsProviderLabel => 'Stocké sur';

  @override
  String get documentsRoleAdmin => 'Admins et propriétaires';

  @override
  String get documentsRoleLabel => 'Visible par';

  @override
  String get documentsRoleMember => 'Tous les membres';

  @override
  String get documentsRoleOwner => 'Propriétaires uniquement';

  @override
  String get documentsTitle => 'Documents';

  @override
  String get documentsTitleLabel => 'Titre';

  @override
  String get documentsUrlHelper =>
      'Collez le lien de partage de votre drive — les droits d\'accès restent gérés là-bas.';

  @override
  String get documentsUrlLabel => 'Lien (https://…)';

  @override
  String get dunningAutomatic => 'Relances automatiques';

  @override
  String get dunningAutomaticHint =>
      'Une fois par jour, les factures dont l\'échéance enregistrée est dépassée passent d\'elles-mêmes au niveau de relance suivant — pour le montant restant dû, jamais pendant qu\'un paiement est en attente ou que la facture est suspendue. Les factures sans échéance enregistrée restent à votre main. Désactivé : vous envoyez chaque relance vous-même.';

  @override
  String get dunningBetweenDays => 'Jours entre les relances';

  @override
  String dunningDueChip(int level) {
    return 'Relance $level à envoyer';
  }

  @override
  String get dunningFirstAfterDays => 'Jours avant la première relance';

  @override
  String get dunningLevels => 'Nombre de niveaux de relance';

  @override
  String get dunningSaved => 'Règles de relance enregistrées.';

  @override
  String get dunningSettingsTitle => 'Règles de relance';

  @override
  String get eInvoiceGapBuyerLegalIdAdvisable =>
      'Le SIREN de l\'acheteur manque. Une plateforme agréée l\'utilise pour acheminer la facture : renseignez-le sur le profil de l\'adhérent avant de transmettre. Ce n\'est pas un refus — le fichier est valide sans lui.';

  @override
  String get eInvoiceGapMissingBuyerLegalId =>
      'L\'acheteur est une entreprise française sans SIREN — renseignez son identifiant légal sur le profil de l\'adhérent.';

  @override
  String get eInvoiceGapMixedNotSubjectLines =>
      'Une ligne hors champ (consigne) figure à côté de lignes taxées — la norme EN 16931 refuse ce mélange ; émettez la consigne sur un document séparé.';

  @override
  String get editorAccessoriesLabel => 'Accessoires';

  @override
  String get editorAddLevel => 'Ajouter un étage';

  @override
  String get editorAmenitiesLabel => 'Équipements';

  @override
  String get editorBackgroundImage => 'Image de fond';

  @override
  String get editorBackgroundRemove => 'Supprimer l\'image de fond';

  @override
  String get editorBackgroundReplace => 'Remplacer l\'image de fond';

  @override
  String get editorBackgroundSet => 'Définir l\'image de fond';

  @override
  String get editorBlockedLabel => 'Bloquée (maintenance)';

  @override
  String get editorBookableAsWhole => 'Réservable en entier';

  @override
  String get editorBookableAsWholeHint =>
      'Quelqu\'un peut la réserver en entier, avec tout ce qu\'elle contient.';

  @override
  String get editorCanvasSemantics => 'Zone de dessin du plan';

  @override
  String get editorChairLabel => 'Type de chaise';

  @override
  String get editorDeleteElementConfirm =>
      'Supprimer cet élément ? Tout ce qui y est placé sera aussi supprimé.';

  @override
  String get editorDeleteElementConfirmAudit =>
      'Supprimer cet élément ? Tout ce qui y est placé est également retiré. Les réservations qui y font référence gardent un instantané texte pour les audits ; les réservations ouvertes sont annulées.';

  @override
  String get editorDeleteLevelConfirm =>
      'Supprimer cet étage ? Tous les bureaux, tables et places qu\'il contient seront supprimés.';

  @override
  String get editorDeleteLevelConfirmAudit =>
      'Supprimer ce niveau ? Tous les bureaux, tables et places qui s\'y trouvent sont retirés. Les réservations qui y font référence gardent un instantané texte pour les audits ; les réservations ouvertes sont annulées.';

  @override
  String get editorDeskFull => 'Plus de place sur cette table.';

  @override
  String get editorDeskNameDefault => 'Table';

  @override
  String get editorDeskNameLabel => 'Nom de la table';

  @override
  String get editorDeskProperties => 'Table';

  @override
  String get editorDuplicate => 'Dupliquer';

  @override
  String get editorEmptyFloorAction => 'Dessiner la première pièce';

  @override
  String get editorEmptyFloorBody =>
      'Tout se trouve dans une pièce : dessinez-en une, placez-y des tables, puis des places sur les tables.';

  @override
  String get editorEmptyFloorTitle => 'Cet étage est vide';

  @override
  String get editorHintDesk =>
      'Faites glisser dans un bureau pour dessiner une table';

  @override
  String get editorHintImage => 'Touchez l\'endroit où placer l\'image';

  @override
  String get editorHintOffice => 'Faites glisser pour dessiner un bureau';

  @override
  String get editorHintSeat => 'Touchez une table pour ajouter une place';

  @override
  String get editorLevelActions => 'Actions de l\'étage';

  @override
  String get editorLevelBookableOff => 'Non réservable en entier';

  @override
  String get editorLevelBookableOn => 'Réservable en entier';

  @override
  String get editorLevelNameLabel => 'Nom de l\'étage';

  @override
  String get editorMediaSaving => 'Enregistrement de l\'image…';

  @override
  String get editorMediaWriteFailed =>
      'L\'enregistrement de l\'image n\'a pas pu être confirmé. Réessayer ne l\'ajoute jamais deux fois.';

  @override
  String get editorNewOffice => 'Nouveau bureau';

  @override
  String get editorNoAccessories =>
      'Aucun accessoire pour l\'instant — ajoutez-les dans Réglages → Accessoires.';

  @override
  String get editorNoAccessoriesAction => 'Aucun équipement — les configurer';

  @override
  String get editorNoLevels =>
      'Aucun étage pour l\'instant. Ajoutez le premier étage de votre espace.';

  @override
  String get editorOfficeNameDefault => 'Bureau';

  @override
  String get editorOfficeNameLabel => 'Nom du bureau';

  @override
  String get editorOfficeProperties => 'Bureau';

  @override
  String get editorOpenTooltip => 'Modifier l\'espace';

  @override
  String get editorOrientationHint =>
      'Le sens dans lequel la chaise est tournée sur le plan.';

  @override
  String get editorOrientationLabel => 'Sens d\'assise';

  @override
  String get editorPlacementOutside =>
      'Doit être entièrement à l\'intérieur d\'un bureau.';

  @override
  String get editorPlacementOverlap => 'Chevauche un élément existant.';

  @override
  String get editorProperties => 'Propriétés';

  @override
  String get editorRenameLevel => 'Renommer';

  @override
  String get editorSeatNameDefault => 'Place';

  @override
  String get editorSeatNameLabel => 'Nom de la place';

  @override
  String get editorSeatNfcDuplicate =>
      'Ce tag est déjà associé à une autre chaise.';

  @override
  String get editorSeatNfcHelp =>
      'UID du tag en hexadécimal — laisser vide pour aucun tag.';

  @override
  String get editorSeatNfcLabel => 'Tag NFC/RFID';

  @override
  String get editorSeatNfcRead => 'Lire un tag maintenant';

  @override
  String get editorSeatNfcReadFailed =>
      'Impossible de démarrer le lecteur de tag.';

  @override
  String get editorSeatNoDesk =>
      'Les places ne peuvent être posées que sur une table.';

  @override
  String get editorSeatProperties => 'Place';

  @override
  String get editorTitle => 'Éditeur d\'espace';

  @override
  String get editorToolDesk => 'Table';

  @override
  String get editorToolErase => 'Effacer';

  @override
  String get editorToolImage => 'Image';

  @override
  String get editorToolOffice => 'Bureau';

  @override
  String get editorToolSeat => 'Place';

  @override
  String get editorToolSelect => 'Sélection';

  @override
  String get einvoiceConfigClear => 'Supprimer la plateforme';

  @override
  String get einvoiceConfigCleared => 'Plateforme supprimée.';

  @override
  String get einvoiceConfigEndpoint => 'URL de dépôt';

  @override
  String get einvoiceConfigField => 'Nom du champ fichier (file par défaut)';

  @override
  String get einvoiceConfigHeader =>
      'En-tête d’authentification (Authorization par défaut)';

  @override
  String get einvoiceConfigIntro =>
      'Là où DesKilo dépose vos factures. Toute plateforme acceptant un envoi avec un jeton fonctionne — une plateforme agréée, un point d\'accès Peppol, une plateforme nationale. Le jeton est stocké côté serveur et n\'en ressort jamais.';

  @override
  String get einvoiceConfigSaved => 'Plateforme enregistrée.';

  @override
  String get einvoiceConfigTitle => 'Plateforme de facturation électronique';

  @override
  String get einvoiceConfigToken => 'Jeton ou identifiant';

  @override
  String get einvoiceConfigTokenSet =>
      'Un jeton est enregistré (saisissez-en un nouveau pour le remplacer).';

  @override
  String get einvoiceConfigUnavailable =>
      'Impossible de charger la configuration de la plateforme. Vérifiez votre connexion et réessayez.';

  @override
  String get einvoiceCustomerSectionHelp =>
      'Où partent les factures destinées au client : son point d’accès Peppol, son portail ou l’API convenue — distinct de la plateforme gouvernementale.';

  @override
  String get einvoiceCustomerSectionTitle => 'Service de remise au client';

  @override
  String get einvoiceDevEndpoint => 'URL d’envoi Dev';

  @override
  String get einvoiceDevToken => 'Jeton ou identifiant Dev';

  @override
  String get einvoiceEnvDev => 'Dev (plateforme de test)';

  @override
  String get einvoiceEnvProd => 'Production';

  @override
  String get einvoiceEnvProdHint => 'La transmission réelle.';

  @override
  String get einvoiceEnvTestHint =>
      'Une répétition — journalisée comme envoi de test.';

  @override
  String get einvoiceEnvTitle => 'Envoyer vers quelle plateforme ?';

  @override
  String get einvoiceEnvUat => 'UAT (plateforme de test)';

  @override
  String get einvoiceTestEnvsHelp =>
      'Points d\'accès et jetons distincts pour les répétitions. Le choix apparaît à l\'envoi uniquement quand le mode développeur est actif.';

  @override
  String get einvoiceTestEnvsTitle => 'Environnements de test (UAT / Dev)';

  @override
  String get einvoiceUatEndpoint => 'URL d’envoi UAT';

  @override
  String get einvoiceUatToken => 'Jeton ou identifiant UAT';

  @override
  String get emblemChoose => 'Choisir une image';

  @override
  String get emblemFailed =>
      'L’emblème n’a pas pu être enregistré. Rien n’a changé.';

  @override
  String get emblemHint =>
      'Une petite image affichée sous le nom de l’application dans le menu. Elle est redessinée à 512 pixels au plus et enregistrée sans les métadonnées du fichier.';

  @override
  String get emblemNotAnImage => 'Ce fichier n’est pas une image.';

  @override
  String get emblemRemove => 'Retirer';

  @override
  String get emblemRemoved => 'Emblème retiré.';

  @override
  String get emblemSaved => 'Emblème enregistré.';

  @override
  String get emblemTitle => 'Emblème';

  @override
  String get emblemTooHeavy =>
      'Cette image est trop lourde pour une marque affichée à 28 pixels.';

  @override
  String get entitlementBlockedFull =>
      'Vous avez utilisé tous vos jours ce mois-ci. Demandez-en plus à un administrateur ou demandez des demi-journées supplémentaires.';

  @override
  String entitlementDaysLeft(String left) {
    return '$left jours restants';
  }

  @override
  String entitlementDaysUsed(String used, String total) {
    return '$used sur $total jours utilisés';
  }

  @override
  String get entitlementPackageFull =>
      'Vous avez utilisé tous vos jours ce mois-ci. Achetez un forfait pour continuer à réserver.';

  @override
  String entitlementPaygRate(String rate) {
    return 'Les jours au-delà de votre forfait sont facturés $rate chacun.';
  }

  @override
  String get entitlementTitle => 'Ce mois-ci';

  @override
  String get environmentDev => 'Développement — pour essayer';

  @override
  String get environmentHint =>
      'Un espace de développement l\'annonce sur chaque écran et filigrane chaque document. Ne le déclarez « production » que lorsque les factures qui en sortent sont réellement dues.';

  @override
  String get environmentLabel => 'Type d’espace';

  @override
  String get environmentPairsCreateTwin => 'Créer son jumeau';

  @override
  String get environmentPairsCreateTwinDesc =>
      'Un espace de développement et un de production du même nom ; la configuration est copiée une fois.';

  @override
  String get environmentPairsPairedDev =>
      'Apparié à son jumeau de développement';

  @override
  String get environmentPairsPairedProd => 'Apparié à son jumeau de production';

  @override
  String get environmentPairsTwinCreated => 'Le jumeau est créé.';

  @override
  String get environmentProd => 'Production — les factures sont dues';

  @override
  String get environmentProdConfirmAction => 'Déclarer en production';

  @override
  String get environmentProdConfirmBody =>
      'Le bandeau disparaît et les documents perdent leur filigrane. Les factures déjà émises ne changent pas : elles gardent le filigrane qu\'elles portaient à l\'émission.';

  @override
  String get environmentProdConfirmTitle =>
      'Déclarer cet espace en production ?';

  @override
  String get environmentSaved => 'Type d’espace enregistré.';

  @override
  String get erasurePreviewKept => 'Conservé, et pourquoi';

  @override
  String get erasurePreviewOutside => 'Hors de cette installation';

  @override
  String get erasurePreviewRemoved => 'Supprimé';

  @override
  String get erasurePreviewTitle => 'Ce que l\'effacement fait ici';

  @override
  String get erasureStoreAccounts =>
      'Factures et grand livre — pièces comptables, conservées pendant la durée légale ; les documents émis ne sont pas réécrits';

  @override
  String get erasureStoreAnswers => 'Vos réponses aux questions de l\'espace';

  @override
  String get erasureStoreBackups =>
      'Sauvegardes de l\'exploitant — expirent selon leur rotation';

  @override
  String get erasureStoreDeviceCaches =>
      'Copies sur vos appareils — effacées à la déconnexion de chacun';

  @override
  String get erasureStoreHeldAnswers =>
      'Réponses sous une obligation de conservation documentée par l\'espace';

  @override
  String get erasureStoreMembership =>
      'La ligne d\'adhésion — relie les données conservées ; pseudonyme, pas anonyme';

  @override
  String get erasureStoreMessages => 'Messages que vous avez envoyés';

  @override
  String get erasureStoreOpenBookings => 'Réservations à venir — annulées';

  @override
  String get erasureStoreOtherInstallations =>
      'Une autre installation DesKilo est un responsable distinct — adressez-vous à elle';

  @override
  String get erasureStorePastBookings =>
      'Réservations passées — l\'historique d\'occupation de l\'espace';

  @override
  String get erasureStoreProfile =>
      'Votre profil (si c\'est votre dernier espace)';

  @override
  String get errorOffline =>
      'Pas de connexion — rien n\'a été envoyé. Réessayez une fois reconnecté.';

  @override
  String get eventAccept => 'Accepter';

  @override
  String get eventAutoValidated => 'Validé automatiquement';

  @override
  String eventExpenseDeviation(Object reason, Object scheduled) {
    return 'validé $scheduled — $reason';
  }

  @override
  String eventExpenseRepartitionLine(
    String actor,
    String title,
    String amount,
    int count,
  ) {
    return '$actor répartit « $title » — $amount entre $count membres';
  }

  @override
  String eventExpenseScheduleLine(Object actor, Object amount, Object title) {
    return '$actor programme « $title » — $amount récurrent';
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
  String eventInvoicePaid(String number, String amount) {
    return 'Facture $number payée — $amount';
  }

  @override
  String eventInvoiceReminderLine(String number, int level, String amount) {
    return 'Relance $level : facture $number — $amount restent dus';
  }

  @override
  String eventInvoiceWriteoffLine(String actor, String number, String amount) {
    return '$actor demande l\'annulation du solde de $number — $amount';
  }

  @override
  String eventPaymentSubmitted(String actor, String amount) {
    return '$actor a enregistré un paiement de $amount';
  }

  @override
  String eventPaymentTermsChangeLine(String actor, String terms) {
    return '$actor demande de fixer les conditions de paiement : $terms';
  }

  @override
  String eventPriceNegotiationItems(int count) {
    return '$count articles';
  }

  @override
  String eventPriceNegotiationLine(String actor, String member, String terms) {
    return '$actor propose des conditions pour $member : $terms';
  }

  @override
  String eventQuotaRequested(String actor, int halfDays, String period) {
    return '$actor demande $halfDays demi-journées supplémentaires pour $period';
  }

  @override
  String get eventReject => 'Refuser';

  @override
  String eventRejectedBy(String name, String when) {
    return 'Refusé par $name · $when';
  }

  @override
  String eventReservationCancelled(String actor, String target) {
    return '$actor a annulé la réservation de $target';
  }

  @override
  String eventReservationCreated(String actor, String target) {
    return '$actor a réservé $target';
  }

  @override
  String get eventReservationDeleteCheckedIn => 'pointée';

  @override
  String eventReservationDeleteLine(String actor, String date, String state) {
    return '$actor demande la suppression de la réservation du $date ($state)';
  }

  @override
  String get eventReservationDeleteUnused => 'jamais utilisée';

  @override
  String eventReservationModified(String actor, String target) {
    return '$actor a modifié la réservation de $target';
  }

  @override
  String eventRoleDemote(String actor) {
    return '$actor demande à retirer le rôle Administrateur·rice';
  }

  @override
  String eventRoleGiven(String actor, String role, String member) {
    return '$actor attribue le rôle $role à $member';
  }

  @override
  String eventRolePromote(String actor) {
    return '$actor demande à attribuer le rôle Administrateur·rice';
  }

  @override
  String eventRoleTakenBack(String actor, String role, String member) {
    return '$actor retire le rôle $role à $member';
  }

  @override
  String eventServiceChargeTitle(String name, int quantity, String amount) {
    return '$name ×$quantity — $amount';
  }

  @override
  String get eventSystemDecider => 'Système';

  @override
  String get eventTypeAdjustment => 'Ajustement';

  @override
  String get eventTypeExpense => 'Dépense';

  @override
  String get eventTypeExpenseRepartition => 'Dépense partagée';

  @override
  String get eventTypeExpenseSchedule => 'Dépense programmée';

  @override
  String get eventTypeInvoiceIssue => 'Émission de facture';

  @override
  String get eventTypeInvoicePayment => 'Paiement de facture';

  @override
  String get eventTypeInvoiceReminder => 'Rappel de paiement';

  @override
  String get eventTypeInvoiceVoid => 'Annulation de facture';

  @override
  String get eventTypeInvoiceWriteoff => 'Annulation de solde';

  @override
  String get eventTypeMatrixChange =>
      'Changement de la matrice des permissions';

  @override
  String get eventTypeMemberJoin => 'Nouveau membre';

  @override
  String get eventTypeMemberStatusChange => 'Changement d\'adhésion';

  @override
  String get eventTypePayment => 'Paiement';

  @override
  String get eventTypePaymentTermsChange => 'Conditions de paiement';

  @override
  String get eventTypePriceNegotiation => 'Négociation tarifaire';

  @override
  String get eventTypeQuota => 'Demi-journées supplémentaires';

  @override
  String get eventTypeRefund => 'Remboursement';

  @override
  String get eventTypeReservation => 'Réservation';

  @override
  String get eventTypeReservationDelete => 'Suppression de réservation';

  @override
  String get eventTypeRoleChange => 'Changement de rôle';

  @override
  String get eventTypeServiceCharge => 'Service';

  @override
  String get eventTypeSpaceReservation => 'Réservations d\'espaces entiers';

  @override
  String get eventTypeSubscriptionChange => 'Changement d\'abonnement';

  @override
  String get eventTypeUnknown => 'Activité';

  @override
  String get eventTypeUsageCorrection => 'Départ anticipé';

  @override
  String get eventTypeUsageRecordDelete => 'Suppression d\'un relevé d\'usage';

  @override
  String eventUsageCorrectionLine(String actor, String from, String to) {
    return '$actor demande à être facturé $to au lieu de $from';
  }

  @override
  String eventUsageRecordDeleteLine(String actor, String space) {
    return '$actor demande la suppression d\'un relevé d\'usage ($space)';
  }

  @override
  String eventValidatedBy(String name, String when) {
    return 'Validé par $name · $when';
  }

  @override
  String eventValidationStage(int stage, int required) {
    return 'Validation $stage sur $required demandée';
  }

  @override
  String eventValidations(int current, int required) {
    return '$current/$required validations';
  }

  @override
  String get eventsEmpty => 'Aucun événement pour l\'instant.';

  @override
  String get eventsFilterAll => 'Tous';

  @override
  String get eventsMessagesHeader => 'Messages';

  @override
  String get eventsPendingHeader => 'En attente de votre confirmation';

  @override
  String get expenseCategoryCoffee => 'Café et cuisine';

  @override
  String get expenseCategoryEquipment => 'Équipement';

  @override
  String get expenseCategoryOther => 'Autre';

  @override
  String get expenseCategorySupplies => 'Fournitures';

  @override
  String get expenseInvalidAmount => 'Saisissez un montant supérieur à zéro.';

  @override
  String get expenseInvalidSupplyQuantity => 'Saisissez au moins une unité.';

  @override
  String get expenseInvalidUnitPrice =>
      'Saisissez un prix unitaire valide, ou laissez-le vide.';

  @override
  String get expenseMissingSupplyName => 'Nommez le nouvel article.';

  @override
  String get expenseSupplyHint =>
      'Capsules de café, sacs d\'aspirateur… Une fois validée, l\'article va sur l\'étagère comme service consommable : ceux qui l\'utilisent le paient.';

  @override
  String get expenseSupplyItem => 'Article';

  @override
  String get expenseSupplyNewItem => 'Nouvel article';

  @override
  String get expenseSupplyQuantity => 'Quantité';

  @override
  String get expenseSupplyToggle => 'C\'est une fourniture pour l\'espace';

  @override
  String get expenseSupplyUnitPrice =>
      'Prix unitaire (ce que coûte une consommation)';

  @override
  String get expenseSupplyUnitPriceHint =>
      'Prérempli avec montant ÷ quantité ; arrondissez si vous voulez.';

  @override
  String get exportClaimExchange =>
      'Pour que votre comptable l’importe et le vérifie — ce n’est pas une déclaration.';

  @override
  String get exportClaimRegulatory =>
      'Le format que votre administration fiscale demande.';

  @override
  String get exportClaimSubset =>
      'Factures et paiements seulement, sans grand livre. Le fichier le dit dans son en-tête.';

  @override
  String get exportNoCompleteBooks =>
      'Reconstitué à partir des factures et des paiements — DesKilo ne tient pas de comptabilité en partie double, ce ne sont donc pas vos livres complets. Votre comptable le complète.';

  @override
  String get exportUncertifiedSoftware =>
      'Conforme à la spécification publiée, mais DesKilo n’est pas un logiciel certifié dans ce pays — vérifiez avec votre comptable si cela vous est imposé.';

  @override
  String get featureAccessorySupplements => 'Suppléments d\'accessoires';

  @override
  String get featureAccessorySupplementsDesc =>
      'Facturer les accessoires de place tarifés par demi-journée réservée. S\'applique aux réservations à partir de l\'activation.';

  @override
  String get featureAccountingBookDesc =>
      'Qui tient les livres officiels de chaque émetteur : Deskilo en pré-comptabilité, un livre local ou un logiciel comptable externe qui fait foi. Chaque émetteur indique sa devise, son exercice et sa base comptable. Désactivé : les soldes des membres et les factures fonctionnent comme avant.';

  @override
  String get featureAccountingBookTitle => 'Livre comptable';

  @override
  String get featureAdminInvoicing => 'Les admins émettent des factures';

  @override
  String get featureAdminInvoicingDesc =>
      'Les admins émettent aussi des factures. Le propriétaire le peut toujours.';

  @override
  String get featureAdminLevelAssign =>
      'Les admins peuvent attribuer des niveaux';

  @override
  String get featureAdminLevelAssignDesc =>
      'Les admins attribuent des réservations de niveau aux membres. Le propriétaire le peut toujours.';

  @override
  String get featureAdminSeatBlocking =>
      'Les admins peuvent bloquer des places';

  @override
  String get featureAdminSeatBlockingDesc =>
      'Les admins marquent des places comme non réservables pour maintenance. Le propriétaire le peut toujours.';

  @override
  String featureAlsoEnabled(String features) {
    return 'Également activé : $features';
  }

  @override
  String featureAlsoEnables(String features) {
    return 'Activer ceci active aussi $features';
  }

  @override
  String get featureAutoCheckInOut => 'Arrivée/départ auto en fin de journée';

  @override
  String get featureAutoCheckInOutDesc =>
      'Les réservations sans arrivée ou départ enregistrés se clôturent seules une fois leur créneau passé.';

  @override
  String get featureBadgeSignInDesc =>
      'Les membres peuvent se connecter en scannant leur badge puis en saisissant leur code, au lieu de taper une adresse e-mail sur une tablette partagée. Chaque membre définit son propre code et active son propre badge.';

  @override
  String get featureBadgeSignInTitle => 'Connexion par badge';

  @override
  String get featureBookForOthers => 'Réserver pour d\'autres';

  @override
  String get featureBookForOthersDesc =>
      'Les admins et propriétaires réservent des places pour d\'autres membres.';

  @override
  String get featureBookingGateDesc =>
      'Chaque surface de réservation — plan, vues jour, semaine et mois, feuille de réservation, kiosque, scan QR ou NFC — vérifie les paramètres de disponibilité avant de proposer un créneau et nomme la raison quand elle ne peut pas ; les jours fermés s\'affichent fermés dans chaque vue, une légende nomme les états des places, et les admins peuvent faire sortir un membre là où la règle le permet.';

  @override
  String get featureBookingGateTitle => 'Garde-fou de réservation';

  @override
  String get featureBookingPoliciesDesc =>
      'Comportement de réservation configurable : réservations passées, réservations à la minute hors heures, check-out par un admin.';

  @override
  String get featureBookingPoliciesTitle => 'Règles de réservation';

  @override
  String get featureCalendarFileExportDesc =>
      'Permet à un membre d’enregistrer l’une de ses propres réservations sous forme de fichier calendrier standard (.ics) pour l’agenda qu’il utilise déjà. Le fichier ne contient que l’horaire, l’espace réservé et le nom de l’espace de coworking — ni montant, ni nom, ni note, ni lien — et c’est un instantané : une modification ultérieure de la réservation ne met pas à jour un fichier déjà enregistré. Rien n’est écrit dans un agenda et rien ne se synchronise. Désactivée, elle masque le bouton.';

  @override
  String get featureCalendarFileExportTitle =>
      'Fichier calendrier d’une réservation';

  @override
  String get featureCalendarHubDesc =>
      'Le calendrier montre tout ce qui est daté — réservations, pointages, alertes, messages, factures, paiements, consommations, rappels — pour un jour ou une période, chaque ligne ouvrant sa source. Désactivé : réservations seulement.';

  @override
  String get featureCalendarHubTitle => 'Calendrier central';

  @override
  String get featureCalendarTab => 'Onglet Calendrier';

  @override
  String get featureCalendarTabDesc =>
      'Vue mensuelle des réservations et jours de fermeture.';

  @override
  String get featureCalendarValidationsDesc =>
      'Chaque décision prise sur un événement apparaît dans le calendrier au moment où elle a été prise, et non au moment de l\'événement : qui a validé ou refusé quoi, et quand. Un appui ouvre son historique. Désactivé : le calendrier ne porte aucune décision.';

  @override
  String get featureCalendarValidationsTitle =>
      'Validations dans le calendrier';

  @override
  String get featureCalendarViewsDesc =>
      'L\'onglet Calendrier en agenda, semaine et mois : repères par jour selon le type, jours fermés affichés fermés, en-têtes Aujourd\'hui / Demain, échéances de paiement et dépenses programmées dans le fil. Désactivé : le simple sélecteur jour ou plage au-dessus du fil.';

  @override
  String get featureCalendarViewsTitle => 'Vues du calendrier';

  @override
  String get featureCapacityKpiDesc =>
      'Montre aux propriétaires et aux gestionnaires des réservations quelle part du temps de place offert a été réservée dans le mois, avec la façon dont c\'est calculé et ce que le chiffre ne peut pas savoir.';

  @override
  String get featureCapacityKpiTitle => 'Occupation des places';

  @override
  String get featureCaptureProtectionDesc =>
      'Les écrans de messages refusent les captures et l’enregistrement d’écran quand l’appareil le permet, masquent leur contenu pendant un enregistrement et annoncent une capture dans la conversation quand elle peut seulement être détectée. Un navigateur ne peut pas bloquer les captures ; la conversation y est floutée quand l’onglet perd le focus.';

  @override
  String get featureCaptureProtectionTitle =>
      'Protection contre la capture d’écran';

  @override
  String get featureCarnetsDesc =>
      'Vendre des carnets de demi-journées, dépensés sur plusieurs mois quand un membre réserve au-delà de son abonnement, facturés une seule fois à la vente.';

  @override
  String get featureCarnetsTitle => 'Carnets';

  @override
  String get featureChangeUnconfirmed =>
      'La modification a été envoyée, mais les fonctionnalités n\'ont pas pu être rechargées pour la confirmer. Rouvrez l\'écran pour voir l\'état actuel.';

  @override
  String get featureChangedMeanwhile =>
      'Les fonctionnalités ont changé entre-temps, rien n\'a donc été enregistré. Vérifiez la liste et recommencez.';

  @override
  String get featureCoOwner => 'Copropriétaires';

  @override
  String get featureCoOwnerDesc =>
      'Nommer des copropriétaires : permissions de propriétaire immédiates (actif) ou succession en attente (passif).';

  @override
  String get featureConfigurationTransfer =>
      'Configuration dans le fichier de l\'espace';

  @override
  String get featureConfigurationTransferDesc =>
      'Le fichier de l\'espace (XML) emporte toute la configuration — tarifs, identité légale, règles de réservation et de validation, rôles, maquettes de documents, sites, jours de fermeture — et l\'import l\'applique, même sur un espace qui a déjà des réservations. Désactivé : le fichier n\'emporte que les réglages et le plan.';

  @override
  String get featureCustomFieldsDesc =>
      'L\'espace peut poser ses propres questions dans le formulaire d\'identité : une fonction au bureau, une date d\'adhésion, un contact d\'urgence. Les réponses appartiennent à l\'adhésion : une question posée ici ne suit personne ailleurs.';

  @override
  String get featureCustomFieldsTitle => 'Les questions de cet espace';

  @override
  String get featureCustomRolesDesc =>
      'L’espace peut définir ses propres rôles — un trésorier, un secrétaire — qui ajoutent des permissions à celles du rôle d’un membre. Ils n’en retirent jamais, et un propriétaire les conserve toutes.';

  @override
  String get featureCustomRolesTitle => 'Rôles définis par cet espace';

  @override
  String get featureDataAccessLogDesc =>
      'Chaque membre voit qui a consulté ses finances et quand (écrit par le serveur, jamais contournable). Désactivé : la ligne est masquée, le journal est conservé.';

  @override
  String get featureDataAccessLogTitle => 'Journal des accès aux données';

  @override
  String get featureDataExport => 'Export des données (Excel)';

  @override
  String get featureDataExportDesc =>
      'Télécharger toutes les données de l’espace dans un classeur Excel.';

  @override
  String get featureDecisionSurfaceDesc =>
      'Un seul endroit qui répond à « est-ce que quelque chose m\'attend ? », classé par ce que coûte le retard — l\'argent qui part d\'abord, puis quelqu\'un qui attend une réponse. Une ligne n\'apparaît que si une personne doit décider ou agir ; un chiffre sur lequel personne ne peut agir reste sur l\'écran qui le porte.';

  @override
  String get featureDecisionSurfaceTitle => 'Ce qui vous attend';

  @override
  String get featureDeletionRequests =>
      'Demandes de suppression de réservation';

  @override
  String get featureDeletionRequestsDesc =>
      'Les membres peuvent DEMANDER la suppression d\'une réservation passée ou pointée ; un propriétaire/admin valide. Désactivé, ces réservations ne peuvent pas être supprimées.';

  @override
  String get featureDemoMode => 'L\'espace de démonstration';

  @override
  String get featureDemoModeDesc =>
      'Un espace inventé que chacun peut ouvrir depuis l\'écran de connexion, avec ses propres personnes, réservations et factures. Rien de ce qui s\'y fait n\'atteint un espace réel ni ne quitte l\'appareil, et aucun compte n\'est nécessaire. Désactivé : la proposition n\'apparaît pas.';

  @override
  String get featureDeployments => 'Déploiements';

  @override
  String get featureDeploymentsDesc =>
      'Configuration et données de base déployées entre les deux côtés d\'une paire, entité par entité, avec un aperçu de ce qui change et un journal qui sait revenir en arrière. Désactivé : les jumeaux se règlent à la main, chacun de son côté.';

  @override
  String get featureDetailChange => 'La modifier parmi les interrupteurs';

  @override
  String featureDetailGrantsPermission(String permission) {
    return 'Accorde aux administrateurs l\'autorisation « $permission ».';
  }

  @override
  String featureDetailHeldBack(String feature) {
    return 'Activée, mais en attente : elle nécessite $feature, qui est désactivée.';
  }

  @override
  String get featureDetailKey => 'Clé technique';

  @override
  String get featureDetailNone => 'Rien.';

  @override
  String get featureDetailOff => 'Désactivée.';

  @override
  String get featureDetailOn => 'Activée.';

  @override
  String featureDetailOnNeededBy(String names) {
    return 'Activée, et nécessaire à $names.';
  }

  @override
  String get featureDetailProvides => 'Apporte';

  @override
  String get featureDetailRequires => 'Nécessite';

  @override
  String get featureDetailTechnical => 'Détails techniques';

  @override
  String get featureDetailUsedBy => 'Utilisée par';

  @override
  String get featureDocuments => 'Bibliothèque de documents';

  @override
  String get featureDocumentsDesc =>
      'La bibliothèque de documents de l\'espace : statuts, guides, états financiers, comptes rendus — liés depuis n\'importe quel drive, visibles selon le rôle.';

  @override
  String get featureDunning => 'Relances de paiement';

  @override
  String get featureDunningDesc =>
      'Niveaux et délais de relance paramétrables, une lettre de relance par niveau et des suggestions « Relance due » sur les factures en retard. L\'envoi reste un geste manuel, sauf avec les Relances de paiement automatiques.';

  @override
  String get featureEinvoiceCustomerDeliveryDesc =>
      'Un second canal d’envoi à côté de la plateforme gouvernementale : transmettre la facture émise directement au service de facturation du client.';

  @override
  String get featureEinvoiceCustomerDeliveryTitle =>
      'Remise des factures au client';

  @override
  String get featureEnvironmentPairs => 'Paires d\'environnements';

  @override
  String get featureEnvironmentPairsDesc =>
      'Un espace et son jumeau — le côté développement et le côté production — comme un couple : une carte dans Profils avec un interrupteur, et le jumeau créé à la demande avec la configuration copiée. Désactivé : deux entrées sans lien.';

  @override
  String get featureEventsTab => 'Onglet Événements';

  @override
  String get featureEventsTabDesc =>
      'Fil d\'activité et confirmations en attente.';

  @override
  String get featureExpenseRepartitionDesc =>
      'Une dépense commune (ménage, montée en débit internet, chaise cassée) répartie entre les membres — parts égales, au prorata de l\'abonnement, au prorata de l\'usage, ou une clé par membre — chaque part prévisualisée avant d\'être comptabilisée. Les parts deviennent des lignes de la prochaine facture de consommation ; une annulation produit des avoirs. Passe par les règles de validation. Désactivé : pas de répartition.';

  @override
  String get featureExpenseRepartitionTitle => 'Dépenses partagées';

  @override
  String get featureExpenseRepartitionWizard => 'Assistant de répartition';

  @override
  String get featureExpenseRepartitionWizardDesc =>
      'Une répartition guidée : une dépense commune proposée au prorata de l\'abonnement, chaque part ajustable, et la règle ajustée mémorisée pour le mois suivant. Désactivé : seule la fiche de répartition d\'une dépense.';

  @override
  String get featureFinanceFacesDesc =>
      'L\'onglet Finances se lit en quatre volets — Relevé, Paiements, Factures, Documents — sous un même sélecteur de mois, chacun avec son aide. Désactivé : une seule colonne.';

  @override
  String get featureFinanceFacesTitle => 'Finances en quatre volets';

  @override
  String get featureFormHelpHintsDesc =>
      'Un carrousel d\'astuces masquable sur chaque écran principal, et un petit ? à côté de chaque paramètre et champ de saisie — un geste ouvre le guide à la bonne section. Réactivable dans les réglages.';

  @override
  String get featureFormHelpHintsTitle => 'Astuces d\'aide';

  @override
  String get featureGuestParticipationDesc =>
      'Permet à une personne qui n\'est pas membre de demander à visiter cet espace, et à quelqu\'un qui gère les réservations de l\'admettre ou de refuser. Une visite ne crée ni adhésion, ni abonnement, ni rôle. Désactivé : personne ne demande ni n\'est admis ici.';

  @override
  String get featureGuestParticipationTitle => 'Visites d\'invités';

  @override
  String get featureHeldBack =>
      'En attente de la fonction au-dessus — activez-la et celle-ci fonctionne de nouveau.';

  @override
  String get featureHolidayImportDesc =>
      'Un propriétaire importe les jours fériés du pays, et d\'une région, depuis une source de données ouvertes, désélectionne les jours où l\'espace reste ouvert et importe les autres comme jours de fermeture. Les mois déjà facturés sont ignorés et nommés.';

  @override
  String get featureHolidayImportTitle => 'Importer les jours fériés';

  @override
  String get featureInstanceWizard => 'Assistant d\'instance';

  @override
  String get featureInstanceWizardDesc =>
      'Sur l\'écran Serveur, un assistant crée un nouveau projet Supabase, installe le schéma de l\'app, déploie ses fonctions et y connecte l\'appareil — un jeton d\'accès, pas de terminal. Désactivé : les étapes manuelles seulement.';

  @override
  String get featureIntakeStoppedNote =>
      'Désactivé : rien de nouveau ne commence ; ce qui est en cours peut encore être traité et clos.';

  @override
  String get featureIntakeUnconfirmedNote =>
      'Désactivé : rien de nouveau ne commence. Ce serveur n\'a pas pu confirmer que ce qui est déjà ouvert reste traitable ; n\'y comptez pas.';

  @override
  String get featureInvoiceAddressWindow => 'Fenêtre d\'adresse';

  @override
  String get featureInvoiceAddressWindowDesc =>
      'Place le destinataire à l\'endroit qu\'une enveloppe à fenêtre laisse voir, pour qu\'une facture imprimée puisse être pliée et postée. Le côté suit le pays et reste modifiable.';

  @override
  String get featureInvoiceJourneyDesc =>
      'Chaque facture montre où elle en est — Émise, Paiement, Confirmation, Close — et à qui est le tour : le membre paie, un admin confirme le paiement déclaré, l\'émetteur le rapproche, les valideurs décident. Le hub des émetteurs ajoute un bandeau d\'étapes avec les compteurs et une explication « Comment ça marche ».';

  @override
  String get featureInvoiceJourneyTitle => 'Le parcours d\'une facture';

  @override
  String get featureInvoicePdfTemplate => 'Modèle de PDF de facture';

  @override
  String get featureInvoicePdfTemplateDesc =>
      'Introduction et pied de page rédigés par le propriétaire sur le PDF de facture. Ne touche jamais au XML de facture électronique.';

  @override
  String get featureInvoiceSettlementDesc =>
      'Plusieurs factures ouvertes d\'un membre peuvent être regroupées en une seule qu\'il paie. Les originales restent dans l\'archive, traçables poste par poste, et ne sont plus relancées séparément.';

  @override
  String get featureInvoiceSettlementTitle => 'Regrouper les factures';

  @override
  String get featureInvoicing => 'Factures';

  @override
  String get featureInvoicingDesc =>
      'Factures immuables et signées dans une archive — à télécharger ou partager en PDF.';

  @override
  String get featureInvoicingWizardDesc =>
      'Un processus guidé de clôture mensuelle pour le responsable financier : une passe de début de mois pour les abonnements payés d\'avance et une passe de fin de mois pour la consommation et les frais supplémentaires — revue, émission en lot, envoi, relances dues, enregistrement et validation des paiements, rapprochement avec les factures, regroupement, abandon de créance ou remboursement, et un récapitulatif avec ce qui reste à faire et par qui. Désactivé : les écrans séparés.';

  @override
  String get featureInvoicingWizardTitle => 'Assistant de facturation';

  @override
  String get featureKioskMemberPhotosDesc =>
      'Le reçu de la borne affiche la photo de profil du membre — le contrôle visuel du mauvais badge.';

  @override
  String get featureKioskMemberPhotosTitle => 'Photos des membres à la borne';

  @override
  String get featureKioskMode => 'Mode borne';

  @override
  String get featureKioskModeDesc =>
      'Comptes tablette murale verrouillés sur le plan en direct ; les membres agissent par badge.';

  @override
  String get featureLess => 'Moins';

  @override
  String get featureLetterStandard => 'Standard lettre pour chaque document';

  @override
  String get featureLetterStandardDesc =>
      'Factures, proformas, relevés, accords, rapports de paiements et de consommation, rappels sans maquette s\'impriment en lettre normalisée : en-tête, destinataire dans la fenêtre de l\'enveloppe, corps à 90 mm, pied fixe.';

  @override
  String get featureLevelBooking => 'Réservations de table, bureau et niveau';

  @override
  String get featureLevelBookingDesc =>
      'Réserver une table, un bureau ou un étage entier en une seule réservation, tarifé par demi-journée. Accordez le droit par membre.';

  @override
  String get featureLifecycleActive => 'Active';

  @override
  String get featureLifecycleDeprecated => 'Dépréciée';

  @override
  String get featureLifecycleRetired => 'Retirée';

  @override
  String get featureManagedProfileAccess => 'Qui administre un profil';

  @override
  String get featureManagedProfileAccessDesc =>
      'Chaque profil géré indique qui peut l\'administrer — par rôle, par personnes nommées, ou les deux. Désactivé : tout propriétaire et tout admin le peuvent, comme avant. L\'identité elle-même est protégée dans les deux cas, et chaque consultation est consignée pour la personne qui reprendra le profil.';

  @override
  String get featureManagedProfiles => 'Profils gérés';

  @override
  String get featureManagedProfilesDesc =>
      'Les admins créent des membres sans compte, réservent et facturent pour eux, puis leur remettent le profil par un code personnel utilisé en rejoignant l\'espace.';

  @override
  String get featureMaturityAlpha => 'Alpha';

  @override
  String get featureMaturityBeta => 'Bêta';

  @override
  String get featureMaturityFilterAll => 'Tous les stades';

  @override
  String get featureMaturityFilterLabel => 'Maturité';

  @override
  String featureMaturitySemantics(String maturity, String lifecycle) {
    return 'Maturité $maturity, $lifecycle';
  }

  @override
  String get featureMaturityStable => 'Stable';

  @override
  String get featureMaturityUnreviewed => 'Non évaluée';

  @override
  String get featureMcpAccessDesc =>
      'Rend l’interface MCP disponible pour cet espace, afin qu’un assistant IA puisse être connecté à DesKilo. Disponibilité seulement : l’activer n’accorde rien à personne. Chaque personne a encore besoin d’une autorisation que le propriétaire configure et que l’administrateur de l’instance approuve, et chaque opération continue de répondre aux permissions et aux règles que l’application applique déjà. Désactivée, elle masque les points d’entrée MCP et refuse les appels ; les autorisations existantes restent visibles et révocables.';

  @override
  String get featureMcpAccessTitle => 'Interface MCP';

  @override
  String get featureMemberAccountMenuDesc =>
      'Un membre qui n\'administre rien rencontre Mon compte au lieu de Réglages — le même écran, qui ne lui montre déjà que son compte, son adhésion et ses préférences, sous le nom qui le dit. Toute personne dont le rôle accorde une administration garde Réglages et tout ce qu\'il ouvre. Ceci renomme une entrée ; cela n\'accorde et ne retire rien.';

  @override
  String get featureMemberAccountMenuTitle => 'Les membres voient Mon compte';

  @override
  String get featureMemberDataExportDesc =>
      'Chaque membre peut exporter ses données en un fichier (RGPD art. 20) et quitter l\'espace avec ses données personnelles effacées (art. 17) depuis Réglages → Confidentialité et données.';

  @override
  String get featureMemberDataExportTitle => 'Export et effacement';

  @override
  String get featureMemberEnvironmentsDesc =>
      'Quand vous invitez quelqu\'un, choisissez s\'il atteint aussi l\'espace de production. Il rejoint l\'espace de test dans tous les cas, et le rôle doit malgré tout autoriser l\'accès à la production.';

  @override
  String get featureMemberEnvironmentsTitle =>
      'Choisir les environnements sur lesquels une personne est activée';

  @override
  String get featureMemberGettingStartedDesc =>
      'Après avoir rejoint ou créé un espace, un membre voit une carte compacte sur le hub Réserver : l’espace dans lequel il se trouve et une prochaine étape suggérée — choisir un créneau à réserver, consulter son adhésion ou ouvrir l’aide — seulement là où les fonctionnalités et ses permissions le permettent. Pas maintenant la masque ; les Réglages peuvent la réafficher. Elle ne réserve, ne paie et n’approuve jamais rien. Pour qui configure l’espace, les réglages montrent aussi, section par section, ce qui le sépare d’une première réservation. Désactivée, elle masque la carte et cette liste et ne change rien d’autre.';

  @override
  String get featureMemberGettingStartedTitle => 'Carte Premiers pas';

  @override
  String get featureMemberNotifications => 'Notifications entre membres';

  @override
  String get featureMemberNotificationsDesc =>
      'Messagerie entre membres : conversations privées et de groupe, accusés de lecture, liens vers une réservation ou un espace ; les admins peuvent notifier tous les admins, propriétaire inclus.';

  @override
  String get featureMemberOriginDesc =>
      'Une ligne discrète sur un membre indiquant comment son adhésion a commencé : a fondé l\'espace, a rejoint sur invitation, ou a reçu un profil créé par un administrateur. Ce n\'est pas un statut.';

  @override
  String get featureMemberOriginTitle => 'Comment chaque membre est arrivé';

  @override
  String get featureMemberPageDesc =>
      'Une page par membre : photo et présence, dernière connexion, réservations en cours et à venir, actions rapides (message, WhatsApp, e-mail), cartes contact et finances, et pour les admins chaque réglage regroupé par thème avec sa valeur actuelle. Désactivé : la feuille de profil et la feuille d\'actions de Membres & forfaits.';

  @override
  String get featureMemberPageTitle => 'Fiche membre';

  @override
  String get featureMemberPaymentTerms => 'Conditions de paiement par membre';

  @override
  String get featureMemberPaymentTermsDesc =>
      'L\'espace définit les conditions par défaut ; un membre peut avoir les siennes, visibles par lui, modifiées uniquement par une demande validée d\'un admin autorisé.';

  @override
  String get featureMemberReports => 'Rapports des membres';

  @override
  String get featureMemberReportsDesc =>
      'L\'accord financier et le rapport mensuel des paiements — en libre-service pour les membres, envoyables par membre.';

  @override
  String get featureMembersDirectory => 'Annuaire des membres';

  @override
  String get featureMembersDirectoryDesc =>
      'L\'onglet communauté : qui est là, statuts, présence.';

  @override
  String get featureMessageForwardingDesc =>
      'Un message peut être transféré dans une autre conversation à laquelle participe la personne qui transfère. La copie indique son origine et son auteur, la conversation d’origine est informée de qui l’a transféré et où, et un auteur peut verrouiller un message contre le transfert. Désactivé, aucun transfert ne sort de cet espace.';

  @override
  String get featureMessageForwardingTitle => 'Transfert de messages';

  @override
  String get featureMessageGesturesDesc =>
      'Balayez un message vers la droite pour le citer dans votre réponse ; vers la gauche pour reprendre votre propre message tant que personne ne l\'a lu, après confirmation. Désactivé : les messages se suppriment par appui long.';

  @override
  String get featureMessageGesturesTitle => 'Balayer pour citer ou reprendre';

  @override
  String get featureMessageMentionsDesc =>
      'Dans un groupe, on peut mentionner une personne par son nom. Seules les personnes de la conversation peuvent être mentionnées, et la personne mentionnée est notifiée même si elle a mis la conversation en sourdine. Désactivé, un nom écrit après @ reste du texte et ne notifie personne.';

  @override
  String get featureMessageMentionsTitle => 'Mentions dans les groupes';

  @override
  String get featureMessagesHubDesc =>
      'Une seule barre de boîte de réception (Tous / Non lus / Archivés et recherche), épingler, couper le son, archiver et marquer non lu sur un fil, la conversation en page entière avec séparateurs de date, un menu joindre et un brouillon conservé dans le composeur, une personne ouverte d\'un seul geste. Désactivé : la boîte à deux barres et le fil en feuille.';

  @override
  String get featureMessagesHubTitle => 'Messages repensés';

  @override
  String get featureMoneyTab => 'Onglet Finances';

  @override
  String get featureMoneyTabDesc =>
      'Factures mensuelles, paiements et dépenses.';

  @override
  String get featureMore => 'Plus';

  @override
  String get featureMultiSite => 'Sites';

  @override
  String get featureMultiSiteDesc =>
      'Plusieurs adresses : les étages sont regroupés par site, chaque site a son adresse et son SIRET, chaque adhérent un site de rattachement, et les documents nomment le site concerné. Désactivé : une seule adresse pour l\'espace.';

  @override
  String get featureNavigationStyle => 'Choix de la navigation';

  @override
  String get featureNavigationStyleDesc =>
      'Chaque membre choisit dans ses réglages comment l\'application navigue : la barre classique avec le bouton rond Réserver, ou le menu comme sur le web. Désactivé : chaque appareil garde le défaut de sa plateforme.';

  @override
  String get featureNfcBadges => 'Badges RFID / NFC';

  @override
  String get featureNfcBadgesDesc =>
      'Les membres pointent à une borne en approchant une carte RFID/NFC. Nécessite un appareil Android avec NFC.';

  @override
  String get featureNfcSeatTagsDesc =>
      'Un tag NFC/RFID physique sur une chaise mène à sa place comme la carte QR imprimée ; le champ se remplit en approchant la puce.';

  @override
  String get featureNfcSeatTagsTitle => 'Tags NFC/RFID des chaises';

  @override
  String get featureNotificationGroupingDesc =>
      'Les membres peuvent regrouper le fil de notifications par type, jour ou membre ; toucher le symbole du groupe ramène à la liste plate.';

  @override
  String get featureNotificationGroupingTitle =>
      'Regroupement des notifications';

  @override
  String get featureNumberSequences => 'Séquences de numérotation';

  @override
  String get featureNumberSequencesDesc =>
      'Comment chaque journal numérote ses documents — préfixe, année ou mois, nombre de chiffres, remise à zéro — sur un seul écran pour toutes les séries. Les numéros sont attribués dans la base, sans trou, que ce soit activé ou non ; activé, le propriétaire change le format pour la suite.';

  @override
  String get featureOnlinePayments => 'Paiements en ligne';

  @override
  String get featureOnlinePaymentsDesc =>
      'Permettre aux membres de payer leur facture en ligne (PayPal). Nécessite la configuration du prestataire de paiement sur le serveur.';

  @override
  String featureOptInAlsoOn(int count, String features) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Activés aussi, car nécessaires ($count) : $features',
      one: 'Activé aussi, car nécessaire : $features',
    );
    return '$_temp0';
  }

  @override
  String featureOptInBody(String features) {
    return 'Pas encore évaluée comme stable : $features. Elle peut changer et a des limites connues. N’activez que si cet espace l’accepte.';
  }

  @override
  String get featureOptInConfirm => 'Activer';

  @override
  String featureOptInStage(String feature, String stage) {
    return '$feature : $stage';
  }

  @override
  String get featureOptInTitle => 'Activer une fonctionnalité expérimentale ?';

  @override
  String get featurePaymentRemindersDesc =>
      'Les factures ouvertes au-delà du délai configuré reçoivent leurs niveaux de relance automatiquement — une alerte dans le fil du membre et une notification, une fois par jour. Désactivé : la relance reste un geste manuel.';

  @override
  String get featurePaymentRemindersTitle =>
      'Relances de paiement automatiques';

  @override
  String get featurePdfExport => 'Export PDF';

  @override
  String get featurePdfExportDesc => 'Exporter la facture mensuelle en PDF.';

  @override
  String get featurePersonalInfo => 'Informations personnelles';

  @override
  String get featurePersonalInfoDesc =>
      'Les membres saisissent nom, adresse postale, téléphone, e-mail et identifiants légaux dans Réglages ; factures et courriers les impriment dans le bloc adresse normalisé.';

  @override
  String get featurePlaceFeedbackDesc =>
      'Les membres marquent des places, bureaux, salles et étages en favoris et les notent de 0 à 5 étoiles. Un favori est personnel ; une note montre sa moyenne et le nombre de notes, jamais qui. Un assistant peut lister les favoris, en réserver un et enregistrer une note. Désactivé, les cœurs et les étoiles disparaissent et les écritures sont refusées ; rien d\'autre n\'en dépend.';

  @override
  String get featurePlaceFeedbackTitle => 'Favoris et notes';

  @override
  String get featurePlanMemberPhotosDesc =>
      'Les places occupées de l\'onglet Plan et du hub Réserver affichent la photo de profil de l\'occupant au lieu de l\'initiale.';

  @override
  String get featurePlanMemberPhotosTitle => 'Photos des membres sur le plan';

  @override
  String get featurePlanObjectDeleteDesc =>
      'Les propriétaires peuvent supprimer niveaux, bureaux, tables et places même si d\'anciennes réservations y font référence — les réservations gardent un instantané texte pour les audits et rapports.';

  @override
  String get featurePlanObjectDeleteTitle =>
      'Supprimer des espaces avec historique';

  @override
  String get featurePriceNegotiationsDesc =>
      'Le tarif est la valeur par défaut ; un membre peut avoir ses propres conditions — abonnement, dépassement, remise sur les suppléments, prix unitaires par service et forfait, pourcentage d\'occupation — proposées par qui détient « Gérer les accords commerciaux » et validées selon les règles. Vues par le membre, les propriétaires et les titulaires de « Consulter les accords commerciaux » ; chaque consultation est journalisée.';

  @override
  String get featurePriceNegotiationsTitle => 'Négociations tarifaires';

  @override
  String get featurePublicHolidaysDesc =>
      'Le propriétaire choisit une année, voit les jours fériés qui deviendraient des jours de fermeture, puis confirme. Relancer une année n\'ajoute rien, et un mois déjà facturé est ignoré et nommé — générer des jours fériés ne modifie jamais une facture déjà émise.';

  @override
  String get featurePublicHolidaysTitle => 'Jours fériés';

  @override
  String get featurePublicListings => 'Présentation publique de l’espace';

  @override
  String get featurePublicListingsDesc =>
      'Publiez les informations et plans choisis, avec les propriétaires visibles et les administrateurs volontaires.';

  @override
  String get featurePushNotifications => 'Notifications push';

  @override
  String get featurePushNotificationsDesc =>
      'Livrer les confirmations en attente sur les appareils des membres.';

  @override
  String get featureQrBadgesDesc =>
      'Cartes badge QR imprimables pour le kiosque, à côté des cartes NFC/RFID.';

  @override
  String get featureQrBadgesTitle => 'Badges QR';

  @override
  String get featureRecordingPrivacyDesc =>
      'Pour filmer ou photographier cet espace. Chaque nom, adresse électronique, numéro de téléphone, adresse postale et photo est remplacé par une personne inventée avant d\'arriver à l\'écran, tandis que le plan, les réservations et les montants restent les vrais. Un bandeau l\'indique sur chaque écran, et les formulaires d\'identité refusent d\'enregistrer tant qu\'il est actif.';

  @override
  String get featureRecordingPrivacyTitle => 'Mode tournage';

  @override
  String get featureRegionalFormatsDesc =>
      'Chaque membre choisit l\'affichage des nombres, des dates, de l\'horloge et du fuseau. Désactivé : tout le monde lit dans la région de la langue de l\'app, en 24 h, à l\'heure de l\'espace.';

  @override
  String get featureRegionalFormatsTitle => 'Région et formats';

  @override
  String get featureReportDesignExchangeDesc =>
      'Chaque maquette de rapport peut être écrite dans un fichier qui se décrit lui-même, puis relue. Le fichier contient la maquette ainsi que le sens de ses champs, le balisage accepté et les variables disponibles : une personne ou un outil peut donc l\'éditer hors de l\'application et la rendre. Un fichier destiné à un autre rapport, ou issu d\'une version plus récente, est refusé avec sa raison. Désactivé : les maquettes ne se modifient que dans l\'éditeur.';

  @override
  String get featureReportDesignExchangeTitle =>
      'Exporter et importer les maquettes';

  @override
  String get featureReportDesignerDesc =>
      'L\'éditeur de rapports en plein écran : éléments modifiés sur place dans leur vraie typographie, glisser pour réordonner, palette d\'insertion, sélecteur de champs avec recherche, annuler et rétablir, taille et alignement des images, garde-fou avant d\'abandonner, modèles et réinitialisation derrière une confirmation, l\'erreur du modèle expliquée, conception et aperçu côte à côte sur grand écran. Désactivé : l\'éditeur en feuille.';

  @override
  String get featureReportDesignerTitle => 'Concepteur de rapports';

  @override
  String get featureReportLayouts => 'Maquettes de rapport positionnées';

  @override
  String get featureReportLayoutsDesc =>
      'Concevez un rapport en indiquant où se place chaque élément, en mm, cm, px ou % ; le PDF imprime exactement cela. Un document doté d\'une maquette l\'utilise, les autres gardent leurs bandes.';

  @override
  String get featureReportTexts => 'Textes des rapports';

  @override
  String get featureReportTextsDesc =>
      'Le propriétaire rédige des textes (formule, note, paragraphe légal) par langue et les place dans n\'importe quel rapport avec text.cle — le libellé change sans toucher la maquette.';

  @override
  String featureRequires(String feature) {
    return 'Nécessite $feature';
  }

  @override
  String get featureRichMessageRefsDesc =>
      'Un message peut pointer vers une alerte, vers l\'historique de validation derrière une alerte, et vers une facture, un paiement ou un remboursement — chaque référence est un lien qui ouvre ce qu\'elle nomme. Chaque sélecteur de référence se filtre à la frappe. Désactivé : seules les réservations et les espaces sont référençables.';

  @override
  String get featureRichMessageRefsTitle => 'Références dans les messages';

  @override
  String get featureRoleAssignmentDesc =>
      'Affiche une section Rôles sur la page de chaque membre pour attribuer ou retirer un rôle, les membres ayant chaque rôle, et permet à chacun de voir ce qu\'il peut faire ici.';

  @override
  String get featureRoleAssignmentTitle => 'Attribution des rôles';

  @override
  String get featureRoleManagement => 'Gestion des rôles';

  @override
  String get featureRoleManagementDesc =>
      'La matrice centrale rôle→permission : le propriétaire décide quelle permission revient à quel rôle ; les autres consultent les leurs. Désactivée, les valeurs par défaut s\'appliquent simplement.';

  @override
  String get featureScheduledExpensesDesc =>
      'Dépenses récurrentes (internet, téléphone, électricité) : chaque membre en programme une avec sa règle (tous les X jours/semaines/mois/ans, X fois ou jusqu\'à une date) ; la programmation est validée une fois, et chaque échéance est présentée au membre — le montant validé compte immédiatement, un montant différent s\'explique et passe la validation des dépenses.';

  @override
  String get featureScheduledExpensesTitle => 'Dépenses programmées';

  @override
  String get featureSeatDayTimeline => 'Journée d\'une place';

  @override
  String get featureSeatDayTimelineDesc =>
      'Une place réservée sur une partie de la journée s\'affiche partiellement remplie sur le plan, et une place partagée par plusieurs personnes ouvre la journée en détail : qui l\'occupe, quand, et quelles plages restent libres.';

  @override
  String get featureSeriesBooking => 'Réservation en série';

  @override
  String get featureSeriesBookingDesc =>
      'Répéter une réservation chaque jour, chaque semaine ou en semaine.';

  @override
  String get featureServices => 'Services';

  @override
  String get featureServicesDesc =>
      'Catalogue de services et suivi des consommations.';

  @override
  String get featureSettlementFoldDesc =>
      'Les factures regroupées en une seule disparaissent des listes et se rangent sous la facture de regroupement, qui porte toutes leurs lignes. Sur une facture regroupée, toute opération est désactivée ; il ne reste que son PDF, tamponné du numéro dans lequel elle a été regroupée. Désactivé : les factures regroupées restent listées à côté de la facture de regroupement.';

  @override
  String get featureSettlementFoldTitle => 'Factures regroupées repliées';

  @override
  String get featureSingleRoomLevelNamesDesc =>
      'Quand un étage ne contient qu’une salle, les vues de réservation nomment l’étage plutôt que la salle — « 2e étage · Table 3 » au lieu de « Bureau 1 · Table 3 ». Une deuxième salle fait revenir les deux noms ; l’éditeur du plan montre toujours les salles.';

  @override
  String get featureSingleRoomLevelNamesTitle =>
      'Nommer par l’étage un étage à une seule salle';

  @override
  String get featureSiteDocuments => 'Sites sur les documents';

  @override
  String get featureSiteDocumentsDesc =>
      'Les documents nomment le site concerné : l\'adresse et le SIRET du site de rattachement de l\'adhérent côté vendeur, et les autres sites fréquentés dans le mois dans le détail. Désactivé : l\'adresse de l\'espace sur tous les documents.';

  @override
  String get featureSpaceInquiriesDesc =>
      'Une personne connectée qui trouve la page publiée peut écrire aux hôtes : les propriétaires et les administrateurs qui ont choisi d’être contacts publics. Les hôtes sont nommés avant l’écriture, et seuls cette personne et les hôtes lisent la conversation. Désactivé, le bouton et la vue Demandes disparaissent : personne n’ouvre de nouvelle demande ; celles en cours restent dans la boîte des hôtes pour y répondre et les clore.';

  @override
  String get featureSpaceInquiriesTitle => 'Écrire aux hôtes';

  @override
  String get featureSpaceQrCodes => 'Codes QR des espaces';

  @override
  String get featureSpaceQrCodesDesc =>
      'Cartes QR imprimables par poste, table, bureau et niveau — scanner pour réserver ou pointer.';

  @override
  String get featureSubscriptionInvoicesDesc =>
      'La cotisation est facturée avant le mois qu\'elle paie, à une date que vous choisissez. Désactivé : la cotisation reste sur la facture du mois.';

  @override
  String get featureSubscriptionInvoicesTitle => 'Factures d\'abonnement';

  @override
  String get featureSupplyExpensesDesc =>
      'Une dépense peut être une fourniture pour l\'espace (capsules, sacs d\'aspirateur…) : validée, elle réapprovisionne ou crée un service consommable avec un prix unitaire ; les consommations décomptent le stock.';

  @override
  String get featureSupplyExpensesTitle => 'Fournitures via les dépenses';

  @override
  String get featureSurfaceCalendarHint =>
      'Ce qui se passe, par jour et par mois.';

  @override
  String get featureSurfaceDocumentsHint =>
      'Les fichiers que l\'espace conserve et partage.';

  @override
  String get featureSurfaceEverywhere => 'Toute l\'application';

  @override
  String get featureSurfaceEverywhereHint =>
      'Change le comportement de l\'application, partout.';

  @override
  String get featureSurfaceKioskHint =>
      'La tablette à la porte, les badges et les scans.';

  @override
  String get featureSurfaceMembersHint =>
      'Qui fréquente l\'espace, leurs profils et leurs rôles.';

  @override
  String get featureSurfaceMessagesHint =>
      'Conversations, alertes et ce qui arrive sur le téléphone.';

  @override
  String get featureSurfaceMoneyHint =>
      'Relevés, paiements, factures et leur contenu.';

  @override
  String get featureSurfaceReports => 'Documents imprimés';

  @override
  String get featureSurfaceReportsHint =>
      'Factures, relevés et courriers, et leur allure sur le papier.';

  @override
  String get featureSurfaceReserveHint =>
      'Réserver une place, le plan, l\'arrivée.';

  @override
  String get featureSurfaceSettingsHint =>
      'La configuration de l\'espace lui-même.';

  @override
  String get featureTaskRecorderDesc =>
      'Permet d\'enregistrer les étapes d\'une tâche sur les écrans de cet espace, sur son propre appareil, de les relire et d\'exporter un fichier sans aucune valeur saisie. Rien n\'est envoyé. Désactivé : personne n\'enregistre ici.';

  @override
  String get featureTaskRecorderTitle => 'Enregistreur de tâches';

  @override
  String get featureTierCore => 'Essentiel';

  @override
  String get featureTierCoreDesc =>
      'Ce dont tout espace a besoin. Actif dès le premier jour.';

  @override
  String get featureTierPlatform => 'Plateforme';

  @override
  String get featureTierPlatformDesc =>
      'Demandé, jamais supposé. Activez ce que cet espace fait vraiment.';

  @override
  String get featureUiAnimationsDesc =>
      'Transitions fluides et animations d\'état dans toute l\'application. Désactivé, chaque changement est instantané ; le réglage « réduire les animations » de l\'appareil prime toujours.';

  @override
  String get featureUiAnimationsTitle => 'Animations de l\'interface';

  @override
  String get featureUniqueMonogramsDesc =>
      'Un avatar sans photo affiche des initiales propres à un seul membre : initiale du prénom et du nom, une lettre de plus en cas de collision, des chiffres seulement en dernier recours. Désactivé : la première lettre seule, identique pour tous ceux qui la partagent.';

  @override
  String get featureUniqueMonogramsTitle => 'Initiales d’avatar distinctes';

  @override
  String get featureUsageInvoicesDesc =>
      'Une fois le mois terminé, ce qu\'il a réellement coûté au-delà de l\'abonnement — dépassements, suppléments, services — est facturé à part. Désactivé : cela reste sur la facture du mois.';

  @override
  String get featureUsageInvoicesTitle => 'Factures de fin de mois';

  @override
  String get featureUsageRecordsDesc =>
      'Chaque réservation comptée laisse un relevé : la fenêtre réservée, le temps réellement passé, et ce qui est facturé. Une réservation où personne n\'est venu est facturée en entier. Un membre parti plus tôt peut demander que le temps non utilisé cesse d\'être facturé, et quelqu\'un d\'autre décide — jamais lui. Désactivé : aucun relevé, aucune correction.';

  @override
  String get featureUsageRecordsTitle => 'Relevés d\'usage';

  @override
  String get featureUsageReport => 'Rapport de consommation';

  @override
  String get featureUsageReportDesc =>
      'En fin de mois, le membre reçoit ce que sa participation a payé, ce qu\'il a réellement consommé et ce qui reste ou dépasse — d\'après les relevés d\'utilisation, sous forme de lettre.';

  @override
  String get featureValidationChainDesc =>
      'Une règle de validation peut demander ses validations l\'une après l\'autre, chaque étape sollicitée une fois la précédente passée, et peut autoriser le propriétaire — jamais un admin — à valider son propre acte. Désactivé : tout est demandé d\'un coup et personne ne valide son propre événement.';

  @override
  String get featureValidationChainTitle => 'Validations enchaînées';

  @override
  String get featureValidationScopesDesc =>
      'Chaque règle de validation nomme qui valide : les admins, des personnes désignées quel que soit leur rôle, ou tous les membres — et combien. Désactivé : propriétaire et admins comme avant.';

  @override
  String get featureValidationScopesTitle =>
      'Validateurs par rôle ou par personne';

  @override
  String get featureVatCounterparty => 'TVA selon le client';

  @override
  String get featureVatCounterpartyDesc =>
      'Qui est l\'acheteur pour la TVA, réglé sur chaque membre : TVA nationale, autoliquidation, hors UE, ou exonéré avec le motif imprimé. Désactivé : la règle automatique seule.';

  @override
  String get featureVatDeclarationsDesc =>
      'Générer la déclaration périodique de TVA depuis les factures émises, la rapprocher du formulaire officiel et la télétransmettre ou l’exporter.';

  @override
  String get featureVatDeclarationsTitle => 'Déclarations de TVA';

  @override
  String get featureVatGroups => 'Groupes de TVA';

  @override
  String get featureVatGroupsDesc =>
      'Chaque taux de TVA porte le groupe fiscal de ce qu\'il taxe — normal, intermédiaire, réduit, super-réduit, zéro, exonéré, non assujetti, consigne remboursable, produit à accises — avec la catégorie et la mention d\'exonération que le groupe implique. Désactivé : de simples pourcentages.';

  @override
  String get featureVatManagementDesc =>
      'L\'éditeur des taux de TVA et les sélecteurs de taux des services, forfaits, accessoires et paliers. Désactivé, la configuration disparaît ; les taux enregistrés continuent de s\'appliquer.';

  @override
  String get featureVatManagementTitle => 'Gestion de la TVA';

  @override
  String get featureVatRateHistory => 'Versions des taux de TVA';

  @override
  String get featureVatRateHistoryDesc =>
      'Un taux est une famille de versions datées : un changement par la loi ajoute la nouvelle valeur à sa date, l\'ancienne reste sur toute prestation antérieure, rien n\'est repointé. Désactivé : une valeur par taux.';

  @override
  String get featureVatReport => 'Rapport de TVA';

  @override
  String get featureVatReportDesc =>
      'Chaque position taxable d\'un mois ou d\'une période — document, client, HT, taux, TVA, TTC, catégorie — avec sous-totaux par taux, en lettre et en CSV pour le comptable.';

  @override
  String get featureWhatsappIntegration => 'Intégration WhatsApp';

  @override
  String get featureWhatsappIntegrationDesc =>
      'Les membres partagent leur numéro WhatsApp sur leur profil ; un geste sur un membre ouvre la discussion ; le lien du groupe dans l\'annuaire. Aucune intégration WhatsApp côté serveur.';

  @override
  String get featureWorkingHours => 'Horaires de travail';

  @override
  String get featureWorkingHoursDesc =>
      'Configurer la journée de travail et proposer la réservation à l\'heure exacte ; désactivé, les valeurs par défaut 8h–17h s\'appliquent.';

  @override
  String get featureWorkspaceBrandingDesc =>
      'L’espace choisit une couleur de marque dont l’application dérive ses thèmes clair et sombre, et les couleurs de remplissage de ses salles. Une couleur qui rendrait l’application illisible est refusée avec la raison ; la palette du produit reste la valeur par défaut.';

  @override
  String get featureWorkspaceBrandingTitle => 'Couleurs de l’espace';

  @override
  String get featureWorkspaceLibraryDesc =>
      'Enregistrez le plan de cet espace et sa façon de fonctionner comme modèle, choisissez qui peut le voir, invitez des personnes par e-mail, et partez de ce que d\'autres proposent.';

  @override
  String get featureWorkspaceLibraryTitle => 'Bibliothèque d\'espaces';

  @override
  String get featureWorkspaceStatus => 'Situation de l\'espace';

  @override
  String get featureWorkspaceStatusDesc =>
      'Ce que l\'espace a facturé, encaissé, remboursé et réparti sur une période, adhérent par adhérent — à l\'écran pour les propriétaires et admins, et en rapport imprimable. Désactivé : pas de vue de situation.';

  @override
  String get featureWorkspaceVocabularyDesc =>
      'L’espace peut renommer, par langue, un petit ensemble approuvé de mots du produit — une place, les libellés de la légende, les onglets. Tout le reste conserve les mots du produit, et un espace qui ne renomme rien s’affiche exactement comme avant.';

  @override
  String get featureWorkspaceVocabularyTitle => 'Vocabulaire de l’espace';

  @override
  String get featuresFilterChanged => 'Modifiées';

  @override
  String get featuresNoMatch => 'Aucune fonctionnalité ne correspond.';

  @override
  String get featuresSearchLabel => 'Rechercher une fonctionnalité';

  @override
  String get featuresTitle => 'Fonctionnalités';

  @override
  String get featuresViewProcesses => 'Processus';

  @override
  String get featuresViewSwitches => 'Interrupteurs';

  @override
  String get fecAccountBank => 'Banque';

  @override
  String get fecAccountCustomers => 'Clients';

  @override
  String get fecAccountExpenses => 'Achats et charges';

  @override
  String get fecAccountRevenue => 'Ventes';

  @override
  String get fecAccountVat => 'TVA collectée';

  @override
  String get fecAccountsIntro =>
      'Un FEC est fait d\'écritures comptables : il lui faut des numéros de compte. Voici les comptes du plan comptable général — remplacez-les par ceux de votre comptable si besoin.';

  @override
  String get fecAccountsTitle => 'Comptes à utiliser';

  @override
  String get fecMissingSiren =>
      'Le FEC porte le nom de votre numéro d\'immatriculation — renseignez-le d\'abord dans Identité légale.';

  @override
  String get federationActionExistingAccount =>
      'Me connecter à mon compte existant';

  @override
  String get federationActionReviewServer => 'Vérifier le serveur';

  @override
  String get federationCancel => 'Annuler';

  @override
  String get federationClose => 'Fermer';

  @override
  String get federationContinue => 'Continuer avec Deskilo';

  @override
  String federationDetailAuthority(String host) {
    return 'Autorité d\'identité : $host';
  }

  @override
  String federationDetailServer(String host) {
    return 'Serveur : $host';
  }

  @override
  String get federationDetails => 'Détails techniques';

  @override
  String get federationFailureBrowser =>
      'Le navigateur n\'a pas pu s\'ouvrir. Vérifiez qu\'un navigateur est disponible, puis réessayez.';

  @override
  String get federationFailureExpired =>
      'Cette connexion a pris trop de temps et a expiré. Recommencez-la.';

  @override
  String get federationFailureIncompatible =>
      'Ce serveur n\'accepte pas cette connexion Deskilo. Vérifiez l\'adresse du serveur ou contactez son administrateur.';

  @override
  String get federationFailureNetwork =>
      'Le serveur est injoignable, la connexion n\'a donc pas abouti. Vérifiez votre connexion, puis réessayez.';

  @override
  String get federationFailureProviderMissing =>
      'La connexion Deskilo n\'est pas configurée sur ce serveur. Demandez à son administrateur de l\'activer.';

  @override
  String get federationFailureRefused =>
      'La connexion a été annulée ou refusée dans le navigateur. Rien n\'a changé ; vous pouvez réessayer.';

  @override
  String get federationFailureUnlinked =>
      'Ce compte Deskilo correspond à un compte d\'ici qui ne lui est pas encore lié. Connectez-vous à ce compte, puis liez Deskilo dans Comptes liés. Rien n\'est fusionné avant la confirmation du serveur.';

  @override
  String get federationFailureWrongAccount =>
      'Votre navigateur s\'est connecté avec un autre compte Deskilo. Changez de compte dans le navigateur, puis réessayez.';

  @override
  String federationPurpose(String server) {
    return 'Votre navigateur confirme votre compte Deskilo, puis vous ramène à $server. Vos adhésions et votre historique ici restent inchangés.';
  }

  @override
  String get federationRetry => 'Réessayer';

  @override
  String get federationStageCompleting => 'Finalisation de la connexion…';

  @override
  String get federationStageOpening => 'Ouverture de la connexion…';

  @override
  String get federationStageWaiting =>
      'En attente de la connexion dans votre navigateur…';

  @override
  String get fieldProblemNotAChoice => 'Choisissez dans la liste.';

  @override
  String get fieldProblemNotADate => 'Une date, merci.';

  @override
  String get fieldProblemNotANumber => 'Un nombre, merci.';

  @override
  String get fieldProblemNotAPhone => 'Ce n\'est pas un numéro de téléphone.';

  @override
  String get fieldProblemNotAUrl => 'Ce n\'est pas une adresse web.';

  @override
  String get fieldProblemNotAnEmail => 'Ce n\'est pas une adresse e-mail.';

  @override
  String get fieldProblemNotWhole => 'Un nombre entier, merci.';

  @override
  String get fieldProblemRequired => 'Merci de répondre.';

  @override
  String fieldProblemTooEarly(String date) {
    return 'Pas avant le $date.';
  }

  @override
  String fieldProblemTooLarge(String max) {
    return 'Au plus $max.';
  }

  @override
  String fieldProblemTooLate(String date) {
    return 'Pas après le $date.';
  }

  @override
  String fieldProblemTooLong(int count) {
    return 'Au plus $count caractères.';
  }

  @override
  String fieldProblemTooShort(int count) {
    return 'Au moins $count caractères.';
  }

  @override
  String fieldProblemTooSmall(String min) {
    return 'Au moins $min.';
  }

  @override
  String get financesAllSpaces => 'Tous les espaces';

  @override
  String get financesAutomatic => 'automatique';

  @override
  String get financesAwaitingValidation => 'Paiement en cours de validation';

  @override
  String get financesDevSection =>
      'Espaces de développement — données de test, non comptées ci-dessus';

  @override
  String financesDueOn(String date) {
    return 'Échéance le $date';
  }

  @override
  String get financesFullHistory =>
      'Historique complet, consommation et autres serveurs';

  @override
  String financesLinkAction(String space) {
    return 'Ouvrir pour $space';
  }

  @override
  String get financesLinkBody =>
      'Vos factures, rappels et paiements de tous vos espaces sont réunis dans Moi › Finances.';

  @override
  String get financesLinkTitle => 'Vos finances dans tous vos espaces';

  @override
  String get financesNoReminders => 'Aucun rappel reçu.';

  @override
  String get financesNothingOwed => 'Rien à payer — vous êtes à jour.';

  @override
  String get financesNothingPaid => 'Aucune facture réglée pour l’instant.';

  @override
  String get financesOutstanding => 'À payer';

  @override
  String financesOverdueCount(int count) {
    return '$count en retard';
  }

  @override
  String financesOverdueSince(String date) {
    return 'En retard depuis le $date';
  }

  @override
  String get financesPaid => 'Payées';

  @override
  String get financesPartlyPaid => 'Partiellement payée';

  @override
  String get financesPayments => 'Paiements';

  @override
  String financesRemindedTimes(int count) {
    return 'Relancée ×$count';
  }

  @override
  String financesReminderLevel(int level) {
    return 'Rappel $level';
  }

  @override
  String get financesReminders => 'Rappels';

  @override
  String get financesStateClosed => 'Clôturée';

  @override
  String get financesStatePaid => 'Payée';

  @override
  String get financesStateRefunded => 'Remboursée';

  @override
  String get financesTitle => 'Finances';

  @override
  String get financesToPay => 'À payer';

  @override
  String get gettingStartedActionChooseDay => 'Choisir un autre jour';

  @override
  String get gettingStartedActionChooseTime => 'Choisir un créneau';

  @override
  String get gettingStartedActionFinishSetup => 'Terminer la mise en place';

  @override
  String get gettingStartedActionHelp => 'Aide pour cet espace';

  @override
  String get gettingStartedActionMembership => 'Voir mon adhésion';

  @override
  String gettingStartedAllowance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vous pouvez tenir $count réservations à la fois.',
      one: 'Vous pouvez tenir une réservation à la fois.',
    );
    return '$_temp0';
  }

  @override
  String get gettingStartedAvailabilityUnknown =>
      'Les disponibilités n’ont pas pu être chargées. L’aide explique comment la réservation fonctionne ici.';

  @override
  String gettingStartedBooked(String id, String state) {
    return 'Votre réservation $id est $state. Votre adhésion indique ce qui est compris par ailleurs.';
  }

  @override
  String get gettingStartedClosedToday =>
      'L’espace est fermé le jour sélectionné. Choisissez un autre jour pour voir ce qui est libre.';

  @override
  String get gettingStartedEnvDev => 'Espace de développement';

  @override
  String get gettingStartedEnvProd => 'Espace de production';

  @override
  String get gettingStartedMembershipUnknown =>
      'Votre adhésion n’a pas pu être chargée pour le moment. L’aide explique comment cet espace fonctionne.';

  @override
  String get gettingStartedNoSpaces =>
      'Rien ne peut encore être réservé ici. Votre adhésion indique ce que comprend votre accès.';

  @override
  String get gettingStartedNotNow => 'Pas maintenant';

  @override
  String get gettingStartedReadyToBook =>
      'L’espace est ouvert ce jour-là. Choisissez un créneau et une place sur le plan — rien n’est réservé tant que vous ne confirmez pas.';

  @override
  String get gettingStartedReopen => 'Premiers pas';

  @override
  String get gettingStartedSemantics =>
      'Premiers pas : une prochaine étape suggérée';

  @override
  String gettingStartedSetupIncomplete(String step) {
    return 'Avant que quiconque puisse réserver ici : $step.';
  }

  @override
  String get gettingStartedStandingAdmin => 'Vous êtes administrateur ici.';

  @override
  String get gettingStartedStandingMember => 'Vous êtes membre ici.';

  @override
  String get gettingStartedStandingOwner =>
      'Vous êtes propriétaire de cet espace.';

  @override
  String get gettingStartedStateCancelled => 'annulée';

  @override
  String get gettingStartedStateCheckedIn => 'pointée';

  @override
  String get gettingStartedStateCompleted => 'terminée';

  @override
  String get gettingStartedStateReleased => 'libérée';

  @override
  String get gettingStartedStateReserved => 'réservée';

  @override
  String gettingStartedTitle(String workspace) {
    return 'Premiers pas dans $workspace';
  }

  @override
  String get groupAnnounceOnly => 'Seuls les admins peuvent écrire';

  @override
  String get groupAnnounceOnlyHint =>
      'Tout le monde lit ; seuls les admins écrivent.';

  @override
  String get groupCreate => 'Créer le groupe';

  @override
  String get groupDescription => 'Description';

  @override
  String get groupDescriptionAdd => 'Ajouter une description';

  @override
  String get groupDescriptionTitle => 'Description du groupe';

  @override
  String get groupMakeAdmin => 'Nommer admin';

  @override
  String get groupName => 'Nom du groupe';

  @override
  String get groupNeedsPeople => 'Ajoutez au moins une personne.';

  @override
  String get groupNew => 'Nouveau groupe';

  @override
  String get groupNewTitle => 'Nouveau groupe';

  @override
  String get groupPeople => 'Personnes du groupe';

  @override
  String get groupPickPeople => 'Ajouter des personnes';

  @override
  String get groupPostingClosed =>
      'Seuls les admins peuvent écrire dans ce groupe.';

  @override
  String get groupRemoveAdmin => 'Retirer admin';

  @override
  String get groupRename => 'Renommer le groupe';

  @override
  String get groupRenameTitle => 'Nom du groupe';

  @override
  String get guideActionConfirmBooking =>
      'confirmez la réservation et attendez la réponse';

  @override
  String get guideActionOpenReserve => 'ouvrez Réserver';

  @override
  String get guideActionSelectDate => 'choisissez le jour';

  @override
  String get guideActionSelectPeriod => 'choisissez la période';

  @override
  String get guideActionSelectResource =>
      'choisissez une place sur le plan ou dans la liste';

  @override
  String get guideBookingRefusedRecovery =>
      'La réservation a été refusée (place prise ou règle). Choisissez une autre place ou période, puis confirmez à nouveau.';

  @override
  String get guideBuiltinBooking => 'Réserver une place';

  @override
  String get guideBuiltinBookingIntro =>
      'Ce guide montre comment réserver une place : choisissez le jour et la période, une place, puis confirmez. Rien n\'est réservé avant votre confirmation.';

  @override
  String get guideHostBack => 'Retour';

  @override
  String get guideHostBlocked =>
      'Réglez d\'abord le message à l\'écran ; le guide attend.';

  @override
  String get guideHostClose => 'Fermer';

  @override
  String get guideHostCommand => 'Confirmez, puis attendez le résultat.';

  @override
  String get guideHostCompleted => 'Guide terminé.';

  @override
  String get guideHostDestination => 'Destination de l’étape';

  @override
  String get guideHostDestinationMissing =>
      'Choisissez la page de cette étape dans l’éditeur du guide.';

  @override
  String guideHostDoAction(String action) {
    return 'Ensuite : $action.';
  }

  @override
  String get guideHostDone => 'Fait';

  @override
  String get guideHostFillField =>
      'Remplissez le champ mis en évidence, puis quittez-le.';

  @override
  String guideHostFillLabel(String label) {
    return 'Remplissez « $label », puis quittez le champ.';
  }

  @override
  String get guideHostGoToPage => 'Aller à la page';

  @override
  String get guideHostInstruction => 'Lisez ceci, puis marquez-le comme fait.';

  @override
  String get guideHostManual =>
      'Faites cette étape vous-même, puis marquez-la comme faite.';

  @override
  String guideHostManualAt(String form) {
    return 'Effectuez cette étape sur « $form », puis marquez-la comme faite.';
  }

  @override
  String guideHostManualProtected(String category) {
    return 'Cette partie se passe sur un écran protégé ($category). Faites-la vous-même, puis marquez-la comme faite.';
  }

  @override
  String get guideHostMinimize => 'Réduire le guide';

  @override
  String get guideHostNotOnScreen =>
      'Ouvrez la page de l’étape, puis suivez les étapes précédentes pour afficher ce contrôle.';

  @override
  String guideHostOpenLabel(String label) {
    return 'Ouvrez « $label ».';
  }

  @override
  String get guideHostOpenScreen => 'Ouvrez l\'écran suivant.';

  @override
  String get guideHostPausedFeature =>
      'En pause : l\'enregistreur de tâches est désactivé dans cet espace.';

  @override
  String get guideHostPausedScope =>
      'En pause : le compte ou l\'espace a changé. Le guide ne continue que là où il a commencé.';

  @override
  String get guideHostRecovery =>
      'C\'est refusé. Suivez ces étapes, puis réessayez.';

  @override
  String guideHostRestore(int current, int total) {
    return 'Afficher le guide (étape $current sur $total)';
  }

  @override
  String get guideHostResume => 'Reprendre';

  @override
  String get guideHostShowMe => 'Ouvrir et mettre en évidence';

  @override
  String get guideHostSkip => 'Passer';

  @override
  String get guideHostStatusAcknowledged => 'Pris en compte';

  @override
  String get guideHostStatusDone => 'Fait';

  @override
  String get guideHostStatusPending => 'À faire';

  @override
  String get guideHostStatusSkipped => 'Passé';

  @override
  String get guideHostStatusWaiting => 'En attente';

  @override
  String guideHostStepOf(int current, int total) {
    return 'Étape $current sur $total';
  }

  @override
  String get guideHostSteps => 'Toutes les étapes';

  @override
  String get guideHostStop => 'Arrêter le guide';

  @override
  String get guideHostStopped => 'Guide arrêté. Rien n\'a été annulé.';

  @override
  String get guideHostTapControl => 'Touchez le contrôle mis en évidence.';

  @override
  String guideHostTapLabel(String label) {
    return 'Touchez « $label ».';
  }

  @override
  String get guideHostTitle => 'Tâche guidée';

  @override
  String get guideHostUncertain =>
      'La réponse n\'est pas arrivée. Vérifiez si l\'action a eu lieu avant de réessayer.';

  @override
  String get guideHostWaiting => 'En attente du résultat…';

  @override
  String get guideStart => 'Lancer le guide';

  @override
  String get guideStartNotRunnable =>
      'Ce guide contient des étapes que cette version de l\'application ne connaît pas ; il peut être lu, pas suivi.';

  @override
  String get guideStartRefused =>
      'Ce guide ne peut pas démarrer ici : connectez-vous et activez l\'enregistreur de tâches dans cet espace.';

  @override
  String handoffAmountOutOfRange(String number) {
    return '$number : un total trop grand pour être transmis exactement';
  }

  @override
  String get handoffBlocked =>
      'Ce fichier ne peut pas être transmis tant que la source n’est pas corrigée.';

  @override
  String get handoffChanged =>
      'Les factures ont changé pendant votre relecture. Exportez à nouveau pour voir les comptes actuels.';

  @override
  String handoffDuplicate(String number) {
    return '$number : apparaît deux fois dans la source';
  }

  @override
  String handoffExcludedSettlements(String count) {
    return '$count récapitulatif(s) de règlement écarté(s) : leurs factures figurent déjà';
  }

  @override
  String handoffIncluded(String count) {
    return '$count document(s) dans le fichier';
  }

  @override
  String get handoffIssued => 'Émises';

  @override
  String handoffMissingCurrency(String number) {
    return '$number : aucune devise';
  }

  @override
  String handoffOrphanMatch(String key) {
    return 'Un paiement ($key) ne correspond à aucun document de cet export';
  }

  @override
  String handoffOverpaid(String number) {
    return '$number : payé au-delà du montant facturé';
  }

  @override
  String handoffPayments(String confirmed, String pending) {
    return 'Payé : $confirmed confirmé, $pending en attente';
  }

  @override
  String handoffRowMismatch(String detail) {
    return 'Les lignes du fichier ne correspondent pas aux documents ($detail)';
  }

  @override
  String get handoffSave => 'Enregistrer le fichier et le rapport';

  @override
  String get handoffTitle => 'Avant d’enregistrer';

  @override
  String handoffUnsupportedCurrency(String number) {
    return '$number : sa devise n’a pas de nombre de décimales vérifié';
  }

  @override
  String get handoffVoided => 'Annulées';

  @override
  String get helpContents => 'Sommaire';

  @override
  String get helpDotTooltip => 'Ouvrir le guide';

  @override
  String get helpGuidedTasks => 'Tâches guidées';

  @override
  String get helpHintAvailability =>
      'Définissez les jours d\'ouverture et les horaires, et ajoutez des jours de fermeture que personne ne peut réserver.';

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
  String get helpHintAvailabilityTopic => 'Disponibilité';

  @override
  String get helpHintBadges =>
      'Émettez un badge QR imprimable ou enregistrez une carte NFC ; révoquez un badge perdu à tout moment.';

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
  String get helpHintBadgesTopic => 'badges RFID';

  @override
  String get helpHintCalendar =>
      'Choisissez un jour ou une période : tout ce qui est daté et que vous pouvez voir, en une liste, chaque ligne ouvrant sa source.';

  @override
  String get helpHintCalendarTip2 =>
      'Passez de Jour à Période pour voir une semaine ou un mois d\'un coup — les flèches avancent de la taille de votre sélection.';

  @override
  String get helpHintCalendarTip3 =>
      'Touchez une puce de type pour ne voir que cela : réservations, alertes, messages, factures, paiements, consommations, rappels.';

  @override
  String get helpHintCalendarTip4 =>
      'Chaque ligne ouvre sa source — la réservation, la conversation, l\'alerte, la facture, ou ce mois dans Finances.';

  @override
  String get helpHintCalendarTip4Topic => 'Comment la réservation se comporte';

  @override
  String get helpHintCalendarTip5 =>
      'Le bouclier montre qui peut voir chaque type, et qui a réellement consulté vos finances.';

  @override
  String get helpHintCalendarTip5Topic => 'Confidentialité';

  @override
  String get helpHintCalendarTopic => 'Calendrier';

  @override
  String get helpHintDismiss => 'Masquer l\'astuce';

  @override
  String get helpHintEditor =>
      'Dessinez salles et bureaux, posez les places — touchez deux fois une place pour modifier ses propriétés.';

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
  String get helpHintEditorTopic => 'éditeur d\'espace';

  @override
  String get helpHintEvents =>
      'Tout ce qui s\'est passé, dans un seul fil. Les décisions qui vous attendent sont en haut ; les filtres affinent le reste.';

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
  String get helpHintEventsTopic => 'Événements';

  @override
  String get helpHintFeatures =>
      'Activez ou désactivez les fonctionnalités de l\'espace — l\'application de chaque membre suit immédiatement.';

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
  String get helpHintFeaturesTopic => 'Fonctionnalités';

  @override
  String get helpHintLearnMore => 'En savoir plus';

  @override
  String get helpHintMembers =>
      'Invitez des membres, réglez leur forfait et leur rôle, et gérez leurs badges.';

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
  String get helpHintMembersTipNegotiation =>
      'Les prix propres d\'un membre : ouvrez sa fiche → Négociation tarifaire, saisissez l\'abonnement, le dépassement ou la remise convenus, et les validateurs de la règle confirment.';

  @override
  String get helpHintMembersTipNegotiationTopic => 'Négociations tarifaires';

  @override
  String get helpHintMembersTopic => 'Membres et forfaits';

  @override
  String get helpHintMessages =>
      'Toutes vos conversations dans une liste, la plus récente en haut. Touchez le crayon pour écrire à quelqu’un ou créer un groupe.';

  @override
  String get helpHintMessagesTip2 =>
      'Choisissez une personne pour une discussion privée, ou plusieurs pour créer un groupe — le champ du nom apparaît dès qu’il y en a deux, et ce nom est unique ici : personne n’a à deviner à quelle « Équipe » il écrit.';

  @override
  String get helpHintMessagesTip3 =>
      'Touchez un nom en haut d’une discussion pour voir son profil : la réservation du jour, la présence sur place, et comment le joindre.';

  @override
  String get helpHintMessagesTip4 =>
      'La recherche trouve les membres, les groupes et les mots dans les messages — un résultat vous y emmène directement.';

  @override
  String get helpHintMessagesTip5 =>
      'Insérez une réservation ou un espace dans un message plutôt que de le décrire ; le lecteur le touche et arrive au bon endroit.';

  @override
  String get helpHintMessagesTopic => 'Messages';

  @override
  String get helpHintMoney =>
      'Votre relevé mensuel : parcourez les mois avec les flèches ; payez, exportez ou partagez d\'ici.';

  @override
  String get helpHintMoneyDocuments =>
      'Vos documents : vos conditions, le rapport des paiements, le relevé du mois en PDF, la bibliothèque de documents.';

  @override
  String get helpHintMoneyDocumentsTip3 =>
      'Mes conditions est votre accord financier en vigueur — formule, tarif, extras — rendu en document à conserver.';

  @override
  String get helpHintMoneyDocumentsTopic => 'Le volet Documents';

  @override
  String get helpHintMoneyInvoices =>
      'Vos factures : ce qui est ouvert et pour quand, chaque facture qui vous a été émise avec son état, un geste vers le détail et vers le paiement.';

  @override
  String get helpHintMoneyInvoicesTip2 =>
      'Passé le délai de paiement de l\'espace, une facture ouverte se lit ici en retard, et les niveaux de relance configurés par le propriétaire arrivent d\'eux-mêmes — dans votre fil et en notification.';

  @override
  String get helpHintMoneyInvoicesTip2Topic =>
      'Relances de paiement automatiques';

  @override
  String get helpHintMoneyInvoicesTopic => 'Le volet Factures';

  @override
  String get helpHintMoneyPayments =>
      'Régler et demander : le solde, comment le régler ou payer en ligne, enregistrer un paiement — et soumettre une dépense, demander des demi-journées ou ajouter une consommation.';

  @override
  String get helpHintMoneyPaymentsTip2 =>
      'Enregistrez un paiement avec la date du mouvement et le mois qu\'il solde — l\'autre partie confirme.';

  @override
  String get helpHintMoneyPaymentsTip3 =>
      'Payer en ligne règle le dû immédiatement ; la carte des instructions montre la voie manuelle avec la référence à indiquer.';

  @override
  String get helpHintMoneyPaymentsTip3Topic => 'paiements en ligne';

  @override
  String get helpHintMoneyPaymentsTipSupply =>
      'Vous avez acheté des capsules ou des sacs d\'aspirateur pour l\'espace ? Soumettez la dépense comme fourniture : validée, elle va sur l\'étagère comme consommable que les autres paient, et vous êtes remboursé.';

  @override
  String get helpHintMoneyPaymentsTipSupplyTopic => 'Services et Accessoires';

  @override
  String get helpHintMoneyPaymentsTopic => 'Le volet Paiements';

  @override
  String get helpHintMoneyStatement =>
      'Le mois tel qu\'il est : votre compte, jours utilisés et restants, abonnement, services, forfaits, positions ouvertes, avoirs et le solde. Parcourez les mois avec les flèches.';

  @override
  String get helpHintMoneyStatementTip2 =>
      'Une matinée réservée compte pour une demi-journée ; les jours hors horaires suivent la politique hors-horaires de l\'espace.';

  @override
  String get helpHintMoneyStatementTip2Topic =>
      'Comment la réservation se comporte';

  @override
  String get helpHintMoneyStatementTip3 =>
      'Plus de jours ? Demandez des demi-journées, achetez un forfait ou continuez à la consommation — selon votre formule.';

  @override
  String get helpHintMoneyStatementTipNegotiation =>
      'Vos conditions négociées sont dans Documents, à côté de votre accord. La carte les compare au tarif et indique qui peut les consulter ; les consultations des autres sont enregistrées.';

  @override
  String get helpHintMoneyStatementTipNegotiationTopic =>
      'Négociations tarifaires';

  @override
  String get helpHintMoneyStatementTopic => 'Le volet Relevé';

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
  String get helpHintMoneyTopic => 'Argent';

  @override
  String get helpHintNextTip => 'Astuce suivante';

  @override
  String get helpHintPlan =>
      'Le plan en direct : touchez une place libre pour réserver, touchez votre réservation pour pointer votre arrivée.';

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
  String get helpHintPlanTopic => 'Le plan';

  @override
  String get helpHintPrevTip => 'Astuce précédente';

  @override
  String get helpHintPrivacy =>
      'Voyez qui peut lire vos données et qui l\'a fait, exportez tout en un fichier, ou partez avec vos données personnelles effacées.';

  @override
  String get helpHintPrivacyTip2 =>
      'Les messages ne sont lisibles que par les personnes de la conversation, quel que soit leur rôle ; l\'argent seulement par vous et la permission finances.';

  @override
  String get helpHintPrivacyTip3 =>
      'Chaque lecture de vos finances par quelqu\'un d\'autre est journalisée par le serveur — le journal ne peut être ni contourné ni modifié.';

  @override
  String get helpHintPrivacyTopic => 'Confidentialité';

  @override
  String get helpHintReserve =>
      'Choisissez un jour et un créneau, puis touchez une place libre pour la réserver.';

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
  String get helpHintReserveTopic => 'hub Réserver';

  @override
  String get helpHintRestoreTitle => 'Réafficher les astuces d\'aide';

  @override
  String get helpHintRestored =>
      'Les astuces d\'aide seront de nouveau affichées.';

  @override
  String get helpHintValidation =>
      'Décidez quelles actions demandent confirmation, qui confirme et combien d\'approbations il faut.';

  @override
  String get helpHintValidationTip2 =>
      'Une carte par type d\'événement, chacune héritant de la règle par défaut tant que vous ne l\'éditez pas — paiements, dépenses, rôles et plus.';

  @override
  String get helpHintValidationTip3 =>
      'Personne ne valide jamais son propre événement, et une demande sans réponse expire après 7 jours — rien n\'est accordé en silence.';

  @override
  String get helpHintValidationTipScopes =>
      'Qui valide, c\'est la portée de la règle : les admins, des personnes désignées quel que soit leur rôle, ou tous les membres — et combien. Le propriétaire peut toujours ; personne ne valide son propre événement.';

  @override
  String get helpHintValidationTipScopesTopic => 'Gestion des rôles';

  @override
  String get helpHintValidationTopic => 'confirmations';

  @override
  String get helpHintWorkspace =>
      'Pays, devise, langue et coordonnées de facturation — documents et taxes suivent ces réglages.';

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
  String get helpHintWorkspaceTopic => 'Réglages de l\'espace';

  @override
  String get helpTitle => 'Aide';

  @override
  String get helpTopicAccounting => 'Exports comptables';

  @override
  String get helpTopicBilling => 'Facturation';

  @override
  String get helpTopicBookingLimits => 'Limites de réservation';

  @override
  String get helpTopicBookingPolicies => 'Règles de réservation';

  @override
  String get helpTopicDeployment => 'Déployer';

  @override
  String get helpTopicDocumentLibrary => 'bibliothèque de documents';

  @override
  String get helpTopicEinvoice => 'facture électronique';

  @override
  String get helpTopicEnvironments => 'Environnements';

  @override
  String get helpTopicInstances => 'Instances';

  @override
  String get helpTopicKiosk => 'Mode borne';

  @override
  String get helpTopicLegalIdentity => 'Identité légale';

  @override
  String get helpTopicReadiness => 'recevabilité';

  @override
  String get helpTopicReportEditor => 'éditeur de rapports';

  @override
  String get helpTopicReportLayout => 'Les mises en page positionnées';

  @override
  String get helpTopicScheduledExpenses => 'Dépenses programmées';

  @override
  String get helpTopicServer => 'votre propre serveur';

  @override
  String get helpTopicSettings => 'Réglages et profil';

  @override
  String get helpTopicTrace => 'Le journal';

  @override
  String get helpTopicVat => 'TVA';

  @override
  String get helpTopicWindowEnvelope => 'Le contrat de l\'enveloppe à fenêtre';

  @override
  String get helpTopicWorkingHours => 'Horaires de travail';

  @override
  String get helpTopicWorkspaceId => 'ID de l\'espace';

  @override
  String get holidayAllSaints => 'Toussaint';

  @override
  String get holidayArmistice => 'Armistice 1918';

  @override
  String get holidayAscension => 'Ascension';

  @override
  String get holidayAssumption => 'Assomption';

  @override
  String get holidayBoxingDay => 'Deuxième jour de Noël';

  @override
  String get holidayChristmas => 'Noël';

  @override
  String get holidayEasterMonday => 'Lundi de Pâques';

  @override
  String get holidayGermanUnity => 'Jour de l\'Unité allemande';

  @override
  String get holidayGoodFriday => 'Vendredi saint';

  @override
  String get holidayImportAction =>
      'Importer les jours fériés (données ouvertes)';

  @override
  String holidayImportConfirm(int count) {
    return 'Importer $count jours de fermeture';
  }

  @override
  String get holidayImportFailed =>
      'Les jours fériés n\'ont pas pu être vérifiés ni importés. Rien n\'a été modifié.';

  @override
  String get holidayImportNationwide => 'Jours fériés nationaux uniquement';

  @override
  String get holidayImportRegion => 'Région';

  @override
  String get holidayImportRetry => 'Réessayer';

  @override
  String holidayImportSource(String source) {
    return 'Source : $source';
  }

  @override
  String get holidayImportUnavailable =>
      'La source des jours fériés est injoignable pour le moment. Réessayez plus tard, ou utilisez « Ajouter les jours fériés ».';

  @override
  String get holidayLabourDay => 'Fête du Travail';

  @override
  String get holidayNationalDay => 'Fête nationale';

  @override
  String get holidayNewYear => 'Jour de l\'An';

  @override
  String get holidayVictory1945 => 'Victoire 1945';

  @override
  String get holidayWhitMonday => 'Lundi de Pentecôte';

  @override
  String get identityConnectBrowser => 'Le navigateur n\'a pas pu être ouvert.';

  @override
  String identityConnectConfirmApply(String name) {
    return 'Envoyer votre demande d\'adhésion à $name ?';
  }

  @override
  String get identityConnectConfirmApplyBody =>
      'Vous êtes maintenant connecté. L\'espace examine votre demande ; rien d\'autre n\'est partagé.';

  @override
  String get identityConnectContinue => 'Continuer avec Deskilo';

  @override
  String get identityConnectCurrentServer =>
      'C\'est le serveur auquel vous êtes déjà connecté.';

  @override
  String get identityConnectDifferentAuthority =>
      'Ce serveur accepte un autre fournisseur d\'identité.';

  @override
  String identityConnectDone(String host) {
    return 'Connecté à $host.';
  }

  @override
  String get identityConnectExistingAccount =>
      'Utiliser un compte que j\'ai déjà sur ce serveur';

  @override
  String get identityConnectExpired =>
      'La connexion a pris trop de temps. Recommencez.';

  @override
  String identityConnectExplain(String host) {
    return '$host saura que c\'est vous, grâce à votre identité Deskilo. Se connecter ne fait pas de vous un membre, ne vous donne aucun rôle et ne connecte aucun assistant : l\'espace décide toujours de chaque demande.';
  }

  @override
  String get identityConnectNetwork =>
      'Le serveur n\'a pas répondu. Réessayez.';

  @override
  String get identityConnectNoDeskiloSignIn =>
      'Ce serveur ne propose pas la connexion avec Deskilo.';

  @override
  String get identityConnectNoSharedIdentity =>
      'Votre compte ici n\'a pas d\'identité Deskilo qu\'un autre serveur pourrait accepter.';

  @override
  String identityConnectNotSaved(String host) {
    return '$host vous a accepté, mais cet appareil n\'a pas pu garder la connexion. Rien n\'a été envoyé. Réessayez.';
  }

  @override
  String get identityConnectRefused =>
      'La connexion n\'a pas abouti. Rien n\'a été envoyé.';

  @override
  String get identityConnectRetry => 'Réessayer';

  @override
  String get identityConnectSend => 'Envoyer la demande';

  @override
  String get identityConnectServerUnsupported =>
      'Ce serveur ne peut pas être connecté depuis cette version de l\'application.';

  @override
  String identityConnectTitle(String host) {
    return 'Se connecter à $host';
  }

  @override
  String get identityConnectUnavailable => 'Ce serveur n\'a pas répondu.';

  @override
  String get identityConnectUnlinked =>
      'Un compte de ce serveur utilise déjà cette identité ou cette adresse e-mail sans y être lié. Utilisez plutôt ce compte.';

  @override
  String get identityConnectWaiting =>
      'Terminez la connexion dans votre navigateur, puis revenez ici.';

  @override
  String get identityConnectWrongAccount =>
      'Le navigateur s\'est connecté avec quelqu\'un d\'autre. Rien n\'a été connecté.';

  @override
  String identityConsentAsks(String host) {
    return 'Utilisez votre identité Deskilo pour vous connecter à $host.';
  }

  @override
  String get identityConsentCompleting => 'Enregistrement de votre choix…';

  @override
  String get identityConsentPurpose =>
      'Les accès aux espaces et aux assistants sont approuvés séparément.';

  @override
  String get identityConsentReturnFailed =>
      'Impossible d’ouvrir la destination.';

  @override
  String get identityConsentReturning => 'Retour à la connexion…';

  @override
  String get identityConsentTitle => 'Continuer avec Deskilo';

  @override
  String get identityConsentUnavailable =>
      'Cette demande de connexion est indisponible. Revenez au site de destination et recommencez.';

  @override
  String get inboxAlertsTab => 'Alertes';

  @override
  String get inboxChatsTab => 'Discussions';

  @override
  String get inboxFilterAll => 'Tous';

  @override
  String get inboxFilterArchived => 'Archivés';

  @override
  String get inboxFilterUnread => 'Non lus';

  @override
  String get inboxMessengerDoor => 'Ouvrir ma messagerie';

  @override
  String get inboxNoArchived => 'Aucune conversation archivée.';

  @override
  String get inboxNoUnread => 'Rien de non lu — vous êtes à jour.';

  @override
  String get inboxRetry => 'Réessayer';

  @override
  String get instanceAccessTitle => 'Accès aux assistants';

  @override
  String instanceAccessUntil(String date) {
    return 'Jusqu\'au $date';
  }

  @override
  String get instanceAccountIntro =>
      'Créez un compte gratuit sur supabase.com, puis un jeton d\'accès personnel (Account → Access Tokens) et collez-le ici. L\'assistant s\'en sert pour créer et configurer le projet ; il n\'est jamais enregistré.';

  @override
  String get instanceAdminsHelp =>
      'Ils décident qui peut utiliser les assistants. Seules les personnes ayant confirmé leur identité pour les assistants peuvent être choisies.';

  @override
  String get instanceAdminsTitle => 'Administrateurs de la base';

  @override
  String get instanceApplySignIn => 'Appliquer les réglages de connexion';

  @override
  String get instanceApprove => 'Approuver';

  @override
  String instanceAttentionForeign(String tables) {
    return 'Son schéma public contient des tables que DesKilo ne crée pas ($tables). L\'installation y est refusée ; utilisez un projet vide.';
  }

  @override
  String get instanceAttentionNotHealthy =>
      'Supabase ne signale pas le projet comme opérationnel. Attendez qu\'il le soit, ou restaurez-le dans le tableau de bord.';

  @override
  String get instanceAttentionOtherTooling =>
      'Ses migrations ont été enregistrées par un autre outil : on ne peut pas savoir où DesKilo reprendrait. Utilisez un projet vide.';

  @override
  String instanceAttentionPostgres(int found, int supported) {
    return 'Il tourne sous Postgres $found ; DesKilo est conçu pour Postgres $supported.';
  }

  @override
  String get instanceAttentionUnrecorded =>
      'Les tables DesKilo sont là, mais aucune migration n\'a été enregistrée. Enregistrez d\'abord ce qu\'il contient avec `dart run tool/instance.dart record`.';

  @override
  String get instanceBlock => 'Bloquer';

  @override
  String get instanceBlockerNoAdmin => 'un administrateur de la base';

  @override
  String get instanceBlockers => 'Il manque encore :';

  @override
  String get instanceCheckToken => 'Vérifier le jeton';

  @override
  String get instanceChooseAnother => 'Choisir un autre projet';

  @override
  String get instanceClaimBody =>
      'Vous avez créé cette instance et aucun propriétaire n\'est défini. En devenant propriétaire, vous en devenez le responsable.';

  @override
  String get instanceClaimButton => 'Devenir propriétaire';

  @override
  String get instanceClaimDone =>
      'Vous êtes maintenant le propriétaire de l\'instance.';

  @override
  String get instanceClaimFailed => 'La propriété n\'a pas pu être prise.';

  @override
  String get instanceClaimTitle => 'Devenir propriétaire';

  @override
  String get instanceClientApproved => 'Approuvé';

  @override
  String get instanceClientBlocked => 'Bloqué';

  @override
  String get instanceClientWaiting => 'En attente d\'approbation';

  @override
  String get instanceClientsHelp =>
      'Un assistant s\'enregistre lui-même à la première connexion ; il ne fonctionne qu\'une fois approuvé ici.';

  @override
  String get instanceClientsTitle => 'Clients d\'assistant';

  @override
  String get instanceConfirmSecondFactor =>
      'Confirmer avec mon authentificateur';

  @override
  String get instanceCreateButton => 'Créer une nouvelle instance';

  @override
  String get instanceCreateProject => 'Créer le projet';

  @override
  String get instanceDatabasePassword =>
      'Mot de passe de la base, choisi pour vous — copiez-le en lieu sûr ; l\'app n\'en a plus jamais besoin.';

  @override
  String get instanceDelegateAdd => 'Déléguer le rôle';

  @override
  String get instanceDelegateAlreadyOwner =>
      'Le propriétaire n\'a pas besoin de délégation.';

  @override
  String get instanceDelegateFieldLabel => 'Adresse e-mail d\'un compte';

  @override
  String get instanceDelegateNoAccount =>
      'Aucun compte n\'utilise cette adresse e-mail.';

  @override
  String get instanceDelegateUnavailable =>
      'Ce serveur ne permet pas encore de déléguer.';

  @override
  String get instanceDelegateUnchanged => 'Cette personne est déjà déléguée.';

  @override
  String get instanceDelegateUnconfirmed =>
      'Ce compte n\'a pas encore confirmé son adresse e-mail.';

  @override
  String get instanceDelegateWithdraw => 'Retirer la délégation';

  @override
  String get instanceDelegateWithdrawBody =>
      'Cette personne perd immédiatement l\'accès à la configuration de l\'installation.';

  @override
  String get instanceDelegateWithdrawConfirm => 'Retirer';

  @override
  String get instanceDelegateWithdrawTitle => 'Retirer cette délégation ?';

  @override
  String get instanceDelegated => 'Rôle délégué.';

  @override
  String get instanceDelegatesHelp =>
      'Un délégué peut effectuer la configuration des assistants pour toute l\'installation. Il ne peut pas déléguer à son tour et ne voit aucun autre espace.';

  @override
  String get instanceDelegatesNone => 'Aucun délégué.';

  @override
  String get instanceDelegatesTitle => 'Délégués';

  @override
  String get instanceDelegationWithdrawn => 'Délégation retirée.';

  @override
  String instanceDeployFunctions(int count) {
    return 'Déployer les fonctions : paiements, factures électroniques, notifications, badges ($count).';
  }

  @override
  String get instanceDoctorAttention => 'Attention requise';

  @override
  String get instanceDoctorIntro =>
      'Avant que cet appareil l\'utilise, le contrôle de sécurité doit passer : une alarme garde le bouton désactivé jusqu\'à correction.';

  @override
  String instanceDoctorPassed(int count) {
    return '$count contrôles réussis';
  }

  @override
  String get instanceDoctorProtected => 'Protégé';

  @override
  String get instanceDoctorRun => 'Lancer le contrôle de sécurité';

  @override
  String get instanceDoctorRunAgain => 'Vérifier à nouveau';

  @override
  String get instanceDoneIntro =>
      'L\'instance est prête. Utilisez-la sur cet appareil, puis partagez le QR du serveur depuis l\'écran Serveur pour que les membres rejoignent la même.';

  @override
  String get instanceEndpointTitle => 'Point d\'accès des assistants';

  @override
  String get instanceFamilyChatgpt => 'ChatGPT';

  @override
  String get instanceFamilyClaude => 'Claude';

  @override
  String get instanceFamilyLoopback =>
      'Assistant de bureau ou en ligne de commande';

  @override
  String get instanceGrant => 'Approuver l\'accès';

  @override
  String get instanceGrantDays => 'Choisissez entre 1 et 30 jours.';

  @override
  String instanceGrantDaysLabel(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return 'Pour $_temp0';
  }

  @override
  String get instanceGrantHelp =>
      'Tant qu\'aucun autre administrateur de la base de données n\'existe, vous approuvez vous-même les accès — le vôtre compris — pour 30 jours au plus, avec une raison. Chaque approbation est enregistrée.';

  @override
  String get instanceGrantNeedsGoogle =>
      'Approuver un accès nécessite que cette session soit connectée avec Google.';

  @override
  String get instanceGrantNoIdentity =>
      'Cette personne n\'a pas encore confirmé son identité.';

  @override
  String get instanceGrantOtherAdmin =>
      'Un administrateur de la base de données décide de l\'accès ici ; demandez-le-lui.';

  @override
  String get instanceGrantReason => 'Raison';

  @override
  String get instanceGrantReasonNeeded =>
      'Indiquez pourquoi cet accès est approuvé (500 caractères maximum).';

  @override
  String instanceGrantTitle(String name) {
    return 'Approuver l\'accès aux assistants pour $name';
  }

  @override
  String instanceInstallSchema(int count) {
    return 'Installer le schéma : chaque migration de l\'app, dans l\'ordre ($count).';
  }

  @override
  String get instanceIntro =>
      'Réglages valables pour tous les espaces de travail de cette installation. Seul l\'opérateur de l\'instance voit cette page ; chaque changement exige votre second facteur et est journalisé.';

  @override
  String get instanceLoopbackHelp =>
      'Claude Code, Cursor, VS Code et les autres assistants qui tournent sur l\'ordinateur d\'une personne. Chacun approuve toujours sa propre connexion.';

  @override
  String get instanceLoopbackTitle =>
      'Autoriser les assistants de bureau et en ligne de commande';

  @override
  String get instanceMakeAdmin => 'Nommer administrateur';

  @override
  String get instanceNoCandidates =>
      'Personne d\'autre n\'a encore confirmé son identité.';

  @override
  String get instanceNotOperator =>
      'Seul l\'opérateur de l\'instance gère les assistants de l\'installation.';

  @override
  String instanceNoticeClientWaiting(String name) {
    return '$name attend votre approbation.';
  }

  @override
  String instanceNoticeOperatorGrant(String name) {
    return 'L\'opérateur a approuvé l\'accès aux assistants pour $name.';
  }

  @override
  String instanceNoticeSelfGrant(String name) {
    return '$name a approuvé son propre accès aux assistants.';
  }

  @override
  String get instanceNoticesMarkRead => 'Marquer comme lu';

  @override
  String get instanceOperatorApproved => 'Approuvé par l\'opérateur';

  @override
  String get instanceOrganisationLabel => 'Organisation';

  @override
  String get instanceOwnerClaimIntro =>
      'À qui appartient cette instance ? Saisissez l\'adresse e-mail avec laquelle vous vous y inscrirez. Après avoir confirmé cette adresse, revendiquez la propriété dans Paramètres → Propriétaire de l\'instance.';

  @override
  String get instanceOwnerClaimLabel => 'E-mail du propriétaire';

  @override
  String get instanceOwnerCopied => 'Adresse e-mail copiée.';

  @override
  String get instanceOwnerCopyEmail => 'Copier l\'adresse e-mail';

  @override
  String get instanceOwnerHelp =>
      'Cette installation est partagée par tous ses espaces. Le propriétaire de l\'instance en est responsable : contactez-le pour tout ce qui concerne l\'ensemble de l\'installation, comme les assistants.';

  @override
  String get instanceOwnerNone =>
      'Aucun propriétaire d\'instance n\'est encore défini.';

  @override
  String get instanceOwnerTitle => 'Propriétaire de l\'instance';

  @override
  String get instanceProbeCheck => 'Vérifier le serveur';

  @override
  String get instanceProbeDeployed =>
      'Le point d\'accès des assistants répond comme prévu.';

  @override
  String get instanceProbeMismatch =>
      'Le point d\'accès répond avec une autre adresse que celle donnée aux assistants.';

  @override
  String get instanceProbeMissing => 'Le serveur n\'a pas encore été vérifié.';

  @override
  String get instanceProbeNotDeployed =>
      'Le point d\'accès des assistants n\'est pas encore déployé sur ce serveur.';

  @override
  String get instanceProbePending => 'Vérification du serveur…';

  @override
  String get instanceProbeStale =>
      'La dernière vérification date de plus de 15 minutes. Vérifiez à nouveau avant d’activer les assistants.';

  @override
  String get instanceProbeUnavailable =>
      'Le serveur n\'a pas pu être joint. Réessayez dans un instant.';

  @override
  String instanceProgress(int done, int total, String current) {
    return '$done / $total · $current';
  }

  @override
  String get instanceProjectName => 'Nom du projet';

  @override
  String instanceProjectReady(String ref) {
    return 'Projet prêt : $ref';
  }

  @override
  String instanceProjectStatus(String status) {
    return 'État du projet : $status';
  }

  @override
  String get instanceReadyAttention =>
      'Ce projet demande votre attention — rien n\'a été installé.';

  @override
  String instanceReadyCurrent(int version) {
    return 'La version $version de DesKilo est installée et à jour : le schéma n\'a besoin de rien.';
  }

  @override
  String get instanceReadyInstall => 'Le projet est vide : tout sera installé.';

  @override
  String instanceReadyResume(int pending) {
    return 'Une installation DesKilo s\'est arrêtée en cours de route : il reste $pending migrations, et seules celles-ci seront exécutées.';
  }

  @override
  String instanceReadyUpgrade(int version, int pending) {
    return 'La version $version de DesKilo est installée : seules les $pending migrations manquantes seront exécutées.';
  }

  @override
  String get instanceRegion => 'Région (la plus proche de l\'espace)';

  @override
  String get instanceRemoveAdmin => 'Retirer';

  @override
  String get instanceRetry => 'Reprendre là où ça s\'est arrêté';

  @override
  String get instanceRevokeToken =>
      'Vous pouvez révoquer le jeton d\'accès maintenant : DesKilo n\'en a gardé aucune copie.';

  @override
  String get instanceRuntimeOff => 'Désactivés';

  @override
  String get instanceRuntimeOn => 'Activés';

  @override
  String get instanceRuntimeTitle => 'Assistants sur cette installation';

  @override
  String get instanceSecondFactorNeeded =>
      'Les changements ici exigent votre second facteur sur cette session.';

  @override
  String get instanceSelfApproved => 'Auto-approuvé par l\'opérateur';

  @override
  String get instanceSignInExplain =>
      'Réglages de connexion : confirmation par courriel activée (une inscription doit cliquer le lien reçu), et les liens de l\'app autorisés pour les réinitialisations de mot de passe et les liens magiques.';

  @override
  String get instanceStepAccount => 'Compte';

  @override
  String get instanceStepDone => 'Terminé';

  @override
  String instanceStepFailed(String item, String message) {
    return 'Arrêt à $item : $message';
  }

  @override
  String get instanceStepFunctions => 'Fonctions';

  @override
  String get instanceStepProject => 'Projet';

  @override
  String get instanceStepSchema => 'Schéma';

  @override
  String get instanceStepSignIn => 'Connexion';

  @override
  String get instanceTitle => 'Installation : assistants';

  @override
  String get instanceTokenLabel => 'Jeton d\'accès personnel';

  @override
  String get instanceTokenReach =>
      'Un jeton d\'accès personnel ouvre tout votre compte Supabase tant qu\'il existe. L\'assistant ne le garde qu\'en mémoire et vous dit quand vous pouvez le révoquer.';

  @override
  String get instanceTokenRefused =>
      'Supabase a refusé le jeton. Créez-en un dans Account → Access Tokens et collez-le en entier.';

  @override
  String get instanceTurnOff => 'Désactiver';

  @override
  String get instanceTurnOn => 'Activer pour tous les espaces';

  @override
  String get instanceTurnOnConfirm =>
      'Les assistants deviennent utilisables dans chaque espace qui les propose. Vous pouvez les désactiver à tout moment.';

  @override
  String get instanceTurnOnNeedsProbe =>
      'Le point d\'accès des assistants n\'est pas confirmé. Vérifiez d\'abord le serveur.';

  @override
  String get instanceUseExisting => 'Ou utiliser un projet existant :';

  @override
  String get instanceUseHere => 'Utiliser cette instance sur cet appareil';

  @override
  String get instanceWizardTitle => 'Créer une nouvelle instance';

  @override
  String get instanceYou => 'vous';

  @override
  String get instanceYouAreDelegate =>
      'Vous êtes délégué du propriétaire de l\'instance.';

  @override
  String get instanceYouAreOwner => 'Vous êtes le propriétaire de l\'instance.';

  @override
  String invitationAlreadyMember(String workspace) {
    return 'Vous êtes déjà membre de $workspace.';
  }

  @override
  String get invitationApprovalRequired =>
      'Un administrateur approuve les nouveaux membres avant l’ouverture de l’espace.';

  @override
  String get invitationApprovalUnknown =>
      'On ne sait pas si un administrateur doit approuver.';

  @override
  String get invitationBadServer =>
      'Le serveur indiqué dans cette invitation n’est pas valide. Demandez une nouvelle invitation.';

  @override
  String get invitationChangeAccount => 'Changer de compte';

  @override
  String get invitationCheckAnother => 'Utiliser une autre invitation';

  @override
  String get invitationCheckFailed =>
      'L’invitation n’a pas pu être vérifiée — statut non mis à jour. Rien n’a été modifié ; réessayez.';

  @override
  String get invitationContinue => 'Continuer vers cet espace';

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
  String get invitationEnvironmentProduction => 'Espace de production';

  @override
  String get invitationEnvironmentTest => 'Espace de test';

  @override
  String get invitationExpired =>
      'Cette invitation a expiré. Demandez-en une nouvelle à la personne qui l’a envoyée.';

  @override
  String invitationInvalid(String host) {
    return 'Aucun espace sur $host ne connaît cette invitation. Vérifiez-la, ou demandez le lien du serveur à l’organisateur.';
  }

  @override
  String get invitationJoinButton => 'Rejoindre l’espace';

  @override
  String get invitationJoinUnconfirmed =>
      'Le résultat n’a pas pu être confirmé. Rejoignez à nouveau pour vérifier — l’invitation n’est pas utilisée deux fois.';

  @override
  String invitationJoiningAs(String account) {
    return 'Adhésion en tant que $account';
  }

  @override
  String get invitationNewerVersion =>
      'Cette invitation a été créée par une version plus récente de DesKilo. Mettez l’application à jour, puis rouvrez-la.';

  @override
  String invitationOtherServer(String host) {
    return 'Cette invitation concerne un autre serveur : $host.';
  }

  @override
  String get invitationPasteButton => 'Coller';

  @override
  String invitationPaused(String workspace) {
    return 'Votre adhésion à $workspace est suspendue. Seul un administrateur de l’espace peut la reprendre.';
  }

  @override
  String get invitationReviewButton => 'Vérifier l’invitation';

  @override
  String get invitationReviewTitle => 'Vérifiez avant d’adhérer';

  @override
  String get invitationRevoked =>
      'Ce code d’espace a été remplacé. Demandez le code actuel à la personne qui l’a envoyé.';

  @override
  String get invitationRoleAdmin => 'Rôle proposé : administrateur';

  @override
  String get invitationRoleMember => 'Rôle proposé : membre';

  @override
  String get invitationRoleUnknown => 'Rôle proposé : pas encore connu';

  @override
  String invitationServerLabel(String label) {
    return 'Nommé « $label » par la personne qui l’a partagé';
  }

  @override
  String invitationServerRow(String host) {
    return 'Serveur : $host';
  }

  @override
  String get invitationTemplateHelp =>
      'Envoyé quand vous invitez quelqu\'un par WhatsApp, SMS ou partage. Laissez vide pour utiliser le message intégré dans la langue choisie. Balises disponibles :';

  @override
  String get invitationTemplateHint =>
      'Message d\'invitation personnalisé utilisant les balises ci-dessus…';

  @override
  String get invitationTemplateLanguage => 'Langue du message';

  @override
  String get invitationTemplateTitle => 'Message d\'invitation';

  @override
  String invitationThisDevice(String host) {
    return 'Cet appareil utilise $host. Une invitation n’est vérifiée que sur son propre serveur.';
  }

  @override
  String get invitationUnknownAnswer =>
      'Le serveur a donné une réponse que cette version de l’application ne sait pas lire. Rien n’a été modifié.';

  @override
  String get invitationUseServer => 'Utiliser ce serveur';

  @override
  String get invitationWrongAccount =>
      'Cette invitation a déjà été utilisée par un autre compte. Si elle vous était destinée, connectez-vous avec ce compte.';

  @override
  String get inviteAdminExplainer =>
      'Ce code est à usage unique : il admet UNE personne comme admin, puis expire. Ne le remettez qu\'à la personne à qui il est destiné.';

  @override
  String get inviteAdminNewCode => 'Nouveau code administrateur·rice';

  @override
  String get inviteAlsoProdSubtitle =>
      'La personne rejoint l\'espace de test dans tous les cas. Le rôle doit malgré tout autoriser l\'accès à la production.';

  @override
  String get inviteAlsoProdTitle => 'Donner aussi accès à la production';

  @override
  String get inviteCreateFailed =>
      'Impossible de créer l\'invitation. Vérifiez votre connexion et réessayez.';

  @override
  String get inviteFirstNameLabel => 'Prénom (facultatif)';

  @override
  String get inviteLanguageLabel => 'Langue du message';

  @override
  String get inviteLastNameLabel => 'Nom (facultatif)';

  @override
  String get inviteOwnerNote =>
      'Il n\'existe pas d\'invitation propriétaire — seul un propriétaire peut accorder la propriété, dans Membres & forfaits.';

  @override
  String get invitePhoneLabel => 'Téléphone (facultatif, avec indicatif)';

  @override
  String get inviteRoleAdmin => 'Invitation administrateur·rice';

  @override
  String get inviteRoleMember => 'Invitation membre';

  @override
  String get inviteRolesHint =>
      'Attribués à l\'arrivée, une fois l\'adhésion active.';

  @override
  String get inviteRolesTitle => 'Rôles à l\'arrivée';

  @override
  String get inviteSectionTitle => 'Inviter quelqu\'un';

  @override
  String get inviteSendFailed =>
      'Impossible d\'ouvrir l\'application d\'envoi. Le message a été copié à la place.';

  @override
  String get inviteViaShare => 'Partager…';

  @override
  String get inviteViaSms => 'SMS';

  @override
  String get inviteViaWhatsapp => 'WhatsApp';

  @override
  String get invoiceAccountingExport => 'Export comptable';

  @override
  String get invoiceAccountingExportEmpty =>
      'Rien à exporter pour cette période.';

  @override
  String get invoiceAllCaughtUp => 'Tout est à jour — rien à facturer.';

  @override
  String get invoiceAlreadyInvoiced =>
      'Ce mois est déjà facturé pour ce membre.';

  @override
  String invoiceAnnexSummary(int movements, int checkIns) {
    return 'Annexe : $movements mouvements, $checkIns pointages';
  }

  @override
  String get invoiceBalance => 'Solde';

  @override
  String get invoiceBuyerReference => 'Code service';

  @override
  String get invoiceBuyerReferenceHint =>
      'Acheteur public (Chorus Pro) : le code service exécutant.';

  @override
  String invoiceCountShown(int count) {
    return '$count factures';
  }

  @override
  String get invoiceCreate => 'Nouvelle facture';

  @override
  String get invoiceDetailedToggle =>
      'Inclure l\'annexe détaillée (présences, services, paiements)';

  @override
  String get invoiceDownload => 'Télécharger le PDF';

  @override
  String get invoiceEInvoiceAction => 'Facture électronique (XML)';

  @override
  String get invoiceEInvoiceBlockedTitle =>
      'Un validateur rejetterait ce fichier :';

  @override
  String invoiceEInvoiceBusinessRoute(String channel, String format) {
    return 'Clients professionnels : transmettez-la via $channel au format $format.';
  }

  @override
  String get invoiceEInvoiceDownload =>
      'Télécharger la facture électronique (XML)';

  @override
  String get invoiceEInvoiceExplain =>
      'La facture EN 16931 lisible par machine — le fichier que réclament les administrations et les clients professionnels.';

  @override
  String get invoiceEInvoiceFixIdentity => 'Compléter l\'identité légale';

  @override
  String invoiceEInvoiceFormatMismatch(String channel, String format) {
    return '$channel n\'accepte que le format $format : ce fichier EN 16931 sert pour Peppol, les acheteurs publics et les clients étrangers — votre plateforme ou votre comptable convertit le reste.';
  }

  @override
  String get invoiceEInvoiceIncompleteTitle =>
      'Valide, mais les profils nationaux stricts demandent aussi :';

  @override
  String invoiceEInvoicePublicRoute(String channel) {
    return 'Clients du secteur public : $channel.';
  }

  @override
  String get invoiceEInvoiceReady =>
      'Prêt — ce fichier satisfait la norme EN 16931.';

  @override
  String get invoiceEInvoiceShare => 'Partager la facture électronique (XML)';

  @override
  String get invoiceEInvoiceStaleIdentity =>
      'Votre identité légale est complète, mais cette facture a été signée avant et conserve ce avec quoi elle a été émise. Marquez-la erronée puis émettez un remplacement pour porter la nouvelle identité.';

  @override
  String get invoiceEInvoiceTransportAccredited =>
      'Une plateforme agréée transporte la facture et transmet les données à l\'administration fiscale pour vous.';

  @override
  String get invoiceEInvoiceTransportBilateral =>
      'Aucun canal imposé : e-mail, portail ou Peppol — comme convenu avec le client.';

  @override
  String get invoiceEInvoiceTransportClearance =>
      'La plateforme nationale reçoit la facture d\'abord et la transmet — l\'envoi direct au client n\'est pas possible.';

  @override
  String get invoiceEInvoiceTransportPeppol =>
      'Un point d\'accès la livre au client — aucune plateforme publique dans le circuit.';

  @override
  String get invoiceEssentialsRefused =>
      'La facture n\'a pas été émise : des informations obligatoires manquent.';

  @override
  String get invoiceExportAccountantCsv => 'CSV comptable';

  @override
  String get invoiceExportAuditTrail => 'Piste d’audit';

  @override
  String get invoiceExportBundle => 'Archive de l\'exercice (zip)';

  @override
  String get invoiceExportChoose => 'Export comptable';

  @override
  String get invoiceExportDatev => 'DATEV (Buchungsstapel)';

  @override
  String get invoiceExportFec => 'FEC (France, exigé en cas de contrôle)';

  @override
  String get invoiceExportSafT => 'SAF-T (XML, international)';

  @override
  String get invoiceExportSafTPt => 'SAF-T (Portugal)';

  @override
  String get invoiceExportSage => 'Sage 50 (journal d’audit)';

  @override
  String get invoiceExternalIssuingTitle =>
      'Émettez cette facture hors de l’application';

  @override
  String get invoiceFacturXDownload => 'Télécharger le Factur-X (PDF)';

  @override
  String get invoiceFacturXExplain =>
      'Un seul fichier : la facture qu\'un humain lit, avec le XML lisible par machine à l\'intérieur. C\'est ce qu\'attendent la plupart des plateformes.';

  @override
  String get invoiceFacturXShare => 'Partager le Factur-X (PDF)';

  @override
  String get invoiceFilterAllMembers => 'Tous les membres';

  @override
  String get invoiceFilterAllMonths => 'Tous les mois';

  @override
  String get invoiceFilterClear => 'Réinitialiser les filtres';

  @override
  String get invoiceFilterMonthLabel => 'Mois';

  @override
  String get invoiceFilterNoMatch =>
      'Aucune facture ne correspond à ces filtres.';

  @override
  String get invoiceGapBuyerVatIdFormat =>
      'Le numéro de TVA du client n\'a pas la forme de son pays — vérifiez-le.';

  @override
  String get invoiceGapCreditNoteWithPayments =>
      'Cet avoir compense aussi des paiements, ce qu\'un avoir EN 16931 ne peut pas exprimer. Émettez l\'avoir sur un document distinct.';

  @override
  String get invoiceGapMissingBuyerCountry => 'Le pays du client manque.';

  @override
  String get invoiceGapMissingBuyerVatId =>
      'Le numéro de TVA du client manque — une facture en autoliquidation doit le porter.';

  @override
  String get invoiceGapMissingExemptionReason =>
      'Le motif de non-assujettissement à la TVA manque.';

  @override
  String get invoiceGapMissingLegalId =>
      'Le numéro d\'immatriculation manque (SIREN, HRB, CIF…) — rien ne vous identifie sur la facture.';

  @override
  String get invoiceGapMissingSellerCity =>
      'la ville de l\'adresse de l\'espace';

  @override
  String get invoiceGapMissingSellerCountry => 'Le pays de l\'espace manque.';

  @override
  String get invoiceGapMissingSellerPostalCode =>
      'le code postal de l\'adresse de l\'espace';

  @override
  String get invoiceGapMissingVatId =>
      'Le numéro de TVA manque — un vendeur exonéré doit l\'indiquer.';

  @override
  String get invoiceGapNoChargeLines =>
      'Cette facture n\'a aucune ligne de charge — son mois était entièrement couvert par des paiements, il n\'y a donc rien à transmettre.';

  @override
  String get invoiceGapPublicSectorRefs =>
      'Destinée à une plateforme publique sans numéro d\'engagement ni code service — Chorus Pro refuse la plupart des dépôts sans l\'un des deux.';

  @override
  String get invoiceGapVatNotSupported =>
      'L\'espace facture la TVA mais cette facture ne porte aucun taux — ajoutez vos taux de TVA, puis émettez-la à nouveau.';

  @override
  String invoiceHeldNote(String reason) {
    return 'Relances suspendues : $reason';
  }

  @override
  String get invoiceHoldAction => 'Suspendre les relances';

  @override
  String get invoiceHoldConfirm => 'Suspendre';

  @override
  String get invoiceHoldExplain =>
      'Aucune relance n\'est envoyée pour cette facture, à la main ou automatiquement, tant que la suspension n\'est pas levée.';

  @override
  String get invoiceHoldFailed =>
      'La suspension des relances n\'a pas pu être modifiée. Veuillez réessayer.';

  @override
  String get invoiceHoldNote => 'Note (facultatif)';

  @override
  String get invoiceHoldPlaced =>
      'Les relances sont suspendues pour cette facture.';

  @override
  String get invoiceHoldReasonDispute => 'Le membre la conteste';

  @override
  String get invoiceHoldReasonIdentity =>
      'Mauvaise personne ou erreur d\'identité';

  @override
  String get invoiceHoldReasonInsolvency => 'Procédure d\'insolvabilité';

  @override
  String get invoiceHoldReasonOther => 'Une autre raison';

  @override
  String get invoiceHoldReleaseAction => 'Lever la suspension des relances';

  @override
  String get invoiceHoldReleased =>
      'Les relances peuvent reprendre pour cette facture.';

  @override
  String get invoiceHoldTitle => 'Pourquoi suspendre les relances ?';

  @override
  String get invoiceIntegrityAltered => 'Modifiée depuis l\'émission';

  @override
  String get invoiceIntegrityUnverifiable =>
      'Émise avant les contrôles d\'intégrité';

  @override
  String get invoiceIntegrityVerified => 'Intégrité vérifiée';

  @override
  String get invoiceIssue => 'Émettre la facture';

  @override
  String get invoiceIssueAll => 'Tout facturer';

  @override
  String invoiceIssueAllConfirm(int count, String month, String total) {
    return 'Émettre $count factures pour $month, $total au total ? Une facture émise ne se modifie plus — une erreur se corrige par un remplacement.';
  }

  @override
  String get invoiceIssueOne => 'Facturer';

  @override
  String get invoiceIssued => 'Facture émise.';

  @override
  String invoiceIssuedCount(int count) {
    return '$count factures émises.';
  }

  @override
  String invoiceIssuedPartial(int issued, int failed) {
    return '$issued émises, $failed en échec.';
  }

  @override
  String get invoiceKindFull => 'Mois entier';

  @override
  String get invoiceKindSettlement => 'Factures regroupées';

  @override
  String get invoiceKindSubscription => 'Abonnement, à l’avance';

  @override
  String get invoiceKindUsage => 'Les extras du mois';

  @override
  String get invoiceLegalAssociationReasonHint =>
      'ex. « TVA non applicable, art. 293 B du CGI » — ou « Exonération de TVA, art. 261, 7-1° du CGI » pour les services rendus aux membres';

  @override
  String get invoiceLegalCustomerCapacityField =>
      'Qualité du client par défaut';

  @override
  String get invoiceLegalCustomerCapacityHint =>
      'Décide des clauses de paiement imprimées sur la facture. Les mentions légales par défaut (pénalités de retard, indemnité forfaitaire de recouvrement, escompte) ne s\'appliquent qu\'aux clients professionnels, et un consommateur ne reçoit jamais l\'indemnité de recouvrement. La qualité propre d\'un membre l\'emporte sur ce défaut. Chaque facture garde les clauses avec lesquelles elle a été émise.';

  @override
  String get invoiceLegalEscompteDefault =>
      'Aucun escompte pour paiement anticipé.';

  @override
  String get invoiceLegalEscompteField => 'Escompte';

  @override
  String get invoiceLegalFormField => 'Forme juridique et capital';

  @override
  String get invoiceLegalFormHint => 'ex. SARL au capital de 7 500 €';

  @override
  String get invoiceLegalFormHintAssociation => 'ex. Association loi 1901';

  @override
  String get invoiceLegalInsuranceField => 'Assurance professionnelle';

  @override
  String get invoiceLegalIntro =>
      'Les mentions légales imprimées sur les factures et les relances. Les clauses de paiement laissées vides utilisent les mentions légales par défaut.';

  @override
  String get invoiceLegalKindAssociation => 'Association (loi 1901)';

  @override
  String get invoiceLegalKindCompany => 'Entreprise';

  @override
  String get invoiceLegalKindField => 'Type d\'organisation';

  @override
  String get invoiceLegalLatePenaltyDefault =>
      'Pénalités de retard : trois fois le taux d\'intérêt légal.';

  @override
  String get invoiceLegalLatePenaltyField => 'Pénalités de retard';

  @override
  String get invoiceLegalPaymentTermsDefault => 'Règlement à réception.';

  @override
  String get invoiceLegalPaymentTermsField => 'Modalités de règlement';

  @override
  String get invoiceLegalRecoveryDefault =>
      'Indemnité forfaitaire pour frais de recouvrement : 40 €.';

  @override
  String get invoiceLegalRecoveryField => 'Indemnité de recouvrement';

  @override
  String get invoiceLegalRegistrationField => 'Registre du commerce (RCS)';

  @override
  String get invoiceLegalRegistrationHint => 'ex. RCS Saint-Brieuc 680 357 910';

  @override
  String get invoiceLegalRegistrationHintAssociation =>
      'ex. RNA W123456789 · SIRET si attribué';

  @override
  String get invoiceLegalSection => 'Mentions de facturation';

  @override
  String get invoiceLegalSpecialField => 'Mentions particulières';

  @override
  String get invoiceLineAdjustment => 'Ajustement';

  @override
  String get invoiceMatchAction => 'Marquer comme payée';

  @override
  String get invoiceMatchCreditNote => 'Créer un avoir pour l\'excédent';

  @override
  String get invoiceMatchForce => 'Accepter quand même (justifier)';

  @override
  String get invoiceMatchNoPayments =>
      'Aucun paiement enregistré à rapprocher — enregistrez-le ou confirmez-le d\'abord.';

  @override
  String get invoiceMatchNoteLabel => 'Note';

  @override
  String get invoiceMatchNoteRequired => 'Une note est obligatoire.';

  @override
  String invoiceMatchOver(String excess) {
    return 'Le membre a payé $excess de plus.';
  }

  @override
  String get invoiceMatchPendingBadge => 'En attente de validation';

  @override
  String get invoiceMatchPickPayment => 'Sélectionner le paiement enregistré';

  @override
  String invoiceMatchSummary(String amount, String date) {
    return 'Payée $amount le $date';
  }

  @override
  String invoiceMatchUnder(String missing) {
    return 'Le membre a payé $missing de moins — accepter exige une note.';
  }

  @override
  String get invoiceMatched => 'Facture rapprochée.';

  @override
  String get invoiceMatchedBadge => 'Payée';

  @override
  String get invoiceMaturityReview =>
      'Aucune échéance convenue n\'a été enregistrée pour cette facture : aucune relance automatique tant que vous ne l\'avez pas examinée.';

  @override
  String get invoiceMemberLabel => 'Membre';

  @override
  String get invoiceMissingBuyerAddress =>
      'L\'adresse postale du membre (obligatoire pour un client professionnel)';

  @override
  String get invoiceMissingBuyerName => 'Le nom ou la société du membre';

  @override
  String get invoiceMissingBuyerVatId =>
      'Le numéro de TVA du membre (requis pour l\'autoliquidation)';

  @override
  String get invoiceMissingExemptionReason =>
      'Le fondement légal de l\'exonération de TVA';

  @override
  String get invoiceMissingSellerAddress =>
      'L\'adresse postale de l\'espace (rue ou ville)';

  @override
  String get invoiceMissingSellerCountry =>
      'Le pays de l\'espace doit être la France ou l\'Allemagne pour émettre ici — les autres pays sont émis hors de l\'application';

  @override
  String get invoiceMissingSellerVatId =>
      'Le numéro d\'identification TVA de l\'espace';

  @override
  String get invoiceMissingTitle =>
      'Complétez ces informations avant d\'émettre';

  @override
  String get invoiceMissingVatNotRegistered =>
      'Aucune TVA sur les lignes : l\'espace ne facture pas la TVA, mais un taux est réglé sur l\'abonnement ou un accessoire';

  @override
  String get invoiceMissingVatRate =>
      'Un taux de TVA en vigueur pour le taux par défaut de l\'espace (sinon 0 % serait facturé)';

  @override
  String get invoiceMissingVatTreatment =>
      'Les factures transfrontalières, en autoliquidation, à l’export ou exonérées doivent être vérifiées et émises hors de l’application avec votre comptable. Les relevés restent disponibles.';

  @override
  String get invoiceMissingVatZeroLine =>
      'Un taux de TVA pour chaque prestation : une prestation est facturée à 0 % sans export, exonération ni autoliquidation qui l\'explique';

  @override
  String get invoiceNoOpen => 'Aucune facture en cours.';

  @override
  String get invoiceNothingToInvoice =>
      'Rien de suivi pour ce mois — rien à facturer.';

  @override
  String invoiceOpenAge(int days) {
    return '$days jours';
  }

  @override
  String get invoicePdfActivity => 'Mouvements & paiements';

  @override
  String get invoicePdfAnnex => 'Annexe — détails';

  @override
  String get invoicePdfAttendance => 'Présences';

  @override
  String get invoicePdfBilledTo => 'Facturé à';

  @override
  String get invoicePdfBuyerReference => 'Service exécutant';

  @override
  String get invoicePdfCharges => 'Charges';

  @override
  String get invoicePdfCopy => 'Copie';

  @override
  String get invoicePdfCreditNote => 'Avoir';

  @override
  String get invoicePdfDescription => 'Description';

  @override
  String get invoicePdfDueOn => 'Échéance';

  @override
  String get invoicePdfIssuedBy => 'Émise par';

  @override
  String get invoicePdfIssuedOn => 'Émise le';

  @override
  String get invoicePdfPage => 'Page';

  @override
  String get invoicePdfPayments => 'Paiements';

  @override
  String get invoicePdfProforma => 'Proforma';

  @override
  String get invoicePdfPurchaseOrder => 'N° d\'engagement';

  @override
  String get invoicePdfReplaces => 'Remplace';

  @override
  String get invoicePdfReserved => 'réservé';

  @override
  String invoicePdfSettledIn(String number) {
    return 'Regroupée dans $number';
  }

  @override
  String get invoicePdfSignature => 'Signature numérique (SHA-256)';

  @override
  String get invoicePdfTitle => 'Facture';

  @override
  String get invoicePdfVoided => 'ERRONÉE — annulée le';

  @override
  String get invoicePickMember =>
      'Choisissez un membre pour voir ce que son mois a enregistré.';

  @override
  String get invoiceProformaAction => 'Facture proforma';

  @override
  String get invoiceProformaNothing =>
      'Rien de suivi pour ce mois — aucune proforma à envoyer.';

  @override
  String get invoiceProformaShared => 'Proforma partagée.';

  @override
  String get invoicePublicBuyer => 'Acheteur public (Chorus Pro)';

  @override
  String get invoicePurchaseOrder => 'N° d\'engagement';

  @override
  String get invoicePurchaseOrderHint =>
      'Acheteur public (Chorus Pro) : le numéro d\'engagement.';

  @override
  String get invoiceRefundButton => 'Enregistrer le remboursement';

  @override
  String invoiceRefundExplain(String amount) {
    return 'Cet avoir signifie que L\'ESPACE doit $amount au membre. Enregistrez le remboursement versé — le montant est imputé au solde du membre et le document se clôt comme Remboursée.';
  }

  @override
  String get invoiceRefundLabel => 'À rembourser';

  @override
  String get invoiceRefunded => 'Remboursement enregistré.';

  @override
  String get invoiceRegisterAllYears => 'Toutes les années';

  @override
  String get invoiceRegisterAmount => 'Montant';

  @override
  String get invoiceRegisterDate => 'Date';

  @override
  String get invoiceRegisterName => 'Nom';

  @override
  String get invoiceRegisterTitle => 'Registre des factures';

  @override
  String get invoiceRegisterTotal => 'Total';

  @override
  String get invoiceRegisterYear => 'Année';

  @override
  String get invoiceRemainingLabel => 'Restant dû';

  @override
  String get invoiceRemindAction => 'Envoyer un rappel';

  @override
  String get invoiceReminded => 'Rappel enregistré.';

  @override
  String invoiceRemindedBadge(int count) {
    return 'Rappelé ×$count';
  }

  @override
  String invoiceRemindedLast(String date) {
    return 'dernière relance $date';
  }

  @override
  String invoiceReminderMessage(String number, String amount) {
    return 'Rappel amical : facture $number — solde dû $amount.';
  }

  @override
  String get invoiceReminderNotSent =>
      'Rien n’a été envoyé, donc rien n’a été enregistré.';

  @override
  String get invoiceReplaceAction => 'Émettre un remplacement';

  @override
  String invoiceReplacedBy(String number) {
    return 'Remplacée par $number';
  }

  @override
  String get invoiceRunningMonth =>
      'Ce mois est en cours — ses positions peuvent encore changer, et un mois ne se facture qu\'une seule fois.';

  @override
  String get invoiceSendAccepted => 'Envoyée — la plateforme l’a acceptée.';

  @override
  String invoiceSendAcceptedTest(String env) {
    return 'Envoi de test accepté ($env).';
  }

  @override
  String get invoiceSendAction => 'Envoyer à la plateforme gouvernementale';

  @override
  String get invoiceSendCustomerAccepted =>
      'Envoyée — le service du client l’a acceptée.';

  @override
  String get invoiceSendCustomerAction => 'Envoyer au service du client';

  @override
  String get invoiceSendRejected => 'La plateforme l’a refusée.';

  @override
  String get invoiceSendStatusAccepted => 'acceptée';

  @override
  String get invoiceSendStatusFailed => 'non transmise';

  @override
  String get invoiceSendStatusRejected => 'refusée';

  @override
  String invoiceSentOn(String date, String status) {
    return 'Envoyée le $date · $status';
  }

  @override
  String get invoiceSentTestChip => 'test';

  @override
  String get invoiceShare => 'Partager le PDF';

  @override
  String get invoiceShowCancelled => 'Afficher les annulées';

  @override
  String get invoiceSortByMember => 'Par membre';

  @override
  String get invoiceSortByMonth => 'Par mois';

  @override
  String get invoiceSortNewest => 'Plus récentes d\'abord';

  @override
  String get invoiceSortTooltip => 'Trier';

  @override
  String get invoiceStatusOpen => 'En cours';

  @override
  String get invoiceStatusPartiallyPaid => 'Partiellement payée';

  @override
  String get invoiceStatusRefunded => 'Remboursée';

  @override
  String get invoiceStatusRemainderCancelled =>
      'Partiellement payée · solde annulé';

  @override
  String invoiceSummaryOpen(int count, String amount) {
    return '$count en cours · $amount dus';
  }

  @override
  String invoiceSummaryToInvoice(int count) {
    return '$count à facturer';
  }

  @override
  String invoiceSummaryToRefund(int count, String amount) {
    return '$count à rembourser · $amount';
  }

  @override
  String get invoiceTabArchive => 'Archives';

  @override
  String get invoiceTabOpen => 'En cours';

  @override
  String get invoiceTabToInvoice => 'À facturer';

  @override
  String get invoiceTemplateBodyLabel =>
      'Bande de corps (les lignes de la facture)';

  @override
  String get invoiceTemplateDocInvoice => 'Facture';

  @override
  String invoiceTemplateDocReminder(int level) {
    return 'Relance $level';
  }

  @override
  String get invoiceTemplateDocStatement => 'Relevé';

  @override
  String get invoiceTemplateDownload => 'Télécharger le PDF';

  @override
  String get invoiceTemplateFooterLabel =>
      'Pied de page (sous les totaux — conditions de paiement, mentions légales)';

  @override
  String get invoiceTemplateHeaderLabel => 'Bande d\'en-tête';

  @override
  String get invoiceTemplateHint =>
      'Trois bandes de rapport rendues sur le PDF — le XML de facture électronique n\'est jamais modifié. Conditions et boucles Liquid, puis balisage de ligne :';

  @override
  String get invoiceTemplateIntroLabel =>
      'Introduction (au-dessus du bloc destinataire)';

  @override
  String get invoiceTemplateNoPreview =>
      'Émettez d\'abord une facture — l\'aperçu rend la plus récente.';

  @override
  String get invoiceTemplatePresets => 'Modèles';

  @override
  String get invoiceTemplatePreview => 'Aperçu';

  @override
  String get invoiceTemplateQuickPreview => 'Aperçu rapide';

  @override
  String get invoiceTemplateReset => 'Réinitialiser au modèle par défaut';

  @override
  String get invoiceTemplateSaved => 'Modèle de facture enregistré.';

  @override
  String get invoiceTemplateShare => 'Partager le PDF';

  @override
  String get invoiceTemplateTitle => 'Modèle de PDF de facture';

  @override
  String get invoiceVoidAction => 'Marquer comme erronée';

  @override
  String invoiceVoidConfirm(String number) {
    return 'Marquer la facture $number comme erronée ? Cette action est irréversible.';
  }

  @override
  String get invoiceVoided => 'Facture marquée comme erronée.';

  @override
  String get invoiceVoidedChip => 'Erronée';

  @override
  String get invoiceWizardAction => 'Assistant de clôture';

  @override
  String get invoiceWriteoffButton => 'Annuler le solde restant';

  @override
  String get invoiceWriteoffExplain =>
      'Le solde impayé de cette facture sera annulé et la facture archivée comme partiellement payée — une fois la validation confirmée. D\'ici là elle reste ouverte et due.';

  @override
  String get invoiceWriteoffRequested =>
      'Annulation demandée — en attente de validation.';

  @override
  String get invoicesEmpty => 'Aucune facture pour l\'instant.';

  @override
  String get invoicesManage => 'Gérer les factures';

  @override
  String get invoicesTitle => 'Factures';

  @override
  String get invoicingBanner =>
      'Vous émettez et relancez les factures de tout l’espace. Vos propres factures et paiements sont dans Moi › Finances.';

  @override
  String get invoicingHubTitle => 'Facturation';

  @override
  String get invoicingMyFinances => 'Mes finances';

  @override
  String get invoicingTools => 'Outils de facturation';

  @override
  String journeyClosedPaid(String date) {
    return 'Payée le $date — close';
  }

  @override
  String journeyClosedRefunded(String date) {
    return 'Remboursée le $date — close';
  }

  @override
  String journeyClosedRemainder(String date) {
    return 'Close — reliquat annulé le $date';
  }

  @override
  String journeyClosedReplaced(String number) {
    return 'Annulée — remplacée par $number';
  }

  @override
  String get journeyClosedSettled =>
      'Regroupée dans une autre facture — c\'est celle-là qui est due et relancée';

  @override
  String get journeyHowButton => 'Comment ça marche';

  @override
  String get journeyHowClosedMember =>
      'Le mois se lit soldé et la facture reste lisible pour toujours : aperçu, PDF, partage.';

  @override
  String get journeyHowClosedWorkspace =>
      'Payée, reliquat annulé ou remboursée : la facture passe aux archives. Une facture fausse est marquée erronée et remplacée — avant paiement, jamais après.';

  @override
  String get journeyHowConfirmationMember =>
      'Rien à faire — sauf si l\'espace a enregistré le paiement pour lui : il le confirme alors dans Événements.';

  @override
  String get journeyHowConfirmationWorkspace =>
      'Un autre admin confirme le paiement déclaré ; l\'émetteur rapproche ensuite le paiement enregistré de la facture (Marquer payée) — une règle de validation peut confier le rapprochement aux valideurs. Trop payé ? Un avoir. Pas assez ? Partiellement payée, le reste dû jusqu\'au paiement ou à l\'annulation.';

  @override
  String get journeyHowIntro =>
      'Quatre étapes, les mêmes pour chaque facture. Chacune dit à qui est le tour.';

  @override
  String get journeyHowIssuedMember =>
      'La trouve sur le volet Factures : positions, solde, échéance.';

  @override
  String get journeyHowIssuedWorkspace =>
      'Émet la facture à partir des données suivies du mois — numérotée, signée, immuable — et partage le PDF ou envoie la facture électronique.';

  @override
  String get journeyHowMemberLabel => 'Membre';

  @override
  String get journeyHowPaymentMember =>
      'Paie en ligne (réglé aussitôt) ou par virement, puis enregistre le paiement pour que l\'espace le sache.';

  @override
  String get journeyHowPaymentWorkspace =>
      'Attend l\'argent. Passé le délai, il envoie les niveaux de relance configurés — à la main ou automatiquement.';

  @override
  String get journeyHowTitle => 'Comment fonctionne la facturation';

  @override
  String get journeyHowWorkspaceLabel => 'Espace';

  @override
  String journeyIssuerAdminConfirms(String name, String amount) {
    return '$name a déclaré un paiement de $amount — un autre admin le confirme dans Événements';
  }

  @override
  String journeyIssuerMatches(String amount) {
    return 'Un paiement de $amount est enregistré — rapprochez-le de cette facture';
  }

  @override
  String journeyIssuerMemberConfirms(String name, String amount) {
    return 'Un paiement de $amount a été enregistré — $name le confirme dans Événements';
  }

  @override
  String journeyIssuerMemberPays(String name, String amount, String date) {
    return 'En attente du paiement de $name : $amount — échéance $date';
  }

  @override
  String journeyIssuerMemberPaysOverdue(String name, String amount, int days) {
    return '$name doit $amount — en retard de $days jours';
  }

  @override
  String journeyIssuerMemberPaysRemainder(String name, String amount) {
    return '$name doit encore $amount après un paiement partiel';
  }

  @override
  String journeyIssuerRefunds(String name, String amount) {
    return 'Avoir — remboursez $amount à $name et enregistrez-le';
  }

  @override
  String get journeyIssuerReplaces =>
      'Annulée — émettez la facture de remplacement';

  @override
  String journeyMemberConfirms(String amount) {
    return 'À vous : confirmez dans Événements le paiement de $amount enregistré pour vous';
  }

  @override
  String journeyMemberDeclared(String amount) {
    return 'Vous avez déclaré $amount — l\'espace le confirme';
  }

  @override
  String journeyMemberPays(String amount, String date) {
    return 'À vous : payez $amount avant le $date';
  }

  @override
  String journeyMemberPaysOverdue(String amount, int days) {
    return 'À vous : payez $amount — en retard de $days jours';
  }

  @override
  String journeyMemberPaysRemainder(String amount) {
    return 'À vous : payez le reliquat de $amount';
  }

  @override
  String journeyMemberRefund(String amount) {
    return 'L\'espace vous doit $amount — rien à payer';
  }

  @override
  String journeyMemberRegistered(String amount) {
    return 'Votre paiement de $amount est enregistré — l\'espace le rapproche de cette facture';
  }

  @override
  String get journeyMemberReplaces =>
      'Annulée — une facture de remplacement suit';

  @override
  String get journeyMemberValidators =>
      'Paiement rapproché — en attente de validation';

  @override
  String get journeyMemberWriteoff =>
      'L\'espace a demandé l\'annulation du reliquat — en attente de validation';

  @override
  String journeyOutstanding(String amount) {
    return '$amount dus';
  }

  @override
  String journeyOverdueCount(int count) {
    return '$count en retard';
  }

  @override
  String get journeyPrimaryConfirmInEvents => 'Ouvrir Événements';

  @override
  String journeyPrimaryRemind(int level) {
    return 'Envoyer la relance $level';
  }

  @override
  String get journeyStageClosed => 'Closes';

  @override
  String get journeyStageCollect => 'À encaisser';

  @override
  String get journeyStageConfirm => 'À confirmer';

  @override
  String get journeyStageIssue => 'À émettre';

  @override
  String get journeyStageStripLabel =>
      'Le processus de facturation : émettre, encaisser, confirmer, clore';

  @override
  String get journeyStepClosed => 'Close';

  @override
  String get journeyStepConfirmation => 'Confirmation';

  @override
  String get journeyStepIssued => 'Émise';

  @override
  String get journeyStepPayment => 'Paiement';

  @override
  String get journeyTimelineTitle => 'Chronologie';

  @override
  String get journeyValidatorsMatch =>
      'Paiement rapproché — en attente de la décision des valideurs';

  @override
  String get journeyValidatorsWriteoff =>
      'Annulation du reliquat demandée — en attente des valideurs';

  @override
  String get kioskBadgeConfirm => 'Confirmer';

  @override
  String get kioskBadgeFieldLabel => 'Code du badge';

  @override
  String get kioskBadgeHint =>
      'Scannez le QR de votre badge, ou saisissez son code.';

  @override
  String get kioskBadgeHintNfc =>
      'Approchez votre carte, scannez votre QR, ou saisissez le code.';

  @override
  String get kioskBadgeRejected => 'Badge non reconnu.';

  @override
  String kioskBasis(String granularity, String hours) {
    return 'Règle : $granularity · aujourd’hui $hours';
  }

  @override
  String kioskBlockedContactHint(String name) {
    return 'Occupé par $name — vous pouvez lui écrire depuis l\'application sur votre téléphone.';
  }

  @override
  String get kioskCheckIn => 'Arrivée';

  @override
  String get kioskCheckInRightAway => 'Pointer tout de suite';

  @override
  String get kioskCheckInRightAwayHint =>
      'Vous êtes sur place — la réservation démarre pointée.';

  @override
  String get kioskCheckOut => 'Départ';

  @override
  String get kioskClosedToday =>
      'L\'espace est fermé aujourd\'hui — pointage et réservations impossibles.';

  @override
  String get kioskConfirmAction => 'Confirmer';

  @override
  String get kioskDone => 'C\'est fait — tout est en ordre.';

  @override
  String get kioskGateBody =>
      'Ce compte est configuré comme borne de l\'espace. En mode borne, la tablette n\'affiche que le plan pour le pointage par badge — rien d\'autre ne peut être ouvert. Pour quitter le mode borne, redémarrez la tablette.';

  @override
  String get kioskGateReject => 'Pas maintenant — ouvrir l\'appli normalement';

  @override
  String get kioskGateStart => 'Démarrer le mode borne';

  @override
  String get kioskGateTitle => 'Démarrer le mode borne ?';

  @override
  String get kioskLevelButton => 'Ce niveau';

  @override
  String get kioskNfcFailed =>
      'Le lecteur RFID n\'a pas démarré — redémarrez l\'application et réessayez.';

  @override
  String get kioskNfcOff =>
      'Le NFC est désactivé dans les paramètres Android de cette tablette — activez-le pour lire les cartes RFID.';

  @override
  String get kioskNfcUnsupported =>
      'Cette tablette n\'a pas de lecteur NFC — scannez le badge QR à la place.';

  @override
  String get kioskNotCheckedIn =>
      'Aucun pointage actif trouvé — le plan vient peut-être de se mettre à jour.';

  @override
  String get kioskPeriodCheckInHint =>
      'Jusqu\'à quand restez-vous ? Le pointage commence maintenant.';

  @override
  String get kioskPeriodReserveHint =>
      'Choisissez la période — aujourd\'hui uniquement.';

  @override
  String get kioskPresentBadge => 'Présentez votre badge';

  @override
  String get kioskPresentBadgeNext => 'Présenter le badge';

  @override
  String get kioskRejectAction => 'Rejeter';

  @override
  String get kioskReserve => 'Réserver';

  @override
  String get kioskReserveAndCheckIn => 'Réserver et pointer';

  @override
  String get kioskRestOfDay => 'Reste de la journée';

  @override
  String get kioskRevertDesc =>
      'Ce profil est configuré comme borne de l\'espace. Rétablissez-le comme membre pour que la question borne ne s\'affiche plus au démarrage.';

  @override
  String get kioskRevertDone => 'Ce profil est de nouveau un membre normal.';

  @override
  String get kioskRevertTitle => 'Appareil borne';

  @override
  String get kioskScanQr => 'Scanner le badge QR';

  @override
  String get kioskTapHint => 'Touchez une place pour pointer';

  @override
  String get languageNameCS => 'Tchèque';

  @override
  String get languageNameDA => 'Danois';

  @override
  String get languageNameDE => 'Allemand';

  @override
  String get languageNameEL => 'Grec';

  @override
  String get languageNameEN => 'Anglais';

  @override
  String get languageNameES => 'Espagnol';

  @override
  String get languageNameFI => 'Finnois';

  @override
  String get languageNameFR => 'Français';

  @override
  String get languageNameHU => 'Hongrois';

  @override
  String get languageNameIT => 'Italien';

  @override
  String get languageNameJA => 'Japonais';

  @override
  String get languageNameNB => 'Norvégien';

  @override
  String get languageNameNL => 'Néerlandais';

  @override
  String get languageNamePL => 'Polonais';

  @override
  String get languageNamePT => 'Portugais';

  @override
  String get languageNameRO => 'Roumain';

  @override
  String get languageNameSV => 'Suédois';

  @override
  String get languageSystemDefault => 'Par défaut du système';

  @override
  String get languageTitle => 'Langue';

  @override
  String get ledgerCategoryAdjustment => 'Ajustement';

  @override
  String get ledgerCategoryExpense => 'Remboursement de dépense';

  @override
  String get ledgerCategoryOverage => 'Dépassement';

  @override
  String get ledgerCategoryPayment => 'Paiement';

  @override
  String get ledgerCategoryService => 'Service';

  @override
  String get ledgerCategorySubscription => 'Abonnement';

  @override
  String get legalIdentityAssociationRegime =>
      'Une association sans activité lucrative n\'est pas assujettie à la TVA : choisissez « Hors du champ de la TVA », pas « Franchise ». La franchise exige un numéro de TVA que vous n\'avez pas, et la facture électronique serait rejetée. Hors du champ, c\'est votre SIRET qui identifie l\'association.';

  @override
  String get legalIdentityCity => 'Ville';

  @override
  String get legalIdentityExemptionReason =>
      'Motif de non-application de la TVA';

  @override
  String get legalIdentityIntro =>
      'Ce qu\'une facture électronique EN 16931 doit indiquer à votre sujet. Les factures déjà émises conservent l\'identité avec laquelle elles ont été signées.';

  @override
  String get legalIdentityLegalId => 'Numéro d\'immatriculation';

  @override
  String get legalIdentityPostalCode => 'Code postal';

  @override
  String get legalIdentityRegime => 'Régime de TVA';

  @override
  String get legalIdentityRegimeExempt => 'Exonéré de TVA (franchise en base)';

  @override
  String get legalIdentityRegimeHint =>
      'Le régime détermine le numéro exigé par la norme : un numéro d’immatriculation hors champ de la TVA, un numéro de TVA en franchise.';

  @override
  String get legalIdentityRegimeNotSubject => 'Hors du champ de la TVA';

  @override
  String get legalIdentityRegimeVatRegistered =>
      'Assujetti à la TVA (facture la TVA)';

  @override
  String get legalIdentitySaved => 'Identité légale enregistrée.';

  @override
  String get legalIdentityStreet => 'Rue';

  @override
  String get legalIdentitySubtitle =>
      'Régime de TVA, identifiants légaux et conditions de paiement par défaut de l\'espace';

  @override
  String get legalIdentityTitle =>
      'Identité légale et facturation électronique';

  @override
  String get legalIdentityVatId => 'Numéro de TVA';

  @override
  String get legalIdentityVatWarning =>
      'Cet espace facture la TVA mais aucun taux n\'est configuré : les factures n\'affichent pas de taxe et l\'export XML reste désactivé tant qu\'il n\'y en a pas.';

  @override
  String get legendBlocked => 'Bloquée';

  @override
  String get legendClosed => 'Jour fermé';

  @override
  String get legendFree => 'Libre';

  @override
  String get legendMine => 'La mienne';

  @override
  String get legendOccupied => 'Présent';

  @override
  String get legendProfileFull => 'Tous les états';

  @override
  String get legendProfileFullDesc =>
      'Libre · Réservée · Présent · La mienne · Bloquée — vous voyez qui est arrivé.';

  @override
  String get legendProfileSimple => 'Moins d’états';

  @override
  String get legendProfileSimpleDesc =>
      'Place libre · Place réservée · Ma place · Place non disponible. Une place réservée et une place où quelqu’un est arrivé se ressemblent.';

  @override
  String get legendProfileTitle => 'Ce que le plan distingue';

  @override
  String get legendReserved => 'Réservée';

  @override
  String get legendUnavailable => 'Indisponible';

  @override
  String get levelAssignMember => 'Pour le membre';

  @override
  String get levelAssignMyself => 'Moi-même';

  @override
  String get levelBookableDesc =>
      'L\'étage entier peut être réservé en une seule réservation.';

  @override
  String get levelBookableToggle => 'Réservable en entier';

  @override
  String get levelConflict => 'Le niveau a des réservations sur cette période.';

  @override
  String get levelDetail => 'Niveau entier';

  @override
  String get levelFeatureOff =>
      'Les réservations de bureau et de niveau sont désactivées dans les fonctionnalités.';

  @override
  String get levelNotAllowed =>
      'Vous n\'êtes pas autorisé à réserver une table, un bureau ou un niveau entier.';

  @override
  String get levelPermissionAllowed =>
      'Peut réserver une table, un bureau ou un niveau entier';

  @override
  String get levelPermissionDenied =>
      'Ne peut pas réserver une table, un bureau ou un niveau entier';

  @override
  String get levelPermissionTile => 'Réservations de niveau';

  @override
  String get levelPriceLabel => 'Prix par demi-journée';

  @override
  String get levelReorderStale =>
      'Les niveaux ont changé entre-temps. Rien n\'a été enregistré ; l\'ordre actuel est affiché.';

  @override
  String get levelReserveButton => 'Réserver le niveau';

  @override
  String get levelReserveTitle => 'Réserver le niveau entier';

  @override
  String get levelSupplementLabel => 'Réservations de niveau';

  @override
  String get libraryApplied => 'Modèle appliqué.';

  @override
  String libraryAppliedChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changements appliqués.',
      one: '1 changement appliqué.',
    );
    return '$_temp0';
  }

  @override
  String get libraryApply => 'Appliquer à cet espace';

  @override
  String libraryApplyChanges(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Appliquer $count changements',
      one: 'Appliquer 1 changement',
      zero: 'Rien de sélectionné',
    );
    return '$_temp0';
  }

  @override
  String get libraryApplyConfirmBody =>
      'Le plan est ajouté ou mis à jour par nom, et les réglages que porte le modèle sont fusionnés. Rien de ce que vous avez déjà n\'est supprimé.';

  @override
  String libraryApplyConfirmTitle(String name) {
    return 'Appliquer « $name » ?';
  }

  @override
  String get libraryCarriesSettings => 'avec ses réglages';

  @override
  String libraryConfirmSensitive(String groups) {
    return 'Cela modifie : $groups. Appliquer ?';
  }

  @override
  String libraryCounts(int levels, int desks, int seats) {
    return '$levels niveaux · $desks tables · $seats places';
  }

  @override
  String get libraryCustomizedHere => 'Personnalisé ici';

  @override
  String get libraryDelete => 'Supprimer le modèle';

  @override
  String libraryDeleteConfirm(String name) {
    return 'Supprimer « $name » ? Les personnes avec qui vous l\'avez partagé perdent l\'accès.';
  }

  @override
  String get libraryEmpty =>
      'Rien ici pour l\'instant. Enregistrez cet espace comme modèle, ou attendez qu\'on en partage un avec vous.';

  @override
  String libraryFeatureNeeds(String feature, String prerequisite) {
    return '$feature nécessite $prerequisite, qui reste désactivé : cela ne fonctionnera pas encore.';
  }

  @override
  String get libraryGroupAppearance => 'Apparence';

  @override
  String get libraryGroupCalendarNavigation => 'Calendrier et fermetures';

  @override
  String get libraryGroupDocumentsOperations => 'Documents et fonctionnement';

  @override
  String get libraryGroupForms => 'Formulaires';

  @override
  String get libraryGroupHoursBooking => 'Horaires et réservation';

  @override
  String get libraryGroupPricingCredits => 'Prix et crédits';

  @override
  String get libraryGroupRolesAccess => 'Rôles et accès';

  @override
  String get libraryGroupSpace => 'Espace et plan';

  @override
  String get libraryGroupUnknown =>
      'Autre — cette version ne peut pas l\'appliquer';

  @override
  String get libraryGroupWording => 'Vocabulaire';

  @override
  String get libraryInvitationTexts => 'Textes d\'invitation';

  @override
  String libraryInvitationTextsHint(String tag) {
    return 'Seulement des textes écrits avec des variables comme $tag ; un texte qui nomme votre espace ou ses membres est refusé.';
  }

  @override
  String get libraryInvitationTextsRefused =>
      'Un texte d\'invitation nomme encore votre espace ou ses membres. Remplacez-les par des variables dans les réglages d\'invitation, ou décochez les textes d\'invitation.';

  @override
  String get libraryNeverDocumentDesign => 'Mise en page des documents';

  @override
  String get libraryNeverDocumentLinks => 'Liens vers vos documents';

  @override
  String get libraryNeverIdentity =>
      'Votre adresse, vos identifiants légaux, mentions légales et groupe WhatsApp';

  @override
  String get libraryNeverInvitations => 'Textes d\'invitation';

  @override
  String get libraryNeverPayment => 'Coordonnées bancaires';

  @override
  String get libraryNeverPublished => 'Jamais publié';

  @override
  String get libraryNeverSites => 'Les sites et leurs adresses';

  @override
  String get libraryNotSupported => 'Ce modèle ne peut pas être appliqué ici.';

  @override
  String get libraryNothingToApply =>
      'Tout ce que porte ce modèle est déjà là.';

  @override
  String get libraryPartial =>
      'Une partie de ce modèle ne peut pas être appliquée ici et est laissée de côté.';

  @override
  String libraryPlanNames(String names) {
    return 'Ces noms partent avec le plan : $names';
  }

  @override
  String get libraryPreviewChanges => 'Voir les changements';

  @override
  String get libraryPreviewFailed =>
      'Les changements n\'ont pas pu être prévisualisés. Rien n\'a été appliqué.';

  @override
  String libraryPreviewTitle(String name) {
    return 'Ce que « $name » changerait';
  }

  @override
  String libraryProcessOff(String feature) {
    return '$feature désactivé';
  }

  @override
  String libraryProcessOn(String feature) {
    return '$feature activé';
  }

  @override
  String get libraryProcessTechnical => 'Technique';

  @override
  String get libraryPublishGroups => 'Ce qui voyage';

  @override
  String get libraryPublishNothing => 'Choisissez au moins un groupe.';

  @override
  String get libraryReasonFeeSchedule =>
      'Votre grille de frais serait remplacée en entier.';

  @override
  String get librarySave => 'Enregistrer cet espace comme modèle';

  @override
  String get librarySaveDescription => 'Description (facultatif)';

  @override
  String get librarySaveName => 'Nom du modèle';

  @override
  String get librarySaveTags => 'Étiquettes, séparées par des virgules';

  @override
  String get librarySaved => 'Enregistré dans vos modèles.';

  @override
  String librarySearchCapabilities(String capabilities) {
    return 'Modèles configurés pour : $capabilities';
  }

  @override
  String get librarySearchHint => 'Rechercher un modèle';

  @override
  String librarySearchSuggestion(String word) {
    return 'Vouliez-vous dire « $word » ?';
  }

  @override
  String get librarySearchUnavailable =>
      'Les réglages des modèles n\'ont pas pu être vérifiés : aucun n\'est donc affiché comme correspondant. Réessayez.';

  @override
  String get libraryShare => 'Partager…';

  @override
  String get libraryShareAdd => 'Inviter';

  @override
  String get libraryShareEmail => 'Adresse e-mail';

  @override
  String get libraryShareHint =>
      'Invitez par e-mail. L\'invitation fonctionne dès que cette adresse se connecte — rien n\'est révélé sur l\'existence d\'un compte.';

  @override
  String get libraryShareNobody => 'Personne n\'est invité pour l\'instant.';

  @override
  String libraryShareTitle(String name) {
    return 'Partager « $name »';
  }

  @override
  String get libraryStartFrom => 'Partir de la bibliothèque';

  @override
  String get libraryStateAttention => 'À examiner';

  @override
  String get libraryStateChange => 'Modifie l\'existant';

  @override
  String get libraryStateMatching => 'Déjà identique';

  @override
  String get libraryStateNew => 'Nouveau';

  @override
  String get libraryTitle => 'Bibliothèque d\'espaces';

  @override
  String get libraryVisibility => 'Qui peut le voir';

  @override
  String get libraryVisibilityBuiltin => 'Intégré';

  @override
  String get libraryVisibilityPrivate => 'Moi seulement';

  @override
  String get libraryVisibilityPublic => 'Tout le monde (la bibliothèque)';

  @override
  String get libraryVisibilityShared => 'Les personnes que j\'invite';

  @override
  String get libraryYours => 'Vos modèles';

  @override
  String get linkedAccountsIntro =>
      'Connectez-vous à ce compte avec une identité associée. Les fournisseurs disponibles dépendent de votre serveur.';

  @override
  String get linkedAccountsLink => 'Lier';

  @override
  String get linkedAccountsLinkStarted =>
      'Continuez dans le navigateur pour terminer la liaison.';

  @override
  String get linkedAccountsLinked => 'Lié';

  @override
  String get linkedAccountsTitle => 'Comptes liés';

  @override
  String get linkedAccountsUnlink => 'Délier';

  @override
  String listCoversSeats(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places',
      one: '1 place',
    );
    return '$_temp0';
  }

  @override
  String listCoversTables(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tables',
      one: '1 table',
    );
    return '$_temp0';
  }

  @override
  String get listWholeReservable => 'Réservable en entier';

  @override
  String get localGapsTitle => 'Pour terminer la configuration de cet espace';

  @override
  String get localNeedsTitle =>
      'Vous les ajouterez vous-même ; un modèle ne les transporte jamais :';

  @override
  String get localSlotEinvoicePlatform =>
      'Votre compte sur la plateforme de facturation électronique';

  @override
  String get localSlotLegalIdentity =>
      'Votre identité légale et votre adresse (pour les factures)';

  @override
  String localSlotNamedValidators(String type) {
    return 'Qui valide : $type';
  }

  @override
  String get localSlotOpen => 'Configurer';

  @override
  String get localSlotPaymentDetails =>
      'Comment les membres vous paient (coordonnées bancaires)';

  @override
  String get localSlotPaymentProvider => 'Un prestataire de paiement en ligne';

  @override
  String get localSlotRecommended => 'Recommandé';

  @override
  String get localSlotSite => 'Au moins un site';

  @override
  String get managedAccessAdmins => 'Les admins';

  @override
  String get managedAccessDefault => 'Tout propriétaire et tout admin';

  @override
  String get managedAccessHint =>
      'Par défaut : tout propriétaire et tout admin. Restreignez par rôle, par personne, ou les deux. Le propriétaire peut toujours modifier cette règle — sinon un profil deviendrait inadministrable — mais n\'accède aux données que si la règle le nomme.';

  @override
  String get managedAccessOwners => 'Les propriétaires';

  @override
  String get managedAccessPeople => 'Personnes nommées';

  @override
  String get managedAccessSaved => 'Règle enregistrée.';

  @override
  String get managedAccessTitle => 'Qui peut administrer ce profil';

  @override
  String get managedProfileAdd => 'Ajouter un profil géré';

  @override
  String get managedProfileChip => 'Géré';

  @override
  String get managedProfileCreated => 'Profil géré créé';

  @override
  String get managedProfileEdit => 'Modifier l\'identité';

  @override
  String get managedProfileHandOver => 'Remettre à la personne';

  @override
  String get managedProfileHandOverHint =>
      'Crée un code personnel lié à ce profil. Qui l\'utilise reprend le profil — réservations, factures, abonnement — dès que vous validez l\'adhésion.';

  @override
  String get managedProfileIdentityUnavailable =>
      'Ces informations n\'ont pas pu être lues : il n\'y a donc rien à modifier pour l\'instant. Rien n\'a été changé.';

  @override
  String get managedProfileIntro =>
      'Cette personne n\'a pas encore de compte. Vous réservez, facturez et gérez pour elle ; remettez-lui le profil quand elle rejoint l\'espace.';

  @override
  String get managedProfileRevoke => 'Annuler la remise';

  @override
  String get managedProfileRevoked => 'Remise annulée';

  @override
  String get managedProfileSaved => 'Identité enregistrée';

  @override
  String get managedProfileTitle => 'Profil géré';

  @override
  String get mcpApiReference => 'Référence de l’API';

  @override
  String get mcpApiReferenceHint =>
      'Ce qu’un assistant peut appeler, et comment c’est autorisé';

  @override
  String get mcpAssistantsTitle => 'Assistants';

  @override
  String get mcpAssistantsUnavailable =>
      'Votre accès aux assistants n\'a pas pu être chargé. Réessayez plus tard.';

  @override
  String get mcpCancel => 'Annuler';

  @override
  String get mcpConfirmAccept => 'Confirmer';

  @override
  String get mcpConfirmApprove => 'Votre réponse : approuver';

  @override
  String mcpConfirmClient(String client) {
    return 'Demandé par : $client';
  }

  @override
  String get mcpConfirmConsequence =>
      'Confirmer permet à l\'assistant d\'envoyer cette demande exacte une seule fois. Les règles de validation de l\'espace s\'appliquent toujours.';

  @override
  String get mcpConfirmDecline => 'Refuser';

  @override
  String get mcpConfirmDeclined => 'Refusé. Rien n\'a été fait.';

  @override
  String get mcpConfirmDone =>
      'Confirmé. L\'assistant peut maintenant envoyer la demande.';

  @override
  String get mcpConfirmExpired =>
      'Cette demande a expiré. Demandez à l\'assistant de la renvoyer.';

  @override
  String mcpConfirmNewShare(String pct) {
    return 'Nouvelle part d\'abonnement : $pct %';
  }

  @override
  String mcpConfirmNewStatus(String status) {
    return 'Nouveau statut : $status';
  }

  @override
  String get mcpConfirmNotFound =>
      'Aucune demande de ce type ne vous concerne.';

  @override
  String mcpConfirmPeriod(String period) {
    return 'Période : $period';
  }

  @override
  String get mcpConfirmRefuse => 'Votre réponse : refuser';

  @override
  String get mcpConfirmStale =>
      'Cette demande ne correspond plus aux données actuelles ou à vos accès. Rien n\'a été fait.';

  @override
  String get mcpConfirmTitle => 'Confirmer une demande d\'assistant';

  @override
  String get mcpConfirmUnavailable =>
      'Cette demande n\'a pas pu être chargée. Réessayez depuis le lien.';

  @override
  String mcpConfirmWorkspace(String workspace) {
    return 'Espace : $workspace';
  }

  @override
  String mcpConnectAccessExpiresIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return 'Approuvé — encore $_temp0.';
  }

  @override
  String mcpConnectAccessExpiresSoon(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days jours',
      one: '1 jour',
    );
    return 'Approuvé — expire dans $_temp0. Redemandez l’approbation une fois expiré.';
  }

  @override
  String get mcpConnectAddTitle => 'Ajouter DesKilo à votre assistant';

  @override
  String get mcpConnectAddressLabel =>
      'Votre adresse DesKilo pour les assistants';

  @override
  String get mcpConnectAllDone =>
      'Tout est prêt. Testez la connexion ci-dessous.';

  @override
  String get mcpConnectBeforeTitle => 'Avant de connecter';

  @override
  String get mcpConnectChatgptNote =>
      'Le mode développeur nécessite une offre ChatGPT payante (Plus, Pro, Business, Enterprise ou Edu).';

  @override
  String get mcpConnectChatgptStep1 =>
      'Dans ChatGPT, activez le mode développeur : Paramètres → Apps → Paramètres avancés.';

  @override
  String get mcpConnectChatgptStep2 =>
      'Créez une app nommée DesKilo, collez l’adresse ci-dessus et choisissez OAuth comme authentification.';

  @override
  String get mcpConnectChatgptStep3 =>
      'Connectez-vous avec Google et choisissez cet espace de travail et ce que ChatGPT peut y faire.';

  @override
  String get mcpConnectClaudeNote =>
      'Claude sur le web, Claude Desktop et l’application mobile Claude partagent les mêmes connecteurs. Avec une offre Team ou Enterprise, un propriétaire de l’organisation Claude ajoute d’abord le connecteur.';

  @override
  String get mcpConnectClaudeOpen => 'Ouvrir les connecteurs Claude';

  @override
  String get mcpConnectClaudeStep1 =>
      'Dans Claude, ouvrez Paramètres → Connecteurs.';

  @override
  String get mcpConnectClaudeStep2 =>
      'Choisissez « Ajouter un connecteur personnalisé », nommez-le DesKilo et collez l’adresse ci-dessus.';

  @override
  String get mcpConnectClaudeStep3 =>
      'Choisissez Connecter, connectez-vous avec Google et choisissez cet espace de travail et ce que Claude peut y faire.';

  @override
  String get mcpConnectCodeStep1 => 'Exécutez ceci dans un terminal :';

  @override
  String get mcpConnectCodeStep2 =>
      'Dans Claude Code, tapez /mcp, choisissez deskilo puis Authenticate. Un navigateur s’ouvre pour vous connecter et choisir cet espace de travail.';

  @override
  String get mcpConnectCopied => 'Copié.';

  @override
  String get mcpConnectCopyRequest => 'Copier une demande à envoyer';

  @override
  String get mcpConnectCursorInstall => 'Ajouter à Cursor';

  @override
  String get mcpConnectCursorStep =>
      'Cursor propose d’installer DesKilo, puis ouvre un navigateur pour vous connecter et choisir cet espace de travail. Sans le bouton, ajoutez ceci à ~/.cursor/mcp.json :';

  @override
  String get mcpConnectDone => 'Fait';

  @override
  String get mcpConnectIntro =>
      'Laissez Claude, ChatGPT ou un autre assistant consulter et réserver pour vous dans DesKilo. Il agit en votre nom, uniquement dans les espaces de travail et pour les actions que vous approuvez.';

  @override
  String mcpConnectLastCall(String client, String when) {
    return 'Dernier appel : $client, $when.';
  }

  @override
  String get mcpConnectManageHint =>
      'Pour voir ce qu\'un assistant a fait ou pour le déconnecter, ouvrez Assistants.';

  @override
  String get mcpConnectOpenFailed =>
      'L’application n’a pas pu être ouverte d’ici. Suivez plutôt les étapes ci-dessous.';

  @override
  String get mcpConnectOpenGuide => 'Ouvrir le guide de connexion';

  @override
  String get mcpConnectOpenInstallation =>
      'Ouvrir la console de l\'installation';

  @override
  String get mcpConnectOpenSetup => 'Ouvrir la configuration des assistants';

  @override
  String get mcpConnectOperatorRequest =>
      'Bonjour, pourriez-vous activer les assistants sur notre serveur DesKilo ? C\'est dans Paramètres → Installation : assistants. Merci.';

  @override
  String get mcpConnectOtherStep1 =>
      'La plupart des clients lisent un fichier JSON de serveurs. Ajoutez cette entrée ; le client ouvre un navigateur pour vous connecter la première fois.';

  @override
  String get mcpConnectOtherStep2 =>
      'Un client qui ne lance que des programmes locaux peut joindre DesKilo via mcp-remote (nécessite Node.js) :';

  @override
  String get mcpConnectRoleDenied =>
      'Rien n\'est proposé à votre rôle ici. Un administrateur de l\'espace de travail décide de ce que chaque rôle peut faire.';

  @override
  String get mcpConnectStepAccess => 'Votre accès aux assistants';

  @override
  String get mcpConnectStepConnect => 'DesKilo ajouté à votre assistant';

  @override
  String get mcpConnectStepGoogle => 'Connexion avec Google';

  @override
  String get mcpConnectStepIdentity => 'Votre identité sur ce serveur';

  @override
  String get mcpConnectStepServer => 'Assistants activés sur ce serveur';

  @override
  String get mcpConnectStepWorkspace =>
      'Cet espace de travail propose les assistants';

  @override
  String get mcpConnectSwitchWorkspace => 'Passer à cet espace de travail';

  @override
  String get mcpConnectTabChatgpt => 'ChatGPT';

  @override
  String get mcpConnectTabClaude => 'Claude';

  @override
  String get mcpConnectTabClaudeCode => 'Claude Code';

  @override
  String get mcpConnectTabCursor => 'Cursor';

  @override
  String get mcpConnectTabOther => 'Autre';

  @override
  String get mcpConnectTabVscode => 'VS Code';

  @override
  String get mcpConnectTest => 'Tester la connexion';

  @override
  String get mcpConnectTestAgain => 'Tester à nouveau';

  @override
  String get mcpConnectTestPrompt =>
      'Avec DesKilo, quelles sont mes réservations cette semaine ?';

  @override
  String mcpConnectTestReached(String client, String when) {
    return 'Connecté : $client a joint DesKilo, $when.';
  }

  @override
  String get mcpConnectTestTimeout =>
      'Aucun appel reçu pour l’instant. Vérifiez que le connecteur est ajouté, que vous avez approuvé cet espace de travail et que les étapes ci-dessus sont faites, puis testez à nouveau.';

  @override
  String get mcpConnectTestTitle => 'Vérifier que cela fonctionne';

  @override
  String get mcpConnectTestWaiting =>
      'En attente d’un appel de votre assistant à DesKilo. Demandez-lui :';

  @override
  String get mcpConnectTitle => 'Connecter un assistant';

  @override
  String get mcpConnectTodoConnect =>
      'À faire — vous : suivez les étapes pour votre assistant ci-dessous.';

  @override
  String get mcpConnectTodoYou => 'À faire — vous.';

  @override
  String get mcpConnectUnavailable => 'Impossible à vérifier pour l\'instant.';

  @override
  String get mcpConnectVscodeInstall => 'Ajouter à VS Code';

  @override
  String get mcpConnectVscodeStep =>
      'VS Code propose d’installer DesKilo. Démarrez-le depuis la liste des serveurs MCP ; un navigateur s’ouvre pour vous connecter et choisir cet espace de travail.';

  @override
  String get mcpConnectWaitingDatabaseAdmin =>
      'En attente d\'un administrateur de la base de données qui approuve votre demande.';

  @override
  String mcpConnectWaitingOperator(String names) {
    return 'En attente de l\'opérateur du serveur : $names.';
  }

  @override
  String get mcpConnectWaitingOperatorUnknown =>
      'En attente de l\'opérateur du serveur, qui n\'est pas encore désigné.';

  @override
  String get mcpConnectWaitingWorkspaceAdmin =>
      'En attente d\'un administrateur de l\'espace de travail qui propose les assistants ici.';

  @override
  String get mcpConnectWhich => 'Quel assistant utilisez-vous ?';

  @override
  String get mcpConnectWorkspaceSelected => 'Espace de travail sélectionné';

  @override
  String get mcpConnectWorkspacesHint =>
      'Chaque espace de travail décide pour lui-même. Quand votre assistant le demande, vous choisissez parmi ceux qui sont prêts.';

  @override
  String get mcpConnectWorkspacesTitle => 'Vos espaces de travail';

  @override
  String get mcpConnectWsConnected =>
      'Connecté — un assistant peut agir pour vous ici.';

  @override
  String get mcpConnectWsNotOffered =>
      'Les assistants sont activés, mais rien n\'est encore proposé à votre rôle. Un administrateur de l\'espace de travail décide.';

  @override
  String get mcpConnectWsOff =>
      'Les assistants sont désactivés dans cet espace de travail. Un administrateur de l\'espace de travail les active dans la configuration des assistants.';

  @override
  String get mcpConnectWsReady =>
      'Prêt — choisissez-le quand votre assistant le demande.';

  @override
  String get mcpConnectWsUnknown =>
      'Affiché une fois votre accès aux assistants approuvé.';

  @override
  String get mcpConnectedNoWorkspace =>
      'Aucun espace : cet assistant ne peut rien faire ici.';

  @override
  String get mcpConnectedNone =>
      'Aucun assistant n\'est connecté. Connectez-en un depuis l\'assistant lui-même.';

  @override
  String get mcpConnectedTitle => 'Assistants connectés';

  @override
  String get mcpConsentAlready =>
      'Cet assistant est déjà connecté. Retour vers lui.';

  @override
  String get mcpConsentApprove => 'Connecter';

  @override
  String mcpConsentAsks(String client) {
    return '$client demande à agir pour vous dans Deskilo.';
  }

  @override
  String get mcpConsentChoose =>
      'Choisissez chaque espace et ce que l\'assistant peut y faire. Rien n\'est choisi à votre place.';

  @override
  String mcpConsentClientBlocked(String name) {
    return 'L\'opérateur a bloqué $name sur ce serveur. Il ne peut pas être connecté.';
  }

  @override
  String mcpConsentClientWaiting(String name) {
    return '$name n\'est pas encore approuvé sur ce serveur. L\'opérateur approuve chaque assistant une fois ; reconnectez-vous ensuite depuis l\'assistant.';
  }

  @override
  String get mcpConsentConnected => 'Connecté. Retour vers l\'assistant.';

  @override
  String mcpConsentDeciderAsk(String name) {
    return 'Demandez à $name de décider.';
  }

  @override
  String get mcpConsentDeciderMe =>
      'C\'est vous qui décidez, dans la console de l\'installation.';

  @override
  String get mcpConsentDeciderNobody =>
      'Personne ne répond encore de ce serveur.';

  @override
  String get mcpConsentDenied => 'Refusé. L\'assistant n\'obtient rien.';

  @override
  String get mcpConsentDeny => 'Refuser';

  @override
  String get mcpConsentFamilyChatgpt =>
      'Approuvé pour toutes les connexions ChatGPT.';

  @override
  String get mcpConsentFamilyClaude =>
      'Approuvé pour toutes les connexions Claude.';

  @override
  String get mcpConsentFamilyLoopback =>
      'Approuvé pour les assistants de bureau et en ligne de commande sur cet ordinateur.';

  @override
  String get mcpConsentFieldsExplain =>
      'Détails qu\'il peut aussi voir ici. Laissez-les décochés pour garder ses réponses minimisées.';

  @override
  String get mcpConsentNoWorkspace =>
      'Aucun de vos espaces n\'accepte les assistants. Rien ne peut être connecté.';

  @override
  String get mcpConsentNotEligible =>
      'Cette base de données n\'a pas encore autorisé les assistants pour vous. Demandez l\'autorisation, puis reconnectez-vous.';

  @override
  String get mcpConsentPartial =>
      'L\'assistant a été approuvé mais la connexion n\'est pas encore utilisable. Reconnectez-vous depuis l\'assistant.';

  @override
  String mcpConsentRedirectHost(String host) {
    return 'La réponse est envoyée à $host.';
  }

  @override
  String get mcpConsentRequestEligibility => 'Demander l\'autorisation';

  @override
  String get mcpConsentRequested =>
      'Autorisation demandée. Un administrateur de la base l\'examinera.';

  @override
  String get mcpConsentTitle => 'Connecter un assistant';

  @override
  String get mcpConsentUnavailable =>
      'Cette demande de connexion n\'a pas pu être chargée. Recommencez depuis l\'assistant.';

  @override
  String get mcpDisclosureMaximumExplain =>
      'Le maximum que les propriétaires de cette base de données peuvent laisser voir aux assistants. Il n\'élargit jamais la politique d\'un espace ni le consentement d\'une personne.';

  @override
  String get mcpDisclosureMaximumLocked =>
      'Confirmez avec votre second facteur pour voir et modifier le maximum.';

  @override
  String get mcpDisclosureMaximumRefused =>
      'Le maximum n\'a pas été enregistré. Il faut votre second facteur.';

  @override
  String get mcpDisclosureMaximumSave => 'Enregistrer le maximum';

  @override
  String get mcpDisclosureMaximumSaved => 'Maximum enregistré.';

  @override
  String get mcpDisclosureNoneAllowed =>
      'Cette base de données ne permet de montrer aucun détail facultatif aux assistants.';

  @override
  String get mcpDisclosurePolicyExplain =>
      'Les assistants reçoivent des réponses minimisées. Choisissez les détails qu\'ils peuvent aussi voir ici ; chaque personne choisit encore pour elle-même.';

  @override
  String get mcpDisclosurePreviewDetailed => 'Réponse détaillée';

  @override
  String get mcpDisclosurePreviewMinimised => 'Réponse minimisée';

  @override
  String get mcpDisclosurePreviewNote =>
      'Une réponse fictive, pour montrer ce que verraient les assistants.';

  @override
  String get mcpDisclosureTitle => 'Détails facultatifs';

  @override
  String get mcpDisclosureUnlock => 'Confirmer';

  @override
  String get mcpDisconnect => 'Déconnecter';

  @override
  String get mcpDisconnectBody =>
      'L\'assistant perd l\'accès à tous les espaces de cette base. Ce qu\'il a déjà lu n\'est pas repris.';

  @override
  String mcpDisconnectTitle(String client) {
    return 'Déconnecter $client ?';
  }

  @override
  String get mcpEligibleExpired =>
      'Votre autorisation a expiré. Redemandez-la pour continuer à utiliser des assistants.';

  @override
  String get mcpEligibleNoIdentity =>
      'Votre identité n\'est pas encore confirmée pour les assistants sur cette base.';

  @override
  String get mcpEligibleNot =>
      'Cette base n\'a pas autorisé les assistants pour vous.';

  @override
  String get mcpEligibleRequested =>
      'Vous avez demandé l\'autorisation. Un administrateur de la base l\'examinera.';

  @override
  String get mcpEligibleWithdraw =>
      'Renoncer à l\'accès des assistants sur cette base';

  @override
  String get mcpEligibleYes =>
      'Cette base vous autorise à utiliser des assistants.';

  @override
  String get mcpFieldName => 'Noms des espaces et des places';

  @override
  String get mcpFieldNameSample => 'Bureau fenêtre 12';

  @override
  String get mcpGroupFinancial => 'Demandes financières';

  @override
  String get mcpGroupMembership => 'Demandes d\'adhésion';

  @override
  String get mcpGroupOwn => 'Réservations et compte personnels';

  @override
  String get mcpGroupValidations => 'Validations';

  @override
  String get mcpIdentityConflict =>
      'Un autre compte détient déjà cette identité ici — un administrateur de la base peut résoudre cela.';

  @override
  String get mcpIdentityIneligible =>
      'Ce compte ne peut pas encore être confirmé — confirmez d\'abord votre adresse e-mail ou connectez-vous avec un fournisseur.';

  @override
  String get mcpNextAwaitEligibility =>
      'Prochaine étape : un administrateur de la base de données statue sur votre demande.';

  @override
  String get mcpNextConsent =>
      'Prochaine étape : connectez un assistant depuis l\'assistant lui-même et approuvez cet espace de travail.';

  @override
  String get mcpNextLinkGoogle =>
      'Les assistants utilisent votre connexion Google. Liez d\'abord Google à ce compte ; sans cela, le compte ne peut pas utiliser d\'assistant.';

  @override
  String get mcpNextLinkIdentity =>
      'Prochaine étape : confirmez votre identité pour les assistants sur cette base — un geste ci-dessous.';

  @override
  String get mcpNextOwnerExposes =>
      'Prochaine étape : le propriétaire de l\'espace de travail propose des opérations aux assistants.';

  @override
  String get mcpNextReady =>
      'Prêt : un assistant connecté peut agir pour vous dans cet espace de travail, dans la limite de ce que vous avez approuvé.';

  @override
  String get mcpNextRequestEligibility =>
      'Prochaine étape : vous demandez l\'approbation aux administrateurs de cette base de données.';

  @override
  String get mcpNextRoleDenied =>
      'Votre rôle ne laisse ici aucune opération. Le propriétaire de l\'espace de travail décide de ce que chaque rôle peut faire.';

  @override
  String get mcpNextSignInGoogle =>
      'Les assistants utilisent votre connexion Google. Connectez-vous avec Google pour continuer.';

  @override
  String get mcpNextUnavailable =>
      'Le serveur n\'a pas pu répondre. Rien n\'est présumé ; réessayez plus tard.';

  @override
  String get mcpOpAvailability => 'Voir les places libres';

  @override
  String get mcpOpCancelReservation =>
      'Annuler vos réservations qui n\'ont pas commencé';

  @override
  String get mcpOpCapabilities => 'Voir ce qu\'il peut y faire';

  @override
  String get mcpOpCheckIn => 'Faire votre arrivée';

  @override
  String get mcpOpCheckOut => 'Faire votre départ';

  @override
  String get mcpOpCreateReservation => 'Réserver une place pour vous';

  @override
  String get mcpOpGetPlace => 'Décrire un lieu, et le montrer sur demande';

  @override
  String get mcpOpGetValidation => 'Lire une demande de validation';

  @override
  String get mcpOpInvoiceIssue => 'Émettre une facture';

  @override
  String get mcpOpInvoiceVoid => 'Annuler une facture';

  @override
  String get mcpOpListMyFavorites => 'Vos lieux favoris';

  @override
  String get mcpOpListWorkspaces => 'Voir les espaces qu\'il peut utiliser';

  @override
  String get mcpOpMemberStatus => 'Modifier le statut d\'un membre';

  @override
  String get mcpOpMyInvoices => 'Voir vos factures';

  @override
  String get mcpOpMyReservations => 'Voir vos réservations';

  @override
  String get mcpOpMyStatement => 'Voir votre relevé de compte';

  @override
  String get mcpOpPendingValidations =>
      'Voir les demandes de validation en attente';

  @override
  String get mcpOpRatePlace => 'Noter des lieux';

  @override
  String get mcpOpRefund => 'Rembourser une facture';

  @override
  String get mcpOpReservationDeletion =>
      'Demander la suppression d\'une réservation commencée';

  @override
  String get mcpOpRespond => 'Répondre à une demande de validation';

  @override
  String get mcpOpSetFavorite => 'Marquer des lieux en favoris';

  @override
  String get mcpOpSubscription => 'Modifier la part d\'abonnement d\'un membre';

  @override
  String get mcpOpUpdateReservation => 'Modifier vos réservations';

  @override
  String get mcpOverviewTitle => 'Autres bases de données connectées';

  @override
  String get mcpOverviewUnavailable =>
      'N\'a pas pu être interrogée pour l\'instant.';

  @override
  String get mcpPolicyBroadening =>
      'Les assistants déjà connectés n\'obtiennent pas les services ajoutés : chaque personne doit les ajouter en se reconnectant.';

  @override
  String get mcpPolicyCeiling =>
      'Données sur lesquelles un assistant peut agir';

  @override
  String get mcpPolicyCeilingOwn => 'Ses propres données';

  @override
  String get mcpPolicyCeilingWorkspace => 'Tout l\'espace';

  @override
  String get mcpPolicyConflict =>
      'Cet enregistrement a été refusé. Vérifiez les réglages actuels et enregistrez à nouveau.';

  @override
  String get mcpPolicyEnabled => 'Proposer les services d\'assistant';

  @override
  String get mcpPolicyExplain =>
      'Choisissez ce que les assistants peuvent faire dans cet espace. Un membre a toujours besoin de l\'autorisation de cette base, du rôle adéquat, et doit choisir cet espace en connectant son assistant.';

  @override
  String get mcpPolicyFeatureOff =>
      'Les assistants sont désactivés dans les fonctionnalités de cet espace. Vous pouvez toujours restreindre ou désactiver les services ci-dessous.';

  @override
  String get mcpPolicySave => 'Enregistrer';

  @override
  String get mcpPolicySaved => 'Enregistré.';

  @override
  String get mcpPolicyStale =>
      'Quelqu\'un a modifié ces réglages entre-temps. Vérifiez les réglages actuels et enregistrez à nouveau.';

  @override
  String get mcpPolicySwitched =>
      'Vous avez changé d\'espace. Rouvrez cette page pour modifier l\'autre espace.';

  @override
  String get mcpPolicyTitle => 'Accès des assistants';

  @override
  String get mcpPolicyUnavailable =>
      'Les réglages des assistants n\'ont pas pu être chargés. Réessayez plus tard.';

  @override
  String get mcpRefusalClientNotApproved =>
      'Cet assistant n’est pas encore approuvé sur ce serveur. L’opérateur approuve chaque assistant une fois ; demandez-le-lui, puis reconnectez-vous depuis l’assistant.';

  @override
  String get mcpRefusalNoIdentity =>
      'Confirmez d’abord votre identité dans DesKilo sous Assistants, puis reconnectez-vous depuis l’assistant.';

  @override
  String get mcpRefusalNotEligible =>
      'Votre accès aux assistants n’est pas encore approuvé. Demandez-le dans DesKilo sous Assistants, puis reconnectez-vous depuis l’assistant.';

  @override
  String get mcpRefusalOfferChanged =>
      'Ce que propose cet espace de travail a changé pendant votre choix. Reconnectez-vous depuis l’assistant pour voir l’offre actuelle.';

  @override
  String get mcpRefusalRequestExpired =>
      'Cette demande de connexion a expiré ou a déjà été utilisée. Recommencez depuis l’assistant.';

  @override
  String get mcpRemoveWorkspace => 'Retirer cet espace';

  @override
  String get mcpReviewApprove => 'Autoriser';

  @override
  String get mcpReviewChanged =>
      'Cette demande a changé ou un autre administrateur a décidé avant vous. Rien n\'a été fait.';

  @override
  String get mcpReviewDone => 'Décision enregistrée.';

  @override
  String get mcpReviewEmpty => 'Aucune demande en attente.';

  @override
  String get mcpReviewExplain =>
      'Autoriser permet à une personne de connecter des assistants sur cette base, dans les espaces dont les propriétaires l\'acceptent. Cela n\'accorde ni adhésion ni rôle.';

  @override
  String get mcpReviewNotAdmin =>
      'Seuls les administrateurs de cette base examinent les autorisations.';

  @override
  String get mcpReviewRefused => 'La décision a été refusée.';

  @override
  String get mcpReviewReject => 'Refuser';

  @override
  String get mcpReviewSecondFactor =>
      'Cette base de données exige votre second facteur dans sa propre session. Rien n\'a été décidé.';

  @override
  String get mcpReviewTitle => 'Autorisations des assistants';

  @override
  String get mcpReviewUnavailable =>
      'Les demandes n\'ont pas pu être chargées. Un examen demande votre second facteur ; réessayez.';

  @override
  String get mcpStateAfterPrevious => 'Après l\'étape précédente';

  @override
  String get mcpStateAllowed => 'Autorisé';

  @override
  String get mcpStateApproved => 'Approuvée';

  @override
  String get mcpStateAvailable => 'Joignable';

  @override
  String get mcpStateCurrent => 'Donné';

  @override
  String get mcpStateDenied => 'Rien pour votre rôle';

  @override
  String get mcpStateDisabled => 'Rien n\'est proposé';

  @override
  String get mcpStateExposed => 'Opérations proposées';

  @override
  String get mcpStateGoogleMissing => 'Google non lié';

  @override
  String get mcpStateGoogleOtherSession => 'Connecté autrement';

  @override
  String get mcpStateGoogleReady => 'Connecté avec Google';

  @override
  String get mcpStateIncompatible => 'Version incompatible';

  @override
  String get mcpStateMissing => 'Non donné';

  @override
  String get mcpStateNotRequested => 'Non demandée';

  @override
  String get mcpStatePending => 'En attente d\'une décision';

  @override
  String get mcpStateRevoked => 'Expirée ou retirée';

  @override
  String get mcpStateUnavailable => 'Inconnu';

  @override
  String get mcpStateUnlinked => 'Non confirmée';

  @override
  String get mcpStateVerified => 'Vérifiée';

  @override
  String get mcpStatusBackend => 'Serveur';

  @override
  String get mcpStatusConfirmIdentity => 'Confirmer mon identité';

  @override
  String get mcpStatusConsent => 'Votre consentement';

  @override
  String get mcpStatusEligibility => 'Approbation de la base de données';

  @override
  String get mcpStatusExposure => 'Offre de l\'espace de travail';

  @override
  String get mcpStatusGoogle => 'Connexion Google';

  @override
  String get mcpStatusIdentity => 'Identité pour les assistants';

  @override
  String get mcpStatusLinkGoogle => 'Lier Google';

  @override
  String get mcpStatusOpenLinkedAccounts => 'Ouvrir les comptes liés';

  @override
  String get mcpStatusRole => 'Votre rôle';

  @override
  String get mcpStatusSignInGoogle => 'Se connecter avec Google';

  @override
  String get mcpStatusTitle => 'Où vous en êtes ici';

  @override
  String get mcpUsageApplied => 'Appliquées';

  @override
  String mcpUsageLastUsed(String when) {
    return 'Dernière utilisation $when';
  }

  @override
  String get mcpUsageMineTitle =>
      'Votre utilisation des assistants aujourd\'hui';

  @override
  String get mcpUsageNone => 'Aucun assistant n\'a encore utilisé votre accès.';

  @override
  String get mcpUsagePending => 'En attente de validation';

  @override
  String get mcpUsageRefusals => 'Refusées';

  @override
  String get mcpUsageRequests => 'Demandes';

  @override
  String get mcpUsageUnavailable => 'L\'utilisation n\'a pas pu être chargée.';

  @override
  String get mcpUsageWorkspaceTitle =>
      'Utilisation des assistants, 30 derniers jours';

  @override
  String get meAccountInMe => 'Mon compte est dans Moi';

  @override
  String get meAccountInMeBody =>
      'Photo, langue, thème et connexions sont à vous, dans chaque espace.';

  @override
  String get meAddressSaveFailed =>
      'Impossible d\'enregistrer votre adresse. Veuillez réessayer.';

  @override
  String get meCreateSpace => 'Créer un espace';

  @override
  String meFinanceGlanceOwed(String amount) {
    return 'À payer : $amount';
  }

  @override
  String get meFindSpace => 'Trouver un espace';

  @override
  String get meGroupAdd => 'Nouveau groupe';

  @override
  String get meGroupDelete => 'Supprimer le groupe';

  @override
  String get meGroupEmptyFavorites =>
      'Donnez un cœur à un espace : il vous attend ici.';

  @override
  String get meGroupEmptyOwn => 'Déplacez des espaces ici depuis leur menu.';

  @override
  String get meGroupFavorites => 'Favoris';

  @override
  String get meGroupInstallations => 'Installations connectées';

  @override
  String get meGroupMove => 'Déplacer vers un groupe…';

  @override
  String get meGroupName => 'Nom du groupe';

  @override
  String get meGroupOther => 'Autres';

  @override
  String get meGroupProfile => 'Mon profil';

  @override
  String get meGroupRename => 'Renommer';

  @override
  String get meGroupWorkspaces => 'Mes espaces de travail';

  @override
  String get meHeaderOwned => 'Votre compte · il n\'appartient qu\'à vous';

  @override
  String get meHomeTitle => 'Accueil';

  @override
  String get meJoinSpace => 'Rejoindre avec un code';

  @override
  String get meLeaveAction => 'Quitter cet espace';

  @override
  String get meLeaveBody =>
      'Vous cessez d\'être membre. Vos réservations, factures et messages restent dans l\'espace. Pour effacer aussi vos données, passez par Confidentialité.';

  @override
  String meLeaveDone(String name) {
    return 'Vous avez quitté $name.';
  }

  @override
  String get meLeaveFailed =>
      'Impossible de quitter l\'espace. Veuillez réessayer.';

  @override
  String get meLeaveOwner =>
      'Les propriétaires transmettent l\'espace avant de le quitter';

  @override
  String meLeaveSide(String side) {
    return 'Quitter $side';
  }

  @override
  String meLeaveTitle(String name) {
    return 'Quitter $name ?';
  }

  @override
  String meLinkedOpen(String host) {
    return 'Ouvrir sur $host';
  }

  @override
  String meLinkedOpenBody(String host) {
    return 'Cet espace se trouve sur $host. L\'application travaille avec un serveur à la fois : l\'ouvrir bascule vers ce serveur et vous demande de vous y connecter.';
  }

  @override
  String meLinkedPendingOn(String host) {
    return 'En attente de validation · $host';
  }

  @override
  String meLinkedUnavailable(String host) {
    return '$host n\'a pas répondu : cette liste peut être incomplète.';
  }

  @override
  String get meManageSpaces => 'Gérer mes espaces';

  @override
  String get meMySpaces => 'Mes espaces';

  @override
  String get meNoSpaceBody =>
      'Trouvez-en un près de chez vous, rejoignez-en un avec un code d\'invitation ou créez le vôtre.';

  @override
  String get meNoSpaceTitle => 'Vous n\'êtes encore dans aucun espace';

  @override
  String get meSectionMine => 'Mon historique et mes données';

  @override
  String get meSortAlphabet => 'A–Z';

  @override
  String get meSortHand => 'Mon ordre';

  @override
  String get meSortRating => 'Mieux notés';

  @override
  String get meSortRecent => 'Utilisés récemment';

  @override
  String get meSortTooltip => 'Trier';

  @override
  String get meSpaceException => 'Dans cet espace';

  @override
  String get meSpaceLastUsed => 'Dernier utilisé';

  @override
  String get meSpaceOpen => 'Ouvrir';

  @override
  String get meSpacePending => 'En attente de validation';

  @override
  String get meSpacesNoMatch => 'Aucun espace ne correspond.';

  @override
  String get meSpacesSearch => 'Rechercher mes espaces';

  @override
  String get meTabDiscover => 'Découvrir';

  @override
  String get meTabHome => 'Accueil';

  @override
  String get meTabMe => 'Moi';

  @override
  String get meTabMessages => 'Messages';

  @override
  String get meWhereSpacesLive => 'Où vivent mes espaces';

  @override
  String get memberAccountTitle => 'Mon compte';

  @override
  String get memberAllAdmins => 'tous les admins';

  @override
  String get memberApprove => 'Approuver l\'adhésion';

  @override
  String memberBadgesTitle(String name) {
    return 'Badges — $name';
  }

  @override
  String get memberBadgesTooltip => 'Badges';

  @override
  String get memberCoOwnerChip => 'Copropriétaire';

  @override
  String get memberCoOwnerPassiveChip => 'Successeur';

  @override
  String get memberContactHeading => 'Contact';

  @override
  String get memberHomeSiteDefault => 'Adresse de l\'espace';

  @override
  String get memberHomeSiteLabel => 'Site de rattachement';

  @override
  String memberInvoiceOpen(String amount) {
    return '$amount dus';
  }

  @override
  String get memberInvoicePaid => 'Payée';

  @override
  String get memberInvoiceVoided => 'Annulée';

  @override
  String get memberInvoicesBanner =>
      'Toutes vos factures et paiements, de tous vos espaces, sont dans Moi › Finances.';

  @override
  String get memberKioskLabel => 'Borne';

  @override
  String get memberMakeAdmin => 'Attribuer le rôle Administrateur·rice';

  @override
  String get memberMakeKiosk => 'Transformer en borne';

  @override
  String get memberMakeMember => 'Retirer le rôle Administrateur·rice';

  @override
  String get memberMessagesAction => 'Messages';

  @override
  String get memberMoneySettled => 'Rien en attente.';

  @override
  String get memberMoneyUnavailable =>
      'Impossible de charger les finances. Tirez pour actualiser.';

  @override
  String get memberMonthInProgress => 'Ce mois-ci';

  @override
  String memberMoreInvoices(int count) {
    return '+$count autres';
  }

  @override
  String get memberNoActions =>
      'Seul le propriétaire de l\'espace peut modifier ce membre.';

  @override
  String get memberNoSubscription => 'Sans abonnement';

  @override
  String get memberNoSubscriptionPaygHint =>
      'Sans abonnement n\'est pas possible avec le paiement à l\'usage : choisissez d\'abord bloquer ou un forfait.';

  @override
  String get memberNoteDelete => 'Supprimer';

  @override
  String get memberNoteDeleteConfirm =>
      'Supprimer ce message ? Cette action est irréversible.';

  @override
  String get memberNoteDeleteNotMine =>
      'Seul l\'expéditeur peut reprendre un message.';

  @override
  String get memberNoteDeleteRead =>
      'Déjà lu — ce message ne peut plus être repris.';

  @override
  String get memberNoteDeleted => 'Message supprimé.';

  @override
  String get memberNoteHint => 'Votre message';

  @override
  String memberNoteReceived(String name) {
    return 'Message de $name';
  }

  @override
  String get memberNoteReply => 'Répondre';

  @override
  String get memberNoteSend => 'Envoyer';

  @override
  String get memberNoteSent => 'Notification envoyée.';

  @override
  String memberNoteTitle(String name) {
    return 'Notifier $name';
  }

  @override
  String memberNoteTo(String name) {
    return 'À $name';
  }

  @override
  String get memberNoteToAllAdmins => 'À tous les admins';

  @override
  String get memberNotifyAction => 'Envoyer une notification';

  @override
  String get memberNotifyAllAdmins => 'Notifier tous les admins';

  @override
  String get memberNumberLabel => 'N° adhérent';

  @override
  String get memberOriginDelegated => 'Profil créé par un administrateur';

  @override
  String get memberOriginFounder => 'A fondé cet espace';

  @override
  String get memberOriginHeading => 'Comment cette adhésion a commencé';

  @override
  String get memberOriginInvited => 'A rejoint sur invitation';

  @override
  String get memberOveragePolicyLabel => 'Quand les jours sont épuisés';

  @override
  String get memberOveragePolicyTooltip => 'Dépassement';

  @override
  String get memberPageAddService => 'Ajouter un service';

  @override
  String memberPageCheckedIn(String seat, String time) {
    return 'Pointé · $seat · depuis $time';
  }

  @override
  String get memberPageEmailAction => 'E-mail';

  @override
  String get memberPageGroupAccess => 'Badges et accès';

  @override
  String get memberPageGroupBilling => 'Facturation';

  @override
  String get memberPageGroupBooking => 'Règles de réservation';

  @override
  String get memberPageGroupMembership => 'Adhésion';

  @override
  String get memberPageLevelTitle => 'Réservations d\'un espace entier';

  @override
  String get memberPageManageHeading => 'Gérer';

  @override
  String get memberPageNeverSeen => 'Jamais vu';

  @override
  String memberPageNext(String label) {
    return 'Prochaine : $label';
  }

  @override
  String get memberPageNone => 'Aucun';

  @override
  String get memberPageNowHeading => 'En ce moment';

  @override
  String memberPageReservedNow(String seat, String time) {
    return 'Réservé maintenant · $seat · jusqu\'à $time';
  }

  @override
  String memberPageSince(String date) {
    return 'Membre depuis le $date';
  }

  @override
  String get memberPageStatusActive => 'Actif';

  @override
  String memberPageWorkspaceDefaultValue(int count) {
    return 'Défaut de l\'espace ($count)';
  }

  @override
  String memberPageYou(String name) {
    return '$name (vous)';
  }

  @override
  String get memberPause => 'Mettre l\'adhésion en pause';

  @override
  String get memberPayments => 'Paiements';

  @override
  String memberPlanShare(String pct) {
    return 'Forfait $pct %';
  }

  @override
  String get memberReactivate => 'Réactiver l\'adhésion';

  @override
  String get memberRejectJoin => 'Refuser l\'adhésion';

  @override
  String memberReservationLimitChip(int n) {
    return 'max $n';
  }

  @override
  String get memberReservationLimitCustom => 'Personnalisé (1–100)';

  @override
  String get memberReservationLimitExplainer =>
      'Combien de réservations ouvertes ce membre peut détenir en même temps.';

  @override
  String get memberReservationLimitLabel => 'Limite de réservations';

  @override
  String get memberReservationLimitNone => 'Sans limite';

  @override
  String get memberReservationLimitTooltip => 'Limite de réservations';

  @override
  String get memberRoleAdmin => 'Administrateur·rice';

  @override
  String get memberRoleChangeRequested =>
      'Changement de rôle envoyé pour validation.';

  @override
  String get memberRoleMember => 'Membre';

  @override
  String get memberRoleOwner => 'Propriétaire';

  @override
  String get memberRolesAdd => 'Ajouter un rôle';

  @override
  String get memberRolesNone =>
      'Aucun rôle : tout ce que peut faire un membre.';

  @override
  String get memberRolesTitle => 'Rôles';

  @override
  String get memberRolesWhatTheyCanDo => 'Ce que cette personne peut faire ici';

  @override
  String get memberSendAgreement => 'Envoyer l\'accord financier';

  @override
  String memberSimultaneousLimitChip(int n) {
    return '$n à la fois';
  }

  @override
  String get memberSimultaneousLimitDefault => 'Réglage de l\'espace';

  @override
  String get memberSimultaneousLimitExplainer =>
      'Combien de réservations ce membre peut détenir sur une même période. Non défini : le réglage de l\'espace s\'applique.';

  @override
  String get memberSimultaneousLimitLabel => 'Réservations simultanées';

  @override
  String get memberStatusActive => 'Actif';

  @override
  String get memberStatusExited => 'Parti';

  @override
  String get memberStatusPaused => 'En pause';

  @override
  String get memberStatusPending => 'En attente';

  @override
  String get memberSubscriptionCustom => 'Personnalisé (1–100)';

  @override
  String get memberSubscriptionLabel => 'Abonnement';

  @override
  String get memberUnmakeKiosk => 'Rétablir comme membre';

  @override
  String get memberVatTreatmentExplainer =>
      'Qui est ce membre pour la TVA : la règle automatique (autoliquidation pour une entreprise d\'un autre État de l\'UE), la TVA nationale quoi qu\'il arrive, l\'autoliquidation, hors UE, ou un acheteur exonéré avec le motif imprimé sur la facture.';

  @override
  String get memberVatTreatmentLabel => 'Traitement TVA';

  @override
  String get membersInvite => 'Inviter un membre';

  @override
  String get membersPlanNone => 'Aucun forfait';

  @override
  String get membersTitle => 'Membres et forfaits';

  @override
  String get messageInfo => 'Infos du message';

  @override
  String get messageNotReadYet => 'Pas encore lu';

  @override
  String get messageReadBy => 'Lu par';

  @override
  String get messageRequestsHint =>
      'Ces personnes sont hors de celles par lesquelles vous avez choisi d\'être joignable. Elles ne sont pas informées de votre décision.';

  @override
  String get messageRequestsTitle => 'Demandes de message';

  @override
  String get messageSearchGroups => 'Groupes';

  @override
  String get messageSearchHint => 'Membres, groupes, messages';

  @override
  String get messageSearchMessages => 'Messages';

  @override
  String get messageSearchNothing => 'Aucun résultat.';

  @override
  String get messageSearchPeople => 'Membres';

  @override
  String get messageSearchPrompt =>
      'Recherchez des membres, des groupes et ce qui a été dit.';

  @override
  String get messageSearchTitle => 'Rechercher';

  @override
  String get messagesEmpty => 'Aucune conversation.';

  @override
  String get messagesTitle => 'Messages';

  @override
  String get messengerContextAccount => 'De personne à personne';

  @override
  String get messengerContextGroup => 'Groupe';

  @override
  String messengerContextInquiryIn(String space) {
    return 'Demande à $space';
  }

  @override
  String messengerContextInquiryOut(String space) {
    return 'Votre demande à $space';
  }

  @override
  String messengerContextSpace(String space) {
    return 'Dans $space';
  }

  @override
  String get messengerCopied => 'Copié.';

  @override
  String get messengerCopy => 'Copier le texte';

  @override
  String get messengerDelete => 'Supprimer le message';

  @override
  String get messengerDeleteConfirm =>
      'Supprimer ce message pour tous les participants de la conversation ?';

  @override
  String get messengerDeleted => 'Message supprimé.';

  @override
  String get messengerDelivered => 'Distribué';

  @override
  String get messengerEdit => 'Modifier';

  @override
  String get messengerEditFailed =>
      'Ce message n’a pas pu être modifié — les 15 minutes sont peut-être écoulées.';

  @override
  String get messengerEditTitle => 'Modifier le message';

  @override
  String get messengerEditWindow =>
      'Un message peut être corrigé pendant 15 minutes après son envoi.';

  @override
  String get messengerEdited => 'modifié';

  @override
  String messengerEventCaptured(String actor) {
    return 'Capture d’écran par $actor';
  }

  @override
  String messengerEventDeleted(String actor) {
    return 'Supprimé par $actor';
  }

  @override
  String messengerEventForwarded(String actor, String target) {
    return 'Transféré par $actor vers $target';
  }

  @override
  String messengerEventForwardedFrom(String actor, String context) {
    return 'Écrit à l’origine par $actor dans $context';
  }

  @override
  String messengerEventForwardedPrivate(String actor) {
    return 'Transféré par $actor vers une conversation personnelle';
  }

  @override
  String messengerEventOther(String event, String actor) {
    return '$event · $actor';
  }

  @override
  String messengerEventRead(String actor) {
    return 'Lu par $actor';
  }

  @override
  String messengerEventSent(String actor) {
    return 'Envoyé par $actor';
  }

  @override
  String get messengerForward => 'Transférer';

  @override
  String get messengerForwardExplain =>
      'Tous les participants de la conversation d’origine, l’auteur en premier, sont informés de qui l’a transféré, quand et où.';

  @override
  String get messengerForwardLocked =>
      'L’auteur a verrouillé ce message contre le transfert.';

  @override
  String get messengerForwardNoTargets =>
      'Aucune autre conversation sur ce serveur vers laquelle transférer.';

  @override
  String get messengerForwardTitle => 'Transférer vers';

  @override
  String messengerForwarded(String target) {
    return 'Transféré vers $target.';
  }

  @override
  String messengerForwardedFrom(String context, String author) {
    return 'Transféré depuis $context · écrit par $author';
  }

  @override
  String get messengerHistory => 'Ce qui s’est passé';

  @override
  String get messengerHistoryEmpty =>
      'Rien n’est encore enregistré pour ce message.';

  @override
  String get messengerHostsIntro =>
      'Votre message est lu par ces hôtes de l’espace :';

  @override
  String get messengerHostsNone =>
      'Personne ne répond aux messages de cet espace pour le moment.';

  @override
  String messengerInboxUnavailable(String servers) {
    return 'Injoignable pour le moment : $servers. Leurs conversations manquent dans cette liste.';
  }

  @override
  String get messengerInquiriesEmpty => 'Aucune demande pour l’instant.';

  @override
  String get messengerInquiriesTitle => 'Demandes';

  @override
  String get messengerInquiryClose => 'Clore la demande';

  @override
  String get messengerInquiryClosed => 'Demande close.';

  @override
  String messengerInquiryFrom(String name) {
    return 'De $name';
  }

  @override
  String get messengerInquirySend => 'Envoyer la demande';

  @override
  String get messengerLock => 'Interdire le transfert';

  @override
  String get messengerMessageActions => 'Actions sur le message';

  @override
  String get messengerNoStarred => 'Aucun message en favori.';

  @override
  String messengerNoticeCaptured(String actor) {
    return '$actor a pris une capture d’écran de cette conversation.';
  }

  @override
  String messengerNoticeForwarded(String actor, String target) {
    return '$actor a transféré un message de cette conversation vers $target.';
  }

  @override
  String messengerNoticeForwardedPrivate(String actor) {
    return '$actor a transféré un message de cette conversation vers une conversation personnelle.';
  }

  @override
  String messengerOnServer(String server) {
    return 'sur $server';
  }

  @override
  String get messengerRead => 'Lu';

  @override
  String get messengerRefusedClosed => 'Cette demande est close.';

  @override
  String get messengerRefusedForwardingOff =>
      'Cet espace n’autorise pas le transfert de ses messages.';

  @override
  String get messengerRefusedLimit =>
      'Trop d’un coup. Veuillez patienter une minute.';

  @override
  String get messengerRefusedRequestPending =>
      'Votre premier message attend une réponse.';

  @override
  String get messengerRefusedTooLong =>
      'Ce message est trop long pour cette conversation.';

  @override
  String get messengerRefusedUnavailable =>
      'Cet espace n’accepte pas de demandes pour le moment.';

  @override
  String get messengerStar => 'Mettre en favori';

  @override
  String get messengerStarred => 'Favoris';

  @override
  String get messengerUnlock => 'Autoriser le transfert';

  @override
  String get messengerUnstar => 'Retirer des favoris';

  @override
  String get messengerWriteToHosts => 'Écrire aux hôtes';

  @override
  String get mfaCode => 'Code à six chiffres';

  @override
  String get mfaEnroll =>
      'Scannez ce code avec une application d\'authentification, ou saisissez la clé, puis tapez les six chiffres affichés.';

  @override
  String get mfaTitle => 'Confirmez avec votre application d\'authentification';

  @override
  String get mfaVerify => 'Vérifier';

  @override
  String get mfaWrong =>
      'Ce code n\'a pas été accepté. Essayez le code actuel.';

  @override
  String get moneyAmountLabel => 'Montant';

  @override
  String get moneyBalance => 'Solde';

  @override
  String get moneyBaseFee => 'Abonnement de base';

  @override
  String get moneyCredits => 'Paiements et crédits';

  @override
  String get moneyDescriptionLabel => 'Description';

  @override
  String get moneyDocumentLibrary => 'Bibliothèque de documents';

  @override
  String moneyDueIn(int days) {
    return 'Échéance dans $days jours';
  }

  @override
  String get moneyExpenseCategoryLabel => 'Catégorie';

  @override
  String get moneyExpensePending =>
      'Dépense soumise — en attente d\'approbation.';

  @override
  String get moneyFaceDocuments => 'Documents';

  @override
  String get moneyFaceInvoices => 'Factures';

  @override
  String get moneyFacePayments => 'Paiements';

  @override
  String get moneyFaceStatement => 'Relevé';

  @override
  String get moneyFaceUsage => 'Usage';

  @override
  String get moneyLedgerEmpty => 'Aucune écriture pour l\'instant.';

  @override
  String get moneyLedgerHeader => 'Grand livre';

  @override
  String get moneyMyAgreement => 'Mes conditions';

  @override
  String get moneyNoInvoicesYet =>
      'Pas encore de facture — l\'espace facture le mois une fois clos.';

  @override
  String get moneyNoteLabel => 'Note (facultatif)';

  @override
  String get moneyNothingOpen => 'Rien d\'ouvert — vous êtes à jour.';

  @override
  String moneyOpenInvoicesSummary(int count, String amount) {
    return '$count ouvertes · $amount dus';
  }

  @override
  String get moneyOpenInvoicesTitle => 'Factures ouvertes';

  @override
  String moneyOverage(int count) {
    return 'Dépassement ($count demi-journées supplémentaires)';
  }

  @override
  String moneyOverdueBanner(int count, String amount) {
    return '$count en retard — $amount à régler';
  }

  @override
  String moneyOverdueBy(int days) {
    return 'En retard de $days jours';
  }

  @override
  String get moneyPayNow => 'Payer maintenant';

  @override
  String get moneyPaymentDateLabel => 'Date du paiement';

  @override
  String get moneyPaymentPending =>
      'Paiement soumis — en attente de confirmation.';

  @override
  String get moneyPaymentPeriodLabel => 'S’applique à';

  @override
  String get moneyRecordPayment => 'Enregistrer un paiement';

  @override
  String moneyRemindedTimes(int count) {
    return 'Relancée ×$count';
  }

  @override
  String get moneySectionDocuments => 'Documents';

  @override
  String get moneySectionPay => 'Payer';

  @override
  String get moneySectionRequests => 'Demandes';

  @override
  String get moneyStatementOpen => 'À régler';

  @override
  String get moneyStatementPdf => 'Relevé du mois (PDF)';

  @override
  String get moneyStatementSettled => 'Réglé';

  @override
  String get moneySubmitExpense => 'Soumettre une dépense';

  @override
  String get moneySubmitPayment => 'Soumettre pour confirmation';

  @override
  String moneySubscriptionPct(int pct) {
    return 'Abonnement $pct %';
  }

  @override
  String moneyUsage(int used, int included) {
    return '$used demi-journées utilisées sur $included';
  }

  @override
  String moneyUsageUnlimited(int used) {
    return '$used demi-journées utilisées';
  }

  @override
  String monthFreeCount(int free, int total) {
    return '$free/$total';
  }

  @override
  String get myBadgeTitle => 'Mon badge';

  @override
  String get myInvoicesTitle => 'Mes factures';

  @override
  String get myVisitsHelp =>
      'Les visites que vous avez demandées ou auxquelles vous avez été admis, en tant qu\'invité. Une visite n\'est pas une adhésion.';

  @override
  String get myVisitsTitle => 'Mes visites';

  @override
  String get navigationClassic =>
      'Classique : la barre du bas et le bouton rond';

  @override
  String get navigationDefault => 'Par défaut pour cet appareil';

  @override
  String get navigationMenu => 'Menu : le hamburger, comme sur le web';

  @override
  String get navigationTitle => 'Navigation';

  @override
  String negotiationActiveSince(String month) {
    return 'Vos conditions s\'appliquent depuis $month.';
  }

  @override
  String get negotiationCardTitle => 'Mes conditions négociées';

  @override
  String get negotiationDefaultColumn => 'Tarif';

  @override
  String get negotiationDiscount => 'Remise sur les suppléments';

  @override
  String get negotiationFee => 'Abonnement mensuel';

  @override
  String get negotiationItems => 'Services et forfaits';

  @override
  String get negotiationItemsHint =>
      'Un prix unitaire pour ce membre ; vide garde le catalogue.';

  @override
  String get negotiationKeepCurrent => 'Garder l\'actuelle';

  @override
  String get negotiationMineColumn => 'Les miennes';

  @override
  String get negotiationNote => 'Note';

  @override
  String get negotiationOccupation => 'Occupation';

  @override
  String get negotiationOccupationHint =>
      'La part des jours d\'ouverture incluse chaque mois ; appliquée au membre une fois validée.';

  @override
  String get negotiationOnTariff => 'Vous êtes au tarif de l\'espace.';

  @override
  String get negotiationOverage => 'Dépassement par demi-journée';

  @override
  String get negotiationPending => 'Des conditions attendent validation.';

  @override
  String get negotiationPendingBadge => 'en attente de validation';

  @override
  String negotiationPercent(int value) {
    return '$value %';
  }

  @override
  String get negotiationProposeHint =>
      'Laissez un champ vide pour garder le tarif. Les conditions passent par la validation avant de s\'appliquer.';

  @override
  String get negotiationProposeTitle => 'Négociation tarifaire';

  @override
  String get negotiationProposed =>
      'Conditions proposées — en attente de validation.';

  @override
  String get negotiationReadOnly => 'Lecture seule';

  @override
  String get negotiationSubmit => 'Proposer pour validation';

  @override
  String get negotiationValidFrom => 'Applicable dès';

  @override
  String get negotiationWhoCanSee => 'Qui peut voir';

  @override
  String get newConversationGroupSwitch => 'Groupe';

  @override
  String get newConversationNoMembers => 'Personne d’autre ici pour l’instant.';

  @override
  String get newConversationSearch => 'Rechercher un membre';

  @override
  String get newConversationStart => 'Démarrer';

  @override
  String get newConversationTapToOpen =>
      'Touchez une personne pour ouvrir la discussion ; activez Groupe pour en choisir plusieurs.';

  @override
  String get newConversationTitle => 'Nouvelle conversation';

  @override
  String get newGroupCreate => 'Créer le groupe';

  @override
  String get newGroupName => 'Nom du groupe';

  @override
  String get newGroupNameTaken =>
      'Un groupe porte déjà ce nom ici. Choisissez-en un autre.';

  @override
  String get newMemberDefaultsConfigured =>
      'Ce avec quoi commence une personne qui rejoint l\'espace.';

  @override
  String get newMemberDefaultsTitle => 'Nouveaux membres';

  @override
  String get newMemberDefaultsUnavailable =>
      'Impossible de les lire pour l\'instant. L\'enregistrement les laisse telles quelles.';

  @override
  String get newMemberDefaultsUnset =>
      'Rien de choisi — les nouveaux membres commencent à 100 % et les réservations sont bloquées une fois le forfait épuisé.';

  @override
  String get newMemberOverageBlocked => 'Bloqué une fois épuisé';

  @override
  String get newMemberOveragePackage => 'Doit acheter un forfait';

  @override
  String get newMemberOveragePayg => 'Paiement à l\'usage';

  @override
  String get newMemberSubscription => 'Abonnement';

  @override
  String get newMemberSubscriptionLess => 'Abonnement plus petit';

  @override
  String get newMemberSubscriptionMore => 'Abonnement plus grand';

  @override
  String newMemberSubscriptionValue(int percent) {
    return '$percent %';
  }

  @override
  String get nfcConfigChecking => 'Vérification…';

  @override
  String get nfcConfigDeviceOff =>
      'Le NFC est désactivé dans les paramètres Android de cet appareil — activez-le pour lire les cartes RFID.';

  @override
  String get nfcConfigDeviceReady => 'NFC disponible et activé';

  @override
  String get nfcConfigDeviceStatus => 'Cet appareil';

  @override
  String get nfcConfigDeviceUnavailable =>
      'Pas de NFC ici — un appareil Android avec NFC activé est nécessaire (les iPad n\'ont pas de NFC). Les badges QR fonctionnent toujours.';

  @override
  String get nfcConfigEnable => 'Activer le pointage par badge NFC';

  @override
  String get nfcConfigEnableDesc =>
      'Afficher l\'option « approcher la carte » sur les bornes et dans le gestionnaire de badges.';

  @override
  String get nfcConfigIntro =>
      'Les membres pointent à une borne murale en approchant une carte RFID/NFC. Enregistrez la carte de chaque membre dans Membres & forfaits ; à la borne, ils approchent la carte pour réserver ou pointer.';

  @override
  String get nfcConfigTitle => 'Badges RFID / NFC';

  @override
  String get noteRefAlert => 'Alerte';

  @override
  String noteRefFilterCount(int shown, int total) {
    return '$shown sur $total';
  }

  @override
  String get noteRefFilterEmpty => 'Aucun résultat.';

  @override
  String get noteRefFilterLabel => 'Filtrer';

  @override
  String get noteRefGone => 'Cette réservation n\'existe plus.';

  @override
  String get noteRefInvoice => 'Facture';

  @override
  String get noteRefNoReservations => 'Aucune réservation à venir à lier.';

  @override
  String get noteRefNone => 'Rien à référencer pour le moment.';

  @override
  String get noteRefPayment => 'Paiement';

  @override
  String get noteRefPickAlert => 'Quelle alerte ?';

  @override
  String get noteRefPickInvoice => 'Quelle facture ?';

  @override
  String get noteRefPickPayment => 'Quel paiement ?';

  @override
  String get noteRefPickValidation => 'Quelle validation ?';

  @override
  String get noteRefRefund => 'Remboursement';

  @override
  String get noteRefReservation => 'Lier une réservation';

  @override
  String get noteRefSpace => 'Lier un espace';

  @override
  String get noteRefValidation => 'Validation';

  @override
  String get noteRefWholeLevel => 'niveau entier';

  @override
  String get notesFilterEmpty => 'Aucun message non lu — vous êtes à jour.';

  @override
  String get notesFilterRead => 'Lus';

  @override
  String get notesFilterUnread => 'Non lus';

  @override
  String get notifCategoryCheckIns => 'Check-ins';

  @override
  String get notifCategoryMembers => 'Membres';

  @override
  String get notifCategoryMoney => 'Finances';

  @override
  String get notifGroupBy => 'Grouper par';

  @override
  String get notifGroupByDate => 'Date';

  @override
  String get notifGroupByType => 'Type';

  @override
  String get notifGroupByUser => 'Membre';

  @override
  String get notifSortByDate => 'Trier par date';

  @override
  String get notifUngroup => 'Dégrouper';

  @override
  String get notificationsSystemOff =>
      'Android bloque les notifications de DesKilo';

  @override
  String get notificationsSystemOffHint =>
      'Autorisez-les dans Paramètres système → Applications → DesKilo → Notifications — le badge de l\'icône en a besoin.';

  @override
  String get numberSequenceDateNone => 'Aucune';

  @override
  String get numberSequenceDatePart => 'Date';

  @override
  String get numberSequenceDateRemovalBlocked =>
      'Des numéros ont déjà été attribués avec la date. La retirer pourrait en répéter un — changez aussi le préfixe ou le suffixe.';

  @override
  String get numberSequenceDateYear => 'Année';

  @override
  String get numberSequenceDateYearMonth => 'Année-mois';

  @override
  String get numberSequenceDigits => 'Chiffres';

  @override
  String get numberSequenceGapless => 'Sans trou — garanti';

  @override
  String get numberSequenceJournalCreditNote => 'Avoirs';

  @override
  String get numberSequenceJournalInvoice => 'Factures';

  @override
  String get numberSequenceJournalMember => 'Adhérents';

  @override
  String get numberSequenceJournalPayment => 'Paiements';

  @override
  String get numberSequenceJournalVatDeclaration => 'Déclarations de TVA';

  @override
  String get numberSequenceNext => 'Prochain numéro';

  @override
  String get numberSequencePrefix => 'Préfixe';

  @override
  String get numberSequenceReset => 'Remise à zéro';

  @override
  String get numberSequenceResetLimited =>
      'Un numéro ne recommence pas plus souvent qu’il n’affiche sa date — sinon il réimprimerait un numéro déjà attribué.';

  @override
  String get numberSequenceResetMonthly => 'Chaque mois';

  @override
  String get numberSequenceResetNever => 'Jamais';

  @override
  String get numberSequenceResetWasInvalid =>
      'Cette série recommençait plus souvent qu’elle n’affiche sa date. Enregistrez pour garder une remise à zéro qui ne répète aucun numéro.';

  @override
  String get numberSequenceResetYearly => 'Chaque année';

  @override
  String get numberSequenceSaved => 'Séquence enregistrée.';

  @override
  String get numberSequenceSuffix => 'Suffixe';

  @override
  String get numberSequencesIntro =>
      'Une série par journal, sans trou : le numéro est pris dans la base au moment où le document est émis, et un document qui n\'aboutit pas ne consomme rien. Modifier le format ne change jamais un document déjà émis.';

  @override
  String get numberSequencesSubtitle =>
      'Comment factures et avoirs sont numérotés.';

  @override
  String get numberSequencesTitle => 'Séquences de numérotation';

  @override
  String get occurrenceAdded => 'Ajouté à vos dépenses.';

  @override
  String get occurrenceConfirm => 'Confirmer cette dépense';

  @override
  String get occurrenceReasonLabel => 'Pourquoi ça diffère (obligatoire)';

  @override
  String get occurrenceReasonMissing =>
      'Un montant différent doit être expliqué.';

  @override
  String get occurrenceRejected =>
      'Les validateurs l’ont rejetée — ajustez le montant ou la description et renvoyez.';

  @override
  String get occurrenceResend => 'Renvoyer en validation';

  @override
  String occurrenceScheduledAmount(Object amount) {
    return 'Validé : $amount';
  }

  @override
  String get occurrenceSentForValidation =>
      'Envoyé aux validateurs — ça comptera une fois confirmé.';

  @override
  String get officeSupplementLabel => 'Réservations de bureau';

  @override
  String get onboardingConfirmIntro => 'Voici ce qui sera créé :';

  @override
  String get onboardingCreateButton => 'Créer l\'espace';

  @override
  String get onboardingCreateTab => 'Créer un espace';

  @override
  String get onboardingCreateWithoutTemplate => 'Créer sans modèle';

  @override
  String get onboardingCurrencyUnknown =>
      'Saisissez un code de devise pris en charge, par exemple EUR';

  @override
  String get onboardingDiscardDraft =>
      'Votre saisie sera perdue. Cela n’annule pas une demande déjà envoyée.';

  @override
  String get onboardingIntentChanged =>
      'Votre demande précédente a peut-être déjà été créée. Relancez-la telle qu\'elle a été envoyée avant de modifier quoi que ce soit.';

  @override
  String get onboardingIntentResumed =>
      'Une création précédente a peut-être abouti. Relancez pour vérifier la même demande.';

  @override
  String get onboardingJoinButton => 'Rejoindre';

  @override
  String get onboardingJoinTab => 'Rejoindre un espace';

  @override
  String get onboardingRetryAsSent => 'Relancer telle quelle';

  @override
  String get onboardingScanButton => 'Scanner un QR code';

  @override
  String get onboardingShapeLabel => 'Que créer';

  @override
  String get onboardingShapePair => 'Une paire liée test et réel';

  @override
  String get onboardingShapeReal => 'Un espace réel';

  @override
  String get onboardingShapeRealHint =>
      'Pour l\'exploitation réelle : les factures émises sont dues.';

  @override
  String get onboardingShapeTest => 'Un espace de test';

  @override
  String get onboardingShapeTestHint =>
      'Idéal pour essayer : chaque écran et chaque document indique qu\'il s\'agit d\'un test. Aucune facturation réelle.';

  @override
  String get onboardingStartEmpty => 'Espace vide';

  @override
  String get onboardingStartEmptyDesc =>
      'Dessinez votre propre plan sur une toile vierge.';

  @override
  String get onboardingStartFrom => 'Partir de';

  @override
  String get onboardingStepConfirm => 'Confirmer';

  @override
  String get onboardingStepName => 'Nom';

  @override
  String get onboardingStepWhere => 'Où';

  @override
  String get onboardingSummaryBillingOff =>
      'Aucune facturation réelle : les documents sont marqués comme test.';

  @override
  String get onboardingSummaryBillingOn =>
      'La facturation réelle est possible : ses factures sont dues.';

  @override
  String onboardingSummaryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Crée $count espaces',
      one: 'Crée un espace',
    );
    return '$_temp0';
  }

  @override
  String onboardingSummaryServer(String host) {
    return 'Sur le serveur $host';
  }

  @override
  String onboardingTemplateSetsUp(String groups) {
    return 'Configure : $groups';
  }

  @override
  String get onboardingTemplatesFailedEmpty =>
      'Les modèles n’ont pas pu être chargés : cet espace démarrerait vide. Revenez en arrière pour réessayer.';

  @override
  String get onboardingTitle => 'Bienvenue sur DesKilo';

  @override
  String get onboardingUnconfirmed =>
      'Le résultat n’a pas pu être confirmé. Votre saisie est conservée. Réessayez pour vérifier la même demande.';

  @override
  String get onboardingUseSuggested => 'Utiliser les réglages proposés';

  @override
  String get onboardingWithTwin => 'Créer la paire développement et production';

  @override
  String get onboardingWithTwinHint =>
      'Deux espaces du même nom : un pour essayer, un qui est réel. Vous possédez les deux.';

  @override
  String get overagePolicyBlocked => 'Bloquer toute réservation';

  @override
  String get overagePolicyPackage => 'Exiger l\'achat d\'un forfait';

  @override
  String get overagePolicyPayg => 'Facturer le dépassement (à l\'usage)';

  @override
  String get payConfigConfigured => 'Configuré';

  @override
  String get payConfigIntro =>
      'Saisissez chaque prestataire de paiement à proposer. Les clés sont stockées en sécurité sur le serveur et ne sont plus affichées.';

  @override
  String get payConfigNotConfigured => 'Non configuré';

  @override
  String get payConfigOpen => 'Configurer';

  @override
  String get payConfigRemove => 'Supprimer';

  @override
  String get payConfigRemoved => 'Supprimé.';

  @override
  String get payConfigSaved => 'Enregistré.';

  @override
  String get payConfigSecretSet => 'Défini — laisser vide pour conserver';

  @override
  String get payConfigTitle => 'Paiements en ligne';

  @override
  String get payFieldApiKey => 'Clé API';

  @override
  String get payFieldClientId => 'Client ID';

  @override
  String get payFieldEnv => 'Environnement';

  @override
  String get payFieldReturnUrl => 'URL de retour';

  @override
  String get payFieldSecret => 'Secret';

  @override
  String get payFieldSecretKey => 'Clé secrète';

  @override
  String get payFieldWebhookId => 'ID du webhook';

  @override
  String get payFieldWebhookSecret => 'Secret de signature du webhook';

  @override
  String get payOnlineButton => 'Payer en ligne';

  @override
  String get payOnlineChooseTitle => 'Payer en ligne';

  @override
  String get payOnlineDiagHint =>
      'Il manque cette configuration côté serveur :';

  @override
  String get payOnlineDiagTitle => 'Paiements en ligne — non configurés';

  @override
  String payOnlineFailedDetail(
    String reference,
    String amount,
    String provider,
  ) {
    return 'Le paiement $reference ($amount via $provider) n\'a pas abouti — rien n\'a été crédité ; le solde reste dû.';
  }

  @override
  String get payOnlineFailedTitle => 'Paiement en ligne échoué';

  @override
  String get payOnlineNotConfigured =>
      'Les paiements en ligne ne sont pas encore configurés. Demandez au propriétaire de l\'espace.';

  @override
  String payOnlinePendingDetail(
    String reference,
    String amount,
    String provider,
  ) {
    return 'Le paiement $reference ($amount via $provider) n\'a pas encore été confirmé par le prestataire : le solde affiche donc toujours ce qui est dû. Citez cette référence s\'il n\'aboutit pas.';
  }

  @override
  String get payOnlinePendingTitle => 'Paiement en ligne en attente';

  @override
  String get paymentAccountNumberLabel => 'Numéro de compte';

  @override
  String get paymentBankCodeLabel => 'Code banque';

  @override
  String get paymentBankNameLabel => 'Nom de la banque';

  @override
  String get paymentBicLabel => 'BIC / SWIFT';

  @override
  String get paymentCopied => 'Copié.';

  @override
  String get paymentInstructionsHelper =>
      'Affichées aux membres sur un relevé impayé. Laisser vide pour ne rien afficher.';

  @override
  String get paymentInstructionsIbanCopied => 'IBAN copié.';

  @override
  String get paymentInstructionsIbanTitle => 'IBAN';

  @override
  String get paymentInstructionsLydiaLabel =>
      'Numéro de téléphone ou identifiant Lydia';

  @override
  String get paymentInstructionsPaypalLabel => 'Lien ou identifiant PayPal.me';

  @override
  String get paymentInstructionsReferenceLabel =>
      'Indication de référence de paiement';

  @override
  String get paymentInstructionsTitle => 'Instructions de paiement';

  @override
  String get paymentInstructionsValueCopied => 'Copié dans le presse-papiers.';

  @override
  String get paymentInstructionsWeroLabel => 'Numéro de téléphone Wero';

  @override
  String get paymentInstructionsWiseLabel => 'Wisetag ou lien de paiement Wise';

  @override
  String get paymentMethodBankTransfer => 'Virement';

  @override
  String get paymentMethodCard => 'Carte';

  @override
  String get paymentMethodCash => 'Espèces';

  @override
  String get paymentMethodLydia => 'Lydia';

  @override
  String get paymentMethodOther => 'Autre';

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
      'IBAN, PayPal, Wero, Lydia, Wise et la référence de paiement';

  @override
  String get paymentProviderMollie => 'Mollie — iDEAL, Bancontact…';

  @override
  String get paymentProviderStripe => 'Carte bancaire (Stripe)';

  @override
  String get paymentProviderWero => 'Wero (via Mollie)';

  @override
  String get paymentRoutingNumberLabel => 'Routing number';

  @override
  String get paymentSortCodeLabel => 'Sort code';

  @override
  String get paymentTermsEdit => 'Demander un changement';

  @override
  String get paymentTermsFieldEscompte => 'Escompte';

  @override
  String get paymentTermsFieldLatePenalty => 'Pénalités de retard';

  @override
  String get paymentTermsFieldRecovery => 'Indemnité de recouvrement';

  @override
  String get paymentTermsFieldTerms => 'Conditions de paiement';

  @override
  String get paymentTermsInherit => 'celles de l\'espace par défaut';

  @override
  String get paymentTermsInherited => 'Par défaut de l\'espace';

  @override
  String get paymentTermsMemberNote =>
      'Ces conditions sont fixées par l\'espace ; un changement passe par sa validation.';

  @override
  String get paymentTermsNone => 'Aucune condition rédigée';

  @override
  String get paymentTermsOverridden => 'Propres au membre';

  @override
  String get paymentTermsReason => 'Motif (facultatif)';

  @override
  String get paymentTermsRequestHint =>
      'Laissez un champ vide pour garder la formulation de l\'espace. Le changement s\'applique une fois validé.';

  @override
  String get paymentTermsRequestTitle =>
      'Demander un changement de conditions de paiement';

  @override
  String get paymentTermsRequested =>
      'Changement demandé — en attente de validation';

  @override
  String get paymentTermsSubmit => 'Envoyer la demande';

  @override
  String get paymentTermsTitle => 'Conditions de paiement';

  @override
  String get paymentTermsUseDefault =>
      'Reprendre les conditions par défaut de l\'espace';

  @override
  String get paymentTransitNumberLabel => 'Transit · institution';

  @override
  String get paymentsPendingTag => 'en attente de validation';

  @override
  String pendingApprovalBody(String workspace) {
    return 'Vous avez rejoint $workspace. Un administrateur doit approuver votre adhésion avant que vous puissiez utiliser l\'espace — vous aurez accès dès sa confirmation.';
  }

  @override
  String get pendingApprovalRefresh => 'Vérifier à nouveau';

  @override
  String get pendingApprovalTitle =>
      'Adhésion à l’espace en attente d’approbation';

  @override
  String get pendingAvailable =>
      'Pendant l’attente, vos autres espaces, votre compte et l’aide restent disponibles.';

  @override
  String get pendingHelp => 'Aide';

  @override
  String pendingLastChecked(String time) {
    return 'Dernière vérification $time';
  }

  @override
  String get pendingNotUpdated =>
      'Statut non mis à jour — le serveur est injoignable. Votre demande reste inchangée.';

  @override
  String get pendingStillWaiting => 'Toujours en attente d’approbation.';

  @override
  String get pendingSwitchWorkspace => 'Changer d’espace';

  @override
  String percentValue(int value) {
    return '$value %';
  }

  @override
  String get permAccessProd => 'Entrer dans l\'espace de production';

  @override
  String get permApproveExpenses => 'Approuver les dépenses';

  @override
  String get permDeployToDev => 'Déployer en développement';

  @override
  String get permDeployToProd => 'Déployer en production';

  @override
  String get permDesignDocuments => 'Concevoir les documents';

  @override
  String get permExportData => 'Exporter la comptabilité et les données';

  @override
  String get permIssueInvoices =>
      'Émettre les factures et rapprocher les paiements';

  @override
  String get permMakeReservations => 'Réserver et utiliser les réservations';

  @override
  String get permManageBilling => 'Gérer les tarifs et règles de facturation';

  @override
  String get permManageConfiguration => 'Gérer la configuration';

  @override
  String get permManageDocuments => 'Gérer la bibliothèque de documents';

  @override
  String get permManageIntegrations => 'Gérer les intégrations';

  @override
  String get permManageMembers => 'Gérer les membres';

  @override
  String get permManageNegotiations => 'Gérer les accords commerciaux';

  @override
  String get permManageReservations => 'Gérer les réservations des autres';

  @override
  String get permManageRoles => 'Gérer les rôles et permissions';

  @override
  String get permManageServices => 'Gérer les services et forfaits';

  @override
  String get permManageSites => 'Gérer les sites et modifier le plan';

  @override
  String get permManageValidation => 'Configurer les règles de validation';

  @override
  String get permOperateKiosk => 'Opérer le kiosque et les badges';

  @override
  String get permPaymentTermsEdit =>
      'Demander un changement de conditions de paiement';

  @override
  String get permUseMessages => 'Utiliser la messagerie';

  @override
  String get permViewAnalytics => 'Consulter les chiffres de l\'espace';

  @override
  String get permViewCalendar => 'Voir le calendrier';

  @override
  String get permViewDirectory => 'Voir l\'annuaire des membres';

  @override
  String get permViewDocuments => 'Voir les documents partagés';

  @override
  String get permViewFinances => 'Consulter les finances de l\'espace';

  @override
  String get permViewMyMoney => 'Voir son propre compte et ses factures';

  @override
  String get permViewNegotiations => 'Consulter les accords commerciaux';

  @override
  String get permViewPersonalData =>
      'Consulter les données personnelles des membres';

  @override
  String get permWorkspaceSettings => 'Modifier les réglages de l\'espace';

  @override
  String get personalInfoCity => 'Ville';

  @override
  String get personalInfoCompany => 'Société (facultatif)';

  @override
  String get personalInfoCountry => 'Pays';

  @override
  String get personalInfoEmail => 'E-mail pour les documents';

  @override
  String get personalInfoFirstName => 'Prénom';

  @override
  String get personalInfoLastName => 'Nom';

  @override
  String get personalInfoLegalId => 'SIRET / identifiant (facultatif)';

  @override
  String get personalInfoNone => 'Pas encore renseignées';

  @override
  String get personalInfoPhone => 'Téléphone';

  @override
  String get personalInfoPostalCode => 'Code postal';

  @override
  String get personalInfoPreview => 'Sur vos documents';

  @override
  String get personalInfoSave => 'Enregistrer';

  @override
  String get personalInfoSaved => 'Informations personnelles enregistrées';

  @override
  String get personalInfoStreet => 'Rue et numéro';

  @override
  String get personalInfoSubtitle =>
      'Imprimées sur vos factures et courriers. Le nom de famille s\'écrit en capitales, comme sur un courrier officiel.';

  @override
  String get personalInfoTitle => 'Informations personnelles';

  @override
  String get personalInfoVatId => 'N° de TVA (facultatif)';

  @override
  String placeFeedbackAverage(String average, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$average · $_temp0';
  }

  @override
  String get placeFeedbackFailed => 'Enregistrement impossible. Réessayez.';

  @override
  String get placeFeedbackFavorite => 'Ajouter aux favoris';

  @override
  String get placeFeedbackNoRating => 'Pas encore de note';

  @override
  String placeFeedbackStars(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n étoiles',
      one: '1 étoile',
    );
    return '$_temp0';
  }

  @override
  String get placeFeedbackUnfavorite => 'Retirer des favoris';

  @override
  String get placeFeedbackZero => '0 étoile';

  @override
  String get planAccessorySupplementHint =>
      'Les suppléments s\'appliquent par demi-journée.';

  @override
  String get planActiveLabel => 'Active';

  @override
  String get planAfternoonChip => 'Après-midi';

  @override
  String get planAvailabilityLoading => 'Vérification des jours d’ouverture…';

  @override
  String get planBaseFeeLabel => 'Forfait mensuel';

  @override
  String get planBookForLabel => 'Réserver pour';

  @override
  String planBookedForPending(String name) {
    return 'Envoyé à $name pour confirmation.';
  }

  @override
  String get planCancelReservationButton => 'Annuler la réservation';

  @override
  String planCappedByNext(String time) {
    return 'La place est réservée à partir de $time.';
  }

  @override
  String get planCheckInButton => 'S\'installer';

  @override
  String get planCheckInFailed =>
      'Impossible de s\'installer — la place vient peut-être d\'être prise.';

  @override
  String planCheckInFor(String name) {
    return 'Installer $name';
  }

  @override
  String get planCheckInNotYetError =>
      'L\'arrivée ouvre 15 minutes avant le début.';

  @override
  String planCheckInOpensAt(String time) {
    return 'L\'arrivée ouvre à $time';
  }

  @override
  String planCheckInOpensOn(String date) {
    return 'Le check-in ouvre le $date';
  }

  @override
  String get planCheckInOverError =>
      'Cette réservation est terminée — s\'installer n\'est plus possible.';

  @override
  String get planCheckInTitle => 'Arrivée';

  @override
  String get planCheckOutButton => 'Partir';

  @override
  String planCheckOutFor(String name) {
    return 'Faire sortir $name';
  }

  @override
  String get planClosedDay => 'Fermé ce jour-là';

  @override
  String get planClosedDayError => 'L\'espace est fermé ce jour-là.';

  @override
  String planClosedDayShowNext(String day) {
    return 'Afficher $day';
  }

  @override
  String get planDurationLabel => 'Durée';

  @override
  String get planEndBeforeStart => 'La fin doit être après le début.';

  @override
  String get planFromLabel => 'De';

  @override
  String get planFullDayChip => 'Journée';

  @override
  String get planFullDayError =>
      'Ici, les réservations couvrent la journée entière.';

  @override
  String get planHalfDayError =>
      'Ici, les réservations se font par demi-journée.';

  @override
  String get planIncludedHelper => 'Laisser vide pour illimité';

  @override
  String get planIncludedLabel => 'Demi-journées incluses';

  @override
  String get planLevelLabel => 'Étage';

  @override
  String get planLevelTooltip => 'Étage';

  @override
  String get planListViewTooltip => 'Vue liste';

  @override
  String get planMakeNotReservable => 'Rendre non réservable';

  @override
  String get planMakeReservable => 'Rendre réservable';

  @override
  String get planMapViewTooltip => 'Vue plan';

  @override
  String get planMorningChip => 'Matin';

  @override
  String get planNameLabel => 'Nom';

  @override
  String get planNoLevels => 'L\'espace n\'a pas encore de plan.';

  @override
  String get planNoSeats => 'Cet étage n\'a pas encore de places.';

  @override
  String get planNowButton => 'Maintenant';

  @override
  String planOccupiedBy(String name) {
    return 'Occupée par $name';
  }

  @override
  String get planOverageLabel => 'Prix par demi-journée supplémentaire';

  @override
  String planOverruleDone(String name) {
    return 'Réservation retirée — $name a été notifié.';
  }

  @override
  String planOverruleHint(String name) {
    return '$name et tous les admins seront notifiés.';
  }

  @override
  String get planOverruleRemove => 'Retirer la réservation (outrepasser)';

  @override
  String get planRepeatLabel => 'Répéter';

  @override
  String get planReservationsEmpty => 'Aucune réservation pour ce jour.';

  @override
  String get planReserveButton => 'Réserver';

  @override
  String planReservedBy(String name) {
    return 'Réservée par $name';
  }

  @override
  String get planSeatBlocked => 'Cette place est bloquée pour maintenance.';

  @override
  String get planSendForConfirmation => 'Envoyer pour confirmation';

  @override
  String planSlotError(int minutes) {
    return 'Les réservations doivent commencer et finir sur la grille de $minutes minutes.';
  }

  @override
  String get planStartNow => 'Commence maintenant';

  @override
  String planStartsAt(String time) {
    return 'Commence à $time';
  }

  @override
  String get planStateFree => 'Libre';

  @override
  String get planStateYours => 'À vous';

  @override
  String get planToLabel => 'À';

  @override
  String planUntil(String time) {
    return 'jusqu\'à $time';
  }

  @override
  String get planUntilDateLabel => 'Répéter jusqu\'au';

  @override
  String get planUntilLabel => 'Jusqu\'à';

  @override
  String get planYourSeat => 'Votre place';

  @override
  String get plansEditorEdit => 'Modifier la formule';

  @override
  String get plansEditorInactive => 'Inactive';

  @override
  String get plansEditorNew => 'Nouvelle formule';

  @override
  String plansEditorPerExtra(String price) {
    return '$price/demi-journée suppl.';
  }

  @override
  String plansEditorQuota(int count) {
    return '$count demi-journées';
  }

  @override
  String get plansEditorTitle => 'Formules';

  @override
  String get plansEditorUnlimited => 'demi-journées illimitées';

  @override
  String get policyAdminCheckoutDesc =>
      'Un admin peut terminer le check-in en cours d\'un membre.';

  @override
  String get policyAdminCheckoutTitle =>
      'Les admins peuvent faire le check-out des membres';

  @override
  String get policyAllowPastDesc =>
      'Les membres peuvent enregistrer une réservation déjà terminée (rattrapage).';

  @override
  String get policyAllowPastTitle => 'Autoriser les réservations passées';

  @override
  String policyDaysValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get policyDurationConflict =>
      'Le minimum ne peut pas dépasser le maximum — plus aucune réservation ne serait acceptée.';

  @override
  String get policyHorizonDesc =>
      'Combien de jours à l\'avance une réservation peut commencer. Au-delà, elle est refusée.';

  @override
  String get policyHorizonTitle => 'Horizon de réservation';

  @override
  String policyHoursValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count heures',
      one: '1 heure',
    );
    return '$_temp0';
  }

  @override
  String get policyLimitsDesc =>
      'Jusqu\'où l\'on peut réserver à l\'avance, et quelle durée est acceptée. Ces règles valent sur toutes les granularités.';

  @override
  String get policyLimitsTitle => 'Limites de réservation';

  @override
  String get policyMaxDurationDesc =>
      'La plus longue réservation acceptée. Une réservation se termine le jour où elle commence : la journée entière est donc le plafond.';

  @override
  String get policyMaxDurationTitle => 'Durée maximale';

  @override
  String get policyMinDurationDesc =>
      'La plus courte réservation acceptée. C\'est pourquoi arriver à 11:45 pour la limite de 12:00 est refusé, trop court.';

  @override
  String get policyMinDurationTitle => 'Durée minimale';

  @override
  String policyMinutesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get policyOutsideHoursCharged => 'Facturé';

  @override
  String get policyOutsideHoursChargedDesc =>
      'Autorisé et compté comme un usage normal — sauf les jours où le membre a déjà une réservation normale.';

  @override
  String get policyOutsideHoursDesc =>
      'Ce qui est possible en dehors de la journée de travail — une seule réponse, pour toutes les granularités. Une réservation qui touche les heures d\'ouverture reste une réservation normale.';

  @override
  String get policyOutsideHoursFree => 'Gratuit';

  @override
  String get policyOutsideHoursFreeDesc =>
      'Autorisé, jamais compté ni facturé — pure information de présence.';

  @override
  String get policyOutsideHoursOff => 'Interdit';

  @override
  String get policyOutsideHoursOffDesc =>
      'Rien en dehors des heures : ni réservation à l\'avance, ni check-in spontané, et une réservation qui dépasse la fin de journée est refusée aussi.';

  @override
  String get policyOutsideHoursTitle => 'En dehors des heures d\'ouverture';

  @override
  String get policyOutsideHoursWalkUp => 'Spontané uniquement';

  @override
  String get policyOutsideHoursWalkUpDesc =>
      'Les check-ins spontanés restent possibles, heures supplémentaires du soir comprises ; réserver à l\'avance en dehors des heures est refusé.';

  @override
  String get policySimultaneousDesc =>
      'Combien de réservations qui se chevauchent un membre peut détenir. 1 garde une seule place à la fois.';

  @override
  String get policySimultaneousTitle => 'Réservations simultanées par membre';

  @override
  String get portalActionFailed =>
      'Impossible d’enregistrer cette modification. Réessayez.';

  @override
  String get portalActionNotNegotiated =>
      'Cette action n’est pas disponible entre cette application et ce serveur. Mettre à jour l’application peut aider.';

  @override
  String get portalAddress => 'Adresse publique';

  @override
  String get portalAdmin => 'Administrateur';

  @override
  String get portalAdminVisible =>
      'Afficher mon rôle d’administrateur publiquement';

  @override
  String get portalAssociation => 'Association';

  @override
  String get portalAvailable =>
      'Autoriser les utilisateurs à trouver mon compte et à m’écrire';

  @override
  String get portalChat => 'Discuter';

  @override
  String get portalCompany => 'Entreprise';

  @override
  String get portalConnect => 'Connecter un serveur';

  @override
  String get portalConnectionFailed =>
      'Connexion impossible. Vérifiez le serveur et vos identifiants.';

  @override
  String get portalConnections => 'Serveurs connectés';

  @override
  String get portalConnectionsHint =>
      'Chaque serveur utilise sa propre connexion. Le déconnecter supprime son accès enregistré pour ce compte sur cet appareil.';

  @override
  String get portalCopyEmail => 'Copier l\'e-mail';

  @override
  String get portalCustomised => 'Personnalisé';

  @override
  String get portalDescription => 'Description';

  @override
  String get portalDirectoryIncompatible =>
      'Certains espaces nécessitent une version plus récente de l’application et ne sont pas affichés.';

  @override
  String get portalDirectoryUnavailable =>
      'Certains annuaires sont inaccessibles. Les résultats sont incomplets.';

  @override
  String get portalDisconnect => 'Déconnecter';

  @override
  String get portalDiscover => 'Trouver un espace de travail';

  @override
  String get portalEmail => 'E-mail public';

  @override
  String get portalEmailCode => 'Code de connexion par e-mail';

  @override
  String get portalEmailCopied => 'E-mail copié';

  @override
  String get portalEmployed => 'Salarié de cet espace';

  @override
  String get portalEmploymentHint =>
      'L’emploi ne change ni les accès ni l’abonnement. Le versement des salaires n’est pas activé.';

  @override
  String get portalEnterSpace => 'Entrer';

  @override
  String get portalFindPeople => 'Rechercher des personnes disponibles';

  @override
  String get portalFollowsWorkspace => 'Repris des informations de l’espace';

  @override
  String get portalImage => 'URL de l’image de l’espace';

  @override
  String get portalLatitude => 'Latitude';

  @override
  String get portalList => 'Liste';

  @override
  String get portalLongitude => 'Longitude';

  @override
  String get portalMap => 'Carte';

  @override
  String get portalMessenger => 'Messagerie du compte';

  @override
  String get portalMoreDirectories => 'Autres annuaires';

  @override
  String get portalNoLongerPublished => 'Cet espace n’est plus publié.';

  @override
  String get portalNoWorkspaces => 'Aucun espace publié trouvé.';

  @override
  String get portalOpenMe => 'Moi : mon compte et mes espaces';

  @override
  String get portalOwner => 'Propriétaire';

  @override
  String get portalPerson => 'Particulier';

  @override
  String get portalPhone => 'Téléphone public';

  @override
  String get portalPlans => 'Formules et tarifs';

  @override
  String get portalPreview => 'Vue externe';

  @override
  String get portalPublicPlan => 'Plan public des locaux';

  @override
  String get portalPublication => 'Page publique de l’espace';

  @override
  String get portalPublished => 'Visible dans l’annuaire public';

  @override
  String get portalRegisterDirectory => 'Publier un serveur dans l’annuaire';

  @override
  String get portalRequestProfile => 'Demander un profil dans cet espace';

  @override
  String get portalRequestSent =>
      'Demande envoyée. L’espace examinera votre profil.';

  @override
  String get portalResetAll =>
      'Rétablir toutes les données publiques depuis les informations de l’espace';

  @override
  String get portalResetAllBody =>
      'Les valeurs publiques de chaque champ qui a une information dans l’espace sont remplacées par celle-ci. Les champs sans équivalent dans l’espace gardent ce que vous avez saisi.';

  @override
  String get portalResetAllConfirm => 'Rétablir';

  @override
  String get portalSavePreview => 'Enregistrer et voir la vue externe';

  @override
  String get portalSearch => 'Rechercher des espaces';

  @override
  String get portalSendCode => 'Envoyer le code de connexion';

  @override
  String get portalSourceUnavailable =>
      'Un serveur est indisponible. Cette vue est incomplète. Appuyez pour réessayer.';

  @override
  String get portalThisServer => 'Ce serveur';

  @override
  String get portalUseCode => 'Utiliser un code par e-mail';

  @override
  String get portalUseWorkspaceInfo => 'Utiliser les informations de l’espace';

  @override
  String get portalVisibilityLink => 'Qui peut me trouver et m\'écrire';

  @override
  String get portalVisibilityLinkBody =>
      'Se choisit dans Moi, sous Qui me voit.';

  @override
  String get portalWebsite => 'Site internet';

  @override
  String get preferencesSaveFailed =>
      'Impossible d’enregistrer vos préférences. Réessayez.';

  @override
  String get preferencesScopeHint =>
      'Langue, apparence et formats régionaux. Désactivé : modifier mes valeurs par défaut.';

  @override
  String get preferencesUseDefaults => 'Utiliser mes valeurs par défaut';

  @override
  String get preferencesWorkspaceOnly => 'Uniquement pour cet espace';

  @override
  String get priceGrossHint =>
      'Prix TTC — ce que paie le membre ; la TVA en fait partie.';

  @override
  String priceVatIncluded(String rate) {
    return 'dont TVA $rate';
  }

  @override
  String get privacyErase => 'Quitter cet espace et effacer mes données';

  @override
  String get privacyEraseConfirmButton => 'Effacer';

  @override
  String privacyEraseConfirmHint(String phrase) {
    return 'Irréversible. Tapez $phrase pour confirmer.';
  }

  @override
  String get privacyEraseConfirmPhrase => 'EFFACER';

  @override
  String get privacyEraseHint =>
      'Annule vos réservations, vide vos messages, efface votre profil. Les pièces comptables restent pendant la durée légale, par identifiant, pas par nom (art. 17).';

  @override
  String get privacyEraseOwner =>
      'Un propriétaire transmet d\'abord l\'espace (Membres et forfaits → Copropriété).';

  @override
  String get privacyErased => 'Vos données ont été effacées.';

  @override
  String get privacyExport => 'Exporter mes données';

  @override
  String get privacyExportHint =>
      'Tout ce dont vous êtes l\'objet, en un fichier JSON (art. 20).';

  @override
  String get privacyExportShareText => 'Mon export de données DesKilo';

  @override
  String get privacyIntro =>
      'Vos données ne sont jamais pistées ni vendues, et ne sont lisibles que par les rôles que les règles ci-dessous nomment ; leur hébergement figure dans la notice de confidentialité de cette installation. Voici vos droits au titre du RGPD — chacun est un bouton.';

  @override
  String privacyNoticeController(String name, String contact) {
    return 'Responsable du traitement : $name — $contact';
  }

  @override
  String get privacyNoticeEssential =>
      'Nécessaire au fonctionnement du compte et de l\'espace';

  @override
  String get privacyNoticeNotRecorded => 'non renseigné par l\'exploitant';

  @override
  String get privacyNoticeOptional =>
      'Facultatif — vous pouvez utiliser l\'application sans';

  @override
  String privacyNoticeRegion(String region) {
    return 'Région : $region';
  }

  @override
  String privacyNoticeRights(String contact) {
    return 'Vos droits : $contact';
  }

  @override
  String get privacyNoticeRightsRoute => 'Vos droits et le contact';

  @override
  String get privacyNoticeTitle => 'Qui traite vos données';

  @override
  String privacyNoticeTransfer(String mechanism) {
    return 'Garantie de transfert : $mechanism';
  }

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get privacyPushOnDevice => 'Notifications push sur cet appareil';

  @override
  String get privacyPushOnDeviceFailed =>
      'Le choix n\'a pas pu être enregistré. Veuillez réessayer.';

  @override
  String get privacyPushOnDeviceHint =>
      'Facultatif. Activé, l\'adresse de cet appareil et chaque notification passent par le service de notifications ; désactivé, l\'application fonctionne et rien n\'est envoyé à cet appareil.';

  @override
  String get privacySpaceNotice => 'La notice de confidentialité de cet espace';

  @override
  String get privacySpaceNoticeAcknowledge => 'J\'ai lu cette notice';

  @override
  String get privacySpaceNoticeFailed =>
      'La prise de connaissance n\'a pas pu être enregistrée. Veuillez réessayer.';

  @override
  String get privacySpaceNoticeRead =>
      'Vous avez pris connaissance de cette version.';

  @override
  String get privacySpaceNoticeUnread => 'Pas encore lue — lisez-la ici.';

  @override
  String get privacyTitle => 'Confidentialité et données';

  @override
  String get privacyWhoCanSee => 'Qui peut voir mes données';

  @override
  String get privacyWhoCanSeeHint =>
      'La règle par catégorie, les personnes qu\'elle désigne aujourd\'hui, et qui a réellement consulté.';

  @override
  String processAlsoNeeds(String features) {
    return 'Tout activer nécessite aussi : $features';
  }

  @override
  String processApplied(int count) {
    return '$count fonctionnalités modifiées.';
  }

  @override
  String get processBillingPayments => 'Facturation et paiements';

  @override
  String get processBillingPaymentsDesc =>
      'Facturer l’activité et suivre les sommes dues.';

  @override
  String processBlockedIntro(String feature, String features) {
    return '$feature est encore nécessaire à : $features';
  }

  @override
  String get processChangeFailed =>
      'Les fonctionnalités n\'ont pas pu être modifiées. Rien n\'a été écrit ; réessayez.';

  @override
  String processConfirmOff(int count) {
    return 'Désactiver $count fonctionnalités';
  }

  @override
  String processConfirmOn(int count) {
    return 'Activer $count fonctionnalités';
  }

  @override
  String get processConflict =>
      'Quelqu\'un a modifié les fonctionnalités entre-temps. Voici l\'aperçu à jour — vérifiez-le à nouveau.';

  @override
  String get processCoordination => 'Calendrier et coordination';

  @override
  String get processCoordinationDesc =>
      'Coordonner les activités, les messages et les décisions.';

  @override
  String get processDocumentsInformation => 'Documents et informations';

  @override
  String get processDocumentsInformationDesc =>
      'Créer, partager et exporter les informations de l’espace.';

  @override
  String processFeatureCount(int enabled, int total) {
    return '$enabled fonctionnalités actives sur $total';
  }

  @override
  String get processFeatureOff => 'Désactivée';

  @override
  String get processFeatureOn => 'Activée';

  @override
  String processFeatureWaiting(String feature) {
    return 'Activée, en attente de $feature';
  }

  @override
  String get processFilterAll => 'Tous';

  @override
  String get processFilterEmpty => 'Aucun processus ne correspond à ce filtre.';

  @override
  String processHeldBack(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count fonctionnalités sont activées mais attendent un prérequis désactivé',
      one: '1 fonctionnalité est activée mais attend un prérequis désactivé',
    );
    return '$_temp0';
  }

  @override
  String processInProcess(String process) {
    return 'dans $process';
  }

  @override
  String get processIntegrations => 'Intégrations et automatisation';

  @override
  String get processIntegrationsDesc =>
      'Envoyer les notifications et documents par des services externes.';

  @override
  String get processKeepDependants =>
      'Désactiver quand même, conserver leurs réglages';

  @override
  String get processMembershipCommerce => 'Offres aux membres';

  @override
  String get processMembershipCommerceDesc =>
      'Définir les prix des services et les accords avec les membres.';

  @override
  String processNeededBy(String features) {
    return 'nécessaire à $features';
  }

  @override
  String get processNothingToDo => 'C\'est déjà le cas — rien à changer.';

  @override
  String get processOperations => 'Exploitation et administration';

  @override
  String get processOperationsDesc =>
      'Gérer la configuration et l’utilisation de l’application.';

  @override
  String processRemoveDependants(int count) {
    return 'Désactiver aussi les $count fonctionnalités dépendantes';
  }

  @override
  String get processReservationsUsage => 'Réservations et utilisation';

  @override
  String get processReservationsUsageDesc =>
      'Réserver les places et suivre leur utilisation.';

  @override
  String get processSearchLabel => 'Rechercher processus et fonctionnalités';

  @override
  String get processSectionAlreadyOn => 'Déjà actives';

  @override
  String get processSectionAlsoNeeded => 'Également nécessaires';

  @override
  String get processSectionAlsoOff => 'Également désactivées';

  @override
  String get processSectionKeptWaiting =>
      'Cessent de fonctionner ; leur réglage est conservé';

  @override
  String get processSectionSwitchedOff => 'Désactivées';

  @override
  String get processSectionSwitchedOn => 'Activées';

  @override
  String get processSectionWorksAgain => 'De nouveau opérationnelles';

  @override
  String processSheetTitleOff(String name) {
    return 'Désactiver $name';
  }

  @override
  String processSheetTitleOn(String name) {
    return 'Activer $name';
  }

  @override
  String get processSpaceManagement => 'Gestion des lieux';

  @override
  String get processSpaceManagementDesc =>
      'Organiser les lieux accessibles aux membres et leurs horaires.';

  @override
  String get processStateActive => 'Actif';

  @override
  String get processStateAvailable => 'Disponible';

  @override
  String get processStateNeedsAttention => 'À vérifier';

  @override
  String get processStatePartial => 'Partiel';

  @override
  String processSubprocessCount(int active, int total) {
    return '$active sous-processus actifs sur $total';
  }

  @override
  String get processSwitchHint =>
      'Touchez une fonctionnalité pour la modifier parmi les interrupteurs.';

  @override
  String get processSwitchOff => 'Désactiver';

  @override
  String get processSwitchOn => 'Activer';

  @override
  String get processUnconfirmed =>
      'La modification a été écrite, mais l\'app n\'a pas pu la confirmer. Fermez et rouvrez les fonctionnalités pour voir l\'état actuel.';

  @override
  String get processWorkspaceAccess => 'Espace et accès';

  @override
  String get processWorkspaceAccessDesc =>
      'Gérer les adhésions, les rôles et l’accès aux locaux.';

  @override
  String get profilePhotoChoose => 'Choisir une photo';

  @override
  String get profilePhotoFileType => 'Image';

  @override
  String get profilePhotoNone => 'Toucher pour ajouter une photo';

  @override
  String get profilePhotoRemove => 'Supprimer la photo';

  @override
  String get profilePhotoRemoved => 'Photo supprimée';

  @override
  String get profilePhotoSaveFailed => 'Impossible de mettre à jour la photo';

  @override
  String get profilePhotoSaved => 'Photo mise à jour';

  @override
  String get profilePhotoSet => 'Toucher pour changer';

  @override
  String get profilePhotoTitle => 'Photo';

  @override
  String get profileStatusFieldLabel => 'Statut';

  @override
  String get profileStatusHelper =>
      'Facultatif. Visible par les membres de vos espaces dans l\'annuaire des membres. Laissez vide pour l\'effacer.';

  @override
  String get profileStatusHint => 'En appel · de retour à 14h00';

  @override
  String get profileStatusNone => 'Aucun statut';

  @override
  String get profileStatusSaveFailed => 'Impossible d\'enregistrer le statut';

  @override
  String get profileStatusSaved => 'Statut enregistré';

  @override
  String get profileStatusTitle => 'Statut';

  @override
  String get profilesActive => 'Profil actif';

  @override
  String get profilesAdd => 'Ajouter un profil';

  @override
  String get profilesAllWorkspaces =>
      'Tous les espaces (opérateur de la plateforme)';

  @override
  String get profilesCopyEmail => 'Copier l\'e-mail';

  @override
  String get profilesDefault => 'Profil par défaut au démarrage';

  @override
  String get profilesEmailCopied => 'E-mail copié.';

  @override
  String get profilesMakeDefault => 'Utiliser par défaut au démarrage';

  @override
  String profilesNotMember(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return 'Non membre · $_temp0';
  }

  @override
  String get profilesOwnersNone => 'Aucun propriétaire.';

  @override
  String profilesOwnersOf(String name) {
    return 'Propriétaires de $name';
  }

  @override
  String get profilesPairDev => 'DEV';

  @override
  String get profilesPairProd => 'PROD';

  @override
  String profilesSiteLine(String site) {
    return 'Site : $site';
  }

  @override
  String get profilesSitePick => 'Changer de site';

  @override
  String get profilesTitle => 'Profils';

  @override
  String get profilesUnavailable => 'Vos espaces n\'ont pas pu être chargés.';

  @override
  String provenanceFromTemplate(String name) {
    return 'Du modèle « $name »';
  }

  @override
  String get provenanceProductDefault => 'Valeur par défaut du produit';

  @override
  String get provenanceResetToDefault => 'Revenir à la valeur par défaut';

  @override
  String get provenanceResetToTemplate => 'Revenir au modèle';

  @override
  String get provenanceWorkspaceSetting => 'Réglage de l\'espace';

  @override
  String get publicHolidaysAction => 'Ajouter les jours fériés';

  @override
  String publicHolidaysConfirm(int count) {
    return 'Créer $count jours de fermeture';
  }

  @override
  String get publicHolidaysCountry => 'Pays';

  @override
  String publicHolidaysCreated(int count) {
    return '$count jours de fermeture créés';
  }

  @override
  String get publicHolidaysLocked => 'Mois facturé — non créé';

  @override
  String publicHolidaysLockedMonths(String months) {
    return 'Ignorés, déjà facturés : $months';
  }

  @override
  String get publicHolidaysNothingToCreate =>
      'Rien à créer — tous les jours sont déjà là.';

  @override
  String get publicHolidaysPresent => 'Déjà un jour de fermeture';

  @override
  String get publicHolidaysPreviewNone => 'Aucun jour férié pour cette année.';

  @override
  String get publicHolidaysSheetTitle => 'Jours fériés';

  @override
  String get publicHolidaysYear => 'Année';

  @override
  String get publicPersonUnavailable => 'Ce profil n\'est pas public.';

  @override
  String get publicProfileCopied => 'Lien copié.';

  @override
  String get publicProfileCopy => 'Copier le lien';

  @override
  String get publicProfileOff =>
      'Désactivé : les personnes non connectées ne voient rien de vous.';

  @override
  String get publicProfileOn =>
      'Toute personne ayant le lien lit votre nom, votre métier et votre présentation.';

  @override
  String get publicProfilePublishAction => 'Publier';

  @override
  String get publicProfilePublishBody =>
      'N\'importe qui sur Internet, connecté ou non, pourra lire votre nom, votre métier et votre présentation via votre lien. Vos coordonnées, votre présence et vos espaces restent privés.';

  @override
  String get publicProfilePublishTitle => 'Publier un profil public ?';

  @override
  String get publicProfileTitle => 'Profil public';

  @override
  String get pushCancelledBody => 'Une réservation a été retirée par un admin.';

  @override
  String get pushCancelledTitle => 'Réservation retirée';

  @override
  String get pushPendingBody => 'Quelqu\'un attend votre confirmation.';

  @override
  String get pushPendingTitle => 'DesKilo';

  @override
  String get pushStatusNoTransport =>
      'Cette version n\'a pas de notifications push';

  @override
  String get pushStatusNoTransportHint =>
      'Les notifications arrivent dans l\'app et en notifications locales sur cet appareil.';

  @override
  String get pushStatusNotConfigured =>
      'Les notifications push ne sont pas encore configurées';

  @override
  String get pushStatusNotConfiguredHint =>
      'Le propriétaire termine la configuration Firebase (guide push-setup).';

  @override
  String get pushStatusRegistered => 'Les notifications push sont actives';

  @override
  String get questionEditorActive => 'Posée actuellement';

  @override
  String get questionEditorChoices => 'Choix, un par ligne';

  @override
  String get questionEditorContextJoin => 'À l\'adhésion';

  @override
  String get questionEditorContextManaged =>
      'Les informations d\'un membre géré';

  @override
  String get questionEditorContextProfile => 'Les informations du membre';

  @override
  String get questionEditorContexts => 'Où elle est posée';

  @override
  String get questionEditorKey => 'Clé';

  @override
  String get questionEditorKeyHelp =>
      'Minuscules, chiffres et tirets bas. Elle ne change jamais : les réponses s\'y rattachent.';

  @override
  String questionEditorLabelFor(String locale) {
    return 'Libellé ($locale)';
  }

  @override
  String get questionEditorMax => 'Nombre maximum';

  @override
  String get questionEditorMaxLength => 'Réponse la plus longue (caractères)';

  @override
  String get questionEditorMin => 'Nombre minimum';

  @override
  String get questionEditorNotPersonalWarning =>
      'Toujours personnelle : la réponse est liée à un membre, elle est donc exportée et effacée avec l\'adhésion quel que soit ce réglage. Seule une conservation légale documentée peut la garder.';

  @override
  String get questionEditorPersonal => 'C\'est une donnée personnelle';

  @override
  String get questionEditorPersonalHelp =>
      'Chaque réponse est liée à un membre : c\'est une donnée personnelle, incluse dans son export de données et effacée à son départ.';

  @override
  String get questionEditorPreview => 'Aperçu';

  @override
  String get questionEditorRequired => 'Réponse obligatoire';

  @override
  String get questionEditorSave => 'Enregistrer la question';

  @override
  String get questionEditorSaveFailed =>
      'La question n\'a pas été enregistrée.';

  @override
  String get questionEditorType => 'Type de réponse';

  @override
  String get questionEditorVisibility => 'Qui voit la réponse';

  @override
  String get questionEditorVisibilityManagers =>
      'Le membre, et qui peut voir les données personnelles';

  @override
  String get questionEditorVisibilityMembers => 'Tous les membres de l\'espace';

  @override
  String get questionEditorVisibilitySelf => 'Le membre seulement';

  @override
  String get questionTypeBoolean => 'Oui ou non';

  @override
  String get questionTypeDate => 'Une date';

  @override
  String get questionTypeDecimal => 'Un nombre';

  @override
  String get questionTypeInteger => 'Un nombre entier';

  @override
  String get questionTypeLongText => 'Une réponse longue';

  @override
  String get questionTypeMultiChoice => 'Plusieurs choix dans une liste';

  @override
  String get questionTypeSingleChoice => 'Un choix dans une liste';

  @override
  String get questionTypeText => 'Une réponse courte';

  @override
  String get questionsAdd => 'Ajouter une question';

  @override
  String get questionsEmpty => 'Aucune question pour l\'instant.';

  @override
  String get questionsInactive => 'Mise de côté';

  @override
  String get questionsSubtitle =>
      'Elles apparaissent dans les informations personnelles, sous le nom de votre espace.';

  @override
  String get questionsTitle => 'Les questions de cet espace';

  @override
  String get quotaExceededError =>
      'Quota mensuel de demi-journées atteint — demandez des demi-journées supplémentaires depuis l\'onglet Finances.';

  @override
  String get quotaRequestButton => 'Demander des demi-journées';

  @override
  String get quotaRequestCountLabel => 'Nombre de demi-journées';

  @override
  String quotaRequestExplainer(String period) {
    return 'Vos réservations sont plafonnées par votre abonnement. Les demi-journées supplémentaires pour $period s\'appliquent une fois validées.';
  }

  @override
  String get quotaRequestPending =>
      'Demande envoyée — en attente de validation.';

  @override
  String get quotaRequestTitle => 'Demander des demi-journées supplémentaires';

  @override
  String readinessActor(String who) {
    return 'Qui : $who';
  }

  @override
  String get readinessActorAdministrator => 'Un administrateur de la base';

  @override
  String get readinessActorOperator => 'L’opérateur du serveur';

  @override
  String get readinessActorOwner => 'Vous';

  @override
  String readinessAll(String ready, String total) {
    return 'Toutes les sections ($ready sur $total prêtes)';
  }

  @override
  String get readinessAreaAssistant => 'Accès des assistants (facultatif)';

  @override
  String get readinessAreaBackend => 'Serveur et version de la base';

  @override
  String get readinessAreaFirstBooking => 'Une première réservation';

  @override
  String get readinessAreaInvitations => 'Inviter les premiers membres';

  @override
  String get readinessAreaLocalSetup =>
      'Informations requises par vos fonctionnalités (identité, banque, plateformes)';

  @override
  String get readinessAreaPayments => 'Comment les membres paient';

  @override
  String get readinessAreaPricing => 'Formules d’adhésion et tarifs';

  @override
  String get readinessAreaRecovery => 'Export et restauration';

  @override
  String get readinessAreaRegionRules =>
      'Jours d’ouverture, fuseau horaire et devise';

  @override
  String get readinessAreaResources => 'Places réservables sur le plan';

  @override
  String get readinessAreaRolesValidation => 'Rôles et validation des demandes';

  @override
  String readinessBlocked(String step) {
    return 'Avant une première réservation : $step';
  }

  @override
  String get readinessFirstBookingReady => 'Prêt pour une première réservation';

  @override
  String get readinessLater => 'Nécessaire plus tard';

  @override
  String get readinessNeededFirst => 'Nécessaire pour une première réservation';

  @override
  String readinessNext(String step) {
    return 'Ensuite : $step';
  }

  @override
  String get readinessReasonEligibilityExpired =>
      'Votre habilitation aux assistants a expiré';

  @override
  String get readinessReasonEligibilityMissing =>
      'Aucun administrateur de la base ne vous a habilité aux assistants';

  @override
  String get readinessReasonEligibilityNoIdentity =>
      'Connectez-vous d’abord avec votre identité vérifiée';

  @override
  String get readinessReasonEligibilityRequested =>
      'Votre demande attend un administrateur de la base';

  @override
  String get readinessReasonNoEvidence =>
      'Aucun export ni restauration enregistré';

  @override
  String get readinessReasonNoPolicies =>
      'Aucune demande n’attend de validateur';

  @override
  String get readinessReasonNotExposed =>
      'Cet espace n’expose encore rien aux assistants';

  @override
  String get readinessReasonRecentExport => 'Un export récent est enregistré';

  @override
  String get readinessReasonStaleExport =>
      'Le dernier export enregistré date de plus de 90 jours';

  @override
  String get readinessReasonTooFewValidators =>
      'Une règle demande plus de validateurs que cet espace n’en compte';

  @override
  String get readinessSetAside => 'Mis de côté pour plus tard';

  @override
  String get readinessSetAsideAction => 'Plus tard';

  @override
  String get readinessSetAsideFailed => 'Impossible d’enregistrer. Réessayez.';

  @override
  String get readinessSetAsideUndo => 'Annuler';

  @override
  String get readinessStateNeeds => 'À configurer';

  @override
  String get readinessStateNeedsOperator => 'En attente d’une autre personne';

  @override
  String get readinessStateNotApplicable => 'Sans objet ici';

  @override
  String get readinessStateReady => 'Prêt';

  @override
  String get readinessStateUnavailable => 'Lecture impossible';

  @override
  String get readinessStateUnverified => 'Pas encore vérifié';

  @override
  String get readinessTitle => 'Mise en place de cet espace';

  @override
  String get recordingPrivacyBadge => 'Mode tournage — personnes inventées';

  @override
  String get recordingPrivacyBadgeHint =>
      'Le mode tournage est actif : chaque nom, adresse électronique, numéro de téléphone, adresse postale et photo affiché appartient à une personne inventée. Le plan, les réservations et les montants sont bien ceux de cet espace. Désactivez-le dans les Réglages une fois le tournage terminé.';

  @override
  String get recordingPrivacyWriteRefused =>
      'Impossible tant que le mode tournage est actif : ce formulaire affiche une personne inventée, et l\'enregistrer écraserait les vraies coordonnées de quelqu\'un. Désactivez d\'abord le mode tournage.';

  @override
  String get refFacetMonth => 'Mois';

  @override
  String get refFacetPerson => 'Personne';

  @override
  String get refFacetStatus => 'Statut';

  @override
  String get refFacetType => 'Type';

  @override
  String get refFacetWorkspace => 'Espace';

  @override
  String get refFilterAll => 'Tout';

  @override
  String get refFilterAmount => 'Montant';

  @override
  String get refFilterClear => 'Effacer les filtres';

  @override
  String refFilterFindIn(String facet) {
    return 'Chercher dans $facet';
  }

  @override
  String get refFilterMore => 'Filtres';

  @override
  String get refFilterReset => 'Réinitialiser';

  @override
  String refFilterShow(int count) {
    return 'Afficher $count résultats';
  }

  @override
  String get refFilterSort => 'Trier';

  @override
  String get refSortAmountHigh => 'Montant le plus élevé';

  @override
  String get refSortAmountLow => 'Montant le plus bas';

  @override
  String get refSortNewest => 'Les plus récents d\'abord';

  @override
  String get refSortOldest => 'Les plus anciens d\'abord';

  @override
  String get refStatusCancelled => 'Annulée';

  @override
  String get refStatusDecided => 'Décidée';

  @override
  String get refStatusOpen => 'Ouverte (impayée)';

  @override
  String get refStatusPaid => 'Payée';

  @override
  String get refStatusPending => 'En attente';

  @override
  String get refStatusRefunded => 'Remboursée';

  @override
  String get refTypeCreditNote => 'Avoir';

  @override
  String get refTypeInvoice => 'Facture';

  @override
  String get refusalAlreadyDecided =>
      'Quelqu\'un a déjà décidé. La liste affiche le résultat.';

  @override
  String get refusalChangedMeanwhile =>
      'Cet élément a changé entre-temps. Rouvrez-le pour voir où il en est.';

  @override
  String get refusalPermission =>
      'Vous n\'avez pas l\'autorisation pour cela. Un propriétaire de l\'espace peut l\'accorder dans Gestion des rôles.';

  @override
  String get refusalSession =>
      'Votre session a expiré. Reconnectez-vous, puis réessayez.';

  @override
  String get regionalClock => 'Horloge';

  @override
  String get regionalClock12h => '12h';

  @override
  String get regionalClock24h => '24h';

  @override
  String get regionalClockAuto => 'Auto';

  @override
  String get regionalDeviceZone => 'Afficher les heures dans mon fuseau';

  @override
  String get regionalDeviceZoneHint =>
      'Désactivé : les heures s\'affichent dans le fuseau de l\'espace, celui des réservations. Activé : celui de votre appareil, signalé quand il diffère.';

  @override
  String get regionalFollowLanguage => 'Automatique';

  @override
  String get regionalFormatLocale => 'Nombres et dates';

  @override
  String regionalFormatLocaleAuto(String locale) {
    return 'Suit la langue de l\'app ($locale)';
  }

  @override
  String get regionalFormatsTitle => 'Région et formats';

  @override
  String get registerPaymentAmount => 'Montant';

  @override
  String get registerPaymentDate => 'Payé le';

  @override
  String get registerPaymentDone =>
      'Paiement enregistré — le membre le confirme de son côté.';

  @override
  String get registerPaymentHint =>
      'Un paiement arrivé à l\'espace — le membre le confirme, puis il peut être rapproché d\'une facture.';

  @override
  String get registerPaymentMember => 'Membre';

  @override
  String get registerPaymentMethod => 'Moyen';

  @override
  String get registerPaymentNote => 'Note';

  @override
  String get registerPaymentSubmit => 'Enregistrer';

  @override
  String get registerPaymentTitle => 'Enregistrer un paiement';

  @override
  String reminderBody(String target, String time) {
    return '$target commence à $time';
  }

  @override
  String reminderHistoryLine(int level, String origin, String date) {
    return 'Niveau $level · $origin · $date';
  }

  @override
  String get reminderHistoryRefresh => 'Vérifier à nouveau l\'envoi';

  @override
  String get reminderHistoryTitle => 'Historique des relances';

  @override
  String get reminderOriginAutomatic => 'automatique';

  @override
  String get reminderOriginLegacy => 'antérieure';

  @override
  String get reminderOriginManual => 'à la main';

  @override
  String get reminderPdfClosing =>
      'Si vous avez déjà payé, veuillez ne pas tenir compte de ce courrier.';

  @override
  String get reminderPdfDays => 'jours';

  @override
  String get reminderPdfDaysOpen => 'Ouverte depuis';

  @override
  String get reminderPdfLevelLabel => 'Niveau de relance';

  @override
  String get reminderPdfOpeningFirm =>
      'malgré notre relance précédente, la facture ci-dessous reste impayée. Merci de régler le montant sans délai.';

  @override
  String get reminderPdfOpeningFriendly =>
      'petit rappel amical : la facture ci-dessous est encore ouverte. Un simple oubli, sans doute — pas d\'inquiétude.';

  @override
  String get reminderPdfTitleFirm => 'Relance';

  @override
  String get reminderPdfTitleFriendly => 'Rappel de paiement';

  @override
  String get reminderStatusAccepted =>
      'Acceptée par le service de notifications — ce n\'est pas une preuve de lecture';

  @override
  String get reminderStatusDeclared =>
      'Partagée par l\'expéditeur — sa déclaration, pas un accusé de réception';

  @override
  String get reminderStatusFailed => 'Non distribuée';

  @override
  String get reminderStatusLegacy =>
      'Enregistrée avant le suivi de l\'envoi — inconnu';

  @override
  String get reminderStatusPrepared => 'Préparée';

  @override
  String get reminderStatusQueued => 'Confiée au service de notifications';

  @override
  String get reminderStatusUnknown =>
      'Aucune réponse du service de notifications';

  @override
  String get reminderTitle => 'Arrivée bientôt';

  @override
  String get repartitionAction => 'Répartir une dépense';

  @override
  String get repartitionAmount => 'Montant total';

  @override
  String get repartitionAmountLabel => 'Montant';

  @override
  String get repartitionBooked => 'Répartition comptabilisée.';

  @override
  String get repartitionExclude => 'Exclure';

  @override
  String get repartitionFiled =>
      'Parts comptabilisées — elles apparaîtront sur la prochaine facture de consommation.';

  @override
  String get repartitionFiledPending =>
      'Parts déposées — elles seront comptabilisées après validation.';

  @override
  String get repartitionHint =>
      'Répartissez un coût commun entre les membres. Les parts deviennent des lignes de la prochaine facture de consommation de chacun ; une annulation rend l\'argent sous forme d\'avoirs.';

  @override
  String get repartitionHistory => 'Répartitions';

  @override
  String get repartitionHistoryEmpty => 'Aucune répartition pour l\'instant.';

  @override
  String get repartitionMethod => 'Répartir selon';

  @override
  String get repartitionMethodCustom => 'Clé personnalisée';

  @override
  String get repartitionMethodEqual => 'Parts égales';

  @override
  String get repartitionMethodSubscription => 'Abonnement';

  @override
  String get repartitionMethodUsage => 'Usage';

  @override
  String get repartitionNoShares =>
      'Personne ne porte de part — vérifiez la clé.';

  @override
  String get repartitionPeriod => 'Imputé sur';

  @override
  String get repartitionPeriodLabel => 'Mois';

  @override
  String get repartitionPreview => 'Parts';

  @override
  String get repartitionRememberRule => 'Mémoriser cette règle';

  @override
  String get repartitionReverse => 'Annulation — rendre sous forme d\'avoirs';

  @override
  String get repartitionRuleHint =>
      'Chaque part est proposée au prorata de l\'abonnement. Décochez un adhérent pour l\'exclure ; en méthode « clé », saisissez son poids. La règle ajustée sera proposée le mois prochain.';

  @override
  String get repartitionRuleNotSaved =>
      'La règle n\'a pas pu être enregistrée : rien n\'a été réparti. Réessayez.';

  @override
  String get repartitionSharesTotal => 'Total des parts';

  @override
  String get repartitionStatusConfirmed => 'Comptabilisée';

  @override
  String get repartitionStatusExpired => 'Expirée';

  @override
  String get repartitionStatusPending => 'En attente de validation';

  @override
  String get repartitionStatusRejected => 'Refusée';

  @override
  String get repartitionStepBook => 'Comptabiliser';

  @override
  String get repartitionStepCost => 'La dépense';

  @override
  String get repartitionStepExpense => 'La dépense';

  @override
  String get repartitionStepRule => 'La règle';

  @override
  String get repartitionSubmit => 'Comptabiliser les parts';

  @override
  String repartitionSum(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres · $amount',
      one: '1 membre · $amount',
    );
    return '$_temp0';
  }

  @override
  String get repartitionTitle => 'Répartir une dépense';

  @override
  String get repartitionTitleField => 'Objet';

  @override
  String get repartitionTitleLabel => 'Intitulé';

  @override
  String get repartitionWeight => 'Clé';

  @override
  String get repartitionWizardSubtitle =>
      'Proposer au prorata de l\'abonnement, ajuster, comptabiliser';

  @override
  String get repartitionWizardTitle => 'Répartir une dépense';

  @override
  String get repartitionWizardWeight => 'Poids';

  @override
  String get repeatDaily => 'Tous les jours';

  @override
  String get repeatNone => 'Ne se répète pas';

  @override
  String get repeatWeekdays => 'Tous les jours ouvrés';

  @override
  String get repeatWeekly => 'Chaque semaine';

  @override
  String get reportBadgesFooter =>
      'Un badge perdu se révoque dans Membres et forfaits, il ne suffit pas de le remplacer.';

  @override
  String get reportBadgesIntro =>
      'Découpez suivant les traits. Chaque carte porte le code badge d\'un membre — à présenter à la borne pour pointer.';

  @override
  String get reportBadgesTitle => 'Badges des membres';

  @override
  String get reportCoaAccounts => 'Comptes suggérés';

  @override
  String get reportCoaDisclaimer =>
      'Aperçu seulement. DesKilo ne tient pas de grand livre et ne fait pas votre comptabilité — le plan de votre comptable prime toujours.';

  @override
  String get reportCoaIntro =>
      'Une suggestion, pas votre comptabilité. Voici les comptes qu\'un comptable de votre pays utiliserait habituellement pour un espace comme le vôtre.';

  @override
  String get reportCoaLabel => 'Libellé';

  @override
  String get reportCoaNumber => 'Compte';

  @override
  String get reportCoaTitle => 'Plan comptable — aperçu';

  @override
  String get reportColQty => 'Qté';

  @override
  String get reportColTotal => 'Total';

  @override
  String get reportColUnitPrice => 'Prix unit.';

  @override
  String get reportDesignEmpty => 'Bande vide — ajoutez un élément ci-dessous.';

  @override
  String get reportDesignErrorInvalidDesign =>
      'Ce fichier ne contient aucune maquette lisible.';

  @override
  String get reportDesignErrorMalformed =>
      'Ce fichier n\'est pas du JSON lisible.';

  @override
  String get reportDesignErrorNotADesign =>
      'Ce fichier n\'est pas une maquette de rapport DesKilo.';

  @override
  String get reportDesignErrorUnknownKind =>
      'Cette maquette concerne un rapport que cet espace n\'a pas.';

  @override
  String get reportDesignErrorVersion =>
      'Cette maquette vient d’une version plus récente de DesKilo.';

  @override
  String get reportDesignErrorWrongKind =>
      'Cette maquette appartient à un autre rapport. Ouvrez ce rapport et importez-la là.';

  @override
  String get reportDesignExport => 'Exporter cette maquette';

  @override
  String get reportDesignFileTypeLabel => 'JSON';

  @override
  String get reportDesignImport => 'Importer une maquette';

  @override
  String get reportDesignImported =>
      'Maquette importée. Enregistrez pour la conserver.';

  @override
  String get reportDesignerDesign => 'Conception';

  @override
  String get reportDesignerDiscard => 'Abandonner';

  @override
  String get reportDesignerDiscardBody =>
      'Vos modifications des modèles ne sont pas enregistrées.';

  @override
  String get reportDesignerDiscardTitle => 'Quitter sans enregistrer ?';

  @override
  String get reportDesignerDrag => 'Glisser pour réordonner';

  @override
  String reportDesignerError(String message) {
    return 'Le modèle ne se génère pas — $message';
  }

  @override
  String get reportDesignerFields => 'Champs';

  @override
  String get reportDesignerFieldsSearch => 'Rechercher un champ';

  @override
  String get reportDesignerInsert => 'Insérer un élément';

  @override
  String get reportDesignerKeepEditing => 'Continuer';

  @override
  String get reportDesignerMoveTo => 'Déplacer vers la bande';

  @override
  String reportDesignerPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get reportDesignerPreview => 'Aperçu';

  @override
  String get reportDesignerRedo => 'Rétablir';

  @override
  String get reportDesignerReplace => 'Remplacer';

  @override
  String get reportDesignerReplaceBody =>
      'Les bandes de ce document sont remplacées. Annuler les restaure.';

  @override
  String get reportDesignerReplaceTitle =>
      'Remplacer la mise en page actuelle ?';

  @override
  String get reportDesignerSideBySide => 'Conception et aperçu côte à côte';

  @override
  String get reportDesignerUndo => 'Annuler';

  @override
  String get reportDesignerZoom => 'Zoom';

  @override
  String get reportDesignerZoomFit => 'Ajuster à la largeur';

  @override
  String get reportDocAgreement => 'Accord financier';

  @override
  String get reportDocBadges => 'Badges des membres';

  @override
  String get reportDocCoa => 'Plan comptable';

  @override
  String get reportDocPayments => 'Rapport des paiements';

  @override
  String get reportDocSpaceCodes => 'Cartes QR des espaces';

  @override
  String get reportDocStatus => 'Situation de l\'espace';

  @override
  String get reportDocUsage => 'Rapport de consommation';

  @override
  String get reportDocVat => 'Rapport de TVA';

  @override
  String get reportDocWorkspace => 'Rapport de l\'espace';

  @override
  String get reportDocWorkspaceSubtitle =>
      'Tout sur l\'espace — via le modèle « espace » de l\'éditeur de rapports';

  @override
  String get reportEditorMarkup => 'Balisage';

  @override
  String get reportEditorTitle => 'Éditeur de rapports';

  @override
  String get reportEditorVisual => 'Visuel';

  @override
  String get reportFieldGroupBank => 'Coordonnées bancaires';

  @override
  String get reportFieldGroupDocument => 'Document';

  @override
  String get reportFieldGroupLegal => 'Mentions légales';

  @override
  String get reportFieldGroupLoops => 'Boucles lignes et TVA';

  @override
  String get reportFieldGroupMember => 'Membre et espace';

  @override
  String get reportFieldGroupMoney => 'Montants';

  @override
  String get reportFieldGroupSeller => 'Vendeur';

  @override
  String get reportFieldGroupSites => 'Sites';

  @override
  String get reportFieldGroupStatus => 'Situation de l\'espace';

  @override
  String get reportFieldGroupTexts => 'Vos textes';

  @override
  String get reportFieldGroupUsage => 'Rapport de consommation';

  @override
  String get reportFieldGroupVat => 'Déclaration de TVA';

  @override
  String get reportFieldMeaningAccountHolder => 'Le titulaire du compte';

  @override
  String get reportFieldMeaningBankAccount => 'Le numéro de compte';

  @override
  String get reportFieldMeaningBankCode => 'Le code banque';

  @override
  String get reportFieldMeaningBankName => 'Le nom de la banque';

  @override
  String get reportFieldMeaningBic => 'Le BIC de la banque';

  @override
  String get reportFieldMeaningBuyerReference =>
      'La référence propre de l\'acheteur (secteur public)';

  @override
  String get reportFieldMeaningCharges => 'Les frais avant règlements';

  @override
  String get reportFieldMeaningClientAddress => 'Le bloc postal du client';

  @override
  String get reportFieldMeaningClientCompany => 'La société du client';

  @override
  String get reportFieldMeaningClientEmail => 'Le courriel du client';

  @override
  String get reportFieldMeaningClientLegalId =>
      'L\'identifiant légal du client (SIREN…)';

  @override
  String get reportFieldMeaningClientMemberNumber =>
      'Le numéro d\'adhérent du client';

  @override
  String get reportFieldMeaningClientName => 'Le nom complet du client';

  @override
  String get reportFieldMeaningClientPhone => 'Le téléphone du client';

  @override
  String get reportFieldMeaningClientVatId => 'Le numéro de TVA du client';

  @override
  String get reportFieldMeaningCopy => 'Vrai sur un duplicata';

  @override
  String get reportFieldMeaningCreditNote => 'Vrai sur un avoir';

  @override
  String get reportFieldMeaningDueDate => 'La date d\'échéance';

  @override
  String get reportFieldMeaningEscompte => 'La mention d\'escompte';

  @override
  String get reportFieldMeaningExemptionReason =>
      'La mention d\'exonération de TVA';

  @override
  String get reportFieldMeaningHasVat => 'Vrai quand la TVA s\'applique';

  @override
  String get reportFieldMeaningIban => 'L\'IBAN du compte';

  @override
  String get reportFieldMeaningInsurance =>
      'La mention d\'assurance professionnelle';

  @override
  String get reportFieldMeaningIssued => 'La date d\'émission';

  @override
  String get reportFieldMeaningIssuedBy => 'Qui a émis le document';

  @override
  String get reportFieldMeaningLatePenalty =>
      'La mention des pénalités de retard';

  @override
  String get reportFieldMeaningLines => 'Les lignes de la facture — une boucle';

  @override
  String get reportFieldMeaningMember => 'Le nom d\'affichage de l\'adhérent';

  @override
  String get reportFieldMeaningNetTotal => 'Le total hors taxe';

  @override
  String get reportFieldMeaningNumber => 'Le numéro du document';

  @override
  String get reportFieldMeaningPaymentReference =>
      'La référence à indiquer au paiement';

  @override
  String get reportFieldMeaningPaymentTerms =>
      'La mention des conditions de paiement';

  @override
  String get reportFieldMeaningPaymentTermsSource =>
      'D\'où viennent les conditions (adhérent ou espace)';

  @override
  String get reportFieldMeaningPayments => 'Les règlements déjà reçus';

  @override
  String get reportFieldMeaningPendingExpensesTotal =>
      'Dépenses encore à valider';

  @override
  String get reportFieldMeaningPendingPaymentsTotal =>
      'Règlements encore à confirmer';

  @override
  String get reportFieldMeaningPeriod => 'Le mois couvert par le document';

  @override
  String get reportFieldMeaningPeriodMonth =>
      'Le mois de la période, par son nom (« Septembre »)';

  @override
  String get reportFieldMeaningPeriodYear => 'L\'année de la période';

  @override
  String get reportFieldMeaningProforma => 'Vrai sur une proforma';

  @override
  String get reportFieldMeaningPurchaseOrder =>
      'La référence du bon de commande de l\'acheteur';

  @override
  String get reportFieldMeaningRecoveryIndemnity =>
      'La mention de l\'indemnité de recouvrement';

  @override
  String get reportFieldMeaningRefundTotal => 'Le montant remboursé';

  @override
  String get reportFieldMeaningReplaces => 'Le numéro de la facture remplacée';

  @override
  String get reportFieldMeaningSellerLegalForm =>
      'La forme juridique du vendeur';

  @override
  String get reportFieldMeaningSellerLegalId =>
      'L\'identifiant légal du vendeur';

  @override
  String get reportFieldMeaningSellerRegistration =>
      'L\'immatriculation du vendeur (SIREN, RNA…)';

  @override
  String get reportFieldMeaningSellerVatId => 'Le numéro de TVA du vendeur';

  @override
  String get reportFieldMeaningSiteAddress => 'L\'adresse du site du document';

  @override
  String get reportFieldMeaningSiteName => 'Le nom du site du document';

  @override
  String get reportFieldMeaningSpecialMentions =>
      'Les mentions particulières de l\'espace';

  @override
  String get reportFieldMeaningStatusCreditNotes => 'Les avoirs émis';

  @override
  String get reportFieldMeaningStatusCredits => 'Les crédits accordés';

  @override
  String get reportFieldMeaningStatusFrom =>
      'Le premier jour de la période de situation';

  @override
  String get reportFieldMeaningStatusInvoiced => 'Ce que l\'espace a facturé';

  @override
  String get reportFieldMeaningStatusMembers =>
      'Les lignes par adhérent — une boucle';

  @override
  String get reportFieldMeaningStatusNet => 'Recettes moins dépenses';

  @override
  String get reportFieldMeaningStatusPayments => 'Ce qui a été encaissé';

  @override
  String get reportFieldMeaningStatusReimbursed => 'Ce qui a été remboursé';

  @override
  String get reportFieldMeaningStatusRepartitioned => 'Ce qui a été réparti';

  @override
  String get reportFieldMeaningStatusTo =>
      'Le dernier jour de la période de situation';

  @override
  String get reportFieldMeaningTotal => 'Le montant dû, tout compris';

  @override
  String get reportFieldMeaningUsageExtraHalfDays =>
      'Demi-journées au-delà de l\'abonnement';

  @override
  String get reportFieldMeaningUsageIncludedHalfDays =>
      'Demi-journées incluses dans l\'abonnement';

  @override
  String get reportFieldMeaningUsageOverage => 'Le dépassement facturé';

  @override
  String get reportFieldMeaningUsagePaid =>
      'Ce que la consommation du mois a coûté';

  @override
  String get reportFieldMeaningUsageRecords =>
      'Chaque enregistrement de consommation — une boucle';

  @override
  String get reportFieldMeaningUsageRemainingHalfDays =>
      'Demi-journées restantes';

  @override
  String get reportFieldMeaningUsageSites =>
      'Les autres sites fréquentés dans le mois';

  @override
  String get reportFieldMeaningUsageSupplements =>
      'Les suppléments d\'accessoires';

  @override
  String get reportFieldMeaningUsageUsedHalfDays => 'Demi-journées consommées';

  @override
  String get reportFieldMeaningVat => 'La TVA par taux — une boucle';

  @override
  String get reportFieldMeaningVatBasisNote =>
      'Si la période compte l\'encaissé ou l\'émis';

  @override
  String get reportFieldMeaningVatExigibilityMention =>
      'Quand la TVA est exigible, en toutes lettres';

  @override
  String get reportFieldMeaningVatPeriod => 'La période de TVA déclarée';

  @override
  String get reportFieldMeaningVatPeriodGross => 'Le total TTC de la période';

  @override
  String get reportFieldMeaningVatPeriodNet =>
      'Le total hors taxe de la période';

  @override
  String get reportFieldMeaningVatPeriodVat => 'La TVA de la période';

  @override
  String get reportFieldMeaningVatPositions =>
      'Chaque facture de la période de TVA — une boucle';

  @override
  String get reportFieldMeaningVatRateTotals =>
      'Les totaux de la période par taux — une boucle';

  @override
  String get reportFieldMeaningVatTotal => 'Le total de TVA';

  @override
  String get reportFieldMeaningVoided => 'Vrai quand la facture est annulée';

  @override
  String get reportFieldMeaningWorkspace => 'Le nom de l\'espace';

  @override
  String get reportFieldMeaningWorkspaceAddress =>
      'L\'adresse de l\'espace, ou celle du site du document';

  @override
  String get reportGuideInsertField => 'Insérer un champ…';

  @override
  String reportGuideInsertedInto(String band) {
    return 'Inséré dans $band';
  }

  @override
  String get reportGuideIntro =>
      'Trois bandes composent le PDF : en-tête, corps, pied. Écrivez du texte, placez un champ là où va une valeur, et un signe de balisage en début de ligne pour son style. Le XML de facture électronique n\'est jamais modifié.';

  @override
  String get reportGuideMarkupTitle => 'Balisage de ligne';

  @override
  String get reportGuideSnippetIf => 'Une ligne seulement si la valeur existe';

  @override
  String get reportGuideSnippetLoop => 'Une ligne par ligne de facture';

  @override
  String get reportGuideSnippetTitle => 'Le titre : facture, avoir ou proforma';

  @override
  String get reportGuideSnippetsTitle => 'Morceaux prêts à l\'emploi';

  @override
  String get reportGuideTitle => 'Champs et balisage';

  @override
  String get reportImageAlign => 'Alignement';

  @override
  String get reportImageAlignCenter => 'Centre';

  @override
  String get reportImageAlignLeft => 'Gauche';

  @override
  String get reportImageAlignRight => 'Droite';

  @override
  String get reportImageSize => 'Taille';

  @override
  String get reportImageSizeLarge => 'Grande';

  @override
  String get reportImageSizeMedium => 'Moyenne';

  @override
  String get reportImageSizeSmall => 'Petite';

  @override
  String get reportImageUpload => 'Téléverser une image';

  @override
  String get reportImagesEmpty =>
      'Aucune image — téléversez votre logo, un tampon ou une signature et référencez-la avec ![nom].';

  @override
  String get reportImagesLoadFailed =>
      'Impossible de charger les images des rapports. Réessayez.';

  @override
  String get reportImagesTitle => 'Images des rapports';

  @override
  String get reportInsertImage => 'Insérer une image';

  @override
  String get reportLanguageAmbiguous =>
      'Ce pays a plusieurs langues — définissez d\'abord la langue de l\'espace dans les Réglages de l\'espace.';

  @override
  String get reportLayoutActive => 'Maquette active';

  @override
  String get reportLayoutBands => 'Bandes';

  @override
  String get reportLayoutExport => 'Exporter le XML';

  @override
  String get reportLayoutFileTypeLabel => 'XML';

  @override
  String get reportLayoutImport => 'Importer un XML';

  @override
  String get reportLayoutImported =>
      'Maquette importée. Enregistrez pour la conserver.';

  @override
  String get reportLayoutPreview => 'Aperçu de la page';

  @override
  String get reportLayoutRemove => 'Supprimer la maquette (bandes)';

  @override
  String get reportLayoutSubtitle =>
      'Une maquette indique où se place chaque élément, en mm, cm, px ou %. Exportez-la, modifiez-la, vérifiez-la avec `dart run tool/report.dart check`, réimportez-la. Quand une maquette existe, c\'est elle qui s\'imprime ; supprimez-la et les bandes s\'impriment à nouveau.';

  @override
  String get reportLayoutTitle => 'Maquette positionnée (XML)';

  @override
  String get reportLineBoldRow => 'Ligne en gras';

  @override
  String get reportLineColumns => 'Début/fin de colonnes';

  @override
  String get reportLineColumnsSplit => 'Saut de colonne';

  @override
  String get reportLineDivider => 'Séparateur';

  @override
  String get reportLineImage => 'Image';

  @override
  String get reportLineLogic => 'Logique';

  @override
  String get reportLineRow => 'Ligne de tableau';

  @override
  String get reportLineSection => 'Section';

  @override
  String get reportLineSmall => 'Petit texte';

  @override
  String get reportLineSpacer => 'Espacement';

  @override
  String get reportLineText => 'Texte';

  @override
  String get reportLineTitle => 'Titre';

  @override
  String get reportMarkupBoldRow => 'Une ligne de tableau en gras';

  @override
  String get reportMarkupColumns =>
      'Des colonnes côte à côte, séparées par |||';

  @override
  String get reportMarkupHeading => 'Un grand titre';

  @override
  String get reportMarkupImage =>
      'Une image de la bibliothèque : taille s/m/l, alignement left/center/right';

  @override
  String get reportMarkupRule => 'Un filet horizontal';

  @override
  String get reportMarkupSection => 'Un titre de section';

  @override
  String get reportMarkupSmall => 'Petit texte discret';

  @override
  String get reportMarkupTable => 'Une ligne de tableau, une cellule par |';

  @override
  String get reportPaymentsPeriodTotal => 'Paiements de la période';

  @override
  String get reportPendingExpenses => 'Dépenses en attente';

  @override
  String get reportPendingPayments => 'Paiements en attente';

  @override
  String get reportPresetClassic => 'Classique';

  @override
  String get reportPresetFormalLetter => 'Lettre formelle';

  @override
  String get reportPresetProfessional => 'Professionnel';

  @override
  String get reportPresetSimple => 'Simple';

  @override
  String get reportPresetVerbose => 'Détaillé';

  @override
  String get reportPreviewFit => 'Ajuster à la largeur';

  @override
  String get reportPreviewSimulated => 'Aperçu rapide — données d\'exemple';

  @override
  String get reportPreviewTitle =>
      'Aperçu rapide — votre facture la plus récente';

  @override
  String get reportPreviewZoomIn => 'Agrandir';

  @override
  String get reportPreviewZoomOut => 'Réduire';

  @override
  String get reportQuickView => 'Aperçu rapide';

  @override
  String get reportRegards => 'Cordialement';

  @override
  String get reportSectionFeatures => 'Fonctionnalités';

  @override
  String get reportSectionPrices => 'Tarifs';

  @override
  String get reportSpaceCodesFooter =>
      'Une carte qui ne correspond plus à son espace trompe celui qui la scanne : réimprimez la planche après avoir déplacé ou renommé un espace.';

  @override
  String get reportSpaceCodesIntro =>
      'Une carte par place, table, bureau et étage. Collez chaque carte sur son espace : la scanner ouvre la feuille que montre la borne.';

  @override
  String get reportSpaceCodesTitle => 'Codes des espaces';

  @override
  String get reportSubject => 'Objet';

  @override
  String get reportTemplateClearOverlay =>
      'Utiliser le défaut pour cette langue';

  @override
  String get reportTemplateLangDefault => 'Par défaut (toutes langues)';

  @override
  String get reportTemplateLangInherits => 'Hérite du défaut';

  @override
  String get reportTemplateLangOverridden => 'Modèle propre';

  @override
  String get reportTextsAdd => 'Ajouter un texte';

  @override
  String get reportTextsHint =>
      'Vos propres formulations, placées dans n\'importe quelle bande ou maquette avec text.cle. Chaque langue peut porter sa valeur ; une valeur vide reprend celle de la langue par défaut.';

  @override
  String get reportTextsInherited => 'Langue par défaut';

  @override
  String get reportTextsKey => 'Clé';

  @override
  String get reportTextsKeyExists => 'Cette clé existe déjà.';

  @override
  String get reportTextsKeyHint =>
      'Lettres, chiffres et tirets bas, ex. formule';

  @override
  String get reportTextsKeyInvalid =>
      'Lettres, chiffres et tirets bas uniquement, en commençant par une lettre.';

  @override
  String get reportTextsRemove => 'Supprimer le texte';

  @override
  String get reportTextsTitle => 'Textes';

  @override
  String get reportVisualAddLine => 'Ajouter une ligne';

  @override
  String get requestAccept => 'Accepter';

  @override
  String get requestBlock => 'Bloquer';

  @override
  String get requestIgnore => 'Ignorer';

  @override
  String get reservationCalendarFileButton =>
      'Enregistrer le fichier calendrier';

  @override
  String get reservationCalendarFileContents => 'Contenu du fichier';

  @override
  String get reservationCalendarFileEvent => 'Événement';

  @override
  String get reservationCalendarFileLocation => 'Lieu';

  @override
  String get reservationCalendarFileName => 'Fichier';

  @override
  String get reservationCalendarFileRefused =>
      'Cette réservation ne peut pas être exportée : elle n’est pas la vôtre, ou elle n’existe plus.';

  @override
  String get reservationCalendarFileSnapshotNote =>
      'Ce fichier est un instantané de la réservation telle qu’elle est maintenant. Si elle est déplacée ou annulée plus tard, un fichier déjà enregistré ou partagé ne change pas — et un fichier partagé ne peut pas être repris.';

  @override
  String get reservationCalendarFileStale =>
      'La réservation a changé depuis cet aperçu. Vérifiez-la à nouveau avant d’enregistrer.';

  @override
  String get reservationCalendarFileStatus => 'Statut';

  @override
  String get reservationCalendarFileStatusCancelled => 'Annulée';

  @override
  String get reservationCalendarFileStatusConfirmed => 'Confirmée';

  @override
  String get reservationCalendarFileTitle => 'Fichier calendrier';

  @override
  String get reservationCalendarFileWhen => 'Quand';

  @override
  String get reservationCancelledSnack => 'Réservation annulée.';

  @override
  String get reservationDeleteReasonLabel => 'Motif (facultatif)';

  @override
  String get reservationDeleteRequestButton => 'Demander la suppression';

  @override
  String get reservationDeleteRequestExplain =>
      'Les réservations passées ou pointées ne sont pas supprimées directement. Un propriétaire ou un admin décidera : le pointage a-t-il simplement été oublié (la réservation reste), ou n\'a-t-elle jamais été utilisée (elle est supprimée) ?';

  @override
  String get reservationDeleteSubmit => 'Envoyer la demande';

  @override
  String get reservationDeleteSubmitted =>
      'Suppression demandée — un propriétaire ou un admin décidera.';

  @override
  String get reservationEditTimes => 'Modifier l\'horaire';

  @override
  String get reservationEndEarlyAheadOnly =>
      'Choisissez une heure encore à venir et avant la fin actuelle.';

  @override
  String get reservationEndEarlyButton => 'Terminer plus tôt';

  @override
  String get reservationExtendButton => 'Rester plus longtemps';

  @override
  String get reservationExtendLaterOnly =>
      'Choisissez une heure après la fin actuelle.';

  @override
  String get reservationLimitError =>
      'Limite de réservations atteinte — vous détenez déjà le maximum de réservations ouvertes.';

  @override
  String reservationNoteCheckedOutAt(String time) {
    return 'Terminée : départ enregistré à $time.';
  }

  @override
  String get reservationNoteOverNotCheckedIn =>
      'Cette période est terminée sans arrivée enregistrée.';

  @override
  String get reservationNoteRecordedAfterEnd =>
      'Enregistrée après la fin de cette période : conservée comme une visite passée.';

  @override
  String get reservationRecurring => 'Réservation récurrente';

  @override
  String get reservationUpdatedSnack => 'Réservation mise à jour.';

  @override
  String get reserveAvailabilityUnavailable =>
      'La disponibilité n\'a pas pu être chargée en entier : aucune place n\'est affichée comme libre. Réessayez.';

  @override
  String get reserveBackToNow => 'Revenir à maintenant';

  @override
  String get reserveBookingFailed =>
      'Réservation impossible — la place vient peut-être d\'être prise.';

  @override
  String get reserveClosedShort => 'Fermé';

  @override
  String get reserveDayView => 'Jour';

  @override
  String get reserveFullDayChip => 'Journée entière';

  @override
  String get reserveMonthView => 'Mois';

  @override
  String get reservePickDateTooltip => 'Choisir une date';

  @override
  String reserveStaleAvailability(String time) {
    return 'Hors ligne — disponibilités au $time. Une place affichée libre a pu être prise depuis.';
  }

  @override
  String get reserveStaleRetry => 'Réessayer';

  @override
  String get reserveViewMenu => 'Vue';

  @override
  String get reserveWeekView => 'Semaine';

  @override
  String get reverseChargeSubtitle =>
      'Un client titulaire d\'un numéro de TVA dans un autre État membre est facturé sans taxe et l\'autoliquide (art. 196). Désactivez si vous ne facturez jamais d\'entreprises à l\'étranger.';

  @override
  String get reverseChargeTitle =>
      'Autoliquidation pour les entreprises de l\'UE';

  @override
  String get rightsKindAccess => 'Obtenir une copie de mes données';

  @override
  String get rightsKindErasure => 'Effacer mes données';

  @override
  String get rightsKindObjection =>
      'M\'opposer à une utilisation de mes données';

  @override
  String get rightsKindPortability =>
      'Récupérer mes données (format lisible par machine)';

  @override
  String get rightsKindRectification => 'Rectifier mes données';

  @override
  String get rightsKindRestriction => 'Limiter l\'utilisation de mes données';

  @override
  String get rightsRequestAsk => 'Que demandez-vous à l\'espace ?';

  @override
  String get rightsRequestDetails => 'Précisions (facultatif)';

  @override
  String get rightsRequestFailed =>
      'La demande n\'a pas pu être envoyée. Veuillez réessayer.';

  @override
  String get rightsRequestNew => 'Faire une demande';

  @override
  String get rightsRequestSend => 'Envoyer la demande';

  @override
  String rightsRequestSent(String date) {
    return 'Demande envoyée — l\'espace répond d\'ici le $date.';
  }

  @override
  String get rightsRequestsEmpty => 'Aucune demande pour le moment.';

  @override
  String get rightsRequestsHint =>
      'Demandez à l\'espace une copie, une rectification, une limitation ou un effacement — réponse sous un mois calendaire.';

  @override
  String get rightsRequestsTitle => 'Mes demandes d\'exercice de droits';

  @override
  String get rightsStatusCompleted =>
      'Traitée — l\'espace a consigné ce qu\'il a fait';

  @override
  String rightsStatusExtended(String date, String reason) {
    return 'Prolongée jusqu\'au $date : $reason';
  }

  @override
  String rightsStatusReceived(String date) {
    return 'Reçue — réponse due le $date';
  }

  @override
  String rightsStatusRefused(String reason) {
    return 'Refusée : $reason';
  }

  @override
  String get roleAdmin => 'Administrateur·rice';

  @override
  String get roleAssignImmediateHint => 'Prend effet immédiatement.';

  @override
  String get roleAssignNothing => 'Il ne reste aucun rôle à attribuer.';

  @override
  String get roleAssignQuorumHint => 'Prend effet une fois validé.';

  @override
  String roleAssignSheetTitle(String name) {
    return 'Attribuer un rôle à $name';
  }

  @override
  String get roleBuiltInNote =>
      'Intégré. Ce qu\'il permet se règle dans Rôles ; il s\'attribue sur la page de chaque membre et prend effet une fois validé.';

  @override
  String get roleBuiltInSubtitle =>
      'Intégré. Ce qu\'il permet se règle dans Rôles.';

  @override
  String get roleEditorActive => 'En usage';

  @override
  String get roleEditorHolders => 'Membres ayant ce rôle';

  @override
  String get roleEditorKey => 'Clé';

  @override
  String get roleEditorKeyHelp =>
      'Minuscules, chiffres et tirets bas. Elle ne change jamais : les personnes qui tiennent le rôle s\'y rattachent.';

  @override
  String roleEditorNameFor(String locale) {
    return 'Nom ($locale)';
  }

  @override
  String get roleEditorNobody => 'Personne pour l\'instant.';

  @override
  String get roleEditorNotYourself =>
      'Vous ne pouvez pas vous attribuer un rôle.';

  @override
  String get roleEditorPermissions => 'Ce qu\'il ajoute';

  @override
  String get roleEditorSave => 'Enregistrer le rôle';

  @override
  String get roleEditorSaveFailed => 'Le rôle n\'a pas été enregistré.';

  @override
  String get roleGiveFailed => 'Le rôle n\'a pas été attribué.';

  @override
  String get roleGiven => 'Rôle attribué.';

  @override
  String get roleHoldersAdd => 'Ajouter un membre';

  @override
  String get roleMember => 'Tous les membres';

  @override
  String get roleOwner => 'Propriétaire';

  @override
  String get roleRefusalExceedsYours =>
      'Ce rôle permet des choses que vous ne pouvez pas faire : seul le propriétaire l\'attribue.';

  @override
  String get roleRefusalNotAssignable => 'Ce membre ne peut pas avoir ce rôle.';

  @override
  String get roleRefusalNotPermitted =>
      'Seule une personne qui gère les rôles peut attribuer celui-ci.';

  @override
  String get roleRefusalOwnerOnly =>
      'Seul le propriétaire attribue un rôle qui gère les rôles.';

  @override
  String get roleRenameAdministrator => 'Renommer';

  @override
  String get roleTakeBackFailed => 'Le rôle n\'a pas été retiré.';

  @override
  String get roleTakenBack => 'Rôle retiré.';

  @override
  String get rolesIntroEditor =>
      'Chacun a exactement un rôle de base — Utilisateur, Administrateur, Copropriétaire ou Propriétaire. Tout autre rôle ajoute ce que ses titulaires peuvent faire et ne retire jamais rien. Le propriétaire détient toujours toutes les permissions ; un copropriétaire peut en détenir moins.';

  @override
  String get rolesIntroReadOnly =>
      'Lecture seule : voici les permissions de chaque rôle. Votre rôle est mis en évidence.';

  @override
  String get rolesOfSpaceAdd => 'Ajouter un rôle';

  @override
  String get rolesOfSpaceEmpty => 'Aucun rôle pour l\'instant.';

  @override
  String get rolesOfSpaceInactive => 'Mis de côté';

  @override
  String get rolesOfSpaceSubtitle =>
      'Chacun ajoute des permissions à ce que ses titulaires peuvent déjà faire. Aucun ne retire rien, et le propriétaire garde toujours toutes les permissions.';

  @override
  String get rolesOfSpaceTitle => 'Les rôles de cet espace';

  @override
  String get rolesOwnRolesLink => 'Les rôles de cet espace';

  @override
  String get rolesTitle => 'Rôles';

  @override
  String get rolesYourRole => 'Votre rôle';

  @override
  String get saftDocumentsOnly => 'Documents seuls';

  @override
  String get saftLedgerIntro =>
      'Avec les numéros de comptes, le fichier porte des écritures en partie double que votre comptable peut importer au lieu de les saisir. Elles couvrent vos ventes et les règlements correspondants — pas l’ensemble de votre comptabilité.';

  @override
  String get saftLedgerTitle => 'Inclure les écritures ?';

  @override
  String get saftWithPostings => 'Avec les écritures';

  @override
  String get sageAccountsIntro =>
      'Les valeurs par défaut sont les comptes livrés par Sage. Le code de TVA détermine sur quelle déclaration ces écritures arrivent : vérifiez-le avec votre comptable si vous n’êtes pas au taux normal.';

  @override
  String get sageAccountsTitle => 'Export Sage';

  @override
  String get sageTaxCode => 'Code TVA (T1 / T0 / T9)';

  @override
  String get scanCameraWebUnavailable =>
      'Le scan par caméra n\'est pas disponible dans le navigateur — saisissez le code, ou approchez un tag NFC de l\'appareil (Chrome sur Android).';

  @override
  String get scanJoinHelp =>
      'Visez le QR d’invitation avec la caméra — vous voyez l’espace avant d’adhérer.';

  @override
  String get scanJoinNotAnInvite =>
      'Ce QR n’est pas une invitation DesKilo — scannez celui du message d’invitation.';

  @override
  String get scanJoinTitle => 'Scanner le QR de l\'espace';

  @override
  String get scheduleCancel => 'Terminer cette programmation';

  @override
  String get scheduleDaily => 'quotidienne';

  @override
  String get scheduleEndsOn => 'Jusqu\'au (facultatif)';

  @override
  String scheduleEveryDays(Object count) {
    return 'tous les $count jours';
  }

  @override
  String get scheduleEveryLabel => 'Tous les';

  @override
  String scheduleEveryMonths(Object count) {
    return 'tous les $count mois';
  }

  @override
  String scheduleEveryWeeks(Object count) {
    return 'toutes les $count semaines';
  }

  @override
  String get scheduleMissingFields => 'Le nom et le montant sont requis.';

  @override
  String get scheduleMonthly => 'mensuelle';

  @override
  String get scheduleNew => 'Programmer une dépense récurrente';

  @override
  String scheduleNextDue(Object date) {
    return 'prochaine : $date';
  }

  @override
  String get scheduleNoEnd => 'Pas de date de fin';

  @override
  String get schedulePending =>
      'Programmé — en attente de la confirmation des validateurs.';

  @override
  String get scheduleStartsOn => 'Première échéance';

  @override
  String get scheduleStatusActive => 'Active';

  @override
  String get scheduleStatusEnded => 'Terminée';

  @override
  String get scheduleStatusPending => 'En attente de validation';

  @override
  String get scheduleStatusRejected => 'Rejetée';

  @override
  String get scheduleSubmit => 'Programmer';

  @override
  String scheduleTimes(Object count) {
    return '$count fois';
  }

  @override
  String get scheduleTimesLabel =>
      'Répétitions (vide = jusqu\'à la date de fin)';

  @override
  String get scheduleTitleLabel => 'Quoi (ex. Internet)';

  @override
  String get scheduleUnitDays => 'jours';

  @override
  String get scheduleUnitLabel => 'Unité';

  @override
  String get scheduleUnitMonths => 'mois';

  @override
  String get scheduleUnitWeeks => 'semaines';

  @override
  String get scheduleUnitYears => 'ans';

  @override
  String scheduleUntil(Object date) {
    return 'jusqu\'au $date';
  }

  @override
  String get scheduleValidationHint =>
      'La programmation passe d\'abord par les validateurs. Chaque échéance vous est ensuite présentée : confirmée à ce montant, elle compte immédiatement ; un montant différent s\'explique et repasse en validation.';

  @override
  String get scheduleWeekly => 'hebdomadaire';

  @override
  String get scheduleYearly => 'annuelle';

  @override
  String get scheduledAwaitingTitle => 'Dépenses programmées à confirmer';

  @override
  String get scheduledExpensesEmpty =>
      'Aucune dépense programmée pour le moment.';

  @override
  String scheduledExpensesFinished(int count) {
    return 'Terminées et refusées ($count)';
  }

  @override
  String get scheduledExpensesIntro =>
      'Les abonnements que l\'espace paie — internet, téléphone, électricité. La programmation est validée une fois ; chaque échéance vous est présentée avant de compter.';

  @override
  String get scheduledExpensesTitle => 'Dépenses programmées';

  @override
  String schemaUpdateBody(int version) {
    return 'Cette application a besoin de la version $version du schéma DesKilo, et le serveur auquel elle se connecte en exécute une plus ancienne. Tant que le serveur n\'est pas mis à jour, l\'application échouerait sans pouvoir expliquer pourquoi : elle s\'arrête donc ici.';
  }

  @override
  String get schemaUpdateMember =>
      'Sinon : prévenez la personne qui gère votre espace. Rien de ce que vous avez saisi n\'est perdu.';

  @override
  String get schemaUpdateOperator =>
      'Si vous gérez ce serveur : appliquez les migrations manquantes avec `dart run tool/instance.dart install --ref <projet>`. Seul ce qui manque est exécuté.';

  @override
  String get schemaUpdateRetry => 'Vérifier à nouveau';

  @override
  String get schemaUpdateServer => 'Réglages du serveur';

  @override
  String get schemaUpdateTitle => 'Ce serveur doit être mis à jour';

  @override
  String get seatDayAhead => 'À venir';

  @override
  String get seatDayFree => 'Libre — réserver';

  @override
  String get seatDayMine => 'Vous';

  @override
  String get seatDayNow => 'En cours';

  @override
  String get seatDayPast => 'Terminé';

  @override
  String get seatDaySomeone => 'Un membre';

  @override
  String get seatDaySubtitle =>
      'Qui occupe cette place, et quand. Touchez une réservation pour l\'ouvrir, ou une plage libre pour la prendre.';

  @override
  String seatDayTitle(String seat) {
    return 'Place $seat aujourd\'hui';
  }

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
  String get serviceOutOfStock => 'Épuisé';

  @override
  String get serviceOutOfStockHint =>
      'Plus rien sur l\'étagère — la prochaine fourniture le réapprovisionne.';

  @override
  String serviceStockCount(int count) {
    return '$count en stock';
  }

  @override
  String get servicesActive => 'Actif';

  @override
  String get servicesEdit => 'Modifier le service';

  @override
  String get servicesEmpty => 'Aucun service pour l’instant.';

  @override
  String get servicesInactive => 'Inactif';

  @override
  String get servicesName => 'Nom';

  @override
  String get servicesNew => 'Nouveau service';

  @override
  String get servicesPrice => 'Prix';

  @override
  String get servicesTitle => 'Services';

  @override
  String get settingsBillingReports => 'Facturation & rapports';

  @override
  String get settingsFrontCamera => 'Scanner avec la caméra avant';

  @override
  String get settingsFrontCameraDesc =>
      'Les badges sont lus avec la caméra côté écran — désactivez pour utiliser la caméra arrière.';

  @override
  String get settingsSectionAccount => 'Mon compte';

  @override
  String get settingsSectionAdministration => 'Administration';

  @override
  String get settingsSectionAdvanced => 'Avancé';

  @override
  String get settingsSectionGovernance => 'Gouvernance';

  @override
  String get settingsSectionHelpAbout => 'Aide et à propos';

  @override
  String get settingsSectionMembership => 'Mon adhésion';

  @override
  String get settingsSectionWorkspace => 'Cet espace';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settlementAction => 'Regrouper en une facture';

  @override
  String get settlementAnnexAlone => 'Cette facture seule';

  @override
  String settlementAnnexBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Les $count factures que celle-ci remplace peuvent la suivre, chacune sur ses propres pages et tamponnée comme regroupée.',
      one: 'La facture que celle-ci remplace peut la suivre, sur ses propres pages et tamponnée comme regroupée.',
    );
    return '$_temp0';
  }

  @override
  String get settlementAnnexTitle => 'Joindre les factures regroupées ?';

  @override
  String get settlementAnnexWith => 'Les joindre';

  @override
  String settlementConfirm(int count, String amount) {
    return 'Regrouper $count factures en une seule de $amount ?';
  }

  @override
  String get settlementDocumentationOnly =>
      'Documentation uniquement — toute opération se fait sur la facture de regroupement.';

  @override
  String settlementDone(String number) {
    return 'Regroupées dans $number.';
  }

  @override
  String settlementFoldedIn(String number) {
    return 'Regroupée dans $number';
  }

  @override
  String get settlementNeedsTwo =>
      'Choisissez au moins deux factures ouvertes du même membre.';

  @override
  String settlementPaidThrough(String number) {
    return 'Payée via $number';
  }

  @override
  String get settlementRegroups => 'Cette facture regroupe';

  @override
  String settlementRegroupsNumbers(String numbers) {
    return 'Regroupe $numbers';
  }

  @override
  String get settlementSettledBy =>
      'Regroupée dans une autre facture — c’est celle-là qui est due et relancée.';

  @override
  String get settlementSourcePdf => 'PDF (regroupée)';

  @override
  String get settlementStepPick => 'Choisir les factures';

  @override
  String get settlementSummaryHint =>
      'Ces factures sont regroupées dans un document de règlement ; chacune reste lisible derrière lui.';

  @override
  String get settlementVatNote =>
      'Les lignes et leur TVA sont reprises des factures regroupées ; la déclaration de TVA compte les originales une seule fois.';

  @override
  String get shellBarHiddenAnnounce => 'Barre de navigation masquée';

  @override
  String get shellBarHideHint => 'Appui long pour l’affichage plein écran';

  @override
  String get shellBarShowHint =>
      'Appui long pour afficher la barre de navigation';

  @override
  String get shellBarShownAnnounce => 'Barre de navigation affichée';

  @override
  String shellPendingDecisions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count décisions vous attendent',
      one: '1 décision vous attend',
    );
    return '$_temp0';
  }

  @override
  String get shellReserveButton => 'Réserver';

  @override
  String get shellSwipeCoachMark =>
      'Balayez la barre vers le bas pour l\'affichage plein écran. Balayez vers le haut, ou appuyez longuement sur le bouton Réserver, pour la faire revenir.';

  @override
  String get siteCity => 'Ville';

  @override
  String get siteCountry => 'Pays (code)';

  @override
  String get siteDelete => 'Supprimer ce site';

  @override
  String get siteDeleteHint =>
      'Ses étages et ses adhérents reviennent au site par défaut.';

  @override
  String get siteExemptionReason => 'Mention d\'exonération (cette entité)';

  @override
  String get siteLegalId => 'SIRET de l\'établissement';

  @override
  String get siteName => 'Nom du site';

  @override
  String get sitePostalCode => 'Code postal';

  @override
  String get siteRegistrationHint =>
      'Seulement si le site est une entité juridique distincte — c\'est en général un espace séparé. Vide : les numéros de l\'espace s\'appliquent.';

  @override
  String get siteSaved => 'Site enregistré.';

  @override
  String get siteStreet => 'Rue';

  @override
  String get siteVatId => 'Numéro de TVA (cette entité)';

  @override
  String get sitesAdd => 'Ajouter un site';

  @override
  String get sitesDefault => 'Site par défaut';

  @override
  String get sitesIntro =>
      'Chaque étage appartient à un site ; le site par défaut porte l\'adresse de l\'espace. Un adhérent a un site de rattachement : c\'est son adresse sur ses documents.';

  @override
  String get sitesLevels => 'Étages';

  @override
  String get sitesSubtitle =>
      'Adresses, étages de chaque site, et site de rattachement de chacun';

  @override
  String get sitesTitle => 'Sites';

  @override
  String get spaceAlreadyCheckedInHere =>
      'Vous êtes déjà pointé ici. Choisissez « Pointer la sortie » pour libérer la place.';

  @override
  String get spaceBackToMe => 'Retour à Moi';

  @override
  String get spaceBlockedByYou =>
      'Vous détenez déjà cet espace pour cette période.';

  @override
  String get spaceCardInfoLabel => 'Informations sur la carte';

  @override
  String get spaceCardInfoWorkspace => 'Espace de travail';

  @override
  String get spaceCardSizeLabel => 'Taille de la carte';

  @override
  String get spaceCardSizeLarge => 'Grande';

  @override
  String get spaceCardSizeMedium => 'Moyenne';

  @override
  String get spaceCardSizeSmall => 'Petite';

  @override
  String get spaceChipTooltip => 'Changer d\'espace';

  @override
  String get spaceCodesDesc =>
      'Une carte QR imprimable par poste, table, bureau et niveau — les membres la scannent pour réserver ou pointer.';

  @override
  String get spaceCodesTitle => 'Codes QR des espaces (PDF)';

  @override
  String get spaceFavoriteAdd => 'Ajouter aux favoris';

  @override
  String get spaceFavoriteRemove => 'Retirer des favoris';

  @override
  String get spaceKindDesk => 'Table';

  @override
  String get spaceKindLevel => 'Niveau';

  @override
  String get spaceKindOffice => 'Bureau';

  @override
  String get spaceKindSeat => 'Poste';

  @override
  String get spaceManageMyBooking => 'Gérer ma réservation';

  @override
  String spaceMessageReserver(String name) {
    return 'Écrire à $name';
  }

  @override
  String get spaceMoveDown => 'Descendre';

  @override
  String get spaceMoveUp => 'Monter';

  @override
  String get spaceNotBookable =>
      'Cet espace n\'est pas configuré pour les réservations entières.';

  @override
  String get spaceNotWholeBookable =>
      'Cet espace n\'est pas configuré pour la réservation entière — le propriétaire active « Réservable en entier » dessus dans l\'éditeur.';

  @override
  String spaceOptions(String name) {
    return 'Options pour $name';
  }

  @override
  String get spaceQrSizeLabel => 'Taille du code QR';

  @override
  String get spaceRatingClear => 'Aucune note';

  @override
  String get spaceScanField => 'Code';

  @override
  String get spaceScanHint =>
      'Visez la carte d\'un poste, d\'une table, d\'un bureau ou d\'un niveau — ou saisissez son code.';

  @override
  String get spaceScanInvalid =>
      'Ce n\'est pas un code d\'espace de cet espace de travail.';

  @override
  String get spaceScanNfcHint =>
      '…ou approchez le téléphone du tag NFC d\'une chaise.';

  @override
  String get spaceScanTitle => 'Scanner un code d\'espace';

  @override
  String get spaceScanUnknown =>
      'Ce code ne correspond plus à aucun espace ici.';

  @override
  String get spaceScanUnknownTag => 'Ce tag n\'est associé à aucune chaise.';

  @override
  String get spaceSeatTaken => 'Occupée';

  @override
  String get spaceYoursCheckedIn => 'Vous êtes arrivé ici pour ce créneau.';

  @override
  String get spaceYoursNow => 'Réservé par vous pour ce créneau.';

  @override
  String get statusAwaiting => 'En attente';

  @override
  String get statusCreditNotes => 'Avoirs';

  @override
  String get statusCredits => 'Crédits accordés';

  @override
  String get statusFrom => 'Du';

  @override
  String get statusInvoiced => 'Facturé';

  @override
  String get statusMembers => 'Adhérents';

  @override
  String get statusNet => 'Net';

  @override
  String get statusNetExplanation =>
      'Ce sous-total correspond aux montants facturés moins les avoirs, remboursements et crédits. Ce n’est ni un bénéfice ni un solde bancaire. Les paiements rapprochés et reçus se recoupent et ne doivent pas être additionnés.';

  @override
  String get statusPaymentsMatched => 'Paiements lettrés';

  @override
  String get statusPaymentsReceived => 'Paiements reçus';

  @override
  String get statusPrint => 'Imprimer la situation';

  @override
  String get statusReimbursed => 'Dépenses remboursées';

  @override
  String get statusRepartitioned => 'Dépenses réparties';

  @override
  String get statusSubtitle =>
      'Recettes, dépenses et adhérents sur une période';

  @override
  String get statusTitle => 'Situation de l\'espace';

  @override
  String get statusTo => 'Au';

  @override
  String get subprocessAttendance => 'Présence et utilisation';

  @override
  String get subprocessAttendanceDesc =>
      'Enregistrer la présence et clôturer les pointages en fin de journée.';

  @override
  String get subprocessAvailability => 'Jours et heures d’ouverture';

  @override
  String get subprocessAvailabilityDesc =>
      'Définir les horaires et générer les jours de fermeture.';

  @override
  String get subprocessCalendar => 'Vues du calendrier';

  @override
  String get subprocessCalendarDesc =>
      'Voir les réservations et décisions en attente dans le temps.';

  @override
  String get subprocessCollection => 'Encaissement';

  @override
  String get subprocessCollectionDesc =>
      'Encaisser les paiements et relancer les factures échues.';

  @override
  String get subprocessCommunication => 'Communication entre membres';

  @override
  String get subprocessCommunicationDesc =>
      'Échanger des messages et suivre les nouveautés.';

  @override
  String get subprocessConfiguration => 'Configuration et déploiement';

  @override
  String get subprocessConfigurationDesc =>
      'Transférer la configuration, utiliser des modèles et gérer les instances.';

  @override
  String get subprocessDecisions => 'Décisions et validations';

  @override
  String get subprocessDecisionsDesc =>
      'Examiner les actions et enregistrer les validations requises.';

  @override
  String get subprocessDelivery => 'Envoi externe';

  @override
  String get subprocessDeliveryDesc =>
      'Connecter les notifications push, WhatsApp et l’envoi de factures électroniques.';

  @override
  String get subprocessDocuments => 'Publication des documents';

  @override
  String get subprocessDocumentsDesc =>
      'Publier les documents et produire les fichiers imprimables.';

  @override
  String get subprocessExpenses => 'Dépenses partagées';

  @override
  String get subprocessExpensesDesc =>
      'Répartir les coûts, réapprovisionner et planifier les dépenses récurrentes.';

  @override
  String get subprocessExperience => 'Utilisation de l’application';

  @override
  String get subprocessExperienceDesc =>
      'Adapter l’aide, la navigation et les préférences d’affichage.';

  @override
  String get subprocessInvoicing => 'Facturation';

  @override
  String get subprocessInvoicingDesc =>
      'Émettre et suivre les factures immuables jusqu’au règlement.';

  @override
  String get subprocessPeople => 'Personnes et adhésions';

  @override
  String get subprocessPeopleDesc =>
      'Identifier les membres et gérer leurs adhésions et droits.';

  @override
  String get subprocessPhysicalAccess => 'Accès aux locaux';

  @override
  String get subprocessPhysicalAccessDesc =>
      'Utiliser les badges, les étiquettes des places et la borne partagée.';

  @override
  String get subprocessPresentation => 'Présentation des lieux';

  @override
  String get subprocessPresentationDesc =>
      'Aider les membres à reconnaître les personnes et lieux sur le plan.';

  @override
  String get subprocessPricing => 'Services et tarification';

  @override
  String get subprocessPricingDesc =>
      'Tarifer les services et accessoires et convenir des conditions des membres.';

  @override
  String get subprocessPrivacy => 'Accès aux données et exports';

  @override
  String get subprocessPrivacyDesc =>
      'Consulter les accès aux données personnelles et exporter les données.';

  @override
  String get subprocessRecords => 'Suivi financier';

  @override
  String get subprocessRecordsDesc =>
      'Comprendre les soldes, paiements et relevés des membres.';

  @override
  String get subprocessReportDesign => 'Conception des rapports';

  @override
  String get subprocessReportDesignDesc =>
      'Concevoir les rapports et gérer leurs textes et mises en page.';

  @override
  String get subprocessReservations => 'Réservation des postes et espaces';

  @override
  String get subprocessReservationsDesc =>
      'Réserver des places ou des espaces selon les règles de l’espace.';

  @override
  String get subprocessStructure => 'Structure des lieux';

  @override
  String get subprocessStructureDesc =>
      'Gérer les sites et la disponibilité des objets du plan.';

  @override
  String get subprocessTax => 'Gestion de la TVA';

  @override
  String get subprocessTaxDesc =>
      'Gérer les groupes, taux et déclarations de TVA.';

  @override
  String get supportChanged =>
      'Le contexte a changé. Préparez un nouvel aperçu.';

  @override
  String get supportDay => 'Dernières 24 heures';

  @override
  String get supportDemo => 'Démo : contexte local simulé';

  @override
  String get supportFailed => 'Impossible de préparer les détails. Réessayez.';

  @override
  String get supportHour => 'Dernière heure';

  @override
  String get supportPrepare => 'Préparer l’aperçu';

  @override
  String get supportPrivacy =>
      'Seuls les compteurs limités de cet appareil et les contrôles connus sont inclus. Identités, adresses serveur, identifiants, données métier et journaux bruts sont exclus. Les contrôles inconnus sont indisponibles ; un opérateur peut exécuter doctor --support-json séparément. Les fichiers partagés ne peuvent pas être révoqués.';

  @override
  String get supportSaved => 'Enregistré localement';

  @override
  String supportSize(int bytes) {
    final intl.NumberFormat bytesNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String bytesString = bytesNumberFormat.format(bytes);

    return 'Aperçu : $bytesString octets';
  }

  @override
  String get supportTitle => 'Détails pour l’assistance';

  @override
  String get symbolHint =>
      'Une pastille ronde d’une ou deux lettres sur une couleur, unique à cet espace — ou utilisez plutôt une photo ci-dessous.';

  @override
  String get symbolLetters => 'Lettres';

  @override
  String get symbolLettersRule =>
      'Utilisez une ou deux lettres ou chiffres pour le symbole.';

  @override
  String get symbolSaveFailed =>
      'Le symbole n’a pas pu être enregistré. Rien n’a changé.';

  @override
  String get symbolSaved => 'Symbole enregistré.';

  @override
  String get symbolTaken =>
      'Un autre espace utilise déjà ces lettres dans cette couleur. Choisissez une autre couleur ou d’autres lettres — ou utilisez une photo.';

  @override
  String get symbolTitle => 'Symbole';

  @override
  String get tabCalendar => 'Calendrier';

  @override
  String get tabEvents => 'Événements';

  @override
  String get tabMoney => 'Finances';

  @override
  String get tabPlan => 'Plan';

  @override
  String get taskExportActionBack => 'Revenez en arrière.';

  @override
  String get taskExportActionCancelReview =>
      'Annulez la vérification sans réserver.';

  @override
  String taskExportActionChangeField(String field) {
    return 'Modifiez le champ : $field.';
  }

  @override
  String get taskExportActionConfirmBooking => 'Confirmez la réservation.';

  @override
  String get taskExportActionOpenReserve => 'Ouvrez l\'écran Réserver.';

  @override
  String get taskExportActionSelectDate => 'Choisissez la date.';

  @override
  String get taskExportActionSelectPeriod => 'Choisissez la période.';

  @override
  String get taskExportActionSelectResource => 'Choisissez une place.';

  @override
  String get taskExportActionSwitchView => 'Changez de vue.';

  @override
  String get taskExportActionUnknown =>
      'Une action que cette version ne sait pas décrire.';

  @override
  String get taskExportActionViewDetails =>
      'Ouvrez le détail de la réservation.';

  @override
  String get taskExportAuthored =>
      'Ajouté lors de la modification : non observé par l\'enregistreur.';

  @override
  String get taskExportCompletenessComplete =>
      'Complet : l\'enregistrement a été arrêté par la personne et chaque commande a reçu une réponse.';

  @override
  String get taskExportCompletenessInterrupted =>
      'Interrompu : l\'application s\'est arrêtée pendant l\'enregistrement.';

  @override
  String get taskExportCompletenessPartial =>
      'Partiel : l\'enregistrement s\'est arrêté plus tôt ou une commande n\'a reçu aucune réponse.';

  @override
  String taskExportDetail(String field, String value) {
    return '$field : $value';
  }

  @override
  String get taskExportDocFallbackTitle => 'Procédure de tâche';

  @override
  String taskExportDuration(int minutes, int seconds) {
    return 'Durée : $minutes min $seconds s';
  }

  @override
  String get taskExportEndInterrupted =>
      'Arrêté parce que l\'application s\'est arrêtée.';

  @override
  String get taskExportEndLimitReached =>
      'Arrêté parce qu\'une limite d\'étapes, de taille ou de durée a été atteinte.';

  @override
  String get taskExportEndScopeChanged =>
      'Arrêté parce que le compte, l\'espace ou l\'installation a changé.';

  @override
  String get taskExportEndStopped =>
      'Arrêté par la personne qui l\'a enregistré.';

  @override
  String get taskExportEndStorageFailed =>
      'Arrêté parce que l\'écriture de l\'enregistrement a échoué.';

  @override
  String taskExportExcluded(String category) {
    return 'Un écran protégé a été visité ($category) ; rien n\'y a été enregistré.';
  }

  @override
  String get taskExportFieldAccessories => 'Accessoires';

  @override
  String get taskExportFieldCheckIn => 'Enregistrement de présence';

  @override
  String get taskExportFieldDateRelation => 'Date';

  @override
  String get taskExportFieldForWhom => 'Pour qui';

  @override
  String get taskExportFieldPeriod => 'Période';

  @override
  String get taskExportFieldRefusal => 'Motif';

  @override
  String get taskExportFieldRepeat => 'Répétition';

  @override
  String get taskExportFieldResourceKind => 'Type de place';

  @override
  String get taskExportFieldSeriesResult => 'Série';

  @override
  String get taskExportFieldTime => 'Heure';

  @override
  String get taskExportFieldUnknown =>
      'un champ que cette version ne sait pas décrire';

  @override
  String get taskExportFieldViewMode => 'Vue';

  @override
  String taskExportFooter(String page, String pages) {
    return 'Page $page sur $pages';
  }

  @override
  String get taskExportIllustrationNotApproved =>
      'Illustration non incluse : elle n\'a pas été approuvée.';

  @override
  String get taskExportIncludeIllustrations =>
      'Inclure les illustrations approuvées';

  @override
  String get taskExportIntro =>
      'Ce document décrit, étape par étape, une tâche enregistrée dans DesKilo. C\'est une documentation : il ne rejoue pas la tâche et ne prouve pas qu\'elle a réussi. Seul ce que l\'enregistrement a observé est présenté comme observé.';

  @override
  String get taskExportKindEdited =>
      'Procédure modifiée : issue d\'un enregistrement et modifiée par une personne.';

  @override
  String get taskExportKindSource =>
      'Capture originale : les étapes ont été observées par l\'enregistreur.';

  @override
  String get taskExportLimitEdited =>
      'Les étapes marquées comme ajoutées lors de la modification ont été écrites par une personne, pas observées.';

  @override
  String get taskExportLimitIncomplete =>
      'L\'enregistrement est incomplet : ce qui s\'est passé après la dernière étape affichée n\'est pas connu.';

  @override
  String get taskExportLimitNoIllustrations =>
      'Ce document ne contient aucune illustration.';

  @override
  String get taskExportLimitNotRunnable =>
      'Certaines étapes proviennent d\'une version plus récente et ne peuvent pas être décrites ici.';

  @override
  String get taskExportLimitRecreated =>
      'Les illustrations sont recréées à partir des faits sûrs de l\'enregistrement, avec des noms de places inventés ; ce ne sont pas des captures de l\'écran.';

  @override
  String get taskExportLimitValues =>
      'Les valeurs saisies ou choisies ne sont jamais enregistrées : seul leur type apparaît, et « non enregistré » remplace tout le reste.';

  @override
  String get taskExportNoResult =>
      'Aucun résultat n\'a été enregistré pour cette commande.';

  @override
  String taskExportNote(String note) {
    return 'Note écrite par la personne qui a enregistré (ses propres mots) : $note';
  }

  @override
  String get taskExportNoteOmitted =>
      'Une note personnelle a été exclue de ce document.';

  @override
  String taskExportOnScreen(String screen) {
    return 'Écran : $screen';
  }

  @override
  String get taskExportOutcomeConfirmed => 'la réservation a été confirmée';

  @override
  String get taskExportOutcomeRefused => 'la réservation a été refusée';

  @override
  String get taskExportOutcomeRequested =>
      'la réservation a été demandée et attend une décision';

  @override
  String get taskExportOutcomeSeriesBooked => 'la série a été réservée';

  @override
  String get taskExportOutcomeUnknown =>
      'aucune réponse n\'a pu être confirmée ; le résultat est inconnu';

  @override
  String get taskExportOutcomeUnregistered =>
      'un résultat que cette version ne sait pas décrire';

  @override
  String taskExportPauses(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pauses',
      one: 'Une pause',
      zero: 'Aucune pause',
    );
    return '$_temp0';
  }

  @override
  String taskExportPlatform(String platform) {
    return 'Enregistré sur : $platform';
  }

  @override
  String get taskExportPrereqBookablePlace =>
      'Au moins une place peut être réservée.';

  @override
  String get taskExportPrereqSignedIn => 'Vous êtes connecté.';

  @override
  String taskExportPrereqStartsOn(String screen) {
    return 'Commencez sur $screen.';
  }

  @override
  String get taskExportPrereqUnknown =>
      'Une condition que cette version ne sait pas décrire.';

  @override
  String get taskExportPrereqWorkspaceMember =>
      'Vous êtes membre de l\'espace.';

  @override
  String get taskExportProtectedAuthentication => 'connexion';

  @override
  String get taskExportProtectedIdentity => 'identité';

  @override
  String get taskExportProtectedMessenger => 'messages';

  @override
  String get taskExportProtectedOperator => 'opérateur';

  @override
  String get taskExportProtectedPayment => 'paiement';

  @override
  String get taskExportProtectedProvider => 'fournisseur';

  @override
  String get taskExportProtectedSecrets => 'secrets';

  @override
  String get taskExportRefused =>
      'Cet enregistrement ne peut pas être exporté en document Word.';

  @override
  String taskExportResult(String outcome) {
    return 'Résultat : $outcome';
  }

  @override
  String taskExportRevision(String revision) {
    return 'Révision du contenu : $revision';
  }

  @override
  String get taskExportSaveFailed =>
      'Le document Word n\'a pas pu être enregistré. L\'enregistrement est inchangé.';

  @override
  String taskExportSaved(String file) {
    return 'Document Word enregistré : $file';
  }

  @override
  String taskExportSceneAlt(String screen, String step) {
    return 'Illustration : $screen – $step';
  }

  @override
  String get taskExportSceneBookingTitle => 'Réserver une place';

  @override
  String get taskExportSceneCancel => 'Annuler';

  @override
  String get taskExportSceneConfirm => 'Confirmer';

  @override
  String get taskExportSceneDetailTitle => 'Réservation';

  @override
  String get taskExportSceneLater => 'Plus tard';

  @override
  String get taskExportSceneProvenance =>
      'Illustration recréée à partir de l\'enregistrement, pas une capture d\'écran';

  @override
  String get taskExportSectionAbout => 'À propos de cet enregistrement';

  @override
  String get taskExportSectionBefore => 'Avant de commencer';

  @override
  String get taskExportSectionLimits => 'Limites';

  @override
  String get taskExportSectionSteps => 'Étapes';

  @override
  String get taskExportStale =>
      'Le storyboard correspond à une autre version de cet enregistrement. Relisez-le avant d\'exporter.';

  @override
  String get taskExportStoryboardApprove => 'Approuver l\'illustration';

  @override
  String get taskExportStoryboardGap => 'Lacune : rien n\'a été enregistré ici';

  @override
  String get taskExportStoryboardInclude => 'Inclure';

  @override
  String get taskExportStoryboardLeftOut =>
      'Étape écartée lors de la relecture.';

  @override
  String get taskExportStoryboardMoveDown => 'Descendre';

  @override
  String get taskExportStoryboardMoveUp => 'Monter';

  @override
  String get taskExportStoryboardOrderRefused =>
      'Un résultat ne peut pas précéder la commande à laquelle il répond.';

  @override
  String get taskExportStoryboardRenderFailed =>
      'L\'illustration n\'a pas pu être dessinée ; cette étape reste en texte.';

  @override
  String get taskExportStoryboardSourceExcluded =>
      'Écran protégé : non illustré';

  @override
  String get taskExportStoryboardSourceScene =>
      'Illustration recréée (pas une capture d\'écran)';

  @override
  String get taskExportStoryboardSourceText => 'Diapositive de texte';

  @override
  String get taskExportSurfaceAny => 'n\'importe quel écran';

  @override
  String get taskExportSurfaceBookingSheet => 'la fiche de réservation';

  @override
  String get taskExportSurfaceReservationDetail =>
      'le détail de la réservation';

  @override
  String get taskExportSurfaceReserve => 'l\'écran Réserver';

  @override
  String get taskExportSurfaceUnknown =>
      'un écran que cette version ne sait pas décrire';

  @override
  String get taskExportUnrecorded =>
      'Une étape que cette version ne sait pas décrire.';

  @override
  String get taskExportValueAfternoon => 'après-midi';

  @override
  String get taskExportValueAllBooked => 'tout réservé';

  @override
  String get taskExportValueClosed => 'l\'espace était fermé';

  @override
  String get taskExportValueConflict => 'la place était déjà prise';

  @override
  String get taskExportValueCustom => 'personnalisée';

  @override
  String get taskExportValueDesk => 'un bureau';

  @override
  String get taskExportValueFullDay => 'journée entière';

  @override
  String get taskExportValueHours => 'à l\'heure';

  @override
  String get taskExportValueLater => 'plus tard';

  @override
  String get taskExportValueLaterThisWeek => 'plus tard cette semaine';

  @override
  String get taskExportValueList => 'liste';

  @override
  String get taskExportValueMorning => 'matin';

  @override
  String get taskExportValueNo => 'non';

  @override
  String get taskExportValueOff => 'désactivé';

  @override
  String get taskExportValueOffline => 'pas de connexion';

  @override
  String get taskExportValueOn => 'activé';

  @override
  String get taskExportValueOnce => 'une fois';

  @override
  String get taskExportValueOtherMember => 'un autre membre';

  @override
  String get taskExportValueOtherPlace => 'un autre type de place';

  @override
  String get taskExportValueOtherReason => 'un autre motif';

  @override
  String get taskExportValuePartiallyBooked => 'partiellement réservé';

  @override
  String get taskExportValuePast => 'un jour passé';

  @override
  String get taskExportValuePermission => 'une autorisation manquante';

  @override
  String get taskExportValuePlan => 'plan';

  @override
  String get taskExportValuePolicy => 'une règle de réservation';

  @override
  String get taskExportValueQuota => 'un quota';

  @override
  String taskExportValueRedacted(int length) {
    return 'non conservé ($length caractères)';
  }

  @override
  String get taskExportValueRoom => 'une salle';

  @override
  String get taskExportValueSelf => 'moi-même';

  @override
  String get taskExportValueSeries => 'en série';

  @override
  String get taskExportValueToday => 'aujourd\'hui';

  @override
  String get taskExportValueTomorrow => 'demain';

  @override
  String get taskExportValueWithheld => 'non enregistré';

  @override
  String get taskExportValueYes => 'oui';

  @override
  String taskExportVersion(int schema, int contract) {
    return 'Format d\'enregistrement $schema, contrat d\'actions $contract';
  }

  @override
  String get taskExportWordButton => 'Exporter en document Word';

  @override
  String get taskGuideCreate => 'Créer un brouillon de guide';

  @override
  String get taskGuideEditText => 'Écrire le texte';

  @override
  String get taskGuideIntro =>
      'Chaque étape telle qu\'un lecteur la suivra. Une étape qui réserve attend la vraie réponse ; rien n\'est fait à la place du lecteur.';

  @override
  String get taskGuideManual => 'Faites cette étape vous-même';

  @override
  String taskGuideManualProtected(String category) {
    return 'Faites cette étape vous-même, sur un écran protégé : $category';
  }

  @override
  String get taskGuideNoText => 'Une instruction encore à écrire';

  @override
  String get taskGuideOptional => 'Le lecteur peut la passer';

  @override
  String get taskGuideRecovery =>
      'En cas de refus : choisissez une autre place, un autre jour ou une autre période, puis confirmez à nouveau.';

  @override
  String get taskGuideSave => 'Enregistrer le guide';

  @override
  String get taskGuideTitle => 'Brouillon de guide';

  @override
  String taskGuideWaitsFor(String outcomes) {
    return 'Attend : $outcomes';
  }

  @override
  String get taskOutputBusy => 'Ce fichier est déjà en cours de création.';

  @override
  String get taskOutputDocument => 'Document Word';

  @override
  String get taskOutputFailed => 'Le fichier n\'a pas pu être créé.';

  @override
  String get taskOutputMake => 'Créer';

  @override
  String get taskOutputMissingMedia =>
      'Cette tâche n\'a aucune image à utiliser.';

  @override
  String get taskOutputStale =>
      'Les illustrations ont été revues pour une version précédente.';

  @override
  String get taskOutputStoryboard => 'Storyboard';

  @override
  String get taskOutputTooLong => 'Cette tâche est trop longue pour ce format.';

  @override
  String get taskOutputUnsupportedPlatform => 'Indisponible sur cet appareil.';

  @override
  String get taskRecorderActionBack => 'Est revenu en arrière';

  @override
  String get taskRecorderActionCalendarCancel =>
      'A annulé une réservation depuis le calendrier';

  @override
  String get taskRecorderActionCalendarFilterKind =>
      'A changé ce que le calendrier affiche';

  @override
  String get taskRecorderActionCalendarMove => 'A parcouru les dates';

  @override
  String get taskRecorderActionCalendarOpenItem =>
      'A ouvert une entrée du calendrier';

  @override
  String get taskRecorderActionCalendarSelectDay =>
      'A choisi un jour dans le calendrier';

  @override
  String get taskRecorderActionCalendarView => 'A changé la vue du calendrier';

  @override
  String get taskRecorderActionCalendarWhose =>
      'A choisi de qui voir le calendrier';

  @override
  String get taskRecorderActionCancelReservation => 'A annulé la réservation';

  @override
  String get taskRecorderActionCancelReview =>
      'A fermé la réservation sans réserver';

  @override
  String get taskRecorderActionCancelRoleEdit =>
      'A fermé le rôle sans enregistrer';

  @override
  String get taskRecorderActionCancelValidationRule =>
      'A fermé la règle sans enregistrer';

  @override
  String get taskRecorderActionChangeField =>
      'A modifié un détail de la réservation';

  @override
  String get taskRecorderActionCheckIn => 'A signalé son arrivée';

  @override
  String get taskRecorderActionCheckOut => 'A signalé son départ';

  @override
  String get taskRecorderActionCloseMyReservation =>
      'A fermé sa réservation sans la modifier';

  @override
  String get taskRecorderActionConfirmBooking => 'A confirmé la réservation';

  @override
  String get taskRecorderActionDecideEvent =>
      'A répondu à une demande de décision';

  @override
  String get taskRecorderActionDeclineOptIn =>
      'N\'a pas activé une fonctionnalité en test';

  @override
  String get taskRecorderActionGiveRole => 'A attribué ou retiré un rôle';

  @override
  String get taskRecorderActionOpenReserve => 'A ouvert Réserver';

  @override
  String get taskRecorderActionOpenRoleMatrix =>
      'A ouvert la matrice des rôles';

  @override
  String get taskRecorderActionOpenSpaceRoles =>
      'A ouvert les rôles de cet espace';

  @override
  String get taskRecorderActionOpenValidationRules =>
      'A ouvert les règles de validation';

  @override
  String get taskRecorderActionOpenWhatYouCanDo =>
      'A ouvert ce que vous pouvez faire';

  @override
  String get taskRecorderActionSaveRole => 'A enregistré un rôle';

  @override
  String get taskRecorderActionSaveValidationRule =>
      'A enregistré une règle de validation';

  @override
  String get taskRecorderActionSelectDate => 'A choisi le jour';

  @override
  String get taskRecorderActionSelectLevel => 'A choisi un niveau';

  @override
  String get taskRecorderActionSelectPeriod => 'A choisi la période';

  @override
  String get taskRecorderActionSelectResource => 'A choisi une place';

  @override
  String get taskRecorderActionSwitchFeature => 'A changé une fonctionnalité';

  @override
  String get taskRecorderActionSwitchView => 'A changé de vue';

  @override
  String get taskRecorderActionTogglePermission => 'A modifié une autorisation';

  @override
  String get taskRecorderActionUiCloseWindow => 'A fermé une fenêtre';

  @override
  String get taskRecorderActionUiCommand => 'A lancé une commande';

  @override
  String get taskRecorderActionUiCommitField => 'A rempli un champ';

  @override
  String get taskRecorderActionUiOpenScreen => 'A ouvert un écran';

  @override
  String get taskRecorderActionUiOpenWindow => 'A ouvert une fenêtre';

  @override
  String get taskRecorderActionUiTap => 'A touché';

  @override
  String get taskRecorderActionViewDetails => 'A ouvert la réservation';

  @override
  String get taskRecorderAddNote => 'Ajouter une note';

  @override
  String get taskRecorderCaptureValues =>
      'Enregistrer les valeurs (pour un rapport de problème)';

  @override
  String get taskRecorderCaptureValuesHint =>
      'Conserve aussi ce que vous saisissez et choisissez — texte, nombres, dates, interrupteurs — pour qu\'un développeur puisse reproduire le problème à partir du fichier. Les mots de passe, coordonnées de paiement, adresses e-mail, numéros de téléphone et autres données de contact personnelles ne sont jamais conservés. Ne partagez le fichier qu\'avec des personnes qui peuvent voir ce que vous avez saisi.';

  @override
  String get taskRecorderCompletenessComplete => 'Complet';

  @override
  String get taskRecorderCompletenessInterrupted => 'Interrompu';

  @override
  String get taskRecorderCompletenessPartial => 'Partiel';

  @override
  String get taskRecorderDelete => 'Supprimer de cet appareil';

  @override
  String get taskRecorderDeleteConfirm =>
      'Supprimer cet enregistrement de cet appareil ? Les fichiers exportés ne sont pas touchés et rien ne change dans l\'espace.';

  @override
  String get taskRecorderDiscard => 'Jeter';

  @override
  String get taskRecorderDisclosureBody =>
      'L\'enregistreur note les étapes que vous faites sur les écrans de cet espace — quel écran, quelle action, ce que l\'application a répondu — sur cet appareil uniquement. Il ne garde jamais ce que vous tapez, ni noms, montants, messages, codes ou mots de passe. La connexion, le paiement, les messages et les autres écrans protégés ne laissent qu\'un repère. Rien n\'est envoyé : vous décidez de ce que vous exportez.';

  @override
  String get taskRecorderDisclosureTitle => 'Avant d\'enregistrer';

  @override
  String taskRecorderEditedNote(int count) {
    return 'Copie modifiée : $count étapes exclues. L\'enregistrement sur cet appareil reste inchangé.';
  }

  @override
  String get taskRecorderEndInterrupted =>
      'Interrompu : l\'application s\'est arrêtée pendant l\'enregistrement';

  @override
  String get taskRecorderEndLimitReached =>
      'Terminé : une limite a été atteinte';

  @override
  String get taskRecorderEndReferenceMissing =>
      'Arrêt : le formulaire actuel n’a pas pu être identifié. Ouvrez une page prise en charge et recommencez.';

  @override
  String get taskRecorderEndScopeChanged =>
      'Terminé : le compte ou l\'espace a changé';

  @override
  String get taskRecorderEndStopped => 'Arrêté par vous';

  @override
  String get taskRecorderEndStorageFailed =>
      'Terminé : impossible de l\'enregistrer sur cet appareil';

  @override
  String get taskRecorderExport => 'Exporter un fichier';

  @override
  String get taskRecorderExportPackage => 'Exporter un paquet de tâche';

  @override
  String get taskRecorderExportPreview => 'Ce que le fichier contiendra';

  @override
  String get taskRecorderExportValuesBody =>
      'Il contient ce qui a été saisi et choisi pendant l\'enregistrement. Vérifiez-le avant de le partager, et ne le partagez qu\'avec des personnes qui peuvent le voir.';

  @override
  String get taskRecorderExportValuesConfirm => 'Enregistrer quand même';

  @override
  String get taskRecorderExportValuesTitle =>
      'Cet enregistrement contient des valeurs';

  @override
  String get taskRecorderFieldAccessories => 'accessoires';

  @override
  String get taskRecorderFieldCheckIn => 'arrivée';

  @override
  String get taskRecorderFieldForWhom => 'pour qui';

  @override
  String get taskRecorderFieldRepeat => 'répétition';

  @override
  String get taskRecorderFieldTime => 'horaire';

  @override
  String taskRecorderIndicator(int count) {
    return 'Enregistrement d\'une tâche : $count étapes';
  }

  @override
  String get taskRecorderLeaveOut => 'Exclure de l\'export';

  @override
  String taskRecorderLimits(int steps, int minutes, int days) {
    return 'Jusqu\'à $steps étapes ou $minutes minutes par enregistrement. Les enregistrements sont effacés de cet appareil après $days jours ; un fichier exporté vous appartient et reste là où vous l\'avez enregistré.';
  }

  @override
  String get taskRecorderMyRecordings => 'Mes enregistrements sur cet appareil';

  @override
  String get taskRecorderNoOutcome => 'Aucune réponse enregistrée';

  @override
  String get taskRecorderNoRecordings =>
      'Aucun enregistrement sur cet appareil.';

  @override
  String get taskRecorderNoteHint =>
      'Vos propres mots, gardés tels que vous les écrivez';

  @override
  String get taskRecorderOpenRecorder => 'Ouvrir l\'enregistreur de tâches';

  @override
  String get taskRecorderOutcomeCancelled => 'Annulée';

  @override
  String get taskRecorderOutcomeCheckedIn => 'Arrivée enregistrée';

  @override
  String get taskRecorderOutcomeCheckedOut => 'Départ enregistré';

  @override
  String get taskRecorderOutcomeCommandDone => 'Fait';

  @override
  String get taskRecorderOutcomeCommandPending => 'Envoyé pour validation';

  @override
  String get taskRecorderOutcomeConfirmed => 'Réservé';

  @override
  String get taskRecorderOutcomeEventDecided => 'Réponse enregistrée';

  @override
  String get taskRecorderOutcomeEventNotConfirmed =>
      'La réponse n\'a pas été confirmée';

  @override
  String get taskRecorderOutcomeRefused => 'Refusé';

  @override
  String get taskRecorderOutcomeRequested => 'Envoyé pour confirmation';

  @override
  String get taskRecorderOutcomeSeries => 'Série réservée';

  @override
  String get taskRecorderOutcomeSettingNotSaved => 'Non enregistré';

  @override
  String get taskRecorderOutcomeSettingPending => 'Envoyé pour validation';

  @override
  String get taskRecorderOutcomeSettingSaved => 'Enregistré';

  @override
  String get taskRecorderOutcomeUnknown => 'Aucune réponse n\'est arrivée';

  @override
  String get taskRecorderPause => 'Pause';

  @override
  String get taskRecorderPaused => 'En pause';

  @override
  String get taskRecorderProtectedAuthentication => 'connexion';

  @override
  String get taskRecorderProtectedIdentity => 'identité';

  @override
  String get taskRecorderProtectedMessenger => 'messages';

  @override
  String get taskRecorderProtectedOperator => 'opérateur de l\'installation';

  @override
  String get taskRecorderProtectedPayment => 'paiement';

  @override
  String get taskRecorderProtectedProvider => 'écran d\'un fournisseur';

  @override
  String get taskRecorderProtectedSecrets => 'clés et secrets';

  @override
  String get taskRecorderPutBack => 'Remettre';

  @override
  String get taskRecorderRecordATask => 'Enregistrer une tâche';

  @override
  String get taskRecorderRecordThisTask => 'Enregistrer cette tâche';

  @override
  String get taskRecorderRecording => 'Enregistrement en cours';

  @override
  String get taskRecorderResume => 'Reprendre';

  @override
  String get taskRecorderSaveFailed =>
      'Le fichier n\'a pas pu être enregistré.';

  @override
  String get taskRecorderSaveNoPath =>
      'Le fichier a été remis à votre navigateur ou appareil, qui n\'a pas dit où il l\'a mis.';

  @override
  String taskRecorderSaved(String path) {
    return 'Enregistré : $path';
  }

  @override
  String taskRecorderSavedPrivately(String path) {
    return 'Gardé seulement dans l\'application : $path';
  }

  @override
  String get taskRecorderSegmentGap => 'En pause ici';

  @override
  String get taskRecorderSignedOut =>
      'Connectez-vous pour enregistrer une tâche.';

  @override
  String get taskRecorderStart => 'Commencer l\'enregistrement';

  @override
  String get taskRecorderStartFailed =>
      'L\'enregistrement n\'a pas pu démarrer sur cet appareil.';

  @override
  String taskRecorderStepCount(int count) {
    return '$count étapes';
  }

  @override
  String get taskRecorderStepExcluded => 'Un écran protégé — non enregistré';

  @override
  String get taskRecorderStepNote => 'Votre note';

  @override
  String get taskRecorderStepUnrecorded =>
      'Une étape que l\'enregistreur ne sait pas décrire';

  @override
  String get taskRecorderStop => 'Arrêter';

  @override
  String get taskRecorderTargetAllKinds => 'tous les types';

  @override
  String get taskRecorderTargetDefaultRule => 'la règle par défaut';

  @override
  String get taskRecorderTargetUnkeyed => 'une commande sans nom';

  @override
  String get taskRecorderTitle => 'Enregistreur de tâches';

  @override
  String get taskRecorderUnavailable =>
      'L\'enregistrement n\'est pas activé dans cet espace.';

  @override
  String get taskRecorderUnreadable =>
      'Cet enregistrement est illisible. Vous pouvez le supprimer.';

  @override
  String get taskRecorderUntitled => 'Tâche sans titre';

  @override
  String get taskRecorderValueAccept => 'acceptée';

  @override
  String get taskRecorderValueAfternoon => 'après-midi';

  @override
  String get taskRecorderValueAgenda => 'agenda';

  @override
  String get taskRecorderValueAlert => 'une alerte';

  @override
  String get taskRecorderValueAllBooked => 'toutes les dates réservées';

  @override
  String get taskRecorderValueCheckIn => 'avec arrivée';

  @override
  String get taskRecorderValueClosed => 'fermé';

  @override
  String get taskRecorderValueConflict => 'déjà pris';

  @override
  String get taskRecorderValueConversation => 'une conversation';

  @override
  String get taskRecorderValueCreated => 'créé';

  @override
  String get taskRecorderValueCustom => 'horaires choisis';

  @override
  String get taskRecorderValueDay => 'jour';

  @override
  String get taskRecorderValueDecision => 'une décision';

  @override
  String get taskRecorderValueDecline => 'refusée';

  @override
  String get taskRecorderValueDesk => 'un bureau';

  @override
  String get taskRecorderValueEdited => 'modifié';

  @override
  String get taskRecorderValueEveryone => 'celui de tous';

  @override
  String get taskRecorderValueFullDay => 'journée entière';

  @override
  String get taskRecorderValueHours => 'à l\'heure';

  @override
  String get taskRecorderValueInvoice => 'une facture';

  @override
  String get taskRecorderValueLater => 'un jour plus tard';

  @override
  String get taskRecorderValueLaterThisWeek => 'plus tard cette semaine';

  @override
  String get taskRecorderValueList => 'liste';

  @override
  String get taskRecorderValueMine => 'le mien';

  @override
  String get taskRecorderValueMonth => 'mois';

  @override
  String get taskRecorderValueMorning => 'matin';

  @override
  String get taskRecorderValueNext => 'en avant';

  @override
  String get taskRecorderValueNoCheckIn => 'sans arrivée';

  @override
  String get taskRecorderValueOff => 'désactivée';

  @override
  String get taskRecorderValueOffline => 'hors ligne';

  @override
  String get taskRecorderValueOn => 'activée';

  @override
  String get taskRecorderValueOnce => 'une fois';

  @override
  String get taskRecorderValueOther => 'autre';

  @override
  String get taskRecorderValueOtherMember => 'pour un autre membre';

  @override
  String get taskRecorderValuePartiallyBooked => 'certaines dates refusées';

  @override
  String get taskRecorderValuePast => 'un jour passé';

  @override
  String get taskRecorderValuePayment => 'un paiement';

  @override
  String get taskRecorderValuePermission => 'une autorisation';

  @override
  String get taskRecorderValuePlan => 'plan';

  @override
  String get taskRecorderValuePolicy => 'une règle de réservation';

  @override
  String get taskRecorderValuePrevious => 'en arrière';

  @override
  String get taskRecorderValueQuota => 'un quota';

  @override
  String get taskRecorderValueRange => 'une période';

  @override
  String get taskRecorderValueRenamed => 'renommé';

  @override
  String get taskRecorderValueRoleAdmin => 'administrateurs';

  @override
  String get taskRecorderValueRoleCoOwner => 'un copropriétaire';

  @override
  String get taskRecorderValueRoleMember => 'chaque membre';

  @override
  String get taskRecorderValueRoleOwner => 'le propriétaire';

  @override
  String get taskRecorderValueRoom => 'une salle';

  @override
  String get taskRecorderValueSelf => 'pour moi';

  @override
  String get taskRecorderValueSeries => 'répétée';

  @override
  String get taskRecorderValueSomeoneElse => 'celui d\'un autre membre';

  @override
  String get taskRecorderValueTimeline => 'frise chronologique';

  @override
  String get taskRecorderValueToday => 'aujourd\'hui';

  @override
  String get taskRecorderValueTomorrow => 'demain';

  @override
  String get taskRecorderValueWeek => 'semaine';

  @override
  String get taskRecorderValueWithheld => 'non enregistré';

  @override
  String get taskRecorderValuesOn => 'Les valeurs sont enregistrées';

  @override
  String get taskWizardAddGuide => 'Ajouter un guide';

  @override
  String get taskWizardAddToGuides => 'Ajouter à mes guides';

  @override
  String get taskWizardBuiltIn => 'Guides fournis avec l\'application';

  @override
  String get taskWizardDeleteGuide => 'Supprimer ce guide';

  @override
  String get taskWizardDeleteGuideBody =>
      'Le guide est supprimé de cet appareil. L\'enregistrement dont il provient n\'est pas touché.';

  @override
  String get taskWizardEdit => 'Modifier';

  @override
  String get taskWizardFromFile => 'À partir d\'un fichier ou paquet de tâche';

  @override
  String get taskWizardFromFileHint =>
      'Un enregistrement, un paquet de tâche ou un fichier de guide venant de quelqu\'un d\'autre.';

  @override
  String get taskWizardFromRecording => 'À partir d\'un de mes enregistrements';

  @override
  String get taskWizardFromRecordingHint =>
      'Choisissez un enregistrement : il devient aussitôt un guide.';

  @override
  String get taskWizardGuideAdded => 'Ajouté à Mes guides.';

  @override
  String get taskWizardGuideName => 'Nom du guide';

  @override
  String get taskWizardGuideNotSaved => 'Le guide n\'a pas pu être conservé.';

  @override
  String get taskWizardGuides => 'Guides';

  @override
  String get taskWizardIntro =>
      'Enregistrez ce que vous faites, transformez-le en guide, et suivez les guides pas à pas dans la vraie application.';

  @override
  String get taskWizardMakeGuide => 'Créer un guide';

  @override
  String get taskWizardNoGuides =>
      'Pas encore de guide à vous. Ajoutez-en un à partir d\'un enregistrement ou d\'un fichier de tâche.';

  @override
  String get taskWizardOpenFileHint =>
      'Lire, modifier et exporter un enregistrement ou un paquet de tâche, sans compte.';

  @override
  String get taskWizardRecordings => 'Enregistrements';

  @override
  String get taskWizardSaveChanges => 'Enregistrer les modifications';

  @override
  String get taskWizardTitle => 'Assistant de tâches';

  @override
  String get taskWizardTools => 'Outils';

  @override
  String get taskWizardUnavailable =>
      'L\'enregistreur de tâches est désactivé dans cet espace : les guides peuvent être lus et modifiés ici, mais pas suivis.';

  @override
  String taskWorkbenchAccepted(int megabytes) {
    return 'Acceptés : .json et .deskilo-task.zip, jusqu\'à $megabytes Mo.';
  }

  @override
  String get taskWorkbenchChoose => 'Choisir un fichier de tâche';

  @override
  String taskWorkbenchClaim(String key, String value) {
    return 'Le fichier indique $key : $value';
  }

  @override
  String get taskWorkbenchEdited => 'Une copie modifiée d\'un enregistrement.';

  @override
  String get taskWorkbenchFileType => 'Fichier de tâche';

  @override
  String get taskWorkbenchIntro =>
      'Ouvrez un fichier de tâche enregistré. Il est lu sur cet appareil uniquement ; rien n\'est envoyé et aucune connexion n\'est nécessaire.';

  @override
  String get taskWorkbenchOfflineFailed =>
      'Le navigateur a refusé de le garder.';

  @override
  String get taskWorkbenchOfflineForget => 'Ne plus le garder';

  @override
  String get taskWorkbenchOfflineKeep => 'Le garder sur cet appareil';

  @override
  String get taskWorkbenchOfflineOff =>
      'Non gardé : sans connexion, cette page ne s\'ouvrira pas.';

  @override
  String get taskWorkbenchOfflineReady =>
      'Gardé dans ce navigateur : l’atelier vérifié s’ouvre sans connexion. Les actions dans un espace nécessitent une connexion.';

  @override
  String get taskWorkbenchOfflineTitle => 'Utiliser l\'atelier hors ligne';

  @override
  String get taskWorkbenchOfflineUnsupported =>
      'Ce navigateur ne peut pas le garder (une fenêtre privée ne le peut généralement pas).';

  @override
  String get taskWorkbenchOpen => 'Ouvrir un fichier de tâche';

  @override
  String get taskWorkbenchRefusedDamaged =>
      'Ce fichier est endommagé ou a été modifié après sa création.';

  @override
  String get taskWorkbenchRefusedInvalid =>
      'Ce fichier ne contient pas de tâche valide.';

  @override
  String get taskWorkbenchRefusedNewer =>
      'Ce fichier a été créé par une version plus récente de l\'application.';

  @override
  String get taskWorkbenchRefusedTooLarge =>
      'Ce fichier est plus grand que ce que l\'atelier lit.';

  @override
  String get taskWorkbenchRefusedUnsafe =>
      'Ce fichier est construit d\'une manière qu\'il n\'est pas sûr d\'ouvrir.';

  @override
  String get taskWorkbenchRefusedUnsupported =>
      'Ce n\'est pas un fichier de tâche.';

  @override
  String get taskWorkbenchReviewIllustrations => 'Revoir les illustrations';

  @override
  String get taskWorkbenchStoryboardRestored =>
      'Les illustrations revues ont été restaurées depuis le fichier.';

  @override
  String get taskWorkbenchTitle => 'Atelier de tâches';

  @override
  String get taskWorkbenchTranscriptOnly =>
      'Certaines étapes viennent d\'une version plus récente : affichées comme simple transcription.';

  @override
  String get taskWorkbenchUntrusted =>
      'Un brouillon privé issu d\'un fichier : rien n\'y est considéré comme fiable ni envoyé.';

  @override
  String get templateApplyConflict =>
      'Cette demande a déjà servi pour autre chose. Rien n\'a été appliqué.';

  @override
  String get templateChangedSinceReview =>
      'Ce modèle a changé depuis votre relecture. Rien n\'a été appliqué ; rouvrez-le pour relire la nouvelle version.';

  @override
  String get templateClearFilters => 'Effacer la recherche';

  @override
  String get templateDetailNone => 'Aucun réglage ne correspond.';

  @override
  String get templateDetailSearch => 'Chercher un réglage dans ce modèle';

  @override
  String get templateDetails => 'Ce qu’il contient';

  @override
  String templateExportResults(String count) {
    return 'Exporter ces résultats ($count)';
  }

  @override
  String templateExportTooMany(String max) {
    return 'Au plus $max modèles par classeur. Affinez d’abord la recherche.';
  }

  @override
  String get templateNoMatch =>
      'Aucun modèle ne correspond. Changez les mots, une étiquette ou une exigence.';

  @override
  String templatePrefer(String capability) {
    return 'Préférer : $capability';
  }

  @override
  String templatePreferredChip(String capability) {
    return 'Préféré : $capability';
  }

  @override
  String get templatePricesOtherCurrency =>
      'Les prix du modèle sont dans une autre devise : les prix d\'ici n\'ont pas été modifiés.';

  @override
  String get templateProfileFull => 'Profil de configuration complet';

  @override
  String templateProfileSelected(String chosen, String total) {
    return 'Groupes choisis : $chosen sur $total';
  }

  @override
  String get templatePublishLocalNeeds =>
      'Un espace qui l’applique les configurera lui-même :';

  @override
  String templateRegionSuggested(String values) {
    return 'Ce modèle a été conçu pour $values. Votre choix est conservé, sauf si vous utilisez ses valeurs.';
  }

  @override
  String get templateRegionUse => 'Utiliser la région du modèle';

  @override
  String templateRequire(String capability) {
    return 'Exiger : $capability';
  }

  @override
  String get templateRequirementRemove => 'Retirer l’exigence';

  @override
  String get templateRequirementsReset => 'Réinitialiser';

  @override
  String templateResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count modèles affichés',
      one: '1 modèle affiché',
      zero: 'Aucun modèle affiché',
    );
    return '$_temp0';
  }

  @override
  String templateValidatorsToChoose(String types) {
    return 'Choisissez qui valide $types dans les réglages de validation ; ces règles n\'ont pas été modifiées.';
  }

  @override
  String get templateWhy => 'Pourquoi ce modèle correspond';

  @override
  String get templateWhyHide => 'Masquer le pourquoi';

  @override
  String get templateWidenConfirm => 'Rendre lisible';

  @override
  String templateWidenCount(String count) {
    return '$count réglages deviennent lisibles, tels que le modèle les contient maintenant.';
  }

  @override
  String templateWidenExcluded(String count) {
    return '$count types de valeurs ne partent jamais avec lui (coordonnées bancaires, sites, adresses…).';
  }

  @override
  String templateWidenTitle(String audience) {
    return 'Rendre ce modèle lisible par : $audience ?';
  }

  @override
  String get templatesLoadFailed => 'Les modèles n’ont pas pu être chargés.';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeSystem => 'Par défaut du système';

  @override
  String get themeTitle => 'Thème';

  @override
  String get threadNoRefs =>
      'Les références ne se partagent qu’avec des personnes du même espace.';

  @override
  String get threadRefsIn => 'Références dans';

  @override
  String get unblockAction => 'Débloquer';

  @override
  String get unblockDone => 'Débloqué.';

  @override
  String get usageAsk => 'Facturer le temps où j\'étais là';

  @override
  String usageAskExplain(String booked, String present, String saved) {
    return 'Vous avez réservé $booked et vous êtes resté $present. Demandez que les $saved non utilisées cessent d\'être facturées. Quelqu\'un d\'autre décide — jamais vous.';
  }

  @override
  String get usageAskSubmit => 'Demander';

  @override
  String get usageAskSubmitted => 'Demandé. Quelqu\'un d\'autre décide.';

  @override
  String get usageBilled => 'Facturé';

  @override
  String get usageBooked => 'Réservé';

  @override
  String get usageCorrected => 'Corrigé';

  @override
  String get usageDelete => 'Supprimer ce relevé';

  @override
  String get usageDeleteSubmitted => 'Suppression demandée.';

  @override
  String get usageEmpty => 'Aucun usage ce mois-ci.';

  @override
  String get usageLeftEarly => 'Parti plus tôt';

  @override
  String get usageMember => 'Membre';

  @override
  String get usageMemberAll => 'Tout le monde';

  @override
  String get usageNoShow =>
      'Personne n\'est arrivé — la réservation est facturée en entier';

  @override
  String get usagePresent => 'Présent';

  @override
  String get usageReasonLabel => 'Pourquoi (facultatif)';

  @override
  String get usageReportButton => 'Rapport de consommation du mois';

  @override
  String get usageReportExtra => 'Demi-journées supplémentaires';

  @override
  String get usageReportIncluded => 'Demi-journées incluses';

  @override
  String get usageReportOverage =>
      'Dépassement reporté sur la prochaine facture';

  @override
  String get usageReportPaid => 'Payé d\'avance (participation)';

  @override
  String get usageReportRecordsHeading => 'Ce qui a été consommé';

  @override
  String get usageReportRemaining => 'Demi-journées restantes';

  @override
  String get usageReportSupplements =>
      'Suppléments (accessoires, bureaux, espaces)';

  @override
  String get usageReportUsed => 'Demi-journées consommées';

  @override
  String get usageTitle => 'Usage';

  @override
  String usageWas(String before) {
    return 'était $before';
  }

  @override
  String get uxAdvancedSection => 'Avancé';

  @override
  String get uxAlertsFilterEmpty =>
      'Aucune actualité ne correspond à ces filtres.';

  @override
  String uxAttentionSummary(int updates, int pending) {
    return '$updates nouveautés · $pending décisions en attente';
  }

  @override
  String get uxBookingChargePending =>
      'Le montant et l’utilisation du forfait seront calculés selon le plan du membre. Le montant final n’est pas disponible ici.';

  @override
  String get uxBookingCheckInHelp =>
      'Indiquer aussi ma présence lors de la confirmation de cette réservation.';

  @override
  String get uxBookingFor => 'Réservation pour';

  @override
  String get uxBookingModesHelp =>
      'Réserver conserve le créneau choisi. S’installer maintenant utilise le créneau actuel et indique votre présence.';

  @override
  String get uxBookingResourceUnavailable => 'Ressource indisponible';

  @override
  String get uxDeviceTime => 'Votre heure';

  @override
  String get uxFinanceAlerts => 'Alertes financières';

  @override
  String get uxFinanceAlertsFailed =>
      'Impossible d’ouvrir les alertes financières. Réessayez.';

  @override
  String get uxLinkedReference => 'Ressource liée';

  @override
  String get uxManageResource => 'Gérer la ressource';

  @override
  String get uxMoneyAllPeriods =>
      'Toutes les périodes · Crédit, factures ouvertes et remboursements.';

  @override
  String get uxMoneyDocumentsScope =>
      'Rapports mensuels et votre accord en vigueur.';

  @override
  String get uxMoneyInvoicesScope =>
      'Vos factures dans cet espace · Toutes les périodes.';

  @override
  String get uxMoneyPaymentsScope =>
      'Solde du mois · Factures en retard de toutes les périodes.';

  @override
  String get uxMoneyStatementScope =>
      'Détail mensuel pour la période sélectionnée.';

  @override
  String get uxMoneyUsageScope =>
      'Réservations et consommations du mois sélectionné.';

  @override
  String get uxMoneyWorkspaceTools => 'Outils financiers de l’espace';

  @override
  String get uxMyBookings => 'Mes réservations';

  @override
  String get uxNavFinance => 'Facturation et paiements';

  @override
  String get uxNavPeople => 'Membres et accès';

  @override
  String get uxNavWorkspace => 'Configuration de l’espace';

  @override
  String get uxOpenWorkspace => 'Ouvrir l’espace';

  @override
  String get uxPreferencesSection => 'Préférences';

  @override
  String get uxPrivacySection => 'Confidentialité';

  @override
  String get uxProfileAccount => 'Profil et compte';

  @override
  String get uxProfileChooseEnvironment => 'Choisir un environnement';

  @override
  String get uxProfileSection => 'Profil';

  @override
  String get uxRealSpaceHint => 'Réservations et factures réelles';

  @override
  String get uxRealWorkspace => 'Espace réel';

  @override
  String get uxReportsFinance => 'Rapports financiers';

  @override
  String get uxReportsHint =>
      'Rapports financiers, documents de l’espace et exports';

  @override
  String get uxReportsTemplates => 'Modèles';

  @override
  String get uxReportsTitle => 'Rapports';

  @override
  String get uxReportsWorkspace => 'Documents de l’espace';

  @override
  String get uxResetFilters => 'Réinitialiser les filtres';

  @override
  String get uxSettingsPersonal => 'Mes réglages';

  @override
  String get uxSettingsSpace => 'Gérer l’espace';

  @override
  String get uxTestSpace => 'Espace de test';

  @override
  String get uxTestSpaceHint =>
      'Espace de test : réservations et factures d’essai';

  @override
  String get uxWorkspaceAppearance => 'Apparence et libellés';

  @override
  String get uxWorkspaceCommunity => 'Communauté et invitations';

  @override
  String get uxWorkspaceGeneral => 'Informations générales';

  @override
  String get uxWorkspaceTime => 'Heure de l’espace';

  @override
  String get uxWorkspaceTools => 'Modèles et données';

  @override
  String get validationAdminsMay => 'Les admins peuvent valider';

  @override
  String get validationAllAdmins => 'Tous les admins';

  @override
  String get validationAutoValidateAdmin =>
      'Les admins suppriment sans validation';

  @override
  String get validationAutoValidateDesc =>
      'Leur propre demande de suppression se règle d\'elle-même et reste marquée comme auto-validée.';

  @override
  String get validationAutoValidateOwner =>
      'Les propriétaires suppriment sans validation';

  @override
  String get validationCustomized => 'Personnalisée';

  @override
  String get validationDefaultPolicy => 'Règle par défaut';

  @override
  String get validationInherited => 'Hérite de la règle par défaut';

  @override
  String get validationMinAmount => 'Seulement au-delà de ce montant';

  @override
  String get validationMinAmountDesc =>
      'En dessous, l\'acte s\'applique aussitôt. Vide : tout montant.';

  @override
  String get validationNoSelfDesc =>
      'Celui qui crée un événement ne le valide jamais. Il attend quelqu\'un d\'autre, ou expire sans décision.';

  @override
  String get validationNoSelfShort => 'Jamais le sien';

  @override
  String get validationNoSelfTitle => 'Personne ne valide le sien';

  @override
  String get validationNotEnough => 'Pas assez de validateurs éligibles.';

  @override
  String get validationOwnerOnly => 'Propriétaire uniquement';

  @override
  String get validationOwnerRequired => 'Le propriétaire doit toujours valider';

  @override
  String get validationOwnerSelf => 'Le propriétaire peut valider le sien';

  @override
  String get validationOwnerSelfDesc =>
      'La seule exception, et elle est au propriétaire seul : un admin ne valide jamais son propre acte.';

  @override
  String get validationOwnerSelfShort => 'Le propriétaire peut valider le sien';

  @override
  String get validationPickPersons => 'Choisissez les personnes';

  @override
  String get validationRequiredCount => 'Validations requises';

  @override
  String get validationSaved => 'Règle de validation enregistrée.';

  @override
  String get validationScopeAdmins => 'Les admins';

  @override
  String get validationScopeHint =>
      'Le propriétaire peut toujours. Admins : tous les admins, ou ceux que vous listez. Désignées : exactement ces personnes, quel que soit leur rôle. Tous les membres : quiconque est actif.';

  @override
  String get validationScopeLabel => 'Qui valide';

  @override
  String get validationScopeListed => 'Personnes désignées';

  @override
  String get validationScopeMembers => 'Tous les membres';

  @override
  String get validationSentForApproval =>
      'Envoyé en validation — appliqué une fois approuvé.';

  @override
  String get validationSequential => 'L\'une après l\'autre';

  @override
  String get validationSequentialDesc =>
      'La validation suivante est demandée une fois la précédente passée, et l\'historique numérote chaque étape.';

  @override
  String get validationSpecificAdmins => 'Admins spécifiques';

  @override
  String get validationStepApplies => 'cela prend effet';

  @override
  String get validationStepOwnerToo => 'et le propriétaire, toujours';

  @override
  String validationStepQuorum(int count, String who) {
    return '$who — $count au choix';
  }

  @override
  String get validationStepRaised => 'Quelqu’un demande';

  @override
  String validationStepSequential(int count, String who) {
    return '$who — $count à la suite';
  }

  @override
  String get validationThresholdNote =>
      'Les montants plus faibles s\'appliquent aussitôt.';

  @override
  String get validationTitle => 'Règles de validation';

  @override
  String validationTrailAwaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'En attente de $count validations de plus.',
      one: 'En attente d’une validation de plus.',
    );
    return '$_temp0';
  }

  @override
  String get validationTrailNone => 'Aucune décision pour le moment.';

  @override
  String validationTrailStep(int order) {
    return 'Étape $order';
  }

  @override
  String get validationTrailTitle => 'Historique de validation';

  @override
  String get validationWorkflowBookings => 'Réservations';

  @override
  String get validationWorkflowBookingsStake =>
      'Tant que ce n\'est pas accepté, la place reste telle quelle.';

  @override
  String get validationWorkflowMoneyStake =>
      'Tant que ce n\'est pas accepté, le montant ne compte sur aucun relevé.';

  @override
  String get validationWorkflowPeople => 'Personnes et rôles';

  @override
  String get validationWorkflowPeopleStake =>
      'Tant que ce n\'est pas accepté, la personne garde les accès qu\'elle a.';

  @override
  String get vatAccountField => 'Compte de TVA';

  @override
  String get vatAccountHint =>
      'Compte où l\'export comptable enregistre la TVA collectée. Vide = 445710.';

  @override
  String get vatAddRate => 'Ajouter un taux';

  @override
  String get vatChangeByLaw => 'Changement par la loi';

  @override
  String get vatChangeByLawExplainer =>
      'Une nouvelle valeur à partir d\'une date : l\'ancienne reste sur toute prestation antérieure, la nouvelle s\'applique à partir de ce jour. Rien n\'est repointé.';

  @override
  String get vatChangeInvalid =>
      'Il faut un pourcentage entre 0 et 99,99 et une date postérieure au début du taux.';

  @override
  String get vatChangeNeedsSave =>
      'Enregistrez d\'abord le taux ; puis changez-le par la loi.';

  @override
  String get vatDeclBox => 'Ligne';

  @override
  String get vatDeclBoxes => 'Lignes du formulaire officiel (CA3)';

  @override
  String get vatDeclDisclaimer =>
      'Générée à partir des factures émises de la période. Vérifiez avec votre comptabilité avant de déclarer — aide à la déclaration, pas un conseil fiscal.';

  @override
  String get vatDeclDraft => 'Brouillon';

  @override
  String get vatDeclEmpty =>
      'Aucune déclaration — choisissez une période et générez la première.';

  @override
  String get vatDeclGenerate => 'Générer';

  @override
  String get vatDeclInvoices => 'Factures';

  @override
  String get vatDeclMarkFiled => 'Marquer comme déposée';

  @override
  String get vatDeclMarkFiledConfirm =>
      'Confirmez avoir déposé cette déclaration vous-même (portail des impôts ou votre comptable). Elle devient immuable.';

  @override
  String get vatDeclNet => 'Base HT';

  @override
  String get vatDeclPdf => 'PDF';

  @override
  String get vatDeclPeriod => 'Période';

  @override
  String get vatDeclRate => 'Taux';

  @override
  String get vatDeclRegimeGate =>
      'Les déclarations n’existent que sous le régime assujetti à la TVA — configurez-le dans les réglages TVA.';

  @override
  String get vatDeclRejected => 'La plateforme a refusé la déclaration.';

  @override
  String get vatDeclSeller => 'Vendeur';

  @override
  String get vatDeclSent => 'Déclaration télétransmise.';

  @override
  String get vatDeclStatus => 'Statut';

  @override
  String get vatDeclSubmitted => 'Déposée';

  @override
  String get vatDeclTitle => 'Déclaration de TVA';

  @override
  String get vatDeclTotals => 'Totaux';

  @override
  String get vatDeclTransmit => 'Télétransmettre';

  @override
  String get vatDeclVat => 'TVA';

  @override
  String get vatDeclVatId => 'N° TVA';

  @override
  String get vatDeclXml => 'Export XML';

  @override
  String get vatDeclarationBasisInvoice =>
      'Base : débits (TVA sur les factures émises pendant la période).';

  @override
  String get vatDeclarationBasisPayment =>
      'Base : encaissements (TVA sur les paiements reçus pendant la période).';

  @override
  String get vatEffectiveDate => 'Date d\'effet (AAAA-MM-JJ)';

  @override
  String get vatEmpty => 'Aucun taux — les factures n\'affichent pas de TVA.';

  @override
  String get vatExemptionReasonField => 'Mention d\'exonération';

  @override
  String get vatExigibilityInvoice => 'Sur les débits (à la facture)';

  @override
  String get vatExigibilityPayment => 'Sur les encaissements (au paiement)';

  @override
  String get vatExigibilitySubtitle =>
      'Sur les encaissements, une période déclare ce que les clients ont payé pendant celle-ci ; sur les débits, ce que vous avez facturé. Le choix est imprimé sur chaque facture.';

  @override
  String get vatExigibilityTitle => 'Exigibilité de la TVA';

  @override
  String get vatGroupDeposit => 'Consigne (hors TVA)';

  @override
  String get vatGroupExamples => 'Ce qui relève de chaque groupe';

  @override
  String get vatGroupExcise => 'Produit à accises';

  @override
  String get vatGroupExempt => 'Exonéré';

  @override
  String get vatGroupIntermediate => 'Intermédiaire';

  @override
  String get vatGroupLabel => 'Groupe';

  @override
  String get vatGroupNotSubject => 'Non assujetti';

  @override
  String get vatGroupReduced => 'Réduit';

  @override
  String get vatGroupStandard => 'Normal';

  @override
  String get vatGroupSuperReduced => 'Super-réduit';

  @override
  String get vatGroupZero => 'Taux zéro';

  @override
  String get vatIntro =>
      'Dans DesKilo les prix sont TTC. Ajouter des taux ne change rien à ce que les membres paient : la taxe est extraite du prix déjà facturé et affichée sur la facture.';

  @override
  String get vatKeptRate =>
      'Un taux encore utilisé par une facture ou un service est conservé, désactivé.';

  @override
  String get vatNeedsDefault =>
      'Marquez exactement un taux comme taux par défaut.';

  @override
  String get vatNewPercent => 'Nouveau taux %';

  @override
  String get vatPdfNet => 'Total HT';

  @override
  String get vatPdfVat => 'TVA';

  @override
  String get vatRateDefaultTooltip =>
      'Taux par défaut — utilisé par les abonnements et par tout ce qui n\'a pas son propre taux';

  @override
  String get vatRateIncomplete =>
      'Chaque taux demande un nom et un pourcentage entre 0 et 99,99.';

  @override
  String get vatRateLabelField => 'Nom';

  @override
  String get vatRatePercentField => 'Taux %';

  @override
  String get vatRateRemoveTooltip => 'Supprimer';

  @override
  String get vatRatesTile => 'Taux de TVA';

  @override
  String get vatRegimeHint =>
      'Cet espace n\'est pas déclaré assujetti à la TVA : les factures n\'en affichent aucune. Cela se change dans Identité légale.';

  @override
  String get vatReportByRate => 'Totaux par taux';

  @override
  String get vatReportCsv => 'Rapport de TVA (CSV)';

  @override
  String get vatReportPdf => 'Rapport de TVA (PDF)';

  @override
  String get vatReportPositions => 'Positions';

  @override
  String get vatReportTotals => 'Totaux de la période';

  @override
  String get vatSaved => 'Taux de TVA enregistrés.';

  @override
  String get vatSeed => 'Utiliser les taux usuels';

  @override
  String get vatServiceRate => 'Taux de TVA';

  @override
  String get vatServiceRateDefault => 'Taux par défaut de l\'espace';

  @override
  String vatShareAmount(String amount) {
    return 'dont TVA $amount';
  }

  @override
  String get vatSince => 'depuis le';

  @override
  String get vatTitle => 'TVA';

  @override
  String get vatTreatmentAuto => 'Automatique';

  @override
  String get vatTreatmentDomestic => 'TVA nationale';

  @override
  String get vatTreatmentExempt => 'Acheteur exonéré';

  @override
  String get vatTreatmentExport => 'Hors UE';

  @override
  String get vatTreatmentReasonField =>
      'Motif d\'exonération (imprimé sur la facture)';

  @override
  String get vatTreatmentReverseCharge => 'Autoliquidation';

  @override
  String get vatUntil => 'jusqu\'au';

  @override
  String get visibilityAbout => 'Métier et présentation';

  @override
  String get visibilityAboutEmpty => 'Ajoutez votre métier et quelques mots';

  @override
  String get visibilityAboutMe => 'À propos de moi';

  @override
  String get visibilityAboutSaveFailed =>
      'Impossible d\'enregistrer votre métier et votre présentation. Veuillez réessayer.';

  @override
  String get visibilityBio => 'Quelques mots sur vous';

  @override
  String visibilityChosenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Membres de $count espaces choisis',
      one: 'Membres d\'1 espace choisi',
    );
    return '$_temp0';
  }

  @override
  String get visibilityChosenSpaces => 'Membres d\'espaces choisis';

  @override
  String get visibilityContact => 'WhatsApp et e-mail';

  @override
  String get visibilityElsewhereIntro =>
      'Sur un serveur connecté, vous avez le compte de ce serveur. Les personnes qui n\'y partagent aucun espace avec vous voient ce que vous autorisez à toute personne connectée ; vos coordonnées et votre présence ne sortent jamais de vos espaces.';

  @override
  String get visibilityElsewhereTitle => 'Sur mes autres serveurs';

  @override
  String get visibilityIdentity => 'Nom et photo';

  @override
  String get visibilityIntro =>
      'Chaque partie de votre compte choisit son public. Rien n\'est public sans votre choix.';

  @override
  String get visibilityMySpaces => 'Membres de mes espaces';

  @override
  String get visibilityNobody => 'Personne';

  @override
  String visibilityOnServer(String host) {
    return 'Qui me voit sur $host';
  }

  @override
  String visibilityOnServerUnavailable(String host) {
    return '$host n\'a pas répondu. Réessayez plus tard.';
  }

  @override
  String get visibilityPresence => 'Présent dans l\'espace aujourd\'hui';

  @override
  String get visibilityPreviewCanWrite =>
      'Peut démarrer une conversation avec vous';

  @override
  String get visibilityPreviewCannotWrite =>
      'Ne peut pas démarrer de conversation avec vous';

  @override
  String get visibilityPreviewFailed => 'L\'aperçu n\'a pas pu être chargé.';

  @override
  String get visibilityPreviewMySpaces => 'Un membre de mes espaces';

  @override
  String get visibilityPreviewNobody => 'Moi seul';

  @override
  String get visibilityPreviewNothing => 'Ils ne voient rien de vous.';

  @override
  String get visibilityPreviewSignedIn => 'Toute personne connectée';

  @override
  String get visibilityPreviewTitle => 'Comment les autres me voient';

  @override
  String get visibilityProfession => 'Métier';

  @override
  String get visibilityReachability =>
      'Qui peut démarrer une conversation avec moi';

  @override
  String get visibilitySaveFailed =>
      'Impossible d\'enregistrer qui le voit. Veuillez réessayer.';

  @override
  String get visibilitySignedIn => 'Toute personne connectée';

  @override
  String get visibilityTitle => 'Qui me voit';

  @override
  String get visibilityWidenAction => 'Élargir';

  @override
  String visibilityWidenConfirm(String field, String audience) {
    return 'Montrer votre $field à : $audience ? Ces personnes pourront le voir.';
  }

  @override
  String get visitCancel => 'Annuler cette visite';

  @override
  String get visitCancelFailed =>
      'Impossible d\'annuler la visite. Rien n\'a changé ; réessayez.';

  @override
  String get visitGuestNote => 'Visite d\'invité — pas une adhésion';

  @override
  String get visitStatusCancelled => 'Annulée';

  @override
  String get visitStatusConfirmed => 'Confirmée';

  @override
  String get visitStatusDeclined => 'Refusée';

  @override
  String get visitStatusExpired => 'Expirée';

  @override
  String get visitStatusRequested => 'Demandée';

  @override
  String whatTheyCanDoTitle(String name) {
    return 'Ce que $name peut faire ici';
  }

  @override
  String get whatYouCanDoFromAdministrator => 'Du rôle Administrateur·rice';

  @override
  String get whatYouCanDoFromCoOwner => 'En tant que copropriétaire';

  @override
  String get whatYouCanDoFromEveryMember => 'Comme tous les membres';

  @override
  String get whatYouCanDoFromOwner => 'En tant que propriétaire : tout';

  @override
  String whatYouCanDoFromRole(String role) {
    return 'Du rôle $role';
  }

  @override
  String get whatYouCanDoIntro =>
      'Ici, tout le monde est membre ; ce que vous pouvez faire — messages, réservations et le reste — vient uniquement des rôles que vous détenez.';

  @override
  String get whatYouCanDoNothingMore => 'Rien de plus qu\'un membre.';

  @override
  String get whatYouCanDoTitle => 'Ce que vous pouvez faire ici';

  @override
  String get whatsappFieldLabel => 'Numéro WhatsApp';

  @override
  String get whatsappHelper =>
      'Facultatif. Visible par les membres de vos espaces pour vous joindre sur WhatsApp. Laissez vide pour ne plus le partager.';

  @override
  String get whatsappHint => '+33 6 12 34 56 78';

  @override
  String get whatsappNotShared => 'Non partagé';

  @override
  String get whatsappSaveFailed =>
      'Impossible d\'enregistrer le numéro WhatsApp';

  @override
  String get whatsappSaved => 'Numéro WhatsApp enregistré';

  @override
  String get whatsappTitle => 'WhatsApp';

  @override
  String get wizardBack => 'Retour';

  @override
  String get wizardCardHint =>
      'Émettre, envoyer, relancer, enregistrer et valider les paiements, rapprocher et clôturer — un seul processus guidé.';

  @override
  String get wizardCloseHint =>
      'Un membre avec plusieurs factures ouvertes peut n\'en payer QU\'UNE ; le reste d\'une facture partiellement payée peut être abandonné ; un avoir est remboursé. Chacun passe par la validation.';

  @override
  String get wizardCloseNone => 'Rien à regrouper, abandonner ou rembourser.';

  @override
  String get wizardFinish => 'Terminer';

  @override
  String wizardIssueAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Émettre $count factures',
      one: 'Émettre 1 facture',
    );
    return '$_temp0';
  }

  @override
  String wizardIssueFailed(String name) {
    return 'Émission impossible pour $name.';
  }

  @override
  String get wizardIssueHint =>
      'Décochez un membre pour l\'exclure de ce lot. Les membres déjà couverts apparaissent comme faits.';

  @override
  String get wizardIssueNothing => 'Rien à émettre pour cette période.';

  @override
  String wizardIssuedChip(String number) {
    return 'Émise $number';
  }

  @override
  String get wizardMatchAction => 'Rapprocher';

  @override
  String wizardMatchCredit(String amount) {
    return 'Crédit disponible : $amount';
  }

  @override
  String get wizardMatchHint =>
      'Une facture est payée lorsqu\'un paiement réel lui est rapproché. Les lignes avec un crédit sur le compte du membre sont prêtes.';

  @override
  String get wizardMatchNoCredit =>
      'Aucun paiement sur le compte pour l\'instant';

  @override
  String get wizardMatchNone => 'Toutes les factures sont payées ou clôturées.';

  @override
  String get wizardMatchPending => 'En attente de validation';

  @override
  String get wizardNext => 'Suivant';

  @override
  String get wizardPaymentAccept => 'Confirmer';

  @override
  String get wizardPaymentReject => 'Refuser';

  @override
  String get wizardPaymentsHint =>
      'Ce que les membres ont déclaré attend votre confirmation ci-dessous. Un paiement arrivé sur le compte sans déclaration s\'enregistre ici — le membre le confirme ensuite.';

  @override
  String get wizardPaymentsNone =>
      'Aucun paiement déclaré n\'attend votre décision.';

  @override
  String wizardPeriodLabel(String period) {
    return 'Période : $period';
  }

  @override
  String get wizardRefund => 'Rembourser';

  @override
  String wizardRemindAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Envoyer $count relances',
      one: 'Envoyer 1 relance',
    );
    return '$_temp0';
  }

  @override
  String get wizardRemindHint =>
      'En retard selon vos règles de relance. Un appui enregistre chaque relance et prévient les membres ; la lettre s\'ouvre par ligne.';

  @override
  String wizardRemindLevel(int level) {
    return 'relance $level';
  }

  @override
  String get wizardRemindNone => 'Aucune relance due selon vos règles.';

  @override
  String get wizardRemindOne => 'Lettre de relance';

  @override
  String get wizardReviewIssued => 'Déjà émises';

  @override
  String get wizardReviewOpen => 'Factures ouvertes';

  @override
  String get wizardReviewOverdue => 'Relances dues';

  @override
  String get wizardReviewPending => 'Paiements à valider';

  @override
  String get wizardReviewToIssue => 'À émettre';

  @override
  String get wizardRunEnd => 'Fin de mois';

  @override
  String get wizardRunEndHint =>
      'Ce que le mois écoulé a coûté : consommation et frais supplémentaires. Émettre, envoyer, relancer — puis enregistrer, valider et rapprocher les paiements, et clôturer.';

  @override
  String get wizardRunStart => 'Début de mois';

  @override
  String get wizardRunStartHint =>
      'Les abonnements payés d\'avance : les émettre pour le mois à venir, les envoyer, prévoir les relances — puis le volet paiements.';

  @override
  String get wizardSendDownload => 'Télécharger le PDF';

  @override
  String get wizardSendHint =>
      'Remettez chaque facture à son membre — partagez le PDF, ou téléchargez-le pour l\'envoyer à votre manière.';

  @override
  String get wizardSendNone =>
      'Aucune facture de cette passe à envoyer pour l\'instant.';

  @override
  String get wizardSendShare => 'Partager le PDF';

  @override
  String wizardSettle(int count) {
    return 'Regrouper $count';
  }

  @override
  String get wizardStepClose => 'Clôturer';

  @override
  String get wizardStepCompleted => 'Terminée';

  @override
  String get wizardStepIssue => 'Émettre';

  @override
  String get wizardStepMatch => 'Rapprocher';

  @override
  String get wizardStepPayments => 'Paiements';

  @override
  String get wizardStepRemind => 'Relancer';

  @override
  String get wizardStepReview => 'Revue';

  @override
  String get wizardStepSend => 'Envoyer';

  @override
  String get wizardStepSkipped => 'Ignorée — réglages proposés';

  @override
  String get wizardStepSummary => 'Récapitulatif';

  @override
  String get wizardStepUnavailable => 'Pas encore disponible';

  @override
  String get wizardSubmitting => 'Envoi en cours';

  @override
  String get wizardSummaryHint => 'Ce que cette passe a fait';

  @override
  String get wizardTallyDecided => 'Paiements confirmés ou refusés';

  @override
  String get wizardTallyIssued => 'Factures émises';

  @override
  String get wizardTallyMatched => 'Factures rapprochées';

  @override
  String get wizardTallyNothing => 'Rien n\'a été modifié.';

  @override
  String get wizardTallyRefunds => 'Remboursements';

  @override
  String get wizardTallyRegistered => 'Paiements enregistrés';

  @override
  String get wizardTallyReminded => 'Relances envoyées';

  @override
  String get wizardTallySettled => 'Regroupements';

  @override
  String get wizardTallyShared => 'PDF partagés ou téléchargés';

  @override
  String get wizardTallyWriteoffs => 'Abandons demandés';

  @override
  String get wizardTitle => 'Assistant de facturation';

  @override
  String get wizardTodoHeading => 'Encore ouvert — à qui de jouer';

  @override
  String get wizardTodoNone => 'Plus rien d\'ouvert.';

  @override
  String get wizardWhoValidators => 'Validateurs';

  @override
  String get wizardWhoYou => 'Vous';

  @override
  String get wizardWriteoff => 'Abandonner';

  @override
  String get wordingChangedOnly => 'Modifiés seulement';

  @override
  String get wordingDefaultLabel => 'Mot du produit';

  @override
  String get wordingIntro =>
      'Renommez un petit ensemble approuvé de mots du produit. Tout le reste conserve les mots du produit, et un terme que vous n\'avez pas renommé s\'affiche exactement comme avant.';

  @override
  String get wordingLocale => 'Langue';

  @override
  String get wordingNone => 'Aucun terme ne correspond.';

  @override
  String get wordingReset => 'Réinitialiser';

  @override
  String get wordingResetHint =>
      'Réinitialiser supprime votre mot et rétablit celui du produit.';

  @override
  String get wordingRow => 'Vocabulaire';

  @override
  String get wordingRowHint =>
      'Les mots que cet espace emploie pour une place, la légende et les onglets.';

  @override
  String get wordingSavedOne => 'Enregistré';

  @override
  String get wordingSearch => 'Rechercher un mot';

  @override
  String get wordingSurfaceBooking => 'Réservation';

  @override
  String get wordingSurfaceLegend => 'Légende';

  @override
  String get wordingSurfaceNavigation => 'Navigation';

  @override
  String get wordingSurfacePlan => 'L\'espace';

  @override
  String get wordingTitle => 'Vocabulaire';

  @override
  String get workbookExportBuilding => 'Construction du classeur…';

  @override
  String get workbookExportCancelled =>
      'Export annulé. Rien n’a été enregistré.';

  @override
  String workbookExportReading(String done, String total) {
    return 'Lecture des modèles : $done sur $total';
  }

  @override
  String get workbookExportSaving => 'Choisissez où l’enregistrer…';

  @override
  String get workbookExportTitle => 'Export du classeur';

  @override
  String get workbookNote =>
      'Un instantané de définitions de modèles. Modifier ce fichier ne change rien dans DesKilo, et ce n’est la sauvegarde d’aucun espace : il ne contient ni membres, ni réservations, ni factures, ni identifiants.';

  @override
  String get workbookStateDefault =>
      'le modèle ne dit rien ; la valeur par défaut s’applique';

  @override
  String get workbookStateExcluded => 'délibérément jamais publié';

  @override
  String get workbookStateInherit =>
      'le modèle ne dit rien ; la cible garde la sienne';

  @override
  String get workbookStateLocal => 'à définir localement';

  @override
  String get workbookStatePresent => 'le modèle fixe cette valeur';

  @override
  String get workbookStateUnknown => 'illisible ; rien n’est affirmé';

  @override
  String get workbookWide =>
      'Catalogs, RolePermissions, Validations et Fields montrent une valeur là où le modèle la fixe, et son état sinon';

  @override
  String get workspaceAddressLabel => 'Adresse de l\'espace';

  @override
  String get workspaceCodeCopied => 'Copié';

  @override
  String get workspaceCodeCopy => 'Copier l\'ID';

  @override
  String get workspaceCodeEdit => 'Changer l\'ID de l\'espace';

  @override
  String get workspaceCodeExplainer =>
      'Les coworkers scannent ce QR code — ou saisissent l\'ID — pour rejoindre cet espace.';

  @override
  String get workspaceCodeHint => '4 à 20 lettres ou chiffres, unique';

  @override
  String get workspaceCodeLabel => 'ID de l\'espace';

  @override
  String get workspaceCodeRejected =>
      'ID refusé — il doit comporter 4 à 20 lettres ou chiffres et ne pas être déjà pris.';

  @override
  String get workspaceCodeSharePng => 'Partager en PNG';

  @override
  String get workspaceCodeTitle => 'ID de l\'espace et QR';

  @override
  String get workspaceConfigAvailability => 'Disponibilité';

  @override
  String get workspaceConfigBookableWhole => 'réservable en entier';

  @override
  String get workspaceConfigClosures => 'Fermetures';

  @override
  String get workspaceConfigColName => 'Nom';

  @override
  String get workspaceConfigColRole => 'Rôle';

  @override
  String get workspaceConfigColStatus => 'Statut';

  @override
  String get workspaceConfigEmptyLevel => 'Aucune salle';

  @override
  String get workspaceConfigFeatures => 'Fonctionnalités activées';

  @override
  String get workspaceConfigFloorPlan => 'Plan';

  @override
  String get workspaceConfigGranularity => 'Granularité de réservation';

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
  String get workspaceConfigInvitations => 'Invitations';

  @override
  String get workspaceConfigMembersSection => 'Membres';

  @override
  String get workspaceConfigNone => 'Aucun';

  @override
  String get workspaceConfigOpenDays => 'Jours d\'ouverture';

  @override
  String get workspaceConfigOverview => 'Aperçu';

  @override
  String get workspaceConfigPdfExport => 'Exporter la configuration (PDF)';

  @override
  String get workspaceConfigPdfExportSubtitle =>
      'Instantané complet : réglages, tous les membres et le plan.';

  @override
  String workspaceConfigPdfGeneratedOn(String date) {
    return 'Généré le $date';
  }

  @override
  String get workspaceConfigPdfTitle => 'Configuration de l\'espace';

  @override
  String get workspaceConfigSeats => 'Places';

  @override
  String get workspaceCountryLabel => 'Pays';

  @override
  String get workspaceCurrencyLabel => 'Devise';

  @override
  String get workspaceDangerZone => 'Zone de danger';

  @override
  String workspaceDeskOpacityValue(int percent) {
    return 'Opacité : $percent %';
  }

  @override
  String get workspaceDeskTransparencyHelper =>
      'Réduisez l\'opacité des tables pour laisser transparaître la photo de fond de l\'étage.';

  @override
  String get workspaceDeskTransparencyTitle => 'Transparence des tables';

  @override
  String get workspaceExcelExport => 'Exporter les données (Excel)';

  @override
  String get workspaceExcelExportSubtitle =>
      'Un ZIP : toutes les données dans un classeur (réservations, paiements, factures, membres, plan — un onglet chacun), un manifeste qui en compte les lignes, et les fichiers de l\'espace.';

  @override
  String get workspaceFieldsOptional => 'facultatif';

  @override
  String get workspaceFieldsPersonalNote =>
      'Vos réponses sont des données personnelles : elles figurent dans votre export de données et sont effacées quand vous quittez cet espace, sauf obligation légale de conservation documentée par l\'espace.';

  @override
  String get workspaceFieldsSaveFailed =>
      'Vos réponses aux questions de cet espace n\'ont pas été enregistrées. Le reste de vos informations, si.';

  @override
  String workspaceFieldsTitle(String workspace) {
    return 'Questions de $workspace';
  }

  @override
  String get workspaceGenericError =>
      'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get workspaceInviteCodeInvalid =>
      'Aucun identifiant trouvé — collez l\'invitation ou saisissez l\'identifiant.';

  @override
  String get workspaceInviteCodeLabel => 'Code d\'invitation';

  @override
  String get workspaceInvitePasteHint =>
      'Collez le message d\'invitation entier — l\'identifiant est trouvé automatiquement.';

  @override
  String get workspaceLanguageHelper =>
      'Les invitations sont rédigées par défaut dans cette langue. La langue de votre application se règle dans Réglages.';

  @override
  String get workspaceLanguageLabel => 'Langue de l\'espace';

  @override
  String get workspaceLanguageUnset => 'Langue de l\'app de l\'expéditeur';

  @override
  String get workspaceNameLabel => 'Nom de l\'espace';

  @override
  String get workspacePaymentsBillingTitle => 'Paiements et facturation';

  @override
  String get workspaceResetConfirmButton => 'Réinitialiser l\'espace';

  @override
  String workspaceResetConfirmLabel(String phrase) {
    return 'Saisissez « $phrase » pour confirmer';
  }

  @override
  String get workspaceResetConfirmPhrase => 'J\'accepte';

  @override
  String get workspaceResetDialogTitle => 'Réinitialiser cet espace ?';

  @override
  String get workspaceResetDone => 'Espace réinitialisé.';

  @override
  String get workspaceResetSubtitle =>
      'Supprime toutes les réservations, la comptabilité et le plan. Conserve les réglages et les membres.';

  @override
  String get workspaceResetTitle => 'Réinitialiser l\'espace';

  @override
  String get workspaceResetWarning =>
      'Cela supprime définitivement toutes les réservations, toute la comptabilité et le grand livre, le fil d\'activité, ainsi que l\'intégralité du plan — étages, salles, tables, places et images. Les réglages de l\'espace, les paliers tarifaires, les disponibilités, les fonctionnalités, les catalogues et les membres sont conservés. Action irréversible.';

  @override
  String get workspaceSettingsConflict =>
      'Quelqu\'un a modifié ces réglages pendant votre saisie. Rien n\'a été enregistré ; vos modifications sont toujours là.';

  @override
  String get workspaceSettingsCurrencyHelper =>
      'Proposée d\'après le pays — modifiable si votre communauté facture dans une autre devise.';

  @override
  String get workspaceSettingsSaved => 'Espace enregistré.';

  @override
  String get workspaceSettingsTitle => 'Espace de coworking';

  @override
  String get workspaceTimezoneHint => 'Europe/Paris';

  @override
  String get workspaceTimezoneLabel => 'Fuseau horaire';

  @override
  String get workspaceTimezoneUnknown => 'Choisissez un fuseau dans la liste';

  @override
  String get workspaceWhatsappGroupHelper =>
      'Affiché aux membres pour qu\'ils puissent rejoindre le groupe WhatsApp de la communauté. Collez le lien d\'invitation du groupe (https://chat.whatsapp.com/…). Laisser vide pour ne rien afficher.';

  @override
  String get workspaceWhatsappGroupInvalid =>
      'Doit être un lien d\'invitation chat.whatsapp.com';

  @override
  String get workspaceWhatsappGroupLabel => 'Lien du groupe WhatsApp';

  @override
  String get workspaceWhatsappGroupTitle => 'Groupe WhatsApp';

  @override
  String get workspaceXmlErrorInvalidPlan =>
      'Le plan des locaux du fichier est invalide : des salles, bureaux ou places se chevauchent ou dépassent de leur zone.';

  @override
  String get workspaceXmlErrorInvalidValue =>
      'Le fichier contient une valeur invalide et ne peut pas être importé.';

  @override
  String get workspaceXmlErrorMalformed =>
      'Le fichier n\'est pas un XML lisible.';

  @override
  String get workspaceXmlErrorMissingAttribute =>
      'Le fichier est incomplet — une valeur requise est manquante.';

  @override
  String get workspaceXmlErrorMissingElement =>
      'Le fichier est incomplet — une section requise est manquante.';

  @override
  String get workspaceXmlErrorUnsupportedVersion =>
      'Le fichier a été exporté par une version plus récente de DesKilo et ne peut pas être importé.';

  @override
  String get workspaceXmlErrorWrongRoot =>
      'Ce n\'est pas un fichier d\'espace DesKilo.';

  @override
  String get workspaceXmlExport => 'Exporter l\'espace (XML)';

  @override
  String get workspaceXmlExportSubtitle =>
      'Paramètres et plan des locaux dans un fichier partageable. Sans membres, réservations ni données financières.';

  @override
  String get workspaceXmlFileTypeLabel => 'XML';

  @override
  String get workspaceXmlImport => 'Importer l\'espace (XML)';

  @override
  String get workspaceXmlImportConfigurationOnly =>
      'La configuration a été appliquée. Le plan a été conservé : cet espace a déjà des réservations, son plan ne peut pas être remplacé.';

  @override
  String get workspaceXmlImportConfirm => 'Remplacer et importer';

  @override
  String get workspaceXmlImportPartial =>
      'Une partie de l’import a été appliquée avant l’arrêt — vérifiez les paramètres et le plan ci-dessous.';

  @override
  String workspaceXmlImportPreviewAccessories(int count) {
    return 'Accessoires : $count';
  }

  @override
  String workspaceXmlImportPreviewConfiguration(
    int settings,
    int tables,
    int rows,
  ) {
    return 'Configuration : $settings réglages, $rows lignes dans $tables tables';
  }

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
  String get workspaceXmlImportPreviewTitle => 'Remplacer le plan des locaux ?';

  @override
  String get workspaceXmlImportPreviewWarning =>
      'Le plan actuel sera supprimé et remplacé, et les paramètres de l\'espace seront écrasés. Cette action est irréversible.';

  @override
  String get workspaceXmlImportReservationsError =>
      'Cet espace a déjà des réservations, son plan des locaux ne peut donc pas être remplacé. L\'import n\'est possible qu\'avant la première réservation.';

  @override
  String get workspaceXmlImportSubtitle =>
      'Restaurer les paramètres et le plan des locaux depuis un fichier exporté. Remplace le plan actuel.';

  @override
  String get workspaceXmlImportSuccess => 'Espace importé.';
}
