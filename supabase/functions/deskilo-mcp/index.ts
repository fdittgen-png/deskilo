// SPDX-License-Identifier: AGPL-3.0-or-later
//
// deskilo-mcp (#1616) — the Model Context Protocol endpoint, through the
// official SDK (Streamable HTTP, stateless: one POST, one answer, no
// session, no SSE held open while a human validates).
//
// Every data-bearing request is authenticated on its own: the bearer is a
// delegated OAuth token (`client_id` in its claims), verified by the
// target's Auth, and the Supabase client is built PER REQUEST with that
// token and the publishable key — never retained, never service_role.
// tools/list answers what THIS caller may call (mcp_my_operations);
// tools/call goes through the one facade, mcp_execute_v1, which re-checks
// every gate. The endpoint also checks the installation it serves against
// its own configuration (DESKILO_INSTALLATION_ID) and refuses to serve
// without one.
//
// #1631 — it also carries the installation epoch it was deployed for
// (DESKILO_MCP_EPOCH, a positive integer) on every database request, in
// `x-deskilo-mcp-epoch`. The database's pre-request guard refuses a
// request whose epoch is not its own, so after an operator resets MCP
// authority on a restored database (operator_reset_mcp_authority moves
// the epoch), this endpoint serves nothing until it is redeployed with the
// new one. Without a configured epoch it serves nothing at all.
//
// Only CORS preflight and the protected-resource metadata are anonymous.

import { Server } from "npm:@modelcontextprotocol/sdk@1.30.1/server/index.js";
import { WebStandardStreamableHTTPServerTransport } from "npm:@modelcontextprotocol/sdk@1.30.1/server/webStandardStreamableHttp.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "npm:@modelcontextprotocol/sdk@1.30.1/types.js";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { delegatedClient } from "../_shared/delegated.ts";
import {
  MCP_FORBIDDEN_INPUTS,
  MCP_INPUT_SCHEMAS,
  MCP_OPERATIONS,
  MCP_OUTPUT_ALLOWED,
  MCP_OUTPUT_OPTIONAL,
  MCP_TOOL_PREFIX,
  McpOperationId,
} from "../_shared/mcp_contract.ts";

/** #1616 — named initial limits. */
export const LIMITS = { inputBytes: 64 * 1024, outputBytes: 256 * 1024, deadlineMs: 15_000 };

const METADATA_PATH = "/.well-known/oauth-protected-resource";

const env = (name: string) => Deno.env.get(name) ?? "";

function allowedOrigins(): Set<string> {
  return new Set(env("DESKILO_MCP_ALLOWED_ORIGINS").split(",").map((o) => o.trim()).filter(Boolean));
}

function cors(origin: string | null): Record<string, string> {
  return origin && allowedOrigins().has(origin)
    ? {
      "Access-Control-Allow-Origin": origin,
      "Access-Control-Allow-Headers": "authorization, content-type, mcp-protocol-version",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Expose-Headers": "WWW-Authenticate",
      Vary: "Origin",
    }
    : {};
}

function resourceUrl(req: Request): string {
  // The canonical resource comes from configuration, never from Host.
  return env("DESKILO_MCP_RESOURCE") || `${env("SUPABASE_URL")}/functions/v1/deskilo-mcp`;
}

function jsonResponse(body: unknown, status: number, headers: Record<string, string> = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
}

function unauthorized(req: Request, headers: Record<string, string>) {
  return jsonResponse({ error: "unauthorized" }, 401, {
    ...headers,
    "WWW-Authenticate": `Bearer resource_metadata="${resourceUrl(req)}${METADATA_PATH}"`,
  });
}

/** Tool name → operation id, only for operations the contract hands to us. */
function operationOf(tool: string): McpOperationId | null {
  if (!tool.startsWith(MCP_TOOL_PREFIX)) return null;
  const id = tool.slice(MCP_TOOL_PREFIX.length) as McpOperationId;
  return MCP_OPERATIONS[id]?.handler ? id : null;
}

/** Refuses what no operation may carry, before the database is asked. */
export function refusedInput(op: McpOperationId, args: Record<string, unknown>): string | null {
  const schema = MCP_INPUT_SCHEMAS[op] as { properties: Record<string, unknown> };
  for (const key of Object.keys(args)) {
    if (MCP_FORBIDDEN_INPUTS.includes(key)) return `forbidden field ${key}`;
    if (!(key in schema.properties)) return `unknown field ${key}`;
  }
  return null;
}

