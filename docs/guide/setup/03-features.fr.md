<!-- anchor: setup.features.overview -->
## Choisir ce que propose votre espace

Un espace n’est pas un produit unique avec cent réglages. C’est une poignée de choses que vous décidez de proposer, une à la fois. Ce chapitre explique comment DesKilo regroupe ce qu’il sait faire, ce qu’un nouvel espace possède déjà, comment les éléments dépendent les uns des autres, et dans quel ordre les activer pour ne jamais proposer ce que vous ne pouvez pas encore assurer.

Dans ce chapitre :
- [Fonctionnalités et processus](help:setup.features.what)
- [Essentiel et Plateforme : ce que possède un nouvel espace](help:setup.features.tiers)
- [Les fonctionnalités qui en nécessitent d’autres](help:setup.features.dependencies)
- [Désactiver ne supprime rien](help:setup.features.off)
- [Bêta, non évaluée, et la question avant d’activer](help:setup.features.maturity)
- [Trois points de départ](help:setup.features.profiles)
- [L’ordre d’activation](help:setup.features.order)
- [Activer une fonctionnalité en sécurité](help:setup.features.safely)
- [Éviter les fonctionnalités qui se contredisent](help:setup.features.consistency)
- [La carte des fonctionnalités](help:setup.features.map)

<!-- anchor: setup.features.what -->
### Fonctionnalités et processus

**Public:** Propriétaire · Copropriétaire

Vous voulez savoir ce que vous actionnez quand vous ouvrez **Fonctionnalités**. Tout ce que DesKilo sait faire au-delà de l’essentiel est une fonctionnalité dotée de son propre interrupteur. Pour garder une centaine d’interrupteurs lisibles, l’écran les regroupe selon leur usage.

<p><img src="images/setup-features-what.fr.jpg" width="280"></p>

*Comment c’est organisé*

- Un *processus* est un métier : par exemple **Facturation & paiements** ou **Calendrier et coordination**. Il y en a neuf.
- Un *sous-processus* est une étape de ce métier : **Facturation**, **Encaissement** et **Gestion de la TVA** sont trois des cinq étapes de **Facturation & paiements**.
- Une *fonctionnalité* est un interrupteur à l’intérieur d’un sous-processus : **Factures**, **Relances de paiement**, **Déclarations de TVA**.

*Les neuf processus et leurs sous-processus*

| Processus | Sous-processus |
|---|---|
| **Espace et accès** | **Personnes et adhésions** · **Accès aux locaux** |
| **Gestion des lieux** | **Structure des lieux** · **Jours et heures d’ouverture** · **Présentation des lieux** |
| **Réservations et utilisation** | **Réservation des postes et espaces** · **Présence et utilisation** |
| **Calendrier et coordination** | **Vues du calendrier** · **Décisions et validations** · **Communication entre membres** |
| **Offres aux membres** | **Services et tarification** |
| **Facturation & paiements** | **Suivi financier** · **Facturation** · **Encaissement** · **Dépenses partagées** · **Gestion de la TVA** |
| **Documents et informations** | **Publication des documents** · **Conception des rapports** · **Accès aux données et exports** |
| **Exploitation et administration** | **Configuration et déploiement** · **Utilisation de l’application** |
| **Intégrations et automatisation** | **Envoi externe** |

**Bon à savoir**

- Une fonctionnalité appartient à un seul processus, même quand elle en nécessite une d’un autre. La carte le dit : « Tout activer nécessite aussi : Onglet Finances (Facturation et paiements) ».
- Les formules d’adhésion et l’éditeur de plan ne sont pas des fonctionnalités : ils sont toujours là. Leurs réglages se trouvent dans Espace et Facturation, pas sur cet écran. Les carnets prépayés sont une fonctionnalité : voir **Carnets**.
- Désactiver une fonctionnalité la masque de tous les écrans où elle apparaissait ; ce n’est pas une permission. Qui peut faire quoi se décide dans les [Rôles](help:user.roles.matrix).

**Voir aussi :** [Ce que sait faire DesKilo](help:setup.before.what) · [Activer ou désactiver des processus entiers](help:user.features.processes)

<!-- anchor: setup.features.tiers -->
### Essentiel et Plateforme : ce que possède un nouvel espace

**Public:** Propriétaire · Copropriétaire

Vous voulez savoir ce que les membres trouvent dès le premier jour, avant que vous n’ayez rien activé.

<p><img src="images/setup-features-tiers.fr.jpg" width="280"></p>

Chaque fonctionnalité appartient à l’un de deux niveaux, et un nouvel espace en est créé :

| Niveau | Dans les mots de l’application | Ce que reçoit un nouvel espace |
|---|---|---|
| **Essentiel** | Ce dont tout espace a besoin. Actif dès le premier jour. | Activée, quand elle est prévue pour l’être au départ. |
| **Plateforme** | Demandé, jamais supposé. Activez ce que cet espace fait vraiment. | Désactivée. Dans **Interrupteurs**, elles sont listées sous le niveau **Plateforme**. |

