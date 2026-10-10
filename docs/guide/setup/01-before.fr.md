<!-- anchor: setup.before.overview -->
## Avant de commencer

Un peu de préparation vous épargne les deux choses qui coûtent le plus cher plus tard : ressaisir, et prendre des décisions qu’on ne peut plus défaire. Ce chapitre montre ce que fait DesKilo, ce dont vous avez vraiment besoin pour ouvrir, et ce qu’il faut avoir sous la main.

Dans ce chapitre :
- [Ce que sait faire DesKilo](help:setup.before.what)
- [Ce qui est nécessaire et ce qui est facultatif](help:setup.before.necessary)
- [Un espace de test ou un espace réel](help:setup.before.environment)
- [Partir d’un modèle ou de rien](help:setup.before.template)
- [Ce qu’il faut préparer](help:setup.before.prepare)
- [Les décisions difficiles à défaire](help:setup.before.permanent)
- [Qui fait quoi](help:setup.before.who)

<!-- anchor: setup.before.what -->
### Ce que sait faire DesKilo

**Public:** Propriétaire · Copropriétaire

Vous voulez une vue d’ensemble avant de choisir quoi que ce soit. DesKilo regroupe ses fonctionnalités en neuf processus ; l’écran **Fonctionnalités** montre une carte par processus, avec son état.

<p><img src="images/setup-before-processes.fr.jpg" width="280"></p>

*Les neuf processus, en mots simples*

| Processus | Ce que cela apporte à un membre |
|---|---|
| **Espace et accès** | Une porte d’entrée : rejoindre l’espace avec son ID, un rôle, un badge. |
| **Gestion des lieux** | Un lieu qui ressemble au vrai : étages, salles, bureaux, horaires d’ouverture. |
| **Réservations et utilisation** | Réserver un bureau ou une salle, s’enregistrer à l’arrivée et au départ, voir ce qui est libre. |
| **Calendrier et coordination** | Un calendrier, des messages et des demandes que quelqu’un confirme. |
| **Offres aux membres** | Une formule, des prix de services et des accords. |
| **Facturation et paiements** | Un relevé, des factures, le paiement, des relances, la TVA. |
| **Documents et informations** | Des documents à lire, des rapports à imprimer, ses propres données à exporter. |
| **Exploitation et administration** | Un espace qui porte ses propres couleurs et ses propres mots. |
| **Intégrations et automatisation** | Des notifications et des documents envoyés par des services extérieurs. |

**Bon à savoir**

- Un nouvel espace démarre avec un ensemble raisonnable de fonctionnalités activées ; vous n’avez pas à les décider une par une. Désactiver une fonctionnalité arrête seulement les nouvelles opérations et ne supprime rien.
- Une fonctionnalité qui en nécessite une autre l’active avec elle, et l’écran nomme ce qui s’est activé. Voir [Un interrupteur de fonctionnalité](help:user.features.switch).
- Les fonctionnalités marquées alpha ou bêta demandent votre consentement quand vous les activez.

**Voir aussi :** [Activer et désactiver des fonctionnalités](help:user.features.processes)

<!-- anchor: setup.before.necessary -->
### Ce qui est nécessaire et ce qui est facultatif

**Public:** Propriétaire · Copropriétaire · Administrateur·rice

Vous voulez connaître le chemin le plus court vers un espace que l’on peut réserver. L’application tient une liste de préparation, **Mise en place de cet espace**, et, sur l’écran Réserver, dit aux propriétaires ce qui manque : *Avant que quiconque puisse réserver ici*.

*Ce qui doit exister avant la première réservation*

