// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3961 — the page that stands in for the payment provider's in the Demo: the
// app's approval seam opens it instead of a browser, it says nothing is
// charged and names no provider, and each of its three buttons settles the
// order its way.
import 'dart:async';

import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/money/providers/payment_approval_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_payment_journeys.dart';
import '../../helpers/pump_app.dart';

void main() {
  Future<String> answerWith(WidgetTester tester, String key) async {
    final fixture = DemoFixture.build();
    late WidgetRef ref;
    late BuildContext context;
    await pumpApp(
      tester,
      Consumer(
        builder: (c, r, _) {
          ref = r;
          context = c;
          return const SizedBox();
        },
      ),
      overrides: demoOverrides(fixture),
    );
    final container = ProviderScope.containerOf(context);
    final start = await startOrder(container, fixture, 2400);
    unawaited(ref.read(paymentApprovalProvider)(context, start.approveUrl!));
    await tester.pumpAndSettle();
    expect(find.text('Payment page (demonstration)'), findsOneWidget);
    expect(find.textContaining('nothing is charged'), findsOneWidget);
    expect(find.textContaining('PayPal'), findsNothing);
    await tester.tap(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    final intent = intentOf(fixture, start.orderId);
    return intent.status;
  }

  testWidgets('pay settles the order', (tester) async {
    expect(await answerWith(tester, 'demo-provider-pay'), 'captured');
  });

  testWidgets('cancel fails the order', (tester) async {
    expect(await answerWith(tester, 'demo-provider-cancel'), 'failed');
  });

  testWidgets('no answer leaves the order uncertain', (tester) async {
    expect(await answerWith(tester, 'demo-provider-no-answer'), 'created');
  });
}
