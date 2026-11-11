// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3599 — a personal surface lists the documents of businesses in different
// countries, so every amount on it goes through `AppFormat.moneyNamed`: the
// currency of the record itself, spelled so it cannot be taken for another
// one. The formatters of a business's own screens (`money`, `moneyCompact`,
// `moneyIn`, `moneyFormat`) spell a narrow symbol and fall back to the open
// business's currency or to the platform's default: none of them belongs
// here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'lint_sources.dart';

/// The personal surfaces outside `lib/features/me`: Me › Finances and the
/// account history live with the money feature.
const List<String> _personalMoneyFiles = [
  'lib/features/money/presentation/screens/account_activity_screen.dart',
  'lib/features/money/presentation/screens/my_finances_screen.dart',
  'lib/features/money/presentation/widgets/finance_document_views.dart',
  'lib/features/money/presentation/widgets/finances_owed_summary.dart',
  'lib/features/money/presentation/widgets/host_activity.dart',
  'lib/features/money/presentation/widgets/host_payment_pages.dart',
  'lib/features/money/presentation/widgets/my_finances_link_card.dart',
  'lib/features/money/presentation/widgets/my_finances_parts.dart',
  'lib/features/money/presentation/widgets/own_finance_export_menu.dart',
  'lib/features/money/presentation/widgets/personal_payment_provider.dart',
];

final RegExp _workspaceFormatter = RegExp(
  r'\.money\(|\.moneyCompact\(|\.moneyIn\(|\bmoneyFormat\(',
);

/// #3647 — the formats a personal surface must not read: the one that
/// follows the route ([appFormatProvider] / `appFormatOf`), which a sheet
/// or a test can reach from a business's layer, and the business's own. A
/// personal surface names `personalFormatProvider` / `personalFormatOf`.
final RegExp _businessFormat = RegExp(
  r'\bappFormatProvider\b|\bappFormatOf\(|\bbusinessFormatProvider\b',
);

List<String> _offenders(RegExp rule, List<File> files) => [
      for (final file in files)
        for (final (n, line) in file.readAsLinesSync().indexed)
          if (rule.hasMatch(line.split('//').first))
            '${file.path}:${n + 1}: ${line.trim()}',
    ];

List<File> _personalFiles() => [
      ...handWrittenDartFiles('lib/features/me'),
      for (final path in _personalMoneyFiles) File(path),
    ];

void main() {
  test('every listed personal file exists', () {
    for (final path in _personalMoneyFiles) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason:
            '$path moved or was removed: update the list, do not drop '
            'the file from the rule',
      );
    }
  });

  test('a personal surface formats money with moneyNamed only', () {
    final offenders = _offenders(_workspaceFormatter, _personalFiles());
    expect(
      offenders,
      isEmpty,
      reason:
          'use appFormat.moneyNamed(record.currency).formatMinor(…) on '
          'a personal surface (#3599):\n${offenders.join('\n')}',
    );
  });

  test('a personal surface reads the personal format only', () {
    final offenders = _offenders(_businessFormat, _personalFiles());
    expect(
      offenders,
      isEmpty,
      reason:
          'read ref.watch(personalFormatProvider) or personalFormatOf(context) '
          'on a personal surface (#3647):\n${offenders.join('\n')}',
    );
  });

  test('the personal-format rule sees a planted offender', () {
    final dir = Directory.systemTemp.createTempSync('personal_format_lint');
    addTearDown(() => dir.deleteSync(recursive: true));
    final planted = File('${dir.path}/planted.dart')
      ..writeAsStringSync([
        'final a = ref.watch(appFormatProvider);',
        'final b = appFormatOf(context).date(at);',
        'final c = ref.watch(businessFormatProvider);',
        '// appFormatOf(context) in a comment is not code',
        'final d = ref.watch(personalFormatProvider);',
        'final e = personalFormatOf(context).date(at);',
      ].join('\n'));
    expect(
      _offenders(_businessFormat, [planted]).map((o) => o.split(':')[1]),
      ['1', '2', '3'],
    );
  });

  test('the rule sees an offender (it is not vacuous)', () {
    expect(_workspaceFormatter.hasMatch('format.money(cents)'), isTrue);
    expect(
      _workspaceFormatter.hasMatch('format.moneyIn(code).formatMinor(1)'),
      isTrue,
    );
    expect(
      _workspaceFormatter.hasMatch('moneyFormat(code, locale: l)'),
      isTrue,
    );
    expect(
      _workspaceFormatter.hasMatch('format.moneyNamed(code).formatMinor(1)'),
      isFalse,
    );
  });
}
