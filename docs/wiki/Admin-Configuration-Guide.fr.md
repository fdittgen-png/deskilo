# Guide administrateur — configurer l'espace

Pour la personne qui installe l'espace : ce que décide chaque paramètre,
dans l'ordre où le questionnaire les demande, puis les données de
référence, puis le plan des locaux et ses images. Le côté technique est
dans le [guide technique](Admin-Technical-Guide.fr) ; déplacer
une configuration d'un espace de développement vers un espace de
production est dans le [guide des environnements](Environments-Guide.fr).

<!-- anchor: config.setup.questionnaire -->
## Le questionnaire d'installation

Le questionnaire web ne pose, dans l'ordre, que ce que vos réponses
précédentes rendent possible, et produit le fichier d'espace que l'app
importe. Chaque question qui s'y trouve existe comme paramètre dans
l'app, et chaque paramètre de l'app s'y trouve — cette symétrie est une
règle, pas une coïncidence.

<!-- image: config-setup-questionnaire -->

<!-- anchor: config.identity.legal -->
## Identité et mentions légales

*Réglages de l'espace → Identité légale et facturation électronique.*
Remplissez ceci avant que le premier document ne quitte la maison : une
facture qui ne nomme pas correctement son vendeur n'est pas une facture.

Le **type d'organisation** — société ou association — décide des clauses
imprimées par défaut. La pénalité de retard, l'indemnité de recouvrement
et l'escompte sont des obligations *entre professionnels* : les
documents d'une association abandonnent donc ces mentions par défaut,
tout en imprimant ce que vous y écrivez vous-même.

Ensuite, dans l'ordre : la **forme juridique et le capital** imprimés
sous le nom ; le **registre** où un lecteur peut vous vérifier (RCS et
ville pour une société, RNA W… et SIRET pour une association) ; le
**régime de TVA**, qui décide si la norme attend de vous un numéro de
TVA ou un numéro d'immatriculation ; l'**adresse structurée**, que porte
la facture électronique parce qu'une machine ne sait pas découper une
adresse d'une seule ligne de façon fiable ; et les huit mentions de
facture.

Chacun de ces champs est documenté, champ par champ, dans le
[guide utilisateur](Guide-utilisateur) au § 11a — le symbole d'aide
placé à côté ouvre exactement son paragraphe.

Les **instructions de paiement** (le bloc bancaire qu'imprime un
document) forment une entité distincte : elles se déploient donc seules
entre un espace de développement et un espace de production.

<!-- anchor: config.vat.overview -->
## TVA

Le taux que porte une prestation est décidé par trois choses, jamais par
une seule : ce qu'elle est (**le groupe**), qui l'achète (**le
traitement**) et quand elle a eu lieu (**le fait générateur**). C'est la
forme ERP, et c'est pourquoi un changement de taux ne réécrit jamais un
ancien document.

Les **taux** portent un nom, un pourcentage et un groupe fiscal, et l'un
d'eux est celui par défaut. Un taux est **versionné par date** : passer
de 20 % à 21 % ajoute une version valable à partir d'une date, cela ne
modifie pas l'ancienne. Tout document déjà émis conserve la version en
vigueur au moment de son émission, figée sur le document lui-même ;
seules les prestations datées du jour de la nouvelle version ou après
l'utilisent.

Les **groupes** sont ce qu'une prestation *est* — normal, réduit, taux
zéro, exonéré, hors champ. Un service, un tarif, un accessoire et un
forfait portent un groupe, pas un pourcentage : la table des taux d'un
pays peut donc changer sous eux sans toucher au catalogue.

