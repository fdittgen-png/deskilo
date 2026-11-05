// SPDX-License-Identifier: AGPL-3.0-or-later
// Resend transport only. Authorization and durable send fencing belong to the caller.
export type SendOrder = {
  apiKey: string;
  sender: string;
  /** Shown beside the address; checked for header characters. */
  senderName?: string;
  recipient: string;
  subject: string;
  text: string;
  pdfBase64: string;
  fileName: string;
  attemptId: string;
};

export type OrderMailResult =
  | { kind: "accepted"; providerId: string }
  | { kind: "refused"; reason: string }
  | { kind: "unconfirmed" };

const mail = /^[^\s@<>",;()[\]\\]+@[^\s@<>",;()[\]\\]+\.[^\s@<>",;()[\]\\]+$/;
/** How long the provider has to answer; past it the outcome is unknown. */
const providerTimeoutMs = 20_000;
const key = /^[A-Za-z0-9_-]{1,100}$/;
const pdf = /^[A-Za-z0-9+/]+={0,2}$/;

/// A transport failure is an unknown outcome, never a reason to auto-resend.
export async function sendOrderViaResend(
  order: SendOrder,
  transport: typeof fetch = fetch,
): Promise<OrderMailResult> {
  if (
    !order.apiKey || !mail.test(order.sender) || !mail.test(order.recipient) ||
    /[\r\n<>"]/.test(order.senderName ?? "") ||
    !order.subject.trim() || /[\r\n]/.test(order.subject) ||
    !key.test(order.attemptId) ||
    !/^[A-Za-z0-9._-]{1,100}\.pdf$/.test(order.fileName) ||
    !pdf.test(order.pdfBase64) || !order.pdfBase64.startsWith("JVBERi0") ||
    order.pdfBase64.length > 8_000_000
  ) {
    return { kind: "refused", reason: "invalid_order_mail" };
  }
  let response: Response;
  try {
    response = await transport("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${order.apiKey}`,
        "Content-Type": "application/json",
        "Idempotency-Key": `purchase-order/${order.attemptId}`,
      },
      body: JSON.stringify({
        from: order.senderName
          ? `${order.senderName} <${order.sender}>`
          : order.sender,
        to: [order.recipient],
        subject: order.subject,
        text: order.text,
        attachments: [{ filename: order.fileName, content: order.pdfBase64 }],
      }),
      signal: AbortSignal.timeout(providerTimeoutMs),
    });
  } catch {
    return { kind: "unconfirmed" };
  }
  if (
    response.status >= 500 || response.status === 408 || response.status === 409
  ) {
    return { kind: "unconfirmed" };
  }
  if (!response.ok) {
    return { kind: "refused", reason: `provider_${response.status}` };
  }
  try {
    const json: unknown = await response.json();
    if (
      typeof json === "object" && json !== null && "id" in json &&
      typeof json.id === "string" && json.id.length > 0
    ) {
      return { kind: "accepted", providerId: json.id };
    }
  } catch {
    // Accepted status without a readable receipt is an unknown outcome.
  }
  return { kind: "unconfirmed" };
}
