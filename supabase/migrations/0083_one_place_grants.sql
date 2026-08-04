-- SPDX-License-Identifier: 0BSD
-- Grant hygiene (#412 follow-up): enforce_one_place (0079) missed the
-- revoke every other trigger function carries — a trigger function is
-- not PostgREST-callable, but the advisor baseline stays exact.
revoke execute on function public.enforce_one_place()
  from public, anon, authenticated;
