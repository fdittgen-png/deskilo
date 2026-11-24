// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- the Demo's billing access: Hanna Weiss, a customer of the head's
// business with no account there, already reads her own documents from the
// visitor's account (a grant she accepted), and Nordlicht GmbH waits for an
// invitation the owner issues. The documents a held subject reads are
// synthetic and belong to the head's business alone; they are answered the way
// the server's `my_finance_overview_v2` answers a billing-grant row.
//
// #4168 -- a grant is held by ONE login: the Demo's account is the persona's.
// Kessler Conseil, the freelancer, invited two of its customers and both
// accepted: Lindner Beratung's invoices are read by Ada, who runs that
// practice (her explicit grant: being the practice's owner authorises nothing
// here), and Chiara Bernard, a customer in her own name with no business of hers,
// reads hers from her personal account.
import '../../../features/money/domain/finance_invoice.dart';
import '../data/fake_billing_access.dart';
import '../demo_fixture.dart';
import '../demo_persona.dart';
import '../demo_space_ids.dart';
import '../demo_spaces.dart';
import 'demo_freelancer_seed.dart' show demoKesslerChiaraId, demoKesslerLindnerId;

/// The Demo's grants, over the customers each space keeps.
FakeBillingAccessRepository seedDemoBillingAccess(DemoFixture fixture) {
  return FakeBillingAccessRepository(
    clock: () => fixture.seededAt,
    accountOf: () => fixture.profiles.myUserId,
    customerOf: (workspaceId, subjectId) {
      for (final key in DemoSpaceKey.values) {
        if (key.id != workspaceId) continue;
        for (final p
            in fixture.stores.at(key).billingCustomers.of(workspaceId)) {
          if (p.subjectId == subjectId) return p;
        }
      }
      return null;
    },
    workspaceNameOf: (workspaceId) =>
        [
          for (final w in fixture.workspaces.workspaces)
            if (w.id == workspaceId) w.name,
        ].firstOrNull ??
        workspaceId,
  )
    ..seedAccepted(
      demoFirstSpaceId,
      _weiss,
      'WEISS2026',
      principal: initialDemoPersona.userId,
    )
    ..seedAccepted(
      demoFreelancerSpaceId,
      demoKesslerLindnerId,
      'LINDNER2026',
      principal: DemoPersona.owner.userId,
    )
    ..seedAccepted(
      demoFreelancerSpaceId,
      demoKesslerChiaraId,
      'CHIARA2026',
      principal: DemoPersona.admin.userId,
    );
}

const _weiss = 'demo-customer-weiss';
const _nordlicht = 'demo-customer-nordlicht';

/// What a held subject of the head's business owes, as `my_finance_overview_v2`
/// answers a document read through a grant (`access: billing_grant`).
List<FinanceInvoice> demoBilledInvoices({
  required DateTime now,
  required Set<String> held,
  required String workspaceName,
  required String? timezone,
}) {
  FinanceInvoice row(
    String subject,
    String id,
    String number,
    int totalCents, {
    required int issuedDaysAgo,
    required int dueInDays,
    bool paid = false,
  }) => FinanceInvoice(
    id: id,
    workspaceId: demoFirstSpaceId,
    workspaceName: workspaceName,
    number: number,
    issuedAt: now.subtract(Duration(days: issuedDaysAgo)),
    dueOn: now.add(Duration(days: dueInDays)),
    totalCents: totalCents,
    paidCents: paid ? totalCents : 0,
    currency: 'EUR',
    state: paid ? FinanceState.paid : FinanceState.open,
    stillDueCents: paid ? 0 : totalCents,
    timezone: timezone,
    financialSubjectId: subject,
    billingOnly: true,
  );
  return [
    if (held.contains(_weiss)) ...[
      row(
        _weiss,
        'demo-billed-1',
        'AR-2026-0412',
        24000,
        issuedDaysAgo: 9,
        dueInDays: 21,
      ),
      row(
        _weiss,
        'demo-billed-2',
        'AR-2026-0377',
        9000,
        issuedDaysAgo: 44,
        dueInDays: -14,
        paid: true,
      ),
    ],
    if (held.contains(_nordlicht))
      row(
        _nordlicht,
        'demo-billed-3',
        'AR-2026-0431',
        180000,
        issuedDaysAgo: 3,
        dueInDays: 27,
      ),
  ];
}
