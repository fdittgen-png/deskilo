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
  // #4479/0968 restates stock_to_inventory, stock_unit_factor and workspace_unit_convert from the bodies the earlier patches
  // left (0747/0836/0951 with 0952's item units and 0963's package dimension): the dimension step is replaced by
  // unit_factor/unit_convert, every other line is theirs. Proved on dev rolled back: 27 cases, parity table 15 cases.
  'stock_to_inventory@0968',
  'stock_unit_factor@0968',
  'workspace_unit_convert@0968',
  // #4448/0958 restates has_permission_raw from the LIVE dev definition (pg_get_functiondef at schema 956, the body every
  // later patch left: the custom roles branch, the co-owner, admin and member branches and the adminInvoicing grant) and
  // adds only 'configureTill' to the admin defaults; pgTAP 571 green on dev with 0958 and 0959, rolled back.
  'has_permission_raw@0958',
  // #4476/0964 restates has_permission_raw from 0958's text (the live dev body at schema 959, nothing patched it since) and
  // adds only 'overrideTillPrice' to the admin defaults; pgTAP 573 green on dev with 0964 and 0965, rolled back.
  'has_permission_raw@0964',
  // #4492/0976 restates counter_goods_return_v1 from the replayed body (the effective schema of Quality run 45834744067,
  // master at schema 974): 0897's text with the one condition 0973 patched in, a returned deposit refused, carried over.
  // What differs is the return itself: the sale's own movements, lot by lot, bounded by what is still out, recorded as
  // a reversal. pgTAP 587, 525, 580 and 581 green on the replay with it (Tools · Database preview).
  'counter_goods_return_v1@0976',
  // #4476/0965 patches counter_receipt_draft_v1 at one asserted anchor of its live dev body (0894 + 0908): its lines pass
  // counter_line_prices first. pgTAP 573 green, and every counter suite (520-532, 553-570) unchanged with it, rolled back.
  'counter_receipt_draft_v1@0965',
  // #4476/0965 patches counter_offline_sync_v1 at one asserted anchor of its live dev body (0944): before it drafts a sale it
  // marks its transaction (deskilo.counter_offline_sync), the only way a line keeps the offline price tolerance. 555 and 570
  // green with it, rolled back.
  'counter_offline_sync_v1@0965',
  // #4436/0947 restates counter_receipt_finalize_v1 from the LIVE dev body (pg_get_functiondef at schema 943:
  // md5(prosrc) 82076ff9fd420cc1a000a8265d50d298, the 0939 body, which carries 0908's share lock on the sale's till
  // session). The diff to it adds only the goods items' lock before their lots are planned and the plan around what
  // the earlier lines take; pgTAP 561, 553, 525 and 520 green on dev with 0947, rolled back.
  'counter_receipt_finalize_v1@0947',
  // #4433/0950 restates void_invoice from 0942; the LIVE dev body (md5(prosrc) ee1554f252cb3d770df13ae186c96155, schema
  // 943) is 0942's byte for byte, and 0950 differs only where an unknown invoice now meets issuing_member like a foreign one.
  'void_invoice@0950',
  // #4165/0901 restates settle_online_payment from the LIVE dev definition
  // (pg_get_functiondef, the 0797 body with 0393's gate and 0757's
  // captured/reversed return) and adds only the explicit branch: the
  // credit's posting day and mode. pgTAP 449, 419 and 527.
  'settle_online_payment@0901',
  // #4165/0901 restates move_payment_credit_v1 from the LIVE dev definition
  // (the 0690 body) and changes only the mode the moved credit and its
  // reversal carry and the invoiced-month guards for explicit credits.
  // pgTAP 364, 366 and 528.
  'move_payment_credit_v1@0901',
  // #4153/0809 carries the live mcp_read_v1 definition, including its
  // place, feature, consent-ceiling and event-type guards. Only booking
  // event visibility is added to validation reads; pgTAP 463 executes them.
  'mcp_read_v1@0809',
  // The live capacity reader keeps its history and analytics gates. Only
  // the live-floor visibility check excludes historical-only ids; pgTAP334.
  'kpi_seat_capacity@0809',
  // #3745/0721 restates start_space_inquiry and send_inquiry_message from
  // the LIVE dev definitions (0316 with 0324's feature_operation_allowed
  // gate) as start_space_inquiry_v1 / send_inquiry_message_v1, and the
  // older two delegate to them. pgTAP 390, 101 and 110.
  'start_space_inquiry@0721',
  'send_inquiry_message@0721',
  // #3671/0717 restates match_invoice from the LIVE dev definition
  // (pg_get_functiondef), so every earlier anchored rule is carried verbatim;
  // the change is the optional part (p_amount_cents) and "what is left of the
  // payment" in place of "the payment has a row". pgTAP 388 and 199.
  'match_invoice@0717',
  // #3671/0718 restates match_invoice from the LIVE dev definition (the
  // 0717 body, pg_get_functiondef) and changes only the locks (invoice,
  // aggregate, payment `for update`) and what is still due on a standing
  // partial (invoice_still_due_cents). pgTAP 389, 388 and 199.
  'match_invoice@0718',
  // #3556/0797 moves match_invoice's body, taken from the LIVE dev
  // definition (pg_get_functiondef, the 0718 body), into match_invoice_part
  // verbatim except the actor parameter and the claim_source in the event;
  // match_invoice keeps the permission check and calls it. open_payment_intent
  // and settle_online_payment are restated from their live definitions too
  // (0393's onlinePayments gate, 0757's captured/reversed return). pgTAP 449,
  // 388, 199 and 160.
  'match_invoice@0797',
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
  // #2631/0442 restates mcp_read_v1 whole from the LIVE dev body
  // (pg_get_functiondef after 0411): every branch verbatim; the changes are
  // the two new availability kinds (room, parking) and the seat branch's
  // kind column read from seats.resource_kind behind resource_kind_enabled.
  // pgTAP 194 drives room availability; 144/170 drive the seat kinds.
  'mcp_read_v1@0442',
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

