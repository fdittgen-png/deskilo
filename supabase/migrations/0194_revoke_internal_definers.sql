-- SPDX-License-Identifier: 0BSD
-- 0194 — #1079: three definer helpers stop answering strangers.
--
-- `export_floor_plan`, `report_image_names` and `document_site_for_member`
-- (and `default_site`, which the last one calls) are SECURITY DEFINER,
-- LANGUAGE sql, and carry NO membership check of any kind. 0191 closed
-- `anon`; `authenticated` was left, and a workspace UUID is not a secret
-- — it travels in links, in exported questionnaires, in invitation flows.
--
-- Verified against the live project before writing this: a freshly
-- created user, confirmed by `is_member_of` to be a member of nothing,
-- read 2 levels of a real workspace's floor plan and 1 report image
-- name. `report_image_names` reads `storage.objects` directly, so it
-- answers PAST storage RLS; `document_site_for_member` returns a whole
-- `sites` row — legal_id, vat_id, street, city.
--
-- The fix is the grant, not a guard in the body. Nothing in lib/, web/
-- or tool/ calls any of them: they exist only to be called by other
-- SECURITY DEFINER functions (`export_workspace_configuration`,
-- `preview_deployment`, the document builders), and those run as the
-- function owner, so an internal call is unaffected by a revoke. Adding
-- `is_member_of` checks instead would have meant converting four sql
-- functions to plpgsql and reasoning about the deployment path, which
-- reads BOTH sides of a pair — more moving parts for the same result.
--
-- Least privilege is the whole change: a function that no client calls
-- should not be callable by every signed-in user on the internet.
revoke execute on function public.export_floor_plan(uuid) from authenticated;
revoke execute on function public.report_image_names(uuid) from authenticated;
revoke execute on function public.document_site_for_member(uuid) from authenticated;
revoke execute on function public.default_site(uuid) from authenticated;

-- 0188 revoked only merge_floor_plan's sibling; make the pair explicit.
revoke execute on function public.export_floor_plan(uuid) from public, anon;
revoke execute on function public.report_image_names(uuid) from public, anon;
revoke execute on function public.document_site_for_member(uuid) from public, anon;
revoke execute on function public.default_site(uuid) from public, anon;
