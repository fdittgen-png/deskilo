// SPDX-License-Identifier: 0BSD
//
// #875 — the local report runner works from a cold shell.
//
// `tool/report.dart` is what a person or Claude runs to prove a design
// before it is imported, so it has to work exactly as documented and
// stay pure Dart: the moment it imports Flutter it needs the app's
// toolchain and the whole point is lost. Both are checked here, the
// second by reading the source rather than trusting a comment.
import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:flutter_test/flutter_test.dart';

const _sample = 'tool/report/samples/invoice-fr.xml';

Future<ProcessResult> _run(List<String> args) =>
    Process.run('dart', ['run', 'tool/report.dart', ...args]);

void main() {
  test('the runner imports no Flutter and no generated l10n', () {
    final src = File('tool/report.dart').readAsStringSync();
    expect(src, isNot(contains("package:flutter")),
        reason: 'the CLI must run without the app toolchain');
    expect(src, isNot(contains('/l10n/')),
        reason: 'the CLI cannot depend on generated localizations');
  });

  test('check renders the sample layout, measures it, and CONFORMS',
      () async {
    final out = Directory.systemTemp.createTempSync('report-cli');
    final pdf = '${out.path}/invoice.pdf';
    final result = await _run(['check', _sample, '--out', pdf]);
    expect(result.exitCode, 0,
        reason: 'stdout:\n${result.stdout}\nstderr:\n${result.stderr}');
    expect(result.stdout, contains('CONFORMS'));
    expect(result.stdout, contains('address field'));
    expect(File(pdf).existsSync(), isTrue);
    expect(String.fromCharCodes(File(pdf).readAsBytesSync().take(5)),
        '%PDF-');
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a layout that puts ink in the window band FAILS check with exit 1',
      () async {
    final out = Directory.systemTemp.createTempSync('report-cli');
    final bad = File('${out.path}/bad.xml')
      ..writeAsStringSync('''
<report-layout margin="20mm">
  <recipient window="fr"/>
  <body y="60mm"><text>trop haut — dans la fenêtre</text></body>
</report-layout>''');
    final result = await _run(['check', bad.path]);
    expect(result.exitCode, 1, reason: '${result.stdout}');
    expect(result.stdout, contains('ISSUE'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('a layout that cannot be read exits 2 and names the element', () async {
    final out = Directory.systemTemp.createTempSync('report-cli');
    final bad = File('${out.path}/bad.xml')
      ..writeAsStringSync('<report-layout><body><blink/></body></report-layout>');
    final result = await _run(['check', bad.path]);
    expect(result.exitCode, 2);
    expect(result.stderr, contains('report-layout/body/blink'));
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('sample writes every placeholder the engine knows', () async {
    final out = Directory.systemTemp.createTempSync('report-cli');
    final json = '${out.path}/invoice.json';
    final result = await _run(['sample', '--out', json]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final data = jsonDecode(File(json).readAsStringSync()) as Map;
    for (final key in InvoicePdfTemplate.placeholders) {
      expect(data.containsKey(key), isTrue, reason: 'sample lacks $key');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));

  test('describe lists the vocabulary a design may use', () async {
    final result = await _run(['describe']);
    expect(result.exitCode, 0);
    for (final word in ['<header', '<recipient', '<body', '<footer', 'mm',
        'px', '%', 'iban', 'lines']) {
      expect(result.stdout, contains(word), reason: word);
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
