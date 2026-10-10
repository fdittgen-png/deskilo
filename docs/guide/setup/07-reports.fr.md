<!-- anchor: setup.reports.overview -->
## Documents et rapports

**Public:** Propriétaire · Copropriétaire · Administrateur·rice facturation

Tout ce que DesKilo imprime ou exporte vient d'un seul moteur et d'un seul endroit pour le concevoir. Ce chapitre vous dit quels documents existent, dans quel ordre les préparer, ce que vous pouvez remettre à votre expert-comptable, et où un assistant IA peut vous aider et où il ne doit pas décider. Les clics sont dans le guide d'utilisation ; ici, vous trouvez les raisons et l'ordre.

L'exemple qui sert de fil conducteur est l'espace de démonstration *Atelier du Marché*.

<!-- anchor: setup.reports.documents -->
### Les documents que produit l'app

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez savoir ce qui existe avant de concevoir quoi que ce soit, et qui reçoit chaque document.

<p><img src="images/setup-reports-hub.fr.jpg" width="280"></p>

Chaque document est d'un certain *type*. Chaque type a sa propre conception : modifier la facture ne change donc jamais le relevé.

| Document | Qui le reçoit | Où le trouver |
|---|---|---|
| Facture et avoir (une conception commune) | Le membre, ou le client d'un mois facturé | [Facturation](help:user.invoicing.hub) |
| Proforma | Un membre qui a besoin d'un devis ou d'une demande d'acompte | Même écran |
| Relevé | Le membre (son compte sur une période) | [Le relevé](help:user.money.statement) |
| Accord | Le membre (les conditions négociées) | [Négociation des prix](help:user.money.negotiation) |
| Paiements, utilisation | Le membre, l'administrateur·rice facturation | [Paiements](help:user.money.payments) · [Utilisation](help:user.money.usage) |
| Lettres de relance, niveau 1 à 9 | Le membre dont une facture est en retard | [Règles de relance](help:user.money.reminders.rules) |
| Rapport de l'espace et état de l'espace | Vous, le bureau, un auditeur | **Rapports** |
| Déclaration de TVA | Vous, puis la plateforme fiscale | [La déclaration de TVA périodique](help:user.money.vat.declaration) |
| Badges, codes QR des espaces | Les membres à la porte, vos murs | [Codes QR des espaces](help:user.workspace.export.space-qr) · [Badges](help:user.badges.nfc) |

**Bon à savoir**

- L'écran **Rapports** les regroupe sous **Rapports financiers**, **Documents de l'espace**, **Analyse d'activité** et **Modèles**, selon vos droits.
- Quelques rapports (plan comptable, badges, cartes QR) ont une seule mise en page fournie. Les autres peuvent être redessinés.
- Les documents tirés d'un espace de test portent un filigrane qui l'indique. Voir [À quoi sert un espace de test](help:user.advanced.test-space).

**Voir aussi:** [Rapports](help:user.money.reports) · [Le modèle PDF de facture](help:user.money.reports.invoice-template)

<!-- anchor: setup.reports.designer -->
### Le concepteur, expliqué au propriétaire

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez un courrier qui vous ressemble sans apprendre un langage de balisage.

<p><img src="images/setup-reports-professional.fr.jpg" width="280"></p>

Un document est une page faite de **bandes**. L'*en-tête* porte votre papier à en-tête et le destinataire. Le *corps* porte les lignes. Le bandeau de *suite* commence à la page deux, et le *pied de page* se répète sur chaque page avec vos conditions de paiement et vos mentions légales. Vous les modifiez dans **Conception** et les vérifiez dans **Aperçu** ; **Balisage** montre les mêmes bandes sous forme de texte, pour le jour où vous en avez besoin.

| Élément | Ce qu'il vous apporte | À choisir quand |
|---|---|---|
| Modèles prêts à l'emploi (**Professionnel**, **Classique**, **Simple**, **Détaillé**, **Lettre formelle**) | Une conception terminée pour démarrer. Les modèles diffèrent pour les factures, proformas, relevés, accords et relances ; les documents structurels ont une seule mise en page fournie | Toujours : partez de **Professionnel** et changez peu de choses |
| Une conception par langue | Un membre lit le document dans sa propre langue | Vos membres ne lisent pas tous la même langue |
| Papier à en-tête et enveloppe à fenêtre | Expéditeur, destinataire et corps placés là où une enveloppe à fenêtre les attend | Vous envoyez vos factures par courrier |
| Mise en page positionnée (XML) | Chaque élément placé au millimètre, pour un formulaire national | Un document doit respecter un formulaire fixe |
| Bibliothèque d'images | Un logo, un tampon ou une signature réutilisés dans plusieurs conceptions | Vous avez un logo |
| Échange de conceptions | Une conception écrite dans un fichier puis relue | Une personne ou un outil extérieur à l'app la modifie |

