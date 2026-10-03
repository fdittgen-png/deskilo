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
  'analytics_history': 'when this installation began recording analytics history (#1920); a fact about this installation, not portable configuration — an imported space starts its own history',
  'seat_history': 'analytics evidence written by triggers on this installation (#1920); the seats it describes are exported, and an import records history from the rows it creates',
  'opening_hours_history': 'analytics evidence written by triggers on this installation (#1920); the booking rules it describes are exported',
  'reservation_target_history': 'analytics evidence written by triggers on this installation (#1920); the reservations it describes are exported',
  'retired_invite_codes': 'withdrawn invitation secrets of this installation, kept only to answer "revoked"; never portable configuration (#1652)',
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
  'book_accounts': 'an issuer\'s chart of accounts is reviewed on this installation by someone who manages billing, never copied with the data (#1869)',
  'book_mappings': 'which account each posting role books to is a reviewed finance decision of this installation, never copied with the data (#1869)',
  'book_profiles': 'who keeps the official books of each issuer is a finance decision taken on this installation, never copied with the data (#1869)',
  'workspace_recovery_evidence': 'the record that an export was taken; a copy of it would claim a backup the copy never had (#1636)',
  'readiness_acknowledgements': 'a person\'s own "later" on a setup section, per installation; a copy must re-ask (#1636)',
  'guest_participations': 'a person\'s visit to a space, bound to their local account on this installation; a copy would admit somebody the target never admitted (#1835)',
  // --- authority a copy must not carry by itself (#1287) ------------
  'workspace_role_members':
      'a grant names a member, and members do not travel — a role given '
          'to somebody in the development twin means nothing in a space '
          'where that person does not exist. It IS the subject\'s own '
          'data, so export_my_data carries it (0247)',
  'workspace_roles':
      'configuration: the roles a workspace invented for itself. They '
          'travel with a template and a deployment as their own entity '
          '(0251, #1505) — the definitions only, which is what makes it '
          'safe, because a role that arrives holds nobody',

  // --- the workspace's own questions (#1288) ------------------------
  'workspace_field_definitions':
      'configuration: a question the workspace asks. It travels with a '
          'template as its own entity, with the conflict rules a type '
          'change needs (0250, #1288 S5)',
  'workspace_field_labels': 'the question in each language; it travels '
      'with the definition above',
  'workspace_field_options': 'the choices of a choice question; as above',
  'workspace_field_option_labels': 'the choices in each language; as above',
  'workspace_field_values':
      'an answer is the member\'s personal data, not the operator\'s copy '
          'of their space — export_my_data carries it (0248), and a '
          'template must never carry answers',
  'invoice_maturities':
      'the due date frozen for each invoice at issue (#1913); derived from '
          'the invoice and the payment term, so the invoices tab already '
          'carries what an operator needs',
  'invoice_dunning_holds':
      'why an invoice is not being reminded (#1913); an operational state '
          'of the dunning flow, not a record the operator re-imports',
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
  'rights_requests':
      'a person\'s requests to exercise their data-protection rights '
          '(#1915); they belong to the requester\'s own export, not to the '
          'operator\'s spreadsheet of the space',
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
  'credit_products':
      'configuration: the carnet catalogue (#1279). It travels with a '
          'template and a deployment as its own entity (0262, #1271) — '
          'the offer only, never a sale',
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
