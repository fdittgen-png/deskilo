// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4419 -- a limit that lives on the server and in the app cannot differ between them, and a new
// copy cannot be added without saying where its source is. `_mirrors` pairs a Dart constant with
// its source: the SQL (the latest migration that states it) or the edge function that holds it;
// each pair is compared. A TypeScript `MAX_…` or `…_LIMIT` constant of supabase/functions is a row
// or carries the marker; the ones several functions share live once in _shared/limits.ts.
// Pinned elsewhere, with a shape a row does not have: a definer's text clip
// (text_limits_pinned_test) and the payment resend windows, which are settings
// (payment_resend_window_test). A
// numeric constant in a `*Limits` class, or named like a bound (`max…Length`, `…MaxBytes`, `…Limit`), that
// has no row below and no `// not-mirrored: <why>` on its line or the line above is counted;
// the count only falls (a row or a marker takes a constant out of it).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// One Dart constant and the SQL it mirrors: the constant [name] of [dartFile] is compared with the number
/// [sql] captures in group 1, read in the latest migration that matches it.
class Mirror {
  const Mirror(this.label, this.dartFile, this.name, this.sql, {this.migration, this.source});
  final String label;
  /// The migration (its number, `0089`) the bound is read in; null: the latest one that matches [sql].
  final String? migration;
  /// A file that holds the source instead of a migration (an edge function); [sql] is read there.
  final String? source;
  final String dartFile;
  final String name;
  final String sql;

  RegExp get dart => RegExp('const\\s+(?:(?:int|double|num)\\s+)?$name\\s*=\\s*([0-9]+);');
}

const _service = 'lib/features/money/domain/service_item.dart';
const _drawer = 'lib/features/money/domain/till_drawer_rules.dart';

const _mirrors = <Mirror>[
  // #4448 -- the till layout's bounds, the same in the app's validation and the server's (0959).
  Mirror('tillLayoutMaxGridSide (till_layout_max_grid_side())', 'lib/features/money/domain/till_layout.dart', 'tillLayoutMaxGridSide',
      r'function public\.till_layout_max_grid_side\(\)[^$]*\$fn\$\s*select\s+(\d+)\s*\$fn\$', migration: '0959'),
  Mirror('tillLayoutMaxBytes (till_layout_max_bytes())', 'lib/features/money/domain/till_layout.dart', 'tillLayoutMaxBytes',
      r'function public\.till_layout_max_bytes\(\)[^$]*\$fn\$\s*select\s+(\d+)\s*\$fn\$', migration: '0959'),
  Mirror('MemberNoteRules.maxLength (0089)', 'lib/features/workspace/domain/member_note.dart', 'maxLength',
      r'length\(btrim\(body\)\) between 1 and (\d+)', migration: '0089'),
  Mirror('StatusTextRules.maxLength (0029)', 'lib/features/profile/domain/profile.dart', 'maxLength',
      r'char_length\(status_text\) <= (\d+)'),
  Mirror('ServiceLimits.minMinutes (0711)', _service, 'minMinutes', r'duration_minutes between (\d+) and \d+'),
  Mirror('ServiceLimits.maxMinutes (0711)', _service, 'maxMinutes', r'duration_minutes between \d+ and (\d+)'),
  Mirror('ServiceLimits.descriptionMaxLength (0711)', _service, 'descriptionMaxLength', r'char_length\(description\) <= (\d+)'),
  Mirror('ServiceLimits.categoryMaxLength (0711)', _service, 'categoryMaxLength', r'char_length\(category\) between 1 and (\d+)'),
  Mirror('kTillNameMaxLength (0907)', _drawer, 'kTillNameMaxLength', r'name text not null check \(char_length\(btrim\(name\)\) between 1 and (\d+)\)',
      migration: '0907'),
  Mirror('kDrawerReasonMaxLength (0907)', _drawer, 'kDrawerReasonMaxLength',
      r'difference_reason is null or char_length\(difference_reason\) <= (\d+)', migration: '0907'),
  // #3556 -- the app refuses a selection over the payment function's limit before anything is sent.
  Mirror('maxClaimedInvoices (create-payment-order)', 'lib/features/money/domain/payment_claims.dart',
      'maxClaimedInvoices', r'export const MAX_CLAIMED_INVOICES = (\d+);',
      source: 'supabase/functions/create-payment-order/request.ts'),
  // #4318 -- the public services a public page carries.
  Mirror('publicPageServiceLimit (public_page_service_limit())', 'lib/features/money/domain/public_page.dart',
      'publicPageServiceLimit', r'function public\.public_page_service_limit\(\)[^$]*\$\$\s*select\s+(\d+)\s*\$\$'),
  // #1870 -- the exact range of an amount, on the edge money boundary.
  Mirror('maxSafeMinor (money.ts)', 'packages/deskilo_money_kernel/lib/src/accounting_amount.dart', 'maxSafeMinor',
      r'MAX_SAFE_MINOR = (\d+)n;', source: 'supabase/functions/_shared/money.ts'),
  Mirror('PurchaseOrderLimits.maxLines (0681)', _order, 'maxLines',
      r"jsonb_array_length\(p_payload -> 'lines'\) not between 1 and (\d+)"),
  Mirror('PurchaseOrderLimits.maxQuantity (0681)', _order, 'maxQuantity',
      r'quantity numeric not null check \(quantity > 0 and quantity <= (\d+)\)', migration: '0681'),
  // the note of a loss: the app refuses a longer one under its field, the table refuses it whatever door is used
  Mirror('kStockLossNoteMaxLength (stock_movements.loss_note)', 'lib/features/stock/domain/stock_operations.dart',
      'kStockLossNoteMaxLength', r'char_length\(loss_note\) between 1 and (\d+)'),
  // the scale of a stored quantity: the stock ledger's numeric(18, 6)
  Mirror('exactQuantityScale (0847)', 'packages/deskilo_money_kernel/lib/src/exact_quantity.dart',
      'exactQuantityScale', r'loaded numeric\(18, (\d+)\)', migration: '0847'),
];

