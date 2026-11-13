// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3335 — the handler with an injected store and a scripted provider. The
// oracle is what the provider SAW (POST count) and what the record holds,
// never only the label returned: two concurrent requests can both answer
// "success" and still have uploaded twice.

import { assertEquals } from "jsr:@std/assert@1";
import { handle } from "./handler.ts";
import type {
  Artifact,
  ClaimResult,
  Member,
  Phase,
  PrepareInput,
  PrepareResult,
  PrepareTestInput,
  PrepareTestResult,
  TransmissionRow,
  TransmissionStore,
} from "./store.ts";

interface Rec extends TransmissionRow {
  key: string;
  binding: string;
  owner: string;
  generation: number;
  deadline: number;
  verdict: Record<string, unknown>;
  queryError: string;
  artifact: Artifact;
  resolvedBy: string;
  declared?: Record<string, string>;
}

const WS = "ws-1";
const INV = "inv-1";
const USER = "user-1";

/** The database's rules, in memory: the same decisions as the 0689 RPCs. */
class FakeStore implements TransmissionStore {
  rows = new Map<string, Rec>();
  member_: Member | null = {
    id: "m1",
    is_admin: true,
    is_owner: true,
    status: "active",
  };
  permission = false;
  /** #3883 -- the permissions granted one by one (beside [permission]). */
  grants = new Set<string>();
  voidedAt: string | null = null;
  wsEnv = "prod";
  provider = "generic";
  config: Record<string, string> = {
    endpoint: "https://x.test",
    auth_value: "t",
  };
  failPrepare = false;
  failRecord = false;
  now = 1_000;
  n = 0;
  resolveError: string | null = null;

  user(_t: string) {
    return Promise.resolve(USER);
  }
  member() {
    return Promise.resolve(this.member_);
  }
  hasPermission(_member: string, name: string) {
    return Promise.resolve(this.permission || this.grants.has(name));
  }
  credentials() {
    return Promise.resolve({ provider: this.provider, config: this.config });
  }
  workspaceEnvironment() {
    return Promise.resolve(this.wsEnv);
  }
  invoice(id: string) {
    return Promise.resolve(
      id === INV
        ? { id, number: "F-1", workspace_id: WS, voided_at: this.voidedAt }
        : null,
    );
  }
  profileName() {
    return Promise.resolve("T");
  }
  transmission(id: string) {
    return Promise.resolve(this.rows.get(id) ?? null);
  }
  expire() {
    for (const r of this.rows.values()) {
      if (r.phase === "sent" && r.deadline < this.now) r.phase = "uncertain";
    }
    return Promise.resolve();
  }
  prepare(i: PrepareInput): Promise<PrepareResult> {
    if (this.failPrepare) return Promise.reject(new Error("storage down"));
    const key = [
      i.workspaceId,
      i.invoiceId,
      i.provider,
      i.destination,
      i.environment,
    ].join("|");
    const binding = [i.hash, i.format, i.receiverScheme, i.receiverId].join(
      "|",
    );
    const found = [...this.rows.values()].find((r) => r.key === key);
    if (found) {
      return Promise.resolve(
        found.binding !== binding
          ? { outcome: "conflict", id: found.id, phase: found.phase }
          : {
            outcome: "existing",
            id: found.id,
            phase: found.phase,
            external_id: found.external_id,
            detail: found.detail,
          },
      );
    }
    const id = `t${++this.n}`;
    this.rows.set(id, {
      id,
      key,
      binding,
      workspace_id: i.workspaceId,
      provider: i.provider,
      phase: "prepared",
      external_id: "",
      detail: "",
      environment: i.environment,
      destination: i.destination,
      format: i.format,
      receipt: {},
      owner: "",
      generation: 0,
      deadline: 0,
      verdict: {},
      queryError: "",
      resolvedBy: "",
      artifact: {
        bytes: i.bytes,
        sha256: i.hash,
        fileName: i.fileName,
        mimeType: i.mimeType,
        receiverScheme: i.receiverScheme,
        receiverId: i.receiverId,
      },
      declared: i.declared,
    });
    return Promise.resolve({ outcome: "prepared", id, phase: "prepared" });
  }
  /** 0762: one test at a time; a rejected or failed one is sent again. */
  prepareTest(i: PrepareTestInput): Promise<PrepareTestResult> {
    const pending = [...this.rows.values()].find((r) =>
      r.kind === "test" &&
      (["prepared", "sent", "uncertain"].includes(r.phase) ||
        (r.phase === "accepted" &&
          !["accepted", "rejected"].includes(
            String((r.verdict as { status?: string }).status ?? ""),
          )))
    );
    if (pending) {
      return Promise.resolve({
        outcome: "test_pending",
        id: pending.id,
        phase: pending.phase,
      });
    }
    const id = `t${++this.n}`;
    this.rows.set(id, {
      id,
      key: `${i.workspaceId}|test|${id}`,
      binding: `${i.hash}|${i.format}`,
      kind: "test",
      workspace_id: i.workspaceId,
      provider: i.provider,
      phase: "prepared",
      external_id: "",
      detail: "",
      environment: "uat",
      destination: "government",
      format: i.format,
      receipt: {},
      owner: "",
      generation: 0,
      deadline: 0,
      verdict: {},
      queryError: "",
      resolvedBy: "",
      artifact: {
        bytes: i.bytes,
        sha256: i.hash,
        fileName: i.fileName,
        mimeType: i.mimeType,
        receiverScheme: "",
        receiverId: "",
      },
      declared: i.declared,
    });
    return Promise.resolve({ outcome: "prepared", id, phase: "prepared" });
  }
  artifact(id: string) {
    return Promise.resolve(this.rows.get(id)?.artifact ?? null);
  }
  claim(id: string, owner: string, window: number): Promise<ClaimResult> {
    const r = this.rows.get(id)!;
    if (r.phase === "sent" && r.deadline < this.now) r.phase = "uncertain";
    if (r.phase === "prepared" || r.phase === "failed") {
      r.phase = "sent";
      r.owner = owner;
      r.generation++;
      r.deadline = this.now + window * 1000;
      return Promise.resolve({
        claimed: true,
        generation: r.generation,
        phase: "sent",
      });
    }
    return Promise.resolve({
      claimed: false,
      phase: r.phase,
      external_id: r.external_id,
      detail: r.detail,
    });
  }
  record(
    id: string,
    generation: number,
    owner: string,
    phase: Phase,
    externalId: string,
    detail: string,
    receipt: Record<string, unknown>,
  ) {
    if (this.failRecord) return Promise.reject(new Error("write lost"));
    const r = this.rows.get(id)!;
    if (
      r.generation !== generation || r.owner !== owner ||
      (r.phase !== "sent" && r.phase !== "uncertain")
    ) {
      return Promise.resolve(false);
    }
    r.phase = phase;
    r.external_id = externalId;
    r.detail = detail;
    r.receipt = receipt;
    return Promise.resolve(true);
  }
  lookup(
    id: string,
    phase: "accepted" | "rejected" | null,
    externalId: string,
    receipt: Record<string, unknown> | null,
    verdict: Record<string, unknown> | null,
    queryError: string | null,
  ) {
    const r = this.rows.get(id)!;
    if (phase && r.phase !== "uncertain") return Promise.resolve(false);
    // the SQL evaluates the receipt CASE against the OLD row (#3576)
    const oldPhase = r.phase;
    const oldReceipt = r.receipt;
    if (phase) {
      r.phase = phase;
      r.external_id = externalId || r.external_id;
    }
    if (
      receipt &&
      !(oldPhase === "accepted" && Object.keys(oldReceipt).length > 0)
    ) r.receipt = receipt;
    if (verdict) r.verdict = verdict;
    r.queryError = queryError ?? "";
    return Promise.resolve(true);
  }
  resolve(
    id: string,
    actor: string,
    outcome: "accepted" | "rejected" | "failed",
    reason: string,
    evidence: string,
    verdict: Record<string, unknown> | null,
  ) {
    if (this.resolveError) {
      return Promise.reject(
        Object.assign(new Error("x"), { code: this.resolveError }),
      );
    }
    const r = this.rows.get(id)!;
    if (!reason.trim() || !evidence.trim()) {
      return Promise.reject(Object.assign(new Error("x"), { code: "22023" }));
    }
    if (r.phase !== "uncertain") {
      return Promise.resolve({ resolved: false, phase: r.phase });
    }
    r.phase = outcome;
    r.resolvedBy = actor;
    if (verdict) r.verdict = verdict;
    return Promise.resolve({ resolved: true, phase: outcome });
  }
}

