// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2863 — the supplier form saves while it is open: Save cannot be pressed
// twice, a refusal keeps every value for another try, and the success
// notice leads back to the saved supplier. A supplier already carrying the
// typed identifier is named before any attempt (the server refuses the
// same duplicate); a supplier with the same name is a caution that never
// blocks. The lookup's other failures (rejected format, a country no
// registry answers, a timeout) each say what happened and keep the input,
// and the lookup is waited for the server's own setting plus the round
// trip.
import 'dart:async';

import 'package:deskilo/core/demo/data/company_lookup_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/core/settings/active_settings.dart';
import 'package:deskilo/core/settings/settings.dart';
import 'package:deskilo/features/money/application/lookup_company.dart';
import 'package:deskilo/features/money/domain/company_lookup.dart';
import 'package:deskilo/features/money/domain/supplier.dart';
import 'package:deskilo/features/money/domain/supplier_prefill.dart';
import 'package:deskilo/features/money/presentation/widgets/suppliers_sheet.dart';
import 'package:deskilo/features/money/providers/company_lookup_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

const _add = ValueKey('supplier-add');
const _findDetails = ValueKey('supplier-find-details');
const _identifier = ValueKey('supplier-lookup-identifier');
const _find = ValueKey('supplier-lookup-find');
const _problem = ValueKey('supplier-lookup-problem');
const _save = ValueKey('supplier-save');
const _saveProblem = ValueKey('supplier-save-problem');
const _similar = ValueKey('supplier-similar-name');
const _progress = ValueKey('supplier-save-progress');

/// Suppliers whose save can be held open or refused.
class _Suppliers extends FakeSupplierRepository {
  Completer<void>? gate;
  StateError? refuse;
  int saves = 0;

  @override
  Future<String> save(String workspaceId, SupplierDraft draft) async {
    saves++;
    final open = gate;
    if (open != null) await open.future;
    final refusal = refuse;
    if (refusal != null) throw refusal;
    return super.save(workspaceId, draft);
  }
}

class _World {
  final suppliers = _Suppliers();
  final lookups = FakeCompanyLookupRepository();
  SettingsSet? settings;

  List<Override> get overrides => [
    supplierRepositoryProvider.overrideWithValue(suppliers),
    companyLookupRepositoryProvider.overrideWithValue(lookups),
    activeSettingsProvider.overrideWithValue(settings),
  ];

  Widget app({Locale? locale}) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SingleChildScrollView(
          child: SuppliersView(workspaceId: 'ws', lookupOn: true),
        ),
      ),
    ),
  );
}

/// Dialogs open and close through a short route animation.
Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle();

Future<void> _openForm(WidgetTester tester, _World world) async {
  await tester.pumpWidget(world.app());
  await _settle(tester);
  await tester.tap(find.byKey(_add));
  await _settle(tester);
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  await tester.enterText(find.byKey(ValueKey('supplier-$key')), text);
  await tester.pump();
}

String _fieldText(WidgetTester tester, String key) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(ValueKey('supplier-$key')),
        matching: find.byType(TextField),
      ),
    )
    .controller!
    .text;

/// The registry rows of the lookup's wait, as `my_settings` answers them.
SettingsSet _settingsWithWait(int seconds) => SettingsSet.parse([
  {
    'key': 'purchase.supplier_lookup_timeout_seconds',
    'type': 'duration',
    'default_value': 15,
    'min': 3,
    'max': 30,
    'unit': 'seconds',
    'group_key': 'billing',
    'scopes': ['platform'],
    'value': seconds,
    'origin': 'platform',
  },
]);

