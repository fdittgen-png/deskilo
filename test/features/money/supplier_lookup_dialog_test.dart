// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2863 — the supplier form's guided lookup: the import path and the
// manual path are both there when the flag is on; a retrieved answer is
// reviewed with each field's provenance and saved with the retrieved
// fields (a save that never looked up would have no name to save); a
// verdict or an outage keeps what was typed and offers the next step; a
// supplier already carrying the identifier opens instead of a second one;
// one column at phone width; the keyboard submits; the verdicts are text.
import 'package:deskilo/core/demo/data/company_lookup_repository.dart';
import 'package:deskilo/core/demo/data/supplier_repository.dart';
import 'package:deskilo/features/money/domain/company_lookup.dart';
import 'package:deskilo/features/money/domain/supplier.dart';
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
const _country = ValueKey('supplier-lookup-country');
const _find = ValueKey('supplier-lookup-find');
const _manual = ValueKey('supplier-lookup-manual');
const _problem = ValueKey('supplier-lookup-problem');
const _openExisting = ValueKey('supplier-lookup-open-existing');
const _status = ValueKey('supplier-review-status');
const _save = ValueKey('supplier-save');

class _World {
  _World({this.lookupOn = true})
    : suppliers = FakeSupplierRepository(),
      lookups = FakeCompanyLookupRepository();

  final FakeSupplierRepository suppliers;
  final FakeCompanyLookupRepository lookups;
  final bool lookupOn;

  List<Override> get overrides => [
    supplierRepositoryProvider.overrideWithValue(suppliers),
    companyLookupRepositoryProvider.overrideWithValue(lookups),
  ];

  Widget app({Locale? locale}) => ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: SuppliersView(workspaceId: 'ws', lookupOn: lookupOn),
        ),
      ),
    ),
  );
}

/// Dialogs open and close through a short route animation.
Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle();

/// From the sheet to the lookup dialog, through the form's Find button.
Future<void> _openLookup(WidgetTester tester) async {
  await tester.tap(find.byKey(_add));
  await _settle(tester);
  await tester.tap(find.byKey(_findDetails));
  await _settle(tester);
}

Future<void> _lookUp(WidgetTester tester, String typed) async {
  await tester.enterText(find.byKey(_identifier), typed);
  await tester.tap(find.byKey(_find));
  await _settle(tester);
}

/// The platform field under a kit field.
TextField _textField(WidgetTester tester, Key key) => tester.widget<TextField>(
  find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
);

/// [key] is the form field's widget-key suffix (`name`, `tax-id`, …).
String _fieldText(WidgetTester tester, String key) =>
    _textField(tester, ValueKey('supplier-$key')).controller!.text;

String? _helperOf(WidgetTester tester, String key) =>
    _textField(tester, ValueKey('supplier-$key')).decoration?.helperText;

