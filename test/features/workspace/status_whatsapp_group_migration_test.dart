// SPDX-License-Identifier: MIT
//
// Content pins for migration 0029 (#231): the status_text column with
// the SAME 40-char cap the client enforces (StatusTextRules cross-pin),
// the whatsapp_group column with the SAME chat.whatsapp.com prefix the
// settings-form validator checks (WhatsappGroupRules cross-pin), and the
// deliberate absence of new policies — both columns ride 0002's existing
// RLS (profiles_select/profiles_update, workspaces_select/
// workspaces_update).
import 'dart:io';

import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/0029_status_text_whatsapp_group.sql')
      .readAsStringSync();

  test('adds status_text to profiles, capped at StatusTextRules.maxLength',
      () {
    expect(sql, contains('alter table public.profiles'));
    expect(
      sql,
      contains("add column status_text text not null default ''"),
    );
    // The client cap and the column check share the one constant.
    expect(
      sql,
      contains(
        'check (char_length(status_text) <= ${StatusTextRules.maxLength})',
      ),
    );
  });

  test('adds whatsapp_group to workspaces, anchored on '
      'WhatsappGroupRules.linkPrefix', () {
    expect(sql, contains('alter table public.workspaces'));
    expect(
      sql,
      contains("add column whatsapp_group text not null default ''"),
    );
    // The form validator and the column check share the one prefix —
    // the SQL regex is the prefix with dots escaped, anchored at ^.
    final escapedPrefix =
        WhatsappGroupRules.linkPrefix.replaceAll('.', r'\.');
    expect(
      sql,
      contains(
        "check (whatsapp_group = '' or whatsapp_group ~ '^$escapedPrefix')",
      ),
    );
  });

  test('adds no new policies — 0002 already covers both audiences '
      '(profiles_select/update, workspaces_select/update)', () {
    expect(sql, isNot(contains('create policy')));
  });
}
