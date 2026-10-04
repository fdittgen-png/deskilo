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
// #1632 — an answer must name the operation, workspace and request id of
// the call it answers; a relabelled or crossed envelope is refused, never
// delivered under this call's JSON-RPC id (sameProvenance). The JSON-RPC
// id correlates transport messages; the request UUID is the intent.
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
import { placeImageBase64 } from "../_shared/place_image.ts";
import {
  MCP_FORBIDDEN_INPUTS,
  MCP_INPUT_SCHEMAS,
  MCP_OPERATIONS,
  MCP_OUTPUT_ALLOWED,
  MCP_OUTPUT_OPTIONAL,
  MCP_TOOL_PREFIX,
  MCP_TOOLS,
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

/**
 * #1632 — the facade's envelope names the operation, workspace and request
 * id it answers (mcp_envelope). An answer naming anything else is not the
 * answer to this call — a relabelled or crossed reply — and is refused
 * rather than delivered under this call's JSON-RPC id. The JSON-RPC id is
 * the transport's correlation; the request UUID is the business intent's.
 */
export function sameProvenance(
  envelope: unknown,
  asked: { operation: string; workspace_id: unknown; request_id: unknown },
): boolean {
  if (envelope === null || typeof envelope !== "object" || Array.isArray(envelope)) return false;
  const e = envelope as Record<string, unknown>;
  const norm = (v: unknown) => (typeof v === "string" ? v.toLowerCase() : v ?? null);
  return norm(e.operation) === asked.operation &&
    norm(e.workspace_id) === norm(asked.workspace_id) &&
    norm(e.request_id) === norm(asked.request_id);
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

/**
 * The server's instructions: how a model is expected to chain the tools,
 * once, instead of in every description.
 */
export const INSTRUCTIONS = [
  "DesKilo is a coworking app: bookings of seats, desks, offices and levels, statements and invoices, and requests that the workspace's validators decide.",
  "Start with deskilo_list_workspaces: every other tool needs one of its workspace_id values. If the person has several workspaces, ask which one unless the request makes it obvious.",
  "Times are ISO 8601 with an explicit offset (e.g. 2026-10-05T09:00:00+02:00); interpret 'tomorrow morning' in the workspace's time zone.",
  "To book a whole morning, afternoon or working day, call deskilo_get_capabilities once for booking_periods (morning, afternoon, full_day, each with its exact local from/to), then pass date (YYYY-MM-DD) and period to deskilo_create_reservation instead of computing times: the workspace applies its own hours exactly.",
  "A person's favourite places: deskilo_list_my_favorites lists them with their ids; to book one, pass its id to deskilo_create_reservation (seat_id, desk_id, office_id or level_id by its kind) with date and period. Mark or unmark a favourite with deskilo_set_favorite and rate a place 0-5 stars with deskilo_rate_place only when the person asks.",
  "Only when the person explicitly asks to SEE a place (image, picture, plan, map), call deskilo_get_place with include_image true; otherwise describe it in words.",
  "Amounts are integer minor units (cents) with a separate currency; divide by 100 to show them.",
  "For every write, generate a new random UUID as request_id. Reuse the same request_id with the same arguments only to retry that same intent: it never acts twice.",
  "Read the status of every answer: completed = done; pending_validation = submitted, NOT done yet, a validator decides; requires_confirmation = nothing happened yet, the person must confirm in the DesKilo app, then call the same tool again with the same request_id and arguments; anything else = not done, and the first text says why and what to do next.",
  "When a tool is missing or refused, deskilo_get_capabilities says what this assistant may do in that workspace.",
].join("\n");

/** The text of a workspace list: names and ids, so the person can be asked which one. */
export function workspacesSummary(list: { workspace_id?: unknown; name?: unknown }[], more: boolean): string {
  if (list.length === 0) {
    return "No workspace is available to this assistant. In the DesKilo app, Settings → Assistants shows why (approval, the workspace owner's settings, or this connection's workspaces).";
  }
  const names = list.map((w) => `${typeof w.name === "string" ? w.name : "workspace"} (${w.workspace_id})`);
  return `${list.length} workspace(s) available: ${names.join("; ")}.${more ? " More exist: raise limit." : ""}`;
}

/** #2145 — what each refusal means for the person, and what they can do. */
export const REFUSAL_TEXT: Record<string, string> = {
  not_eligible:
    "This person is not approved to use an assistant on this DesKilo database (or the approval expired). They can ask for approval in the DesKilo app: Settings → Assistants → Ask for approval.",
  no_identity:
    "This person's account is not linked to a verified identity on this DesKilo database. They should sign in to the DesKilo app once with the same account, then try again.",
  no_google_identity:
    "This assistant connection was made with a Google account that is not linked to this person's DesKilo account. Reconnect the assistant with the account used in the DesKilo app.",
  no_connection:
    "This assistant is not connected for this person any more (it was disconnected or the approval changed). Reconnect it from the assistant, then try again.",
  no_consent:
    "This person has not allowed this assistant in that workspace. They can allow it by reconnecting the assistant and ticking the workspace.",
  not_exposed:
    "That workspace's owner has not made this action available to assistants. Use the DesKilo app for it, or ask the workspace owner.",
  not_a_member:
    "This person is not an active member of that workspace. Use deskilo_list_workspaces to pick one of their workspaces.",
  forbidden:
    "This person's role in that workspace does not allow this action. Ask a workspace administrator, or use the DesKilo app.",
  target_ceiling:
    "In that workspace this assistant may only act on the person's own items, not on the whole workspace.",
  runtime_disabled:
    "Assistants are switched off on this DesKilo database right now. Use the DesKilo app; the administrator can switch them back on.",
  wrong_installation:
    "This assistant is connected to a different DesKilo database than this endpoint serves. Reconnect it to the right one.",
  no_client:
    "This assistant is not registered or not allowed on this DesKilo database. Ask the database administrator.",
  unknown_operation: "This action does not exist in DesKilo. Use one of the listed tools.",
  invalid_arguments:
    "Some arguments are invalid (see error.fields). Fix them and call again with a new request_id.",
  window: "The time window is invalid: the end must be after the start, and at most 31 days later.",
  not_found:
    "Nothing found with that id for this person in that workspace. List the items first (e.g. deskilo_list_my_reservations) and use an id from the answer.",
  stale:
    "The item changed since it was read; nothing was done. Read data.state_digest and the current state, confirm with the person, then try again.",
  request_id_reused:
    "This request_id was already used for a different action. Generate a new request_id for a new intent.",
  confirmation_stale:
    "The confirmation no longer matches (it expired, was declined, or the item changed). Nothing was done. Call the tool again with a NEW request_id to ask for a new confirmation.",
};

function appLink(confirmationId: unknown): string | null {
  const base = env("DESKILO_APP_URL").replace(/\/+$/, "");
  if (!base || typeof confirmationId !== "string" || !/^[0-9a-f-]{36}$/i.test(confirmationId)) return null;
  // The web app routes by fragment; the native app shows the same screen.
  return `${base}/#/mcp/confirm/${confirmationId}`;
}

/** The first text of every answer: the outcome in plain words, and the next step. */
export function summarize(envelope: Record<string, unknown>): string {
  const status = String(envelope.status ?? "");
  const data = (envelope.data ?? {}) as Record<string, unknown>;
  const code = (envelope.error as { code?: string } | undefined)?.code;
  switch (status) {
    case "completed":
      return "Done.";
    case "pending_validation":
      return "Submitted, NOT completed yet: the workspace's validators must approve it first. Tell the person; the result appears in the DesKilo app once decided (deskilo_list_pending_validations shows it meanwhile).";
    case "requires_confirmation": {
      const link = appLink(data.confirmation_id);
      const until = typeof data.expires_at === "string" ? ` before ${data.expires_at}` : "";
      return `Nothing happened yet: the person must confirm this exact action in the DesKilo app${until}` +
        (link ? ` (open ${link})` : " (signed in as themselves)") +
        ". Once they confirmed, call this same tool again with the same request_id and the same arguments to carry it out.";
    }
    case "rate_limited": {
      const wait = typeof data.retry_after === "number" ? ` Wait ${data.retry_after} seconds, then retry.` : " Wait a minute, then retry.";
      return `Not done: too many requests from this assistant right now.${wait}`;
    }
    case "conflict":
      if (code === "refused") {
        const reason = typeof data.reason === "string" && data.reason ? data.reason : "the workspace's rules refused it";
        return `Not done: ${reason}. Tell the person; the same rules apply in the DesKilo app.`;
      }
      return `Not done: ${REFUSAL_TEXT[code ?? ""] ?? "it conflicts with the current state. Read it again and retry."}`;
    default:
      return `Not done: ${REFUSAL_TEXT[code ?? ""] ?? `the request was refused (${code ?? status}).`}`;
  }
}

function toolResult(op: McpOperationId, raw: Record<string, unknown>) {
  const projected = raw.data === undefined ? raw : { ...raw, data: projectData(op, raw.data) };
  // #2145 — a rate limit's wait is the one answer a refusal must carry.
  const retry = (raw.data as { retry_after?: unknown } | undefined)?.retry_after;
  const envelope = raw.status === "rate_limited" && typeof retry === "number"
    ? { ...projected, data: { ...(projected.data as Record<string, unknown> ?? {}), retry_after: retry } }
    : projected;
  const status = String(envelope.status ?? "");
  const isError = ["denied", "validation_error", "not_found", "conflict", "rate_limited"].includes(status);
  return boundedResult(envelope, summarize(envelope), isError);
}

/**
 * get_place — the picture is drawn here, from the geometry the database
 * returns, and ONLY when the caller asked for it (include_image = true).
 * The geometry string never reaches the assistant as text; a picture that
 * would push the answer over its bound is left out rather than the answer.
 */
async function placeResult(raw: Record<string, unknown>, wantsImage: boolean) {
  const data = (raw.data ?? {}) as Record<string, unknown>;
  const { render, ...described } = data;
  const result = toolResult("get_place", { ...raw, data: described }) as {
    isError?: boolean;
    content: { type: string; text?: string; data?: string; mimeType?: string }[];
  };
  if (!wantsImage || result.isError || typeof render !== "string") return result;
  const picture = await placeImageBase64(render).catch(() => null);
  if (picture === null) return result;
  const withImage = { ...result, content: [...result.content, { type: "image", data: picture, mimeType: "image/png" }] };
  return new TextEncoder().encode(JSON.stringify(withImage)).length > LIMITS.outputBytes ? result : withImage;
}

function buildServer(db: SupabaseClient, installation: string, signal: AbortSignal) {
  const server = new Server(
    { name: "deskilo", version: "1" },
    { capabilities: { tools: { listChanged: false } }, instructions: INSTRUCTIONS },
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
      // #2145 — the contract's own title, description, schemas and annotations.
      tools.push(MCP_TOOLS[id as McpOperationId]);
    }
    return { tools };
  });

  server.setRequestHandler(CallToolRequestSchema, async (request: { params: { name: string; arguments?: Record<string, unknown> } }) => {
    const op = operationOf(request.params.name);
    if (!op) {
      return { isError: true, content: [{ type: "text", text: "Not done: unknown tool. Use one of the tools tools/list returns." }] };
    }
    const args = (request.params.arguments ?? {}) as Record<string, unknown>;
    const refused = refusedInput(op, args);
    if (refused) {
      return { isError: true, content: [{ type: "text", text: `Not done: ${refused}. Use only the fields this tool's inputSchema lists.` }] };
    }
    if (op === "list_workspaces") {
      const limit = args.limit ?? 100;
      if (typeof limit !== "number" || !Number.isInteger(limit) || limit < 1 || limit > 100) {
        return { isError: true, content: [{ type: "text", text: "Not done: limit must be an integer from 1 to 100." }] };
      }
      const { data, error } = await db.rpc("mcp_my_operations", { p_installation_id: installation })
        .abortSignal(signal);
      if (error) {
        return { isError: true, content: [{ type: "text", text: "DesKilo could not list the workspaces just now. Try again in a moment." }] };
      }
      const workspaces = (data?.workspaces ?? []) as { workspace_id?: unknown; name?: unknown }[];
      const visible = workspaces.slice(0, limit);
      return boundedResult(
        { workspaces: visible, has_more: workspaces.length > limit },
        workspacesSummary(visible, workspaces.length > limit),
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
    if (error || !sameProvenance(data, { operation: op, workspace_id, request_id })) {
      // Never the database's own words: they can name tables and values.
      return { isError: true, content: [{ type: "text", text: "DesKilo could not deliver an answer to this request just now. Call again with the same request_id and arguments to learn the outcome: it never acts twice." }] };
    }
    if (op === "get_place") {
      return await placeResult(data as Record<string, unknown>, (args as { include_image?: unknown }).include_image === true);
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