/// #4397 -- what the guard found when it learned to see a patch written as `pg_get_functiondef('public.<name>(…)'`
/// (before it saw only `proname = '…'`, and found none of these). Each pair is a whole re-creation AFTER an in-place
/// patch, not yet argued against the live body. Recorded so that no NEW pair can join: the set may shrink (argue a pair
/// against `pg_get_functiondef` on the live project, move it to `_reviewed` with what you checked), never grow.
const _foundWhenWidened = {
  'clear_einvoice_credentials@0796',
  'invoice_legal_snapshot@0794',
  'mcp_execute_v1@0411',
  'mcp_execute_v1@0412',
  'mcp_target@0759',
  'member_has_permission@0804',
  'member_profile_projection@0712',
  'member_profile_projection@0788',
  'member_profile_purposes@0713',
  'preview_my_member_profile@0712',
  'save_book_mapping@0517',
  'set_payment_credentials@0796',
  'set_personal_preferences@0578',
  'set_personal_preferences@0715',
  'set_personal_preferences@0737',
  'set_seat_block@0809',
  'upsert_site@0789',
  'void_invoice@0942',
};

/// A function whose generator restates it whole every time it changes (`tool/build_template_field_registry_sql.dart`):
/// its history is restatements by design, and #4396 turns it into rows. Exempt until then.
const _generatedWhole = {'template_field_registry'};

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

/// The functions a migration's text patches in place: it reads the live body (`pg_get_functiondef`, by the name
/// in the call or by `proname = '…'`) and rewrites it at an anchor (#4397 -- every form, not only `proname`).
Set<String> patchedFunctions(String source) => {
  for (final m in RegExp(r"proname\s*=\s*'(\w+)'").allMatches(source)) m.group(1)!,
  for (final m in RegExp(r"pg_get_functiondef\(\s*'(?:public\.)?(\w+)\s*\(").allMatches(source)) m.group(1)!,
};

