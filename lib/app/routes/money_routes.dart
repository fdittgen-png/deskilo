// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — feature route list: invoicing, VAT, billing, services, payment configuration and the account's finances.
// A route is one GoRoute and its RouteAccess here; router.dart only composes
// the lists.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/navigation/list_detail_route.dart';
import '../../features/money/application/arrived_accounting_sign_in.dart';
import '../../features/money/domain/accounting_sign_in_return.dart';
import '../../features/money/domain/invoicing_wizard.dart';
import '../../features/money/presentation/invoicing/invoice_page.dart';
import '../../features/money/presentation/invoicing/invoicing_customer_actions.dart';
import '../../features/money/presentation/screens/accounting_exports_screen.dart';
import '../../features/money/presentation/screens/accounting_sign_in_return_screen.dart';
import '../../features/money/presentation/screens/billing_screen.dart';
import '../../features/money/presentation/screens/einvoice_config_screen.dart';
import '../../features/money/presentation/screens/guest_passes_screen.dart';
import '../../features/money/presentation/screens/invoice_register_screen.dart';
import '../../features/money/presentation/screens/invoices_screen.dart';
import '../../features/money/presentation/screens/invoicing_wizard_screen.dart';
import '../../features/money/presentation/screens/legal_identity_screen.dart';
import '../../features/money/presentation/screens/money_hubs_screen.dart';
import '../../features/money/presentation/screens/money_view_data.dart';
import '../../features/money/presentation/screens/my_finances_screen.dart';
import '../../features/money/presentation/screens/my_payment_terms_screen.dart';
import '../../features/money/presentation/screens/number_sequences_screen.dart';
import '../../features/money/presentation/screens/payment_config_screen.dart';
import '../../features/money/presentation/screens/purchase_approvals_screen.dart';
import '../../features/money/presentation/screens/purchase_order_page.dart';
import '../../features/money/presentation/screens/purchase_orders_screen.dart';
import '../../features/money/presentation/screens/recorded_payments_screen.dart';
import '../../features/money/presentation/screens/repartition_wizard_screen.dart';
import '../../features/money/presentation/screens/report_editor_screen.dart';
import '../../features/money/presentation/screens/services_screen.dart';
import '../../features/money/presentation/screens/suppliers_desk.dart';
import '../../features/money/presentation/screens/suppliers_screen.dart';
import '../../features/money/presentation/screens/vat_declarations_screen.dart';
import '../../features/money/presentation/screens/vat_return_page.dart';
import '../../features/money/presentation/screens/vat_screen.dart';
import '../../features/money/presentation/screens/workspace_status_screen.dart';
import '../../features/money/presentation/widgets/expense_repartition_sheet.dart'
    show expenseRepartitionPage;
import '../../features/money/presentation/widgets/purchases_sheet.dart';
import '../../features/money/presentation/widgets/settlement_sheet.dart'
    show settlementPage;
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../route_access.dart';
import '../route_env.dart';
import 'me_adapters.dart';

/// Routes of the money feature.
List<RouteBase> moneyRoutes(RouteEnv env) => [
  ..._invoicingRoutes(env),
  ..._purchaseRoutes(env),
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
      // Fee bands and subscription levels are money functionality.
      redirect: env.guard(
        const RouteAccess(
          permission: WorkspacePermission.manageBilling,
          features: [WorkspaceFeature.moneyTab],
        ),
      ),
      builder: (context, state) => const BillingScreen(),
    ),
    GoRoute(
      path: '/invoices',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.invoicing], to: '/money'),
      ),
      builder: (context, state) => const InvoicesScreen(),
      // #3607 — an open invoice's address: beside the list on a large
      // window, a page of its own otherwise.
      routes: [
        // #3614 — a customer's address, the same way.
        GoRoute(
          path: 'customer/:id',
          pageBuilder: (context, state) => recordPage(
            context,
            state,
            (id) => CustomerRecord(customerId: id),
          ),
        ),
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) => recordPage(
            context,
            state,
            (id) => InvoicePage(invoiceId: id),
          ),
        ),
      ],
    ),
    // The sortable register (0072): every member reads their own, an
    // issuer the whole workspace's.
    GoRoute(
      path: '/invoice-register',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.invoicing], to: '/money'),
      ),
      // #2578 — a drill-through from a figure narrows it to the figure's
      // months; a missing or malformed pair shows the whole register.
      builder: (context, state) => InvoiceRegisterScreen(
        from: state.uri.queryParameters['from'],
        to: state.uri.queryParameters['to'],
      ),
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

/// The purchase side: the hub, the approvals queue and the suppliers.
/// Who writes a purchase order: a buyer, in a space that has the orders.
const _orderWriteAccess = RouteAccess(
  permission: WorkspacePermission.managePurchases,
  features: [WorkspaceFeature.purchases, WorkspaceFeature.purchaseOrders],
  to: '/money/purchase-orders',
);

