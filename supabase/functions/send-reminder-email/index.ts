// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-reminder-email (#3673) — e-mails a payment reminder letter to the
// customer through the business's own Resend sender (0724).
//
// The CLIENT builds the letter with the same report system that prints it,
// in the customer's document language, and posts the bytes, the subject and
// the text here with that language; this function holds the key and does
// the sending. It writes no words of its own. The key never reaches a
// phone: it lives in Vault and only the service role reads it
// (`business_mail_key_resolved`).
//
// Durable fencing, in this order (0726):
//   1. `begin_reminder_email_v1`, with the CALLER's token, decides who may
//      send (a native session that issues invoices, the reminderEmail
//      feature, an invoice that owes and is not on hold, the level the rules
//      give now, the sender configured, the customer's address on file) and
//      opens the attempt. One e-mail per invoice and level may leave; a
//      pending or unconfirmed earlier attempt refuses a new one; the same
//      attempt id replays it, and the answer says whether it may still be
//      sent: by the call that opened it, or by a young replay. An older
//      pending attempt is never sent again (the provider's idempotency
//      window is not relied on): a person decides it.
//   2. Resend is called with the attempt id as its idempotency key.
//   3. `finish_reminder_email` (service role) records what came back:
//      accepted (the reminder is counted, with its e-mail evidence), refused
//      (its reason; nothing is counted) or unconfirmed — a timeout, a 5xx, an
//      unreadable receipt. Unconfirmed is never retried here: a person
//      decides it in the app.
//
// An attempt this function opened is always finished, whatever happens
// after the call; a failure to record it leaves it pending, which blocks a
// second send just the same.

import { refuseDelegated } from "../_shared/delegated.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { CORS, preflight } from "../_shared/cors.ts";
import {
  type OrderMailResult,
  sendOrderViaResend,
} from "../send-purchase-order/resend.ts";

/** The most a request body may weigh: the ids and the base64 PDF Resend
 * accepts (resend.ts bounds the PDF at 8 MB of base64). */
export const MAX_BODY_BYTES = 8_100_000;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const LANGUAGES = new Set(["en", "fr", "de", "es", "it"]);

export type SendRequest = {
  workspace_id: string;
  invoice_id: string;
  level: number;
  language: string;
  attempt_id: string;
  subject: string;
  text: string;
  pdf_base64: string;
  file_name: string;
};

/** Reads and checks a body; the words of a refusal otherwise. */
export function parseSendRequest(
  body: unknown,
): SendRequest | { error: string } {
  if (typeof body !== "object" || body === null) {
    return { error: "invalid body" };
  }
  const b = body as Record<string, unknown>;
  const str = (k: string) => (typeof b[k] === "string" ? (b[k] as string) : "");
  for (const k of ["workspace_id", "invoice_id", "attempt_id"]) {
    if (!UUID.test(str(k))) return { error: `${k} required` };
  }
  const level = typeof b.level === "number" ? b.level : NaN;
  if (!Number.isInteger(level) || level < 1) {
    return { error: "level required" };
  }
  // No language, no letter: the server never chooses one for the customer.
  if (!LANGUAGES.has(str("language"))) return { error: "language required" };
  if (!str("subject").trim() || /[\r\n]/.test(str("subject"))) {
    return { error: "subject required" };
  }
  if (!str("pdf_base64")) return { error: "pdf required" };
  return {
    workspace_id: str("workspace_id"),
    invoice_id: str("invoice_id"),
    level,
    language: str("language"),
    attempt_id: str("attempt_id"),
    subject: str("subject").trim(),
    text: str("text"),
    pdf_base64: str("pdf_base64"),
    file_name: str("file_name"),
  };
}

export type Db = {
  rpc: (
    fn: string,
    args: Record<string, unknown>,
  ) => PromiseLike<{ data: unknown; error: unknown }>;
};

export type Deps = {
  /** A client bound to the caller's own token. */
  caller: (authorization: string) => Db;
  /** The service role, for the key and the outcome only. */
  service: () => Db;
  /** Sends one mail; the Resend transport in production. */
  send?: typeof sendOrderViaResend;
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, "Content-Type": "application/json" },
  });

type Attempt = {
  id: string;
  state: string;
  recipient: string;
  sendable: boolean;
};

function attemptOf(data: unknown): Attempt | null {
  if (typeof data !== "object" || data === null) return null;
  const d = data as Record<string, unknown>;
  return typeof d.id === "string" && typeof d.state === "string" &&
      typeof d.recipient === "string"
    ? {
      id: d.id,
      state: d.state,
      recipient: d.recipient,
      sendable: d.sendable === true,
    }
    : null;
}