/** A provider that counts uploads and answers as scripted. */
function provider(answer: () => Response | Promise<Response>) {
  const posts: string[] = [];
  const gets: string[] = [];
  const fetchImpl = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input instanceof Request ? input.url : input);
    if ((init?.method ?? "GET") === "POST") posts.push(url);
    else gets.push(url);
    return Promise.resolve(answer());
  }) as typeof fetch;
  return { posts, gets, fetchImpl };
}

const ok = (id = "X1") => new Response(JSON.stringify({ id }), { status: 200 });

const bodyOf = (extra: Record<string, unknown> = {}) => ({
  workspace_id: WS,
  invoice_id: INV,
  content_base64: btoa("<xml>one</xml>"),
  format: "facturX",
  ...extra,
});

const call = (store: FakeStore, fetchImpl: typeof fetch, body: unknown) =>
  handle(
    new Request("https://f.test/send", {
      method: "POST",
      headers: { Authorization: "Bearer t" },
      body: JSON.stringify(body),
    }),
    { store, fetchImpl },
  );

const read = async (res: Response) => ({
  status: res.status,
  body: await res.json(),
});

Deno.test("O1: a failed prepare sends nothing and records no sent row", async () => {
  const s = new FakeStore();
  s.failPrepare = true;
  const p = provider(ok);
  const r = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(r.status, 500);
  assertEquals(p.posts.length, 0);
  assertEquals(s.rows.size, 0);
});

Deno.test("O1: an artifact that does not verify never leaves", async () => {
  const s = new FakeStore();
  const p = provider(ok);
  const real = s.artifact.bind(s);
  s.artifact = async (id) => ({ ...(await real(id))!, sha256: "tampered" });
  const r = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(r.body.error, "artifact_unavailable");
  assertEquals(p.posts.length, 0);
});

Deno.test("a send is prepared, claimed, posted once and recorded accepted", async () => {
  const s = new FakeStore();
  const p = provider(ok);
  const r = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(r.status, 200);
  assertEquals(r.body.phase, "accepted");
  assertEquals(r.body.external_id, "X1");
  assertEquals(p.posts.length, 1);
  assertEquals([...s.rows.values()][0].generation, 1);
});

Deno.test("O2: simultaneous requests upload once, whatever the bytes", async () => {
  const s = new FakeStore();
  const p = provider(async () => {
    await new Promise((r) => setTimeout(r, 20));
    return ok();
  });
  const rs = await Promise.all([
    call(s, p.fetchImpl, bodyOf()),
    call(s, p.fetchImpl, bodyOf()),
    call(s, p.fetchImpl, bodyOf({ content_base64: btoa("<xml>two</xml>") })),
  ].map(async (x) => read(await x)));
  // Which request reaches prepare first is not fixed; the invariants are:
  assertEquals(p.posts.length, 1); // at most one provider upload
  assertEquals(s.rows.size, 1); // one durable identity
  assertEquals(rs.filter((x) => x.status === 200).length, 1); // one winner
  for (const loser of rs.filter((x) => x.status !== 200)) {
    // every other request is refused or told the dispatch is in flight
    assertEquals(
      loser.body.error === "binding_changed" || loser.body.phase === "sent",
      true,
      JSON.stringify(loser),
    );
  }
});

Deno.test("O3: a record prepared but never dispatched is claimed by the next request", async () => {
  const s = new FakeStore();
  const p = provider(ok);
  // the previous process died after prepare, before claim
  await s.prepare({
    workspaceId: WS,
    invoiceId: INV,
    provider: "generic",
    destination: "government",
    environment: "prod",
    actor: USER,
    byName: "T",
    format: "facturX",
    hash: await hash("<xml>one</xml>"),
    fileName: "F-1.pdf",
    mimeType: "application/pdf",
    receiverScheme: "",
    receiverId: "",
    bytes: new TextEncoder().encode("<xml>one</xml>") as Uint8Array<
      ArrayBuffer
    >,
    declared: {},
  });
  const r = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(r.body.phase, "accepted");
  assertEquals(p.posts.length, 1);
  assertEquals(s.rows.size, 1);
});

