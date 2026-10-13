// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: the account and settings routes of the profile feature, the server screens and the schema update.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../core/backend/backend_uri.dart';
import '../../core/i18n/regional_formats_section.dart';
import '../../features/profile/presentation/screens/backend_screen.dart';
import '../../features/profile/presentation/screens/consent_screen.dart';
import '../../features/profile/presentation/screens/developer_screen.dart';
import '../../features/profile/presentation/screens/new_instance_screen.dart';
import '../../features/profile/presentation/screens/personal_info_screen.dart';
import '../../features/profile/presentation/screens/privacy_screen.dart';
import '../../features/profile/presentation/screens/profiles_screen.dart';
import '../../features/profile/presentation/screens/schema_update_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../route_access.dart';
import '../route_env.dart';
import '../schema_gate.dart';

/// Routes of the profile feature.
List<RouteBase> profileRoutes(RouteEnv env) {
  return [
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/profiles',
      builder: (context, state) => const ProfilesScreen(),
    ),
    // #780 — which Supabase instance this device talks to. Outside the
    // workspace shell on purpose: it must be reachable when no
    // workspace can be loaded, which is exactly when it is needed.
    // #977 — the instance wizard, beside the server screen it serves.
    GoRoute(
      // #1650 — its instanceWizard boundary is the policy's: a
      // workspace's flag, applied only when there is a workspace.
      path: '/server/new-instance',
      builder: (context, state) => const NewInstanceScreen(),
    ),
    GoRoute(
      path: '/server',
      builder: (context, state) => BackendScreen(
        candidate: state.extra is BackendDescriptor
            ? state.extra! as BackendDescriptor
            : null,
      ),
    ),
    GoRoute(
      // No owner guard (#144): developer mode is local diagnostics,
      // available to every member.
      path: '/developer',
      builder: (context, state) => const DeveloperScreen(),
    ),
    GoRoute(
      // #751 — the GDPR consent; ?review=1 reads it without the gate.
      path: '/consent',
      builder: (context, state) =>
          ConsentScreen(review: state.uri.queryParameters['review'] == '1'),
    ),
    GoRoute(
      // #719 — Privacy & data: who can see my data, who did, export,
      // erasure, the policy. Every member; the tools inside are gated.
      path: '/privacy',
      builder: (context, state) => const PrivacyScreen(),
    ),
    GoRoute(
      // #734 — Region & formats as a screen of its own.
      path: '/formats',
      // #1151 — gated like every feature-owned route.
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.regionalFormats],
          to: '/settings',
        ),
      ),
      builder: (context, state) => const RegionalFormatsScreen(),
    ),
    // #886 — the person's identity as the documents print it.
    GoRoute(
      path: '/settings/personal-info',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.personalInfo],
          to: '/settings',
        ),
      ),
      builder: (context, state) => const PersonalInfoScreen(),
    ),
    // #1312 — where a server older than this app sends every route.
    GoRoute(
      path: kSchemaUpdateRoute,
      builder: (context, state) => const SchemaUpdateScreen(),
    ),
  ];
}
