// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2863 — what VIES answers becomes the neutral contract with two separate
// verdicts, every failure class is its own outcome, nothing undisclosed is
// invented, and the handler's own checks (shape, size, rate) refuse before
// anything leaves.
import { assertEquals } from "jsr:@std/assert@1";
import { askVies, splitAddress, VIES_MAX_RESPONSE_BYTES } from "./vies.ts";
import { handle, MAX_BODY_BYTES, parseLookupRequest, RateLimiter } from "./index.ts";

const request = {
  country_code: "FR",
  identifier: "11223344556",
  kind: "vat" as const,
  mode: "identifier" as const,
};
const at = () => new Date("2026-05-13T08:00:00Z");
const ask = (r: typeof request, fetcher: typeof fetch, timeoutMs = 1000) =>
  askVies(r, { timeoutMs, fetcher, now: at });

const answering = (status: number, body: unknown, seen?: unknown[]) =>
  ((_url: string | URL | Request, init?: RequestInit) => {
    seen?.push(JSON.parse(String(init?.body)));
    return Promise.resolve(new Response(JSON.stringify(body), { status }));
  }) as typeof fetch;

Deno.test("a valid number with a disclosed profile is retrieved and validated", async () => {
  const seen: unknown[] = [];
  const result = await ask(request, answering(200, {
    valid: true,
    requestIdentifier: "WAPIAAAAZ1",
    name: "ATELIER DES ARCEAUX SAS",
    address: "7 RUE DES ARCEAUX\n34000 MONTPELLIER",
  }, seen));
  assertEquals(seen[0], { countryCode: "FR", vatNumber: "11223344556" });
  assertEquals(result, {
    provider: "vies",
    looked_up_at: "2026-05-13T08:00:00.000Z",
    retrieval: "retrieved",
    validation: "validated",
    fields: {
      country_code: "FR",
      name: "ATELIER DES ARCEAUX SAS",
      street: "7 RUE DES ARCEAUX",
      postal_code: "34000",
      city: "MONTPELLIER",
    },
    reference: "WAPIAAAAZ1",
    detail: "",
  });
});

Deno.test("a member state that discloses nothing validates and returns no profile", async () => {
  const result = await ask(
    { ...request, country_code: "DE", identifier: "123456789" },
    answering(200, { valid: true, requestIdentifier: "", name: "---", address: "---" }),
  );
  assertEquals(result.retrieval, "not_returned");
  assertEquals(result.validation, "validated");
  assertEquals(result.fields, { country_code: "DE" });
});

Deno.test("an invalid number is a verdict on the identifier, not an outage", async () => {
  const result = await ask(request, answering(200, { valid: false, requestIdentifier: "" }));
  assertEquals(result.retrieval, "not_found");
  assertEquals(result.validation, "invalid");
  assertEquals(result.fields, {});
});

Deno.test("each VIES error code is its own outcome", async () => {
  const cases: [string, string, string][] = [
    ["INVALID_INPUT", "invalid_input", "not_validated"],
    ["MS_UNAVAILABLE", "unavailable", "unavailable"],
    ["SERVICE_UNAVAILABLE", "unavailable", "unavailable"],
    ["MS_MAX_CONCURRENT_REQ", "throttled", "unavailable"],
    ["GLOBAL_MAX_CONCURRENT_REQ", "throttled", "unavailable"],
    ["TIMEOUT", "timeout", "unavailable"],
  ];
  for (const [error, retrieval, validation] of cases) {
    const result = await ask(request, answering(200, {
      actionSucceed: false,
      errorWrappers: [{ error }],
    }));
    assertEquals([result.retrieval, result.validation, result.detail], [retrieval, validation, error]);
  }
});

Deno.test("no answer, a timeout and an unreadable answer are told apart", async () => {
  const down = await ask(request, (() => Promise.reject(new Error("down"))) as typeof fetch);
  assertEquals(down.retrieval, "unavailable");
  const aborted = await ask(
    request,
    (() => Promise.reject(new DOMException("aborted", "AbortError"))) as typeof fetch,
  );
  assertEquals(aborted.retrieval, "timeout");
  const garbage = await ask(
    request,
    (() => Promise.resolve(new Response("<html>", { status: 200 }))) as typeof fetch,
  );
  assertEquals(garbage.retrieval, "malformed");
  const huge = await ask(
    request,
    (() =>
      Promise.resolve(
        new Response(JSON.stringify({ valid: true, name: "x".repeat(VIES_MAX_RESPONSE_BYTES) }), {
          status: 200,
        }),
      )) as typeof fetch,
  );
  assertEquals(huge.retrieval, "malformed");
  const http = await ask(request, answering(503, {}));
  assertEquals(http.retrieval, "unavailable");
  const busy = await ask(request, answering(429, {}));
  assertEquals(busy.retrieval, "throttled");
});

