// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1635 — the evaluation page's words and its planner form. The
// arithmetic is web/cost_planner.js; this file turns form fields into a
// scenario and a plan into sentences. No network: the page's CSP sets
// connect-src 'none', and nothing here fetches, posts or reports.
import { planCost, parseScenario, serializeScenario, minorDigits } from './cost_planner.js';
import { CAPABILITIES } from './product_capabilities.js';

export const LOCALES = ['en', 'fr', 'de', 'es', 'it'];

export const TEXT = {
  en: {
    colon: ': ',
    beta: 'Beta', language: 'Language',
    tagline: 'A booking and money app for coworking communities.',
    startTitle: 'Start', actionDemo: 'Explore the demo', actionSignIn: 'Sign in or get started', actionJoin: 'Join with an invitation',
    startNote: 'The demo opens from the sign-in screen ("Explore the demo") and resets when you leave it. To join, sign in, then paste the code you were given. Nothing is created or joined by opening this page.',
    operatorNote: "Running your own server is an operator's task, set up from the app's Server screen; it is never needed to try the app or join a space.",
    questionsTitle: 'The three questions it answers',
    q1: 'Where can I work? The plan shows every place and who holds it, for any day.',
    q2: 'What do I owe? Each member reads their own statement: subscription, use, credits and payments.',
    q3: 'Who must approve this? Expenses, deletions and changes go to the people the community named.',
    demoTitle: 'Try it in the demo',
    demo1: 'Book a place for a half-day, then read what it used of your allowance on your statement.',
    demo2: 'Submit a community expense and approve it as another member.',
    demo3: 'Open a request still waiting for a decision and see who may decide it.',
    demoNote: 'The demo is a fictional community on your device; nothing you do there reaches a server.',
    statusTitle: 'Where it runs today', platform: 'Platform', status: 'Status',
    statusWeb: 'Available in the browser', statusAndroid: 'Closed test on Google Play', statusIos: 'Public beta through TestFlight', statusDesktop: 'Installers attached to each release',
    statusNote: 'As of 27 September 2026. Features still being built are not listed as available.',
    capsTitle: 'What it does today', capsName: 'Capability', capsState: 'State',
    capStateVerified: 'Available, checked on a real installation',
    capStateTested: 'Available, covered by automated tests; not yet checked on a real installation',
    capStatePlanned: 'Planned, not available yet',
    capStateUnknown: 'Not verified',
    capsNote: 'Generated from the project’s capability evidence. A test that passes is not a certification.',
    'cap_booking': 'Booking a place',
    'cap_membership_allowances': 'Membership allowances',
    'cap_statements_shared_expenses': 'Statements and shared expenses',
    'cap_approvals': 'Approvals by the people named',
    'cap_payments_stripe': 'Payments with Stripe',
    'cap_payments_paypal': 'Payments with PayPal',
    'cap_payments_mollie': 'Payments with Mollie',
    'cap_payments_wero': 'Payments with Wero',
    'cap_accounting_export': 'Accounting export',
    'cap_einvoice_generate': 'E-invoices: creating them',
    'cap_einvoice_transmit': 'E-invoices: sending them',
    'cap_recovery_database_restore': 'Database restore',
    'cap_recovery_storage_auth': 'Local application recovery drill',
    'cap_demo': 'The demo',
    'cap_mcp_read': 'Assistants: reading',
    'cap_mcp_write': 'Assistants: acting',
    'cap_mcp_consent': 'Assistants: consent',
    'cap_calendar_interchange': 'Calendar file export (.ics)',
    'cap_suppliers_lookup': 'Supplier VAT lookup',
    'cap_purchases_payables': 'Purchases and payables',
    'cap_purchases_orders': 'Supplier purchase orders',
    'cap_guests_passes': 'Guest passes',
    'cap_bank_reconciliation': 'Bank statement reconciliation',
    'cap_accounting_connections': 'Accounting connections',
    'cap_tax_hmrc_mtd': 'UK VAT returns through HMRC MTD',
    'cap_personal_workspace_separation': 'Personal home and workspaces',
    'cap_setup_guide': 'Workspace setup guide',
    'cap_privacy_member_rights': 'Member data rights',
    'cap_webmcp_browser': 'Browser assistants with WebMCP',
    rolesTitle: 'Who is responsible for what',
    roleOwner: 'The workspace owner sets the rules, prices and members.',
    roleDba: 'A database administrator decides which assistants may connect and how.',
    roleOperator: 'Whoever runs the server keeps it updated and restorable.',
    roleMember: 'Each member decides whether an assistant may act for them.',
    supportNote: 'There is no support contract or guaranteed response time.',
    svcTitle: 'Who provides what',
    svcIntro: 'DesKilo is free software. The business around it is paid support, consultancy, hosting and maintenance. There are three ways to run it. “To be agreed” means that no price, hours or service level has been chosen yet.',
    svcColSelf: 'Run it yourself',
    svcColEngaged: 'Your server, with a service engagement',
    svcColHosted: 'Hosted by the author',
    svcRowBackend: 'Backend and credentials',
    svcRowBackup: 'Backups and restore tests',
    svcRowIncidents: 'Updates, monitoring, incidents',
    svcRowRecurring: 'Recurring cost',
    svcRowOneTime: 'One-time work',
    svcRowExit: 'Leaving',
    svcBackendSelf: 'You own the Supabase project and its credentials.',
    svcBackendEngaged: 'You own the project and its credentials. The access the provider receives is to be agreed.',
    svcBackendHosted: 'The author operates the backend. Before any charge starts, you can choose to move to your own server.',
    svcBackupSelf: 'You. The operations guide shows how to dump the data, keep a copy outside the account and restore it; the restore procedure is rehearsed in the project’s automated checks.',
    svcBackupEngaged: 'You stay the owner of the backups. Whether the provider takes, keeps or test-restores them is to be agreed.',
    svcBackupHosted: 'No guarantee about availability or data location. Backup retention and restore time are undecided.',
    svcIncidentsSelf: 'You apply the updates, watch your instance and read the security notices; the doctor command checks it.',
    svcIncidentsEngaged: 'Updates, monitoring, incident handling, supported versions, channel and hours are to be agreed. A response commitment (a first answer) and a resolution commitment (a fix) are agreed separately.',
    svcIncidentsHosted: 'Best effort by one person. No support contract, no guaranteed response or resolution time.',
    svcRecurringSelf: 'No fee from DesKilo. Your own hosting, payment provider and time.',
    svcRecurringEngaged: 'A recurring service fee: to be agreed, not priced here.',
    svcRecurringHosted: 'Free until 31 December 2027. From 1 January 2028, free up to five active subscribers (eight for nonprofits); planned above that: from €29 a month on the shared server, from €79 on an isolated project. A planned tariff, not a support quote.',
    svcOneTimeSelf: 'Your own time: the setup hours in the planner below.',
    svcOneTimeEngaged: 'Assisted launch and member import from €490; migrations, templates, integrations and customisation as agreed projects.',
    svcOneTimeHosted: 'The same agreed projects can be ordered.',
    svcExitSelf: 'Your data is in your own project; the operations guide shows how to dump it and restore it elsewhere.',
    svcExitEngaged: 'The same: the project is yours. The duties of each side at handover are to be agreed.',
    svcExitHosted: 'Moving to your own server is offered before any charge starts. How the data is handed over is to be agreed.',
    svcNoteSelfService: 'Setup, ordinary configuration, the help and the everyday invoice and booking workflows are self-service. Paid help is for onboarding, migration, reliability and custom work; a product defect is a matter for the issue tracker, not a billable service.',
    svcNoteNoContract: 'Nothing here is a contract or a quote.',
    svcOpsLink: 'Operations guide: backup, restore, rollback',
    plannerSubtotalNote: 'A total is the known subtotal plus the items listed as not counted. Administration you do yourself is not free: enter your hours and the value of an hour, or it stays listed as not counted. The hosting dates and amounts above are not a full support quote.',
    plannerTitle: 'Plan your operating cost',
    plannerNote: 'Every value is yours to enter; nothing is looked up. A blank field is unknown, not free. Taxes are not included.',
    currency: 'Currency (ISO code)', setupTitle: 'One-time setup', setupHours: 'Setup hours', hourlyValue: 'Value of an hour',
    monthlyTitle: 'Each month', backendPlan: 'Server plan', storageUsed: 'Storage used (GB)', storageFree: 'Storage included (GB)', storagePrice: 'Price per extra GB',
    foreignTitle: 'A cost in another currency',
    foreignAmount: 'Monthly amount',
    foreignCurrency: 'Its currency (ISO code)',
    foreignRate: 'Rate: 1 unit of it in the scenario currency',
    foreignDate: 'Rate date',
    foreignSource: 'Where the rate comes from',
    foreignNote: 'The rate is yours: nothing is looked up. Without a valid rate, date and source this cost stays out of the total.',
    resultConverted: 'Converted',
    backup: 'Backup and monitoring', payCount: 'Online payments', payAverage: 'Average payment', payPercent: 'Provider fee (%)', payFixed: 'Provider fee per payment',
    adminHours: 'Admin hours', assistantFunding: 'Assistant', assistantUser: 'Members bring their own', assistantDeskilo: 'Paid by the community',
    assistantTokens: 'Assistant tokens', assistantPrice: 'Price per million tokens',
    save: 'Save scenario', load: 'Load a scenario', print: 'Print', reset: 'Reset',
    licence: 'Free software under the GNU AGPL 3.0 or later; anyone using the code must credit its author.',
    resultOneTime: 'One-time setup', resultMonthly: 'Each month',
    resultIncomplete: 'at least — some values are still unknown', resultUnresolved: 'Not counted',
    reasonUnknown: 'left blank', reasonInvalid: 'not a valid number', reasonMixed: 'another currency',
    resultExcluded: 'Not included: taxes, fees you did not enter, exchange-rate changes.',
    resultInvalidCurrency: 'Enter a three-letter currency code, such as EUR.', loadFailed: 'This file is not a scenario this page can read.',
  },
  fr: {
    colon: ' : ',
    beta: 'Bêta', language: 'Langue',
    tagline: 'Une application de réservation et de comptes pour les communautés de coworking.',
    startTitle: 'Commencer', actionDemo: 'Explorer la démo', actionSignIn: 'Se connecter ou commencer', actionJoin: 'Rejoindre avec une invitation',
    startNote: 'La démo s’ouvre depuis l’écran de connexion (« Explorer la démo ») et se réinitialise quand vous la quittez. Pour rejoindre, connectez-vous puis collez le code reçu. Ouvrir cette page ne crée ni ne rejoint rien.',
    operatorNote: 'Faire tourner votre propre serveur est une tâche d’opérateur, depuis l’écran Serveur de l’app ; ce n’est jamais nécessaire pour essayer l’app ou rejoindre un espace.',
    questionsTitle: 'Les trois questions auxquelles elle répond',
    q1: 'Où puis-je travailler ? Le plan montre chaque place et qui l’occupe, pour n’importe quel jour.',
    q2: 'Que dois-je ? Chaque membre lit son propre relevé : cotisation, utilisation, crédits et paiements.',
    q3: 'Qui doit approuver ? Dépenses, suppressions et changements vont aux personnes désignées par la communauté.',
    demoTitle: 'Essayer dans la démo',
    demo1: 'Réservez une place pour une demi-journée, puis voyez sur votre relevé ce qu’elle a pris de votre forfait.',
    demo2: 'Déposez une dépense de la communauté et approuvez-la en tant qu’autre membre.',
    demo3: 'Ouvrez une demande en attente de décision et voyez qui peut en décider.',
    demoNote: 'La démo est une communauté fictive sur votre appareil ; rien de ce que vous y faites n’atteint un serveur.',
    statusTitle: 'Où elle fonctionne aujourd’hui', platform: 'Plateforme', status: 'État',
    statusWeb: 'Disponible dans le navigateur', statusAndroid: 'Test fermé sur Google Play', statusIos: 'Bêta publique via TestFlight', statusDesktop: 'Installateurs joints à chaque version',
    statusNote: 'Au 27 septembre 2026. Les fonctionnalités encore en construction ne sont pas indiquées comme disponibles.',
    capsTitle: 'Ce qu’elle fait aujourd’hui', capsName: 'Fonction', capsState: 'État',
    capStateVerified: 'Disponible, vérifié sur une vraie installation',
    capStateTested: 'Disponible, couvert par des tests automatiques ; pas encore vérifié sur une vraie installation',
    capStatePlanned: 'Prévu, pas encore disponible',
    capStateUnknown: 'Non vérifié',
    capsNote: 'Généré à partir des preuves de fonctionnement du projet. Un test réussi n’est pas une certification.',
    'cap_booking': 'Réserver une place',
    'cap_membership_allowances': 'Forfaits d’adhésion',
    'cap_statements_shared_expenses': 'Relevés et dépenses partagées',
    'cap_approvals': 'Validations par les personnes désignées',
    'cap_payments_stripe': 'Paiements avec Stripe',
    'cap_payments_paypal': 'Paiements avec PayPal',
    'cap_payments_mollie': 'Paiements avec Mollie',
    'cap_payments_wero': 'Paiements avec Wero',
    'cap_accounting_export': 'Export comptable',
    'cap_einvoice_generate': 'Factures électroniques : création',
    'cap_einvoice_transmit': 'Factures électroniques : envoi',
    'cap_recovery_database_restore': 'Restauration de la base',
    'cap_recovery_storage_auth': 'Exercice local de restauration de l’application',
    'cap_demo': 'La démo',
    'cap_mcp_read': 'Assistants : lecture',
    'cap_mcp_write': 'Assistants : actions',
    'cap_mcp_consent': 'Assistants : consentement',
    'cap_calendar_interchange': 'Export de fichier calendrier (.ics)',
    'cap_suppliers_lookup': 'Recherche de fournisseurs par numéro de TVA',
    'cap_purchases_payables': 'Achats et sommes à payer',
    'cap_purchases_orders': 'Commandes fournisseurs',
    'cap_guests_passes': 'Pass invités',
    'cap_bank_reconciliation': 'Rapprochement bancaire',
    'cap_accounting_connections': 'Connexions comptables',
    'cap_tax_hmrc_mtd': 'Déclarations de TVA au Royaume-Uni (HMRC MTD)',
    'cap_personal_workspace_separation': 'Espace personnel et espaces de travail',
    'cap_setup_guide': 'Guide de configuration de l’espace',
    'cap_privacy_member_rights': 'Droits sur les données personnelles',
    'cap_webmcp_browser': 'Assistants du navigateur avec WebMCP',
    rolesTitle: 'Qui est responsable de quoi',
    roleOwner: 'Le propriétaire de l’espace fixe les règles, les prix et les membres.',
    roleDba: 'Un administrateur de base de données décide quels assistants peuvent se connecter, et comment.',
    roleOperator: 'Qui fait tourner le serveur le tient à jour et restaurable.',
    roleMember: 'Chaque membre décide si un assistant peut agir pour lui.',
    supportNote: 'Il n’y a ni contrat d’assistance ni délai de réponse garanti.',
    svcTitle: 'Qui fournit quoi',
    svcIntro: 'DesKilo est un logiciel libre. L’activité qui l’entoure est payante : assistance, conseil, hébergement et maintenance. Il y a trois façons de l’exploiter. « À convenir » signifie qu’aucun prix, horaire ni niveau de service n’a encore été choisi.',
    svcColSelf: 'L’exploiter soi-même',
    svcColEngaged: 'Votre serveur, avec une mission de service',
    svcColHosted: 'Hébergé par l’auteur',
    svcRowBackend: 'Serveur et identifiants',
    svcRowBackup: 'Sauvegardes et tests de restauration',
    svcRowIncidents: 'Mises à jour, surveillance, incidents',
    svcRowRecurring: 'Coût récurrent',
    svcRowOneTime: 'Travaux ponctuels',
    svcRowExit: 'Partir',
    svcBackendSelf: 'Vous possédez le projet Supabase et ses identifiants.',
    svcBackendEngaged: 'Vous possédez le projet et ses identifiants. L’accès donné au prestataire est à convenir.',
    svcBackendHosted: 'L’auteur exploite le serveur. Avant tout paiement, vous pouvez choisir de passer sur votre propre serveur.',
    svcBackupSelf: 'Vous. Le guide d’exploitation montre comment exporter les données, en garder une copie hors du compte et les restaurer ; la procédure de restauration est répétée dans les contrôles automatiques du projet.',
    svcBackupEngaged: 'Vous restez propriétaire des sauvegardes. Que le prestataire les réalise, les conserve ou en teste la restauration est à convenir.',
    svcBackupHosted: 'Aucune garantie de disponibilité ni de lieu des données. La durée de conservation des sauvegardes et le délai de restauration ne sont pas décidés.',
    svcIncidentsSelf: 'Vous appliquez les mises à jour, surveillez votre instance et lisez les avis de sécurité ; la commande doctor la contrôle.',
    svcIncidentsEngaged: 'Mises à jour, surveillance, traitement des incidents, versions prises en charge, canal et horaires sont à convenir. Un engagement de réponse (une première réponse) et un engagement de résolution (un correctif) se conviennent séparément.',
    svcIncidentsHosted: 'Au mieux, par une seule personne. Ni contrat d’assistance, ni délai de réponse ou de résolution garanti.',
    svcRecurringSelf: 'Aucuns frais de DesKilo. Votre propre hébergement, votre prestataire de paiement et votre temps.',
    svcRecurringEngaged: 'Des frais de service récurrents : à convenir, non chiffrés ici.',
    svcRecurringHosted: 'Gratuit jusqu’au 31 décembre 2027. À partir du 1er janvier 2028, gratuit jusqu’à cinq abonnés actifs (huit pour les organisations à but non lucratif) ; prévu au-delà : dès 29 € par mois sur le serveur partagé, dès 79 € sur un projet isolé. Un tarif prévu, pas un devis d’assistance.',
    svcOneTimeSelf: 'Votre propre temps : les heures de mise en place du simulateur ci-dessous.',
    svcOneTimeEngaged: 'Lancement accompagné et import des membres dès 490 € ; migrations, modèles, intégrations et personnalisation sous forme de projets convenus.',
    svcOneTimeHosted: 'Les mêmes projets convenus peuvent être commandés.',
    svcExitSelf: 'Vos données sont dans votre propre projet ; le guide d’exploitation montre comment les exporter et les restaurer ailleurs.',
    svcExitEngaged: 'Pareil : le projet est le vôtre. Les devoirs de chaque partie lors de la remise sont à convenir.',
    svcExitHosted: 'Le passage sur votre propre serveur est proposé avant tout paiement. La façon de remettre les données est à convenir.',
    svcNoteSelfService: 'La mise en place, la configuration courante, l’aide et les tâches quotidiennes de facturation et de réservation se font en autonomie. L’aide payante sert à l’accompagnement, aux migrations, à la fiabilité et aux développements sur mesure ; un défaut du produit relève du suivi des tickets, pas d’une prestation facturable.',
    svcNoteNoContract: 'Rien ici n’est un contrat ni un devis.',
    svcOpsLink: 'Guide d’exploitation : sauvegarde, restauration, retour arrière',
    plannerSubtotalNote: 'Un total est le sous-total connu plus les éléments indiqués comme non comptés. L’administration que vous faites vous-même n’est pas gratuite : saisissez vos heures et la valeur d’une heure, sinon elle reste indiquée comme non comptée. Les dates et montants d’hébergement ci-dessus ne forment pas un devis d’assistance complet.',
    plannerTitle: 'Estimer votre coût de fonctionnement',
    plannerNote: 'Chaque valeur est la vôtre ; rien n’est recherché ailleurs. Un champ vide est inconnu, pas gratuit. Les taxes ne sont pas incluses.',
    currency: 'Devise (code ISO)', setupTitle: 'Mise en place (une fois)', setupHours: 'Heures de mise en place', hourlyValue: 'Valeur d’une heure',
    monthlyTitle: 'Chaque mois', backendPlan: 'Offre serveur', storageUsed: 'Stockage utilisé (Go)', storageFree: 'Stockage inclus (Go)', storagePrice: 'Prix par Go supplémentaire',
    foreignTitle: 'Un coût dans une autre devise',
    foreignAmount: 'Montant mensuel',
    foreignCurrency: 'Sa devise (code ISO)',
    foreignRate: 'Taux : 1 unité de cette devise dans la devise du scénario',
    foreignDate: 'Date du taux',
    foreignSource: 'Origine du taux',
    foreignNote: 'Le taux est le vôtre : rien n’est consulté en ligne. Sans taux, date et origine valides, ce coût reste hors du total.',
    resultConverted: 'Converti',
    backup: 'Sauvegarde et surveillance', payCount: 'Paiements en ligne', payAverage: 'Paiement moyen', payPercent: 'Frais du prestataire (%)', payFixed: 'Frais fixes par paiement',
    adminHours: 'Heures d’administration', assistantFunding: 'Assistant', assistantUser: 'Les membres apportent le leur', assistantDeskilo: 'Payé par la communauté',
    assistantTokens: 'Jetons de l’assistant', assistantPrice: 'Prix par million de jetons',
    save: 'Enregistrer le scénario', load: 'Charger un scénario', print: 'Imprimer', reset: 'Réinitialiser',
    licence: 'Logiciel libre sous GNU AGPL 3.0 ou ultérieure ; quiconque utilise le code doit en créditer l’auteur.',
    resultOneTime: 'Mise en place', resultMonthly: 'Chaque mois',
    resultIncomplete: 'au moins — certaines valeurs restent inconnues', resultUnresolved: 'Non compté',
    reasonUnknown: 'laissé vide', reasonInvalid: 'nombre invalide', reasonMixed: 'autre devise',
    resultExcluded: 'Non inclus : taxes, frais non saisis, variations de change.',
    resultInvalidCurrency: 'Saisissez un code devise de trois lettres, par exemple EUR.', loadFailed: 'Ce fichier n’est pas un scénario que cette page sait lire.',
  },
  de: {
    colon: ': ',
    beta: 'Beta', language: 'Sprache',
    tagline: 'Eine Buchungs- und Abrechnungs-App für Coworking-Gemeinschaften.',
    startTitle: 'Loslegen', actionDemo: 'Demo ansehen', actionSignIn: 'Anmelden oder starten', actionJoin: 'Mit Einladung beitreten',
    startNote: 'Die Demo öffnet sich vom Anmeldebildschirm aus („Demo ansehen“) und wird beim Verlassen zurückgesetzt. Zum Beitreten melden Sie sich an und fügen den erhaltenen Code ein. Das Öffnen dieser Seite legt nichts an und tritt nichts bei.',
    operatorNote: 'Einen eigenen Server zu betreiben ist Aufgabe eines Betreibers, eingerichtet über den Server-Bildschirm der App; zum Ausprobieren oder Beitreten ist es nie nötig.',
    questionsTitle: 'Die drei Fragen, die sie beantwortet',
    q1: 'Wo kann ich arbeiten? Der Plan zeigt jeden Platz und wer ihn belegt, für jeden Tag.',
    q2: 'Was schulde ich? Jedes Mitglied liest seine eigene Übersicht: Beitrag, Nutzung, Guthaben und Zahlungen.',
    q3: 'Wer muss das genehmigen? Ausgaben, Löschungen und Änderungen gehen an die von der Gemeinschaft benannten Personen.',
    demoTitle: 'In der Demo ausprobieren',
    demo1: 'Buchen Sie einen Platz für einen halben Tag und lesen Sie in Ihrer Übersicht, was er von Ihrem Kontingent verbraucht hat.',
    demo2: 'Reichen Sie eine Gemeinschaftsausgabe ein und genehmigen Sie sie als anderes Mitglied.',
    demo3: 'Öffnen Sie eine Anfrage, die noch auf eine Entscheidung wartet, und sehen Sie, wer entscheiden darf.',
    demoNote: 'Die Demo ist eine fiktive Gemeinschaft auf Ihrem Gerät; nichts davon erreicht einen Server.',
    statusTitle: 'Wo sie heute läuft', platform: 'Plattform', status: 'Stand',
    statusWeb: 'Im Browser verfügbar', statusAndroid: 'Geschlossener Test bei Google Play', statusIos: 'Öffentliche Beta über TestFlight', statusDesktop: 'Installer an jeder Veröffentlichung',
    statusNote: 'Stand 27. September 2026. Funktionen im Bau werden nicht als verfügbar aufgeführt.',
    capsTitle: 'Was sie heute kann', capsName: 'Funktion', capsState: 'Stand',
    capStateVerified: 'Verfügbar, auf einer echten Installation geprüft',
    capStateTested: 'Verfügbar, durch automatische Tests abgedeckt; noch nicht auf einer echten Installation geprüft',
    capStatePlanned: 'Geplant, noch nicht verfügbar',
    capStateUnknown: 'Nicht geprüft',
    capsNote: 'Aus den Funktionsnachweisen des Projekts erzeugt. Ein bestandener Test ist keine Zertifizierung.',
    'cap_booking': 'Einen Platz buchen',
    'cap_membership_allowances': 'Kontingente der Mitgliedschaft',
    'cap_statements_shared_expenses': 'Abrechnungen und geteilte Ausgaben',
    'cap_approvals': 'Freigaben durch die benannten Personen',
    'cap_payments_stripe': 'Zahlungen mit Stripe',
    'cap_payments_paypal': 'Zahlungen mit PayPal',
    'cap_payments_mollie': 'Zahlungen mit Mollie',
    'cap_payments_wero': 'Zahlungen mit Wero',
    'cap_accounting_export': 'Buchhaltungsexport',
    'cap_einvoice_generate': 'E-Rechnungen: erstellen',
    'cap_einvoice_transmit': 'E-Rechnungen: versenden',
    'cap_recovery_database_restore': 'Datenbank wiederherstellen',
    'cap_recovery_storage_auth': 'Lokaler Wiederherstellungstest der Anwendung',
    'cap_demo': 'Die Demo',
    'cap_mcp_read': 'Assistenten: lesen',
    'cap_mcp_write': 'Assistenten: handeln',
    'cap_mcp_consent': 'Assistenten: Einwilligung',
    'cap_calendar_interchange': 'Kalenderdatei exportieren (.ics)',
    'cap_suppliers_lookup': 'Lieferantensuche per USt-IdNr.',
    'cap_purchases_payables': 'Einkäufe und Verbindlichkeiten',
    'cap_purchases_orders': 'Lieferantenbestellungen',
    'cap_guests_passes': 'Gästepässe',
    'cap_bank_reconciliation': 'Abgleich von Kontoauszügen',
    'cap_accounting_connections': 'Buchhaltungsanbindungen',
    'cap_tax_hmrc_mtd': 'Britische Umsatzsteuererklärungen (HMRC MTD)',
    'cap_personal_workspace_separation': 'Persönlicher Bereich und Workspaces',
    'cap_setup_guide': 'Leitfaden zur Workspace-Einrichtung',
    'cap_privacy_member_rights': 'Datenschutzrechte der Mitglieder',
    'cap_webmcp_browser': 'Browser-Assistenten mit WebMCP',
    rolesTitle: 'Wer wofür verantwortlich ist',
    roleOwner: 'Die Workspace-Inhaberin legt Regeln, Preise und Mitglieder fest.',
    roleDba: 'Eine Datenbankadministration entscheidet, welche Assistenten sich wie verbinden dürfen.',
    roleOperator: 'Wer den Server betreibt, hält ihn aktuell und wiederherstellbar.',
    roleMember: 'Jedes Mitglied entscheidet, ob ein Assistent für es handeln darf.',
    supportNote: 'Es gibt keinen Supportvertrag und keine garantierte Antwortzeit.',
    svcTitle: 'Wer was liefert',
    svcIntro: 'DesKilo ist freie Software. Das Geschäft darum herum sind bezahlter Support, Beratung, Hosting und Wartung. Es gibt drei Arten, sie zu betreiben. „Zu vereinbaren“ heißt: Preis, Zeiten oder Servicelevel sind noch nicht festgelegt.',
    svcColSelf: 'Selbst betreiben',
    svcColEngaged: 'Ihr Server, mit Service-Vereinbarung',
    svcColHosted: 'Vom Autor gehostet',
    svcRowBackend: 'Backend und Zugangsdaten',
    svcRowBackup: 'Backups und Wiederherstellungstests',
    svcRowIncidents: 'Updates, Überwachung, Störungen',
    svcRowRecurring: 'Laufende Kosten',
    svcRowOneTime: 'Einmalige Arbeiten',
    svcRowExit: 'Wechseln',
    svcBackendSelf: 'Das Supabase-Projekt und seine Zugangsdaten gehören Ihnen.',
    svcBackendEngaged: 'Das Projekt und seine Zugangsdaten gehören Ihnen. Welchen Zugang der Dienstleister erhält, ist zu vereinbaren.',
    svcBackendHosted: 'Der Autor betreibt das Backend. Bevor Kosten anfallen, können Sie auf einen eigenen Server wechseln.',
    svcBackupSelf: 'Sie. Das Betriebshandbuch zeigt, wie man die Daten sichert, eine Kopie außerhalb des Kontos aufbewahrt und wiederherstellt; das Verfahren wird in den automatischen Prüfungen des Projekts geübt.',
    svcBackupEngaged: 'Die Backups bleiben Ihre Sache. Ob der Dienstleister sie erstellt, aufbewahrt oder testweise wiederherstellt, ist zu vereinbaren.',
    svcBackupHosted: 'Keine Zusage zu Verfügbarkeit oder Speicherort der Daten. Aufbewahrungsdauer der Backups und Wiederherstellungszeit sind nicht entschieden.',
    svcIncidentsSelf: 'Sie spielen die Updates ein, beobachten Ihre Instanz und lesen die Sicherheitshinweise; der Befehl doctor prüft sie.',
    svcIncidentsEngaged: 'Updates, Überwachung, Störungsbearbeitung, unterstützte Versionen, Kanal und Zeiten sind zu vereinbaren. Eine Reaktionszusage (erste Antwort) und eine Lösungszusage (Behebung) werden getrennt vereinbart.',
    svcIncidentsHosted: 'Nach bestem Bemühen durch eine Person. Kein Supportvertrag, keine garantierte Reaktions- oder Lösungszeit.',
    svcRecurringSelf: 'Keine Gebühr von DesKilo. Ihr eigenes Hosting, Ihr Zahlungsdienstleister und Ihre Zeit.',
    svcRecurringEngaged: 'Ein laufendes Serviceentgelt: zu vereinbaren, hier nicht beziffert.',
    svcRecurringHosted: 'Bis 31. Dezember 2027 kostenlos. Ab 1. Januar 2028 kostenlos bis fünf aktive Abonnenten (acht für Non-Profit-Organisationen); darüber geplant: ab 29 € im Monat auf dem gemeinsamen Server, ab 79 € auf einem isolierten Projekt. Ein geplanter Tarif, kein Supportangebot.',
    svcOneTimeSelf: 'Ihre eigene Zeit: die Einrichtungsstunden im Rechner unten.',
    svcOneTimeEngaged: 'Begleiteter Start und Mitgliederimport ab 490 €; Migrationen, Vorlagen, Integrationen und Anpassungen als vereinbarte Projekte.',
    svcOneTimeHosted: 'Dieselben vereinbarten Projekte können beauftragt werden.',
    svcExitSelf: 'Ihre Daten liegen in Ihrem eigenen Projekt; das Betriebshandbuch zeigt, wie man sie sichert und anderswo wiederherstellt.',
    svcExitEngaged: 'Ebenso: das Projekt gehört Ihnen. Die Pflichten beider Seiten bei der Übergabe sind zu vereinbaren.',
    svcExitHosted: 'Der Wechsel auf einen eigenen Server wird angeboten, bevor Kosten anfallen. Wie die Daten übergeben werden, ist zu vereinbaren.',
    svcNoteSelfService: 'Einrichtung, übliche Konfiguration, die Hilfe und die täglichen Rechnungs- und Buchungsabläufe erledigen Sie selbst. Bezahlte Hilfe gibt es für Einführung, Migration, Zuverlässigkeit und individuelle Arbeiten; ein Produktfehler gehört in den Issue-Tracker und ist keine abrechenbare Leistung.',
    svcNoteNoContract: 'Nichts hier ist ein Vertrag oder ein Angebot.',
    svcOpsLink: 'Betriebshandbuch: Backup, Wiederherstellung, Rollback',
    plannerSubtotalNote: 'Eine Summe ist die bekannte Zwischensumme plus die als nicht gezählt aufgeführten Posten. Verwaltung, die Sie selbst erledigen, ist nicht kostenlos: Geben Sie Ihre Stunden und den Wert einer Stunde ein, sonst bleibt sie als nicht gezählt aufgeführt. Die Hosting-Daten und -Beträge oben sind kein vollständiges Supportangebot.',
    plannerTitle: 'Betriebskosten planen',
    plannerNote: 'Jeder Wert ist Ihre Eingabe; nichts wird nachgeschlagen. Ein leeres Feld ist unbekannt, nicht kostenlos. Steuern sind nicht enthalten.',
    currency: 'Währung (ISO-Code)', setupTitle: 'Einmalige Einrichtung', setupHours: 'Einrichtungsstunden', hourlyValue: 'Wert einer Stunde',
    monthlyTitle: 'Jeden Monat', backendPlan: 'Server-Tarif', storageUsed: 'Genutzter Speicher (GB)', storageFree: 'Enthaltener Speicher (GB)', storagePrice: 'Preis je weiterem GB',
    foreignTitle: 'Kosten in einer anderen Währung',
    foreignAmount: 'Monatlicher Betrag',
    foreignCurrency: 'Ihre Währung (ISO-Code)',
    foreignRate: 'Kurs: 1 Einheit davon in der Szenariowährung',
    foreignDate: 'Datum des Kurses',
    foreignSource: 'Quelle des Kurses',
    foreignNote: 'Der Kurs ist Ihrer: Nichts wird abgerufen. Ohne gültigen Kurs, Datum und Quelle bleiben diese Kosten außerhalb der Summe.',
    resultConverted: 'Umgerechnet',
    backup: 'Sicherung und Überwachung', payCount: 'Online-Zahlungen', payAverage: 'Durchschnittliche Zahlung', payPercent: 'Anbietergebühr (%)', payFixed: 'Anbietergebühr je Zahlung',
    adminHours: 'Verwaltungsstunden', assistantFunding: 'Assistent', assistantUser: 'Mitglieder bringen eigenen mit', assistantDeskilo: 'Von der Gemeinschaft bezahlt',
    assistantTokens: 'Assistenten-Tokens', assistantPrice: 'Preis je Million Tokens',
    save: 'Szenario speichern', load: 'Szenario laden', print: 'Drucken', reset: 'Zurücksetzen',
    licence: 'Freie Software unter GNU AGPL 3.0 oder später; wer den Code nutzt, muss den Autor nennen.',
    resultOneTime: 'Einmalige Einrichtung', resultMonthly: 'Jeden Monat',
    resultIncomplete: 'mindestens — einige Werte sind noch unbekannt', resultUnresolved: 'Nicht gezählt',
    reasonUnknown: 'leer gelassen', reasonInvalid: 'keine gültige Zahl', reasonMixed: 'andere Währung',
    resultExcluded: 'Nicht enthalten: Steuern, nicht eingegebene Gebühren, Wechselkursänderungen.',
    resultInvalidCurrency: 'Geben Sie einen dreistelligen Währungscode ein, etwa EUR.', loadFailed: 'Diese Datei ist kein Szenario, das diese Seite lesen kann.',
  },
  es: {
    colon: ': ',
    beta: 'Beta', language: 'Idioma',
    tagline: 'Una app de reservas y cuentas para comunidades de coworking.',
    startTitle: 'Empezar', actionDemo: 'Explorar la demo', actionSignIn: 'Iniciar sesión o empezar', actionJoin: 'Unirse con una invitación',
    startNote: 'La demo se abre desde la pantalla de inicio de sesión («Explorar la demo») y se restablece al salir. Para unirse, inicie sesión y pegue el código recibido. Abrir esta página no crea ni une nada.',
    operatorNote: 'Ejecutar su propio servidor es tarea de un operador, desde la pantalla Servidor de la app; nunca es necesario para probar la app o unirse a un espacio.',
    questionsTitle: 'Las tres preguntas que responde',
    q1: '¿Dónde puedo trabajar? El plano muestra cada puesto y quién lo ocupa, cualquier día.',
    q2: '¿Qué debo? Cada miembro lee su propio extracto: cuota, uso, créditos y pagos.',
    q3: '¿Quién debe aprobarlo? Gastos, eliminaciones y cambios van a las personas que la comunidad designó.',
    demoTitle: 'Pruébelo en la demo',
    demo1: 'Reserve un puesto para media jornada y vea en su extracto lo que ha usado de su cupo.',
    demo2: 'Presente un gasto de la comunidad y apruébelo como otro miembro.',
    demo3: 'Abra una solicitud pendiente de decisión y vea quién puede decidirla.',
    demoNote: 'La demo es una comunidad ficticia en su dispositivo; nada de lo que haga llega a un servidor.',
    statusTitle: 'Dónde funciona hoy', platform: 'Plataforma', status: 'Estado',
    statusWeb: 'Disponible en el navegador', statusAndroid: 'Prueba cerrada en Google Play', statusIos: 'Beta pública en TestFlight', statusDesktop: 'Instaladores en cada versión',
    statusNote: 'A 27 de septiembre de 2026. Las funciones aún en construcción no figuran como disponibles.',
    capsTitle: 'Lo que hace hoy', capsName: 'Función', capsState: 'Estado',
    capStateVerified: 'Disponible, comprobado en una instalación real',
    capStateTested: 'Disponible, cubierto por pruebas automáticas; aún no comprobado en una instalación real',
    capStatePlanned: 'Previsto, aún no disponible',
    capStateUnknown: 'Sin verificar',
    capsNote: 'Generado a partir de las pruebas de funcionamiento del proyecto. Una prueba superada no es una certificación.',
    'cap_booking': 'Reservar un puesto',
    'cap_membership_allowances': 'Cupos de la membresía',
    'cap_statements_shared_expenses': 'Extractos y gastos compartidos',
    'cap_approvals': 'Aprobaciones por las personas designadas',
    'cap_payments_stripe': 'Pagos con Stripe',
    'cap_payments_paypal': 'Pagos con PayPal',
    'cap_payments_mollie': 'Pagos con Mollie',
    'cap_payments_wero': 'Pagos con Wero',
    'cap_accounting_export': 'Exportación contable',
    'cap_einvoice_generate': 'Facturas electrónicas: creación',
    'cap_einvoice_transmit': 'Facturas electrónicas: envío',
    'cap_recovery_database_restore': 'Restauración de la base de datos',
    'cap_recovery_storage_auth': 'Prueba local de restauración de la aplicación',
    'cap_demo': 'La demo',
    'cap_mcp_read': 'Asistentes: lectura',
    'cap_mcp_write': 'Asistentes: acciones',
    'cap_mcp_consent': 'Asistentes: consentimiento',
    'cap_calendar_interchange': 'Exportación de archivos de calendario (.ics)',
    'cap_suppliers_lookup': 'Búsqueda de proveedores por NIF-IVA',
    'cap_purchases_payables': 'Compras y cuentas por pagar',
    'cap_purchases_orders': 'Pedidos a proveedores',
    'cap_guests_passes': 'Pases de invitado',
    'cap_bank_reconciliation': 'Conciliación bancaria',
    'cap_accounting_connections': 'Conexiones contables',
    'cap_tax_hmrc_mtd': 'Declaraciones de IVA británico (HMRC MTD)',
    'cap_personal_workspace_separation': 'Espacio personal y espacios de trabajo',
    'cap_setup_guide': 'Guía de configuración del espacio',
    'cap_privacy_member_rights': 'Derechos sobre los datos personales',
    'cap_webmcp_browser': 'Asistentes del navegador con WebMCP',
    rolesTitle: 'Quién es responsable de qué',
    roleOwner: 'La persona propietaria del espacio fija reglas, precios y miembros.',
    roleDba: 'Una administración de la base de datos decide qué asistentes pueden conectarse y cómo.',
    roleOperator: 'Quien ejecuta el servidor lo mantiene actualizado y recuperable.',
    roleMember: 'Cada miembro decide si un asistente puede actuar por él.',
    supportNote: 'No hay contrato de soporte ni tiempo de respuesta garantizado.',
    svcTitle: 'Quién ofrece qué',
    svcIntro: 'DesKilo es software libre. El negocio a su alrededor es de pago: soporte, consultoría, alojamiento y mantenimiento. Hay tres formas de operarlo. «Por acordar» significa que aún no se ha elegido precio, horario ni nivel de servicio.',
    svcColSelf: 'Operarlo usted mismo',
    svcColEngaged: 'Su servidor, con un contrato de servicio',
    svcColHosted: 'Alojado por el autor',
    svcRowBackend: 'Servidor y credenciales',
    svcRowBackup: 'Copias de seguridad y pruebas de restauración',
    svcRowIncidents: 'Actualizaciones, supervisión, incidencias',
    svcRowRecurring: 'Coste recurrente',
    svcRowOneTime: 'Trabajo puntual',
    svcRowExit: 'Salir',
    svcBackendSelf: 'El proyecto de Supabase y sus credenciales son suyos.',
    svcBackendEngaged: 'El proyecto y sus credenciales son suyos. El acceso que recibe el proveedor está por acordar.',
    svcBackendHosted: 'El autor opera el servidor. Antes de que empiece cualquier cobro, puede elegir pasar a su propio servidor.',
    svcBackupSelf: 'Usted. La guía de operación muestra cómo volcar los datos, guardar una copia fuera de la cuenta y restaurarla; el procedimiento de restauración se ensaya en las comprobaciones automáticas del proyecto.',
    svcBackupEngaged: 'Usted sigue siendo el propietario de las copias. Si el proveedor las hace, las conserva o prueba su restauración está por acordar.',
    svcBackupHosted: 'Sin garantía de disponibilidad ni de ubicación de los datos. La retención de copias y el tiempo de restauración no están decididos.',
    svcIncidentsSelf: 'Usted aplica las actualizaciones, vigila su instancia y lee los avisos de seguridad; el comando doctor la comprueba.',
    svcIncidentsEngaged: 'Actualizaciones, supervisión, gestión de incidencias, versiones admitidas, canal y horario están por acordar. Un compromiso de respuesta (una primera contestación) y uno de resolución (una corrección) se acuerdan por separado.',
    svcIncidentsHosted: 'Con el mejor esfuerzo de una sola persona. Sin contrato de soporte ni tiempo de respuesta o resolución garantizado.',
    svcRecurringSelf: 'Sin cuota de DesKilo. Su propio alojamiento, su proveedor de pagos y su tiempo.',
    svcRecurringEngaged: 'Una cuota de servicio recurrente: por acordar, sin precio aquí.',
    svcRecurringHosted: 'Gratis hasta el 31 de diciembre de 2027. Desde el 1 de enero de 2028, gratis hasta cinco suscriptores activos (ocho para entidades sin ánimo de lucro); previsto por encima: desde 29 € al mes en el servidor compartido, desde 79 € en un proyecto aislado. Una tarifa prevista, no un presupuesto de soporte.',
    svcOneTimeSelf: 'Su propio tiempo: las horas de puesta en marcha del simulador de abajo.',
    svcOneTimeEngaged: 'Puesta en marcha asistida e importación de miembros desde 490 €; migraciones, plantillas, integraciones y personalización como proyectos acordados.',
    svcOneTimeHosted: 'Pueden encargarse los mismos proyectos acordados.',
    svcExitSelf: 'Sus datos están en su propio proyecto; la guía de operación muestra cómo volcarlos y restaurarlos en otro sitio.',
    svcExitEngaged: 'Igual: el proyecto es suyo. Las obligaciones de cada parte en la entrega están por acordar.',
    svcExitHosted: 'El paso a su propio servidor se ofrece antes de que empiece cualquier cobro. La forma de entregar los datos está por acordar.',
    svcNoteSelfService: 'La puesta en marcha, la configuración habitual, la ayuda y los flujos diarios de facturas y reservas son autoservicio. La ayuda de pago es para la incorporación, la migración, la fiabilidad y el trabajo a medida; un defecto del producto corresponde al seguimiento de incidencias, no a un servicio facturable.',
    svcNoteNoContract: 'Nada de esto es un contrato ni un presupuesto.',
    svcOpsLink: 'Guía de operación: copia de seguridad, restauración, vuelta atrás',
    plannerSubtotalNote: 'Un total es el subtotal conocido más las partidas indicadas como no contadas. La administración que hace usted mismo no es gratis: introduzca sus horas y el valor de una hora, o seguirá indicada como no contada. Las fechas e importes de alojamiento de arriba no son un presupuesto de soporte completo.',
    plannerTitle: 'Planifique su coste de funcionamiento',
    plannerNote: 'Cada valor lo introduce usted; no se consulta nada. Un campo vacío es desconocido, no gratuito. No incluye impuestos.',
    currency: 'Moneda (código ISO)', setupTitle: 'Puesta en marcha (una vez)', setupHours: 'Horas de puesta en marcha', hourlyValue: 'Valor de una hora',
    monthlyTitle: 'Cada mes', backendPlan: 'Plan de servidor', storageUsed: 'Almacenamiento usado (GB)', storageFree: 'Almacenamiento incluido (GB)', storagePrice: 'Precio por GB adicional',
    foreignTitle: 'Un coste en otra moneda',
    foreignAmount: 'Importe mensual',
    foreignCurrency: 'Su moneda (código ISO)',
    foreignRate: 'Tipo: 1 unidad de ella en la moneda del escenario',
    foreignDate: 'Fecha del tipo',
    foreignSource: 'Origen del tipo',
    foreignNote: 'El tipo es suyo: no se consulta nada. Sin un tipo, fecha y origen válidos, este coste queda fuera del total.',
    resultConverted: 'Convertido',
    backup: 'Copias y supervisión', payCount: 'Pagos en línea', payAverage: 'Pago medio', payPercent: 'Comisión del proveedor (%)', payFixed: 'Comisión fija por pago',
    adminHours: 'Horas de administración', assistantFunding: 'Asistente', assistantUser: 'Los miembros traen el suyo', assistantDeskilo: 'Pagado por la comunidad',
    assistantTokens: 'Tokens del asistente', assistantPrice: 'Precio por millón de tokens',
    save: 'Guardar escenario', load: 'Cargar un escenario', print: 'Imprimir', reset: 'Restablecer',
    licence: 'Software libre bajo GNU AGPL 3.0 o posterior; quien use el código debe citar a su autor.',
    resultOneTime: 'Puesta en marcha', resultMonthly: 'Cada mes',
    resultIncomplete: 'como mínimo — algunos valores siguen sin conocerse', resultUnresolved: 'No contado',
    reasonUnknown: 'en blanco', reasonInvalid: 'número no válido', reasonMixed: 'otra moneda',
    resultExcluded: 'No incluido: impuestos, comisiones no introducidas, variaciones del tipo de cambio.',
    resultInvalidCurrency: 'Introduzca un código de moneda de tres letras, como EUR.', loadFailed: 'Este archivo no es un escenario que esta página pueda leer.',
  },
  it: {
    colon: ': ',
    beta: 'Beta', language: 'Lingua',
    tagline: 'Un’app di prenotazioni e conti per le comunità di coworking.',
    startTitle: 'Inizia', actionDemo: 'Esplora la demo', actionSignIn: 'Accedi o inizia', actionJoin: 'Unisciti con un invito',
    startNote: 'La demo si apre dalla schermata di accesso («Esplora la demo») e si azzera quando la lasci. Per unirti, accedi e incolla il codice ricevuto. Aprire questa pagina non crea né unisce nulla.',
    operatorNote: 'Gestire un proprio server è compito di un operatore, dalla schermata Server dell’app; non serve mai per provare l’app o unirsi a uno spazio.',
    questionsTitle: 'Le tre domande a cui risponde',
    q1: 'Dove posso lavorare? La planimetria mostra ogni posto e chi lo occupa, per qualsiasi giorno.',
    q2: 'Quanto devo? Ogni membro legge il proprio estratto: quota, utilizzo, crediti e pagamenti.',
    q3: 'Chi deve approvare? Spese, cancellazioni e modifiche vanno alle persone indicate dalla comunità.',
    demoTitle: 'Provalo nella demo',
    demo1: 'Prenota un posto per mezza giornata, poi leggi nel tuo estratto quanto ha usato del tuo monte ore.',
    demo2: 'Invia una spesa della comunità e approvala come un altro membro.',
    demo3: 'Apri una richiesta in attesa di decisione e vedi chi può deciderla.',
    demoNote: 'La demo è una comunità fittizia sul tuo dispositivo; nulla di ciò che fai raggiunge un server.',
    statusTitle: 'Dove funziona oggi', platform: 'Piattaforma', status: 'Stato',
    statusWeb: 'Disponibile nel browser', statusAndroid: 'Test chiuso su Google Play', statusIos: 'Beta pubblica tramite TestFlight', statusDesktop: 'Installatori allegati a ogni versione',
    statusNote: 'Al 27 settembre 2026. Le funzioni ancora in costruzione non sono indicate come disponibili.',
    capsTitle: 'Cosa fa oggi', capsName: 'Funzione', capsState: 'Stato',
    capStateVerified: 'Disponibile, verificata su un’installazione reale',
    capStateTested: 'Disponibile, coperta da test automatici; non ancora verificata su un’installazione reale',
    capStatePlanned: 'Prevista, non ancora disponibile',
    capStateUnknown: 'Non verificata',
    capsNote: 'Generato dalle prove di funzionamento del progetto. Un test superato non è una certificazione.',
    'cap_booking': 'Prenotare un posto',
    'cap_membership_allowances': 'Quote dell’abbonamento',
    'cap_statements_shared_expenses': 'Estratti e spese condivise',
    'cap_approvals': 'Approvazioni dalle persone indicate',
    'cap_payments_stripe': 'Pagamenti con Stripe',
    'cap_payments_paypal': 'Pagamenti con PayPal',
    'cap_payments_mollie': 'Pagamenti con Mollie',
    'cap_payments_wero': 'Pagamenti con Wero',
    'cap_accounting_export': 'Esportazione contabile',
    'cap_einvoice_generate': 'Fatture elettroniche: creazione',
    'cap_einvoice_transmit': 'Fatture elettroniche: invio',
    'cap_recovery_database_restore': 'Ripristino del database',
    'cap_recovery_storage_auth': 'Prova locale di ripristino dell’applicazione',
    'cap_demo': 'La demo',
    'cap_mcp_read': 'Assistenti: lettura',
    'cap_mcp_write': 'Assistenti: azioni',
    'cap_mcp_consent': 'Assistenti: consenso',
    'cap_calendar_interchange': 'Esportazione di file di calendario (.ics)',
    'cap_suppliers_lookup': 'Ricerca fornitori per partita IVA',
    'cap_purchases_payables': 'Acquisti e debiti da saldare',
    'cap_purchases_orders': 'Ordini ai fornitori',
    'cap_guests_passes': 'Pass per ospiti',
    'cap_bank_reconciliation': 'Riconciliazione bancaria',
    'cap_accounting_connections': 'Collegamenti contabili',
    'cap_tax_hmrc_mtd': 'Dichiarazioni IVA britanniche (HMRC MTD)',
    'cap_personal_workspace_separation': 'Area personale e spazi di lavoro',
    'cap_setup_guide': 'Guida alla configurazione dello spazio',
    'cap_privacy_member_rights': 'Diritti sui dati personali',
    'cap_webmcp_browser': 'Assistenti del browser con WebMCP',
    rolesTitle: 'Chi è responsabile di cosa',
    roleOwner: 'Chi possiede lo spazio stabilisce regole, prezzi e membri.',
    roleDba: 'Un’amministrazione del database decide quali assistenti possono collegarsi e come.',
    roleOperator: 'Chi gestisce il server lo tiene aggiornato e ripristinabile.',
    roleMember: 'Ogni membro decide se un assistente può agire per lui.',
    supportNote: 'Non esiste un contratto di assistenza né un tempo di risposta garantito.',
    svcTitle: 'Chi offre che cosa',
    svcIntro: 'DesKilo è software libero. L’attività che lo circonda è a pagamento: assistenza, consulenza, hosting e manutenzione. Esistono tre modi di gestirlo. «Da concordare» significa che prezzo, orari o livello di servizio non sono ancora stati scelti.',
    svcColSelf: 'Gestirlo in proprio',
    svcColEngaged: 'Il Suo server, con un incarico di servizio',
    svcColHosted: 'Ospitato dall’autore',
    svcRowBackend: 'Backend e credenziali',
    svcRowBackup: 'Backup e prove di ripristino',
    svcRowIncidents: 'Aggiornamenti, monitoraggio, incidenti',
    svcRowRecurring: 'Costo ricorrente',
    svcRowOneTime: 'Lavori una tantum',
    svcRowExit: 'Uscita',
    svcBackendSelf: 'Il progetto Supabase e le sue credenziali sono Suoi.',
    svcBackendEngaged: 'Il progetto e le sue credenziali sono Suoi. L’accesso concesso al fornitore è da concordare.',
    svcBackendHosted: 'L’autore gestisce il backend. Prima che inizi qualsiasi addebito, è possibile scegliere di passare al proprio server.',
    svcBackupSelf: 'È a Suo carico. La guida operativa mostra come esportare i dati, conservarne una copia fuori dall’account e ripristinarli; la procedura di ripristino viene provata nei controlli automatici del progetto.',
    svcBackupEngaged: 'I backup restano di Sua proprietà. Se il fornitore li esegue, li conserva o ne prova il ripristino è da concordare.',
    svcBackupHosted: 'Nessuna garanzia su disponibilità o luogo dei dati. Conservazione dei backup e tempo di ripristino non sono decisi.',
    svcIncidentsSelf: 'Gli aggiornamenti, il monitoraggio dell’istanza e la lettura degli avvisi di sicurezza sono a Suo carico; il comando doctor la verifica.',
    svcIncidentsEngaged: 'Aggiornamenti, monitoraggio, gestione degli incidenti, versioni supportate, canale e orari sono da concordare. Un impegno di risposta (una prima risposta) e un impegno di risoluzione (una correzione) si concordano separatamente.',
    svcIncidentsHosted: 'Al meglio delle possibilità, da una sola persona. Nessun contratto di assistenza, nessun tempo di risposta o di risoluzione garantito.',
    svcRecurringSelf: 'Nessun canone da parte di DesKilo. Il proprio hosting, il proprio fornitore di pagamenti e il proprio tempo.',
    svcRecurringEngaged: 'Un corrispettivo di servizio ricorrente: da concordare, qui non quantificato.',
    svcRecurringHosted: 'Gratuito fino al 31 dicembre 2027. Dal 1° gennaio 2028 gratuito fino a cinque abbonati attivi (otto per le organizzazioni senza scopo di lucro); previsto oltre: da 29 € al mese sul server condiviso, da 79 € su un progetto isolato. Una tariffa prevista, non un preventivo di assistenza.',
    svcOneTimeSelf: 'Il proprio tempo: le ore di avviamento nel simulatore qui sotto.',
    svcOneTimeEngaged: 'Avvio assistito e importazione dei membri da 490 €; migrazioni, modelli, integrazioni e personalizzazioni come progetti concordati.',
    svcOneTimeHosted: 'Si possono ordinare gli stessi progetti concordati.',
    svcExitSelf: 'I dati si trovano nel Suo progetto; la guida operativa mostra come esportarli e ripristinarli altrove.',
    svcExitEngaged: 'Lo stesso: il progetto è Suo. I doveri di ciascuna parte alla consegna sono da concordare.',
    svcExitHosted: 'Il passaggio al proprio server viene offerto prima che inizi qualsiasi addebito. Le modalità di consegna dei dati sono da concordare.',
    svcNoteSelfService: 'Avviamento, configurazione ordinaria, guida e flussi quotidiani di fatture e prenotazioni sono in autonomia. L’aiuto a pagamento serve per l’introduzione, la migrazione, l’affidabilità e i lavori su misura; un difetto del prodotto riguarda il tracker delle segnalazioni, non un servizio fatturabile.',
    svcNoteNoContract: 'Nulla di quanto qui indicato è un contratto o un preventivo.',
    svcOpsLink: 'Guida operativa: backup, ripristino, ritorno indietro',
    plannerSubtotalNote: 'Un totale è il subtotale noto più le voci indicate come non conteggiate. L’amministrazione svolta in proprio non è gratuita: inserire le proprie ore e il valore di un’ora, altrimenti resta indicata come non conteggiata. Le date e gli importi di hosting indicati sopra non costituiscono un preventivo di assistenza completo.',
    plannerTitle: 'Pianifica il costo di gestione',
    plannerNote: 'Ogni valore lo inserisci tu; nulla viene cercato altrove. Un campo vuoto è sconosciuto, non gratuito. Le imposte non sono incluse.',
    currency: 'Valuta (codice ISO)', setupTitle: 'Avvio (una tantum)', setupHours: 'Ore di avvio', hourlyValue: 'Valore di un’ora',
    monthlyTitle: 'Ogni mese', backendPlan: 'Piano del server', storageUsed: 'Spazio usato (GB)', storageFree: 'Spazio incluso (GB)', storagePrice: 'Prezzo per GB in più',
    foreignTitle: 'Un costo in un’altra valuta',
    foreignAmount: 'Importo mensile',
    foreignCurrency: 'La sua valuta (codice ISO)',
    foreignRate: 'Cambio: 1 unità di essa nella valuta dello scenario',
    foreignDate: 'Data del cambio',
    foreignSource: 'Fonte del cambio',
    foreignNote: 'Il cambio è il suo: nulla viene consultato. Senza cambio, data e fonte validi, questo costo resta fuori dal totale.',
    resultConverted: 'Convertito',
    backup: 'Backup e monitoraggio', payCount: 'Pagamenti online', payAverage: 'Pagamento medio', payPercent: 'Commissione del fornitore (%)', payFixed: 'Commissione fissa per pagamento',
    adminHours: 'Ore di amministrazione', assistantFunding: 'Assistente', assistantUser: 'I membri portano il proprio', assistantDeskilo: 'Pagato dalla comunità',
    assistantTokens: 'Token dell’assistente', assistantPrice: 'Prezzo per milione di token',
    save: 'Salva scenario', load: 'Carica uno scenario', print: 'Stampa', reset: 'Azzera',
    licence: 'Software libero sotto GNU AGPL 3.0 o successiva; chi usa il codice deve citarne l’autore.',
    resultOneTime: 'Avvio', resultMonthly: 'Ogni mese',
    resultIncomplete: 'almeno — alcuni valori sono ancora sconosciuti', resultUnresolved: 'Non conteggiato',
    reasonUnknown: 'lasciato vuoto', reasonInvalid: 'numero non valido', reasonMixed: 'altra valuta',
    resultExcluded: 'Non inclusi: imposte, commissioni non inserite, variazioni di cambio.',
    resultInvalidCurrency: 'Inserisci un codice valuta di tre lettere, ad esempio EUR.', loadFailed: 'Questo file non è uno scenario che questa pagina sa leggere.',
  },
};

