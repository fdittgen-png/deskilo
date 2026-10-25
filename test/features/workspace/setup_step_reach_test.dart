// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2871 — the steps a choice of levels sends the owner to: a step's own
// feature and the features its page takes in both lead to it, in guide
// order and once each; a switch with nothing to set up leads nowhere.
import 'package:deskilo/features/workspace/domain/setup_step_reach.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _ids(Iterable<WorkspaceFeature> fs) => [
  for (final s in setupStepsFor(fs)) s.id,
];

void main() {
  test("a step's own feature leads to it", () {
    expect(_ids({WorkspaceFeature.vatManagement}), ['vat']);
  });

  test('a feature a page takes in leads to that step', () {
    expect(_ids({WorkspaceFeature.holidayImport}), ['hours']);
    expect(_ids({WorkspaceFeature.accountingPeriods}), ['accounting']);
  });

  test('the steps come in guide order, once each', () {
    expect(
      _ids({
        WorkspaceFeature.vatDeclarations,
        WorkspaceFeature.vatManagement,
        WorkspaceFeature.carnets,
        WorkspaceFeature.workingHours,
      }),
      ['hours', 'pricing', 'vat'],
    );
  });

  test('a switch with nothing to set up leads to no step', () {
    expect(
      _ids({WorkspaceFeature.messageGestures, WorkspaceFeature.uiAnimations}),
      isEmpty,
    );
    expect(_ids(const {}), isEmpty);
  });
}
