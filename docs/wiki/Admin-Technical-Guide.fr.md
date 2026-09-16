# Guide administrateur — le côté technique

Pour la personne qui fait tourner un espace DesKilo : les documents
qu'il imprime, les fichiers qu'il échange, les services auxquels il
parle, et la base de données en dessous. La configuration de tous les
jours est dans le [guide de configuration](Admin-Configuration-Guide.fr) ;
ce qu'un membre voit est dans le [guide utilisateur](Guide-utilisateur).

*Un emplacement marqué `<!-- image: … -->` est une capture d'écran que la
chaîne n'a pas encore reçue.*

<!-- anchor: admin.reports.overview -->
## Documents et rapports

Tout ce que DesKilo imprime — une facture, une relance, un courrier
adhérent, un rapport de consommation, une déclaration de TVA, une
planche de badges — sort d'un seul moteur. Un **type de document** le
nomme ; une **conception** dit à quoi il ressemble ; les **données** que
l'app lui remet sont un vocabulaire fixe d'espaces réservés.

<p><img src="images/admin-reports-editor.jpg" width="240"></p>

*L'éditeur de rapports : les sélecteurs de langue et de document en haut, les commutateurs Balisage / Visuel et Conception / Aperçu en dessous, et les bandes de la facture — en-tête, corps, pied — plus bas.*

<!-- anchor: admin.reports.kinds -->
### Les types, et les quatre modèles

Chaque type (facture, avoir, proforma, relevé, convention, paiements,
consommation, TVA, espace) part de l'un des quatre modèles — *Simple*,
*Classique*, *Détaillé*, *Lettre formelle* — qui ne diffèrent que par la
quantité de choses qu'ils disent, jamais par ce que la loi exige.

<!-- anchor: admin.reports.bands -->
### Les bandes : en-tête, suite, corps, pied

La façon rapide de concevoir. Quatre bandes de balisage, chacune avec
son rôle :

| Bande | Où elle s'imprime |
|---|---|
| **en-tête** | en haut de la page 1 seulement — le papier à en-tête |
| **suite** | en haut des pages 2 et suivantes — un bandeau nommant le document |
| **corps** | la seule zone qui s'écoule : c'est elle qui continue et pagine |
| **pied** | en bas de *chaque* page |

Dans une bande, un signe par ligne décide ce qu'est la ligne :

| Signe | Ce que devient la ligne |
|---|---|
| `# ` | un titre |
| `## ` | un sous-titre |
| `- ` | une petite ligne |
| `\| a \| b \|` | une ligne de tableau ; une ligne de `---` fait de celle du dessus un en-tête |
| `---` | un filet horizontal |
| `![nom\|l\|align]` | une image de la bibliothèque, avec taille et alignement |
| (vide) | une espace |
| tout le reste | du texte courant |

Le panneau *Espaces réservés et balisage* du concepteur porte tout cela
en ligne, plus **Insérer un champ…** — le sélecteur cherchable, groupé
par thème, avec une ligne de sens sous chaque nom, cherchable par ce sens
aussi — et trois pièces toutes faites : une ligne qui ne s'imprime que si
sa valeur existe, une ligne par ligne de facture, et le titre qui dit
facture, avoir ou proforma. Ce que vous touchez atterrit au curseur de la
bande que vous avez modifiée en dernier.

<!-- anchor: admin.reports.layouts -->
### Les mises en page positionnées

La façon exacte. Une mise en page XML place chaque élément au
millimètre, pour un document qui doit satisfaire une enveloppe à fenêtre
ou un formulaire national. **Une mise en page l'emporte sur les bandes**
pour le type sur lequel elle est posée.

La racine et ses zones :

```xml
<report-layout version="1" page="A4" margin="20mm"
               margin-top="8mm" margin-bottom="8mm">
  <header height="…">…</header>
  <continuation height="…">…</continuation>
  <recipient window="fr|din|off"/>
  <body y="90mm">…</body>
  <footer height="…">…</footer>
</report-layout>
```

`margin` est la marge latérale ; `margin-top` et `margin-bottom`
séparent la marge verticale quand un document en a besoin, et valent la
marge latérale en leur absence. `<recipient>` prend une fenêtre nommée —
**fr** à 110 mm, **din** à 20 mm, toutes deux à 45 mm du haut dans une
boîte de 85 × 40 mm — ou des `x y w h` explicites, ou `off`.
`<body y="…">` est la seule zone qui s'écoule : `y` est l'endroit où
elle reprend, 90 mm sous une fenêtre.

**Les éléments**, valides dans une zone, une `<box>` ou une `<column>` :

