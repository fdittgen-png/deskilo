// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 (cut 2) -- the customer quotes' routes: the list, one quote and its
// editor (`new` for a new quote). One feature (customerQuotes) guards all
// three; the server still decides who may act.
import 'package:go_router/go_router.dart';

import '../../features/money/presentation/screens/customer_quote_editor_screen.dart';
import '../../features/money/presentation/screens/customer_quote_screen.dart';
import '../../features/money/presentation/screens/customer_quotes_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the customerQuotes feature.
List<RouteBase> customerQuoteRoutes(RouteEnv env) {
  final guard = env.guard(
    const RouteAccess(features: [WorkspaceFeature.customerQuotes], to: '/money'),
  );
  return [
    GoRoute(
      path: '/money/quotes',
      redirect: guard,
      builder: (context, state) => const CustomerQuotesScreen(),
    ),
    GoRoute(
      path: '/money/quotes/:id',
      redirect: guard,
      builder: (context, state) =>
          CustomerQuoteScreen(quoteId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/money/quotes/:id/edit',
      redirect: guard,
      builder: (context, state) =>
          CustomerQuoteEditorScreen(quoteId: state.pathParameters['id']!),
    ),
  ];
}