/**
 * #1644 — the database already projects every answer; this repeats the
 * same allow-list defensively, recursively, so a field the contract does
 * not classify as operational never reaches the assistant from here.
 * #1645 — an optional display field the contract names for this operation
 * is left as the database decided: it is only there when the installation
 * maximum, the workspace policy and this caller's consent all allowed it,
 * which this adapter cannot see. Anything else is still dropped.
 */
export function projectData(op: McpOperationId, value: unknown): unknown {
  const allowed = new Set([...(MCP_OUTPUT_ALLOWED[op] ?? []), ...(MCP_OUTPUT_OPTIONAL[op] ?? [])]);
  const walk = (v: unknown): unknown => {
    if (Array.isArray(v)) return v.map(walk);
    if (v === null || typeof v !== "object") return v;
    const out: Record<string, unknown> = {};
    for (const [k, inner] of Object.entries(v as Record<string, unknown>)) {
      if (allowed.has(k)) out[k] = walk(inner);
    }
    return out;
  };
  return walk(value);
}

function boundedResult(envelope: Record<string, unknown>, summary: string, isError = false) {
  const result = {
    isError,
    structuredContent: envelope,
    content: [
      { type: "text", text: summary },
      { type: "text", text: JSON.stringify(envelope) },
    ],
  };
  if (new TextEncoder().encode(JSON.stringify(result)).length > LIMITS.outputBytes) {
    return { isError: true, content: [{ type: "text", text: "the answer is too large" }] };
  }
  return result;
}

function toolResult(op: McpOperationId, raw: Record<string, unknown>) {
  const envelope = raw.data === undefined ? raw : { ...raw, data: projectData(op, raw.data) };
  const status = String(envelope.status ?? "");
  const isError = ["denied", "validation_error", "not_found", "conflict", "rate_limited"].includes(status);
  const summary = status === "pending_validation"
    ? "Submitted: waiting for the workspace's validators. Not completed yet."
    : status === "requires_confirmation"
    ? "Needs confirmation in the Deskilo app before anything happens."
    : status === "completed"
    ? "Done."
    : `Not done: ${(envelope.error as { code?: string } | undefined)?.code ?? status}.`;
  return boundedResult(envelope, summary, isError);
}

function buildServer(db: SupabaseClient, installation: string, signal: AbortSignal) {
  const server = new Server(
    { name: "deskilo", version: "1" },
    { capabilities: { tools: { listChanged: false } } },
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => {
    const { data, error } = await db.rpc("mcp_my_operations", { p_installation_id: installation })
      .abortSignal(signal);
    if (error) throw new Error("the operation list could not be read");
    const allowed = new Set<string>((data?.operations ?? []) as string[]);
    const tools = [];
    for (const [id, op] of Object.entries(MCP_OPERATIONS)) {
      if (!op.handler) continue;
      if (id !== "list_workspaces" && !allowed.has(id)) continue;
      if (id === "list_workspaces" && allowed.size === 0) continue;
      tools.push({
        name: `${MCP_TOOL_PREFIX}${id}`,
        description: `Deskilo: ${id.replaceAll("_", " ")}`,
        inputSchema: MCP_INPUT_SCHEMAS[id as McpOperationId],
        annotations: { readOnlyHint: op.mutation === "read", idempotentHint: op.idempotency === "request_id" },
      });
    }
    return { tools };
  });

  server.setRequestHandler(CallToolRequestSchema, async (request: { params: { name: string; arguments?: Record<string, unknown> } }) => {
    const op = operationOf(request.params.name);
    if (!op) {
      return { isError: true, content: [{ type: "text", text: "unknown tool" }] };
    }
    const args = (request.params.arguments ?? {}) as Record<string, unknown>;
    const refused = refusedInput(op, args);
    if (refused) return { isError: true, content: [{ type: "text", text: refused }] };
    if (op === "list_workspaces") {
      const limit = args.limit ?? 100;
      if (typeof limit !== "number" || !Number.isInteger(limit) || limit < 1 || limit > 100) {
        return { isError: true, content: [{ type: "text", text: "invalid limit" }] };
      }
      const { data, error } = await db.rpc("mcp_my_operations", { p_installation_id: installation })
        .abortSignal(signal);
      if (error) return { isError: true, content: [{ type: "text", text: "unavailable" }] };
      const workspaces = (data?.workspaces ?? []) as unknown[];
      const visible = workspaces.slice(0, limit);
      return boundedResult(
        { workspaces: visible, has_more: workspaces.length > limit },
        `${visible.length} workspace(s) available.`,
      );
    }
    const { workspace_id, request_id, ...rest } = args as { workspace_id?: string; request_id?: string };
    const { data, error } = await db.rpc("mcp_execute_v1", {
      p_installation_id: installation,
      p_workspace_id: workspace_id ?? null,
      p_operation: op,
      p_arguments: rest,
      p_request_id: request_id ?? null,
    }).abortSignal(signal);
    if (error) {
      // Never the database's own words: they can name tables and values.
      return { isError: true, content: [{ type: "text", text: "the request could not be processed" }] };
    }
    return toolResult(op, data as Record<string, unknown>);
  });

  return server;
}