1. **Jours d’ouverture, fuseau horaire et devise** : un fuseau horaire, une devise et au moins un jour de la semaine ouvert.
2. **Places réservables sur le plan** : au moins une place.
3. **Rôles et validation des demandes** : compté seulement quand une règle de validation, de quelque nature qu’elle soit, demande plus de validateurs que l’espace n’en a. Une règle qui exige deux approbations alors que vous êtes seul dans l’espace laisserait les demandes en attente pour toujours.
4. **Ce que les membres peuvent faire** : les membres détiennent **Réserver et utiliser les réservations**. Un nouvel espace ne leur accorde rien : un membre qui rejoint l’espace ne peut pas réserver tant que vous ne l’avez pas coché dans [Rôles](app:/roles).

Une ligne de plus, **Serveur et version de la base**, ne bloque que si le serveur est en retard sur cette application ; elle attend alors l’opérateur du serveur. Et tant que **Factures** est activé, **L'identité légale et l'adresse de l'espace** est obligatoire aussi : la liste la marque **Nécessaire avant de facturer**, car aucune facture ne peut être émise sans elle.

*Ce qui est facultatif et peut attendre*

- **Formules d’adhésion et tarifs**
- **Inviter les premiers membres**
- **Comment les membres paient**
- **Export et restauration**
- **Informations requises par vos fonctionnalités (identité, banque, plateformes)**
- **Une première réservation**

Chacune de ces étapes peut être mise de côté avec **Plus tard** et reprise ensuite ; la liste indique si une étape est **À configurer**, **Prêt**, **Sans objet ici** ou **En attente d’une autre personne**. Deux autres états existent : **Pas encore vérifié** (**Export et restauration** ne passe à Prêt qu’après un vrai export au cours des 90 derniers jours) et une ligne qui n’a pas pu être lue.

**Bon à savoir**

- La liste nomme qui agit : **Vous**, **L’opérateur du serveur** ou **Un administrateur de la base**.
- Facultatif ne veut pas dire sans importance : des coordonnées bancaires, un prestataire de paiement ou un site sont des informations requises par vos fonctionnalités, et la liste les nomme.
- Si vous activez la facturation sans identité légale, l’application vous laisse faire ; la liste et [Ce qui vous attend](help:user.collaborate.attention) la signalent, et l’émission d’une facture est refusée, en disant ce qui manque.

**Voir aussi :** [Vérifier votre espace](help:setup.place.check) · [La carte Premiers pas et les astuces](help:user.start.get-started)

<!-- anchor: setup.before.environment -->
### Un espace de test ou un espace réel

**Public:** Propriétaire · Copropriétaire · Opérateur·rice

Vous voulez essayer sans conséquence, puis faire tourner l’espace réel. Un espace peut être un test, un espace réel, ou une paire liée portant le même nom.

<p><img src="images/setup-before-environment.fr.jpg" width="280"></p>

| Option | À choisir quand | Ce qui se passe |
|---|---|---|
| **Un espace de test** | Vous apprenez. | Chaque écran et chaque document indique qu’il s’agit d’un test : les documents portent un filigrane. Aucune facturation réelle. |
| **Un espace réel** | Vous connaissez vos réglages. | Les factures qu’il émet sont dues. |
| **Une paire liée test et réel** | Vous voulez répéter les changements avant que les vrais membres les voient. | Deux espaces, tous deux à vous. Seul un déploiement fait passer la configuration de l’un à l’autre ; les membres, réservations, factures et paiements ne voyagent jamais. |

**Bon à savoir**

- Le sélecteur démarre sur l’option test.
- L’environnement est une déclaration du propriétaire ; toute personne ayant la permission de configuration (le propriétaire, toujours) peut le changer plus tard, et les factures déjà émises gardent le filigrane qu’elles portaient. En cas de doute, commencez donc par un espace de test.
- Pour vous exercer sans espace à vous, utilisez l’espace de démonstration.

**Voir aussi :** [Un espace a deux faces](help:user.advanced.environments) · [Créer un espace](help:user.start.create) · [Un espace de test](help:user.advanced.test-space)

<!-- anchor: setup.before.template -->
### Partir d’un modèle ou de rien

**Public:** Propriétaire

