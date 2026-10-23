// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup guide's Run step pages, from the features that own them: the
// step screen lives in the workspace feature, below money and events, so
// the router composes them here and hands them in.
import 'package:flutter/widgets.dart';

import '../../features/events/presentation/widgets/setup_approvals_step.dart';
import '../../features/money/presentation/widgets/bill_view.dart';
import '../../features/money/presentation/widgets/setup_online_payments_step.dart';
import '../../features/money/presentation/widgets/setup_pricing_step.dart';
import '../../features/workspace/domain/payment_instructions.dart';
import '../../features/workspace/presentation/widgets/setup_run_pages.dart';

const SetupRunPages setupRunPages = SetupRunPages(
  pricing: SetupPricingStep.new,
  checkout: _checkout,
  onlinePayments: SetupOnlinePaymentsStep.new,
  approvals: SetupApprovalsStep.new,
);

/// The how-to-pay card of a member's unpaid statement. The steps show it
/// as a picture that nothing acts on, so its online button only has to
/// be there when online payment is.
Widget _checkout(PaymentInstructions instructions, {required bool payOnline}) =>
    HowToPayCard(
      instructions: instructions,
      onPayOnline: payOnline ? _shownOnly : null,
    );

void _shownOnly() {}
