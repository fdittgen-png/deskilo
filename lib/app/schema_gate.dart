// SPDX-License-Identifier: AGPL-3.0-or-later
import '../core/instance/app_compatibility.dart';
import '../core/instance/schema_compatibility.dart';

/// #1312 — where a server older than this app sends every route.
const String kSchemaUpdateRoute = '/server-update';

/// The router's first question: may [location] open against a server whose
/// schema compares as [schema]?
///
/// Only `behind` gates, signed in or not, and it leaves open what it takes
/// to get out: the Server screen and its wizard, the help, the privacy page, and the
/// Demo (#3247), which runs on no server.
/// `unknown` — not yet answered, or offline — gates nothing, so a start
/// without a network behaves exactly as before the gate existed.
String? schemaGateRedirect(SchemaCompatibility? schema, String location) {
  final atUpdate = location == kSchemaUpdateRoute;
  if (schema == SchemaCompatibility.behind) {
    return _wayOut(location) ? null : kSchemaUpdateRoute;
  }
  return atUpdate ? '/reserve' : null;
}

/// What a gate never closes: the Server screen and its wizard, the help,
/// the privacy page and the Demo, which runs on no server.
bool _wayOut(String location) =>
    location.startsWith('/server') ||
    location == '/demo' ||
    location == '/help' ||
    location == '/privacy';

/// #3726 — where an installation that accepts only newer apps sends every
/// route.
const String kAppUpdateRoute = '/app-update';

/// May [location] open while the installation judges this app [verdict]?
///
/// Only `below` gates, and it leaves the same way out open as the schema
/// gate; the screen itself also offers signing out. `unknown` — a floor never
/// read — gates nothing. Null: stay where asked. When the app is not below,
/// the update screen sends home.
String? appFloorGateRedirect(AppFloorVerdict? verdict, String location) {
  final atUpdate = location == kAppUpdateRoute;
  if (verdict == AppFloorVerdict.below) {
    return atUpdate || _wayOut(location) ? null : kAppUpdateRoute;
  }
  return atUpdate ? '/reserve' : null;
}
