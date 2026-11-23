// SPDX-License-Identifier: AGPL-3.0-or-later
// #4423 -- the invariant: an edge function reads its environment through one module, and the direct reads
// outside it only fall.
import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { env, KEYS, requiredEnv } from "./config.ts";
import { sourceFiles } from "./catch_check.ts";

/** RATCHET (#4423): the `Deno.env.get(` calls in the functions outside `_shared/`. Only falls, as functions adopt config.ts. */
const ENV_READS_OUTSIDE_SHARED = 60;

Deno.test("#4423 env reads a key; requiredEnv names a missing key and never prints a value", () => {
  Deno.env.set("DESKILO_TEST_KEY", "v");
  assertEquals(env("DESKILO_TEST_KEY"), "v");
  assertEquals(requiredEnv("DESKILO_TEST_KEY"), "v");
  Deno.env.delete("DESKILO_TEST_KEY");
  assertEquals(env("DESKILO_TEST_KEY"), undefined);
  assertThrows(() => requiredEnv("DESKILO_TEST_KEY"), Error, "missing environment key DESKILO_TEST_KEY");
  assertEquals(KEYS.supabaseUrl, "SUPABASE_URL");
});

Deno.test("#4423 the environment reads outside _shared only fall", () => {
  const root = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
  let reads = 0;
  for (const file of sourceFiles(root)) {
    if (file.slice(root.length + 1).startsWith("_shared/")) continue;
    reads += (Deno.readTextFileSync(file).match(/Deno\.env\.get\(/g) ?? []).length;
  }
  assertEquals(reads, ENV_READS_OUTSIDE_SHARED, reads < ENV_READS_OUTSIDE_SHARED ? "it fell: lower ENV_READS_OUTSIDE_SHARED" : "a function reads the environment directly: use config.ts");
});
