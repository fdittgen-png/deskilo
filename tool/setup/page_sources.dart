// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2926 — `web/setup.html` and the scripts it is split into
// (setup_params.js, setup_steps.js, setup_xml.js), read as ONE page by the
// tests that check the questionnaire's source. The list is the page's own
// `<script src>` tags, so a further split needs no edit here.
import 'dart:io';

const setupPagePath = 'web/setup.html';

/// The scripts the page loads beside it that are not its own code: the
/// generated resources and the shared and questionnaire WebMCP files.
const _notOwn = {
  'setup_catalogue.js',
  'setup_l10n.js',
  'webmcp.js',
  'setup_webmcp.js',
};

/// The page's own scripts, `web/…` paths in the order the page loads them.
List<String> setupPageScripts([String? html]) => [
  for (final m in RegExp(
    r'<script src="([^"]+)"></script>',
  ).allMatches(html ?? File(setupPagePath).readAsStringSync()))
    if (!_notOwn.contains(m.group(1))) 'web/${m.group(1)}',
];

/// The page followed by its own scripts, each inside `<script>` tags so a
/// reader that tells markup from code reads them as code.
String setupPageSource() {
  final html = File(setupPagePath).readAsStringSync();
  return [
    html,
    for (final path in setupPageScripts(html))
      '<script>\n${File(path).readAsStringSync()}\n</script>',
  ].join('\n');
}