/// `function@migration` for each wholesale re-creation of a function AFTER the last migration that patched it, that
/// is not in [_reviewed] (nor, unless [withBaseline], in `_foundWhenWidened`). [sources] maps a migration's four-digit number to its text.
List<String> recreatedAfterPatch(Map<String, String> sources, {bool withBaseline = false}) {
  final patchedIn = <String, List<String>>{};
  final recreatedIn = <String, List<String>>{};
  for (final MapEntry(key: number, value: source) in sources.entries) {
    for (final name in patchedFunctions(source)) {
      (patchedIn[name] ??= []).add(number);
    }
    for (final m in RegExp(r'create or replace function public\.(\w+)').allMatches(source)) {
      (recreatedIn[m.group(1)!] ??= []).add(number);
    }
  }
  final offenders = <String>[];
  for (final entry in patchedIn.entries) {
    if (_generatedWhole.contains(entry.key)) continue;
    final lastPatch = entry.value.reduce((a, b) => a.compareTo(b) > 0 ? a : b);
    for (final recreation in recreatedIn[entry.key] ?? const <String>[]) {
      if (recreation.compareTo(lastPatch) <= 0) continue;
      final key = '${entry.key}@$recreation';
      if (!_reviewed.contains(key) && (withBaseline || !_foundWhenWidened.contains(key))) offenders.add(key);
    }
  }
  return offenders..sort();
}

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
    final offenders = recreatedAfterPatch({
      for (final f in sqlFiles('supabase/migrations'))
        f.uri.pathSegments.last.substring(0, 4): f.readAsStringSync(),
    });

    expect(offenders, isEmpty,
        reason: 'These functions are re-created wholesale AFTER a '
            'migration patched them at an anchor, so the patch is gone '
            'unless the new body repeats it:\n  ${offenders.join('\n  ')}\n'
            'Carry the earlier rules forward, verify against the LIVE '
            'function with pg_get_functiondef — not against the migration '
            'text — and then add the pair to _reviewed with what you '
            'checked.');
  });

  test('#4397 the guard sees a patch however it reads the live body, and can fail', () {
    const byDef = '''
do \$p\$ declare v_def text := pg_get_functiondef('public.stock_apply_lines(uuid, uuid, uuid, jsonb, text, timestamptz, jsonb, text)'::regprocedure);
begin execute pg_temp.anchor_replace(v_def, 'a', 'b'); end \$p\$;''';
    const byName = "select pg_get_functiondef(p.oid) from pg_proc p where p.proname = 'stock_apply_lines'";
    const recreate = 'create or replace function public.stock_apply_lines(p_workspace_id uuid) returns void';
    for (final patch in [byDef, byName]) {
      expect(recreatedAfterPatch({'0100': patch, '0200': recreate}), ['stock_apply_lines@0200']);
      expect(recreatedAfterPatch({'0100': recreate, '0200': patch}), isEmpty, reason: 'a patch after the definition is the normal order');
    }
    expect(recreatedAfterPatch({'0100': byDef, '0200': recreate.replaceAll('stock_apply_lines', 'other_fn')}), isEmpty);
    expect(patchedFunctions("pg_get_functiondef('public.f(uuid)'::regprocedure) pg_get_functiondef('g(int)'::regprocedure)"),
        {'f', 'g'});
  });

  test('#4397 the recorded set only shrinks: each pair in it is still found', () {
    final all = recreatedAfterPatch({
      for (final f in sqlFiles('supabase/migrations'))
        f.uri.pathSegments.last.substring(0, 4): f.readAsStringSync(),
    }, withBaseline: true).toSet();
    expect(_foundWhenWidened.difference(all), isEmpty,
        reason: 'these pairs no longer exist: remove them from _foundWhenWidened');
  });

  test('the reviewed set has not gone stale', () {
    // Every entry must still describe a real pair; a removed migration
    // or a renamed function should shrink this list, not be forgotten.
    final numbers = sqlFiles('supabase/migrations')
        .map((f) => f.uri.pathSegments.last.substring(0, 4))
        .toSet();
    for (final key in {..._reviewed, ..._foundWhenWidened}) {
      expect(numbers, contains(key.split('@').last),
          reason: '$key names a migration that no longer exists');
    }
  });
}
