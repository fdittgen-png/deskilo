// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3485 -- the structure of the ICU messages, which `arb_key_parity_test`
// (key sets only) cannot see:
//   (a) every locale carries the same placeholders, plural variables and
//       select case sets as English; a plural's own cases are the language's
//       (#3743: `one` / `other`, `=0` for a different sentence, so French may
//       carry an `=0` English does not), checked by test/lint/arb_plural_test;
//   (b) a message that interpolates `{count}` / `{n}` without a plural reads
//       wrong at 1: it takes plural forms or sits on a reasoned allow-list;
//   (c) no select echoes its own argument: a dictionary word is a key per
//       case (lib/l10n/dictionary_labels.dart), so a missing one is a test;
//   (d) the longest English value only shrinks.
// The ceilings are the measure of 2026-11-10; the follow-up slices lower them.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lint/icu_message.dart';

const _locales = ['fr', 'de', 'es', 'it'];

/// Messages that keep a bare `{count}` / `{n}`, each with its reason: a
/// position or a number in a label (`Line {n}`, `×{count}`), a count after a
/// colon or in brackets (a figure, not a noun phrase), an invariable adjective
/// (`{count} overdue`), or a constant noun (`of 12 columns`). The list only
/// shrinks; a new count takes plural forms.
const Map<String, String> _bareCountAllowed = {
  'acctDeliverInFlight': 'after a colon',
  'acctDeliverStoppedAt': 'after a colon',
  'availabilityHourOption': 'unit label',
  'bankCsvColumn': 'position',
  'biEditorColumns': 'of 12: a constant total',
  'biEditorPlace': 'position',
  'biEditorVisualLabel': 'position',
  'biVendorCredited': 'in brackets',
  'capacityKpiRooms': 'after a colon',
  'compareOpen': 'in brackets',
  'eventRepeatedMarker': 'a multiplier mark',
  'financesRemindedTimes': 'a multiplier mark',
  'inboxRequestsCount': 'after a colon',
  'instanceDeployFunctions': 'in brackets',
  'instanceInstallSchema': 'in brackets',
  'invoiceRemindedBadge': 'a multiplier mark',
  'invoiceSummaryToInvoice': 'a count before a verb phrase',
  'invoiceSummaryToRefund': 'a count before a verb phrase',
  'memberPageWorkspaceDefaultValue': 'in brackets',
  'memberReservationLimitChip': 'a chip value',
  'memberSimultaneousLimitChip': 'a chip value',
  'moneyRemindedTimes': 'a multiplier mark',
  'overviewTilePosition': 'position',
  'payConfigSettlementsFetched': 'a count before a participle',
  'portalDirectoryCount': 'in brackets',
  'purchaseOrderLine': 'position',
  'scheduledExpensesFinished': 'in brackets',
  'serviceStockCount': 'a count before a preposition',
  'setupChoicesSummary': 'after a colon',
  'setupOverviewRemaining': 'after a colon',
  'templateExportResults': 'in brackets',
  'usagePrepared': 'after a colon',
  'validationStepSequential': 'a count after a dash',
  'wizardSettle': 'a count before a verb phrase',
  'workspaceXmlImportPreviewAccessories': 'after a colon',
};

/// The longest English message, in characters.
const _longestCeiling = 565;

Map<String, String> _messages(String locale) {
  final map =
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
          as Map<String, dynamic>;
  return {
    for (final e in map.entries)
      if (!e.key.startsWith('@') && e.value is String) e.key: e.value as String,
  };
}

/// One plural / select construct of a message: its argument, kind and cases.
typedef _Construct = ({String arg, String kind, List<String> cases});

int _closing(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '{') depth++;
    if (s[i] == '}') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return s.length - 1;
}

final _head = RegExp(r'^\s*(\w+)\s*,\s*(plural|select|selectordinal)\s*,');
final _caseHead = RegExp(r'\s*(=?\w+)\s*\{');

/// Every construct of [text], nested ones included, as a sorted signature.
List<String> _constructs(String text) {
  final out = <_Construct>[];
  void scan(String s) {
    var k = 0;
    while (k < s.length) {
      if (s[k] != '{') {
        k++;
        continue;
      }
      final end = _closing(s, k);
      final inner = s.substring(k + 1, end);
      final head = _head.firstMatch(inner);
      if (head != null) {
        final rest = inner.substring(head.end);
        final cases = <String>[];
        var q = 0;
        while (q < rest.length) {
          final m = _caseHead.matchAsPrefix(rest, q);
          if (m == null) {
            q++;
            continue;
          }
          final open = m.end - 1;
          final close = _closing(rest, open);
          cases.add(m.group(1)!);
          scan(rest.substring(open + 1, close));
          q = close + 1;
        }
        final kind = head.group(2)!;
        out.add((
          arg: head.group(1)!,
          kind: kind,
          // A plural's cases are the language's own (#3743).
          cases: kind == 'select' ? (cases..sort()) : <String>[],
        ));
      }
      k = end + 1;
    }
  }

  scan(text);
  return ([for (final c in out) '${c.arg}:${c.kind}:${c.cases.join('|')}']
    ..sort());
}

