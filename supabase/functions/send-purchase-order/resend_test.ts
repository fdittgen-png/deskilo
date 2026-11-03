// SPDX-License-Identifier: AGPL-3.0-or-later
// A provider receipt is accepted, a timeout remains unknown, and invalid mail is never sent.
import { assertEquals } from "jsr:@std/assert@1";
import { type SendOrder, sendOrderViaResend } from "./resend.ts";

const order: SendOrder = {
  apiKey: "test-only",
  sender: "owner@example.test",
  recipient: "vendor@example.test",
  subject: "PO-1",
  text: "Please see the order.",
  pdfBase64: "JVBERi0xLjQ=",
  fileName: "order.pdf",
  attemptId: "attempt-1",
};

Deno.test("sends one PDF with an attempt-bound idempotency key", async () => {
  let called = 0;
  const fake: typeof fetch = async (_input, init) => {
    called++;
    const headers = new Headers(init?.headers);
    assertEquals(headers.get("Idempotency-Key"), "purchase-order/attempt-1");
    const body = JSON.parse(String(init?.body));
    assertEquals(body.attachments, [{
      filename: "order.pdf",
      content: order.pdfBase64,
    }]);
    return new Response(JSON.stringify({ id: "synthetic-id" }), {
      status: 200,
    });
  };
  assertEquals(await sendOrderViaResend(order, fake), {
    kind: "accepted",
    providerId: "synthetic-id",
  });
  assertEquals(called, 1);
});

Deno.test("invalid recipient or attachment does not call provider", async () => {
  let called = 0;
  const fake: typeof fetch = async () => {
    called++;
    return new Response();
  };
  assertEquals(
    (await sendOrderViaResend({ ...order, recipient: "bad\r\nBcc:x" }, fake))
      .kind,
    "refused",
  );
  assertEquals(
    (await sendOrderViaResend({ ...order, pdfBase64: "aW52YWxpZA==" }, fake))
      .kind,
    "refused",
  );
  assertEquals(called, 0);
});

Deno.test("transport error, server error and unreadable receipt remain unconfirmed", async () => {
  const timeout: typeof fetch = async () => {
    throw new Error("timeout");
  };
  assertEquals(await sendOrderViaResend(order, timeout), {
    kind: "unconfirmed",
  });
  assertEquals(
    await sendOrderViaResend(
      order,
      async () => new Response("", { status: 503 }),
    ),
    { kind: "unconfirmed" },
  );
  assertEquals(
    await sendOrderViaResend(order, async () => new Response("", { status: 409 })),
    { kind: "unconfirmed" },
  );
  assertEquals(
    await sendOrderViaResend(
      order,
      async () => new Response("not json", { status: 200 }),
    ),
    { kind: "unconfirmed" },
  );
  assertEquals(
    await sendOrderViaResend(
      order,
      async () => new Response("", { status: 422 }),
    ),
    { kind: "refused", reason: "provider_422" },
  );
});
