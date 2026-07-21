# Guide utilisateur

Tout ce qu'un membre, un admin ou un propriétaire doit savoir pour utiliser DesKilo.

> Les captures d'écran de ce guide montrent l'application en français — chaque écran existe à l'identique dans les cinq langues (English, Français, Deutsch, Español, Italiano) ; changez dans **Réglages → Langue**.

![](assets/help/images/settings-language.jpg)

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

Le propriétaire règle cela par **domaine** dans **Réglages → Règles de validation** : paiements, dépenses, services, demi-journées supplémentaires, changements de rôle, réservations et ajustements ont chacun leur règle (ou héritent de la règle par défaut). Une règle fixe le nombre de validations requises, *quels* admins peuvent valider (tous, ou nommés), et si le propriétaire doit toujours signer.

![](assets/help/images/validation-rules.jpg)

 

![](assets/help/images/validation-rule-edit.jpg)

*À gauche : une règle par domaine, héritant de la règle par défaut. À droite : édition d'une règle — validations requises, validateurs autorisés, signature du propriétaire.*

## 7. Pour les propriétaires : éditeur et réglages

Toute l'administration vit sous **Réglages → Administration**. Une règle à connaître : **l'entrée de réglages d'une fonctionnalité n'apparaît que tant que la fonctionnalité est activée** — désactivez *Paiements en ligne* dans **Fonctionnalités** et son écran de configuration disparaît avec elle (il revient quand vous la réactivez). L'entrée **Fonctionnalités** elle-même est toujours là, pour pouvoir toujours réactiver un module.

![](assets/help/images/settings-administration.jpg)

