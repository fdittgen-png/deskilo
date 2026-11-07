import { assertEquals } from "jsr:@std/assert@1";
Deno.test("PROOF #3329: a nested test is run by CI", () => assertEquals(1, 2));