void main() {
  testWidgets(
    'the form offers the lookup beside the fields when the flag is on, '
    'the lookup offers the manual path, and the flag off hides it',
    (tester) async {
      final world = _World();
      await tester.pumpWidget(world.app(locale: const Locale('fr')));
      await _settle(tester);
      await tester.tap(find.byKey(_add));
      await _settle(tester);
      expect(find.byKey(_findDetails), findsOneWidget);
      expect(find.text('Rechercher la société'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('supplier-name')),
        findsOneWidget,
        reason: 'the fields are the manual path, visible at once',
      );
      await tester.tap(find.byKey(_findDetails));
      await _settle(tester);
      expect(find.byKey(_country), findsOneWidget);
      expect(find.byKey(_identifier), findsOneWidget);
      expect(find.byKey(_find), findsOneWidget);
      await tester.tap(find.byKey(_manual));
      await _settle(tester);
      expect(find.byKey(_identifier), findsNothing);
      expect(find.byKey(const ValueKey('supplier-name')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_World(lookupOn: false).app());
      await _settle(tester);
      await tester.tap(find.byKey(_add));
      await _settle(tester);
      expect(find.byKey(_findDetails), findsNothing);
      expect(find.byKey(const ValueKey('supplier-name')), findsOneWidget);
    },
  );

  testWidgets(
    'a retrieved answer is reviewed with its provenance, an edit is marked, '
    'and Save stores the retrieved fields',
    (tester) async {
      final world = _World();
      await tester.pumpWidget(world.app());
      await _settle(tester);
      await _openLookup(tester);
      await _lookUp(tester, 'FR 11 223 344 556');

      expect(find.byKey(_identifier), findsNothing, reason: 'back on the form');
      expect(find.text('VAT number validated'), findsOneWidget);
      expect(find.textContaining('Source: VIES'), findsOneWidget);
      expect(_fieldText(tester, 'name'), 'Atelier des Arceaux SAS');
      expect(_fieldText(tester, 'tax-id'), 'FR 11 223 344 556');
      expect(_fieldText(tester, 'country'), 'FR');
      expect(_helperOf(tester, 'name'), 'Retrieved from VIES');
      expect(_helperOf(tester, 'street'), 'Retrieved from VIES');
      expect(_helperOf(tester, 'tax-id'), 'Validated by VIES');
      expect(_helperOf(tester, 'contact'), isNull, reason: 'never looked up');

      await tester.enterText(
        find.byKey(const ValueKey('supplier-city')),
        'Sète',
      );
      await tester.pump();
      expect(_helperOf(tester, 'city'), 'Edited by you');
      expect(_helperOf(tester, 'postal'), 'Retrieved from VIES');

      await tester.tap(find.byKey(_save));
      await _settle(tester);
      final saved = world.suppliers.suppliers.single;
      expect(saved.name, 'Atelier des Arceaux SAS');
      expect(saved.street, '7 rue des Arceaux');
      expect(saved.postalCode, '34000');
      expect(saved.city, 'Sète');
      expect(saved.countryCode, 'FR');
      expect(saved.taxIdentifier, 'FR11223344556');
      expect(
        world.lookups.requests.single.identifier.canonical,
        'FR11223344556',
      );
    },
  );

  testWidgets(
    'a validated number without a profile says so and leaves the fields '
    'to the person',
    (tester) async {
      final world = _World();
      await tester.pumpWidget(world.app());
      await _settle(tester);
      await _openLookup(tester);
      await _lookUp(tester, 'DE123456789');
      expect(find.text('VAT number validated'), findsOneWidget);
      expect(
        find.textContaining('returned no name or address'),
        findsOneWidget,
      );
      expect(_fieldText(tester, 'name'), isEmpty);
      expect(_helperOf(tester, 'name'), 'Not returned by the registry');
      expect(_helperOf(tester, 'tax-id'), 'Validated by VIES');
    },
  );

  testWidgets(
    'an unknown number keeps the input and offers the manual path; an '
    'outage offers a retry that goes on to the review',
    (tester) async {
      final world = _World();
      await tester.pumpWidget(world.app());
      await _settle(tester);
      await _openLookup(tester);
      await _lookUp(tester, 'FR99999999999');
      expect(find.byKey(_problem), findsOneWidget);
      expect(
        find.textContaining('does not know this VAT number'),
        findsOneWidget,
      );
      expect(
        find.text('Retry'),
        findsNothing,
        reason: 'a verdict is never retried as a network error',
      );
      expect(find.text('Continue manually'), findsOneWidget);
      expect(_textField(tester, _identifier).controller!.text, 'FR99999999999');
      await tester.enterText(find.byKey(_identifier), 'IT00000000000');
      await tester.tap(find.byKey(_find));
      await _settle(tester);
      expect(find.textContaining('unavailable right now'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Continue manually'), findsOneWidget);

      world.lookups.answers['IT00000000000'] = CompanyLookupResult(
        providerId: viesProviderId,
        retrieval: LookupRetrieval.retrieved,
        validation: IdentifierValidation.validated,
        lookedUpAt: DateTime(2026, 5, 13, 10),
        fields: const {CompanyField.legalName: 'Officina Srl'},
      );
      await tester.tap(find.byKey(_find));
      await _settle(tester);
      expect(find.byKey(_status), findsOneWidget);
      expect(_fieldText(tester, 'name'), 'Officina Srl');
      expect(world.lookups.requests, hasLength(3));
    },
  );

  testWidgets(
    'continuing manually after a failure keeps the typed identifier and '
    'country in the form',
    (tester) async {
      final world = _World();
      await tester.pumpWidget(world.app());
      await _settle(tester);
      await _openLookup(tester);
      await _lookUp(tester, 'FR99999999999');
      await tester.tap(find.byKey(_manual));
      await _settle(tester);
      expect(find.byKey(_identifier), findsNothing);
      expect(_fieldText(tester, 'tax-id'), 'FR99999999999');
      expect(
        _fieldText(tester, 'country'),
        '',
        reason: 'nothing was chosen in the dropdown; the prefix spoke',
      );
      expect(world.suppliers.suppliers, isEmpty);
    },
  );

  testWidgets(
    'an identifier a supplier already carries opens that supplier; nothing '
    'is asked and nothing is created',
    (tester) async {
      final world = _World();
      await world.suppliers.save(
        'ws',
        const SupplierDraft(name: 'ACME', taxId: 'FR12345678901'),
      );
      await tester.pumpWidget(world.app());
      await _settle(tester);
      await _openLookup(tester);
      await _lookUp(tester, 'fr 12 345 678 901');
      expect(find.textContaining('already exists: 1 · ACME'), findsOneWidget);
      expect(find.byKey(_openExisting), findsOneWidget);
      expect(
        find.byKey(_manual),
        findsNothing,
        reason: 'the way on is the existing supplier, not a second one',
      );
      expect(world.lookups.requests, isEmpty);
      await tester.tap(find.byKey(_openExisting));
      await _settle(tester);
      expect(find.text('Edit supplier'), findsOneWidget);
      expect(_fieldText(tester, 'name'), 'ACME');
      expect(world.suppliers.suppliers, hasLength(1));
    },
  );

  testWidgets('at phone width the lookup stacks in one column with its primary '
      'action on screen', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final world = _World();
    await tester.pumpWidget(world.app());
    await _settle(tester);
    await _openLookup(tester);
    final country = tester.getRect(find.byKey(_country));
    final identifier = tester.getRect(find.byKey(_identifier));
    expect(country.left, identifier.left);
    expect(country.bottom, lessThanOrEqualTo(identifier.top));
    expect(tester.getRect(find.byKey(_find)).bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the keyboard submits the identifier, a missing country is said under '
    'its field, and the verdicts are plain text',
    (tester) async {
      final handle = tester.ensureSemantics();
      final world = _World();
      await tester.pumpWidget(world.app());
      await _settle(tester);
      await _openLookup(tester);
      await tester.enterText(find.byKey(_identifier), '11223344556');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(find.text("Choose the supplier's country."), findsOneWidget);
      expect(world.lookups.requests, isEmpty);

      await tester.enterText(find.byKey(_identifier), 'FR11223344556');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      expect(world.lookups.requests, hasLength(1));
      expect(
        tester.getSemantics(find.byKey(_status)).label,
        contains('VAT number validated'),
      );
      handle.dispose();
    },
  );
}