Vous voulez prendre de l’avance sans être enfermé dans les choix de quelqu’un d’autre. Quand vous créez un espace, **Partir de** propose **Espace vide** ou un modèle prêt à l’emploi, et préselectionne *A tiny space* ; choisissez *Espace vide* si vous voulez une page blanche.

<p><img src="images/setup-before-template.fr.jpg" width="280"></p>

*Les deux modèles fournis*

| Modèle | Ce qu’il met en place |
|---|---|
| A tiny space | Deux niveaux, quatre bureaux, huit places, rien d’autre : de quoi réserver, scanner et parcourir dès la première minute. |
| Association de coworking (France) | Demi-journées 7 h 00–13 h 00 et 13 h 00–19 h 00, du lundi au vendredi, jours fériés, adhésions à 50 % et à 100 %, deux carnets prépayés de demi-journées (10 et 20), rôles de bureau (trésorier, secrétaire, responsable de salle), un calendrier pour les validations et deux étages prêts à réserver. Il règle aussi la langue de l’espace sur le français et le régime de TVA sur *non assujetti à la TVA* ; seuls trois mots sont renommés (Place, Étage, Réservations). Le nom du modèle est français dans toutes les langues de l’application. |

**Bon à savoir**

- Un modèle ne contient jamais votre identité légale, vos coordonnées bancaires, vos sites, vos invitations ni vos liens de documents : ils vous appartiennent, et la liste de préparation les nomme (l’identité légale, quand **Factures** est activé, comme un domaine à part).
- Un espace créé depuis un modèle peut avoir la facturation activée et rien pour émettre tant que vous n’avez pas ajouté l’identité.
- Appliquer un modèle à un espace qui a déjà des tarifs remplace ses tranches de tarification : utilisez-le sur un nouvel espace.

**Voir aussi :** [Créer un espace](help:user.start.create)

<!-- anchor: setup.before.prepare -->
### Ce qu’il faut préparer

**Public:** Propriétaire

Vous voulez avoir les faits sous la main pour que la configuration prenne quelques minutes, pas quelques jours. Rassemblez d’abord ceci.

**Avant de commencer**

- [ ] L’**identité légale** : association ou société, dénomination, adresse, numéros d’immatriculation et de TVA si vous en avez.
- [ ] Un **comptable** (ou une personne qui confirmera les choix fiscaux) : les factures et la TVA sont ce qu’il faut faire vérifier par un professionnel.
- [ ] Une idée de tarif : gratuit, une adhésion forfaitaire, ou un pourcentage de jours avec une cotisation mensuelle.
- [ ] Les **coordonnées bancaires** vers lesquelles les membres paieront (IBAN et BIC, ou la méthode en usage dans votre pays).
- [ ] La liste des premières personnes : noms et adresses e-mail, et qui validera les demandes.
- [ ] Un croquis du plan : étages, salles, nombre de bureaux et de places, et la possibilité ou non de réserver une salle entière.
- [ ] Vos jours et horaires d’ouverture, et les jours de fermeture.

**Bon à savoir**

- Vous pouvez ouvrir sans l’identité légale ni les coordonnées bancaires ; il vous les faut avant la première facture.
- Faites d’abord le croquis sur papier. L’application dessine des étages, des salles, des bureaux et des places ; il est plus rapide de saisir un plan que vous avez déjà pensé.

**Voir aussi :** [Préparer un espace avec le questionnaire de configuration](help:user.start.questionnaire)

<!-- anchor: setup.before.permanent -->
### Les décisions difficiles à défaire

**Public:** Propriétaire · Copropriétaire

Vous voulez savoir sur quels choix prendre votre temps. La plupart des réglages peuvent changer n’importe quel jour. Ceux-ci ne le peuvent pas, ou pas proprement.

> **Attention** Une facture émise ne change jamais, et son numéro n’est jamais réutilisé. Si vous vous êtes trompé, vous corrigez par une annulation, un avoir ou une demande de remboursement, pas par une modification.

