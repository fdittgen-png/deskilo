// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1376 — who the visitor is while they look around.
//
// A persona is NOT a pretend role. Switching one changes the member the
// fixture answers `fetchMyMember` with, and the signed-in user id beside
// it; everything above that reads permissions exactly the way it does in
// live mode, through `effectivePermissions(member, workspace)`. A screen
// that hides a button from a member hides it here for the same reason it
// hides it there, and no Demo-specific branch decides anything.
//
// The three are people who already exist in the dataset (#1374), so
// switching shows the product through somebody with real bookings, real
// bills and a real place on the plan — not an empty shell with a
// different badge.
import 'demo_dataset.dart';

/// The perspectives a visitor can look from.
enum DemoPersona {
  /// Books a seat, reads their own statement, submits an expense.
  member,

  /// Runs the day: members, reservations, expenses.
  admin,

  /// Configures the space: roles, features, templates, governance.
  owner,
}

extension DemoPersonaCast on DemoPersona {
  /// The person in the dataset this persona looks through.
  DemoPerson get person => switch (this) {
        DemoPersona.member => demoCast[1], // Bruno: half-time, owes a bill
        DemoPersona.admin => demoCast[2], // Chiara: checked in, runs the day
        DemoPersona.owner => demoCast[0], // Ada: the owner
      };

  /// The member id the fixture answers with while this persona is active.
  String get memberId => person.memberId;

  /// The signed-in user id.
  String get userId => person.userId;
}

/// The persona a visitor lands in.
///
/// The owner, because an empty-handed first impression is the wrong one:
/// every administrative surface has something to show, and stepping DOWN
/// to a member is the interesting move.
const DemoPersona initialDemoPersona = DemoPersona.owner;
