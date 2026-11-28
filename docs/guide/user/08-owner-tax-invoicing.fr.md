<!-- anchor: user.invoicing.overview -->
## Fiscalité, facturation et comptabilité

Pour les propriétaires et les administrateurs facturation : qui vous êtes en tant que vendeur, comment la TVA est gérée, où partent les factures électroniques, à quoi ressemblent vos documents, et le rythme mensuel pour émettre, envoyer et relancer les factures.

> **Attention** DesKilo imprime ce que vous déclarez et vérifie que les informations obligatoires sont présentes. Il ne certifie ni vos factures, ni votre traitement de la TVA, ni votre comptabilité. Chaque fois qu'une section ci-dessous dit « à confirmer avec votre comptable », faites-le.

Dans ce chapitre :
- Ce que l'application émet elle-même, et ce qui reste chez votre comptable
- Votre identité légale et les mentions imprimées sur chaque facture
- La TVA : régime, numéro, taux, groupes et déclaration périodique
- La facturation électronique : où part la facture lisible par une machine
- Le modèle PDF de facture et l'éditeur de rapports
- Émettre et clôturer un mois : l'écran Facturation, la facturation du mois, une facture et un client, les paiements et les avoirs, l'assistant de clôture, le regroupement, les dépenses partagées
- Les relances de paiement
- Le registre des factures, les exports comptables et l'analyse d'activité

<!-- anchor: user.invoicing.scope -->
### Ce que l'application émet, et ce qui reste chez votre comptable

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez savoir, avant de vous y fier, quelles factures DesKilo émet lui-même et lesquelles vous émettez encore avec votre comptable. Voici le périmètre de cette version.

| Situation | Dans l'application | Hors de l'application |
|---|---|---|
| Un espace en France ou en Allemagne, assujetti à la TVA ou hors du champ de la TVA | Factures émises, numérotées, envoyées et suivies | — |
| Un poste, un bureau ou une salle, quel que soit le client, même à l'étranger | Émis avec votre TVA : le lieu de la prestation est le bâtiment | — |
| Un espace dans un autre pays | Réservations, relevés et paiements | Les factures, avec votre comptable |
| Le régime d'exonération de TVA | — | Les factures, avec votre comptable |
| Autoliquidation, export, acheteur exonéré | Enregistré sur le membre | Les factures, avec votre comptable |
| Facturation électronique | Le fichier EN 16931, déposé sur la plateforme que vous configurez | Le choix de la plateforme et ce que le dispositif national vous demande |
| Comptabilité | Des exports reconstruits à partir des factures et des paiements | Le grand livre, la clôture et les comptes |
| Déclaration de TVA | Les montants, calculés à partir des factures et des paiements | Son dépôt auprès de l'administration fiscale |

**Bon à savoir**

- La facturation électronique tient en trois étapes : DesKilo produit la facture structurée ; le connecteur la dépose sur votre plateforme ; la plateforme la transmet au client et à l'administration selon le dispositif national. Un fichier valide n'est que la première étape.
- En France, seule une plateforme agréée peut transmettre les factures dans le cadre de la réforme, et DesKilo n'en est pas une : configurez la plateforme que vous choisissez. Toutes les entreprises concernées doivent pouvoir recevoir des factures électroniques à partir du 1er septembre 2026 ; les PME et les microentreprises doivent les émettre à partir du 1er septembre 2027.
- DesKilo ne tient pas de grand livre en partie double : votre comptable complète les fichiers exportés.
- Ce tableau évolue avec l'application. Quand une ligne passe dans l'application, cette section le dit.

**Voir aussi:** [Émettre une facture](help:user.invoicing.new-invoice) · [La plateforme de facturation électronique](help:user.money.einvoice.overview) · [Exports comptables](help:user.invoicing.accounting-export) · [Régime de TVA](help:user.money.vat.regime)

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

