// SPDX-License-Identifier: AGPL-3.0-or-later
// Synthetic accounting authority and landlord for the city demos.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import '../../../features/money/domain/accounting_connection.dart';
import '../../../features/money/domain/accounting_target.dart';
import '../../../features/money/domain/book_chart.dart';
import '../../../features/money/domain/lease_commitment.dart';
import '../../../features/money/domain/premises_lease.dart';
import '../../../features/money/domain/workspace_asset.dart';
import '../data/accounting_connection_repository.dart';
import '../data/book_period_repository.dart';
import '../data/book_profile_repository.dart';
import '../data/lease_commitment_repository.dart';
import '../data/money_repository.dart';
import '../data/premises_lease_repository.dart';
import '../data/purchase_repository.dart';
import '../data/workspace_asset_repository.dart';

FakeBookProfileRepository cityBooks(
  FakeMoneyRepository money,
  DateTime now, {
  required String workspaceId,
  required String siteId,
  required bool external,
  FakePurchaseRepository? purchases,
}) =>
    FakeBookProfileRepository(
        money: money,
        country: external ? 'GB' : 'US',
        purchases: purchases,
      )
      ..profiles.add(
        BookProfile(
          id: '$workspaceId-book',
          workspaceId: workspaceId,
          issuerSiteId: siteId,
          authority: external
              ? BookAuthority.externalBook
              : BookAuthority.localBook,
          externalSystem: external ? 'Sage' : '',
          functionalCurrency: external ? 'GBP' : 'USD',
          fiscalYearStartMonth: 1,
          fiscalYearStartDay: 1,
          basis: AccountingBasis.accrual,
          effectiveFrom: DateTime(now.year - 4),
          revision: 1,
        ),
      )
      ..accounts.addAll([
        for (final (index, role) in BookRole.values.indexed)
          BookAccount(
            id: '$workspaceId-account-${role.wire}',
            workspaceId: workspaceId,
            issuerSiteId: siteId,
            code: '${1000 + index * 100}',
            name: role.wire,
            type: role.type,
            isPosting: true,
            origin: AccountOrigin.manual,
            revision: 1,
          ),
      ])
      ..mappings.addAll([
        for (final role in BookRole.values)
          BookMapping(
            id: '$workspaceId-mapping-${role.wire}',
            workspaceId: workspaceId,
            issuerSiteId: siteId,
            role: role,
            accountId: '$workspaceId-account-${role.wire}',
            effectiveFrom: DateTime(now.year - 4),
            revision: 1,
          ),
      ]);

FakeAccountingConnectionRepository cityAccounting(
  DateTime now, {
  required bool sage,
}) => FakeAccountingConnectionRepository(
  books: FakeBookPeriodRepository(today: now),
  today: now,
  connections: [
    if (sage)
      AccountingConnection(
        id: 'uk-sage-demo',
        issuerSiteId: 'uk-site-camden',
        targetId: 'sage_business_cloud_gb',
        authKind: AccountingAuthKind.oauth2,
        status: ConnectionStatus.connected,
        displayName: 'Sage Accounting · Demo',
        statusDetail: 'Simulated connection',
        connectedAt: DateTime(now.year - 2),
      ),
  ],
);

FakePremisesLeaseRepository newYorkLease(DateTime now) {
  final start = DateTime(now.year - 4, now.month);
  return FakePremisesLeaseRepository([
    PremisesLease(
      id: 'ny-lease',
      revision: 1,
      supplierId: 'ny-landlord',
      supplierName: 'Hudson Property Company (Demo)',
      premises: 'Hudson House and satellite sites, New York',
      coveredLevels: 'Four floors, parking and four satellite sites',
      areaM2: 1200,
      startsOn: start,
      fixedUntil: DateTime(now.year + 5),
      noticeMonths: 6,
      depositCents: 1200000,
      status: LeaseStatus.active,
      terms: [
        LeaseTerm(
          id: 'ny-rent',
          kind: LeaseTermKind.rent,
          amountCents: 600000,
          effectiveFrom: start,
          occurrencesDone: 48,
        ),
        LeaseTerm(
          id: 'ny-service',
          kind: LeaseTermKind.serviceChargeAdvance,
          amountCents: 80000,
          effectiveFrom: start,
          occurrencesDone: 48,
        ),
      ],
    ),
  ]);
}

FakeLeaseCommitmentRepository newYorkCommitments(DateTime now) {
  final occurrences = <CommitmentOccurrence>[];
  for (
    var month = DateTime(now.year - 4, now.month);
    month.isBefore(DateTime(now.year, now.month));
    month = DateTime(month.year, month.month + 1)
  ) {
    final period = yearMonth(month.year, month.month);
    occurrences.add(
      CommitmentOccurrence(
        id: 'ny-commitment-$period',
        dueOn: month,
        expectedCents: 680000,
        matchedCents: 680000,
        matches: [
          CommitmentMatch(
            id: 'ny-rent-match-$period',
            purchaseId: 'ny-rent-$period',
            lineNo: 1,
            allocatedCents: 600000,
            lineGrossCents: 600000,
          ),
          CommitmentMatch(
            id: 'ny-fee-match-$period',
            purchaseId: 'ny-rent-$period',
            lineNo: 2,
            allocatedCents: 80000,
            lineGrossCents: 80000,
          ),
        ],
      ),
    );
  }
  return FakeLeaseCommitmentRepository({'ny-lease': occurrences});
}

FakeWorkspaceAssetRepository cityAssets(
  DateTime now, {
  required bool tenant,
  required List<String> sites,
}) {
  final prefix = tenant ? 'ny' : 'uk';
  final installed = DateTime(now.year - (tenant ? 4 : 3), now.month);
  final period = yearMonth(installed.year, installed.month);
  return FakeWorkspaceAssetRepository(
    assets: [
      for (final (index, site) in sites.indexed)
        WorkspaceAsset(
          id: '$prefix-printers-$index',
          revision: 1,
          assetNumber: index + 1,
          description: '$site: colour and mono printers, copier and 3D printer',
          currency: tenant ? 'USD' : 'GBP',
          acquisitionCostCents: 220000,
          supplierName: 'Amazon Business (Demo)',
          originalReference: 'equipment-$period-$index',
          decision: AssetDecision.capitalise,
          state: AssetState.inUse,
          availableForUseOn: installed,
          purchaseId: '$prefix-equipment-$period-$index',
          lineNo: 1,
        ),
    ],
  );
}
