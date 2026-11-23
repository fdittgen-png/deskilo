-- SPDX-License-Identifier: AGPL-3.0-or-later
-- risk: additive
-- apps: additive
--
-- #3726 (K1) -- an installation states the oldest app it accepts, in the app's COMPATIBILITY NUMBER
-- (ADR 0053, section 1), never in a schema number.
--
--   * `deskilo_app_floor()` answers that number, or null for "no floor": every app is accepted. Null is the
--     answer here, and stays so until a later migration raises it. The raise is a separate, later file with one
--     line of reason, applied only after apps that read the floor have been available for the support window
--     (#3732). It is never in the file that first needs it, and never because a milestone exists.
--   * It is read beside `deskilo_schema_version()` (0226), before sign-in too, so anon may call it.
--   * This is a courtesy for apps that know it, not a control: an app released before it never asks, and a
--     number an app states about itself is not a credential. An old contract is ended by the server, by the
--     function or shape that stops answering (#3731). Every money and authorization rule stays on the server
--     whatever the app.
--   * Raising it later: `create or replace` this function with the new number, in its own migration, with its
--     reason in the header.

create or replace function public.deskilo_app_floor()
returns int
language sql
immutable
security invoker
set search_path = public
as $$
  select null::int;
$$;

comment on function public.deskilo_app_floor() is
  'The oldest app compatibility number this installation accepts; null = every app (#3726, ADR 0053).';

revoke execute on function public.deskilo_app_floor() from public, anon, authenticated;
grant execute on function public.deskilo_app_floor() to anon, authenticated;

notify pgrst, 'reload schema';
select public.set_deskilo_schema_version(900);
