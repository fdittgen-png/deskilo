// SPDX-License-Identifier: MIT
//
// Content pins for migration 0028 (#223): the two profile columns, the
// wire-shape check the client normalization targets, and the self-scoped
// SECURITY DEFINER heartbeat RPC with 0004-style grant discipline.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/migrations/0028_profile_whatsapp_presence.sql')
      .readAsStringSync();

  test('adds the whatsapp and last_seen_at columns to profiles', () {
    expect(sql, contains('alter table public.profiles'));
    expect(sql, contains("add column whatsapp text not null default ''"));
    expect(sql, contains('add column last_seen_at timestamptz'));
  });

  test('whatsapp check pins the normalized wire shape (+ then digits)',
      () {
    expect(
      sql,
      contains(r"check (whatsapp = '' or whatsapp ~ '^\+[0-9]{6,19}$')"),
    );
  });

  test('touch_last_seen is security definer and strictly self-scoped',
      () {
    expect(
      sql,
      contains('create or replace function public.touch_last_seen()'),
    );
    expect(sql, contains('security definer'));
    expect(
      sql,
      contains(
        'update public.profiles set last_seen_at = now() '
        'where id = auth.uid();',
      ),
    );
  });

  test('touch_last_seen is granted to authenticated only (0004 style)',
      () {
    expect(
      sql,
      contains('revoke execute on function public.touch_last_seen() '
          'from public, anon;'),
    );
    expect(
      sql,
      contains('grant execute on function public.touch_last_seen() '
          'to authenticated;'),
    );
  });

  test('adds no new profiles policies — 0002 profiles_select already '
      'covers shares_workspace_with readers', () {
    expect(sql, isNot(contains('create policy')));
  });
}
