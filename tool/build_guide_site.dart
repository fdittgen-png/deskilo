// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Renders the five wiki user guides as one static help site:
//
//   docs/wiki/User-Guide.md (+ fr de es it)  ->  web/guide/<lang>.html
//
// The look is web/guide/guide.css and behaviour web/guide/guide.js; this
// tool only decides the markup: a section card per `###` (audience chips,
// numbered steps, callouts, a scrollable phone for each screenshot), a
// table of contents, a role filter and search. The pages ship with the web
// app (`/guide/en.html`), read the screenshots from the app's own bundled
// copy (`assets/help/images`) and link every `app:` link into the live app.
//
//   dart run tool/build_guide_site.dart            write web/guide
//   dart run tool/build_guide_site.dart --check    fail when it is stale
import 'dart:io';

import 'package:markdown/markdown.dart' as md;

import 'build_user_guide.dart' show families, Family;
import 'guide_links.dart';

const outDir = 'web/guide';
const imageBase = '../assets/assets/help/images/';

/// Everything the page says that is not the guide, per language.
class Ui {
  const Ui({
    required this.search,
    required this.iAm,
    required this.levels,
    required this.sections,
    required this.menu,
    required this.theme,
    required this.empty,
    required this.top,
    required this.openApp,
    required this.footer,
    required this.title,
    required this.chapter,
    required this.structure,
    required this.seeAlso,
    required this.careful,
    required this.audience,
  });
  final String search, iAm, sections, menu, theme, empty, top, openApp, footer, title, chapter;
  final Map<String, String> levels;
  final Map<String, String> structure; // lower-case skeleton word -> label key
  final String seeAlso, careful, audience;
}

const ui = <String, Ui>{
  'en': Ui(
    search: 'Search the guide  ( / )', iAm: 'I am', sections: '{n} sections', menu: 'Contents', theme: 'Light or dark', empty: 'Nothing matches. Try another word, or show everything.',
    top: 'Back to top', openApp: 'Open DesKilo', footer: 'DesKilo user guide — the screenshots show the demo workspace; every person and figure is invented.', title: 'DesKilo User Guide', chapter: 'Chapter',
    levels: {'member': 'Member', 'admin': 'Administrator', 'owner': 'Owner', 'everything': 'Everything'},
    structure: {'steps': 'steps', 'good to know': 'know', 'before you start': 'before', 'result': 'result'},
    seeAlso: 'see also', careful: 'careful', audience: 'audience',
  ),
  'fr': Ui(
    search: 'Rechercher dans le guide  ( / )', iAm: 'Je suis', sections: '{n} sections', menu: 'Sommaire', theme: 'Clair ou sombre', empty: 'Rien ne correspond. Essayez un autre mot ou affichez tout.',
    top: 'Haut de page', openApp: 'Ouvrir DesKilo', footer: 'Guide utilisateur DesKilo — les captures montrent l’espace de démonstration ; toutes les personnes et tous les chiffres sont inventés.', title: 'Guide utilisateur DesKilo', chapter: 'Chapitre',
    levels: {'member': 'Membre', 'admin': 'Administrateur·rice', 'owner': 'Propriétaire', 'everything': 'Tout'},
    structure: {'étapes': 'steps', 'bon à savoir': 'know', 'avant de commencer': 'before', 'résultat': 'result'},
    seeAlso: 'voir aussi', careful: 'attention', audience: 'public',
  ),
  'de': Ui(
    search: 'Im Handbuch suchen  ( / )', iAm: 'Ich bin', sections: '{n} Abschnitte', menu: 'Inhalt', theme: 'Hell oder dunkel', empty: 'Nichts gefunden. Anderes Wort versuchen oder alles anzeigen.',
    top: 'Nach oben', openApp: 'DesKilo öffnen', footer: 'DesKilo Benutzerhandbuch — die Screenshots zeigen den Demo-Arbeitsbereich; alle Personen und Zahlen sind erfunden.', title: 'DesKilo Benutzerhandbuch', chapter: 'Kapitel',
    levels: {'member': 'Mitglied', 'admin': 'Administrator:in', 'owner': 'Inhaber', 'everything': 'Alles'},
    structure: {'schritte': 'steps', 'gut zu wissen': 'know', 'bevor sie beginnen': 'before', 'ergebnis': 'result'},
    seeAlso: 'siehe auch', careful: 'achtung', audience: 'zielgruppe',
  ),
  'es': Ui(
    search: 'Buscar en la guía  ( / )', iAm: 'Soy', sections: '{n} secciones', menu: 'Contenido', theme: 'Claro u oscuro', empty: 'Sin resultados. Pruebe otra palabra o muestre todo.',
    top: 'Ir arriba', openApp: 'Abrir DesKilo', footer: 'Guía de usuario de DesKilo — las capturas muestran el espacio de demostración; todas las personas y cifras son inventadas.', title: 'Guía de usuario de DesKilo', chapter: 'Capítulo',
    levels: {'member': 'Miembro', 'admin': 'Administrador/a', 'owner': 'Propietario', 'everything': 'Todo'},
    structure: {'pasos': 'steps', 'conviene saber': 'know', 'antes de empezar': 'before', 'resultado': 'result'},
    seeAlso: 'véase también', careful: 'atención', audience: 'público',
  ),
  'it': Ui(
    search: 'Cerca nella guida  ( / )', iAm: 'Sono', sections: '{n} sezioni', menu: 'Indice', theme: 'Chiaro o scuro', empty: 'Nessun risultato. Prova un’altra parola o mostra tutto.',
    top: 'Torna su', openApp: 'Apri DesKilo', footer: 'Guida utente DesKilo — gli screenshot mostrano lo spazio dimostrativo; tutte le persone e le cifre sono inventate.', title: 'Guida utente DesKilo', chapter: 'Capitolo',
    levels: {'member': 'Membro', 'admin': 'Amministratore', 'owner': 'Proprietario', 'everything': 'Tutto'},
    structure: {'passaggi': 'steps', 'da sapere': 'know', 'prima di iniziare': 'before', 'risultato': 'result'},
    seeAlso: 'vedi anche', careful: 'attenzione', audience: 'destinatari',
  ),
};