- **Éditeur** (barre d'app) : dessinez votre espace sur une grille — niveaux, bureaux, tables, places (avec orientation, type de chaise et équipements), blocage de places pour maintenance. Ajoutez une **photo d'arrière-plan** par niveau et des **images d'illustration** déplaçables et redimensionnables. Supprimer un élément portant des réservations futures oblige à les résoudre d'abord.
- **Identifiant & QR** : vos invitations liées aux rôles (§2). Vous pouvez remplacer l'identifiant généré par un identifiant mémorable (4–20 lettres/chiffres), le copier, ou partager le QR en PNG.
- **Disponibilité** : jours d'ouverture, jours de fermeture, et granularité — plage horaire libre, grille de minutes (5/15/30/60), demi-journées, ou journées entières uniquement.
- **Fonctionnalités** : activez ou désactivez des modules entiers par espace — calendrier, événements, argent, services, export PDF, séries, réserver pour autrui, notifications push, blocage de places par les admins, suppléments d'accessoires, **paiements en ligne**, **badges RFID/NFC**. Désactiver un module retire *tous* ses écrans et boutons pour tous les membres.

![](assets/help/images/workspace-id-qr.jpg)

 

![](assets/help/images/availability-granularity.jpg)

 

![](assets/help/images/features-toggles-1.jpg)

 

![](assets/help/images/features-toggles-2.jpg)

- **Membres & forfaits** : touchez un membre pour ouvrir sa **feuille de gestion** — lui ajouter un service, régler son pourcentage d'abonnement, choisir sa **politique de dépassement** (§8), plafonner ses **réservations simultanées**, émettre ses **badges** (§9), le promouvoir/rétrograder admin, transformer le compte en **borne**, ou mettre l'adhésion en pause.

![](assets/help/images/member-management-sheet.jpg)

 

![](assets/help/images/member-subscription.jpg)

 

![](assets/help/images/member-reservation-limit.jpg)

*La feuille de gestion, le dialogue de pourcentage d'abonnement, et la limite de réservations par membre.*

- **Facturation** : tranches tarifaires des abonnements en pourcentage, tarifs de dépassement, niveaux d'abonnement proposés (avec valeur libre négociée en option) — et **forfaits de jours** (un nombre de jours pour un prix) pour les membres en politique « forfait ».
- **Services** et **Accessoires** : les catalogues derrière le §8 — extras définis par le propriétaire (casiers, impression…) et équipements de place avec supplément par demi-journée en option. Deux listes simples avec un bouton **+**.

![](assets/help/images/billing-bands-levels-packages.jpg)

 

![](assets/help/images/services-catalog.jpg)

 

![](assets/help/images/services-new-service.jpg)

 

![](assets/help/images/accessories-catalog.jpg)

*Facturation (tranches, niveaux, forfaits de jours) · le catalogue Services et son formulaire de création · le catalogue Accessoires. Un admin ajoute une consommation de service pour un membre depuis sa feuille de gestion :*

![](assets/help/images/member-add-service.jpg)

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
3. **Enregistrez** — une pastille verte *Configuré* apparaît. Activez la fonctionnalité **Paiements en ligne** (Réglages → Fonctionnalités) et les membres voient **Payer en ligne** sur une facture impayée. (L'entrée de réglages *Paiements en ligne* elle-même n'apparaît que quand la fonctionnalité est activée.)

![](assets/help/images/payment-config-paypal-stripe.jpg)

 

![](assets/help/images/payment-config-mollie-wero.jpg)

Une clé secrète enregistrée n'est plus jamais affichée — laissez le champ vide pour la conserver, saisissez pour la remplacer, **Supprimer** pour retirer le prestataire. Les frais sont ceux du prestataire (typiquement ~1,5–3 % par paiement, sans abonnement mensuel) ; DesKilo n'ajoute rien, et le virement/IBAN manuel reste gratuit.

Si un paiement ne démarre pas, activez **Réglages → Avancé → Mode développeur** et ouvrez l'écran **Développeur** : la trace *payments* montre exactement quels prestataires sont configurés et quels champs manquent encore.

![](assets/help/images/developer-payment-traces.jpg)

#### Les tableaux de bord des prestataires, pas à pas

Séparez **strictement les environnements de test et de production** : chaque prestataire a des clés distinctes par mode, et toutes les clés collées dans DesKilo doivent appartenir au même mode. Dans les URL ci-dessous, `<project-ref>` est la référence de votre projet Supabase (les auto-hébergeurs utilisent l'URL de leur instance).

**PayPal**

1. Connectez-vous sur [developer.paypal.com](https://developer.paypal.com) et ouvrez **Apps & Credentials**.
2. Basculez l'interrupteur **Sandbox / Live** — commencez en *sandbox* ; passez en *live* seulement pour la production. Le champ *Environnement* de DesKilo doit correspondre aux clés.
3. **Créez une app REST-API** — cela génère le **Client ID** et le **Secret**.
4. Dans l'app, ajoutez un **webhook** : URL `https://<project-ref>.supabase.co/functions/v1/paypal-webhook`, abonné au minimum à *Payment capture completed* (plus *denied* / *order voided*). Copiez l'**ID du webhook**. Dans DesKilo, le webhook n'est pas optionnel — c'est lui qui règle le paiement sur la facture.
5. Collez Client ID, Secret, Environnement, ID du webhook et votre URL de retour dans **Réglages → Paiements en ligne → PayPal**. Rien n'est stocké dans l'application ni sur un appareil — tout part sur le serveur.

**Stripe (cartes bancaires & Cartes Bancaires)**

1. Connectez-vous sur [dashboard.stripe.com](https://dashboard.stripe.com) et ouvrez **Developers**.
2. L'interrupteur **Mode test / Mode live** décide des clés affichées. DesKilo n'a besoin que de la **clé secrète** — le paiement est créé côté serveur, la clé *publishable* n'est pas utilisée.
3. Sous **Settings → Payment methods**, activez les réseaux souhaités. **Vous visez la France ? Activez explicitement Cartes Bancaires** — les membres français préfèrent souvent le réseau CB au routage international Visa/Mastercard.
4. Sous **Developers → Webhooks**, ajoutez le point de terminaison `https://<project-ref>.supabase.co/functions/v1/stripe-webhook` avec l'événement `checkout.session.completed`, et copiez le **secret de signature du webhook**.
5. Collez la clé secrète, le secret de signature et votre URL de retour dans **Réglages → Paiements en ligne → Carte bancaire (Stripe)**.

**Mollie (iDEAL, Bancontact, Wero…)**

1. Connectez-vous sur [my.mollie.com](https://my.mollie.com) → **Developers → API keys** et copiez la **clé API Test** ou **Live** (le mode est encodé dans la clé elle-même).
2. Sous **Settings → Payment methods**, activez ce que vos membres doivent voir : **iDEAL** (Pays-Bas), **Bancontact** (Belgique), cartes — et **Wero**, le portefeuille de l'European Payments Initiative pour les paiements instantanés de compte à compte en Allemagne, France et Belgique (le successeur de Paylib et giropay).
3. Dans DesKilo, **Mollie** et **Wero** sont deux cartes prestataire partageant la même clé API — un paiement Wero est créé comme un paiement Mollie avec la méthode Wero. Configurez ce que vos membres doivent voir.
4. Les URL de redirection et de webhook sont définies **automatiquement par DesKilo** à chaque paiement (redirection = votre URL de retour, webhook = la fonction `mollie-webhook`) — rien à configurer dans le tableau de bord Mollie.

#### D'autres méthodes de paiement (perspectives)

| Prestataire / méthode | Cible | Comment cela s'intègre à DesKilo |
|---|---|---|
| **Apple Pay / Google Pay** | Portefeuilles mobiles, paiement en un geste | Activez-les dans votre tableau de bord Stripe (ou Mollie) — ils apparaissent automatiquement sur la page de paiement hébergée, sans changement dans DesKilo ni frais de base supplémentaires. |
| **Klarna** | Paiement différé (BNPL) | Pareil : activez-le dans Stripe/Mollie et il apparaît au paiement — pertinent pour les montants élevés. |
| **Adyen** | Entreprise & omnicanal, une API pour presque toutes les méthodes | Non intégré — ce serait un nouveau prestataire dans DesKilo (contributions bienvenues). |
| **Braintree** | Drop-in mobile & web (propriété de PayPal) | Non intégré — l'intégration PayPal directe de DesKilo couvre déjà ce terrain. |

### Configurer les badges RFID / NFC (propriétaires)

Les cartes physiques permettent de pointer d'un simple contact — sans téléphone.

1. Ouvrez **Réglages → Badges RFID / NFC** (propriétaire uniquement). Activez **Activer le pointage par badge NFC**, et lisez la ligne d'**état de l'appareil** — il faut un appareil **Android** avec NFC activé (les iPad n'ont pas de NFC).
2. Donnez une carte à chaque membre : **Membres & forfaits → le membre → Badges → Enregistrer une carte**, puis approchez sa carte de l'appareil. Toute carte à puce lisible convient (MIFARE, NTAG…).
3. Utilisez-les à une **borne** (§9) : le membre approche sa carte pour réserver ou pointer. Révoquez une carte perdue depuis la même fenêtre Badges.

![](assets/help/images/nfc-config.jpg)

 

![](assets/help/images/member-badges-dialog.jpg)

*L'écran de configuration NFC (interrupteur de l'espace + état NFC de cet appareil) et la fenêtre Badges d'un membre : révoquer, enregistrer une carte, ou émettre un nouveau badge QR.*

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
