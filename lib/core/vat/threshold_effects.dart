// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What crossing a `threshold` row of the tax reference store does (its
// `effect`), the list `tax_reference_valid` accepts:
//   * next_year, immediate -- the net turnover that ends a small-business
//     exemption, with the year or on the supply that passes it;
//   * annual_operations -- the yearly operations with one customer a
//     Spanish space lists on the modelo 347;
//   * simplified_invoice -- the total up to which a simplified invoice is
//     enough (RD 1619/2012 art. 4, VAT Notice 700 §16.4);
//   * stamp_duty -- the total of an Italian document without VAT above which
//     the imposta di bollo is due, the row's `charge_cents` the duty.

const thresholdEffects = [
  'next_year',
  'immediate',
  'annual_operations',
  'simplified_invoice',
  'stamp_duty',
];
