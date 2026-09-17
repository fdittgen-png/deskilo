// SPDX-License-Identifier: 0BSD
//
// #1310 S2 — every table a workspace owns is either in the export or
// exempt on the record.
//
// The workspace Excel export (#395) writes eleven tabs. The schema has
// forty-five tables carrying a `workspace_id`. Nothing said which of
// the rest were a deliberate omission and which were simply never
// considered, and no test would have noticed a forty-sixth arriving.
//
// An operator's export is their copy of their own space. What it leaves
// out has to be an argument rather than an accident — so each exclusion
// below carries its reason, and a new workspace-scoped table with no
// decision fails this test.
//
// The same shape as `gdpr_export_coverage_test` (#1238), which asks the
// same question of the member's subject-access export.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `public.<table>` in the migrations that carries a
/// `workspace_id` column — read from the migrations rather than a live
/// database, because CI has the files and not the project.
Set<String> _workspaceScopedTables() {
  final dir = Directory('supabase/migrations');
  final files = dir.listSync().whereType<File>().toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));

  final create = RegExp(
    r'create table (?:if not exists )?public\.(\w+)\s*\((.*?)\n\);',
    dotAll: true,
  );
  // `alter table … add column workspace_id` — a table can gain the
  // column long after it was created.
  final added = RegExp(
    r'alter table (?:only )?public\.(\w+)[\s\S]{0,200}?'
    r'add column (?:if not exists )?workspace_id',
    caseSensitive: false,
  );

  final scoped = <String>{};
  final dropped = <String>{};
  for (final f in files) {
    if (!f.path.endsWith('.sql')) continue;
    final sql = f.readAsStringSync();
    for (final m in create.allMatches(sql)) {
      if (m.group(2)!.contains('workspace_id')) scoped.add(m.group(1)!);
    }
    for (final m in added.allMatches(sql)) {
      scoped.add(m.group(1)!);
    }
    for (final m in RegExp(r'drop table (?:if exists )?public\.(\w+)')
        .allMatches(sql)) {
      dropped.add(m.group(1)!);
    }
  }
  return scoped.difference(dropped);
}

/// The tables the workbook writes, tab by tab. `buildWorkspaceExcelExport`
/// is a pure function over already-fetched lists, so this names the
/// SOURCE of each argument it takes rather than the tab titles.
const Set<String> _exported = {
  'workspaces', // Workspace tab (the row itself)
  'levels', // Levels
  'offices', // Desks tab — offices and desks are one plan tree
  'desks', // Desks
  'seats', // Seats
  'members', // Users
  'reservations', // Reservations + Check-ins
  'ledger_entries', // Payments
  'payment_intents', // Payments
  'events', // pending events, on the Reservations side
  'services', // Services + Service catalog
  'invoices', // Invoices
  'invoice_transmissions', // Invoices (the e-invoice column)
};

