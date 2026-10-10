<!-- anchor: user.space.overview -->
## Votre espace, configuré par vous (Réglages de l'espace)

Ce chapitre s'adresse aux personnes qui font vivre un espace : propriétaires, copropriétaires et administrateurs à qui ils confient les réglages. Vous y dessinez les étages, décidez qui peut entrer et quand, choisissez les fonctionnalités qui existent, donnez à l'espace son aspect et ses mots, et gardez une copie de tout.

Dans ce chapitre :
- [Dessiner vos étages, vos pièces et vos tables](help:user.space.editor.levels)
- [Inviter des personnes avec l'ID de l'espace](help:user.workspace.code)
- [Dire quand l'espace est ouvert](help:user.workspace.availability.open-weekdays)
- [Activer et désactiver des fonctionnalités](help:user.features.processes)
- [Remplir les réglages de l'espace](help:user.workspace.settings.country)
- [Donner à l'espace ses couleurs et ses mots](help:user.workspace.settings.wording)
- [Décider qui peut faire quoi](help:user.roles.matrix)
- [Faire tourner une tablette murale et des badges](help:user.kiosk.mode)
- [Tenir une bibliothèque de documents](help:user.documents.add)
- [Exporter et importer l'espace](help:user.workspace.export.space-xml)

> **Astuce** La plupart des écrans de ce chapitre se trouvent dans le menu, sous **Espace**, **Disponibilité**, **Fonctionnalités** et **Rôles**. Chaque entrée n'apparaît que pour les personnes qui détiennent la permission nécessaire, et certaines seulement quand leur fonctionnalité est activée. Un administrateur ne voit ces écrans que si le propriétaire lui en a donné l'autorisation dans la matrice des rôles.

<!-- anchor: user.space.editor.levels -->
### Éditeur d'espace : ajouter, renommer et supprimer des étages

**Public:** Propriétaire · Administrateur·rice

Vous voulez donner au bâtiment ses étages, dans l'ordre que l'on attend. L'**Éditeur d'espace** liste tous les étages de l'espace.

<p><img src="images/user-space-editor-levels.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez l'[Éditeur d'espace](app:/editor), ou touchez **Modifier l'espace** sur l'écran Réserver.
2. Touchez **Ajouter un étage**, saisissez le nom et touchez **Enregistrer**.
3. Faites glisser la poignée à gauche d'un étage pour changer l'ordre.
4. Touchez les trois points (**Actions de l'étage**) pour **Renommer** ou **Supprimer** un étage.
5. Touchez un étage pour y dessiner.

**Bon à savoir**

- Supprimer un étage supprime tous les bureaux, tables et places qui s'y trouvent. La confirmation indique ce que deviennent les réservations qui les concernent.
- La ligne sous chaque étage indique s'il est **Réservable en entier** ou **Non réservable en entier**.
- Sans aucun étage, l'éditeur affiche **Aucun étage pour l'instant. Ajoutez le premier étage de votre espace.**

**Voir aussi:** [Réserver un étage entier](help:user.space.editor.level-booking) · [Dessiner pièces, tables et places](help:user.space.editor.rooms)

<!-- anchor: user.space.editor.level-booking -->
### Laisser les membres réserver un étage entier

**Public:** Propriétaire · Administrateur·rice

Vous voulez qu'une équipe puisse prendre un étage complet pour une journée.

<p><img src="images/user-space-editor-level-booking.fr.jpg" width="280"></p>

**Étapes**

1. Dans l'[Éditeur d'espace](app:/editor), touchez le bouton de couches sur la ligne de l'étage.
2. Activez **Réservable en entier**.
3. Saisissez le **Prix par demi-journée**.
4. Touchez **Enregistrer**.

**Bon à savoir**

- Le bouton de couches est plein quand l'étage est réservable en entier.
- Réserver un étage, un bureau ou une table en entier demande aussi la fonctionnalité **Réservations de table, bureau et niveau**. Chaque membre doit avoir le droit de réserver un niveau ; les administrateurs l'ont automatiquement. Voir [Un interrupteur de fonctionnalité](help:user.features.switch).

**Voir aussi:** [Propriétés d'un bureau ou d'une table](help:user.space.editor.office)

<!-- anchor: user.space.editor.rooms -->
### Dessiner pièces, tables et places

**Public:** Propriétaire · Administrateur·rice

Vous voulez que le plan à l'écran ressemble à l'étage réel. Tout se place dans une pièce : vous dessinez une pièce, y mettez des tables, puis des places sur les tables.

<p><img src="images/user-space-editor-rooms.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez un étage depuis l'[Éditeur d'espace](app:/editor). Un étage vide propose **Dessiner la première pièce**.
2. Touchez **Bureau** et faites glisser sur la grille pour dessiner une pièce.
3. Touchez **Table** et faites glisser dans la pièce pour dessiner une table.
4. Touchez **Place**, puis touchez une table pour y ajouter une place.
5. Touchez **Image**, puis touchez l'endroit où une illustration doit se trouver.
6. Touchez un élément pour le sélectionner. La barre du bas propose **Dupliquer**, **Propriétés** et **Supprimer**.

**Bon à savoir**

- Toucher une deuxième fois l'outil actif le repose, et le canevas revient à la sélection.
- L'application refuse une forme qui **Chevauche un élément existant.** ou qui **Doit être entièrement à l'intérieur d'un bureau.** Les places ne peuvent aller que sur une table, et une table pleine indique **Plus de place sur cette table.**
- Le bouton image en haut à droite définit, remplace ou retire l'**Image de fond** de l'étage, par exemple un scan du plan réel.
- Supprimer une pièce supprime aussi ses tables et ses places.

**Voir aussi:** [Propriétés d'une place](help:user.space.editor.seat) · [Transparence des tables](help:user.workspace.settings.desk-transparency)

<!-- anchor: user.space.editor.office -->
### Nommer un bureau ou une table et y mettre un prix

**Public:** Propriétaire · Administrateur·rice

Vous voulez qu'une pièce ou une table porte son propre nom et puisse être réservée d'un seul bloc.

<p><img src="images/user-space-editor-office.fr.jpg" width="280"></p>

**Étapes**

1. Sélectionnez le bureau ou la table sur l'étage et touchez **Propriétés**.
2. Modifiez **Nom du bureau** (ou **Nom de la table**).
3. Activez **Réservable en entier** si l'on peut le réserver au complet, avec tout ce qu'il contient.
4. Saisissez le **Prix par demi-journée** qui apparaît.
5. Touchez **Enregistrer**.

**Bon à savoir**

- Le champ du prix n'apparaît que lorsque l'interrupteur est activé.
- Une pièce réservable en entier ne peut être réservée que si rien de ce qu'elle contient n'est réservé.

**Voir aussi:** [Réserver un étage entier](help:user.space.editor.level-booking) · [Propriétés d'une place](help:user.space.editor.seat)

<!-- anchor: user.space.editor.seat -->
### Configurer une place

**Public:** Propriétaire · Administrateur·rice

Vous voulez qu'une place indique de quel côté la chaise est tournée, ce qui l'accompagne et quand elle est hors service.

<p><img src="images/user-space-editor-seat.fr.jpg" width="280"></p>

**Étapes**

1. Sélectionnez la place sur l'étage et touchez **Propriétés**.
2. Modifiez **Nom de la place**.
3. Choisissez le **Sens d'assise** : la flèche montre de quel côté la chaise est tournée sur le plan.
4. Choisissez un **Type de chaise**.
5. Touchez les **Accessoires** qui appartiennent à cette place. Un prix affiché à côté d'un accessoire est un supplément par demi-journée.
6. Si la place porte un tag, saisissez son numéro dans **Tag NFC/RFID**, ou utilisez **Lire un tag maintenant**. Le champ du tag apparaît quand la fonctionnalité **Tags NFC/RFID des chaises** est activée, et la lecture demande un appareil capable de lire les tags.
7. Activez **Bloquée (maintenance)** pour mettre la place hors service, puis touchez **Enregistrer**.

**Bon à savoir**

- Un numéro de tag ne peut appartenir qu'à une seule chaise : **Ce tag est déjà associé à une autre chaise.**
- Sans aucun accessoire, la feuille propose **Aucun équipement — les configurer**.

**Voir aussi:** [Pointage par badge NFC](help:user.badges.nfc)

<!-- anchor: user.workspace.code -->
### L'ID de l'espace

**Public:** Propriétaire · Administrateur·rice

Vous voulez que l'on trouve votre espace et que l'on demande à le rejoindre. L'écran **ID de l'espace et QR** présente l'invitation de membre : un code QR et l'ID qui s'y cache.

<p><img src="images/user-workspace-code.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [ID de l'espace et QR](app:/workspace-code). L'onglet **Invitation membre** s'affiche.
2. Touchez **Copier l'ID** pour le coller où vous voulez, ou **Partager en PNG** pour imprimer ou afficher le code QR.
3. Pour choisir un ID facile à retenir, touchez **Changer l'ID de l'espace**, saisissez 4 à 20 lettres ou chiffres et touchez **Enregistrer**.

**Bon à savoir**

- L'ID est unique dans tout DesKilo. S'il est déjà pris, ou s'il n'a pas 4 à 20 lettres ou chiffres, l'application répond **ID refusé**.
- Toute personne qui scanne le code ou saisit l'ID demande à rejoindre l'espace comme membre. Personne n'entre sans approbation.
- Une fois l'ID changé, l'ancien cesse de fonctionner. Imprimez de nouveau le code QR.
- L'onglet **Invitation administrateur·rice** est réservé aux propriétaires et copropriétaires.

**Voir aussi:** [Invitation administrateur](help:user.workspace.code.admin) · [Inviter quelqu'un](help:user.workspace.code.invite)

<!-- anchor: user.workspace.code.admin -->
### Inviter un administrateur

**Public:** Propriétaire

Vous voulez accueillir une personne qui vous aidera à faire vivre l'espace. L'onglet **Invitation administrateur·rice** vous donne un code valable pour une seule personne.

<p><img src="images/user-workspace-code-admin.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [ID de l'espace et QR](app:/workspace-code) et touchez **Invitation administrateur·rice**.
2. Remettez le code, ou son QR, à la personne concernée.
3. Pour l'administrateur suivant, touchez **Nouveau code administrateur·rice**.

**Bon à savoir**

- Le code admet une seule personne comme administrateur, puis il expire.
- Il n'y a pas d'invitation de propriétaire. Seul un propriétaire peut accorder la propriété, dans **Membres et forfaits**.

**Voir aussi:** [L'ID de l'espace](help:user.workspace.code) · [La matrice des rôles](help:user.roles.matrix)

<!-- anchor: user.workspace.code.invite -->
### Inviter quelqu'un par message

**Public:** Propriétaire · Administrateur·rice

Vous voulez envoyer une invitation chaleureuse et toute prête plutôt qu'un simple code.

<p><img src="images/user-workspace-code-invite.fr.jpg" width="280"></p>

**Étapes**

1. Sur [ID de l'espace et QR](app:/workspace-code), touchez **Inviter quelqu'un**.
2. Remplissez **Prénom (facultatif)**, **Nom (facultatif)** et, si vous le souhaitez, le numéro de téléphone.
3. Sous **Rôles à l'arrivée**, touchez chaque rôle que cette personne doit recevoir en rejoignant l'espace.
4. Choisissez la **Langue du message**.
5. Envoyez-le avec **WhatsApp**, **SMS** ou **Partager…**.

**Bon à savoir**

- Le message explique les étapes : télécharger, créer un compte, rejoindre. Il est écrit dans la langue que vous choisissez, et part de celle définie comme [Langue de l'espace](help:user.workspace.settings.language).
- Chaque message porte son propre code personnel. Vous pouvez écrire votre propre texte sous [Message d'invitation](help:user.workspace.settings.invitation-message).

**Voir aussi:** [L'ID de l'espace](help:user.workspace.code)

<!-- anchor: user.workspace.availability.open-weekdays -->
### Jours d'ouverture

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que l'espace ne soit ouvert que les jours où vous travaillez. L'écran **Disponibilité** commence par les jours de la semaine.

<p><img src="images/user-workspace-availability--open-weekdays.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Disponibilité](app:/availability).
2. Sous **Jours d'ouverture**, touchez un jour pour l'ouvrir ou le fermer.

**Bon à savoir**

- Au moins un jour de la semaine doit rester ouvert.
- Une réservation qui touche un jour fermé est refusée, et le plan dessine ce jour comme fermé.

**Voir aussi:** [Jours de fermeture](help:user.workspace.availability.closure-days) · [Granularité](help:user.workspace.availability.granularity)

<!-- anchor: user.workspace.availability.granularity -->
### Granularité

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que les réservations suivent un rythme qui convient à votre espace : demi-journées, journées entières, ou à l'heure que l'on veut.

<p><img src="images/user-workspace-availability--granularity.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Disponibilité](app:/availability).
2. Sous **Granularité de réservation**, choisissez la forme d'une réservation.

**Bon à savoir**

- Les choix sont **Plage horaire libre**, **Créneaux de 5 minutes**, **Créneaux de 15 minutes**, **Créneaux de 30 minutes**, **Créneaux d'une heure**, **Demi-journées (matin et après-midi)**, **Journées entières uniquement** et **Heures réelles (de–à exact, demi/journées en raccourcis)**. **Heures réelles** apparaît quand la fonctionnalité **Horaires de travail** est activée.
- Le plan, la feuille de réservation, un code scanné et la borne ne proposent que ce que la granularité permet.

**Voir aussi:** [Horaires de travail](help:user.workspace.availability.working-hours)

<!-- anchor: user.workspace.availability.working-hours -->
### Horaires de travail

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez qu'une matinée, un après-midi et une journée signifient la même chose partout.

<p><img src="images/user-workspace-availability--working-hours.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Disponibilité](app:/availability).
2. Sous **Horaires de travail**, touchez **Début de journée**, **Limite de demi-journée** et **Fin de journée** et réglez chaque heure.
3. Avec la granularité **Heures réelles**, réglez aussi **Heures facturées comme demi-journée** et **Heures facturées comme journée complète**.

**Bon à savoir**

- Les fenêtres de demi-journée et de journée dans les réservations, le pointage et la facturation suivent ces horaires.
- La petite étiquette sous le titre indique si les horaires sont ceux du produit, viennent d'un modèle ou sont les vôtres. **Revenir au modèle** et **Revenir à la valeur par défaut** les rétablissent.
- La journée doit suivre l'ordre : début, puis limite de demi-journée, puis fin.
- Cette section fait partie de la fonctionnalité **Horaires de travail**.

**Voir aussi:** [En dehors des heures d'ouverture](help:user.workspace.availability.outside-hours)

<!-- anchor: user.workspace.availability.closure-days -->
### Jours de fermeture

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez fermer l'espace pour un jour férié, une semaine d'août ou le passage du plombier, sans que personne ne puisse réserver.

<p><img src="images/user-workspace-availability--closure-days.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Disponibilité](app:/availability) et allez à **Jours de fermeture**.
2. Touchez **Ajouter un jour de fermeture**, choisissez la date et, si vous le souhaitez, un **Motif (facultatif)**.
3. Pour en retirer un, touchez la corbeille à côté.

**Bon à savoir**

- Une réservation un jour de fermeture est refusée et le motif s'affiche.
- Les jours déjà facturés ne peuvent pas être transformés en jours de fermeture par le générateur de jours fériés.

**Voir aussi:** [Jours fériés](help:user.workspace.availability.public-holidays)

<!-- anchor: user.workspace.availability.public-holidays -->
### Jours fériés

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez créer d'un coup tous les jours fériés d'une année comme jours de fermeture.

**Étapes**

1. Dans [Disponibilité](app:/availability), sous **Jours de fermeture**, touchez **Ajouter les jours fériés**.
2. Utilisez les flèches pour choisir l'année. La feuille liste les dates qui deviendraient des jours de fermeture.
3. Touchez le bouton du bas pour les créer.
4. Vous préférez une liste de données ouvertes ? Touchez **Importer les jours fériés (données ouvertes)**, choisissez la région et confirmez.

**Bon à savoir**

- Rien n'est créé avant votre confirmation, et les jours qui existent déjà sont signalés.
- Les mois déjà facturés sont ignorés.
- Ces entrées apparaissent quand la fonctionnalité **Jours fériés** est activée. **Importer les jours fériés (données ouvertes)** demande aussi la fonctionnalité **Importer les jours fériés**.

**Voir aussi:** [Jours de fermeture](help:user.workspace.availability.closure-days)

<!-- anchor: user.workspace.availability.policies -->
### Règles de réservation

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez assouplir ou durcir les règles de réservation. Ce que vous réglez ici vaut pour toutes les façons de réserver : l'application, un code scanné et la borne.

<p><img src="images/user-workspace-availability--policies.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Disponibilité](app:/availability) et allez à **Règles de réservation**.
2. Activez ou désactivez les règles voulues.
3. Sous **En dehors des heures d'ouverture** et **Limites de réservation**, réglez le reste.

**Bon à savoir**

- Les deux interrupteurs sont désactivés par défaut.
- Cette section fait partie de la fonctionnalité **Règles de réservation**.
- La ligne **Ce que le plan distingue** en dessous explique les états que les membres voient sur le plan.

**Voir aussi:** [Autoriser les réservations passées](help:user.workspace.availability.allow-past) · [Les admins peuvent faire le check-out des membres](help:user.workspace.availability.admin-checkout) · [Limites de réservation](help:user.workspace.availability.limits)

<!-- anchor: user.workspace.availability.allow-past -->
### Autoriser les réservations passées

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que les membres puissent enregistrer une réservation après coup, pour un espace qui note les présences plus tard.

**Étapes**

1. Dans [Disponibilité](app:/availability), sous **Règles de réservation**, activez **Autoriser les réservations passées**.

**Bon à savoir**

- Désactivé, une réservation déjà terminée un jour antérieur est refusée.
- Réserver un créneau antérieur le même jour est toujours permis.

**Voir aussi:** [Règles de réservation](help:user.workspace.availability.policies)

<!-- anchor: user.workspace.availability.admin-checkout -->
### Les administrateurs peuvent faire le check-out

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que l'équipe ferme la salle le soir et termine les pointages que l'on a oublié de clore.

**Étapes**

1. Dans [Disponibilité](app:/availability), sous **Règles de réservation**, activez **Les admins peuvent faire le check-out des membres**.

**Bon à savoir**

- Désactivé, le check-out est strictement personnel.
- Activé, un administrateur peut terminer le pointage en cours d'un membre.

**Voir aussi:** [Règles de réservation](help:user.workspace.availability.policies)

<!-- anchor: user.workspace.availability.outside-hours -->
### En dehors des heures d'ouverture

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez dire ce qui se passe quand quelqu'un arrive tôt ou reste tard. Une seule réponse vaut pour toutes les granularités.

<p><img src="images/user-workspace-availability--outside-hours.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Disponibilité](app:/availability), trouvez **En dehors des heures d'ouverture**.
2. Choisissez **Désactivé**, **Spontané uniquement**, **Libre** ou **Facturé**.

**Bon à savoir**

- **Désactivé** : rien en dehors des horaires, ni réservation à l'avance, ni arrivée spontanée.
- **Spontané uniquement** : les pointages sans réservation restent possibles, heures supplémentaires du soir comprises, mais réserver à l'avance en dehors des horaires est refusé.
- **Libre** : permis, jamais compté et jamais facturé.
- **Facturé** : permis et compté comme un usage ordinaire, sauf un jour où le membre a déjà une réservation classique.
- Une réservation qui touche les horaires de travail est une réservation ordinaire.

**Voir aussi:** [Horaires de travail](help:user.workspace.availability.working-hours)

<!-- anchor: user.workspace.availability.limits -->
### Limites de réservation

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez dire jusqu'à quand à l'avance on peut réserver, quelle durée minimale et maximale une réservation peut avoir, et combien on peut en détenir en même temps.

<p><img src="images/user-workspace-availability--limits.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Disponibilité](app:/availability), trouvez **Réservations simultanées par membre** et utilisez les boutons moins et plus.
2. Sous **Limites de réservation**, réglez **Horizon de réservation**, **Durée minimale** et **Durée maximale**.

**Bon à savoir**

- **Réservations simultanées par membre** est le nombre de réservations qui se chevauchent qu'un membre peut détenir. 1 garde une seule place à la fois.
- Une réservation se termine le jour où elle commence : une journée entière est donc le maximum.
- Le minimum ne peut pas dépasser le maximum, sinon aucune réservation ne serait acceptée. L'écran vous avertit.
- Chaque refus nomme la limite et sa valeur.

**Voir aussi:** [Règles de réservation](help:user.workspace.availability.policies)

<!-- anchor: user.features.processes -->
### Activer ou désactiver des processus entiers

**Public:** Propriétaire · Copropriétaire

Vous voulez une vue d'ensemble de ce que l'espace sait faire, et activer d'un coup tout un domaine. L'écran **Fonctionnalités** s'ouvre sur une carte par processus métier.

<p><img src="images/user-features-processes.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Fonctionnalités](app:/features). La vue **Processus** s'affiche.
2. Lisez chaque carte : son état, combien de sous-processus sont actifs et combien de fonctionnalités sont activées.
3. Ouvrez une carte et touchez **Activer** ou **Désactiver** pour le processus entier ou un sous-processus.
4. Lisez l'aperçu, puis confirmez.

**Bon à savoir**

- Une carte est **Active** quand toutes ses fonctionnalités marchent, **Partiel** quand certaines marchent, **Disponible** quand aucune n'est encore activée, et **À examiner** quand une fonctionnalité est activée mais attend un prérequis désactivé.
- Les pastilles **Tous**, **Actif**, **Disponible** et **À examiner** réduisent les cartes, et **Rechercher processus et fonctionnalités** atteint tout.
- L'aperçu liste ce qui est activé, ce qui est **Également nécessaires** venant d'un autre processus et ce qui est déjà activé. Désactiver quelque chose dont d'autres fonctionnalités ont besoin est refusé tant que vous n'avez pas choisi ce qu'elles deviennent.

**Voir aussi:** [Un interrupteur de fonctionnalité](help:user.features.switch)

<!-- anchor: user.features.switch -->
### Un interrupteur de fonctionnalité

**Public:** Propriétaire · Copropriétaire

Vous voulez activer ou désactiver une seule fonctionnalité.

<p><img src="images/user-features-switches.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Fonctionnalités](app:/features) et touchez **Interrupteurs**.
2. Trouvez la fonctionnalité avec **Rechercher une fonctionnalité**, ou réduisez la liste avec **Modifiées** ou **Maturité**.
3. Basculez son interrupteur.

**Bon à savoir**

- Activez une fonctionnalité et toutes ses parties apparaissent : l'onglet, le bouton, le lien. Désactivez-la et il n'en reste rien, pas même un lien enregistré.
- Une fonctionnalité qui en nécessite une autre se place sous elle avec **Nécessite** et indique **En attente de la fonction au-dessus** tant que la fonctionnalité parente est désactivée. Son propre choix est conservé.
- Activer une fonctionnalité peut aussi activer ce dont elle a besoin. L'application vous le dit.
- Une fonctionnalité pas encore validée comme stable vous demande d'abord de confirmer : elle peut changer et a des limites connues.
- Ce qui est déjà fait reste fait. Une facture émise pendant qu'une fonctionnalité était activée garde son contenu.

**Voir aussi:** [Activer ou désactiver des processus entiers](help:user.features.processes)

<!-- anchor: user.workspace.settings.country -->
### Pays

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que l'espace sache où il est établi. **Espace** s'ouvre sur **Informations générales**.

<p><img src="images/user-workspace-settings--country.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Espace](app:/workspace-settings).
2. Sous **Informations générales**, choisissez le **Pays**.
3. Touchez **Enregistrer** en bas.

**Bon à savoir**

- Le pays propose la devise et le fuseau horaire, et détermine les taux de TVA proposés.
- Dès que l'espace a émis un document ou enregistré de l'argent, le pays ne peut plus être changé : l'enregistrement indique « La devise et le pays sont figés dès que l'espace a émis un document ou enregistré de l'argent. Rien n'a été enregistré. »
- **Enregistrer** écrit tout le formulaire d'un coup. Si quelqu'un a modifié ces réglages entre-temps, rien n'est enregistré et ce que vous avez saisi reste à l'écran.

**Voir aussi:** [Devise et fuseau horaire](help:user.workspace.settings.currency-timezone)

<!-- anchor: user.workspace.settings.currency-timezone -->
### Devise et fuseau horaire

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que les prix et les jours soient comptés comme votre espace les compte.

<p><img src="images/user-workspace-settings--currency-timezone.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Espace](app:/workspace-settings), sous **Informations générales**, choisissez la **Devise**.
2. Recherchez le **Fuseau horaire** et choisissez-le.
3. Touchez **Enregistrer**.

**Bon à savoir**

- La devise est proposée d'après le pays. Vous pouvez la changer tant que l'espace n'a émis aucun document ni enregistré d'argent ; ensuite, elle est figée.
- Le fuseau horaire n'est pas décoratif : un jour ouvré, une limite de demi-journée et un jour de fermeture sont tous comptés dedans, si bien qu'un membre à l'étranger voit la journée de l'espace plutôt que la sienne.

**Voir aussi:** [Pays](help:user.workspace.settings.country)

<!-- anchor: user.workspace.settings.language -->
### Langue de l'espace

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que les invitations et les documents parlent la langue de votre communauté.

<p><img src="images/user-workspace-settings--language.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Espace](app:/workspace-settings), sous **Informations générales**, ouvrez **Langue de l'espace**.
2. Choisissez une langue, ou **Langue de l'app de l'expéditeur**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Les invitations sont écrites par défaut dans cette langue.
- Ce n'est pas la langue de votre propre application. Celle-ci ne change que ce que vous voyez, et se trouve dans vos réglages personnels.

**Voir aussi:** [Message d'invitation](help:user.workspace.settings.invitation-message)

<!-- anchor: user.workspace.settings.address -->
### Adresse d'en-tête

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez votre adresse postale sur le papier que l'espace envoie.

<p><img src="images/user-workspace-settings--address.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Espace](app:/workspace-settings), sous **Informations générales**, remplissez **Adresse de l'espace**.
2. Touchez **Enregistrer**.

**Bon à savoir**

- C'est un texte libre, imprimé tel quel sur les courriers et les factures.
- L'adresse structurée dont une facture électronique a besoin est une saisie distincte, sous l'identité juridique.

**Voir aussi:** [Pays](help:user.workspace.settings.country)

<!-- anchor: user.workspace.settings.whatsapp-group -->
### Groupe WhatsApp

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que les membres trouvent le groupe WhatsApp de votre communauté.

<p><img src="images/user-workspace-settings-community--whatsapp-group.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Espace](app:/workspace-settings), ouvrez **Communauté et invitations**.
2. Collez le lien d'invitation du groupe dans **Lien du groupe WhatsApp**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Le lien doit être un lien d'invitation chat.whatsapp.com, sinon le champ le signale.
- Laissez-le vide pour ne rien afficher.

**Voir aussi:** [Message d'invitation](help:user.workspace.settings.invitation-message)

<!-- anchor: user.workspace.settings.invitation-message -->
### Message d'invitation

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que les invitations vous ressemblent, dans chaque langue que vous utilisez.

<p><img src="images/user-workspace-settings-community--invitation-message.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Espace](app:/workspace-settings), ouvrez **Communauté et invitations**.
2. Sous **Langue du message**, choisissez la langue du texte que vous modifiez.
3. Écrivez le texte. Touchez une balise comme {firstName} ou {inviteLink} pour l'insérer à l'endroit du curseur.
4. Touchez **Enregistrer**.

**Bon à savoir**

- Laissez la zone vide pour utiliser le message intégré dans cette langue.
- La ligne **Langue du message** indique seulement quel brouillon est à l'écran. Elle n'est pas enregistrée et s'ouvre chaque fois sur la langue de l'espace.
- Les balises sont remplies à l'envoi d'une invitation. Le code et le lien viennent de l'application : ne les collez donc pas vous-même.

**Voir aussi:** [Inviter quelqu'un par message](help:user.workspace.code.invite)

<!-- anchor: user.workspace.settings.new-members -->
### Faire démarrer les nouveaux membres de la même façon

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que chaque personne qui rejoint l'espace commence avec le même abonnement et la même règle quand ses jours sont épuisés.

<p><img src="images/user-workspace-settings-members--defaults.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Espace](app:/workspace-settings), ouvrez **Nouveaux membres**.
2. Réglez le pourcentage d'**Abonnement** avec les boutons moins et plus.
3. Choisissez **Bloqué une fois épuisé**, **Paiement à l'usage** ou **Doit acheter un forfait**.
4. Touchez **Enregistrer**.

**Bon à savoir**

- Tant que vous n'avez pas choisi, les nouveaux membres commencent à 100 % avec les réservations bloquées une fois le droit épuisé.
- L'abonnement propre à un membre se règle plus tard, sur la page du membre.

**Voir aussi:** [L'abonnement d'un membre](help:user.members.subscription)

<!-- anchor: user.workspace.settings.wording -->
### Vocabulaire

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que l'application emploie vos mots : un autre nom pour une place, pour un état sur le plan, pour un onglet.

<p><img src="images/user-workspace-settings-wording.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Espace](app:/workspace-settings), ouvrez **Apparence et libellés** et touchez **Vocabulaire**.
2. Trouvez un mot avec **Rechercher un mot**, ou touchez **Modifiés seulement** pour voir ce que vous avez renommé.
3. Touchez le crayon à côté du mot et saisissez le vôtre, pour chaque langue.

**Bon à savoir**

- Le mot du produit reste affiché sous le vôtre, pour que vous voyiez ce que vous remplacez.
- **Réinitialiser** supprime votre mot au lieu de copier celui du produit. Le terme suit alors le produit quand son vocabulaire change.
- Les termes sont regroupés selon l'endroit où ils apparaissent : **Légende**, **L'espace**, **Navigation**, **Réservation**.

**Voir aussi:** [Couleurs](help:user.workspace.settings.colours)

<!-- anchor: user.workspace.settings.colours -->
### Couleurs

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que l'application porte votre couleur. Choisissez-en une et l'application en déduit ses thèmes clair et sombre.

<p><img src="images/user-workspace-settings-colours--colours.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Espace](app:/workspace-settings), ouvrez **Apparence et libellés** et touchez **Couleurs**. La ligne est là tant que **Couleurs de l’espace** est activée dans les fonctionnalités.
2. Touchez l'une des couleurs, ou saisissez un code comme #0F766E dans **Couleur**.
3. Vérifiez **Ce que cela donne**, en **Clair** et en **Sombre**.
4. Touchez **Enregistrer**. **Couleurs du produit** supprime les vôtres.

**Bon à savoir**

- L'application garde son propre contraste. Si une couleur était illisible quelque part, elle est refusée et l'écran nomme la paire concernée.
- Sous **Couleurs des salles**, vous pouvez ajouter jusqu'à huit couleurs à vous pour les pièces du plan.
- Le logo DesKilo, les couleurs des états des places et la bannière de production ne sont jamais modifiés.

**Voir aussi:** [Motif](help:user.workspace.settings.pattern) · [Symbole et emblème](help:user.workspace.settings.branding)

<!-- anchor: user.workspace.settings.pattern -->
### Motif

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez que votre espace se distingue facilement des autres auxquels une personne appartient.

<p><img src="images/user-workspace-settings-colours--pattern.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Couleurs](app:/settings/colours).
2. Sous **Motif**, touchez **Uni**, **Rayures**, **Pois**, **Quadrillage** ou **Vagues**.

**Bon à savoir**

- Le motif dessine votre couleur sur la carte de cet espace dans Moi, sur sa pastille et pendant l'ouverture de l'espace.
- Il s'enregistre dès que vous le touchez.

**Voir aussi:** [Couleurs](help:user.workspace.settings.colours)

<!-- anchor: user.workspace.settings.branding -->
### Symbole et emblème

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez une petite marque qui représente l'espace : des lettres sur une couleur, ou votre propre logo.

<p><img src="images/user-workspace-settings-colours--branding.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Couleurs](app:/settings/colours) et allez à **Symbole**.
2. Saisissez une ou deux **Lettres**, choisissez une couleur et touchez **Enregistrer**.
3. Sous **Emblème**, touchez **Choisir une image** pour ajouter votre logo. **Retirer** l'enlève.

**Bon à savoir**

- Les lettres sur une couleur sont uniques pour un espace. Si un autre espace a déjà les mêmes, l'application vous demande de changer la couleur ou les lettres.
- L'emblème s'affiche sous le nom de l'application dans le menu, et pendant que l'on ouvre cet espace. Il est redessiné à 512 pixels de large au plus, et les détails propres à la photo, comme le lieu de la prise de vue, ne sont pas conservés.
- L'emblème ne remplace jamais le logo DesKilo.

**Voir aussi:** [Couleurs](help:user.workspace.settings.colours)

<!-- anchor: user.workspace.settings.desk-transparency -->
### Transparence des tables

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous avez dessiné le plan sur une photo et voulez que la pièce apparaisse à travers le mobilier.

<p><img src="images/user-workspace-settings-appearance--desk-transparency.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Espace](app:/workspace-settings), ouvrez **Apparence et libellés**.
2. Faites glisser le curseur **Transparence des tables**. La valeur s'affiche comme **Opacité**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Baissez l'opacité pour que la photo de fond d'un étage apparaisse à travers les tables.
- Remontez-la à 100 % quand les places comptent plus que la pièce.

**Voir aussi:** [Dessiner pièces, tables et places](help:user.space.editor.rooms)

<!-- anchor: user.workspace.settings.public-page -->
### Page publique de l'espace

**Public:** Propriétaire

Vous voulez que les personnes extérieures à votre espace le trouvent et voient ce qu'il propose.

<p><img src="images/user-workspace-settings-public-page.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez la [Page publique de l'espace](app:/settings/public-page), ou touchez-la en haut de **Espace**.
2. Activez **Visible dans l’annuaire public**.
3. Choisissez le type d'hôte, et complétez **Description**, **Adresse publique**, **E-mail public**, **Téléphone public** et **Site internet**.
4. Touchez **Enregistrer et voir la vue externe**.

**Bon à savoir**

- Les champs marqués **Repris des informations de l’espace** suivent les informations propres à l'espace. **Utiliser les informations de l’espace** les rétablit après modification.
- **Rétablir toutes les données publiques depuis les informations de l’espace** remplace chaque champ qui a un équivalent dans l'espace.
- Les administrateurs peuvent choisir eux-mêmes s'ils sont affichés comme administrateurs publics.

**Voir aussi:** [Découvrir et le réseau public](help:user.collaborate.discover)

<!-- anchor: user.roles.matrix -->
### La matrice des rôles

**Public:** Propriétaire · Copropriétaire

Vous voulez décider des permissions que détient chaque rôle. **Rôles** montre une carte par rôle, avec une coche pour chaque permission détenue.

<p><img src="images/user-roles-matrix.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Rôles](app:/roles).
2. Sur la carte d'un rôle, cochez ou décochez une permission comme **Gérer les rôles et permissions**, **Gérer les membres**, **Modifier les réglages de l'espace** ou **Émettre les factures et rapprocher les paiements**.

**Bon à savoir**

- Chacun a exactement un rôle de base : Utilisateur, Administrateur, Copropriétaire ou Propriétaire. Les autres rôles s'y ajoutent et ne retirent jamais rien.
- Le propriétaire détient toujours toutes les permissions, cette carte est donc verrouillée. Un copropriétaire peut en détenir moins.
- Toute personne qui ne peut pas gérer les rôles voit la matrice en lecture seule, avec **Votre rôle** en surbrillance.
- Une permission est vérifiée par le serveur partout : la décocher la retire donc partout à la fois.
- L'entrée **Rôles** s'affiche quand la fonctionnalité **Gestion des rôles** est activée.

**Voir aussi:** [Les rôles que cet espace définit](help:user.roles.space) · [Copropriétaires](help:user.roles.co-owners)

<!-- anchor: user.roles.space -->
### Les rôles que cet espace définit

**Public:** Propriétaire · Copropriétaire

Vous voulez des rôles adaptés à votre espace, comme un hôte ou un comptable, en plus des rôles de base.

<p><img src="images/user-roles-space.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Rôles](app:/roles), touchez **Les rôles de cet espace**, ou ouvrez [Les rôles de cet espace](app:/settings/roles-of-this-space). Cet écran apparaît quand la fonctionnalité **Rôles définis par cet espace** est activée.
2. Touchez **Ajouter un rôle**.
3. Donnez un nom au rôle, puis choisissez **Ce qu'il ajoute**.
4. Touchez **Enregistrer le rôle**.
5. Pour le donner à un membre, ouvrez la page du membre, trouvez **Rôles** et touchez **Ajouter un rôle**.

**Bon à savoir**

- Chaque rôle ajoute des permissions à ce que ses titulaires peuvent déjà faire. Aucun ne retire quoi que ce soit, et le propriétaire garde toujours toutes les permissions.
- Un rôle dont vous ne voulez plus peut être mis de côté en désactivant **En usage**.
- La clé du rôle ne change jamais : les personnes qui le détiennent y sont rattachées.
- Personne ne peut se donner un rôle à soi-même. Un rôle qui gère les rôles ne peut être donné que par le propriétaire.

**Voir aussi:** [La matrice des rôles](help:user.roles.matrix)

<!-- anchor: user.roles.co-owners -->
### Copropriétaires

**Public:** Propriétaire

Vous voulez que l'espace survive si vous vous retirez un jour.

**Étapes**

1. Ouvrez [Membres et forfaits](app:/members) et choisissez le membre.
2. Sous **Copropriété**, choisissez un copropriétaire actif ou un successeur.
3. Pour transmettre tout de suite, choisissez **Promouvoir propriétaire maintenant**.

**Bon à savoir**

- Un copropriétaire actif a dès maintenant les permissions du propriétaire. Un successeur, signalé par **Successeur**, attend et devient propriétaire quand il est activé ou quand le propriétaire part.
- Si le dernier propriétaire part, le meilleur copropriétaire devient propriétaire automatiquement, actif avant successeur.
- Les copropriétaires font partie de la fonctionnalité **Copropriétaires**.

**Voir aussi:** [Copropriété](help:user.members.co-ownership) · [La matrice des rôles](help:user.roles.matrix)

<!-- anchor: user.kiosk.mode -->
### Mode borne : une tablette murale pour le pointage

**Public:** Propriétaire · Administrateur·rice

Vous voulez une tablette près de la porte où l'on pointe avec un badge.

**Étapes**

1. Créez un compte pour la tablette, rejoignez l'espace avec lui et, dans [Membres et forfaits](app:/members), utilisez **Transformer en borne** sur ce membre.
2. Vérifiez que le **Mode borne** est activé dans [Fonctionnalités](app:/features).
3. Sur la tablette, ouvrez l'application. Elle demande **Démarrer le mode borne ?**. Touchez **Démarrer le mode borne**.
4. Un membre touche une place, ou **Ce niveau**, et présente un badge : une carte, ou un code QR imprimé.

**Bon à savoir**

- Le mode borne ne démarre jamais tout seul. **Pas maintenant — ouvrir l'appli normalement** ouvre l'application comme d'habitude, ce qui est pratique pour la mise en place.
- En mode borne, la tablette n'affiche que le plan. Pour en sortir, vous redémarrez la tablette. Pour redonner au compte son statut de membre ordinaire, utilisez **Appareil borne** sous **Réglages** sur l'appareil ou **Rétablir comme membre** dans **Membres et forfaits**.
- La feuille qui s'ouvre nomme la règle qu'elle suit. Un jour de fermeture, la borne indique d'emblée que l'espace est fermé aujourd'hui.
- Le badge fait office de confirmation : il identifie le membre, exécute l'action et l'écran se vide pour la personne suivante. Une place tenue par quelqu'un d'autre montre qui la tient et renvoie vers l'application.
- Les badges ont leurs propres fonctionnalités, **Badges RFID / NFC** et badges QR, toutes deux sous **Mode borne**.
- Une tablette murale ne peut pas être montrée ici : la borne ne démarre que sur un appareil marqué comme tel.

**Voir aussi:** [Pointage par badge NFC](help:user.badges.nfc) · [Codes QR des espaces (PDF)](help:user.workspace.export.space-qr)

<!-- anchor: user.badges.nfc -->
### Pointage par badge NFC

**Public:** Propriétaire · Administrateur·rice

Vous voulez que les membres pointent en approchant une carte, sans téléphone.

<p><img src="images/user-badges-nfc.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Badges RFID / NFC](app:/nfc-config).
2. Activez **Activer le pointage par badge NFC**.
3. Lisez la ligne **Cet appareil** : elle dit si cet appareil sait lire les cartes.
4. Donnez une carte à chaque membre dans [Membres et forfaits](app:/members) : ouvrez les badges du membre, touchez **Enregistrer une carte**, puis tenez la carte contre le dos de l'appareil.

**Bon à savoir**

- Il faut un appareil Android avec NFC. Les iPad n'ont pas de NFC, et les badges QR y fonctionnent quand même.
- Le gestionnaire de badges permet aussi d'émettre un **Nouveau badge**, d'en **Révoquer** un et de l'**Enregistrer en PDF** pour l'imprimer. Un badge révoqué peut être supprimé définitivement.
- **Me connecte** est désactivé par défaut : un badge qui vous pointe ne vous connecte pas tant que le membre ne le choisit pas.
- Chaque membre peut aussi créer son propre badge dans ses réglages personnels.

**Voir aussi:** [Une tablette murale pour le pointage](help:user.kiosk.mode)

<!-- anchor: user.documents.add -->
### Ajouter un document à la bibliothèque

**Public:** Propriétaire · Administrateur·rice

Vous voulez réunir vos statuts, guides, états financiers et comptes rendus au même endroit pour les membres qui en ont besoin. La bibliothèque contient des liens, pas des fichiers.

<p><img src="images/user-documents-add.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Documents](app:/documents) et touchez le bouton plus.
2. Remplissez **Intitulé** et **Lien (https://…)**.
3. Choisissez **Stocké sur**, **Catégorie** et **Visible par**.
4. Touchez **Enregistrer**.

**Bon à savoir**

- La bibliothèque demande la fonctionnalité **Bibliothèque de documents**, et la permission de la gérer.
- Retirez un document avec sa corbeille : elle demande d'abord **Retirer le document ?**
- Les membres autorisés à ouvrir la bibliothèque voient les documents auxquels ils ont droit, regroupés par catégorie.

**Voir aussi:** [Intitulé du document](help:user.documents.title) · [Lien](help:user.documents.url) · [Visible par](help:user.documents.role)

<!-- anchor: user.documents.title -->
### Intitulé du document

**Public:** Propriétaire · Administrateur·rice

Vous voulez que les membres reconnaissent un document au premier coup d'œil.

**Étapes**

1. Dans le formulaire d'ajout de document, saisissez l'**Intitulé**.

**Bon à savoir**

- Un document a besoin d'un intitulé et d'un lien https://, sinon **Enregistrer** est refusé.
- Écrivez-le pour le lecteur : c'est la ligne qu'il voit dans la bibliothèque.

**Voir aussi:** [Ajouter un document à la bibliothèque](help:user.documents.add)

<!-- anchor: user.documents.url -->
### Lien

**Public:** Propriétaire · Administrateur·rice

Vous voulez que le document s'ouvre là où il se trouve déjà.

**Étapes**

1. Collez le lien de partage de votre espace de stockage dans **Lien (https://…)**.

**Bon à savoir**

- DesKilo conserve le lien, pas le fichier. Les droits d'accès restent gérés là où se trouve le document.
- Le lien doit commencer par https://.

**Voir aussi:** [Stocké sur](help:user.documents.provider)

<!-- anchor: user.documents.provider -->
### Stocké sur

**Public:** Propriétaire · Administrateur·rice

Vous voulez que les membres voient où le document est conservé.

**Étapes**

1. Choisissez **Stocké sur** : Google Drive, OneDrive, SharePoint, Dropbox, Nextcloud ou **Lien**.

**Bon à savoir**

- C'est une étiquette avec une icône. Rien n'est récupéré pour vous.

**Voir aussi:** [Lien](help:user.documents.url)

<!-- anchor: user.documents.category -->
### Catégorie

**Public:** Propriétaire · Administrateur·rice

Vous voulez que la bibliothèque se lise comme une étagère bien rangée.

**Étapes**

1. Choisissez une **Catégorie** : **Statuts et juridique**, **Guides et manuels**, **États financiers**, **Comptes rendus** ou **Autres documents**.

**Bon à savoir**

- La bibliothèque regroupe les documents sous ces rubriques, et n'affiche une rubrique que si elle contient un document.

**Voir aussi:** [Visible par](help:user.documents.role)

<!-- anchor: user.documents.role -->
### Visible par

**Public:** Propriétaire · Administrateur·rice

Vous voulez certains documents pour tout le monde et d'autres pour le bureau seulement.

**Étapes**

1. Choisissez **Visible par** : **Tous les membres**, **Admins et propriétaires** ou **Propriétaires uniquement**.

**Bon à savoir**

- Le serveur le fait respecter. Un membre qui n'a pas le droit de voir un document ne le reçoit pas du tout.

**Voir aussi:** [Ajouter un document à la bibliothèque](help:user.documents.add)

<!-- anchor: user.workspace.export.space-xml -->
### Exporter l'espace (XML)

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez un fichier contenant le plan et les réglages, pour le garder en sauvegarde, le réutiliser ou le déplacer vers un autre espace.

<p><img src="images/user-workspace-settings-tools--tools.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Espace](app:/workspace-settings) et allez à **Modèles et données**.
2. Touchez **Exporter l'espace (XML)**.

**Bon à savoir**

- Il contient les réglages et le plan. Il ne contient jamais de membres, de réservations ni de données financières, ni le code d'invitation ou les identifiants de paiement.
- Avec **Configuration dans le fichier de l'espace** activée, le fichier contient aussi les tarifs, les taux de TVA, les règles, les rôles et plus encore.
- Le fichier est enregistré sur votre appareil.

**Voir aussi:** [Importer l'espace (XML)](help:user.workspace.export.space-import)

<!-- anchor: user.workspace.export.space-import -->
### Importer l'espace (XML)

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez appliquer un fichier exporté à un espace.

**Étapes**

1. Dans [Espace](app:/workspace-settings), sous **Modèles et données**, touchez **Importer l'espace (XML)**.
2. Choisissez le fichier et lisez l'aperçu : étages, bureaux, tables, places et configuration.
3. Touchez **Remplacer et importer**.

**Bon à savoir**

- Cela remplace le plan actuel et écrase les réglages. Impossible de revenir en arrière.
- Dès qu'un espace a des réservations, seule la configuration est appliquée. Le plan est conservé, et l'application le dit.
- Un fichier illisible, ou qui ne vient pas de DesKilo, est refusé avec un message clair.

**Voir aussi:** [Exporter l'espace (XML)](help:user.workspace.export.space-xml)

<!-- anchor: user.workspace.export.config-pdf -->
### Exporter la configuration (PDF)

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez un document de tous les paramètres, à lire, à signer ou à remettre à un comptable.

<p><img src="images/user-workspace-export-reports.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Rapports](app:/reports?section=documents) et choisissez **Documents de l’espace**.
2. Touchez **Exporter la configuration (PDF)**.

**Bon à savoir**

- C'est un instantané complet des réglages, des membres et du plan. C'est un justificatif, pas une sauvegarde : seul le XML peut être réimporté.

**Voir aussi:** [Exporter l'espace (XML)](help:user.workspace.export.space-xml)

<!-- anchor: user.workspace.export.workspace-report -->
### Rapport de l'espace

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez l'espace sous forme de document : ses places, ses prix et ses règles.

**Étapes**

1. Ouvrez [Rapports](app:/reports?section=documents) et choisissez **Documents de l’espace**.
2. Touchez **Rapport de l'espace**.

**Bon à savoir**

- Il est produit par le modèle d'espace de l'éditeur de rapports, son aspect suit donc la mise en page que vous avez choisie.

**Voir aussi:** [Exporter la configuration (PDF)](help:user.workspace.export.config-pdf)

<!-- anchor: user.workspace.export.space-qr -->
### Codes QR des espaces (PDF)

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez une carte QR sur chaque place, table, bureau et étage, pour que l'on réserve ou pointe en la scannant.

**Étapes**

1. Ouvrez [Rapports](app:/reports?section=documents) et choisissez **Documents de l’espace**.
2. Touchez **Codes QR des espaces (PDF)**.
3. Choisissez **Taille de la carte**, **Taille du code QR** et **Informations sur la carte**, puis touchez **Enregistrer**.
4. Imprimez, découpez et collez chaque carte sur sa place.

**Bon à savoir**

- Il faut la fonctionnalité **Codes QR des espaces**.
- Scanner une carte ouvre la même feuille que celle de la borne.

**Voir aussi:** [Une tablette murale pour le pointage](help:user.kiosk.mode)

<!-- anchor: user.workspace.export.excel -->
### Exporter les données (Excel)

**Public:** Propriétaire · Administrateur·rice avec l'autorisation

Vous voulez vos chiffres dans un tableur pour votre propre analyse.

**Étapes**

1. Ouvrez [Rapports](app:/reports?section=documents) et choisissez **Documents de l’espace**.
2. Touchez **Exporter les données (Excel)**.

**Bon à savoir**

- Il arrive sous forme d'un seul ZIP : un classeur avec un onglet pour les réservations, les paiements, les factures, les membres et le plan, un manifeste qui compte les lignes, et les fichiers stockés de l'espace.
- Il faut la fonctionnalité **Export des données (Excel)** et l'autorisation d'exporter les données. C'est un export seulement : rien ne le relit.

**Voir aussi:** [Exporter l'espace (XML)](help:user.workspace.export.space-xml)

<!-- anchor: user.workspace.sites -->
### Sites

**Public:** Propriétaire · Administrateur·rice

Vous gérez plus d'une adresse et voulez que chaque étage et chaque membre appartienne au bon site.

**Étapes**

1. Activez **Sites** dans [Fonctionnalités](app:/features).
2. Ouvrez [Sites](app:/settings/sites) et touchez **Ajouter un site**.
3. Remplissez **Nom du site**, **Rue**, **Code postal**, **Ville** et les étages qui en font partie.

**Bon à savoir**

- Le site par défaut porte l'adresse de l'espace. Le site d'attache d'un membre est l'adresse figurant sur ses documents.
- **Supprimer ce site** renvoie ses étages et ses membres au site par défaut.
- Un site qui est sa propre entité juridique peut porter son propre numéro d'immatriculation et de TVA.