/// #1635 — a capability's state as the page states it, from the evidence
/// only: roadmap is planned, whatever its tests; shipped needs evidence;
/// a real installation's record is the only 'verified'. Anything else is
/// unknown, never available.
export function capabilityState(c) {
  if (c.status === 'roadmap') return 'planned';
  if (c.status !== 'shipped') return 'unknown';
  if (c.evidence.some((e) => e.endsWith(':recorded'))) return 'verified';
  if (c.evidence.some((e) => e.endsWith(':gated'))) return 'tested';
  return 'unknown';
}

export const capabilityKey = (id) => `cap_${id.replace(/\./g, '_')}`;

/// The capability rows for [locale], in the manifest's order.
export function capabilityRows(locale, caps = CAPABILITIES) {
  const t = TEXT[locale] ?? TEXT.en;
  const words = {
    verified: t.capStateVerified, tested: t.capStateTested,
    planned: t.capStatePlanned, unknown: t.capStateUnknown,
  };
  return caps.map((c) => ({
    id: c.id,
    name: t[capabilityKey(c.id)] ?? c.id,
    state: capabilityState(c),
    text: words[capabilityState(c)],
  }));
}

/// A form value as the planner reads it: '' is blank (unknown), a
/// decimal with a point or a comma is a number, anything else is kept
/// as the text it was so the planner reports it invalid.
export function fieldValue(raw) {
  const s = String(raw ?? '').trim();
  if (s === '') return null;
  const normalised = s.replace(',', '.');
  return /^\d+(\.\d+)?$/.test(normalised) ? Number(normalised) : s;
}

