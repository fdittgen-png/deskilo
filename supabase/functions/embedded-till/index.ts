// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4454 (E03A, slice 1) -- the till board's enrollment routes (handler.ts). The service role, in this function's
// environment only, reaches the two board functions of migration 0984; nothing else is called with it.

import { env as readEnv, KEYS } from "../_shared/config.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { guard } from "../_shared/serve.ts";
import { budget, handle } from "./handler.ts";

const supabase = createClient(
  readEnv(KEYS.supabaseUrl)!,
  readEnv(KEYS.supabaseServiceRoleKey)!,
);

// a board polls every few seconds while it waits; a source past this is refused for the rest of the minute
const allow = budget(30);

Deno.serve(guard("embedded-till", (req) =>
  handle(req, {
    rpc: (fn, args) => supabase.rpc(fn, args),
    allow,
  })
));
