// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3307 — the send function's fencing: the database decides who may send
// before anything leaves; the key is read only with the service role; the
// outcome is always recorded; an attempt that already has an outcome is
// never sent again; a timeout is recorded as unconfirmed; a delegated token
// and a malformed body are refused before any call.
import { assertEquals } from "jsr:@std/assert@1";
import { type Db, handle, parseSendRequest } from "./index.ts";
import type { OrderMailResult, SendOrder } from "../_shared/resend.ts";

const ids = {
  workspace_id: "00000000-0000-4000-8000-000000000001",
  order_id: "00000000-0000-4000-8000-000000000002",
  attempt_id: "00000000-0000-4000-8000-000000000003",
};
const body = {
  ...ids,
  revision: 2,
  subject: "Purchase order 2026-0001",
  text: "Please find our order attached.",
  pdf_base64: "JVBERi0xLjQ=",
  file_name: "purchase-order-2026-0001.pdf",
};

type Call = {
  fn: string;
  args: Record<string, unknown>;
  as: "caller" | "service";
};

function harness(opts: {
  begin?: { data: unknown; error: unknown };
  config?: { data: unknown; error: unknown };
  finish?: { data: unknown; error: unknown };
  result?: OrderMailResult;
}) {
  const calls: Call[] = [];
  const sent: SendOrder[] = [];
  const db = (as: "caller" | "service"): Db => ({
    rpc: (fn, args) => {
      calls.push({ fn, args, as });
      if (fn === "begin_purchase_order_send_v1") {
        return Promise.resolve(
          opts.begin ?? {
            data: {
              id: ids.attempt_id,
              state: "pending",
              recipient: "orders@alpha.test",
            },
            error: null,
          },
        );
      }
      if (fn === "purchase_order_mail_key_resolved") {
        return Promise.resolve(
          opts.config ?? {
            data: {
              api_key: "test-only-key",
              sender_email: "orders@space.test",
              sender_name: "The Space",
            },
            error: null,
          },
        );
      }
      return Promise.resolve(
        opts.finish ?? {
          data: {
            id: ids.attempt_id,
            state: (args as { p_outcome?: string }).p_outcome,
          },
          error: null,
        },
      );
    },
  });
  const deps = {
    caller: () => db("caller"),
    service: () => db("service"),
    send: (o: SendOrder) => {
      sent.push(o);
      return Promise.resolve(
        opts.result ??
          { kind: "accepted", providerId: "re_1" } as OrderMailResult,
      );
    },
  };
  return { calls, sent, deps };
}

const post = (
  b: unknown,
  headers: Record<string, string> = { Authorization: "Bearer user" },
) =>
  new Request("http://localhost/send-purchase-order", {
    method: "POST",
    headers,
    body: JSON.stringify(b),
  });

Deno.test("an accepted send: decided as the caller, keyed as the service, recorded", async () => {
  const h = harness({});
  const res = await handle(post(body), h.deps);
  assertEquals(res.status, 200);
  assertEquals(h.calls.map((c) => `${c.as}:${c.fn}`), [
    "caller:begin_purchase_order_send_v1",
    "service:purchase_order_mail_key_resolved",
    "service:finish_purchase_order_send",
  ]);
  assertEquals(h.sent.length, 1);
  assertEquals(h.sent[0].recipient, "orders@alpha.test");
  assertEquals(h.sent[0].attemptId, "00000000000040008000000000000003");
  assertEquals(h.calls[2].args.p_outcome, "accepted");
  assertEquals(h.calls[2].args.p_provider_id, "re_1");
  // The key never reaches the answer.
  assertEquals((await res.text()).includes("test-only-key"), false);
});

Deno.test("a timeout is recorded as unconfirmed and not retried", async () => {
  const h = harness({ result: { kind: "unconfirmed" } });
  const res = await handle(post(body), h.deps);
  assertEquals(res.status, 200);
  assertEquals(h.sent.length, 1);
  assertEquals(h.calls.at(-1)?.args.p_outcome, "unconfirmed");
});

Deno.test("a refusal by the database sends nothing and reads no key", async () => {
  for (
    const [code, status] of [["42501", 403], ["55000", 409], [
      "22023",
      400,
    ]] as const
  ) {
    const h = harness({
      begin: { data: null, error: { code, message: "refused" } },
    });
    const res = await handle(post(body), h.deps);
    assertEquals(res.status, status);
    assertEquals(h.sent.length, 0);
    assertEquals(h.calls.some((c) => c.as === "service"), false);
  }
});

Deno.test("a replayed attempt with an outcome is answered, never sent again", async () => {
  const h = harness({
    begin: {
      data: {
        id: ids.attempt_id,
        state: "accepted",
        recipient: "orders@alpha.test",
      },
      error: null,
    },
  });
  const res = await handle(post(body), h.deps);
  assertEquals(res.status, 200);
  assertEquals(h.sent.length, 0);
  assertEquals(h.calls.length, 1);
});

Deno.test("an unconfigured space records a refusal without calling the provider", async () => {
  const h = harness({ config: { data: null, error: null } });
  await handle(post(body), h.deps);
  assertEquals(h.sent.length, 0);
  assertEquals(h.calls.at(-1)?.args.p_outcome, "refused");
  assertEquals(h.calls.at(-1)?.args.p_reason, "mail_not_configured");
});

Deno.test("an outcome that could not be recorded says so", async () => {
  const h = harness({ finish: { data: null, error: { message: "down" } } });
  const res = await handle(post(body), h.deps);
  assertEquals(res.status, 502);
});

Deno.test("a malformed body or no session is refused before any call", async () => {
  const h = harness({});
  assertEquals(
    (await handle(post({ ...body, order_id: "x" }), h.deps)).status,
    400,
  );
  assertEquals(
    (await handle(post({ ...body, subject: "a\nBcc: b" }), h.deps)).status,
    400,
  );
  assertEquals((await handle(post(body, {}), h.deps)).status, 401);
  assertEquals(h.calls.length, 0);
  assertEquals("error" in parseSendRequest({ ...body, revision: 0 }), true);
});

Deno.test("a delegated token is refused before any call", async () => {
  const claims = btoa(JSON.stringify({ client_id: "assistant" })).replace(
    /=+$/,
    "",
  );
  const h = harness({});
  const res = await handle(
    post(body, { Authorization: `Bearer x.${claims}.y` }),
    h.deps,
  );
  assertEquals(res.status, 403);
  assertEquals(h.calls.length, 0);
});