List<RouteBase> _purchaseRoutes(RouteEnv env) {
  return [
    // #2577 — the purchase side on its own page.
    GoRoute(
      path: '/money/purchases',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.purchases], to: '/money'),
      ),
      builder: (context, state) => const PurchasesHubScreen(),
      // #3615 — a document's address: beside the purchases table on a large
      // window, a page of its own otherwise.
      routes: [
        GoRoute(
          path: 'doc/:id',
          pageBuilder: (context, state) => recordPage(
            context,
            state,
            (id) => Consumer(
              builder: (context, ref, _) => PurchaseRecord(
                workspaceId: ref.watch(currentWorkspaceProvider).value?.id ?? '',
                purchaseId: id,
                held: MoneyViewData.purchasePermissionNames(ref),
              ),
            ),
          ),
        ),
      ],
    ),
    // #3070 — what waits for a decision, with the count on its drawer entry.
    GoRoute(
      path: '/money/purchases/approvals',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.purchases], to: '/money'),
      ),
      builder: (context, state) => const PurchaseApprovalsScreen(),
    ),
    // #2578 — the payments behind the collected figure, for its window.
    GoRoute(
      path: '/money/payments',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.moneyTab], to: '/money'),
      ),
      builder: (context, state) => RecordedPaymentsScreen(
        from: state.uri.queryParameters['from'],
        to: state.uri.queryParameters['to'],
      ),
    ),
    // The original short link goes through the canonical route's guards.
    GoRoute(path: '/suppliers', redirect: (context, state) => '/money/suppliers'),
    // #3308 — passes sold at the desk to guests who are not members.
    GoRoute(
      path: '/money/guest-passes',
      redirect: env.guard(
        const RouteAccess(
          // #3550 — a pass books a place for its guest.
          features: [WorkspaceFeature.placeBooking, WorkspaceFeature.guestPasses],
          to: '/money',
        ),
      ),
      builder: (context, state) => const GuestPassesScreen(),
    ),
    // #3070 — the suppliers as a screen: list, search, a deep link.
    GoRoute(
      path: '/money/suppliers',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.supplyExpenses],
          to: '/money',
        ),
      ),
      builder: (context, state) => const SuppliersScreen(),
      // #3615 — a supplier's address: beside the table on a large window,
      // their payables as a page otherwise.
      routes: [
        GoRoute(
          path: ':id',
          pageBuilder: (context, state) => recordPage(
            context,
            state,
            (id) => Consumer(
              builder: (context, ref, _) => SupplierRecord(
                workspaceId: ref.watch(currentWorkspaceProvider).value?.id ?? '',
                supplierId: id,
                held: MoneyViewData.purchasePermissionNames(ref),
              ),
            ),
          ),
        ),
      ],
    ),
    // #3307 — the space's orders to its suppliers.
    GoRoute(
      path: '/money/purchase-orders',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.purchases, WorkspaceFeature.purchaseOrders],
          to: '/money',
        ),
      ),
      builder: (context, state) => const PurchaseOrdersScreen(),
      // #3608 — the order's form is a long task: a page with an address.
      // Writing it is a buyer's (managePurchases); the list is read by
      // finance too.
      routes: [
        GoRoute(
          path: 'new',
          redirect: env.guard(_orderWriteAccess),
          builder: (context, state) => const PurchaseOrderPage(),
        ),
        GoRoute(
          path: ':id/edit',
          redirect: env.guard(_orderWriteAccess),
          builder: (context, state) =>
              PurchaseOrderPage(orderId: state.pathParameters['id']),
        ),
      ],
    ),
  ];
}

List<RouteBase> _financeRoutes(RouteEnv env) {
  return [
    // #3614 — Sales opens on the invoicing home; the hub's links are the
    // Sales group of the menu. The address stays for the links to it.
    GoRoute(path: '/money/sales', redirect: (context, state) => '/invoices'),
    GoRoute(
      path: '/money/accounting',
      redirect: env.guard(
        const RouteAccess(features: [WorkspaceFeature.moneyTab], to: '/money'),
      ),
      builder: (context, state) => const AccountingHubScreen(),
    ),
    _accountingSignInRoute(env),
    // #3616 — the files handed to the accountant, as records.
    GoRoute(
      path: '/money/accounting/exports',
      redirect: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.moneyTab, WorkspaceFeature.accountingPeriods],
          to: '/money',
        ),
      ),
      builder: (context, state) => const AccountingExportsScreen(),
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
    // The two assistants the invoices screen opens over itself:
    // a typed link opens them only while their feature is on.
    expenseRepartitionPage.route(
      guard: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.expenseRepartition],
          to: '/money',
        ),
      ),
    ),
    settlementPage.route(
      guard: env.guard(
        const RouteAccess(
          features: [WorkspaceFeature.invoiceSettlement],
          to: '/money',
        ),
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
      // #3616 — a return as a long task at its address.
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) =>
              VatReturnPage(declarationId: state.pathParameters['id'] ?? ''),
        ),
      ],
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
      // #2552 — under the personal shell this is /me/data?view=finances.
      redirect: (context, state) => personalShellAdapter(env, state),
      builder: (context, state) =>
          MyFinancesScreen(workspaceId: state.uri.queryParameters['workspace']),
    ),
  ];
}

/// #3906 — an accounting target's sign-in, completed by the signed-in person;
/// the router took its code and state out of the address. While a return
/// waits to be completed the page stays — right after a sign-in the switches
/// may still be the defaults — and the server decides switch and right on
/// completion; with none waiting the guard applies.
GoRoute _accountingSignInRoute(RouteEnv env) {
  final guard = env.guard(
    const RouteAccess(
      features: [WorkspaceFeature.accountingConnectors],
      to: '/money/accounting',
    ),
  );
  return GoRoute(
    path: accountingSignInReturnPath,
    redirect: (context, state) =>
        env.ref.read(arrivedAccountingSignInProvider).holds
            ? null
            : guard(context, state),
    builder: (context, state) => const AccountingSignInReturnScreen(),
  );
}
