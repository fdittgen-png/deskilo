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
  const fake: typeof fetch = (_input, init) => {
    called++;
    const headers = new Headers(init?.headers);
    assertEquals(headers.get("Idempotency-Key"), "purchase-order/attempt-1");
    const body = JSON.parse(String(init?.body));
    assertEquals(body.attachments, [{
      filename: "order.pdf",
      content: order.pdfBase64,
    }]);
    return Promise.resolve(
      new Response(JSON.stringify({ id: "synthetic-id" }), {
        status: 200,
      }),
    );
  };
  assertEquals(await sendOrderViaResend(order, fake), {
    kind: "accepted",
    providerId: "synthetic-id",
  });
  assertEquals(called, 1);
});

Deno.test("invalid recipient or attachment does not call provider", async () => {
  let called = 0;
  const fake: typeof fetch = () => {
    called++;
    return Promise.resolve(new Response());
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
  const timeout: typeof fetch = () => Promise.reject(new Error("timeout"));
  assertEquals(await sendOrderViaResend(order, timeout), {
    kind: "unconfirmed",
  });
  assertEquals(
    await sendOrderViaResend(
      order,
      () => Promise.resolve(new Response("", { status: 503 })),
    ),
    { kind: "unconfirmed" },
  );
  assertEquals(
    await sendOrderViaResend(
      order,
      () => Promise.resolve(new Response("", { status: 409 })),
    ),
    { kind: "unconfirmed" },
  );
  assertEquals(
    await sendOrderViaResend(
      order,
      () => Promise.resolve(new Response("not json", { status: 200 })),
    ),
    { kind: "unconfirmed" },
  );
  assertEquals(
    await sendOrderViaResend(
      order,
      () => Promise.resolve(new Response("", { status: 422 })),
    ),
    { kind: "refused", reason: "provider_422" },
  );
});

Deno.test("a sender's name travels beside the address, never as a header", async () => {
  let from = "";
  const fake: typeof fetch = (_input, init) => {
    from = JSON.parse(String(init?.body)).from;
    return Promise.resolve(
      new Response(JSON.stringify({ id: "synthetic-id" }), { status: 200 }),
    );
  };
  await sendOrderViaResend({ ...order, senderName: "The Space" }, fake);
  assertEquals(from, "The Space <owner@example.test>");
  let called = 0;
  const counting: typeof fetch = () => {
    called++;
    return Promise.resolve(new Response("{}", { status: 200 }));
  };
  assertEquals(
    await sendOrderViaResend(
      { ...order, senderName: "x\r\nBcc: y@z.t" },
      counting,
    ),
    { kind: "refused", reason: "invalid_order_mail" },
  );
  assertEquals(called, 0);
});
