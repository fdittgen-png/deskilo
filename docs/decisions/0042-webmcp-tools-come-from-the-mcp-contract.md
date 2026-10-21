# ADR 0042 — WebMCP tools come from the MCP contract

**Status:** accepted · **Date:** 2026-10-16 · **Refs:** #2504, #2500, #2596

## Context
The web app can offer tools to an in-browser agent through WebMCP
(`document.modelContext`). The external MCP endpoint already has one
contract, `contracts/mcp/operations.json`: names, descriptions, input
schemas, the mutation kind, the confirmation kind, the features and the
output ceiling. The MCP facade authorises a call from a delegated session
(`mcp_authorize` needs a `client_id` claim and a consent row); the app's own
session is native and cannot pass it. Making it pass would need a new SQL
path or a second session in the page.

## Decision
1. **The tool list is generated, not written.** `tool/build_mcp_contract.dart`
   also writes `lib/core/webmcp/webmcp_tools.g.dart` from the same model as
   `tools.json`. The existing contract test pins it; forbidden inputs
   (`mcpForbiddenInputs`) never appear in a schema.
2. **Execution goes through the app's own commands**, the code the Flutter UI
   calls, not through the facade and not through a bypass of it. No guard of
   `mcp_*` is weakened, no privileged RPC is called by a tool, and no SQL
   changes. The contract still decides what a tool is called, what it accepts,
   which features it needs and which fields may leave; a refusal equals the
   app UI's refusal for the same action.
3. **Consent is the person's, in the app.** A write that needs a decision
   opens the existing in-app confirmation and answers the agent
   `requires_confirmation` (the contract's status) until the person decides. A recording or a tool call
   is never a permission.
4. **Registered only while all hold:** a web build with a `modelContext`, a
   signed-in person, `WorkspaceFeature.webMcp` effective for the workspace and
   the per-device switch on. Anything else withdraws every tool. A change of
   account or workspace withdraws first; an answer that was started under the
   previous context is dropped, never returned under the new one.
5. **Non-web builds** get a stub that cannot register; nothing is offered on
   mobile or desktop.

## Consequences
The registry (`WebMcpRegistry`) is independent of how a tool runs: a runner is
supplied per tool kind, reads first, writes with the confirmation sheet after.
Facade parity stays a later option and would be a deliberate SQL change in the
migration lane.
