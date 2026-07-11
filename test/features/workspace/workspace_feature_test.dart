// SPDX-License-Identifier: MIT
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every feature ships ON except adminSeatBlocking (#161), which the
/// owner must explicitly delegate.
final Set<WorkspaceFeature> registryDefaults =
    WorkspaceFeature.values.toSet()
      ..remove(WorkspaceFeature.adminSeatBlocking);

void main() {
  test('manifest covers every feature; only adminSeatBlocking defaults OFF',
      () {
    expect(featureManifest.keys, containsAll(WorkspaceFeature.values));
    for (final entry in featureManifest.values) {
      expect(
        entry.defaultOn,
        entry.feature != WorkspaceFeature.adminSeatBlocking,
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

  test('a stored true override enables the default-OFF feature (#161)', () {
    final enabled =
        resolveEnabledFeatures(const {'adminSeatBlocking': true});

    expect(enabled.contains(WorkspaceFeature.adminSeatBlocking), isTrue);
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
}
