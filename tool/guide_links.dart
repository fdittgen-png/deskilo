// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The links of the user guide, in one place. A chapter writes
// `[text](help:user.reserve.plan)` (jump to a section) and
// `[Reserve](app:/reserve)` (open a screen). The wiki and the static site
// need ordinary links, the app needs the originals back:
//
//   chapter   help:user.reserve.plan   app:/reserve
//   wiki      #reserve-a-place         https://<web app>/#/reserve
//   app       help:user.reserve.plan   app:/reserve     (tool/build_help.dart)
//
// So `tool/build_user_guide.dart` turns the first into the second and
// `tool/build_help.dart` turns the second back — both with the functions here.

/// Where the web app lives; the wiki's `app:` links point into it.
const webAppBase = 'https://fdittgen-png.github.io/deskilo/';

final _anchorComment = RegExp(r'<!--\s*anchor:\s*([a-z][a-z0-9]*(?:\.[a-z0-9-]+)+)\s*-->');

/// GitHub's heading slug: lower case, punctuation dropped, spaces to
/// hyphens, letters of every script kept.
String githubSlug(String heading) => heading
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s_-]', unicode: true), '')
    .trim()
    .replaceAll(RegExp(r'\s'), '-');

/// anchor id -> the slug GitHub gives its heading in [markdown] (duplicate
/// headings get `-1`, `-2`… in file order, which is what GitHub does).
Map<String, String> anchorSlugs(String markdown) {
  final seen = <String, int>{};
  final out = <String, String>{};
  String? pending;
  var fenced = false;
  for (final line in markdown.split('\n')) {
    if (line.trimLeft().startsWith('```')) fenced = !fenced;
    if (fenced) continue;
    final a = _anchorComment.firstMatch(line);
    if (a != null) {
      pending = a.group(1);
      continue;
    }
    if (line.startsWith('#')) {
      final text = line.replaceFirst(RegExp(r'^#+\s*'), '').trim();
      var slug = githubSlug(text);
      final n = seen[slug] ?? 0;
      seen[slug] = n + 1;
      if (n > 0) slug = '$slug-$n';
      if (pending != null) out[pending] = slug;
      pending = null;
    } else if (line.trim().isNotEmpty) {
      pending = null;
    }
  }
  return out;
}

final _helpLink = RegExp(r'\]\(help:([a-z0-9.-]+)\)');
final _appLink = RegExp(r'\]\(app:(/[^)\s]*)\)');

/// chapter links -> wiki links. A `help:` anchor of this guide becomes `#slug`;
/// one of another guide ([external]: anchor -> `Page#slug`) becomes a link to
/// that page. Returns the unknown targets in [unknown].
String toWikiLinks(String markdown, {List<String>? unknown, Map<String, String> external = const {}}) {
  final slugs = anchorSlugs(markdown);
  return markdown
      .replaceAllMapped(_helpLink, (m) {
        final slug = slugs[m[1]];
        if (slug != null) return '](#$slug)';
        final other = external[m[1]];
        if (other != null) return ']($other)';
        unknown?.add(m[1]!);
        return m[0]!;
      })
      .replaceAllMapped(_appLink, (m) => ']($webAppBase#${m[1]})');
}

/// wiki links -> app links (the inverse of [toWikiLinks], for one guide file).
/// [pages] maps another guide's page name to its markdown, so a link
/// `[x](User-Guide#slug)` becomes `help:<anchor>` too.
String toAppLinks(String markdown, {Map<String, String> pages = const {}}) {
  final byAnchor = anchorSlugs(markdown);
  final bySlug = {for (final e in byAnchor.entries) e.value: e.key};
  final other = <String, String>{
    for (final page in pages.entries)
      for (final e in anchorSlugs(page.value).entries) '${page.key}#${e.value}': e.key,
  };
  markdown = markdown.replaceAllMapped(RegExp(r'\]\(([A-Za-z0-9-]+#[^)\s]+)\)'), (m) {
    final id = other[m[1]];
    return id == null ? m[0]! : '](help:$id)';
  });
  return markdown
      .replaceAllMapped(RegExp(r'\]\(#([^)\s]+)\)'), (m) {
        final id = bySlug[m[1]];
        return id == null ? m[0]! : '](help:$id)';
      })
      .replaceAllMapped(
        RegExp('\\]\\(${RegExp.escape(webAppBase)}#(/[^)\\s]*)\\)'),
        (m) => '](app:${m[1]})',
      );
}
