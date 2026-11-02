// SPDX-License-Identifier: AGPL-3.0-or-later
// #3070: unavailable or loading approval counts do not appear as a true zero.
import 'package:deskilo/app/shell/purchase_approval_badge.dart';
import 'package:deskilo/features/money/domain/purchase_approval_reads.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _view(AsyncValue<PurchaseApprovalPage> value) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: PurchaseApprovalBadge(value: value)),
);

void main() {
  testWidgets('loading, error, zero and recovered count are distinct', (
    tester,
  ) async {
    await tester.pumpWidget(_view(const AsyncLoading()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(
      _view(AsyncError(StateError('denied'), StackTrace.current)),
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(
      find.byTooltip('The documents waiting for approval could not be read.'),
      findsOneWidget,
    );
    await tester.pumpWidget(
      _view(
        const AsyncData(PurchaseApprovalPage(rows: [], count: 0, version: 'v')),
      ),
    );
    expect(find.byType(Badge), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    await tester.pumpWidget(
      _view(
        const AsyncData(PurchaseApprovalPage(rows: [], count: 3, version: 'v')),
      ),
    );
    expect(find.text('3'), findsOneWidget);
  });
}
