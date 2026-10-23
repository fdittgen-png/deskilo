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
//
// #2393 — arguments are checked against the contract's input schema before
// the database (error.fields names each problem); a bearer is verified
// locally (signature, issuer, expiry) before Auth is asked; the
// protected-resource metadata names its scopes and resource; a rate limit
// is also an HTTP 429 with Retry-After; resources (a workspace's
// capabilities and booking periods, a place's picture) and one prompt sit
// beside the tools behind the same gates. The transport is stateless (no
// Mcp-Session-Id, no server-initiated request), which is why a sensitive
// write asks for a native confirmation in the app instead of elicitation.

import { Server } from "npm:@modelcontextprotocol/sdk@1.30.1/server/index.js";
import { WebStandardStreamableHTTPServerTransport } from "npm:@modelcontextprotocol/sdk@1.30.1/server/webStandardStreamableHttp.js";
import {
  CallToolRequestSchema,
  GetPromptRequestSchema,
  ListPromptsRequestSchema,
  ListResourcesRequestSchema,
  ListResourceTemplatesRequestSchema,
  ListToolsRequestSchema,
  ReadResourceRequestSchema,
} from "npm:@modelcontextprotocol/sdk@1.30.1/types.js";
import { createClient, SupabaseClient } from "npm:@supabase/supabase-js@2";
import { delegatedClient } from "../_shared/delegated.ts";
import { verifyLocally } from "../_shared/local_jwt.ts";
import { validateInput } from "../_shared/mcp_validate.ts";
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

/** #2393 — the SDK version these handlers and their tests were written against. */
export const SDK_VERSION = "1.30.1";

/** #2393 — the first protocol version whose clients read structuredContent. */
const STRUCTURED_SINCE = "2025-06-18";

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

/**
 * #2393 — every argument against the contract's input schema, before the
 * database is asked: field name -> problem; empty = valid.
 */
export function refusedFields(op: McpOperationId, args: Record<string, unknown>): Record<string, string> {
  return validateInput(MCP_INPUT_SCHEMAS[op], args, MCP_FORBIDDEN_INPUTS);
}

