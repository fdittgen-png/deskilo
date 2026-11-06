// SPDX-License-Identifier: AGPL-3.0-or-later

import 'feature_assessment.dart';

// Reviews describe the cited evidence and preserve its limitations.
// They do not enable features, grant permissions or claim stable maturity.

const _reviewedBetaRationale =
    'Reviewed against the cited shipped capabilities and their gated '
    'evidence. Beta is retained; the catalogue states the scope and '
    'limitations of each check. No stable qualification is claimed.';

const _reviewedOwnerBetaRationale =
    'The owner decision of 2026-10-13 set this feature to beta. The cited '
    'shipped capabilities now have an evidence-based review. Their scope '
    'and limitations are retained here; this review does not promote '
    'maturity.';

const bankReconciliationAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: ['bank.reconciliation'],
  limitations:
      'This imports files rather than connecting directly to a bank. '
      'Duplicate movements without a stable bank identifier require review. '
      'Currency and import bounds are checked. Recorded reconciliation is not '
      'evidence of bank or payment-provider acceptance. Undo preserves the '
      'bank facts: incoming undo removes the invoice match and keeps its '
      'payment credit, while outgoing undo restores reported payment state '
      'with a reason; closed-period and incompatible settlement cases are '
      'refused.',
);

const onlinePaymentsAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedBetaRationale,
  evidence: [
    'payments.stripe',
    'payments.mollie',
    'payments.paypal',
    'payments.wero',
  ],
  limitations:
      'payments.stripe: CI runs the real order and webhook handlers against a '
      'stateful local stub through ten settlement scenarios; no Stripe '
      'sandbox has been exercised from this repository: '
      'scripts/payment_sandbox_check.sh is the opt-in test-mode runner, and '
      'without test keys it records not_run, never a pass. Refunds are '
      'recorded by hand. payments.mollie: The real order and Mollie webhook '
      'handlers run against a stateful local stub. Classic callbacks cause a '
      'provider readback and settle only matching paid payments; pending, '
      'failed, mismatched, duplicate, concurrent and unavailable-provider '
      'cases are exercised. No Mollie sandbox acceptance is recorded; '
      'next-generation callbacks are refused. payments.paypal: The real order '
      'and PayPal webhook handlers run against a stateful local PayPal stub, '
      'including approval and capture, signature refusal, wrong payment '
      'facts, replay, concurrency and a lost capture response. The stub '
      'verifies the local protocol and ledger effects; no PayPal sandbox or '
      'live signature acceptance is recorded. payments.wero: Local handler '
      'integration exercises Wero separately from Mollie with its own '
      'credentials, method and payment, including a paid settlement and '
      'refusal of a wrong method. This is stateful stub evidence, not '
      'evidence that a Mollie account or bank has accepted Wero in a sandbox '
      'or live environment.',
);

const invoicingAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedBetaRationale,
  evidence: [
    'einvoice.generate',
    'guests.passes',
  ],
  limitations:
      'einvoice.generate: Arithmetic, document structure and channel-specific '
      'prerequisites have local checks. Generated samples and national '
      'connector code do not establish acceptance by a destination platform '
      'or authority, and unsupported issuance routes remain refused. '
      'guests.passes: The feature is off by default. Each sale uses its own '
      'managed guest profile. The evidence covers sale and payment recording '
      'in the application, not collection through an external payment '
      'provider.',
);

const accountingExportAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedBetaRationale,
  evidence: ['accounting.export'],
  limitations:
      'Local format and source checks do not establish complete statutory '
      'books, certification or acceptance by an accountant\'s importer or '
      'authority. FEC retains its complete-books obligation; Portuguese SAF-T '
      'retains its software-certification obligation. Poland JPK_KR_PD '
      'remains blocked at specificationNeeded pending authoritative source '
      'coverage despite schema-valid sample generation. A target without a '
      'reviewed qualification is refused.',
);

const vatManagementAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedBetaRationale,
  evidence: [
    'accounting.export',
    'einvoice.generate',
  ],
  limitations:
      'accounting.export: Local format and source checks do not establish '
      'complete statutory books, certification or acceptance by an '
      'accountant\'s importer or authority. FEC retains its complete-books '
      'obligation; Portuguese SAF-T retains its software-certification '
      'obligation. Poland JPK_KR_PD remains blocked at specificationNeeded '
      'pending authoritative source coverage despite schema-valid sample '
      'generation. A target without a reviewed qualification is refused. '
      'einvoice.generate: Arithmetic, document structure and channel-specific '
      'prerequisites have local checks. Generated samples and national '
      'connector code do not establish acceptance by a destination platform '
      'or authority, and unsupported issuance routes remain refused.',
);

const taxHmrcMtdAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: ['tax.hmrc_mtd'],
  limitations:
      'The current evidence uses simulated function replies and a local '
      'database. No recorded Developer Hub sandbox submission or HMRC '
      'production acceptance is present. A lost response or expired attempt '
      'remains unconfirmed until the current attempt has been checked; no '
      'receipt is invented.',
);

const einvoiceTransmitAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedBetaRationale,
  evidence: ['einvoice.transmit'],
  limitations:
      'The client handoff, channel selection and receipt interpretation are '
      'unit-tested using simulated responses. No real or sandbox transmission '
      'or acceptance by a national platform is recorded by this evidence.',
);

const statementsSharedExpensesAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedBetaRationale,
  evidence: ['statements.shared_expenses'],
  limitations:
      'Statements are a view of the ledger, not an accounting ledger of the '
      'association; see accounting.export for the books.',
);

const supplyExpensesAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedBetaRationale,
  evidence: [
    'statements.shared_expenses',
    'suppliers.lookup',
    'purchases.payables',
  ],
  limitations:
      'statements.shared_expenses: Statements are a view of the ledger, not '
      'an accounting ledger of the association; see accounting.export for the '
      'books. suppliers.lookup: The current registry adapter is VIES; a '
      'valid VAT number may return no business profile. The cited widget '
      'evidence uses simulated registry replies, including failure and retry. '
      'It does not prove a real VIES lookup or establish that a returned '
      'legal identity is correct. purchases.payables: Unqualified tax '
      'information remains unknown rather than zero. Supplier approval '
      'requires a different authorized person from the submitter. The '
      'workflow records obligations and reported outgoing payments; it does '
      'not execute a bank transfer or prove statutory VAT deductibility.',
);

const accountingBookAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: [
    'accounting.export',
    'accounting.connections',
  ],
  limitations:
      'accounting.export: Local format and source checks do not establish '
      'complete statutory books, certification or acceptance by an '
      'accountant\'s importer or authority. FEC retains its complete-books '
      'obligation; Portuguese SAF-T retains its software-certification '
      'obligation. Poland JPK_KR_PD remains blocked at specificationNeeded '
      'pending authoritative source coverage despite schema-valid sample '
      'generation. A target without a reviewed qualification is refused. '
      'accounting.connections: The evidence exercises the app and database '
      'delivery contract, including permissions, secret isolation and '
      'idempotency. Implemented target adapters remain unaccepted by real '
      'provider accounts; specificationNeeded targets stay unavailable. An '
      'unresolved transmission is not reported as a successful delivery.',
);

const suppliersLookupAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: ['suppliers.lookup'],
  limitations:
      'The current registry adapter is VIES; a valid VAT number may return no '
      'business profile. The cited widget evidence uses simulated registry '
      'replies, including failure and retry. It does not prove a real VIES '
      'lookup or establish that a returned legal identity is correct.',
);

const purchasesPayablesAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: ['purchases.payables'],
  limitations:
      'Unqualified tax information remains unknown rather than zero. Supplier '
      'approval requires a different authorized person from the submitter. '
      'The workflow records obligations and reported outgoing payments; it '
      'does not execute a bank transfer or prove statutory VAT deductibility.',
);

const purchasesAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: [
    'purchases.payables',
    'purchases.orders',
  ],
  limitations:
      'purchases.payables: Unqualified tax information remains unknown rather '
      'than zero. Supplier approval requires a different authorized person '
      'from the submitter. The workflow records obligations and reported '
      'outgoing payments; it does not execute a bank transfer or prove '
      'statutory VAT deductibility. purchases.orders: The feature is off by '
      'default. Sent orders are frozen and stale revisions are refused. An '
      'unconfirmed email attempt blocks another send until a person resolves '
      'it. The local UI and database evidence does not prove email-provider '
      'acceptance or delivery to a supplier.',
);

const accountingConnectorsAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: [
    'accounting.connections',
    'tax.hmrc_mtd',
  ],
  limitations:
      'accounting.connections: The evidence exercises the app and database '
      'delivery contract, including permissions, secret isolation and '
      'idempotency. Implemented target adapters remain unaccepted by real '
      'provider accounts; specificationNeeded targets stay unavailable. An '
      'unresolved transmission is not reported as a successful delivery. '
      'tax.hmrc_mtd: The current evidence uses simulated function replies and '
      'a local database. No recorded Developer Hub sandbox submission or '
      'HMRC production acceptance is present. A lost response or expired '
      'attempt remains unconfirmed until the current attempt has been '
      'checked; no receipt is invented.',
);

const purchasesOrdersAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: ['purchases.orders'],
  limitations:
      'The feature is off by default. Sent orders are frozen and stale '
      'revisions are refused. An unconfirmed email attempt blocks another '
      'send until a person resolves it. The local UI and database evidence '
      'does not prove email-provider acceptance or delivery to a supplier.',
);

const guestsPassesAssessment = FeatureAssessment(
  maturity: FeatureMaturity.beta,
  rationale: _reviewedOwnerBetaRationale,
  evidence: ['guests.passes'],
  limitations:
      'The feature is off by default. Each sale uses its own managed guest '
      'profile. The evidence covers sale and payment recording in the '
      'application, not collection through an external payment provider.',
);