Un nouvel espace démarre avec 45 fonctionnalités activées, toutes de niveau Essentiel (46 si vous créez en même temps le jumeau de test : **Paires d'environnements** est alors activée aussi). En clair :

- Réservation : réserver une place sur le plan, répéter une réservation (**Réservation en série**), réserver pour quelqu’un d’autre (**Réserver pour d'autres**), voir une place à moitié réservée comme partiellement occupée (**Journée d'une place**), enregistrer une réservation dans un calendrier personnel (**Fichier calendrier d’une réservation**), des règles de réservation comme les réservations passées et hors horaires (**Règles de réservation**, **Garde-fou de réservation**), demander la suppression d’une réservation passée (**Demandes de suppression de réservation**), imprimer des cartes QR pour les places (**Codes QR des espaces**), des horaires de travail paramétrables (**Horaires de travail**).
- Personnes : l’onglet de la communauté (**Annuaire des membres**), une page par membre (**Fiche membre**), la matrice centrale des rôles (**Gestion des rôles** et **Attribution des rôles**), les informations personnelles pour les courriers et les factures (**Informations personnelles**), des initiales distinctes sur les avatars (**Initiales d’avatar distinctes**).
- Calendrier et messages : le calendrier en plusieurs vues (**Onglet Calendrier**, **Calendrier central**, **Vues du calendrier**), le fil d’activité et les confirmations (**Onglet Événements**), les conversations privées et de groupe (**Notifications entre membres**, **Messages repensés**) avec références, transfert, mentions, gestes de balayage et protection contre la capture d’écran, le regroupement du fil de notifications (**Regroupement des notifications**), et le bouton pour écrire aux hôtes d’une page publiée (**Écrire aux hôtes**).
- Argent : l’onglet Finances et ses quatre volets (**Onglet Finances**, **Finances en quatre volets**), les factures (**Factures**), un catalogue de services (**Services**), un PDF de la facture mensuelle (**Export PDF**).
- Documents et données : la bibliothèque de documents (**Bibliothèque de documents**), l’export des données pour le propriétaire (**Export des données (Excel)**), et l’export et l’effacement de ses propres données par chaque membre (**Export et effacement**).
- Confort : les astuces d’aide, la carte Premiers pas, les favoris et les notes pour les places, les animations, les formats régionaux et le choix du style de navigation.
- Envoi : **Notifications push**, qui n’atteignent les téléphones qu’une fois que la personne qui fait tourner l’installation a configuré le service de notifications (voir [Comment les membres sont informés](help:setup.notify.channels)).
- Rangement du plan : **Supprimer des espaces avec historique** et **Nommer par l’étage un étage à une seule salle**.

Tout le reste est de niveau Plateforme et désactivé : borne et badges, plusieurs sites, suppléments d’accessoires, paiements en ligne, gestion de la TVA, le parcours d’une facture, conception des rapports, déploiements, WhatsApp, l’interface pour assistants et le reste.

**Bon à savoir**

- La fonctionnalité de factures est activée dès le départ, mais rien ne peut être émis tant que votre identité légale n’est pas complète ; **Mise en place de cet espace** la marque **Nécessaire avant de facturer**. Voir [Éviter les fonctionnalités qui se contredisent](help:setup.features.consistency).
- Un espace qui existe déjà ne change jamais quand DesKilo modifie ce que reçoit un nouvel espace.
- Si vous partez d’un modèle, celui-ci peut activer ou désactiver quelques fonctionnalités en plus de cet ensemble. Voir [Trois points de départ](help:setup.features.profiles).

**Voir aussi :** [Un interrupteur de fonctionnalité](help:user.features.switch)

<!-- anchor: setup.features.dependencies -->
### Les fonctionnalités qui en nécessitent d’autres

**Public:** Propriétaire · Copropriétaire

Vous voulez activer quelque chose en étant sûr que cela fonctionne, ou désactiver quelque chose sans casser ce qui en dépend.

Beaucoup de fonctionnalités dépendent d’une autre. **Paiements en ligne** nécessite **Onglet Finances** ; **Relances de paiement** nécessite **Factures** ; **Relances de paiement automatiques** nécessite **Relances de paiement** ; **Déclarations de TVA** nécessite **Gestion de la TVA**, qui nécessite **Factures**. Dans la liste **Interrupteurs**, une fonctionnalité qui en nécessite une autre affiche **Nécessite** suivi du nom de son parent.

*Ce que fait l’application*

| Vous | L’application |
|---|---|
| Activez une fonctionnalité dont le parent est désactivé | Active toute la chaîne et nomme ce qui s’est activé avec elle : « Également activé : … ». |
| Désactivez un parent | N’efface pas les choix de ses enfants. Ils sont conservés tels que vous les avez réglés, mais ne font rien ; la ligne indique « En attente de la fonction au-dessus — activez-la et celle-ci fonctionne de nouveau ». |
| Réactivez le parent | Les enfants qui étaient activés fonctionnent de nouveau aussitôt. |
| Désactivez un processus ou un sous-processus entier alors que quelque chose en dépend encore | Refuse et nomme qui en a besoin (« … est encore nécessaire à : … »), sauf si vous choisissez **Désactiver quand même, conserver leurs réglages** ou de désactiver aussi les dépendants. |

**Bon à savoir**

- Un enfant activé qui attend son parent fait afficher **À examiner** sur son processus. C’est le seul état où un interrupteur et l’application ne sont pas d’accord : il mérite un coup d’œil. Voir [Activer une fonctionnalité en sécurité](help:setup.features.safely).
- Un parent peut se trouver dans un autre processus que son enfant : **Services** (Offres aux membres) nécessite **Onglet Finances** (Facturation et paiements). La carte avertit alors que tout activer nécessite aussi l’autre.
- La vérification porte sur la fonctionnalité, pas sur une permission : un rôle qui a le droit de faire quelque chose ne suffit jamais si la fonctionnalité est désactivée.

**Voir aussi :** [Un interrupteur de fonctionnalité](help:user.features.switch) · [Activer ou désactiver des processus entiers](help:user.features.processes)

<!-- anchor: setup.features.off -->
### Désactiver ne supprime rien

**Public:** Propriétaire · Copropriétaire

Vous voulez pouvoir changer d’avis plus tard : il faut donc savoir ce qu’un interrupteur ne touche pas.

Désactiver une fonctionnalité arrête les nouvelles opérations. Elle ne supprime pas un seul enregistrement : factures, réservations, messages, rôles et réglages restent où ils sont, et réactiver la fonctionnalité les ramène. Ce qui est fait reste fait : une facture émise pendant que la fonctionnalité était activée garde ce qu’elle dit.

Derrière cela, DesKilo range les actions d’une fonctionnalité activable en trois catégories :

| Catégorie | Ce que fait l’interrupteur | Exemple |
|---|---|---|
| Travail nouveau (*acceptNew*) | S’arrête quand la fonctionnalité est désactivée. | Ouvrir une nouvelle conversation avec les hôtes ; donner un rôle personnalisé à un membre ; bloquer une place ; lancer un nouveau paiement en ligne. |
| Travail déjà ouvert (*serviceExisting*) | Continue, pour que rien ne reste en suspens. | Répondre à une conversation déjà commencée ; retirer un rôle personnalisé ; lever le blocage d’une place ; solder un paiement déjà ouvert. |
| Chemins risqués (*suspended*) | Restent fermés quoi que dise l’interrupteur. | Réservé à un chemin que le serveur juge risqué ; aucune action n’est classée ainsi aujourd’hui. |

Trois fonctionnalités le disent sur leur ligne, avec ces mots : « Désactivé : rien de nouveau ne commence ; ce qui est en cours peut encore être traité et clos. » Ce sont **Écrire aux hôtes**, **Les rôles de cet espace** et **Les admins peuvent bloquer des places**. **Arrivée/départ auto en fin de journée** arrête aussi son balayage de fin de journée quand elle est désactivée, mais sa ligne ne le dit pas. Sur un serveur qui ne peut pas le confirmer, la ligne dit « n’y comptez pas ».

**Bon à savoir**

- L’argent déjà engagé est toujours réglé : un retour de paiement ou un remboursement n’est jamais bloqué par un interrupteur.
- Avec **Paiements en ligne** désactivé, le serveur refuse un nouveau paiement en ligne ; un paiement déjà ouvert se solde quand même. Sa ligne ne porte aucune note à ce sujet.
- Un interrupteur n’est pas un moyen de cacher quelque chose à une seule personne. Pour cela, utilisez les [Rôles](help:user.roles.matrix).

**Voir aussi :** [Un interrupteur de fonctionnalité](help:user.features.switch)

<!-- anchor: setup.features.maturity -->
### Bêta, non évaluée, et la question avant d’activer

**Public:** Propriétaire · Copropriétaire

Vous voyez un petit mot sous le nom d’une fonctionnalité et vous voulez savoir quoi en faire.

<p><img src="images/setup-features-maturity.fr.jpg" width="280"></p>

Chaque ligne de **Interrupteurs** porte un badge de maturité, qui dit jusqu’où la fonctionnalité a été examinée, preuves à l’appui :

| Badge | Signification |
|---|---|
| **Non évaluée** | Personne ne l’a encore examinée, preuves à l’appui. Cela n’a rien de négatif. |
| **Alpha** | Examinée, à un stade précoce. |
| **Bêta** | Examinée, avec des limites connues ; ses tests tournent à chaque modification. |
| **Stable** | Examinée, et en plus qualifiée avec de vrais fournisseurs, du vrai matériel ou de vrais opérateurs. |

À l’heure où nous écrivons, la plupart des fonctionnalités sont **Non évaluée**, dix-huit sont **Bêta**, et aucune n’est encore **Stable**.

*Ce que demande l’application*

1. Basculez l’interrupteur d’une fonctionnalité **Alpha** ou **Bêta**.
2. L’application demande **Activer une fonctionnalité expérimentale ?** et dit : « Pas encore évaluée comme stable : … Elle peut changer et a des limites connues. N’activez que si cet espace l’accepte. »
3. Elle nomme le stade de chaque fonctionnalité et celles qui s’activeraient avec elle parce qu’elles sont nécessaires.
4. Touchez **Activer** pour accepter, ou **Annuler** : rien n’est enregistré.

**Bon à savoir**

- Les fonctionnalités **Non évaluée** ne demandent rien. Seules **Alpha** et **Bêta** demandent.
- La question se pose sur un seul interrupteur. Un **Activer** de processus entier montre ce qu’il va activer, mais ne pose pas cette question : activez les fonctionnalités **Bêta** une par une.
- Parmi les fonctionnalités bêta, à l’heure où nous écrivons : **Factures**, **Paiements en ligne**, **Gestion de la TVA**, **Carnets**, **Dépenses partagées**, **Relevés d'usage**, **Règles de réservation**, **Réservation en série**, **Garde-fou de réservation**, **Demandes de suppression de réservation**, **Finances en quatre volets**, **Fournitures via les dépenses**, **Validateurs par rôle ou par personne**, **Validations enchaînées**, **Arrivée/départ auto en fin de journée**, **Export des données (Excel)**, **Remise des factures au client** et **L'espace de démonstration**. Lisez les limites de chaque fonctionnalité avec **Plus** avant de vous y fier pour de l’argent.
- Plusieurs d’entre elles sont de niveau Essentiel et déjà activées dans un nouvel espace. Elles démarrent activées, sans la question ; elle n’apparaît que si vous en réactivez une.
- **Maturité** réduit la liste à un seul stade : c’est un moyen rapide de voir tout ce qui est expérimental et que votre espace utilise déjà.

**Voir aussi :** [Un interrupteur de fonctionnalité](help:user.features.switch)

<!-- anchor: setup.features.profiles -->
### Trois points de départ

**Public:** Propriétaire · Copropriétaire

Vous ne voulez pas décider cent choses. Voici trois points de départ réalistes ; chacun liste exactement ce qui est activé. Choisissez le plus proche, puis ajustez.

Le premier n’a besoin d’aucun modèle. Le deuxième est le modèle prêt à l’emploi de l’application. Le troisième est construit à partir des fonctionnalités elles-mêmes. Ils portent le nom de ce qu’ils offrent, pas d’une taille.

<!-- anchor: setup.features.profile-tiny -->
### Quelques places partagées

**Public:** Propriétaire

Vous gérez une poignée de bureaux ou de salles que l’on réserve, et rien d’autre pour l’instant. Créez l’espace avec **Espace vide** ou avec le modèle « A tiny space » sous **Partir de** : deux niveaux, quatre tables et huit places, de quoi réserver, scanner et parcourir.

Le modèle n’active aucune fonctionnalité : l’espace a donc exactement les 45 fonctionnalités de niveau Essentiel d’[Essentiel et Plateforme](help:setup.features.tiers). Rien n’est activé au-delà. Pour ce profil, laissez le reste de côté :

- La réservation, le calendrier, les messages, l’annuaire, les cartes QR des places, la bibliothèque de documents et les astuces d’aide sont tous là.
- **Onglet Finances** et **Factures** sont activés, mais tant que vous n’avez pas saisi votre identité légale et vos tarifs, ils n’affichent qu’un relevé vide.
- Rien ne demande de configuration en dehors du plan et des horaires d’ouverture. Voir [Votre lieu](help:setup.place.overview).

> **Astuce** Si vous ne facturez jamais rien, vous pouvez laisser les fonctionnalités d’argent activées sans inconvénient : les membres ne voient simplement rien à payer.

<!-- anchor: setup.features.profile-association -->
### Une association avec une salle

**Public:** Propriétaire

Vous êtes une association française qui partage une salle, avec un bureau, des membres qui paient une cotisation et des réservations en demi-journées. Choisissez le modèle « Association de coworking (France) » sous **Partir de**. Il met en place les règles d’ouverture, des tranches de cotisation à 50 % et à 100 %, deux carnets prépayés, les rôles du bureau, le vocabulaire en français et deux étages, et il porte ce profil de fonctionnalités :

- Les 45 fonctionnalités Essentiel, **sauf** quatre qu’il **désactive** : **Onglet Événements**, **Annuaire des membres**, **Fiche membre** et **Regroupement des notifications**. Une petite association n’a pas besoin d’un fil d’événements ni d’un annuaire à côté de ses conversations.
- Quatre qu’il **active**, parce que le bureau en a besoin : **Validations dans le calendrier** (les décisions affichées dans le calendrier), **Carnets** (des demi-journées prépayées pour les personnes qui n’ont pas d’abonnement, Bêta), **Les rôles de cet espace** (trésorier, secrétaire, référent de salle) et **Vocabulaire de l’espace** (les mots propres à l’association).

Cela donne 45 − 4 + 4 = 45 fonctionnalités activées. Le modèle ne contient aucune identité : l’adresse, le numéro d’immatriculation et les coordonnées bancaires restent à saisir par vous, et le régime de TVA démarre sur « non assujetti ».

**Bon à savoir**

- Carnets est en bêta et le modèle l’active sans poser la question ; c’est le choix du modèle, et vous pouvez le désactiver.
- Le modèle laisse **Factures** activée, comme dans l’ensemble Essentiel. Une association qui ne facture pas peut la laisser telle quelle.

<!-- anchor: setup.features.profile-invoicing -->
### Un coworking qui facture

**Public:** Propriétaire

Vous louez des bureaux à des membres et leur envoyez des factures chaque mois, en France ou en Allemagne. Il n’existe pas de modèle prêt à l’emploi : ce profil est donc la liste de ce qu’il faut ajouter à l’ensemble Essentiel, dans cet ordre. Tout s’y enchaîne à partir de **Onglet Finances** et de **Factures**, qui sont déjà activés.

| N° | Activer | Pourquoi | Nécessite |
|---|---|---|---|
| 1 | **Séquences de numérotation** | Décider de la numérotation des documents avant que le premier n’existe. | **Factures** |
| 2 | **Factures d'abonnement** | La cotisation est facturée avant le mois qu’elle couvre. | **Factures** |
| 3 | **Relevés d'usage** | Un relevé du temps réellement utilisé (Bêta). | **Factures** |
| 4 | **Factures de fin de mois** | Ce que le mois a coûté en plus de l’abonnement est facturé à part. | **Factures** |
| 5 | **Assistant de facturation** | Une clôture de mois guidée pour la personne qui fait la facturation. | **Factures** |
| 6 | **Le parcours d'une facture** | Chaque facture montre où elle en est et à qui c’est de jouer. | **Factures** |
| 7 | **Modèle de PDF de facture** | Votre propre texte d’introduction et de pied de page sur le PDF. | **Factures** |
| 8 | **Rapports des membres** | L’accord financier et le rapport mensuel des paiements pour les membres. | **Onglet Finances** |
| 9 | **Relances de paiement** | Des niveaux de relance, une lettre par niveau, « Relance due » sur les factures en retard. | **Factures** |
| 10 | **Rapport de consommation** | Une lettre en fin de mois sur ce qui a été utilisé. | **Relevés d'usage** |

Ajoutez ensuite seulement ce qui vous concerne :

- **Gestion de la TVA** (Bêta) si votre espace est assujetti à la TVA. Puis **Déclarations de TVA**, et **Versions des taux de TVA** et **Groupes de TVA** si votre comptable les demande.
- **Les admins émettent des factures** si vous voulez qu’un administrateur de la facturation puisse en émettre. Le propriétaire le peut toujours.
- **Paiements en ligne** (Bêta) seulement quand vous avez un prestataire de paiement à connecter.
- **Relances de paiement automatiques** seulement après avoir lu [ce qu’elles font](help:setup.money.reminders).
- **Suppléments d'accessoires**, **Carnets** et **Dépenses partagées** quand vous facturez ces éléments.

**Bon à savoir**

- Avant la première facture, complétez votre identité légale et la TVA. Voir [Identité légale et facturation](help:setup.money.identity).
- L’émission ici ne fonctionne que pour les espaces en France et en Allemagne.
- Activez-les une par une et émettez d’abord une facture d’essai dans un espace de test. Voir [L’ordre d’activation](help:setup.features.order).

**Voir aussi :** [Argent et facturation](help:setup.money.overview) · [Partir d’un modèle ou de rien](help:setup.before.template)

<!-- anchor: setup.features.order -->
### L’ordre d’activation

**Public:** Propriétaire · Copropriétaire

Vous voulez éviter le jour où tout est activé et où rien ne marche. Avancez un processus à la fois, et regardez chacun du côté d’un membre avant de passer au suivant.

<p><img src="images/setup-features-order.fr.jpg" width="280"></p>

**Étapes**

1. Gardez l’ensemble Essentiel et faites fonctionner les bases : les places, les horaires d’ouverture, un tarif. Voir [Votre lieu](help:setup.place.overview).
2. Ouvrez [Fonctionnalités](app:/features) et ouvrez une carte de processus. Choisissez le processus qui correspond à votre prochain besoin, pas celui qui paraît le plus complet.
3. Touchez **Activer** pour un sous-processus, ou ouvrez une seule fonctionnalité parmi les **Interrupteurs**.
4. Lisez l’aperçu : ce qui figure sous **Également nécessaires**, ce qui est déjà activé.
5. Regardez-le comme un membre : connectez-vous en tant que tel (un second compte, ou le côté test de votre espace) et faites ce que ferait un membre.
6. Seulement alors, passez au processus suivant.

*Un ordre raisonnable*

| Étape | Processus | Pourquoi cette place dans l’ordre |
|---|---|---|
| 1 | **Gestion des lieux** | Rien ne peut être réservé sans lieu ni horaires d’ouverture. |
| 2 | **Réservations et utilisation** | Les règles de réservation façonnent tout ce qui suit. |
| 3 | **Espace et accès** | Les rôles et qui valide, avant la première invitation. |
| 4 | **Calendrier et coordination** | Les messages et les validations supposent que des personnes existent. |
| 5 | **Offres aux membres**, puis **Facturation & paiements** | Les prix avant les factures ; l’identité légale avant la première facture. |
| 6 | **Documents et informations**, **Intégrations et automatisation** | Ils habillent et livrent ce que produisent les autres. |
| 7 | **Exploitation et administration** | Paires, déploiements et transferts, une fois que l’espace vaut d’être copié. |

**Bon à savoir**

- Activer ne coûte presque rien et désactiver ne supprime rien : une mauvaise étape coûte du temps, pas des données. L’exception est tout ce qui émet une facture : voir [Les décisions difficiles à défaire](help:setup.before.permanent).
- Un espace de test est le bon endroit pour essayer un processus. Voir [Un espace de test ou un espace réel](help:setup.before.environment) et [Un espace de test](help:user.advanced.test-space).
- Invitez les membres en dernier, après les rôles, les règles de validation et les tarifs qu’ils rencontreront.

**Voir aussi :** [Activer ou désactiver des processus entiers](help:user.features.processes)

<!-- anchor: setup.features.safely -->
### Activer une fonctionnalité en sécurité

**Public:** Propriétaire · Copropriétaire

Vous êtes sur le point de modifier une fonctionnalité et vous voulez voir l’effet avant qu’il existe.

<p><img src="images/setup-features-safely.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Fonctionnalités](app:/features). La vue **Processus** s’affiche.
2. Touchez **À examiner**. Il ne reste que les processus qui contiennent quelque chose d’activé mais en attente.
3. Ouvrez une carte. Une fonctionnalité *activée, en attente de* un parent nommé est ce qu’il faut corriger.
4. Corrigez en activant le parent, ou en désactivant la fonctionnalité.
5. Pour changer une seule fonctionnalité, touchez **Interrupteurs**, trouvez-la avec **Rechercher une fonctionnalité** et basculez son interrupteur.
6. Lisez la question ou la ligne « Également activé », et confirmez.

*Ce que veut dire « retenue »*

Une fonctionnalité est retenue quand vous l’avez choisie mais que quelque chose dont elle a besoin est désactivé. Son propre interrupteur reste activé, c’est pourquoi on la manque facilement : l’écran dit que la fonctionnalité est activée, et l’application ne la propose pas. La carte indique combien de fonctionnalités sont retenues (« … sont activées mais attendent un prérequis désactivé ») et quel prérequis elles attendent, et vous corrigez cela dans [Fonctionnalités](app:/features) même. [Ce qui vous attend](help:user.collaborate.attention) montre la même chose, en une ligne par prérequis désactivé.

D’autres choses qu’une fonctionnalité peut attendre ne figurent pas sur cet écran. Une fonctionnalité peut être activée et pleinement autorisée alors que ses informations manquent : votre identité légale, un site, un prestataire de paiement. Elles apparaissent dans **Mise en place de cet espace**, en haut des réglages de l’espace : l’identité légale, quand **Factures** est activé, sous **L'identité légale et l'adresse de l'espace**, le reste sous **Informations requises par vos fonctionnalités (identité, banque, plateformes)**.

**Bon à savoir**

- Si quelqu’un d’autre a modifié les fonctionnalités pendant que vous regardiez, l’application n’écrit rien et le dit : « Les fonctionnalités ont changé entre-temps, rien n’a donc été enregistré. » Regardez de nouveau la liste et recommencez.
- **Modifiées** compte les interrupteurs qui diffèrent de la valeur par défaut du registre. Sur un nouvel espace, il affiche déjà un nombre (les fonctionnalités Plateforme qui démarrent désactivées) : ce n’est donc pas le compte de vos propres changements.
- Seul un propriétaire ou un copropriétaire peut modifier les fonctionnalités. Le serveur le vérifie de nouveau au moment d’écrire.

**Voir aussi :** [Activer ou désactiver des processus entiers](help:user.features.processes) · [Un interrupteur de fonctionnalité](help:user.features.switch)

<!-- anchor: setup.features.consistency -->
### Éviter les fonctionnalités qui se contredisent

**Public:** Propriétaire · Copropriétaire · Administrateur·rice facturation

Vous voulez savoir quelles combinaisons laissent un espace à moitié fonctionnel, et lesquelles l’application détecte pour vous.

L’application a des garde-fous pour certaines contradictions et aucun pour d’autres. Dans le tableau, un garde-fou est ce que fait l’application ; une lacune est ce qui reste de votre responsabilité.

| Si vous avez… | Garde-fou dans l’application | Lacune qui subsiste |
|---|---|---|
| **Factures** activées, pas d’identité légale | L’émission est refusée, avec **Complétez ces informations avant d'émettre** qui liste l’adresse, le numéro de TVA, etc. manquants. Le besoin apparaît aussi dans **Mise en place de cet espace**, sous **L'identité légale et l'adresse de l'espace**, **Nécessaire avant de facturer**, et dans Ce qui vous attend. | La fonctionnalité est activée dès le premier jour : rien n’empêche donc d’inviter des membres et de faire tourner un mois avant que l’identité existe. |
| Un pays autre que la France ou l’Allemagne | L’émission dit que le pays « doit être la France ou l’Allemagne pour émettre ici ». | Rien ne vous avertit quand vous choisissez le pays ou activez la facturation. |
| Assujetti à la TVA, aucun taux en vigueur | L’émission est refusée tant qu’aucun taux par défaut n’est en vigueur. La description de **Gestion de la TVA** et l’avertissement de l’écran d’identité légale le disent. | Avec **Gestion de la TVA** désactivée, la configuration est masquée alors que les taux enregistrés continuent de s’appliquer. Vérifiez les taux après l’avoir désactivée. |
| **Paiements en ligne** activés, pas de prestataire | Un nouveau paiement en ligne est refusé quand la fonctionnalité est désactivée ; l’absence de prestataire apparaît dans **Mise en place de cet espace**. | Vous pouvez l’activer sans prestataire. Connectez-le d’abord : [Prestataire de paiement](help:user.money.payments.provider). |
| **Mode borne** activé, pas de badges ni de membre borne | **Badges RFID / NFC**, **Badges QR**, **Photos des membres à la borne** et **Connexion par badge** ne peuvent pas être activés sans lui. | Rien ne vérifie qu’un membre borne existe ni qu’un badge a été émis. Voir [Faire tourner une tablette murale](help:user.kiosk.mode). |
| **Sites** activés, aucun site | **Au moins un site** apparaît parmi les informations requises par vos fonctionnalités. | L’interrupteur peut être activé sans aucun site. |
| **Notifications push** activées, pas de service de notifications | Les membres reçoivent quand même tout dans l’application. | Les téléphones ne reçoivent rien tant que la personne qui fait tourner l’installation n’a pas configuré le service de notifications. Voir [Comment les membres sont informés](help:setup.notify.channels). |
| **Relances de paiement** activées, **Relances de paiement automatiques** activées | La seconde ne peut pas être activée sans la première. | Le serveur les envoie chaque matin si l’installation planifie des tâches ; sinon, elles partent quand un administrateur ouvre Finances. L’interrupteur et la description de la fonctionnalité le disent ; l’opérateur de votre serveur sait ce qui s’applique. |
| Une règle de validation qui demande plus de validateurs qu’il n’en existe | **Mise en place de cet espace** dit « Une règle demande plus de validateurs que cet espace n’en compte », et **Rôles et validation des demandes** devient obligatoire, quel que soit le type de demande. | Les demandes créées avant que vous corrigiez ne peuvent pas être menées à bien et expirent au bout de sept jours. Voir [Qui valide](help:user.validation.overview). |
| **Demandes de suppression de réservation** activées, personne pour valider | La même ligne de préparation. | La même lacune. |
| **Réservations de table, bureau et niveau** activées | **Les admins peuvent attribuer des niveaux** en a besoin. | Chaque membre doit aussi en avoir le droit ; rien ne vérifie que quelqu’un l’a. |
| Une fonctionnalité enfant activée, son parent désactivé | **À examiner**, et « En attente de la fonction au-dessus ». | Aucune : ce cas est entièrement couvert. |
| Un espace créé depuis un modèle | Le modèle nomme ce que vous devez saisir (identité, banque, site). | Il n’en contient aucun : un espace peut donc démarrer avec **Factures** activées et rien pour émettre. |

**Bon à savoir**

- La règle d’or : si une fonctionnalité met votre nom, votre argent ou vos obligations légales sur un document, finissez ses informations avant d’en parler aux membres.
- **Mise en place de cet espace** est une liste, pas un verrou. Elle ne vous empêche jamais d’activer quelque chose.
- La vérification « Avant que quiconque puisse réserver ici » ne parle que des domaines obligatoires : le fuseau horaire, la devise, un jour de semaine ouvert, au moins une place, des membres qui détiennent **Réserver et utiliser les réservations** et assez de validateurs. Quand **Factures** est activé, l’identité légale est aussi obligatoire, mais avant de facturer : la carte de l’espace dit « Avant de facturer », et celle de Réserver ne la mentionne jamais.

**Voir aussi :** [Identité légale et facturation](help:setup.money.identity) · [Essai à blanc](help:setup.money.dry-run)

<!-- anchor: setup.features.map -->
### La carte des fonctionnalités

**Public:** Propriétaire · Copropriétaire

Vous voulez un seul endroit qui dise, pour les principales fonctionnalités, ce que les membres obtiennent, ce qu’il faut et qui doit les configurer. « Nécessite » liste d’abord la fonctionnalité du dessus, puis les informations hors de l’écran Fonctionnalités. « Qui » est la personne qui doit agir avant que ce soit utile ; « Personne » veut dire que cela fonctionne dès l’activation.

*Espace et accès*

| Fonctionnalité | Ce qu’elle apporte aux membres | Ce qu’il faut | Qui configure |
|---|---|---|---|
| **Annuaire des membres** | L’onglet de la communauté : qui est là, statuts, présence. | | Personne |
| **Copropriétaires** | Les permissions du propriétaire pour des personnes désignées, dès maintenant ou en cas de succession. | | Propriétaire |
| **Gestion des rôles** | La matrice des permissions détenues par chaque rôle. | | Propriétaire |
| **Attribution des rôles** | Une section Rôles sur chaque fiche membre. | **Gestion des rôles** | Propriétaire |
| **Les rôles de cet espace** | Vos propres rôles, comme trésorier ou secrétaire. | | Propriétaire |
| **Les questions de cet espace** | Vos propres questions dans le formulaire d’identité. | | Propriétaire |
| **Informations personnelles** | Nom, adresse, téléphone et identifiants que les courriers impriment. | | Les membres |
| **Profils gérés** | Des membres sans compte, pour qui l’on réserve et facture. | **Annuaire des membres** | Administrateur |
| **Fiche membre** | Une page par membre. | **Annuaire des membres** | Personne |
| **Visites d'invités** | Une personne qui n’est pas membre peut demander à venir. | | La personne qui admet les visites |
| **Mode borne** | Une tablette murale verrouillée sur le plan en direct. | Une tablette et un membre borne | Propriétaire |
| **Badges RFID / NFC** | S’enregistrer en passant une carte. | **Mode borne**, Android avec NFC, badges émis | Propriétaire |
| **Badges QR** | Cartes-badges QR imprimables. | **Mode borne** | Propriétaire |
| **Connexion par badge** | Badge et code PIN au lieu de saisir une adresse e-mail. | **Badges RFID / NFC** | Propriétaire, puis chaque membre |
| **Tags NFC/RFID des chaises** | Une puce sur une chaise ouvre sa place. | Des tags | Propriétaire |
| **Codes QR des espaces** | Cartes QR imprimables par place. | | Personne |

*Gestion des lieux*

| Fonctionnalité | Ce qu’elle apporte aux membres | Ce qu’il faut | Qui configure |
|---|---|---|---|
| **Sites** | Plusieurs adresses, chacune avec son propre enregistrement. | Au moins un site | Propriétaire |
| **Supprimer des espaces avec historique** | Les propriétaires peuvent supprimer un lieu qui a des réservations passées. | | Personne |
| **Les admins peuvent bloquer des places** | Des places marquées non réservables pour maintenance. | | Propriétaire |
| **Horaires de travail** | La journée de travail et la réservation à l’heure exacte. | | Propriétaire |
| **Jours fériés** | Des jours de fermeture tirés des jours fériés d’une année. | | Propriétaire |
| **Importer les jours fériés** | Les jours fériés d’un pays ou d’une région importés. | **Jours fériés** | Propriétaire |
| **Occupation des places** | Un chiffre mensuel du taux de réservation. | | Propriétaire |
| **Photos des membres sur le plan** | Les photos des occupants sur les places. | | Personne |
| **Vocabulaire de l’espace** | Les mots propres à l’espace pour quelques libellés. | | Propriétaire |
| **Couleurs de l’espace** | La couleur de la marque et les couleurs des salles. | | Propriétaire |
| **Présentation publique de l’espace** | Une page publique avec ce que vous choisissez de montrer. | | Propriétaire |

*Réservations et utilisation*

| Fonctionnalité | Ce qu’elle apporte aux membres | Ce qu’il faut | Qui configure |
|---|---|---|---|
| **Réservation en série** | Répéter une réservation. | | Personne |
| **Réserver pour d'autres** | Les administrateurs réservent pour les membres. | | Personne |
| **Réservations de table, bureau et niveau** | Réserver une table, un bureau ou un étage entier. | Un droit accordé à chaque membre | Propriétaire |
| **Les admins peuvent attribuer des niveaux** | Les administrateurs attribuent ces réservations. | **Réservations de table, bureau et niveau** | Propriétaire |
| **Règles de réservation** | Réservations passées, réservations hors horaires, départ enregistré par l’administrateur. | | Propriétaire |
| **Garde-fou de réservation** | Chaque écran vérifie les règles et nomme le motif. | **Règles de réservation** | Personne |
| **Arrivée/départ auto en fin de journée** | Les réservations non pointées se terminent d’elles-mêmes. | | Propriétaire |
| **Relevés d'usage** | Le temps réellement utilisé, et une demande pour cesser de facturer le temps non utilisé. | **Factures** | Administrateur·rice facturation |

*Calendrier et coordination*

| Fonctionnalité | Ce qu’elle apporte aux membres | Ce qu’il faut | Qui configure |
|---|---|---|---|
| **Onglet Calendrier**, **Calendrier central**, **Vues du calendrier** | Mois, semaine et agenda, avec tout ce qui est daté. | | Personne |
| **Validations dans le calendrier** | Les décisions affichées à la date où elles ont été prises. | **Calendrier central** | Personne |
| **Onglet Événements** | Le fil d’activité et les confirmations. | | Personne |
| **Regroupement des notifications** | Les notifications regroupées dans le fil. | | Personne |
| **Validateurs par rôle ou par personne** | Une règle peut nommer qui valide et combien. | | Propriétaire |
| **Validations enchaînées** | Des validations demandées l’une après l’autre. | | Propriétaire |
| **Demandes de suppression de réservation** | Un membre demande la suppression d’une réservation passée. | Un validateur | Propriétaire |
| **Notifications entre membres** | Conversations privées et de groupe. | | Personne |
| **Messages repensés** | Barre de la boîte de réception, épingler, mettre en sourdine, archiver, brouillons. | | Personne |
| **Écrire aux hôtes** | Une personne qui trouve votre page peut vous écrire. | Une page publiée | Propriétaire |
| **Mentions dans les groupes**, **Transfert de messages**, **Protection contre la capture d’écran** | Compléments de messagerie. | **Notifications entre membres** | Personne |

*Offres aux membres*

| Fonctionnalité | Ce qu’elle apporte aux membres | Ce qu’il faut | Qui configure |
|---|---|---|---|
| **Services** | Un catalogue de choses à consommer et à payer. | **Onglet Finances** | Administrateur·rice facturation |
| **Suppléments d'accessoires** | Des accessoires de place tarifés par demi-journée. | **Onglet Finances** | Administrateur·rice facturation |
| **Négociations tarifaires** | Des conditions propres à un membre. | **Onglet Finances** | Administrateur·rice facturation |
| **Conditions de paiement par membre** | Des conditions de paiement propres. | **Factures** | Administrateur·rice facturation |
| **Carnets** | Des demi-journées prépayées (Bêta). | **Factures**, un carnet défini | Administrateur·rice facturation |

*Facturation & paiements*

| Fonctionnalité | Ce qu’elle apporte aux membres | Ce qu’il faut | Qui configure |
|---|---|---|---|
| **Onglet Finances** | L’onglet Finances : relevé, paiements, dépenses. | | Personne |
| **Finances en quatre volets** | Relevé, Paiements, Factures, Documents. | **Onglet Finances** | Personne |
| **Rapports des membres** | L’accord et le rapport mensuel des paiements. | **Onglet Finances** | Administrateur·rice facturation |
| **Factures** | Des factures signées et immuables (Bêta). | **Onglet Finances**, identité légale, TVA, FR ou DE | Administrateur·rice facturation |
| **Les admins émettent des factures** | Les administrateurs en émettent aussi. | **Factures** | Propriétaire |
| **Factures d'abonnement** | La cotisation facturée avant son mois. | **Factures**, une date | Administrateur·rice facturation |
| **Factures de fin de mois** | L’usage facturé après le mois. | **Factures** | Administrateur·rice facturation |
| **Regrouper les factures** | Plusieurs factures ouvertes réunies en une. | **Factures** | Administrateur·rice facturation |
| **Le parcours d'une facture** | Où en est chaque facture. | **Factures** | Personne |
| **Assistant de facturation** | Une clôture de mois guidée. | **Factures** | Administrateur·rice facturation |
| **Séquences de numérotation** | Une numérotation par journal. | **Factures** | Administrateur·rice facturation |
| **Paiements en ligne** | Payer en ligne (Bêta). | **Onglet Finances**, un prestataire de paiement | Propriétaire |
| **Relances de paiement** | Niveaux de relance et lettres. | **Factures**, des règles | Administrateur·rice facturation |
| **Relances de paiement automatiques** | Des relances envoyées d’elles-mêmes. | **Relances de paiement** | Administrateur·rice facturation |
| **Fournitures via les dépenses** | Les fournitures achetées deviennent des services. | **Services** | Administrateur·rice facturation |
| **Dépenses programmées** | Des frais récurrents planifiés. | **Onglet Finances** | Administrateur·rice facturation |
| **Dépenses partagées** | Des frais partagés entre membres. | **Factures** | Administrateur·rice facturation |
| **Assistant de répartition** | Un partage guidé d’un frais commun. | **Dépenses partagées** | Administrateur·rice facturation |
| **Livre comptable** | Qui tient les livres officiels. | **Factures** | Administrateur·rice facturation |
| **Gestion de la TVA** | Les taux de TVA et leurs sélecteurs (Bêta). | **Factures**, régime de TVA | Administrateur·rice facturation |
| **Déclarations de TVA** | La déclaration périodique. | **Gestion de la TVA** | Administrateur·rice facturation |
| **Groupes de TVA**, **Versions des taux de TVA**, **TVA selon le client** | Un traitement plus fin de la TVA. | **Gestion de la TVA** | Administrateur·rice facturation |

*Documents et informations, Exploitation, Intégrations*

| Fonctionnalité | Ce qu’elle apporte aux membres | Ce qu’il faut | Qui configure |
|---|---|---|---|
| **Bibliothèque de documents** | Statuts, procès-verbaux, guides, par rôle. | | Propriétaire |
| **Export PDF** | La facture mensuelle en PDF. | | Personne |
| **Modèle de PDF de facture** | Vos textes sur la facture. | **Factures** | Propriétaire |
| **Concepteur de rapports**, **Maquettes de rapport positionnées**, **Textes des rapports** | Des rapports conçus sur mesure. | **Modèle de PDF de facture** | Propriétaire |
| **Rapport de consommation** | Une lettre mensuelle sur ce qui a été utilisé. | **Relevés d'usage** | Administrateur·rice facturation |
| **Déclaration de TVA** | Chaque ligne imposable, avec un CSV. | **Déclarations de TVA** | Administrateur·rice facturation |
| **Journal des accès aux données** | Les membres voient qui a consulté leurs finances. | **Onglet Finances** | Personne |
| **Export des données (Excel)** | Le propriétaire exporte les données sous forme de classeur (Bêta). | La permission **Exporter la comptabilité et les données** | Propriétaire |
| **Export et effacement** | Un membre exporte et efface ses propres données. | | Personne |
| **Mode tournage** | Remplace à l’écran les vraies personnes par des personnes inventées. | | Propriétaire |
| **Paires d'environnements**, **Déploiements** | Un côté test et un côté réel, avec déploiement. | | Propriétaire |
| **Configuration dans le fichier de l'espace** | Toute la configuration voyage dans le fichier de l’espace. | **Export des données (Excel)** | Propriétaire |
| **Assistant d'instance** | Créer un nouveau serveur depuis l’application. | | Opérateur·rice |
| **Ce qui vous attend** | Une seule liste classée de ce qui vous attend. | | Personne |
| **Enregistreur de tâches** | Enregistrer et rejouer les étapes d’une tâche. | | Personne |
| **Notifications push** | Les confirmations en attente sur le téléphone. | Le service de notifications de l’installation | Opérateur·rice |
| **Intégration WhatsApp** | Une conversation avec un membre en un geste, le lien du groupe. | **Annuaire des membres** | Propriétaire |
| **Remise des factures au client** | L’envoi vers la propre plateforme du client (Bêta). | **Factures**, un compte | Administrateur·rice facturation |
| **Interface MCP** | Un assistant peut être connecté. | Une autorisation par personne, approuvée par l’installation | Propriétaire, puis Opérateur·rice |

**Bon à savoir**

- Les noms sont ceux de la liste **Interrupteurs**. Le niveau Essentiel ou Plateforme de chacune y est indiqué.
- Quelques fonctionnalités ne figurent pas ici. Celles de confort (astuces d’aide, animations, style de navigation, formats régionaux) n’ont pas de ligne dans le tableau : elles fonctionnent dès qu’elles sont activées.

**Voir aussi :** [Qui fait quoi](help:setup.before.who) · [Activer et désactiver des fonctionnalités](help:user.features.processes)
