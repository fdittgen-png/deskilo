// SPDX-License-Identifier: AGPL-3.0-or-later

import 'action_registry.dart';

/// Only registered pages and finite, public tab names can travel in a guide.
/// Record identifiers, arbitrary queries and external URLs never do.
bool isGuideDestination(String value) =>
    (!value.contains(':') && uiRoutes.contains(value)) ||
    guideMeDestinations.contains(value);

const guideMeDestinations = {
  '/me?tab=home',
  '/me?tab=discover',
  '/me?tab=messages',
  '/me?tab=me',
};

String? guidePageForTarget(String? target) {
  if (target == null) return null;
  if (isGuideDestination(target)) return target;
  return const {
    '/member/:memberId': '/members',
    '/res/:id': '/calendar',
    '/conversation/:conversationId': '/messages',
    '/space/:kind/:id': '/discover',
    '/editor/level/:levelId': '/editor',
  }[target];
}

const Map<String, String> guideSurfaceRoutes = {
  RecorderSurfaces.reserve: '/reserve',
  RecorderSurfaces.bookingSheet: '/reserve',
  RecorderSurfaces.myReservation: '/reserve',
  RecorderSurfaces.reservationDetail: '/calendar',
  RecorderSurfaces.calendar: '/calendar',
  RecorderSurfaces.eventDecisions: '/calendar',
  RecorderSurfaces.workspaceFeatures: '/features',
  RecorderSurfaces.roles: '/roles',
  RecorderSurfaces.validationRules: '/validation',
};
