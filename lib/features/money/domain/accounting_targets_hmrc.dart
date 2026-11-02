// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the tax authority's own submission service, as a target of the
// accounting connection machinery: HMRC's Making Tax Digital for VAT. It is
// not a software the books are kept in: `authority` keeps it out of the
// software picker and the export choices. It connects by signing in at HMRC
// (the VRN is the remote tenant) and takes no accounting operation, only the
// prepared VAT return through its own action.
import 'accounting_format.dart';

const List<AccountingTarget> hmrcAccountingTargets = [
  AccountingTarget(
    id: 'hmrc_mtd',
    authority: true,
    vendor: 'HMRC',
    product: 'Making Tax Digital for VAT',
    edition: 'VAT API 1.0',
    countries: {'GB'},
    transport: AccountingTransport.api,
    payload: AccountingPayload.documents,
    operations: {},
    taxCodeModel: TaxCodeModel.none,
    connectsBy: {AccountingAuthKind.oauth2},
  ),
];
