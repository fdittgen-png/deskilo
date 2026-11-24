// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 -- the Demo's billing-access durations, named once: how long an invitation's code can be used (the server's
// default, 0910) and how long ago the seeded grant was invited and accepted.
const demoInviteValidity = Duration(days: 14);
const demoSeedInvitedAgo = Duration(days: 30);
const demoSeedAcceptedAfter = Duration(days: 1);
