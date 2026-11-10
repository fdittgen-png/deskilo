// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3550 — a kind's profile becomes a proposal: what switches on, what
// switches off (with the subtree a parent takes), and the flags to write.
import 'package:deskilo/features/workspace/domain/business_kind_proposal.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a new workspace stores: every unchosen flag at its default.
Set<WorkspaceFeature> get _fresh => resolveEnabledFeatures(const {});

void main() {
  test('coworking proposes nothing: its profile is today\'s defaults', () {
    final p = proposalFor(profile: const {}, raw: _fresh);
    expect(p.isEmpty, isTrue);
    expect(p.flags, isEmpty);
  });

  test('a kind without places switches the places off with their subtree', () {
    final raw = {
      ..._fresh,
      WorkspaceFeature.kioskMode,
      WorkspaceFeature.nfcBadges,
    };
    final p = proposalFor(profile: const {'placeBooking': false}, raw: raw);
    expect(p.switchesOff, contains(WorkspaceFeature.placeBooking));
    // The dependants go with their parent, and are listed so nothing
    // disappears unannounced.
    expect(
      p.switchesOff,
      containsAll([
        WorkspaceFeature.kioskMode,
        WorkspaceFeature.nfcBadges,
        WorkspaceFeature.planDecor,
      ]),
    );
    expect(p.switchesOn, isEmpty);
    // Only the profile's own key is written: the children keep their
    // stored choice and come back with their parent.
    expect(p.flags, {'placeBooking': false});
  });

  test('switching a child on brings the parents it needs', () {
    final raw = _fresh.difference({
      WorkspaceFeature.moneyTab,
      WorkspaceFeature.invoicing,
    });
    final p = proposalFor(profile: const {'invoicing': true}, raw: raw);
    expect(p.flags, {'invoicing': true, 'moneyTab': true});
    expect(
      p.switchesOn,
      containsAll([WorkspaceFeature.moneyTab, WorkspaceFeature.invoicing]),
    );
  });

  test('a profile that matches the workspace proposes nothing', () {
    final p = proposalFor(profile: const {'placeBooking': true}, raw: _fresh);
    expect(p.isEmpty, isTrue);
  });

  test('an unknown key is ignored, never written', () {
    final p = proposalFor(profile: const {'noSuchFlag': true}, raw: _fresh);
    expect(p.flags, isEmpty);
    expect(p.isEmpty, isTrue);
  });
}
