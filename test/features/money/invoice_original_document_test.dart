// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3853 — the document of an issued invoice is its stored original. Two
// people using the app in two languages, a second apart, render the same
// bytes; once stored, those bytes are what everyone receives, whatever
// changed in the business since. What is not the original says why: an
// invoice issued before originals were kept, stored bytes that do not match
// their digest, a reader who may not issue invoices before anyone who may
// has opened it, and a PDF larger than the store keeps.
import 'dart:async';
import 'dart:typed_data';

import 'package:deskilo/core/demo/data/money/demo_invoice_original_repository.dart';
import 'package:deskilo/features/money/application/invoice_originals.dart';
import 'package:deskilo/features/money/domain/invoice_original.dart';
import 'package:deskilo/features/money/presentation/document_policies.dart';
import 'package:deskilo/features/money/presentation/invoice_original_document.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/real_async.dart';
import '../../helpers/test_workspace_context.dart';

/// A Belgian business whose own document language is German, named [name].
FakeWorkspaceRepository _business({String name = 'COWORKONTI'}) {
  final repo = FakeWorkspaceRepository.withWorkspace();
  repo.workspaces[0] = repo.workspaces[0].copyWith(
    countryCode: 'BE',
    defaultLocale: 'de',
    name: name,
  );
  return repo;
}

/// An invoice of that business issued after originals are kept, frozen in
/// French; [keeps] false makes it one issued before.
Future<(FakeMoneyRepository, Invoice)> _issued({bool keeps = true}) async {
  final money = FakeMoneyRepository();
  await money.createInvoice(
    workspaceId: 'ws-1',
    memberId: 'member-1',
    period: '2026-11',
  );
  final invoice = money.invoices.single.copyWith(
    documentLanguage: 'fr',
    formatLocale: 'fr_BE',
    keepsOriginal: keeps,
  );
  return (money, invoice);
}

DemoInvoiceOriginalRepository _store() => DemoInvoiceOriginalRepository(
  storedBy: () => 'user-1',
  now: () => DateTime.utc(2026, 12),
);

/// The store [inner] answering with altered bytes.
class _Tampered implements InvoiceOriginalRepository {
  _Tampered(this.inner);
  final InvoiceOriginalRepository inner;
  @override
  Future<InvoiceOriginal?> originalOf(String ws, String id) =>
      inner.originalOf(ws, id);
  @override
  Future<Set<String>> keptIn(String ws) => inner.keptIn(ws);
  @override
  Future<Uint8List> pdfOf(InvoiceOriginal o) async =>
      Uint8List.fromList([...await inner.pdfOf(o), 32]);
  @override
  Future<String> xmlOf(String ws, InvoiceOriginal o) async =>
      '${await inner.xmlOf(ws, o)} ';
  @override
  Future<InvoiceOriginal> store({
    required String workspaceId,
    required String invoiceId,
    required Uint8List pdf,
    required String xml,
  }) => inner.store(
    workspaceId: workspaceId,
    invoiceId: invoiceId,
    pdf: pdf,
    xml: xml,
  );
}

/// A store that keeps no PDF this large.
class _TooLarge extends DemoInvoiceOriginalRepository {
  _TooLarge() : super(storedBy: () => null, now: () => DateTime.utc(2026));
  @override
  Future<InvoiceOriginal> store({
    required String workspaceId,
    required String invoiceId,
    required Uint8List pdf,
    required String xml,
  }) async =>
      throw const InvoiceOriginalRefused(InvoiceOriginalRefusal.tooLarge);
}

/// A store where someone else stored first, whose bytes are not those it
/// recorded.
class _FirstElsewhere extends DemoInvoiceOriginalRepository {
  _FirstElsewhere()
    : super(storedBy: () => null, now: () => DateTime.utc(2026));
  @override
  Future<InvoiceOriginal> store({
    required String workspaceId,
    required String invoiceId,
    required Uint8List pdf,
    required String xml,
  }) async => InvoiceOriginal(
    invoiceId: invoiceId,
    path: 'elsewhere',
    pdfBytes: 1,
    pdfSha256: pdfSha256OfBytes(const [1]),
    xmlSha256: '',
  );
  @override
  Future<Uint8List> pdfOf(InvoiceOriginal original) async =>
      Uint8List.fromList(const [2]);
}

