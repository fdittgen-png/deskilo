<!-- anchor: user.advanced.overview -->
## Avancé

**Public:** Propriétaire · Opérateur·rice

Ce qui entoure le travail de tous les jours : le côté test d'un espace et le côté réel, les assistants, l'enregistreur de tâches et ses visites guidées, la démo, les applis sur chaque appareil, et que faire quand quelque chose ne fonctionne pas.

Dans ce chapitre :
- [Un espace a deux côtés](help:user.advanced.environments) · [Entrer d'un côté](help:user.advanced.enter-environment) · [Un espace de test](help:user.advanced.test-space) · [Qui peut déployer](help:user.advanced.deploy-permissions) · [Déployer entre les côtés](help:user.advanced.deploy) · [Situation de l'espace et archive de l'exercice](help:user.advanced.status-archive)
- [Votre propre serveur](help:user.advanced.own-server)
- [Les assistants](help:user.advanced.assistants) · [Connecter un assistant](help:user.advanced.assistants-connect) · [Les autorisations](help:user.advanced.assistants-approve) · [Ce que les assistants peuvent faire](help:user.advanced.assistants-policy)
- [L'enregistreur de tâches](help:user.advanced.recorder) · [Enregistrer une tâche](help:user.advanced.recorder-record) · [Relire un enregistrement](help:user.advanced.recorder-review) · [Créer un guide](help:user.advanced.guide-make) · [Suivre un guide](help:user.advanced.guide-play) · [Le menu rond](help:user.advanced.guide-circle) · [Modifier un guide](help:user.advanced.guide-edit) · [Confidentialité des enregistrements](help:user.advanced.recorder-privacy)
- [L'espace de démonstration](help:user.advanced.demo) · [Mode tournage](help:user.advanced.filming)
- [Les plateformes](help:user.advanced.platforms) · [Détails pour l'assistance](help:user.advanced.support) · [Quand quelque chose ne fonctionne pas](help:user.advanced.troubleshooting)
- [Les mots de l'app](help:user.advanced.glossary) · [Accessibilité et clavier](help:user.advanced.accessibility) · [Plus d'aide](help:user.advanced.help)

<!-- anchor: user.advanced.environments -->
### Un espace a deux côtés

**Public:** Propriétaire

Vous voulez un endroit pour essayer des choses sans toucher aux vraies réservations ni aux vraies factures. Un espace peut venir en paire : un côté test et un côté réel, avec le même nom.

<p><img src="images/user-advanced-environments.fr.jpg" width="280"></p>

**Étapes**

1. Quand vous créez un espace, laissez coché **Créer la paire développement et production**. Les deux côtés vous appartiennent dès la première seconde.
2. Vous avez déjà un espace seul ? Ouvrez [Réglages](app:/settings), allez à **Gouvernance** et touchez **Créer son jumeau**. La configuration est copiée une fois.
3. À partir de là, les deux côtés sont indépendants. Seul un déploiement fait passer quelque chose de l'un à l'autre.

**Bon à savoir**

- Le côté développement s'appelle **Développement — pour essayer**. Le côté production s'appelle **Production — les factures sont dues**.
- Tout document imprimé du côté développement porte un filigrane, pour qu'on ne le prenne pas pour un vrai.
- **Créer son jumeau** n'apparaît que lorsque la fonctionnalité **Paires d'environnements** est activée, et seulement pour le propriétaire. Le déploiement entre les côtés revient aux titulaires des droits de déploiement.
- Les membres, les réservations, les factures et les paiements ne sont jamais copiés d'un côté à l'autre.

**Voir aussi:** [Entrer d'un côté](help:user.advanced.enter-environment) · [Un espace de test](help:user.advanced.test-space)

<!-- anchor: user.advanced.enter-environment -->
### Entrer côté réel ou côté test

**Public:** Tout le monde

Vous voulez ouvrir un espace du côté dont vous avez besoin. Votre compte voit les deux côtés d'une paire, chacun avec son propre bouton.

**Étapes**

1. Ouvrez [Moi](app:/me) et repérez l'espace sous **Mes espaces**.
2. Touchez **Ouvrir l’espace** pour le côté réel, ou **Espace de test** pour le côté où s'entraîner.
3. Ou ouvrez [Profils](app:/profiles) : la paire forme une seule carte. Touchez-la, puis **Choisir un environnement** entre **DEV** et **PROD**.

**Bon à savoir**

- Un côté où vous n'avez pas le droit d'entrer est grisé et ne fait rien.
- Une personne membre du côté réel est toujours membre du côté test aussi.
- Le bouton de test porte l'indication « Espace de test : réservations et factures d’essai » ; le bouton réel « Réservations et factures réelles ».

**Voir aussi:** [Qui peut déployer](help:user.advanced.deploy-permissions)

<!-- anchor: user.advanced.test-space -->
### À quoi sert un espace de test

**Public:** Propriétaire

Vous allez changer des prix, des règles ou le plan et vous voulez d'abord voir l'effet. Faites-le sur l'espace de test.

**Étapes**

1. Entrez côté test avec **Espace de test**.
2. Configurez, importez un fichier d'espace, invitez un collègue, émettez une facture d'essai, déplacez des places, imprimez.
3. Quand c'est bon, [déployez-le côté réel](help:user.advanced.deploy).

**Bon à savoir**

- L'interrupteur **Type d’espace** dans [Réglages](app:/settings) (sous **Gouvernance**) indique de quel type est un espace. Seuls les propriétaires le voient.
- Déclarer un espace en production demande **Déclarer cet espace en production ?** — la bannière disparaît et les documents perdent leur filigrane. Les factures déjà émises gardent le filigrane qu'elles avaient.
- Ne déclarez la production que lorsque les factures qui quittent l'espace sont vraiment dues.
- Quand vous invitez quelqu'un, vous pouvez choisir s'il accède aussi à l'espace de production : **Espace de test** ou **Espace de production**. Dans les deux cas, il rejoint l'espace de test.

**Voir aussi:** [Un espace a deux côtés](help:user.advanced.environments)

<!-- anchor: user.advanced.deploy-permissions -->
### Qui peut déployer et entrer en production

**Public:** Propriétaire · Copropriétaire

Vous décidez qui peut toucher au côté réel. Trois permissions de la matrice des rôles en décident.

**Étapes**

1. Ouvrez [Rôles](app:/roles).
2. Repérez **Entrer dans l'espace de production**, **Déployer en développement** et **Déployer en production**.
3. Activez chacune pour les rôles qui en ont besoin.

**Bon à savoir**

- Les propriétaires et les copropriétaires détiennent les trois. Les administrateurs détiennent **Déployer en développement** et **Entrer dans l'espace de production**. Les membres n'en ont aucune tant que vous ne la leur donnez pas.
- Qui peut déployer en production peut toujours déployer en développement.
- Un rôle n'entre côté production que tant qu'il détient **Entrer dans l'espace de production** : une invitation ou une adhésion en production est refusée sinon, et l'app dit pourquoi.

**Voir aussi:** [La matrice des rôles](help:user.roles.matrix) · [Déployer entre les côtés](help:user.advanced.deploy)

<!-- anchor: user.advanced.deploy -->
### Déployer entre les deux côtés

**Public:** Propriétaire · Copropriétaire · Administrateur·rice

Vous avez stabilisé la configuration d'un côté et vous voulez que l'autre l'ait aussi.

**Étapes**

1. Placez-vous du côté que vous voulez écrire, et ouvrez [Réglages](app:/settings) → **Gouvernance** → [Déploiement](app:/deployment).
2. Cochez ce qui doit voyager. Les entités sont regroupées en **Configuration**, **Données de base** et **Rapports** ; ce dont une entité a **besoin** est coché avec elle.
3. Touchez **Tirer depuis la PROD…** (depuis le côté développement) ou **Tirer depuis la DEV…** (depuis le côté production).
4. Lisez l'aperçu : **Ce qui change côté production**, ou côté développement. Quand les deux côtés concordent, il indique **Aucun changement**.
5. Confirmez. La question nomme le côté qui est écrit : **Déployer dans cette DEV ?** ou **Déployer dans cette PROD ?**

**Bon à savoir**

- Un déploiement va toujours dans le côté où vous vous trouvez. Rien ne peut être poussé par erreur sur l'autre côté.
- Chaque déploiement est consigné dans le **Journal**. **Revenir en arrière** sur le dernier remet ce que le côté contenait avant.
- Les plans sont fusionnés : ce que seul ce côté possède est conservé, car une place peut porter une réservation. Les étiquettes de badge ne voyagent jamais.
- Les membres, les réservations, les factures, les paiements, les événements et les identifiants ne voyagent jamais.
- L'entrée n'apparaît que lorsque la fonctionnalité **Déploiements** est activée, que l'espace a un jumeau et que vous détenez une permission de déploiement.

**Voir aussi:** [Qui peut déployer](help:user.advanced.deploy-permissions)

<!-- anchor: user.advanced.status-archive -->
### Situation de l'espace et archive de l'exercice

**Public:** Propriétaire · Administrateur·rice · Administrateur·rice facturation

Vous voulez un coup d'œil sur ce que l'espace a facturé et encaissé, et un fichier complet de l'année pour vos archives.

**Étapes**

1. Ouvrez [Situation de l'espace](app:/money/status). Choisissez les mois dans **Du** et **Au**.
2. Lisez **Facturé**, **Avoirs**, **Paiements lettrés**, **Paiements reçus**, **Dépenses remboursées**, **Dépenses réparties** et **Crédits accordés** ; **Net** fait la synthèse. Touchez l'imprimante pour **Imprimer la situation**.
3. Pour le fichier annuel, choisissez **Archive de l'exercice (zip)** dans les exports de factures.

**Bon à savoir**

- **Net** n'est ni un bénéfice ni un solde bancaire. Les paiements lettrés et les paiements reçus se recoupent : ne les additionnez pas.
- La situation apparaît lorsque la fonctionnalité **Situation de l'espace** est activée.
- Un espace de développement produit des fichiers marqués DEV : ce ne sont pas les vrais livres.

**Voir aussi:** [Rapport de l'espace](help:user.workspace.export.workspace-report)

<!-- anchor: user.advanced.own-server -->
### Faire tourner votre propre serveur

**Public:** Opérateur·rice · Propriétaire

Vous voulez les données de votre communauté sur un serveur que vous maîtrisez, ou vous faites partie d'une organisation qui en gère un.

**Étapes**

1. Lisez comment un serveur est installé dans [Comment faire tourner le vôtre](help:user.backend.how).
2. Sur chaque appareil, pointez l'app vers lui : [Votre propre serveur](help:user.backend.server).
3. Vérifiez dans [Moi](app:/me) → **Où vivent mes espaces** : la liste indique les serveurs que ce compte utilise.

**Bon à savoir**

- L'app pointe vers un seul serveur pour la connexion ; **Cet appareil utilise** indique lequel. Les autres serveurs auxquels vous appartenez apparaissent sous **Où vivent mes espaces**.
- Une invitation n'est vérifiée que sur son propre serveur : rejoignez donc un espace pendant que l'app pointe vers le serveur qui l'a émise.
- Un opérateur peut activer les assistants pour toute l'installation — voir [Les autorisations](help:user.advanced.assistants-approve).

**Voir aussi:** [Votre propre serveur](help:user.backend.server)

<!-- anchor: user.advanced.assistants -->
### Les assistants : ce que c'est

**Public:** Tout le monde

Un assistant IA tel que Claude ou ChatGPT peut vérifier et réserver des choses pour vous dans DesKilo. Il agit en votre nom, uniquement dans les espaces et pour les actions que vous autorisez.

<p><img src="images/user-advanced-assistants-policy.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Assistants](app:/assistants). **Où vous en êtes ici** liste ce qui vous manque encore : **Connexion Google**, **Identité pour les assistants**, **Approbation de la base de données**, **Offre de l'espace de travail**, **Votre rôle**, **Votre consentement**, **Serveur**.
2. Descendez la liste ; chaque ligne dit qui fait l'étape suivante.

**Bon à savoir**

- Plusieurs personnes interviennent : vous, le propriétaire ou un administrateur de l'espace, un administrateur de la base et l'opérateur de l'installation. Personne ne peut tout ouvrir à lui seul.
- Activer les assistants n'accorde rien à personne par lui-même.
- Sous **Assistants connectés**, vous voyez ce qui est connecté et vous pouvez le **Déconnecter**. **Votre utilisation des assistants aujourd'hui** compte les **Demandes**, **Refusé**, **Appliquées** et **En attente de validation**.

**Voir aussi:** [Connecter un assistant](help:user.advanced.assistants-connect)

<!-- anchor: user.advanced.assistants-connect -->
### Connecter un assistant

**Public:** Membre · Administrateur·rice · Propriétaire

Vous voulez que votre assistant travaille avec vos propres réservations et votre compte.

**Étapes**

1. Ouvrez [Connecter un assistant](app:/assistants/connect). Sous **Avant de connecter**, chaque ligne doit indiquer **Fait**.
2. Sous **Quel assistant utilisez-vous ?**, choisissez **Claude**, **Claude Code**, **ChatGPT**, **Cursor**, **VS Code** ou **Autre**. Copiez-y **Votre adresse DesKilo pour les assistants** comme l'indiquent les étapes.
3. Connectez-vous quand l'assistant le demande, puis choisissez cet espace et ce que l'assistant peut y faire.
4. Touchez **Tester la connexion** et demandez à votre assistant : « Avec DesKilo, quelles sont mes réservations cette semaine ? »

**Bon à savoir**

- L'assistant lui-même vous demande d'approuver l'espace et chaque type d'opération ; rien n'est choisi à votre place.
- La connexion demande la fonctionnalité **Interface MCP** dans l'espace. Si elle est désactivée, l'écran vous renvoie vers Assistants.
- Ça ne marche pas ? **Tester la connexion** dit ce qu'elle attend encore.
- **Déconnecter** retire l'assistant de tous les espaces de cette base de données. Ce qu'il a déjà lu n'est pas repris.

**Voir aussi:** [Les autorisations](help:user.advanced.assistants-approve)

<!-- anchor: user.advanced.assistants-approve -->
### Autorisations et confirmations pour les assistants

**Public:** Propriétaire · Opérateur·rice

Les assistants sont autorisés par couches, pour qu'une personne ne puisse pas en activer un seule.

**Étapes**

1. Le propriétaire de l'espace (ou celui qui gère les intégrations) ouvre [Configuration des assistants](app:/settings/assistant-setup) et la descend : **Activer les assistants pour cet espace de travail**, **Choisir ce que les assistants peuvent faire**.
2. Chaque membre demande une fois : **Demander l'autorisation**. Un administrateur de la base décide dans [Autorisations des assistants](app:/database/assistant-approvals) avec **Approuver** ou **Rejeter**.
3. L'opérateur de l'installation ouvre [Installation : assistants](app:/installation/assistants) et touche **Activer pour tous les espaces**. La page liste aussi les **Administrateurs de la base** et les **Clients d'assistant**, chacun **Approuvé**, **Bloqué** ou **En attente d'approbation**.
4. Quand un assistant envoie une demande à fort impact, on vous demande : **Confirmer une demande d'assistant**. **Confirmer** lui laisse envoyer cette demande précise une seule fois ; **Refuser** ne fait rien.

**Bon à savoir**

- Les autorisations et les modifications de l'installation demandent votre second facteur.
- L'autorisation expire ; l'écran indique les jours restants et vous la demandez à nouveau.
- Une demande confirmée suit toujours les règles de validation de l'espace.
- Sans autre administrateur de la base, l'opérateur autorise l'accès, avec un motif, pour 30 jours au plus.

**Voir aussi:** [Ce que les assistants peuvent faire](help:user.advanced.assistants-policy)

<!-- anchor: user.advanced.assistants-policy -->
### Ce que les assistants peuvent faire dans un espace

**Public:** Propriétaire · Administrateur·rice

Vous décidez quels services un espace propose aux assistants.

**Étapes**

1. Ouvrez [Accès des assistants](app:/settings/assistants).
2. Activez **Proposer les services d'assistant**.
3. Sous **Données sur lesquelles un assistant peut agir**, choisissez **Ses propres données** ou **Tout l'espace**.
4. Cochez les opérations, par groupes : **Réservations et compte personnels**, **Demandes financières**, **Demandes d'adhésion**, **Validations**.
5. Touchez **Enregistrer**.

**Bon à savoir**

- Les opérations se lisent comme « Voir les places libres », « Réserver une place pour vous », « Vous enregistrer à l'arrivée » ou « Annuler vos réservations qui n'ont pas commencé ».
- Les assistants reçoivent des réponses réduites au minimum. **Détails facultatifs** permet d'en autoriser davantage ; chaque personne choisit tout de même pour elle-même.
- Les assistants déjà connectés ne reçoivent de nouveaux services que lorsque chaque personne approuve à nouveau.
- Activez d'abord la fonctionnalité **Interface MCP** dans [Fonctionnalités](app:/features). Elle est désactivée par défaut.
- C'est réservé aux personnes qui détiennent la permission d'intégrations ; les propriétaires l'ont toujours.

**Voir aussi:** [Un interrupteur de fonctionnalité](help:user.features.switch)

<!-- anchor: user.advanced.recorder -->
### L'enregistreur de tâches et les visites guidées

**Public:** Tout le monde

Vous voulez montrer à quelqu'un comment se fait une tâche, ou qu'on vous la montre. Enregistrez la tâche une fois, transformez-la en guide et suivez-la pas à pas sur la vraie app.

<p><img src="images/user-advanced-wizard.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez l'[Assistant de tâches](app:/task-wizard) : dans le menu sur un grand écran, ou sous **Avancé** dans [Moi](app:/me).
2. **Guides** contient vos propres guides et ceux qui viennent avec l'app, comme **Réserver une place**.
3. **Enregistrements** liste les tâches que vous avez enregistrées, et **Enregistrer une tâche** en commence une nouvelle.
4. **Outils** ouvre un fichier de tâche sans compte.

**Bon à savoir**

- Tout reste sur votre appareil jusqu'à ce que vous l'exportiez.
- L'enregistreur de tâches est une fonctionnalité (**Enregistreur de tâches**). Quand elle est désactivée, l'assistant de tâches n'apparaît pas dans les menus.
- Vous devez être connecté pour enregistrer ou suivre un guide.

**Voir aussi:** [Enregistrer une tâche](help:user.advanced.recorder-record) · [Suivre un guide](help:user.advanced.guide-play)

<!-- anchor: user.advanced.recorder-record -->
### Enregistrer une tâche

**Public:** Tout le monde

Vous voulez garder la trace de ce que vous faites, pour en tirer un document ou un guide.

<p><img src="images/user-advanced-record.fr.jpg" width="280"></p>

**Étapes**

1. Dans l'[Enregistreur de tâches](app:/task-recorder), lisez **Avant d'enregistrer**.
2. Touchez **Commencer l'enregistrement**.
3. Faites la tâche comme d'habitude, sur n'importe quel écran de l'espace ou de [Moi](app:/me).
4. Utilisez la barre qui affiche **Enregistrement en cours** pour **Pause**, **Reprendre**, **Ajouter une note** ou **Arrêter**.

**Bon à savoir**

- Un enregistrement dure jusqu'à 500 étapes ou 30 minutes, et il est supprimé de l'appareil après 30 jours. Un fichier que vous avez exporté reste là où vous l'avez enregistré.
- Chaque étape nomme l'écran, l'action et ce que l'app a répondu, comme **Réservé** ou **Refusé**.
- La connexion, le paiement, les messages et les autres écrans protégés ne laissent qu'un repère.
- Si vous passez à un autre compte ou à un autre espace, l'enregistrement s'arrête.

**Voir aussi:** [Confidentialité des enregistrements](help:user.advanced.recorder-privacy)

<!-- anchor: user.advanced.recorder-review -->
### Relire, modifier et exporter un enregistrement

**Public:** Tout le monde

Vous voulez vérifier ce qui a été capturé avant de le partager.

**Étapes**

1. Dans l'[Assistant de tâches](app:/task-wizard), touchez un enregistrement sous **Enregistrements**.
2. Lisez les étapes. Touchez **Exclure de l'export** sur toute étape dont vous ne voulez pas ; **Remettre** la rétablit.
3. Regardez **Ce que le fichier contiendra**.
4. Choisissez **Exporter un fichier**, **Exporter un paquet de tâche** ou **Exporter en document Word**.

**Bon à savoir**

- Exclure une étape ne change que l'export. L'enregistrement sur l'appareil reste inchangé.
- Pour lire un fichier venant de quelqu'un d'autre, utilisez **Ouvrir un fichier de tâche** dans l'[Atelier de tâches](app:/task-workbench). Rien n'est envoyé, et aucun compte n'est nécessaire.
- Un fichier abîmé, ou créé par une version plus récente, est refusé avec un message clair.
- **Supprimer de cet appareil** supprime l'enregistrement ; les fichiers exportés ne sont pas touchés.

**Voir aussi:** [Créer un guide](help:user.advanced.guide-make)

<!-- anchor: user.advanced.guide-make -->
### Créer un guide à partir d'un enregistrement

**Public:** Tout le monde

Vous voulez que d'autres suivent une tâche que vous avez enregistrée.

**Étapes**

1. Dans l'[Assistant de tâches](app:/task-wizard), touchez **Créer un guide** à côté d'un enregistrement. Ou choisissez **Ajouter un guide** → **À partir d'un de mes enregistrements** ou **À partir d'un fichier ou paquet de tâche**.
2. Vérifiez le brouillon. Chaque étape est écrite comme le lecteur la verra.
3. Donnez-lui un nom sous **Nom du guide**.
4. Touchez **Ajouter à mes guides**.

**Bon à savoir**

- Le guide est conservé sur votre appareil sous **Guides**. Un guide peut être modifié ou supprimé : **Supprimer ce guide** ne touche pas à son enregistrement.
- Une étape qui réserve attend la vraie réponse. Rien n'est fait à la place du lecteur.
- **Enregistrer le guide** l'écrit dans un fichier que vous pouvez transmettre.

**Voir aussi:** [Modifier un guide](help:user.advanced.guide-edit)

<!-- anchor: user.advanced.guide-play -->
### Suivre un guide

**Public:** Tout le monde

Vous voulez être guidé dans une tâche sur les vrais écrans.

**Étapes**

1. Dans l'[Assistant de tâches](app:/task-wizard), touchez **Lancer le guide** à côté de l'un des guides.
2. Un panneau affiche Étape 1 sur … et ce qu'il faut faire, par exemple « Touchez « Réserver ». » ou « Remplissez « … », puis quittez le champ. »
3. Touchez **Ouvrir et mettre en évidence** pour aller au bon écran et voir le contrôle repéré.
4. Faites l'étape vous-même. Le guide s'en aperçoit et passe à la suivante. Pour une étape de lecture, touchez **Fait**.

**Bon à savoir**

- Utilisez **Retour** et **Passer**, et ouvrez **Toutes les étapes** pour voir chacune comme **À faire**, **En attente**, **Fait**, **Pris en compte** ou **Passé**.
- Une étape qui réserve attend la réponse : **En attente du résultat…**. Si elle est refusée, le guide dit quoi essayer ; si aucune réponse n'est venue, il vous demande de vérifier avant de réessayer.
- **Arrêter le guide** y met fin. Rien n'est annulé.
- Le guide se met en pause quand le compte ou l'espace change, ou quand l'enregistreur de tâches est désactivé.

**Voir aussi:** [Le menu rond](help:user.advanced.guide-circle)

<!-- anchor: user.advanced.guide-circle -->
### Le menu rond

**Public:** Tout le monde

Vous avez besoin de tout l'écran pour travailler, mais vous voulez garder le guide à portée de main. Réduisez-le.

**Étapes**

1. Dans le panneau du guide, touchez **Réduire le guide**. Il se réduit en un petit rond.
2. Touchez le rond pour un menu : Afficher le guide (étape … sur …), **Ouvrir et mettre en évidence**, un bouton vers la page de l'étape, **Fait**, **Passer**, **Retour**, **Reprendre** et **Arrêter le guide**.
3. Choisissez **Afficher le guide** pour rouvrir le panneau.

**Bon à savoir**

- Le menu ne propose que ce qui a du sens maintenant : **Reprendre** seulement pendant une pause, **Fait** seulement pour une étape de lecture.
- **Fermer** sur le panneau le masque ; le guide lui-même reste où il en était.
- Ouvrir et mettre en évidence vous emmène à la page de l'étape et désigne le contrôle ; le bouton de page vous emmène à la page seulement.

**Voir aussi:** [Suivre un guide](help:user.advanced.guide-play)

<!-- anchor: user.advanced.guide-edit -->
### Modifier ou réparer un guide

**Public:** Tout le monde

Un guide se lit mal, ou une étape pointe vers la mauvaise page. Corrigez-le dans le brouillon.

**Étapes**

1. Dans l'[Assistant de tâches](app:/task-wizard), touchez **Modifier** à côté de votre guide.
2. Sur une étape, touchez **Écrire le texte** et saisissez votre propre texte.
3. Sous **Destination de l’étape**, choisissez la page à laquelle l'étape renvoie. Touchez **Ouvrir et mettre en évidence** pour vérifier.
4. Activez **Le lecteur peut la passer** pour une étape facultative.
5. Touchez **Enregistrer les modifications**.

**Bon à savoir**

- Une étape marquée **Une instruction encore à écrire** attend vos mots. **Une étape que l'enregistreur ne sait pas décrire** et **Faites cette étape vous-même** sont faites par le lecteur.
- Les étapes sur des écrans protégés, comme le paiement, demandent au lecteur de les faire seul.
- Vous ne pouvez pas faire attendre à un guide un résultat que son action n'a pas ; cette partie est fixée.
- Un guide qui nomme des étapes que cette version ne connaît pas peut être lu, mais pas suivi.

**Voir aussi:** [Créer un guide](help:user.advanced.guide-make)

<!-- anchor: user.advanced.recorder-privacy -->
### Ce qu'un enregistrement conserve

**Public:** Tout le monde

Vous voulez savoir exactement ce qui ne laisse aucune trace.

**Étapes**

1. Ouvrez l'[Enregistreur de tâches](app:/task-recorder).
2. Lisez **Avant d'enregistrer**.
3. Laissez **Enregistrer les valeurs (pour un rapport de problème)** désactivé, sauf si un développeur vous l'a demandé.

**Bon à savoir**

- Normalement, un enregistrement ne conserve jamais ce que vous saisissez, ni les noms, montants, messages, codes ou mots de passe.
- Avec les valeurs activées, il conserve aussi ce que vous saisissez et choisissez, pour qu'un développeur puisse reproduire un problème. Les mots de passe, les données de paiement, les adresses e-mail et les numéros de téléphone ne sont toujours jamais conservés. L'exporter demande **Cet enregistrement contient des valeurs**.
- Rien n'est envoyé : vous décidez de ce que vous exportez.
- Ne partagez un fichier qu'avec des personnes qui peuvent voir ce que vous avez saisi.

**Voir aussi:** [Enregistrer une tâche](help:user.advanced.recorder-record)

<!-- anchor: user.advanced.demo -->
### L'espace de démonstration

**Public:** Tout le monde

Vous voulez regarder autour de vous avant de vous engager. La démo est un espace inventé, ouvert à tous, sans compte.

**Étapes**

1. Sur l'écran de connexion, touchez **Explorer l'espace de démonstration**.
2. Lisez la courte note, puis touchez **Commencer**.
3. Utilisez **Voir en tant que** pour voir le même espace comme **Le propriétaire**, **Un administrateur** ou **Un membre**.
4. Touchez **Réinitialiser la démo** pour la remettre comme au départ, ou **Quitter la démo**.

**Bon à savoir**

- Tout est inventé : les personnes, les réservations et les factures. Rien n'atteint un vrai espace et rien ne quitte votre appareil.
- Une bannière indique **Démo** sur chaque écran.
- Fermer l'app oublie la session.
- L'offre n'apparaît que lorsque la fonctionnalité **L'espace de démonstration** est activée.

**Voir aussi:** [Mode tournage](help:user.advanced.filming)

<!-- anchor: user.advanced.filming -->
### Mode tournage

**Public:** Propriétaire

Vous devez montrer votre vrai espace — dans une vidéo, une image ou une présentation — sans montrer ses membres.

**Étapes**

1. Ouvrez [Fonctionnalités](app:/features) et cherchez **Mode tournage**.
2. Activez-le. Une bannière indique **Mode tournage — personnes inventées** sur chaque écran.
3. Filmez. Quand vous avez fini, désactivez-le.

**Bon à savoir**

- Chaque nom, e-mail, numéro de téléphone, adresse et photographie devient une personne inventée, la même partout. Le plan, les réservations et les chiffres restent réels.
- Tant qu'il est activé, les formulaires d'identité refusent d'enregistrer, pour que des données inventées ne puissent pas écraser les vraies.
- Il ne peut pas masquer ce que quelqu'un a saisi, comme un message ou le libellé d'une place. Relisez l'écran avant de filmer.
- Pour une image qui n'a pas besoin de montrer cet espace, utilisez [la démo](help:user.advanced.demo).

**Voir aussi:** [Un interrupteur de fonctionnalité](help:user.features.switch)

<!-- anchor: user.advanced.platforms -->
### DesKilo sur vos appareils

**Public:** Tout le monde

Vous voulez utiliser DesKilo là où vous travaillez. Le même compte et les mêmes données vous suivent.

**Étapes**

1. **Android :** rejoignez le test fermé sur Google Play.
2. iPhone et iPad : rejoignez la bêta via TestFlight.
3. **Ordinateur :** une image disque macOS ou un installateur Windows depuis la page des versions ; ou ouvrez simplement l'app web.
4. **Navigateur :** ouvrez l'adresse que publie votre espace. Rien à installer.

**Bon à savoir**

- Une place réservée sur un téléphone apparaît un instant plus tard dans un onglet du navigateur.
- L'image disque macOS de la page des versions est signée et notariée par Apple ; ouvrez-la normalement.
- L'installateur Windows n'est pas signé : Windows SmartScreen signale un éditeur inconnu ; choisissez Informations complémentaires, puis Exécuter quand même.
- La lecture d'une étiquette de chaise fonctionne dans les navigateurs Chromium sur Android (HTTPS et un toucher nécessaires) ; les apps Android et iPhone lisent directement les étiquettes.
- Une version sans services Google, sans notifications push dans le cloud, est construite et a été soumise à F-Droid ; elle n'est pas encore dans le catalogue F-Droid. Sur cette version, les notifications sont locales et la boîte de réception fait foi.
- Les mises à jour arrivent par le canal depuis lequel vous avez installé l'app : Google Play, TestFlight, la page des versions, ou en rechargeant l'app web.

**Voir aussi:** [Votre badge](help:user.profile.settings.badge)

<!-- anchor: user.advanced.support -->
### Détails pour l'assistance

**Public:** Tout le monde

Vous contactez l'assistance et vous voulez envoyer ce qui l'aide, sans rien exposer de privé.

<p><img src="images/user-advanced-support.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Aide](app:/help) et touchez l'icône d'assistance (**Détails pour l’assistance**).
2. Choisissez **Dernière heure** ou **Dernières 24 heures**.
3. Touchez **Préparer l’aperçu** et lisez ce qu'il contient : Aperçu : … octets.
4. Touchez **Enregistrer**, puis envoyez le fichier.

**Bon à savoir**

- Seuls des comptages d'événements bornés et des vérifications connues sont inclus. Les identités, les adresses de serveur, les identifiants, les données métier et les journaux bruts sont exclus.
- Un fichier partagé ne peut pas être révoqué.
- Si le contexte a changé, l'écran vous demande de préparer un nouvel aperçu.
- Un opérateur peut lancer `doctor --support-json` pour le côté serveur.

**Voir aussi:** [Quand quelque chose ne fonctionne pas](help:user.advanced.troubleshooting)

<!-- anchor: user.advanced.troubleshooting -->
### Quand quelque chose ne fonctionne pas

**Public:** Tout le monde

Quelque chose semble anormal. Essayez ceci, dans l'ordre.

**Étapes**

1. Cherchez un message à l'écran ; la plupart disent quoi faire. « Une erreur est survenue. Veuillez réessayer. » mérite un nouvel essai.
2. Vérifiez que vous êtes du côté que vous croyez : **Espace de test** ou **Ouvrir l’espace** dans [Moi](app:/me).
3. Vérifiez [Fonctionnalités](app:/features) : une fonction absente du menu est généralement une fonctionnalité désactivée. Seul un propriétaire peut la changer.
4. Vérifiez le serveur sous [Votre propre serveur](help:user.backend.server) : **Cet appareil utilise** le nomme.
5. Préparez les [Détails pour l'assistance](help:user.advanced.support) et envoyez-les.

**Bon à savoir**

- Ce que vous voyez dépend de votre rôle : un écran absent peut être une question de permission. Demandez à votre propriétaire.
- Les administrateurs peuvent activer le **Mode développeur** sous **Avancé** dans [Réglages](app:/settings). Il ajoute un écran [Développeur](app:/developer) où **Exporter le journal** et **Vider le journal** aident l'assistance. Il s'applique à tous les membres de l'espace.
- Vous pouvez aussi signaler un bug depuis la section À propos de l'app : **Signaler un bug / suggérer une fonctionnalité**.
- Un guide bloqué sur **En attente du résultat…** signifie qu'aucune réponse n'est arrivée : vérifiez le résultat avant de réessayer.

**Voir aussi:** [Détails pour l'assistance](help:user.advanced.support)

<!-- anchor: user.advanced.glossary -->
### Les mots de l'app

**Public:** Tout le monde

Les mots que vous rencontrez le plus, et ce qu'ils signifient ici.

| Mot | Ce que cela signifie |
|---|---|
| **Espace** (aussi appelé espace de travail) | Un lieu géré par une communauté : son plan, ses membres, ses règles et son argent. Vous pouvez en rejoindre plusieurs. |
| **Moi** | Votre propre compte : profil, messages, espaces et réglages, dans tous vos espaces. |
| **Plan** | Soit le plan au sol à partir duquel vous réservez, soit une formule d'adhésion — voir **Membres et forfaits**. |
| **Niveau** | Un étage ou une zone du plan. Un niveau peut être réservé en entier quand la fonctionnalité est activée. |
| **Table** | Une place réservable. Les bureaux et les salles regroupent des tables. |
| Demi-journée | L'unité dans laquelle les réservations et les abonnements sont comptés. |
| **Validation** | Une règle qui dit qu'une action demande une ou plusieurs confirmations avant de compter. |
| **Événements** | Le fil de ce qui s'est passé, avec en haut les décisions qui vous attendent. |
| **Borne** | Une tablette partagée à la porte où les personnes s'enregistrent avec un badge. |
| Fonctionnalité | Une fonction que le propriétaire active ou désactive pour tout l'espace. |
| **Rôle** | Ce qu'une personne peut faire dans un espace. Les permissions se règlent par rôle. |
| **Environnement** | Le côté développement (test) ou le côté production (réel) d'un espace. |
| Jumeau | L'autre côté d'une paire. |
| **Déploiement** | Faire passer la configuration d'un côté d'une paire à l'autre. |
| **Assistant** | Un outil d'IA connecté à votre compte, qui n'agit que comme vous l'autorisez. |
| Opérateur·rice | La personne qui fait tourner l'installation avec laquelle l'app communique. |

**Bon à savoir**

- Les propriétaires peuvent changer les mots qu'un espace utilise sous **Vocabulaire** ; l'app affiche alors ceux de l'espace.

**Voir aussi:** [Vocabulaire](help:user.workspace.settings.wording)

<!-- anchor: user.advanced.accessibility -->
### Accessibilité et clavier

**Public:** Tout le monde

Vous voulez que l'app s'adapte à votre façon de travailler.

**Étapes**

1. Choisissez un aspect sous [Réglages](app:/settings) : **Thème**, **Langue**, **Nombres et dates**.
2. Pour des écrans plus calmes, activez le réglage de réduction des animations de votre appareil.
3. Sur un ordinateur, appuyez sur Échap dans un assistant pour revenir en arrière.

**Bon à savoir**

- Le réglage de réduction des animations de l'appareil l'emporte toujours sur la fonctionnalité **Animations de l'interface** ; un propriétaire peut aussi désactiver cette fonctionnalité.
- Quitter un assistant avec des modifications non enregistrées demande d'abord confirmation : **Continuer** ou **Abandonner**.
- Les commandes portent des libellés textuels, afin qu'un lecteur d'écran les annonce.
- Sur le web et sur un ordinateur, une fenêtre large affiche le menu à côté du contenu.

**Voir aussi:** [Thème](help:user.profile.settings.theme) · [Langue de l'application](help:user.profile.settings.language)

<!-- anchor: user.advanced.help -->
### Où trouver plus d'aide

**Public:** Tout le monde

Vous êtes bloqué sur un champ ou sur un écran.

**Étapes**

1. Touchez le **?** à côté d'un champ : le guide s'ouvre sur ce champ.
2. Ouvrez [Aide](app:/help) pour tout le guide ; **Sommaire** saute à un chapitre.
3. Les astuces d'un écran peuvent être écartées avec **Masquer l'astuce** ; **Astuce suivante** et **Astuce précédente** les font défiler, **En savoir plus** ouvre le guide.
4. Pour revoir les astuces écartées, utilisez **Réafficher les astuces d'aide** dans vos réglages.

**Bon à savoir**

- Le guide fonctionne hors ligne, dans votre langue.
- Votre administrateur peut répondre aux questions sur votre espace ; les Détails pour l'assistance aident quand il s'agit de l'app.

**Voir aussi:** [Réafficher les astuces](help:user.profile.settings.restore-hints) · [Détails pour l'assistance](help:user.advanced.support)
