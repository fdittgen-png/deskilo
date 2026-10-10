<!-- anchor: setup.notify.overview -->
## Informer les gens

Ce chapitre s'adresse à vous qui voulez que les membres et les administrateurs soient informés de ce qui compte, et de cela seulement. Il décrit ce que DesKilo envoie réellement, qui le reçoit, ce que vous configurez et ce que vous laissez à l'opérateur de l'installation.

Dans ce chapitre :
- Les canaux, en mots simples
- Un tableau : ce qui se passe, qui est prévenu, par quel canal, ce qu'un membre peut modifier
- Ce que vous configurez, et ce que l'opérateur doit faire pour le push
- Un plan de test avec deux comptes
- Comment éviter à la fois la surcharge et le silence

<!-- anchor: setup.notify.channels -->
### Les canaux, en mots simples

**Public:** Propriétaire · Administrateur·rice

Vous voulez une image claire des moyens dont DesKilo dispose pour joindre une personne, avant de rien promettre à vos membres.

<p><img src="images/setup-notify-features.fr.jpg" width="280"></p>

**Avant de commencer**

Il existe six moyens, et ils ne se valent pas. L'essentiel se passe dans l'app.

| Canal | De quoi il s'agit | Ce qu'il faut |
|---|---|---|
| Le fil d'événements et la cloche | Tout ce qui se passe dans l'espace est écrit dans un fil. La cloche compte les nouveautés et les décisions qui vous attendent. | **Onglet Événements** ; **Regroupement des notifications** est une option en plus |
| Les messages | Des conversations privées et de groupe entre membres, avec accusés de lecture et liens vers une réservation ou un espace. | **Notifications entre membres** |
| Le push | Une courte notification sur un téléphone ou un ordinateur, même quand l'app est fermée. Le texte est générique : ni noms, ni horaires. | **Notifications push** activées, et une configuration du push par l'opérateur ; voir [la part de l'opérateur](help:setup.notify.operator) |
| Le rappel d'enregistrement | Une notification sur l'appareil du membre, 15 minutes avant une réservation pour laquelle il ne s'est pas encore enregistré. | L'autorisation du système pour le membre. Absent de la version navigateur. |
| Les relances de paiement | Une alerte dans le fil et un push au membre dont une facture est en retard. | **Relances de paiement** et **Relances de paiement automatiques** ; voir [Relances de paiement](help:setup.money.reminders) |
| WhatsApp | Un lien de groupe que vous publiez, et le numéro WhatsApp qu'un membre choisit de partager. L'app ouvre WhatsApp ; rien n'est envoyé depuis le serveur. | **Intégration WhatsApp** |

**Bon à savoir**

- DesKilo n'envoie aucun e-mail de lui-même en dehors des e-mails de compte (confirmation d'inscription, réinitialisation du mot de passe). Les invitations sont des textes que vous partagez depuis votre propre téléphone.
- Il n'y a pas d'abonnement par événement : un membre ne peut pas choisir « prévenez-moi des notes de frais mais pas des réservations ».
- Une notification peut être retardée ou perdue, comme tout push ; le fil et la liste des messages font foi.

**Voir aussi:** [Notifications](help:user.collaborate.notifications) · [Événements et confirmations](help:user.collaborate.events)

<!-- anchor: setup.notify.table -->
### Qui est prévenu de quoi

**Public:** Propriétaire · Administrateur·rice

Vous voulez savoir, événement par événement, qui est prévenu et comment.

<p><img src="images/setup-notify-events.fr.jpg" width="280"></p>

**Avant de commencer**

Le push n'est envoyé que pour les cinq lignes marquées « push » ci-dessous. Tout autre événement (une réservation faite, un paiement enregistré, l'arrivée d'un membre) apparaît dans le fil, et nulle part ailleurs.

