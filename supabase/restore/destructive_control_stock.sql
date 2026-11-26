-- SPDX-License-Identifier: AGPL-3.0-or-later
--
-- #4492 row 6 -- the destructive control of the populated upgrade's stock
-- case (STOCK_AT).
--
-- NOT a migration. `scripts/populated_upgrade_check.sh` applies this through
-- the same path as the real migrations, after the honest upgrade has been
-- compared, to prove the comparison can fail: it is the unit migration that
-- goes wrong -- one that "converts" the receipt entered by the carton a second
-- time, as if the stored quantity were still in cartons. The
-- check passes only when the snapshot diff names exactly that movement and
-- the balances no longer equal the sum of their movements.
alter table public.stock_movements disable trigger user;

update public.stock_movements m
   set quantity = m.quantity * 12
 where m.workspace_id = '00000000-0000-4000-8000-0000000a0002'
   and m.request_id = '00000000-0000-4000-8000-0000000a0601';

alter table public.stock_movements enable trigger user;
