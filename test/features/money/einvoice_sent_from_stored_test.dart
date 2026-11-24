// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4120 -- a sending uses what the invoice stored; an older invoice names the
// values that are today's and is sent only once the person confirms; what left
// is downloaded again exactly as stored, and a stored copy that no longer
// matches is said not intact, never handed out.
import 'dart:convert';
import 'dart:typed_data';

import 'package:deskilo/core/codes/dk_code.dart';
import 'package:deskilo/core/files/file_saver.dart';
import 'package:deskilo/features/money/domain/einvoice_transmissions.dart';
import 'package:deskilo/features/money/presentation/widgets/einvoice_today_values.dart';
import 'package:deskilo/features/money/presentation/widgets/sent_einvoice_download.dart';
import 'package:deskilo/features/money/providers/money_queries_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

class _Sent implements EInvoiceTransmissions {
  _Sent(this.answer);
  final Object answer;

  @override
  Future<SentEInvoiceDocument> fetchSentDocument(String invoiceId) async {
    final a = answer;
    if (a is PostgrestException) throw a;
    return a as SentEInvoiceDocument;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child, List<Override> overrides) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  test('the basis reads the account the invoice stored, or none', () {
    final stored = EInvoiceSendBasis.fromAnswer({
      'payment': {'iban': 'FR7630006000011234567890189'},
      'payment_today': false,
      'reference_today': false,
    });
    expect(stored.iban, 'FR7630006000011234567890189');
    expect(stored.anyToday, isFalse);
    final older = EInvoiceSendBasis.fromAnswer({
      'payment': null,
      'payment_today': true,
      'reference_today': true,
    });
    expect(older.iban, isNull, reason: 'none stored: today\'s is used');
    expect(older.accountOr('DE89370400440532013000'), 'DE89370400440532013000');
    expect(older.paymentToday && older.referenceToday, isTrue);
  });

  test('an invoice issued without an account is sent without one, and names nothing as today\'s', () {
    // Issued while the business had no account; one was added since.
    final basis = EInvoiceSendBasis.fromAnswer({
      'payment': <String, Object?>{},
      'payment_today': false,
      'reference_today': false,
    });
    expect(
      basis.accountOr('DE89370400440532013000'),
      isEmpty,
      reason: 'the stored block is the invoice\'s own, even empty',
    );
    expect(basis.anyToday, isFalse, reason: 'no "today\'s value" is named');
  });

  testWidgets(
    'an older invoice names its today\'s values and is sent only once confirmed',
    (tester) async {
      bool? confirmed;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => confirmed = await confirmTodayValues(
                context,
                const EInvoiceSendBasis(
                  paymentToday: true,
                  referenceToday: true,
                ),
              ),
              child: const Text('send'),
            ),
          ),
          const [],
        ),
      );
      await tester.tap(find.text('send'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("the business's bank account"),
        findsOneWidget,
      );
      expect(find.textContaining('the tax reference'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('einvoice-today-values-send')),
      );
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    },
  );

  testWidgets('an invoice whose values are its own is sent without asking', (
    tester,
  ) async {
    bool? confirmed;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => confirmed = await confirmTodayValues(
              context,
              EInvoiceSendBasis.sameAsToday,
            ),
            child: const Text('send'),
          ),
        ),
        const [],
      ),
    );
    await tester.tap(find.text('send'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('einvoice-today-values')), findsNothing);
    expect(confirmed, isTrue);
  });

  testWidgets('what left is saved exactly as stored', (tester) async {
    final saved = <({String name, List<int> bytes})>[];
    final bytes = Uint8List.fromList(utf8.encode('<Invoice>sent</Invoice>'));
    await tester.pumpWidget(
      _app(const SentEInvoiceDownload(invoiceId: 'inv-1'), [
        eInvoiceTransmissionsProvider.overrideWithValue(
          _Sent(
            SentEInvoiceDocument(
              fileName: 'peppolBis.xml',
              mimeType: 'application/xml',
              bytes: bytes,
              sha256: 'h',
            ),
          ),
        ),
        fileDeliveryModeProvider.overrideWithValue(FileDeliveryMode.direct),
        typedFileSaverProvider.overrideWithValue(({
          required bytes,
          required fileName,
        }) async {
          saved.add((name: fileName, bytes: bytes));
          return SavedFile('/local/$fileName');
        }),
      ]),
    );
    await tester.tap(
      find.byKey(const ValueKey('invoice-detail-sent-download')),
    );
    await tester.pumpAndSettle();
    expect(saved.single.name, 'peppolBis.xml');
    expect(saved.single.bytes, bytes);
  });

  testWidgets('a stored copy that no longer matches is said not intact', (
    tester,
  ) async {
    final saved = <String>[];
    await tester.pumpWidget(
      _app(const SentEInvoiceDownload(invoiceId: 'inv-1'), [
        eInvoiceTransmissionsProvider.overrideWithValue(
          _Sent(const PostgrestException(message: 'not intact', code: DkCode.dki09)),
        ),
        fileDeliveryModeProvider.overrideWithValue(FileDeliveryMode.direct),
        typedFileSaverProvider.overrideWithValue(({
          required bytes,
          required fileName,
        }) async {
          saved.add(fileName);
          return SavedFile('/local/$fileName');
        }),
      ]),
    );
    await tester.tap(
      find.byKey(const ValueKey('invoice-detail-sent-download')),
    );
    await tester.pumpAndSettle();
    expect(saved, isEmpty);
    expect(find.textContaining('is not intact'), findsOneWidget);
  });
}
