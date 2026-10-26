// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2365 — the demo space's books: last year closed by its owner and exported
// once to the accountant; #2370 the studio connected to Pennylane.
import '../../../features/money/domain/accounting_connection.dart';
import '../../../features/money/domain/accounting_target.dart';
import '../../../features/money/domain/book_period.dart';
import '../data/accounting_connection_repository.dart';
import '../data/book_period_repository.dart';

FakeBookPeriodRepository seedDemoBookPeriods(DateTime now, {String? actor}) =>
    FakeBookPeriodRepository(
      today: now,
      // #2377 — the demo's exports name the person who made them, as the
      // server's log does.
      actorMemberId: actor,
      periods: [
        BookPeriod(
          id: 'demo-period-last-year',
          from: DateTime(now.year - 1),
          to: DateTime(now.year - 1, 12, 31),
          reason: BookPeriodReason.owner,
        ),
      ],
      exports: [
        BookExport(
          id: 'demo-export-last-year',
          formatId: 'fec',
          from: DateTime(now.year - 1),
          to: DateTime(now.year - 1, 12, 31),
          sha256: 'a' * 64,
          byteCount: 18234,
          rowCount: 212,
          documentCount: 41,
          closedPeriod: true,
          exportedAt: DateTime(now.year, 1, 15),
          exportedByMemberId: actor,
        ),
      ],
    );

/// The studio's books handed to Pennylane through a token connection: the
/// French rate and the revenue mapped, January's first invoice delivered and
/// acknowledged, a credit note whose answer never came back, waiting for its
/// readback.
FakeAccountingConnectionRepository seedDemoAccountingConnections(
  FakeBookPeriodRepository books,
  DateTime now,
) => FakeAccountingConnectionRepository(
  books: books,
  today: now,
  connections: [
    AccountingConnection(
      id: 'demo-connection-pennylane',
      issuerSiteId: 'demo-site-studio',
      targetId: 'pennylane_api',
      authKind: AccountingAuthKind.token,
      status: ConnectionStatus.connected,
      displayName: 'Pennylane — Atelier du Marché',
      remoteTenantId: '812345678',
      connectedAt: DateTime(now.year, 1, 5),
      secretsSet: const ['access_token'],
      maps: const [
        AccountingMap(
          id: 'demo-map-revenue',
          kind: AccountingMapKind.account,
          key: 'revenue:standard',
          remoteCode: '706000',
          remoteName: 'Prestations de services',
        ),
        AccountingMap(
          id: 'demo-map-vat-20',
          kind: AccountingMapKind.tax,
          key: 'VAT|FR|taxed|20|2014',
          remoteCode: 'FR_200',
        ),
      ],
    ),
  ],
  deliveries: [
    AccountingDelivery(
      id: 'demo-delivery-invoice',
      targetId: 'pennylane_api',
      connectionId: 'demo-connection-pennylane',
      documentKind: 'invoice',
      documentId: 'demo-invoice-january',
      documentNumber: 'F-${now.year}-0001',
      eventDate: DateTime(now.year, 1, 31),
      payloadSha256: 'b' * 64,
      status: DeliveryStatus.acknowledged,
      remoteId: '48211',
      remoteNumber: 'F-${now.year}-0001',
      remoteState: 'posted',
    ),
    AccountingDelivery(
      id: 'demo-delivery-credit',
      targetId: 'pennylane_api',
      connectionId: 'demo-connection-pennylane',
      documentKind: 'credit_note',
      documentId: 'demo-credit-february',
      documentNumber: 'A-${now.year}-0001',
      eventDate: DateTime(now.year, 2, 14),
      payloadSha256: 'c' * 64,
      status: DeliveryStatus.conflict,
      error: 'no answer after send: timeout',
    ),
  ],
);