/// A store whose server refuses the structured part.
class _Refused extends DemoInvoiceOriginalRepository {
  _Refused() : super(storedBy: () => null, now: () => DateTime.utc(2026));
  @override
  Future<InvoiceOriginal> store({
    required String workspaceId,
    required String invoiceId,
    required Uint8List pdf,
    required String xml,
  }) async => throw const InvoiceOriginalRefused(
    InvoiceOriginalRefusal.refused,
    'the structured part does not name this invoice\'s amount due',
  );
}

/// A store that refuses the structured part, once [gate] is opened.
class _RefusedWhenOpened extends _Refused {
  final gate = Completer<void>();
  @override
  Future<InvoiceOriginal> store({
    required String workspaceId,
    required String invoiceId,
    required Uint8List pdf,
    required String xml,
  }) async {
    await gate.future;
    return super.store(
      workspaceId: workspaceId,
      invoiceId: invoiceId,
      pdf: pdf,
      xml: xml,
    );
  }
}

/// The document of [invoice], as a person using the app in [locale] opens it.
Future<InvoiceDocument> _open(
  WidgetTester tester, {
  required Invoice invoice,
  required FakeMoneyRepository money,
  required InvoiceOriginalRepository store,
  Locale locale = const Locale('it'),
  FakeWorkspaceRepository? workspace,
  bool mayIssue = true,
}) async {
  InvoiceDocument? document;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          money: money,
          workspace: workspace ?? _business(),
          invoiceOriginals: store,
        ),
        testReadyWorkspaceContext(),
        currentWorkspaceProvider.overrideWith(
          (ref) async => (workspace ?? _business()).workspaces.single,
        ),
        myPermissionsProvider.overrideWithValue({
          if (mayIssue) WorkspacePermission.issueInvoices,
        }),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              key: const ValueKey('go'),
              onPressed: () async {
                await readDocumentPolicies(ref);
                if (!context.mounted) return;
                document = await InvoiceDocumentFlow(
                  context,
                  ref,
                ).documentOf(invoice);
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.runAsync(() async {
    await tester.tap(find.byKey(const ValueKey('go')));
    await untilReal(() => document != null, what: 'the invoice document');
  });
  return document!;
}