Les **traitements** sont ce que la contrepartie en fait : national,
entreprise intracommunautaire (autoliquidation, le client s'impose
lui-même au titre de l'art. 196), particulier intracommunautaire,
export. Le pays et le numéro de TVA du client décident lequel
s'applique, et le contrôle de facturation électronique refuse d'envoyer
un document en autoliquidation tant que ce numéro de TVA est absent :
c'est lui qui prouve que la taxe est la leur.

**Le moment où la TVA devient exigible** est un réglage de l'espace :
*sur les débits* (exigible à l'émission) ou *sur les encaissements*
(exigible le jour où le client paie). La France place les services sur
les encaissements sauf option contraire ; l'Allemagne appelle cela
*Ist-Versteuerung*, l'Italie *IVA per cassa*. Sur les encaissements, une
période de déclaration couvre les paiements reçus à l'intérieur, un
paiement partiel porte une part de chaque taux du document au prorata,
et l'arrondi va au taux le plus large pour que le total corresponde
exactement à ce qui a été reçu.

Les **déclarations** sont construites pour une période à partir des
documents (ou des paiements) qu'elle contient, transposées dans les
cases du formulaire de votre pays — CA3 en France, UStVA en Allemagne —
et produites en PDF et en XML. Une déclaration passe de brouillon à
déposée, et une déclaration déposée n'est jamais recalculée.

Le catalogue complet des taux d'un pays est livré avec l'app (UE27, CH,
NO, CA) ; le tenir à jour quand un gouvernement change un taux vous
revient.

<!-- anchor: config.tariffs.overview -->
## Tarifs et règles de facturation

Un **tarif** est un pourcentage d'abonnement assorti d'un montant
mensuel : 25 %, 50 %, 100 % des demi-journées ouvrées du mois, chacun
avec son prix et son groupe de TVA. Un membre détient un tarif ; le
pourcentage devient un forfait de demi-journées, et le montant est ce
que coûte le mois, que le forfait soit consommé ou non.

**La demi-journée** est l'unité dans laquelle tout se compte. Ce qui en
constitue une est décidé par les heures d'ouverture et la granularité :
une matinée, une après-midi, ou un créneau de la grille que vous
définissez.

**Le dépassement** est ce qui se passe au-delà du forfait. Soit les
demi-journées supplémentaires sont refusées, soit elles sont facturées
au prix de dépassement par demi-journée, qui est un prix distinct avec
son propre groupe de TVA. Des demi-journées supplémentaires peuvent
aussi être demandées et accordées membre par membre.

**Le moment où un mois se facture** est une règle, pas une habitude : la
ligne d'abonnement est émise *avant* le mois qu'elle couvre, et les
lignes d'usage la suivent. Chaque ligne d'abonnement nomme son mois —
*septembre 100 %* — pour qu'une facture soit toujours rattachée à la
période qu'elle paie.

**L'arithmétique d'un mois est figée sur le document.** Changer le prix
d'un tarif change ce que coûtera le mois suivant ; cela ne change jamais
une facture déjà émise, et cela ne rouvre jamais un mois déjà soldé.

<!-- anchor: config.services -->
## Services

Tout ce qui se vend et qui n'est pas une place : une heure de salle de
réunion, un forfait d'impression, un casier, un abonnement au café. Un
service a un nom, un prix, un groupe de TVA et une unité, et un
administrateur peut le porter sur une facture ou le rattacher à un
forfait.

Les services se déploient entre un espace de développement et un espace
de production comme leur propre entité — et parce qu'ils portent un
groupe de TVA plutôt qu'un pourcentage, les taux de TVA voyagent avec
eux.

<!-- anchor: config.packages -->
## Forfaits journée

Une journée vendue comme un tout : un poste, un casier et deux heures de
salle de réunion, à un seul prix. Un forfait réunit des services et un
quota de place, porte son propre groupe de TVA, et apparaît sur la
facture comme une ligne unique dont les composants sont listés en
dessous lorsque la mise en page le demande.

Utilisez un forfait là où un membre ne devrait pas avoir à assembler sa
journée lui-même, et un tarif là où le mois est l'unité.

<!-- anchor: config.accessories -->
## Accessoires

L'équipement attaché à une place plutôt que vendu séparément : un second
écran, une station d'accueil, un rehausseur de bureau, un tableau blanc.
Un accessoire a un nom, un prix facultatif avec son groupe de TVA, et il
est posé sur le plan contre une place, un bureau ou une salle.

Sur le plan, un accessoire fait partie de ce qu'obtient une
réservation. Lorsqu'il porte un prix, réserver la place ajoute sa propre
ligne de facture à son propre taux — c'est pourquoi le catalogue
d'accessoires et les taux de TVA se déploient ensemble.

<!-- anchor: config.sites -->
## Sites

Plusieurs adresses sous une même organisation : laquelle un document
nomme, quelle immatriculation il porte, et comment un membre est
rattaché à l'une d'elles.

<!-- anchor: config.availability -->
## Disponibilité et règles de réservation

*Réglages de l'espace → Disponibilité.* Chaque règle définie ici est
appliquée par le serveur et non par l'écran : une règle que vous posez
tient donc même face à une app qui n'est plus à jour.

**Les jours et heures d'ouverture** définissent la journée de travail
et, avec la granularité, ce qu'est une demi-journée. **Les jours de
fermeture** sont des dates où l'espace est clos : une réservation qui en
touche une est refusée, avec ce motif nommé.

**Les jours fériés** peuvent être générés une année entière d'un coup
plutôt qu'ajoutés date par date (#1274). Choisissez l'année, lisez la
liste que le serveur propose, et confirmez — la génération n'est jamais
automatique et jamais silencieuse. Relancer une année n'ajoute rien : la
répéter est donc sans danger.

Un mois qui porte déjà une facture est **ignoré et nommé à l'écran**. Un
jour de fermeture y changerait le nombre de demi-journées incluses dans
ce mois, et donc une facture déjà émise ; la règle est appliquée dans la
base de données plutôt que dans l'écran (ADR 0025). Corriger un mois
facturé reste un acte délibéré : ajoutez le jour à la main et traitez la
facture.

Les dates viennent du serveur : la même liste alimente donc un modèle
qui configure un espace entier. Activez *Jours fériés* pour voir
l'action ; elle est désactivée tant que vous ne la demandez pas.

**La granularité** est ce que peut être une réservation — une
demi-journée, une journée entière, ou un créneau sur une grille de N
minutes. Une réservation qui ne tombe pas sur la grille est refusée, et
le pas lui est indiqué.

**L'horizon** est la distance à laquelle les réservations s'ouvrent.
**Les durées minimale et maximale** bornent une réservation. **Les
réservations simultanées** bornent le nombre qu'un membre peut détenir
ouvertes en même temps, par espace et redéfinissable par membre. Une
réservation se termine toujours le jour où elle commence.

**Les réservations passées** sont refusées sauf si vous les autorisez ;
une réservation rétroactive le jour même est légitime, parce que
quelqu'un qui s'est assis à neuf heures doit pouvoir le dire à dix.

**En dehors des heures d'ouverture** offre trois modes : *désactivé*
(refusé), *accueil spontané seulement* (une arrivée spontanée est
possible, réserver à l'avance ne l'est pas), ou *facturé* (autorisé et
compté). Chacun a sa propre phrase de refus, pour qu'un membre
apprenne quelle porte est fermée.

**Les règles de validation** décident quels actes demandent une décision
humaine — voir plus bas.

<!-- anchor: config.plan.overview -->
## Le plan des locaux

Le plan est ce sur quoi les membres réservent. Il se construit à partir
de trois formes imbriquées posées sur une image de fond, sur une grille
dont la cellule est l'unité de placement. Construisez-le dans cet
ordre : le niveau et son fond d'abord, puis les salles, puis les bureaux
et les places. Tout ce qui suit se trace par-dessus l'image, jamais de
mémoire.

<!-- anchor: config.plan.levels -->
### Niveaux

Un niveau est un étage, ou un ensemble de pièces traité comme un tout.
Il porte son **site** (l'adresse à laquelle il appartient), son **image
de fond**, et, lorsqu'il est réservable en entier, son **prix par
demi-journée** et son groupe de TVA.

*Réservable en entier* est un interrupteur sur le niveau lui-même. Sans
lui, une demande de réservation du niveau complet est refusée en
indiquant quel interrupteur manque — le refus nomme le réglage plutôt
que de blâmer le membre.

<!-- anchor: config.plan.offices -->
### Salles, bureaux et places

**Une salle** est une pièce à l'intérieur d'un niveau. **Un bureau** est
une table dans une salle ou posée librement sur le niveau. **Une place**
est un poste à un bureau — ce qu'un membre réserve réellement. Chacun a
son emprise sur la grille ; une place occupe six cellules de large et
quatre de profondeur, ce qui fixe l'échelle de tout le reste.

Une place porte son **orientation** (le sens vers lequel la chaise
regarde, pour que le plan se lise comme la pièce), son **équipement et
ses accessoires**, et ses **étiquettes** — un badge ou une étiquette NFC
rend la place scannable à la porte.

**Réservable en entier** existe aussi sur le bureau et sur la salle :
activez-le et le bureau ou la pièce se réserve en une fois plutôt que
place par place. Une réservation d'ensemble bloque ses enfants pour la
période, et une réservation d'enfant bloque l'ensemble.

**Bloquer** une place la retire du service pour maintenance sans la
supprimer : elle reste sur le plan, grisée, et toute tentative de
réservation est refusée avec ce motif. Les blocages ne voyagent jamais
d'un espace de développement vers un espace de production, parce qu'un
blocage de maintenance est un fait qui concerne un bâtiment un jour
donné.

<!-- anchor: config.plan.background -->
### L'image de fond

Un plan se lit mieux par-dessus un dessin de la pièce réelle. L'image
est propre au niveau, se place sous la grille, et ne bouge plus une fois
les places tracées dessus.

<!-- image: config-plan-background -->

<!-- anchor: config.plan.ai-image -->
### Fabriquer cette image à partir de photographies, avec une IA

Vous n'avez pas besoin du dessin d'un architecte. Photographiez la
pièce, demandez à un modèle d'image une vue en plan, et servez-vous de
sa réponse comme fond.

**Photographiez correctement.** Placez-vous dans chaque coin, tenez
l'appareil à hauteur de poitrine, et prenez une image par coin plus une
le long de chaque grand mur. Faites tenir tout le sol dans au moins deux
d'entre elles. Mesurez une chose — la longueur d'une table, la largeur
d'une porte — et notez le nombre : c'est lui qui fixera l'échelle.

**Demandez un plan, pas une image.** L'invite qui fonctionne demande une
vue orthographique de dessus, des aplats de couleur, aucune perspective,
aucune ombre, aucune personne, et le mobilier comme de simples emprises :

> À partir de ces photographies d'une même pièce, dessine-en un plan
> orthographique vu de dessus. Murs droits, angles droits exacts, aucune
> perspective et aucune ombre. Ne montre que les éléments fixes : murs,
> portes avec leur débattement, fenêtres, radiateurs, poteaux, blocs
> cuisine et sanitaires, et l'emprise de chaque grand meuble comme une
> forme pleine simplement détourée. Couleurs claires et sourdes sur fond
> blanc ; aucun texte, aucune étiquette, aucune cote, aucune personne,
> aucune décoration. La [table] de la pièce mesure [1,60] m de long —
> dessine tout à cette échelle. Produis une seule image, en [4:3], d'au
> moins 1600 pixels de large.

**Vérifiez l'échelle avant de tracer.** Importez l'image comme fond du
niveau, puis mesurez l'objet que vous avez noté contre la grille : une
place occupe six cellules de large et quatre de profondeur, et la
cellule est l'unité de placement de l'app. Mettez l'image à l'échelle
jusqu'à ce que l'objet réel corresponde à sa vraie taille sur la
grille ; tout ce qui sera tracé ensuite est alors honnête.

**Tracez, ne dessinez pas.** Posez les salles, les bureaux et les places
par-dessus l'image. Le fond guide l'œil ; ce que l'app réserve, ce sont
les places que vous posez.

**Ce qu'il ne faut pas accepter.** Une vue en perspective, un rendu avec
des ombres, un plan comportant des pièces inventées, ou un plan dont le
mobilier ne correspond pas aux photographies. Redemandez avec une invite
plus serrée plutôt que de corriger un plan faux à la main.

<!-- anchor: config.plan.images -->
### Images du plan

Des images posées *sur* le plan plutôt qu'en dessous — un logo près de
l'entrée, un panneau, la photographie d'un coin — chacune avec sa
position et sa taille sur la grille. Ce sont des décorations : rien ne
s'y réserve, et elles se placent au-dessus du fond et sous les places.

Elles voyagent avec le plan lors d'un déploiement, et le fichier
d'espace les emporte à l'export.

<!-- anchor: config.documents -->
## Bibliothèque de documents

Les fichiers que l'espace conserve et montre aux personnes autorisées à
les voir : le règlement intérieur, une attestation d'assurance, un plan
d'évacuation, un modèle de contrat de membre. Chaque document porte les
rôles qui peuvent le lire : la bibliothèque est donc un seul endroit à
visibilité par rôle, plutôt que plusieurs dossiers.

Les *mises en page* de documents — la composition d'une facture ou d'une
lettre — sont autre chose, et vivent dans le
[guide technique](Admin-Technical-Guide.fr).

<!-- anchor: config.roles -->
## Rôles et permissions

*Réglages → Rôles.* Une matrice : les rôles d'un côté, les permissions
de l'autre. Propriétaire, copropriétaire, administrateur, membre — et
chaque permission est une case que vous pouvez activer ou désactiver,
sauf celles qu'un propriétaire détient toujours.

Une permission est demandée au serveur par une seule fonction : une
permission que vous retirez est donc retirée partout à la fois. L'écran
masque le bouton, et l'appel derrière refuse de toute façon.

Les permissions d'environnement vivent ici également — *Entrer dans
l'espace de production*, *Déployer vers le développement*, *Déployer
vers la production* — et sont expliquées dans le
[guide des environnements](Environments-Guide.fr).

<!-- anchor: config.validation -->
## Règles de validation

Quels actes demandent une décision humaine avant de prendre effet, et
qui décide. Chaque domaine a sa règle : un membre qui rejoint, une
réservation supprimée, une facture passée en perte, des demi-journées
supplémentaires accordées, et les autres.

Par domaine, vous choisissez si une demande est seulement émise, et si
la demande d'un administrateur ou d'un propriétaire est **validée
automatiquement** — auquel cas l'événement est enregistré déjà réglé,
plutôt que de solliciter un validateur pour approuver sa propre action.

Une décision est toujours un événement : qui a décidé, quand, et sur
quoi. Rien n'est validé en silence, et une décision prise par le système
le dit.

<!-- anchor: config.features -->
## Fonctionnalités

Chaque fonctionnalité est un interrupteur. Ce qu'un interrupteur
désactive, ce qu'il ne désactive jamais (l'arithmétique déjà appliquée),
et le graphe de dépendances qui décide quels interrupteurs sont
disponibles.
