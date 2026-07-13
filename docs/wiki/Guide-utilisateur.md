# Guide utilisateur

Tout ce qu'un membre, un admin ou un propriétaire doit savoir pour utiliser DesKilo. *English version: [User Guide](User-Guide).*

## 1. Premiers pas

### Créer un compte

Ouvrez l'application et inscrivez-vous avec votre e-mail, un mot de passe (8 caractères minimum) et un nom affiché. Le bouton en forme d'œil permet d'afficher ou de masquer le mot de passe pendant la saisie.

### Créer un espace — ou en rejoindre un

Après connexion, l'écran d'accueil propose deux chemins :

- **Créer un espace de travail** — vous en devenez le **propriétaire**. Choisissez un nom, un pays (qui détermine la devise par défaut) et un fuseau horaire. Vous dessinerez ensuite votre plan dans l'éditeur (§7).
- **Rejoindre un espace** — saisissez l'**identifiant de l'espace** qu'on vous a communiqué, ou touchez **Scanner le QR code** et visez le QR d'invitation affiché au mur de votre espace. Vous rejoignez avec le rôle que porte l'invitation (§2).

Un compte peut appartenir à plusieurs espaces ; changez d'espace dans **Réglages → Profils**. Tout dans l'application est limité à l'espace actif.

## 2. Rôles et invitations

DesKilo a trois rôles cumulatifs :

| Rôle | Peut |
|---|---|
| **Membre** | S'enregistrer/partir, réserver, soumettre des dépenses, voir et gérer ses propres événements et son propre compte |
| **Admin** | Tout ce qu'un membre peut faire, plus : agir *pour n'importe qui* (réservations, paiements, dépenses — soumis à confirmation, §6), approuver les dépenses, configurer les règles de réservation |
| **Propriétaire** | Tout ce qu'un admin peut faire, plus : modifier l'espace physique, définir les forfaits et les prix, gérer les rôles et les réglages de l'espace |

**Chaque invitation est liée à un rôle.** Sur l'écran *Identifiant & QR* du propriétaire, il existe deux invitations, chacune avec son propre QR code et son propre code :

- **Invitation membre** — l'identifiant de l'espace lui-même. Imprimez-le, affichez-le au mur, partagez-le librement : quiconque le scanne ou le saisit rejoint comme simple membre.
- **Invitation admin** — un code secret distinct, visible des propriétaires uniquement. Ne le partagez qu'avec des personnes qui doivent gérer l'espace : quiconque l'utilise rejoint comme admin.

**Il n'existe pas d'invitation propriétaire — c'est voulu.** La propriété ne peut être accordée que par un propriétaire existant, dans *Membres & forfaits*. Un espace garde toujours au moins un propriétaire : l'application refuse de rétrograder ou de supprimer le dernier.

Le QR encode un lien qui nomme le rôle qu'il accorde (`deskilo://join?role=…`). Falsifier le lien ne change rien — le serveur déduit le rôle du code secret lui-même.

## 3. Le plan (onglet Plan)

Le plan montre le niveau actif de votre espace : bureaux, tables et places, avec un code couleur — **libre**, **réservée**, **occupée**, **la mienne**, **bloquée**. Les places occupées montrent qui s'y trouve (chaque membre contrôle sa propre visibilité dans les Réglages).

- **Enregistrement spontané** : touchez une place libre → la fiche propose *maintenant* jusqu'à l'heure de fin par défaut → confirmez. Si quelqu'un a réservé cette place plus tard, votre heure de fin est plafonnée et vous en êtes informé.
- **Enregistrement sur réservation** : votre réservation ouvre une fenêtre d'enregistrement (par défaut 15 min avant le début). Enregistrez-vous depuis le plan ou depuis la notification de rappel. En cas d'absence, la place est **libérée automatiquement** après le délai configuré et vous êtes notifié.
- **Départ** : manuel, ou automatique à la fin de la réservation / à la fermeture.
- **Curseur temporel** : faites glisser la frise sous le plan pour voir l'occupation à n'importe quel moment futur ; le bouton *Maintenant* revient au direct.
- Les places peuvent porter des **accessoires** (écran, bureau debout…), certains avec un supplément par demi-journée qui apparaît sur votre relevé.

## 4. Réservations

Ouvrez le hub **Réserver** (bouton central) ou touchez une place sur le plan à un moment futur.

