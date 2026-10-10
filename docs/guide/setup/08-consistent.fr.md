<!-- anchor: setup.consistent.overview -->
## Rester cohérent

Un espace peut se tromper de deux façons : un réglage qui manque, et deux réglages qui se contredisent. DesKilo en repère certains, dans les deux cas, et le dit à l'écran. Ce chapitre liste ce qu'il repère et où vous le voyez, dit sans détour ce qu'il ne repère pas, et vous donne un audit à passer avant d'ouvrir les portes ainsi qu'une courte routine à répéter chaque mois.

Dans ce chapitre :
- [Les garde-fous de l'app](help:setup.consistent.guards)
- [Les erreurs que les garde-fous ne repèrent pas](help:setup.consistent.gaps)
- [L'audit avant l'ouverture](help:setup.consistent.audit)
- [La routine mensuelle](help:setup.consistent.monthly)
- [Quand quelque chose semble faux](help:setup.consistent.wrong)
- [Ce qui ne se défait pas](help:setup.consistent.irreversible)

L'exemple qui sert de fil conducteur est l'*Atelier du Marché*. Sa propriétaire, Ada, passe l'audit une fois dans un espace de test, puis une seconde fois dans l'espace réel.

<!-- anchor: setup.consistent.guards -->
### Les garde-fous de l'app

**Public:** Propriétaire · Copropriétaire · Administrateur·rice · Administrateur·rice facturation

Vous voulez savoir lesquelles de vos erreurs l'app vous signalera, et où, pour regarder au bon endroit.

<p><img src="images/setup-consistent-features-attention.fr.jpg" width="280"></p>

| Garde-fou | Ce qu'il repère | Où vous le voyez |
|---|---|---|
| Une fonction qui en demande une autre | Une fonction ne peut pas marcher sans celle dont elle dépend. Activer une fonction active sa fonction parente et nomme ce qui s'est activé. Désactiver une fonction parente retient ses enfants et conserve leur propre choix. | **Fonctionnalités** : le parcours d'activation avec son aperçu, **Nécessite** et **En attente de la fonction au-dessus** |
| Un processus retenu | Une fonction activée qui attend quelque chose de désactivé. | **Fonctionnalités**, vue **Processus** : l'état **À examiner** et sa pastille de filtre |
| La liste de préparation | Une ligne par domaine de l'espace, avec son état, qui agit et où le régler. Domaines : **Jours d’ouverture, fuseau horaire et devise**, **Places réservables sur le plan**, **Formules d’adhésion et tarifs**, **Inviter les premiers membres**, **Comment les membres paient**, **Rôles et validation des demandes**, **Export et restauration**, **Informations requises par vos fonctionnalités (identité, banque, plateformes)**, **Une première réservation** et, le cas échéant, **Serveur et version de la base** et **Accès des assistants (facultatif)** (ce dernier seulement quand l'interface MCP est activée). | **Mise en place de cet espace**, en haut d'[Espace](app:/workspace-settings) |
| La ligne qui empêche une première réservation | Seulement ce qu'une réservation exige vraiment : un fuseau horaire, une devise, un jour d'ouverture, une place et, quand une règle de réservation demande plus de validateurs qu'il n'en existe, ces validateurs. Le reste est facultatif et peut être mis de côté avec **Plus tard**. | **Avant que quiconque puisse réserver ici**, sur la carte de démarrage de [Réserver](app:/reserve) |
| Ce dont vos fonctions ont encore besoin en local | L'identité légale (requise par **Factures**), les coordonnées bancaires, un prestataire de paiement en ligne, un compte de facturation électronique, un site. | La même carte, domaine **Informations requises par vos fonctionnalités (identité, banque, plateformes)**, avec **Configurer** et **Recommandé** |
| Le garde-fou des factures | Une facture est refusée tant qu'elle n'est pas complète : l'adresse de l'espace, son numéro de TVA, un pays qui soit la France ou l'Allemagne, un fondement légal pour une exonération, le nom, l'adresse et le numéro de TVA du membre en cas d'autoliquidation, un taux de TVA en vigueur, une explication pour chaque ligne facturée à 0 %. Les factures transfrontalières, en autoliquidation, à l'export et exonérées sont refusées : émettez-les en dehors de l'app. | **Complétez ces informations avant d'émettre**, avec la liste des éléments manquants |
| Le garde-fou du paiement en ligne | Quand **Paiements en ligne** est désactivé, le serveur refuse un nouveau paiement en ligne. Un paiement déjà ouvert se règle encore. | Les écrans de paiement (la ligne de la fonction n'en dit rien) |
| Le garde-fou de validation | **Validations requises** au-delà du nombre de personnes disponibles. | **Pas assez de validateurs éligibles.** dans l'éditeur de règle ; « Une règle demande plus de validateurs que cet espace n'en compte » dans la liste de préparation |
| Le garde-fou des séquences de numérotation | Une remise à zéro plus fréquente que la date imprimée dans le numéro est refusée. | [Séquences de numérotation](app:/settings/number-sequences), à l'enregistrement |
| Le contrôle de maturité | Une fonction évaluée **Alpha** ou **Bêta**. | Une confirmation avant de l'activer, et un badge sur chaque interrupteur |
| Le contrôle de remplacement du plan | Remplacer le plan ou les réglages à partir d'un fichier. | Un avertissement : c'est irréversible. Le plan est refusé dès que des réservations existent |

**Bon à savoir**

- **Mise en place de cet espace** est une liste, pas un verrou. Elle ne vous empêche jamais d'activer quelque chose.
- La plupart des garde-fous agissent quand vous essayez d'émettre, de payer ou de réserver, pas quand vous choisissez un réglage. C'est pourquoi l'audit ci-dessous existe.
- La boîte du propriétaire ([Ce qui vous attend](help:user.collaborate.attention)) ne signale pas aujourd'hui les problèmes de configuration. N'attendez pas qu'elle vous les dise.

**Voir aussi:** [Éviter les fonctions qui se contredisent](help:setup.features.consistency) · [Vérifier votre espace](help:setup.place.check)

<!-- anchor: setup.consistent.gaps -->
### Les erreurs que les garde-fous ne repèrent pas

**Public:** Propriétaire · Copropriétaire · Administrateur·rice facturation

Vous voulez la liste honnête de ce qui reste de votre responsabilité. Ce sont des configurations que l'app vous laisse créer sans vous avertir. Chacune a une façon de l'éviter à la main.

| Erreur | Pourquoi rien ne l'arrête | Comment l'éviter |
|---|---|---|
| Choisir un autre pays que la France ou l'Allemagne en attendant des factures | L'app propose de nombreux pays et taux de TVA, mais n'émet de factures que pour la France et l'Allemagne. Rien ne le dit quand vous choisissez le pays. | Décider avant de promettre une facture aux membres. Ailleurs, gardez les relevés dans l'app et émettez les factures en dehors. |
| Être assujetti à la TVA sans taux en vigueur | L'émission est refusée, mais seulement à la première facture. Quand **Gestion de la TVA** est désactivée, la configuration est masquée mais les taux enregistrés continuent de s'appliquer. | Ajouter le taux sous [TVA](app:/vat) avant la première clôture de mois, et émettre une facture d'essai. |
| **Paiements en ligne** activé sans prestataire | Vous pouvez l'activer ; le prestataire manquant n'apparaît que comme un élément de la liste de préparation. | Connecter d'abord le prestataire, puis activer. |
| **Factures** activé sans identité légale | La fonction est active dès le premier jour ; le refus arrive au moment de l'émission. | Renseigner l'identité avant de dire aux membres qu'ils seront facturés. |
| Une règle qui demande plus de validateurs que vous n'en avez, hors réservations | La liste de préparation ne retient la première réservation que pour les règles de réservation. L'éditeur vous laisse en enregistrer une qui dépasse le nombre de personnes disponibles. Les autres demandes sont créées, ne peuvent pas être menées à terme, et expirent après sept jours. | Compter les propriétaires et administrateurs actifs après chaque règle. Voir [Éviter les demandes qui attendent pour toujours](help:setup.people.stuck). |
| Des membres qui ne peuvent pas ouvrir le plan | Dans un nouvel espace, la carte **Utilisateur** de [Rôles](app:/roles) est vide et rien ne vous avertit. | Cocher les droits du quotidien et rejoindre une fois avec un second compte. |
| Un espace créé à partir d'un modèle | Un modèle ne reprend jamais l'identité, les coordonnées bancaires, les sites ni les invitations. | Traiter le domaine **Informations requises par vos fonctionnalités (identité, banque, plateformes)** comme une liste de choses à faire. |
| Un fichier de réglages qui promet plus qu'il ne livre | Aujourd'hui, le fichier reprend la matrice des rôles, vos propres rôles et toutes les règles de validation, mais pas les membres, les numéros de factures et de membres, la période de TVA ni les prix valables pour tout l'espace. Ce qu'il reprend n'est appliqué que si **Configuration dans le fichier de l'espace** est activée dans la cible. Un plan n'est pas remplacé dès que des réservations existent. | Ressaisir à la main ce qu'il ne reprend pas, et lire l'aperçu avant **Remplacer et importer**. |
| Des relances qui ne partent jamais | Elles partent chaque matin depuis le serveur quand la base de données a son planificateur (pg_cron) ; sinon, elles partent quand un administrateur ouvre les Finances. Elles restent aussi muettes quand **Relances de paiement automatiques** est désactivé. | Demander à l'opérateur si le planificateur existe, et ouvrir vous-même les Finances s'il n'existe pas. Voir [Relances de paiement](help:user.money.reminders.automatic). |
| Changer de pays, de devise ou de fuseau horaire une fois que de l'argent existe | Je n'ai trouvé aucun garde-fou. Les montants sont stockés comme des nombres et ne sont pas convertis : vérifiez auprès du propriétaire de l'installation avant de vous y fier. | Les choisir dès le premier jour. Voir [Les décisions difficiles à défaire](help:setup.before.permanent). |
| Une numérotation ou une période de TVA qui ne convient pas au format de votre expert-comptable | L'app ne les compare pas à l'export comptable du pays. | Demander à votre expert-comptable le format de numérotation et l'export qu'il utilise avant d'émettre. Voir [Exports comptables](help:user.invoicing.accounting-export). |
| Prendre un test pour l'espace réel | Hormis le filigrane sur les documents imprimés, la différence est facile à manquer. | Regarder la bannière de l'espace de test et le côté affiché dans [Moi](app:/me) avant d'agir. |

**Bon à savoir**

- Un kiosque sans membre kiosque, une fonction de sites sans site, un push sans service push : [Éviter les fonctions qui se contredisent](help:setup.features.consistency).
- L'app est plus stricte qu'il n'y paraît pour les factures, et plus souple qu'il n'y paraît pour tout le reste. Dans le doute, émettez une facture d'essai dans un espace de test.

**Voir aussi:** [Une répétition sans risque](help:setup.money.dry-run)

<!-- anchor: setup.consistent.audit -->
### L'audit avant l'ouverture

**Public:** Propriétaire · Copropriétaire

Vous voulez une preuve, pas une impression, avant d'ouvrir. Trente et un contrôles, en trois niveaux. Passez *Ouvrir* avant d'inviter qui que ce soit, *Faire tourner* avant de rien promettre sur l'argent, *Développer* avant que la première facture ne parte. Faites-le d'abord dans un espace de test, avec une deuxième personne.

*Ouvrir : un lieu que l'on peut réserver*

| N° | Contrôle | Où | À quoi ressemble un bon résultat |
|---|---|---|---|
| 1 | Pays, devise, fuseau horaire | [Espace](app:/workspace-settings), **Informations générales** | Atelier du Marché : France, EUR, Europe/Paris |
| 2 | Langue de l'espace | Même écran | La langue dans laquelle vos invitations sont écrites |
| 3 | Jours et horaires d'ouverture | [Disponibilité](app:/availability) | Les jours d'ouverture sont cochés ; les horaires correspondent au jour |
| 4 | Jours de fermeture | Disponibilité, jours de fermeture | Les jours fériés et fermetures des mois à venir sont saisis, avant la première fin de mois |
| 5 | Au moins une place | [Éditeur de l'espace](app:/editor) | Chaque salle que vous louez a des places |
| 6 | Préparation | **Mise en place de cet espace** | Rien sous **Jours d’ouverture, fuseau horaire et devise** ni **Places réservables sur le plan** ne demande de configuration |
| 7 | Vous avez réservé une place | [Réserver](app:/reserve) | La place est réservée, enregistrée et annulée sans mauvaise surprise |
| 8 | L'identifiant de l'espace | [Identifiant de l'espace et QR](app:/workspace-code) | L'identifiant est de ceux que l'on peut dire à voix haute ; le QR est imprimé |
| 9 | Droits du quotidien | [Rôles](app:/roles) | **Utilisateur** détient les six droits du quotidien |
| 10 | Un second compte a rejoint l'espace | Un autre appareil | Il a été approuvé et a pu ouvrir le plan et réserver |
| 11 | Plus d'une personne peut agir | [Membres et formules](app:/members) | Un propriétaire plus un copropriétaire ou un administrateur, tous **Actif** |
| 12 | Nombre de validations | [Règles de validation](app:/validation) | Aucune règle ne demande plus de validateurs que de propriétaires et d'administrateurs actifs |
| 13 | L'invitation dans chaque langue | **Communauté et invitations** | Vous avez lu chaque version une fois ; aucune balise n'est restée vide |
| 14 | Le côté où vous êtes | [Moi](app:/me) | La bannière de l'espace de test est affichée, ou non, comme prévu |

*Faire tourner : les gens paient et les rôles tiennent*

| N° | Contrôle | Où | À quoi ressemble un bon résultat |
|---|---|---|---|
| 15 | Paliers tarifaires | [Facturation](app:/billing) | Chaque part qu'un membre peut choisir tombe dans un palier ; pas de trou entre 0 et 100 pour cent |
| 16 | Formules proposées | Facturation, niveaux | Seulement les formules que vous voulez vendre |
| 17 | Ce que reçoivent les nouveaux membres au départ | **Nouveaux membres**, dans Espace | L'abonnement et la règle quand les jours sont épuisés sont ceux que vous avez choisis |
| 18 | Forfaits et services | Facturation, [Services](app:/services) | Les noms et les prix se lisent bien pour un membre |
| 19 | Comment les membres paient | **Comment les membres paient** dans la liste de préparation | Le domaine indique **Prêt** et les coordonnées bancaires attendues (IBAN, référence) apparaissent dans les Réglages ; un prestataire seul le rend aussi prêt |
| 20 | Paiements en ligne | [Fonctionnalités](app:/features) | Désactivé, sauf si un prestataire est connecté |
| 21 | Administrateurs | Membres et formules | Chacun est une personne à qui vous confieriez les données de tous les membres |
| 22 | La carte Administrateur de la matrice | Rôles | Vous savez lire chaque case cochée et la défendre |
| 23 | Qui est prévenu de quoi | [Comment les membres sont prévenus](help:setup.notify.members) | Les membres trouvent tout sous **Événements** ; le push seulement si l'opérateur l'a configuré |
| 24 | Kiosque et badges | [Fonctionnalités](app:/features) | Désactivés, ou un membre kiosque existe et des badges sont émis |
| 25 | Sites | Fonctionnalités | Désactivés, ou au moins un site existe |
| 26 | Fonctions retenues | **Fonctionnalités**, **À examiner** | Le filtre n'affiche aucun processus |

*Développer : factures, fiscalité et archives*

| N° | Contrôle | Où | À quoi ressemble un bon résultat |
|---|---|---|---|
| 27 | Identité légale | [Identité légale et facturation électronique](app:/legal-identity) | **Complétez ces informations avant d'émettre** n'affiche rien quand vous démarrez une facture d'essai |
| 28 | Régime de TVA et taux | [TVA](app:/vat) | Le régime est celui que votre expert-comptable vous a donné ; un taux est en vigueur pour votre taux par défaut |
| 29 | Format de numérotation | [Séquences de numérotation](app:/settings/number-sequences) | Vous avez lu l'aperçu et votre expert-comptable est d'accord |
| 30 | Une facture d'essai | Espace de test, assistant de clôture du mois | Elle a été émise, dans chaque langue que lisent vos membres, sans élément manquant |
| 31 | Un export récent | **Export et restauration** | « Un export récent est enregistré » |

**Étapes**

1. Imprimez les trois tableaux ou copiez-les dans vos notes.
2. Passez *Ouvrir* et cochez chaque ligne quand vous voyez la colonne du bon résultat, pas quand vous vous en souvenez.
3. Faites de même pour *Faire tourner* et *Développer* dans l'espace de test, avec votre expert-comptable pour les lignes de *Développer*.
4. Refaites les lignes qui ont changé quand vous passez à l'espace réel. Un modèle ou un fichier de réglages ne les reprend pas toutes.

**Résultat :** une liste que vous pouvez montrer à quelqu'un, et un espace que vous avez vu fonctionner avant que quiconque en dépende.

**Voir aussi:** [De la semaine 0 à la semaine 4](help:setup.training.overview) · [Une répétition sans risque](help:setup.money.dry-run) · [L'ordre à suivre](help:setup.reports.sequence)

<!-- anchor: setup.consistent.monthly -->
### La routine mensuelle

**Public:** Propriétaire · Administrateur·rice · Administrateur·rice facturation

Vous voulez une courte habitude qui garde l'espace cohérent, en dix minutes à la fin du mois.

**Étapes**

1. Ouvrez **Mise en place de cet espace**. Chaque domaine indique toujours **Prêt**, ou **Sans objet ici**, ou est mis de côté volontairement.
2. Ouvrez [Événements](app:/events). **En attente de votre confirmation** est vide ou presque, et aucun membre n'est resté **En attente** plus d'un jour ou deux.
3. Recomptez l'équipe. Une personne partie ou mise en pause peut laisser une règle sans assez de validateurs. Voir [Éviter les demandes qui attendent pour toujours](help:setup.people.stuck).
4. Clôturez le mois : les jours de fermeture sont saisis, l'assistant de clôture du mois est passé, les relances de paiement sont parties (automatiquement chaque matin, ou à l'ouverture des Finances là où la base n'a pas de planificateur). Voir [L'assistant de clôture du mois](help:user.invoicing.wizard).
5. Faites l'export des données, et ouvrez **Fonctionnalités** pour vérifier qu'aucun processus ne demande d'attention après les changements du mois.

**Bon à savoir**

- Écrire la date du dernier passage sur la première ligne de vos notes indique à la personne suivante quand tout cela était vrai pour la dernière fois.
- Tout ce qui a changé durant le mois dans la matrice des rôles ou dans une règle de validation mérite de revérifier les lignes 9, 11 et 12 de l'audit.

**Résultat :** un espace qui reste tel que vous l'avez mis en place.

**Voir aussi:** [L'audit avant l'ouverture](help:setup.consistent.audit)

<!-- anchor: setup.consistent.wrong -->
### Quand quelque chose semble faux

**Public:** Propriétaire · Copropriétaire · Administrateur·rice

Vous voulez savoir quoi essayer, dans quel ordre, et à qui demander.

<p><img src="images/setup-consistent-recovery-export.fr.jpg" width="280"></p>

**Étapes**

1. Lisez le message à l'écran. La plupart disent quoi faire.
2. Vérifiez le côté où vous êtes. Regardez la bannière de l'espace de test et le côté affiché dans [Moi](app:/me). Les documents imprimés du côté test portent un filigrane et rien n'y est dû ; le côté réel émet des factures qui, elles, sont dues.
3. Vérifiez [Fonctionnalités](app:/features) et [Rôles](app:/roles) : une fonction qui manque est une fonction désactivée ou un droit que personne n'a coché.
4. Ouvrez **Mise en place de cet espace** et lisez le domaine qui correspond au symptôme.
5. Préparez les **Détails pour l’assistance** sous [Aide](app:/help) : choisissez **Dernière heure** ou **Dernières 24 heures**, **Préparer l’aperçu**, relisez-le, **Enregistrer**, et envoyez le fichier. Il ne contient que des comptes et des contrôles, ni identités, ni identifiants, ni données d'activité.
6. Avant de changer quoi que ce soit d'important, faites l'export des données (ci-dessous).

*À qui demander*

| Sujet | Demandez à |
|---|---|
| Un réglage de votre espace, une règle, un rôle | Vous, puis votre copropriétaire |
| Une facture, la TVA, un numéro | Votre expert-comptable, avec la facture d'essai |
| Un domaine qui indique **En attente d’une autre personne** ou **L’opérateur du serveur** | L'opérateur de votre installation |
| Un assistant qui n'est pas approuvé | Un administrateur de base de données |
| Une erreur que vous ne savez pas expliquer | L'assistance, avec le fichier de détails |

*L'export de secours*

1. Ouvrez [Rapports](app:/reports?section=documents) et choisissez **Documents de l’espace**.
2. Touchez **Exporter les données (Excel)**. Cela demande la fonction **Export des données (Excel)** et le droit **Exporter la comptabilité et les données**. Vous obtenez un seul ZIP : un classeur avec un onglet par jeu de données, un manifeste qui compte les lignes, et les fichiers stockés.
3. Touchez **Exporter la configuration (PDF)** pour garder une trace des paramètres et, dans **Espace**, **Exporter l'espace (XML)** pour le plan et les réglages.

**Bon à savoir**

- Un export de données terminé est enregistré ; le domaine de préparation **Export et restauration** l'indique pendant 90 jours, puis précise que l'export est plus ancien.
- Le PDF est une trace, pas une sauvegarde. Seul le XML peut être réimporté, et il ne contient jamais ni membres ni argent.
- Gardez le fichier dans un endroit que vous seul pouvez ouvrir : il contient vos membres.

**Voir aussi:** [Détails pour l'assistance](help:user.advanced.support) · [Quand quelque chose ne fonctionne pas](help:user.advanced.troubleshooting) · [Exporter les données (Excel)](help:user.workspace.export.excel)

<!-- anchor: setup.consistent.irreversible -->
### Ce qui ne se défait pas

**Public:** Propriétaire · Copropriétaire · Administrateur·rice facturation

Vous voulez une page qui dit sur quoi ralentir. La liste complète, avec ce qu'il faut faire à la place, se trouve dans [Les décisions difficiles à défaire](help:setup.before.permanent). Ceci en est le résumé.

> **Attention** Une facture émise ne change jamais et son numéro n'est jamais réutilisé. Une erreur se corrige par une annulation, un avoir ou une demande de remboursement, pas par une modification.

| Décision | Définitive à partir de | Traitée dans |
|---|---|---|
| Format et séquence des numéros de facture | La première facture émise | [Les décisions difficiles à défaire](help:setup.before.permanent) |
| Le mois facturé d'un membre | Le moment où la facture est émise | [Argent](help:setup.money.permanent) |
| Mentions légales de la facture | La première facture émise | [L'ordre à suivre](help:setup.reports.sequence) |
| Régime de TVA et taux | Les taux sont versionnés par date et jamais modifiés ; une déclaration soumise n'est jamais recalculée | [Argent](help:setup.money.permanent) |
| Pays, devise, fuseau horaire | Dès que de l'argent existe : les montants ne sont pas convertis | [Les décisions difficiles à défaire](help:setup.before.permanent) |
| Remplacement du plan | Refusé dès qu'une réservation existe ; supprimer un étage supprime ce qu'il contient | [Les décisions difficiles à défaire](help:setup.before.permanent) |
| L'identifiant de l'espace | Quand vous le changez, l'ancien cesse de fonctionner aussitôt ; réimprimez le QR | [Comment les gens rejoignent l'espace](help:setup.people.join) |
| La propriété | Un propriétaire peut la céder ; il n'y a pas d'invitation de propriétaire | [Copropriétaires](help:setup.people.coowner) |
| Un changement de matrice ou de validation | Il est enregistré comme événement et s'applique à tout le monde d'un coup | [La matrice des rôles](help:setup.people.matrix) |
| Test ou réel | Un espace réel émet des factures qui sont dues | [Avant de commencer](help:setup.before.overview) |
| Un export partagé | Un fichier partagé ne peut pas être révoqué | [Quand quelque chose semble faux](help:setup.consistent.wrong) |

**Bon à savoir**

- Désactiver une fonction n'efface jamais de données.
- Un fichier qui contient des identifiants n'est pas une sauvegarde. Gardez les jetons hors de tout fichier que vous envoyez.

**Résultat :** vous savez quelles lignes lire deux fois.

**Voir aussi:** [Avant de commencer](help:setup.before.overview)
