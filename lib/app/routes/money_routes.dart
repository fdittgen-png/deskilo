// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: invoicing, VAT, billing, services, payment configuration and the account's finances.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:go_router/go_router.dart';

import '../../features/money/domain/invoicing_wizard.dart';
import '../../features/money/presentation/screens/billing_screen.dart';
import '../../features/money/presentation/screens/einvoice_config_screen.dart';
import '../../features/money/presentation/screens/invoice_register_screen.dart';
import '../../features/money/presentation/screens/invoices_screen.dart';
import '../../features/money/presentation/screens/invoicing_wizard_screen.dart';
import '../../features/money/presentation/screens/legal_identity_screen.dart';
import '../../features/money/presentation/screens/money_hubs_screen.dart';
import '../../features/money/presentation/screens/my_finances_screen.dart';
import '../../features/money/presentation/screens/my_payment_terms_screen.dart';
import '../../features/money/presentation/screens/number_sequences_screen.dart';
import '../../features/money/presentation/screens/payment_config_screen.dart';
import '../../features/money/presentation/screens/repartition_wizard_screen.dart';
import '../../features/money/presentation/screens/report_editor_screen.dart';
import '../../features/money/presentation/screens/services_screen.dart';
import '../../features/money/presentation/screens/vat_declarations_screen.dart';
import '../../features/money/presentation/screens/vat_screen.dart';
import '../../features/money/presentation/screens/workspace_status_screen.dart';
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../route_access.dart';
import '../route_env.dart';

/// Routes of the money feature.
List<RouteBase> moneyRoutes(RouteEnv env) => [
  ..._invoicingRoutes(env),
  ..._financeRoutes(env),
];

List<RouteBase> _invoicingRoutes(RouteEnv env) {
  return [
    GoRoute(
      path: '/payment-config',
      redirect: env.guard(
        const RouteAccess(
          permission: WorkspacePermission.manageIntegrations,
          features: [WorkspaceFeature.onlinePayments],
        ),
      ),
      builder: (context, state) => const PaymentConfigScreen(),
    ),
    GoRoute(
      path: '/billing',
      redirect: env.guard(
        const RouteAccess(permission: WorkspacePermission.manageBilling),
      ),
      builder: (context, state) => const BillingScreen(),
    ),
    GoRoute(
      path: '/invoices',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.invoicing], to: '/money'),
      ),
      builder: (context, state) => const InvoicesScreen(),
    ),
    // The sortable register (0072): every member reads their own, an
    // issuer the whole workspace's.
    GoRoute(
      path: '/invoice-register',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.invoicing], to: '/money'),
      ),
      builder: (context, state) => const InvoiceRegisterScreen(),
    ),
    // Where invoices are POSTED (0073) — owner-only.
    GoRoute(
      path: '/einvoice-config',
      // #2137 — the credentials RPCs ask manageIntegrations.
      redirect: env.guard(
        const RouteAccess(
          permission: WorkspacePermission.manageIntegrations,
          features: [WorkspaceFeature.invoicing],
          to: '/money',
        ),
      ),
      builder: (context, state) => const EInvoiceConfigScreen(),
    ),
    // #513 — the central role→permission matrix. Anyone with a role
    // can READ it; editing needs manageRoles (enforced in-screen and
    // by the RPC).
    // #827 — the invoicing wizard.
    GoRoute(
      path: '/invoicing/wizard',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.invoicingWizard],
          to: '/money',
        ),
      ),
      builder: (context, state) => InvoicingWizardScreen(
        initialRun: WizardRun.values
            .asNameMap()[state.uri.queryParameters['run'] ?? ''],
      ),
    ),
    // #822 — the report editor as a full-screen designer.
    GoRoute(
      path: '/report-editor',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.reportDesigner],
          to: '/money',
        ),
      ),
      builder: (context, state) => const ReportEditorScreen(),
    ),
    // #902 — the conditions this member's documents print, read-only.
    GoRoute(
      path: '/settings/payment-terms',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.memberPaymentTerms],
          to: '/settings',
        ),
      ),
      builder: (context, state) => const MyPaymentTermsScreen(),
    ),
    // #925 — how every journal numbers its documents, one screen.
    GoRoute(
      path: '/settings/number-sequences',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.numberSequences],
          to: '/settings',
        ),
      ),
      builder: (context, state) => const NumberSequencesScreen(),
    ),
  ];
}

List<RouteBase> _financeRoutes(RouteEnv env) {
  return [
    // #2577 — the purchase and the sales side, each on its own page.
    GoRoute(
      path: '/money/purchases',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.purchases], to: '/money'),
      ),
      builder: (context, state) => const PurchasesHubScreen(),
    ),
    GoRoute(
      path: '/money/sales',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.invoicing], to: '/money'),
      ),
      builder: (context, state) => const SalesHubScreen(),
    ),
    GoRoute(
      path: '/money/cash',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.moneyTab], to: '/money'),
      ),
      builder: (context, state) => const CashHubScreen(),
    ),
    // #934 — the treasurer's view, and the guided repartition.
    GoRoute(
      path: '/money/status',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.workspaceStatus],
          to: '/money',
        ),
      ),
      builder: (context, state) => WorkspaceStatusScreen(
        from: state.uri.queryParameters['from'],
        to: state.uri.queryParameters['to'],
      ),
    ),
    GoRoute(
      path: '/money/repartition-wizard',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.expenseRepartitionWizard],
          to: '/money',
        ),
      ),
      builder: (context, state) => const RepartitionWizardScreen(),
    ),
    // The workspace's legal identity (0069) — owner-only, and only
    // where invoices exist at all.
    GoRoute(
      path: '/legal-identity',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.invoicing],
          bypass: RoleBypass.owner,
          to: '/money',
        ),
      ),
      builder: (context, state) => const LegalIdentityScreen(),
    ),
    GoRoute(
      path: '/vat-declarations',
      redirect: env.guard(
        const RouteAccess(
          features: [
            WorkspaceFeature.invoicing,
            WorkspaceFeature.vatDeclarations,
          ],
          bypass: RoleBypass.owner,
          to: '/money',
        ),
      ),
      builder: (context, state) => const VatDeclarationsScreen(),
    ),
    GoRoute(
      path: '/vat',
      // #2137 — set_vat_rates asks manageBilling.
      redirect: env.guard(
        const RouteAccess(
          permission: WorkspacePermission.manageBilling,
          features: [WorkspaceFeature.vatManagement],
          to: '/money',
        ),
      ),
      builder: (context, state) => const VatScreen(),
    ),
    GoRoute(
      path: '/services',
      redirect: env.guard(
        const RouteAccess(
          permission: WorkspacePermission.manageServices,
          features: [WorkspaceFeature.services],
        ),
      ),
      builder: (context, state) => const ServicesScreen(),
    ),
    // Account history and applicant chat survive a refused membership.
    GoRoute(
      path: '/account-activity',
      builder: (context, state) =>
          MyFinancesScreen(workspaceId: state.uri.queryParameters['workspace']),
    ),
  ];
}
