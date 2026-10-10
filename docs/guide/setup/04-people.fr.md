<!-- anchor: setup.people.overview -->
## Les personnes, les rôles et les décisions

Un espace, c’est ses personnes. Avant d’inviter la première, décidez trois choses : qui peut faire quoi, comment on entre, et quels actes demandent l’accord d’une seconde personne. Ces réglages sont rapides à faire et pénibles à réparer une fois que quarante personnes s’y fient.

Dans ce chapitre :
- [Qui fait quoi dans une vraie organisation](help:setup.people.organisation)
- [La matrice des rôles : le moindre privilège](help:setup.people.matrix)
- [Copropriétaires : plus d’une personne qui peut agir](help:setup.people.coowner)
- [Comment les personnes rejoignent l’espace](help:setup.people.join)
- [Le message d’invitation, langue par langue](help:setup.people.invitation)
- [Profils gérés](help:setup.people.managed)
- [Validation : de quoi est faite une règle](help:setup.people.validation)
- [Trois préréglages à copier](help:setup.people.presets)
- [Éviter les demandes qui attendent pour toujours](help:setup.people.stuck)
- [La première semaine de vos membres](help:setup.people.first-week)

L’exemple suivi est *Atelier du Marché*. Imaginez qu’il soit géré par une association : Ada en est la présidente, Chiara la secrétaire, Bruno le trésorier. Chaque étape ci-dessous est montrée sur cet espace.

<!-- anchor: setup.people.organisation -->
### Qui fait quoi dans une vraie organisation

**Public:** Propriétaire · Copropriétaire

Vous voulez faire correspondre les personnes de votre organisation aux rôles que propose DesKilo, pour que personne ne détienne plus que ce que son travail demande.

<p><img src="images/setup-people-members.fr.jpg" width="280"></p>

*Les quatre rôles de base*

| Rôle | À quoi il sert | Dans l’association |
|---|---|---|
| **Propriétaire** | La personne qui répond de l’espace et détient toutes les permissions. Seul un propriétaire peut accorder la propriété. | Ada, la présidente. |
| **Copropriétaire** | Une seconde clé. Détient par défaut toutes les permissions, et peut prendre le relais quand le propriétaire part. | Le vice-président, si le bureau en a un. |
| **Administrateur·rice** | Fait tourner le quotidien : membres, réservations pour d’autres, borne, documents, services. Détient ce que la matrice lui donne, et rien de plus. | Chiara, la secrétaire. |
| **Utilisateur** | La personne qui utilise l’espace. Ne détient que les permissions de tous les jours que vous lui donnez. | Bruno, un membre comme les autres. |

Chaque personne a exactement un rôle de base. Un rôle que l’espace définit, comme *Hôte* ou *Comptable*, s’y ajoute et n’enlève jamais rien.

*Un trésorier sans être administrateur*

Bruno tient les comptes, mais ne devrait pas modifier le plan ni approuver de nouveaux membres. Donnez-lui le rôle de base **Utilisateur** et ajoutez un rôle à vous, par exemple *Comptable*, avec quatre permissions : **Consulter les finances de l'espace**, **Émettre les factures et rapprocher les paiements**, **Exporter la comptabilité et les données** et **Consulter les chiffres de l'espace**. Rien de plus. Aucun rôle de ce type n’est fourni : vous le créez avec les étapes ci-dessous.

<p><img src="images/setup-people-roles-space.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Les rôles de cet espace](app:/settings/roles-of-this-space) et touchez **Ajouter un rôle**. Voir [Les rôles de cet espace](help:user.roles.space).
2. Nommez le rôle, choisissez **Ce qu'il ajoute**, touchez **Enregistrer le rôle**.
3. Ouvrez la personne dans [Membres et forfaits](app:/members), trouvez **Rôles** et touchez **Ajouter un rôle**.

**Bon à savoir**

