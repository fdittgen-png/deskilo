// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2329 — one register per language.
//
// The user guide addresses the reader formally in German ("Sie"),
// Spanish ("usted") and Italian ("Lei"), and so must every string the
// app shows: a screen that says "Prüfen Sie Ihre Verbindung" above a
// snackbar that says "prüfe deine E-Mails" reads as two products. This
// lint fails on an informal second-person form in a de/es/it fragment —
// the pronouns and possessives, and the informal verb forms that cannot
// be anything else.
//
// What it cannot see: a tú/tu imperative that is also a third-person
// description ("Abre el plan" = "opens the plan"), and the conventional
// Italian command labels on buttons ("Salva", "Annulla", "Chiudi"),
// which are standard UI wording, not informal address. Those stay a
// review concern; this pins everything a regular expression can decide.
//
// Placeholders (`{name}`) and ICU keywords are removed before matching,
// so `{tu}` as an argument name never fires. Word edges are explicit
// Unicode letter classes: Dart's `\b` is ASCII-only, so it neither
// matches after "tú" nor stops "du" inside "Produkt".
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The informal second-person words per locale. Exact, case-sensitive
/// alternatives: German "Ihr"/"Sie" (formal) must never match, and an
/// Italian "Le"/"Suo" is the courtesy form.
const Map<String, List<String>> _informal = {
  'de': [
    // Pronouns and possessives.
    'du', 'Du', 'dich', 'Dich', 'dir', 'Dir', 'euch', 'Euch',
    'dein', 'deine', 'deinen', 'deinem', 'deiner', 'deines',
    'Dein', 'Deine', 'Deinen', 'Deinem', 'Deiner', 'Deines',
    'euer', 'eure', 'euren', 'eurem', 'eurer', 'Euer', 'Eure',
    // du-imperatives and du-verbs that have no formal or descriptive
    // reading.
    'kannst', 'hast', 'bist', 'willst', 'musst', 'darfst', 'sollst',
    'Wähle', 'Prüfe', 'Tippe', 'Öffne', 'Füge', 'Bestätige', 'Melde',
    // ("Versuche" capitalised is the noun, "Zu viele Versuche".)
    'Schalte', 'versuche', 'Kaufe', 'Frag', 'Gib', 'Sieh',
    'Warte', 'Setze', 'Lege', 'Kopiere', 'Erlaube', 'Speichere', 'Halte',
    'Registriere', 'Trage', 'Schließe', 'Scanne', 'scanne', 'Fordere',
    'Installiere', 'Richte', 'Wische', 'Finde', 'beantrage', 'checke',
  ],
  'es': [
    'tú', 'Tú', 'tu', 'Tu', 'tus', 'Tus', 'te', 'Te', 'ti', 'contigo',
    'tuyo', 'tuya', 'tuyos', 'tuyas',
    'vosotros', 'vosotras', 'vuestro', 'vuestra', 'vuestros', 'vuestras',
    // tú-verbs and tú-imperatives that are never a description. ("Abre",
    // "Activa", "Toca", "Usa", "Crea" … are left out: they are also the
    // third-person description of what a control does; lower-case
    // "elige"/"comprueba" are the usted indicative, "usted elige".)
    'puedes', 'tienes', 'quieres', 'estás', 'eres', 'debes', 'necesitas',
    'has', 'Has', 'podrás', 'tendrás', 'verás', 'olvidaste', 'Olvidaste',
    'Inténtalo', 'inténtalo', 'Elige', 'Pulsa',
    'Comprueba', 'Introduce', 'Selecciona', 'Mantén',
    'Únete', 'únete', 'Regístrate', 'regístrate', 'Pregúntale',
    'Actívala', 'actívala', 'Actívalo', 'actívalo', 'Ábrelo', 'ábrelo',
    'Úsalo', 'úsalo', 'Revísala', 'Revísalo', 'Compruébalo',
    'Inicia sesión', 'Vuelve a intentarlo', 'vuelve a intentarlo',
    'registrarte', 'unirte', 'contactarte', 'escribirte',
  ],
  'it': [
    'tu', 'Tu', 'ti', 'Ti', 'te', 'Te',
    'tuo', 'Tuo', 'tua', 'Tua', 'tuoi', 'Tuoi', 'tue', 'Tue',
    // tu-verbs and reflexive tu-imperatives. Left out: "sei" (also the
    // number six), "registrati"/"collegati" (also participles), and the
    // command forms of buttons ("Scegli", "Inserisci", "Riprova").
    'puoi', 'Puoi', 'vuoi', 'Vuoi', 'devi', 'Devi', 'hai', 'Hai',
    'stai', 'fai', 'sai', 'vai', 'potrai', 'vedrai', 'riceverai', 'avrai',
    'Unisciti', 'unisciti', 'Iscriviti', 'iscriviti', 'Connettiti',
    'Rivolgiti', 'rivolgiti', 'chiedigli', 'chiediglielo',
    // The plural "voi" register, which had crept in beside "tu".
    'voi', 'Voi', 'vostro', 'vostra', 'vostri', 'vostre', 'Vostro',
    'Vostra', 'avete', 'siete', 'potete',
  ],
};

