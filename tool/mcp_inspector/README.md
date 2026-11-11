# MCP contract probe

This independent development package pins MCP Inspector 2.14.0 and Node 24.22.1.
It reads the product endpoint's `tools/list`; it never calls a business tool.
The development Dart server in the root MCP configuration is a different server.

From the repository root, with the pinned Node on PATH:

```bash
npm ci --prefix tool/mcp_inspector
npm test --prefix tool/mcp_inspector
npm run check --prefix tool/mcp_inspector -- /absolute/path/capture.json
```

The checker accepts `{ "result": { "tools": [...] } }`, including a JSON-RPC
response, and compares complete definitions with `contracts/mcp/generated/tools.json`.
Unknown or duplicate names, altered definitions, errors and remaining pagination
fail. A nonempty list must contain `deskilo_list_workspaces`.

Discovery is caller-specific: policy, consent, membership and permission determine
its subset. An empty list is valid. Subset conformity does not prove completeness
or authorization. An optional second file supplies an independent array of exact
expected names for a prepared persona; do not derive it from the response tested.

```bash
npm run check --prefix tool/mcp_inspector -- /absolute/path/capture.json /absolute/path/expected-names.json
```

For live capture, supply `DESKILO_MCP_URL` and `DESKILO_MCP_BEARER` through the local
environment or secret manager, never a committed file or command-line argument.
Use the actual product endpoint and a delegated OAuth bearer; a native session
token is refused. The server needs its installation and epoch configuration.

```bash
npm run capture --prefix tool/mcp_inspector
npm run capture --prefix tool/mcp_inspector -- /absolute/path/expected-names.json
```

Only HTTPS or loopback HTTP is accepted; redirects, URL credentials, queries and
fragments are refused. The pinned CLI uses legacy negotiation, stored auth only
and strict schema validation. It opens no browser or interactive authorization.
An outer 30-second timeout kills the CLI directly. Native nonzero exits are
preserved; the outer timeout exits 124. Raw client diagnostics are withheld because
they may contain secrets. Authentication, network and contract failures remain failures.

A successful run writes only checked definitions to
`.dart_tool/mcp_inspector/tools-list.json` in this checkout. A new capture removes
the previous file before attempting the request. Each run uses a private temporary
configuration and isolated memory-only authentication storage, removed on exit.
The saved JSON is an offline comparison input, not an attestation of live access.

Tests exercise the actual pinned client against a local HTTP fixture plus negative
contract cases, secret handling, timeout cleanup and recovery. That fixture is not
a Deskilo deployment. Without an explicit endpoint and delegated bearer, live
product verification is **NOT RUN**. Existing Flutter, Deno and SQL gates remain
authoritative for product behavior and workspace isolation.

References: [Inspector CLI](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/cli)
and [configuration](https://modelcontextprotocol.io/docs/2026-07-28/tools/inspector/configuration).
