// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — the route policy has a fixed point everywhere: for every
// registered route under every combination of facts, following the hops
// settles on a location the policy does not redirect again. A redirect
// that lands on a location the policy would bounce is a loop by another
// name, and a table of hand-picked rows would only see the loops
// somebody thought of. The rows themselves come with the router
// delegation in the next checkpoint.
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/app/route_policy.dart';
import 'package:deskilo/core/instance/schema_compatibility.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

bool _wizardOff(WorkspaceFeature f) => f != WorkspaceFeature.instanceWizard;

void main() {
  test('every route settles under every combination of facts', () {
    var checked = 0;
    for (final rule in routeRules) {
      final path = rule.pattern.replaceAll(RegExp(r':[a-zA-Z]+'), 'x');
      for (final auth in AuthFact.values) {
        for (final privacy in PrivacyFact.values) {
          for (final workspaces in WorkspacesFact.values) {
            for (final membership in MembershipFact.values) {
              for (final kiosk in KioskFact.values) {
                for (final schema in SchemaCompatibility.values) {
                  final facts = RouteFacts(
                    auth: auth,
                    privacy: privacy,
                    workspaces: workspaces,
                    membership: membership,
                    kiosk: kiosk,
                    schema: schema,
                    featureEnabled: _wizardOff,
                  );
                  final request = RouteRequest.parse(path);
                  final settled = settleDestination(request, facts);
                  expect(settled.reason, isNot(RouteReason.loopAverted),
                      reason: '$path under $auth/$privacy/$workspaces/'
                          '$membership/$kiosk/$schema loops');
                  final landing = settled.redirect ?? path;
                  expect(
                    resolveDestination(RouteRequest.parse(landing), facts)
                        .redirect,
                    isNull,
                    reason: '$landing is redirected again under $auth/'
                        '$privacy/$workspaces/$membership/$kiosk/$schema',
                  );
                  checked++;
                }
              }
            }
          }
        }
      }
    }
    expect(checked, routeRules.length * 5 * 4 * 4 * 5 * 4 * 4);
  });

  test('a loop is averted by staying, and says so', () {
    // No registered facts produce one; the guard is exercised on a
    // request whose only hop leads back to itself by construction.
    final decision = settleDestination(
      const RouteRequest('/auth'),
      const RouteFacts(auth: AuthFact.signedIn, home: '/auth'),
    );
    expect(decision.stays, isTrue);
    expect(decision.reason, RouteReason.loopAverted);
  });

  test('resolution reads its arguments and nothing else', () {
    // The only callback the facts carry is the feature predicate; a
    // resolution that never asks a feature question leaves it untouched,
    // and one that does asks it — there is no other seam to write through.
    var asked = 0;
    bool counting(WorkspaceFeature _) {
      asked++;
      return true;
    }

    resolveDestination(
      const RouteRequest('/reserve'),
      RouteFacts(auth: AuthFact.signedIn, featureEnabled: counting),
    );
    expect(asked, 0);
    resolveDestination(
      const RouteRequest('/server/new-instance'),
      RouteFacts(auth: AuthFact.signedIn, featureEnabled: counting),
    );
    expect(asked, 1);
  });
}
