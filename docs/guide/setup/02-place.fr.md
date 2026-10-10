<!-- anchor: setup.place.overview -->
## Construire le lieu

Ce chapitre réalise le premier niveau, *Ouvrir* : où se trouve l’espace, à quoi il ressemble, quand il est ouvert et quelles sont les règles de réservation. En une vingtaine de minutes, l’espace peut être réservé. L’exemple est *Atelier du Marché*, une association de Pézenas avec deux étages et une salle.

Dans ce chapitre :
- [Pays, devise, fuseau horaire et langue](help:setup.place.where)
- [Le plan](help:setup.place.plan)
- [Horaires d’ouverture et règles de réservation](help:setup.place.times)
- [Jours de fermeture et jours fériés](help:setup.place.closure)
- [Vérifier votre espace](help:setup.place.check)

<!-- anchor: setup.place.where -->
### Pays, devise, fuseau horaire et langue

**Public:** Propriétaire · Administrateur·rice

Vous voulez que l’espace sache où il vit. Ces quatre choix pèsent plus qu’il n’y paraît.

<p><img src="images/setup-place-country.fr.jpg" width="280"></p>

*Ce que décide chaque choix*

| Choix | Ce qu’il décide |
|---|---|
| **Pays** | La devise et le fuseau horaire proposés, et les jours fériés offerts comme jours de fermeture (voir plus bas). |
| **Devise** | La façon dont chaque montant est affiché et compté. |
| **Fuseau horaire** | Ce que signifient un jour de travail, une limite de demi-journée et un jour de fermeture ; un membre à l’étranger voit le jour de l’espace. |
| **Langue de l'espace** | La langue dans laquelle les invitations et les références de messages partagées sont rédigées par défaut. |

**Étapes**

1. Ouvrez [Espace](app:/workspace-settings) et allez à **Informations générales**.
2. Choisissez le **Pays** ; la **Devise** et le **Fuseau horaire** suivent, et vous pouvez les corriger. Pour l’Atelier du Marché : France, EUR, Europe/Paris.
3. Choisissez la **Langue de l'espace**, puis touchez **Enregistrer**.

> **Attention** Choisissez le pays et la devise correctement dès le premier jour. Les montants sont enregistrés comme de simples nombres : changer de devise une fois que de l’argent existe fausserait l’intitulé de tout ce qui est déjà compté.

**Bon à savoir**

- L’application liste de nombreux pays, mais l’émission de factures dans DesKilo ne fonctionne aujourd’hui que pour la France et l’Allemagne. Ailleurs, vous gardez les relevés et émettez les factures en dehors de l’application.
- La langue de l’espace n’est pas la langue de votre propre application, qui se trouve dans vos réglages personnels.

**Voir aussi :** [Pays](help:user.workspace.settings.country) · [Devise et fuseau horaire](help:user.workspace.settings.currency-timezone) · [Langue de l’espace](help:user.workspace.settings.language)

<!-- anchor: setup.place.plan -->
### Le plan

**Public:** Propriétaire · Administrateur·rice

Vous voulez que le plan à l’écran ressemble au vrai lieu. Il se construit en quatre couches : les étages, puis les bureaux (les salles), puis les tables, puis les places. Un membre réserve une place ; c’est la place que compte la liste de préparation.

<p><img src="images/setup-place-rooms.fr.jpg" width="280"></p>

**Étapes**

1. Faites un croquis sur papier : étages, salles, tables, places.
2. Ouvrez l’[Éditeur d’espace](app:/editor) et ajoutez les étages avec **Ajouter un étage**.
3. Ouvrez un étage et dessinez chaque salle avec **Bureau**, puis **Table** et **Place** à l’intérieur.
4. Si une équipe peut prendre une salle ou un étage pour une journée, activez la réservation de la salle entière dans ses propriétés.

**Bon à savoir**

- Commencez petit : un étage, une salle, quelques places. Tout peut s’ajouter ensuite.
- Un étage, un bureau ou une table entiers ne peuvent être réservés que si **Réservations de table, bureau et niveau** est activé et que le membre en a la permission.
- Le modèle fourni *A tiny space* vous donne deux niveaux, quatre tables et huit places à ajuster.
- Supprimer un étage supprime tout ce qui s’y trouve, et l’import d’un plan est refusé dès que des réservations existent.

**Voir aussi :** [Ajouter, renommer et supprimer des étages](help:user.space.editor.levels) · [Dessiner des salles, des tables et des places](help:user.space.editor.rooms) · [Laisser les membres réserver un étage entier](help:user.space.editor.level-booking)

<!-- anchor: setup.place.times -->
### Horaires d’ouverture et règles de réservation

**Public:** Propriétaire · Administrateur·rice

Vous voulez que les réservations suivent le rythme de votre lieu. Un seul écran, **Disponibilité**, contient les jours, la forme d’une réservation, les horaires de travail et les règles. Le serveur les applique partout : plan, feuille de réservation, codes scannés et borne.

<p><img src="images/setup-place-availability--times.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Disponibilité](app:/availability).
2. Choisissez les **Jours d'ouverture** (au moins un) et la **Granularité de réservation**.
3. Réglez les **Horaires de travail** : **Début de journée**, **Limite de demi-journée**, **Fin de journée**.
4. Sous **Règles de réservation**, décidez de **Autoriser les réservations passées**, **En dehors des heures d'ouverture** et des **Limites de réservation**.