Deux faits vous évitent les surprises. La norme de courrier imprime le destinataire dans la fenêtre à droite pour un espace français et à gauche pour un espace allemand, sauf si vous la modifiez. Et une conception qui ne s'affiche pas ne bloque jamais un document : la mise en page intégrée prend le relais.

> **Attention** Les termes d'une conception ne sont pas un conseil juridique. L'apparence et la traduction ne suffisent pas à établir la conformité légale ni à satisfaire une obligation de facturation électronique. Ce qu'une facture doit mentionner se décide sous [Votre identité légale](help:user.money.legal.identity), et se confirme avec votre expert-comptable.

**Voir aussi:** [L'éditeur de rapports](help:user.money.reports.editor) · [Modèles prêts à l'emploi](help:user.money.reports.presets) · [Une conception par langue](help:user.money.reports.languages)

<!-- anchor: setup.reports.sequence -->
### L'ordre à suivre

**Public:** Propriétaire · Administrateur·rice facturation

Vous allez concevoir des documents et vous voulez le faire une seule fois, dans le bon ordre.

<p><img src="images/setup-reports-presets.fr.jpg" width="280"></p>

**Étapes**

1. Fixez d'abord votre identité légale : type d'organisation, adresse, immatriculation, régime de TVA et mentions particulières. Une conception n'imprime que ce que vous y avez saisi. Voir [Votre identité légale](help:user.money.legal.identity).
2. Ouvrez l'[Éditeur de rapports](app:/report-editor), choisissez le document et partez de **Professionnel** sous **Modèles**.
3. Ajoutez une version pour chaque langue que lisent vos membres. Choisissez **EN**, **FR**, **DE**, **ES** ou **IT** sous le document. Voir [Une conception par langue](help:user.money.reports.languages).
4. Vérifiez chacune avec **Aperçu rapide**. Il utilise votre facture la plus récente, ou des données d'exemple s'il n'y en a pas.
5. Répétez dans un espace de test : entrez-y, émettez une facture d'essai, imprimez-la et envoyez-la à votre expert-comptable. Voir [À quoi sert un espace de test](help:user.advanced.test-space).
6. Figez la conception avant la première facture. Notez ce que vous avez décidé, puis ne changez une conception que lorsqu'une règle change.

**Bon à savoir**

- Le remplacement d'une mise en page peut être défait avec **Annuler** jusqu'à ce que vous quittiez l'éditeur.
- Une facture émise est un document figé. Modifier la conception plus tard change les nouveaux documents, jamais ceux déjà émis.
- Si le même texte existe en deux langues, demandez à quelqu'un qui lit la seconde langue de relire l'aperçu.

> **Attention** Le numéro de facture et les mentions légales imprimées sur une facture deviennent définitifs dès la première facture émise. Réglez-les avant, pas après.

**Résultat :** chaque document que vous enverrez vous ressemble, dans chaque langue, et a été relu une fois par quelqu'un d'autre que vous.

**Voir aussi:** [Votre identité légale](help:user.money.legal.identity) · [Le modèle PDF de facture](help:user.money.reports.invoice-template)

<!-- anchor: setup.reports.accountant -->
### Ce que vous remettez à votre expert-comptable

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez que votre expert-comptable ait ce qu'il lui faut, et qu'il sache ce que l'app ne prétend pas faire.

<p><img src="images/setup-reports-export.fr.jpg" width="280"></p>

Partez du [Registre des factures](app:/invoice-register), qui liste chaque facture avec son statut, et touchez **Export comptable**. Chaque format indique dans la fiche ce qu'il revendique.

| Fichier | Ce qu'il revendique | Ce qu'il ne revendique pas |
|---|---|---|
| FEC | Le format français qu'exige un contrôle, reconstitué à partir des factures et des paiements | Une comptabilité complète. Votre expert-comptable la complète |
| DATEV | Un fichier d'échange pour les logiciels des comptables allemands, lu et comptabilisé par une personne | Un dépôt, ou une remise pour un contrôle fiscal |
| SAF-T | La structure internationale, volontairement partielle : factures et paiements, sans grand livre | Un fichier comptable complet. Il le dit dans son en-tête |
| SAF-T PT, Sage 50 | Un format réglementaire portugais (non certifié) et un format d'échange britannique/irlandais, selon votre pays | Un dépôt ou une certification |
| CSV comptable, Piste d'audit, Archive de l'année (zip) | Une aide à la lecture pour votre expert-comptable | Un dépôt |

