<!-- anchor: setup.money.overview -->
## Argent et fiscalité

Ce chapitre s'adresse à vous qui allez décider comment un espace se finance. Il parle des décisions et de leur ordre ; les clics sont dans le guide d'utilisation, et chaque section y renvoie.

> **Attention** DesKilo enregistre, calcule et imprime ce que vous déclarez, et vérifie que les informations obligatoires sont présentes. Il ne certifie ni vos factures, ni votre traitement de la TVA, ni votre comptabilité. Chaque fois que ce chapitre dit « demandez à votre expert-comptable », faites-le.

Dans ce chapitre :
- Les membres paient-ils, et qui émet les factures
- Comment se construit un tarif, avec les chiffres de l'espace de démonstration *Atelier du Marché*
- Comment les membres vous paient
- Votre identité légale, et les questions à poser à votre expert-comptable
- Facturation manuelle ou automatique, relances, et la TVA en résumé
- Les décisions financières irréversibles, et comment répéter sans risque

<!-- anchor: setup.money.decide -->
### D'abord décider : les membres paient-ils, et qui émet les factures

**Public:** Propriétaire

Vous choisissez jusqu'où DesKilo va dans votre gestion financière. Tout le reste de ce chapitre découle de ce choix. Il est facile d'aller plus loin plus tard, mais difficile de revenir en arrière une fois que des factures existent.

<p><img src="images/setup-money-paths.fr.jpg" width="280"></p>

**Avant de commencer**

Répondez à deux questions : les membres vous paient-ils pour l'espace, et voulez-vous que les factures légales sortent de DesKilo ?

| Voie | À choisir quand | Ce qui se passe |
|---|---|---|
| 1. Pas d'argent | L'espace est gratuit, ou les membres sont des amis qui se partagent le loyer en dehors de l'app | Vous laissez désactivées les fonctions financières. Les membres réservent ; personne n'est facturé. |
| 2. Relevés et paiements, factures à l'extérieur | Vous avez déjà un expert-comptable ou un outil de facturation, ou vous travaillez dans un pays pour lequel DesKilo ne peut pas émettre de factures | Les membres ont un relevé mensuel, vous enregistrez les paiements reçus, et vous exportez les chiffres pour votre expert-comptable. Les factures légales sont produites ailleurs. |
| 3. Factures émises par DesKilo | Vous êtes en France ou en Allemagne, et vous êtes soit assujetti à la TVA, soit hors champ de la TVA (une association, par exemple) | DesKilo produit des factures signées et numérotées à partir de ce qui a été réservé, avec votre identité légale imprimée dessus. |

**Étapes**

