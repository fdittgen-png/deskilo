// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The welcome page's WebMCP tools (W3 of epic #2500). Local only: the page's
// CSP says connect-src 'none' and nothing here fetches. The entry points are
// the links the page itself marks with data-entry (label and address are
// read from the DOM when asked, so they follow the page language); go_to
// follows an id from that list and nothing else.
(function (win) {
  'use strict';
  var M = win.WebMcp;
  if (!M || !M.supported()) return;
  var doc = win.document;

  var S = {
    en: { list: 'List where this page can send the visitor: the demo, the app, the user guide, the setup questionnaire and the product page.',
      go: 'Open one of the listed entry points in this tab. Only ids from list_entry_points are followed.',
      id: 'An entry point id from list_entry_points.', notFound: 'There is no entry point with this id; the listed ones are the only targets.' },
    fr: { list: 'Liste les endroits où cette page peut envoyer le visiteur : la démo, l’application, le guide utilisateur, le questionnaire de configuration et la page produit.',
      go: 'Ouvre l’un des points d’entrée listés dans cet onglet. Seuls les identifiants de list_entry_points sont suivis.',
      id: 'Un identifiant de point d’entrée issu de list_entry_points.', notFound: 'Aucun point d’entrée n’a cet identifiant ; ceux listés sont les seules cibles.' },
    de: { list: 'Listet, wohin diese Seite die Besucher schicken kann: Demo, App, Benutzerhandbuch, Einrichtungsfragebogen und Produktseite.',
      go: 'Öffnet einen der aufgelisteten Einstiegspunkte in diesem Tab. Nur IDs aus list_entry_points werden verfolgt.',
      id: 'Eine Einstiegspunkt-ID aus list_entry_points.', notFound: 'Kein Einstiegspunkt hat diese ID; die aufgelisteten sind die einzigen Ziele.' },
    es: { list: 'Lista a dónde puede enviar esta página al visitante: la demo, la aplicación, la guía de usuario, el cuestionario de configuración y la página del producto.',
      go: 'Abre uno de los puntos de entrada listados en esta pestaña. Solo se siguen los identificadores de list_entry_points.',
      id: 'Un identificador de punto de entrada de list_entry_points.', notFound: 'Ningún punto de entrada tiene este identificador; los listados son los únicos destinos.' },
    it: { list: 'Elenca dove questa pagina può mandare il visitatore: la demo, l’app, la guida utente, il questionario di configurazione e la pagina del prodotto.',
      go: 'Apre uno dei punti di ingresso elencati in questa scheda. Sono seguiti solo gli identificatori di list_entry_points.',
      id: 'Un identificatore di punto di ingresso da list_entry_points.', notFound: 'Nessun punto di ingresso ha questo identificatore; quelli elencati sono le uniche destinazioni.' },
  };
  var lang = function () { return doc.documentElement.getAttribute('lang') || 'en'; };
  var T = function () { return S[lang()] || S.en; };

  // The entry points as the page shows them right now.
  function entries() {
    var seen = {};
    var out = [];
    Array.prototype.forEach.call(doc.querySelectorAll('a[data-entry]'), function (a) {
      var id = a.getAttribute('data-entry');
      var url = String(a.href || '');
      if (seen[id] || url.indexOf('https://') !== 0) return;
      seen[id] = true;
      out.push({ id: id, label: String(a.textContent || '').replace(/\s+/g, ' ').trim(), url: url });
    });
    return out;
  }

  function listEntryPoints() { return M.ok({ language: lang(), entry_points: entries() }); }

  function goTo(input) {
    var list = entries();
    var hit = list.filter(function (e) { return typeof input.id === 'string' && e.id === input.id; })[0];
    if (!hit) return M.fail('not_found', T().notFound, list.map(function (e) { return e.id; }), { entry_points: list });
    win.location.assign(hit.url);
    return M.ok({ id: hit.id, url: hit.url });
  }

  function register() {
    var t = T();
    var none = { type: 'object', properties: {}, required: [], additionalProperties: false };
    M.register([
      { name: 'list_entry_points', description: t.list, annotations: { readOnlyHint: true }, inputSchema: none, execute: listEntryPoints },
      { name: 'go_to', description: t.go,
        inputSchema: { type: 'object', properties: { id: { type: 'string', description: t.id } }, required: ['id'], additionalProperties: false }, execute: goTo },
    ]);
  }

  register();
  // welcome.js applies the stored language once the document is parsed.
  if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', function () { win.setTimeout(register, 0); });
  // The language is applied by welcome.js after the select changes.
  var select = doc.getElementById('lang');
  if (select) select.addEventListener('change', function () { win.setTimeout(register, 0); });
})(window);
