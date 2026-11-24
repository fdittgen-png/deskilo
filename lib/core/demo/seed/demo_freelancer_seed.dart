// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4168 -- Kessler Conseil: the Demo's freelancer. A one-person consultancy in
// Pézenas (France, euros), owned by Bruno, of the kind `freelancer` and with no
// places: the features of a new space with the kind's reviewed profile applied
// on top, as the kind sheet applies it. It sells to three customers who need no
// account (a business with no VAT number, a person, a business that is also a
// practice of the Demo), keeps one quote the customer accepted, two invoices
// beside the one the journey issues from that quote, and owes a printer.
//
// The figures are fixed so the journey can reconcile them. The quote (revision
// 2): 1.5 h of consulting at EUR 90.00 net and a EUR 400.00 training = EUR 535.00
// net + 20 % VAT = EUR 642.00. A2 is EUR 60.00 and nothing is paid; A3 is
// EUR 108.00 and paid; the printer's bill is EUR 120.00 and unpaid. They are
// arithmetic fixtures, not a tax treatment of any jurisdiction.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show isoDay, yearMonth;

import '../../../features/events/domain/workspace_event.dart';
import '../../../features/money/domain/billing_customer.dart';
import '../../../features/money/domain/purchase.dart';
import '../../../features/money/domain/service_fulfilment.dart';
import '../../../features/money/domain/standalone_invoice.dart';
import '../../../features/workspace/domain/business_kind_proposal.dart';
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../../../features/workspace/domain/workspace_feature.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import '../data/business_kind_repository.dart';
import '../data/fake_billing_customers.dart';
import '../data/fake_customer_quotes.dart';
import '../data/fake_service_fulfilments.dart';
import '../data/money_repository.dart';
import '../data/purchase_repository.dart';
import '../data/workspace_repository.dart';
import '../demo_persona.dart';
import '../demo_space_ids.dart';

const _name = 'Kessler Conseil';

/// The customer who is a person in her own name, and the one that is a
/// business run by the practice's owner: each reads its own invoices through
/// a grant the business issued (demo_billing_access_seed.dart).
const demoKesslerChiaraId = 'kessler-customer-chiara';
const demoKesslerLindnerId = 'kessler-customer-lindner';

/// The customers, none of them with an account here.
const _customers = <BillingParty>[
  BillingParty(
    subjectId: 'kessler-customer-aires',
    revision: 1,
    capacity: 'business',
    draft: BillingPartyDraft(
      company: 'Domaine des Aires',
      street: '2 chemin des Vignes',
      postalCode: '34120',
      city: 'Pézenas',
      countryCode: 'FR',
    ),
  ),
  BillingParty(
    subjectId: demoKesslerChiaraId,
    revision: 1,
    capacity: 'consumer',
    draft: BillingPartyDraft(
      firstName: 'Chiara',
      lastName: 'Bernard',
      street: '14 rue du Four',
      postalCode: '34500',
      city: 'Béziers',
      countryCode: 'FR',
    ),
  ),
  BillingParty(
    subjectId: demoKesslerLindnerId,
    revision: 1,
    capacity: 'business',
    draft: BillingPartyDraft(
      company: 'Lindner Beratung',
      street: 'Kastanienallee 12',
      postalCode: '10435',
      city: 'Berlin',
      countryCode: 'DE',
      vatId: 'DE811234567',
    ),
  ),
];

String _customerName(String subjectId) => _customers
    .where((c) => c.subjectId == subjectId)
    .map((c) => c.displayName)
    .firstOrNull ?? subjectId;

/// The postal block of a customer, as the invoice prints it.
String _customerAddress(String subjectId) {
  final d = _customers
      .where((c) => c.subjectId == subjectId)
      .map((c) => c.draft)
      .firstOrNull;
  return d == null ? '' : '${d.street}, ${d.postalCode} ${d.city}';
}

Map<String, bool> _flags() {
  final fresh = defaultFeatureFlagsForNewWorkspace();
  return {
    ...fresh,
    ...proposalFor(
      profile: demoFreelancerProfile,
      raw: resolveEnabledFeatures(fresh),
      country: 'FR',
    ).flags,
    WorkspaceFeature.workspaceOverview.dbKey: true,
  };
}

