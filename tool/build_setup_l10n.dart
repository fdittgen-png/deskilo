// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Builds web/setup_l10n.js — every word the setup questionnaire
// (web/setup.html) shows, in the five locales the app ships (#1366).
//
// Two sources, never a third:
//
//  * The app's own ARB catalogue (lib/l10n/app_<locale>.arb) for anything
//    the app already names: each WorkspaceFeature's name and description
//    (resolved through the same getters featureName/featureDescription
//    use), each permission (perm*), each validation domain (eventType*)
//    and each country (countryName*). The questionnaire used to keep a
//    sixth, French-only copy of the feature catalogue; it drifted from
//    the app the way copies do.
//  * web/setup_l10n/setup_<locale>.json for the page's own prose — step
//    explanations, validation messages, buttons. Those strings exist only
//    on this page, so they stay out of the app's ARB (and out of the
//    generated AppLocalizations the app would carry for nothing).
//
// The output is committed and published beside setup.html, which loads it
// before its own script. test/lint/setup_l10n_test.dart regenerates it in
// memory and fails on any difference.
//
// Usage:
//   dart run tool/build_setup_l10n.dart

import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_process.dart';

/// The locales the page offers — the app's own, English first.
const setupLocales = ['en', 'fr', 'de', 'es', 'it'];

/// The generated resource setup.html loads.
const setupL10nOutput = 'web/setup_l10n.js';

/// #1330 — the business catalogue setup.html groups its switches by:
/// `workspaceProcesses` as data, not words. The words (each process's and
/// subprocess's title and description) ride in [setupL10nOutput], so the
/// page never keeps a sixth copy of the process taxonomy either. The XML
/// the page exports stays feature-keyed; this file changes what it
/// SHOWS, never what it writes.
const setupCatalogueOutput = 'web/setup_catalogue.js';

/// Where the page-only strings live, one JSON object per locale.
String setupStringsPath(String locale) => 'web/setup_l10n/setup_$locale.json';

const _setupHtml = 'web/setup.html';
const _featureNames = 'lib/features/workspace/presentation/feature_names.dart';
const _featureCopy = 'lib/features/workspace/presentation/feature_copy.dart';

/// Validation domains whose ARB key is not `eventType` + the camel-cased
/// wire name. The app calls the `service` event a service CHARGE.
const _domainKeyOverrides = {'service': 'eventTypeServiceCharge'};

/// `WorkspaceFeature.x => l10n?.someKey` in [source], as `x -> someKey`.
///
/// Read from the Dart source rather than restated here, so a feature whose
/// label getter is renamed changes the questionnaire with it.
Map<String, String> _getterMap(String source) => {
  for (final m in RegExp(
    r'WorkspaceFeature\.(\w+)\s*=>\s*l10n\?\.(\w+)',
  ).allMatches(source))
    m.group(1)!: m.group(2)!,
};

String _getter(Map<String, String> map, WorkspaceFeature f, String file) =>
    map[f.name] ??
    (throw StateError(
      '$file has no `WorkspaceFeature.${f.name} => '
      'l10n?.<key>` arm — the setup questionnaire reads its label there',
    ));

String _camel(String snake) => snake
    .split('_')
    .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
    .join();

/// The single-quoted keys inside `const NAME=[ ... ];` in setup.html.
List<String> _pageList(String html, String name, RegExp item) {
  final start = html.indexOf('const $name=[');
  if (start < 0) throw StateError('$_setupHtml has no const $name=[');
  final end = html.indexOf('];', start);
  return [
    for (final m in item.allMatches(html.substring(start, end))) m.group(1)!,
  ];
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String _arbString(Map<String, dynamic> arb, String key, String locale) {
  final value = arb[key];
  if (value is! String || value.trim().isEmpty) {
    throw StateError(
      'lib/l10n/app_$locale.arb has no "$key" — the setup '
      'questionnaire reads it; add it to the fragments and run build_arb',
    );
  }
  return value;
}

/// The whole resource, as the file's exact text.
String buildSetupL10n() {
  final html = File(_setupHtml).readAsStringSync();
  final names = _getterMap(File(_featureNames).readAsStringSync());
  final descriptions = _getterMap(File(_featureCopy).readAsStringSync());
  final permissions = _pageList(html, 'PERMS', RegExp(r"'([A-Za-z]+)'"));
  final domains = _pageList(html, 'DOMAINS', RegExp(r"'([a-z_]+)'"));
  final countries = _pageList(html, 'COUNTRIES', RegExp(r"\['([A-Z]{2})'"));

  final out = <String, dynamic>{};
  for (final locale in setupLocales) {
    final arb = _readJson('lib/l10n/app_$locale.arb');
    final strings = _readJson(setupStringsPath(locale));
    out[locale] = {
      's': strings,
      'feature': {
        for (final f in WorkspaceFeature.values)
          f.name: [
            _arbString(arb, _getter(names, f, _featureNames), locale),
            _arbString(arb, _getter(descriptions, f, _featureCopy), locale),
          ],
      },
      'process': {
        for (final p in workspaceProcesses)
          p.key: [
            _arbString(arb, p.titleKey, locale),
            _arbString(arb, p.descriptionKey, locale),
          ],
      },
      'subprocess': {
        for (final p in workspaceProcesses)
          for (final sp in p.subprocesses)
            sp.key: [
              _arbString(arb, sp.titleKey, locale),
              _arbString(arb, sp.descriptionKey, locale),
            ],
      },
      'perm': {
        for (final p in permissions)
          p: _arbString(
            arb,
            'perm${p[0].toUpperCase()}${p.substring(1)}',
            locale,
          ),
      },
      'domain': {
        for (final d in domains)
          d: _arbString(
            arb,
            _domainKeyOverrides[d] ?? 'eventType${_camel(d)}',
            locale,
          ),
      },
      'country': {
        for (final c in countries) c: _arbString(arb, 'countryName$c', locale),
      },
    };
  }
  const encoder = JsonEncoder.withIndent(' ');
  return '// SPDX-License-Identifier: AGPL-3.0-or-later\n'
      '// GENERATED by tool/build_setup_l10n.dart from the app ARB catalogue '
      'and web/setup_l10n/.\n'
      '// Do not edit: change the sources and run '
      '`dart run tool/build_setup_l10n.dart`.\n'
      'window.SETUP_L10N=${encoder.convert(out)};\n';
}

/// The process catalogue, as the file's exact text: process → subprocess
/// → feature keys, in registry order. Read from `workspaceProcesses`, the
/// one registry the Features screen, the resolver and the search use.
String buildSetupCatalogue() {
  final processes = [
    for (final p in workspaceProcesses)
      {
        'key': p.key,
        'subprocesses': [
          for (final sp in p.subprocesses)
            {
              'key': sp.key,
              'features': [for (final f in sp.capabilities) f.name],
            },
        ],
      },
  ];
  const encoder = JsonEncoder.withIndent(' ');
  return '// SPDX-License-Identifier: AGPL-3.0-or-later\n'
      '// GENERATED by tool/build_setup_l10n.dart from workspaceProcesses '
      '(#1330).\n'
      '// Do not edit: change lib/features/workspace/domain/workspace_process.dart '
      'and run `dart run tool/build_setup_l10n.dart`.\n'
      'window.SETUP_PROCESSES=${encoder.convert(processes)};\n';
}

void main() {
  File(setupL10nOutput).writeAsStringSync(buildSetupL10n());
  stdout.writeln('wrote $setupL10nOutput');
  File(setupCatalogueOutput).writeAsStringSync(buildSetupCatalogue());
  stdout.writeln('wrote $setupCatalogueOutput');
}
