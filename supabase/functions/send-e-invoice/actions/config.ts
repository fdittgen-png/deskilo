// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice -- the `config` action (#4400). The client asks first whether sending is even possible.

import type { Action } from "../common.ts";
import { json, ENVIRONMENTS, DESTINATIONS, configForDestination, missingFor } from "../common.ts";
import { isProvider } from "../connectors.ts";

// deno-lint-ignore require-await
export const config: Action = async (ctx) => {
  const { credentials, fullCfg } = ctx;
  const govCfg = configForDestination(fullCfg, "government");
  const govProvider = credentials?.provider ?? "generic";
  // a provider whose connector was retired cannot send: say so (#3338)
  const installed = isProvider(govProvider);
  return json({
    configured: installed &&
      missingFor(govCfg, "prod", govProvider).length === 0,
    ...(installed ? {} : { error: "provider_not_installed" }),
    provider: govProvider,
    missing: missingFor(govCfg, "prod", govProvider),
    environments: Object.fromEntries(
      ENVIRONMENTS.map((
        env,
      ) => [env, missingFor(govCfg, env, govProvider).length === 0]),
    ),
    destinations: Object.fromEntries(
      DESTINATIONS.map((dest) => {
        const scoped = configForDestination(fullCfg, dest);
        return [dest, {
          configured: missingFor(scoped, "prod").length === 0,
          missing: missingFor(scoped, "prod"),
          environments: Object.fromEntries(
            ENVIRONMENTS.map(
              (env) => [env, missingFor(scoped, env).length === 0],
            ),
          ),
        }];
      }),
    ),
    // a client that sees this understands the unresolved phases (#3335)
    phases: true,
  });
};