/// The form's fields, by name, as a planner scenario.
export function scenarioFromFields(f) {
  const v = (n) => fieldValue(f[n]);
  const currency = String(f.currency ?? '').trim().toUpperCase();
  const foreign = {
    amount: v('foreign_amount'),
    currency: String(f.foreign_currency ?? '').trim().toUpperCase() || currency,
  };
  return {
    version: 1,
    currency,
    allowances: { storage: v('storage_free') },
    components: [
      { id: 'setup', kind: 'one_time', type: 'hours', hours: v('setup_hours'), hourly_value: v('hourly_value') },
      { id: 'backend_plan', kind: 'recurring', type: 'flat', amount: v('backend_plan') },
      { id: 'storage', kind: 'recurring', type: 'usage', usage: v('storage_used'), increment: 1, price_per_increment: v('storage_price'), allowance_group: 'storage' },
      { id: 'backup', kind: 'recurring', type: 'flat', amount: v('backup') },
      { id: 'payments', kind: 'recurring', type: 'payments', count: v('pay_count'), average_value: v('pay_average'), percent_fee: v('pay_percent'), fixed_fee: v('pay_fixed') },
      { id: 'admin', kind: 'recurring', type: 'hours', hours: v('admin_hours'), hourly_value: v('hourly_value') },
      { id: 'assistant', kind: 'recurring', type: 'assistant', funding: f.assistant_funding === 'deskilo' ? 'deskilo' : 'user', usage: v('assistant_tokens'), increment: 1e6, price_per_increment: v('assistant_price') },
      // Only once an amount is entered: an untouched row is not an
      // unknown cost, it is no cost the visitor has.
      ...(foreign.amount === null ? [] : [
        { id: 'foreign', kind: 'recurring', type: 'flat', amount: foreign.amount, currency: foreign.currency },
      ]),
    ],
    conversions: foreign.amount === null || foreign.currency === currency ? [] : [
      { from: foreign.currency, rate: v('foreign_rate'), date: String(f.foreign_date ?? '').trim(), source: String(f.foreign_source ?? '').trim() },
    ],
  };
}