- Les réservations suivent la **granularité** de l'espace : demi-journées, journées entières, ou horaires libres — le propriétaire choisit.
- La **vue semaine** affiche une grille place × jour pour toute la semaine — trouvez une place libre d'un coup d'œil.
- L'onglet **calendrier** liste vos réservations par mois/semaine/jour.
- Les réservations respectent les **jours d'ouverture** et **jours de fermeture** de l'espace, ainsi que les règles de réservation (horizon, durée maximale, délai d'annulation — définis par le propriétaire dans *Disponibilité*).
- Annuler après le délai compte quand même comme consommation — l'application vous prévient avant de confirmer.

## 5. Annuaire des membres (onglet Membres)

Voyez qui fait partie de votre communauté :

- Chaque fiche montre le **statut personnalisé** du membre (« à Berlin jusqu'à vendredi… ») et une **puce de réservation** : place occupée, réservée en ce moment, ou prochaine réservation.
- **Glissez** sur un membre (ou ouvrez sa fiche) pour lui écrire sur **WhatsApp**.
- Le **bouton groupe** ouvre le groupe WhatsApp de votre communauté (configuré par le propriétaire).
- Définissez votre propre statut et la visibilité de votre numéro dans les **Réglages**.

## 6. Événements et confirmations (icône cloche)

Le fil d'événements est la piste d'audit de votre espace : réservations créées/modifiées/annulées, paiements enregistrés, dépenses soumises/approuvées, ajustements. Les membres voient leurs propres événements ; les admins et propriétaires voient tout.

**Le protocole de confirmation :** dès qu'un admin agit *pour quelqu'un d'autre* — réserve une place pour vous, enregistre votre paiement, annule votre réservation — l'action reste **en attente jusqu'à votre confirmation**. Les éléments en attente sont épinglés en haut avec les boutons accepter/refuser et vous recevez une notification. Ce que vous faites pour vous-même ne demande jamais confirmation.

## 7. Pour les propriétaires : l'éditeur et les réglages

- **Éditeur** (barre d'application) : dessinez votre espace sur une grille — ajoutez des niveaux, tracez les bureaux, placez les tables, posez les places (une place est un emplacement 6×4 avec une orientation), attribuez types de chaise et équipements, bloquez des places pour maintenance. Supprimer un élément avec des réservations futures impose de les résoudre d'abord.
- **Identifiant & QR** : vos invitations liées aux rôles (§2). Vous pouvez remplacer l'identifiant généré par un identifiant mémorable (4–20 lettres/chiffres).
- **Disponibilité** : jours d'ouverture, jours de fermeture, granularité et règles de réservation.
- **Fonctionnalités** : activez ou désactivez des modules entiers (onglet événements, services…) par espace.
- **Membres & forfaits** : attribuez les pourcentages d'abonnement, suspendez/sortez des membres, accordez ou retirez les rôles admin et propriétaire.
- **Facturation** : forfaits sur le modèle quota + dépassement, tranches de tarif, taux de dépassement.
- **Import/export** : toute la configuration du plan voyage dans un fichier XML — sauvegarde, modèle, ou migration d'une instance auto-hébergée.

## 8. Argent (onglet Argent)

Votre compte répond à *qu'est-ce que je dois, qu'est-ce qu'on me doit* :

- **Débits** : abonnement mensuel (forfait en pourcentage), demi-journées de dépassement, consommation de services, suppléments d'accessoires.
- **Crédits** : dépenses approuvées, paiements enregistrés, ajustements.
- **Relevés** : mensuels, avec statut **payé / partiellement payé / impayé**, exportables en **facture PDF**.
- **Enregistrer un paiement** : DesKilo suit les paiements, il ne les traite pas. Payez par virement/espèces selon l'usage de votre communauté, puis enregistrez-le (« j'ai payé ») — l'admin confirme ; ou l'admin l'enregistre (« reçu ») — vous confirmez. Les relevés impayés affichent les **instructions de paiement** de l'espace et peuvent ouvrir directement le lien **PayPal.me** du propriétaire.
- **Dépenses** : vous avez acheté du café pour l'espace ? Soumettez la dépense avec montant et description. Un autre admin l'approuve (pas d'auto-approbation), et le montant est crédité sur votre prochain relevé.
- **Services** : extras définis par le propriétaire (casiers, impression…) dont la consommation apparaît sur votre relevé.

## 9. Notifications

Rappels d'enregistrement, libérations pour absence, confirmations en attente, décisions sur les dépenses. La livraison est locale d'abord ; sur Android, la version F-Droid utilise **UnifiedPush** (p. ex. ntfy) au lieu des services Google — aucun Firebase nulle part.

## 10. Confidentialité

Données minimales : nom, e-mail, forfait, réservations, compte. Vous contrôlez l'affichage de votre nom sur le plan et la visibilité de votre numéro dans l'annuaire. Pas de pistage, pas d'analytique tierce. L'historique financier est anonymisé, pas supprimé, lors de l'effacement du compte (obligation comptable).

## 11. Plateformes

Android (Google Play et F-Droid), iPhone/iPad, et ordinateur — macOS et Windows — avec la même application. Vos données suivent votre compte.
