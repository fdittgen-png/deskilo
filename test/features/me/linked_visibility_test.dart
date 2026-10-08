// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2211 (4) — who sees me on my other servers. Each connected server has
// its own account for me, so what people there see is set there: the
// card lists every connected server, the sheet reads that server's
// my_visibility, a change is written with that server's set_visibility,
// and the caps hold — contact details never offer every signed-in person,
// and chosen spaces are not offered for another server. A server that
// does not answer says so instead of showing defaults.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/features/me/domain/visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _other = 'https://coworkonti.example';

ConnectedInstallation _linked(String url) => ConnectedInstallation(
  endpoint: BackendEndpoint(url, 'sb_publishable_other'),
  account: 'remote-user',
  installationId: 'inst-$url',
);

Future<void> _openSheet(WidgetTester tester) async {
  await tapIn(
    tester,
    'me-account-list',
    find.byKey(const ValueKey('linked-visibility-coworkonti.example')),
  );
}

void main() {
  testWidgets('no connected server, no card', (tester) async {
    final router = await pumpMeApp(tester, me: FakeMeRepository());
    await goTo(tester, router, '/me?tab=me');
    expect(
      find.byKey(const ValueKey('me-linked-visibility-card')),
      findsNothing,
    );
  });

  testWidgets('a change is written on that server, within the caps', (
    tester,
  ) async {
    final me = FakeMeRepository();
    final router = await pumpMeApp(
      tester,
      me: me,
      connectedSources: [_linked(_other)],
    );
    await goTo(tester, router, '/me?tab=me');
    await _openSheet(tester);

    // Contact details: no "every signed-in person", no chosen spaces.
    await tester.tap(
      find.byKey(const ValueKey('linked-visibility-field-contact_channels')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('linked-visibility-audience-signed_in')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('linked-visibility-audience-chosen_spaces')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('linked-visibility-audience-my_spaces')),
    );
    await tester.pumpAndSettle();
    // Widening asks first, then the server holds the new audience.
    await tester.tap(find.byKey(const ValueKey('visibility-widen-confirm')));
    await tester.pumpAndSettle();
    expect(
      me.linkedVisibility[_other]!.of(VisibilityField.contactChannels).audience,
      VisibilityAudience.mySpaces,
    );
    // Home is untouched.
    expect(
      (await me.myVisibility()).of(VisibilityField.contactChannels).audience,
      VisibilityAudience.nobody,
    );

    // Name and photo may go to every signed-in person there.
    await tester.tap(
      find.byKey(const ValueKey('linked-visibility-field-identity')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('linked-visibility-audience-signed_in')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('visibility-widen-confirm')));
    await tester.pumpAndSettle();
    expect(
      me.linkedVisibility[_other]!.of(VisibilityField.identity).audience,
      VisibilityAudience.signedIn,
    );
  });

  testWidgets('a server that does not answer says so', (tester) async {
    final me = FakeMeRepository()..unavailable.add(_other);
    final router = await pumpMeApp(
      tester,
      me: me,
      connectedSources: [_linked(_other)],
    );
    await goTo(tester, router, '/me?tab=me');
    await _openSheet(tester);
    expect(
      find.byKey(const ValueKey('linked-visibility-unavailable')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('linked-visibility-field-identity')),
      findsNothing,
    );
  });
}