| Source | Événement | Qui est prévenu | Canal | Ce que le membre peut modifier |
|---|---|---|---|---|
| Règles de validation | Une demande attend une confirmation | Les personnes que la règle désigne (fil, **En attente de votre confirmation**) ; le push va seulement au membre concerné par la demande, jamais à celui qui l'a faite, donc les validateurs ne reçoivent un push que s'ils sont ce membre. Texte : « Quelqu'un attend votre confirmation. » | Fil, cloche ; push | Désactiver le push sur l'appareil |
| Réservations | Un administrateur supprime ou écrase une réservation | Le membre déplacé, et chaque administrateur et propriétaire actif sauf celui qui a agi. Texte : « Une réservation a été retirée par un admin. » | Fil ; push | Désactiver le push sur l'appareil |
| Relances de paiement | Une facture a dépassé son échéance et un niveau de relance arrive à terme | Le membre concerné par la facture. La facture d'un propriétaire revient au propriétaire. Texte : « Une relance de paiement vous attend. » | Alerte dans le fil ; push | Désactiver le push sur l'appareil |
| Notifications entre membres | Un nouveau message | Message direct : le destinataire. Groupe : les participants sauf l'expéditeur. Une conversation mise en sourdine par un membre reste silencieuse pour lui. Texte : « Vous avez un nouveau message. » | Messages, cloche ; push | Couper, épingler ou archiver une conversation ; désactiver le push |
| Mentions dans les messages | Un message de groupe nomme quelqu'un | Les personnes nommées, même dans une conversation en sourdine. Texte : « Vous avez été mentionné·e dans une conversation. » | Messages ; push | Désactiver le push |
| Réservations | Une réservation approche | Le membre qui a réservé, sur son propre appareil, 15 minutes avant le début, pour les réservations des sept jours à venir | Notification locale | Refuser l'autorisation du système |
| Intégration WhatsApp | Rien n'est envoyé | Le lien du groupe s'affiche dans l'annuaire ; un membre peut partager son numéro | Ouvre WhatsApp | Partager ou masquer le numéro |

**Bon à savoir**

- Quand l'app est ouverte, le push d'une réservation retirée est remplacé par une notification dans la langue du membre. Pour les messages, les mentions, les confirmations et les relances de paiement, l'app ouverte affiche pour l'instant son texte générique (« Quelqu'un attend votre confirmation. »). Les textes génériques en anglais du serveur apparaissent quand l'app est en arrière-plan ou fermée.
- Un administrateur n'est prévenu que de ce sur quoi il agit ou de ce qu'une règle lui confie ; il n'existe pas de résumé « tout ».
- Les membres voient leurs propres événements ; les administrateurs et les propriétaires voient ceux de tout le monde.

**Voir aussi:** [Règles de validation](help:user.validation.overview) · [Messages](help:user.collaborate.messages)

<!-- anchor: setup.notify.configure -->
### Ce que vous configurez

**Public:** Propriétaire

Vous décidez lesquels de ces canaux existent dans votre espace, et à qui l'on demande de décider quoi.

<p><img src="images/setup-notify-validation.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Fonctionnalités](help:user.features.switch) et vérifiez les interrupteurs de notification : **Notifications push**, **Notifications entre membres**, **Onglet Événements**, **Regroupement des notifications**, **Relances de paiement**, **Relances de paiement automatiques** et **Intégration WhatsApp**.
2. Réglez les [règles de validation](help:user.validation.overview) : pour chaque type de demande, combien de validations sont requises et qui peut les donner. Cela décide qui est sollicité, et donc qui voit une décision en attente.
3. Décidez si la demande d'un administrateur ou d'un propriétaire se règle d'elle-même ; voir [Valider automatiquement la demande d'un administrateur](help:user.validation.auto-validate-admin) et [Valider automatiquement la demande d'un propriétaire](help:user.validation.auto-validate-owner). Une demande déjà réglée ne prévient personne.
4. Rédigez le message d'invitation que reçoivent les membres, et collez le lien du groupe de la communauté ; voir [Message d'invitation](help:user.workspace.settings.invitation-message) et [Groupe WhatsApp](help:user.workspace.settings.whatsapp-group).
5. Activez **Demandes de suppression de réservation** si les membres peuvent demander à supprimer une réservation passée ou déjà enregistrée : quelqu'un devra alors répondre.

**Bon à savoir**

