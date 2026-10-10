// SPDX-License-Identifier: AGPL-3.0-or-later
// DesKilo welcome page: language, theme, reveal-on-scroll, the hero and tour
// screens, and the little floor plan you can book on. No dependencies.
(function () {
  'use strict';

  var root = document.documentElement;
  var LANGS = ['en', 'fr', 'de', 'es', 'it'];
  var GUIDE = 'https://fdittgen-png.github.io/deskilo/guide/';
  var reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  var dict = window.DESKILO_I18N || {};

  function store(key, value) {
    try {
      if (value === undefined) return window.localStorage.getItem(key);
      window.localStorage.setItem(key, value);
    } catch (e) { /* private mode: the page works without it */ }
    return null;
  }

  // ---------- language ----------
  // English lives in the HTML itself; it is captured once so switching back
  // to English needs no second copy of the text.
  var english = { text: {}, html: {}, alt: {}, aria: {} };
  function each(sel, fn) { Array.prototype.forEach.call(document.querySelectorAll(sel), fn); }
  each('[data-i18n]', function (el) { english.text[el.getAttribute('data-i18n')] = el.textContent; });
  each('[data-i18n-html]', function (el) { english.html[el.getAttribute('data-i18n-html')] = el.innerHTML; });
  each('[data-i18n-alt]', function (el) { english.alt[el.getAttribute('data-i18n-alt')] = el.getAttribute('alt'); });
  each('[data-i18n-aria]', function (el) { english.aria[el.getAttribute('data-i18n-aria')] = el.getAttribute('aria-label'); });

  var lang = 'en';
  function t(key, vars) {
    var table = dict[lang] || {};
    var s = table[key] || (dict.en || {})[key] || english.text[key] || key;
    if (vars) Object.keys(vars).forEach(function (k) { s = s.split('{' + k + '}').join(vars[k]); });
    return s;
  }

  function pickLanguage() {
    var fromUrl = new URLSearchParams(window.location.search).get('lang');
    if (fromUrl && LANGS.indexOf(fromUrl) >= 0) return fromUrl;
    var saved = store('deskilo.welcome.lang');
    if (saved && LANGS.indexOf(saved) >= 0) return saved;
    var prefs = navigator.languages || [navigator.language || 'en'];
    for (var i = 0; i < prefs.length; i++) {
      var code = String(prefs[i]).slice(0, 2).toLowerCase();
      if (LANGS.indexOf(code) >= 0) return code;
    }
    return 'en';
  }

  function applyLanguage(next) {
    lang = next;
    var table = lang === 'en' ? {} : (dict[lang] || {});
    root.setAttribute('lang', lang);
    each('[data-i18n]', function (el) { var k = el.getAttribute('data-i18n'); el.textContent = table[k] || english.text[k]; });
    each('[data-i18n-html]', function (el) { var k = el.getAttribute('data-i18n-html'); el.innerHTML = table[k] || english.html[k]; });
    each('[data-i18n-alt]', function (el) { var k = el.getAttribute('data-i18n-alt'); el.setAttribute('alt', table[k] || english.alt[k]); });
    each('[data-i18n-aria]', function (el) { var k = el.getAttribute('data-i18n-aria'); el.setAttribute('aria-label', table[k] || english.aria[k]); });
    each('img[data-shot]', function (img) { img.src = 'img/' + img.getAttribute('data-shot') + '.' + lang + '.webp'; });
    // Guide links follow the language and keep the section they point at.
    function anchorOf(a) { var id = a.getAttribute('data-anchor'); return id ? '#' + id : ''; }
    each('a.guide-link', function (a) { a.href = GUIDE + lang + '.html' + anchorOf(a); });
    each('a.setup-guide-link', function (a) { a.href = GUIDE + 'setup-' + lang + '.html' + anchorOf(a); });
    document.title = t('meta.title');
    var desc = document.querySelector('meta[name="description"]');
    if (desc) desc.setAttribute('content', t('meta.desc'));
    // Phone layout labels each comparison cell with its column heading.
    var heads = document.querySelectorAll('.compare thead th');
    each('.compare tbody tr', function (tr) {
      Array.prototype.forEach.call(tr.querySelectorAll('td'), function (td, i) {
        var th = heads[i + 1];
        if (th) td.setAttribute('data-label', th.textContent);
      });
    });
    var select = document.getElementById('lang');
    if (select) select.value = lang;
    renderPlanStatus();
    renderMotion();
  }

  // ---------- motion ----------
  // Everything that moves on its own can be stopped, and stays stopped: the
  // reader decides how long to look at a screen.
  var still = store('deskilo.welcome.still') === '1';
  function renderMotion() {
    root.classList.toggle('still', still);
    each('.motion-btn', function (b) {
      b.hidden = reduced;
      b.setAttribute('aria-pressed', String(still));
      b.setAttribute('aria-label', t(still ? 'motion.play' : 'motion.pause'));
      b.setAttribute('title', t(still ? 'motion.play' : 'motion.pause'));
    });
  }
  function moving() { return !still && !document.hidden; }

  // ---------- theme ----------
  var savedTheme = store('deskilo.welcome.theme');
  if (savedTheme === 'light' || savedTheme === 'dark') root.setAttribute('data-theme', savedTheme);
  function isDark() {
    var forced = root.getAttribute('data-theme');
    if (forced) return forced === 'dark';
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  }

  // ---------- floor plan ----------
  var seats = [];
  var lastAction = null;
  function seatLabel(s) { return t('plan.seat_' + s.state, { d: s.id }); }
  function renderSeat(s) {
    s.el.className = 'seat ' + (s.state === 'free' ? '' : s.state);
    s.el.setAttribute('aria-pressed', s.state === 'mine' ? 'true' : 'false');
    s.el.disabled = s.state === 'taken' || s.state === 'in';
    s.el.setAttribute('aria-label', seatLabel(s));
    s.el.innerHTML = '';
    s.el.appendChild(document.createTextNode(s.id));
    if (s.who && (s.state === 'taken' || s.state === 'in')) {
      var who = document.createElement('span');
      who.className = 'who';
      who.textContent = s.who;
      s.el.appendChild(who);
    }
  }
  function renderPlanStatus() {
    var out = document.getElementById('plan-status');
    if (!out || !seats.length) return;
    seats.forEach(renderSeat);
    var free = seats.filter(function (s) { return s.state === 'free'; }).length;
    var line = t('plan.count', { n: free, t: seats.length });
    if (lastAction) line = t(lastAction.key, { d: lastAction.id }) + ' · ' + line;
    out.textContent = line;
  }
  function buildPlan() {
    var layout = [
      ['.r-main .desks', [['A1'], ['A2', 'taken', 'BK'], ['A3'], ['A4'], ['A5', 'in', 'CR'], ['A6']]],
      ['.r-studio .desks', [['S1', 'taken', 'AL'], ['S2']]],
      ['.r-meet .desks', [['M1']]]
    ];
    layout.forEach(function (room) {
      var host = document.querySelector(room[0]);
      if (!host) return;
      room[1].forEach(function (d) {
        var el = document.createElement('button');
        el.type = 'button';
        var s = { id: d[0], state: d[1] || 'free', who: d[2] || '', el: el };
        el.addEventListener('click', function () {
          if (s.state === 'free') {
            seats.forEach(function (o) { if (o.state === 'mine') o.state = 'free'; });
            s.state = 'mine';
            lastAction = { key: 'plan.booked', id: s.id };
          } else if (s.state === 'mine') {
            s.state = 'free';
            lastAction = { key: 'plan.released', id: s.id };
          }
          renderPlanStatus();
        });
        host.appendChild(el);
        seats.push(s);
      });
    });
    renderPlanStatus();
    if (reduced) return;
    // The plan lives a little while it is on screen: someone arrives, someone books.
    var floor = document.getElementById('floor');
    var visible = false;
    if ('IntersectionObserver' in window && floor) {
      new IntersectionObserver(function (es) { visible = es[0].isIntersecting; }).observe(floor);
    }
    var people = ['DM', 'EF', 'AL', 'BK', 'CR'];
    window.setInterval(function () {
      if (!visible || !moving()) return;
      var pool = seats.filter(function (s) { return s.state !== 'mine'; });
      var s = pool[Math.floor(Math.random() * pool.length)];
      if (s.state === 'taken') s.state = 'in';
      else if (s.state === 'in') { s.state = 'free'; s.who = ''; }
      else { s.state = 'taken'; s.who = people[Math.floor(Math.random() * people.length)]; }
      renderPlanStatus();
    }, 2600);
  }

  // ---------- rotators ----------
  function show(rotator, index) {
    var imgs = rotator.querySelectorAll('img');
    Array.prototype.forEach.call(imgs, function (img, i) { img.classList.toggle('on', i === index); });
  }
  function heroRotator() {
    var r = document.getElementById('hero-rotator');
    if (!r || reduced) return;
    var n = r.querySelectorAll('img').length;
    var i = 0;
    window.setInterval(function () {
      if (!moving()) return;
      i = (i + 1) % n;
      show(r, i);
    }, 3400);
  }

  function storyTelling() {
    var screen = document.getElementById('story-screen');
    var dots = document.getElementById('story-dots');
    var steps = document.querySelectorAll('.step');
    if (!screen || !steps.length) return;
    Array.prototype.forEach.call(steps, function () { dots.appendChild(document.createElement('i')); });
    function activate(i) {
      show(screen, i);
      Array.prototype.forEach.call(steps, function (s, j) { s.classList.toggle('on', j === i); });
      Array.prototype.forEach.call(dots.children, function (d, j) { d.classList.toggle('on', j === i); });
    }
    activate(0);
    if (!('IntersectionObserver' in window)) return;
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) activate(Number(e.target.getAttribute('data-step')));
      });
    }, { rootMargin: '-45% 0px -45% 0px' });
    Array.prototype.forEach.call(steps, function (s) { io.observe(s); });
  }

  // ---------- reveal & nav ----------
  function reveals() {
    var items = document.querySelectorAll('.reveal');
    // Stagger siblings that enter together.
    Array.prototype.forEach.call(items, function (el) {
      var sibs = el.parentElement ? el.parentElement.querySelectorAll(':scope > .reveal') : [];
      var idx = Array.prototype.indexOf.call(sibs, el);
      if (idx > 0) el.style.setProperty('--d', Math.min(idx, 6) * 0.08 + 's');
    });
    if (reduced || !('IntersectionObserver' in window)) {
      Array.prototype.forEach.call(items, function (el) { el.classList.add('in'); });
      return;
    }
    // What is already on screen stays visible: no flash before the first paint.
    var h = window.innerHeight;
    Array.prototype.forEach.call(items, function (el) {
      if (el.getBoundingClientRect().top < h) el.classList.add('in');
    });
    root.classList.add('js');
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) { e.target.classList.add('in'); io.unobserve(e.target); }
      });
    }, { rootMargin: '0px 0px -8% 0px', threshold: 0.08 });
    Array.prototype.forEach.call(items, function (el) { if (!el.classList.contains('in')) io.observe(el); });
  }

  function nav() {
    var bar = document.querySelector('.nav');
    var links = document.getElementById('nav-links');
    var burger = document.getElementById('burger');
    function onScroll() { bar.classList.toggle('scrolled', window.scrollY > 8); }
    window.addEventListener('scroll', onScroll, { passive: true });
    onScroll();
    burger.addEventListener('click', function () {
      var open = !links.classList.contains('open');
      links.classList.toggle('open', open);
      burger.setAttribute('aria-expanded', open ? 'true' : 'false');
    });
    links.addEventListener('click', function (e) {
      if (e.target.tagName === 'A') { links.classList.remove('open'); burger.setAttribute('aria-expanded', 'false'); }
    });
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') { links.classList.remove('open'); burger.setAttribute('aria-expanded', 'false'); }
    });
    if (!('IntersectionObserver' in window)) return;
    var anchors = links.querySelectorAll('a');
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (!e.isIntersecting) return;
        Array.prototype.forEach.call(anchors, function (a) {
          a.classList.toggle('active', a.getAttribute('href') === '#' + e.target.id);
        });
      });
    }, { rootMargin: '-40% 0px -55% 0px' });
    Array.prototype.forEach.call(anchors, function (a) {
      var target = document.querySelector(a.getAttribute('href'));
      if (target) io.observe(target);
    });
  }

  function init() {
    document.getElementById('lang').addEventListener('change', function (e) {
      var next = e.target.value;
      store('deskilo.welcome.lang', next);
      var url = new URL(window.location.href);
      url.searchParams.set('lang', next);
      window.history.replaceState(null, '', url);
      applyLanguage(next);
    });
    document.getElementById('theme').addEventListener('click', function () {
      var next = isDark() ? 'light' : 'dark';
      root.setAttribute('data-theme', next);
      store('deskilo.welcome.theme', next);
    });
    each('.motion-btn', function (b) {
      b.addEventListener('click', function () {
        still = !still;
        store('deskilo.welcome.still', still ? '1' : '0');
        renderMotion();
      });
    });
    // A link to a question opens it.
    function openTarget() {
      var el = window.location.hash && document.getElementById(window.location.hash.slice(1));
      if (el && el.tagName === 'DETAILS') el.open = true;
    }
    window.addEventListener('hashchange', openTarget);
    openTarget();
    buildPlan();
    applyLanguage(pickLanguage());
    reveals();
    nav();
    heroRotator();
    storyTelling();
    window.requestAnimationFrame(function () { document.body.classList.add('loaded'); });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
  else init();
})();
