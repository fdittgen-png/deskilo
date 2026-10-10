<!-- anchor: user.invoicing.overview -->
## Fiscalité, facturation et comptabilité

Pour les propriétaires et les administrateurs facturation : qui vous êtes en tant que vendeur, comment la TVA est gérée, où partent les factures électroniques, à quoi ressemblent vos documents, et le rythme mensuel pour émettre, envoyer et relancer les factures.

> **Attention** DesKilo imprime ce que vous déclarez et vérifie que les informations obligatoires sont présentes. Il ne certifie ni vos factures, ni votre traitement de la TVA, ni votre comptabilité. Chaque fois qu'une section ci-dessous dit « à confirmer avec votre comptable », faites-le.

Dans ce chapitre :
- Votre identité légale et les mentions imprimées sur chaque facture
- La TVA : régime, numéro, taux, groupes et déclaration périodique
- La facturation électronique : où part la facture lisible par une machine
- Le modèle PDF de facture et l'éditeur de rapports
- Émettre et clôturer un mois : l'écran Facturation, l'assistant de clôture, le regroupement, les dépenses partagées
- Les relances de paiement
- Le registre des factures, les exports comptables et l'analyse d'activité

<!-- anchor: user.money.legal.identity -->
### Votre identité légale

**Public:** Propriétaire

Vous voulez que vos factures vous désignent correctement : qui vous êtes, comment vous êtes immatriculé et comment vous facturez la TVA.

**Étapes**

1. Ouvrez [Espace de coworking](app:/workspace-settings) et touchez **Identité légale et facturation électronique**, ou allez directement à [Identité légale et facturation électronique](app:/legal-identity).
2. Avancez de haut en bas : le régime de TVA d'abord, puis les identifiants, l'adresse et les **Mentions de facturation**.
3. Touchez **Enregistrer** en bas.

**Bon à savoir**

- L'écran n'affiche que les champs dont votre régime de TVA a besoin. Changez de régime et le formulaire suit.
- Les factures déjà émises gardent l'identité avec laquelle elles ont été signées. Un changement s'applique aux suivantes.
- Seuls les propriétaires peuvent ouvrir cet écran.

**Voir aussi:** [Régime de TVA](help:user.money.vat.regime) · [Type d'organisation](help:user.money.legal.seller-kind) · [Facturation électronique](help:user.money.einvoice.overview)

<!-- anchor: user.money.legal.seller-kind -->
### Type d'organisation

**Public:** Propriétaire

Vous dirigez soit une entreprise, soit une association à but non lucratif, et vos factures doivent le refléter.

<p><img src="images/user-money-legal-seller-kind--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Identité légale et facturation électronique](app:/legal-identity) et descendez jusqu'à **Mentions de facturation**.
2. Choisissez **Entreprise** ou **Association (loi 1901)**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Pour une association, les textes d'exemple changent (par exemple une immatriculation de type RNA plutôt qu'un registre du commerce). Les clauses de paiement imprimées dépendent de votre pays et de la qualité du client, pas du type d'organisation.
- Une association sans activité commerciale est normalement hors du champ de la TVA. L'écran vous avertit si vous choisissez « exonéré » pour une association ; confirmez le bon choix avec votre comptable.

**Voir aussi:** [Qualité du client](help:user.money.legal.customer-capacity) · [Régime de TVA](help:user.money.vat.regime)

<!-- anchor: user.money.legal.customer-capacity -->
### Qualité du client par défaut

**Public:** Propriétaire

Les clients professionnels et les particuliers n'ont pas droit aux mêmes clauses de paiement. Vous fixez la valeur par défaut de l'espace.

<p><img src="images/user-money-legal-customer-capacity--f.fr.jpg" width="280"></p>

**Étapes**

1. Dans **Mentions de facturation**, repérez **Qualité du client par défaut**.
2. Choisissez **Non précisée**, **Professionnel** ou **Consommateur**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Les valeurs légales par défaut des pénalités de retard, de l'indemnité de recouvrement et de l'escompte ne s'appliquent qu'aux clients professionnels d'un espace établi en France ; pour les autres pays, rien n'est imprimé sauf ce que vous avez écrit. Un consommateur ne reçoit jamais l'indemnité de recouvrement.
- La qualité propre à un membre l'emporte sur cette valeur par défaut.
- Chaque facture conserve les clauses avec lesquelles elle a été émise.

**Voir aussi:** [Pénalités de retard](help:user.money.legal.late-penalty) · [Indemnité de recouvrement](help:user.money.legal.recovery)

<!-- anchor: user.money.legal.legal-form -->
### Forme juridique et capital

**Public:** Propriétaire

Vos factures indiquent la forme juridique de votre entreprise et, le cas échéant, son capital social.

<p><img src="images/user-money-legal-legal-form--f.fr.jpg" width="280"></p>

**Étapes**

1. Dans **Mentions de facturation**, touchez **Forme juridique et capital**.
2. Saisissez la ligne telle qu'elle doit s'imprimer, par exemple « SARL au capital de 7 500 € » (une association écrira peut-être « Association loi 1901 »).
3. Touchez **Enregistrer**.

**Bon à savoir**

- Le texte est imprimé tel que vous le saisissez, jusqu'à 300 caractères. Vérifiez avec votre comptable la formulation exacte exigée pour votre forme juridique.

**Voir aussi:** [Registre du commerce](help:user.money.legal.registration)

<!-- anchor: user.money.legal.registration -->
### Registre du commerce (RCS)

**Public:** Propriétaire

Vous indiquez où votre organisation est immatriculée.

<p><img src="images/user-money-legal-registration--f.fr.jpg" width="280"></p>

**Étapes**