| Élément | Ce qu'il fait |
|---|---|
| `<text style="heading\|subheading\|body\|small" align="left\|center\|right" bold="true">` | une plage de texte |
| `<image name="nom-en-bibliothèque" fit="contain\|cover\|fill" align="…"/>` | une image de la bibliothèque |
| `<table><col w="55%" align="right"/>…<row bold="true"><cell align="…">…</cell></row></table>` | un tableau à colonnes déclarées |
| `<box>…</box>` | un groupe, pour que les enfants se positionnent dedans |
| `<columns><column>…</column>…</columns>` | des groupes côte à côte |
| `<rule/>` | un filet horizontal |
| `<spacer size="4mm"/>` | de l'espace vertical |
| `<markup>…</markup>` | du balisage de bande, tel quel, dans une mise en page positionnée |

**Les attributs de cadre** — `x y w h` — s'appliquent à n'importe quel
élément. Avec `x` ou `y`, l'élément est placé en absolu dans son parent ;
sans l'un ni l'autre, il s'écoule à la suite de ses voisins.

**Les unités** sont `mm cm px pt %`. Un nombre nu est en millimètres ;
`px` est le pixel CSS (1/96 de pouce) ; `%` est relatif au parent —
largeur pour `x` et `w`, hauteur pour `y` et `h`.

<!-- anchor: admin.reports.placeholders -->
### Le vocabulaire

Tous les espaces réservés que le moteur connaît, par famille de
document, avec les boucles (`lines`, `vat`, `usage_records`, …) et les
champs que porte chaque ligne. `dart run tool/report.dart describe`
imprime la liste courante — elle est générée depuis le registre que lit
le moteur de rendu, elle ne peut donc jamais être périmée.

<!-- anchor: admin.reports.operators -->
### Liquid : conditions, boucles, filtres

Liquid passe sur tout le fichier **d'abord**, avant que le XML ne soit
analysé : une condition peut donc s'ouvrir dans un élément et se fermer
dans un autre. Les valeurs sont échappées XML à l'entrée.

| Forme | Ce qu'elle fait |
|---|---|
| `{{ champ }}` | imprime la valeur, échappée |
| `{% if champ != "" %}…{% endif %}` | n'imprime le bloc que si le champ a une valeur |
| `{% if a == b %}…{% else %}…{% endif %}` | la forme à deux branches |
| `{% unless champ == "" %}…{% endunless %}` | la forme niée |
| `{% for line in lines %}…{% endfor %}` | un passage par ligne d'une boucle |
| `{{ forloop.index }}` | le numéro de ligne, à partir de 1, dans une boucle |

**La règle qui piège tout le monde :** chaque espace réservé que le
moteur connaît est initialisé **vide**, jamais nul. Un champ absent vaut
`""`, donc `{% if x != "" %}` se comporte bien et une conception
n'imprime jamais le mot `nil`. Les textes du propriétaire
(`text.<clé>`) sont initialisés de la même façon par leur propre table
de valeurs par défaut.

**Les boucles et leurs lignes.** `lines` donne `label, kind, pct, month,
qty, unit_price, net, vat_rate, amount, negative`. `month` est le mois
de la position d'abonnement, déjà traduit dans la langue du document —
c'est pour cela qu'une ligne de facture peut se lire *septembre 100 %*.
`vat` donne la ventilation par taux, `usage_records` les demi-journées,
`vat_positions` et `vat_rate_totals` les lignes propres à la
déclaration.

<!-- anchor: admin.reports.window -->
### Le contrat de l'enveloppe à fenêtre

Une lettre qui part dans une enveloppe à fenêtre a une géométrie, et ce
n'est pas une affaire de goût :

| Chose | Où |
|---|---|
| ligne expéditeur | à 20 mm de la gauche, 20 mm du haut |
| bloc destinataire | à 110 mm de la gauche, 45 mm du haut, dans 85 × 40 mm |
| corps | reprend à 90 mm |
| pied | sur chaque page |
| bandeau de suite | à partir de la page deux |

Rien d'autre que le destinataire ne doit poser d'encre dans la bande de
la fenêtre. C'est **prouvé sur le PDF produit**, pas à l'œil : le
contrôle mesure les positions d'encre du fichier produit et sort en
erreur quand quelque chose atterrit là où est la fenêtre.

<!-- anchor: admin.reports.cli -->
### La ligne de commande

```
dart run tool/report.dart check <layout.xml> [--data data.json]
dart run tool/report.dart render <layout.xml> [--data data.json] -o out.pdf
dart run tool/report.dart sample --kind invoice > data.json
dart run tool/report.dart describe
```

