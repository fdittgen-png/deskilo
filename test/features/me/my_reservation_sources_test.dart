// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C2 — the hosts My reservations reads come from the workspaces my
// personal account names: one source per installation, in the order they
// were named, with my workspaces on it and their readable names. A saved
// reference with no relationship on my home holds no booking of mine and
// is not read; another installation's workspace is read there.
import 'package:deskilo/features/me/application/my_reservation_sources.dart';
import 'package:deskilo/features/me/domain/personal_workspace_refs.dart';
import 'package:flutter_test/flutter_test.dart';

const _home = '11111111-1111-4111-8111-111111111111';
const _wa = '22222222-2222-4222-8222-222222222222';

String _ws(int n) => '00000000-0000-4000-8000-00000000000$n';

PersonalWorkspaceRef _ref(
  String installation,
  int n, {
  bool here = true,
  RefStatus? status = RefStatus.active,
  String? label,
}) =>
    PersonalWorkspaceRef(
      networkId: '$installation:${_ws(n)}',
      hostedHere: here,
      freshness: here ? RefFreshness.local : RefFreshness.unavailable,
      status: here ? status : null,
      label: label,
    );

void main() {
  test('one source per installation, with my workspaces and their names', () {
    final sources = myReservationSourcesOf(PersonalWorkspaceRefs(
      homeInstallationId: _home,
      refs: [
        _ref(_home, 1, label: 'Pézenas'),
        _ref(_wa, 2, here: false),
        _ref(_home, 3, status: RefStatus.exited, label: 'Old'),
        _ref(_wa, 4, here: false, label: 'Leipzig'),
      ],
    ));
    expect(sources.map((s) => s.installationId), [_home, _wa]);
    expect(sources.first.hostedHere, isTrue);
    expect(sources.first.workspaceIds, [_ws(1), _ws(3)],
        reason: 'a space I left still holds my past bookings');
    expect(sources.first.labels, ['Pézenas', 'Old']);
    expect(sources.last.hostedHere, isFalse, reason: 'read on its own installation');
    expect(sources.last.workspaceIds, [_ws(2), _ws(4)]);
    expect(sources.last.labels, ['Leipzig'], reason: 'an unnamed space adds no name');
  });

  test('a reference saved here without a relationship is not read', () {
    final sources = myReservationSourcesOf(PersonalWorkspaceRefs(
      homeInstallationId: _home,
      refs: [_ref(_home, 1, status: null, label: 'Saved')],
    ));
    expect(sources, isEmpty);
  });

  test('no reference, no source', () {
    expect(myReservationSourcesOf(PersonalWorkspaceRefs.none), isEmpty);
  });
}