void main() {
  testWidgets(
    'Save runs in the open form: progress, no second press, a refusal keeps '
    'every value, and the retry saves once',
    (tester) async {
      final world = _World();
      await _openForm(tester, world);
      await _type(tester, 'name', 'Papeterie du Lez');
      await _type(tester, 'tax-id', 'FR 40 123 456 789');
      await _type(tester, 'city', 'Montpellier');

      world.suppliers
        ..gate = Completer<void>()
        ..refuse = StateError('connection dropped');
      await tester.tap(find.byKey(_save));
      await tester.pump();
      expect(find.byKey(_progress), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byKey(_save)).onPressed,
        isNull,
        reason: 'a second press cannot send a second save',
      );
      await tester.tap(find.byKey(_save), warnIfMissed: false);
      await tester.pump();
      world.suppliers.gate!.complete();
      await _settle(tester);
      expect(world.suppliers.saves, 1);
      expect(find.byKey(_saveProblem), findsOneWidget);
      expect(find.textContaining('could not be saved'), findsOneWidget);
      expect(_fieldText(tester, 'name'), 'Papeterie du Lez');
      expect(_fieldText(tester, 'tax-id'), 'FR 40 123 456 789');
      expect(_fieldText(tester, 'city'), 'Montpellier');
      expect(world.suppliers.suppliers, isEmpty);

      world.suppliers
        ..gate = null
        ..refuse = null;
      await tester.tap(find.byKey(_save));
      await _settle(tester);
      expect(world.suppliers.saves, 2);
      expect(world.suppliers.suppliers.single.name, 'Papeterie du Lez');
      expect(find.byKey(_save), findsNothing, reason: 'the form closed');
      expect(find.text('Supplier saved.'), findsOneWidget);
    },
  );

  testWidgets('the success notice leads back to the saved supplier', (
    tester,
  ) async {
    final world = _World();
    await _openForm(tester, world);
    await _type(tester, 'name', 'Papeterie du Lez');
    await tester.tap(find.byKey(_save));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('supplier-saved-open')));
    await _settle(tester);
    expect(find.text('Edit supplier'), findsOneWidget);
    expect(_fieldText(tester, 'name'), 'Papeterie du Lez');
  });

  testWidgets(
    'a typed identifier a supplier already carries is named on Save and '
    'offers that supplier; nothing is sent',
    (tester) async {
      final world = _World();
      await world.suppliers.save(
        'ws',
        const SupplierDraft(name: 'ACME', taxId: 'FR12345678901'),
      );
      world.suppliers.saves = 0;
      await _openForm(tester, world);
      await _type(tester, 'name', 'Acme Montpellier');
      await _type(tester, 'tax-id', '12 345 678 901');
      await _type(tester, 'country', 'FR');
      await tester.tap(find.byKey(_save));
      await _settle(tester);
      expect(world.suppliers.saves, 0);
      expect(find.textContaining('already exists: 1 · ACME'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(_saveProblem),
          matching: find.text('Open existing supplier'),
        ),
      );
      await _settle(tester);
      expect(find.text('Edit supplier'), findsOneWidget);
      expect(_fieldText(tester, 'name'), 'ACME');
      expect(world.suppliers.suppliers, hasLength(1));
    },
  );

  testWidgets(
    'a supplier with the same name is a caution that never blocks: Save '
    'still creates the new one',
    (tester) async {
      final world = _World();
      await world.suppliers.save(
        'ws',
        const SupplierDraft(
          name: 'Atelier des Arceaux',
          taxId: 'FR11111111111',
        ),
      );
      await _openForm(tester, world);
      await _type(tester, 'name', 'ATELIER  des arceaux');
      expect(find.byKey(_similar), findsOneWidget);
      expect(
        find.textContaining('same name exists: 1 · Atelier des Arceaux'),
        findsOneWidget,
      );
      await _type(tester, 'name', 'Atelier du Lez');
      expect(find.byKey(_similar), findsNothing);
      await _type(tester, 'name', 'Atelier des Arceaux');
      await _type(tester, 'tax-id', 'FR22222222222');
      await tester.tap(find.byKey(_save));
      await _settle(tester);
      expect(world.suppliers.suppliers, hasLength(2));
    },
  );

  testWidgets('an empty name is said under its field and nothing is sent', (
    tester,
  ) async {
    final world = _World();
    await _openForm(tester, world);
    await tester.tap(find.byKey(_save));
    await tester.pump();
    expect(find.text('A supplier needs a name.'), findsOneWidget);
    expect(world.suppliers.saves, 0);
    await _type(tester, 'name', 'Papeterie');
    expect(find.text('A supplier needs a name.'), findsNothing);
  });

  testWidgets(
    'a rejected format, a country no registry answers and a timeout each '
    'say what happened and keep the input',
    (tester) async {
      final world = _World();
      world.lookups.answers
        ..['FR00000000000'] = CompanyLookupResult.failure(
          viesProviderId,
          LookupRetrieval.invalidInput,
        )
        ..['FR22222222222'] = CompanyLookupResult.failure(
          viesProviderId,
          LookupRetrieval.timeout,
        );
      await _openForm(tester, world);
      await tester.tap(find.byKey(_findDetails));
      await _settle(tester);
      Future<void> ask(String typed) async {
        await tester.enterText(find.byKey(_identifier), typed);
        await tester.tap(find.byKey(_find));
        await _settle(tester);
      }

      await ask('FR00000000000');
      expect(find.textContaining('rejected the format'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);

      await ask('US123456789');
      expect(find.byKey(_problem), findsOneWidget);
      expect(find.textContaining('No registry answers for'), findsOneWidget);
      expect(
        world.lookups.requests,
        hasLength(1),
        reason: 'an unsupported country is answered without a call',
      );

      await ask('FR22222222222');
      expect(find.textContaining('did not answer in time'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Continue manually'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(_identifier),
                matching: find.byType(TextField),
              ),
            )
            .controller!
            .text,
        'FR22222222222',
      );
      expect(world.suppliers.suppliers, isEmpty);
    },
  );

  testWidgets('the lookup is waited for the server setting plus the round '
      'trip', (tester) async {
    final world = _World()..settings = _settingsWithWait(7);
    await _openForm(tester, world);
    await tester.tap(find.byKey(_findDetails));
    await _settle(tester);
    await tester.enterText(find.byKey(_identifier), 'FR11223344556');
    await tester.tap(find.byKey(_find));
    await _settle(tester);
    expect(world.lookups.waits, [const Duration(seconds: 17)]);
  });

  test('without the settings, or on an older server, the registry default '
      'stands', () {
    expect(supplierLookupWait(null), const Duration(seconds: 25));
    expect(
      supplierLookupWait(SettingsSet.defaults(const [])),
      const Duration(seconds: 25),
    );
    expect(supplierLookupWait(_settingsWithWait(30)).inSeconds, 40);
  });

  test('a draft duplicates by its normalised identifier, never by its name, '
      'never itself, never as a VAT group', () {
    const acme = Supplier(
      id: 's1',
      number: '1',
      name: 'ACME',
      taxIdEntered: 'FR12345678901',
      taxIdentifier: 'FR12345678901',
    );
    expect(
      supplierDuplicateOf(
        [acme],
        const SupplierDraft(
          name: 'x',
          taxId: '12.345.678.901',
          countryCode: 'fr',
        ),
      )?.id,
      's1',
    );
    expect(
      supplierDuplicateOf([acme], const SupplierDraft(name: 'ACME')),
      isNull,
    );
    expect(
      supplierDuplicateOf([
        acme,
      ], const SupplierDraft(id: 's1', name: 'ACME', taxId: 'FR12345678901')),
      isNull,
    );
    expect(
      supplierDuplicateOf(
        [acme],
        const SupplierDraft(
          name: 'x',
          taxId: 'FR12345678901',
          taxIdKind: SupplierIdKind.vatGroup,
        ),
      ),
      isNull,
    );
    expect(
      supplierWithSimilarName([acme], const SupplierDraft(name: ' a.c.m.e ')),
      acme,
    );
    expect(
      supplierWithSimilarName([
        acme,
      ], const SupplierDraft(id: 's1', name: 'ACME')),
      isNull,
    );
    expect(
      supplierWithSimilarName([acme], const SupplierDraft(name: 'ACME Sud')),
      isNull,
    );
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('the save step speaks ${locale.languageCode}', (tester) async {
      final world = _World();
      await world.suppliers.save(
        'ws',
        const SupplierDraft(name: 'ACME', taxId: 'FR12345678901'),
      );
      await tester.pumpWidget(world.app(locale: locale));
      await _settle(tester);
      await tester.tap(find.byKey(_add));
      await _settle(tester);
      final l10n = lookupAppLocalizations(locale);
      await _type(tester, 'name', 'acme');
      expect(find.text(l10n.supplierSimilarName('1 · ACME')), findsOneWidget);
      await _type(tester, 'name', '');
      await tester.tap(find.byKey(_save));
      await tester.pump();
      expect(find.text(l10n.supplierNameMissing), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
