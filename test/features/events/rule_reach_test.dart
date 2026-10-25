// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — who can decide under an approval rule, counted as the server
// counts them when it calls a rule short (workspace_readiness, 0399):
// owners always; 'members' every active member; 'listed' the listed ones;
// 'admins' the administrators the rule admits, all or the listed ones;
// a listed person who is no longer active is not counted. A rule asking
// for more is short.
import 'package:deskilo/features/events/domain/rule_reach.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:flutter_test/flutter_test.dart';

Decider _m(String id, {bool owner = false, bool admin = false}) =>
    (id: id, isOwner: owner, isAdmin: admin);

/// The active members: the page hands in no one who has left.
final _people = [
  _m('owner', owner: true, admin: true),
  _m('admin-a', admin: true),
  _m('admin-b', admin: true),
  _m('member-1'),
  _m('member-2'),
];

ValidationPolicy _rule({
  int required = 1,
  String scope = 'admins',
  bool admins = true,
  List<String> listed = const [],
}) => ValidationPolicy(
  workspaceId: 'ws-1',
  eventType: 'payment',
  requiredCount: required,
  adminsMayValidate: admins,
  eligibleAdminIds: listed,
  ownerRequired: false,
  validatorScope: scope,
);

void main() {
  test('admins: the owner and every active administrator', () {
    expect(decidersUnder(_rule(), _people), 3);
  });

  test('admins, listed subset: the owner and the listed administrators', () {
    expect(decidersUnder(_rule(listed: ['admin-a', 'member-1']), _people), 2);
  });

  test('admins not admitted: the owner alone', () {
    expect(decidersUnder(_rule(admins: false), _people), 1);
  });

  test('listed: the owner and exactly the listed persons, any role', () {
    expect(
      decidersUnder(
        _rule(scope: 'listed', listed: ['member-1', 'someone-gone']),
        _people,
      ),
      2,
    );
  });

  test('members: the owner and every active member', () {
    expect(decidersUnder(_rule(scope: 'members'), _people), 5);
  });

  test('a scope the server does not know admits the owners alone', () {
    expect(decidersUnder(_rule(scope: 'nobody'), _people), 1);
  });

  test('short only when it asks for more than can decide', () {
    expect(ruleIsShort(_rule(required: 3), _people), isFalse);
    expect(ruleIsShort(_rule(required: 4), _people), isTrue);
  });
}
