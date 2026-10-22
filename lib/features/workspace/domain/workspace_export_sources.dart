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
  }) : everyColumn = false;

  /// #2860 — a table `export_workspace_records` (0540) writes whole: every
  /// column the schema holds, on a sheet named after the table.
  const ExportSource.everyColumn(this.table)
      : sheets = const [],
        columns = const {},
        partial = null,
        everyColumn = true;

  /// The `public.<table>` the rows come from.
  final String table;

  /// The sheets its values land on.
  final List<String> sheets;

  /// The table's columns whose values reach a sheet.
  final Set<String> columns;

  /// Null when every row of the table is written; otherwise which rows are,
  /// as a sentence. A partial source is counted until it carries every row.
  final String? partial;

  /// Every column of the table travels, whatever the schema adds later.
  final bool everyColumn;
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
  // #2860 — written whole by export_workspace_records (0540).
  ExportSource.everyColumn('sites'),
  ExportSource.everyColumn('plans'),
  ExportSource.everyColumn('fee_bands'),
  ExportSource.everyColumn('packages'),
  ExportSource.everyColumn('credit_products'),
  ExportSource.everyColumn('vat_rates'),
  ExportSource.everyColumn('accessories'),
  ExportSource.everyColumn('seat_accessories'),
  ExportSource.everyColumn('closure_days'),
  ExportSource.everyColumn('validation_policies'),
  ExportSource.everyColumn('workspace_roles'),
  ExportSource.everyColumn('workspace_role_members'),
  ExportSource.everyColumn('workspace_field_definitions'),
  ExportSource.everyColumn('workspace_field_values'),
  ExportSource.everyColumn('number_sequences'),
  ExportSource.everyColumn('charging_stations'),
  ExportSource.everyColumn('plan_images'),
  ExportSource.everyColumn('setting_values'),
  ExportSource.everyColumn('member_credits'),
  ExportSource.everyColumn('member_credit_uses'),
  ExportSource.everyColumn('price_negotiations'),
  ExportSource.everyColumn('quota_extensions'),
  ExportSource.everyColumn('usage_records'),
  ExportSource.everyColumn('invoice_matches'),
  ExportSource.everyColumn('invoice_reminders'),
  ExportSource.everyColumn('invoice_dunning_holds'),
  ExportSource.everyColumn('tax_exemption_certificates'),
  ExportSource.everyColumn('suppliers'),
  ExportSource.everyColumn('purchase_documents'),
  ExportSource.everyColumn('purchase_lines'),
  ExportSource.everyColumn('purchase_obligations'),
  ExportSource.everyColumn('outgoing_payments'),
  ExportSource.everyColumn('expense_schedules'),
  ExportSource.everyColumn('expense_occurrences'),
  ExportSource.everyColumn('expense_repartitions'),
  ExportSource.everyColumn('premises_leases'),
  ExportSource.everyColumn('lease_terms'),
  ExportSource.everyColumn('lease_settlements'),
  ExportSource.everyColumn('room_rentals'),
  ExportSource.everyColumn('room_rental_fees'),
  ExportSource.everyColumn('workspace_assets'),
  ExportSource.everyColumn('asset_valuation_batches'),
  ExportSource.everyColumn('asset_valuation_rows'),
  ExportSource.everyColumn('book_profiles'),
  ExportSource.everyColumn('book_accounts'),
  ExportSource.everyColumn('book_mappings'),
  ExportSource.everyColumn('book_periods'),
  ExportSource.everyColumn('vat_declarations'),
  ExportSource.everyColumn('einvoice_inbox'),
  ExportSource.everyColumn('guest_participations'),
  ExportSource.everyColumn('rights_requests'),
];
