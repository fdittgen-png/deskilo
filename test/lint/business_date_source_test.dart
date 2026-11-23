// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4322 -- a business date comes from the BUSINESS's calendar. A date made from the clock's instant
// by reading its year, month or day (`now().day`, `.toLocal().year`, `DateTime(now.year, ...)`,
// `DateUtils.dateOnly(now)`) is the date on the DEVICE's zone: a business in Auckland is read a day
// ahead of a phone in Los Angeles and the year filter of an invoice files it in the wrong year.
// The date is read through `businessDateOf` / `WorkspaceCalendar.dateOf` / `businessTodayProvider`
// (the workspace's time zone), or the server's own date is used.
//
// The cases left in `lib/features/*/domain` and `presentation` are COUNTED, each one a date to
// move onto the business's calendar; the ceiling only falls. (`DateTime.now()` itself is already
// banned by `no_wall_clock_test`, and `.toLocal()` below presentation is pinned by
// `format_seam_test`.)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'literal_ratchet.dart';

final _deviceDate = LiteralKind(
  'a date read off the clock\'s instant',
  RegExp(
    r'\bnow\(\)\s*\.(?:year|month|day|weekday)\b'
    r'|\.toLocal\(\)\s*\.(?:year|month|day|weekday)\b'
    r'|\bDateTime\(\s*(?:now|today|_now|clock\.now\(\))\s*\.year\b'
    r'|DateUtils\.dateOnly\(\s*(?:now|clock\.now\(\)|ref\.read\(clockProvider\)\.now\(\))'
    // #4426 -- the instant handed on as the day itself: `today = ...clockProvider...now();`
    r'|\b(?:today|_today|day|date|_date)\s*=\s*(?:ref\.(?:read|watch)\(clockProvider\)|clock)\.now\(\)\s*[;,)]',
  ),
);

/// #4426 -- a variable assigned from the clock (`final at = ref.read(clockProvider).now();`, `_clock.now()`,
/// `widget.clock.now()`) whose year, month and day then build a date, under whatever name: the same device date, one line
/// further. Counted per file with the direct shapes above.
final _fromClock = RegExp(r'\b(\w+)\s*=\s*[^;=]*\b(?:clockProvider|\w*[cC]lock)\b[^;]*\.now\(\)\s*;');

int _throughVariables(File file) {
  final text = codeLines(file).join('\n');
  var n = 0;
  for (final m in _fromClock.allMatches(text)) {
    final v = RegExp.escape(m.group(1)!);
    n += RegExp('\\bDateTime\\(\\s*$v\\.year\\b|DateUtils\\.dateOnly\\(\\s*$v\\s*\\)').allMatches(text).length;
  }
  return n;
}

/// The layers whose dates are counted: domain and presentation since #4322, and since #4426 providers, application and
/// the app's own wiring, where the same device date was being made.
bool _counted(File f) {
  final path = f.path;
  if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) return false;
  if (path.contains('lib/app/')) return true;
  if (!path.contains('lib/features/')) return false;
  return ['/domain/', '/presentation/', '/providers/', '/application/'].any(path.contains);
}

/// The cases recorded per file (#4322, widened by #4426): each is a date to move onto the business's calendar. A count
/// only falls, and a file that is not listed holds none: a new file cannot add a device-clock date. Regenerate with
/// `WRITE_BASELINE=true flutter test test/lint/business_date_source_test.dart` when a file is cleaned.
const _baselineFile = 'test/lint/business_date_source_baseline.txt';

void main() {
  test('the pattern sees a date read off the device clock and not one read on the business\'s calendar', () {
    for (final bad in [
      'final d = clock.now().day;',
      'final y = at.toLocal().year;',
      'final today = DateTime(now.year, now.month, now.day);',
      'final d = DateUtils.dateOnly(now);',
      'final d = DateUtils.dateOnly(ref.read(clockProvider).now());',
      'final today = ref.watch(clockProvider).now();',
      'final today = ref.read(clockProvider).now();',
      'final date = clock.now();',
    ]) {
      expect(_deviceDate.pattern.hasMatch(bad), isTrue, reason: bad);
    }
    for (final good in [
      'final d = businessDateOf(at, timezone);',
      'final d = calendar.dateOf(clock.now());',
      'final today = ref.watch(businessTodayProvider);',
      'final shown = appFormatOf(context).date(at);',
      'final today = ref.watch(businessDayProvider);',
      'final d = ref.watch(businessDateOfProvider)(ref.watch(clockProvider).now());',
      'final at = ref.read(clockProvider).now();',
    ]) {
      expect(_deviceDate.pattern.hasMatch(good), isFalse, reason: good);
    }
  });

  test('a variable assigned from a clock whose year, month and day build a date is seen, under any name', () {
    final dir = Directory.systemTemp.createTempSync('business_date_fixture');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bad = File('${dir.path}/bad.dart')
      ..writeAsStringSync('void f(){ final at = ref.read(clockProvider).now(); final d = DateTime(at.year, at.month, at.day); }\n'
          'void g(){ final stamp = _clock.now(); final d = DateUtils.dateOnly(stamp); }\n');
    final good = File('${dir.path}/good.dart')
      ..writeAsStringSync('void f(){ final at = ref.read(clockProvider).now(); final d = calendar.dateOf(at); }\n');
    expect(_throughVariables(bad), 2);
    expect(_throughVariables(good), 0);
  });

  test('dates made off the device clock only fall, per file, and a file not on the list holds none', () {
    final files = filesUnder(['lib/features', 'lib/app']).where(_counted);
    final perFile = {...countLiterals(files, [_deviceDate])[_deviceDate.name]!};
    for (final f in files) {
      final more = _throughVariables(f);
      if (more > 0) perFile[f.path] = (perFile[f.path] ?? 0) + more;
    }
    if (const bool.fromEnvironment('WRITE_BASELINE')) {
      File(_baselineFile).writeAsStringSync(
        '# #4322/#4426 -- dates made off the device clock, per file; a count only falls (see business_date_source_test.dart)\n'
        '${(perFile.entries.toList()..sort((a, b) => a.key.compareTo(b.key))).map((e) => '${e.key}: ${e.value}').join('\n')}\n',
      );
    }
    final baseline = {
      for (final line in File(_baselineFile).readAsLinesSync())
        if (line.isNotEmpty && !line.startsWith('#')) line.split(': ').first: int.parse(line.split(': ').last),
    };
    final up = <String>[];
    final down = <String>[];
    for (final path in {...perFile.keys, ...baseline.keys}) {
      final now = perFile[path] ?? 0;
      final was = baseline[path] ?? 0;
      if (now > was) up.add('$path: $was -> $now');
      if (now < was) down.add('$path: $was -> $now');
    }
    expect(
      up,
      isEmpty,
      reason:
          'a date made off the device clock where the business\'s calendar is the source (#4322, #4426): read it through '
          'businessDayProvider / businessDateOfProvider / WorkspaceCalendar.dateOf. A file not in the baseline holds none.',
    );
    expect(down, isEmpty, reason: 'a win: lower the baseline of these files (WRITE_BASELINE=true)');
    expect(total(perFile), total({for (final e in baseline.entries) e.key: e.value}));
  });
}
