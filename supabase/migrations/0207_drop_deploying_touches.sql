-- SPDX-License-Identifier: 0BSD
-- 0207 — #1154: `deploying_touches()` has had no reader since 0197.
--
-- 0186 introduced it so the deployment's definer functions could reach
-- each other's side under one transaction-local setting, and let the
-- permission guards accept it as a stand-in. 0197 took it OUT of the
-- guards — "a transaction-local setting is a capability token for
-- plumbing, not an authorisation" — and after that nothing in `public`
-- calls it: verified on the live project by scanning every function's
-- source for its name (only its own definition matched).
--
-- The `deskilo.deploying` setting the deploy functions still SET is
-- harmless without a reader and stays: removing it means patching three
-- function bodies for no behaviour change.
do $harness$
declare v_readers int;
begin
  select count(*) into v_readers
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname <> 'deploying_touches'
     and p.prosrc like '%deploying_touches%';
  if v_readers > 0 then
    raise exception '0207: deploying_touches still has % reader(s) — not dropping', v_readers;
  end if;
end
$harness$;

drop function if exists public.deploying_touches(uuid);