/// Workspace-scoped tables the export does NOT carry, and why each is
/// right to leave out.
///
/// Deleting a line here without exporting the table is how an export
/// quietly becomes partial, so each one is an argument somebody has to
/// disagree with in review.
const Map<String, String> _notExported = {
  // --- secrets: exporting them would hand over a credential ---------
  'payment_credentials':
      'a payment provider secret. An export is copied, mailed and left '
          'in a downloads folder; a credential must not travel that way',
  'einvoice_credentials':
      'as above — the platform credential that lets the workspace '
          'transmit invoices in its own name',

  // --- audit logs: the operator's own record, not their data --------
  'data_access_log':
      'who looked at what, written by the server. It is evidence about '
          'the operator, and an export they control must not be its only '
          'copy',
  'platform_access_log':
      "the platform owner's audit of their own access — not the "
          "workspace's data at all",

  // --- derived: recomputed from what IS exported --------------------
  'invoice_matches':
      'the reconciliation between an invoice and its payments, derived '
          'from invoices and ledger_entries, both exported',
  'invoice_match_payments':
      'the junction under invoice_matches, derived the same way',
  'expense_repartitions':
      'how one cost was split — derived from the expense and the '
          'members, and meaningless without the schedule it belongs to',
  'expense_occurrences':
      'one instance of a scheduled cost, regenerated from '
          'expense_schedules',
  'usage_records':
      'consumption already summed onto the invoices that are exported; '
          'the raw rows are an accounting intermediate',

  // --- configuration: the configuration export owns these -----------
  'accessories': 'workspace configuration — export_workspace_configuration',
  'seat_accessories': 'configuration: which seat carries which accessory',
  'closure_days': 'configuration: the calendar of closed days',
  'fee_bands': 'configuration: the pricing bands',
  'packages': 'configuration: the subscription catalogue',
  'plans': 'configuration: the floor plan, exported as Levels/Desks/Seats',
  'plan_images': 'configuration: plan backgrounds, storage paths',
  'sites': 'configuration: the sites and their addresses',
  'validation_policies': 'configuration: which events need a decision',
  'vat_rates': 'configuration: the rate catalogue',
  'number_sequences': 'configuration: invoice numbering state',
  'workspace_documents': 'configuration: the document library',

  // --- operational state, not a record of the space -----------------
  'deployments':
      'a dev/prod transfer log belonging to the environment pair, not '
          'to either workspace',
  'invitations':
      'pending invitations are transient, and each names a person who '
          'is not yet a member',
  'member_badges':
      'a badge identifier is an access credential; #662 governs it',
  'member_notes':
      "notes written ABOUT a member by an administrator — the member's "
          'own copy is the subject-access export, not this one',
  'conversations':
      'messages between members. The operator is not a party to them, '
          'and a bulk export would hand over private correspondence',
  'managed_identities':
      'a profile the workspace holds until its person claims it; the '
          'member rows are exported',
  'invoice_reminders': 'dunning state, regenerated from the invoices',
  'price_negotiations': 'a per-member agreed price; part of membership',
  'quota_extensions': 'a granted exception, part of membership',
  'credit_products': 'configuration: the carnet catalogue (#1279)',
  'member_credits':
      '#1279 — a carnet sale; its charge is in ledger_entries, exported, and '
          'the member\'s own copy is the subject-access export',
  'member_credit_uses':
      '#1279 — which reservation drew on which carnet; both reservations '
          'and the sale\'s charge are exported',
  'workspace_creation_requests':
      '#1303 — the claim a creation request made, keyed by the creator; it '
          'belongs to the act of creating, and the workspace it made is the '
          'export itself',
  'workspace_template_applications':
      '#1276 — when a template was applied and what the workspace held '
          'before; the configuration it changed is exported itself',
  'reservation_requests':
      'a request that became a reservation or was refused — the '
          'reservations themselves are exported',
  'expense_schedules':
      'the recurring-cost configuration; its occurrences are derived',
  'vat_declarations':
      'a filed declaration is a document, produced by the VAT report '
          'rather than carried as rows',
};

void main() {
  test('every workspace-scoped table is exported or exempt with a reason '
      '(#1310 S2)', () {
    final scoped = _workspaceScopedTables();
    expect(
      scoped,
      isNotEmpty,
      reason: 'the migration scan found no workspace_id tables at all — '
          'the regexes stopped matching, which would make this whole '
          'test vacuous',
    );

    final decided = {..._exported, ..._notExported.keys};
    final undecided = scoped.difference(decided).toList()..sort();

    expect(
      undecided,
      isEmpty,
      reason: 'these tables carry a workspace_id and the workspace '
          'export neither includes them nor says why not:\n'
          '${undecided.join('\n')}\n\n'
          'Add each to _exported (and to the workbook) or to '
          '_notExported with the reason it is right to leave out. An '
          "operator's export of their own space may be partial, but not "
          'by accident (#1310).',
    );
  });

  test('every exemption names a table that exists', () {
    // A reason for a table nobody has any more is a comment pretending
    // to be a decision — and it hides the real question when the table
    // comes back under another name.
    final scoped = _workspaceScopedTables();
    final stale = _notExported.keys
        .where((t) => !scoped.contains(t))
        .toList()
      ..sort();
    expect(
      stale,
      isEmpty,
      reason: 'these exemptions name tables that no longer carry a '
          'workspace_id (renamed, dropped, or never existed):\n'
          '${stale.join('\n')}',
    );
  });

  test('nothing is both exported and exempt', () {
    final both = _exported.intersection(_notExported.keys.toSet()).toList()
      ..sort();
    expect(both, isEmpty,
        reason: 'a table cannot be both in the export and exempt from '
            'it — one of the two lists is wrong:\n${both.join('\n')}');
  });
}