- **check** rend la conception et la mesure contre le contrat de la
  fenêtre. Sortie 0 : conforme ; sortie 1 : de l'encre dans la bande de
  la fenêtre, et elle dit quel élément ; sortie 2 : la conception n'a pas
  pu être lue, et elle nomme l'élément qui a cassé.
- **render** produit le PDF, pour qu'une conception puisse être relue
  sans l'app.
- **sample** écrit un fichier de données portant tous les espaces
  réservés que le moteur connaît, ce qui est la façon la plus rapide de
  voir comment un champ s'appelle.
- **describe** imprime le vocabulaire ci-dessus — zones, éléments,
  attributs de cadre, unités, Liquid et la liste des espaces réservés.
  Il est généré depuis le registre que lit le moteur de rendu : il ne
  peut pas diverger du moteur.

La CLI est en Dart pur et doit le rester : elle n'importe rien de Flutter
ni des localisations, et un test casse à la seconde où un fichier de
domaine qu'elle utilise tire `AppLocalizations` avec lui.

<!-- anchor: admin.einvoice.overview -->
## Facturation électronique

Une facture quitte DesKilo sous forme d'un PDF qu'une personne lit et
d'un fichier structuré qu'une machine lit, et les deux disent la même
chose parce qu'ils sont produits depuis le même document gelé.

<!-- anchor: admin.einvoice.formats -->
### CII, UBL, Factur-X

Tous les trois sont la même facture exprimée de trois façons, et tous
les trois satisfont **EN 16931**, le modèle sémantique européen qui dit
quels faits une facture doit porter (BT-1 le numéro, BT-48
l'identifiant de TVA de l'acheteur, et ainsi de suite).

| Format | Ce que c'est |
|---|---|
| **CII** | UN/CEFACT Cross Industry Invoice — la syntaxe XML que prend Chorus Pro |
| **UBL** | OASIS Universal Business Language — la syntaxe que prend Peppol |
| **Factur-X** | un PDF/A-3 avec le XML CII *embarqué dedans* — un seul fichier qu'une personne lit et qu'une machine analyse |

Factur-X est la raison pour laquelle le PDF et le XML ne peuvent pas se
contredire : c'est le même fichier. Quand une plateforme les veut
séparés, les deux sont produits depuis l'unique document gelé, jamais
regénérés depuis les données vivantes.

<!-- anchor: admin.einvoice.readiness -->
### Le contrôle de recevabilité

Avant toute transmission, l'app vérifie le document contre la norme et
**refuse en nommant ce qui manque**, parce qu'une facture rejetée par
une plateforme coûte plus cher à réparer qu'une facture jamais envoyée.

Ce qu'il refuse :

- un vendeur sans l'identifiant que le régime exige — un numéro de TVA
  quand vous facturez de la TVA, un numéro d'immatriculation quand vous
  n'en facturez pas ;
- un document en **autoliquidation** dont le client n'a pas de numéro de
  TVA : ce numéro est ce qui prouve que la taxe est la sienne ;
- une exonération sans motif et sans valeur par défaut du pays sur
  laquelle se rabattre ;
- un numéro de TVA client dont la **forme ne correspond pas à son
  pays** — un avertissement, pas un refus, puisque les formes changent ;
- un acheteur sans adresse, dès lors que la destination en exige une.

Les adhérents renseignent eux-mêmes leur pays et, quand ils facturent en
tant qu'entreprise, leur numéro de TVA, à côté de leur adresse dans
*Réglages → Informations personnelles*.

<!-- anchor: admin.einvoice.platforms -->
### Plateformes et identifiants

Un document peut partir vers **deux destinations à la fois** : la
plateforme publique que votre pays impose, et le service propre au
client. Les deux se configurent sur l'espace, et l'une ou l'autre peut
être désactivée.

Les identifiants vivent sur l'espace, jamais dans le fichier d'espace ni
dans un déploiement — un export que vous envoyez à un collègue emporte la
configuration et pas les clés. Un **espace de développement utilise
toujours le point de terminaison de test**, qui ne peut physiquement pas
atteindre une plateforme publique : une facture de test ne peut donc
jamais devenir réelle.

Chaque tentative est consignée dans l'historique de transmission de la
facture elle-même : quand, vers quelle destination, ce que la plateforme
a répondu, et la référence qu'elle a renvoyée. Une transmission échouée
laisse la facture intacte et re-tentable — le document est gelé, la
transmission n'en fait pas partie.

<!-- anchor: admin.exports.accounting -->
## Exports comptables

Trois formats, un seul grand livre en dessous :

