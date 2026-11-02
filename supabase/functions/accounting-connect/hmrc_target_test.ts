// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — HMRC is one more OAuth target of the accounting connection
// machinery; its hosts come from the installation's chosen environment.
import { assertEquals } from "jsr:@std/assert@1";
import { clientOf, targetOf } from "./connection.ts";
import type { Deps } from "./connection.ts";

const deps = (env: Record<string, string>) =>
  ({ env: (n: string) => env[n] }) as Pick<Deps, "env">;

Deno.test("HMRC signs in on its own host and exchanges on the API host, per the chosen environment", () => {
  const t = targetOf(deps({ HMRC_ENVIRONMENT: "sandbox" }), "hmrc_mtd")!;
  assertEquals(
    t.authorizeUrl,
    "https://test-www.tax.service.gov.uk/oauth/authorize",
  );
  assertEquals(t.tokenUrl, "https://test-api.service.hmrc.gov.uk/oauth/token");
  assertEquals(t.clientAuth, "body");
  assertEquals(
    targetOf(deps({ HMRC_ENVIRONMENT: "production" }), "hmrc_mtd")!.tokenUrl,
    "https://api.service.hmrc.gov.uk/oauth/token",
  );
});

Deno.test("no environment, or a made-up one, is no target; other targets are untouched", () => {
  assertEquals(targetOf(deps({}), "hmrc_mtd"), undefined);
  assertEquals(
    targetOf(deps({ HMRC_ENVIRONMENT: "https://evil.example" }), "hmrc_mtd"),
    undefined,
  );
  assertEquals(
    targetOf(deps({}), "xero_gb")?.tokenUrl,
    "https://identity.xero.com/connect/token",
  );
  assertEquals(targetOf(deps({}), "nope"), undefined);
});

Deno.test("the application is the installation's own: id and secret from the function's environment", () => {
  const d = deps({
    ACCOUNTING_HMRC_MTD_CLIENT_ID: "cid",
    ACCOUNTING_HMRC_MTD_CLIENT_SECRET: "sec",
  });
  assertEquals(clientOf(d as Deps, "hmrc_mtd"), {
    clientId: "cid",
    clientSecret: "sec",
  });
  assertEquals(clientOf(deps({}) as Deps, "hmrc_mtd"), null);
});
