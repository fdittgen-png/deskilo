// SPDX-License-Identifier: AGPL-3.0-or-later

/// What DesKilo may say about an accounting export beyond its [FormatClaim]
/// (#1868, checkpoint A): how far it has been QUALIFIED, and which
/// obligations the file cannot satisfy by itself.
///
/// The axes are kept apart on purpose. A structurally valid file is a
/// software fact; a statutory duty (complete posted books, software
/// certification) or an authority's acceptance is a different one, and the
/// highest software state never implies them. `unknown/requires-review` is
/// an answer, not a gap: nothing here invents an absence of obligations.
library;

import 'accounting_format.dart';

/// How far a format's production has been qualified. Ordered: a later
/// state needs the earlier ones, but none of them settles an [Obligation].
enum QualificationState {
  unsupported,
  specificationNeeded,
  implemented,
  locallyValidated,
  targetAccepted,
}

/// A duty the produced file cannot discharge by being well-formed.
enum Obligation {
  /// The format is the authority's file over COMPLETE posted books; DesKilo
  /// holds invoices and payments, not a double-entry ledger (ADR 0022).
  completePostedBooks,

  /// The jurisdiction certifies invoicing software and DesKilo is not
  /// certified under it.
  softwareCertification,

  /// Nobody has told us the target accepted a file from this app.
  targetAcceptance,
}

class AccountingCapability {
  const AccountingCapability({
    required this.formatId,
    required this.state,
    this.obligations = const {Obligation.targetAcceptance},
    this.specification = '',
  });

  final String formatId;
  final QualificationState state;

  /// Everything still open between "the file is well-formed" and "the duty
  /// is met". Never empty for a regulatory format.
  final Set<Obligation> obligations;

  /// The published specification the production was reviewed against, with
  /// its version. Empty means none was reviewed — never a guessed URL.
  final String specification;

  /// A file of this format may be presented as the entity's complete
  /// statutory books only when nothing is outstanding.
  bool get mayPresentAsComplete => obligations.isEmpty;

  /// The export may be produced at all.
  bool get producible =>
      state.index >= QualificationState.implemented.index;
}

/// The reviewed decision for every offered format. Keyed by the format id so
/// a format added to [accountingFormats] without a decision is caught by the
/// qualification test rather than defaulting to "fine".
const Map<String, AccountingCapability> accountingCapabilities = {
  // Reconstructed from invoices and payments. Without complete posted-book
  // evidence it is a reconstruction an accountant completes, not the entity's
  // FEC.
  'fec': AccountingCapability(
    formatId: 'fec',
    state: QualificationState.locallyValidated,
    obligations: {
      Obligation.completePostedBooks,
      Obligation.targetAcceptance,
    },
    specification: 'DGFiP fichiers standards des écritures comptables',
  ),
  // Invoicing-only declaration ('F'); the spec is met, certification is not.
  'saft_pt': AccountingCapability(
    formatId: 'saft_pt',
    state: QualificationState.locallyValidated,
    obligations: {
      Obligation.softwareCertification,
      Obligation.targetAcceptance,
    },
    specification: 'SAF-T PT, TaxAccountingBasis F',
  ),
  'saft': AccountingCapability(
    formatId: 'saft',
    state: QualificationState.implemented,
    // The subset claim already says so in the file's own header and on the
    // row; no further obligation is asserted for a document handoff.
    obligations: {},
    specification: 'OECD SAF-T, ledger omitted on purpose',
  ),
  'datev': AccountingCapability(
    formatId: 'datev',
    state: QualificationState.locallyValidated,
  ),
  'sage50': AccountingCapability(
    formatId: 'sage50',
    state: QualificationState.implemented,
  ),
  'accountant_csv': AccountingCapability(
    formatId: 'accountant_csv',
    state: QualificationState.implemented,
    obligations: {},
  ),
  'audit_trail': AccountingCapability(
    formatId: 'audit_trail',
    state: QualificationState.implemented,
    obligations: {},
  ),
  'bundle': AccountingCapability(
    formatId: 'bundle',
    state: QualificationState.implemented,
    obligations: {},
  ),
};

/// The decision for [format]; a format nobody reviewed is `unsupported`
/// and blocked, never silently allowed.
AccountingCapability capabilityOf(AccountingFormat format) =>
    accountingCapabilities[format.id] ??
    AccountingCapability(
      formatId: format.id,
      state: QualificationState.unsupported,
    );
