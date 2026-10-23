// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The two sides of a space (production and development) are one row in
// both of Me's lists: the home list and every linked server's. One helper
// groups them, rows keep the order their first side came in, and
// production comes first within a row whatever order the server sent.
import 'package:deskilo/features/me/domain/my_spaces.dart';
import 'package:deskilo/features/me/domain/space_pairs.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

const _dev = WorkspaceEnvironment.development;
const _prod = WorkspaceEnvironment.production;

LinkedSpace _side(
  String id, {
  String pair = '',
  WorkspaceEnvironment env = _dev,
}) => LinkedSpace(id: id, name: id, pairId: pair, environment: env);

List<List<String>> _ids(List<List<SpaceSide>> rows) => [
  for (final row in rows) [for (final side in row) side.id],
];

void main() {
  test('a lone space is a row of its own, keyed by its id', () {
    final lone = _side('a');
    expect(_ids(pairSides([lone])), [
      ['a'],
    ]);
    expect(spaceRowKeyOf(lone), 'space:a');
  });

  test('a pair is one row, production first, keyed by the pair', () {
    final rows = pairSides([
      _side('dev-1', pair: 'p'),
      _side('solo'),
      _side('prod-1', pair: 'p', env: _prod),
    ]);
    expect(_ids(rows), [
      ['prod-1', 'dev-1'],
      ['solo'],
    ], reason: 'the pair keeps the place of its first side');
    expect(spaceRowKeyOf(rows.first.last), 'pair:p');
  });

  test('a pair whose production side is not mine is a row of development', () {
    final rows = pairSides([_side('dev-1', pair: 'p'), _side('other')]);
    expect(_ids(rows), [
      ['dev-1'],
      ['other'],
    ]);
    expect(rows.first.single.env.isProduction, isFalse);
  });

  test('a workspace pairs by the same rule as a linked space', () {
    Workspace ws(String id, String env) => Workspace(
      id: id,
      name: id,
      countryCode: 'FR',
      currencyCode: 'EUR',
      timezone: 'Europe/Paris',
      inviteCode: 'X',
      pairId: 'p',
      environment: env,
    );
    final rows = pairSides([ws('d', 'dev'), ws('p', 'prod')]);
    expect(_ids(rows), [
      ['p', 'd'],
    ]);
    expect(
      spaceRowKeyOf(rows.single.first),
      spaceRowKeyOf(_side('x', pair: 'p')),
    );
  });
}
