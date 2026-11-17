// SPDX-License-Identifier: AGPL-3.0-or-later
import { CORS } from "../_shared/cors.ts";

interface Caller {
  rpc(name: string, args: Record<string, unknown>): PromiseLike<{
    data: unknown;
    error: { code?: string } | null;
  }>;
}

export type ContinuedIntent = Record<string, unknown> & {
  id: string;
  reference: string;
  status: string;
  created_at: string;
};

const uuid = (value: unknown): value is string => typeof value === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);

/** Resolve only an existing own intent. Client amounts, providers and request
 * keys are ignored; an unknown payment can never fall through to creation. */
export async function continuationOf(
  body: Record<string, unknown>,
  caller: () => Caller,
): Promise<ContinuedIntent | Response | null> {
  if (body.action !== "continue") return null;
  const unavailable = () => Response.json(
    { error: "claim_refused", code: "DKC10" },
    { status: 409, headers: CORS },
  );
  if (!uuid(body.payment_id) || !uuid(body.workspace_id)) return unavailable();
  const { data, error } = await caller().rpc("resume_payment_claim", {
    p_workspace: body.workspace_id,
    p_intent: body.payment_id,
  });
  if (error?.code === "PGRST202" || error?.code === "42883") {
    return Response.json({ status: "not_configured", missing: ["resume_payment_claim (not deployed)"] }, { headers: CORS });
  }
  if (error || !data || typeof data !== "object" || Array.isArray(data)) return unavailable();
  const intent = data as Record<string, unknown>;
  if (intent.id !== body.payment_id || intent.workspace_id !== body.workspace_id ||
    !uuid(intent.member_id) || !uuid(intent.request_id) || intent.status !== "created" ||
    typeof intent.reference !== "string" || typeof intent.created_at !== "string") return unavailable();
  return { ...intent, id: body.payment_id, reference: intent.reference,
    status: intent.status, created_at: intent.created_at, reused: true };
}
