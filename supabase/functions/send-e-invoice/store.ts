// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3335 — everything send-e-invoice reads and writes, behind one narrow
// interface. The handler (handler.ts) talks only to this, so its tests
// inject an in-memory store and a scripted provider: the decisions that
// matter (one dispatch owner, uncertain is never resent, a late writer
// records nothing) are exercised without a database. The Supabase
// implementation below is a thin mapping onto the 0689 RPCs.

import { SupabaseClient } from "npm:@supabase/supabase-js@2";

export type Phase =
  | "prepared"
  | "sent"
  | "accepted"
  | "rejected"
  | "failed"
  | "uncertain";

export interface Member {
  id: string;
  is_admin: boolean;
  is_owner: boolean;
  status: string;
}

export interface TransmissionRow {
  id: string;
  workspace_id: string;
  provider: string;
  phase: Phase;
  external_id: string;
  detail: string;
  environment: string;
  destination: string;
  format: string;
  receipt: Record<string, unknown>;
}

export interface PrepareInput {
  workspaceId: string;
  invoiceId: string;
  provider: string;
  destination: string;
  environment: string;
  actor: string;
  byName: string;
  format: string;
  hash: string;
  fileName: string;
  mimeType: string;
  receiverScheme: string;
  receiverId: string;
  bytes: Uint8Array<ArrayBuffer>;
  /** What the client says about its renderer, already clipped (see
   * clipDeclared in handler.ts); kept apart from what the server knows. */
  declared: Record<string, string>;
}

export interface PrepareResult {
  outcome: "prepared" | "existing" | "conflict" | "unknown_invoice";
  id?: string;
  phase?: Phase;
  external_id?: string;
  detail?: string;
}

export interface ClaimResult {
  claimed: boolean;
  generation?: number;
  phase?: Phase;
  external_id?: string;
  detail?: string;
}

export interface Artifact {
  bytes: Uint8Array<ArrayBuffer>;
  sha256: string;
  fileName: string;
  mimeType: string;
  receiverScheme: string;
  receiverId: string;
}

export interface TransmissionStore {
  user(token: string): Promise<string | null>;
  member(workspaceId: string, userId: string): Promise<Member | null>;
  hasPermission(memberId: string, permission: string): Promise<boolean>;
  credentials(
    workspaceId: string,
  ): Promise<{ provider: string; config: Record<string, string> } | null>;
  workspaceEnvironment(workspaceId: string): Promise<string>;
  invoice(
    id: string,
  ): Promise<{ id: string; number: string; workspace_id: string } | null>;
  profileName(userId: string): Promise<string>;
  transmission(id: string): Promise<TransmissionRow | null>;
  expire(workspaceId: string): Promise<void>;
  prepare(input: PrepareInput): Promise<PrepareResult>;
  artifact(id: string): Promise<Artifact | null>;
  claim(id: string, owner: string, windowSeconds: number): Promise<ClaimResult>;
  record(
    id: string,
    generation: number,
    owner: string,
    phase: "accepted" | "rejected" | "failed" | "uncertain",
    externalId: string,
    detail: string,
    receipt: Record<string, unknown>,
  ): Promise<boolean>;
  lookup(
    id: string,
    phase: "accepted" | "rejected" | null,
    externalId: string,
    receipt: Record<string, unknown> | null,
    verdict: Record<string, unknown> | null,
    queryError: string | null,
  ): Promise<boolean>;
  resolve(
    id: string,
    actor: string,
    outcome: "accepted" | "rejected" | "failed",
    reason: string,
    evidence: string,
    verdict: Record<string, unknown> | null,
  ): Promise<{ resolved: boolean; phase?: Phase }>;
}

