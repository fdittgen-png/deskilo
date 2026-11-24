// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice -- steps 2-5 of a send (#4400): verify, claim, post, record.

import { json, configFor, sha256, answer, DISPATCH_WINDOW_SECONDS } from "./common.ts";
import type { Environment, Destination, Config } from "./common.ts";
import { submit } from "./connectors.ts";
import type { Submission } from "./connectors.ts";
import { redact, safeError } from "./connectors/common.ts";
import { clientDetail } from "./connectors/safe_fetch.ts";
import type { TransmissionStore } from "./store.ts";
import { logLine } from "../_shared/log.ts";
/** What a prepared transmission needs to leave: its record, the stored
 * artifact's hash, and where it goes. */
export interface Dispatch {
  id: string;
  hash: string;
  provider: string;
  cfg: Config;
  environment: Environment;
  destination: Destination;
  fileName: string;
  mimeType: string;
  format: string;
  number: string;
  /** The binding the request verified (an invoice's send); a test
   * document has none. */
  binding?: string;
}

/** Steps 2-5 of a send, for an invoice's document and a sandbox test
 * document alike (#3883): verify the stored artifact, claim the dispatch,
 * post it, record the outcome. */
export async function dispatchPrepared(
  store: TransmissionStore,
  fetchImpl: typeof fetch,
  d: Dispatch,
): Promise<Response> {
  const {
    id,
    hash,
    provider,
    cfg,
    environment,
    destination,
    fileName,
    mimeType,
    format,
  } = d;
  // 2. VERIFY the stored artifact before it can leave (O1).
  let artifact;
  try {
    artifact = await store.artifact(id);
  } catch (error) {
    logLine("error", "send-e-invoice", "artifact_read_failed", { error: safeError(error) });
    return json({ error: "artifact_unavailable" }, 500);
  }
  if (
    !artifact || artifact.sha256 !== hash ||
    (await sha256(artifact.bytes)) !== hash
  ) {
    return json({ error: "artifact_unavailable" }, 500);
  }

  // 3. CLAIM the dispatch atomically; only the winner calls the provider.
  const owner = crypto.randomUUID();
  let claim;
  try {
    claim = await store.claim(id, owner, DISPATCH_WINDOW_SECONDS, d.binding);
  } catch (error) {
    logLine("error", "send-e-invoice", "claim_failed", { error: safeError(error) });
    return json({ error: "claim_failed" }, 500);
  }
  if (!claim.claimed && claim.detail === "binding_changed") {
    // the document was replaced after it was verified: this request holds
    // the old one and sends nothing
    return json({
      error: "binding_changed",
      phase: claim.phase,
      transmission_id: id,
      detail: "This invoice was prepared again with other content; this " +
        "request sent nothing.",
    }, 409);
  }
  if (!claim.claimed || claim.generation === undefined) {
    return answer(
      claim.phase ?? "sent",
      id,
      claim.external_id ?? "",
      claim.detail ?? "",
      environment,
      destination,
    );
  }

  // 4. POST from the STORED artifact, provider, destination, environment.
  const outcome: Submission = await submit(
    provider,
    configFor(cfg, environment, provider),
    {
      fileName: artifact.fileName || fileName,
      mimeType: artifact.mimeType || mimeType,
      bytes: artifact.bytes,
      format,
      number: d.number,
      receiver: artifact.receiverId
        ? { scheme: artifact.receiverScheme, id: artifact.receiverId }
        : undefined,
    },
    fetchImpl,
  );
  // #3090 — the provider's own words are for the server log only.
  if (outcome.status !== "accepted") {
    logLine("error", "send-e-invoice", `transmission_${outcome.status}`, { detail: redact(outcome.detail) });
  }

  // 5. RECORD against this owner and generation. If the write is lost the
  // dispatch stays `sent` and expires to `uncertain`: never rejected.
  const detail = clientDetail(
    outcome.status === "uncertain" ? "failed" : outcome.status,
    outcome.detail,
  );
  let recorded = false;
  try {
    recorded = await store.record(
      id,
      claim.generation,
      owner,
      outcome.status,
      outcome.externalId,
      detail,
      outcome.receipt,
    );
  } catch (error) {
    logLine("error", "send-e-invoice", "outcome_write_failed", { error: safeError(error) });
  }
  if (!recorded) {
    return answer(
      "uncertain",
      id,
      outcome.externalId,
      "",
      environment,
      destination,
    );
  }
  // #3932 -- a platform that decides in the answer to the upload: its verdict
  // is recorded beside the upload, as a later status query would
  if (outcome.verdict !== undefined && outcome.status === "accepted") {
    try {
      await store.lookup(
        id,
        null,
        outcome.externalId,
        outcome.receipt,
        { status: outcome.verdict, detail: clientDetail(outcome.verdict, outcome.detail) },
        "",
      );
    } catch (error) {
      logLine("error", "send-e-invoice", "verdict_write_failed", { error: safeError(error) });
    }
  }
  return answer(
    outcome.status,
    id,
    outcome.externalId,
    detail,
    environment,
    destination,
  );
}
