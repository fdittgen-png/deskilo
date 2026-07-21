# Guide utilisateur

Tout ce qu'un membre, un admin ou un propriétaire doit savoir pour utiliser DesKilo. *Autres langues : [English](User-Guide) · [Deutsch](Benutzerhandbuch) · [Español](Guia-de-usuario) · [Italiano](Guida-utente).*

## 1. Premiers pas

### Créer un compte

Ouvrez l'application et inscrivez-vous avec votre e-mail, un mot de passe (8 caractères minimum) et un nom affiché. Le bouton en forme d'œil permet d'afficher ou de masquer le mot de passe pendant la saisie.

### Créer un espace — ou en rejoindre un

Après connexion, l'écran d'accueil propose deux chemins :

- **Créer un espace de travail** — vous en devenez le **propriétaire**. Choisissez un nom, un pays (qui détermine la devise par défaut) et un fuseau horaire. Vous dessinerez ensuite votre plan dans l'éditeur (§7).
- **Rejoindre un espace** — saisissez l'**identifiant de l'espace** qu'on vous a communiqué, ou touchez **Scanner le QR code** et visez le QR d'invitation affiché au mur. Vous rejoignez avec le rôle que porte l'invitation (§2).

Un compte peut appartenir à plusieurs espaces ; changez d'espace dans **Réglages → Profils**. Tout dans l'application est limité à l'espace actif.

## 2. Rôles et invitations

DesKilo a trois rôles cumulatifs, plus un compte « appareil » :

| Rôle | Peut |
|---|---|
| **Membre** | Pointer à l'arrivée/au départ, réserver, soumettre des dépenses, voir et gérer ses propres événements et son propre compte |
| **Admin** | Tout ce qu'un membre peut faire, plus : agir *pour n'importe qui* (réservations, paiements, dépenses — soumis à confirmation, §6), approuver les dépenses, émettre des badges de borne |
| **Propriétaire** | Tout ce qu'un admin peut faire, plus : modifier l'espace physique, définir les forfaits et les prix, gérer les rôles, les bornes et les réglages de l'espace |
| **Borne** | Un compte de tablette murale (§9) — n'affiche que le plan ; les membres agissent à travers elle avec un badge |

**Chaque invitation est liée à un rôle.** Sur l'écran *Identifiant & QR* du propriétaire, il existe deux invitations, chacune avec son propre QR code et son propre code :

- **Invitation membre** — l'identifiant de l'espace lui-même. Imprimez-le, affichez-le au mur, partagez-le librement : quiconque le scanne ou le saisit rejoint comme simple membre.
- **Invitation admin** — un code secret distinct, visible des propriétaires uniquement. Ne le partagez qu'avec les personnes qui doivent gérer l'espace : quiconque l'utilise rejoint comme admin.

**Il n'existe pas d'invitation propriétaire — c'est voulu.** La propriété ne peut être accordée que par un propriétaire existant, dans *Membres & forfaits*. Un espace garde toujours au moins un propriétaire : l'application refuse de rétrograder ou de retirer le dernier. Promouvoir ou rétrograder un **admin** passe par le flux de validation (§6) — le changement s'applique une fois confirmé par les validateurs de l'espace.

Le QR encode un lien qui nomme le rôle accordé (`deskilo://join?role=…`). Falsifier le lien ne change rien — le serveur déduit le rôle du code secret lui-même.

## 3. Le plan (onglet Plan)

Le plan montre le niveau actif de votre espace : bureaux, tables et places, avec un code couleur — **libre**, **réservée**, **occupée**, **la mienne**, **bloquée**. Les places occupées affichent le prénom de l'occupant, un **badge de pointage** quand il est arrivé, et un **point vert** quand il est en ligne dans l'application.

Le plan peut ressembler à votre espace réel : le propriétaire peut mettre une **photo de la pièce en arrière-plan du niveau** et placer des **images d'illustration redimensionnables** (plantes, canapés…) sur la grille. Un curseur de **transparence des tables** dans les réglages laisse la photo transparaître sous les tables dessinées.

Se repérer :

- Le canevas **s'ajuste automatiquement** à votre étage à l'ouverture ou à la rotation de l'appareil ; **pincez pour zoomer** ou utilisez les boutons **+ / −**, faites glisser les **barres de défilement** sur les bords, et touchez le bouton d'**ajustement** pour recentrer.
- Choisissez l'étage dans le **menu des niveaux** (liste compacte) ; l'icône d'horloge ramène la frise temporelle à **maintenant**.
- En **paysage**, les commandes passent dans un panneau latéral et le plan remplit l'écran — pratique sur tablette.

