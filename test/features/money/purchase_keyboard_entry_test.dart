// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A supplier bill is entered from the keyboard alone: Tab from control to
// control, the supplier chosen with the arrow keys, the amount and the
// dates typed (the invoice date as eight digits, read back under the field
// before anything is saved), Enter to save. No tap, no pointer.
import 'package:deskilo/core/demo/data/purchase_repository.dart';
import 'package:deskilo/core/i18n/format_controller.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/presentation/widgets/purchases_sheet.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/money/providers/supplier_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

class _Recording extends FakePurchaseRepository {
  PurchaseDraft? saved;

  @override
  Future<String> saveDraft(
    String workspaceId,
    String requestId,
    PurchaseDraft draft,
  ) {
    saved = draft;
    return super.saveDraft(workspaceId, requestId, draft);
  }
}

/// Presses Tab until the focus is inside [target]; fails after [limit].
Future<void> _tabTo(
  WidgetTester tester,
  Finder target, {
  int limit = 40,
}) async {
  final element = tester.element(target);
  for (var i = 0; i < limit; i++) {
    final focused = FocusManager.instance.primaryFocus?.context;
    var inside = false;
    focused?.visitAncestorElements((a) => !(inside = identical(a, element)));
    if (focused != null && (inside || identical(focused, element))) return;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  fail('Tab never reached $target');
}

void main() {
  testWidgets('a bill with supplier, date and amount, without the mouse', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Recording();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          purchaseRepositoryProvider.overrideWithValue(repo),
          suppliersProvider.overrideWith(
            (ref, ws) async => const [
              Supplier(id: 's-1', number: '401', name: 'Papeterie Martin'),
            ],
          ),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PurchasesView(workspaceId: 'ws', canCapture: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tabTo(tester, find.byKey(const ValueKey('purchase-add-bill')));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('purchase-save')), findsOneWidget);

    // The supplier: its menu opens with Enter, the arrow picks, Enter takes.
    await _tabTo(tester, find.byKey(const ValueKey('purchase-supplier')));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    final gross = find.byKey(const ValueKey('purchase-gross'));
    await _tabTo(tester, gross);
    tester.testTextInput.enterText('120.50');
    await tester.pump();

    // The invoice date as eight digits in the order of the person's format.
    final invoice = find.byKey(const ValueKey('purchase-invoice-date'));
    await _tabTo(tester, invoice);
    final locale = appFormatOf(tester.element(invoice)).locale;
    final day = DateTime(2030, 2);
    final monthFirst = DateFormat.yMd(locale).pattern!.startsWith('M');
    tester.testTextInput.enterText(monthFirst ? '02012030' : '01022030');
    await tester.pump();
    expect(
      find.descendant(
        of: invoice,
        matching: find.textContaining(
          DateFormat.yMMMMEEEEd(locale).format(day),
        ),
      ),
      findsOneWidget,
      reason: 'the understood date is shown under the field before saving',
    );

    final due = find.byKey(const ValueKey('purchase-due-date'));
    await _tabTo(tester, due);
    tester.testTextInput.enterText(monthFirst ? '03/01/2030' : '01/03/2030');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final saved = repo.saved! as PurchaseBillDraft;
    expect(saved.supplierId, 's-1');
    expect(saved.grossCents, 12050);
    expect(saved.originalDate, day);
    expect(saved.dueOn, DateTime(2030, 3));
    expect(find.byKey(const ValueKey('purchase-save')), findsNothing);
  });

  testWidgets('an unreadable date or amount keeps the dialog, saying why', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Recording();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [purchaseRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PurchasesView(workspaceId: 'ws', canCapture: true),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('purchase-add-bill')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('purchase-gross')),
      '12e3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('purchase-invoice-date')),
      '31/02/2030',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('purchase-save')));
    await tester.tap(find.byKey(const ValueKey('purchase-save')));
    await tester.pumpAndSettle();
    expect(repo.saved, isNull);
    expect(find.byKey(const ValueKey('purchase-invalid')), findsOneWidget);
    expect(
      find.text('Not an amount. Use digits and one decimal separator.'),
      findsOneWidget,
    );
    expect(find.text('This date does not exist.'), findsOneWidget);
    // The typed text is kept as typed, never rewritten into another value.
    expect(find.text('12e3'), findsOneWidget);
  });
}
