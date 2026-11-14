// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3963 — the Demo's VAT number check answers by a rule, never by a real
// register: a French number is valid when its two-digit key is the one its
// nine digits give, and invalid when it is not; a number of a member state
// the Demo says does not answer is an outage, as VIES gives one; a member with
// no number is never checked into validity. Each answer is recorded on the
// Demo's day, with a consultation number the way a valid one has.
import '../../../../features/money/domain/vies_check.dart';
import '../../../../features/money/domain/vies_repository.dart';

/// The member states the Demo's VIES does not answer for.
const demoViesOutageCountries = {'IT'};

/// What the rule says of [vatId]: its status and, for an outage, why.
({ViesStatus status, String detail}) demoViesRule(String vatId) {
  final id = vatId.replaceAll(RegExp(r'\s'), '').toUpperCase();
  if (id.isEmpty) return (status: ViesStatus.none, detail: '');
  if (id.length < 3) return (status: ViesStatus.invalid, detail: '');
  final country = id.substring(0, 2);
  if (demoViesOutageCountries.contains(country)) {
    return (
      status: ViesStatus.unavailable,
      detail: 'the member state does not answer (MS_UNAVAILABLE)',
    );
  }
  if (country == 'FR') {
    final match = RegExp(r'^FR(\d{2})(\d{9})$').firstMatch(id);
    if (match == null) return (status: ViesStatus.invalid, detail: '');
    final key = (12 + 3 * (int.parse(match.group(2)!) % 97)) % 97;
    return (
      status: int.parse(match.group(1)!) == key
          ? ViesStatus.valid
          : ViesStatus.invalid,
      detail: '',
    );
  }
  return (
    status: RegExp(r'^[A-Z]{2}[0-9A-Z]{8,12}$').hasMatch(id)
        ? ViesStatus.valid
        : ViesStatus.invalid,
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
    final answer = demoViesRule(vatId);
    if (answer.status == ViesStatus.none) return ViesCheck.none;
    final at = now();
    return _checks[memberId] = ViesCheck(
      vatId: vatId,
      status: answer.status,
      consultation: answer.status == ViesStatus.valid
          ? 'DEMO-${vatId.replaceAll(' ', '')}-${at.year}${at.month.toString().padLeft(2, '0')}${at.day.toString().padLeft(2, '0')}'
          : '',
      checkedAt: at,
      detail: answer.detail,
    );
  }
}