1. Choisissez votre voie dans le tableau.
2. Pour la voie 2 ou 3, activez les fonctions financières dont vous avez besoin dans [Fonctionnalités](help:user.features.switch) : **Factures** est la base de tout ce qui est émis, et les fonctions placées en dessous (**Factures d'abonnement**, **Factures de fin de mois**, **Relances de paiement**, **Gestion de la TVA**) s'activent une à une.
3. Pour la voie 3, passez à [votre identité légale](help:setup.money.identity) avant la première réservation, pas après.

**Bon à savoir**

- L'émission de factures dans l'app existe aujourd'hui pour un espace situé en **France** ou en **Allemagne**. Dans tout autre pays, prenez la voie 2 : les relevés restent disponibles.
- Le serveur refuse d'émettre, et la liste **Complétez ces informations avant d'émettre** vous dit pourquoi, quand une information manque ou quand le traitement n'est pas géré par DesKilo : ventes transfrontalières, autoliquidation, exportations et factures exonérées de TVA doivent être examinées et émises hors de l'app, avec votre expert-comptable.
- Un vendeur en franchise en base de TVA (Kleinunternehmer en Allemagne) ne peut pas émettre de factures dans l'app : le serveur refuse la catégorie de TVA exonérée. Restez sur la voie 2 et émettez ces factures ailleurs.
- Désactiver une fonction arrête les nouvelles opérations de ce type ; rien n'est supprimé.
- Vous pouvez rester sur la voie 2 pour toujours. Beaucoup d'associations le font.

**Résultat**

Vous savez laquelle des trois voies est la vôtre, et de quelles fonctions elle a besoin.

**Voir aussi:** [La facturation en un coup d'œil](help:user.money.invoicing) · [Activer ou désactiver des processus entiers](help:user.features.processes)

<!-- anchor: setup.money.tariff -->
### Concevoir un tarif

**Public:** Propriétaire · Administrateur·rice facturation

Vous transformez « combien vaut une place ? » en chiffres que DesKilo applique chaque mois sans vous.

<p><img src="images/setup-money-bands--bands.fr.jpg" width="280"></p>

**Avant de commencer**

Gardez le modèle en tête. Il se lit de gauche à droite, et chaque étape alimente la suivante :

1. Pourcentage d'abonnement : un membre détient un pourcentage du mois : 25, 50, 75 ou 100 %, ou une valeur que vous autorisez.
2. Quota de demi-journées : le pourcentage devient un nombre de demi-journées pour le mois : le nombre de jours ouverts, multiplié par deux, multiplié par le pourcentage, arrondi au supérieur.
3. Palier tarifaire : le pourcentage tombe dans un palier, qui donne le tarif mensuel et le prix d'une demi-journée supplémentaire. Un palier couvre « au-dessus de son début, jusqu'à sa fin incluse », et les paliers réunis doivent couvrir de 0 à 100 % sans trou.
4. Règle de dépassement : quand le quota est épuisé, chaque membre est soit bloqué, soit facturé au prix du dépassement, soit invité à acheter un forfait.
5. Forfaits et services : un forfait de jours vend à l'avance des demi-journées supplémentaires au prix que vous fixez ; les services (un café, un casier, l'impression) se vendent en plus.

**Étapes**

1. Décidez des pourcentages que vous proposez sous **Niveaux d'abonnement**, et si un propriétaire peut saisir une valeur négociée (voir [Niveaux d'abonnement](help:user.money.billing.levels)).
2. Définissez une ligne par tranche dans **Paliers tarifaires** : sa limite haute, le tarif mensuel et le prix du dépassement (voir [Paliers tarifaires](help:user.money.billing.fee-bands)).
3. Choisissez la règle par défaut pour les membres qui n'ont plus de jours : [Quand les jours sont épuisés](help:user.members.overage-policy).
4. Ajoutez les [forfaits de jours](help:user.money.billing.packages) et les [services](help:user.money.services.overview) que vous vendez.

**Bon à savoir**

- Le calcul est figé sur chaque document émis. Modifier un prix change le mois suivant, jamais un mois déjà facturé.
- Les horaires d'ouverture et les jours de fermeture décident du nombre de jours ouverts dans un mois, donc de la taille du quota. Réglez-les d'abord.
- Un membre sans abonnement est prévu pour les visiteurs qui achètent des carnets ; il ne peut pas être au paiement à l'usage.

**Voir aussi:** [Facturation](help:user.money.billing.fee-bands) · [L'abonnement d'un membre](help:user.members.subscription)

<!-- anchor: setup.money.example -->
### Un exemple pas à pas

**Public:** Propriétaire · Administrateur·rice facturation

Vous suivez un membre pendant un mois avec les chiffres de l'*Atelier du Marché*, pour pouvoir vérifier les vôtres de la même façon.

<p><img src="images/setup-money-packages--packages.fr.jpg" width="280"></p>

**Avant de commencer**

L'espace de démonstration a trois paliers tarifaires, en euros et TVA comprise. Les chiffres sont ceux de la démo, pas une recommandation.

| Palier | Tarif mensuel | Demi-journée en plus | Demi-journées dans un mois de 22 jours ouverts |
|---|---|---|---|
| jusqu'à 25 % | 0,00 | 15,00 | 11 |
| au-dessus de 25 %, jusqu'à 50 % | 150,00 | 8,00 | 22 |
| au-dessus de 50 %, jusqu'à 100 % | 250,00 | 0,00 | 44 (à 100 %) |

**Étapes**

