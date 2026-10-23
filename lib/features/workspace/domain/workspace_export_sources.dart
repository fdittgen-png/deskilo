// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2859 — what the workspace workbook (`workspace_excel.dart`) carries, as
// data: each source table, the sheet it lands on, the columns whose value
// reaches the sheet (resolved references count: a member id written as the
// member's name), and whether every row goes out. The export coverage lint
// reads this instead of a list of its own, and measures it against the
// columns the migrations leave behind.
import 'package:meta/meta.dart';

/// One table the workbook reads.
class ExportSource {
  const ExportSource(
    this.table, {
    required this.sheets,
    required this.columns,
    this.partial,
  });

  /// The `public.<table>` the rows come from.
  final String table;

  /// The sheets its values land on.
  final List<String> sheets;

  /// The table's columns whose values reach a sheet.
  final Set<String> columns;

  /// Null when every row of the table is written; otherwise which rows are,
  /// as a sentence. A partial source is counted until it carries every row.
  final String? partial;
}

/// Every source of the workspace workbook (#395, #1310).
@visibleForTesting
const List<ExportSource> workspaceExportSources = [
  ExportSource(
    'workspaces',
    sheets: ['Workspace'],
    columns: {
      'id',
      'name',
      'country_code',
      'currency_code',
      'timezone',
      'invite_code',
      'vat_regime',
      'vat_id',
      'legal_id',
      'street',
      'postal_code',
      'city',
      'feature_flags',
    },
  ),
  ExportSource(
    'levels',
    sheets: ['Levels'],
    columns: {'id', 'name', 'sort_order', 'bookable_as_whole', 'price_cents'},
  ),
  ExportSource(
    'offices',
    sheets: ['Offices', 'Desks'],
    columns: {
      'id',
      'level_id',
      'name',
      'area_kind',
      'x',
      'y',
      'w',
      'h',
      'color',
      'bookable_as_whole',
      'price_cents',
    },
  ),
  ExportSource(
    'desks',
    sheets: ['Desks', 'Seats'],
    columns: {
      'id',
      'office_id',
      'name',
      'x',
      'y',
      'w',
      'h',
      'bookable_as_whole',
      'price_cents',
    },
  ),
  ExportSource(
    'seats',
    sheets: ['Seats'],
    columns: {
      'id',
      'desk_id',
      'name',
      'x',
      'y',
      'orientation',
      'chair',
      'amenities',
      'blocked_from',
      'blocked_to',
      'resource_kind',
      'capacity',
      'parking_kind',
      'slot_minutes',
    },
  ),
  ExportSource(
    'members',
    sheets: ['Users'],
    columns: {
      'id',
      'user_id',
      'status',
      'is_owner',
      'is_admin',
      'is_kiosk',
      'subscription_pct',
      'overage_policy',
      'member_number',
      'joined_at',
      'co_owner',
      'vat_treatment',
      'payment_terms',
      'managed_identity',
    },
  ),
  ExportSource(
    'profiles',
    sheets: ['Users'],
    columns: {
      'display_name',
      'country_code',
      'vat_id',
      'address',
      'whatsapp',
      'last_seen_at',
      'first_name',
      'last_name',
      'company',
      'street',
      'postal_code',
      'city',
      'email',
      'phone',
      'legal_id',
    },
    partial: 'the profiles of this workspace\'s members only',
  ),
  ExportSource(
    'reservations',
    sheets: ['Reservations', 'Check-ins'],
    columns: {
      'id',
      'member_id',
      'seat_id',
      'desk_id',
      'office_id',
      'level_id',
      'starts_at',
      'ends_at',
      'status',
      'series_id',
      'series_pattern',
      'checked_in_at',
      'checked_out_at',
    },
  ),
  ExportSource(
    'ledger_entries',
    sheets: ['Ledger', 'Payments', 'Services'],
    columns: {
      'id',
      'member_id',
      'kind',
      'category',
      'amount_cents',
      'period',
      'occurred_on',
      'created_at',
      'description',
    },
  ),
  ExportSource(
    'payment_intents',
    sheets: ['Payments'],
    columns: {
      'member_id',
      'amount_cents',
      'period',
      'created_at',
      'provider',
      'order_id',
      'status',
    },
  ),
  ExportSource(
    'events',
    sheets: ['Events', 'Decisions', 'Payments', 'Services'],
    columns: {
      'id',
      'type',
      'action',
      'status',
      'subject_member_id',
      'actor_member_id',
      'payload',
      'created_at',
      'decided_at',
    },
  ),
  ExportSource(
    'event_decisions',
    sheets: ['Decisions'],
    columns: {
      'event_id',
      'member_id',
      'decision',
      'decided_by_system',
      'decided_at',
    },
  ),
  ExportSource(
    'services',
    sheets: ['Service catalog'],
    columns: {'id', 'name', 'price_cents', 'active'},
  ),
  ExportSource(
    'invoices',
    sheets: ['Invoices'],
    columns: {
      'id',
      'number',
      'member_id',
      'period',
      'issued_at',
      'total_cents',
      'currency',
      'voided_at',
      'replaces_number',
      'details',
      'kind',
      'title',
      'vat_totals',
      'lines',
      'issuer_name',
    },
  ),
  ExportSource(
    'invoice_maturities',
    sheets: ['Invoices'],
    columns: {'invoice_id', 'due_on'},
  ),
  ExportSource(
    'invoice_transmissions',
    sheets: ['Invoices'],
    columns: {'invoice_id', 'sent_at'},
    partial: 'the last sending time of each invoice only',
  ),
];
