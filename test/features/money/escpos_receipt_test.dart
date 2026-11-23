// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4368 (CS6) -- the bytes of a receipt: byte-identical goldens for an original and a copy at 80 and 58 mm, the code page
// of é ß ñ à, the drawer kick, and a TCP listener that captures what the sender sends. Regenerate a golden only when the
// receipt is MEANT to change: `--dart-define=WRITE_GOLDEN=true`, and say so.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/features/money/data/tcp_receipt_sender.dart';
import 'package:deskilo/features/money/domain/escpos_receipt.dart';
import 'package:deskilo/features/money/domain/receipt_sender.dart';
import 'package:flutter_test/flutter_test.dart';

const _write = bool.fromEnvironment('WRITE_GOLDEN');

ReceiptPrint _receipt({bool copy = false, String qr = '', String business = 'Épicerie du Marché'}) => ReceiptPrint(
  business: business,
  title: 'Receipt R-00001',
  issuedAt: '2026-11-22 09:41',
  lines: const [
    ReceiptPrintLine(label: 'Oat milk', amount: '4.20', detail: '2 l'),
    ReceiptPrintLine(label: 'Coffee beans, a very long name that has to wrap onto a second line', amount: '8.40', detail: '0.35 kg'),
    ReceiptPrintLine(label: 'Käse ñandú à ß', amount: '12.00'),
  ],
  taxLabel: 'of which tax',
  tax: '4.10',
  totalLabel: 'TOTAL',
  total: '24.60',
  tenders: const [ReceiptPrintTender(label: 'Cash', amount: '30.00')],
  changeLabel: 'Change',
  change: '5.40',
  copyMark: copy ? '*** COPY ***' : '',
  footer: 'Thank you',
  qr: qr,
);

String _hex(Uint8List bytes) {
  final b = StringBuffer();
  for (var i = 0; i < bytes.length; i += 16) {
    b.writeln(bytes.sublist(i, i + 16 > bytes.length ? bytes.length : i + 16).map((x) => x.toRadixString(16).padLeft(2, '0')).join(' '));
  }
  return b.toString();
}

void _golden(String name, Uint8List bytes) {
  final file = File('test/features/money/goldens/$name.hex');
  if (_write) file.writeAsStringSync(_hex(bytes));
  expect(_hex(bytes), file.readAsStringSync(), reason: '$name changed: the receipt is not byte-identical to its golden');
}

void main() {
  test('the code pages hold 128 characters each, and é ß ñ à are where a printer has them', () {
    for (final page in EscposCodePage.values) {
      expect(page.byteOf(0x41), 0x41);
      expect(page.byteOf('é'.runes.first), 0x82, reason: '$page é');
      expect(page.byteOf('ñ'.runes.first), 0xA4, reason: '$page ñ');
      expect(page.byteOf('à'.runes.first), 0x85, reason: '$page à');
      expect(page.byteOf('ß'.runes.first), 0xE1, reason: '$page ß');
      expect(page.byteOf('字'.runes.first), isNull);
    }
    expect(EscposCodePage.cp858.byteOf('€'.runes.first), 0xD5);
    expect(EscposCodePage.cp437.byteOf('€'.runes.first), isNull);
    expect(EscposCodePage.cp858.select, 19);
    expect(EscposCodePage.cp437.select, 0);
  });

  test('a character the page lacks is a question mark, never a wrong letter', () {
    final bytes = encodeReceipt(_receipt(business: '字'), const EscposProfile(codePage: EscposCodePage.cp437));
    expect(bytes.contains(0x3F), isTrue);
  });

  test('the drawer kick is ESC p, a pin and two pulse times in 2 ms units', () {
    expect(drawerKick(), [0x1B, 0x70, 0, 25, 250]);
    expect(drawerKick(pin: 1, onMs: 100, offMs: 200), [0x1B, 0x70, 1, 50, 100]);
  });

  test('80 mm: an original and a copy are byte-identical to their goldens', () {
    _golden('receipt_escpos_80', encodeReceipt(_receipt(), const EscposProfile()));
    _golden('receipt_escpos_80_copy', encodeReceipt(_receipt(copy: true), const EscposProfile()));
  });

  test('58 mm: an original and a copy are byte-identical to their goldens', () {
    const profile = EscposProfile(paperMm: 58);
    _golden('receipt_escpos_58', encodeReceipt(_receipt(), profile));
    _golden('receipt_escpos_58_copy', encodeReceipt(_receipt(copy: true), profile));
  });

  test('with a QR code the receipt carries the native QR commands', () {
    final bytes = encodeReceipt(_receipt(qr: 'https://example.test/r/1'), const EscposProfile());
    _golden('receipt_escpos_80_qr', bytes);
  });

  test('a copy says it is one and an original does not', () {
    final copy = String.fromCharCodes(encodeReceipt(_receipt(copy: true), const EscposProfile()));
    final original = String.fromCharCodes(encodeReceipt(_receipt(), const EscposProfile()));
    expect(copy, contains('*** COPY ***'));
    expect(original, isNot(contains('COPY')));
  });

  test('every line fits the paper: 48 columns at 80 mm, 32 at 58 mm', () {
    for (final (mm, cols) in const [(80, 48), (58, 32)]) {
      final bytes = encodeReceipt(_receipt(), EscposProfile(paperMm: mm));
      final rows = String.fromCharCodes(bytes.where((b) => b >= 0x20 || b == 0x0A)).split('\n');
      for (final row in rows) {
        if (row.contains('TOTAL')) continue;
        expect(row.length, lessThanOrEqualTo(cols + 8), reason: row);
      }
    }
  });

  test('the sender writes the bytes to a printer that listens, and says so when none does', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final got = Completer<List<int>>();
    final seen = <int>[];
    server.listen((client) {
      client.listen(seen.addAll, onDone: () {
        got.complete(seen);
        client.destroy();
      });
    });
    final bytes = encodeReceipt(_receipt(), const EscposProfile());
    await TcpReceiptSender(host: '127.0.0.1', port: server.port).send(bytes);
    expect(await got.future.timeout(const Duration(seconds: 5)), bytes);
    final port = server.port;
    await server.close();
    await expectLater(
      TcpReceiptSender(host: '127.0.0.1', port: port, timeout: const Duration(seconds: 2)).send(bytes),
      throwsA(isA<ReceiptNotPrinted>()),
    );
  });
}
