// SPDX-License-Identifier: AGPL-3.0-or-later
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { createServer, request as httpRequest } from 'node:http';
import { createConnection } from 'node:net';
import { mkdtemp, readFile, readdir, realpath, rm, stat, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { captureLive, checkCapture, endpoint } from './probe.mjs';

const { tools } = JSON.parse(await readFile(new URL('../../contracts/mcp/generated/tools.json', import.meta.url)));
const subset = tools.filter(tool => ['deskilo_list_workspaces', 'deskilo_get_capabilities'].includes(tool.name));
const names = subset.map(tool => tool.name);
const response = { result: { tools: subset } };
async function directory(t) {
  const path = await realpath(await mkdtemp(join(tmpdir(), 'deskilo-contract-')));
  t.after(() => rm(path, { recursive: true, force: true }));
  return path;
}

test('canonical definitions, caller subset and empty discovery remain distinct', () => {
  assert.equal(checkCapture({ jsonrpc: '2.0', id: 1, result: { tools } }).mode, 'subset');
  assert.equal(checkCapture(response, names).mode, 'exact');
  assert.equal(checkCapture({ result: { tools: [] } }).completeness, 'NOT EVALUATED');
  assert.equal(checkCapture({ result: { tools: [] } }, []).tools, 0);
  for (const invalid of [null, {}, { tools }, { error: {}, ...response },
    { ...response, jsonrpc: '1.0' }, { result: { ...response.result, nextCursor: 'next' } },
    { result: { tools: [...subset, subset[0]] } }, { result: { tools: [{ name: 'unknown' }] } },
    { result: { tools: subset.filter(tool => tool.name !== 'deskilo_list_workspaces') } },
    { result: { tools: [{ ...subset[0], description: 'changed' }] } }]) {
    assert.throws(() => checkCapture(invalid));
  }
  for (const expected of [[], [...names, names[0]], ['unknown'], null]) {
    assert.throws(() => checkCapture(response, expected));
  }
  assert.deepEqual(checkCapture(response), checkCapture(JSON.parse(JSON.stringify(response))));
});

test('only explicit HTTPS or loopback HTTP endpoints are accepted', () => {
  for (const url of ['https://example.test/mcp', 'http://localhost:123/mcp', 'http://127.0.0.1/mcp', 'http://[::1]/mcp']) {
    assert.equal(endpoint(url), new URL(url).href);
  }
  for (const url of ['', 'file:///tmp/mcp', 'http://example.test/mcp', 'http://localhost.evil/mcp',
    'https://user:secret@example.test/mcp', 'https://example.test/mcp?token=secret', 'https://example.test/mcp#secret']) {
    assert.throws(() => endpoint(url));
  }
});

test('CLI invoked through a symlink still validates its input', async t => {
  const path = await directory(t);
  const alias = join(path, 'probe alias.mjs');
  await symlink(fileURLToPath(new URL('./probe.mjs', import.meta.url)), alias);
  await assert.rejects(promisify(execFile)(process.execPath, [alias, 'check', join(path, 'missing.json')]),
    error => error.code === 1 && error.stderr.includes('Cannot read a valid JSON input file.'));
});

test('credentials stay in a private temporary config; failure removes stale output and recovery works', async t => {
  const path = await directory(t);
  const env = { DESKILO_MCP_URL: 'https://example.test/mcp', DESKILO_MCP_BEARER: 'fixture-secret', MCP_STORAGE_DIR: '/outside' };
  const options = { directory: path, env, expected: names };
  const success = async (_executable, args, settings) => {
    assert(!args.join(' ').includes(env.DESKILO_MCP_BEARER));
    assert.equal(settings.env.DESKILO_MCP_BEARER, undefined);
    const config = args[args.indexOf('--config') + 1];
    assert.equal((await stat(config)).mode & 0o777, 0o600);
    assert.equal(JSON.parse(await readFile(config)).mcpServers.deskilo.headers.Authorization, 'Bearer fixture-secret');
    assert(settings.env.MCP_STORAGE_DIR.startsWith(path));
    return { stdout: JSON.stringify({ ...response, extra: env.DESKILO_MCP_BEARER }) };
  };
  await captureLive({ ...options, run: success });
  assert(!(await readFile(join(path, 'tools-list.json'), 'utf8')).includes(env.DESKILO_MCP_BEARER));
  for (const fault of [{ code: 6 }, { killed: true }, { code: 'ENOENT' }]) {
    await assert.rejects(captureLive({ ...options, run: async () => { throw Object.assign(new Error('fixture-secret'), fault); } }),
      error => error.exitCode === (fault.killed ? 124 : typeof fault.code === 'number' ? fault.code : 1) && !error.message.includes('fixture-secret'));
    assert.deepEqual(await readdir(path), []);
    await captureLive({ ...options, run: success });
  }
  await assert.rejects(captureLive({ ...options, env: {} }));
  assert.deepEqual(await readdir(path), []);
  await captureLive({ ...options, run: success });
  await assert.rejects(captureLive({ ...options, expectedPath: join(path, 'missing.json'), run: success }));
  assert.deepEqual(await readdir(path), []);
  await assert.rejects(captureLive({ ...options, run: async () => ({ stdout: 'invalid' }) }));
  assert.deepEqual(await readdir(path), []);
});

test('the pinned client lists a real HTTP fixture, refuses redirects and times out without residue', async t => {
  const path = await directory(t);
  let mode = 'success';
  let exposed = subset;
  const methods = [];
  let redirected = 0;
  const server = createServer(async (request, reply) => {
    if (request.url === '/redirected') redirected++;
    if (mode === 'hang') return;
    if (mode === 'redirect') { reply.writeHead(302, { location: '/redirected' }).end(); return; }
    assert.equal(request.headers.authorization, 'Bearer fixture-secret');
    if (request.method !== 'POST') { reply.writeHead(405).end(); return; }
    const chunks = [];
    for await (const chunk of request) chunks.push(chunk);
    const message = JSON.parse(Buffer.concat(chunks));
    methods.push(message.method);
    if (message.id === undefined) { reply.writeHead(202).end(); return; }
    const result = message.method === 'initialize'
      ? { protocolVersion: '2025-06-18', capabilities: { tools: {} }, serverInfo: { name: 'fixture', version: '1' } }
      : { tools: exposed };
    reply.writeHead(200, { 'content-type': 'application/json' }).end(JSON.stringify({ jsonrpc: '2.0', id: message.id, result }));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => { server.closeAllConnections(); server.close(); });
  let tunnels = 0;
  const sockets = new Set();
  const proxy = createServer((request, reply) => {
    tunnels++;
    const forward = httpRequest(request.url, { method: request.method, headers: request.headers }, response => {
      reply.writeHead(response.statusCode, response.headers); response.pipe(reply);
    });
    request.pipe(forward);
    forward.on('error', () => reply.destroy());
  });
  proxy.on('connect', (request, client, head) => {
    assert.equal(request.url, `127.0.0.1:${server.address().port}`);
    tunnels++;
    const upstream = createConnection(server.address().port, '127.0.0.1', () => {
      client.write('HTTP/1.1 200 Connection Established\r\n\r\n');
      upstream.write(head); client.pipe(upstream); upstream.pipe(client);
    });
    sockets.add(client); sockets.add(upstream);
    client.on('close', () => upstream.destroy());
    upstream.on('error', () => client.destroy());
  });
  await new Promise(resolve => proxy.listen(0, '127.0.0.1', resolve));
  t.after(() => { for (const socket of sockets) socket.destroy(); proxy.close(); });
  const options = { directory: path, expected: names,
    env: { ...process.env, HTTP_PROXY: '', HTTPS_PROXY: '', http_proxy: '', https_proxy: '', NO_PROXY: '*', no_proxy: '*',
      DESKILO_MCP_URL: `http://127.0.0.1:${server.address().port}/mcp`, DESKILO_MCP_BEARER: 'fixture-secret' } };
  assert.equal((await captureLive(options)).mode, 'exact');
  assert(methods.includes('tools/list'));
  assert(methods.every(method => ['initialize', 'notifications/initialized', 'tools/list'].includes(method)));
  mode = 'redirect';
  await assert.rejects(captureLive(options));
  assert.equal(redirected, 0);
  assert.deepEqual(await readdir(path), []);
  const proxyUrl = `http://127.0.0.1:${proxy.address().port}`;
  Object.assign(options.env, { HTTP_PROXY: proxyUrl, HTTPS_PROXY: proxyUrl, http_proxy: proxyUrl, https_proxy: proxyUrl, NO_PROXY: '', no_proxy: '' });
  await assert.rejects(captureLive(options));
  assert(tunnels > 0, 'the redirect refusal also passes through the real HTTP proxy');
  assert.equal(redirected, 0);
  assert.deepEqual(await readdir(path), []);
  mode = 'hang';
  await assert.rejects(captureLive({ ...options, timeout: 1500 }), error => error.exitCode === 124);
  assert.deepEqual(await readdir(path), []);
  mode = 'success';
  exposed = tools;
  assert.equal((await captureLive({ ...options, expected: tools.map(tool => tool.name) })).tools, tools.length);
});