void main() {
  testWidgets('two people in two languages, a second apart, render the same '
      'original', (tester) async {
    final (money, invoice) = await _issued();
    final first = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: _store(),
    );
    final waited = Stopwatch()..start();
    await tester.runAsync(
      () => untilReal(
        () => waited.elapsedMilliseconds > 1000,
        what: 'a second to pass',
      ),
    );
    final second = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: _store(),
      locale: const Locale('de'),
    );
    expect(first.source, InvoiceDocumentSource.original);
    expect(second.source, InvoiceDocumentSource.original);
    expect(second.bytes, first.bytes);
  });

  testWidgets('once stored, it is what everyone receives, whatever changed '
      'in the business since', (tester) async {
    final (money, invoice) = await _issued();
    final store = _store();
    final stored = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: store,
    );
    expect(
      (await store.originalOf(
        invoice.workspaceId,
        invoice.id,
      ))!.holds(stored.bytes),
      isTrue,
    );
    final later = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: store,
      locale: const Locale('de'),
      workspace: _business(name: 'COWORKONTI RENAMED'),
      mayIssue: false,
    );
    expect(later.source, InvoiceDocumentSource.original);
    expect(later.bytes, stored.bytes);
  });

  testWidgets('an invoice issued before originals were kept is a copy, and '
      'none is stored', (tester) async {
    final (money, invoice) = await _issued(keeps: false);
    final store = _store();
    final document = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: store,
    );
    expect(document.source, InvoiceDocumentSource.notKept);
    expect(document.bytes, isNotEmpty);
    expect(await store.originalOf(invoice.workspaceId, invoice.id), isNull);
  });

  testWidgets('stored bytes that do not match their digest give a copy', (
    tester,
  ) async {
    final (money, invoice) = await _issued();
    final store = _store();
    await _open(tester, invoice: invoice, money: money, store: store);
    final document = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: _Tampered(store),
    );
    expect(document.source, InvoiceDocumentSource.mismatch);
  });

  testWidgets('a reader who may not issue invoices, before anyone who may '
      'opened it, gets a copy and stores none', (tester) async {
    final (money, invoice) = await _issued();
    final store = _store();
    final document = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: store,
      mayIssue: false,
    );
    expect(document.source, InvoiceDocumentSource.notYetKept);
    expect(await store.originalOf(invoice.workspaceId, invoice.id), isNull);
  });

  testWidgets('a member who reads first gets the copy that says the business '
      'has not kept the original yet; after the issuer\'s flow, the original', (
    tester,
  ) async {
    final (money, invoice) = await _issued();
    money.invoices[0] = invoice;
    final store = _store();
    final before = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: store,
      mayIssue: false,
    );
    expect(before.source, InvoiceDocumentSource.notYetKept);
    // the issuer's flow right after issue, without a tap
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(
            money: money,
            workspace: _business(),
            invoiceOriginals: store,
          ),
          testReadyWorkspaceContext(),
          currentWorkspaceProvider.overrideWith(
            (ref) async => _business().workspaces.single,
          ),
          myPermissionsProvider.overrideWithValue({
            WorkspacePermission.issueInvoices,
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                key: const ValueKey('keep'),
                onPressed: () =>
                    InvoiceDocumentFlow(context, ref).keep([invoice.id]),
                child: const Text('keep'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('keep')));
      await untilReal(
        () => store
            .originalOf(invoice.workspaceId, invoice.id)
            .then((o) => o != null),
        what: 'the original kept by the issuer\'s flow',
      );
    });
    final after = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: store,
      mayIssue: false,
    );
    expect(after.source, InvoiceDocumentSource.original);
  });

  testWidgets('an original someone else stored first is checked by its '
      'digest too', (tester) async {
    final (money, invoice) = await _issued();
    final document = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: _FirstElsewhere(),
    );
    expect(document.source, InvoiceDocumentSource.mismatch);
  });

  testWidgets('the run the person asked for shows its progress, which Back '
      'does not close; it closes it itself, leaves the page under it and '
      'says what could not be kept', (tester) async {
    final (money, invoice) = await _issued();
    money.invoices[0] = invoice;
    final store = _RefusedWhenOpened();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(
            money: money,
            workspace: _business(),
            invoiceOriginals: store,
          ),
          testReadyWorkspaceContext(),
          currentWorkspaceProvider.overrideWith(
            (ref) async => _business().workspaces.single,
          ),
          myPermissionsProvider.overrideWithValue({
            WorkspacePermission.issueInvoices,
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                key: const ValueKey('keep'),
                onPressed: () => InvoiceDocumentFlow(
                  context,
                  ref,
                ).keep([invoice.id], askedFor: true),
                child: const Text('keep'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final progress = find.byKey(const ValueKey('invoice-originals-keeping'));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('keep')));
      await untilReal(() async {
        await tester.pump();
        return progress.evaluate().isNotEmpty;
      }, what: 'the progress of the run');
      // Back does not close it while the run goes on.
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(progress, findsOneWidget);
      store.gate.complete();
      await untilReal(() async {
        await tester.pump();
        return progress.evaluate().isEmpty;
      }, what: 'the run closing its progress');
    });
    await tester.pump();
    expect(find.byKey(const ValueKey('keep')), findsOneWidget);
    expect(find.text(l10n.invoiceOriginalsCouldNotKeep(1)), findsOneWidget);
  });

  testWidgets('a refusal that is not about size says it could not be kept, '
      'in the server\'s words', (tester) async {
    final (money, invoice) = await _issued();
    final document = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: _Refused(),
    );
    expect(document.source, InvoiceDocumentSource.refused);
    expect(document.why, contains('amount due'));
  });

  testWidgets('the Factur-X that leaves is the stored original, the same '
      'bytes as the download', (tester) async {
    final (money, invoice) = await _issued();
    final store = _store();
    final stored = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: store,
    );
    ({List<int> bytes, String fileName})? leaving;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...standardTestOverrides(
            money: money,
            workspace: _business(),
            invoiceOriginals: store,
          ),
          testReadyWorkspaceContext(),
          currentWorkspaceProvider.overrideWith(
            (ref) async => _business().workspaces.single,
          ),
          myPermissionsProvider.overrideWithValue({
            WorkspacePermission.issueInvoices,
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                key: const ValueKey('leave'),
                onPressed: () async {
                  await readDocumentPolicies(ref);
                  if (!context.mounted) return;
                  leaving = await InvoiceDocumentFlow(
                    context,
                    ref,
                  ).facturXOriginal(invoice);
                },
                child: const Text('leave'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('leave')));
      await untilReal(() => leaving != null, what: 'the Factur-X that leaves');
    });
    expect(leaving!.bytes, stored.bytes);
  });

  testWidgets('a PDF larger than the store keeps gives a copy that says so', (
    tester,
  ) async {
    final (money, invoice) = await _issued();
    final document = await _open(
      tester,
      invoice: invoice,
      money: money,
      store: _TooLarge(),
    );
    expect(document.source, InvoiceDocumentSource.tooLarge);
  });
}