/** The outcome as `finish_reminder_email` records it. */
function outcomeOf(result: OrderMailResult) {
  switch (result.kind) {
    case "accepted":
      return {
        p_outcome: "accepted",
        p_provider_id: result.providerId,
        p_reason: "",
      };
    case "refused":
      return {
        p_outcome: "refused",
        p_provider_id: "",
        p_reason: result.reason,
      };
    default:
      return {
        p_outcome: "unconfirmed",
        p_provider_id: "",
        p_reason: "no confirmed answer",
      };
  }
}

export async function handle(req: Request, deps: Deps): Promise<Response> {
  if (req.method === "OPTIONS") return preflight();
  // #1614 — an assistant's delegated token never reaches this function.
  const delegated = refuseDelegated(req, CORS);
  if (delegated) return delegated;
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization) return json({ error: "not signed in" }, 401);
  if (Number(req.headers.get("content-length") ?? "0") > MAX_BODY_BYTES) {
    return json({ error: "body too large" }, 400);
  }
  const text = await req.text();
  if (text.length > MAX_BODY_BYTES) {
    return json({ error: "body too large" }, 400);
  }
  let payload: unknown;
  try {
    payload = JSON.parse(text);
  } catch {
    return json({ error: "invalid body" }, 400);
  }
  const parsed = parseSendRequest(payload);
  if ("error" in parsed) return json({ error: parsed.error }, 400);

  // 1. Who may send, decided by the database with the caller's token.
  const begun = await deps.caller(authorization).rpc(
    "begin_reminder_email_v1",
    {
      p_workspace_id: parsed.workspace_id,
      p_invoice_id: parsed.invoice_id,
      p_level: parsed.level,
      p_language: parsed.language,
      p_attempt_id: parsed.attempt_id,
    },
  );
  if (begun.error) {
    const e = begun.error as { code?: string; message?: string };
    const status = e.code === "42501"
      ? 403
      : e.code === "55000" || e.code === "40001"
      ? 409
      : 400;
    return json({ error: e.message ?? "refused", code: e.code ?? "" }, status);
  }
  const attempt = attemptOf(begun.data);
  if (!attempt) return json({ error: "no attempt" }, 500);
  // A replayed attempt that already has its outcome is answered as it is:
  // never sent a second time.
  if (attempt.state !== "pending") return json(begun.data);
  // A pending attempt is sent by the call that opened it or a young replay
  // only; an older one may have left: a person decides it.
  if (!attempt.sendable) {
    return json({
      error:
        "an earlier e-mail of this reminder has no confirmed outcome: decide it by hand",
      code: "55000",
    }, 409);
  }

  const service = deps.service();
  const config = await service.rpc("business_mail_key_resolved", {
    p_workspace_id: parsed.workspace_id,
  });
  const c = (config.data ?? {}) as Record<string, unknown>;
  let result: OrderMailResult;
  if (
    config.error || typeof c.api_key !== "string" ||
    typeof c.sender_email !== "string"
  ) {
    result = { kind: "refused", reason: "mail_not_configured" };
  } else {
    const name = typeof c.sender_name === "string" ? c.sender_name.trim() : "";
    result = await (deps.send ?? sendOrderViaResend)({
      apiKey: c.api_key,
      sender: c.sender_email,
      senderName: name,
      recipient: attempt.recipient,
      subject: parsed.subject,
      text: parsed.text,
      pdfBase64: parsed.pdf_base64,
      fileName: parsed.file_name,
      attemptId: parsed.attempt_id.replace(/-/g, ""),
      kind: "payment-reminder",
    });
  }
  // 3. The outcome, recorded whatever it is.
  const finished = await service.rpc("finish_reminder_email", {
    p_attempt_id: parsed.attempt_id,
    ...outcomeOf(result),
  });
  if (finished.error) {
    console.error("send-reminder-email: the outcome could not be recorded");
    return json({
      error: "the outcome could not be recorded",
      state: "pending",
    }, 502);
  }
  return json(finished.data);
}

if (import.meta.main) {
  const url = Deno.env.get("SUPABASE_URL")!;
  const deps: Deps = {
    caller: (authorization) =>
      createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
        global: { headers: { Authorization: authorization } },
      }),
    service: () =>
      createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!),
  };
  Deno.serve((req) => handle(req, deps));
}
