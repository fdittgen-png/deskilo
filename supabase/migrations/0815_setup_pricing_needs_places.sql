-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: transforming
-- (the setup step catalogue is restated and one line of the status function
-- is patched; no stored step state moves)
--
-- 0815 (#4223) -- "Prices and plans" applies only to a business with places.
-- Its levels, extra half-days and day packs price presence, so a business whose
-- places are off (placeBooking off: a practice, a salon) is not asked for them:
-- the step is not applicable to it (0539's rule), as the `places` step is
-- (0708), and the steps that wait on it (`payment_methods`) are not held back,
-- since a step that does not apply never blocks one.
--
-- A step now names a second feature it needs (`also_needs`): it applies only
-- when both are effective, so a business with places and billing switched off
-- keeps today's answer (moneyTab still gates it). Every existing workspace reads
-- placeBooking ON, so its guide is unchanged.

-- ── the setup step catalogue (dart run tool/build_setup_steps.dart) ──
create or replace function public.setup_step_catalogue()
returns jsonb language sql immutable set search_path = public as $fn$
  select $json$[{"id":"basics","group":"open","milestone":"bookable","route":"/setup/step/basics","evidence":"basics","feature":null,"required":true,"depends_on":[],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"hours","group":"open","milestone":"bookable","route":"/setup/step/hours","evidence":"hours","feature":null,"required":true,"depends_on":["basics"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"places","group":"open","milestone":"bookable","route":"/setup/step/places","evidence":"places","feature":"placeBooking","required":true,"depends_on":["basics"],"actor":"owner","estimate_minutes":10,"secret":false},{"id":"member_rights","group":"open","milestone":"bookable","route":"/setup/step/member_rights","evidence":"member_rights","feature":null,"required":true,"depends_on":[],"actor":"owner","estimate_minutes":1,"secret":false},{"id":"invite","group":"open","milestone":"bookable","route":"/setup/step/invite","evidence":"invite","feature":null,"required":false,"depends_on":["member_rights"],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"pricing","group":"run","milestone":"money","route":"/setup/step/pricing","evidence":"pricing","feature":"moneyTab","also_needs":"placeBooking","required":true,"depends_on":[],"actor":"owner","estimate_minutes":10,"secret":false},{"id":"services","group":"run","milestone":"money","route":"/setup/step/services","evidence":"services","feature":"services","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"payment_methods","group":"run","milestone":"money","route":"/setup/step/payment_methods","evidence":"payment_methods","feature":"moneyTab","required":true,"depends_on":["pricing"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"online_payments","group":"run","milestone":"money","route":"/setup/step/online_payments","evidence":"online_payments","feature":"onlinePayments","required":true,"depends_on":["payment_methods"],"actor":"operator","estimate_minutes":5,"secret":true},{"id":"approvals","group":"run","milestone":"money","route":"/setup/step/approvals","evidence":"approvals","feature":null,"required":true,"depends_on":["invite"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"new_members","group":"run","milestone":"live","route":"/setup/step/new_members","evidence":"manual","feature":null,"required":false,"depends_on":[],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"notifications","group":"run","milestone":"live","route":"/setup/step/notifications","evidence":"manual","feature":null,"required":false,"depends_on":[],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"limits","group":"run","milestone":"live","route":"/setup/step/limits","evidence":"manual","feature":"bookingPolicies","required":false,"depends_on":[],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"kiosk","group":"run","milestone":"live","route":"/setup/step/kiosk","evidence":"kiosk","feature":"kioskMode","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"purchases","group":"run","milestone":"money","route":"/setup/step/purchases","evidence":"purchases","feature":"purchases","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"lease","group":"run","milestone":"money","route":"/setup/step/lease","evidence":"lease","feature":"premisesLease","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"assets","group":"run","milestone":"money","route":"/setup/step/assets","evidence":"assets","feature":"assetRegister","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"look","group":"run","milestone":"live","route":"/setup/step/look","evidence":"look","feature":"workspaceBranding","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"public_page","group":"run","milestone":"live","route":"/setup/step/public_page","evidence":"public_page","feature":"publicListings","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"legal_identity","group":"grow","milestone":"invoice","route":"/setup/step/legal_identity","evidence":"legal_identity","feature":"invoicing","required":true,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"vat","group":"grow","milestone":"invoice","route":"/setup/step/vat","evidence":"vat","feature":"vatManagement","required":true,"depends_on":["legal_identity"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"numbering","group":"grow","milestone":"invoice","route":"/setup/step/numbering","evidence":"numbering","feature":"numberSequences","required":true,"depends_on":["legal_identity"],"actor":"owner","estimate_minutes":3,"secret":false},{"id":"documents","group":"grow","milestone":"invoice","route":"/setup/step/documents","evidence":"documents","feature":"invoicePdfTemplate","required":false,"depends_on":["legal_identity"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"einvoicing","group":"grow","milestone":"invoice","route":"/setup/step/einvoicing","evidence":"einvoicing","feature":"einvoiceCustomerDelivery","required":true,"depends_on":["legal_identity","numbering"],"actor":"owner","estimate_minutes":15,"secret":true},{"id":"accounting","group":"grow","milestone":"invoice","route":"/setup/step/accounting","evidence":"accounting","feature":"accountingBook","required":true,"depends_on":["vat"],"actor":"owner","estimate_minutes":10,"secret":false},{"id":"reminders","group":"grow","milestone":"invoice","route":"/setup/step/reminders","evidence":"reminders","feature":"dunning","required":false,"depends_on":[],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"first_booking","group":"launch","milestone":"live","route":"/reserve","evidence":"first_booking","feature":"placeBooking","required":true,"depends_on":["places","member_rights"],"actor":"owner","estimate_minutes":5,"secret":false},{"id":"recovery","group":"launch","milestone":"live","route":"/workspace-settings","evidence":"recovery","feature":null,"required":false,"depends_on":[],"actor":"owner","estimate_minutes":2,"secret":false},{"id":"assistant","group":"launch","milestone":"live","route":"/settings/assistant-setup","evidence":"assistant","feature":"mcpAccess","required":false,"depends_on":[],"actor":"operator","estimate_minutes":5,"secret":false}]$json$::jsonb;
$fn$;
revoke execute on function public.setup_step_catalogue() from public, anon;
grant execute on function public.setup_step_catalogue() to authenticated;

-- ── workspace_setup_status: a step applies when its feature AND its second
-- feature, if it names one, are effective (one anchored line) ──
create or replace function pg_temp.anchor_replace(p_def text, p_old text, p_new text)
returns text
language plpgsql
as $f$
begin
  if (length(p_def) - length(replace(p_def, p_old, ''))) / length(p_old) <> 1 then
    return null;
  end if;
  return replace(p_def, p_old, p_new);
end
$f$;
revoke execute on function pg_temp.anchor_replace(text, text, text) from public, anon, authenticated;

do $migration$
declare
  v_def text;
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'workspace_setup_status';
  -- Applied once: a second run leaves the function as it is.
  if position($a$v_step->>'also_needs'$a$ in v_def) > 0 then return; end if;
  v_def := pg_temp.anchor_replace(v_def,
    $a$    v_applies := v_step->>'feature' is null
                 or public.feature_effective(p_workspace_id, v_step->>'feature');$a$,
    $a$    v_applies := (v_step->>'feature' is null
                  or public.feature_effective(p_workspace_id, v_step->>'feature'))
                 and (v_step->>'also_needs' is null
                  or public.feature_effective(p_workspace_id, v_step->>'also_needs'));$a$);
  if v_def is null then
    raise exception 'an anchor of #4223 was not found in workspace_setup_status' using errcode = 'P0001';
  end if;
  execute v_def;
end
$migration$;

select public.set_deskilo_schema_version(815);