| Format | Où il est demandé | Ce qu'il porte |
|---|---|---|
| **FEC** | France (art. A47 A-1 LPF) | toutes les écritures de la période, dans l'ordre de colonnes imposé |
| **SAF-T** | la norme OCDE, plusieurs pays de l'UE | le fichier d'audit : comptes, écritures, documents |
| **DATEV** | Allemagne, pour le logiciel du conseil fiscal | les écritures dans la disposition que DATEV importe |

Tous les trois couvrent une période que vous choisissez et utilisent le
**plan comptable** configuré sur l'espace — le compte de TVA compris,
et c'est pourquoi ce champ appartient à l'identité légale plutôt qu'à
l'export. Une période déjà exportée n'est pas verrouillée : un export
est une lecture, et il peut être repris après une correction.

<!-- anchor: admin.integrations.overview -->
## Intégrations

| Intégration | Ce qu'elle fait | Sans elle |
|---|---|---|
| **Prestataire de paiement** | encaisse un paiement contre une facture | les paiements sont saisis à la main ; rien d'autre ne change |
| **Canal WhatsApp** | envoie une relance ou un avis sur WhatsApp | le message reste dans la boîte de l'app |
| **Push** | délivre les notifications à un appareil | les notifications apparaissent à l'ouverture de l'app |
| **Plateforme de facturation électronique** | transmet la facture structurée | le PDF est produit et envoyé par d'autres moyens |

Deux règles valent pour toutes. **Les identifiants vivent sur l'espace**,
dans une table que le fichier d'espace et tous les déploiements sautent :
aucun export n'emporte donc de clé. Et **une intégration non configurée
se dégrade, elle ne casse pas** : la fonctionnalité qui en a besoin est
désactivée, l'écran le dit, et rien ne lève d'exception.

<!-- anchor: admin.instances.overview -->
## Instances

Une **instance** est un DesKilo entier sur sa propre base de données.
Deux espaces — même une paire développement et production — en partagent
une ; deux instances ne partagent rien. Utilisez-en une là où des données
personnelles ou des identifiants de paiement doivent être physiquement
séparés, ou là où un client exige sa propre base.

Le **bundle** est la matière première de l'instance : toutes les
migrations dans l'ordre, les fonctions edge, les compartiments de
stockage et l'amorce. Il est regénéré à chaque migration appliquée : le
bundle et la base vivante ne sont donc jamais désaccordés.

Créez une instance depuis l'assistant de l'app ou depuis
`dart run tool/instance.dart` ; les deux appliquent le bundle à une base
vide et estampillent la migration à laquelle elle se tient. Une migration
ultérieure atteint une instance existante de la même façon — appliquée
dans l'ordre à partir de l'estampille, jamais rejouée.

La configuration et les données de référence voyagent entre instances par
le **fichier d'espace**, puisqu'un déploiement a besoin d'une seule base
et qu'une instance est précisément le moment où il y en a deux.

<!-- anchor: admin.trace.overview -->
## Le journal

*Réglages → Développeur.* Un tampon circulaire des 500 dernières
entrées, adossé à un fichier sur l'appareil, avec toutes les erreurs du
framework et de la plateforme branchées dessus dès la première ligne de
`main()`.

Trois formes, et celle du milieu est la utile :

- **step** — une décision ou un aller-retour serveur qui s'est passé
  comme prévu.
- **refused** — l'app qui décline ce que quelqu'un a cherché à faire.
  Niveau avertissement, et la première chose à chercher quand le rapport
  est *« j'ai appuyé et il ne s'est rien passé »*.
- **failed** — une exception, portant les mêmes champs que le step qui
  l'a provoquée, pour qu'une ligne rouge ne soit jamais orpheline de son
  contexte.

Chaque ligne est un verbe suivi de paires `clé=valeur` : un journal se
grep donc. `grep 'act=check-in'` lit un type de tentative de bout en
bout, et `grep 'server='` lit tous les refus émis par le serveur, avec
son code, son message, ses détails et son indice dans un seul champ.

**Un journal est par appareil.** Le journal qui répond à *« un adhérent
n'a pas pu pointer »* est sur le téléphone de cet adhérent. *Exporter*
l'écrit dans un fichier estampillé de la version de l'app et de
l'espace, ce qui est ce qui rattache un journal exporté au signalement
auquel il répond. Les charges utiles scannées sont consignées par
**forme** — schéma, hôte, quels paramètres sont présents, quelle
longueur — jamais par valeur, parce qu'un code d'invitation est un secret
et qu'un journal est fait pour être envoyé à quelqu'un.

**Un « started » sans « done » correspondant** signifie que l'acte n'est
jamais revenu : l'app a été tuée, la requête n'est jamais rentrée, ou un
`await` est suspendu. Ce trou est la trouvaille.
