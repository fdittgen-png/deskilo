// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4157 — what a person chooses on their own booking's sheet: a closed set.
// There is no default branch that stands for one of them: an unknown choice
// cannot exist, so it cannot reach a command.

/// The choices of the own-booking sheet.
enum MySeatAction {
  checkIn('checkin'),
  checkOut('checkout'),
  cancel('cancel'),

  /// A booking that can no longer be cancelled is asked to be deleted: a
  /// request an owner or admin validates (#492).
  requestDeletion('requestDeletion');

  const MySeatAction(this.wireName);

  /// The name the task recorder and the trace have always used for it.
  final String wireName;
}
