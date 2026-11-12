// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3653 — what a person reads is formatted by the boundary
// (`lib/core/i18n/app_format.dart`, `rate_format.dart`, `capitalize.dart`),
// never by hand: a rate as "8.1 %" built with a dot decimal and a literal
// sign, a raw ISO day in a Text, a forced 24-hour clock, a capital taken from
// the first code unit. `format_seam_test.dart` guards the Intl entry points;
// this one guards the hand-built text around them, in every layer.
//
// The writers of a MACHINE-READABLE format (the accountant CSV, DATEV, FEC,
// SAF-T, e-invoices, VAT files) and the stored keys are not displays: they
// keep their canonical formatters and are named below with the invariant
// each implements. No ambient format is ever passed into an export writer.
//
// Each kind is counted per file; a file's count is pinned and only falls.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';
import 'literal_ratchet.dart';

/// A pinned count and the invariant that justifies it.
typedef Allowed = (int, String);

const _machineMoney =
    'a machine file: the point-decimal, locale-independent money/tax text of '
    'a versioned export, identical whoever clicks Export';

/// Every file that may hold a kind, with its pinned count.
const _allowed = <String, Map<String, Allowed>>{
  'toStringAsFixed(': {
    'lib/core/theme/contrast_audit.dart': (
      1,
      'a developer audit message naming a contrast ratio, never shown to a member',
    ),
    'lib/core/format/cents.dart': (
      1,
      'the point-decimal text of an amount typed into a field (`centsToMajor`), read back by the input parser, not a display',
    ),
    'lib/features/money/domain/accountant_csv.dart': (2, _machineMoney),
    'lib/features/money/domain/vat_register_it.dart': (
      1,
      'a machine file: the Italian VAT register states the rate with two decimals',
    ),
    'lib/features/workspace/domain/workspace_excel.dart': (
      1,
      'a machine file: the spreadsheet export states the VAT of a rate with two decimals',
    ),
    'lib/features/money/domain/report_layout/pdf_geometry.dart': (
      2,
      'a coordinate in millimetres in a developer trace, not a value a member reads',
    ),
    'lib/features/directory/presentation/public_page_place.dart': (
      2,
      'a machine key: a latitude and a longitude in a map link',
    ),
    'lib/features/money/presentation/widgets/accountant_handoff_preflight.dart':
        (
          1,
          'a machine file: the amount the accountant handoff checks, point-decimal',
        ),
    'lib/features/money/presentation/widgets/vat_rate_editor.dart': (
      1,
      "what the owner types into a rate field: an input value, not a display (a typed number is read back by parseDecimalInput)",
    ),
    'lib/features/money/presentation/widgets/negotiation_card.dart': (
      1,
      'the text of a discount input field, not a display',
    ),
    'lib/features/money/presentation/widgets/purchase_order_receipt_actions.dart':
        (1, 'a quantity typed into a receipt field, not a display'),
    'lib/features/reservations/presentation/widgets/place_feedback_bar.dart': (
      2,
      'a star average with one decimal; a rating is not a rate or an amount',
    ),
  },
  'a rate built with a literal %': {
    'lib/features/money/domain/accountant_csv.dart': (2, _machineMoney),
    'lib/features/money/domain/fec_writer.dart': (
      1,
      'a machine file: the FEC journal label of a VAT line (comma decimal, fixed by the standard)',
    ),
    'lib/features/money/domain/report_letter_layouts.dart': (
      29,
      'layout geometry: column widths in percent units of a stored layout file, not a displayed rate',
    ),
    'lib/features/money/presentation/report_sample_data.dart': (
      6,
      'a sample row printed to show a design its placeholders: fixed French sample data, never a member\'s figure',
    ),
    'lib/features/money/domain/xero_invoice_csv.dart': (
      2,
      'a machine file: the Xero import label, point-decimal',
    ),
    'lib/features/money/presentation/report_defaults.dart': (
      1,
      'a template: the Jinja-style `{% if %}` blocks of a stored report design, not a rate',
    ),
    'lib/features/money/domain/report_layout_file.dart': (
      1,
      'a machine file: the layout file\'s unit vocabulary',
    ),
    'lib/features/directory/data/supabase_public_discovery_repository.dart': (
      1,
      'a machine key: the SQL LIKE wildcard of a search',
    ),
  },
  'a raw ISO day in displayed text': {},
  'a forced 24-hour clock': {
    'lib/features/profile/presentation/screens/developer_screen.dart': (
      3,
      'machine stamps: file names and the raw developer log line, never a member-facing time',
    ),
  },
  'a capital from the first code unit': {
    'lib/features/workspace/domain/workspace_export_labels.dart': (
      1,
      'a stored key in readable English (`created_at` is `Created at`), not a localized value',
    ),
    'lib/features/workspace/domain/workspace_process.dart': (
      2,
      'a catalogue key built into an ARB key name (`processFoo`), ASCII by construction',
    ),
    'lib/features/workspace/domain/setup_obligations.dart': (
      1,
      'the English source sentence of an obligation, not a localized value',
    ),
    'lib/features/task_recorder/presentation/guide_host/guide_step_text.dart': (
      1,
      'a URL path segment named as a step, ASCII by construction',
    ),
  },
};