async function hash(text: string) {
  const d = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return [...new Uint8Array(d)].map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.test("O4: a lost answer after dispatch is uncertain and never resent", async () => {
  const s = new FakeStore();
  const p = provider(() => {
    throw new Error("socket reset");
  });
  const first = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(first.body.phase, "uncertain");
  assertEquals(first.body.status, "failed"); // what an older client decodes
  assertEquals(first.body.detail, "In progress or unresolved - do not resend");
  const again = await read(await call(s, p.fetchImpl, bodyOf()));
  const third = await read(
    await call(s, p.fetchImpl, bodyOf({ content_base64: btoa("x") })),
  );
  assertEquals(again.body.phase, "uncertain");
  assertEquals(third.body.error, "binding_changed");
  assertEquals(p.posts.length, 1);
});

Deno.test("O4: a lost outcome write leaves the dispatch unresolved; expiry makes it uncertain, never a resend", async () => {
  const s = new FakeStore();
  s.failRecord = true;
  const p = provider(ok);
  const first = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(first.body.phase, "uncertain");
  s.failRecord = false;
  s.now += 10 * 60_000; // the owner is long gone
  const again = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(again.body.phase, "uncertain");
  assertEquals(p.posts.length, 1);
});

Deno.test("O4: a provider 5xx after the upload is uncertain, a 4xx refusal is rejected", async () => {
  const s = new FakeStore();
  const p = provider(() => new Response("busy", { status: 503 }));
  assertEquals(
    (await read(await call(s, p.fetchImpl, bodyOf()))).body.phase,
    "uncertain",
  );
  const s2 = new FakeStore();
  const p2 = provider(() => new Response("no", { status: 422 }));
  const r = await read(await call(s2, p2.fetchImpl, bodyOf()));
  assertEquals(r.body.phase, "rejected");
  assertEquals(r.body.status, "rejected");
});

Deno.test("O6: the generic adapter stays uncertain over any number of status calls", async () => {
  const s = new FakeStore();
  const p = provider(() => {
    throw new Error("socket reset");
  });
  const sent = await read(await call(s, p.fetchImpl, bodyOf()));
  for (let i = 0; i < 3; i++) {
    const r = await read(
      await call(s, p.fetchImpl, {
        workspace_id: WS,
        action: "status",
        transmission_id: sent.body.transmission_id,
      }),
    );
    assertEquals(r.body.phase, "uncertain");
    assertEquals(r.body.lookup, "unavailable");
  }
  assertEquals(p.posts.length, 1);
});

Deno.test("O7: a replay of an accepted transmission returns its receipt and uploads nothing", async () => {
  const s = new FakeStore();
  const p = provider(ok);
  await call(s, p.fetchImpl, bodyOf());
  const again = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(again.body.phase, "accepted");
  assertEquals(again.body.external_id, "X1");
  assertEquals(p.posts.length, 1);
  assertEquals(s.rows.size, 1);
});

Deno.test("O8: changed bytes or recipient conflict, with a fresh request each time", async () => {
  const s = new FakeStore();
  const p = provider(ok);
  await call(s, p.fetchImpl, bodyOf());
  const bytes = await read(
    await call(
      s,
      p.fetchImpl,
      bodyOf({ content_base64: btoa("<xml>two</xml>") }),
    ),
  );
  const who = await read(
    await call(
      s,
      p.fetchImpl,
      bodyOf({ receiver_id: "someone-else", receiver_scheme: "0088" }),
    ),
  );
  assertEquals(bytes.status, 409);
  assertEquals(bytes.body.error, "binding_changed");
  assertEquals(who.body.error, "binding_changed");
  assertEquals(p.posts.length, 1);
  assertEquals([...s.rows.values()][0].external_id, "X1");
});

Deno.test("O9: a failed status query leaves the upload receipt and the phase", async () => {
  const s = new FakeStore();
  s.provider = "peppol";
  s.config = {
    base_url: "https://ap.test",
    api_key: "k",
    legal_entity_id: "1",
  };
  s.rows.set("t9", {
    id: "t9",
    key: "k",
    binding: "b",
    workspace_id: WS,
    provider: "peppol",
    phase: "accepted",
    external_id: "G-1",
    detail: "",
    environment: "prod",
    destination: "government",
    format: "peppolBis",
    receipt: { guid: "G-1" },
    owner: "o",
    generation: 1,
    deadline: 0,
    verdict: {},
    queryError: "",
    resolvedBy: "",
    artifact: {
      bytes: new Uint8Array() as Uint8Array<ArrayBuffer>,
      sha256: "",
      fileName: "",
      mimeType: "",
      receiverScheme: "",
      receiverId: "",
    },
  });
  const p = provider(() => new Response("expired token", { status: 401 }));
  const r = await read(
    await call(s, p.fetchImpl, {
      workspace_id: WS,
      action: "status",
      transmission_id: "t9",
    }),
  );
  assertEquals(r.body.phase, "accepted");
  assertEquals(r.body.document_status, "unknown");
  const row = s.rows.get("t9")!;
  assertEquals(row.receipt, { guid: "G-1" });
  assertEquals(row.phase, "accepted");
  assertEquals(row.queryError !== "", true);
  assertEquals(p.posts.length, 0);
});

Deno.test("O11: the government and customer legs are separate transmissions", async () => {
  const s = new FakeStore();
  const p = provider(ok);
  s.config = {
    endpoint: "https://x.test",
    auth_value: "t",
    customer_endpoint: "https://c.test",
    customer_auth_value: "c",
  };
  await call(s, p.fetchImpl, bodyOf());
  await call(s, p.fetchImpl, bodyOf({ destination: "customer" }));
  assertEquals(s.rows.size, 2);
  assertEquals(p.posts.sort(), ["https://c.test", "https://x.test"]);
});

Deno.test("O12: nobody unauthorised reaches the provider or the record", async () => {
  for (
    const arrange of [
      (s: FakeStore) => {
        s.member_ = null;
      },
      (s: FakeStore) => {
        s.member_ = {
          id: "m",
          is_admin: true,
          is_owner: true,
          status: "inactive",
        };
      },
      (s: FakeStore) => {
        s.member_ = {
          id: "m",
          is_admin: false,
          is_owner: false,
          status: "active",
        };
      },
    ]
  ) {
    const s = new FakeStore();
    arrange(s);
    const p = provider(ok);
    const r = await read(await call(s, p.fetchImpl, bodyOf()));
    assertEquals(r.status, 403);
    assertEquals(p.posts.length, 0);
    assertEquals(s.rows.size, 0);
  }
  const s = new FakeStore();
  s.member_ = { id: "m", is_admin: false, is_owner: false, status: "active" };
  s.permission = true;
  assertEquals((await call(s, provider(ok).fetchImpl, bodyOf())).status, 200);
});

Deno.test("an administrator sends only with the right to issue invoices; an owner always does", async () => {
  const admin = new FakeStore();
  admin.member_ = { id: "m", is_admin: true, is_owner: false, status: "active" };
  const p = provider(ok);
  const refused = await read(await call(admin, p.fetchImpl, bodyOf()));
  assertEquals(refused.status, 403);
  assertEquals(refused.body.error, "not allowed to issue invoices in this workspace");
  assertEquals(p.posts.length, 0);
  assertEquals(admin.rows.size, 0);

  const granted = new FakeStore();
  granted.member_ = { id: "m", is_admin: true, is_owner: false, status: "active" };
  granted.permission = true;
  assertEquals((await call(granted, provider(ok).fetchImpl, bodyOf())).status, 200);

  const owner = new FakeStore();
  owner.member_ = { id: "m", is_admin: false, is_owner: true, status: "active" };
  assertEquals((await call(owner, provider(ok).fetchImpl, bodyOf())).status, 200);
});

Deno.test("a voided invoice is not sent", async () => {
  const s = new FakeStore();
  s.voidedAt = "2026-11-01T10:00:00Z";
  const p = provider(ok);
  const r = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(r.status, 409);
  assertEquals(r.body.error, "invoice_voided");
  assertEquals(p.posts.length, 0);
  assertEquals(s.rows.size, 0);
});

Deno.test("a document over the size bound is not sent", async () => {
  const s = new FakeStore();
  const p = provider(ok);
  const r = await read(
    await call(s, p.fetchImpl, bodyOf({ content_base64: "A".repeat(14_000_004) })),
  );
  assertEquals(r.status, 413);
  assertEquals(r.body.error, "document_too_large");
  assertEquals(p.posts.length, 0);
});

Deno.test("a development workspace sends nothing and records nothing", async () => {
  const s = new FakeStore();
  s.wsEnv = "dev";
  const p = provider(ok);
  const r = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(r.body.error, "development_workspace");
  assertEquals(p.posts.length, 0);
  assertEquals(s.rows.size, 0);
});

Deno.test("O13: an unresolved record reads as a failure with the words not to resend, plus its true phase", async () => {
  const s = new FakeStore();
  const p = provider(() => {
    throw new Error("socket reset");
  });
  const r = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(
    ["accepted", "rejected", "failed"].includes(r.body.status),
    true,
  );
  assertEquals(r.body.phase, "uncertain");
  const config = await read(
    await call(s, p.fetchImpl, { workspace_id: WS, action: "config" }),
  );
  assertEquals(config.body.phases, true);
});

Deno.test("O14: manual resolution needs the authority, a reason and evidence, and cannot repeat", async () => {
  const s = new FakeStore();
  const p = provider(() => {
    throw new Error("socket reset");
  });
  const sent = await read(await call(s, p.fetchImpl, bodyOf()));
  const id = sent.body.transmission_id;
  const resolve = (extra: Record<string, unknown>) =>
    call(s, p.fetchImpl, {
      workspace_id: WS,
      action: "resolve",
      transmission_id: id,
      ...extra,
    });
  s.resolveError = "42501";
  const refused = await resolve({ outcome: "failed", reason: "r", evidence: "e" });
  assertEquals(refused.status, 403);
  assertEquals(await refused.json(), {
    error: "not allowed to issue invoices in this workspace",
  });
  s.resolveError = null;
  assertEquals(
    (await resolve({ outcome: "failed", reason: "r", evidence: "" })).status,
    400,
  );
  assertEquals(
    (await resolve({ outcome: "bogus", reason: "r", evidence: "e" })).status,
    400,
  );
  const done = await read(
    await resolve({
      outcome: "accepted",
      reason: "portal shows it",
      evidence: "ref 1",
      verdict: { document: "rejected" },
    }),
  );
  assertEquals(done.body.resolved, true);
  assertEquals(s.rows.get(id)!.resolvedBy, USER);
  assertEquals(s.rows.get(id)!.verdict, { document: "rejected" });
  const twice = await read(
    await resolve({ outcome: "failed", reason: "r", evidence: "e" }),
  );
  assertEquals(twice.status, 409);
  assertEquals(s.rows.get(id)!.phase, "accepted");
  assertEquals(p.posts.length, 1);
});

Deno.test("a resolved no-acceptance failure may be dispatched again, with the same record", async () => {
  const s = new FakeStore();
  let n = 0;
  const p = provider(() => {
    n++;
    if (n === 1) throw new Error("socket reset");
    return ok("X2");
  });
  const sent = await read(await call(s, p.fetchImpl, bodyOf()));
  await call(s, p.fetchImpl, {
    workspace_id: WS,
    action: "resolve",
    transmission_id: sent.body.transmission_id,
    outcome: "failed",
    reason: "provider logs show nothing",
    evidence: "ticket 9",
  });
  const retry = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(retry.body.phase, "accepted");
  assertEquals(retry.body.transmission_id, sent.body.transmission_id);
  assertEquals(s.rows.get(sent.body.transmission_id)!.generation, 2);
});

Deno.test("O10: a later document rejection is a verdict beside the upload; the phase stays accepted", async () => {
  const s = new FakeStore();
  s.provider = "it_sdi";
  s.config = {
    base_url: "https://sdi.test",
    login_url: "https://login.test/login",
    username: "u@x.it",
    password: "p",
  };
  s.rows.set("t10", {
    id: "t10",
    key: "k",
    binding: "b",
    workspace_id: WS,
    provider: "it_sdi",
    phase: "accepted",
    external_id: "u-1",
    detail: "",
    environment: "prod",
    destination: "government",
    format: "fatturaPa",
    receipt: { uuid: "u-1" },
    owner: "o",
    generation: 1,
    deadline: 0,
    verdict: {},
    queryError: "",
    resolvedBy: "",
    artifact: {
      bytes: new Uint8Array() as Uint8Array<ArrayBuffer>,
      sha256: "",
      fileName: "",
      mimeType: "",
      receiverScheme: "",
      receiverId: "",
    },
  });
  const p = provider(() => new Response("{}"));
  const answers: Record<string, unknown> = {
    "https://login.test/login": { token: "jwt" },
    "https://sdi.test/invoices/u-1": { marking: "rejected" },
    "https://sdi.test/invoices/u-1/notifications": [
      { type: "NS", message: "00404 duplicate" },
    ],
  };
  const fetchImpl = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input instanceof Request ? input.url : input);
    if ((init?.method ?? "GET") === "POST" && !url.endsWith("/login")) {
      p.posts.push(url);
    }
    return Promise.resolve(
      new Response(JSON.stringify(answers[url] ?? {}), { status: 200 }),
    );
  }) as typeof fetch;
  const r = await read(
    await call(s, fetchImpl, {
      workspace_id: WS,
      action: "status",
      transmission_id: "t10",
    }),
  );
  const row = s.rows.get("t10")!;
  assertEquals(r.body.phase, "accepted"); // transport progress is kept
  assertEquals(r.body.document_status, "rejected"); // the verdict, separately
  assertEquals(row.phase, "accepted");
  assertEquals((row.verdict as { status?: string }).status, "rejected");
  assertEquals(row.receipt.uuid !== undefined, true);
  assertEquals(p.posts.length, 0); // asking never uploads
});