/// The business as its owner set it up: French, in euros, registered for VAT.
Workspace demoFreelancerSpace() => Workspace(
  id: demoFreelancerSpaceId,
  rolePermissions: everydayMatrix(),
  name: _name,
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'KESSLER2026',
  featureFlags: _flags(),
  environment: 'prod',
  address: '8 rue des Remparts, 34120 Pézenas',
  street: '8 rue des Remparts',
  postalCode: '34120',
  city: 'Pézenas',
  vatRegime: 'vat_registered',
  legalId: '81234567800019',
  branding: const {
    'seed_color': '#7C3AED',
    'pattern': 'dots',
    'symbol_text': 'KC',
    'symbol_color': '#7C3AED',
  },
);

/// Bruno owns the business, and nobody else is in it: ownership is the
/// membership of THIS business, never a global persona.
void seedFreelancerPeople(FakeWorkspaceRepository space) {
  final owner = DemoPersona.member.person;
  space
    ..myMember = Member(
      id: owner.memberId,
      workspaceId: demoFreelancerSpaceId,
      userId: owner.userId,
      isAdmin: true,
      isOwner: true,
      status: MemberStatus.active,
      subscriptionPct: owner.subscriptionPct,
    )
    ..memberNames[owner.memberId] = owner.name
    ..memberEmails[owner.memberId] = owner.email;
  // A customer with no account is a member row of the business with no user:
  // the financial subject its invoices and quotes name (#4164).
  for (final customer in _customers) {
    space
      ..otherMembers.add(
        Member(
          id: customer.subjectId,
          workspaceId: demoFreelancerSpaceId,
          userId: '',
          isAdmin: false,
          isOwner: false,
          status: MemberStatus.active,
        ),
      )
      ..memberNames[customer.subjectId] = customer.displayName;
  }
}

const _lesson = StandaloneLine(
  description: 'Consulting',
  quantity: '1.5',
  unitCode: 'hour',
  unitLabel: 'h',
  unEceCode: 'HUR',
  unitPrice: '90',
);
const _training = StandaloneLine(
  description: 'Training day',
  quantity: '1',
  unitCode: 'unit',
  unitLabel: 'day',
  unEceCode: 'DAY',
  unitPrice: '400',
);

FakeBillingCustomerRepository seedFreelancerBillingCustomers() {
  final repo = FakeBillingCustomerRepository();
  for (final customer in _customers) {
    repo.seed(demoFreelancerSpaceId, customer);
  }
  return repo;
}

/// The customers' quote: revision 1 was the consulting alone, revision 2 added
/// the training and is the one the customer accepted. Converting it issues the
/// real invoice through [invoicing], into the business's own money.
FakeCustomerQuoteRepository seedFreelancerQuotes(
  DateTime today,
  StandaloneInvoiceCommands invoicing,
) {
  final issued = today.subtract(const Duration(days: 12));
  return FakeCustomerQuoteRepository(clock: () => today)
    ..invoicing = invoicing
    ..seedSent(
      demoFreelancerSpaceId,
      subjectId: 'kessler-customer-aires',
      lines: const [_lesson],
      extras: (notes: '', amendments: const [[_lesson, _training]]),
      issuedOn: issued,
      validUntil: today.add(const Duration(days: 18)),
    )
    ..seedAccepted(
      demoFreelancerSpaceId,
      0,
      decidedOn: today.subtract(const Duration(days: 4)),
    );
}

