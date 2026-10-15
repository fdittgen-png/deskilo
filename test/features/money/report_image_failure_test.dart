// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2586 — invariant: a missing optional report image is null and only that;
// a denied, failed or invalid read is a typed failure, never null, and a
// final export refuses to complete over it while a preview omits the image.
import 'dart:typed_data';

import 'package:deskilo/features/money/data/report_image_read.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_image_failure.dart';
import 'package:deskilo/features/money/presentation/invoice_documents.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show StorageException;

import '../../helpers/real_async.dart';

final _png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 1, 2, 3]);
final _jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 1]);
final _webp = Uint8List.fromList(
  [0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50],
);
const _noWait = <Duration>[];

Matcher failure(ReportImageFailureKind kind) => throwsA(
    isA<ReportImageFailure>().having((e) => e.kind, 'kind', kind));

void main() {
  group('readReportImage', () {
    test('valid bytes load (png, jpeg, webp)', () async {
      for (final bytes in [_png, _jpeg, _webp]) {
        expect(await readReportImage('a', () async => bytes, delays: _noWait), bytes);
      }
    });

    test('the Storage not-found answer is null, the one absent case', () async {
      expect(
        await readReportImage('a',
            () async => throw const StorageException('Object not found', statusCode: '404', error: 'not_found'),
            delays: _noWait),
        isNull,
      );
      expect(
        await readReportImage('a',
            () async => throw const StorageException('gone', statusCode: '400', error: 'not_found'),
            delays: _noWait),
        isNull,
      );
    });

    test('401 and 403 are forbidden, not null', () async {
      for (final code in ['401', '403']) {
        await expectLater(
          readReportImage('a',
              () async => throw StorageException('denied', statusCode: code),
              delays: _noWait),
          failure(ReportImageFailureKind.forbidden),
        );
      }
    });

    test('a 500, a missing status and a transport failure are unavailable', () async {
      await expectLater(
        readReportImage('a',
            () async => throw const StorageException('boom', statusCode: '500'),
            delays: _noWait),
        failure(ReportImageFailureKind.unavailable),
      );
      await expectLater(
        readReportImage('a', () async => throw const StorageException('weird'),
            delays: _noWait),
        failure(ReportImageFailureKind.unavailable),
      );
      await expectLater(
        readReportImage('a', () async => throw Exception('SocketException: x'),
            delays: _noWait),
        failure(ReportImageFailureKind.unavailable),
      );
    });

    test('only the failed read is retried, then it succeeds', () async {
      var calls = 0;
      final bytes = await readReportImage('a', () async {
        calls++;
        if (calls == 1) throw Exception('SocketException: reset');
        return _png;
      }, delays: const [Duration(milliseconds: 1)]);
      expect(bytes, _png);
      expect(calls, 2);
    });

    test('a refusal is not retried', () async {
      var calls = 0;
      await expectLater(
        readReportImage('a', () async {
          calls++;
          throw const StorageException('denied', statusCode: '403');
        }, delays: const [Duration(milliseconds: 1), Duration(milliseconds: 1)]),
        failure(ReportImageFailureKind.forbidden),
      );
      expect(calls, 1);
    });

    test('bytes that are no image are invalid, not an image', () async {
      for (final bytes in [Uint8List(0), Uint8List.fromList([1, 2, 3, 4])]) {
        await expectLater(
          readReportImage('a', () async => bytes, delays: _noWait),
          failure(ReportImageFailureKind.invalid),
        );
      }
    });
  });

  group('resolveReportImages', () {
    const report = InvoiceReport(
      header: [ReportImage('logo'), ReportImage('stamp')],
      body: [],
      footer: [],
    );

    Future<Object?> run(
      WidgetTester tester, {
      required bool strict,
      required Future<Uint8List?> Function(String) read,
    }) async {
      Object? outcome;
      await tester.pumpWidget(ProviderScope(
        retry: (_, _) => null,
        overrides: [
          reportImageBytesProvider('logo').overrideWith((ref) => read('logo')),
          reportImageBytesProvider('stamp').overrideWith((ref) => read('stamp')),
        ],
        child: MaterialApp(home: Consumer(builder: (context, ref, _) {
          return TextButton(
            onPressed: () async {
              try {
                outcome = await resolveReportImages(ref, report, strict: strict);
              } on Object catch (e) {
                outcome = e;
              }
            },
            child: const Text('go'),
          );
        })),
      ));
      await tester.runAsync(() async {
        await tester.tap(find.text('go'));
        await untilReal(() => outcome != null, what: 'the image resolution');
      });
      return outcome;
    }

    testWidgets('an absent optional image is omitted, even in a final export',
        (tester) async {
      final out = await run(tester,
          strict: true, read: (n) async => n == 'logo' ? _png : null);
            expect((out! as Map).keys, ['logo']);
    });

    testWidgets('a denied image fails a final export, naming it', (tester) async {
      final out = await run(tester, strict: true, read: (n) async {
        if (n == 'stamp') {
          throw const ReportImageFailure(ReportImageFailureKind.forbidden, 'stamp');
        }
        return _png;
      });
      expect(out, isA<ReportImageFailure>());
      expect((out! as ReportImageFailure).name, 'stamp');
      expect((out as ReportImageFailure).kind, ReportImageFailureKind.forbidden);
    });

    testWidgets('a preview leaves the failed image out and still renders',
        (tester) async {
      final out = await run(tester, strict: false, read: (n) async {
        if (n == 'stamp') {
          throw const ReportImageFailure(ReportImageFailureKind.unavailable, 'stamp');
        }
        return _png;
      });
      expect((out! as Map).keys, ['logo']);
    });
  });
}