/** A Postgres bytea travels through PostgREST as a `\x…` hex string. */
const toHex = (bytes: Uint8Array): string =>
  "\\x" + [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");

function fromHex(text: string): Uint8Array<ArrayBuffer> {
  const hex = text.startsWith("\\x") ? text.slice(2) : text;
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

export function supabaseStore(admin: SupabaseClient): TransmissionStore {
  // An RPC error is thrown, never swallowed: the handler turns a failure
  // before dispatch into "no upload", and one after it into "uncertain".
  const rpc = async <T>(name: string, args: Record<string, unknown>) => {
    const { data, error } = await admin.rpc(name, args);
    if (error) {
      throw Object.assign(new Error(error.message), { code: error.code });
    }
    return data as T;
  };
  return {
    async user(token) {
      const { data, error } = await admin.auth.getUser(token);
      if (error || !data?.user) {
        console.error("send-e-invoice auth failed", error?.message);
        return null;
      }
      return data.user.id;
    },
    async member(workspaceId, userId) {
      const { data } = await admin
        .from("members")
        .select("id, is_admin, is_owner, status")
        .eq("workspace_id", workspaceId)
        .eq("user_id", userId)
        .maybeSingle();
      return data ?? null;
    },
    async hasPermission(memberId, permission) {
      const { data } = await admin.rpc("member_has_permission", {
        p_member_id: memberId,
        perm: permission,
      });
      return data === true;
    },
    async credentials(workspaceId) {
      const { data, error } = await admin.rpc("einvoice_credentials_resolved", {
        p_workspace_id: workspaceId,
      });
      if (!error) {
        return data
          ? { provider: data.provider ?? "generic", config: data.config ?? {} }
          : null;
      }
      // an instance whose database predates #2358 keeps plain values
      const { data: row } = await admin
        .from("einvoice_credentials")
        .select("provider, config")
        .eq("workspace_id", workspaceId)
        .maybeSingle();
      return row
        ? { provider: row.provider ?? "generic", config: row.config ?? {} }
        : null;
    },
    async workspaceEnvironment(workspaceId) {
      const { data } = await admin.from("workspaces").select("environment")
        .eq("id", workspaceId).maybeSingle();
      return data?.environment ?? "dev";
    },
    async invoice(id) {
      const { data } = await admin.from("invoices")
        .select("id, number, workspace_id").eq("id", id).maybeSingle();
      return data ?? null;
    },
    async profileName(userId) {
      const { data } = await admin.from("profiles").select("display_name")
        .eq("id", userId).maybeSingle();
      return data?.display_name ?? "";
    },
    async transmission(id) {
      const { data } = await admin.from("invoice_transmissions")
        .select(
          "id, workspace_id, provider, phase, external_id, detail, " +
            "environment, destination, format, receipt",
        ).eq("id", id).maybeSingle();
      return (data as TransmissionRow | null) ?? null;
    },
    async expire(workspaceId) {
      await rpc("expire_einvoice_dispatches_v1", {
        p_workspace_id: workspaceId,
      });
    },
    prepare(i) {
      return rpc<PrepareResult>("prepare_einvoice_v1", {
        p_workspace_id: i.workspaceId,
        p_invoice_id: i.invoiceId,
        p_provider: i.provider,
        p_destination: i.destination,
        p_environment: i.environment,
        p_actor: i.actor,
        p_by_name: i.byName,
        p_format: i.format,
        p_hash: i.hash,
        p_file_name: i.fileName,
        p_mime_type: i.mimeType,
        p_receiver_scheme: i.receiverScheme,
        p_receiver_id: i.receiverId,
        p_bytes: toHex(i.bytes),
        p_declared: i.declared,
      });
    },
    async artifact(id) {
      const { data } = await admin.from("invoice_transmission_artifacts")
        .select(
          "bytes, sha256, file_name, mime_type, receiver_scheme, receiver_id",
        )
        .eq("transmission_id", id).maybeSingle();
      if (!data) return null;
      return {
        bytes: fromHex(data.bytes as string),
        sha256: data.sha256,
        fileName: data.file_name,
        mimeType: data.mime_type,
        receiverScheme: data.receiver_scheme,
        receiverId: data.receiver_id,
      };
    },
    claim(id, owner, windowSeconds) {
      return rpc<ClaimResult>("claim_einvoice_dispatch_v1", {
        p_id: id,
        p_owner: owner,
        p_window_seconds: windowSeconds,
      });
    },
    async record(id, generation, owner, phase, externalId, detail, receipt) {
      const out = await rpc<{ recorded: boolean }>(
        "record_einvoice_outcome_v1",
        {
          p_id: id,
          p_generation: generation,
          p_owner: owner,
          p_phase: phase,
          p_external_id: externalId,
          p_detail: detail,
          p_receipt: receipt,
        },
      );
      return out.recorded;
    },
    async lookup(id, phase, externalId, receipt, verdict, queryError) {
      const out = await rpc<{ recorded: boolean }>(
        "record_einvoice_lookup_v1",
        {
          p_id: id,
          p_phase: phase,
          p_external_id: externalId,
          p_receipt: receipt,
          p_verdict: verdict,
          p_query_error: queryError,
        },
      );
      return out.recorded;
    },
    resolve(id, actor, outcome, reason, evidence, verdict) {
      return rpc("resolve_einvoice_manually_v1", {
        p_id: id,
        p_actor: actor,
        p_outcome: outcome,
        p_reason: reason,
        p_evidence: evidence,
        p_verdict: verdict,
      });
    },
  };
}
