// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 / #2603 -- which of the member page's gated sections a viewer sees,
// as a decision on facts instead of conditions inside the page's build. The
// page maps each section to its widget; the table test pins who sees what.
//
// Pure Dart.
library;

/// A section of the member page that only some viewers see.
enum MemberPageSection {
  /// Write a message to the member (app bar and quick action).
  message,

  /// The member's negotiated prices.
  negotiation,

  /// The roles card (#2085).
  roles,

  /// The member's payment terms.
  paymentTerms,
}

/// What the page's decisions read: the member, the viewer's standing and
/// the workspace's features.
class MemberPageFacts {
  const MemberPageFacts({
    required this.isSelf,
    required this.viewerIsMember,
    required this.memberActive,
    this.memberIsKiosk = false,
    this.memberIsManaged = false,
    this.isOwner = false,
    this.canAdmin = false,
    this.canGiveRoles = false,
    this.seesNegotiations = false,
    this.notesOn = false,
    this.negotiationsOn = false,
    this.rolesOn = false,
    this.paymentTermsOn = false,
  });

  /// The page is the viewer's own.
  final bool isSelf;

  /// The viewer is a member of this workspace.
  final bool viewerIsMember;

  final bool memberActive;
  final bool memberIsKiosk;
  final bool memberIsManaged;

  /// The viewer holds owner-level standing.
  final bool isOwner;

  /// The viewer administers the workspace.
  final bool canAdmin;

  /// The viewer holds manageRoles.
  final bool canGiveRoles;

  /// The viewer holds manageNegotiations or viewNegotiations.
  final bool seesNegotiations;

  final bool notesOn;
  final bool negotiationsOn;
  final bool rolesOn;
  final bool paymentTermsOn;
}

/// The gated sections [f]'s viewer sees.
Set<MemberPageSection> memberPageSections(MemberPageFacts f) => {
  // #887 -- nobody reads a message sent to a managed member.
  if (f.notesOn &&
      !f.isSelf &&
      !f.memberIsKiosk &&
      !f.memberIsManaged &&
      f.memberActive)
    MemberPageSection.message,
  if (f.negotiationsOn &&
      !f.isSelf &&
      f.viewerIsMember &&
      (f.isOwner || f.seesNegotiations))
    MemberPageSection.negotiation,
  if (f.rolesOn &&
      !f.memberIsKiosk &&
      (f.isSelf || f.canAdmin || f.canGiveRoles))
    MemberPageSection.roles,
  if (f.paymentTermsOn && (f.isSelf || f.canAdmin))
    MemberPageSection.paymentTerms,
};