- Réglages par défaut d'un nouvel espace : l'onglet événements, les notifications entre membres et le regroupement sont activés ; **Relances de paiement** et **Relances de paiement automatiques** sont activées comme fonctions, mais aucune relance n'est envoyée tant que vous n'activez pas **Relances automatiques** dans les règles de relance.
- **Notifications push** est activé par défaut, mais ne livre rien tant que l'opérateur ne l'a pas configuré.
- Désactiver une fonction arrête les nouvelles activités de ce type. Cela ne supprime pas l'existant.
- Les rôles décident qui peut voir et répondre à quoi ; voir [La matrice des rôles](help:user.roles.matrix).

**Voir aussi:** [Qui peut valider](help:user.validation.who-may) · [Validations requises](help:user.validation.required-count)

<!-- anchor: setup.notify.operator -->
### La part de l'opérateur : faire fonctionner le push

**Public:** Opérateur·rice · Propriétaire

Vous voulez le push sur les téléphones des membres, et vous devez savoir qui fait quoi.

**Avant de commencer**

Le push ne vient pas avec l'app toute seule. Si votre espace tourne sur l'installation de référence partagée, demandez à son opérateur si le push est configuré. Si vous faites tourner votre propre installation, c'est vous ou votre responsable technique qui êtes l'opérateur.

**Étapes**

1. Créez un projet Firebase et compilez l'app avec lui. Sans cela, l'app reste limitée aux notifications locales, et un membre voit **Cette version n'a pas de notifications push**. La version distribuée par la boutique F-Droid n'a aucun push.
2. Pour iPhone et Mac, ajoutez une clé push Apple au projet Firebase.
3. Enregistrez la clé de compte de service Firebase comme secret du serveur et déployez la fonction push.
4. Sur votre propre installation, faites pointer la ligne `push_config` de votre base de données vers l'adresse et la clé de votre propre fonction push. Elle est préremplie avec l'adresse de l'installation de référence.
5. Testez avec deux comptes, comme décrit dans [le plan de test](help:setup.notify.test).

**Bon à savoir**

- Sans les étapes 1 à 4, rien n'est poussé, quels que soient les interrupteurs. Le fil, la cloche et les messages fonctionnent toujours.
- La liste de contrôle détaillée s'adresse à l'opérateur : voir [Les plateformes](help:user.advanced.platforms) et [Votre propre serveur](help:user.advanced.own-server).
- Le texte d'un push ne contient jamais de nom ni d'horaire : c'est voulu, pour la confidentialité.

**Voir aussi:** [Notifications push sur cet appareil](help:user.privacy.push)

<!-- anchor: setup.notify.members -->
### Ce que les membres contrôlent

**Public:** Propriétaire · Administrateur·rice

Vous voulez dire honnêtement à vos membres ce qu'ils peuvent désactiver.

<p><img src="images/setup-notify-push.fr.jpg" width="280"></p>

**Étapes**

1. Un membre ouvre [Confidentialité et données](app:/privacy) et utilise **Notifications push sur cet appareil** pour arrêter ou reprendre le push sur cet appareil.
2. Dans [Messages](app:/me?tab=messages), un membre appuie longuement sur une conversation pour **Épingler en haut**, **Couper les notifications**, **Marquer comme non lu** ou **Archiver**.
3. Dans les réglages système du téléphone, un membre peut refuser toutes les notifications, rappels d'enregistrement compris.
4. Dans son profil, un membre décide s'il partage un numéro WhatsApp.

**Bon à savoir**

- Une conversation en sourdine reste silencieuse mais est toujours comptée ; une mention l'emporte sur la sourdine.
- Un membre qui désactive le push sur un appareil n'est pas touché sur un autre.
- Il n'y a pas d'interrupteurs par catégorie. Si un membre veut moins de bruit, il coupe des conversations ; s'il n'en veut aucun, il désactive le push.

**Voir aussi:** [Notifications](help:user.collaborate.notifications) · [Vos données, vos droits](help:user.privacy.consent)

<!-- anchor: setup.notify.test -->
### Un plan de test : envoyez-vous un exemple de chaque

**Public:** Propriétaire · Administrateur·rice · Opérateur·rice

Vous vous assurez que chaque canal fonctionne avant que vos membres en dépendent.

**Avant de commencer**

