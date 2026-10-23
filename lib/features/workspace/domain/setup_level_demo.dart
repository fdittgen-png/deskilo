// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 (ADR 0047 §3) — "See it in the demo" on each level of the levels
// screen: the screen of the demo's complete space (Pézenas) that shows the
// process at that level. A level that adds nothing has nothing to show.
// Every route is one the demo link allows (demo_link_test pins it).
import 'setup_levels.dart';

/// The demo screen of each level that adds something, by process and
/// level id.
const Map<SetupProcess, Map<String, String>> _setupLevelDemoRoutes = {
  SetupProcess.bookings: {
    'simple': '/reserve',
    'resources': '/editor',
    'measured': '/nfc-config',
  },
  SetupProcess.community: {'basic': '/members', 'organised': '/roles'},
  SetupProcess.money: {'statements': '/money', 'invoices': '/billing'},
  SetupProcess.payments: {'online': '/payment-config'},
  SetupProcess.tax: {'vat': '/vat', 'books': '/legal-identity'},
  SetupProcess.purchases: {'expenses': '/money', 'full': '/money/purchases'},
  SetupProcess.presentation: {
    'basic': '/reserve',
    'branded': '/settings/colours',
    'public': '/settings/public-page',
  },
  SetupProcess.operations: {
    'basic': '/setup',
    'insight': '/workspace-overview',
    'advanced': '/workspace-settings',
  },
  SetupProcess.assistant: {'on': '/settings/assistant-setup'},
};

/// Where the demo shows [process] at [level]; null for a level that adds
/// nothing.
String? setupLevelDemoRoute(SetupProcess process, String level) =>
    _setupLevelDemoRoutes[process]?[level];
