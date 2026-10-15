// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — core/help and core/privacy ask about features by key. The keys
// are the features', the unwired defaults are the registry's, and the
// scopes that wire the set (server choice, demo) answer as the enum did.
import 'package:deskilo/app/server_choice_app.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/features/enabled_feature_keys.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the keys core asks about are the features\' own', () {
    expect(formHelpHintsKey, WorkspaceFeature.formHelpHints.dbKey);
    expect(recordingPrivacyKey, WorkspaceFeature.recordingPrivacy.dbKey);
  });

  test('unwired, a question is answered with the registry default', () {
    final defaults = resolveEnabledFeatures(const {});
    expect(
      featureOn(null, formHelpHintsKey, byDefault: true),
      defaults.contains(WorkspaceFeature.formHelpHints),
    );
    expect(
      featureOn(null, recordingPrivacyKey, byDefault: false),
      defaults.contains(WorkspaceFeature.recordingPrivacy),
    );
  });

  test('the server-choice scope answers as the enum did', () {
    final container = ProviderContainer(
      overrides: [
        enabledFeaturesSyncProvider.overrideWithValue(
          ServerChoiceApp.features,
        ),
        enabledFeatureKeysFromWorkspace,
      ],
    );
    addTearDown(container.dispose);
    final keys = container.read(enabledFeatureKeysProvider)!;
    expect(keys, {for (final f in ServerChoiceApp.features) f.dbKey});
    expect(keys.contains(formHelpHintsKey), isFalse);
  });

  test('the demo scope wires the set from its own workspace', () {
    final container = ProviderContainer(
      overrides: demoOverrides(DemoFixture.build()),
    );
    addTearDown(container.dispose);
    expect(container.read(enabledFeatureKeysProvider), isNotNull);
  });
}
