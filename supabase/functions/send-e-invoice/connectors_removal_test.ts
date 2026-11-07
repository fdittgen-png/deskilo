// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 — the removal check for a provider connector. A provider is removable
// when nothing but the registry line (connectors.ts) imports its file; a file
// several connectors share is not, and the check says so by naming who still
// needs it. The same question the Dart check asks of a package, asked here of
// the Edge function's own files.

import { assert, assertEquals } from "jsr:@std/assert@1";

const DIR = new URL("./", import.meta.url);

/** The non-test files that import [file] (`it_sdi.ts`, `common.ts`), named by
 * their path under the function. */
async function importersOf(file: string): Promise<string[]> {
  const found: string[] = [];
  const walk = async (dir: URL, prefix: string) => {
    for await (const entry of Deno.readDir(dir)) {
      if (entry.isDirectory) {
        await walk(new URL(`${entry.name}/`, dir), `${prefix}${entry.name}/`);
      } else if (
        entry.name.endsWith(".ts") && !entry.name.endsWith("_test.ts")
      ) {
        const text = await Deno.readTextFile(new URL(entry.name, dir));
        const re = new RegExp(`from "[./a-z_]*/${file.replace(".", "\\.")}"`);
        if (re.test(text)) found.push(`${prefix}${entry.name}`);
      }
    }
  };
  await walk(DIR, "");
  return found.sort();
}

Deno.test("the Italian connector is imported by the registry alone", async () => {
  assertEquals(await importersOf("it_sdi.ts"), ["connectors.ts"]);
});

Deno.test("every connector file is imported by the registry alone", async () => {
  for (
    const file of [
      "generic.ts",
      "peppol.ts",
      "fr_pa.ts",
      "it_sdi.ts",
      "pl_ksef.ts",
      "ro_efactura.ts",
    ]
  ) {
    assertEquals(await importersOf(file), ["connectors.ts"], file);
  }
});

Deno.test("a helper other connectors use cannot be removed with one of them", async () => {
  const common = await importersOf("common.ts");
  for (
    const name of [
      "connectors/fr_pa.ts",
      "connectors/it_sdi.ts",
      "connectors/peppol.ts",
      "connectors/pl_ksef.ts",
      "connectors/ro_efactura.ts",
    ]
  ) {
    assert(common.includes(name), `${name} imports common.ts`);
  }
  assert(common.length > 1, "common.ts is shared: removal is blocked");
  const safeFetch = await importersOf("safe_fetch.ts");
  assert(safeFetch.length >= 1, "safe_fetch.ts has users: removal is blocked");
});

Deno.test("no switch outside the registry names a provider", async () => {
  const text = await Deno.readTextFile(new URL("./connectors.ts", DIR));
  for (const id of ["it_sdi", "pl_ksef", "ro_efactura", "fr_pa", "peppol"]) {
    assert(
      !text.includes(`"${id}"`) && !text.includes(`case "${id}"`),
      `connectors.ts must not name ${id}`,
    );
  }
});