/// Two invoices the business already issued, A2 (EUR 60.00, nothing paid) and
/// A3 (EUR 108.00, paid in full), each a single net line at 20 %.
void seedFreelancerInvoices(FakeMoneyRepository money, DateTime today) {
  // the business's one rate: what its invoices and the quote's conversion read
  money.vatRates = const [VatRate(id: 'kessler-vat-20', label: 'Standard', percent: 20, isDefault: true)];
  money.invoiceQueries.buyers.of = (id) =>
      (name: _customerName(id), address: _customerAddress(id));
  void issue(String id, String number, String subject, String what, int net, {required int daysAgo, bool paid = false}) {
    final issued = today.subtract(Duration(days: daysAgo));
    final gross = net + net ~/ 5;
    money.invoices.add(
      Invoice(
        id: id,
        workspaceId: demoFreelancerSpaceId,
        memberId: subject,
        number: number,
        issuedAt: issued,
        title: what,
        lines: [
          InvoiceLine(
            label: what,
            amountCents: gross,
            vatPercent: 20,
            netCents: net,
            taxCents: gross - net,
          ),
        ],
        totalCents: gross,
        vatTotals: [
          InvoiceVatTotal(percent: 20, category: 'S', grossCents: gross, netCents: net, vatCents: gross - net),
        ],
        currency: 'EUR',
        memberName: _customerName(subject),
        memberAddress: _customerAddress(subject),
        workspaceName: _name,
        workspaceAddress: '8 rue des Remparts, 34120 Pézenas',
        issuerName: DemoPersona.member.person.name,
        signature: 'f' * 64,
        keepsOriginal: true,
      ),
    );
    if (!paid) return;
    final paymentId = 'ledger-$id';
    final period = yearMonth(issued.year, issued.month);
    money.ledger.add(
      LedgerEntry(
        id: paymentId,
        memberId: subject,
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: gross,
        description: 'Bank transfer',
        period: period,
        createdAt: issued,
        occurredOn: issued,
      ),
    );
    money.usePayment(paymentId, gross);
    money.invoiceMatchesStore[id] = InvoiceMatch(
      invoiceId: id,
      paidCents: gross,
      resolution: 'exact',
      paymentLedgerId: paymentId,
      matchedAt: issued,
      byName: _name,
    );
  }

  issue('kessler-a2', 'KC-2026-0002', demoKesslerChiaraId, 'Coaching session', 5000, daysAgo: 20);
  issue('kessler-a3', 'KC-2026-0003', demoKesslerLindnerId, 'Workshop preparation', 9000, daysAgo: 9, paid: true);
  // Chiara declared her payment of the EUR 60.00 invoice; Bruno has not
  // confirmed it yet: a pending payment event of hers (what the invoicing home
  // counts "to confirm") and the claim on the invoice it names (0797), so it is
  // owed but no longer "to collect". Its id is a declaration's (the
  // `evt-payment-` the Demo's own declarations take), so Me reads it as the
  // event she may take back and drops the claim once Bruno decides it.
  const declaredId = 'evt-payment-kessler-a2';
  final declaredOn = today.subtract(const Duration(days: 2));
  money.eventRepository?.events.add(
    WorkspaceEvent(
      id: declaredId,
      workspaceId: demoFreelancerSpaceId,
      type: EventType.payment,
      action: EventAction.submitted,
      actorMemberId: demoKesslerChiaraId,
      subjectMemberId: demoKesslerChiaraId,
      payload: {
        'amount_cents': 6000,
        'note': '',
        'method': '',
        'paid_on': isoDay(declaredOn),
        'period': yearMonth(declaredOn.year, declaredOn.month),
      },
      status: EventStatus.pending,
      createdAt: declaredOn,
    ),
  );
  money.claims[declaredId] = ['kessler-a2'];
}

/// What the business owes: the printer's bill, EUR 120.00, unpaid.
void seedFreelancerPurchases(FakePurchaseRepository purchases, DateTime today) {
  final received = today.subtract(const Duration(days: 6));
  purchases.addApprovedBill(
    PurchaseDetail(
      summary: PurchaseSummary(
        id: 'kessler-bill-printer',
        kind: PurchaseKind.bill,
        state: PurchaseState.draft,
        category: 'Printing',
        reference: 'IMP-2026-118',
        currency: 'EUR',
        grossCents: 12000,
        receivedOn: received,
      ),
      revision: 1,
      lines: const [
        PurchaseLine(
          lineNo: 1,
          description: 'Printing, workshop handouts',
          grossCents: 12000,
          netCents: 10000,
          taxCents: 2000,
          taxRatePercent: 20,
          recoverableTaxCents: 2000,
          recognitionKind: 'operating',
        ),
      ],
      sources: const [],
      supplierName: 'Imprimerie du Pays d’Oc',
      dueOn: today.add(const Duration(days: 24)),
    ),
    'kessler-supplier-printer',
  );
}

/// The engagement of the training Kessler Conseil was ordered: opened from the
/// accepted quote's training line, started and done before any invoice exists.
/// Its invoice and payments come later and are read beside it, never in it.
Future<void> seedFreelancerEngagement(
  FakeServiceFulfilmentRepository engagements,
  FakeCustomerQuoteRepository quotes,
) async {
  final quote = (await quotes.quotes(demoFreelancerSpaceId)).single;
  final training = quote.revisions.last.lines.firstWhere((l) => l.description == _training.description);
  final opened = await engagements.openFromLine(
    demoFreelancerSpaceId,
    requestId: 'kessler-engagement-open',
    kind: 'quote',
    id: quote.id,
    lineId: training.lineId!,
  );
  var state = opened.fulfilment;
  for (final to in [FulfilmentState.started, FulfilmentState.done]) {
    state = await engagements.transition(
      demoFreelancerSpaceId,
      state.id,
      expectedRevision: state.revision,
      to: to,
      requestId: 'kessler-engagement-${to.wire}',
    );
  }
}