Faites-le dans un espace de test (voir [une répétition sans risque](help:setup.money.dry-run)). Il vous faut deux comptes : le vôtre comme propriétaire, et un second comme membre, sur un autre téléphone, un autre navigateur, ou le même téléphone après déconnexion. L'espace de démonstration permet de voir les écrans avec ses personnages, mais n'envoie aucun vrai push.

**Étapes**

1. Message : depuis le compte membre, écrivez au propriétaire dans [Messages](app:/me?tab=messages). Sur le compte propriétaire, la cloche le compte et la conversation apparaît comme non lue. Ouvrez-la : le message du membre affiche un accusé de lecture.
2. Mention : dans une conversation de groupe, nommez le propriétaire (la fonction de mentions de la messagerie doit être activée). Si le push est configuré, le téléphone du propriétaire affiche « Vous avez été mentionné·e dans une conversation. »
3. Décision : en tant que membre, demandez la suppression d'une réservation passée (la fonction **Demandes de suppression de réservation** doit être activée). Le propriétaire la voit sous **En attente de votre confirmation** dans [Événements](app:/events) ; répondez-y et regardez le fil du membre changer.
4. Retrait : en tant que propriétaire, retirez une réservation à venir du membre. Le fil du membre l'affiche, et un téléphone avec push affiche « Une réservation a été retirée par un admin. »
5. Rappel : en tant que membre, réservez une place qui commence dans environ 20 minutes (une réservation qui commence dans moins de 15 minutes n'a pas de rappel). Environ 15 minutes avant le début, le téléphone du membre affiche le rappel d'enregistrement.
6. Relance de paiement : avec **Relances de paiement** activé, activez **Relances automatiques** dans les règles de relance avec un délai court avant la première relance, émettez une facture d'essai qui a un délai de paiement, attendez que le délai passe, puis ouvrez les Finances en tant que propriétaire ou copropriétaire ; le fil du membre affiche l'alerte.
7. Sourdine : en tant que membre, coupez la conversation, envoyez un autre message depuis le propriétaire, et vérifiez que rien ne sonne mais que le compteur de non lus augmente.

**Bon à savoir**

- Les étapes 2 et 4 n'affichent un push que si la configuration de l'opérateur est complète. Si elles échouent alors que les autres fonctionnent, la faute est dans la configuration, pas dans vos règles.
- Dans la version navigateur de l'app, il n'y a pas de rappel d'enregistrement.
- Un téléphone qui bloque les notifications n'affiche rien du tout ; vérifiez d'abord les réglages système.

**Résultat**

Vous avez vu de vos propres yeux chaque canal sur lequel un membre comptera.

**Voir aussi:** [Les canaux](help:setup.notify.channels) · [Démarrer une conversation ou un groupe](help:user.collaborate.messages-new)

<!-- anchor: setup.notify.silence -->
### Éviter la surcharge, et éviter le silence

**Public:** Propriétaire · Administrateur·rice

Vous voulez que les gens soient prévenus de ce qui les concerne, sans être noyés.

**Étapes**

1. Gardez **Regroupement des notifications** activé : les membres et les administrateurs peuvent replier le fil par type, par jour ou par membre.
2. Ne demandez une validation que là où une décision est réelle : chaque règle qui exige une validation crée une demande à laquelle quelqu'un doit répondre. Voir [Règles de validation](help:user.validation.overview).
3. Utilisez les interrupteurs de validation automatique pour les demandes dont la réponse est évidente.
4. Jetez un œil de temps en temps à [Ce qui vous attend](help:user.collaborate.attention) : il classe ce qui est en attente.

**Bon à savoir**

- La surcharge vient de règles qui sollicitent trop souvent, ou de trop d'administrateurs sur une même règle.
- Le silence vient d'une règle que personne ne peut traiter : exiger deux validations alors que seul le propriétaire existe, ou lister des administrateurs partis, laisse les demandes en attente pour toujours. La carte de préparation de l'installation peut signaler une règle de réservation qui a trop peu de validateurs.
- Le silence vient aussi d'un push non configuré, de membres qui ont désactivé le push, et d'un système qui bloque les notifications.
- Les relances de paiement automatiques ne dispensent pas de regarder de temps en temps les factures ouvertes.

**Voir aussi:** [Qui peut valider](help:user.validation.who-may) · [Validations requises](help:user.validation.required-count)