/// The two books of the site and their titles, per language.
const bookTitles = <String, Map<String, String>>{
  'en': {'user': 'User guide', 'setup': 'Setup guide'},
  'fr': {'user': 'Guide utilisateur', 'setup': 'Guide de démarrage'},
  'de': {'user': 'Benutzerhandbuch', 'setup': 'Einrichtungsanleitung'},
  'es': {'user': 'Guía de usuario', 'setup': 'Guía de puesta en marcha'},
  'it': {'user': 'Guida utente', 'setup': 'Guida di avvio'},
};

/// `en.html` for the user guide, `setup-en.html` for the setup guide.
String pageName(String book, String lang) => book == 'user' ? '$lang.html' : '$book-$lang.html';

/// The other guides of this language, as the site names their pages: the wiki
/// page name -> (site page, slug -> anchor id), so a link into the other book
/// (`Setup-Guide#slug`) lands on the right card.
Map<String, ({String page, Map<String, String> idBySlug})> crossPages(String lang) {
  final out = <String, ({String page, Map<String, String> idBySlug})>{};
  for (final family in families) {
    final file = family.files[lang];
    if (file == null) continue;
    final source = File('docs/wiki/$file');
    if (!source.existsSync()) continue;
    final slugs = anchorSlugs(source.readAsStringSync());
    out[file.replaceFirst(RegExp(r'\.md$'), '')] = (
      page: pageName(family.name, lang),
      idBySlug: {for (final e in slugs.entries) e.value: e.key},
    );
  }
  return out;
}

/// A role word of any language -> the role key the stylesheet and the
/// filter know.
String roleKey(String word) {
  final w = word.toLowerCase().trim();
  if (RegExp(r'billing|facturation|abrechnung|facturación|fatturazione').hasMatch(w)) return 'billing';
  if (RegExp(r'^(co-?owner|copropri|mitinhaber|copropietario|comproprietario)').hasMatch(w)) return 'coowner';
  if (RegExp(r'^(owner|propri|inhaber|propiet)').hasMatch(w)) return 'owner';
  if (RegExp(r'^(administrat|amministrat|administrador)').hasMatch(w)) return 'admin';
  if (RegExp(r'^(member|membre|mitglied|miembro|membro)').hasMatch(w)) return 'member';
  if (RegExp(r'^(operat|betreiber|operador)').hasMatch(w)) return 'operator';
  return 'all';
}

String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

class Section {
  Section(this.id, this.title, this.lines);
  final String id, title;
  final List<String> lines;
}

class Chapter {
  Chapter(this.id, this.title);
  final String id, title;
  final List<String> intro = [];
  final List<Section> sections = [];
}