Deno.test("an address is split only where its last line reads as postal code and city", () => {
  assertEquals(splitAddress("12 AVENUE DE VERDUN\n34500 BEZIERS"), {
    street: "12 AVENUE DE VERDUN",
    postal_code: "34500",
    city: "BEZIERS",
  });
  assertEquals(splitAddress("KEIZERSGRACHT 1\n1015 AA AMSTERDAM"), {
    street: "KEIZERSGRACHT 1",
    postal_code: "1015 AA",
    city: "AMSTERDAM",
  });
  assertEquals(splitAddress("VIA ROMA 1, ROMA"), { street: "VIA ROMA 1, ROMA" });
  assertEquals(splitAddress("---"), {});
  assertEquals(splitAddress(""), {});
});

Deno.test("the request is checked for shape before anything leaves", () => {
  const ws = "0b8a6a4e-5c2f-4c7b-9d1e-2f3a4b5c6d7e";
  const ok = parseLookupRequest({
    workspace_id: ws,
    provider: "vies",
    kind: "vat",
    mode: "identifier",
    country_code: "fr",
    identifier: " 11 223.344-556 ",
  });
  assertEquals("error" in ok, false);
  if (!("error" in ok)) {
    assertEquals(ok.request, { country_code: "FR", identifier: "11223344556", kind: "vat", mode: "identifier" });
  }
  const refused = (body: unknown) => (parseLookupRequest(body) as { error?: string }).error;
  assertEquals(refused(null), "invalid body");
  assertEquals(refused({ provider: "vies" }), "workspace_id required");
  assertEquals(refused({ workspace_id: ws, provider: "registry-x" }), "unknown provider");
  assertEquals(refused({ workspace_id: ws, provider: "vies", kind: "registration", mode: "identifier" }), "unsupported identifier kind");
  assertEquals(refused({ workspace_id: ws, provider: "vies", kind: "vat", mode: "name" }), "unsupported lookup mode");
  assertEquals(refused({ workspace_id: ws, provider: "vies", kind: "vat", mode: "identifier", country_code: "FRA" }), "country_code must be two letters");
  assertEquals(
    refused({ workspace_id: ws, provider: "vies", kind: "vat", mode: "identifier", country_code: "FR", identifier: "1" }),
    "identifier must be 2-20 letters or digits",
  );
  assertEquals(
    refused({ workspace_id: ws, provider: "vies", kind: "vat", mode: "identifier", country_code: "FR", identifier: "12; drop table" }),
    "identifier must be 2-20 letters or digits",
  );
});

Deno.test("a caller is throttled after the window's quota, and recovers", () => {
  const limiter = new RateLimiter(1000);
  assertEquals(limiter.allow("a", 2, 0), true);
  assertEquals(limiter.allow("a", 2, 10), true);
  assertEquals(limiter.allow("a", 2, 20), false);
  assertEquals(limiter.allow("b", 2, 20), true);
  assertEquals(limiter.allow("a", 2, 1011), true);
  // A quota raised in the settings applies to the next lookup.
  assertEquals(limiter.allow("a", 3, 1012), true);
});

// ── the handler, through a stubbed database and a stubbed registry ──────

const WS = "0b8a6a4e-5c2f-4c7b-9d1e-2f3a4b5c6d7e";
const OTHER_WS = "9f8e7d6c-5b4a-4321-8fed-cba987654321";
const TOKEN = "Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1In0.c2lnbmF0dXJl";

type Rpc = { fn: string; args: Record<string, unknown> };

/** A database that answers as the caller: rights only in [allowedWs],
 * the given settings, and a record of every call. */
