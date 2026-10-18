// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1228, #2588 C1 — a SECURITY DEFINER function a signed-in person can call
// checks who is calling.
//
// Definer means the function runs with the owner's rights and RLS does not
// apply, so the guard is written by hand — and was forgotten three times in
// fifty-seven. The scanner (definer_scan.dart) reads migration text: a
// HEURISTIC, described there, that the real-role database and HTTP checks of
// CI complement and do not replace. Its first version delimited a body with
// `$$;`, so a `$fn$` function borrowed the guard of the next function; the
// fixtures below keep each way it was wrong from coming back.
//
// The functions it still finds are listed in definer_unreviewed.txt, each as
// `name/parameters | status`. Nobody has READ them yet: the list is the work
// to do, not a verdict, and it only shrinks. A new definer function without a
// guard fails here; so does an entry whose function is guarded or gone.
import 'package:flutter_test/flutter_test.dart';

import 'definer_scan.dart';
import 'lint_sources.dart';

List<MigrationText> _sql(List<String> files) => [
  for (var i = 0; i < files.length; i++) (path: '$i.sql', sql: files[i]),
];

const _wrapped = r'''
create or replace function public.reads(p_workspace_id uuid)
returns jsonb language sql security definer as $fn$
  select to_jsonb(1);
$fn$;
create or replace function public.guarded(p_workspace_id uuid)
returns jsonb language plpgsql security definer as $fn$
begin
  if auth.uid() is null then raise exception 'no'; end if;
  return to_jsonb(1);
end;
$fn$;
''';

void main() {
  group('the scanner', () {
    test('a body ends at its own dollar-quote, not at the next function', () {
      expect(unguardedExposedDefiners(_sql([_wrapped])), ['reads/1']);
    });

    test('a guard named in a comment or a message is not a guard', () {
      const sql = r'''
create or replace function public.f(p_member_id uuid)
returns int language plpgsql security definer as $$
begin
  -- must call has_permission(...) one day
  raise notice 'is_member_of is not checked';
  return 1;
end;
$$;
''';
      expect(unguardedExposedDefiners(_sql([sql])), ['f/1']);
    });

    test('an overload is its own function', () {
      const sql = r'''
create or replace function public.g(p_workspace_id uuid)
returns int language plpgsql security definer as $$
begin perform auth.uid(); return 1; end;
$$;
create or replace function public.g(p_workspace_id uuid, p_other uuid)
returns int language plpgsql security definer as $$
begin return 1; end;
$$;
''';
      expect(unguardedExposedDefiners(_sql([sql])), ['g/2']);
    });

    test('exposure follows grants and revokes in order', () {
      const make = r'''
create or replace function public.h()
returns int language sql security definer as $$ select 1 $$;
''';
      // A new function is executable by authenticated until it is revoked.
      expect(unguardedExposedDefiners(_sql([make])), ['h/0']);
      expect(
        unguardedExposedDefiners(
          _sql([
            make,
            'revoke execute on function public.h() from public, anon, authenticated;',
          ]),
        ),
        isEmpty,
      );
      // Revoking from public and anon alone leaves authenticated's own grant.
      expect(
        unguardedExposedDefiners(
          _sql([
            make,
            'revoke execute on function public.h() from public, anon;',
          ]),
        ),
        ['h/0'],
      );
      expect(
        unguardedExposedDefiners(
          _sql([
            make,
            'revoke execute on function public.h() from authenticated;',
            'grant execute on function public.h() to authenticated;',
          ]),
        ),
        ['h/0'],
      );
    });

    test('a trigger function and an invoker function are out of scope', () {
      const sql = r'''
create or replace function public.t()
returns trigger language plpgsql security definer as $$ begin return new; end; $$;
create or replace function public.i(p_member_id uuid)
returns int language sql as $$ select 1 $$;
''';
      expect(unguardedExposedDefiners(_sql([sql])), isEmpty);
    });

    test(
      'one level of delegation to a guarded function counts, two do not',
      () {
        const sql = r'''
create or replace function public.gate(p_workspace_id uuid)
returns void language plpgsql security definer as $$
begin perform auth.uid(); end;
$$;
create or replace function public.one(p_workspace_id uuid)
returns int language sql security definer as $$ select public.gate(p_workspace_id) is null $$;
create or replace function public.two(p_workspace_id uuid)
returns int language sql security definer as $$ select public.one(p_workspace_id) $$;
''';
        // `two` hands over to `one`, which only hands over to `gate`.
        expect(unguardedExposedDefiners(_sql([sql])), ['two/1']);
      },
    );
  });

  test('every exposed definer function checks its caller, or is listed', () {
    final found = unguardedExposedDefiners(
      repositoryMigrations(sqlFiles('supabase/migrations')),
    );
    final listed = <String>{
      for (final line in File2.lines('test/lint/definer_unreviewed.txt'))
        if (line.trim().isNotEmpty && !line.trim().startsWith('#'))
          line.split('|').first.trim(),
    };
    expect(
      found.toSet().difference(listed),
      isEmpty,
      reason:
          'these run with the owner\'s rights, are callable by a signed-in '
          'person and never check who is asking, directly or through one '
          'guarded helper. Add the guard (auth.uid(), has_permission, '
          'is_member_of, ...); do not add to definer_unreviewed.txt.',
    );
    expect(
      listed.difference(found.toSet()),
      isEmpty,
      reason:
          'these are guarded, revoked or gone: delete them from '
          'definer_unreviewed.txt (the list only shrinks)',
    );
  });
}