/** The envelope the facade would answer for invalid arguments, made here. */
function invalidArguments(op: McpOperationId, args: Record<string, unknown>, fields: Record<string, string>) {
  const str = (v: unknown) => (typeof v === "string" ? v : undefined);
  return {
    schema_version: 1,
    ...(str(args.request_id) ? { request_id: str(args.request_id) } : {}),
    operation: op,
    ...(str(args.workspace_id) ? { workspace_id: str(args.workspace_id) } : {}),
    status: "validation_error",
    error: { code: "invalid_arguments", fields },
  };
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

/**
 * #2393 — the answer's bytes are counted once: a client that reads
 * structuredContent (protocol 2025-06-18 or later) gets the summary as its
 * text; an older one also gets the envelope as text, and that copy counts.
 */
function boundedResult(envelope: Record<string, unknown>, summary: string, isError = false, structured = true) {
  const result = {
    isError,
    structuredContent: envelope,
    content: [
      { type: "text", text: summary },
      ...(structured ? [] : [{ type: "text", text: JSON.stringify(envelope) }]),
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
  "Never ask the person for passwords, API keys, tokens or other credentials (payment providers, e-invoicing): they enter those in the DesKilo app themselves, and DesKilo refuses them from an assistant.",
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
  secret_in_app_only:
    "Credentials (passwords, API keys, tokens, payment or e-invoicing keys) are never taken from an assistant. Nothing was done. The person enters them in the DesKilo app on the screen the setup status names for that step (its route).",
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

function toolResult(op: McpOperationId, raw: Record<string, unknown>, structured = true) {
  const projected = raw.data === undefined ? raw : { ...raw, data: projectData(op, raw.data) };
  // #2145 — a rate limit's wait is the one answer a refusal must carry.
  const retry = (raw.data as { retry_after?: unknown } | undefined)?.retry_after;
  const envelope = raw.status === "rate_limited" && typeof retry === "number"
    ? { ...projected, data: { ...(projected.data as Record<string, unknown> ?? {}), retry_after: retry } }
    : projected;
  const status = String(envelope.status ?? "");
  const isError = ["denied", "validation_error", "not_found", "conflict", "rate_limited"].includes(status);
  return boundedResult(envelope, summarize(envelope), isError, structured);
}

/**
 * get_place — the picture is drawn here, from the geometry the database
 * returns, and ONLY when the caller asked for it (include_image = true).
 * The geometry string never reaches the assistant as text; a picture that
 * would push the answer over its bound is left out rather than the answer.
 */
async function placeResult(raw: Record<string, unknown>, wantsImage: boolean, structured = true) {
  const data = (raw.data ?? {}) as Record<string, unknown>;
  const { render, ...described } = data;
  const result = toolResult("get_place", { ...raw, data: described }, structured) as {
    isError?: boolean;
    content: { type: string; text?: string; data?: string; mimeType?: string }[];
  };
  if (!wantsImage || result.isError || typeof render !== "string") return result;
  const picture = await placeImageBase64(render).catch(() => null);
  if (picture === null) return result;
  const withImage = { ...result, content: [...result.content, { type: "image", data: picture, mimeType: "image/png" }] };
  return new TextEncoder().encode(JSON.stringify(withImage)).length > LIMITS.outputBytes ? result : withImage;
}

/** #2393 — the resources a workspace offers, by the operation that reads them. */
const RESOURCES = [
  { path: "capabilities", operation: "get_capabilities", name: "What the assistant may do here", mimeType: "application/json" },
  { path: "booking-periods", operation: "get_capabilities", name: "Booking periods and opening hours", mimeType: "application/json" },
  { path: "setup-status", operation: "get_setup_status", name: "Where the space's setup stands", mimeType: "application/json" },
] as const;
const RESOURCE_URI = /^deskilo:\/\/workspace\/([0-9a-f-]{36})\/(capabilities|booking-periods|setup-status)$/i;
const PLACE_URI = /^deskilo:\/\/workspace\/([0-9a-f-]{36})\/place\/(seat|desk|office|level)\/([0-9a-f-]{36})\/image$/i;

/** #2393 — the prompts that chain the tools the instructions describe. */
export const PROMPTS = {
  book_usual_seat: {
    name: "book_usual_seat",
    title: "Book my usual seat",
    description: "Book the person's favourite place for a day and period (by default tomorrow morning).",
    arguments: [
      { name: "workspace_id", description: "The workspace (from deskilo_list_workspaces); asked when missing.", required: false },
      { name: "when", description: "The day and period in words, e.g. \"tomorrow morning\".", required: false },
    ],
  },
  set_up_my_space: {
    name: "set_up_my_space",
    title: "Set up my space",
    description: "Walk the person who configures a workspace through its setup: where it stands, the level each process should have, and every change confirmed in the DesKilo app.",
    arguments: [
      { name: "workspace_id", description: "The workspace (from deskilo_list_workspaces); asked when missing.", required: false },
    ],
  },
} as const;

/** The operations each prompt chains: it is offered only when the caller may call them all. */
const PROMPT_NEEDS: Record<keyof typeof PROMPTS, readonly string[]> = {
  book_usual_seat: ["get_capabilities", "list_my_favorites", "create_reservation"],
  set_up_my_space: ["get_setup_status", "preview_setup_levels", "apply_setup_levels"],
};

/** The setup guide in the order an owner meets it, worded for an assistant. */
function setupPromptText(args: Record<string, string | undefined>): string {
  const where = args.workspace_id ? `workspace ${args.workspace_id}` : "the workspace I name (deskilo_list_workspaces if unsure)";
  return [
    `Help me set up ${where}, one step at a time. Ask before every change and keep each answer short.`,
    "1. deskilo_get_setup_status: tell me which milestone comes next (bookable, money, invoice, live), how many of its required steps are ready, and next_step in plain words.",
    "2. Ask me about the space, one question at a time: do members owe money, do I issue invoices, am I VAT-registered, do I keep books, do I track purchases, are there several rooms or sites, a tablet at the door, a public page, online payments. Then propose a level for each process, or a quick start (essentiel, standard, complet; deskilo_list_setup_levels lists them), and say why.",
    "3. deskilo_preview_setup_levels with that choice: tell me what it switches on and off, and any gap to fix first.",
    "4. When I agree, deskilo_apply_setup_levels with the same choice and a new request_id. It answers requires_confirmation: I confirm in the DesKilo app, then you call it again with the same request_id and arguments.",
    "5. Read the status again. A step whose assistant is mark_done or set_aside, once I say it is done or can wait: deskilo_mark_setup_step, confirmed the same way. Any other open step: tell me which screen of the app to open (its route) and what it needs.",
    "Never ask me for passwords, API keys, tokens or other credentials (payment providers, e-invoicing): I enter them in the DesKilo app myself.",
  ].join("\n");
}

function promptText(args: Record<string, string | undefined>): string {
  const when = args.when?.trim() || "tomorrow morning";
  const where = args.workspace_id ? `in workspace ${args.workspace_id}` : "in the workspace the person names (deskilo_list_workspaces if unsure)";
  return [
    `Book my usual seat ${where} for ${when}.`,
    "1. deskilo_get_capabilities: read booking_periods and the time zone, and turn the day into a date there.",
    "2. deskilo_list_my_favorites: take the first favourite; if there is none, ask me which place.",
    "3. deskilo_create_reservation with that place's id, the date and the period, and a new request_id.",
    "4. Tell me the status in plain words: done, waiting for a validator, or to confirm in the DesKilo app.",
  ].join("\n");
}

function buildServer(db: SupabaseClient, installation: string, signal: AbortSignal, structured = true) {
  const server = new Server(
    { name: "deskilo", version: "1" },
    {
      capabilities: {
        tools: { listChanged: false },
        resources: { listChanged: false },
        prompts: { listChanged: false },
      },
      instructions: INSTRUCTIONS,
    },
  );

  /** The caller's own workspaces and operations (mcp_my_operations). */
  const mine = async () => {
    const { data, error } = await db.rpc("mcp_my_operations", { p_installation_id: installation })
      .abortSignal(signal);
    if (error) throw new Error("the operation list could not be read");
    return {
      operations: new Set<string>((data?.operations ?? []) as string[]),
      workspaces: (data?.workspaces ?? []) as { workspace_id?: string; name?: string; operations?: string[] }[],
    };
  };

  /** One completed read through the facade, as tools/call would make it. */
  const facadeRead = async (op: McpOperationId, workspace: string, args: Record<string, unknown>) => {
    const { data, error } = await db.rpc("mcp_execute_v1", {
      p_installation_id: installation,
      p_workspace_id: workspace,
      p_operation: op,
      p_arguments: args,
      p_request_id: null,
    }).abortSignal(signal);
    if (error || !sameProvenance(data, { operation: op, workspace_id: workspace, request_id: null })) {
      throw new Error("DesKilo could not deliver an answer to this request just now.");
    }
    const envelope = data as Record<string, unknown>;
    if (envelope.status !== "completed") {
      throw new Error(summarize(envelope));
    }
    return (envelope.data ?? {}) as Record<string, unknown>;
  };

  server.setRequestHandler(ListResourcesRequestSchema, async () => {
    const { workspaces } = await mine();
    const resources = [];
    for (const w of workspaces) {
      for (const r of RESOURCES) {
        if (!(w.operations ?? []).includes(r.operation) || typeof w.workspace_id !== "string") continue;
        resources.push({
          uri: `deskilo://workspace/${w.workspace_id}/${r.path}`,
          name: `${r.name}${typeof w.name === "string" ? ` (${w.name})` : ""}`,
          mimeType: r.mimeType,
        });
      }
    }
    return { resources };
  });

  server.setRequestHandler(ListResourceTemplatesRequestSchema, async () => {
    const { operations } = await mine();
    return {
      resourceTemplates: operations.has("get_place")
        ? [{
          uriTemplate: "deskilo://workspace/{workspace_id}/place/{kind}/{place_id}/image",
          name: "A place on its floor plan",
          description: "The floor plan with the place highlighted; kind is seat, desk, office or level.",
          mimeType: "image/png",
        }]
        : [],
    };
  });

  server.setRequestHandler(ReadResourceRequestSchema, async (request: { params: { uri: string } }) => {
    const uri = request.params.uri;
    const workspaceResource = RESOURCE_URI.exec(uri);
    if (workspaceResource) {
      const [, workspace, path] = workspaceResource;
      const data = projectData("get_capabilities", await facadeRead("get_capabilities", workspace, {})) as Record<string, unknown>;
      if (path === "setup-status") {
        const status = projectData("get_setup_status", await facadeRead("get_setup_status", workspace, {}));
        return { contents: [{ uri, mimeType: "application/json", text: JSON.stringify(status) }] };
      }
      const body = path === "booking-periods"
        ? { time_zone: data.time_zone, opening_hours: data.opening_hours, booking_periods: data.booking_periods }
        : data;
      return { contents: [{ uri, mimeType: "application/json", text: JSON.stringify(body) }] };
    }
    const place = PLACE_URI.exec(uri);
    if (place) {
      const [, workspace, kind, id] = place;
      const { render, ...described } = await facadeRead("get_place", workspace, { [`${kind}_id`]: id, include_image: true });
      const picture = typeof render === "string" ? await placeImageBase64(render).catch(() => null) : null;
      if (picture === null) {
        // No picture to draw: the place in words, as the tool answers it.
        return { contents: [{ uri, mimeType: "application/json", text: JSON.stringify(projectData("get_place", described)) }] };
      }
      return { contents: [{ uri, mimeType: "image/png", blob: picture }] };
    }
    throw new Error("Unknown resource. Use resources/list or the place image template.");
  });

  server.setRequestHandler(ListPromptsRequestSchema, async () => {
    const { operations } = await mine();
    return {
      prompts: (Object.keys(PROMPTS) as (keyof typeof PROMPTS)[])
        .filter((name) => PROMPT_NEEDS[name].every((o) => operations.has(o)))
        .map((name) => PROMPTS[name]),
    };
  });

  server.setRequestHandler(GetPromptRequestSchema, async (request: { params: { name: string; arguments?: Record<string, string> } }) => {
    const name = request.params.name as keyof typeof PROMPTS;
    if (!Object.hasOwn(PROMPTS, name)) throw new Error("Unknown prompt.");
    const { operations } = await mine();
    if (!PROMPT_NEEDS[name].every((o) => operations.has(o))) {
      throw new Error(name === "set_up_my_space"
        ? "This assistant may not set up this space: deskilo_get_capabilities says why."
        : "This assistant may not book here: deskilo_get_capabilities says why.");
    }
    const args = request.params.arguments ?? {};
    return {
      description: PROMPTS[name].description,
      messages: [{ role: "user", content: { type: "text", text: name === "set_up_my_space" ? setupPromptText(args) : promptText(args) } }],
    };
  });

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
    const fields = refusedFields(op, args);
    if (Object.keys(fields).length > 0) {
      const envelope = invalidArguments(op, args, fields);
      const named = Object.entries(fields).map(([k, v]) => `${k}: ${v}`).join(", ");
      return boundedResult(envelope, `Not done: ${named}. Use only the fields this tool's inputSchema lists, in their formats, then call again.`, true, structured);
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
        false,
        structured,
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
      return await placeResult(data as Record<string, unknown>, (args as { include_image?: unknown }).include_image === true, structured);
    }
    return toolResult(op, data as Record<string, unknown>, structured);
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

/**
 * #2393 — a tools/call the facade answered `rate_limited` is also an HTTP
 * 429 with Retry-After, for clients that back off at the transport.
 */
async function withRateLimit(response: Response): Promise<Response> {
  if (!(response.headers.get("content-type") ?? "").includes("application/json")) return response;
  const text = await response.text();
  const rebuilt = (status: number, extra: Record<string, string> = {}) => {
    const headers = new Headers(response.headers);
    for (const [k, v] of Object.entries(extra)) headers.set(k, v);
    return new Response(text, { status, headers });
  };
  try {
    const content = JSON.parse(text)?.result?.structuredContent;
    if (content?.status === "rate_limited") {
      const wait = typeof content.data?.retry_after === "number" ? Math.max(1, Math.ceil(content.data.retry_after)) : 60;
      return rebuilt(429, { "Retry-After": String(wait) });
    }
  } catch {
    // Not a JSON-RPC result: delivered as it is.
  }
  return rebuilt(response.status);
}

export async function handle(req: Request): Promise<Response> {
  const origin = req.headers.get("Origin");
  const headers = cors(origin);
  if (origin && !allowedOrigins().has(origin)) {
    return jsonResponse({ error: "origin_not_allowed" }, 403);
  }
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  const url = new URL(req.url);
  if (req.method === "GET" && (url.pathname.endsWith(METADATA_PATH) || url.pathname.includes(`${METADATA_PATH}/`))) {
    // RFC 9728: the resource, its authorization server, how the bearer is
    // sent, the scopes a client asks for, and a name to show. Served at
    // the endpoint's own well-known path and its path-suffixed form; the
    // host's root well-known path is not routed to a function.
    return jsonResponse({
      resource: resourceUrl(req),
      resource_name: "DesKilo",
      authorization_servers: [`${env("SUPABASE_URL")}/auth/v1`],
      bearer_methods_supported: ["header"],
      scopes_supported: ["openid", "email", "profile"],
    }, 200, headers);
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405, { ...headers, Allow: "POST, OPTIONS" });
  }
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
  const correlation = crypto.randomUUID();
  let body: unknown;
  try {
    const raw = await readBody(req, signal);
    if (raw === null) return jsonResponse({ error: "payload_too_large" }, 413, headers);
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
    // #2393 — a forged, unsigned, foreign or expired bearer costs no Auth call.
    if (await verifyLocally(authorization.slice(7), env("SUPABASE_URL"), signal) === "invalid") {
      return unauthorized(req, headers);
    }
    signal.throwIfAborted();
    const { data: user, error: userError } = await db.auth.getUser(authorization.slice(7));
    signal.throwIfAborted();
    if (userError || !user?.user) return unauthorized(req, headers);
    const structured = (req.headers.get("mcp-protocol-version") ?? STRUCTURED_SINCE) >= STRUCTURED_SINCE;
    const server = buildServer(db, installation, signal, structured);
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
    return await withRateLimit(response);
  } catch (e) {
    if (signal.aborted) return jsonResponse({ error: "request_timeout" }, 504, headers);
    // A correlation, never the arguments: the JSON-RPC id and this request's id.
    const rpcId = (body as { id?: unknown } | undefined)?.id;
    console.error("deskilo-mcp failed", e instanceof Error ? e.name : "error",
      JSON.stringify({ jsonrpc_id: typeof rpcId === "number" || typeof rpcId === "string" ? rpcId : null, request: correlation }));
    return jsonResponse({ jsonrpc: "2.0", id: null, error: { code: -32603, message: "Internal error" } }, 500, headers);
  } finally {
    clearTimeout(deadline);
  }
}

if (import.meta.main) Deno.serve(handle);
