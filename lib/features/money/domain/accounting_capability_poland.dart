// SPDX-License-Identifier: AGPL-3.0-or-later
// #2379 — Schema validation does not establish complete books or acceptance.
import 'accounting_capability.dart';

const polandJpkCapability = AccountingCapability(
  formatId: 'jpk_kr_pl',
  // The schema probe is not proof of an authoritative, complete source book.
  state: QualificationState.specificationNeeded,
  obligations: {Obligation.completePostedBooks, Obligation.targetAcceptance},
  specification: 'JPK_KR_PD(1) v1-1, Polish Ministry of Finance',
);
