// SPDX-License-Identifier: 0BSD
import '../core/instance/schema_compatibility.dart';

/// #1312 — where a server older than this app sends every route.
const String kSchemaUpdateRoute = '/server-update';

/// The router's first question: may [location] open against a server whose
/// schema compares as [schema]?
///
/// Only `behind` gates, signed in or not, and it leaves open what it takes
/// to get out: the Server screen and its wizard, the help, the privacy page.
/// `unknown` — not yet answered, or offline — gates nothing, so a start
/// without a network behaves exactly as before the gate existed.
String? schemaGateRedirect(SchemaCompatibility? schema, String location) {
  final atUpdate = location == kSchemaUpdateRoute;
  if (schema == SchemaCompatibility.behind) {
    final exempt = location.startsWith('/server') ||
        location == '/help' ||
        location == '/privacy';
    return exempt ? null : kSchemaUpdateRoute;
  }
  return atUpdate ? '/reserve' : null;
}
