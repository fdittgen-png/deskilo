-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
--
-- #3932 -- the Spanish channel's connector (es_verifactu) can be configured:
-- the provider check of the e-invoice credentials and the provider list of
-- set_einvoice_credentials name it. Its certificate and private key are
-- stored like every key the registry does not call public: in the Vault, the
-- row holding a marker (einvoice_config_is_secret, 0414: an unknown key is a
-- secret). Nothing else changes: no existing connector, row or grant.

alter table public.einvoice_credentials
  drop constraint if exists einvoice_credentials_provider_check;
alter table public.einvoice_credentials
  add constraint einvoice_credentials_provider_check
  check (provider in ('generic', 'peppol', 'fr_pa', 'it_sdi', 'pl_ksef', 'ro_efactura', 'es_verifactu'));

do $patch$
declare
  v_def text;
  v_new text;
  v_old constant text := $a$'pl_ksef', 'ro_efactura') then$a$;
begin
  select pg_get_functiondef('public.set_einvoice_credentials(uuid,jsonb)'::regprocedure) into v_def;
  if v_def is null or length(v_def) - length(replace(v_def, v_old, '')) <> length(v_old) then
    raise exception '0818: the provider list of set_einvoice_credentials is not found exactly once'
      using errcode = 'P0001';
  end if;
  v_new := replace(v_def, v_old, $b$'pl_ksef', 'ro_efactura', 'es_verifactu') then$b$);
  execute v_new;
end
$patch$;

select public.set_deskilo_schema_version(818);
