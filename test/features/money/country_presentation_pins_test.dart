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
//   HMRC door                GB x mtdSubmission on x prepared return -> the
//                            MTD button; GB without the feature -> none;
//                            FR with the feature -> none (also pinned by
//                            test/core/demo/demo_hmrc_journey_test.dart: the
//                            London space has it, the French space none)
//   (workspaces.country_code is `^[A-Z]{2}$` since migration 0001, so every
//   workspace country the screens read is upper-case)
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/presentation/widgets/vat_tax_point_notice.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo_vat_declaration/deskilo_vat_declaration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_money_repository.dart';
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

  for (final (country, feature, shown) in <(String, bool, bool)>[
    ('GB', true, true),
    ('GB', false, false),
    ('FR', true, false),
  ]) {
    testWidgets('the MTD door for a $country space, feature '
        '${feature ? 'on' : 'off'}: ${shown ? 'shown' : 'none'}', (
      tester,
    ) async {
      final workspace = FakeWorkspaceRepository.withWorkspace(
        featureFlags: feature
            ? {
                for (final e in featureFlagsToggleDelta(
                  feature: WorkspaceFeature.mtdSubmission,
                  value: true,
                ).entries)
                  e.key.dbKey: e.value,
              }
            : const {},
      );
      workspace.workspaces[0] = workspace.workspaces[0].copyWith(
        vatRegime: 'vat_registered',
        countryCode: country,
      );
      final money = FakeMoneyRepository()
        ..vatDeclarations.add(
          VatDeclaration(
            id: 'd1',
            workspaceId: 'ws-1',
            periodStart: DateTime(2026, 9),
            periodEnd: DateTime(2026, 9, 30),
            status: 'prepared',
            lines: const [
              VatDeclarationLine(
                percent: 20,
                category: 'S',
                grossCents: 120000,
                netCents: 100000,
                vatCents: 20000,
                invoiceCount: 1,
              ),
            ],
            totalNetCents: 100000,
            totalVatCents: 20000,
            currency: 'EUR',
            invoiceCount: 1,
            createdAt: DateTime.utc(2026, 10, 2),
          ),
        );
      await tester.binding.setSurfaceSize(const Size(900, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: standardTestOverrides(money: money, workspace: workspace),
          child: const DeskiloApp(),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      unawaited(GoRouter.of(context).push('/vat-declarations'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('vat-decl-mtd-d1')),
        shown ? findsOneWidget : findsNothing,
      );
    });
  }
}