/** Stop oversized or stalled bodies before buffering an unbounded request. */
async function readBody(req: Request, signal: AbortSignal): Promise<string | null> {
  const reader = req.body?.getReader();
  if (!reader) return "";
  const cancel = () => { void reader.cancel().catch(() => {}); };
  signal.addEventListener("abort", cancel, { once: true });
  try {
    signal.throwIfAborted();
    const chunks: Uint8Array[] = [];
    let size = 0;
    while (true) {
      const { value, done } = await reader.read();
      signal.throwIfAborted();
      if (done) break;
      size += value.byteLength;
      if (size > LIMITS.inputBytes) {
        cancel();
        return null;
      }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return new TextDecoder().decode(bytes);
  } finally {
    signal.removeEventListener("abort", cancel);
    reader.releaseLock();
  }
}

export async function handle(req: Request): Promise<Response> {
  const origin = req.headers.get("Origin");
  const headers = cors(origin);
  if (origin && !allowedOrigins().has(origin)) {
    return jsonResponse({ error: "origin_not_allowed" }, 403);
  }
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  const url = new URL(req.url);
  if (req.method === "GET" && url.pathname.endsWith(METADATA_PATH)) {
    return jsonResponse({
      resource: resourceUrl(req),
      authorization_servers: [`${env("SUPABASE_URL")}/auth/v1`],
      bearer_methods_supported: ["header"],
    }, 200, headers);
  }
  if (req.method !== "POST") return jsonResponse({ error: "method_not_allowed" }, 405, headers);
  if (!(req.headers.get("content-type") ?? "").includes("application/json")) {
    return jsonResponse({ error: "unsupported_media_type" }, 415, headers);
  }
  const installation = env("DESKILO_INSTALLATION_ID");
  const epoch = env("DESKILO_MCP_EPOCH");
  if (!/^[0-9a-f-]{36}$/.test(installation) || !/^[1-9][0-9]{0,8}$/.test(epoch)) {
    return jsonResponse({ error: "not_configured" }, 503, headers);
  }
  const authorization = req.headers.get("Authorization") ?? "";
  if (!authorization.startsWith("Bearer ") || delegatedClient(authorization) === null) {
    return unauthorized(req, headers);
  }
  const controller = new AbortController();
  const signal = AbortSignal.any([controller.signal, req.signal]);
  const deadline = setTimeout(() => controller.abort(), LIMITS.deadlineMs);
  try {
    const raw = await readBody(req, signal);
    if (raw === null) return jsonResponse({ error: "payload_too_large" }, 413, headers);
    let body: unknown;
    try {
      body = JSON.parse(raw);
    } catch {
      return jsonResponse({ jsonrpc: "2.0", id: null, error: { code: -32700, message: "Parse error" } }, 400, headers);
    }

    // Per request: this caller's token, with one deadline for Auth and RPCs.
    const db = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
      global: {
        headers: { Authorization: authorization, "x-deskilo-mcp-epoch": epoch },
        fetch: (input, init) => fetch(input, {
          ...init,
          signal: init?.signal ? AbortSignal.any([signal, init.signal]) : signal,
        }),
      },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: user, error: userError } = await db.auth.getUser(authorization.slice(7));
    signal.throwIfAborted();
    if (userError || !user?.user) return unauthorized(req, headers);
    const server = buildServer(db, installation, signal);
    const transport = new WebStandardStreamableHTTPServerTransport({
      sessionIdGenerator: undefined,
      enableJsonResponse: true,
    });
    await server.connect(transport);
    const response = await transport.handleRequest(
      new Request(req.url, { method: "POST", headers: req.headers, body: JSON.stringify(body) }),
    );
    signal.throwIfAborted();
    for (const [k, v] of Object.entries(headers)) response.headers.set(k, v);
    return response;
  } catch (e) {
    if (signal.aborted) return jsonResponse({ error: "request_timeout" }, 504, headers);
    console.error("deskilo-mcp failed", e instanceof Error ? e.name : "error");
    return jsonResponse({ jsonrpc: "2.0", id: null, error: { code: -32603, message: "Internal error" } }, 500, headers);
  } finally {
    clearTimeout(deadline);
  }
}

if (import.meta.main) Deno.serve(handle);
