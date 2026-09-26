// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — the router's three continuation hooks, out of router.dart so
// the redirect closure stays the fact-collector it became in C3. Each
// is a deferred write of navigation state only: none touches a
// membership, a workspace, an MFA decision or a grant.
import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../features/auth/providers/auth_providers.dart';
import 'entry_intent.dart';
import 'entry_intents.dart';
import 'route_classes.dart';

/// A refresh makes GoRouter re-ask the top-level redirect about the LAST
/// REPORTED location, and the report lags the navigator by a frame.
/// While the providers settle after sign-in that is "where does /auth
/// go?" asked again and again from a screen the person has already
/// left — harmless while every answer was /reserve, and a way back to
/// /reserve once the answer depends on a continuation that is spent on
/// arrival. So before a refresh the router reports where the person IS,
/// the way the Router itself does after a frame.
void reportCurrentLocation(GoRouter router) {
  final config = router.routerDelegate.currentConfiguration;
  if (config.isEmpty) return;
  final current = router.routeInformationParser.restoreRouteInformation(config);
  if (current != null) {
    router.routeInformationProvider.routerReportsNewRouteInformation(current);
  }
}

/// A signed-out person's request is kept as the place to come back to —
/// when it validates, and when it is an ask rather than the default
/// location the app opens on. Off the routing frame: setting a provider
/// mid-redirect is modifying state while the tree is building.
void captureRequest(Ref ref, Uri requested, EntryIntent? current) {
  final location = EntryIntent.validatedLocation(requested.toString());
  if (location == null ||
      Uri.parse(location).path == kDefaultHome ||
      location == current?.destination) {
    return;
  }
  final intents = ref.read(entryIntentsProvider.notifier);
  unawaited(Future.microtask(
    () => intents.capture(EntryIntent.openValidated(intents.nextId(), location)),
  ));
}

/// A continuation is spent when the person ARRIVES, read off the
/// router's own location — never off a redirect's decision, which is
/// applied later and can be re-decided from the old location before
/// it is. Registered on the router delegate; off its notification
/// frame for the same reason as the capture.
void spendOnArrival(GoRouter router, Ref ref) {
  final intent = ref.read(entryIntentsProvider);
  if (intent == null || ref.read(authStateProvider).value == null) return;
  final wanted = Uri.parse(intent.destination ?? '').path;
  if (wanted.isEmpty || router.state.uri.path != wanted) return;
  final id = intent.id;
  unawaited(
    Future.microtask(() => ref.read(entryIntentsProvider.notifier).consume(id)),
  );
}
