// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- the Swiss payment slip (the QR bill, SIX Swiss QR-bill
// implementation guidelines): its existence is the gate, and it declares the
// country its addresses are written in.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this declares.
const chPaymentSlipImplementationVersion = '1';

/// The Swiss payment slip.
class ChPaymentSlip extends PaymentSlipContribution {
  const ChPaymentSlip();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'ch.payment_slip',
    implementationVersion: chPaymentSlipImplementationVersion,
    contractVersion: paymentSlipContractVersion,
    formatVersion: 'six-qr-bill-2.3',
    capabilityId: 'payment_slip.CH',
  );

  @override
  String get debtorDefaultCountry => 'CH';

  /// A Swiss address has no country prefix; a foreign one is `DE-10115 Berlin`.
  @override
  String addressCountryPrefix(String country) =>
      '';
}
