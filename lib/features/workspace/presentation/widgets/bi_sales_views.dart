// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 3 — how the sales figures read: the net and the gross beside
// it, the kinds of line by name, the services and the rented rooms, what
// the period cannot know, and how each is computed.
import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_result.dart';
import '../../domain/kpi_sales.dart';
import 'bi_module_section.dart';

SalesQualityKpi? _kpi(BiMeasure m) => m.detail as SalesQualityKpi?;

/// What every sales card says about its period and its amounts.
List<String> _notes(BiMeasure m, AppLocalizations l10n) => [
  if (m.reasons.contains('currency_mix')) l10n.biFinanceCurrencyMix,
  if (m.reasons.contains('amount_not_exact')) l10n.biFinanceNotExact,
  if (m.reasons.contains('period_not_over')) l10n.biFinancePartial,
  if (m.reasons.contains('external_rooms_off')) l10n.biSalesRoomsOff,
];

/// The name of a kind of invoice line.
String? _salesKindName(String kind, AppLocalizations l10n) => switch (kind) {
  'subscription' => l10n.biSalesKindSubscription,
  'overage' => l10n.biSalesKindOverage,
  'accessories' => l10n.biSalesKindAccessories,
  'level' => l10n.biSalesKindLevel,
  'office' => l10n.biSalesKindOffice,
  'desk' => l10n.biSalesKindDesk,
  'service' => l10n.biSalesKindService,
  'package' => l10n.biSalesKindPackage,
  'adjustment' => l10n.biSalesKindAdjustment,
  _ => l10n.biSalesKindOther,
};

/// The sales modules' views (#3294 step 3).
final salesModuleViews = <String, BiModuleView>{
  'sales.revenue_by_kind': BiModuleView(
    title: (l10n) => l10n.biSalesKindTitle,
    value: biMoneyCell,
    basis: (m, l10n, locale) => m.unknown
        ? ''
        : switch (_kpi(m)) {
            final k? => l10n.biSalesKindBasis(
              biMoneyCell(k.grossMinor, locale, k.currency),
              '${k.lines}',
              '${k.invoices}',
            ),
            null => '',
          },
    notes: (m, l10n, locale) => _notes(m, l10n),
    details: (m, l10n, locale) => [l10n.biSalesKindDefinition],
    rowLabel: (row, l10n, locale) => _salesKindName(row.key, l10n),
  ),
  'sales.revenue_by_service': BiModuleView(
    title: (l10n) => l10n.biSalesServiceTitle,
    value: biMoneyCell,
    basis: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => l10n.biSalesServiceBasis('${k.serviceCount}'),
      null => '',
    },
    notes: (m, l10n, locale) => _notes(m, l10n),
    details: (m, l10n, locale) => [l10n.biSalesServiceDefinition],
    rowLabel: (row, l10n, locale) =>
        row.label == null ? l10n.biSalesNoDescription : null,
  ),
  'sales.room_margin': BiModuleView(
    title: (l10n) => l10n.biSalesRoomTitle,
    value: biMoneyCell,
    basis: (m, l10n, locale) => m.unknown
        ? ''
        : switch (_kpi(m)?.rooms) {
            final r? => l10n.biSalesRoomBasis(
              biMoneyCell(r.chargesMinor, locale, _kpi(m)!.currency),
              biMoneyCell(r.costMinor, locale, _kpi(m)!.currency),
              '${r.uses}',
              '${r.rooms}',
            ),
            null => '',
          },
    notes: (m, l10n, locale) => _notes(m, l10n),
    details: (m, l10n, locale) => switch (_kpi(m)) {
      final k? => [
        l10n.biSalesRoomDefinition,
        if (!m.unknown)
          for (final room in k.rooms?.rows ?? const <RoomMargin>[])
            l10n.biSalesRoomLine(
              room.name,
              biMoneyCell(room.chargesMinor, locale, k.currency),
              biMoneyCell(room.costMinor, locale, k.currency),
              '${room.uses}',
            ),
      ],
      null => const [],
    },
  ),
};