1. Dans **Mentions de facturation**, touchez **Registre du commerce (RCS)**.
2. Saisissez la ligne d'immatriculation, par exemple « RCS Saint-Brieuc 680 357 910 ». Une association peut indiquer un numéro RNA, et un SIRET si elle en a un.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Cette ligne est une mention imprimée sur le document. L'identifiant dont la facture électronique elle-même a besoin est le [numéro d'immatriculation](help:user.money.legal.legal-id) ou le [numéro de TVA](help:user.money.vat.number), selon votre régime.

**Voir aussi:** [Forme juridique et capital](help:user.money.legal.legal-form)

<!-- anchor: user.money.legal.payment-terms -->
### Modalités de règlement

**Public:** Propriétaire

Vous indiquez quand les factures sont dues.

<p><img src="images/user-money-legal-payment-terms--f.fr.jpg" width="280"></p>

**Étapes**

1. Dans **Mentions de facturation**, touchez **Modalités de règlement**.
2. Saisissez vos conditions, par exemple « Paiement sous 30 jours à compter de la date de facture ».
3. Touchez **Enregistrer**.

**Bon à savoir**

- Laissé vide, les factures impriment « Règlement à réception. »
- Un membre peut avoir ses propres modalités de règlement ; elles s'impriment alors sur ses documents à la place.
- Les relances ne lisent pas ce texte : elles comptent à partir de la date de la facture plus **Jours avant la première relance** dans les règles de relance. Les conditions de paiement sont seulement ce que le document imprime.

**Voir aussi:** [Règles de relance](help:user.money.reminders.rules)

<!-- anchor: user.money.legal.late-penalty -->
### Pénalités de retard

**Public:** Propriétaire

Vous indiquez la pénalité en cas de paiement tardif.

<p><img src="images/user-money-legal-late-penalty--f.fr.jpg" width="280"></p>

**Étapes**

1. Dans **Mentions de facturation**, touchez **Pénalités de retard**.
2. Saisissez votre clause, ou laissez le champ vide.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Laissé vide, rien n'est inventé à votre place, sauf pour un espace établi en France qui facture un client professionnel : la formulation légale s'imprime alors (trois fois le taux d'intérêt légal).
- Confirmez avec votre comptable la clause qui s'applique à votre pays.

**Voir aussi:** [Qualité du client par défaut](help:user.money.legal.customer-capacity)

<!-- anchor: user.money.legal.recovery -->
### Indemnité de recouvrement

**Public:** Propriétaire

Vous indiquez l'indemnité forfaitaire pour frais de recouvrement.

<p><img src="images/user-money-legal-recovery--f.fr.jpg" width="280"></p>

**Étapes**

1. Dans **Mentions de facturation**, touchez **Indemnité de recouvrement**.
2. Saisissez votre clause, ou laissez le champ vide.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Laissée vide, l'indemnité forfaitaire de 40 € ne s'imprime que sur les factures d'un espace établi en France à un client professionnel.
- Un consommateur ne reçoit jamais cette mention.

**Voir aussi:** [Qualité du client par défaut](help:user.money.legal.customer-capacity)

<!-- anchor: user.money.legal.escompte -->
### Escompte

**Public:** Propriétaire

Vous indiquez si un paiement anticipé donne droit à une remise.

<p><img src="images/user-money-legal-escompte--f.fr.jpg" width="280"></p>

**Étapes**

1. Dans **Mentions de facturation**, touchez **Escompte**.
2. Saisissez les conditions de votre escompte, ou laissez le champ vide.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Laissées vides, les factures d'un espace établi en France à un client professionnel impriment « Aucun escompte pour paiement anticipé. » ; ailleurs, la ligne est omise sauf si vous en rédigez une.

**Voir aussi:** [Modalités de règlement](help:user.money.legal.payment-terms)

<!-- anchor: user.money.legal.insurance -->
### Assurance professionnelle

**Public:** Propriétaire

Si votre activité vous oblige à indiquer votre assurance professionnelle, elle s'imprime sur vos factures.

<p><img src="images/user-money-legal-insurance--f.fr.jpg" width="280"></p>

**Étapes**

1. Dans **Mentions de facturation**, touchez **Assurance professionnelle**.
2. Saisissez l'assureur, le contrat et la couverture géographique tels qu'ils doivent se lire.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Il n'y a pas de valeur par défaut : un champ vide n'imprime rien.
- L'obligation de l'indiquer dépend de votre activité. Demandez à votre comptable.

**Voir aussi:** [Mentions particulières](help:user.money.legal.special-mentions)

<!-- anchor: user.money.legal.special-mentions -->
### Mentions particulières

**Public:** Propriétaire

Une ligne de votre choix qui doit figurer sur chaque facture.

<p><img src="images/user-money-legal-special-mentions--f.fr.jpg" width="280"></p>

**Étapes**

1. Dans **Mentions de facturation**, touchez **Mentions particulières**.
2. Saisissez le texte.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Rien ne s'imprime quand le champ est vide.
- Sous les mentions, lorsque la fonctionnalité **Fenêtre d'adresse** est activée, **Fenêtre d'adresse** règle l'emplacement de l'adresse du destinataire pour qu'elle apparaisse dans une enveloppe à fenêtre.

**Voir aussi:** [Le modèle PDF de facture](help:user.money.reports.invoice-template)

<!-- anchor: user.money.vat.regime -->
### Régime de TVA

**Public:** Propriétaire

Vous déclarez la situation de votre organisation au regard de la TVA. Ce choix détermine le numéro dont vos documents ont besoin.

<p><img src="images/user-money-vat-regime--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Identité légale et facturation électronique](app:/legal-identity).
2. Dans **Régime de TVA**, choisissez **Hors du champ de la TVA**, **Exonéré de TVA (franchise en base)** ou **Assujetti à la TVA (facture la TVA)**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Hors du champ de la TVA : aucun numéro de TVA n'est imprimé ; c'est le numéro d'immatriculation qui vous identifie.
- Exonéré ou assujetti : votre numéro de TVA est demandé.
- Choisir le régime est une décision fiscale, pas un réglage logiciel. Confirmez-le avec votre comptable avant d'émettre des factures.
- Dans cette version, l'app émet elle-même les factures pour les espaces établis en France ou en Allemagne, à des clients nationaux, sous le régime d'assujetti à la TVA ou hors champ. Les factures sous le régime d'exonération sont émises hors de l'app avec votre comptable.

**Voir aussi:** [Numéro de TVA](help:user.money.vat.number) · [Numéro d'immatriculation](help:user.money.legal.legal-id)

<!-- anchor: user.money.vat.reverse-charge -->
### Autoliquidation pour les entreprises de l'UE

**Public:** Propriétaire

Quand vous facturez la TVA et que vous facturez une entreprise établie dans un autre pays de l'UE, la taxe peut être due par le client.

<p><img src="images/user-money-vat-reverse-charge--f.fr.jpg" width="280"></p>

**Étapes**

1. Choisissez **Assujetti à la TVA (facture la TVA)** comme régime.
2. Activez ou désactivez **Autoliquidation pour les entreprises de l'UE**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Activée : l'app reconnaît une entreprise dotée d'un numéro de TVA dans un autre État membre. Aujourd'hui, l'app n'émet pas elle-même ces factures : vous les émettez hors de l'app avec votre comptable.
- Désactivée : désactivez-la si vous ne facturez jamais d'entreprises à l'étranger.
- L'option n'apparaît que pour le régime des assujettis à la TVA.

**Voir aussi:** [Traitement TVA d'un membre](help:user.members.vat-treatment)

<!-- anchor: user.money.vat.due -->
### Exigibilité de la TVA

**Public:** Propriétaire

La TVA de chaque facture devient exigible le jour que fixe la loi de votre pays — à l'encaissement, à l'exécution de la prestation ou à la facture. Vous gardez cette règle, ou vous choisissez l'option que votre pays permet.

<p><img src="images/user-money-vat-due--f.fr.jpg" width="280"></p>

**Étapes**

1. Choisissez **Assujetti à la TVA (facture la TVA)** comme régime.
2. Dans **Exigibilité de la TVA**, gardez la première option, la règle légale de votre pays, ou choisissez l'option que votre pays permet : **Sur les débits (à la facture)** en France, **Sur les encaissements (au paiement)** ailleurs.
3. Touchez **Enregistrer**.

**Bon à savoir**

- La règle légale pour les prestations de services : les encaissements en France ; le mois où la prestation est exécutée en Allemagne et en Espagne, les acomptes à leur encaissement ; la facture ou le paiement, au premier des deux, en Italie, au Royaume-Uni et au Canada ; la facture en Suisse.
- Sur les encaissements, une facture payée en plusieurs fois tombe dans autant de périodes que de paiements. Un avoir compte à son émission (sur les encaissements, à son remboursement), jamais dans la période de la facture qu'il corrige.
- Le choix est imprimé sur chaque facture — l'option pour les débits avec la mention légale — et pilote à l'identique la [déclaration de TVA](help:user.money.vat.declaration), le rapport de TVA et les exports FEC et DATEV. Un espace français qui n'avait jamais choisi suit les encaissements, et son propriétaire en est averti une fois.
- L'option qui vous concerne est une question fiscale pour votre comptable.

**Voir aussi:** [La déclaration périodique de TVA](help:user.money.vat.declaration)

<!-- anchor: user.money.vat.account -->
### Compte de TVA

**Public:** Propriétaire

Votre comptable veut que la TVA collectée soit comptabilisée sur un compte précis.

<p><img src="images/user-money-vat-account--f.fr.jpg" width="280"></p>

**Étapes**

1. Choisissez **Assujetti à la TVA (facture la TVA)** comme régime.
2. Saisissez votre numéro de compte dans **Compte de TVA**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- L'export comptable comptabilise la TVA collectée sur ce compte. Laissé vide, il utilise le 445710.

**Voir aussi:** [Exports comptables](help:user.invoicing.accounting-export)

<!-- anchor: user.money.vat.number -->
### Numéro de TVA

**Public:** Propriétaire

Votre numéro d'identification à la TVA figure sur vos factures et vos factures électroniques.

<p><img src="images/user-money-vat-number--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Identité légale et facturation électronique](app:/legal-identity).
2. Saisissez le numéro dans **Numéro de TVA**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Le champ apparaît pour les régimes exonéré et assujetti. Hors du champ de la TVA, il est remplacé par le numéro d'immatriculation.
- Vos membres ont leur propre numéro de TVA dans leurs réglages, pour leurs documents.

**Voir aussi:** [Numéro d'immatriculation](help:user.money.legal.legal-id)

<!-- anchor: user.money.vat.exemption-reason -->
### Motif de non-application de la TVA

**Public:** Propriétaire

Quand aucune TVA n'est facturée, la loi exige généralement que le motif soit imprimé sur la facture.

<p><img src="images/user-money-vat-exemption-reason--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Identité légale et facturation électronique](app:/legal-identity).
2. Saisissez le fondement juridique dans **Motif de non-application de la TVA**, par exemple « TVA non applicable, art. 293 B du CGI ».
3. Touchez **Enregistrer**.

**Bon à savoir**

- L'app ne peut pas savoir quel fondement s'applique à vous. Prenez la formulation exacte auprès de votre comptable.
- La formulation est imprimée sur la facture. Pour l'instant, l'app n'émet pas elle-même de factures sous le régime d'exonération : elles sont émises hors de l'app avec votre comptable.

**Voir aussi:** [Régime de TVA](help:user.money.vat.regime)

<!-- anchor: user.money.legal.legal-id -->
### Numéro d'immatriculation

**Public:** Propriétaire

Si vous êtes hors du champ de la TVA, votre numéro d'immatriculation vous identifie sur les factures électroniques.

<p><img src="images/user-money-legal-legal-id--f.fr.jpg" width="280"></p>

**Étapes**

1. Réglez **Régime de TVA** sur **Hors du champ de la TVA**.
2. Saisissez le numéro dans **Numéro d'immatriculation**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Sous les autres régimes, ce champ est remplacé par le numéro de TVA.
- Une association utilise en général son immatriculation (par exemple le RNA, ou le SIRET s'il est attribué).

**Voir aussi:** [Registre du commerce](help:user.money.legal.registration)

<!-- anchor: user.money.legal.address -->
### Adresse structurée

**Public:** Propriétaire

Une facture électronique a besoin de votre adresse en plusieurs parties distinctes, et non d'un bloc de texte.

<p><img src="images/user-money-legal-address--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Identité légale et facturation électronique](app:/legal-identity).
2. Remplissez **Rue**, **Code postal** et **Ville**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- La rue part de l'adresse déjà présente dans les réglages de votre espace : vous la complétez au lieu de la ressaisir.
- Les factures ne peuvent pas être émises sans l'adresse postale de l'espace.

**Voir aussi:** [Adresse du papier à en-tête](help:user.workspace.settings.address)

<!-- anchor: user.money.vat.rates -->
### Définir les taux

**Public:** Propriétaire · Administrateur·rice facturation

Vous listez les taux de TVA que vos factures peuvent utiliser. Ce que paient les membres ne change pas : les prix incluent la TVA, et la taxe en est extraite.

<p><img src="images/user-money-vat-rates--f.fr.jpg" width="320"></p>

**Étapes**

1. Ouvrez [TVA](app:/vat) (depuis **Identité légale et facturation électronique**, touchez **Taux de TVA**).
2. Sur une liste vide, touchez **Utiliser les taux usuels** (si votre pays dispose d'un catalogue) pour partir des taux de votre pays, ou **Ajouter un taux** et renseignez le nom et **Taux %** (de 0 à 99,99).
3. Touchez l'étoile sur un seul taux pour en faire le taux par défaut.
4. Touchez **Enregistrer**.

**Bon à savoir**

- Les taux usuels sont un point de départ. Savoir quelle prestation relève de quel taux est une question pour votre comptable.
- Le taux par défaut est utilisé par les abonnements et par tout ce qui n'a pas de taux propre.
- Un taux encore utilisé par une facture ou un service est conservé, désactivé, plutôt que supprimé.
- Sans taux par défaut en vigueur alors que vous êtes assujetti à la TVA, aucune facture ne peut être émise ; l'écran d'identité légale vous en avertit.
- Cet écran demande la fonctionnalité **Gestion de la TVA** ; l'entrée Taux de TVA de l'écran d'identité légale n'apparaît que pour le régime des assujettis à la TVA.

**Voir aussi:** [Groupes de TVA](help:user.money.vat.groups) · [Changement par la loi](help:user.money.vat.change-by-law)

<!-- anchor: user.money.vat.groups -->
### Groupes de TVA

**Public:** Propriétaire · Administrateur·rice facturation

Un groupe dit de quel type de taux il s'agit, pour que la facture le range dans la bonne catégorie.

<p><img src="images/user-money-vat-groups.fr.jpg" width="320"></p>

**Étapes**

1. Ouvrez [TVA](app:/vat).
2. Sur chaque taux, lorsque la fonctionnalité **Groupes de TVA** est activée, choisissez un **Groupe** : **Normal**, **Intermédiaire**, **Réduit**, **Super-réduit**, **Taux zéro**, **Exonéré**, **Non assujetti**, **Consigne (hors TVA)** ou **Produit à accises**.
3. Pour un groupe exonéré ou non assujetti, renseignez la **Mention d'exonération** qui apparaît.
4. Touchez **Enregistrer**.

**Bon à savoir**

- **Ce qui relève de chaque groupe** liste des exemples pour votre pays, à titre indicatif seulement.
- Une ligne hors TVA, comme une consigne remboursable, ne peut pas figurer sur le même document que des lignes taxées ; émettez-la séparément.

**Voir aussi:** [Définir les taux](help:user.money.vat.rates)

<!-- anchor: user.money.vat.change-by-law -->
### Changer un taux par la loi

**Public:** Propriétaire · Administrateur·rice facturation

Un taux change à partir d'une date donnée. Les anciennes prestations gardent l'ancienne valeur ; la nouvelle s'applique à partir de ce jour.

<p><img src="images/user-money-vat-change-by-law.fr.jpg" width="320"></p>

**Étapes**

1. Ouvrez [TVA](app:/vat) et vérifiez que le taux est enregistré.
2. Touchez le bouton **Changement par la loi** sur le taux.
3. Saisissez **Nouveau taux %** et la **Date d'effet (AAAA-MM-JJ)**.
4. Touchez **Enregistrer** dans la boîte de dialogue, puis **Enregistrer** sur l'écran.

**Bon à savoir**

- L'ancien taux se clôt à cette date et un nouveau s'ouvre, avec l'étoile déplacée s'il était le taux par défaut.
- Rien de ce qui a déjà été émis n'est modifié.

**Voir aussi:** [Définir les taux](help:user.money.vat.rates)

<!-- anchor: user.money.vat.declaration -->
### La déclaration périodique de TVA

**Public:** Propriétaire

Vous voulez un récapitulatif prêt à l'emploi de la TVA d'une période, à déposer auprès de l'administration fiscale ou à remettre à votre comptable.

<p><img src="images/user-money-vat-declaration.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Déclaration de TVA](app:/vat-declarations).
2. Choisissez la **Période** et touchez **Générer**.
3. Ouvrez le résultat avec **PDF** ou **Export XML**, ou consultez **Rapport de TVA (PDF)** et **Rapport de TVA (CSV)**.
4. Une fois que vous l'avez déposée vous-même, touchez **Marquer comme déposée**.

**Bon à savoir**

- Elle n'existe que sous le régime des assujettis à la TVA. La note en haut indique si la période compte les factures ou les encaissements.
- C'est une aide au dépôt générée à partir des factures émises de la période, pas un conseil fiscal. Vérifiez-la avec votre comptabilité avant de la déposer.
- Une déclaration déposée ne peut plus être modifiée.
- Lorsqu'une plateforme est configurée dans [Facturation électronique](help:user.money.einvoice.overview), un bouton **Télétransmettre** peut l'envoyer.

**Voir aussi:** [Exigibilité de la TVA](help:user.money.vat.due) · [Exports comptables](help:user.invoicing.accounting-export)

<!-- anchor: user.money.einvoice.overview -->
### La plateforme de facturation électronique

**Public:** Propriétaire · Administrateur·rice facturation

Vous indiquez à DesKilo où déposer vos factures sous forme de fichiers lisibles par une machine.

<p><img src="images/user-money-einvoice-overview--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Plateforme de facturation électronique](app:/einvoice-config) (accessible aussi depuis **Identité légale et facturation électronique**).
2. Renseignez **URL de dépôt** et **Jeton ou identifiant**, ainsi que les deux champs facultatifs si votre plateforme les demande.
3. Touchez **Enregistrer**. **Supprimer la plateforme** efface les réglages.

**Bon à savoir**

- Toute plateforme qui accepte un envoi avec un jeton fonctionne : une plateforme agréée, un point d'accès Peppol, une plateforme nationale.
- Le jeton est stocké sur le serveur et n'est plus jamais affiché.
- Le fichier valide est une facture EN 16931. Savoir si votre pays impose une plateforme, et laquelle, est à confirmer avec votre comptable.

**Voir aussi:** [Envoyer une facture électronique](help:user.money.einvoice.send) · [Identité légale](help:user.money.legal.identity)

<!-- anchor: user.money.einvoice.endpoint -->
### URL de dépôt

**Public:** Propriétaire · Administrateur·rice facturation

L'adresse à laquelle votre plateforme reçoit les factures.

<p><img src="images/user-money-einvoice-endpoint--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Plateforme de facturation électronique](app:/einvoice-config).
2. Collez l'adresse dans **URL de dépôt**, exactement comme votre plateforme la documente.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Elle figure dans la documentation de votre plateforme ou chez votre prestataire.

**Voir aussi:** [Jeton ou identifiant](help:user.money.einvoice.token)

<!-- anchor: user.money.einvoice.token -->
### Jeton ou identifiant

**Public:** Propriétaire · Administrateur·rice facturation

Le secret qui prouve à la plateforme que l'envoi vient bien de vous.

<p><img src="images/user-money-einvoice-token--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Plateforme de facturation électronique](app:/einvoice-config).
2. Collez la clé dans **Jeton ou identifiant**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Une fois enregistré, l'écran indique « Un jeton est enregistré ». N'en saisissez un nouveau que pour le remplacer.
- Il est conservé sur le serveur et n'en ressort jamais.

**Voir aussi:** [En-tête d'authentification](help:user.money.einvoice.auth-header)

<!-- anchor: user.money.einvoice.auth-header -->
### En-tête d'authentification

**Public:** Propriétaire · Administrateur·rice facturation

Le nom de l'en-tête qui porte le jeton.

<p><img src="images/user-money-einvoice-auth-header--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Plateforme de facturation électronique](app:/einvoice-config).
2. Si votre plateforme attend un autre en-tête que l'en-tête standard, saisissez son nom dans **En-tête d’authentification (Authorization par défaut)**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Laissé vide, `Authorization` est utilisé.

**Voir aussi:** [Nom du champ fichier](help:user.money.einvoice.file-field)

<!-- anchor: user.money.einvoice.file-field -->
### Nom du champ fichier

**Public:** Propriétaire · Administrateur·rice facturation

Le nom du champ de formulaire qui porte le fichier de la facture.

<p><img src="images/user-money-einvoice-file-field--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Plateforme de facturation électronique](app:/einvoice-config).
2. Si votre plateforme attend un autre nom de champ, saisissez-le dans **Nom du champ fichier (file par défaut)**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Laissé vide, `file` est utilisé.

**Voir aussi:** [URL de dépôt](help:user.money.einvoice.endpoint)

<!-- anchor: user.money.einvoice.customer-delivery -->
### Service de remise au client

**Public:** Propriétaire · Administrateur·rice facturation

Votre client peut recevoir ses factures ailleurs que sur une plateforme gouvernementale : son propre point d'accès Peppol, un portail ou un service de dépôt convenu.

<p><img src="images/user-money-einvoice-customer-delivery--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Plateforme de facturation électronique](app:/einvoice-config).
2. Dans **Service de remise au client**, renseignez les mêmes quatre champs que ci-dessus.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Il est distinct de la plateforme gouvernementale. Les deux peuvent être configurés, et chaque facture propose les deux envois.

**Voir aussi:** [Envoyer une facture électronique](help:user.money.einvoice.send)

<!-- anchor: user.money.einvoice.uat -->
### Point de terminaison et jeton UAT

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez faire une répétition avant d'envoyer de vraies factures.

<p><img src="images/user-money-einvoice-uat--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Plateforme de facturation électronique](app:/einvoice-config).
2. Sous **Environnements de test (UAT / Dev)**, renseignez **URL d’envoi UAT** et **Jeton ou identifiant UAT**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Le choix de l'environnement n'apparaît à l'envoi que tant que le mode développeur est activé.
- Un envoi de test est enregistré comme un envoi de test.

**Voir aussi:** [Point de terminaison et jeton Dev](help:user.money.einvoice.dev)

<!-- anchor: user.money.einvoice.dev -->
### Point de terminaison et jeton Dev

**Public:** Propriétaire · Administrateur·rice facturation

Un second point de terminaison de test, pour le développement.

<p><img src="images/user-money-einvoice-dev--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Plateforme de facturation électronique](app:/einvoice-config).
2. Sous **Environnements de test (UAT / Dev)**, renseignez **URL d’envoi Dev** et **Jeton ou identifiant Dev**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Mêmes règles que pour l'UAT. Le véritable dépôt part toujours vers le point de terminaison de production.

**Voir aussi:** [Point de terminaison et jeton UAT](help:user.money.einvoice.uat)

<!-- anchor: user.money.einvoice.send -->
### Envoyer une facture électronique

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez remettre une facture émise sous sa forme lisible par une machine.

**Étapes**

1. Ouvrez une facture dans [Facturation](app:/invoices) et touchez **Facture électronique (XML)**.
2. Lisez le contrôle en haut de la feuille : il indique si le fichier est prêt ou ce qui manque.
3. Touchez **Envoyer à la plateforme gouvernementale**, **Envoyer au service du client**, ou téléchargez ou partagez le fichier (**Télécharger le Factur-X (PDF)** porte le XML à l'intérieur du PDF).

**Bon à savoir**

- Si quelque chose manque, la feuille le liste. **Compléter l'identité légale** vous mène à l'écran qui le corrige.
- Une facture signée avant que vous ayez complété votre identité garde ce avec quoi elle a été émise. Marquez-la comme erronée et émettez-en une de remplacement si cela compte.
- Le canal que doit utiliser un client dépend de votre pays et du client. Confirmez avec votre comptable.

**Voir aussi:** [La plateforme de facturation électronique](help:user.money.einvoice.overview) · [L'écran Facturation](help:user.invoicing.hub)

<!-- anchor: user.money.reports.invoice-template -->
### Le modèle PDF de facture

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez que vos factures soient à votre image : logo, mise en page, formulations.

<p><img src="images/user-money-reports-invoice-template.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Rapports](app:/reports?section=templates) et l'onglet **Modèles**.
2. Touchez **Éditeur de rapports**.

**Bon à savoir**

- Le modèle ne change que le PDF. Le XML de la facture électronique n'est jamais modifié.
- Toute personne autorisée à concevoir des documents peut le faire.
- Un modèle qui ne s'affiche pas ne bloque jamais un document : la mise en page intégrée prend le relais.

**Voir aussi:** [L'éditeur de rapports](help:user.money.reports.editor)

<!-- anchor: user.money.reports.editor -->
### L'éditeur de rapports

**Public:** Propriétaire · Administrateur·rice facturation

Vous concevez un document sur une page, sans écrire de code.

<p><img src="images/user-money-reports-editor.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Éditeur de rapports](app:/report-editor).
2. Choisissez le document avec les pastilles (Facture, Proforma, Relevé, relances et les autres rapports).
3. Dans **Conception**, touchez une ligne pour la modifier, ajoutez des lignes, ou faites-les glisser pour les réordonner. Touchez **Aperçu** pour voir le résultat avec vos données.
4. Touchez **Enregistrer**.

**Bon à savoir**

- Le mode **Balisage** modifie les mêmes bandes sous forme de texte.
- **Insérer une image** place un logo, un tampon ou une signature depuis la bibliothèque d'images.
- **Aperçu rapide** s'affiche instantanément avec votre facture la plus récente, ou des données d'exemple s'il n'y en a pas. **Réinitialiser au modèle par défaut** rétablit la mise en page intégrée.
- **Exporter cette maquette** et **Importer une maquette** font entrer et sortir une maquette sous forme de fichier. **Maquette positionnée (XML)** sert aux documents qui doivent correspondre à une enveloppe à fenêtre ou à un formulaire national.
- Quitter avec un travail non enregistré demande d'abord confirmation.

**Voir aussi:** [Modèles prêts à l'emploi](help:user.money.reports.presets) · [Langues](help:user.money.reports.languages)

<!-- anchor: user.money.reports.presets -->
### Modèles prêts à l'emploi

**Public:** Propriétaire · Administrateur·rice facturation

Vous partez d'une maquette terminée et vous changez ce que vous voulez.

<p><img src="images/user-money-reports-presets.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Éditeur de rapports](app:/report-editor) et choisissez un document.
2. Touchez **Modèles** et choisissez **Professionnel**, **Classique**, **Simple**, **Détaillé** ou **Lettre formelle**.
3. Confirmez le remplacement si l'app le demande, puis modifiez et **Enregistrer**.

**Bon à savoir**

- Le remplacement d'une mise en page peut être annulé avec **Annuler**.
- Les rapports structurels (plan comptable, badges, cartes QR) ont une seule mise en page fournie.
- Les modèles de facture portent déjà vos mentions légales. Ils n'impriment toujours que ce que vous avez saisi sous [Mentions de facturation](help:user.money.legal.identity).

**Voir aussi:** [L'éditeur de rapports](help:user.money.reports.editor)

<!-- anchor: user.money.reports.languages -->
### Une maquette par langue

**Public:** Propriétaire · Administrateur·rice facturation

Vos membres lisent leurs documents dans leur propre langue.

<p><img src="images/user-money-reports-languages--f.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Éditeur de rapports](app:/report-editor).
2. Sous le document, choisissez **Par défaut (toutes langues)** ou l'une des langues **EN**, **FR**, **DE**, **ES**, **IT**.
3. Modifiez les bandes pour cette langue et **Enregistrer**. **Utiliser le défaut pour cette langue** supprime une maquette propre.

**Bon à savoir**

- Un point sur une langue signifie qu'elle a sa propre maquette ; sinon elle hérite de celle par défaut.
- Le document d'un membre s'imprime dans sa langue quand une maquette existe pour elle, sinon dans la langue par défaut de l'espace.

**Voir aussi:** [Langue de l'espace](help:user.workspace.settings.language)

<!-- anchor: user.invoicing.hub -->
### L'écran Facturation

**Public:** Propriétaire · Administrateur·rice facturation

Vous voyez d'un coup d'œil ce qu'il faut émettre, ce qu'il faut encaisser et ce qui est clos.

<p><img src="images/user-invoicing-hub.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Facturation](app:/invoices).
2. Lisez la bande : **À émettre**, **À encaisser**, **À confirmer**, **Closes**.
3. Travaillez dans les trois onglets : **À facturer** (membres avec quelque chose de suivi, pas encore facturé), **En cours** (émises, impayées) et **Archives** (payées ou closes).
4. Touchez l'icône d'outils pour les autres outils.

**Bon à savoir**

- Vous voyez les factures de tout l'espace. Les vôtres sont dans vos finances, sous **Mes finances**.
- Les factures ne sont jamais modifiées ni supprimées : une facture erronée est marquée comme telle et remplacée.
- L'entrée **Comment fonctionne la facturation** explique qui intervient à chaque étape.

**Voir aussi:** [Nouvelle facture](help:user.invoicing.new-invoice) · [Factures en cours](help:user.invoicing.open)

<!-- anchor: user.invoicing.new-invoice -->
### Émettre une facture

**Public:** Propriétaire · Administrateur·rice facturation

Vous facturez un membre pour un mois.

<p><img src="images/user-invoicing-new-invoice.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Facturation](app:/invoices), touchez **Nouvelle facture**, ou **Facturer** sur une ligne de **À facturer**.
2. Choisissez le **Membre** et le mois. Les positions viennent de ce qui a été suivi.
3. Activez **Inclure l'annexe détaillée (présences, services, paiements)** si vous la souhaitez.
4. Touchez **Émettre la facture**. Dans **À facturer**, **Tout facturer** émet chaque ligne.

**Bon à savoir**

- Les factures sont dérivées des données suivies et ne se composent pas à la main. La dernière ligne est le **Solde**.
- Un mois ne peut être facturé qu'une fois par membre, et un mois encore en cours vous avertit que les positions peuvent changer.
- Si une information obligatoire manque, **Complétez ces informations avant d'émettre** la liste (adresse, numéro de TVA, fondement de l'exonération, taux de TVA ; aussi le pays de l'espace, qui doit être la France ou l'Allemagne).
- Dans cette version, l'émission dans l'app est disponible pour les espaces établis en France ou en Allemagne, pour des clients nationaux. Les factures transfrontalières, en autoliquidation, à l'export ou à un acheteur exonéré sont émises hors de l'app avec votre comptable.
- Une facture émise est signée et immuable.

**Voir aussi:** [Assistant de clôture](help:user.invoicing.wizard)

<!-- anchor: user.invoicing.open -->
### Relancer et solder les factures en cours

**Public:** Propriétaire · Administrateur·rice facturation

Vous suivez ce qui est impayé et vous le soldez correctement.

<p><img src="images/user-invoicing-open.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Facturation](app:/invoices), ouvrez l'onglet **En cours** et touchez une facture.
2. Utilisez les actions proposées : **Envoyer un rappel**, **Marquer comme payée** (rapprocher un paiement enregistré), **Annuler le solde restant**, **Marquer comme erronée**, ou partager le PDF.
3. Les factures payées passent dans **Archives**.

**Bon à savoir**

- Une facture est payée dès qu'un vrai paiement lui est rapproché. Un écart demande une note, ou un avoir pour l'excédent.
- L'annulation d'un solde restant passe par une validation.
- **Marquer comme erronée** est irréversible. Faites-le avant le paiement, jamais après.

**Voir aussi:** [Règles de relance](help:user.money.reminders.rules) · [Regrouper des factures](help:user.invoicing.settlement)

<!-- anchor: user.invoicing.wizard -->
### L'assistant de clôture

**Public:** Propriétaire · Administrateur·rice facturation

Un seul parcours guidé pour la routine financière : émettre, envoyer, relancer, enregistrer les paiements, rapprocher et clôturer.

<p><img src="images/user-invoicing-wizard.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Facturation](app:/invoices), touchez **Assistant de clôture** (ou ouvrez l'[Assistant de facturation](app:/invoicing/wizard)).
2. Choisissez la passe : **Début de mois** (abonnements que les membres paient d'avance, pour le mois à venir) ou **Fin de mois** (usage, consommation et frais supplémentaires du mois qui vient de s'achever). La date en propose une.
3. Suivez les étapes : **Revue**, **Émettre**, **Envoyer**, **Relancer**, **Paiements**, **Rapprocher**, **Clôturer**, **Récapitulatif**.
4. Touchez **Suivant** à chaque étape, et **Terminer** à la fin.

**Bon à savoir**

- Vous pouvez décocher un membre pour l'exclure d'un lot ; les membres déjà traités apparaissent comme faits.
- **Récapitulatif** liste ce que la passe a fait, ce qui reste ouvert et à qui c'est le tour.
- Une étape sans rien à faire le dit.

**Voir aussi:** [L'écran Facturation](help:user.invoicing.hub) · [Regrouper des factures](help:user.invoicing.settlement)

<!-- anchor: user.invoicing.settlement -->
### Regrouper des factures en une seule

**Public:** Propriétaire · Administrateur·rice facturation

Un membre a plusieurs factures ouvertes et ne doit en payer qu'une.

<p><img src="images/user-invoicing-settlement.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Facturation](app:/invoices), touchez l'icône d'outils et **Regrouper en une facture**.
2. Choisissez au moins deux factures ouvertes du même membre.
3. Confirmez. On vous demande si vous voulez joindre les factures regroupées.

**Bon à savoir**

- La nouvelle facture est celle qui est due et relancée. Les originales restent lisibles derrière elle.
- Les lignes et la TVA sont reprises ; la déclaration de TVA compte les originales une seule fois.

**Voir aussi:** [Factures en cours](help:user.invoicing.open)

<!-- anchor: user.invoicing.shared-expense -->
### Répartir une dépense partagée

**Public:** Propriétaire · Administrateur·rice facturation

Un coût partagé par la communauté est réparti entre les membres.

<p><img src="images/user-invoicing-shared-expense.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Facturation](app:/invoices), touchez l'icône d'outils et **Répartir une dépense**.
2. Décrivez **La dépense**, puis choisissez **Répartir selon** : **Parts égales**, **Abonnement**, **Usage** ou **Clé personnalisée**.
3. Vérifiez les **Parts**, décochez toute personne à **Exclure**, et touchez **Comptabiliser les parts**.

**Bon à savoir**

- Une fois comptabilisées (après validation, si une règle l'exige), les parts arrivent en lignes sur la prochaine facture d'usage de chaque membre.
- **Annulation — rendre sous forme d'avoirs** restitue l'argent.
- **Mémoriser cette règle** reproposera la règle ajustée le mois suivant.

**Voir aussi:** [L'assistant de clôture](help:user.invoicing.wizard)

<!-- anchor: user.money.reminders.rules -->
### Règles de relance

**Public:** Propriétaire · Administrateur·rice facturation

Vous décidez quand et à quelle fréquence une facture en retard est relancée.

<p><img src="images/user-money-reminders-rules.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Facturation](app:/invoices), touchez l'icône d'outils et **Règles de relance**.
2. Réglez **Nombre de niveaux de relance**, **Jours avant la première relance** et **Jours entre les relances**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Les relances impriment les mentions de paiement que vous avez configurées.
- Une relance est enregistrée sur la facture et apparaît comme un badge **Rappelé**.

**Voir aussi:** [Relances automatiques](help:user.money.reminders.automatic) · [Modalités de règlement](help:user.money.legal.payment-terms)

<!-- anchor: user.money.reminders.automatic -->
### Relances automatiques

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez que les relances partent toutes seules.

<p><img src="images/user-money-reminders-automatic.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez **Règles de relance** dans les outils de Facturation.
2. Activez **Relances automatiques**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Une fois par jour, les factures qui ont dépassé leur échéance enregistrée passent au niveau suivant, pour le montant encore dû.
- Jamais tant qu'un paiement est en attente ou que la facture est suspendue. Les factures sans échéance enregistrée vous sont laissées.
- Désactivées : vous envoyez chaque relance vous-même.
- Quand cela s'exécute : chaque matin sur le serveur si l'installation planifie des tâches, sinon quand un administrateur ouvre Finances. L'opérateur de votre serveur sait ce qui s'applique.

**Voir aussi:** [Règles de relance](help:user.money.reminders.rules)

<!-- anchor: user.invoicing.register -->
### Le registre des factures

**Public:** Propriétaire · Administrateur·rice facturation

Toutes les factures dans une seule liste triable.

<p><img src="images/user-invoicing-register.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Registre des factures](app:/invoice-register).
2. Choisissez l'**Année** ou **Toutes les années**.
3. Triez par **Date**, **Nom** ou **Montant** ; le total est en bas.

**Bon à savoir**

- Les membres voient les leurs ; les personnes qui émettent des factures voient celles de l'espace.
- L'export comptable part d'ici.

**Voir aussi:** [Exports comptables](help:user.invoicing.accounting-export)

<!-- anchor: user.invoicing.accounting-export -->
### Exports comptables

**Public:** Propriétaire · Administrateur·rice facturation

Vous remettez à votre comptable les factures et les paiements de l'année.

<p><img src="images/user-invoicing-accounting-export.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Registre des factures](app:/invoice-register) et touchez **Export comptable**.
2. Dans **Export comptable**, choisissez un format, comme **FEC (France, exigé en cas de contrôle)**, **SAF-T (XML, international)**, **CSV comptable**, **Piste d’audit** ou **Archive de l'exercice (zip)**. La liste dépend de votre pays ; quelques pays ajoutent le leur, comme **DATEV (Buchungsstapel)**.
3. Dans **Avant d’enregistrer**, lisez le contrôle, puis touchez **Enregistrer le fichier et le rapport**.

**Bon à savoir**

- Chaque format dit ce qu'il prétend être. « Pour que votre comptable l’importe et le vérifie — ce n’est pas une déclaration » n'est pas une déclaration fiscale.
- DesKilo ne tient pas de grand livre en partie double : les fichiers sont reconstruits à partir des factures et des paiements, et votre comptable les complète.
- Un fichier est bloqué tant que les problèmes de la source ne sont pas corrigés.
- Certains formats précisent que DesKilo n'est pas un logiciel certifié dans votre pays.

**Voir aussi:** [Compte de TVA](help:user.money.vat.account) · [Le registre des factures](help:user.invoicing.register)

<!-- anchor: user.invoicing.bi -->
### Analyse d'activité

**Public:** Propriétaire · Administrateur·rice facturation

Vous regardez comment l'espace se porte.

**Étapes**

1. Ouvrez [Analyse d’activité](app:/bi), ou **Reporting** dans le menu.
2. Choisissez la **Durée de la période** (**Mois**, **Trimestre**, **Année**), une comparaison, et un regroupement là où il est proposé.
3. Lisez les analyses par domaine, comme **Finances** (**Facturé**, **Encaissé**) et **Espaces et capacité**.
4. Enregistrez une vue sous **Vues**, ou touchez **Exporter en PDF**.

**Bon à savoir**

- Vous ne voyez que les analyses que vous avez le droit de lire.
- « Encaissé » désigne les paiements rapprochés des factures. Ce n'est pas un bénéfice : aucun coût n'entre dans le chiffre.
- La période en cours est partielle ; ses chiffres changent encore.

**Voir aussi:** [L'écran Facturation](help:user.invoicing.hub)