/// The plan in words, for [locale]. Amounts use the scenario currency's
/// own decimals; a kind with anything unresolved says "at least".
export function describePlan(plan, locale) {
  const t = TEXT[locale] ?? TEXT.en;
  if (!plan.currency) return [t.resultInvalidCurrency];
  const fmt = (minor) => new Intl.NumberFormat(locale, {
    style: 'currency', currency: plan.currency,
    minimumFractionDigits: minorDigits(plan.currency), maximumFractionDigits: minorDigits(plan.currency),
  }).format(minor / 10 ** minorDigits(plan.currency));
  const reason = { unknown: t.reasonUnknown, invalid: t.reasonInvalid, mixed_currency: t.reasonMixed };
  const name = {
    setup: t.setupTitle, backend_plan: t.backendPlan, storage: t.storageUsed, backup: t.backup,
    payments: t.payCount, admin: t.adminHours, assistant: t.assistantFunding,
    foreign: t.foreignTitle,
  };
  const lines = [];
  for (const [kind, label] of [['one_time', t.resultOneTime], ['recurring', t.resultMonthly]]) {
    const b = plan[kind];
    lines.push(`${label}${t.colon}${fmt(b.known_minor)}${b.complete ? '' : ` (${t.resultIncomplete})`}`);
    for (const u of b.unresolved) {
      lines.push(`  ${t.resultUnresolved}${t.colon}${name[u.id] ?? u.id} — ${reason[u.reason] ?? u.reason}`);
    }
  }
  // #1635 — a converted cost says at what rate, on what date, from where.
  for (const l of plan.lines ?? []) {
    if (!l.provenance) continue;
    const p = l.provenance;
    lines.push(`  ${t.resultConverted}${t.colon}${name[l.id] ?? l.id} — 1 ${p.from} = ${p.rate} ${plan.currency}, ${p.date}, ${p.source}`);
  }
  lines.push(t.resultExcluded);
  return lines;
}

