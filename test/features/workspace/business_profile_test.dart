// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3549 — a workspace's business kind, as its settings say.
import 'package:deskilo/features/workspace/domain/business_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no settings (an older server) read as a coworking space', () {
    final p = BusinessProfile.fromSettings(null);
    expect(p.kind, 'coworking');
    expect(p.moreKinds, isEmpty);
    expect(p.kinds, ['coworking']);
  });

  test('the primary kind comes first; a further kind never repeats it', () {
    const p = BusinessProfile(kind: 'practice', moreKinds: ['studio']);
    expect(p.kinds, ['practice', 'studio']);
    expect(p.isA('studio'), isTrue);
    expect(p.isA('salon'), isFalse);
  });
}