// #3881 -- an SdI status gives a verdict only on the SdI's outcome
// notification: NS refuses, RC delivers, MC and AT count the invoice as
// issued. Before the SdI has answered, the status writes no verdict.
async function sdiStatus(notifications: unknown[]) {
  const s = new FakeStore();
  s.provider = "it_sdi";
  s.config = {
    base_url: "https://sdi.test",
    login_url: "https://login.test/login",
    username: "u@x.it",
    password: "p",
  };
  s.rows.set("t81", {
    id: "t81",
    key: "k",
    binding: "b",
    workspace_id: WS,
    provider: "it_sdi",
    phase: "accepted",
    external_id: "u-1",
    detail: "",
    environment: "prod",
    destination: "government",
    format: "fatturaPa",
    receipt: { uuid: "u-1" },
    owner: "o",
    generation: 1,
    deadline: 0,
    verdict: {},
    queryError: "",
    resolvedBy: "",
    artifact: {
      bytes: new Uint8Array() as Uint8Array<ArrayBuffer>,
      sha256: "",
      fileName: "",
      mimeType: "",
      receiverScheme: "",
      receiverId: "",
    },
  });
  const answers: Record<string, unknown> = {
    "https://login.test/login": { token: "jwt" },
    "https://sdi.test/invoices/u-1": { marking: "sent" },
    "https://sdi.test/invoices/u-1/notifications": notifications,
  };
  const fetchImpl = ((input: string | URL | Request) => {
    const url = String(input instanceof Request ? input.url : input);
    return Promise.resolve(
      new Response(JSON.stringify(answers[url] ?? {}), { status: 200 }),
    );
  }) as typeof fetch;
  const r = await read(
    await call(s, fetchImpl, {
      workspace_id: WS,
      action: "status",
      transmission_id: "t81",
    }),
  );
  return { r, row: s.rows.get("t81")! };
}