const _order = 'lib/features/money/domain/purchase_order.dart';

final _tsBound = RegExp(r'^\s*(?:export\s+)?const\s+(MAX_\w+|\w+_LIMIT)\s*=\s*[0-9]');

/// The TypeScript bound constants of [source] with no `// not-mirrored:` marker on their line or above.
List<String> unlistedTsBounds(String source) {
  final lines = source.split('\n');
  return [
    for (var i = 0; i < lines.length; i++)
      if (_tsBound.firstMatch(lines[i]) case final m?
          when !lines[i].contains('not-mirrored:') && !(i > 0 && lines[i - 1].contains('not-mirrored:')))
        m.group(1)!,
  ];
}

/// RATCHET: numeric bound constants of `lib/` with no mirror row and no `// not-mirrored:` marker.
/// Only falls: give a constant its row (its SQL source), or the marker with the reason it has none.
const _unlistedBudget = 11;

final _bound = RegExp(
  r'^\s*(?:static\s+)?const\s+(?:int|double|num)\s+(\w+)\s*=\s*([0-9][0-9_.]*);',
);
// a bound is a count the server may also check: a length, a size in bytes or rows, a number of lines, items or
// pages, a quantity, a span of minutes or days (a width or a scale of the screen is the app's own)
final _boundName = RegExp(
  r'((^max|Max).*(Length|Chars|Bytes|Rows|Count|Lines|Items|Entries|Pages|Minutes|Days|Quantity|Size)|Limits?$|Limit[A-Z0-9])',
);
final _limitsClass = RegExp(r'^(?:abstract final |final |abstract )?class \w*Limits\b');

/// The `(name, line)` of the bound-like numeric constants of [source] without a marker.
List<(String, int)> unlistedBounds(String source) {
  final lines = source.split('\n');
  final out = <(String, int)>[];
  var inLimits = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (_limitsClass.hasMatch(line)) inLimits = true;
    if (inLimits && line == '}') inLimits = false;
    final m = _bound.firstMatch(line);
    if (m == null) continue;
    if (!inLimits && !_boundName.hasMatch(m.group(1)!)) continue;
    final marked = line.contains('not-mirrored:') ||
        (i > 0 && lines[i - 1].contains('not-mirrored:'));
    if (!marked) out.add((m.group(1)!, i + 1));
  }
  return out;
}

