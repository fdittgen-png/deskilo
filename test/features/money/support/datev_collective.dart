// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The sub-ledger detail of the hand-worked DATEV tests that predate the
// Debitors: every member on one Debitor, 10000, no cost centre and no
// voucher links, so their rows read as they were worked out by hand. The
// Debitor per member is datev_package_test.dart's.
import 'dart:collection';

import 'package:deskilo/features/money/domain/datev.dart';

/// Every member on Debitor 10000.
const datevCollective = DatevDetail(
  defaultCostCentre: '',
  voucherLinks: false,
  debtors: _AnyMember(),
);

class _AnyMember extends UnmodifiableMapBase<String, String> {
  const _AnyMember();

  @override
  String operator [](Object? key) => '10000';

  @override
  Iterable<String> get keys => const [];
}