Deno.test("#3881 an SdI status before the SdI has answered writes no verdict", async () => {
  const { r, row } = await sdiStatus([]);
  assertEquals(r.body.document_status, "unknown");
  assertEquals(row.verdict, {});
  assertEquals(row.queryError, "");
  assertEquals(row.phase, "accepted");
  assertEquals(row.receipt, { uuid: "u-1" });
});

Deno.test("#3881 an SdI notification that is no outcome writes no verdict", async () => {
  const { r, row } = await sdiStatus([{ type: "MT", message: "metadata" }]);
  assertEquals(r.body.document_status, "unknown");
  assertEquals(row.verdict, {});
});

Deno.test("#3881 a delivery receipt is the SdI's acceptance, whatever follows it", async () => {
  for (const notes of [[{ type: "RC" }], [{ type: "RC" }, { type: "DT" }], [{ type: "MC" }], [{ type: "AT" }]]) {
    const { r, row } = await sdiStatus(notes);
    assertEquals(r.body.document_status, "accepted", JSON.stringify(notes));
    assertEquals((row.verdict as { status?: string }).status, "accepted");
  }
});

Deno.test("O3/O4: a send on a record whose dispatch window passed answers uncertain and uploads nothing", async () => {
  const s = new FakeStore();
  const p = provider(ok);
  // the function died mid-POST: claimed, never recorded, deadline passed
  const prep = await s.prepare({
    workspaceId: WS,
    invoiceId: INV,
    provider: "generic",
    destination: "government",
    environment: "prod",
    actor: USER,
    byName: "T",
    format: "facturX",
    hash: await hash("<xml>one</xml>"),
    fileName: "F-1.pdf",
    mimeType: "application/pdf",
    receiverScheme: "",
    receiverId: "",
    bytes: new TextEncoder().encode("<xml>one</xml>") as Uint8Array<
      ArrayBuffer
    >,
    declared: {},
  });
  await s.claim(prep.id!, "dead-owner", 150);
  s.now += 10 * 60_000;
  const r = await read(await call(s, p.fetchImpl, bodyOf()));
  assertEquals(r.body.phase, "uncertain");
  assertEquals(r.body.status, "failed"); // what an older client decodes
  assertEquals(p.posts.length, 0);
  assertEquals(s.rows.get(prep.id!)!.phase, "uncertain");
});

Deno.test("#3336: what the client declares is clipped to strings of four keys and kept apart", async () => {
  const s = new FakeStore();
  const p = provider(ok);
  await call(
    s,
    p.fetchImpl,
    bodyOf({
      declared: {
        renderer: "facturX",
        app_version: "1.2.3",
        renderer_version: 7, // a non-string is dropped, never coerced
        format: ["facturX"],
        issuer: "forged",
        actor_user_id: "forged",
      },
    }),
  );
  const row = [...s.rows.values()][0];
  assertEquals(row.declared, { renderer: "facturX", app_version: "1.2.3" });
});

Deno.test("#3336: a long declared value is cut and a malformed declaration is ignored", async () => {
  const s = new FakeStore();
  const p = provider(ok);
  await call(
    s,
    p.fetchImpl,
    bodyOf({ declared: { renderer: "x".repeat(400) } }),
  );
  assertEquals([...s.rows.values()][0].declared!.renderer.length, 120);
  for (const bad of ["facturX", 42, null, ["renderer"], true]) {
    const s2 = new FakeStore();
    const r = await read(
      await call(s2, provider(ok).fetchImpl, bodyOf({ declared: bad })),
    );
    assertEquals(r.status, 200); // the send is unaffected
    assertEquals([...s2.rows.values()][0].declared, {});
  }
});

Deno.test("#3336: a send without a declaration (an older client) records none", async () => {
  const s = new FakeStore();
  const r = await read(await call(s, provider(ok).fetchImpl, bodyOf()));
  assertEquals(r.status, 200);
  assertEquals([...s.rows.values()][0].declared, {});
});

Deno.test("#3338: the config of a provider with no installed connector says provider_not_installed and is not configured", async () => {
  const s = new FakeStore();
  s.provider = "retired_sdi";
  s.config = { endpoint: "https://example.test", auth_value: "x" };
  const p = provider(() => new Response("{}"));
  const config = await read(
    await call(s, p.fetchImpl, { workspace_id: WS, action: "config" }),
  );
  assertEquals(config.body.configured, false);
  assertEquals(config.body.error, "provider_not_installed");
  assertEquals(config.body.provider, "retired_sdi");
});

Deno.test("#3338: an installed provider's config carries no error", async () => {
  const s = new FakeStore();
  const p = provider(() => new Response("{}"));
  const config = await read(
    await call(s, p.fetchImpl, { workspace_id: WS, action: "config" }),
  );
  assertEquals(config.body.error, undefined);
});

// ── #3338 row 7: the previous client against the upgraded function ─────────
// The requests and the readers below are pinned to what the client of 010b6df
// (before the transmission lifecycle) sent and decoded; they must keep
// working against today's handler. Nothing here is generated from the new
// code: the field lists are the old ones.

/** The fields the client of 010b6df put in a send request, and no other. */
const oldSendBody = (extra: Record<string, unknown> = {}) => ({
  workspace_id: WS,
  invoice_id: INV,
  content_base64: btoa("<xml>one</xml>"),
  file_name: "F-1.pdf",
  mime_type: "application/pdf",
  format: "facturX",
  environment: "prod",
  destination: "government",
  ...extra,
});

Deno.test("#3338/7: the previous client's send request still works and its answer carries the keys it decoded", async () => {
  const s = new FakeStore();
  const p = provider(() => ok("X-OLD"));
  const r = await read(await call(s, p.fetchImpl, oldSendBody()));
  assertEquals(r.status, 200);
  // the old decoder read exactly: status (one of three), external_id, detail
  assertEquals(
    ["accepted", "rejected", "failed"].includes(r.body.status),
    true,
  );
  assertEquals(typeof r.body.external_id, "string");
  assertEquals(typeof (r.body.detail ?? r.body.error ?? ""), "string");
  assertEquals(p.posts.length, 1);
});

