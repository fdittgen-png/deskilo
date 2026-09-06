// SPDX-License-Identifier: 0BSD
//
// #957 — the per-year archive bundle: its name, its register, its zip.
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:deskilo/features/money/domain/accounting_format.dart';
import 'package:deskilo/features/money/domain/archive_bundle.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

Invoice _inv(String number, DateTime at, int total, {String replaces = ''}) => Invoice(
      id: 'i-$number', workspaceId: 'w', memberId: 'm', number: number, issuedAt: at,
      period: '2026-09', title: '', lines: const [InvoiceLine(kind: 'subscription', label: '100', amountCents: 10000)],
      totalCents: total, currency: 'EUR', memberName: 'Ana Martin', memberAddress: '', workspaceName: 'W',
      workspaceAddress: '', issuerName: 'F', signature: 'f' * 64, replacesNumber: replaces,
    );

void main() {
  test('the bundle is named after the entity and the year, DEV first for a development workspace', () {
    expect(archiveBundleFileName('812 345 678', 2026), '812345678-2026-archive.zip');
    expect(archiveBundleFileName('812 345 678', 2026, development: true), 'DEV-812345678-2026-archive.zip');
    expect(archiveBundleFileName('', 2026), 'archive-2026-archive.zip');
  });

  test('the register lists every document in issue order with its status and integrity word', () {
    final csv = buildInvoiceRegisterCsv(
      [_inv('INV-2', DateTime(2026, 9, 2), -1000, replaces: 'INV-1'), _inv('INV-1', DateTime(2026, 9, 1), 10000)],
      integrity: {'i-INV-1': 'verified'},
    );
    final lines = const LineSplitter().convert(csv);
    expect(lines.first, startsWith('number;issued;period;kind;member;member_number;total;currency;status;replaces;integrity'));
    expect(lines[1], '"INV-1";2026-09-01;"2026-09";full;"Ana Martin";"";100.00;EUR;issued;"";verified');
    expect(lines[2], contains('"INV-2";2026-09-02;"2026-09";full;"Ana Martin";"";-10.00;EUR;credit_note;"INV-1";'));
  });

  test('the zip holds every file under its path, in a deterministic order', () {
    final bytes = zipBundle({
      'register.csv': textBytes('a;b\r\n'),
      'invoices/INV-1.pdf': [37, 80, 68, 70],
      'audit-trail.csv': textBytes('x\r\n'),
    });
    final archive = ZipDecoder().decodeBytes(bytes);
    expect(archive.files.map((f) => f.name).toList(), ['audit-trail.csv', 'invoices/INV-1.pdf', 'register.csv']);
    expect(utf8.decode(archive.findFile('register.csv')!.content as List<int>), 'a;b\r\n');
    expect(zipBundle({'a': [1]}), zipBundle({'a': [1]}), reason: 'byte-identical for the same input');
  });

  test('the bundle is an export format offered everywhere', () {
    expect(accountingFormats.map((f) => f.id), contains('bundle'));
    for (final c in ['FR', 'DE', 'ES', 'PT', 'XX']) {
      expect(formatsFor(c).map((f) => f.id), contains('bundle'), reason: c);
    }
    expect(archiveBundleFormat.extension, 'zip');
  });
}
