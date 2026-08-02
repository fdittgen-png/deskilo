-- SPDX-License-Identifier: 0BSD
-- E-invoice test environments (#393). Testing a transmission used to mean
-- pointing the ONE configured endpoint at the test platform and
-- remembering to point it back — an error-prone swap on production
-- credentials, with a log that cannot tell a rehearsal from the real
-- submission.
--
-- The config jsonb (0071) already accepts arbitrary keys, so the UAT and
-- dev platforms live as SUFFIXED keys beside the production ones:
-- endpoint_uat, auth_value_uat, endpoint_dev, auth_value_dev (plus
-- optional auth_header_/field_name_ overrides). Production keys are
-- untouched — a workspace configured before this migration behaves
-- identically after it.
--
-- Two additive changes, nothing destructive:

-- 1. The secret gate learns the suffixes, so a UAT endpoint echoes back
-- to the owner UI exactly like the production one instead of being
-- reported as an unreadable secret. Tokens (auth_value*) stay secret.
create or replace function public.einvoice_config_is_secret(p_key text)
returns boolean language sql immutable as $$
  select p_key !~ '^(endpoint|auth_header|field_name|provider)(_uat|_dev)?$';
$$;

-- 2. The transmission log names the environment, so a test send is never
-- mistaken for the real submission when someone asks "did this leave?".
-- 'prod' default keeps every existing row truthful.
alter table public.invoice_transmissions
  add column environment text not null default 'prod'
  check (environment in ('prod', 'uat', 'dev'));
