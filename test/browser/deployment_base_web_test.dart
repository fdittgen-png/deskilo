// SPDX-License-Identifier: AGPL-3.0-or-later
@TestOn('browser')
library;

import 'package:deskilo/core/backend/auth_callback_guard.dart';
import 'package:deskilo/core/instance/deployment_base_web.dart';
import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:deskilo/core/instance/instance_bundle_asset.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/web.dart' as web;

import '../helpers/installation_auth_storage.dart' show MemorySecrets;

void main() {
  test('first-start and fragment routes use the deployed base href', () {
    final existing = web.document.querySelector('base[href]');
    final base = existing ?? web.document.createElement('base');
    final previousHref = base.getAttribute('href');
    final previousLocation = web.window.location.href;
    final previousGuard = bootAuthCallbackGuard;
    bootAuthCallbackGuard = null;
    if (existing == null) web.document.head!.appendChild(base);
    addTearDown(() {
      bootAuthCallbackGuard = previousGuard;
      web.window.history.replaceState(null, '', previousLocation);
      if (existing == null) {
        base.remove();
      } else {
        base.setAttribute('href', previousHref!);
      }
    });
    base.setAttribute('href', '/app/');
    web.window.history.replaceState(null, '', '/app/?flow=temporary#/auth/reset');
    final deployment = deploymentBaseUri()!;
    final patch = InstanceAuthConfig.patchForWebBase(deployment);
    expect(deployment.path, '/app/');
    expect(patch['site_url'], '${deployment.origin}/app/');
    expect(patch['uri_allow_list'], 'deskilo://**,${deployment.origin}/app/**');
    expect(instanceAuthPatchForRuntime(), patch);
    bootAuthCallbackGuard = AuthCallbackGuard(
      MemorySecrets(), Uri.parse('https://backend.example.test'),
      Uri.parse('${deployment.origin}/custom/?deskilo_flow=old#route'),
    );
    expect(instanceAuthPatchForRuntime()['site_url'], '${deployment.origin}/custom/');
    expect(instanceAuthPatchForRuntime()['uri_allow_list'],
        'deskilo://**,${deployment.origin}/custom/**');
    bootAuthCallbackGuard = null;
    web.window.history.replaceState(null, '', '/app/other-route#/another');
    expect(deploymentBaseUri(), deployment);
    for (final invalid in ['', 'relative/', '//other.example/', 'https://[']) {
      base.setAttribute('href', invalid);
      expect(deploymentBaseUri, throwsA(isA<StateError>().having(
          (error) => error.message, 'message', contains('configure the build base href'))));
    }
    base.remove();
    expect(deploymentBaseUri, throwsA(isA<StateError>().having(
          (error) => error.message, 'message', contains('configure the build base href'))));
    web.document.head!.appendChild(base);
  });
}
