// SPDX-License-Identifier: 0BSD
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

/// The features the owner must explicitly activate: adminSeatBlocking
/// (#161), accessorySupplements (#170), onlinePayments (0043), and the
/// level-booking pair (0050).
const Set<WorkspaceFeature> defaultOffFeatures = {
  WorkspaceFeature.adminSeatBlocking,
  WorkspaceFeature.accessorySupplements,
  WorkspaceFeature.onlinePayments,
  WorkspaceFeature.levelBooking,
  WorkspaceFeature.adminLevelAssign,
};

/// Every other feature ships ON.
final Set<WorkspaceFeature> registryDefaults =
    WorkspaceFeature.values.toSet()..removeAll(defaultOffFeatures);

void main() {
  test(
      'manifest covers every feature; only adminSeatBlocking, '
      'accessorySupplements, onlinePayments, levelBooking and '
      'adminLevelAssign default OFF', () {
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
      '(#161, #170, 0043, 0050)', () {
    final enabled = resolveEnabledFeatures(const {
      'adminSeatBlocking': true,
      'accessorySupplements': true,
      'onlinePayments': true,
      'levelBooking': true,
      'adminLevelAssign': true,
    });

    expect(enabled.contains(WorkspaceFeature.adminSeatBlocking), isTrue);
    expect(enabled.contains(WorkspaceFeature.accessorySupplements), isTrue);
    expect(enabled.contains(WorkspaceFeature.onlinePayments), isTrue);
    expect(enabled.contains(WorkspaceFeature.levelBooking), isTrue);
    expect(enabled.contains(WorkspaceFeature.adminLevelAssign), isTrue);
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
}
