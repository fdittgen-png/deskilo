# Environnements — un espace pour essayer, un espace qui est réel

Deux espaces, un seul nom. Sur l'un vous configurez, importez, imprimez
et cassez des choses ; sur l'autre des gens réservent des places et
reçoivent des factures qui sont dues. Ce que vous arrêtez sur le
premier, vous le déployez sur le second.

<!-- anchor: env.pair.why -->
## Pourquoi un couple

Un espace de coworking est configuré par la personne qui le tient, pas
par un intégrateur, et la configuration est l'endroit où les erreurs
sont bon marché à commettre et chères à découvrir : un tarif saisi deux
fois, un taux de TVA sur le mauvais groupe, un plan dont les places ont
bougé après que des gens les ont réservées. Un espace de développement
ne coûte rien et absorbe tout cela. Chaque document qu'il imprime porte
le **filigrane de développement**, ses factures électroniques partent
vers le point de test, et rien de ce qu'il produit ne peut être pris
pour un document réel.

<p><img src="images/env-pair-profiles.jpg" width="240"></p>

*L'écran Profils : un espace apparié porte DEV et PROD sur une seule ligne — un espace, deux environnements, et la coche indique celui où vous vous trouvez.*

<!-- anchor: env.pair.create -->
## Créer le couple

Un nouvel espace est créé **avec son jumeau** : même nom, même pays,
même monnaie, même fuseau horaire, les deux à vous dès la première
seconde. *Profils* affiche le couple comme une seule carte à deux
puces, **DEV** et **PROD** ; toucher une puce change de côté, et ce
choix devient votre défaut, si bien qu'un redémarrage vous ouvre là où
vous étiez.

Un espace créé avant l'existence des couples, ou créé seul, reçoit son
jumeau à la demande : *Réglages → Avancé → Créer son jumeau*. La
configuration est copiée une fois à cet instant ; ensuite les deux
côtés sont indépendants et seul un déploiement fait passer quelque
chose de l'un à l'autre.

<!-- anchor: env.pair.permissions -->
## Qui a le droit de quoi

Trois permissions dans la matrice des rôles :

- **Accéder à l'espace de production** — sans elle, un rôle ne peut pas
  être membre du côté production du tout. Les propriétaires et
  copropriétaires l'ont ; les administrateurs l'ont ; les membres ne
  l'ont pas tant que vous ne la donnez pas.
- **Déployer en développement** — tirer la configuration du côté
  production vers celui de développement. Les administrateurs l'ont.
- **Déployer en production** — la permission sensible, propriétaire et
  copropriétaire seulement par défaut. Qui la détient détient aussi
  *Déployer en développement*.

Deux règles en découlent. **Un membre du côté production est toujours
membre du côté développement** : l'adhésion est reflétée, rôle et
statut compris, donc personne n'a besoin d'être invité deux fois. Et
**un rôle n'entre du côté production que tant qu'il détient la
permission d'accès** — une invitation, une adhésion ou une reprise de
profil vers la production est refusée sinon, avec la raison à l'écran.

<!-- anchor: env.work.configure -->
## Travailler du côté développement

Configurez, importez un fichier d'espace, invitez un collègue, émettez
une facture d'essai, déplacez des places, imprimez. Rien là n'est réel :
le filigrane le dit sur chaque document, et le point de test des
factures électroniques refuse d'atteindre une plateforme
gouvernementale.

<!-- anchor: env.deploy.screen -->
## Déployer

*Réglages → Administration → Déploiement*, du côté que vous voulez
**écrire**. Un déploiement va toujours **dans le côté où vous vous
tenez** : du côté production le bouton dit *Tirer depuis la DEV*, du
côté développement *Tirer depuis la PROD*. Rien ne peut être poussé sur
l'autre côté par erreur.

<p><img src="images/env-deploy-screen.jpg" width="240"></p>

*L'écran Déploiement vu du côté développement : la phrase en haut nomme le sens, et ce que vous cochez est tiré du jumeau de production — après un aperçu.*

<!-- anchor: env.deploy.entities -->
### Ce qui voyage, entité par entité

Groupé en **Configuration**, **Données de base** et **Rapports** :

| Groupe | Entités |
|---|---|
| Configuration | Identité et mentions légales · Règles de réservation · Règles de validation · Matrice des rôles · Règles de relance · Instructions de paiement · Liens de documents · Jours de fermeture · Modèles d'invitation · Fonctionnalités |
| Données de base | TVA · Tarifs · Services · Forfaits · Accessoires · Sites · Plans |
| Rapports | Conceptions de documents, avec leurs images |

Cochez-en une et ce dont elle a besoin se coche avec elle — les
services ont besoin des taux de TVA, un plan a besoin de ses
accessoires et de ses sites.

<!-- anchor: env.deploy.plan -->
### Le plan est fusionné, jamais remplacé

Les étages correspondent par nom, les bureaux, tables et places par nom
ou, sans nom, par position. Ce que l'autre côté a est ajouté ou mis à
jour ; ce que seul ce côté a est signalé et **conservé**, car une place
peut déjà porter une réservation. Les badges et les blocages ne voyagent
jamais. Les fonds et les images du plan sont copiés avec.

<!-- anchor: env.deploy.preview -->
### L'aperçu, puis la confirmation

Rien ne bouge avant qu'un aperçu dise, par entité, ce qui serait
ajouté, modifié et retiré. Un aperçu sans rien à faire le dit et ne
déploie rien. Puis une confirmation nomme le côté qui va être écrit et
les entités, car c'est le moment où une erreur devient chère.

<!-- anchor: env.deploy.journal -->
### Le journal et le retour en arrière

Chaque déploiement est enregistré : qui, quand, dans quel sens, quelles
entités, et ce que la cible contenait avant. *Revenir en arrière* sur le
dernier restaure exactement cela. Un retour en arrière est refusé tant
qu'un déploiement plus récent tient le même côté — défaites-les dans
l'ordre.

<!-- anchor: env.deploy.never -->
### Ce qui ne voyage jamais

Les membres, les réservations, les comptes, les factures, les paiements,
les événements, les messages, les identifiants de toute sorte, et les
compteurs de numérotation. Une série de numéros se déploie comme un
**format** ; le numéro suivant appartient toujours à l'espace qui
l'émet.

<!-- anchor: env.instances -->
## Quand un couple ne suffit pas

Deux espaces partagent une base de données. Là où des données
personnelles ou des identifiants de paiement doivent être physiquement
séparés, appariez plutôt des **instances** : l'assistant de nouvelle
instance construit une seconde base à partir du paquet, et les mêmes
entités voyagent entre les deux par le fichier d'espace.
