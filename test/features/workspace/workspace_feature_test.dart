// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

/// The features the owner must explicitly activate: adminSeatBlocking
/// (#161), accessorySupplements (#170), onlinePayments (0043), the
/// level-booking pair (0050), the invoice delegation (0060) and badge
/// sign-in (#662).
///
/// The list is short on purpose, and every entry earns its place by
/// being a decision only the owner can make — delegating an admin
/// power, charging money, or (badgeSignIn) turning a shared tablet into
/// a login surface. Shipping any of those ON would make the choice for
/// them silently.
const Set<WorkspaceFeature> defaultOffFeatures = {
  WorkspaceFeature.adminSeatBlocking,
  WorkspaceFeature.accessorySupplements,
  WorkspaceFeature.onlinePayments,
  WorkspaceFeature.levelBooking,
  WorkspaceFeature.adminLevelAssign,
  WorkspaceFeature.adminInvoicing,
  WorkspaceFeature.autoCheckInOut,
  WorkspaceFeature.badgeSignIn,
};

/// Every other feature ships ON.
final Set<WorkspaceFeature> registryDefaults =
    WorkspaceFeature.values.toSet()..removeAll(defaultOffFeatures);

void main() {
  test(
      'manifest covers every feature; only adminSeatBlocking, '
      'accessorySupplements, onlinePayments, levelBooking, '
      'adminLevelAssign, adminInvoicing, autoCheckInOut and badgeSignIn '
      'default OFF', () {
    expect(featureManifest.keys, containsAll(WorkspaceFeature.values));
    for (final entry in featureManifest.values) {
      expect(
        entry.defaultOn,
        !defaultOffFeatures.contains(entry.feature),
        reason: '${entry.feature} default',
      );
    }
  });

  test('empty flags resolve to all registry defaults', () {
    expect(resolveEnabledFeatures(const {}), registryDefaults);
  });

  test('a stored false override disables exactly that feature', () {
    final enabled = resolveEnabledFeatures(const {'moneyTab': false});

    expect(enabled.contains(WorkspaceFeature.moneyTab), isFalse);
    expect(
      enabled,
      registryDefaults.toSet()..remove(WorkspaceFeature.moneyTab),
    );
  });

  test('a stored true override enables the default-OFF features '
      '(#161, #170, 0043, 0050, 0060, #662)', () {
    final enabled = resolveEnabledFeatures(const {
      'adminSeatBlocking': true,
      'accessorySupplements': true,
      'onlinePayments': true,
      'levelBooking': true,
      'adminLevelAssign': true,
      'adminInvoicing': true,
      'autoCheckInOut': true,
      'badgeSignIn': true,
    });

    expect(enabled.contains(WorkspaceFeature.adminSeatBlocking), isTrue);
    expect(enabled.contains(WorkspaceFeature.accessorySupplements), isTrue);
    expect(enabled.contains(WorkspaceFeature.onlinePayments), isTrue);
    expect(enabled.contains(WorkspaceFeature.levelBooking), isTrue);
    expect(enabled.contains(WorkspaceFeature.adminLevelAssign), isTrue);
    expect(enabled.contains(WorkspaceFeature.adminInvoicing), isTrue);
    expect(enabled.contains(WorkspaceFeature.autoCheckInOut), isTrue);
    expect(enabled.contains(WorkspaceFeature.badgeSignIn), isTrue);
    // Every default-OFF feature turned on = the whole registry. If this
    // set ever falls short, a feature was added without a home in
    // defaultOffFeatures above.
    expect(enabled, WorkspaceFeature.values.toSet());
  });

  test('an explicit true override keeps the feature on', () {
    final enabled = resolveEnabledFeatures(
      const {'calendarTab': true, 'services': false},
    );

    expect(enabled.contains(WorkspaceFeature.calendarTab), isTrue);
    expect(enabled.contains(WorkspaceFeature.services), isFalse);
  });

  test('unknown keys and non-boolean values are ignored', () {
    final enabled = resolveEnabledFeatures(const {
      'hologramDesk': false, // a future client's flag
      'pdfExport': 'nope', // malformed value
      'eventsTab': false,
    });

    expect(enabled.contains(WorkspaceFeature.pdfExport), isTrue);
    expect(enabled.contains(WorkspaceFeature.eventsTab), isFalse);
    expect(
      enabled,
      registryDefaults.toSet()..remove(WorkspaceFeature.eventsTab),
    );
  });

  group('feature hierarchy (effectiveFeatures)', () {
    test('a child is EFFECTIVE only while its parent is on', () {
      final raw = resolveEnabledFeatures(const {
        'kioskMode': false,
      });
      // nfcBadges stays in the RAW set (its own flag defaults on)…
      expect(raw.contains(WorkspaceFeature.nfcBadges), isTrue);
      // …but drops from the EFFECTIVE set with its parent.
      final effective = effectiveFeatures(raw);
      expect(effective.contains(WorkspaceFeature.kioskMode), isFalse);
      expect(effective.contains(WorkspaceFeature.nfcBadges), isFalse);
    });

    test('money children ride the money tab', () {
      final effective = effectiveFeatures(resolveEnabledFeatures(const {
        'moneyTab': false,
        'services': true,
        'onlinePayments': true,
      }));
      expect(effective.contains(WorkspaceFeature.services), isFalse);
      expect(effective.contains(WorkspaceFeature.onlinePayments), isFalse);
    });

    test('the stored child choice SURVIVES a parent off/on cycle', () {
      // Parent off: child ineffective but still raw-on.
      final off = resolveEnabledFeatures(const {
        'membersDirectory': false,
        'whatsappIntegration': true,
      });
      expect(off.contains(WorkspaceFeature.whatsappIntegration), isTrue);
      // Parent back on: the child returns exactly as stored.
      final on = effectiveFeatures(resolveEnabledFeatures(const {
        'membersDirectory': true,
        'whatsappIntegration': true,
      }));
      expect(on.contains(WorkspaceFeature.whatsappIntegration), isTrue);
    });

    test('every declared dependency points at a registered feature and '
        'the graph has no cycles', () {
      for (final entry in featureManifest.values) {
        var current = entry.requires;
        final seen = <WorkspaceFeature>{entry.feature};
        while (current != null) {
          expect(featureManifest.containsKey(current), isTrue);
          expect(seen.add(current), isTrue,
              reason: 'dependency cycle at ${entry.feature}');
          current = featureManifest[current]!.requires;
        }
      }
    });
  });

  group('#800 — dependencies activate with the feature that needs them', () {
    test('the requirement chain reads upwards, nearest parent first', () {
      // badgeSignIn needs nfcBadges, which needs kioskMode.
      expect(
        requirementChain(WorkspaceFeature.badgeSignIn),
        [WorkspaceFeature.nfcBadges, WorkspaceFeature.kioskMode],
      );
      expect(requirementChain(WorkspaceFeature.moneyTab), isEmpty);
    });

    test('switching a deep child ON brings its whole chain', () {
      final flags = featureFlagsAfterToggle(
        raw: const <WorkspaceFeature>{},
        feature: WorkspaceFeature.badgeSignIn,
        value: true,
      );
      expect(flags[WorkspaceFeature.badgeSignIn], isTrue);
      expect(flags[WorkspaceFeature.nfcBadges], isTrue);
      expect(flags[WorkspaceFeature.kioskMode], isTrue);
      // Nothing ELSE is touched: a cascade goes up, never sideways.
      expect(flags[WorkspaceFeature.moneyTab], isFalse);
    });

    test('switching a parent OFF keeps its dependants stored', () {
      // They are already ineffective; erasing the choices would make the
      // owner rebuild the subtree by hand after switching the parent on.
      final flags = featureFlagsAfterToggle(
        raw: const {
          WorkspaceFeature.kioskMode,
          WorkspaceFeature.nfcBadges,
          WorkspaceFeature.badgeSignIn,
        },
        feature: WorkspaceFeature.kioskMode,
        value: false,
      );
      expect(flags[WorkspaceFeature.kioskMode], isFalse);
      expect(flags[WorkspaceFeature.nfcBadges], isTrue);
      expect(effectiveFeatures(
        {for (final e in flags.entries) if (e.value) e.key},
      ), isNot(contains(WorkspaceFeature.nfcBadges)));
    });

    test('the UI can name what a switch would bring with it', () {
      expect(
        alsoEnabledWith(
          raw: const {WorkspaceFeature.kioskMode},
          feature: WorkspaceFeature.badgeSignIn,
        ),
        [WorkspaceFeature.nfcBadges],
      );
      expect(
        alsoEnabledWith(
          raw: const {WorkspaceFeature.kioskMode, WorkspaceFeature.nfcBadges},
          feature: WorkspaceFeature.badgeSignIn,
        ),
        isEmpty,
      );
    });

    test('dependants of a feature are its whole subtree', () {
      final money = dependentFeatures(WorkspaceFeature.moneyTab);
      expect(money, contains(WorkspaceFeature.invoicing));
      // Grandchildren too — dunning hangs off invoicing.
      expect(money, contains(WorkspaceFeature.dunning));
      expect(money, contains(WorkspaceFeature.paymentReminders));
    });

    test('the money features hang off the Finances tab, none stranded', () {
      // #800 — these three read finances and were roots, so an owner
      // could switch the Finances tab off and leave them "on".
      for (final feature in [
        WorkspaceFeature.financeFaces,
        WorkspaceFeature.memberReports,
        WorkspaceFeature.dataAccessLog,
      ]) {
        expect(requirementChain(feature), contains(WorkspaceFeature.moneyTab),
            reason: '${feature.name} needs the Finances tab');
      }
    });

    test('no feature requires itself, directly or through a cycle', () {
      for (final feature in WorkspaceFeature.values) {
        expect(requirementChain(feature), isNot(contains(feature)),
            reason: feature.name);
      }
    });
  });
}