Deno.test("#3338/7: the previous client's config reader finds every key it decoded", async () => {
  const s = new FakeStore();
  const p = provider(() => ok());
  const r = await read(
    await call(s, p.fetchImpl, { workspace_id: WS, action: "config" }),
  );
  const b = r.body;
  assertEquals(typeof b.configured, "boolean");
  assertEquals(typeof b.provider, "string");
  assertEquals(Array.isArray(b.missing), true);
  for (const v of Object.values(b.environments as Record<string, unknown>)) {
    assertEquals(typeof v, "boolean");
  }
  for (
    const d of Object.values(
      b.destinations as Record<
        string,
        { configured: unknown; missing: unknown; environments: unknown }
      >,
    )
  ) {
    assertEquals(typeof d.configured, "boolean");
    assertEquals(Array.isArray(d.missing), true);
    assertEquals(typeof d.environments, "object");
  }
});

Deno.test("#3338/7: an old client's retry of an unresolved send cannot bypass the server's fencing", async () => {
  const s = new FakeStore();
  const p = provider(() => {
    throw new Error("socket reset");
  });
  const first = await read(await call(s, p.fetchImpl, oldSendBody()));
  assertEquals(first.body.status, "failed"); // what the old decoder reads
  assertEquals(p.posts.length, 1);
  // the old client retries the identical request: nothing leaves again
  const retry = await read(await call(s, p.fetchImpl, oldSendBody()));
  assertEquals(retry.body.status, "failed");
  assertEquals(p.posts.length, 1, "no second upload");
  assertEquals(s.rows.size, 1, "and no second logical transmission");
});

// #2358 (carried from #2379) — the Peppol access point, mocked: one BIS
// Billing 3.0 document per invoice to the configured participant id, the
// message-level response read back and stored as the acknowledgement, and a
// second delivery that sends nothing. A live sandbox round trip stays
// owner-blocked; this proves the handler's side of it.
Deno.test("Peppol mock: one BIS document to the participant id, the MLR stored, a second delivery sends nothing", async () => {
  const s = new FakeStore();
  s.provider = "peppol";
  s.config = {
    base_url: "https://ap.test",
    api_key: "k",
    legal_entity_id: "7",
  };
  const sent: { url: string; body: Record<string, unknown> }[] = [];
  const asked: string[] = [];
  const fetchImpl = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input instanceof Request ? input.url : input);
    if ((init?.method ?? "GET") === "POST") {
      sent.push({ url, body: JSON.parse(String(init?.body)) });
      return Promise.resolve(
        new Response(JSON.stringify({ guid: "G-7" }), { status: 200 }),
      );
    }
    asked.push(url);
    return Promise.resolve(
      new Response(
        JSON.stringify({ messageLevelResponse: "AP", status: "ACKNOWLEDGED" }),
        { status: 200 },
      ),
    );
  }) as typeof fetch;
  const body = bodyOf({
    format: "peppolBis",
    receiver_scheme: "0208",
    receiver_id: "0202239951",
  });

  const first = await read(await call(s, fetchImpl, body));
  assertEquals(first.body.phase, "accepted");
  assertEquals(first.body.external_id, "G-7");
  // exactly one document left, to the configured participant id
  assertEquals(sent.length, 1);
  assertEquals(sent[0].url, "https://ap.test/api/v2/document_submissions");
  const routed = sent[0].body.routing as {
    eIdentifiers: { scheme: string; id: string }[];
  };
  assertEquals(routed.eIdentifiers, [{ scheme: "BE:EN", id: "0202239951" }]);
  const doc = sent[0].body.document as {
    rawDocumentData: { parseStrategy: string };
  };
  assertEquals(doc.rawDocumentData.parseStrategy, "ubl");

  // the message-level response is read back and stored beside the upload;
  // until its outcome fields are named from a real answer it is no verdict
  // (#3881)
  const row = [...s.rows.values()][0];
  const status = await read(
    await call(s, fetchImpl, {
      workspace_id: WS,
      action: "status",
      transmission_id: row.id,
    }),
  );
  assertEquals(status.body.document_status, "unknown");
  assertEquals(asked, [
    "https://ap.test/api/v2/document_submissions/G-7/evidence/sending",
  ]);
  assertEquals(row.verdict, {});
  assertEquals(row.queryError, "");
  assertEquals(row.phase, "accepted");

  // a second delivery of the same invoice sends nothing
  const again = await read(await call(s, fetchImpl, body));
  assertEquals(again.body.phase, "accepted");
  assertEquals(again.body.external_id, "G-7");
  assertEquals(sent.length, 1);
  assertEquals(s.rows.size, 1);
});

// ── #3576 — retained-ID recovery of an uncertain transmission ─────────────
// Supported: an uncertain row that KEPT its provider id is asked about, with
// the credentials of its STORED environment. Not supported (and not tested
// here as if it were): finding a lost transmission by a pre-dispatch key.

const UAT_CFG = {
  base_url: "https://prod.test",
  api_key: "prod-key",
  legal_entity_id: "1",
  base_url_uat: "https://uat.test",
  api_key_uat: "uat-key",
  legal_entity_id_uat: "2",
};
const UAT_EVIDENCE_URL =
  "https://uat.test/api/v2/document_submissions/G-UAT/evidence/sending";
const PARTIAL = { partial: "before lookup" };

/** A Peppol government row stored for UAT, made through prepare (so its key
 * and binding are the real ones a later send recomputes), then left uncertain
 * with a retained id, a partial receipt, an owner and a generation. */
async function retainedUat(externalId = "G-UAT") {
  const s = new FakeStore();
  s.provider = "peppol";
  s.config = { ...UAT_CFG };
  const prepared = await s.prepare({
    workspaceId: WS,
    invoiceId: INV,
    provider: "peppol",
    destination: "government",
    environment: "uat",
    actor: USER,
    byName: "T",
    format: "peppolBis",
    hash: await hash("<xml>one</xml>"),
    fileName: "F-1.pdf",
    mimeType: "application/pdf",
    receiverScheme: "0208",
    receiverId: "0202239951",
    bytes: new TextEncoder().encode("<xml>one</xml>") as Uint8Array<
      ArrayBuffer
    >,
    declared: {},
  });
  const row = s.rows.get(prepared.id!)!;
  row.phase = "uncertain";
  row.external_id = externalId;
  row.owner = "o";
  row.generation = 1;
  row.receipt = { ...PARTIAL };
  return { s, id: row.id };
}

/** A network stub that records every request it sees. */
function recorder(answer: () => Response | Promise<Response>) {
  const seen: { url: string; method: string; auth: string }[] = [];
  const fetchImpl = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input instanceof Request ? input.url : input);
    seen.push({
      url,
      method: init?.method ?? "GET",
      auth: new Headers(init?.headers).get("Authorization") ?? "",
    });
    return Promise.resolve(answer());
  }) as typeof fetch;
  return { seen, fetchImpl };
}