| Décision | Quand elle devient définitive | Que faire à la place |
|---|---|---|
| Format et séquence des numéros de facture | Le numéro suivant peut être augmenté, jamais diminué. Après la première facture, vous ne pouvez plus imprimer moins de la date que ne le montre la série. | Voir l’aperçu du format, consulter votre comptable, puis émettre. |
| Le mois d’une facture émise | Dès que le mois d’un membre est facturé, il est verrouillé ; les jours de fermeture et les imports de jours fériés l’ignorent. | Fixer les jours de fermeture avant la fin du mois. |
| Régime de TVA et taux | Les taux sont versionnés par date et jamais modifiés ; une déclaration de TVA transmise n’est jamais recalculée. | Ajouter un nouveau taux à partir d’une date ; décider du régime avec votre comptable. |
| Pays, devise, fuseau horaire | Les montants sont enregistrés comme des nombres, sans conversion. Dès que l’espace a émis un document ou enregistré de l’argent, le serveur refuse tout changement de devise ou de pays. Le fuseau horaire n’est jamais verrouillé, mais chaque jour y est compté. | Les choisir correctement dès le premier jour ; voir [Construire le lieu](help:setup.place.overview). |
| Remplacement du plan | L’import d’un plan est refusé dès que des réservations existent. | Modifier les étages et les salles un par un dans l’éditeur. |
| ID de l’espace | C’est ce que les membres saisissent et ce vers quoi pointent les QR codes imprimés. Vous pouvez le changer (4 à 20 lettres ou chiffres) avec **Changer l'ID de l'espace**, mais l’ancien ID cesse de fonctionner aussitôt. | Choisir un ID court et facile à retenir avant d’imprimer quoi que ce soit ; le changer tôt si nécessaire. |
| Test ou réel | Un espace réel émet des factures dues ; les documents de développement portent un filigrane. | Commencer dans un espace de test, déployer quand tout est prêt. |
| Une règle qui exige plus de validateurs que vous n’en avez | Les demandes attendent pour toujours. | Compter vos validateurs avant d’en exiger deux. |

**Bon à savoir**

- Désactiver une fonctionnalité n’efface jamais de données.
- Supprimer un étage supprime tous les bureaux, tables et places qui s’y trouvent.

**Voir aussi :** [Argent](help:setup.money.permanent)

<!-- anchor: setup.before.who -->
### Qui fait quoi

**Public:** Propriétaire · Copropriétaire · Administrateur·rice · Opérateur·rice

Vous voulez savoir qui appeler pour quoi. Trois personnes peuvent intervenir, et la liste de préparation les nomme.

| Qui | Ce qu’elle fait |
|---|---|
| **Propriétaire** (et *copropriétaire*) | Tout ce qui concerne l’espace : étages, horaires, fonctionnalités, rôles, tarifs, identité légale, invitations, déploiements. Les copropriétaires détiennent par défaut toutes les permissions ; le propriétaire décide de ce que les administrateurs peuvent faire. |
| *Opérateur* | Fait tourner l’installation : le serveur et ses secrets, et les mises à jour de la base. Nécessaire pour que les notifications push fonctionnent, et pour tout ce que la liste de préparation appelle **En attente d’une autre personne**. |
| *Administrateur de la base* | Approuve l’accès d’un membre pour les assistants. |

**Bon à savoir**

- Sur une installation partagée, l’opérateur est en général celui de la plateforme, pas vous.
- Les administrateurs agissent dans les limites des permissions que le propriétaire leur a données dans la [matrice des rôles](help:user.roles.matrix).
- Quand une section parle de **L’opérateur du serveur**, l’application ne peut pas le faire depuis votre écran.

**Voir aussi :** [Décider qui peut faire quoi](help:user.roles.matrix) · [Permissions de déploiement](help:user.advanced.deploy-permissions)