final _anchor = RegExp(r'<!--\s*anchor:\s*([a-z][a-z0-9]*(?:\.[a-z0-9-]+)+)\s*-->');

/// Splits a guide into its title block and chapters. A chapter's `###`
/// sections each carry their anchor; the anchor id is the page's element id.
({List<String> head, List<Chapter> chapters}) split(String markdown) {
  final head = <String>[];
  final chapters = <Chapter>[];
  Chapter? chapter;
  Section? section;
  String? pending;
  var fenced = false;
  for (final line in markdown.split('\n')) {
    if (line.trimLeft().startsWith('```')) fenced = !fenced;
    final a = fenced ? null : _anchor.firstMatch(line);
    if (a != null) {
      pending = a.group(1);
      continue;
    }
    if (!fenced && line.startsWith('## ')) {
      chapter = Chapter(pending ?? 'chapter-${chapters.length}', line.substring(3).trim());
      chapters.add(chapter);
      section = null;
      pending = null;
      continue;
    }
    if (!fenced && line.startsWith('### ') && chapter != null) {
      section = Section(pending ?? 'section-${chapter.sections.length}', line.substring(4).trim(), []);
      chapter.sections.add(section);
      pending = null;
      continue;
    }
    if (line.trim().isNotEmpty) pending = null;
    if (section != null) {
      section.lines.add(line);
    } else if (chapter != null) {
      chapter.intro.add(line);
    } else {
      head.add(line);
    }
  }
  return (head: head, chapters: chapters);
}

String _html(String markdown) => md.markdownToHtml(markdown, extensionSet: md.ExtensionSet.gitHubFlavored);

/// One section's body: html, its screenshots and its roles.
({String body, List<String> figures, List<String> roles}) renderBody(
  String lang,
  List<String> lines,
  String title,
  Map<String, String> idBySlug,
  Map<String, ({String page, Map<String, String> idBySlug})> cross,
) {
  final u = ui[lang]!;
  var roles = <String>[];
  final cleaned = <String>[];
  var seenAudience = false;
  for (final line in lines) {
    final m = RegExp(r'^\*\*([^*:]+):\*\*\s*(.*)$').firstMatch(line);
    if (!seenAudience && m != null && m[1]!.toLowerCase() == u.audience) {
      seenAudience = true;
      roles = m[2]!.split('·').map(roleKey).toSet().toList();
      continue;
    }
    cleaned.add(line);
  }
  var html = _html(cleaned.join('\n'));

  final figures = <String>[];
  html = html.replaceAllMapped(RegExp(r'<p>\s*(<img [^>]*>)\s*</p>|(<img [^>]*>)'), (m) {
    final tag = (m[1] ?? m[2])!;
    final src = RegExp(r'src="images/([^"]+)"').firstMatch(tag)?[1];
    if (src == null) return m[0]!;
    final wide = RegExp(r'width="(\d+)"').firstMatch(tag);
    final isWide = wide != null && int.parse(wide[1]!) > 400;
    figures.add('<figure class="shot${isWide ? ' wide' : ''}"><div class="screen" tabindex="0"><img loading="lazy" src="$imageBase$src" alt="${esc(title)}"></div></figure>');
    return '';
  });

  // The skeleton's labels become small headings.
  html = html.replaceAllMapped(RegExp(r'<p><strong>([^<:]+)</strong></p>'), (m) {
    final key = u.structure[m[1]!.toLowerCase().trim()];
    return key == null ? m[0]! : '<h4 class="lbl lbl-$key">${m[1]}</h4>';
  });
  html = html.replaceAllMapped(RegExp(r'<p>(<strong>' + RegExp.escape(u.seeAlso) + r'[^<]*</strong>)', caseSensitive: false), (m) => '<p class="see-also">${m[1]}');
  html = html.replaceAllMapped(RegExp(r'<blockquote>\s*<p><strong>' + RegExp.escape(u.careful), caseSensitive: false), (m) => '<blockquote class="warn"><p><strong>${m[0]!.split('<strong>').last}');
  // Links: section links by id, app links out to the live app.
  html = html.replaceAllMapped(RegExp(r'href="#([^"]+)"'), (m) => 'href="#${idBySlug[m[1]] ?? m[1]}"');
  html = html.replaceAllMapped(RegExp(r'href="([A-Za-z0-9-]+)(?:#([^"]+))?"'), (m) {
    final other = cross[m[1]];
    if (other == null) return m[0]!;
    final id = m[2] == null ? null : other.idBySlug[m[2]];
    return 'href="${other.page}${id == null ? '' : '#$id'}"';
  });
  html = html.replaceAllMapped(RegExp('<a href="(${RegExp.escape(webAppBase)}[^"]*)"'), (m) => '<a class="app-link" target="_blank" rel="noopener" href="${m[1]}"');
  return (body: html, figures: figures, roles: roles.isEmpty ? ['all'] : roles);
}