int _number(String text, Pattern pattern, String what) {
  final m = pattern.matchAsPrefix(text) ?? pattern.allMatches(text).firstOrNull;
  expect(m, isNotNull, reason: '$what: the pattern $pattern finds nothing');
  return int.parse(m!.group(1)!);
}

void main() {
  test('a bound constant with no row and no marker is seen', () {
    expect(unlistedBounds('abstract final class FooLimits {\n  static const int cap = 5;\n}\n'), [('cap', 2)]);
    expect(unlistedBounds('const int maxRows = 100;'), [('maxRows', 1)]);
    expect(unlistedBounds('// not-mirrored: a UI choice\nconst int maxRows = 100;'), isEmpty);
    expect(unlistedBounds('const int maxRows = 100; // not-mirrored: a UI choice'), isEmpty);
    expect(unlistedBounds('const int pageSize = 20;'), isEmpty);
    expect(unlistedBounds('class Other {\n  static const int cap = 5;\n}'), isEmpty);
  });

  test('every mirrored bound equals its SQL source', () {
    final all = sqlFiles('supabase/migrations').reversed.toList();
    for (final m in _mirrors) {
      final migrations = m.migration == null
          ? all
          : all.where((f) => f.uri.pathSegments.last.startsWith('${m.migration}_')).toList();
      final dart = _number(File(m.dartFile).readAsStringSync(), m.dart, m.label);
      File? source = m.source == null ? null : File(m.source!);
      for (final f in source == null ? migrations : const <File>[]) {
        if (RegExp(m.sql).hasMatch(f.readAsStringSync())) {
          source = f;
          break;
        }
      }
      expect(source, isNotNull, reason: '${m.label}: no migration states ${m.sql}');
      final sql = _number(source!.readAsStringSync(), RegExp(m.sql), m.label);
      expect(dart, sql, reason: '${m.label}: Dart $dart, SQL $sql (${source.uri.pathSegments.last})');
    }
  });

  test('a mirror row names a constant that exists', () {
    for (final m in _mirrors) {
      expect(m.dart.hasMatch(File(m.dartFile).readAsStringSync()), isTrue, reason: m.label);
    }
  });

  test('a TypeScript bound with no marker is seen', () {
    expect(unlistedTsBounds('export const MAX_PAGES = 10;\nconst PAGE_LIMIT = 5;'), ['MAX_PAGES', 'PAGE_LIMIT']);
    expect(unlistedTsBounds('export const MAX_PAGES = 10; // not-mirrored: a run budget'), isEmpty);
    expect(unlistedTsBounds('export const MAX_BODY_BYTES = MAIL_BODY_MAX_BYTES;'), isEmpty);
  });

  test('every TypeScript bound of an edge function is a row or says why it has none', () {
    final mirrored = {
      for (final m in _mirrors)
        if (m.source != null) m.source!: RegExp(r'MAX_\w+|\w+_LIMIT').firstMatch(m.sql)!.group(0)!,
    };
    final unlisted = [
      for (final f in filesWithExtension('supabase/functions', '.ts', recursive: true))
        if (!f.path.endsWith('_test.ts'))
          for (final name in unlistedTsBounds(f.readAsStringSync()))
            if (mirrored[f.path.replaceAll('\\', '/')] != name) '${f.path}: $name',
    ];
    expect(unlisted, isEmpty, reason: 'give it a row in _mirrors, or a // not-mirrored: <why> marker');
  });

  test('the unlisted bound constants only fall', () {
    var unlisted = 0;
    final shown = <String>[];
    for (final f in handWrittenDartFiles('lib')) {
      final path = f.path.replaceAll('\\', '/');
      for (final (name, line) in unlistedBounds(f.readAsStringSync())) {
        if (_mirrors.any((m) => m.dartFile == path && m.name == name)) continue;
        unlisted++;
        if (shown.length < 25) shown.add('$path:$line $name');
      }
    }
    expect(unlisted, lessThanOrEqualTo(_unlistedBudget), reason: 'give it a row or a // not-mirrored: marker:\n${shown.join('\n')}');
    expect(unlisted, _unlistedBudget, reason: 'it fell: lower _unlistedBudget to $unlisted');
  });
}
