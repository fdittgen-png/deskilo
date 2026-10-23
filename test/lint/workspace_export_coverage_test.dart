// SPDX-License-Identifier: AGPL-3.0-or-later
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

import 'dart:convert';
import 'dart:io';

import 'package:deskilo/features/workspace/domain/workspace_export_sources.dart';
import 'package:flutter_test/flutter_test.dart';

import 'export_schema.dart';
import 'lint_sources.dart';

/// Every `public.<table>` in the migrations that carries a
/// `workspace_id` column — read from the migrations rather than a live
/// database, because CI has the files and not the project.
Set<String> _workspaceScopedTables() {
  final files = sqlFiles('supabase/migrations');

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

/// The tables the workbook writes — read from the workbook's own
/// declaration (#2859), so the lint and the builder cannot disagree.
final Set<String> _exported = {
  for (final s in workspaceExportSources) s.table,
};

/// Workspace-scoped tables the export does NOT carry, and why each is
/// right to leave out.
///
/// Deleting a line here without exporting the table is how an export
/// quietly becomes partial, so each one is an argument somebody has to
/// disagree with in review.
const Map<String, String> _notExported = {
  'workspace_favorites': 'a person\'s own favourite workspaces (#2185): personal data returned by export_my_data to the person it belongs to, not a workspace\'s portable configuration',
  'workspace_ratings': 'a person\'s own 0-5 star ratings of workspaces (#2185): personal data returned by export_my_data to the person it belongs to, not a workspace\'s portable configuration',
  'resource_favorites': 'a member\'s own marks on places (#2185): personal data, returned by export_my_data to the member it belongs to; the places they point at are exported',
  'resource_ratings': 'a member\'s own 0-5 star ratings of places (#2185): personal data, returned by export_my_data to the member it belongs to, not portable configuration',
  'analytics_history': 'when this installation began recording analytics history (#1920); a fact about this installation, not portable configuration — an imported space starts its own history',
  'seat_history': 'analytics evidence written by triggers on this installation (#1920); the seats it describes are exported, and an import records history from the rows it creates',
  'opening_hours_history': 'analytics evidence written by triggers on this installation (#1920); the booking rules it describes are exported',
  'reservation_origins': 'which assistant created a booking, audit evidence of this installation\'s MCP channel (#2145); the reservations it describes are exported',
  'reservation_target_history': 'analytics evidence written by triggers on this installation (#1920); the reservations it describes are exported',
  'retired_invite_codes': 'withdrawn invitation secrets of this installation, kept only to answer "revoked"; never portable configuration (#1652)',
  'workspace_licences': 'the platform\'s licence record (non-profit verification, negotiated plan, billing reference) is not the space\'s data to export or import (0367)',
  'workspace_public_pages': 'publication consent is installation-specific; importing a workspace must not publish it (#1791)',
  'public_workspace_cards': 'derived public projection regenerated only by explicit publication on this installation (#1791)',
  'account_field_audience_spaces': 'a person\'s own choice of which of their spaces sees a field of their account (#1823); it belongs to the account, not to the space, and travels in that person\'s own export',
  'space_inquiries': 'correspondence between a space\'s hosts and a person OUTSIDE it (#1824), readable only by that person and the hosts; an operator\'s export must not carry a stranger\'s messages, and the requester\'s own export does',
  'workspace_applications': 'account-bound request ownership is not portable workspace configuration (#1791)',
  'workspace_application_messages': 'private applicant/reviewer correspondence belongs in subject-access export, not a bulk workspace workbook (#1791)',
  // #1610/#1612 — MCP exposure and consent are authority, not data: an
  // export that carried them would re-activate a workspace's MCP exposure
  // or a person's consent wherever it was imported.
  'workspace_mcp_policies': 'MCP exposure is authority; an import must not re-enable it (#1610)',
  'workspace_mcp_policy_revisions': 'the history of that authority, same reason (#1610)',
  'mcp_connection_scopes': 'a person\'s consent to an assistant, never portable (#1612)',
  'mcp_idempotency': 'replay records of MCP calls, operational state only (#1612)',
  'mcp_action_confirmations': 'a person\'s pending confirmation of an assistant request, never portable (#1619)',
  'mcp_usage': 'the audit of MCP calls and the count the limits read, operational state only (#1630)',
  'bi_views': 'saved Web-BI views (#1923 C) are questions a reader asked of this installation\'s analytics, kept under its rights; a private one travels in its author\'s access export, and none is portable configuration',
  'workspace_recovery_evidence': 'the record that an export was taken; a copy of it would claim a backup the copy never had (#1636)',
  'readiness_acknowledgements': 'a person\'s own "later" on a setup section, per installation; a copy must re-ask (#1636)',
  'sample_data_batches': 'which sample data this test space generated (#2872); it names rows of this server, and the sample rows themselves are exported like any other until they are cleared',
  'sample_data_records': 'the ids of one sample batch\'s rows (#2872), so clearing removes exactly them; they name rows of this server',
  'setup_step_drafts': 'a setup step\'s unfinished answers (#2869), never configuration; the copy re-asks, and what was applied is exported where it lives',
  // --- the workspace's own questions (#1288) ------------------------
  'workspace_field_labels': 'the question in each language; the definition '
      'itself is exported whole (0540)',
  'workspace_field_options': 'the choices of a choice question; as above',
  'workspace_field_option_labels': 'the choices in each language; as above',
  'privacy_notices':
      'the published privacy notices (#1914); public text every member '
          'reads in the app, and the installation\'s own rows belong to no '
          'space at all',
  'reminder_intents':
      'one row per payment reminder and its delivery status (#1922); the '
          'invoices tab already shows reminders, and this is collection '
          'evidence, not data an operator re-imports',
  'reminder_attempts':
      'the append-only delivery evidence of each reminder (#1922); as above',
  'workspace_field_value_options':
      'which choices one member made; personal in the same way',
  'workspace_field_retention_holds':
      'a documented legal basis for keeping one question\'s answers after '
          'erasure (#1912); it governs personal data, so it stays with the '
          'owner and the privacy policy rather than in a spreadsheet',

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
  'invoice_match_payments':
      'the junction under invoice_matches, which is exported whole (0540)',

  // --- configuration: the configuration export owns these -----------
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
  'purchase_settlement_allocations':
      '#2574 — the append-only link from a claim to a payment; it names rows '
          'of this server',
  'purchase_sources':
      '#2573 — the links from a purchase to the expenses and invoices that '
          'evidence it; they name rows of this server',
  'financial_command_receipts':
      '#2585 — the receipt of a native financial command attempt (request id and '
          'the invoice or event it made); technical recovery state, never a '
          'workbook row',
  'purchase_requests':
      '#2573 — replay ledger of the purchase writes (request ids and their '
          'committed answers); technical, never a workbook row',
  'purchase_commitment_matches':
      '#2575 — the append-only link from a lease\'s expected rent to the bill '
          'lines that replaced it; it names rows of this server',
  'room_rental_audience':
      '#2568 — who may book a rented room; it names members and plans of this '
          'server',
  'reservation_charges':
      '#2575 — the quote behind a ledger charge for a rented room; it names '
          'reservations and ledger rows of this server',
  'bi_cost_allocation_rules':
      '#2582 — how this server\'s space spreads its shared costs over its '
          'resources, by revision; a fresh space imports no rule it did not '
          'write',
  'book_exports':
      '#2365 — the log of the files this server handed out, with their '
          'sha256; it describes exports of this server only',
  'supplier_bank_revisions':
      '#2567 — sensitive payee bank details and their change history; '
          'never part of a workbook that is shared on',
  'supplier_review_candidates':
      '#2567 — a transient to-do (which invoice waits for a supplier '
          'decision), derived from the source documents',
  'vat_return_entries':
      '#2357 — what a filed VAT return declared, per document; it belongs '
          'to the filing on this server and is recomputed from nothing a '
          'fresh space could import',
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

  // #2859 — the table list above says which tables are decided. These
  // measure what the decisions leave open, in a baseline that may only
  // fall: the columns of an exported table that reach no sheet, the
  // sources that write only some of their rows, the tables with no
  // workspace_id that hang off a workspace table and were never decided,
  // and the exemptions that argue about importing into a fresh space —
  // which says nothing about the operator's copy of their own data.
  test('what the export leaves open only shrinks (#2859)', () {
    final actual = _openItems();
    final file = File(_baselinePath);
    if (Platform.environment['UPDATE_EXPORT_COVERAGE'] == '1') {
      file.writeAsStringSync(
          '${const JsonEncoder.withIndent('  ').convert(actual)}\n');
    }
    final baseline = (jsonDecode(file.readAsStringSync()) as Map)
        .map((k, v) => MapEntry(k as String,
            (v as List).map((e) => e as String).toSet()));
    final added = <String>[];
    final gone = <String>[];
    for (final key in {...actual.keys, ...baseline.keys}) {
      final now = actual[key]?.toSet() ?? const <String>{};
      final then = baseline[key] ?? const <String>{};
      added.addAll(now.difference(then).map((e) => '$key: $e'));
      gone.addAll(then.difference(now).map((e) => '$key: $e'));
    }
    expect(added, isEmpty,
        reason: 'new open items — export them (declare them in '
            'workspace_export_sources.dart) or give a reason:\n'
            '${added.join('\n')}');
    expect(gone, isEmpty,
        reason: 'these are decided now — lower $_baselinePath by running '
            'this test with UPDATE_EXPORT_COVERAGE=1:\n${gone.join('\n')}');
  });

  test('the tables written whole are the ones the server answers (#2860)',
      () {
    final sql = sqlFiles('supabase/migrations')
        .lastWhere((f) => f
            .readAsStringSync()
            .contains('function public.export_workspace_records('))
        .readAsStringSync();
    final list = RegExp(r"v_tables text\[\] := array\[(.*?)\];", dotAll: true)
        .firstMatch(sql)!
        .group(1)!;
    final server = RegExp(r"'([a-z_]+)'").allMatches(list).map((m) => m[1]!)
        .toSet();
    final declared = {
      for (final s in workspaceExportSources)
        if (s.everyColumn) s.table,
    };
    expect(declared, server);
  });

  test('the column replay sees what the export needs (#2859)', () {
    final schema = replaySchema();
    for (final source in workspaceExportSources) {
      final table = schema[source.table];
      expect(table, isNotNull, reason: '${source.table} is not a table');
      final unknown = source.columns.difference(table!.columns);
      expect(unknown, isEmpty,
          reason: '${source.table} declares columns it does not have');
    }
    expect(schema['seats']!.columns, contains('parking_kind'));
    expect(schema['event_decisions']!.references, contains('events'));
  });
}

const _baselinePath = 'docs/design/EXPORT_COVERAGE_BASELINE.json';

/// An exemption whose reason is about importing into another space: right
/// for the configuration transfer, no argument against the operator's own
/// copy. A reason that is truly transfer-only says `[transfer-only]`.
final _importArgument =
    RegExp(r'\bimport|fresh space', caseSensitive: false);

Map<String, List<String>> _openItems() {
  final schema = replaySchema();
  final scoped = _workspaceScopedTables();
  final decided = {..._exported, ..._notExported.keys};
  List<String> sorted(Iterable<String> it) => it.toList()..sort();
  return {
    for (final source in workspaceExportSources)
      if (schema[source.table] case final table?)
        'columns.${source.table}': sorted(table.columns
            .difference(source.everyColumn ? table.columns : source.columns)
            .difference(systemColumns)
            // The export is of one workspace: its id is the whole file's.
            .difference(const {'workspace_id'})
            .difference(_notExportedColumns[source.table] ?? const {})),
    'partialSources': sorted([
      for (final s in workspaceExportSources)
        if (s.partial != null) s.table,
    ]),
    'undecidedChildTables': sorted([
      for (final t in schema.values)
        if (!t.columns.contains('workspace_id') &&
            !decided.contains(t.name) &&
            t.references.any(scoped.contains))
          t.name,
    ]),
    'importArguedExemptions': sorted([
      for (final MapEntry(:key, :value) in _notExported.entries)
        if (_importArgument.hasMatch(value) &&
            !value.startsWith('[transfer-only]'))
          key,
    ]),
  };
}

/// Columns of an exported table left out on purpose, and why.
const Map<String, Set<String>> _notExportedColumns = {
  'einvoice_inbox': {
    // The received document itself: it travels as a file of its own, not
    // as one cell of a sheet (0540).
    'source_xml',
  },
  'profiles': {
    // The hash of a person's badge PIN (#662): a credential, never in a
    // workbook that is shared on.
    'pin_hash',
  },
};
