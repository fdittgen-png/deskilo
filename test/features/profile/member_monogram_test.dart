// SPDX-License-Identifier: 0BSD
//
// #793 — the Membres list drew three identical `M` circles: Mathieu,
// mathieu.bouchard and marion.blein.gauthier all rendered as one letter,
// so the glyph shown for every member without a photo identified nobody.
//
// The rule: initials of the first and family name, a further letter of
// the family name when two would clash, numbers only when the letters
// run out.
import 'package:deskilo/features/profile/domain/member_monogram.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the ladder one name would like', () {
    test('two names give the two initials, then grow through the family',
        () {
      expect(
        monogramLadder('mathieu.bouchard'),
        ['MB', 'MBO'],
      );
    });

    test('a lone name has no family name — it grows through itself', () {
      expect(monogramLadder('Guilhem'), ['G', 'GU', 'GUI']);
    });

    test('the LAST token is the family name, whatever is in between', () {
      // marion.blein.gauthier → Marion Gauthier.
      expect(monogramLadder('marion.blein.gauthier').first, 'MG');
    });

    test('spaces, dots, hyphens and underscores all separate a name', () {
      for (final written in [
        'Marion Gauthier',
        'marion.gauthier',
        'marion-gauthier',
        'marion_gauthier',
      ]) {
        expect(monogramLadder(written).first, 'MG', reason: written);
      }
    });

    test('digits in a handle are kept — flo1 is a name people type', () {
      expect(monogramLadder('flo1'), ['F', 'FL', 'FLO']);
    });

    test('a nameless member still gets a glyph', () {
      expect(monogramLadder(''), ['?']);
      expect(plainInitial(''), '?');
    });
  });

  group('assignment across the workspace', () {
    test('the screenshot that started this: seven members, seven distinct '
        'monograms', () {
      final assigned = assignMonograms({
        'u-flo': 'Flo',
        'u-flo1': 'flo1',
        'u-flo2': 'Flo2',
        'u-guilhem': 'Guilhem',
        'u-marion': 'marion.blein.gauthier',
        'u-mathieu': 'Mathieu',
        'u-bouchard': 'mathieu.bouchard',
      });

      expect(assigned.values.toSet(), hasLength(assigned.length),
          reason: 'every member must be told apart by their circle');
      // The three that used to collide on M:
      expect(assigned['u-mathieu'], 'M');
      expect(assigned['u-bouchard'], 'MB');
      expect(assigned['u-marion'], 'MG');
      // …and the three that used to collide on F. Flo has no family
      // name, so it grows through its own letters.
      expect(assigned['u-flo'], 'F');
      expect(assigned['u-flo1'], 'FL');
      expect(assigned['u-flo2'], 'FLO');
      expect(assigned['u-guilhem'], 'G');
    });

    test('numbers take over only once the letters are exhausted', () {
      // Four people who write their name identically: the ladder gives
      // MB and MBO, then counting begins — from the FIRST choice, so the
      // numbered ones still read as the family they belong to.
      final assigned = assignMonograms({
        'a': 'mathieu.bouchard',
        'b': 'mathieu.bouchard',
        'c': 'mathieu.bouchard',
        'd': 'mathieu.bouchard',
      });
      expect(assigned.values.toSet(), {'MB', 'MBO', 'MB2', 'MB3'});
    });

    test('the answer does not depend on the order the map was built in',
        () {
      const names = {
        'u-mathieu': 'Mathieu',
        'u-bouchard': 'mathieu.bouchard',
        'u-marion': 'marion.blein.gauthier',
      };
      final forwards = assignMonograms(names);
      final backwards = assignMonograms({
        for (final key in names.keys.toList().reversed) key: names[key]!,
      });
      // Two devices rendering the same workspace must agree, and a row
      // rebuilding must not reshuffle who owns which letters.
      expect(forwards, backwards);
    });

    test('a member whose ladder does not clash is left alone', () {
      // Adding Guilhem cannot move Mathieu's letter: only colliding
      // ladders are ever resolved against each other.
      final before = assignMonograms({'u-m': 'Mathieu'});
      final after =
          assignMonograms({'u-m': 'Mathieu', 'u-g': 'Guilhem'});
      expect(after['u-m'], before['u-m']);
    });
  });

  group('#793 — first come, first served', () {
    test('a later joiner never takes an earlier member\'s letters', () {
      // "Ana" sorts before "Bob", but Bob was here first. Sorting by name
      // would have handed Ana the M and pushed Bob to a longer form.
      const names = {'u-bob': 'Mathieu', 'u-ana': 'Mathieu'};
      final assigned = assignMonograms(names, order: {
        'u-bob': DateTime.utc(2024),
        'u-ana': DateTime.utc(2026),
      });
      expect(assigned['u-bob'], 'M');
      expect(assigned['u-ana'], isNot('M'));
    });

    test('adding a member does not move anyone already there', () {
      const before = {'u-1': 'Mathieu'};
      final order = {
        'u-1': DateTime.utc(2024) as DateTime?,
        'u-2': DateTime.utc(2026) as DateTime?,
      };
      final first = assignMonograms(before, order: order);
      final after = assignMonograms(
        {...before, 'u-2': 'Mathieu'},
        order: order,
      );
      expect(after['u-1'], first['u-1'],
          reason: 'an existing member keeps the circle they already had');
    });

    test('a member with a known join beats one without', () {
      final assigned = assignMonograms(
        const {'u-known': 'Mathieu', 'u-unknown': 'Mathieu'},
        order: {'u-known': DateTime.utc(2025), 'u-unknown': null},
      );
      expect(assigned['u-known'], 'M');
    });

    test('with no order at all it still resolves, deterministically', () {
      const names = {'u-b': 'Mathieu', 'u-a': 'Mathieu'};
      expect(assignMonograms(names), assignMonograms(names));
      expect(assignMonograms(names).values.toSet(), hasLength(2));
    });
  });
}