1. Un membre détient 50 %. Dans un mois de 22 jours ouverts, le quota est de 22 × 2 × 50 / 100 = 22 demi-journées.
2. 50 % tombe dans le deuxième palier (au-dessus de 25, jusqu'à 50) : le tarif est de 150,00, quoi que le membre consomme.
3. Le membre réserve 24 demi-journées. Deux dépassent le quota, à 8,00 chacune : 16,00.
4. Le mois coûte 150,00 + 16,00 = 166,00, avant tout service. Dans la démo, les prix sont TTC : la TVA de 20 % est comprise dedans, et l'écran l'indique sous chaque prix.
5. Comparez avec un forfait : le forfait de 5 jours de la démo coûte 40,00 et ajoute 10 demi-journées (5 jours, deux demi-journées chacun), soit 4,00 la demi-journée. Face à 8,00 de dépassement, il devient rentable dès la sixième demi-journée supplémentaire d'un mois.

**Bon à savoir**

- Un prix de dépassement de 0,00 signifie que les demi-journées supplémentaires ne coûtent rien au paiement à l'usage.
- Le relevé que voit un membre montre les mêmes lignes : tarif, inclus, utilisé, en plus, dépassement.
- Les prix s'affichent TTC quand la TVA est activée ; la taxe en est extraite.
- Si vous convenez avec un membre de conditions différentes, voir [la négociation des prix](help:setup.money.negotiation).

**Résultat**

Vous pouvez prévoir la facture d'un membre à partir de trois nombres : son pourcentage, les jours ouverts, les réservations.

**Voir aussi:** [Lire votre relevé](help:user.money.statement) · [Ce qu'a coûté chaque réservation](help:user.money.usage)

<!-- anchor: setup.money.negotiation -->
### Négociation des prix

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez qu'un membre paie des conditions différentes de celles du tarif, en laissant une trace.

**Étapes**

1. Activez la fonction de négociation des prix dans [Fonctionnalités](help:user.features.switch).
2. Proposez des conditions sur la fiche du membre : un tarif mensuel différent, un taux de dépassement, une remise sur les suppléments, des prix unitaires ou un pourcentage d'occupation (voir [Négociation des prix](help:user.members.negotiation)).
3. Laissez la règle de validation des négociations de prix décider qui la confirme.

**Bon à savoir**

- Le tarif reste la référence ; un prix négocié appartient à un seul membre.
- Il est visible du membre, des propriétaires et des personnes autorisées à consulter les accords commerciaux, et chaque lecture est journalisée.
- Fixez votre politique avant de commencer : une exception accordée discrètement devient vite le prix que tout le monde réclame.

**Voir aussi:** [Vos prix négociés](help:user.money.negotiation)

<!-- anchor: setup.money.pay -->
### Comment les membres vous paient

**Public:** Propriétaire · Administrateur·rice facturation

Vous choisissez où va l'argent d'un membre, et quelle part du travail DesKilo fait pour vous.

<p><img src="images/setup-money-payment-instructions.fr.jpg" width="280"></p>

**Étapes**

1. Commencez par la voie gratuite : renseignez les [instructions de paiement](help:user.money.payments.methods) : votre IBAN et vos coordonnées bancaires, ainsi que PayPal.me, Wero, Lydia ou Wise si vous les acceptez, plus une indication de référence.
2. Les membres voient ces informations sur un relevé impayé. Quand un paiement arrive sur votre compte, vous ou un·e administrateur·rice facturation [l'enregistrez](help:user.money.payments.record).
3. Seulement si vous voulez que les membres paient dans l'app, connectez un prestataire dans [Paiements en ligne](help:user.money.payments.provider) : PayPal, Stripe ou Mollie. Cela demande la fonction **Paiements en ligne** et votre propre compte chez le prestataire.

**Bon à savoir**

- DesKilo enregistre les paiements ; avec la voie manuelle, il ne déplace jamais d'argent.
- Un prestataire prélève ses propres frais et reçoit les clés de votre compte (la fiche des identifiants explique comment elles se saisissent).
- Quand **Paiements en ligne** est désactivé, un nouveau paiement en ligne est refusé ; un paiement déjà ouvert peut encore se régler.
- Un espace créé à partir d'un modèle ne reprend pas les coordonnées de paiement : saisissez-les dans chaque espace. Un export de configuration, lui, les reprend.

**Voir aussi:** [Régler ce que vous devez](help:user.money.payments) · [Identifiants du prestataire](help:user.money.payments.credentials)

<!-- anchor: setup.money.identity -->
### Votre identité légale, et ce qu'il faut demander à votre expert-comptable

**Public:** Propriétaire

Vous dites à DesKilo qui vend, pour que chaque facture vous désigne correctement. C'est la partie à régler avec un professionnel.

<p><img src="images/setup-money-legal--top.fr.jpg" width="280"></p>

**Avant de commencer**

L'écran est [Identité légale et facturation électronique](app:/legal-identity). Préparez :

- votre type d'organisation : une entreprise, ou une association à but non lucratif ;
- votre régime de TVA : hors champ de la TVA, exonéré de TVA (franchise en base), ou assujetti à la TVA. L'app ne peut émettre des factures que pour le premier et le dernier ; avec la franchise en base, l'écran enregistre votre statut mais les factures doivent être émises ailleurs (voie 2) ;
- votre numéro d'immatriculation (SIREN ou SIRET en France), et votre numéro de TVA si vous en avez un ;
- votre adresse postale, telle qu'elle figure sur votre immatriculation ;
- la raison pour laquelle aucune TVA n'est facturée, si vous n'en facturez pas.

> **Attention** Choisir le régime est une décision fiscale, pas un réglage logiciel. Une association sans activité commerciale est normalement hors champ de la TVA, et l'écran vous avertit si vous choisissez « exonéré » pour elle. Confirmez ce choix avant d'émettre la première facture.

**Étapes**

1. Ouvrez [Identité légale et facturation électronique](app:/legal-identity) et avancez depuis le haut : d'abord le **Régime de TVA**, puis les identifiants, l'adresse et les **Mentions de facturation**.
2. Renseignez les conditions de paiement, les mentions de retard de paiement et les autres mentions que votre pays exige (voir [Votre identité légale](help:user.money.legal.identity)).
3. Touchez **Enregistrer**, puis relisez une fois le modèle de facture avec votre expert-comptable (voir [Le modèle PDF de facture](help:user.money.reports.invoice-template)).

> **Astuce** Les questions à poser à votre expert-comptable :
>
> 1. Dans quel type d'organisation et quel régime de TVA suis-je ?
> 2. Quels sont mon numéro d'immatriculation et mon numéro de TVA, et comment les écrire ?
> 3. Si je ne facture pas de TVA, quelle mention légale le justifie ?
> 4. Quelles mentions doivent figurer sur mes factures (délai de paiement, pénalité de retard, indemnité forfaitaire de recouvrement, escompte pour paiement anticipé, assurance) ?
> 5. Comment numéroter les factures, et la numérotation repart-elle chaque année ou chaque mois ?
> 6. La TVA est-elle exigible à la facturation ou à l'encaissement ?
> 7. Dois-je envoyer des factures électroniques à une plateforme publique, et laquelle ?
> 8. Ai-je besoin de déclarations de TVA périodiques, et à quel rythme ?

**Bon à savoir**

- Les factures déjà émises gardent l'identité avec laquelle elles ont été signées ; une modification s'applique aux suivantes.
- Seul un propriétaire ou un copropriétaire actif peut ouvrir cet écran, et la fonction **Factures** doit être activée.
- Un espace créé à partir d'un modèle ne reprend pas votre identité : saisissez-la de nouveau. Un déploiement entre les deux côtés d'une paire, lui, la reprend.

**Voir aussi:** [Régime de TVA](help:user.money.vat.regime) · [La plateforme de facturation électronique](help:user.money.einvoice.overview) · [Type d'organisation](help:user.money.legal.seller-kind)

<!-- anchor: setup.money.invoicing -->
### Facturer à la main ou automatiquement

**Public:** Propriétaire · Administrateur·rice facturation

Vous décidez si une personne appuie sur les boutons chaque mois ou si DesKilo s'en charge.


**Étapes**

1. Pour un premier mois, travaillez à la main : ouvrez [Facturation](app:/invoices), lisez **À émettre**, et émettez la facture d'un membre (voir [Émettre une facture](help:user.invoicing.new-invoice)).
2. Pour une routine, utilisez l'[assistant de clôture du mois](help:user.invoicing.wizard) : il passe par **Revue**, **Émettre**, **Envoyer**, **Relancer**, **Paiements**, **Rapprocher**, **Clôturer** et **Récapitulatif**.
3. Pour automatiser, activez **Factures d'abonnement** et **Factures de fin de mois** dans [Fonctionnalités](help:user.features.switch), puis réglez les jours dans [Calendrier de facturation](help:user.money.billing.schedule).

**Bon à savoir**

- Deux documents existent par mois : le tarif d'abonnement, émis avant le mois, et ce que le mois a réellement coûté, émis après. Une facture peut être datée de quelques jours à l'avance (trois par défaut, réglables dans le calendrier de facturation) ; une facture datée du 29 août peut donc désigner septembre.
- Côté serveur, une exécution quotidienne émet les deux quand la base de données de l'installation a son planificateur activé ; en cas de doute, demandez à l'opérateur.
- Chaque type de facture (abonnement, fin de mois) ne peut être émis qu'une fois par membre et par mois. Une facture ne se modifie ni ne se supprime ; une facture erronée est marquée comme telle et remplacée.
- Par défaut, le propriétaire et les copropriétaires émettent les factures. **Les admins émettent des factures** étend ce droit aux administrateurs.

**Voir aussi:** [L'écran Facturation](help:user.invoicing.hub) · [Relancer et solder les factures ouvertes](help:user.invoicing.open)

<!-- anchor: setup.money.reminders -->
### Relances de paiement

**Public:** Propriétaire · Administrateur·rice facturation

Vous décidez à partir de quand un paiement est en retard, et qui relance.

<p><img src="images/setup-money-reminders.fr.jpg" width="280"></p>

**Étapes**

1. Activez **Relances de paiement** dans [Fonctionnalités](help:user.features.switch). Elle se trouve sous **Factures**.
2. Réglez le nombre de niveaux et les délais dans [Règles de relance](help:user.money.reminders.rules) : jours avant la première relance, jours entre deux relances.
3. Décidez si les relances partent toutes seules : activez **Relances automatiques** dans la même fenêtre (voir [Relances automatiques](help:user.money.reminders.automatic)) ; la fonction **Relances de paiement automatiques** doit aussi être activée.

**Bon à savoir**

- Le délai avant la première relance est aussi lu comme votre délai de paiement. Réglez-le avec les [Conditions de paiement](help:user.money.legal.payment-terms).
- Les relances automatiques s'exécutent une fois par jour sur le serveur quand la base de données a son planificateur activé. Elles s'exécutent aussi quand une personne autorisée à émettre des factures (un propriétaire, un copropriétaire, ou un administrateur si **Les admins émettent des factures** est activé) ouvre les Finances : un espace sans planificateur les reçoit donc, les jours où quelqu'un regarde. L'interrupteur et la description de la fonctionnalité le disent aussi ; l'opérateur de votre serveur sait ce qui s'applique.
- La fonction **Relances de paiement** ne fait que rendre les règles disponibles. Une relance ne part toute seule que si **Relances automatiques** est activé dans les règles de relance, ce qui n'est pas le cas tant que vous ne l'avez pas choisi.
- Elles ignorent une facture dont un paiement est en attente ou suspendu, et une facture sans délai de paiement enregistré.
- Le membre reçoit une alerte dans son fil et, si les notifications push sont configurées, une notification générique ; voir [Informer les gens](help:setup.notify.overview).

**Voir aussi:** [Conditions de paiement](help:user.money.legal.payment-terms)

<!-- anchor: setup.money.vat -->
### La TVA en résumé

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez savoir ce que la TVA va vous demander avant de l'activer.

<p><img src="images/setup-money-vat--rates.fr.jpg" width="280"></p>

**Étapes**

1. Seulement si vous êtes assujetti à la TVA, activez **Gestion de la TVA** dans [Fonctionnalités](help:user.features.switch).
2. Réglez les taux dans [TVA](app:/vat) : **Utiliser les taux usuels** de votre pays, puis marquez-en un seul comme taux par défaut (voir [Régler les taux](help:user.money.vat.rates)).
3. Donnez à chaque taux son groupe, et un motif d'exonération là où il s'applique (voir [Groupes de TVA](help:user.money.vat.groups)).
4. Quand la loi change un taux, utilisez **Changement par la loi** pour que les anciennes factures gardent leur taux (voir [Changer un taux par la loi](help:user.money.vat.change-by-law)).
5. Si vous devez déposer des déclarations, activez **Déclarations de TVA** et générez chaque période dans [Déclaration de TVA](help:user.money.vat.declaration).

**Bon à savoir**

- Un catalogue de taux est fourni pour les États membres de l'UE, la Suisse, la Norvège et le Canada. Le tenir à jour quand un gouvernement modifie un taux relève de vous.
- Si vous êtes assujetti sans taux par défaut en vigueur, le serveur refuse d'émettre. La description de **Gestion de la TVA** et l'avertissement de l'écran d'identité légale le disent.
- Une déclaration est une aide au dépôt, établie à partir de vos factures émises. Vérifiez-la avant de la déposer, et ne la marquez comme déposée qu'une fois que c'est fait.
- Le journal des déclarations a sa propre série de numéros.

**Voir aussi:** [Régime de TVA](help:user.money.vat.regime) · [Quand la TVA devient exigible](help:user.money.vat.due)

<!-- anchor: setup.money.permanent -->
### Ce qui ne se défait pas

**Public:** Propriétaire

Vous voulez savoir, avant la première facture, ce que vous ne pourrez plus changer ensuite.

<p><img src="images/setup-money-numbering.fr.jpg" width="280"></p>

> **Attention** À partir de la première facture émise, les éléments ci-dessous sont définitifs. Décidez-les d'abord avec votre expert-comptable.

| Décision | Ce qui devient définitif | Quand |
|---|---|---|
| Une facture émise | Elle est signée et immuable : montants, parties, ventilation de TVA et calcul du tarif restent tels qu'imprimés. Une correction est une annulation, un avoir ou un remboursement, chacun étant un nouveau document. | À l'émission |
| Numéro de facture | Les numéros se suivent sans trou et sont attribués dans la base de données au moment de l'émission. Le prochain numéro peut être relevé, jamais abaissé. Un changement de format s'applique à partir de là. Une remise à zéro ne peut pas être plus fréquente que la date que le numéro imprime. | À la première émission |
| Un mois facturé | Un mois comportant une facture pour un membre est clos pour ce membre. Les jours de fermeture et les imports de jours fériés ignorent ces mois et les nomment. | À la première facture de ce mois |
| Taux de TVA | Les taux sont versionnés par date, jamais modifiés. Une déclaration de TVA soumise n'est jamais recalculée. | À la première utilisation |
| Devise et pays | Les montants sont stockés en unités mineures entières, sans conversion. Dès que l'espace a émis un document ou enregistré de l'argent, le serveur refuse de changer l'un ou l'autre. | Au premier document ou paiement |

**Étapes**

1. Ouvrez [Séquences de numérotation](app:/settings/number-sequences) et réglez le préfixe, le suffixe, la partie date, les chiffres et la remise à zéro pour chaque journal (factures, avoirs, déclarations de TVA, membres, paiements). L'écran demande la fonction **Séquences de numérotation**.
2. Montrez le résultat à votre expert-comptable avant la première facture.
3. Choisissez le pays, la devise et le fuseau horaire dans [Réglages de l'espace](help:user.workspace.settings.country) avant que quiconque réserve.

**Bon à savoir**

- Les numéros ne sont pas gaspillés : un document dont l'émission échoue n'en prend aucun.
- Les deux états d'un espace, test et production, existent pour que rien de tout cela ne soit essayé pour de vrai ; voir [une répétition sans risque](help:setup.money.dry-run).

**Voir aussi:** [Le registre des factures](help:user.invoicing.register) · [Devise et fuseau horaire](help:user.workspace.settings.currency-timezone)

<!-- anchor: setup.money.dry-run -->
### Une répétition sans risque dans un espace de test

**Public:** Propriétaire

Vous répétez une fois toute la routine financière, sans rien risquer de réel.

**Étapes**

1. Créez ou ouvrez un espace de test (**Un espace de test**, ou le côté DEV d'une paire liée) ; voir [Espace de test](help:user.advanced.test-space) et [Environnements](help:user.advanced.environments).
2. Saisissez l'identité légale, les taux, le tarif et les instructions de paiement tels que vous comptez les utiliser.
3. Invitez deux ou trois personnes à réserver quelques jours ; ajoutez un service pour l'une d'elles.
4. Parcourez l'[assistant de clôture du mois](help:user.invoicing.wizard) du début à la fin et lisez le PDF de la facture.
5. Enregistrez un paiement, laissez une relance arriver à échéance, et lisez le relevé comme le membre.
6. Montrez les PDF et l'export comptable à votre expert-comptable.

**Bon à savoir**

- Un espace de test met un filigrane sur chaque document et indique qu'il s'agit d'un test ; rien n'est dû.
- Déclarer un espace en production retire le filigrane ; les factures déjà émises gardent le leur.
- La paire peut tirer la configuration d'un côté vers l'autre, mais les identifiants ne voyagent pas.

**Résultat**

Un premier mois que vous avez déjà vu, et une liste de questions réglées avant qu'elles ne coûtent quoi que ce soit.

**Voir aussi:** [Les deux environnements](help:user.advanced.environments) · [Exports comptables](help:user.invoicing.accounting-export)