- Activée : une prestation générale (non rattachée aux locaux) à une entreprise d'un autre pays de l'UE est autoliquidée. Un poste, un bureau ou une salle ne l'est jamais : il porte votre TVA, quel que soit le numéro de TVA du client. L'app émet une telle facture une fois le numéro de TVA du client trouvé valide dans [VIES](#vérification-du-numéro-de-tva-vies) ; sinon, ou si cette fonctionnalité est désactivée, vous l'émettez hors de l'app avec votre comptable.
- Désactivée : désactivez-la si vous ne facturez jamais d'entreprises à l'étranger.
- L'option n'apparaît que pour le régime des assujettis à la TVA.

**Voir aussi:** [Traitement TVA d'un membre](help:user.members.vat-treatment)

<!-- anchor: user.money.vat.vies -->
### Vérification du numéro de TVA (VIES)

**Public:** Propriétaire · Administrateur·rice facturation

Avant d'autoliquider une prestation générale vendue à une entreprise d'un autre pays de l'UE, l'app a besoin d'une preuve que le client est une entreprise : son numéro de TVA trouvé valide dans VIES, le registre européen des numéros de TVA.

**Étapes**

1. Ouvrez la page du membre et touchez **Vérification du numéro de TVA (VIES)**.
2. Touchez **Vérifier maintenant**.
3. La ligne indique alors **Valide** avec le numéro de consultation et la date, **Non valide dans VIES** ou **VIES n'a pas répondu**.

**Bon à savoir**

- Le numéro de consultation est conservé sur le membre et figé sur chaque facture autoliquidée, comme preuve.
- L'émission refuse une autoliquidation sans vérification valide de ce numéro précis datant de moins de 90 jours, et le dit : **Une vérification VIES valide du numéro de TVA du membre**. Quand VIES ne répond pas, réessayez plus tard ; la facture ne repasse jamais d'elle-même à votre TVA.
- Un poste, un bureau ou une salle n'est jamais autoliquidé : aucune vérification n'est nécessaire.
- La ligne apparaît pour qui peut émettre des factures, quand la fonctionnalité **Vérification du numéro de TVA (VIES)** est activée.

**Voir aussi:** [Autoliquidation pour les entreprises de l'UE](#autoliquidation-pour-les-entreprises-de-lue) · [Lieu de prestation d'un service](#lieu-de-prestation-dun-service)

<!-- anchor: user.money.vat.recap -->
### Déclaration européenne de services

**Public:** Propriétaire

Chaque mois où vous autoliquidez des services vendus à des entreprises d'autres pays de l'UE, l'administration attend leur liste : la DES en France, la Zusammenfassende Meldung en Allemagne, le modelo 349 en Espagne.

**Étapes**

1. Ouvrez [Déclarations de TVA](https://fdittgen-png.github.io/deskilo/#/vat-declarations) et choisissez la période.
2. Touchez **Déclaration européenne de services (CSV)**.
3. Déposez-la sur le portail de l'administration, ou confiez-la à votre comptable.

**Bon à savoir**

- La liste totalise, par mois et par numéro de TVA du client, ce que vos factures émises ont autoliquidé ; un poste facturé avec votre TVA n'y figure jamais.
- Tant qu'une déclaration est due, la **Facturation** affiche un avis : **Une déclaration européenne de services est due pour** le mois.
- Le fichier a des colonnes fixes : période, pays, numéro de TVA, client, montant, documents.
- Il faut la fonctionnalité **Déclaration européenne de services**.

**Voir aussi:** [Vérification du numéro de TVA (VIES)](#vérification-du-numéro-de-tva-vies) · [Autoliquidation pour les entreprises de l'UE](#autoliquidation-pour-les-entreprises-de-lue)

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
- Une facture garde la règle qu'elle a imprimée : émise sur les encaissements, elle attend le paiement ; portant l'option pour les débits, elle est exigible dès son émission, quel que soit le choix ultérieur de l'espace.

**Voir aussi:** [Préparer la déclaration de TVA](help:user.money.vat.declaration)

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
3. Pour un groupe exonéré ou non assujetti, choisissez la **Mention d'exonération** qui apparaît : l'article de la directive TVA qui l'exonère, ou **Non soumis à la TVA**. La facture en imprime la formule légale dans la langue de vos documents ; une mention saisie avant la liste reste affichée tant que vous n'en choisissez pas une (#4501).
4. Touchez **Enregistrer**.

**Bon à savoir**

- **Ce qui relève de chaque groupe** liste des exemples pour votre pays, à titre indicatif seulement.
- Une ligne hors TVA, comme une consigne remboursable, ne peut pas figurer sur le même document que des lignes taxées ; émettez-la séparément.

**Voir aussi:** [Définir les taux](help:user.money.vat.rates)

<!-- anchor: user.money.vat.ch-return -->
### Le décompte suisse : chiffres 205 et 383

**Public:** Propriétaire · Administrateur·rice facturation

Votre espace est en Suisse, et vous voulez les prestations pour lesquelles vous avez opté et l'impôt sur les acquisitions dans les bonnes cases.

**Étapes**

1. Dans [Identité légale et facturation électronique](app:/legal-identity), sous **Location et option (Suisse)**, activez **Nous ne louons que des locaux nus** si vous louez des locaux sans services. Activez ensuite **Nous avons opté (art. 22 LTVA)** si vous avez opté, et saisissez **Option effective dès (AAAA-MM-JJ)**.
2. Enregistrez une dépense achetée à l'étranger avec **Acheté auprès d'un fournisseur à l'étranger** activé.
3. Ouvrez [Déclaration de TVA](app:/vat-declarations) et préparez la période.
4. Téléchargez **Décompte TVA, XML eCH-0217 (téléversement ePortal)** et déposez-le sur l'ePortal.

**Bon à savoir**

- Le chiffre 205 est la part de votre chiffre d'affaires (chiffre 200) qui est une location nue imposée parce que vous avez opté. Les lignes immobilières de la facture donnent cette part. Le décompte la compte toujours dans le chiffre 200.
- Le chiffre 383 est l'impôt sur les acquisitions. Il est déclaré comme impôt dû, et sa part déductible compte avec l'impôt préalable. Il ne fait pas partie du chiffre d'affaires.
- Dans le fichier eCH-0217, les prestations optées sont écrites `opted`, et l'impôt sur les acquisitions un élément `acquisitionTax` par taux.
- Un·e opérateur·rice qui modifie les cases dans **Données de référence fiscales** nomme les lignes supplémentaires d'une case dans **Autres catégories de lignes qu'elle additionne (séparées par des virgules, p. ex. acquisition)**. Le chiffre 383 porte `acquisition`.

**Voir aussi:** [Préparer la déclaration de TVA](help:user.money.vat.declaration) · [La TVA d'une dépense](help:user.money.expenses.vat)

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
### Préparer la déclaration de TVA

**Public:** Propriétaire

Vous voulez la TVA d'une période calculée à partir de vos factures et de vos encaissements, prête à déposer auprès de l'administration fiscale ou à remettre à votre comptable.

<p><img src="images/user-money-vat-declaration.fr.jpg" width="280"></p>

**Étapes**

1. Ouvrez [Déclaration de TVA](app:/vat-declarations).
2. Choisissez la **Période** et touchez **Préparer**.
3. Ouvrez le résultat avec **PDF** ou **Export XML**, ou consultez **Rapport de TVA (PDF)** et **Rapport de TVA (CSV)**.
4. Déposez vous-même la déclaration auprès de l'administration fiscale (ou par votre comptable), puis touchez **Marquer comme déposée** et saisissez la **Référence de l’accusé de réception de l’administration fiscale**.

**Bon à savoir**

- Elle n'existe que sous le régime des assujettis à la TVA. La note en haut indique quand la TVA de la période devient exigible.
- Le serveur calcule les montants, à partir des factures, des encaissements enregistrés un à un et de l'exigibilité de chaque facture. Chaque taux est ventilé par catégorie : taux normal, autoliquidation, exonération et taux zéro restent séparés. Les factures de regroupement sont écartées ; leur paiement compte pour les factures qu'elles regroupent.
- Une déclaration passe de **Brouillon** à **Préparée** puis **Déposée**. La préparer à nouveau remplace les montants ; une fois déposée, plus rien ne la modifie. Si une facture ou un encaissement de la période a changé depuis la préparation, l'application refuse de la marquer déposée tant qu'elle n'a pas été préparée à nouveau.
- La liste **Période** ne propose que des périodes de la durée choisie sous **Périodicité de la déclaration de TVA** dans [Identité légale et facturation électronique](app:/legal-identity) — mensuelle, trimestrielle ou annuelle ; trimestrielle tant que vous n'avez pas choisi. Une période qui chevauche une déclaration déposée ne peut pas être préparée.
- **PDF** et **Export XML** listent les cases du formulaire de votre pays — la CA3, l'UStVA allemande, la déclaration britannique, le décompte TVA suisse, la déclaration TPS/TVH canadienne, le Modelo 303 espagnol, la liquidation périodique italienne — chaque montant arrondi comme ce formulaire le veut : à l'euro sur la CA3, à l'euro sans les centimes pour les bases de l'UStVA, à la livre pour les cases 6 à 9 britanniques. Les ventes sont ventilées par catégorie (exportations, services intracommunautaires, exonérations), la TVA déductible sur immobilisations à part du reste. Les autres pays reçoivent une case par taux.
- En Allemagne et en France, **Fichier ELSTER (UStVA)** et **Fichier EDI-TVA (CA3)** écrivent la déclaration préparée au format que prend le canal de dépôt, à partir des mêmes cases que le PDF. Remettez le fichier ELSTER à votre logiciel de transmission ou à votre conseiller fiscal, le fichier EDI-TVA à votre partenaire EDI ; l'application ne transmet rien. Le fichier ELSTER demande la Steuernummer à chaque fois (ce n'est pas le numéro de TVA) et couvre un mois ou un trimestre ; le fichier EDI-TVA prend le SIREN dans le numéro d'immatriculation ou dans un numéro de TVA français.
- Une période déposée est verrouillée. Si quelque chose y change ensuite — une facture annulée, un encaissement enregistré tardivement à une date antérieure — la déclaration déposée reste telle quelle, et la prochaine déclaration que vous préparez porte la différence comme **Régularisation de** cette période, sur une ligne à part. Déposer cette déclaration enregistre la régularisation : elle n'est déclarée qu'une fois. Sur la CA3, les régularisations vont aux lignes 15 (TVA à reverser) et 21 (autre TVA à déduire) ; ailleurs, elles s'ajoutent aux cases du taux de la période en cours.
- Avec **TVA déductible** activée, la déclaration liste aussi la **TVA déductible** des dépenses approuvées dans la période, par taux, à part des ventes, et les totaux indiquent la **TVA à payer** ou le **Crédit de TVA**. Sur les formulaires, elle va à la ligne 20 de la CA3, à la Kz 66 de l'UStVA, à la case 4 britannique, au chiffre 400 suisse et à la ligne 108 canadienne.
- L'application ne télétransmet pas de déclaration : la France dépose par EDI-TVA ou l'espace professionnel d'impots.gouv, l'Allemagne par ELSTER. La plateforme de facturation électronique ne transporte que les factures.
- C'est une aide au dépôt, pas un conseil fiscal. Vérifiez-la avec votre comptabilité avant de la déposer.

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
- Déposer le fichier est la deuxième de trois étapes : voir [Ce que l'application émet, et ce qui reste chez votre comptable](help:user.invoicing.scope).
- En Italie, aucune facture n'est émise avant que la plateforme nationale (le SdI) ait accepté un document de l'espace. **Envoyer un document de test** dans l'étape facturation électronique du guide de configuration : la facture pro forma du mois en cours d'un membre, avec un numéro de test, part vers l'environnement de test de la plateforme avec ses identifiants de test. Rien n'est émis, numéroté ni comptabilisé. Une fois la plateforme d'accord, l'espace émet ; de nouveaux identifiants ou une autre identité du vendeur demandent un nouveau test.

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
- Si la réponse de la plateforme se perd alors que le document a peut-être été envoyé, la facture affiche **résultat inconnu** et **Envoyer** n'est plus proposé. Vérifiez l'enregistrement de la plateforme, puis touchez **Consigner ce qui s'est passé** et indiquez ce que vous avez constaté, pourquoi vous en êtes sûr et ce que vous avez vérifié. Une personne autorisée à émettre des factures peut le faire une fois ; rien n'est envoyé par ce geste.

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
- Une facture émise garde l'original avec lequel elle a été émise : un modèle modifié ensuite ne change que les factures émises après. Des images qui rendent une facture plus lourde qu'un original ne peut l'être empêchent de conserver son original ; utilisez des images plus légères.
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

Vous ouvrez la facturation et voyez ce qu'on vous doit, ce qu'il reste à faire et les factures de chaque client.

<p><img src="images/user-invoicing-hub--tasks.en.jpg" width="280"></p>

*À faire*

<details>
<summary>Capture complète (en anglais)</summary>

<p><img src="images/user-invoicing-hub.en.jpg" width="280"></p>

</details>

**Étapes**

1. Ouvrez [Facturation](app:/invoices).
2. Lisez **À recevoir** : ce qui est **En retard**, ce qui est **Pas encore échu**, et ce qui a été **Facturé en** et **Encaissé en** ce mois-ci.
3. Avancez dans **À faire** : chaque entrée dit quoi faire, pour combien, et s'ouvre avec **Voir**. Quand il ne reste rien, elle indique **Tout est à jour.**
4. En dessous, choisissez **Ouvertes**, **En retard**, **À confirmer** ou **Payées**, et lisez la liste par **Clients** ou par **Factures**. **Rechercher** trouve un client ou un numéro.
5. Touchez **Nouvelle** pour une seule facture, et **Plus** pour **Factures payées et closes**, **Mes propres factures**, **Registre des factures**, **Modèle PDF des factures** et **Comment fonctionne la facturation**.

**Bon à savoir**

- Un avoir que l'entreprise doit n'est jamais compté dans ce qu'on vous doit : il attend dans **Rembourser les avoirs**.
- Chaque statut est un mot autant qu'une couleur : **Échéance aujourd’hui**, **Paiement reçu · à rapprocher**, **En attente de la confirmation du client**, **Suspendue**.
- Vos propres factures sont dans vos finances, sous **Mes propres factures**.
- Une facture ne se modifie ni ne se supprime : une facture fausse est corrigée par une facture de remplacement.

**Voir aussi:** [Facturer le mois](help:user.invoicing.month) · [Suivre une facture](help:user.invoicing.open)

<!-- anchor: user.invoicing.month -->
### Facturer le mois

**Public:** Propriétaire · Administrateur·rice facturation

Le mois qui vient de s'achever a des clients encore à facturer, et vous les facturez en une fois.

<p><img src="images/user-invoicing-month--review.en.jpg" width="280"></p>

*À compléter*

<details>
<summary>Capture complète (en anglais)</summary>

<p><img src="images/user-invoicing-month.en.jpg" width="280"></p>

</details>

**Étapes**

1. Dans [Facturation](app:/invoices), trouvez **Facturer** et le mois dans **À faire**, et touchez **Voir**.
2. Lisez la liste : chaque client qui a quelque chose à facturer est coché, avec son montant. **Tous** coche ou décoche tout ensemble.
3. Un client marqué **À compléter** dit ce qui manque. Touchez **Compléter**, complétez, puis revenez : le client est relu.
4. Touchez **Émettre** avec le nombre et le montant.
5. Lisez ce qui s'est passé (**Émise**, **Attend une validation** ou **Non fait**) et touchez **Terminé**.

**Bon à savoir**

- Un mois dont les crédits dépassent les frais émet un avoir : l'entreprise le doit, et il attend dans **Rembourser les avoirs**.
- Une information qui manque à votre entreprise est dite une seule fois, en haut, avec un seul **Compléter** ; rien n'est émis tant qu'elle manque.
- Ce qui n'a pas été fait reste dans **À faire**, et **Réessayer pour celles-ci** réessaie sans rien émettre deux fois.
- **Voir la proforma** montre la facture d'un client avant qu'elle n'existe.

**Voir aussi:** [L'écran Facturation](help:user.invoicing.hub) · [Rembourser un avoir](help:user.invoicing.refunds)

<!-- anchor: user.invoicing.new-invoice -->
### Émettre une facture

**Public:** Propriétaire · Administrateur·rice facturation

Vous facturez un membre pour un mois.

<p><img src="images/user-invoicing-new-invoice.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Facturation](app:/invoices), touchez **Nouvelle**. Pour facturer tout un mois, voyez [Facturer le mois](help:user.invoicing.month).
2. Choisissez le **Membre** et le mois. Les positions viennent de ce qui a été suivi.
3. Activez **Inclure l'annexe détaillée (présences, services, paiements)** si vous la souhaitez.
4. Touchez **Émettre la facture**.

**Bon à savoir**

- Les factures sont dérivées des données suivies et ne se composent pas à la main. La dernière ligne est le **Solde**.
- Un mois ne peut être facturé qu'une fois par membre, et un mois encore en cours vous avertit que les positions peuvent changer.
- Si une information obligatoire manque, **Complétez ces informations avant d'émettre** la liste (adresse, numéro de TVA, fondement de l'exonération, taux de TVA ; aussi le pays de l'espace, qui doit être la France ou l'Allemagne).
- Dans cette version, l'émission dans l'app est disponible pour les espaces établis en France ou en Allemagne, y compris pour des clients à l'étranger : un poste, un bureau ou une salle porte votre TVA où que vive le client. Les factures à l'export ou à un acheteur exonéré, et une autoliquidation sans vérification VIES valide, sont émises hors de l'app avec votre comptable, et une prestation générale à un client à l'étranger demande d'abord sa qualité (professionnel ou consommateur).
- Une facture émise est signée et immuable.

**Voir aussi:** [Assistant de clôture](help:user.invoicing.wizard)

<!-- anchor: user.invoicing.open -->
### Suivre une facture

**Public:** Propriétaire · Administrateur·rice facturation

Vous ouvrez une facture et voyez où elle en est, ce qui s'est passé et la seule chose à faire maintenant.

<p><img src="images/user-invoicing-open--history.en.jpg" width="280"></p>

*Ce qui s’est passé*

<details>
<summary>Capture complète (en anglais)</summary>

<p><img src="images/user-invoicing-open.en.jpg" width="280"></p>

</details>

**Étapes**

1. Dans [Facturation](app:/invoices), touchez un client, puis la facture (ou touchez-la dans la liste par **Factures**).
2. Lisez le haut : ce qui reste dû sur le total et l'échéance, ou **Payée en totalité**.
3. Lisez **Ce qui s’est passé** : l'émission, l'échéance, chaque relance, un paiement déclaré par le client, le paiement.
4. Utilisez l'action du bas : **Partager la relance** avec son niveau, **Confirmer le paiement**, **Rapprocher le paiement** ou **Enregistrer le remboursement**.
5. Touchez **Plus** pour le PDF (**Voir le PDF**, **Télécharger le PDF**, **Partager le PDF**), **Suspendre les relances**, **Rapprocher un paiement** et les **Corrections** : **Corriger par une facture de remplacement**, **Annuler cette facture, émise par erreur**, **Passer le reste en perte**.

**Bon à savoir**

- **Par e-mail** envoie la facture à l'e-mail de contact du client, et **Renvoyer** l'envoie une fois de plus. Un e-mail accepté par le fournisseur ne prouve pas qu'il a été lu.
- Suspendue, aucune relance ne part tant que vous ne la levez pas.
- Le remplacement ou l'annulation sont proposés tant que rien n'est rapproché de la facture, **Passer le reste en perte** dès qu'une partie a été payée. Une facture ne se modifie jamais.
- Un client qui dit avoir payé attend votre réponse : vérifiez votre banque, puis **Confirmer le paiement** ou **Non reçu**.

**Voir aussi:** [Partager les relances](help:user.invoicing.reminders) · [Rapprocher un paiement reçu](help:user.invoicing.payments)

<!-- anchor: user.invoicing.reminders -->
### Partager les relances

**Public:** Propriétaire · Administrateur·rice facturation

Dans votre espace, les relances se partagent à la main, et certaines sont dues.

<p><img src="images/user-invoicing-reminders--queue.en.jpg" width="280"></p>

*Relances à partager*

<details>
<summary>Capture complète (en anglais)</summary>

<p><img src="images/user-invoicing-reminders.en.jpg" width="280"></p>

</details>

**Étapes**

1. Dans [Facturation](app:/invoices), trouvez **Partager les relances à la main** dans **À faire** et touchez **Voir**.
2. Chaque ligne nomme le client, le montant et le retard, avec son niveau (Relance 1, …). **Aperçu** montre la lettre.
3. Touchez **Partager** sur une ligne et envoyez la lettre comme vous le souhaitez ; le bouton sous la liste partage la suivante.
4. Quand le client a une adresse e-mail, **Envoyer par e-mail** l'envoie ; un bouton à la fin envoie par e-mail chaque ligne qui a une adresse.
5. Touchez **Terminé** quand la file dit ce qui a été partagé.

**Bon à savoir**

- Une relance n'est enregistrée sur sa facture que si elle a vraiment été partagée ou envoyée. Un partage que vous avez fermé n'enregistre rien.
- Si de l'argent reçu n'est pas encore affecté, la file vous demande de le vérifier d'abord (**À vérifier d'abord : argent reçu et non affecté**) : le client a peut-être payé.
- Quand les relances partent d'elles-mêmes, cette entrée n'est pas dans **À faire** ; **Règles** dit comment elles fonctionnent.

**Voir aussi:** [Règles de relance](help:user.money.reminders.rules) · [Relances automatiques](help:user.money.reminders.automatic)

<!-- anchor: user.invoicing.payments -->
### Rapprocher un paiement reçu

**Public:** Propriétaire · Administrateur·rice facturation

Un paiement est arrivé sur le compte et vous dites quelles factures il paie.

<p><img src="images/user-invoicing-payments--payment.en.jpg" width="280"></p>

*Paiements à rapprocher*

<p><img src="images/user-invoicing-payments--assignment.en.jpg" width="280"></p>

*Affecter aux factures*

<details>
<summary>Capture complète (en anglais)</summary>

<p><img src="images/user-invoicing-payments.en.jpg" width="280"></p>

</details>

**Étapes**

1. Dans [Facturation](app:/invoices), trouvez **Rapprocher des paiements** dans **À faire** et touchez **Voir**, puis **Rapprocher** sur le client.
2. **Paiements à rapprocher** montre chaque paiement reçu avec les factures qu'il peut payer ; **Même montant** marque celle qui correspond.
3. Touchez cette facture pour la rapprocher, ou **Affecter aux factures** pour répartir un paiement sur plusieurs.
4. Dans **Affecter aux factures**, cochez les factures et vérifiez les montants ; la plus ancienne est payée d'abord. Touchez **Affecter aux factures** pour confirmer.

**Bon à savoir**

- Ce qui reste du paiement reste en avoir pour le client, et la feuille dit combien.
- Une facture payée en partie demande une note.
- Un rapprochement peut attendre une seconde approbation quand une règle le demande.
- Rien n'est enregistré si quelque chose a changé entre-temps : la page relit le paiement et dit pourquoi.

**Voir aussi:** [Suivre une facture](help:user.invoicing.open) · [La page d'un client et son relevé](help:user.invoicing.customer)

<!-- anchor: user.invoicing.refunds -->
### Rembourser un avoir

**Public:** Propriétaire · Administrateur·rice facturation

L'entreprise doit de l'argent à un client sur un avoir, et vous enregistrez qu'il a été remboursé.

<p><img src="images/user-invoicing-refunds--refund.en.jpg" width="280"></p>

*L’entreprise doit ce remboursement*

<details>
<summary>Capture complète (en anglais)</summary>

<p><img src="images/user-invoicing-refunds.en.jpg" width="280"></p>

</details>

**Étapes**

1. Dans [Facturation](app:/invoices), trouvez **Rembourser les avoirs** dans **À faire** et touchez **Voir**.
2. Touchez le client, puis l'avoir : il indique **Remboursement dû** et **L’entreprise doit ce remboursement**.
3. Remboursez le client, puis touchez **Enregistrer le remboursement** et confirmez.

**Bon à savoir**

- Un avoir n'est jamais compté dans **À recevoir**.
- Une fois enregistré, l'avoir indique **Remboursée** et quitte **À faire**.

**Voir aussi:** [Facturer le mois](help:user.invoicing.month)

<!-- anchor: user.invoicing.customer -->
### La page d'un client et son relevé

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez tout sur un client : ce qu'il doit, ses factures et un relevé à lui envoyer.

<p><img src="images/user-invoicing-customer--balance.en.jpg" width="280"></p>

*Doit*

<p><img src="images/user-invoicing-customer--story.en.jpg" width="280"></p>

*Historique*

<details>
<summary>Capture complète (en anglais)</summary>

<p><img src="images/user-invoicing-customer.en.jpg" width="280"></p>

</details>

**Étapes**

1. Dans [Facturation](app:/invoices), touchez le client.
2. Lisez ce qu'il **Doit**, ou **Rien à payer**, et son avoir éventuel : les paiements qu'aucune facture n'a encore pris.
3. Lisez les **Factures** et l'**Historique** : émissions, paiements, relances partagées, paiements déclarés.
4. Touchez **Relevé de compte** pour les éléments ouverts à ce jour, ou **Relevé sur une période** pour les mouvements entre deux dates avec le solde d'ouverture et de clôture.

**Bon à savoir**

- Un relevé est dans une seule devise ; s'il y en a plusieurs, vous choisissez laquelle.
- S'il n'y a rien d'ouvert, il n'y a pas de relevé à ce jour à imprimer.
- Dans un relevé sur une période, les soldes avant le premier jour enregistré sont reconstitués à partir des données d'aujourd'hui, et le relevé le dit.

**Voir aussi:** [Rapprocher un paiement reçu](help:user.invoicing.payments)

<!-- anchor: user.invoicing.wizard -->
### L'assistant de clôture

**Public:** Propriétaire · Administrateur·rice facturation

Un seul parcours guidé pour la routine financière : émettre, envoyer, relancer, enregistrer les paiements, rapprocher et clôturer.

<p><img src="images/user-invoicing-wizard.fr.jpg" width="280"></p>

**Étapes**

1. Dans [Facturation](app:/invoices), touchez **Plus** puis **Assistant de clôture** (ou ouvrez l'[Assistant de facturation](app:/invoicing/wizard)).
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

1. Dans [Facturation](app:/invoices), touchez **Plus** puis **Regrouper des factures en une**.
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

1. Ouvrez [Mes finances](app:/money) et touchez **Répartir une dépense**, à côté de **Achats**.
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

1. Dans [Facturation](app:/invoices), touchez **Plus** puis **Règles de relance**.
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

1. Ouvrez **Règles de relance** depuis **Plus** dans Facturation.
2. Activez **Relances automatiques**.
3. Touchez **Enregistrer**.

**Bon à savoir**

- Une fois par jour, les factures qui ont dépassé leur échéance enregistrée passent au niveau suivant, pour le montant encore dû.
- Jamais tant qu'un paiement est en attente ou que la facture est suspendue. Les factures sans échéance enregistrée vous sont laissées.
- Désactivées : vous envoyez chaque relance vous-même.
- Quand cela s'exécute : chaque matin sur le serveur si l'installation planifie des tâches, sinon quand un administrateur ouvre Finances. L'opérateur de votre serveur sait ce qui s'applique.
- L’acceptation d’une demande push par le serveur ne prouve pas sa réception par un appareil. Le résultat reste inconnu lorsque le service push ne révèle pas la livraison ; le rappel reste enregistré et la somme due ne change pas.

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

<!-- anchor: user.money.accounting-journals -->
### Vos journaux comptables

**Public:** Propriétaire

Le logiciel de votre comptable connaît vos journaux sous ses propres codes, et vous voulez que chaque export les utilise.

<!-- image: user-money-accounting-journals -->

**Étapes**

1. Ouvrez [Comptabilité et TVA](app:/money/accounting) et touchez **Journaux comptables**.
2. Pour **Ventes**, **Banque**, **Achats** et **Opérations diverses**, saisissez le **Code** et le **Libellé** qu'utilise votre comptable.
3. Touchez **Enregistrer**. **Utiliser les codes standard** remet les codes standard du pays.

**Bon à savoir**

- Chaque export comptable de l'application les utilise : le FEC, le journal générique, les grands livres SAF-T et les livres imprimés.
- Un code n'a ni saut de ligne, ni tabulation, ni |, et deux journaux n'ont jamais le même code ; le formulaire dit quel champ corriger.
- Un code modifié change aussi les numéros d'écriture d'une période exportée à nouveau.
- Les envois vers Pennylane et Business Central utilisent aussi ces codes ; le journal doit y exister sous le même code.

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

<!-- anchor: user.invoicing.transfers -->
### Transferts : le lien numérique vers votre système comptable

**Public:** Propriétaire · Administrateur·rice facturation

Vous tenez vos registres de TVA dans un autre système comptable, et vous devez montrer comment les chiffres y sont arrivés, par exemple pour le Making Tax Digital britannique.

**Étapes**

1. Ouvrez [Comptabilité et TVA](app:/money/accounting) et touchez **Systèmes comptables**.
2. Lisez **Transferts** : chaque fichier remis et chaque document livré à une connexion sur la période, chacun avec le SHA-256 de ce qui a été transmis.
3. Remettez le **CSV comptable** à votre comptable. Son `report.json` cite la liste des Transferts de l'année.

**Bon à savoir**

- Un lien numérique est un fichier ou une livraison par connexion enregistré dans **Transferts**. Recopier des chiffres à la main dans l'autre système n'est pas un lien numérique.
- Le SHA-256 prouve que le fichier reçu par l'autre système est celui que DesKilo a remis.
- Une liste vide indique « Rien n'a été remis ni envoyé dans cette période. »

**Voir aussi:** [Exports comptables](help:user.invoicing.accounting-export) · [Où les registres sont conservés](help:user.invoicing.records-location)

<!-- anchor: user.invoicing.records-location -->
### Où les registres sont conservés

**Public:** Propriétaire · Administrateur·rice facturation · Opérateur·rice

Certains pays disent où une entreprise conserve ses livres, et vous voulez savoir ce que l'application indique pour la vôtre.

**Étapes**

1. Ouvrez [Identité légale et facturation électronique](app:/legal-identity) et allez à la section **Livre comptable**.
2. Lisez **Où les registres sont conservés**, à côté des durées de conservation.
3. Pour une entreprise canadienne dont les registres sont conservés hors du Canada, saisissez **Autorisation de l'ARC de conserver les registres hors du Canada** dans les paramètres de l'espace, sous **Lieu de conservation des registres**.

**Bon à savoir**

- L'opérateur·rice de l'installation déclare **Pays où cette installation conserve ses données**, comme le contrat d'hébergement l'indique. L'application ne le devine jamais. Non déclaré, la tuile le dit et n'indique aucun lieu.
- Le Canada fait conserver les livres au Canada sauf autorisation de l'ARC ; l'Allemagne fait conserver les livres électroniques dans l'UE. La tuile avertit quand le pays déclaré ne convient pas.
- Une archive britannique, irlandaise, canadienne ou américaine contient ses tables avec un `tables/README.txt` qui décrit en anglais chaque table et chaque colonne, et dit où les registres sont conservés.

**Voir aussi:** [Transferts : le lien numérique vers votre système comptable](help:user.invoicing.transfers)

<!-- anchor: user.invoicing.accounting-state -->
### Arrêter le nouveau travail comptable

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez que vos connecteurs comptables n'acceptent plus de nouveau travail, par exemple en changeant de comptable, sans perdre ce qui a déjà été envoyé.

**Étapes**

1. Ouvrez **Systèmes comptables** et lisez la carte **Nouveau travail comptable** : elle indique si les connecteurs sont **Actif**, **En maintenance** ou **Retiré**.
2. Pour mettre en pause, touchez **Arrêter le nouveau travail**. Pour admettre de nouveau du travail, touchez **Reprendre le nouveau travail**.
3. Le propriétaire peut toucher **Retirer les connecteurs** depuis la maintenance, et **Rouvrir en maintenance** depuis l'état retiré. Les deux demandent un **Motif**.

**Bon à savoir**

- Tant que rien de nouveau n'est admis, vous pouvez encore lire l'historique, révoquer une connexion et terminer les livraisons déjà commencées.
- Le retrait est refusé tant que des livraisons sont en cours ; terminez-les ou réglez-les d'abord.
- La carte n'est montrée qu'aux personnes qui gèrent les connecteurs ; seul le propriétaire voit les actions de retrait et de réouverture.
- Sans décision propre, la carte suit le réglage des connecteurs comptables.

**Voir aussi :** [Exports comptables](help:user.invoicing.accounting-export)

<!-- anchor: user.invoicing.bi -->
### Analyse d'activité

**Public:** Propriétaire · Administrateur·rice facturation

Vous regardez comment l'espace se porte.

**Étapes**

1. Ouvrez [Analyse d’activité](app:/bi), ou **Reporting** dans le menu.
2. Choisissez la **Durée de la période** (**Mois**, **Trimestre**, **Année**), une comparaison, et un regroupement là où il est proposé.
3. Lisez les analyses par domaine, comme **Finances** (**Facturé**, **Encaissé**) et **Espaces et capacité**.
4. Enregistrez une vue sous **Vues**, ou touchez **Exporter en PDF**.

**Analyses affichées** choisit les analyses que la page montre et leur ordre : cochez celles que vous voulez et faites glisser la poignée d’une ligne pour la déplacer (les flèches à côté font de même au clavier). Votre choix est mémorisé pour vous dans cet espace, sur tout appareil, et s’ouvre de nouveau la fois suivante ; une adresse qui nomme des analyses, ou une vue que vous ouvrez, l’emporte pour cette visite. **Retour au standard** l’efface.

**Bon à savoir**

- Vous ne voyez que les analyses que vous avez le droit de lire.
- « Encaissé » désigne les paiements rapprochés des factures. Ce n'est pas un bénéfice : aucun coût n'entre dans le chiffre.
- La période en cours est partielle ; ses chiffres changent encore.

**Voir aussi:** [L'écran Facturation](help:user.invoicing.hub)

<!-- anchor: user.invoicing.bi-costs -->
### Charges, échéances et charges partagées dans l'analyse

**Public:** Propriétaire · Administrateur·rice facturation

Vous voulez le côté achats de l'analyse : ce que l'espace a dépensé, doit encore et s'attend encore à payer, et comment les charges partagées pèsent sur chaque ressource.

**Étapes**

1. Ouvrez [Analyse d’activité](app:/bi) et choisissez les mois.
2. Lisez **Charges d'exploitation (enregistrées)**, **Facturé moins charges d'exploitation enregistrées**, **Amortissements comptables (enregistrés)** et **Équipement acquis (immobilisé)**.
3. Lisez **Payé (enregistré)**, **Reste à facturer (contrats)** et **À payer attendu (dû + contrats)** pour la trésorerie.
4. Lisez **Charges partagées par ressource**, et touchez **Règles de répartition** pour dire comment une catégorie d'achat se répartit sur les étages et les bureaux.
5. Dans une règle, choisissez la **Catégorie d'achat** (ou **Une ligne d'achat**), les **Poids (nombres entiers ; vide ou 0 : aucune part)**, la **Base (pourquoi ces poids)** et **En vigueur à partir du**, puis enregistrez. **Arrêter la règle** y met fin à partir de ce mois.

**Bon à savoir**

- Les chiffres disent ce qu'ils comptent. **Facturé moins charges d'exploitation enregistrées** n'est pas un bénéfice : ni amortissements, ni salaires, ni frais bancaires. **Payé (enregistré)** reprend les paiements enregistrés, pas un solde bancaire rapproché.
- Les amortissements ne sont connus que si les valeurs comptables confirmées par votre expert-comptable couvrent exactement les mois choisis ; sinon ils sont inconnus, jamais 0.
- Une charge qu'aucune règle ne répartit reste non affectée, jamais partagée à parts égales. La répartition est une analyse : aucun membre n'est facturé et aucun document ne change.
- Les règles de répartition demandent **Gérer les tarifs et règles de facturation**.

**Voir aussi:** [Analyse d'activité](help:user.invoicing.bi) · [Le registre des équipements](help:user.money.purchases.equipment)
