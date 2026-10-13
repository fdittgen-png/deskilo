// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The product page's WebMCP tools (W3 of epic #2500). Everything is answered
// from the generated capability catalogue (product_capabilities.js, from
// docs/product/capabilities.json) and the page's own words (product.js): no
// network (the CSP says connect-src 'none'), nothing copied. The names and
// states follow the page language; the catalogue's prose (outcome,
// prerequisites, limitations) is the manifest's English and is marked so.
import { TEXT, LOCALES, capabilityRows } from './product.js';
import { CAPABILITIES } from './product_capabilities.js';

export const STRINGS = {
  en: { list: 'List what DesKilo does today from the capability catalogue: id, name, area, state. Optionally filter by area (the id prefix, for example payments) or by words.',
    get: 'Return one capability by id with its outcome, prerequisites, limitations, features and evidence scopes. The prose is English.',
    explain: 'Explain DesKilo in a few lines assembled only from the catalogue, naming the capability ids used. Optionally about a topic.',
    audiences: 'List who is responsible for what: owner, database administrator, server operator and member.',
    area: 'The area: the first part of a capability id.', query: 'Words to look for.', id: 'A capability id from list_capabilities.', topic: 'A word or phrase to explain.',
    notFound: 'There is no capability with this id.', textLanguage: 'The outcome, prerequisites and limitations are the manifest text, in English.' },
  fr: { list: 'Liste ce que fait DesKilo aujourd’hui d’après le catalogue des capacités : identifiant, nom, domaine, état. Filtrable par domaine (préfixe de l’identifiant, par exemple payments) ou par mots.',
    get: 'Renvoie une capacité par identifiant avec son résultat, ses prérequis, ses limites, ses fonctionnalités et les portées de preuve. Le texte est en anglais.',
    explain: 'Explique DesKilo en quelques lignes composées uniquement à partir du catalogue, en nommant les identifiants utilisés. Facultativement sur un sujet.',
    audiences: 'Liste qui est responsable de quoi : propriétaire, administrateur de base de données, opérateur du serveur et membre.',
    area: 'Le domaine : première partie d’un identifiant de capacité.', query: 'Mots à chercher.', id: 'Un identifiant de capacité issu de list_capabilities.', topic: 'Un mot ou une expression à expliquer.',
    notFound: 'Aucune capacité n’a cet identifiant.', textLanguage: 'Le résultat, les prérequis et les limites sont le texte du manifeste, en anglais.' },
  de: { list: 'Listet aus dem Fähigkeitenkatalog, was DesKilo heute kann: ID, Name, Bereich, Zustand. Filterbar nach Bereich (Präfix der ID, zum Beispiel payments) oder Wörtern.',
    get: 'Liefert eine Fähigkeit nach ID mit Ergebnis, Voraussetzungen, Grenzen, Funktionen und Nachweisbereichen. Der Text ist englisch.',
    explain: 'Erklärt DesKilo in wenigen Zeilen, allein aus dem Katalog zusammengesetzt, mit den verwendeten Fähigkeits-IDs. Optional zu einem Thema.',
    audiences: 'Listet, wer wofür verantwortlich ist: Inhaber, Datenbankadministrator, Serverbetreiber und Mitglied.',
    area: 'Der Bereich: der erste Teil einer Fähigkeits-ID.', query: 'Suchbegriffe.', id: 'Eine Fähigkeits-ID aus list_capabilities.', topic: 'Ein Wort oder eine Wendung zum Erklären.',
    notFound: 'Keine Fähigkeit hat diese ID.', textLanguage: 'Ergebnis, Voraussetzungen und Grenzen sind der Manifesttext, auf Englisch.' },
  es: { list: 'Lista lo que hace DesKilo hoy según el catálogo de capacidades: identificador, nombre, área, estado. Se puede filtrar por área (prefijo del identificador, por ejemplo payments) o por palabras.',
    get: 'Devuelve una capacidad por identificador con su resultado, requisitos, límites, funciones y ámbitos de evidencia. El texto está en inglés.',
    explain: 'Explica DesKilo en pocas líneas compuestas solo a partir del catálogo, nombrando los identificadores usados. Opcionalmente sobre un tema.',
    audiences: 'Lista quién es responsable de qué: propietario, administrador de base de datos, operador del servidor y miembro.',
    area: 'El área: la primera parte de un identificador de capacidad.', query: 'Palabras a buscar.', id: 'Un identificador de capacidad de list_capabilities.', topic: 'Una palabra o frase a explicar.',
    notFound: 'Ninguna capacidad tiene este identificador.', textLanguage: 'El resultado, los requisitos y los límites son el texto del manifiesto, en inglés.' },
  it: { list: 'Elenca ciò che DesKilo fa oggi dal catalogo delle capacità: identificatore, nome, area, stato. Filtrabile per area (prefisso dell’identificatore, ad esempio payments) o per parole.',
    get: 'Restituisce una capacità per identificatore con risultato, prerequisiti, limiti, funzioni e ambiti di prova. Il testo è in inglese.',
    explain: 'Spiega DesKilo in poche righe composte solo dal catalogo, nominando gli identificatori usati. Facoltativamente su un argomento.',
    audiences: 'Elenca chi è responsabile di cosa: proprietario, amministratore del database, operatore del server e membro.',
    area: 'L’area: la prima parte di un identificatore di capacità.', query: 'Parole da cercare.', id: 'Un identificatore di capacità da list_capabilities.', topic: 'Una parola o frase da spiegare.',
    notFound: 'Nessuna capacità ha questo identificatore.', textLanguage: 'Risultato, prerequisiti e limiti sono il testo del manifesto, in inglese.' },
};

