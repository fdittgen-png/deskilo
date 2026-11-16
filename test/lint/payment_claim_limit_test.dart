// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 — the app refuses a selection over the payment function's limit
// before anything is sent; the two numbers are one rule written twice (the
// function cannot read the app's), so this keeps them equal.
import 'dart:io';

import 'package:deskilo/features/money/domain/payment_claims.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app\'s invoices per payment equal the payment function\'s', () {
    final source = File('supabase/functions/create-payment-order/request.ts')
        .readAsStringSync();
    final match = RegExp(r'export const MAX_CLAIMED_INVOICES = (\d+);')
        .firstMatch(source);
    expect(match, isNotNull, reason: 'request.ts names its limit');
    expect(int.parse(match!.group(1)!), maxClaimedInvoices);
  });
}