La liste des formats dépend de votre pays. Le FEC et le DATEV demandent vos numéros de comptes, et le FEC aussi votre numéro d'immatriculation : ayez-les à portée de main. Les chiffres de TVA de la période se trouvent dans [La déclaration de TVA périodique](help:user.money.vat.declaration).

*Ce que l'app ne fait pas*

- Elle tient les factures, les paiements et un compte courant par membre. Elle ne tient pas de comptabilité en partie double sur un plan comptable : elle ne peut donc pas remplacer un logiciel de comptabilité.
- Certaines obligations restent à vous et à votre expert-comptable : une comptabilité complète, un logiciel certifié là où votre pays l'exige, et l'acceptation par l'administration destinataire.
- Un fichier reste bloqué tant que les problèmes de la source ne sont pas corrigés.

**Bon à savoir**

- Exporter, c'est lire. Vous pouvez recommencer pour n'importe quelle période.
- Préparez une courte note pour votre expert-comptable avant la première facture : votre régime de TVA, le moment où la TVA devient exigible, la numérotation choisie et les exports que vous voudrez. Voir [L'aide d'une IA](help:setup.reports.ai).

**Voir aussi:** [Exports comptables](help:user.invoicing.accounting-export) · [Le registre des factures](help:user.invoicing.register) · [Compte de TVA](help:user.money.vat.account)

<!-- anchor: setup.reports.analytics -->
### L'analyse d'activité en résumé

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez voir comment l'espace se porte une fois lancé, sans tableur.

<p><img src="images/setup-reports-documents.fr.jpg" width="280"></p>

**Analyse d'activité** présente des chiffres par domaine : facturé et encaissé, occupation et capacité. Vous choisissez une période (mois, trimestre ou année), la comparez à une autre, enregistrez une vue et l'exportez en PDF. Vous ne voyez que les analyses que votre rôle autorise.

L'encaissé correspond aux paiements rapprochés des factures. Ce n'est pas un bénéfice, car aucun coût n'entre dans ce chiffre, et la période en cours est partielle.

Pour un document sur l'ensemble de l'espace, l'onglet **Documents de l'espace** contient le **Rapport de l'espace**, les **Codes QR des espaces (PDF)**, **Exporter les données (Excel)** et **Exporter la configuration (PDF)**. Servez-vous des deux derniers comme copie de secours avant un gros changement.

**Voir aussi:** [Analyse d'activité](help:user.invoicing.bi) · [Exports](help:user.workspace.export.workspace-report)

<!-- anchor: setup.reports.ai -->
### L'aide d'un assistant IA

**Public:** Propriétaire · Copropriétaire

Un outil de conversation IA peut vous faire gagner des heures sur les mots qui entourent votre configuration. Il ne peut pas décider de ce qui est juste sur le plan juridique ou fiscal. Cette section parle des outils que vous utilisez en dehors de DesKilo ; la connexion d'un assistant dans l'app est décrite à la fin.

*À quoi sert un outil extérieur*

- Rédiger le message d'invitation que vous envoyez à vos premiers membres. Voir [Le message d'invitation](help:user.workspace.settings.invitation-message). Les variables comme le prénom ou le lien d'invitation restent telles quelles.
- Formuler les mentions particulières que vous soumettrez à votre expert-comptable, comme brouillon à vérifier, jamais comme texte définitif.
- Traduire le texte d'une conception dans une autre langue, pour que vous n'ayez plus qu'à le relire.
- Expliquer un rapport ou un relevé à un membre avec des mots simples.
- Préparer la note de vos choix pour votre expert-comptable : pays, type d'organisation, régime de TVA, numérotation, exports.
- Esquisser l'image qui sert de fond à votre plan, à partir de photographies, dans un outil d'image.

*Ce qu'il ne doit pas décider*

- Les mentions légales d'une facture, le traitement de la TVA d'une activité, la raison pour laquelle aucune TVA n'est facturée, et les taux de TVA.
- Tout ce qui devient définitif : un format de numéro de facture, un régime de TVA, la devise, une facture émise.
- Si quelque chose est conforme ou non. Une réponse assurée n'est pas une réponse vérifiée, et c'est votre expert-comptable qui vérifie.

*La méthode sûre*