/// fragment key → why its value may contain one of the words above.
/// Every entry must still match: a stale exemption is deleted, not kept.
const Map<String, String> _allowed = {
  // Quotes the French tax code verbatim ("art. 293 B du CGI"): the
  // statutory mention an association prints, not German "du".
  'invoiceLegalAssociationReasonHint': 'quotes French law',
};

final RegExp _placeholder = RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}');

RegExp _wordsOf(List<String> words) => RegExp(
  '(?<![\\p{L}\\p{N}_])(${words.map(RegExp.escape).join('|')})'
  '(?![\\p{L}\\p{N}_])',
  unicode: true,
);

/// Placeholders first; then ICU plural/select: drop the argument header
/// (`{count, plural,`) and the selector keywords (`=1{`, `other{`) — once
/// the placeholders are gone, every remaining `{` opens a branch.
String _messageText(String value) => value
    .replaceAll(_placeholder, ' ')
    .replaceAll(RegExp(r'\{\s*\w+\s*,\s*(plural|select)\s*,'), ' ')
    .replaceAll(RegExp(r'(=\d+|\w+)\s*\{'), ' ');

void main() {
  final fragments =
      Directory('lib/l10n/_fragments')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final entry in _informal.entries) {
    final locale = entry.key;
    final pattern = _wordsOf(entry.value);

    test('every $locale string uses the formal register', () {
      final offences = <String>[];
      for (final file in fragments.where(
        (f) => f.path.endsWith('_$locale.arb'),
      )) {
        final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final e in arb.entries) {
          if (e.key.startsWith('@') || e.value is! String) continue;
          if (_allowed.containsKey(e.key)) continue;
          final hit = pattern.firstMatch(_messageText(e.value as String));
          if (hit != null) {
            offences.add(
              '${file.path}: ${e.key} — "${hit[0]}" in '
              '"${e.value}"',
            );
          }
        }
      }
      expect(
        offences,
        isEmpty,
        reason:
            'The $locale strings address the reader formally, like '
            'the user guide (de "Sie", es "usted", it "Lei"). Rewrite '
            'each value in the formal register. If a match is genuinely '
            'not second person, add its key to _allowed with the reason.\n'
            '${offences.join('\n')}',
      );
    });
  }

  test('every exemption still matches its word list', () {
    final values = <String, (String, String)>{};
    for (final file in fragments) {
      final locale = RegExp(r'_([a-z]{2})\.arb$').firstMatch(file.path)?[1];
      if (locale == null || !_informal.containsKey(locale)) continue;
      final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final key in _allowed.keys) {
        final value = arb[key];
        if (value is String) values['$key/$locale'] = (locale, value);
      }
    }
    for (final key in _allowed.keys) {
      final fires = values.entries
          .where((e) => e.key.startsWith('$key/'))
          .any(
            (e) =>
                _wordsOf(_informal[e.value.$1]!)
                    .hasMatch(_messageText(e.value.$2)),
          );
      expect(fires, isTrue, reason: '$key no longer needs its exemption');
    }
  });

  // The demo personas are role labels: the neutral role words of
  // docs/guide/AUTHORING.md, never a gendered person.
  const personas = {
    'de': {
      'demoPersonaMember': 'Mitglied',
      'demoPersonaAdmin': 'Administrator:in',
      'demoPersonaOwner': 'Inhaber',
    },
    'es': {
      'demoPersonaMember': 'Miembro',
      'demoPersonaAdmin': 'Administrador/a',
      'demoPersonaOwner': 'Propietario',
    },
    'it': {
      'demoPersonaMember': 'Membro',
      'demoPersonaAdmin': 'Amministratore',
      'demoPersonaOwner': 'Proprietario',
    },
  };
  test('the demo personas use the neutral role words', () {
    for (final locale in personas.entries) {
      final arb = jsonDecode(
        File('lib/l10n/_fragments/demo_session_${locale.key}.arb')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final p in locale.value.entries) {
        expect(
          arb[p.key],
          p.value,
          reason:
              'demo_session_${locale.key}.arb: ${p.key} is a role '
              'label — the role word of docs/guide/AUTHORING.md.',
        );
      }
    }
  });
}
