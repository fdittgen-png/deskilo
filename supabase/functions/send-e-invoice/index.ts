// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice — posts an issued invoice to the workspace's e-invoicing
// platform, so "Envoyer" sends instead of handing the user a file.
//
// The CLIENT builds the document (Factur-X PDF or EN 16931 XML) with the
// same builders that produce the download and posts the bytes here; this
// function holds the credential and does the transmission. The decisions
// live in handler.ts (prepare before send, atomic dispatch claim, uncertain
// is never resent — #3335); the providers in connectors.ts (#2358); every
// read and write in store.ts.

import { createClient } from "npm:@supabase/supabase-js@2";
import { handle } from "./handler.ts";
import { supabaseStore } from "./store.ts";

Deno.serve((req) =>
  handle(req, {
    store: supabaseStore(
      createClient(
        Deno.env.get("SUPABASE_URL")!,
        Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      ),
    ),
  })
);
