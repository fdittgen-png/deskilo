// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 / #2603 -- who sees which gated section of a member's page, as a
// table on the decision (no taps): the page only maps each section to its
// widget.
import 'package:deskilo/features/members/domain/member_page_sections.dart';
import 'package:flutter_test/flutter_test.dart';

const _allOn = MemberPageFacts(
  isSelf: false,
  viewerIsMember: true,
  memberActive: true,
  notesOn: true,
  negotiationsOn: true,
  rolesOn: true,
  paymentTermsOn: true,
);

MemberPageFacts _with({
  bool isSelf = false,
  bool viewerIsMember = true,
  bool memberActive = true,
  bool kiosk = false,
  bool managed = false,
  bool owner = false,
  bool admin = false,
  bool giveRoles = false,
  bool seesNegotiations = false,
  bool featuresOn = true,
}) => MemberPageFacts(
  isSelf: isSelf,
  viewerIsMember: viewerIsMember,
  memberActive: memberActive,
  memberIsKiosk: kiosk,
  memberIsManaged: managed,
  isOwner: owner,
  canAdmin: admin,
  canGiveRoles: giveRoles,
  seesNegotiations: seesNegotiations,
  notesOn: featuresOn && _allOn.notesOn,
  negotiationsOn: featuresOn && _allOn.negotiationsOn,
  rolesOn: featuresOn && _allOn.rolesOn,
  paymentTermsOn: featuresOn && _allOn.paymentTermsOn,
);

void main() {
  const message = MemberPageSection.message;
  const negotiation = MemberPageSection.negotiation;
  const roles = MemberPageSection.roles;
  const terms = MemberPageSection.paymentTerms;

  final table = <String, (MemberPageFacts, Set<MemberPageSection>)>{
    'a plain member looking at another': (_with(), {message}),
    'the owner looking at another': (
      _with(owner: true),
      {message, negotiation},
    ),
    'an administrator': (_with(admin: true), {message, roles, terms}),
    'a role giver': (_with(giveRoles: true), {message, roles}),
    'a negotiation viewer': (
      _with(seesNegotiations: true),
      {message, negotiation},
    ),
    'my own page': (_with(isSelf: true, owner: true), {roles, terms}),
    'a kiosk member, seen by an administrator': (
      _with(kiosk: true, admin: true),
      {terms},
    ),
    'a managed member (#887)': (_with(managed: true), <MemberPageSection>{}),
    'a paused member': (_with(memberActive: false), <MemberPageSection>{}),
    'an owner who is not a member here': (
      _with(viewerIsMember: false, owner: true),
      {message},
    ),
    'every feature off': (
      _with(featuresOn: false, owner: true, admin: true),
      <MemberPageSection>{},
    ),
  };

  for (final MapEntry(key: name, value: (facts, expected)) in table.entries) {
    test(name, () => expect(memberPageSections(facts), expected));
  }
}