const acknowledged = () =>
  new Response(
    JSON.stringify({ messageLevelResponse: "AP", status: "ACKNOWLEDGED" }),
    { status: 200 },
  );

const statusBody = (id: string, extra: Record<string, unknown> = {}) => ({
  workspace_id: WS,
  action: "status",
  transmission_id: id,
  ...extra,
});

const expectedUatGet = [
  { url: UAT_EVIDENCE_URL, method: "GET", auth: "Bearer uat-key" },
];

Deno.test("R1 retained-ID recovery: an uncertain row with its id settles accepted on a successful status, keeping row, binding and artifact; the document has no verdict yet (#3881)", async () => {
  const { s, id } = await retainedUat();
  const before = structuredClone(s.rows.get(id)!);
  const net = recorder(acknowledged);
  const r = await read(await call(s, net.fetchImpl, statusBody(id)));
  const row = s.rows.get(id)!;
  assertEquals(r.body.phase, "accepted");
  assertEquals(r.body.document_status, "unknown");
  assertEquals(row.phase, "accepted");
  assertEquals(row.verdict, {});
  // the correlated evidence REPLACES the partial prior receipt
  assertEquals(row.receipt, {
    guid: "G-UAT",
    evidence: { messageLevelResponse: "AP", status: "ACKNOWLEDGED" },
  });
  assertEquals(row.key, before.key);
  assertEquals(row.binding, before.binding);
  assertEquals(row.owner, before.owner);
  assertEquals(row.generation, before.generation);
  assertEquals(row.external_id, "G-UAT");
  assertEquals(row.artifact, before.artifact);
  assertEquals(s.rows.size, 1);
  assertEquals(net.seen, expectedUatGet);
});

Deno.test("R2 retained-ID recovery: a status request without an environment asks the stored UAT endpoint with the UAT token only", async () => {
  const { s, id } = await retainedUat();
  const net = recorder(acknowledged);
  await call(s, net.fetchImpl, statusBody(id));
  assertEquals(net.seen, expectedUatGet);
  assertEquals(
    net.seen.some((q) =>
      q.url.includes("prod.test") || q.auth.includes("prod")
    ),
    false,
  );
});

Deno.test("R3 retained-ID recovery: a status request saying prod cannot redirect recovery away from the stored UAT environment", async () => {
  const { s, id } = await retainedUat();
  const net = recorder(acknowledged);
  await call(s, net.fetchImpl, statusBody(id, { environment: "prod" }));
  assertEquals(net.seen, expectedUatGet);
});

Deno.test("R4 retained-ID recovery: a document rejection on an uncertain row is a verdict beside accepted transport and uploads nothing", async () => {
  const s = new FakeStore();
  s.provider = "it_sdi";
  s.config = {
    base_url: "https://sdi.test",
    login_url: "https://login.test/login",
    username: "u@x.it",
    password: "p",
  };
  s.rows.set("t40", {
    id: "t40",
    key: "k",
    binding: "b",
    workspace_id: WS,
    provider: "it_sdi",
    phase: "uncertain",
    external_id: "u-1",
    detail: "",
    environment: "prod",
    destination: "government",
    format: "fatturaPa",
    receipt: { ...PARTIAL },
    owner: "o",
    generation: 1,
    deadline: 0,
    verdict: {},
    queryError: "",
    resolvedBy: "",
    artifact: {
      bytes: new Uint8Array() as Uint8Array<ArrayBuffer>,
      sha256: "",
      fileName: "",
      mimeType: "",
      receiverScheme: "",
      receiverId: "",
    },
  });
  const before = structuredClone(s.rows.get("t40")!);
  const answers: Record<string, unknown> = {
    "https://login.test/login": { token: "jwt" },
    "https://sdi.test/invoices/u-1": { marking: "rejected" },
    "https://sdi.test/invoices/u-1/notifications": [
      { type: "NS", message: "00404 duplicate" },
    ],
  };
  const net = recorder(() => new Response("{}"));
  const fetchImpl = ((input: string | URL | Request, init?: RequestInit) => {
    const url = String(input instanceof Request ? input.url : input);
    void net.fetchImpl(input, init);
    return Promise.resolve(
      new Response(JSON.stringify(answers[url] ?? {}), { status: 200 }),
    );
  }) as typeof fetch;
  const r = await read(await call(s, fetchImpl, statusBody("t40")));
  const row = s.rows.get("t40")!;
  assertEquals(r.body.phase, "accepted");
  assertEquals(r.body.document_status, "rejected");
  assertEquals(row.phase, "accepted");
  assertEquals((row.verdict as { status?: string }).status, "rejected");
  assertEquals(row.id, before.id);
  assertEquals(row.key, before.key);
  assertEquals(row.binding, before.binding);
  assertEquals(row.generation, before.generation);
  assertEquals(row.artifact, before.artifact);
  assertEquals(s.rows.size, 1);
  // the login POST is allowed; an invoice upload is not
  const uploads = net.seen.filter((q) =>
    q.method === "POST" && !q.url.endsWith("/login")
  );
  assertEquals(uploads.length, 0);
});

for (
  const [name, answer] of [
    ["401", () => new Response("expired token", { status: 401 })],
    ["503", () => new Response("busy", { status: 503 })],
    ["timeout", () => {
      throw new DOMException("timed out", "TimeoutError");
    }],
  ] as [string, () => Response][]
) {
  Deno.test(`R5 retained-ID recovery: a ${name} status query leaves the uncertain row untouched, records the query error and uploads nothing`, async () => {
    const { s, id } = await retainedUat();
    const before = structuredClone(s.rows.get(id)!);
    const net = recorder(answer);
    const r = await read(await call(s, net.fetchImpl, statusBody(id)));
    const row = s.rows.get(id)!;
    assertEquals(r.body.phase, "uncertain");
    assertEquals(r.body.document_status, "unknown");
    assertEquals(row.phase, "uncertain");
    assertEquals(row.external_id, before.external_id);
    assertEquals(row.receipt, before.receipt);
    assertEquals(row.binding, before.binding);
    assertEquals(row.generation, before.generation);
    assertEquals(row.artifact, before.artifact);
    assertEquals(row.verdict, {});
    assertEquals(row.queryError !== "", true);
    assertEquals(s.rows.size, 1);
    assertEquals(net.seen, expectedUatGet);
    assertEquals(net.seen.filter((q) => q.method === "POST").length, 0);
  });
}

Deno.test("R6 retained-ID recovery: an uncertain Peppol row WITHOUT an id says lookup unavailable, makes no provider call and invents no identifier", async () => {
  const { s, id } = await retainedUat("");
  const before = structuredClone(s.rows.get(id)!);
  const net = recorder(acknowledged);
  for (let i = 0; i < 2; i++) {
    const r = await read(await call(s, net.fetchImpl, statusBody(id)));
    assertEquals(r.body.phase, "uncertain");
    assertEquals(r.body.lookup, "unavailable");
  }
  assertEquals(net.seen.length, 0);
  assertEquals(s.rows.get(id), before);
  assertEquals(s.rows.size, 1);
});

