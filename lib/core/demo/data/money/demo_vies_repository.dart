// SPDX-License-Identifier: AGPL-3.0-or-later
// #3963 — the Demo's VAT number check answers by one stated rule, never by a
// real register and never by a country's own rules: a number is two letters
// and nine to twelve digits; with the digits taken as a number, it is VALID
// when they leave a remainder of one when divided by 97 (a check-digit rule,
// as a real register has), INVALID when they leave another, and an OUTAGE
// when they end in a zero (the Demo's way of having a service that does not
// answer). A member with no number is never checked into validity. Each
// answer is recorded on the Demo's day, and a valid one has a consultation
// number the way VIES gives one.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show isoDay;

import '../../../../features/money/domain/vies_check.dart';
import '../../../../features/money/domain/vies_repository.dart';

/// What the rule says of [vatId]: its status and, for an outage, why.
({ViesStatus status, String detail}) _rule(String vatId) {
  final id = vatId.replaceAll(RegExp(r'\s'), '').toUpperCase();
  if (id.isEmpty) return (status: ViesStatus.none, detail: '');
  final shape = RegExp(r'^[A-Z]{2}([0-9]{9,12})$').firstMatch(id);
  if (shape == null) return (status: ViesStatus.invalid, detail: '');
  final digits = shape.group(1)!;
  if (digits.endsWith('0')) {
    return (
      status: ViesStatus.unavailable,
      detail: 'the service does not answer (MS_UNAVAILABLE)',
    );
  }
  return (
    status: int.parse(digits) % 97 == 1 ? ViesStatus.valid : ViesStatus.invalid,
    detail: '',
  );
}

/// VIES checks of the Demo's members, read from their profiles' numbers.
class DemoViesRepository implements ViesRepository {
  DemoViesRepository({required this.vatIdOf, required this.now});

  /// The VAT number of a member of the space, '' when none.
  final String Function(String memberId) vatIdOf;
  final DateTime Function() now;

  final Map<String, ViesCheck> _checks = {};

  @override
  Future<ViesCheck> fetchViesCheck(String memberId) async =>
      _checks[memberId] ?? ViesCheck.none;

  @override
  Future<ViesCheck> checkVies(String workspaceId, String memberId) async {
    final vatId = vatIdOf(memberId);
    final answer = _rule(vatId);
    if (answer.status == ViesStatus.none) return ViesCheck.none;
    final at = now();
    return _checks[memberId] = ViesCheck(
      vatId: vatId,
      status: answer.status,
      consultation: answer.status == ViesStatus.valid
          ? 'DEMO-${vatId.replaceAll(' ', '')}-${isoDay(at).replaceAll('-', '')}'
          : '',
      checkedAt: at,
      detail: answer.detail,
    );
  }
}
