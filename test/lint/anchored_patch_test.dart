// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1092 — a migration that re-creates a function FROM SCRATCH silently
// discards every anchored patch applied to it since.
//
// `CREATE OR REPLACE FUNCTION` replaces the whole body. When 0185
// re-created `create_workspace` to add `p_environment` and
// `p_with_twin`, it dropped both rules later migrations had patched in:
// 0165's founder `member_number` and 0166's "an owner must have an
// e-mail address". Neither was noticed for weeks, because nothing looks
// at a function's history — and the e-mail rule still held in
// `activate_co_owner`, patched by the same 0166 block, so it applied to
// a co-owner and not to the person creating the space.
//
// The same class cost this project a day once already (#960/0175, the
// detailed invoices). This is the guard: adding a wholesale re-creation
// of a previously-patched function fails the build and names it, so the
// author carries the patches forward deliberately instead of finding
// out from a field report.
//
// A pair here is NOT necessarily a bug — three of the four below were
// verified against the live database and had kept their patches. The
// set is frozen so that NEW pairs must be argued for; it may shrink,
// never grow.

import 'package:flutter_test/flutter_test.dart';
import 'lint_sources.dart';

/// `function` re-created after being patched, each verified by hand.
/// Recorded as `function@recreating-migration`.
const _reviewed = {
  // #2356/0407 restates set_vat_rates from the LIVE dev definition
  // (pg_get_functiondef): 0170's anchored group_key / outside_base /
  // exemption_reason columns and 0180's has_permission('manageBilling')
  // are carried verbatim; the change is the DKV01 refusal of a new percent
  // on a rate in force while an invoice was issued. pgTAP 169 saves rates.
  'set_vat_rates@0407',
  // #2357/0402 restates mark_vat_declaration_submitted from the LIVE dev
  // definition (pg_get_functiondef): 0165's anchored DECL- number draw
  // (next_document_number when number = '') is carried verbatim; the
  // change is the channel (manual | export), the required receipt, the
  // prepared-only rule, the recompute check and the writer token.
  // pgTAP 166 files a return and asserts its DECL- number.
  'mark_vat_declaration_submitted@0402',
  // #2357/0406 restates it again from 0402's body (the LIVE dev
  // definition, md5-checked before the apply): 0165's DECL- draw is still
  // carried verbatim; the additions are the overlap refusal and the
  // vat_return_entries insert. pgTAP 166 and 169 file returns and assert
  // the number and the recorded entries.
  'mark_vat_declaration_submitted@0406',
  // #2145/0358 restates mcp_read_v1 whole. The LIVE dev body is 0275's
  // with 0345's one anchored change (free = mcp_seat_bookable(...) is
  // null), comments and blank lines aside; the new body keeps that verdict
  // and every other branch verbatim, and adds labels, the level/office
  // filters and an id-true cursor. pgTAP 144 drives availability paging,
  // the filters and the engine verdict.
  'mcp_read_v1@0358',
  // #2391/0411 restates mcp_read_v1 whole again from the LIVE dev body
  // (pg_get_functiondef, 0358's text): every branch verbatim except the
  // validation rows (own rows only under an `own` ceiling) and
  // availability over the four kinds, whose verdict moves from
  // mcp_seat_bookable to mcp_place_bookable (the same engine probe for any
  // kind). pgTAP 170 drives both; 129 pins the engine call.
  'mcp_read_v1@0411',
  // #2137/0361 restates create_invitation from the LIVE dev definition
  // (pg_get_functiondef), so every earlier anchored patch (environments,
  // handover, prod access) is carried; the one change is that a member
  // invitation also accepts manageMembers. pgTAP 146 drives it.
  'create_invitation@0361',
  // #1922/0334 restates sweep_payment_reminders and record_invoice_reminder
  // once more, from 0331's bodies (the live dev definitions): the row
  // lock, the feature gate and the shared invoice_dunning_state_core are
  // unchanged; the push moved into reminder_queue_push so its outcome is
  // recorded instead of swallowed. pgTAP 120 drives both paths.
  'sweep_payment_reminders@0334',
  'record_invoice_reminder@0334',
  // #1913/0331 restates sweep_payment_reminders and record_invoice_reminder
  // around the shared invoice_dunning_state_core. Both new bodies were
  // built from pg_get_functiondef on the LIVE dev project, which already
  // carried 0162's per-invoice row lock and 0227's feature_effective_in
  // gate; both are kept verbatim, and pgTAP 117 drives the sweep and the
  // manual path under real authenticated roles.
  'sweep_payment_reminders@0331',
  'record_invoice_reminder@0331',
  // #1276 S3/0230 re-creates preview_deployment as a caller of
  // configuration_change_set. The body was read from pg_get_functiondef on
  // the LIVE project, so 0190's design-image additions are carried forward
  // verbatim. A rolled-back harness captured the old output for all eight
  // live and fixture pair directions, applied 0230, and compared: identical.
  // The one deliberate difference is number series, which the old
  // entity_row_key misreported as removed and re-added.
  'preview_deployment@0230',
  // #1276 S1/0219 restates deployable_entities to add `merge_policy` and
  // `group` to each of the eighteen entities. The new body was built FROM
  // `pg_get_functiondef` on the live project — the post-patch state by
  // definition — and a rolled-back harness asserted that all five
  // pre-existing keys (key, kind, requires, workspace_keys, tables)
  // survive on all eighteen, so nothing an earlier migration established
  // was dropped. The function is pure data with no logic to lose.
  'deployable_entities@0219',
  // #1320/0217 restates next_document_number from pg_get_functiondef on
  // the LIVE project (post-patch by definition): the defaults upsert, the
  // gapless row lock and number_sequence_format are carried unchanged;
  // only the restart decision and the re-key were changed, and a
  // rolled-back pgTAP run drew every scenario of 15_number_series.sql.
  'next_document_number@0217',
  // 0185 lost BOTH patches. Restored by 0192, with a live harness.
  'create_workspace@0185',
  // 0180/0185 kept the 0139/0154 permission additions — verified in
  // pg_get_functiondef on the live project.
  'has_permission@0180',
  'has_permission@0185',
  // 0182 rewrote both for #985 (dated rate versions) and kept the
  // earlier rules; the 2-arg invoice_lines_for body still carries
  // 0156's credit-VAT coalesce, and set_vat_rates still carries
  // 0170's group_key / outside_base / exemption_reason.
  'invoice_lines_for@0182',
  'set_vat_rates@0182',
  // #1110/0200 adds `origin` to the three paths that create a member.
  // The bodies were not taken from an earlier migration file — they were
  // read out of `pg_get_functiondef` on the LIVE project, which is the
  // post-patch state by definition, and the one line each was added to
  // them. That is the only way to re-create a patched function without
  // guessing, and unlike carrying patches forward by hand it cannot
  // silently miss one.
  //
  // Verified afterwards by reading the live definitions back:
  // create_workspace still carries 0166's `user_has_email` and 0165's
  // `next_document_number`; join_workspace still carries 0165's numbering,
  // 0153's managed-identity claim and the member_join event;
  // create_managed_member still carries 0153's identity row and 0161's
  // data_access_log write.
  'create_workspace@0200',
  'join_workspace@0200',
  'create_managed_member@0200',
  // #1119/0201 adds the environment choice to create_invitation. Same
  // method as 0200's three: the body came out of `pg_get_functiondef`
  // on the live project, not from an older file. The old five-argument
  // signature is DROPPED in the same migration — an overload whose
  // extra parameter has a default is ambiguous against an exact-arity
  // sibling, and leaving both would have broken every existing caller.
  //
  // `join_workspace` is NOT in this list for 0201: that one is a
  // genuine anchored patch, with four asserted anchors and four
  // post-conditions, precisely so that this function is not re-created
  // twice in two migrations.
  'create_invitation@0201',
  // #1063/0202 gives create_workspace the feature flags to write at
  // creation. Body from `pg_get_functiondef` on the live project again,
  // and verified after applying: it still carries 0166's
  // `user_has_email`, 0165's numbering and #1110's 'founder'.
  //
  // The six-argument signature is dropped in the same migration, for
  // the reason 0201 discovered: an overload whose extra parameter has a
  // default is ambiguous against an exact-arity sibling, and the harness
  // reproduced the refusal ("function ... is not unique") before the
  // drop was added.
  'create_workspace@0202',
};

