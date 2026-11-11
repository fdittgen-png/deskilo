// SPDX-License-Identifier: AGPL-3.0-or-later
import { execFile } from 'node:child_process';
import { mkdir, mkdtemp, readFile, realpath, rename, rm, writeFile } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isDeepStrictEqual, promisify } from 'node:util';

const here = dirname(fileURLToPath(import.meta.url));
const root = await realpath(join(here, '../..'));
const state = join(root, '.dart_tool/mcp_inspector');
const catalogue = JSON.parse(await readFile(join(root, 'contracts/mcp/generated/tools.json'), 'utf8'));
const definitions = new Map(catalogue.tools.map(tool => [tool.name, tool]));
class Failure extends Error {
  constructor(message, code = 1) { super(message); this.exitCode = code; }
}
function requireThat(condition, message) { if (!condition) throw new Failure(message); }
async function jsonFile(path) {
  try { return JSON.parse(await readFile(path, 'utf8')); }
  catch { throw new Failure('Cannot read a valid JSON input file.'); }
}

export function checkCapture(capture, expected) {
  requireThat(capture && typeof capture === 'object' && !Array.isArray(capture), 'Invalid capture envelope.');
  requireThat(!Object.hasOwn(capture, 'error') && !capture.result?.isError, 'Capture contains an error.');
  requireThat(!Object.hasOwn(capture, 'jsonrpc') || capture.jsonrpc === '2.0', 'Invalid JSON-RPC version.');
  const result = capture.result;
  requireThat(result && Array.isArray(result.tools), 'Expected result.tools array.');
  requireThat(result.nextCursor == null, 'Capture is incomplete: pagination remains.');
  const seen = new Set();
  for (const tool of result.tools) {
    requireThat(tool && definitions.has(tool.name), 'Capture contains an unknown tool.');
    requireThat(!seen.has(tool.name), 'Capture contains a duplicate tool.');
    seen.add(tool.name);
    requireThat(isDeepStrictEqual(tool, definitions.get(tool.name)), `Definition differs: ${tool.name}.`);
  }
  requireThat(seen.size === 0 || seen.has('deskilo_list_workspaces'), 'Nonempty list lacks workspace discovery.');
  if (expected !== undefined) {
    requireThat(Array.isArray(expected) && expected.every(name => definitions.has(name)) &&
      new Set(expected).size === expected.length, 'Expected names must be unique canonical names.');
    requireThat(isDeepStrictEqual([...seen].sort(), [...expected].sort()), 'Tool names differ from the supplied expectation.');
  }
  return { mode: expected === undefined ? 'subset' : 'exact', tools: seen.size,
    completeness: expected === undefined ? 'NOT EVALUATED' : 'matched supplied expectation',
    authorization: 'NOT DEMONSTRATED: discovery does not authorize calls' };
}

export function endpoint(value) {
  let url;
  try { url = new URL(value); } catch { throw new Failure('Set DESKILO_MCP_URL to a valid endpoint.'); }
  const local = ['localhost', '127.0.0.1', '[::1]'].includes(url.hostname);
  requireThat(url.protocol === 'https:' || (url.protocol === 'http:' && local), 'Endpoint requires HTTPS or loopback HTTP.');
  requireThat(!url.username && !url.password && !url.search && !url.hash, 'Endpoint cannot contain credentials, query or fragment.');
  return url.href;
}

export async function captureLive({ env = process.env, directory = state, expected, expectedPath,
  timeout = 30000, run = promisify(execFile) } = {}) {
  await mkdir(directory, { recursive: true, mode: 0o700 });
  requireThat(await realpath(directory) === resolve(directory), 'State directory cannot contain symbolic links.');
  const output = join(directory, 'tools-list.json');
  await rm(output, { force: true });
  if (expectedPath) expected = await jsonFile(expectedPath);
  const url = endpoint(env.DESKILO_MCP_URL);
  const token = env.DESKILO_MCP_BEARER;
  requireThat(typeof token === 'string' && /^\S+$/.test(token), 'Set DESKILO_MCP_BEARER to the bare delegated token.');
  const temporary = await mkdtemp(join(directory, 'run-'));
  try {
    const config = join(temporary, 'config.json');
    await writeFile(config, JSON.stringify({ mcpServers: { deskilo: {
      type: 'streamable-http', url, requestInit: { redirect: 'error' }, headers: { Authorization: `Bearer ${token}` },
    } } }), { mode: 0o600, flag: 'wx' });
    const isolated = Object.fromEntries(Object.entries(env).filter(([key]) => !key.startsWith('MCP_') && !key.startsWith('DESKILO_MCP_')));
    Object.assign(isolated, { MCP_STORAGE_DIR: temporary,
      MCP_CLIENT_CONFIG_PATH: join(temporary, 'client.json'), MCP_INSPECTOR_OAUTH_STATE_PATH: join(temporary, 'oauth.json'),
      MCP_INSPECTOR_SECRET_STORE: 'memory', MCP_INSPECTOR_PERSIST_TOKENS: 'none', MCP_AUTO_OPEN_ENABLED: 'false' });
    let stdout;
    try {
      // The pinned CLI entry avoids a launcher child surviving the timeout.
      ({ stdout } = await run(process.execPath, [join(here, 'node_modules/@modelcontextprotocol/inspector/clients/cli/build/index.js'),
        '--config', config, '--server', 'deskilo', '--stored-auth-only', '--protocol-era', 'legacy',
        '--method', 'tools/list', '--strict', '--format', 'json'],
      { cwd: root, env: isolated, encoding: 'utf8', timeout, killSignal: 'SIGKILL', maxBuffer: 2 * 1024 * 1024 }));
    } catch (error) {
      // Upstream diagnostics can contain headers, URLs or credentials.
      const code = error.killed ? 124 : typeof error.code === 'number' ? error.code : 1;
      throw new Failure(`Capture failed (exit ${code}); diagnostics withheld.`, code);
    }
    let response;
    try { response = JSON.parse(stdout); } catch { throw new Failure('Capture did not return JSON.'); }
    const report = checkCapture(response, expected);
    // Persist only reviewed definitions, never arbitrary upstream metadata.
    const pending = join(temporary, 'tools-list.json');
    await writeFile(pending, JSON.stringify({ result: { tools: response.result.tools } }, null, 2) + '\n', { mode: 0o600 });
    await rename(pending, output);
    return { ...report, capture: output };
  } finally { await rm(temporary, { recursive: true, force: true }); }
}

if (process.argv[1] && await realpath(process.argv[1]) === await realpath(fileURLToPath(import.meta.url))) {
  try {
    const [mode, first, second, ...rest] = process.argv.slice(2);
    requireThat(rest.length === 0 && ((mode === 'check' && first) || (mode === 'capture' && second === undefined)),
      'Usage: check <capture.json> [expected-names.json] | capture [expected-names.json]');
    const report = mode === 'check'
      ? checkCapture(await jsonFile(first), second ? await jsonFile(second) : undefined)
      : await captureLive({ expectedPath: first });
    console.log(JSON.stringify(report));
  } catch (error) {
    console.error(error instanceof Failure ? error.message : 'Probe failed; local input, storage or process unavailable.');
    process.exitCode = error instanceof Failure ? error.exitCode : 1;
  }
}