Réserver depuis le plan :

- **Pointage spontané** : touchez une place libre → la feuille propose *maintenant* jusqu'à la fin par défaut de l'espace → confirmez. Si quelqu'un a réservé cette place plus tard, votre heure de fin est plafonnée et on vous le dit.
- **Pointage sur réservation** : votre réservation ouvre une fenêtre de pointage. Pointez depuis le plan ou depuis la notification de rappel. En cas d'absence, la place est **libérée automatiquement** après le délai configuré.
- **Départ** : manuel, ou automatique à la fin de la réservation / à la fermeture.
- **Frise temporelle** : choisissez une fenêtre de→à (ou Matin / Après-midi / Journée entière selon la granularité de l'espace) pour voir l'occupation à tout moment futur.
- Les places peuvent porter des **accessoires** (écran, bureau debout…), certains avec un supplément par demi-journée qui apparaît sur votre relevé.
- Les réservations comptent dans vos **jours mensuels** (§8) — au-delà de votre forfait, l'application bloque ou facture, selon ce que le propriétaire a configuré pour vous.

## 4. Réservations (hub Réserver)

Ouvrez le hub **Réserver** (bouton central). Une bande de dates choisit le jour ; les puces de fenêtre choisissent l'horaire ; puis quatre vues :

- **Plan** — le plan filtré sur votre fenêtre ; touchez une place libre pour réserver.
- **Jour** — chaque place en ligne de chronologie pour le jour choisi ; touchez une plage libre pour réserver, votre propre bloc pour ses détails.
- **Semaine** — une grille place × jour pour toute la semaine ISO ; repérez une demi-journée libre d'un coup d'œil et touchez-la pour réserver.
- **Mois** — un calendrier de disponibilité : bureaux libres par jour tous étages confondus ; touchez un jour pour ouvrir sa vue Jour.

Les réservations suivent la **règle de granularité** de l'espace — demi-journées, journées entières, ou horaires libres sur la grille de créneaux du propriétaire. Elles respectent les **jours d'ouverture** et les **jours de fermeture**, et les règles de réservation (horizon, durée maximale, délai d'annulation). Besoin récurrent ? Réservez une **série** (quotidienne, jours ouvrés, hebdomadaire) — les jours fermés et les conflits sont sautés et signalés.

L'onglet **Calendrier** montre vos réservations par mois — vos jours en **rouge**, ceux des autres en **bleu**, aujourd'hui entouré — avec une chronologie par jour. En paysage, calendrier et chronologie utilisent la disposition en deux panneaux.

## 5. Annuaire des membres (onglet Membres)

Voyez qui fait partie de votre communauté :

- Chaque carte membre montre sa **photo** (ou initiale), son **rôle**, son **statut personnalisé** (« à Berlin jusqu'à vendredi… »), un indicateur **en ligne / vu récemment**, et une **puce de réservation** : place pointée, réservée maintenant, ou prochaine réservation.
- Touchez un membre pour sa **fiche détaillée** — avec ses réservations à venir.
- **Balayez** un membre pour lui écrire sur **WhatsApp** ; le **bouton de groupe** ouvre le groupe WhatsApp de la communauté (défini par le propriétaire).
- Définissez votre photo, votre statut et la visibilité de votre téléphone dans **Réglages**.

## 6. Événements et confirmations (icône cloche)

Le fil d'événements est la piste d'audit de votre espace : réservations créées/modifiées/annulées, paiements enregistrés, dépenses soumises, demandes de jours supplémentaires, changements de rôle. Les membres voient leurs propres événements ; admins et propriétaires voient tout.

**Le protocole de confirmation :** dès qu'un admin agit *pour quelqu'un d'autre* — réserve une place pour vous, enregistre votre paiement — l'action reste **en attente jusqu'à votre confirmation**. Les éléments en attente sont épinglés en haut avec des boutons accepter/refuser et vous êtes notifié. Vos actions sur vous-même ne demandent jamais de confirmation.

**Quorum de validation :** pour les questions d'argent et les changements de rôle, le propriétaire définit *qui* doit approuver et *combien* d'approbations il faut. Les demandes sans réponse expirent après 7 jours — rien de coûteux n'est jamais accordé en silence.

## 7. Pour les propriétaires : éditeur et réglages

- **Éditeur** (barre d'app) : dessinez votre espace sur une grille — niveaux, bureaux, tables, places (avec orientation, type de chaise et équipements), blocage de places pour maintenance. Ajoutez une **photo d'arrière-plan** par niveau et des **images d'illustration** déplaçables et redimensionnables. Supprimer un élément portant des réservations futures oblige à les résoudre d'abord.
- **Identifiant & QR** : vos invitations liées aux rôles (§2). Vous pouvez remplacer l'identifiant généré par un identifiant mémorable (4–20 lettres/chiffres).
- **Disponibilité** : jours d'ouverture, jours de fermeture, et granularité — demi-journées, journées entières, ou grille de minutes (15/30/60).
- **Fonctionnalités** : activez ou désactivez des modules entiers par espace — calendrier, événements, argent, services, export PDF, séries, réserver pour autrui, notifications push, blocage de places par les admins, suppléments d'accessoires, **paiements en ligne**.
- **Membres & forfaits** : pourcentages d'abonnement, **politique de dépassement** de chaque membre (§8), pause/sortie, promotions/rétrogradations d'admin, marquage des **bornes**, émission des **badges** (§9).
- **Facturation** : tranches tarifaires des abonnements en pourcentage, tarifs de dépassement, niveaux d'abonnement proposés — et **forfaits de jours** (un nombre de jours pour un prix) pour les membres en politique « forfait ».
- **Réglages de l'espace** : nom, pays/devise, fuseau, instructions de paiement (IBAN, PayPal.me, Wero, Lydia, Wise), lien du groupe WhatsApp, **transparence des tables**, exports — et la **zone dangereuse** : **réinitialisation complète** (supprime réservations, argent et plan ; conserve configuration et membres), protégée par la saisie de « I agree ».
- **Import/export** : toute la configuration voyage en **fichier XML** — sauvegarde, modèle, ou migration d'une instance auto-hébergée. Un **PDF de configuration** (membres, plan, prix, fonctionnalités) peut aussi être généré. Les fichiers sont enregistrés **localement sur votre appareil**.

### Configurer les paiements en ligne (propriétaires)

Chaque communauté encaisse sur son **propre** compte prestataire ; l'application ne conserve jamais les clés secrètes sur un appareil — elles restent sur le serveur.

1. Ouvrez **Réglages → Paiements en ligne** (propriétaire uniquement).
2. Choisissez un prestataire et collez ses clés depuis son tableau de bord :
   - **PayPal** — Client ID, Secret, Environnement (commencez par *sandbox*), ID du webhook, URL de retour (PayPal Developer → votre app REST).
   - **Carte bancaire (Stripe)** — Clé secrète, Secret de signature du webhook, URL de retour (Stripe → clés API / Webhooks).
   - **Mollie** — Clé API, URL de retour (propose iDEAL, Bancontact, cartes…).
   - **Wero (via Mollie)** — la même clé API Mollie, avec Wero activé dans votre compte Mollie.
3. **Enregistrez** — une pastille verte *Configuré* apparaît. Activez la fonctionnalité **Paiements en ligne** (Réglages → Fonctionnalités) et les membres voient **Payer en ligne** sur une facture impayée.

Une clé secrète enregistrée n'est plus jamais affichée — laissez le champ vide pour la conserver, saisissez pour la remplacer, **Supprimer** pour retirer le prestataire. Les frais sont ceux du prestataire (typiquement ~1,5–3 % par paiement, sans abonnement mensuel) ; DesKilo n'ajoute rien, et le virement/IBAN manuel reste gratuit.

### Configurer les badges RFID / NFC (propriétaires)

Les cartes physiques permettent de pointer d'un simple contact — sans téléphone.

1. Ouvrez **Réglages → Badges RFID / NFC** (propriétaire uniquement). Activez **Activer le pointage par badge NFC**, et lisez la ligne d'**état de l'appareil** — il faut un appareil **Android** avec NFC activé (les iPad n'ont pas de NFC).
2. Donnez une carte à chaque membre : **Membres & forfaits → le membre → Badges → Enregistrer une carte**, puis approchez sa carte de l'appareil. Toute carte à puce lisible convient (MIFARE, NTAG…).
3. Utilisez-les à une **borne** (§9) : le membre approche sa carte pour réserver ou pointer. Révoquez une carte perdue depuis la même fenêtre Badges.

## 8. Argent (onglet Argent)

Votre compte répond à *combien je dois, combien on me doit* — et *combien puis-je encore réserver* :

- **Ce mois-ci** — la carte en haut de votre facture : combien de **jours** votre abonnement inclut ce mois, combien sont **utilisés**, combien il en **reste**, avec une barre de progression. Une matinée réservée compte 0,5 jour. Le droit mensuel suit les jours d'ouverture de l'espace et votre pourcentage.
- **Quand vos jours sont épuisés**, la suite est un choix du propriétaire, par membre :
  - **Bloqué** (défaut) — plus de réservation ; demandez à un admin, ou demandez des **demi-journées supplémentaires** depuis l'onglet Argent (les validateurs approuvent ; les jours accordés restent facturés au tarif de dépassement).
  - **À l'usage** — vous continuez à réserver ; chaque jour supplémentaire est facturé au tarif de dépassement de votre tranche (affiché sur la carte).
  - **Forfaits** — touchez **Acheter un forfait** et choisissez un pack de jours du propriétaire ; vos jours augmentent immédiatement et le prix arrive sur la facture du mois.
- **Débits** : abonnement mensuel (forfait en pourcentage), dépassement, consommation de services, suppléments d'accessoires, forfaits de jours.
- **Crédits** : dépenses approuvées, paiements enregistrés, ajustements.
- **Relevés** : mensuels, avec statut **réglé / à régler**, exportables en **facture PDF** enregistrée localement.
- **Payer** : DesKilo suit les paiements ; une facture à régler affiche les **instructions de paiement** de l'espace (l'IBAN se copie d'un geste, PayPal.me s'ouvre directement). Enregistrez un paiement (« j'ai payé ») avec sa méthode — l'autre partie confirme. Si l'espace a activé les **paiements en ligne** et que son serveur est configuré, un bouton **Payer en ligne** permet de régler le montant dû aussitôt — par **PayPal, carte bancaire (Stripe), Mollie ou Wero**, selon ce que l'espace a activé (plusieurs affichent un choix).
- **Dépenses** : vous avez acheté du café pour l'espace ? Soumettez la dépense — un autre admin l'approuve (pas d'auto-approbation) et le montant est crédité sur votre prochain relevé.
- **Services** : extras définis par le propriétaire (casiers, impression…) dont la consommation arrive sur votre relevé après votre confirmation.

## 9. Mode borne (tablette murale)

Fixez une tablette Android ou un iPad près de la porte et laissez chacun pointer en entrant :

1. Le propriétaire crée un compte normal pour l'appareil, le fait rejoindre l'espace, et le marque comme **borne** dans *Membres & forfaits*. Dès lors ce compte est verrouillé sur le plan en plein écran — aucun autre écran, rien d'autre à toucher.
2. Le propriétaire (ou un admin) donne un **badge** à chaque membre, dans *Membres & forfaits → un membre → Badges*. Deux types :
   - **QR code** — affiché **une seule fois** ; touchez **Enregistrer en PDF** pour imprimer une carte de badge, ou gardez le QR sur le téléphone du membre.
   - **Carte RFID/NFC** — touchez **Enregistrer une carte** et approchez la carte physique du membre (Android avec NFC). Configurez-le dans *Réglages → Badges RFID / NFC* (§7).
   Chaque badge est révocable à tout moment.
3. À la borne : touchez une place → **Arrivée**, **Réserver** ou **Départ** → présentez le badge : **approchez la carte RFID/NFC**, scannez le QR avec un lecteur de codes-barres USB/Bluetooth, ou saisissez le code.

Votre identité n'existe que le temps de l'opération : l'identifiant est envoyé une fois au serveur, la réservation est faite **à votre nom**, et rien n'est stocké sur la tablette — vous êtes « déconnecté » dès que c'est terminé. (Le scan QR par caméra et la connexion ponctuelle Google/Facebook restent sur la feuille de route ; **les iPad n'ont pas de NFC**, le QR y est donc la voie à suivre.)

## 10. Notifications

Rappels de pointage, libérations pour absence, confirmations en attente, décisions de dépense. La livraison est locale d'abord ; sur Android, la version F-Droid utilise **UnifiedPush** (p. ex. ntfy) au lieu des services Google — aucun Firebase nulle part.

## 11. Confidentialité

Données minimales : nom, e-mail, forfait, réservations, compte. Vous contrôlez votre photo, votre statut, l'affichage de votre nom sur le plan et la visibilité de votre numéro dans l'annuaire. Les badges de borne ne sont stockés que sous forme de hachés — un badge perdu se révoque, il ne se devine pas. Pas de pistage, pas d'analytique tierce. L'historique financier est anonymisé, pas supprimé, à l'effacement du compte (obligations comptables).

## 12. Plateformes

Android (Google Play et F-Droid), iPhone/iPad, et bureau — macOS, et Windows avec un **installateur MSI** produit à chaque version. Vos données suivent votre compte.
