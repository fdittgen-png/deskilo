// SPDX-License-Identifier: 0BSD
//
// #1390 — the time-zone search field's hint was the literal
// `'Europe/Paris'`, while the label directly above it resolved through
// `AppLocalizations`. Every reader, in every language, was shown Paris.
//
// The identifiers themselves are never translated — `Europe/Rome` is
// `Europe/Rome` in Italian. What is localized is the EXAMPLE: the hint
// exists to tell somebody what to type, so it should name a city they
// recognise.
//
// The picker had no test at all before this. `ValueKey('timezone-search')`
// has been on that field since #711 and nothing has ever found it, which
// is how a hard-coded hint survived a lint whose whole subject is
// hard-coded strings: `no_hardcoded_strings_test` greps `Text('`, and
// this was an `InputDecoration`.
import 'package:deskilo/core/i18n/time_zone_picker.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opens the picker inside a localized app at [locale] and returns the
/// hint the search field is showing.
Future<String?> _hintIn(
  WidgetTester tester,
  Locale locale, {
  void Function(TextField field)? beforeClose,
}) async {
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const ValueKey('open'),
            onPressed: () => showTimeZonePicker(
              context,
              current: 'Europe/Paris',
              now: DateTime.utc(2026, 5, 13, 10),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.byKey(const ValueKey('open')));
  await tester.pumpAndSettle();

  final field = tester.widget<TextField>(
    find.byKey(const ValueKey('timezone-search')),
  );
  final hint = field.decoration?.hintText;
  beforeClose?.call(field);
  // Close the sheet before the next locale pumps a fresh app: a modal
  // barrier left standing puts the next `open` button under it, and the
  // tap then only lands by luck.
  Navigator.of(tester.element(find.byKey(const ValueKey('timezone-search'))))
      .pop();
  await tester.pumpAndSettle();
  return hint;
}

/// The label the same field is showing, read while the sheet is open.
Future<String?> _labelIn(WidgetTester tester, Locale locale) async {
  String? label;
  await _hintIn(tester, locale, beforeClose: (field) {
    label = field.decoration?.labelText;
  });
  return label;
}

void main() {
  testWidgets('the search hint is localized, not a literal Paris',
      (tester) async {
    // The defect: every locale was shown 'Europe/Paris'. Each now names
    // a zone its own reader recognises.
    const expected = {
      'en': 'Europe/London',
      'fr': 'Europe/Paris',
      'de': 'Europe/Berlin',
      'es': 'Europe/Madrid',
      'it': 'Europe/Rome',
    };

    for (final entry in expected.entries) {
      final hint = await _hintIn(tester, Locale(entry.key));
      expect(hint, entry.value,
          reason: '${entry.key} shows "$hint" — the hint tells a reader '
              'what to type, so it names a city they know');
    }
  });

  testWidgets('the hint comes from the localizations, so it cannot drift '
      'back to a literal', (tester) async {
    // The assertion that survives a rename: whatever the French value
    // is, it must BE the localized one rather than a coincidence. If
    // somebody re-hardcodes 'Europe/Paris', French still passes above —
    // this is the case that would not.
    final l10n = await AppLocalizations.delegate.load(const Locale('de'));
    final hint = await _hintIn(tester, const Locale('de'));

    expect(hint, l10n.workspaceTimezoneHint,
        reason: 'the field must read its hint from AppLocalizations; a '
            'literal would pass the French case by accident and fail here');
    expect(hint, isNot('Europe/Paris'),
        reason: 'the #1390 defect, stated directly');
  });

  testWidgets('the label above it stays localized too', (tester) async {
    // Guarding the thing that was already right: the label resolved
    // through l10n and the hint did not, and the fix must not trade one
    // for the other.
    final l10n = await AppLocalizations.delegate.load(const Locale('it'));
    final label = await _labelIn(tester, const Locale('it'));

    expect(label, l10n.workspaceTimezoneLabel);
  });
}
