-- SPDX-License-Identifier: 0BSD
-- 0179 — #979/#980: two functions any signed-in user could call.
--
-- release_invoice_payment (0144) is the helper respond_to_event uses to
-- undo a rejected settlement; it never checked who called it, and the
-- authenticated role could execute it — so any member holding an event
-- id could delete another workspace's payment matches. It is internal:
-- executable by nobody but the security-definer functions that own it.
--
-- preview_invoice (0062) checked that the subject belonged to the
-- workspace and nothing about the caller, so a member could read any
-- other member's charges. A member previews their own; anyone else
-- needs the finance permissions the invoice hub itself demands.
-- Harnessed live: a plain member sees their own preview and is refused
-- another's; the owner sees anyone's; authenticated cannot execute the
-- release helper.
revoke execute on function public.release_invoice_payment(uuid) from public, anon, authenticated;
do $patch$
declare v_def text; v_old text;
begin
  select pg_get_functiondef(p.oid) into v_def from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='preview_invoice';
  v_old := E'    raise exception ''unknown subject member'';\n  end if;\n';
  if position(v_old in v_def) = 0 then raise exception '0179: anchor missing'; end if;
  v_def := replace(v_def, v_old, v_old
    || E'  -- #980 — a member previews their OWN charges; anyone else needs the\n'
    || E'  -- finance permissions the invoice hub itself demands.\n'
    || E'  if not (exists (select 1 from public.members m where m.id = p_member_id and m.user_id = auth.uid())\n'
    || E'          or public.has_permission(p_workspace_id, ''viewFinances'')\n'
    || E'          or public.has_permission(p_workspace_id, ''issueInvoices'')) then\n'
    || E'    raise exception ''not allowed to preview this member''''s charges'';\n'
    || E'  end if;\n');
  execute v_def;
end $patch$;
