// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice -- the `resolve` action (#4400). A person settles an uncertain submission.

import type { Action } from "../common.ts";
import { json } from "../common.ts";
import { safeError } from "../connectors/common.ts";
import { logLine } from "../../_shared/log.ts";

export const resolve: Action = async (ctx) => {
  const { store, payload, workspaceId, userId } = ctx;
  const target = await store.transmission(payload.transmission_id ?? "");
  if (!target || target.workspace_id !== workspaceId) {
    return json({ error: "unknown transmission" }, 404);
  }
  if (!["accepted", "rejected", "failed"].includes(payload.outcome ?? "")) {
    return json({ error: "invalid resolution" }, 400);
  }
  try {
    const done = await store.resolve(
      target.id,
      userId,
      payload.outcome as "accepted" | "rejected" | "failed",
      payload.reason ?? "",
      payload.evidence ?? "",
      payload.verdict ?? null,
    );
    return json(
      { resolved: done.resolved, phase: done.phase ?? null },
      done.resolved ? 200 : 409,
    );
  } catch (error) {
    const code = (error as { code?: string }).code;
    if (code === "42501") {
      return json({ error: "not allowed to issue invoices in this workspace" }, 403);
    }
    if (code === "22023") {
      return json({ error: "a reason and the evidence are required" }, 400);
    }
    logLine("error", "send-e-invoice", "resolve_failed", { error: safeError(error) });
    return json({ error: "resolve_failed" }, 500);
  }
};