- **Les rôles de cet espace** est une fonctionnalité à part entière, désactivée dans un nouvel espace. Activez-la dans [Fonctionnalités](app:/features).
- Personne ne peut se donner un rôle à soi-même. Donner un rôle demande **Gérer les rôles et permissions**, et seul un propriétaire peut donner un rôle qui la comporte.
- Un rôle défini par l’espace prend effet aussitôt et est enregistré. Seuls le fait de nommer quelqu’un administrateur, ou de le lui retirer, suit la règle de validation **Changement de rôle**.

**Résultat** Chaque personne du bureau détient les permissions de son travail, et le propriétaire reste le seul à pouvoir les changer.

**Voir aussi :** [La matrice des rôles](help:user.roles.matrix)

<!-- anchor: setup.people.matrix -->
### La matrice des rôles : le moindre privilège

**Public:** Propriétaire · Copropriétaire

Vous voulez que chaque rôle détienne ce dont il a besoin, et rien d’autre. C’est le principe du moindre privilège : commencer petit, ajouter quand quelqu’un le demande, car une permission accordée se reprend rarement de bonne grâce.

<p><img src="images/setup-people-roles-matrix.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Rôles](app:/roles). Il y a une carte par rôle : **Propriétaire**, **Copropriétaire**, **Administrateur·rice** (le propriétaire peut la renommer) et **Utilisateur**.
2. Lisez d’abord la carte **Administrateur·rice**. Elle montre ce qu’un administrateur détient aujourd’hui dans votre espace.
3. Décochez ce que vous ne voulez pas déléguer. Cochez les permissions de tous les jours dont la carte **Utilisateur** a besoin (voir plus bas).

*Ce qu’un administrateur détient par défaut*

| Groupe | Permissions |
|---|---|
| Personnes | **Gérer les membres**, **Consulter les données personnelles des membres** |
| Réservations et lieu | **Gérer les réservations des autres**, **Opérer le kiosque et les badges**, **Gérer les sites et modifier le plan** |
| Argent : lire et approuver | **Consulter les finances de l'espace**, **Approuver les dépenses**, **Gérer les services et forfaits**, **Consulter les accords commerciaux**, **Gérer les accords commerciaux**, **Demander un changement de conditions de paiement**, **Exporter la comptabilité et les données** |
| Documents et chiffres | **Gérer la bibliothèque de documents**, **Consulter les chiffres de l'espace** |
| Les deux côtés d’un espace | **Déployer en développement**, **Entrer dans l'espace de production** |

Un administrateur ne détient pas **Gérer les rôles et permissions**, **Configurer les règles de validation**, **Modifier les réglages de l'espace**, **Gérer les tarifs et règles de facturation**, **Concevoir les documents**, **Gérer les intégrations**, **Gérer la configuration** ni **Déployer en production**. Un copropriétaire les détient toutes, jusqu’à ce que vous en décochiez. Le propriétaire les détient toujours toutes.