<p><img src="images/setup-place-availability--rules.fr.jpg" width="280"></p>

*Points de départ conseillés (des suggestions, pas des règles ; par défaut, **En dehors des heures d'ouverture** est sur **Facturé**, et le modèle d’association n’y change rien)*

| Situation | Granularité | Horaires | Hors horaires | Réservations passées | Limites |
|---|---|---|---|---|---|
| Quelques bureaux partagés | **Plage horaire libre** ou **Créneaux d'une heure** | Journée 8 h 00–17 h 00 | **Libre** | Non | Une réservation à la fois ; horizon de 30 jours |
| Une salle d’association (Atelier du Marché) | **Demi-journées (matin et après-midi)** | 7 h 00, limite 13 h 00, fin 19 h 00 | **Désactivé** | Non | Une réservation à la fois ; horizon de 90 jours |
| Un coworking en demi-journées | **Demi-journées (matin et après-midi)** | 8 h 00, limite 12 h 00, fin 18 h 00 | **Facturé** | Non | Une ou deux à la fois ; horizon de 90 jours |

**Bon à savoir**

- En dehors des heures d’ouverture, **Désactivé** refuse tout, **Spontané uniquement** autorise les venues sans réservation, **Libre** autorise sans compter, **Facturé** compte comme une utilisation ordinaire, sauf un jour où le membre détient déjà une réservation normale.
- La journée doit se dérouler dans l’ordre : début, puis limite, puis fin ; la durée minimale ne peut pas dépasser la durée maximale.
- Une réservation se termine le jour où elle commence. Les réservations passées sont désactivées par défaut ; réserver une plage antérieure le jour même est toujours permis.
- Les plages de demi-journée et de journée entière pilotent aussi l’enregistrement à l’arrivée et la facturation : fixez donc les horaires avant de fixer les prix.

**Voir aussi :** [Jours d’ouverture](help:user.workspace.availability.open-weekdays) · [Granularité](help:user.workspace.availability.granularity) · [Horaires de travail](help:user.workspace.availability.working-hours) · [En dehors des heures d’ouverture](help:user.workspace.availability.outside-hours) · [Limites de réservation](help:user.workspace.availability.limits)

<!-- anchor: setup.place.closure -->
### Jours de fermeture et jours fériés

**Public:** Propriétaire · Administrateur·rice

Vous voulez que l’espace soit fermé les jours fériés, sans que personne les réserve par erreur.

<p><img src="images/setup-place-availability--closure.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Disponibilité](app:/availability), allez à **Jours de fermeture**.
2. Touchez **Ajouter les jours fériés** (si vous ne le voyez pas, activez d’abord la fonctionnalité *Jours fériés* ; elle est désactivée par défaut) pour créer toute une année d’un coup, ou **Ajouter un jour de fermeture** pour une date isolée, comme un jour d’inventaire.
3. Vérifiez la liste et retirez tout jour où vous travaillez réellement.

**Bon à savoir**

- Des listes de jours fériés sont fournies pour la France et l’Allemagne. Pour les autres pays, activez *Jours fériés* et *Importer les jours fériés* (données ouvertes, connexion nécessaire). Rien n’est créé avant votre confirmation.
- Une réservation un jour de fermeture est refusée, et le plan montre le jour comme fermé, avec son motif.
- Les mois déjà facturés sont ignorés : ajoutez donc les jours de fermeture avant la clôture du mois.

**Voir aussi :** [Jours de fermeture](help:user.workspace.availability.closure-days) · [Jours fériés](help:user.workspace.availability.public-holidays)

<!-- anchor: setup.place.check -->
### Vérifier votre espace

**Public:** Propriétaire · Administrateur·rice

Vous voulez la preuve que l’espace est prêt, avant d’inviter qui que ce soit. Deux cartes la donnent.

<p><img src="images/setup-place-get-started--card.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Espace](app:/workspace-settings) : la carte **Mise en place de cet espace** liste chaque domaine avec son état, et l’étape suivante.
2. Ouvrez [Réserver](app:/reserve). Les propriétaires et les administrateurs qui ont la permission de configuration voient la carte *Premiers pas dans* votre espace. S’il manque quelque chose, elle dit *Avant que quiconque puisse réserver ici*, avec **Terminer la mise en place**.
3. Réservez vous-même une place pour tester, puis annulez-la.

**Bon à savoir**

- Prêt veut dire prêt pour une première réservation : jours d’ouverture, fuseau horaire, devise, au moins une place, et assez de validateurs.
- Tout ce qui est facultatif, comme les tarifs ou les paiements, peut être mis de côté avec **Plus tard** et ne bloque pas l’ouverture.
- Les deux cartes dépendent de la fonctionnalité *Carte Premiers pas*.
- **Pas maintenant** masque la carte sur cet appareil ; le menu d’affichage du plan la ramène avec **Premiers pas**.

**Résultat** Un espace que les membres peuvent réserver. Ensuite : inviter les premières personnes, puis passer aux rôles et aux tarifs du deuxième niveau.

**Voir aussi :** [La carte Premiers pas et les astuces](help:user.start.get-started) · [Inviter des personnes avec l’ID de l’espace](help:user.workspace.code) · [Rôles](help:user.roles.matrix)