final _kinds = <LiteralKind>[
  LiteralKind('toStringAsFixed(', RegExp(r'\.toStringAsFixed\(')),
  LiteralKind(
    'a rate built with a literal %',
    RegExp(r'''(?:\}|\$\w+)\s?%(?=['"\s)])|['"]\d+(?:[.,]\d+)?\s?%['"]'''),
  ),
  LiteralKind(
    'a raw ISO day in displayed text',
    RegExp(
      r'(?:\bText\(|\bl10n\.\w+\()(?:(?!;)[\s\S])*?(?:(?<![.\w])isoDay\(|toIso8601String\()',
    ),
  ),
  LiteralKind(
    'a forced 24-hour clock',
    RegExp(r'''\.add_Hm\(\)|DateFormat\.Hm\(|DateFormat\(\s*['"][^'"]*HH'''),
  ),
  LiteralKind(
    'a capital from the first code unit',
    RegExp(r'\[0\]\.toUpperCase\(\)|substring\(0,\s?1\)\.toUpperCase\(\)'),
  ),
];

/// The boundary itself: the one place allowed to build these.
const _boundary = {
  'lib/core/i18n/app_format.dart',
  'lib/core/i18n/rate_format.dart',
  'lib/core/i18n/capitalize.dart',
};

void main() {
  group('the patterns see what they name, and only that', () {
    bool hits(String kind, String code) =>
        _kinds.firstWhere((k) => k.name == kind).pattern.hasMatch(code);

    test('a rate built by hand', () {
      expect(hits('a rate built with a literal %', r"'${p.rate} %'"), isTrue);
      expect(hits('a rate built with a literal %', r"'$pct %'"), isTrue);
      expect(hits('a rate built with a literal %', "'20 %'"), isTrue);
      expect(
        hits('a rate built with a literal %', 'final r = (a + b) % 7;'),
        isFalse,
      );
      expect(
        hits('a rate built with a literal %', r"format.ratePercent(8.1)"),
        isFalse,
      );
    });

    test('a raw ISO day in a Text or a message', () {
      expect(
        hits('a raw ISO day in displayed text', 'Text(isoDay(day))'),
        isTrue,
      );
      expect(
        hits(
          'a raw ISO day in displayed text',
          'l10n.since(\n  day.toIso8601String())',
        ),
        isTrue,
      );
      expect(
        hits(
          'a raw ISO day in displayed text',
          'Text(appFormatOf(context).isoDay(day))',
        ),
        isFalse,
      );
      expect(
        hits('a raw ISO day in displayed text', 'final key = isoDay(day);'),
        isFalse,
      );
    });

    test('a forced 24-hour clock and a first-code-unit capital', () {
      expect(
        hits('a forced 24-hour clock', 'DateFormat.yMd().add_Hm()'),
        isTrue,
      );
      expect(hits('a forced 24-hour clock', "DateFormat('HH:mm')"), isTrue);
      expect(
        hits('a forced 24-hour clock', 'DateFormat.yMd().add_jm()'),
        isFalse,
      );
      expect(
        hits(
          'a capital from the first code unit',
          'name[0].toUpperCase() + name.substring(1)',
        ),
        isTrue,
      );
      expect(
        hits(
          'a capital from the first code unit',
          'capitalizeFirst(name, locale: l)',
        ),
        isFalse,
      );
    });
  });

  final files = [
    for (final f in handWrittenDartFiles('lib'))
      if (!_boundary.contains(f.path.replaceAll(r'\', '/'))) File(f.path),
  ];
  final counted = countLiterals(files, _kinds);

  for (final kind in _kinds) {
    test('${kind.name}: only where it is allowed, each count pinned', () {
      final allowed = _allowed[kind.name] ?? const <String, Allowed>{};
      final perFile = counted[kind.name]!;
      final problems = <String>[];
      for (final MapEntry(key: path, value: n) in perFile.entries) {
        final key = path.replaceAll(r'\', '/');
        final pinned = allowed[key]?.$1 ?? 0;
        if (n != pinned) {
          problems.add(
            '$key: $n, pinned at $pinned. A new one goes through the '
            'boundary (AppFormat.ratePercent / fractionPercent / isoDay / '
            'calendarDay / time, capitalizeFirst); a removed one lowers '
            'the pin.',
          );
        }
      }
      for (final MapEntry(key: path, value: (pinned, why)) in allowed.entries) {
        expect(why.trim(), isNotEmpty, reason: path);
        expect(
          File(path).existsSync(),
          isTrue,
          reason: '$path is gone: drop it',
        );
        if (!perFile.containsKey(path) && pinned > 0) {
          problems.add('$path: 0, pinned at $pinned: drop it from the list.');
        }
      }
      expect(
        problems,
        isEmpty,
        reason:
            'format boundary (#3653), "${kind.name}":\n'
            '${problems.join('\n')}',
      );
    });
  }
}