function database(opts: {
  allowedWs?: string;
  permission?: boolean;
  suppliers?: boolean;
  verification?: boolean;
  settings?: Record<string, unknown>;
  calls: Rpc[];
  tokens?: string[];
}) {
  const settings = opts.settings ?? {
    "purchase.supplier_lookup_timeout_seconds": 7,
    "purchase.supplier_lookup_per_minute": 20,
  };
  return (authorization: string) => {
    opts.tokens?.push(authorization);
    return {
      rpc(fn: string, args: Record<string, unknown>) {
        opts.calls.push({ fn, args });
        const ws = (args.ws ?? args.p_workspace_id ?? args.p_workspace) as string;
        const mine = ws === (opts.allowedWs ?? WS);
        const answer = (data: unknown) => Promise.resolve({ data, error: null });
        if (fn === "has_permission") return answer(mine && (opts.permission ?? true));
        if (fn === "feature_effective") {
          const on = args.p_key === "supplyExpenses" ? opts.suppliers ?? true : opts.verification ?? true;
          return answer(mine && on);
        }
        if (fn === "setting_value") {
          const v = settings[args.p_key as string];
          return v === undefined
            ? Promise.resolve({ data: null, error: { message: "unknown setting" } })
            : answer(v);
        }
        return Promise.resolve({ data: null, error: { message: `unexpected ${fn}` } });
      },
    };
  };
}

const body = (over: Record<string, unknown> = {}) =>
  JSON.stringify({
    workspace_id: WS,
    provider: "vies",
    kind: "vat",
    mode: "identifier",
    country_code: "FR",
    identifier: "11223344556",
    ...over,
  });

const post = (text: string, headers: Record<string, string> = { Authorization: TOKEN }) =>
  new Request("http://localhost/supplier-lookup", { method: "POST", headers, body: text });

/** Captures console output while [run] runs. */
async function captured(run: () => Promise<void>): Promise<string> {
  const lines: string[] = [];
  const saved = { log: console.log, warn: console.warn, error: console.error };
  const keep = (...a: unknown[]) => lines.push(a.map(String).join(" "));
  console.log = keep;
  console.warn = keep;
  console.error = keep;
  try {
    await run();
  } finally {
    Object.assign(console, saved);
  }
  return lines.join("\n");
}

Deno.test("a lookup asks the registry under the server's wait, and only reads the database", async () => {
  const calls: Rpc[] = [];
  const tokens: string[] = [];
  const seen: unknown[] = [];
  let signal: AbortSignal | undefined;
  const fetcher = ((url: string | URL | Request, init?: RequestInit) => {
    signal = init?.signal ?? undefined;
    return answering(200, {
      valid: true,
      requestIdentifier: "WAPI1",
      name: "ATELIER DES ARCEAUX SAS",
      address: "7 RUE DES ARCEAUX\n34000 MONTPELLIER",
    }, seen)(url, init);
  }) as typeof fetch;
  const response = await handle(post(body()), {
    caller: database({ calls, tokens }),
    limiter: new RateLimiter(),
    fetcher,
    now: at,
  });
  assertEquals(response.status, 200);
  const answer = await response.json();
  assertEquals([answer.retrieval, answer.validation, answer.fields.name], [
    "retrieved",
    "validated",
    "ATELIER DES ARCEAUX SAS",
  ]);
  assertEquals(seen, [{ countryCode: "FR", vatNumber: "11223344556" }]);
  assertEquals(signal instanceof AbortSignal, true);
  // Reads only: no save_supplier, no insert — a lookup creates nothing.
  assertEquals(
    calls.map((c) => c.fn).sort(),
    ["feature_effective", "feature_effective", "has_permission", "setting_value", "setting_value"],
  );
  // Every read names the requested workspace and runs with the caller's own token.
  for (const c of calls) {
    assertEquals(c.args.ws ?? c.args.p_workspace_id ?? c.args.p_workspace, WS);
  }
  assertEquals(tokens, [TOKEN]);
});

Deno.test("the registry's wait is the server's setting", async () => {
  let aborted = false;
  const fetcher = ((_url: string | URL | Request, init?: RequestInit) =>
    new Promise((_resolve, reject) => {
      init?.signal?.addEventListener("abort", () => {
        aborted = true;
        reject(new DOMException("aborted", "AbortError"));
      });
    })) as typeof fetch;
  const started = Date.now();
  let answer: Record<string, unknown> = {};
  await captured(async () => {
    const response = await handle(post(body()), {
      caller: database({
        calls: [],
        settings: {
          "purchase.supplier_lookup_timeout_seconds": 1,
          "purchase.supplier_lookup_per_minute": 20,
        },
      }),
      limiter: new RateLimiter(),
      fetcher,
      now: at,
    });
    answer = await response.json();
  });
  const waited = Date.now() - started;
  assertEquals(aborted, true);
  assertEquals(answer.retrieval, "timeout");
  assertEquals(waited >= 900 && waited < 5000, true, `waited ${waited} ms for a 1 s setting`);
});

