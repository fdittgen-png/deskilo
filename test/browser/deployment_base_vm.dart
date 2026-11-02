// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_bundle_asset.dart';
import 'package:flutter_test/flutter_test.dart';

void runDeploymentBaseTests() {
  test('native runtime retains the legacy target and callback scheme', () {
    expect(instanceAuthPatchForRuntime(), InstanceAuthConfig.patch);
    expect(InstanceAuthConfig.patch['uri_allow_list'], startsWith('deskilo://**,'));
  });
  test('explicit web base is scoped and drops transient flow data', () {
    final patch = InstanceAuthConfig.patchForWebBase(
      Uri.parse('https://example.test/app/?flow=temporary#/deep'),
    );
    expect(patch['site_url'], 'https://example.test/app/');
    expect(patch['uri_allow_list'], 'deskilo://**,https://example.test/app/**');
  });
}