const fold = (t) => String(t).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
export const areaOf = (id) => id.split('.')[0];
const AUDIENCES = [['owner', 'roleOwner'], ['database_administrator', 'roleDba'], ['server_operator', 'roleOperator'], ['member', 'roleMember']];

/// The tools for [locale]; [caps] defaults to the generated catalogue.
export function productTools(locale, caps = CAPABILITIES) {
  const l = LOCALES.includes(locale) ? locale : 'en';
  const t = STRINGS[l];
  const rows = capabilityRows(l, caps);
  const byId = Object.fromEntries(caps.map((c) => [c.id, c]));
  const brief = (r) => ({ id: r.id, name: r.name, area: areaOf(r.id), status: byId[r.id].status, state: r.state, state_text: r.text });
  const haystack = (r) => fold(`${r.id} ${r.name} ${byId[r.id].outcome ?? ''}`);
  const matching = (query) => {
    const words = fold(query ?? '').split(/[^a-z0-9]+/).filter((w) => w.length >= 3);
    if (!words.length) return rows;
    return rows.filter((r) => words.some((w) => haystack(r).includes(w)));
  };
  const ok = (data) => ({ ok: true, data });
  const fail = (code, message, extra) => ({ ok: false, error: { code, message, ...extra } });
  const str = (description) => ({ type: 'string', description });
  const obj = (properties, required = []) => ({ type: 'object', properties, required, additionalProperties: false });
  return [
    { name: 'list_capabilities', description: t.list, annotations: { readOnlyHint: true },
      inputSchema: obj({ area: str(t.area), query: str(t.query) }),
      execute: ({ area, query }) => {
        let list = matching(query);
        if (typeof area === 'string' && area) list = list.filter((r) => areaOf(r.id) === area);
        return ok({ language: l, capabilities: list.map(brief) });
      } },
    { name: 'get_capability', description: t.get, annotations: { readOnlyHint: true },
      inputSchema: obj({ id: str(t.id) }, ['id']),
      execute: ({ id }) => {
        const r = rows.find((x) => x.id === id);
        if (!r) return fail('not_found', t.notFound, { allowed: rows.map((x) => x.id) });
        const c = byId[id];
        return ok({ ...brief(r), outcome: c.outcome, prerequisites: c.prerequisites, limitations: c.limitations, features: c.features,
          evidence: c.evidence, text_language: 'en', note: t.textLanguage });
      } },
    { name: 'explain_product', description: t.explain, annotations: { readOnlyHint: true },
      inputSchema: obj({ topic: str(t.topic) }),
      execute: ({ topic }) => {
        const used = (topic ? matching(topic) : rows).slice(0, 6);
        const lines = used.map((r) => `${r.name} (${r.text}): ${byId[r.id].outcome}`);
        return ok({ language: l, answer: lines.join('\n'), capability_ids: used.map((r) => r.id), text_language: 'en', note: t.textLanguage });
      } },
    { name: 'list_audiences', description: t.audiences, annotations: { readOnlyHint: true }, inputSchema: obj({}),
      execute: () => ok({ language: l, audiences: AUDIENCES.map(([id, key]) => ({ id, text: TEXT[l][key] })) }) },
  ];
}

/// Registers the tools and again whenever the page language changes.
export function start(win = globalThis.window) {
  const M = win?.WebMcp;
  if (!M || !M.supported()) return null;
  const doc = win.document;
  const select = doc.getElementById('lang');
  const register = () => M.register(productTools(select && LOCALES.includes(select.value) ? select.value : 'en'));
  register();
  // product.js translates on this event, and its listener was added first.
  if (select) select.addEventListener('change', register);
  return register;
}

const ready = (fn) => (document.readyState === 'loading' ? document.addEventListener('DOMContentLoaded', fn) : fn());
if (typeof document !== 'undefined' && typeof window !== 'undefined') ready(() => start(window));
