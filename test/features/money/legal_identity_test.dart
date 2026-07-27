// SPDX-License-Identifier: 0BSD
//
// The workspace's LEGAL IDENTITY (0069) — the data EN 16931 cannot do
// without. The screen asks for the VAT regime first because the regime
// decides which identifier the norm demands: a registration number
// outside the scope of VAT (BR-O-02 forbids a tax id there), a VAT number
// when exempt (BR-E-02 requires one).
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpIdentity(
  WidgetTester tester, {
  FakeWorkspaceRepository? workspace,
}) async {
  workspace ??= FakeWorkspaceRepository.withWorkspace();
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push('/legal-identity');
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets(
      'outside the scope of VAT the screen asks for the REGISTRATION '
      'number, and saving it persists the identity', (tester) async {
    final workspace = await pumpIdentity(tester);

    expect(find.byKey(const ValueKey('legal-identity-legal-id')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('legal-identity-vat-id')), findsNothing,
        reason: 'BR-O-02 forbids a tax id in this regime — do not ask '
            'for one');

    await tester.enterText(
      find.byKey(const ValueKey('legal-identity-legal-id')),
      '812345678',
    );
    await tester.enterText(
      find.byKey(const ValueKey('legal-identity-city')),
      'Pézenas',
    );
    await tester.enterText(
      find.byKey(const ValueKey('legal-identity-postal-code')),
      '34120',
    );
    await tester.tap(find.byKey(const ValueKey('legal-identity-save')));
    await tester.pumpAndSettle();

    final saved = workspace.workspaces.single;
    expect(saved.legalId, '812345678');
    expect(saved.city, 'Pézenas');
    expect(saved.postalCode, '34120');
    expect(saved.vatRegime, 'not_subject');
    expect(find.text('Legal identity saved.'), findsOneWidget);
  });

  testWidgets(
      'switching to the exempt regime swaps the field for the VAT number',
      (tester) async {
    final workspace = await pumpIdentity(tester);

    await tester.tap(find.byKey(const ValueKey('legal-identity-regime')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VAT-exempt (small-business scheme)').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('legal-identity-vat-id')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('legal-identity-legal-id')),
        findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('legal-identity-vat-id')),
      'FR12812345678',
    );
    await tester.enterText(
      find.byKey(const ValueKey('legal-identity-reason')),
      'Franchise en base de TVA',
    );
    await tester.tap(find.byKey(const ValueKey('legal-identity-save')));
    await tester.pumpAndSettle();

    final saved = workspace.workspaces.single;
    expect(saved.vatRegime, 'exempt');
    expect(saved.vatId, 'FR12812345678');
    expect(saved.taxExemptionReason, 'Franchise en base de TVA');
  });

  testWidgets(
      'declaring a VAT-charging workspace warns that the XML export stays '
      'off — the app cannot break VAT down per position', (tester) async {
    await pumpIdentity(tester);

    await tester.tap(find.byKey(const ValueKey('legal-identity-regime')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('VAT-registered (charges VAT)').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('legal-identity-vat-warning')),
        findsOneWidget);
  });

  testWidgets('a plain member cannot reach the screen at all', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: false);
    await pumpIdentity(tester, workspace: workspace);

    expect(find.byKey(const ValueKey('legal-identity-save')), findsNothing);
  });
}
