-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- 0222 (#1360) — a space's WhatsApp group is not wording.
--
-- `deployable_entities()` listed `whatsapp_group` in the **invitations**
-- entity, beside `invitation_template` and `invitation_templates`. Those
-- two are wording a template may legitimately carry. `whatsapp_group` is
-- a link to ONE space's group chat.
--
-- So deploying `invitations` from space A into space B pointed B's
-- members at A's WhatsApp group — an outside chat full of people who are
-- not their members. Between a space's own twins that is merely wrong;
-- between two spaces it is a privacy problem. Found by the #1290 sweep,
-- which classified the key A and the entity B and made the mismatch
-- visible.
--
-- ## Moved, not dropped
--
-- The issue proposed dropping it, "unless someone names a case for
-- carrying it". There is one, and the registry already has a home for
-- it: `identity` is the entity that carries the class-A keys — address,
-- street, city, vat_regime, vat_id, legal_id, tax_exemption_reason,
-- vat_account, invoice_legal — and the matrix describes it as travelling
-- "between a space's OWN twins, not between spaces".
--
-- `whatsapp_group` is class A. Dropping it would make it the only
-- class-A key that cannot follow a space to its own production twin,
-- which is a second defect rather than a fix. Moving it costs no new
-- machinery: `identity` exists and already holds ten such keys.
--
-- Three facts make the move safe rather than a smaller version of the
-- same bug, all read from the code rather than assumed:
--
--   * a deployment selects nothing by default — `_selected` starts empty
--     and every entity is an explicit checkbox, with the confirm sheet
--     naming exactly what was ticked;
--   * `identity` declares `requires: []`, so ticking it pulls in nothing;
--   * no other entity requires `identity`, so nothing can pull IT in
--     transitively. It only ever travels when somebody chooses it.
--
-- The hazard was that `invitations` is class-B wording — precisely what
-- somebody ticks when copying a template — and it silently carried a
-- link. After this, carrying the link is a deliberate act.
--
-- ## Anchored patch, both substitutions asserted
--
-- Verified before applying, as a rolled-back harness on the development
-- project:
--
--   entities_before=19 entities_after=19 complete=19
--   holder_before=invitations holder_after=identity holders=1
--   invitations_has_whatsapp=f identity_has_whatsapp=t
--
-- `complete=19` is every entity still carrying all seven keys (key,
-- kind, requires, workspace_keys, tables, merge_policy, group), and
-- `holders=1` is the assertion that the key MOVED — not copied into a
-- second entity, not dropped from both.
--
-- Both anchors were also confirmed to exist verbatim in 0186 and 0219,
-- so the replay from empty cuts at the same text the hosted project
-- holds. An anchor verified only against the live body is half a check:
-- `quality · database` replays every migration onto an empty Postgres,
-- where the function is whatever the FILES build.
do $patch$
declare
  v_def text;
  v_anchor_inv text; v_new_inv text;
  v_anchor_id  text; v_new_id  text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'deployable_entities' limit 1;
  if v_def is null then raise exception '0222: deployable_entities not found'; end if;

  v_anchor_inv := $a$'workspace_keys', '["invitation_template","invitation_templates","whatsapp_group"]'::jsonb$a$;
  v_new_inv    := $a$'workspace_keys', '["invitation_template","invitation_templates"]'::jsonb$a$;
  v_anchor_id  := $a$'["address","street","postal_code","city","default_locale","vat_regime","vat_id","legal_id","tax_exemption_reason","vat_account","invoice_legal"]'::jsonb$a$;
  v_new_id     := $a$'["address","street","postal_code","city","default_locale","vat_regime","vat_id","legal_id","tax_exemption_reason","vat_account","invoice_legal","whatsapp_group"]'::jsonb$a$;

  -- Both asserted: a silent no-op here would leave the key exactly where
  -- the bug is, and the migration would report success (#960/0175).
  if position(v_anchor_inv in v_def) = 0 then
    raise exception '0222: the invitations workspace_keys anchor did not match';
  end if;
  if position(v_anchor_id in v_def) = 0 then
    raise exception '0222: the identity workspace_keys anchor did not match';
  end if;

  v_def := replace(v_def, v_anchor_inv, v_new_inv);
  v_def := replace(v_def, v_anchor_id,  v_new_id);
  execute v_def;

  -- And asserted AFTER, because the anchors matching is not the same
  -- claim as the registry being right.
  if exists (select 1 from jsonb_array_elements(public.deployable_entities()) e
              where e->>'key' = 'invitations'
                and e->'workspace_keys' @> '["whatsapp_group"]'::jsonb) then
    raise exception '0222: whatsapp_group is still in the invitations entity';
  end if;
  if not exists (select 1 from jsonb_array_elements(public.deployable_entities()) e
                  where e->>'key' = 'identity'
                    and e->'workspace_keys' @> '["whatsapp_group"]'::jsonb) then
    raise exception '0222: whatsapp_group did not arrive in the identity entity';
  end if;
  if (select count(*) from jsonb_array_elements(public.deployable_entities()) e
       where e->'workspace_keys' @> '["whatsapp_group"]'::jsonb) <> 1 then
    raise exception '0222: whatsapp_group must belong to exactly one entity';
  end if;
end
$patch$;