1. Demandez un brouillon à l'outil. Donnez-lui un scénario, pas les noms de vos membres ni aucune donnée personnelle.
2. Collez le brouillon dans le champ, dans l'**Éditeur de rapports** ou dans les réglages.
3. Regardez-le dans l'**Aperçu** avec des données d'exemple.
4. Envoyez le texte qui a une portée juridique à votre expert-comptable et attendez sa réponse.
5. Essayez tout le parcours dans un espace de test avant l'espace réel.

> **Attention** Ne collez jamais de jeton, de mot de passe, de numéro de compte bancaire ni de données personnelles d'un membre dans un outil extérieur.

*La connexion d'assistant propre à DesKilo*

L'app permet à un assistant tel que Claude ou ChatGPT d'agir pour un membre grâce à un protocole appelé MCP. Elle est désactivée par défaut : c'est une fonction que vous activez (**Interface MCP**, voir [Un interrupteur de fonction](help:user.features.switch)). Elle est construite en couches, pour qu'aucune personne seule ne puisse tout ouvrir.

<p><img src="images/setup-reports-assistants.fr.jpg" width="280"></p>

| Couche | Qui | Ce qu'elle fait |
|---|---|---|
| L'installation | L'opérateur | Active les assistants pour l'installation. |
| L'espace | Vous, le propriétaire | Activez la fonction, puis choisissez dans [Ce que les assistants peuvent faire](help:user.advanced.assistants-policy) quels services sont proposés et si un assistant voit uniquement les données du membre ou celles de tout l'espace. |
| La base de données | Un administrateur de base de données | Approuve la demande de chaque personne. |
| Le membre | Chaque membre | Demande une fois son approbation et choisit cet espace. |
| Une demande à conséquences | Le membre, sur son appareil | Confirme la demande exacte, qui suit encore vos règles de validation. |

L'assistant d'un membre travaille sur les propres données de ce membre : trouver et décrire des places libres, favoris et notes, réserver, modifier ou annuler sa propre réservation, demander la suppression d'une réservation commencée, s'enregistrer et se désenregistrer, lire son relevé et ses factures, et lister et traiter les validations qu'on lui demande. Quelques demandes (émission de facture, annulation de facture, remboursement, changement de statut d'un membre, part d'abonnement) sont réservées au personnel : elles exigent des droits de personnel, la confirmation de la personne dans l'app, puis vos règles de validation. Il n'a aucune opération qui configure un espace : il ne peut ni activer une fonction, ni fixer un tarif, ni changer un rôle, ni construire un plan. Il ne peut pas configurer votre espace à votre place, et il n'agit que dans ce que vous exposez.

**Bon à savoir**

- Activer les assistants n'accorde rien à personne par lui-même.
- Chaque approbation expire ; l'écran indique combien de jours il reste.
- Lisez les étapes dans [Approbations et confirmations pour les assistants](help:user.advanced.assistants-approve).

**Voir aussi:** [Les assistants : ce que c'est](help:user.advanced.assistants) · [Connecter un assistant](help:user.advanced.assistants-connect)

<!-- anchor: setup.reports.developer -->
### Travailler avec un développeur : le fichier de conception et l'outil de rapports

**Public:** Propriétaire · Opérateur·rice

Une personne technique vous aide, et une conception doit être modifiée ou éprouvée en dehors de l'app.

**Étapes**

1. Dans l'[Éditeur de rapports](app:/report-editor), utilisez **Exporter cette maquette** pour écrire la conception dans un seul fichier. Le fichier explique ce que signifient ses champs et quelles variables existent. **Importer une maquette** le relit ; un fichier destiné à un autre rapport, ou venant d'une version plus récente, est refusé avec la raison.
2. Un développeur peut éprouver la conception depuis un terminal avec l'outil de rapports, décrit dans le guide de l'administrateur technique : `check` mesure une mise en page par rapport au contrat de l'enveloppe à fenêtre et se termine par un code non nul quand de l'encre tombe dans la fenêtre ; `render` produit le PDF ; `sample` écrit un fichier de données avec chaque variable ; `describe` liste le vocabulaire.
3. De retour dans l'app, importez le fichier, prévisualisez-le avec **Aperçu rapide** et **Enregistrer**.

**Bon à savoir**

- L'échange de conceptions est une fonction (**Exporter et importer les maquettes**), parmi les fonctions de rapports de [Fonctionnalités](app:/features). Activez-la d'abord.
- L'outil a besoin du code source de l'app ; il est destiné à la personne qui fait tourner votre installation, pas à un usage quotidien.

**Voir aussi:** [L'éditeur de rapports](help:user.money.reports.editor) · [Le modèle PDF de facture](help:user.money.reports.invoice-template)
