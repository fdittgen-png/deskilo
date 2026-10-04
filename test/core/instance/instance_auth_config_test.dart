// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The auth patch every instance gets: linking a Google (or other) account
// from Settings needs gotrue's manual linking switched on.
import 'package:deskilo/core/instance/instance_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the auth patch turns manual identity linking on', () {
    expect(InstanceAuthConfig.patch['security_manual_linking_enabled'], true);
    expect(InstanceAuthConfig.patch['mailer_autoconfirm'], false);
  });
}