Deno.test("a caller without the right, or with the features off, is refused before the registry", async () => {
  const cases: [Parameters<typeof database>[0], string][] = [
    [{ calls: [], permission: false }, "not allowed to manage suppliers"],
    [{ calls: [], suppliers: false }, "supplier management is switched off in this space"],
    [{ calls: [], verification: false }, "vat verification is off in this workspace"],
    // Rights in another workspace never answer for this one.
    [{ calls: [], allowedWs: OTHER_WS }, "not allowed to manage suppliers"],
  ];
  for (const [db, error] of cases) {
    let asked = false;
    const response = await handle(post(body()), {
      caller: database(db),
      limiter: new RateLimiter(),
      fetcher: (() => {
        asked = true;
        return Promise.reject(new Error("must not be asked"));
      }) as typeof fetch,
    });
    assertEquals([response.status, (await response.json()).error, asked], [403, error, false]);
    assertEquals(db.calls.some((c) => c.fn === "setting_value"), false);
  }
});

Deno.test("no token, a delegated token, a malformed or oversized body are refused before any read", async () => {
  const calls: Rpc[] = [];
  const deps = { caller: database({ calls }), limiter: new RateLimiter() };
  assertEquals((await handle(post(body(), {}), deps)).status, 401);
  const delegatedClaims = btoa(JSON.stringify({ sub: "u", client_id: "assistant" }));
  const delegated = await handle(post(body(), { Authorization: `Bearer x.${delegatedClaims}.y` }), deps);
  assertEquals(delegated.status, 403);
  assertEquals((await handle(post("{not json"), deps)).status, 400);
  assertEquals((await handle(post(body({ mode: "name" })), deps)).status, 400);
  assertEquals((await handle(post(body({ kind: "registration" })), deps)).status, 400);
  assertEquals((await handle(post(body({ identifier: "x".repeat(MAX_BODY_BYTES) })), deps)).status, 400);
  assertEquals(calls, []);
});

Deno.test("the quota is the server's setting: over it, the registry is not asked", async () => {
  let asked = 0;
  const deps = {
    caller: database({
      calls: [],
      settings: {
        "purchase.supplier_lookup_timeout_seconds": 5,
        "purchase.supplier_lookup_per_minute": 1,
      },
    }),
    limiter: new RateLimiter(),
    fetcher: ((url: string | URL | Request, init?: RequestInit) => {
      asked++;
      return answering(200, { valid: false })(url, init);
    }) as typeof fetch,
  };
  assertEquals((await handle(post(body()), deps)).status, 200);
  const second = await handle(post(body()), deps);
  assertEquals([second.status, (await second.json()).error, asked], [429, "too many lookups", 1]);
});

Deno.test("without its settings the server makes no call it cannot bound", async () => {
  let asked = false;
  let response = new Response();
  const logs = await captured(async () => {
    response = await handle(post(body()), {
      caller: database({ calls: [], settings: {} }),
      limiter: new RateLimiter(),
      fetcher: (() => {
        asked = true;
        return Promise.reject(new Error("must not be asked"));
      }) as typeof fetch,
    });
  });
  assertEquals([response.status, asked], [503, false]);
  assertEquals(logs.includes("11223344556"), false);
});

Deno.test("an outage answers in neutral words: no token, identifier or upstream body in the answer or the logs", async () => {
  const upstream = "<html>Internal proxy 10.0.0.7 stack trace secret-xyz</html>";
  let text = "";
  const logs = await captured(async () => {
    const response = await handle(post(body()), {
      caller: database({ calls: [] }),
      limiter: new RateLimiter(),
      fetcher: (() => Promise.resolve(new Response(upstream, { status: 502 }))) as typeof fetch,
    });
    text = await response.text();
  });
  const answer = JSON.parse(text);
  assertEquals(answer.retrieval, "malformed");
  for (const secret of ["secret-xyz", "10.0.0.7", TOKEN, "eyJ"]) {
    assertEquals(text.includes(secret), false, `answer leaks ${secret}`);
    assertEquals(logs.includes(secret), false, `logs leak ${secret}`);
  }
  assertEquals(logs.includes("11223344556"), false);
  const down = await captured(async () => {
    const response = await handle(post(body()), {
      caller: database({ calls: [] }),
      limiter: new RateLimiter(),
      fetcher: (() => Promise.reject(new Error(`connect ${upstream}`))) as typeof fetch,
    });
    text = await response.text();
  });
  assertEquals(JSON.parse(text).retrieval, "unavailable");
  assertEquals(text.includes("secret-xyz") || down.includes("secret-xyz"), false);
  assertEquals(down.includes("11223344556"), false);
});
