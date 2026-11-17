// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3961 — where the real app leaves for the provider's page, the Demo shows
// the page that stands in for it, applies the answer to the order, and lets
// the money pages read what changed. An address that is not the stand-in's
// goes where every other Demo link goes: recorded, never opened.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/money/providers/money_providers.dart';
import '../../features/money/providers/payment_approval_providers.dart';
import 'data/money/demo_payment_gateway_repository.dart';
import 'demo_fixture.dart';
import 'demo_spaces.dart';
import 'presentation/demo_provider_page.dart';

/// The Demo's [PaymentApproval] for [fixture]'s session.
PaymentApproval Function(Ref ref) demoPaymentApproval(DemoFixture fixture) =>
    (ref) => (BuildContext context, Uri approveUrl) async {
      final orderId = demoProviderOrderOf(approveUrl);
      final workspaceId = approveUrl.queryParameters['workspace'];
      final space = DemoSpaceKey.values.where((s) => s.id == workspaceId).singleOrNull;
      if (orderId == null || space == null) {
        await fixture.outward.openLink(approveUrl);
        return;
      }
      final gateway = fixture.space(space).money.paymentGateway;
      final actor = fixture.actor.memberId;
      final answer = await showDemoProviderPage(context);
      if (fixture.actor.memberId != actor) return;
      await gateway.resolveOrder(
        orderId,
        answer ?? DemoPaymentOutcome.noAnswer,
      );
      ref
        ..invalidate(myPaymentIntentsProvider)
        ..invalidate(invoicesProvider)
        ..invalidate(invoiceMatchesProvider)
        ..invalidate(myLedgerProvider)
        ..invalidate(myAccountProvider)
        ..invalidate(myStatementProvider);
    };
