// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice -- the `test_state` action (#4400). The state of the sandbox test document of the national channel (#3883).

import type { Action } from "../common.ts";
import { json } from "../common.ts";
import { acceptedFormats, takesTestDocument } from "../connectors.ts";

export const test_state: Action = async (ctx) => {
  const { store, workspaceId, mayManage, credentials } = ctx;
  if (!mayManage) {
    return json({
      error: "not allowed to manage the integrations of this workspace",
    }, 403);
  }
  const latest = await store.latestTest(workspaceId);
  const verdict = (latest?.verdict ?? {}) as Record<string, unknown>;
  return json({
    available: takesTestDocument(credentials?.provider ?? "generic"),
    // the channel's own syntax: a test document is built in it (#3930)
    format: takesTestDocument(credentials?.provider ?? "generic")
      ? (acceptedFormats(credentials?.provider ?? "generic")[0] ?? "")
      : "",
    test: latest === null ? null : {
      transmission_id: latest.id,
      phase: latest.phase,
      document_status: verdict.document === "rejected"
        ? "rejected"
        : verdict.status === "accepted" || verdict.status === "rejected"
        ? verdict.status
        : "unknown",
    },
  });
};
