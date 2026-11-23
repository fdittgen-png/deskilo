// SPDX-License-Identifier: AGPL-3.0-or-later
// #4412 -- the invariant: a catch of an edge function logs, rethrows or says why it is handled; an empty or
// swallowing one fails the CI check, and the ones that predate the rule only fall.
import { assertEquals } from "jsr:@std/assert@1";
import { checkTree, unaccountedCatches } from "./catch_check.ts";

Deno.test("#4412 an empty or swallowing catch is seen; one that logs, rethrows or says why is not", () => {
  assertEquals(unaccountedCatches("try { a(); } catch (e) {}"), [""]);
  assertEquals(unaccountedCatches("try { a(); } catch { }").length, 1);
  assertEquals(unaccountedCatches("try { a(); } catch (e) { console.warn('x', e); }").length, 1);
  assertEquals(unaccountedCatches("try { a(); } catch (e) { logLine('warn', 'f', 'c'); }"), []);
  assertEquals(unaccountedCatches("try { a(); } catch (e) { return fail(e, { fn: 'f' }); }"), []);
  assertEquals(unaccountedCatches("try { a(); } catch (e) { throw new Error('x'); }"), []);
  assertEquals(unaccountedCatches("try { a(); } catch { // handled: the default is the answer\n return 1; }"), []);
  assertEquals(unaccountedCatches("const s = \"} catch {\"; const o = { a: 1 };"), []);
});

Deno.test("#4412 a promise catch is a catch; text inside a string or a comment is not code", () => {
  assertEquals(unaccountedCatches("p.catch(() => {});").length, 1);
  assertEquals(unaccountedCatches("p.catch(() => ({}));").length, 1);
  assertEquals(unaccountedCatches("p.catch((e) => logLine('warn', 'f', 'c', { e }));"), []);
  assertEquals(unaccountedCatches("p.catch((e) => { throw e; });"), []);
  assertEquals(unaccountedCatches("p.catch(() => null /* handled: the default is the answer */);"), []);
  // a logger named only in a string or a comment does not account for the catch
  assertEquals(unaccountedCatches("try { a(); } catch (e) { const t = 'logLine('; }").length, 1);
  assertEquals(unaccountedCatches("try { a(); } catch (e) { // logLine(e) later\n }").length, 1);
  assertEquals(unaccountedCatches("try { a(); } catch (e) { const t = 'throw'; }").length, 1);
  // a catch written inside a comment or a string is not one
  assertEquals(unaccountedCatches("// try {} catch (e) {}\nconst s = 'catch (e) {}';"), []);
});

Deno.test("#4412 the CI check fails on a fixture with an empty catch, and a baseline holds what predates it", () => {
  const dir = Deno.makeTempDirSync();
  try {
    Deno.mkdirSync(`${dir}/fn`);
    Deno.writeTextFileSync(`${dir}/fn/index.ts`, "export function f() { try { g(); } catch (e) {} }\n");
    const failing = checkTree(dir, {});
    assertEquals(failing.problems.length, 1);
    assertEquals(failing.counts, { "fn/index.ts": 1 });
    assertEquals(checkTree(dir, { "fn/index.ts": 1 }).problems, []);
    assertEquals(checkTree(dir, { "fn/index.ts": 2 }).problems.length, 1); // it fell: the baseline is lowered
    Deno.writeTextFileSync(`${dir}/fn/index.ts`, "export function f() { try { g(); } catch (e) { // handled: g is optional\n } }\n");
    assertEquals(checkTree(dir, {}).problems, []);
  } finally {
    Deno.removeSync(dir, { recursive: true });
  }
});

Deno.test("#4412 the baseline is the tree's: no function gained an unaccounted catch", () => {
  const root = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
  const baseline = JSON.parse(Deno.readTextFileSync(new URL("./catch_baseline.json", import.meta.url)));
  assertEquals(checkTree(root, baseline).problems, []);
});
