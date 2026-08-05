// SPDX-License-Identifier: 0BSD
//
// The workspace's LEGAL IDENTITY (0069) — the data EN 16931 cannot do
// without. The screen asks for the VAT regime first because the regime
// decides which identifier the norm demands: a registration number
// outside the scope of VAT (BR-O-02 forbids a tax id there), a VAT number
// when exempt (BR-E-02 requires one).
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/invoice_legal.dart';
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

/// The #480 mention fields sit below the identity — the ListView is
/// lazy, so scroll a field into existence before touching it.
Future<void> reveal(WidgetTester tester, Key key) async {
  await tester.scrollUntilVisible(
    find.byKey(key),
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.byKey(key));
  await tester.pumpAndSettle();
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
    await reveal(tester, const ValueKey('legal-identity-save'));
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
    await reveal(tester, const ValueKey('legal-identity-save'));
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

  testWidgets(
      'the invoice-mention fields save into invoice_legal, and empty '
      'clauses fall back to statutory defaults on the document (#480)',
      (tester) async {
    final workspace = await pumpIdentity(tester);

    await reveal(tester, const ValueKey('legal-identity-legal-form'));
    await tester.enterText(
      find.byKey(const ValueKey('legal-identity-legal-form')),
      'SARL au capital de 7 500 €',
    );
    await reveal(tester, const ValueKey('legal-identity-registration'));
    await tester.enterText(
      find.byKey(const ValueKey('legal-identity-registration')),
      'RCS Saint-Brieuc 680 357 910',
    );
    await reveal(tester, const ValueKey('legal-identity-insurance'));
    await tester.enterText(
      find.byKey(const ValueKey('legal-identity-insurance')),
      'Assurance Pro — France métropolitaine',
    );
    await reveal(tester, const ValueKey('legal-identity-save'));
    await tester.tap(find.byKey(const ValueKey('legal-identity-save')));
    await tester.pumpAndSettle();

    final legal = InvoiceLegal.fromJson(
        workspace.workspaces.single.invoiceLegal);
    expect(legal.legalForm, 'SARL au capital de 7 500 €');
    expect(legal.registration, 'RCS Saint-Brieuc 680 357 910');
    expect(legal.insurance, 'Assurance Pro — France métropolitaine');
    // The clauses the owner left empty stay empty in STORAGE — the
    // statutory defaults are applied at render time, per locale.
    expect(legal.paymentTerms, '');
    expect(legal.latePenalty, '');
  });

  testWidgets(
      'declaring the workspace an ASSOCIATION saves seller_kind and '
      'adapts the hints (RNA, no B2B clauses) (#484)', (tester) async {
    final workspace = await pumpIdentity(tester);

    await reveal(tester, const ValueKey('legal-identity-kind'));
    await tester.tap(find.text('Association (non-profit)'));
    await tester.pumpAndSettle();

    // The hints now speak association: RNA instead of a trade register,
    // and the B2B-clause note is shown.
    expect(find.textContaining('RNA W123456789'), findsOneWidget);
    expect(find.textContaining('mandatory only between professionals'),
        findsOneWidget);

    await reveal(tester, const ValueKey('legal-identity-save'));
    await tester.tap(find.byKey(const ValueKey('legal-identity-save')));
    await tester.pumpAndSettle();

    final legal = InvoiceLegal.fromJson(
        workspace.workspaces.single.invoiceLegal);
    expect(legal.sellerKind, 'association');
    expect(legal.isAssociation, isTrue);
  });

  testWidgets('a plain member cannot reach the screen at all', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace();
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: false);
    await pumpIdentity(tester, workspace: workspace);

    expect(find.byKey(const ValueKey('legal-identity-save')), findsNothing);
  });
}
