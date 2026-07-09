// SPDX-License-Identifier: MIT
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manifest covers every feature and everything defaults ON', () {
    expect(featureManifest.keys, containsAll(WorkspaceFeature.values));
    expect(featureManifest.values.every((e) => e.defaultOn), isTrue);
  });

  test('empty flags resolve to all registry defaults', () {
    expect(
      resolveEnabledFeatures(const {}),
      WorkspaceFeature.values.toSet(),
    );
  });

  test('a stored false override disables exactly that feature', () {
    final enabled = resolveEnabledFeatures(const {'moneyTab': false});

    expect(enabled.contains(WorkspaceFeature.moneyTab), isFalse);
    expect(
      enabled,
      WorkspaceFeature.values.toSet()..remove(WorkspaceFeature.moneyTab),
    );
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
    expect(enabled.length, WorkspaceFeature.values.length - 1);
  });
}
