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
  hasPermission() {
    return Promise.resolve(this.permission);
  }
  credentials() {
    return Promise.resolve({ provider: this.provider, config: this.config });
  }
  workspaceEnvironment() {
    return Promise.resolve(this.wsEnv);
  }
  invoice(id: string) {
    return Promise.resolve(
      id === INV ? { id, number: "F-1", workspace_id: WS } : null,
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
    if (phase) {
      r.phase = phase;
      r.external_id = externalId || r.external_id;
    }
    if (
      receipt && !(r.phase === "accepted" && Object.keys(r.receipt).length > 0)
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
  assertEquals(
    (await resolve({ outcome: "failed", reason: "r", evidence: "e" })).status,
    403,
  );
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