String renderPage(String lang, String markdown, {String book = 'user'}) {
  final u = ui[lang]!;
  _roleWords = _wordsFor(lang);
  final slugs = anchorSlugs(markdown);
  final idBySlug = {for (final e in slugs.entries) e.value: e.key};
  final cross = crossPages(lang);
  final parts = split(markdown);

  // Title block: the H1 and the tagline, minus the "other languages" line.
  final headText = parts.head.join('\n');
  final h1 = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(headText)?[1] ?? u.title;
  var tagline = headText.replaceFirst(RegExp(r'^#\s+.+$', multiLine: true), '').trim();
  tagline = tagline.replaceAll(RegExp(r'\s*\*[^*]*\]\(User-Guide\)[^*]*\*|\s*\*(?:Autres langues|Other languages)[^*]*\*'), '').trim();
  tagline = tagline.replaceAll(RegExp(r'\s*\*[^*]*\[[^\]]+\]\((?:User-Guide|Guide-utilisateur|Benutzerhandbuch|Guia-de-usuario|Guida-utente)\)[^*]*\*'), '').trim();

  final toc = StringBuffer('<ol>');
  final main = StringBuffer();
  var number = 0;
  for (final c in parts.chapters) {
    final hasSections = c.sections.isNotEmpty;
    if (hasSections) number++;
    final tag = hasSections ? '${u.chapter} ${number.toString().padLeft(2, '0')}' : '';
    final intro = renderBody(lang, c.intro, c.title, idBySlug, cross);
    toc.write('<li data-id="${c.id}"><a class="chap" href="#${c.id}">${esc(c.title)}</a>');
    if (hasSections) toc.write('<ol>');
    if (hasSections) {
      main.write('<section class="chapter" id="${c.id}"><header><span class="no">$tag</span><h2>${esc(c.title)}</h2>');
      if (intro.body.trim().isNotEmpty) main.write('<div class="intro">${intro.body}</div>');
      main.write('</header>');
    }
    if (!hasSections) {
      // A chapter without sections (the "how to use" page) is one card.
      main.write(_card(c.id, c.title, intro, 'h2'));
    }
    for (final s in c.sections) {
      final r = renderBody(lang, s.lines, s.title, idBySlug, cross);
      toc.write('<li data-id="${s.id}"><a href="#${s.id}">${esc(s.title)}</a></li>');
      main.write(_card(s.id, s.title, r, 'h3'));
    }
    if (hasSections) {
      toc.write('</ol>');
      main.write('</section>');
    }
    toc.write('</li>');
  }
  toc.write('</ol>');

  final levels = ['member', 'admin', 'owner', 'everything']
      .map((k) => '<button class="chip-btn" type="button" data-level="$k" aria-pressed="false">${esc(u.levels[k]!)}</button>')
      .join();
  final langs = ui.keys
      .map((l) => '<a class="chip-btn lang${l == lang ? ' cur' : ''}" href="${pageName(book, l)}" hreflang="$l" lang="$l"${l == lang ? ' aria-current="true"' : ''}>${l.toUpperCase()}</a>')
      .join();
  final books = bookTitles[lang]!;
  final bookNav = books.entries
      .map((e) => '<a class="book${e.key == book ? ' cur' : ''}" href="${pageName(e.key, lang)}"${e.key == book ? ' aria-current="page"' : ''}>${esc(e.value)}</a>')
      .join();

  return '''<!doctype html>
<html lang="$lang">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src 'self' data:; style-src 'self'; script-src 'self'; base-uri 'none'; form-action 'none'">
<title>${esc(books[book]!)} · DesKilo</title>
<meta name="description" content="${esc(tagline.replaceAll(RegExp(r'[*_`]'), '').split('\n').first)}">
<link rel="icon" href="../favicon.png">
<link rel="stylesheet" href="guide.css">
</head>
<body>
<header class="bar">
  <button class="icon-btn menu-btn" type="button" aria-label="${esc(u.menu)}" aria-expanded="false">☰</button>
  <a class="brand" href="#top"><span class="brand-mark" aria-hidden="true"></span><span>DesKilo</span></a>
  <nav class="books" aria-label="${esc(u.menu)}">$bookNav</nav>
  <label class="search"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/></svg><input type="search" placeholder="${esc(u.search)}" aria-label="${esc(u.search)}"></label>
  <button class="icon-btn theme-btn" type="button" aria-label="${esc(u.theme)}">◐</button>
</header>
<div class="layout" id="top">
  <nav class="toc" aria-label="${esc(u.menu)}">
    <div class="books books-m">$bookNav</div>
    <div class="langs">$langs</div>
    $toc
  </nav>
  <main>
    <div class="hero">
      <h1>${esc(h1)}</h1>
      ${_html(tagline)}
      <div class="filters" role="group" aria-label="${esc(u.iAm)}"><span class="lbl">${esc(u.iAm)}</span>$levels<span class="count" data-template="${esc(u.sections)}"></span></div>
      <p><a class="app-link" target="_blank" rel="noopener" href="$webAppBase">${esc(u.openApp)}</a></p>
    </div>
    $main
    <p class="empty">${esc(u.empty)}</p>
    <footer class="site">${esc(u.footer)}</footer>
  </main>
</div>
<button class="to-top" type="button" aria-label="${esc(u.top)}">↑</button>
<dialog class="lightbox"><img alt=""></dialog>
<script src="guide.js"></script>
</body>
</html>
''';
}

