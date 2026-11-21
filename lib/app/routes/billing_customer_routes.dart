// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 -- the billing customers' route list: whom the business invoices, with
// or without an account. One GoRoute and its RouteAccess; router.dart composes
// the list.
import 'package:go_router/go_router.dart';

import '../../features/money/presentation/screens/billing_customers_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the billingCustomers feature.
List<RouteBase> billingCustomerRoutes(RouteEnv env) => [
  GoRoute(
    path: '/money/customers',
    redirect: env.guard(
      const RouteAccess(
        features: [WorkspaceFeature.billingCustomers],
        to: '/money',
      ),
    ),
    builder: (context, state) => const BillingCustomersScreen(),
  ),
];
