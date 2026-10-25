// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2494 / #2603 -- which switches the Features screen lists, as a table on
// the decision (no taps): a query finds a row by its name, its description
// or its "Requires" line, case-insensitively; "Changed" keeps the rows whose
// stored state is not their default; the maturity filter drops rows; the
// Changed count is every row that moved, whatever the filters.
import 'package:deskilo/features/workspace/domain/feature_switch_rows.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

const _calendar = FeatureManifestEntry(
  feature: WorkspaceFeature.calendarTab,
  tier: FeatureTier.core,
  surface: FeatureSurface.calendar,
);
const _badge = FeatureManifestEntry(
  feature: WorkspaceFeature.badgeSignIn,
  tier: FeatureTier.core,
  surface: FeatureSurface.reserve,
  defaultOn: false,
  requires: WorkspaceFeature.nfcBadges,
);
const _money = FeatureManifestEntry(
  feature: WorkspaceFeature.moneyTab,
  tier: FeatureTier.core,
  surface: FeatureSurface.money,
);

const _manifest = [_calendar, _badge, _money];

const _text = <WorkspaceFeature, FeatureRowText>{
  WorkspaceFeature.calendarTab: (
    name: 'Calendar tab',
    description: 'Shows closed days and events',
    requires: null,
  ),
  WorkspaceFeature.badgeSignIn: (
    name: 'Sign in with a badge',
    description: 'A card opens the app',
    requires: 'Requires RFID / NFC badges',
  ),
  WorkspaceFeature.moneyTab: (
    name: 'Money tab',
    description: 'Invoices and payments',
    requires: null,
  ),
};

/// The rows shown, by feature, for one combination of the filters.
List<WorkspaceFeature> _shown({
  Set<WorkspaceFeature> raw = const {
    WorkspaceFeature.calendarTab,
    WorkspaceFeature.moneyTab,
  },
  String query = '',
  bool changedOnly = false,
  Set<WorkspaceFeature> immature = const {},
}) => [
  for (final entry in featureSwitchRows(
    _manifest,
    raw: raw,
    query: query,
    changedOnly: changedOnly,
    maturityMatches: (entry) => !immature.contains(entry.feature),
    textOf: (entry) => _text[entry.feature]!,
  ).rows)
    entry.feature,
];

void main() {
  group('which rows a query finds', () {
    final table = <String, (String, List<WorkspaceFeature>)>{
      'no query lists every row, in manifest order': (
        '',
        [
          WorkspaceFeature.calendarTab,
          WorkspaceFeature.badgeSignIn,
          WorkspaceFeature.moneyTab,
        ],
      ),
      'a part of the name': ('sign in with', [WorkspaceFeature.badgeSignIn]),
      'the name in another case': ('MONEY', [WorkspaceFeature.moneyTab]),
      'a word only the description holds': (
        'closed days',
        [WorkspaceFeature.calendarTab],
      ),
      'a word only the Requires line holds': (
        'nfc badges',
        [WorkspaceFeature.badgeSignIn],
      ),
      'a word every row holds': (
        'a',
        [
          WorkspaceFeature.calendarTab,
          WorkspaceFeature.badgeSignIn,
          WorkspaceFeature.moneyTab,
        ],
      ),
      'nothing matching': ('zzzznope', []),
    };
    for (final MapEntry(key: name, value: (query, shown)) in table.entries) {
      test(name, () => expect(_shown(query: query), shown));
    }
  });

  group('Changed and maturity', () {
    test('Changed keeps a default-off row that is on', () {
      expect(
        _shown(
          raw: const {
            WorkspaceFeature.calendarTab,
            WorkspaceFeature.badgeSignIn,
            WorkspaceFeature.moneyTab,
          },
          changedOnly: true,
        ),
        [WorkspaceFeature.badgeSignIn],
      );
    });

    test('Changed keeps a default-on row that is off', () {
      expect(
        _shown(raw: const {WorkspaceFeature.calendarTab}, changedOnly: true),
        [WorkspaceFeature.moneyTab],
      );
    });

    test('Changed at the defaults shows nothing', () {
      expect(_shown(changedOnly: true), isEmpty);
    });

    test('Changed and a query narrow together', () {
      expect(
        _shown(
          raw: const {WorkspaceFeature.badgeSignIn},
          changedOnly: true,
          query: 'money',
        ),
        [WorkspaceFeature.moneyTab],
      );
    });

    test('the maturity filter drops its rows', () {
      expect(
        _shown(immature: const {WorkspaceFeature.calendarTab}),
        [WorkspaceFeature.badgeSignIn, WorkspaceFeature.moneyTab],
      );
    });
  });

  group('the Changed count', () {
    test('counts every row away from its default, whatever is filtered', () {
      final result = featureSwitchRows(
        _manifest,
        raw: const {WorkspaceFeature.badgeSignIn},
        query: 'zzzznope',
        changedOnly: true,
        maturityMatches: (_) => false,
        textOf: (entry) => _text[entry.feature]!,
      );
      expect(result.rows, isEmpty);
      // badgeSignIn on (default off), calendarTab and moneyTab off (default on).
      expect(result.changedCount, 3);
    });

    test('is zero at the defaults', () {
      final result = featureSwitchRows(
        _manifest,
        raw: const {WorkspaceFeature.calendarTab, WorkspaceFeature.moneyTab},
        query: '',
        changedOnly: false,
        maturityMatches: (_) => true,
        textOf: (entry) => _text[entry.feature]!,
      );
      expect(result.changedCount, 0);
    });
  });

  test('the words are read only for rows the other filters keep', () {
    final read = <WorkspaceFeature>[];
    featureSwitchRows(
      _manifest,
      raw: const {WorkspaceFeature.calendarTab, WorkspaceFeature.moneyTab},
      query: 'x',
      changedOnly: false,
      maturityMatches: (entry) => entry.feature != WorkspaceFeature.moneyTab,
      textOf: (entry) {
        read.add(entry.feature);
        return _text[entry.feature]!;
      },
    );
    expect(read, [WorkspaceFeature.calendarTab, WorkspaceFeature.badgeSignIn]);
  });
}
