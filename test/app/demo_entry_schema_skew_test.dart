// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3247 -- a build whose required schema is above the server's still opens
// the Demo entry (the Demo runs on no server), while every live route keeps
// going to the update notice. Booted as the whole app, not as the pure policy.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/mock_providers.dart';

void main() {
  for (final signedIn in [false, true]) {
    testWidgets(
      'schema behind, ${signedIn ? 'signed in' : 'signed out'}: the Demo '
      'entry and its older link open, the live routes go to the notice',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: standardTestOverrides(
              auth: signedIn ? FakeAuthRepository.signedIn() : null,
              schemaVersion: const FixedSchemaVersionSource(
                requiredSchemaVersion - 1,
              ),
            ),
            child: const DeskiloApp(),
          ),
        );
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        final context = tester.element(find.byType(Navigator).first);
        final router = ProviderScope.containerOf(context).read(routerProvider);
        Future<String> landed(String location) async {
          final match = await router.routeInformationParser
              .parseRouteInformationWithDependencies(
                RouteInformation(uri: Uri.parse(location)),
                context,
              );
          return match.uri.path;
        }

        expect(await landed('/demo'), '/demo');
        expect(await landed('/auth?demo=1&space=leipzig'), '/demo');
        expect(await landed('/reserve'), '/server-update');
        expect(await landed('/money'), '/server-update');
        expect(await landed('/auth'), '/server-update');
      },
    );
  }
}