Deno.test("R7 retained-ID recovery: after the lookup settles the row, sending the same transmission again answers it and uploads nothing", async () => {
  const { s, id } = await retainedUat();
  const net = recorder(acknowledged);
  await call(s, net.fetchImpl, statusBody(id));
  const settled = structuredClone(s.rows.get(id)!);
  assertEquals(settled.phase, "accepted");
  const sendNet = recorder(ok);
  const again = await read(
    await call(
      s,
      sendNet.fetchImpl,
      bodyOf({
        format: "peppolBis",
        receiver_scheme: "0208",
        receiver_id: "0202239951",
        environment: "uat",
      }),
    ),
  );
  assertEquals(again.body.phase, "accepted");
  assertEquals(again.body.external_id, "G-UAT");
  assertEquals(again.body.transmission_id, id);
  assertEquals(sendNet.seen.length, 0);
  assertEquals(s.rows.size, 1);
  assertEquals(s.rows.get(id), settled);
});

// #3883 -- a sandbox test document of the national channel: sent by whoever
// manages the integrations, to the sandbox only, one at a time.
function sdiTestStore() {
  const s = new FakeStore();
  s.provider = "it_sdi";
  s.config = {
    base_url: "https://live.sdi.test",
    login_url: "https://live.login.test/login",
    username: "live",
    password: "live",
    base_url_uat: "https://api-sandbox.acubeapi.com",
    login_url_uat: "https://common-sandbox.api.acubeapi.com/login",
    username_uat: "u",
    password_uat: "p",
  };
  s.member_ = { id: "m2", is_admin: false, is_owner: false, status: "active" };
  s.grants.add("manageIntegrations");
  return s;
}
const sdiAnswer = () =>
  new Response(JSON.stringify({ token: "jwt", uuid: "u-test" }), {
    status: 200,
  });
const testBody = {
  workspace_id: WS,
  action: "test",
  content_base64: btoa("<FatturaElettronica>TEST</FatturaElettronica>"),
  file_name: "TEST-1.xml",
  mime_type: "application/xml",
  format: "fatturaPa",
};

Deno.test("#3883 whoever manages the integrations sends a test document to the sandbox, with no invoice", async () => {
  const s = sdiTestStore();
  const p = provider(sdiAnswer);
  const r = await read(await call(s, p.fetchImpl, testBody));
  assertEquals(r.status, 200);
  const row = [...s.rows.values()][0];
  assertEquals([row.kind, row.environment, row.destination], ["test", "uat", "government"]);
  assertEquals(row.phase, "accepted");
  assertEquals(p.posts.filter((u) => u.endsWith("/invoices")), [
    "https://api-sandbox.acubeapi.com/invoices",
  ]);
  assertEquals(p.posts.some((u) => u.includes("live.")), false);
});

Deno.test("#3883 the right to issue invoices does not send a test document", async () => {
  const s = sdiTestStore();
  s.grants.clear();
  s.grants.add("issueInvoices");
  const p = provider(sdiAnswer);
  const r = await read(await call(s, p.fetchImpl, testBody));
  assertEquals(r.status, 403);
  assertEquals(s.rows.size, 0);
  assertEquals(p.posts.length, 0);
});

Deno.test("#3883 a missing sandbox field refuses the test; the live one is never used instead", async () => {
  const s = sdiTestStore();
  delete s.config.password_uat;
  const p = provider(sdiAnswer);
  const r = await read(await call(s, p.fetchImpl, testBody));
  assertEquals(r.status, 409);
  assertEquals(r.body.error, "sandbox_credentials_missing");
  assertEquals(r.body.missing, ["password"]);
  assertEquals(s.rows.size, 0);
  assertEquals(p.posts.length, 0);
});

Deno.test("#3883 a connector whose verdict opens no gate takes no test document", async () => {
  const s = sdiTestStore();
  s.provider = "peppol";
  const p = provider(sdiAnswer);
  const r = await read(await call(s, p.fetchImpl, testBody));
  assertEquals(r.status, 409);
  assertEquals(r.body.error, "test_unavailable");
  assertEquals(p.posts.length, 0);
});

Deno.test("#3883 a second test waits for the first one's verdict, with a sentence", async () => {
  const s = sdiTestStore();
  const p = provider(sdiAnswer);
  await call(s, p.fetchImpl, testBody);
  const second = await read(await call(s, p.fetchImpl, testBody));
  assertEquals(second.status, 409);
  assertEquals(second.body.error, "test_pending");
  assertEquals(typeof second.body.detail, "string");
  assertEquals(p.posts.filter((u) => u.endsWith("/invoices")).length, 1);
});

Deno.test("#3883 a rejected test is sent again", async () => {
  const s = sdiTestStore();
  const p = provider(sdiAnswer);
  await call(s, p.fetchImpl, testBody);
  const first = [...s.rows.values()][0];
  first.verdict = { status: "rejected" };
  const again = await read(await call(s, p.fetchImpl, testBody));
  assertEquals(again.status, 200);
  assertEquals(s.rows.size, 2);
});

Deno.test("#3883 whoever manages the integrations asks about a test, not about an invoice's transmission", async () => {
  const s = sdiTestStore();
  const p = provider(sdiAnswer);
  await call(s, p.fetchImpl, testBody);
  const test = [...s.rows.values()][0];
  test.external_id = "u-test";
  const asked = await read(
    await call(s, p.fetchImpl, { workspace_id: WS, action: "status", transmission_id: test.id }),
  );
  assertEquals(asked.status, 200);
  s.rows.set("inv-t", { ...test, id: "inv-t", kind: "invoice" });
  const refused = await read(
    await call(s, p.fetchImpl, { workspace_id: WS, action: "status", transmission_id: "inv-t" }),
  );
  assertEquals(refused.status, 403);
});

Deno.test("#3883 a test goes only to the connector's documented sandbox", async () => {
  const s = sdiTestStore();
  s.config.base_url_uat = "https://elsewhere.test";
  const p = provider(sdiAnswer);
  const r = await read(await call(s, p.fetchImpl, testBody));
  assertEquals(r.status, 409);
  assertEquals(r.body.error, "sandbox_not_documented");
  assertEquals(s.rows.size, 0);
  assertEquals(p.posts.length, 0);
});

Deno.test("#3883 a test's verdict is read from the documented sandbox only", async () => {
  const s = sdiTestStore();
  const p = provider(sdiAnswer);
  await call(s, p.fetchImpl, testBody);
  const test = [...s.rows.values()][0];
  test.external_id = "u-test";
  s.config.base_url_uat = "https://elsewhere.test";
  const asked = await read(
    await call(s, p.fetchImpl, { workspace_id: WS, action: "status", transmission_id: test.id }),
  );
  assertEquals(asked.status, 409);
  assertEquals(asked.body.error, "sandbox_not_documented");
  assertEquals(test.verdict, {});
});