function wire() {
  const lang = document.getElementById('lang');
  const form = document.getElementById('planner');
  const result = document.getElementById('result');
  const fields = () => Object.fromEntries(new FormData(form).entries());
  const current = () => (LOCALES.includes(lang.value) ? lang.value : 'en');
  const render = () => {
    const locale = current();
    const plan = planCost(scenarioFromFields(fields()));
    result.replaceChildren(...describePlan(plan.ok || plan.currency ? plan : { currency: '' }, locale)
      .map((line) => Object.assign(document.createElement('p'), { textContent: line })));
  };
  const translate = () => {
    const t = TEXT[current()];
    document.documentElement.lang = current();
    for (const el of document.querySelectorAll('[data-i18n]')) {
      const text = t[el.dataset.i18n];
      if (text) el.textContent = text;
    }
    // The services table stacks on a phone: each cell then names its column.
    const heads = [...document.querySelectorAll('table.svc thead th')].map((h) => h.textContent);
    for (const row of document.querySelectorAll('table.svc tbody tr')) {
      [...row.children].forEach((cell, i) => { if (i > 0) cell.dataset.col = heads[i]; });
    }
    document.getElementById('caps').replaceChildren(...capabilityRows(current()).map((r) => {
      const tr = document.createElement('tr');
      tr.dataset.state = r.state;
      tr.append(
        Object.assign(document.createElement('td'), { textContent: r.name }),
        Object.assign(document.createElement('td'), { textContent: r.text }));
      return tr;
    }));
    render();
  };
  const browserLang = (navigator.language || 'en').slice(0, 2);
  lang.value = LOCALES.includes(browserLang) ? browserLang : 'en';
  lang.addEventListener('change', translate);
  form.addEventListener('input', render);
  form.addEventListener('reset', () => setTimeout(render));
  document.getElementById('print').addEventListener('click', () => window.print());
  document.getElementById('save').addEventListener('click', () => {
    const blob = new Blob([serializeScenario(scenarioFromFields(fields()))], { type: 'application/json' });
    const a = Object.assign(document.createElement('a'), { href: URL.createObjectURL(blob), download: 'deskilo-cost-scenario.json' });
    a.click();
    URL.revokeObjectURL(a.href);
  });
  document.getElementById('load').addEventListener('change', async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const s = parseScenario(await file.text());
      form.elements.currency.value = s.currency ?? '';
      const byId = Object.fromEntries(s.components.map((c) => [c.id, c]));
      const set = (name, value) => { form.elements[name].value = value ?? ''; };
      set('setup_hours', byId.setup?.hours); set('hourly_value', byId.setup?.hourly_value);
      set('backend_plan', byId.backend_plan?.amount); set('storage_used', byId.storage?.usage);
      set('storage_price', byId.storage?.price_per_increment); set('storage_free', s.allowances?.storage);
      set('backup', byId.backup?.amount); set('pay_count', byId.payments?.count);
      set('pay_average', byId.payments?.average_value); set('pay_percent', byId.payments?.percent_fee);
      set('pay_fixed', byId.payments?.fixed_fee); set('admin_hours', byId.admin?.hours);
      set('assistant_tokens', byId.assistant?.usage); set('assistant_price', byId.assistant?.price_per_increment);
      form.elements.assistant_funding.value = byId.assistant?.funding === 'deskilo' ? 'deskilo' : 'user';
      const conv = (s.conversions ?? [])[0];
      set('foreign_amount', byId.foreign?.amount); set('foreign_currency', byId.foreign?.currency);
      set('foreign_rate', conv?.rate); set('foreign_date', conv?.date); set('foreign_source', conv?.source);
      render();
    } catch {
      result.replaceChildren(Object.assign(document.createElement('p'), { textContent: TEXT[current()].loadFailed }));
    }
  });
  translate();
}

if (typeof document !== 'undefined') {
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', wire);
  else wire();
}