void main() {
  final en = _messages('en');

  test('every locale carries the English placeholders, plurals and selects', () {
    final problems = <String>[];
    for (final locale in _locales) {
      final other = _messages(locale);
      for (final e in en.entries) {
        final mine = _constructs(e.value);
        final theirs = _constructs(other[e.key] ?? '');
        if ('$mine' != '$theirs') {
          problems.add('$locale ${e.key}: en $mine vs $locale $theirs');
        }
        final placeholders = allArgs(parseIcu(e.value));
        final mineArgs = allArgs(parseIcu(other[e.key] ?? ''));
        if (placeholders.difference(mineArgs).isNotEmpty ||
            mineArgs.difference(placeholders).isNotEmpty) {
          problems.add(
            '$locale ${e.key}: placeholders en ${placeholders.toList()..sort()}'
            ' vs $locale ${mineArgs.toList()..sort()}',
          );
        }
      }
    }
    expect(
      problems,
      isEmpty,
      reason: 'a locale differs from English in its ICU case set (#3485): '
          'add or drop the case in every language',
    );
  });

  test('a message counting with {count} / {n} has plural forms or a reason', () {
    final bare = RegExp(r'\{(count|n)\}');
    final offenders = {
      for (final e in en.entries)
        if (bare.hasMatch(e.value) &&
            !_constructs(e.value).any(
              (c) => c.startsWith('count:plural') || c.startsWith('n:plural'),
            ))
          e.key,
    };
    expect(
      offenders.difference(_bareCountAllowed.keys.toSet()),
      isEmpty,
      reason: 'a count without plural forms (#3485): give it '
          '{count, plural, one{…} other{…}} in all five languages',
    );
    expect(
      _bareCountAllowed.keys.toSet().difference(offenders),
      isEmpty,
      reason: 'these now have plural forms: drop them from _bareCountAllowed',
    );
  });

  test('a counted message reads differently at 1 and at 2 in every locale', () {
    for (final locale in AppLocalizations.supportedLocales) {
      final words = lookupAppLocalizations(locale);
      for (final (one, many) in [
        (words.invoiceCountShown(1), words.invoiceCountShown(2)),
        (words.holidayImportConfirm(1), words.holidayImportConfirm(2)),
        (words.taskRecorderStepCount(1), words.taskRecorderStepCount(2)),
        (words.processConfirmOn(1), words.processConfirmOn(2)),
        (words.scheduleEveryWeeks(1), words.scheduleEveryWeeks(2)),
      ]) {
        expect(one, isNot(many), reason: locale.languageCode);
        expect(one, isNot(contains('{')));
      }
    }
  });

  test('a language reads its own plural categories (#3743)', () {
    // French `one` covers 0 and 1: "0 jour", "1 jour", "2 jours".
    final fr = lookupAppLocalizations(const Locale('fr'));
    for (final (days, late, seen, value) in [
      (0, '0 jour de retard', 'Vu il y a 0 jour', '0 jour'),
      (1, '1 jour de retard', 'Vu il y a 1 jour', '1 jour'),
      (2, '2 jours de retard', 'Vu il y a 2 jours', '2 jours'),
    ]) {
      expect(fr.invoicingDaysLate(days), late);
      expect(fr.directoryLastSeenDays(days), seen);
      expect(fr.policyDaysValue(days), value);
    }
    // The other four languages are unchanged at 1 and at n.
    for (final (code, one, many) in [
      ('en', '1 day', '3 days'),
      ('de', '1 Tag', '3 Tage'),
      ('es', '1 día', '3 días'),
      ('it', '1 giorno', '3 giorni'),
    ]) {
      final words = lookupAppLocalizations(Locale(code));
      expect(words.policyDaysValue(1), one, reason: code);
      expect(words.policyDaysValue(3), many, reason: code);
    }
  });

  test('no select echoes its own argument as the fallback (#3485)', () {
    final echo = RegExp(r'\{(\w+),\s*select,.*other\{\{\1\}\}', dotAll: true);
    final offenders = [
      for (final e in en.entries)
        if (echo.hasMatch(e.value)) e.key,
    ];
    expect(
      offenders,
      isEmpty,
      reason: 'a select that prints its raw key when a case is missing: give '
          'each case its own key and map it in lib/l10n/dictionary_labels.dart',
    );
  });

  test('the longest English message only shrinks', () {
    final longest = en.values.fold<int>(0, (m, v) => v.length > m ? v.length : m);
    expect(longest, lessThanOrEqualTo(_longestCeiling));
    expect(longest, _longestCeiling,
        reason: 'record the win: lower _longestCeiling to $longest');
  });
}