> **Attention** Dans un nouvel espace, la carte **Utilisateur** est vide. Les six permissions de tous les jours (**Utiliser la messagerie**, **Réserver et utiliser les réservations**, **Voir le calendrier**, **Voir l'annuaire des membres**, **Voir son propre compte et ses factures**, **Voir les documents partagés**) ne sont détenues que par la matrice ou par un rôle. Tant que vous ne les cochez pas, un membre qui arrive ne peut pas ouvrir le plan. La démonstration les montre déjà cochées, ce qui masque ce point. **Mise en place de cet espace** affiche **Ce que les membres peuvent faire** comme **Nécessaire pour une première réservation** tant que la carte **Utilisateur** ne détient pas **Réserver et utiliser les réservations** ; elle ne vérifie pas les cinq autres. Cochez-les pour la carte **Utilisateur**, et pour la carte **Administrateur·rice** si les administrateurs réservent aussi, puis testez avec un second compte.

**Bon à savoir**

- Par défaut, un administrateur peut lire toutes les finances et les données personnelles de chaque membre. Si vos administrateurs sont bénévoles, demandez-vous si c’est souhaitable.
- **Les admins émettent des factures** (une fonctionnalité, désactivée par défaut, sous **Factures**) donne aux administrateurs **Émettre les factures et rapprocher les paiements** quoi que dise la matrice. Préférez la case de la matrice, ou un rôle à vous, qui est plus précis.
- Décocher une permission la retire partout à la fois ; le serveur la vérifie, pas seulement le menu.
- Chaque changement de la matrice est enregistré comme un événement. La fonctionnalité **Gestion des rôles** n’affiche que l’écran ; désactivée, la matrice que vous avez enregistrée continue de s’appliquer, vous ne pouvez simplement plus la modifier.

**Résultat** Une matrice que vous savez expliquer en une phrase par rôle.

**Voir aussi :** [La matrice des rôles](help:user.roles.matrix) · [Qui fait quoi](help:setup.before.who)

<!-- anchor: setup.people.coowner -->
### Copropriétaires : plus d’une personne qui peut agir

**Public:** Propriétaire · Copropriétaire

Vous voulez que l’espace continue de fonctionner quand vous êtes malade, absent ou parti. Tout espace a besoin de plus d’une personne qui peut agir. Par défaut, seuls les propriétaires et les copropriétaires détiennent les permissions qui changent les fonctionnalités, les rôles, les règles de validation et l’ID de l’espace, et seul un propriétaire peut nommer un autre propriétaire.

<p><img src="images/setup-people-coowner.fr.jpg" width="280"></p>

*Les deux sortes*

| Sorte | Ce qu’elle fait | À choisir quand |
|---|---|---|
| *Copropriétaire actif* | Détient dès maintenant les permissions du propriétaire, et prend le relais si le propriétaire part. | Vous partagez le travail : le vice-président, un associé. |
| **Successeur** | Attend. Devient propriétaire quand vous le promouvez ou quand vous partez. | Vous voulez seulement un héritier. |

**Étapes**

1. Activez la fonctionnalité **Copropriétaires** dans [Fonctionnalités](app:/features). Elle est désactivée dans un nouvel espace.
2. Ouvrez la personne dans [Membres et forfaits](app:/members), allez à **Gérer** et touchez **Copropriété**.
3. Choisissez *Copropriétaire actif* ou **Successeur**. Pour transmettre dès maintenant, choisissez **Promouvoir propriétaire maintenant**.

**Bon à savoir**

- Si le dernier propriétaire part, le meilleur copropriétaire devient propriétaire de lui-même, un actif avant un successeur.
- Deux administrateurs, ce n’est pas la même chose : un administrateur ne détient que ce que la matrice lui donne et ne peut jamais transmettre la propriété.
- Une règle qui dit **Le propriétaire doit toujours valider** demande un propriétaire. Vérifiez sur votre côté test que votre copropriétaire peut toujours décider ce que vous attendez.

**Résultat** L’espace a une seconde personne qui peut agir.

**Voir aussi :** [Copropriétaires](help:user.roles.co-owners) · [Copropriété](help:user.members.co-ownership)

<!-- anchor: setup.people.join -->
### Comment les personnes rejoignent l’espace

**Public:** Propriétaire · Administrateur·rice

Vous voulez choisir comment les gens arrivent dans votre espace et qui les laisse entrer. Il existe quatre voies, et chacune aboutit au même endroit : une personne qui demande à rejoindre, et quelqu’un qui décide.

<p><img src="images/setup-people-workspace-code.fr.jpg" width="280"></p>

| Voie | Ce que la personne reçoit | Ce qu’elle devient |
|---|---|---|
| L’ID de l’espace | Un mot court, saisi dans l’application. | Membre, après approbation. |
| Le QR code | Le même ID sous forme d’image à imprimer ou à afficher (**Partager en PNG**). | Membre, après approbation. |
| Un message d’invitation | Un texte avec un code personnel, valable pour une seule personne, dans la langue que vous choisissez. | Le rôle que vous proposez, après approbation. |
| Un code administrateur | Un code pour une seule personne, depuis l’onglet **Invitation administrateur·rice**. | Administrateur, une fois. |

**Étapes**

1. Ouvrez [ID de l’espace et QR](app:/workspace-code). Choisissez un ID dont on peut se souvenir avec **Changer l'ID de l'espace** : de 4 à 20 lettres ou chiffres, unique dans tout DesKilo.
2. Pour une personne nommée, touchez **Inviter quelqu'un**. Renseignez le nom, cochez **Rôles à l'arrivée** si elle doit recevoir un rôle, choisissez la **Langue du message** et envoyez.
3. Quand quelqu’un demande à rejoindre, sa ligne dans [Membres et forfaits](app:/members) indique **En attente**. Ouvrez-la et choisissez **Approuver l'adhésion** ou **Refuser l'adhésion**.

**Bon à savoir**

- Personne n’entre sans décision. Tant qu’elle n’est pas prise, la personne qui arrive voit un écran d’attente et rien d’autre.
- La décision suit la règle de **Nouveau membre** dans les [Règles de validation](app:/validation) : par défaut, un propriétaire ou un administrateur suffit ; si vous en exigez deux, la première approbation laisse la personne en attente.
- Si vous changez l’ID de l’espace, l’ancien cesse de fonctionner. Imprimez de nouveau le QR code.
- Il n’y a pas d’invitation de propriétaire. La propriété se donne dans **Membres et forfaits**.

**Résultat** Les gens peuvent vous trouver, et vous décidez qui reste.

**Voir aussi :** [L’ID de l’espace](help:user.workspace.code) · [Rejoindre un espace](help:user.start.join) · [Membres en attente et en pause](help:user.members.pending)

<!-- anchor: setup.people.invitation -->
### Le message d’invitation, langue par langue

**Public:** Propriétaire · Administrateur·rice

Vous voulez une invitation qui ressemble à votre espace, dans la langue de la personne qui la reçoit. Chaque langue a son propre texte ; celle que vous ne rédigez pas retombe sur le message fourni.

<p><img src="images/setup-people-invite.fr.jpg" width="280"></p>

<p><img src="images/setup-people-invitation-message--message.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Espace](app:/workspace-settings) et allez à **Communauté et invitations**.
2. Sous **Langue du message**, choisissez la langue pour laquelle vous écrivez. La ligne s’ouvre sur la langue de votre espace.
3. Rédigez le texte. Touchez une balise pour l’insérer à l’endroit du curseur. La limite est de 2 000 caractères.
4. Recommencez pour chaque langue que vos membres utilisent, puis touchez **Enregistrer**.

*Les balises*

| Balise | Remplie avec |
|---|---|
| `{firstName}` `{lastName}` `{phone}` | Ce que vous avez saisi dans **Inviter quelqu'un**. Vide si vous n’avez rien saisi. |
| `{workspaceName}` | Le nom de votre espace. |
| `{workspaceId}` | Le code d’invitation personnel de ce message (pas l’ID public de l’espace). |
| `{inviteLink}` | Un lien qui ouvre l’application sur le bon serveur, avec le code déjà rempli. |
| `{downloadUrl}` | La page de l’application dans la boutique. |
| `{role}` | Le rôle que propose l’invitation, dans la langue du message. |

**Bon à savoir**

- Laissez la case vide et l’application rédige son propre message dans cette langue. Il explique les étapes : télécharger, créer un compte, rejoindre avec le code.
- Ne collez pas vous-même un code ou un lien. Chaque envoi crée son propre code, valable pour une seule personne.
- Une balise mal orthographiée reste visible dans le texte envoyé : lisez l’aperçu avant d’envoyer.
- Le message fourni indique à la personne que le code est à usage unique et valable 14 jours.

**Résultat** Une invitation que vos membres peuvent suivre sans vous poser de question.

**Voir aussi :** [Message d’invitation](help:user.workspace.settings.invitation-message) · [Inviter quelqu’un par message](help:user.workspace.code.invite)

<!-- anchor: setup.people.managed -->
### Profils gérés

**Public:** Propriétaire · Administrateur·rice

Vous voulez réserver, facturer et gérer pour quelqu’un qui n’a pas encore de compte : un visiteur, un membre âgé, une personne qui préfère le papier.

**Étapes**

1. Activez **Profils gérés** dans [Fonctionnalités](app:/features).
2. Dans [Membres et forfaits](app:/members), touchez **Ajouter un profil géré** et renseignez l’identité.
3. Quand la personne est prête, ouvrez sa page et choisissez **Remettre à la personne**. Cela crée un code personnel lié au profil.

**Bon à savoir**

- La personne qui utilise le code reprend le profil avec ses réservations, ses factures et son abonnement, une fois que vous approuvez l’adhésion.
- Reprenez la remise avec **Annuler la remise** si le code n’a pas encore été utilisé.

**Voir aussi :** [Ajouter un profil géré](help:user.members.managed)

<!-- anchor: setup.people.validation -->
### Validation : de quoi est faite une règle

**Public:** Propriétaire

Vous voulez choisir, acte par acte, si une seconde personne doit donner son accord. Un domaine de validation est une sorte d’acte avec sa propre règle : *un paiement*, *une dépense*, *un nouveau membre*, *la suppression d’une réservation*. Dans **Règles de validation**, les domaines sont répartis en trois groupes.

<p><img src="images/setup-people-validation-overview.fr.jpg" width="280"></p>

| Groupe | Domaines, en mots simples | Pendant l’attente |
|---|---|---|
| **Argent** | Un paiement, une dépense, un service, une facture rapprochée de son paiement, une facture émise ou annulée, un remboursement, une passation en perte, un accord de prix, une dépense partagée, une dépense programmée, un changement de conditions de paiement, un départ anticipé, un relevé d’usage supprimé | Le montant ne compte sur le relevé de personne. |
| **Réservations** | Les **Demi-journées supplémentaires** qu’un membre demande, les **Réservations d'espaces entiers**, une réservation faite pour un membre par un administrateur, une **Suppression de réservation** | La place reste telle qu’elle était. |
| **Personnes et rôles** | **Nouveau membre**, un changement de rôle, un changement de statut, un changement d’abonnement, un changement de la matrice des permissions | La personne garde l’accès qu’elle a actuellement. |

Chaque domaine démarre sur **Hérite de la règle par défaut** : une validation par n’importe quel administrateur ou propriétaire. **Règle par défaut** est la règle dont héritent toutes les autres. Un domaine que vous ouvrez et enregistrez devient **Personnalisée**.

*Les curseurs d’une règle*

| Réglage | Ce qu’il signifie | Nécessite |
|---|---|---|
| **Validations requises** | Combien de personnes doivent dire oui. | |
| **Qui valide** | **Les admins**, **Personnes désignées** ou **Tous les membres**. Le propriétaire le peut toujours. | **Validateurs par rôle ou par personne** : sans elle, le choix n’est pas affiché et les administrateurs valident. Après l’avoir désactivée, vérifiez de nouveau les règles qui nommaient **Personnes désignées** |
| **Les admins peuvent valider** | Désactivé, seuls les propriétaires valident. | |
| **Le propriétaire doit toujours valider** | Un des oui doit venir d’un propriétaire. | |
| **Le propriétaire peut valider le sien** | La demande du propriétaire lui-même n’attend pas quelqu’un d’autre. Un administrateur n’obtient jamais cela. | **Validations enchaînées** |
| **L'une après l'autre** | La seconde est demandée quand la première a dit oui. | **Validations enchaînées** |
| **Seulement au-delà de ce montant** | En dessous, l’acte s’applique aussitôt. Domaines d’argent uniquement. | **Validations enchaînées** |
| **Les admins suppriment sans validation** / **Les propriétaires suppriment sans validation** | Leur propre **Suppression de réservation** se règle d’elle-même et reste marquée comme validée automatiquement. Désactivé par défaut. | |

<p><img src="images/setup-people-validation-sheet.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Règles de validation](app:/validation). Touchez **Règle par défaut** et décidez de ce dont tout le reste hérite.
2. Touchez un domaine, réglez les curseurs, touchez **Enregistrer**.
3. Gardez peu d’exceptions. Chaque exception est une chose de plus à retenir quand quelqu’un demande « pourquoi cela attend-il ? ».

**Bon à savoir**

- Personne ne valide son propre acte. Il attend quelqu’un d’autre, sauf si l’exception du propriétaire est activée.
- Chaque décision est enregistrée : qui, quand, sur quoi.
- Une demande à laquelle personne ne répond expire au bout de sept jours, constatés la prochaine fois que quelqu’un ouvre Événements. Un acte qu’un administrateur a fait pour un membre est en revanche confirmé automatiquement.

**Voir aussi :** [Règles de validation, domaine par domaine](help:user.validation.overview) · [Qui peut valider](help:user.validation.who-may) · [Validation automatique](help:user.validation.auto-validate-admin)

<!-- anchor: setup.people.presets -->
### Trois préréglages à copier

**Public:** Propriétaire

Vous voulez un jeu de règles que vous pouvez copier aujourd’hui et affiner plus tard. Choisissez-en un ; chacun s’appuie sur le périmètre par défaut, propriétaire et administrateurs, si bien qu’aucune fonctionnalité supplémentaire n’est nécessaire.

| Préréglage | À choisir quand | Ce que vous réglez | Validateurs nécessaires |
|---|---|---|---|
| *Adhésion libre* | Vous connaissez les personnes qui scanneront votre code. | Rien. Chaque domaine hérite de la règle par défaut : une validation par n’importe quel propriétaire ou administrateur. Une adhésion n’est tout de même jamais automatique. | 1 (vous) |
| *Adhésions validées* | Un bureau décide qui entre. | **Nouveau membre** : **Validations requises** 2, **Le propriétaire doit toujours valider** activé. | 2 : un propriétaire et un administrateur |
| *Adhésions et réservations validées* | Les places ou les salles entières sont rares, ou les suppressions de réservation demandent un témoin. | *Adhésions validées*, plus, sur **Réservations d'espaces entiers**, **Demi-journées supplémentaires** et **Suppression de réservation** : **Validations requises** 1. | 2 au minimum, 3 pour être à l’aise |

Dans l’association : Ada est propriétaire, Chiara administratrice. Avec *Adhésions validées*, Ada et Chiara approuvent toutes deux chaque nouvelle personne. Avec le troisième préréglage, une salle entière que Bruno réserve lui est aussitôt bloquée, mais Ada ou Chiara peuvent encore la refuser, et une suppression que Chiara demande est décidée par Ada, pas par Chiara.

**Étapes**

1. Ouvrez [Règles de validation](app:/validation).
2. Touchez **Nouveau membre**, réglez ce que dit le tableau, touchez **Enregistrer**.
3. Pour le troisième préréglage, recommencez sur les trois autres domaines.
4. Ouvrez **Membres et forfaits** et comptez vos propriétaires et administrateurs actifs. Il en faut au moins le nombre de la dernière colonne.

**Bon à savoir**

- Une réservation ordinaire d’un membre n’est jamais retenue pour approbation par ces préréglages. Ce qui attend, c’est une salle entière, des demi-journées supplémentaires, une suppression et l’adhésion.
- Un préréglage est un point de départ. N’augmentez un nombre que lorsque vous avez assez de personnes pour répondre.

**Voir aussi :** [Validations requises](help:user.validation.required-count) · [Un propriétaire est requis](help:user.validation.owner-required)

<!-- anchor: setup.people.stuck -->
### Éviter les demandes qui attendent pour toujours

**Public:** Propriétaire · Copropriétaire

Vous voulez être sûr que chaque demande pour laquelle vous créez une règle peut recevoir une réponse. Une règle qui demande plus de validateurs qu’il n’en existe n’est pas refusée partout : la demande est créée, personne ne peut la mener à bien, et elle expire au bout de sept jours.

> **Attention** L’éditeur compte un validateur de plus pour la personne concernée : il vous laisse donc enregistrer **Validations requises** à un de plus que les personnes dont vous disposez. Ce oui supplémentaire n’existe que pour une réservation qu’un administrateur a faite pour un membre, et pour certains paiements. Pour une adhésion ou une demande d’argent, il n’existe pas. Ne comptez pas sur l’éditeur pour compter à votre place.

*Comptez avant d’exiger*

| Vous exigez | Il vous faut, en plus de la personne qui demande |
|---|---|
| 1 | Un propriétaire ou un administrateur actif |
| 2 | Deux propriétaires ou administrateurs actifs |
| 2 avec **Le propriétaire doit toujours valider** | Un propriétaire et une personne de plus |
| Une liste **Personnes désignées** | Chaque personne de la liste doit être active ; un nouvel administrateur n’y est pas ajouté automatiquement |

*Comment vérifier*

1. Ouvrez [Règles de validation](app:/validation) et lisez chaque carte personnalisée : « Tous les admins — n’importe lesquels 2 » veut dire deux personnes.
2. Ouvrez [Membres et forfaits](app:/members). Comptez les propriétaires et administrateurs actifs. Les personnes en pause ou sorties ne comptent pas.
3. Ouvrez **Mise en place de cet espace** dans [Espace](app:/workspace-settings). Le domaine **Rôles et validation des demandes** dit « Une règle demande plus de validateurs que cet espace n’en compte » quand il en compte trop peu. Le domaine devient alors obligatoire, quel que soit le type de demande, et [Ce qui vous attend](help:user.collaborate.attention) le signale.
4. Ouvrez [Événements](app:/events). **En attente de votre confirmation** montre ce qui attend, et une ligne affiche « 1/2 validations ».

**Bon à savoir**

- L’éditeur lui-même dit **Pas assez de validateurs éligibles.** quand un nombre dépasse nettement les personnes disponibles. Il ne détecte pas tous les cas.
- Un propriétaire seul qui demande quelque chose pour lui-même attend quelqu’un d’autre : ajoutez un administrateur, ou activez **Le propriétaire peut valider le sien** sous **Validations enchaînées**.
- Mettre en pause ou retirer un administrateur peut laisser une règle à court de validateurs. Recomptez après chaque changement d’équipe.

**Résultat** Chaque règle peut recevoir une réponse de personnes qui existent.

**Voir aussi :** [Validations requises](help:user.validation.required-count) · [Rester cohérent](help:setup.consistent.overview)

<!-- anchor: setup.people.first-week -->
### La première semaine de vos membres

**Public:** Propriétaire · Administrateur·rice

Vous voulez que vos premiers membres s’en sortent sans vous solliciter. Ce que vous leur dites la première semaine détermine ce que vous aurez à répondre la deuxième.

*Avant d’inviter qui que ce soit*

1. Connectez-vous comme seconde personne avec un compte de test et rejoignez votre espace. Vérifiez que vous pouvez ouvrir le plan et réserver une place.
2. Approuvez ce compte comme membre, et faites approuver aussi le second validateur si vous en exigez deux.

**Étapes**

1. Envoyez le message d’invitation. Il explique comment télécharger l’application, créer un compte et rejoindre l’espace. Voir [Rejoindre un espace](help:user.start.join).
2. Approuvez chaque nouvelle personne le jour même. Quelqu’un qui attend une journée commence avec un doute.
3. Dites-leur les trois premières choses : le plan et la réservation ([Réserver une place](help:user.reserve.book)), l’enregistrement à l’arrivée ([S’enregistrer à l’arrivée et au départ](help:user.reserve.check-in)), et l’endroit où attendent leurs demandes ([Événements](help:user.collaborate.events)).
4. Dites-leur ce que vous voyez d’eux et ce qu’ils contrôlent ([Qui peut voir mes données](help:user.privacy.visibility)).
5. Désignez une personne à qui s’adresser, et où : la messagerie, ou l’accueil.

**Bon à savoir**

- Quand un administrateur fait quelque chose pour un membre, cela reste en attente jusqu’à ce que le membre confirme. Prévenez-les, sinon la première réservation que vous ferez pour quelqu’un aura l’air d’une erreur.
- Les membres qui n’utilisent pas les notifications push retrouvent tout sous **Événements**.
- À la première visite de Réserver, la carte **Premiers pas** montre aux propriétaires ce qui manque encore. Les membres ont leurs propres petites astuces. Voir [La carte Premiers pas et les astuces](help:user.start.get-started).

**Résultat** Des personnes qui savent réserver, s’enregistrer et à qui s’adresser.

**Voir aussi :** [De la semaine 0 à la semaine 4](help:setup.training.overview) · [Comment les membres sont informés](help:setup.notify.members)