/// #2392 — from the facade's restatement on, an MCP function changes by
/// a whole new definition (a new `mcp_op_<id>` for a new operation), never
/// by an anchored patch of its live text. [sources] maps a migration's
/// four-digit number to its text; answers the offending numbers.
List<String> mcpAnchorPatches(Map<String, String> sources, {String since = '0412'}) => [
  for (final e in sources.entries)
    if (e.key.compareTo(since) >= 0 &&
        RegExp(r"pg_get_functiondef\(\s*'public\.mcp_|proname\s*=\s*'mcp_")
            .hasMatch(e.value))
      e.key,
]..sort();

void main() {
  test('#2392 no migration anchors a patch into an mcp_ function', () {
    final sources = {
      for (final f in sqlFiles('supabase/migrations'))
        f.uri.pathSegments.last.substring(0, 4): f.readAsStringSync(),
    };
    expect(mcpAnchorPatches(sources), isEmpty,
        reason: 'An MCP operation is a catalogue entry and its own '
            'mcp_op_<id> function; gates change in a whole mcp_authorize.');
  });

  test('#2392 the MCP anchor guard can fail', () {
    const fixture = '''
select pg_temp.anchor_replace(pg_get_functiondef('public.mcp_authorize(uuid, uuid, text)'::regprocedure),
  'if v_grant.id is null then', 'if false then');''';
    expect(mcpAnchorPatches({'0500': fixture, '0300': fixture}), ['0500']);
    expect(mcpAnchorPatches({'0500': "select proname = 'mcp_execute_v1'"}), ['0500']);
    expect(mcpAnchorPatches({'0500': 'create or replace function public.mcp_op_x(c public.mcp_call_context, p_args jsonb)'}),
        isEmpty);
  });

  test('no migration re-creates a function a later-unreviewed patch owns',
      () {
    final files = sqlFiles('supabase/migrations');

    final patchedIn = <String, List<String>>{};
    final recreatedIn = <String, List<String>>{};

    for (final file in files) {
      final number = file.uri.pathSegments.last.substring(0, 4);
      final source = file.readAsStringSync();
      // A patch reads the live body and rewrites it at an anchor.
      for (final m
          in RegExp(r"proname\s*=\s*'(\w+)'").allMatches(source)) {
        (patchedIn[m.group(1)!] ??= []).add(number);
      }
      for (final m in RegExp(r'create or replace function public\.(\w+)')
          .allMatches(source)) {
        (recreatedIn[m.group(1)!] ??= []).add(number);
      }
    }

    final offenders = <String>[];
    for (final entry in patchedIn.entries) {
      final lastPatch = entry.value.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      for (final recreation in recreatedIn[entry.key] ?? const <String>[]) {
        if (recreation.compareTo(lastPatch) <= 0) continue;
        final key = '${entry.key}@$recreation';
        if (!_reviewed.contains(key)) offenders.add(key);
      }
    }

    expect(offenders, isEmpty,
        reason: 'These functions are re-created wholesale AFTER a '
            'migration patched them at an anchor, so the patch is gone '
            'unless the new body repeats it:\n  ${offenders.join('\n  ')}\n'
            'Carry the earlier rules forward, verify against the LIVE '
            'function with pg_get_functiondef — not against the migration '
            'text — and then add the pair to _reviewed with what you '
            'checked.');
  });

  test('the reviewed set has not gone stale', () {
    // Every entry must still describe a real pair; a removed migration
    // or a renamed function should shrink this list, not be forgotten.
    final numbers = sqlFiles('supabase/migrations')
        .map((f) => f.uri.pathSegments.last.substring(0, 4))
        .toSet();
    for (final key in _reviewed) {
      expect(numbers, contains(key.split('@').last),
          reason: '$key names a migration that no longer exists');
    }
  });
}
