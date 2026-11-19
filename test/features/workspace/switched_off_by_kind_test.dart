// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3547 — a feature the business's primary kind keeps off is its choice, not
// setup left to do. The primary kind decides, as it does when the kind is
// chosen; a further kind and a kind that is silent change nothing.
import 'package:deskilo/features/workspace/domain/business_kind.dart';
import 'package:deskilo/features/workspace/domain/business_profile.dart';
import 'package:deskilo/features/workspace/domain/switched_off_by_kind.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

const _kinds = [
  BusinessKind(code: 'coworking', sortOrder: 10),
  BusinessKind(
    code: 'practice',
    sortOrder: 30,
    profile: {'placeBooking': false, 'services': true},
  ),
  BusinessKind(
    code: 'studio',
    sortOrder: 20,
    profile: {'placeBooking': true, 'services': true},
  ),
];

bool _off(BusinessProfile profile, [WorkspaceFeature? f]) =>
    switchedOffByKind(f ?? WorkspaceFeature.placeBooking, profile, _kinds);

void main() {
  test('a kind whose profile proposes the places off keeps them off', () {
    expect(_off(const BusinessProfile(kind: 'practice')), isTrue);
  });

  test('a kind that proposes the places on, or says nothing about them, '
      'keeps nothing off', () {
    expect(_off(const BusinessProfile(kind: 'studio')), isFalse);
    expect(_off(const BusinessProfile(kind: 'coworking')), isFalse);
  });

  test('a feature the practice proposes on is not kept off', () {
    expect(
      _off(const BusinessProfile(kind: 'practice'), WorkspaceFeature.services),
      isFalse,
    );
  });

  test(
    'the primary kind decides: a coworking space that also runs a '
    'practice keeps its places, a practice that also lets desks does not',
    () {
      expect(
        _off(const BusinessProfile(kind: 'coworking', moreKinds: ['practice'])),
        isFalse,
      );
      expect(
        _off(const BusinessProfile(kind: 'practice', moreKinds: ['coworking'])),
        isTrue,
      );
    },
  );

  test('a kind the registry does not list keeps nothing off', () {
    expect(_off(const BusinessProfile(kind: 'unheard-of')), isFalse);
    expect(
      switchedOffByKind(
        WorkspaceFeature.placeBooking,
        const BusinessProfile(kind: 'practice'),
        const [],
      ),
      isFalse,
    );
  });
}
