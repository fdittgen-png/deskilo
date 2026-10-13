// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The user guide's WebMCP tools (W2 of epic #2500). They answer only from
// guide_index_<lang>.js, which tool/build_guide_site.dart generates from the
// same markdown as the page and which this script loads (a same-origin
// script tag, only when the browser supports WebMCP): no fetch, no storage,
// no new text for the guide. Entries of another language than the page's are not offered in v1
// (only the page's own index is loaded; the CSP stays as it is).
(function (win) {
  'use strict';
  var M = win.WebMcp;
  var lang = document.documentElement.lang;
  // The index is half a megabyte: a browser without WebMCP never loads it.
  if (!M || !M.supported()) return;
  var all = win.__guideIndex && win.__guideIndex[lang];
  if (all) { start(all); return; }
  var tag = document.createElement('script');
  tag.src = 'guide_index_' + lang + '.js';
  tag.onload = function () { if (win.__guideIndex && win.__guideIndex[lang]) start(win.__guideIndex[lang]); };
  document.head.appendChild(tag);

  function start(all) {

  var S = {
    en: { search: 'Search the DesKilo guide in the page language. Returns ranked sections with the real section id, title, audience, summary and URL.',
      get: 'Return one guide section by id: full text, image descriptions and links into the app.',
      list: 'List the guide sections (id, title, audience) visible at the reader level.',
      roles: 'List the reader levels of the guide and the audiences each shows.',
      query: 'Words to look for.', role: 'Reader level; defaults to the level chosen on the page.', limit: 'Maximum results.', book: 'Which guide: user or setup; defaults to this page’s.',
      id: 'The section id, as search_guide returns it.', language: 'Only the page language is available here.',
      badRole: 'Unknown reader level.', badQuery: 'Give a query of at least one word.', notFound: 'No section has this id. Closest sections are listed.',
      otherLang: 'Only the language of this page is available; open the page of the other language.' },
    fr: { search: 'Recherche dans le guide DesKilo, dans la langue de la page. Renvoie les sections classées avec leur identifiant réel, titre, public, résumé et URL.',
      get: 'Renvoie une section du guide par identifiant : texte complet, descriptions des images et liens vers l’application.',
      list: 'Liste les sections du guide (identifiant, titre, public) visibles au niveau du lecteur.',
      roles: 'Liste les niveaux de lecteur du guide et les publics que chacun affiche.',
      query: 'Mots à chercher.', role: 'Niveau de lecteur ; par défaut celui choisi sur la page.', limit: 'Nombre maximal de résultats.', book: 'Quel guide : user ou setup ; par défaut celui de cette page.',
      id: 'L’identifiant de section, tel que search_guide le renvoie.', language: 'Seule la langue de la page est disponible ici.',
      badRole: 'Niveau de lecteur inconnu.', badQuery: 'Donnez une requête d’au moins un mot.', notFound: 'Aucune section n’a cet identifiant. Les sections les plus proches sont listées.',
      otherLang: 'Seule la langue de cette page est disponible ; ouvrez la page de l’autre langue.' },
    de: { search: 'Durchsucht das DesKilo-Handbuch in der Seitensprache. Liefert gereihte Abschnitte mit echter Abschnitts-ID, Titel, Zielgruppe, Zusammenfassung und URL.',
      get: 'Liefert einen Handbuchabschnitt nach ID: vollständiger Text, Bildbeschreibungen und Links in die App.',
      list: 'Listet die Handbuchabschnitte (ID, Titel, Zielgruppe), die auf der Leserstufe sichtbar sind.',
      roles: 'Listet die Leserstufen des Handbuchs und die Zielgruppen, die jede zeigt.',
      query: 'Suchbegriffe.', role: 'Leserstufe; standardmäßig die auf der Seite gewählte.', limit: 'Maximale Trefferzahl.', book: 'Welches Handbuch: user oder setup; standardmäßig das dieser Seite.',
      id: 'Die Abschnitts-ID, wie search_guide sie liefert.', language: 'Hier ist nur die Seitensprache verfügbar.',
      badRole: 'Unbekannte Leserstufe.', badQuery: 'Geben Sie eine Suche mit mindestens einem Wort an.', notFound: 'Kein Abschnitt hat diese ID. Die nächsten Abschnitte sind aufgelistet.',
      otherLang: 'Nur die Sprache dieser Seite ist verfügbar; öffnen Sie die Seite der anderen Sprache.' },
    es: { search: 'Busca en la guía de DesKilo, en el idioma de la página. Devuelve secciones ordenadas con su identificador real, título, público, resumen y URL.',
      get: 'Devuelve una sección de la guía por identificador: texto completo, descripciones de imágenes y enlaces a la aplicación.',
      list: 'Lista las secciones de la guía (identificador, título, público) visibles al nivel del lector.',
      roles: 'Lista los niveles de lector de la guía y los públicos que muestra cada uno.',
      query: 'Palabras a buscar.', role: 'Nivel de lector; por defecto el elegido en la página.', limit: 'Máximo de resultados.', book: 'Qué guía: user o setup; por defecto la de esta página.',
      id: 'El identificador de sección, tal como lo devuelve search_guide.', language: 'Aquí solo está disponible el idioma de la página.',
      badRole: 'Nivel de lector desconocido.', badQuery: 'Indique una consulta de al menos una palabra.', notFound: 'Ninguna sección tiene este identificador. Se listan las más cercanas.',
      otherLang: 'Solo está disponible el idioma de esta página; abra la página del otro idioma.' },
    it: { search: 'Cerca nella guida DesKilo, nella lingua della pagina. Restituisce sezioni ordinate con identificatore reale, titolo, destinatari, riassunto e URL.',
      get: 'Restituisce una sezione della guida per identificatore: testo completo, descrizioni delle immagini e link verso l’app.',
      list: 'Elenca le sezioni della guida (identificatore, titolo, destinatari) visibili al livello del lettore.',
      roles: 'Elenca i livelli di lettore della guida e i destinatari che ciascuno mostra.',
      query: 'Parole da cercare.', role: 'Livello di lettore; per impostazione quello scelto nella pagina.', limit: 'Numero massimo di risultati.', book: 'Quale guida: user o setup; per impostazione quella di questa pagina.',
      id: 'L’identificatore di sezione, come lo restituisce search_guide.', language: 'Qui è disponibile solo la lingua della pagina.',
      badRole: 'Livello di lettore sconosciuto.', badQuery: 'Indica una ricerca di almeno una parola.', notFound: 'Nessuna sezione ha questo identificatore. Sono elencate le più vicine.',
      otherLang: 'È disponibile solo la lingua di questa pagina; apri la pagina dell’altra lingua.' },
  };
  var T = S[lang] || S.en;

  var LIMIT_DEFAULT = 5, LIMIT_MAX = 20;
  var BOOKS = ['user', 'setup'];
  var pageBook = document.body.getAttribute('data-book') || 'user';
  var state = win.GuideState || { ladder: { everything: null }, level: function () { return 'everything'; } };

  function fold(t) { return String(t).normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase(); }
  function terms(q) { return fold(q).split(/[^a-z0-9]+/).filter(function (w) { return w.length >= 3; }); }
  function count(hay, w) { var n = 0, i = hay.indexOf(w); while (i >= 0 && n < 5) { n++; i = hay.indexOf(w, i + w.length); } return n; }
  function pageName(book) { return book === 'user' ? lang + '.html' : book + '-' + lang + '.html'; }
  function urlOf(e) { return new URL(pageName(e.family) + '#' + e.id, win.location.href).href; }
  function visible(e, level) {
    var allowed = state.ladder[level];
    return !allowed || e.roles.some(function (r) { return allowed.indexOf(r) >= 0; });
  }
  function brief(e) { return { id: e.id, title: e.title, family: e.family, roles: e.roles, summary: e.summary, url: urlOf(e) }; }

  var folded = all.map(function (e) { return { t: fold(e.title), s: fold(e.summary), x: fold(e.text), i: fold(e.id.replace(/[.-]/g, ' ')) }; });

  function levelOf(input) {
    var level = input.role === undefined ? state.level() : input.role;
    if (!(level in state.ladder)) return { error: M.fail('validation_error', T.badRole, Object.keys(state.ladder)) };
    return { level: level };
  }
  function otherLanguage(input) {
    if (input.language !== undefined && input.language !== lang) return M.fail('unsupported_language', T.otherLang, [lang]);
    return null;
  }

  function search(input) {
    var lg = otherLanguage(input); if (lg) return lg;
    var q = terms(typeof input.query === 'string' ? input.query : '');
    if (!q.length) return M.fail('validation_error', T.badQuery);
    var lv = levelOf(input); if (lv.error) return lv.error;
    var book = input.book === undefined ? pageBook : input.book;
    if (BOOKS.indexOf(book) < 0) return M.fail('validation_error', T.book, BOOKS);
    var limit = input.limit === undefined ? LIMIT_DEFAULT : Math.floor(Number(input.limit));
    if (!(limit >= 1 && limit <= LIMIT_MAX)) return M.fail('validation_error', T.limit, undefined, { min: 1, max: LIMIT_MAX });
    var hits = [];
    all.forEach(function (e, n) {
      if (e.family !== book || !visible(e, lv.level)) return;
      var f = folded[n], score = 0, matched = 0;
      q.forEach(function (w) {
        var s = count(f.t, w) * 6 + count(f.i, w) * 4 + count(f.s, w) * 3 + count(f.x, w);
        if (s) { matched++; score += s; }
      });
      if (matched) hits.push({ e: e, score: score + matched * 8 });
    });
    hits.sort(function (a, b) { return b.score - a.score; });
    return M.ok({ language: lang, level: lv.level, results: hits.slice(0, limit).map(function (h) { return brief(h.e); }) });
  }

  function getSection(input) {
    var lg = otherLanguage(input); if (lg) return lg;
    var id = typeof input.id === 'string' ? input.id : '';
    var e = all.filter(function (x) { return x.id === id; })[0];
    if (!e) {
      var q = terms(id.replace(/[.-]/g, ' '));
      var near = all.map(function (x, n) { var f = folded[n], s = 0; q.forEach(function (w) { s += count(f.i, w) * 3 + count(f.t, w); }); return { x: x, s: s }; })
        .filter(function (h) { return h.s > 0; }).sort(function (a, b) { return b.s - a.s; }).slice(0, LIMIT_DEFAULT)
        .map(function (h) { return { id: h.x.id, title: h.x.title }; });
      return M.fail('not_found', T.notFound, undefined, { suggestions: near });
    }
    var out = brief(e);
    out.text = e.text; out.images = e.images; out.appLinks = e.appLinks; out.language = lang;
    return M.ok(out);
  }

  function listSections(input) {
    var lv = levelOf(input); if (lv.error) return lv.error;
    return M.ok({ language: lang, level: lv.level, sections: all.filter(function (e) { return visible(e, lv.level); })
      .map(function (e) { return { id: e.id, title: e.title, family: e.family, roles: e.roles, url: urlOf(e) }; }) });
  }

  function listRoles() {
    return M.ok({ current: state.level(), levels: Object.keys(state.ladder).map(function (k) { return { level: k, shows: state.ladder[k] || 'all' }; }) });
  }

  var obj = function (props, req) { return { type: 'object', properties: props, required: req || [], additionalProperties: false }; };
  var role = function () { return { type: 'string', enum: Object.keys(state.ladder), description: T.role }; };
  var language = { type: 'string', enum: ['en', 'fr', 'de', 'es', 'it'], description: T.language };
  M.register([
    { name: 'search_guide', description: T.search, annotations: { readOnlyHint: true },
      inputSchema: obj({ query: { type: 'string', description: T.query }, role: role(), limit: { type: 'integer', minimum: 1, maximum: LIMIT_MAX, default: LIMIT_DEFAULT, description: T.limit },
        book: { type: 'string', enum: BOOKS, description: T.book }, language: language }, ['query']), execute: search },
    { name: 'get_section', description: T.get, annotations: { readOnlyHint: true },
      inputSchema: obj({ id: { type: 'string', description: T.id }, language: language }, ['id']), execute: getSection },
    { name: 'list_sections', description: T.list, annotations: { readOnlyHint: true }, inputSchema: obj({ role: role() }), execute: listSections },
    { name: 'list_roles', description: T.roles, annotations: { readOnlyHint: true }, inputSchema: obj({}), execute: listRoles },
  ]);
  }
})(window);
