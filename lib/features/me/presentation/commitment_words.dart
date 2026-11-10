// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3548 -- Me's words and icons for a `PersonalCommitment`: what it holds and
// where it stands, from the commitment alone (no reservation type).
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/personal_commitment.dart';

/// The icon of what a commitment holds.
IconData commitmentIcon(PersonalCommitment c) => switch (c.place) {
  CommitmentPlace.seat => Icons.chair_outlined,
  CommitmentPlace.desk => Icons.desk_outlined,
  CommitmentPlace.office => Icons.meeting_room_outlined,
  CommitmentPlace.level => Icons.layers_outlined,
  CommitmentPlace.other || null => Icons.event_outlined,
};

/// What a commitment holds, in words; '' for a kind with no word (the label
/// says it).
String commitmentKindWords(AppLocalizations l10n, PersonalCommitment c) =>
    switch (c.place) {
      CommitmentPlace.seat => l10n.myReservationsKindSeat,
      CommitmentPlace.desk => l10n.myReservationsKindDesk,
      CommitmentPlace.office => l10n.myReservationsKindOffice,
      CommitmentPlace.level => l10n.myReservationsKindLevel,
      CommitmentPlace.other || null => '',
    };

/// Where a commitment stands, in words.
String commitmentStateWords(AppLocalizations l10n, CommitmentState state) =>
    switch (state) {
      CommitmentState.upcoming => l10n.myReservationsStatusReserved,
      CommitmentState.ongoing => l10n.myReservationsStatusCheckedIn,
      CommitmentState.done => l10n.myReservationsStatusCompleted,
      CommitmentState.cancelled => l10n.myReservationsStatusCancelled,
    };
