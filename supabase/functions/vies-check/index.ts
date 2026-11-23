// SPDX-License-Identifier: AGPL-3.0-or-later
//
// vies-check (#2354) — asks the EU's VIES service whether a member's VAT
// number is valid, and records the answer with its consultation number
// as evidence of the customer's business status (Implementing Regulation
// 282/2011 art. 18). A reverse-charged invoice is issued only on a valid
// check (create_invoice, 0404).
//
// The caller is resolved by the database, not here: `vies_check_subject`
// runs with the CALLER's token and refuses anyone who may not issue
// invoices, or a workspace with `viesVerification` off. Only then does
// this function talk to VIES, and only the service role may record the
// answer (`record_vies_check`). An outage is recorded as `unavailable`,
// which blocks the reverse charge instead of silently charging domestic
// VAT.

import { REFUSED_CODE } from "../_shared/webhook_guard.ts";
import { refuseDelegated } from "../_shared/delegated.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import { CORS, preflight } from "../_shared/cors.ts";
import { describeError, logLine } from "../_shared/log.ts";
import { ok, refuse } from "../_shared/respond.ts";
import { guard } from "../_shared/serve.ts";

const VIES_URL =
  "https://ec.europa.eu/taxation_customs/vies/rest-api/check-vat-number";

/** How long VIES gets before the check counts as an outage. */
const VIES_TIMEOUT_MS = 15000;

type Subject = {
  vat_id: string;
  country_code: string;
  number: string;
  requester_country: string;
  requester_number: string;
};

type Outcome = {
  status: "valid" | "invalid" | "unavailable";
  consultation: string;
  detail: string;
};

/** One VIES question; never throws — an outage is an outcome. */
export async function askVies(
  subject: Subject,
  fetcher: typeof fetch = fetch,
): Promise<Outcome> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), VIES_TIMEOUT_MS);
  try {
    const body: Record<string, string> = {
      countryCode: subject.country_code,
      vatNumber: subject.number,
    };
    // The requester makes VIES return a consultation number.
    if (subject.requester_country && subject.requester_number) {
      body.requesterMemberStateCode = subject.requester_country;
      body.requesterNumber = subject.requester_number;
    }
    const response = await fetcher(VIES_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json", Accept: "application/json" },
      body: JSON.stringify(body),
      signal: controller.signal,
    });
    const answer = await response.json().catch(() => ({}));
    if (response.ok && typeof answer?.valid === "boolean") {
      return {
        status: answer.valid ? "valid" : "invalid",
        consultation: String(answer.requestIdentifier ?? ""),
        detail: answer.valid ? "" : "not valid in VIES",
      };
    }
    const error = answer?.errorWrappers?.[0]?.error ?? `HTTP ${response.status}`;
    return { status: "unavailable", consultation: "", detail: String(error) };
  } catch (error) {
    logLine("warn", "vies-check", "vies_no_answer", { error: describeError(error) });
    return { status: "unavailable", consultation: "", detail: "no answer" };
  } finally {
    clearTimeout(timer);
  }
}

/** One check: the caller is resolved by the database, VIES is asked, the answer is recorded. */
export async function handle(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") return preflight();
  // #1614 — an assistant's delegated token never reaches this function.
  const delegated = refuseDelegated(req, CORS);
  if (delegated) return delegated;

  let payload: { workspace_id?: string; member_id?: string };
  try {
    payload = await req.json();
  } catch (error) {
    logLine("warn", "vies-check", "invalid_body", { error: describeError(error) });
    return refuse("invalid body", 400);
  }
  const workspaceId = payload.workspace_id ?? "";
  const memberId = payload.member_id ?? "";
  if (!workspaceId || !memberId) {
    return refuse("workspace_id and member_id required", 400);
  }

  const url = Deno.env.get("SUPABASE_URL")!;
  const caller = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: {
      headers: { Authorization: req.headers.get("Authorization") ?? "" },
    },
  });
  // WHO is asking, decided by the database before anything leaves.
  const { data: subject, error } = await caller.rpc("vies_check_subject", {
    p_workspace_id: workspaceId,
    p_member_id: memberId,
  });
  if (error || !subject) {
    // #3093 E9 — one fixed code; the text of a database error names tables.
    return refuse(REFUSED_CODE, 403);
  }
  const s = subject as Subject;
  if (!s.number || !s.country_code) {
    return refuse("no_vat_id", 409);
  }

  const outcome = await askVies(s);
  const admin = createClient(url, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: recorded, error: recordError } = await admin.rpc(
    "record_vies_check",
    {
      p_member_id: memberId,
      p_vat_id: s.vat_id,
      p_status: outcome.status,
      p_consultation: outcome.consultation,
      p_detail: outcome.detail,
    },
  );
  if (recordError) {
    logLine("error", "vies-check", "record_failed", { error: describeError(recordError) });
    return refuse("not recorded", 500);
  }
  return ok(recorded);
}

if (import.meta.main) {
  Deno.serve(guard("vies-check", handle));
}
