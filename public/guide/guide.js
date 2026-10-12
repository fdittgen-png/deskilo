/* The user guide site: role filter, search, scroll-spy, screenshots viewer.
   No dependencies; everything degrades to a plain readable page. */
(function () {
  'use strict';
  var $ = function (s, r) { return (r || document).querySelector(s); };
  var $$ = function (s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); };
  // The index page picks the reader's language and gets out of the way.
  if (document.body.getAttribute('data-page') === 'index') {
    var have = ['en', 'fr', 'de', 'es', 'it'];
    var pick = (navigator.language || 'en').slice(0, 2).toLowerCase();
    location.replace((have.indexOf(pick) >= 0 ? pick : 'en') + '.html' + location.hash);
    return;
  }
  var sections = $$('.section');
  var store = {
    get: function (k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set: function (k, v) { try { localStorage.setItem(k, v); } catch (e) { /* private window */ } }
  };

  // Who am I? A level, not a list: an owner also sees what members and
  // administrators see. Running the server is another job than running the
  // space, so the operator level stands apart from the owner's.
  var ladder = {
    member: ['all', 'member'],
    admin: ['all', 'member', 'admin', 'billing'],
    owner: ['all', 'member', 'admin', 'billing', 'owner', 'coowner'],
    operator: ['all', 'operator'],
    everything: null
  };
  var level = store.get('guide.level') || 'everything';
  if (!(level in ladder)) level = 'everything';
  var query = '';
  // Search ignores case and accents: "echeance" finds "échéance".
  function fold(t) { return t.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase(); }
  var texts = sections.map(function (s) { return fold(s.textContent); });

  function apply() {
    var allowed = ladder[level];
    var shown = 0;
    sections.forEach(function (s, i) {
      var roles = (s.getAttribute('data-roles') || 'all').split(' ');
      var okRole = !allowed || roles.some(function (r) { return allowed.indexOf(r) >= 0; });
      var okText = !query || texts[i].indexOf(query) >= 0;
      s.hidden = !(okRole && okText);
      if (!s.hidden) shown++;
    });
    $$('.chapter').forEach(function (c) {
      c.hidden = !$$('.section', c).some(function (s) { return !s.hidden; });
    });
    $$('nav.toc li[data-id]').forEach(function (li) {
      var s = document.getElementById(li.getAttribute('data-id'));
      li.hidden = s ? s.hidden : false;
    });
    $$('.chip-btn[data-level]').forEach(function (b) {
      b.setAttribute('aria-pressed', String(b.getAttribute('data-level') === level));
    });
    var c = $('.count');
    if (c) c.textContent = (c.getAttribute('data-template') || '{n}').replace('{n}', shown);
    var e = $('.empty');
    if (e) e.classList.toggle('on', shown === 0);
    $$('mark').forEach(function (m) { m.replaceWith(document.createTextNode(m.textContent)); });
  }
  $$('.chip-btn[data-level]').forEach(function (b) {
    b.addEventListener('click', function () {
      level = b.getAttribute('data-level');
      store.set('guide.level', level);
      apply();
    });
  });
  var input = $('.search input');
  if (input) {
    input.addEventListener('input', function () { query = fold(input.value.trim()); apply(); });
    document.addEventListener('keydown', function (e) {
      if (e.key === '/' && document.activeElement.tagName !== 'INPUT') { e.preventDefault(); input.focus(); }
      if (e.key === 'Escape' && document.activeElement === input) { input.value = ''; query = ''; apply(); input.blur(); }
    });
  }
  apply();

  // A link to a hidden section shows it: the reader asked for it.
  function reveal() {
    var id = decodeURIComponent(location.hash.slice(1));
    var s = id && document.getElementById(id);
    if (s && s.hidden) { level = 'everything'; query = ''; if (input) input.value = ''; apply(); }
    if (s) setTimeout(function () { s.scrollIntoView({ block: 'start' }); }, 30);
  }
  window.addEventListener('hashchange', reveal);
  if (location.hash) reveal();

  // The menu on small screens.
  var menu = $('.menu-btn');
  if (menu) menu.addEventListener('click', function () {
    var open = document.body.classList.toggle('nav-open');
    menu.setAttribute('aria-expanded', String(open));
  });
  $$('nav.toc a').forEach(function (a) { a.addEventListener('click', function () { document.body.classList.remove('nav-open'); }); });

  // Theme.
  var theme = $('.theme-btn');
  var saved = store.get('guide.theme');
  if (saved) document.documentElement.setAttribute('data-theme', saved);
  if (theme) theme.addEventListener('click', function () {
    var dark = document.documentElement.getAttribute('data-theme') === 'dark' ||
      (!document.documentElement.getAttribute('data-theme') && matchMedia('(prefers-color-scheme: dark)').matches);
    var next = dark ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', next);
    store.set('guide.theme', next);
  });

  // Scroll-spy: the table of contents follows the reader.
  if ('IntersectionObserver' in window) {
    var links = {};
    $$('nav.toc a[href^="#"]').forEach(function (a) { links[a.getAttribute('href').slice(1)] = a; });
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        var a = links[en.target.id];
        if (!a) return;
        if (en.isIntersecting) {
          $$('nav.toc a.on').forEach(function (x) { x.classList.remove('on'); });
          a.classList.add('on');
          if (a.scrollIntoView && !matchMedia('(max-width: 1060px)').matches) a.scrollIntoView({ block: 'nearest' });
        }
      });
    }, { rootMargin: '-80px 0px -65% 0px' });
    $$('.section, .chapter').forEach(function (s) { if (s.id) io.observe(s); });
  }

  // The other languages open on the same section: the anchors are the same
  // in every language.
  $$('a.lang').forEach(function (a) {
    a.addEventListener('click', function () {
      var on = $('nav.toc a.on');
      var id = (on && on.getAttribute('href').slice(1)) || location.hash.slice(1);
      if (id) a.setAttribute('href', a.getAttribute('href').split('#')[0] + '#' + id);
    });
  });

  // Screenshots open large: a click on the phone, its button, or Enter on
  // the focused phone. The close button, Escape or a click anywhere closes,
  // and focus goes back to where it was.
  var dlg = $('dialog.lightbox');
  if (dlg && dlg.showModal) {
    var opener = null;
    var open = function (fig, from) {
      var img = $('.screen img', fig);
      $('img', dlg).src = img.src;
      $('img', dlg).alt = img.alt;
      opener = from;
      dlg.showModal();
      var x = $('form button', dlg);
      if (x) x.focus();
    };
    $$('figure.shot').forEach(function (fig) {
      var sc = $('.screen', fig);
      var zoom = $('.zoom', fig);
      sc.addEventListener('click', function () { open(fig, zoom || sc); });
      sc.addEventListener('keydown', function (e) {
        if (e.key === 'Enter') { e.preventDefault(); open(fig, sc); }
      });
      if (zoom) zoom.addEventListener('click', function () { open(fig, zoom); });
    });
    dlg.addEventListener('click', function () { dlg.close(); });
    dlg.addEventListener('close', function () { if (opener) opener.focus(); opener = null; });
  }

  var up = $('.to-top');
  if (up) {
    addEventListener('scroll', function () { up.classList.toggle('on', scrollY > 900); }, { passive: true });
    up.addEventListener('click', function () { scrollTo({ top: 0 }); });
  }
})();
