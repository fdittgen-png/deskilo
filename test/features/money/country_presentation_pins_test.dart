// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) item 4 -- which country-specific parts the money screens
// show, pinned BEFORE they read the add-ons.
//
// Row -> branch table:
//   needsVatTaxPointNotice   FR | fr | ' fr ' x vat_registered x never chose
//                            -> told; DE | '' | exempt | chose -> not told
//   legal identity fields    GB x vat_registered -> the UK land-tax fields;
//                            CH -> the Swiss letting fields; CA -> the
//                            Canadian tax fields; FR / DE / '' -> none;
//                            every country x exempt -> none
//   (the HMRC door on the declarations screen is pinned by
//   test/core/demo/demo_hmrc_journey_test.dart: the London space has it, the
//   French space has none)
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/presentation/widgets/vat_tax_point_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _landTax = ValueKey('legal-identity-land-tax');
const _letting = ValueKey('legal-identity-letting');
const _canada = ValueKey('legal-identity-canada');

Future<Set<String>> _fieldsShown(
  WidgetTester tester, {
  required String country,
  required String regime,
}) async {
  final workspace = FakeWorkspaceRepository.withWorkspace();
  workspace.workspaces[0] = workspace.workspaces[0].copyWith(
    countryCode: country,
    vatRegime: regime,
  );
  await tester.binding.setSurfaceSize(const Size(800, 6000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  unawaited(GoRouter.of(context).push('/legal-identity'));
  await tester.pumpAndSettle();
  return {
    if (find.byKey(_landTax).evaluate().isNotEmpty) 'uk-land',
    if (find.byKey(_letting).evaluate().isNotEmpty) 'ch-letting',
    if (find.byKey(_canada).evaluate().isNotEmpty) 'ca-tax',
  };
}

void main() {
  test('the French tax-point notice: French, VAT-registered, never chose', () {
    bool needs(String country, String regime, [Map<dynamic, dynamic>? legal]) =>
        needsVatTaxPointNotice(
          country: country,
          vatRegime: regime,
          invoiceLegal: legal ?? const {},
        );
    expect(needs('FR', 'vat_registered'), isTrue);
    expect(needs('fr', 'vat_registered'), isTrue);
    expect(needs(' fr ', 'vat_registered'), isTrue);
    expect(needs('DE', 'vat_registered'), isFalse);
    expect(needs('', 'vat_registered'), isFalse);
    expect(needs('FR', 'exempt'), isFalse);
    expect(needs('FR', 'not_subject'), isFalse);
    expect(
      needs('FR', 'vat_registered', {'vat_tax_point': 'invoice'}),
      isFalse,
      reason: 'a space that chose is not told',
    );
  });

  for (final (country, expected) in <(String, Set<String>)>[
    ('GB', {'uk-land'}),
    ('CH', {'ch-letting'}),
    ('CA', {'ca-tax'}),
    ('FR', {}),
    ('DE', {}),
  ]) {
    testWidgets('legal identity of a VAT-registered $country space shows '
        '$expected', (tester) async {
      expect(
        await _fieldsShown(
          tester,
          country: country,
          regime: 'vat_registered',
        ),
        expected,
      );
    });

    testWidgets('legal identity of an exempt $country space shows none', (
      tester,
    ) async {
      expect(
        await _fieldsShown(tester, country: country, regime: 'exempt'),
        isEmpty,
      );
    });
  }
}
