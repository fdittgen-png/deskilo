-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- #1847 checkpoint B: the public network descriptor and server-side
-- revalidation of the negotiated operation version.
--
-- public_network_descriptor() is generated from
-- contracts/public_network/operations.json (renderPublicNetworkDescriptorSql;
-- test/tool/public_network_contract_test.dart pins it). It is anonymous and
-- names only the protocol, its capabilities and the versions of each external
-- operation: no configuration, build, schema level, flag or person.
--
-- public_network_require(op) reads the `x-deskilo-operation: <op>@<version>`
-- request header. A request without it is a client from before negotiation
-- and means the operation's `unlabelled` version. A version the descriptor
-- does not list, a malformed claim or a claim for another operation is
-- refused with one named message. The claim selects semantics only: every
-- authorization check after it is unchanged.
create or replace function public.public_network_descriptor()
returns jsonb
language sql
immutable
set search_path = public
as $descriptor$
  select $json${"protocol":"deskilo.public-network","protocol_versions":[1],"capabilities":["operation_header"],"operations":[{"id":"network.descriptor.read","versions":[1],"requires":[]},{"id":"directory.sources.list","versions":[1],"requires":[]},{"id":"directory.workspaces.search","versions":[1],"requires":[]},{"id":"directory.workspaces.detail","versions":[1],"requires":[]},{"id":"directory.sources.register","versions":[1],"requires":[],"unlabelled":1},{"id":"workspace.profile.request","versions":[1],"requires":[],"unlabelled":1}]}$json$::jsonb
$descriptor$;
revoke execute on function public.public_network_descriptor() from public;
grant execute on function public.public_network_descriptor() to anon, authenticated;

create function public.public_network_require(p_operation text)
returns void
language plpgsql
stable
set search_path = public
as $require$
declare
  v_claim text;
  v_op text;
  v_version int;
  v_entry jsonb;
begin
  v_claim := nullif(current_setting('request.headers', true), '')::jsonb ->> 'x-deskilo-operation';
  select e into v_entry
    from jsonb_array_elements(public.public_network_descriptor() -> 'operations') e
   where e ->> 'id' = p_operation;
  if v_entry is null then
    raise exception 'unsupported public network version';
  end if;
  if v_claim is null then
    v_op := p_operation;
    v_version := (v_entry ->> 'unlabelled')::int;
  elsif v_claim ~ '^[a-z]+(\.[a-z_]+)+@[0-9]{1,4}$' then
    v_op := split_part(v_claim, '@', 1);
    v_version := split_part(v_claim, '@', 2)::int;
  else
    raise exception 'unsupported public network version';
  end if;
  if v_op <> p_operation or v_version is null
     or not (v_entry -> 'versions') @> to_jsonb(v_version) then
    raise exception 'unsupported public network version';
  end if;
end;
$require$;
revoke execute on function public.public_network_require(text) from public, anon, authenticated;

-- The two participant mutations, as 0305 wrote them, revalidating first.
create or replace function public.register_public_directory(p_origin text,p_key text) returns void
language plpgsql security definer set search_path=public as $$
declare v_payload jsonb;
begin
 perform public.mcp_require_native();
 perform public.public_network_require('directory.sources.register');
 if auth.uid() is null then raise exception 'not authenticated'; end if;
 if p_key like 'sb_publishable_%' then null;
 elsif p_key ~ '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$' then
  begin
   v_payload:=convert_from(decode(translate(split_part(p_key,'.',2),'-_','+/') || repeat('=',(4-length(split_part(p_key,'.',2))%4)%4),'base64'),'UTF8')::jsonb;
  exception when others then raise exception 'publishable key required'; end;
  if v_payload->>'role' is distinct from 'anon' or v_payload ? 'sub' then raise exception 'publishable key required'; end if;
 else raise exception 'publishable key required'; end if;
 if (select count(*) from public.public_directory_sources where registered_by=auth.uid())>=20
  and not exists(select 1 from public.public_directory_sources where origin=p_origin and registered_by=auth.uid())
  then raise exception 'directory limit reached'; end if;
 insert into public.public_directory_sources(origin,publishable_key,registered_by) values(p_origin,p_key,auth.uid())
 on conflict(origin) do update set publishable_key=excluded.publishable_key
 where public.public_directory_sources.registered_by=auth.uid();
end;
$$;
create or replace function public.request_public_workspace_profile(p_workspace uuid) returns void
language plpgsql security definer set search_path=public as $$
declare v_code text;
begin
 perform public.mcp_require_native(); if auth.uid() is null then raise exception 'not authenticated'; end if;
 perform public.public_network_require('workspace.profile.request');
 if not exists(select 1 from public.public_workspace_cards where workspace_id=p_workspace) then raise exception 'workspace not published'; end if;
 select invite_code into strict v_code from public.workspaces where id=p_workspace;
 perform public.join_workspace(v_code);
end;
$$;
revoke execute on function public.register_public_directory(text,text) from public, anon;
grant execute on function public.register_public_directory(text,text) to authenticated;
revoke execute on function public.request_public_workspace_profile(uuid) from public, anon;
grant execute on function public.request_public_workspace_profile(uuid) to authenticated;

select public.set_deskilo_schema_version(347);
