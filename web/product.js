// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1635 — the evaluation page's words and its planner form. The
// arithmetic is web/cost_planner.js; this file turns form fields into a
// scenario and a plan into sentences. No network: the page's CSP sets
// connect-src 'none', and nothing here fetches, posts or reports.
import { planCost, parseScenario, serializeScenario, minorDigits } from './cost_planner.js';

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
    rolesTitle: 'Who is responsible for what',
    roleOwner: 'The workspace owner sets the rules, prices and members.',
    roleDba: 'A database administrator decides which assistants may connect and how.',
    roleOperator: 'Whoever runs the server keeps it updated and restorable.',
    roleMember: 'Each member decides whether an assistant may act for them.',
    supportNote: 'There is no support contract or guaranteed response time.',
    plannerTitle: 'Plan your operating cost',
    plannerNote: 'Every value is yours to enter; nothing is looked up. A blank field is unknown, not free. Taxes are not included.',
    currency: 'Currency (ISO code)', setupTitle: 'One-time setup', setupHours: 'Setup hours', hourlyValue: 'Value of an hour',
    monthlyTitle: 'Each month', backendPlan: 'Server plan', storageUsed: 'Storage used (GB)', storageFree: 'Storage included (GB)', storagePrice: 'Price per extra GB',
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
    rolesTitle: 'Qui est responsable de quoi',
    roleOwner: 'Le propriétaire de l’espace fixe les règles, les prix et les membres.',
    roleDba: 'Un administrateur de base de données décide quels assistants peuvent se connecter, et comment.',
    roleOperator: 'Qui fait tourner le serveur le tient à jour et restaurable.',
    roleMember: 'Chaque membre décide si un assistant peut agir pour lui.',
    supportNote: 'Il n’y a ni contrat d’assistance ni délai de réponse garanti.',
    plannerTitle: 'Estimer votre coût de fonctionnement',
    plannerNote: 'Chaque valeur est la vôtre ; rien n’est recherché ailleurs. Un champ vide est inconnu, pas gratuit. Les taxes ne sont pas incluses.',
    currency: 'Devise (code ISO)', setupTitle: 'Mise en place (une fois)', setupHours: 'Heures de mise en place', hourlyValue: 'Valeur d’une heure',
    monthlyTitle: 'Chaque mois', backendPlan: 'Offre serveur', storageUsed: 'Stockage utilisé (Go)', storageFree: 'Stockage inclus (Go)', storagePrice: 'Prix par Go supplémentaire',
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
    rolesTitle: 'Wer wofür verantwortlich ist',
    roleOwner: 'Die Workspace-Inhaberin legt Regeln, Preise und Mitglieder fest.',
    roleDba: 'Eine Datenbankadministration entscheidet, welche Assistenten sich wie verbinden dürfen.',
    roleOperator: 'Wer den Server betreibt, hält ihn aktuell und wiederherstellbar.',
    roleMember: 'Jedes Mitglied entscheidet, ob ein Assistent für es handeln darf.',
    supportNote: 'Es gibt keinen Supportvertrag und keine garantierte Antwortzeit.',
    plannerTitle: 'Betriebskosten planen',
    plannerNote: 'Jeder Wert ist Ihre Eingabe; nichts wird nachgeschlagen. Ein leeres Feld ist unbekannt, nicht kostenlos. Steuern sind nicht enthalten.',
    currency: 'Währung (ISO-Code)', setupTitle: 'Einmalige Einrichtung', setupHours: 'Einrichtungsstunden', hourlyValue: 'Wert einer Stunde',
    monthlyTitle: 'Jeden Monat', backendPlan: 'Server-Tarif', storageUsed: 'Genutzter Speicher (GB)', storageFree: 'Enthaltener Speicher (GB)', storagePrice: 'Preis je weiterem GB',
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
    rolesTitle: 'Quién es responsable de qué',
    roleOwner: 'La persona propietaria del espacio fija reglas, precios y miembros.',
    roleDba: 'Una administración de la base de datos decide qué asistentes pueden conectarse y cómo.',
    roleOperator: 'Quien ejecuta el servidor lo mantiene actualizado y recuperable.',
    roleMember: 'Cada miembro decide si un asistente puede actuar por él.',
    supportNote: 'No hay contrato de soporte ni tiempo de respuesta garantizado.',
    plannerTitle: 'Planifique su coste de funcionamiento',
    plannerNote: 'Cada valor lo introduce usted; no se consulta nada. Un campo vacío es desconocido, no gratuito. No incluye impuestos.',
    currency: 'Moneda (código ISO)', setupTitle: 'Puesta en marcha (una vez)', setupHours: 'Horas de puesta en marcha', hourlyValue: 'Valor de una hora',
    monthlyTitle: 'Cada mes', backendPlan: 'Plan de servidor', storageUsed: 'Almacenamiento usado (GB)', storageFree: 'Almacenamiento incluido (GB)', storagePrice: 'Precio por GB adicional',
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
    rolesTitle: 'Chi è responsabile di cosa',
    roleOwner: 'Chi possiede lo spazio stabilisce regole, prezzi e membri.',
    roleDba: 'Un’amministrazione del database decide quali assistenti possono collegarsi e come.',
    roleOperator: 'Chi gestisce il server lo tiene aggiornato e ripristinabile.',
    roleMember: 'Ogni membro decide se un assistente può agire per lui.',
    supportNote: 'Non esiste un contratto di assistenza né un tempo di risposta garantito.',
    plannerTitle: 'Pianifica il costo di gestione',
    plannerNote: 'Ogni valore lo inserisci tu; nulla viene cercato altrove. Un campo vuoto è sconosciuto, non gratuito. Le imposte non sono incluse.',
    currency: 'Valuta (codice ISO)', setupTitle: 'Avvio (una tantum)', setupHours: 'Ore di avvio', hourlyValue: 'Valore di un’ora',
    monthlyTitle: 'Ogni mese', backendPlan: 'Piano del server', storageUsed: 'Spazio usato (GB)', storageFree: 'Spazio incluso (GB)', storagePrice: 'Prezzo per GB in più',
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
  return {
    version: 1,
    currency: String(f.currency ?? '').trim().toUpperCase(),
    allowances: { storage: v('storage_free') },
    components: [
      { id: 'setup', kind: 'one_time', type: 'hours', hours: v('setup_hours'), hourly_value: v('hourly_value') },
      { id: 'backend_plan', kind: 'recurring', type: 'flat', amount: v('backend_plan') },
      { id: 'storage', kind: 'recurring', type: 'usage', usage: v('storage_used'), increment: 1, price_per_increment: v('storage_price'), allowance_group: 'storage' },
      { id: 'backup', kind: 'recurring', type: 'flat', amount: v('backup') },
      { id: 'payments', kind: 'recurring', type: 'payments', count: v('pay_count'), average_value: v('pay_average'), percent_fee: v('pay_percent'), fixed_fee: v('pay_fixed') },
      { id: 'admin', kind: 'recurring', type: 'hours', hours: v('admin_hours'), hourly_value: v('hourly_value') },
      { id: 'assistant', kind: 'recurring', type: 'assistant', funding: f.assistant_funding === 'deskilo' ? 'deskilo' : 'user', usage: v('assistant_tokens'), increment: 1e6, price_per_increment: v('assistant_price') },
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
  };
  const lines = [];
  for (const [kind, label] of [['one_time', t.resultOneTime], ['recurring', t.resultMonthly]]) {
    const b = plan[kind];
    lines.push(`${label}${t.colon}${fmt(b.known_minor)}${b.complete ? '' : ` (${t.resultIncomplete})`}`);
    for (const u of b.unresolved) {
      lines.push(`  ${t.resultUnresolved}${t.colon}${name[u.id] ?? u.id} — ${reason[u.reason] ?? u.reason}`);
    }
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
