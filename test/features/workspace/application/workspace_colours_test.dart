// SPDX-License-Identifier: 0BSD
//
// #1289 S2 — the decision, without a screen.
import 'package:deskilo/features/workspace/application/workspace_colours.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/mock_providers.dart';

/// A check that refuses one colour, so the refusal is exercised without
/// depending on which colours the derivation happens to accept today.
List<String> _refuseYellow(int argb) =>
    argb == 0xFFFACC15 ? ['onPrimary on primary', 'outline on surface'] : [];

void main() {
  test('a colour is stored upper-case and reported as applied', () async {
    final repository = FakeWorkspaceRepository();
    final colours = WorkspaceColours(repository, _refuseYellow);
    final outcome =
        await colours.choose(workspaceId: 'ws-1', text: ' #1f3a5f ');
    expect(outcome, isA<ColourApplied>());
    expect((outcome as ColourApplied).hex, '#1F3A5F');
    expect(repository.brandings['ws-1'], {'seed_color': '#1F3A5F'});
  });

  test('an emptied box is a reset, not a blank colour', () async {
    final repository = FakeWorkspaceRepository()
      ..brandings['ws-1'] = {'seed_color': '#1F3A5F'};
    final colours = WorkspaceColours(repository, _refuseYellow);
    expect(await colours.choose(workspaceId: 'ws-1', text: '   '),
        isA<ColourReset>());
    expect(repository.brandings['ws-1'], isEmpty,
        reason: 'the key is removed; storing the product colour would '
            'freeze this space against the next palette change');
  });

  test('something that is not a colour is refused as malformed and writes '
      'nothing', () async {
    final repository = FakeWorkspaceRepository();
    final colours = WorkspaceColours(repository, _refuseYellow);
    for (final text in ['tomato', '#12345', '#GGGGGG', '1F3A5F']) {
      final outcome = await colours.choose(workspaceId: 'ws-1', text: text);
      expect(outcome, isA<ColourMalformed>(), reason: text);
      expect((outcome as ColourMalformed).text, text);
    }
    expect(repository.brandings, isEmpty);
  });

  test('a colour the app could not make readable names its pair and writes '
      'nothing', () async {
    final repository = FakeWorkspaceRepository();
    final colours = WorkspaceColours(repository, _refuseYellow);
    final outcome =
        await colours.choose(workspaceId: 'ws-1', text: '#FACC15');
    expect(outcome, isA<ColourRefused>());
    expect((outcome as ColourRefused).pair, 'onPrimary on primary');
    expect(repository.brandings, isEmpty);
  });

  test('the explicit reset removes the key', () async {
    final repository = FakeWorkspaceRepository()
      ..brandings['ws-1'] = {'seed_color': '#1F3A5F', 'seat_palette': 'default'};
    final colours = WorkspaceColours(repository, _refuseYellow);
    expect(await colours.reset(workspaceId: 'ws-1'), isA<ColourReset>());
    expect(repository.brandings['ws-1'], {'seat_palette': 'default'},
        reason: 'the seed goes, the rest of the map stays');
  });
}