String _card(String id, String title, ({String body, List<String> figures, List<String> roles}) r, String tag) {
  final roles = r.roles.map((k) => '<span class="role role-$k">${esc(_roleLabel(k))}</span>').join();
  final media = r.figures.isEmpty ? '' : '<div class="media">${r.figures.join()}</div>';
  return '<article class="section${r.figures.isEmpty ? ' no-media' : ''}" id="$id" data-roles="${r.roles.join(' ')}">'
      '<header><$tag>${esc(title)} <a class="permalink" href="#$id" aria-label="link">#</a></$tag><div class="roles">$roles</div></header>'
      '<div class="body">${r.body}</div>$media</article>';
}

// The chip text is the language's own role word, set by the caller's table.
String _roleLabel(String key) => _roleWords[key] ?? key;
Map<String, String> _roleWords = const {};

void main(List<String> args) {
  final check = args.contains('--check');
  var stale = false;
  Directory(outDir).createSync(recursive: true);
  for (final Family family in families) {
    for (final e in family.files.entries) {
      final source = File('docs/wiki/${e.value}');
      if (!source.existsSync()) continue;
      final html = renderPage(e.key, source.readAsStringSync(), book: family.name);
      final target = File('$outDir/${pageName(family.name, e.key)}');
      if (check) {
        if (!target.existsSync() || target.readAsStringSync() != html) {
          stderr.writeln('${target.path} is stale — run: dart run tool/build_guide_site.dart');
          stale = true;
        }
      } else {
        target.writeAsStringSync(html);
        stdout.writeln('wrote ${target.path}');
      }
    }
  }
  exitCode = stale ? 1 : 0;
}

/// Role chips carry the guide's own role words.
Map<String, String> _wordsFor(String lang) => switch (lang) {
      'fr' => {'all': 'Tout le monde', 'member': 'Membre', 'admin': 'Administrateur·rice', 'owner': 'Propriétaire', 'coowner': 'Copropriétaire', 'billing': 'Administrateur·rice facturation', 'operator': 'Opérateur·rice'},
      'de' => {'all': 'Alle', 'member': 'Mitglied', 'admin': 'Administrator:in', 'owner': 'Inhaber', 'coowner': 'Mitinhaber', 'billing': 'Abrechnungsadministrator:in', 'operator': 'Betreiber:in'},
      'es' => {'all': 'Todos', 'member': 'Miembro', 'admin': 'Administrador/a', 'owner': 'Propietario', 'coowner': 'Copropietario', 'billing': 'Administrador/a de facturación', 'operator': 'Operador/a'},
      'it' => {'all': 'Tutti', 'member': 'Membro', 'admin': 'Amministratore', 'owner': 'Proprietario', 'coowner': 'Comproprietario', 'billing': 'Amministratore fatturazione', 'operator': 'Operatore'},
      _ => {'all': 'Everyone', 'member': 'Member', 'admin': 'Administrator', 'owner': 'Owner', 'coowner': 'Co-owner', 'billing': 'Billing administrator', 'operator': 'Operator'},
    };
