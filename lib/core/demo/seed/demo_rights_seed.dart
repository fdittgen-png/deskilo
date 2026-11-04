// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3278 — two rights requests addressed to the demo space, so the personal
// data admin's screen has something to record, extend, complete or refuse.
import '../../../features/profile/domain/rights_request.dart';
import '../demo_dataset.dart';

/// The two open requests, dated around [now].
List<RightsRequest> demoRightsRequests(DateTime now) {
  final asked = now.subtract(const Duration(days: 6));
  final later = now.subtract(const Duration(days: 2));
  return [
    RightsRequest(
      id: 'demo-rights-1',
      workspaceId: 'ws-1',
      memberId: demoCast[1].memberId,
      kind: 'access',
      status: 'received',
      receivedAt: asked,
      dueOn: DateTime(asked.year, asked.month + 1, asked.day),
      details: 'A copy of the data you hold about me.',
    ),
    RightsRequest(
      id: 'demo-rights-2',
      workspaceId: 'ws-1',
      memberId: demoCast[2].memberId,
      kind: 'rectification',
      status: 'received',
      receivedAt: later,
      dueOn: DateTime(later.year, later.month + 1, later.day),
      details: 'My phone number is wrong.',
    ),
  ];
}
