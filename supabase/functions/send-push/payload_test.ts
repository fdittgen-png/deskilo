// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2559 C2 -- XPRIV-payload: what a push shows and carries. The records it
// is about hold an amount, a message, a contact and a token (sentinels);
// none of them reaches the visible text or the data of any message FCM is
// asked to deliver. The text is generic per kind in the recipient's own
// language; the data is the qualified reference (installation, workspace,
// record kind and id) and nothing else. The required notification is still
// delivered.
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  buildMessage,
  cachedAccessToken,
  handle,
  notificationText,
  recipientLocale,
  referenceData,
  resetTokenCacheForTests,
} from "./index.ts";

const SENTINELS = [
  "SENTINEL-AMOUNT-4242",
  "SENTINEL-MESSAGE-BODY",
  "SENTINEL-CONTACT@example.org",
  "SENTINEL-TOKEN-abc123",
  "Alice Sentinel",
];

type Row = Record<string, unknown>;

/** A read-only stand-in for the service-role client: filters rows by the
 * calls the function makes; deletes and rpc answer empty. */
function fakeSupabase(tables: Record<string, Row[]>) {
  // deno-lint-ignore no-explicit-any
  const query = (table: string): any => {
    let rows = [...(tables[table] ?? [])];
    let head = false;
    const chain = {
      select: (_cols: string, opts?: { head?: boolean }) => {
        head = opts?.head === true;
        return chain;
      },
      eq: (c: string, v: unknown) => {
        rows = rows.filter((r) => r[c] === v);
        return chain;
      },
      neq: (c: string, v: unknown) => {
        rows = rows.filter((r) => r[c] !== v);
        return chain;
      },
      is: (c: string, v: unknown) => {
        rows = rows.filter((r) => (r[c] ?? null) === v);
        return chain;
      },
      in: (c: string, vs: unknown[]) => {
        rows = rows.filter((r) => vs.includes(r[c]));
        return chain;
      },
      like: (c: string, p: string) => {
        const prefix = p.replace(/%$/, "");
        rows = rows.filter((r) => String(r[c]).startsWith(prefix));
        return chain;
      },
      order: () => chain,
      limit: () => chain,
      range: (from: number, to: number) =>
        Promise.resolve({ data: rows.slice(from, to + 1), error: null }),
      maybeSingle: () =>
        Promise.resolve({ data: rows[0] ?? null, error: null }),
      delete: () => chain,
      then: (resolve: (v: unknown) => unknown) =>
        resolve(
          head
            ? { count: rows.length, error: null }
            : { data: rows, error: null },
        ),
    };
    return chain;
  };
  return {
    from: query,
    rpc: () => Promise.resolve({ data: [], error: null }),
  };
}

const INSTALLATION = "11111111-1111-4111-8111-111111111111";
const WORKSPACE = "22222222-2222-4222-8222-222222222222";

function tables(): Record<string, Row[]> {
  return {
    installation_identity: [{ installation_id: INSTALLATION }],
    workspaces: [{
      id: WORKSPACE,
      default_locale: "de",
      name: "Alice Sentinel",
    }],
    members: [
      {
        id: "m-actor",
        workspace_id: WORKSPACE,
        status: "active",
        is_admin: false,
        is_owner: false,
        user_id: "u-actor",
        preferred_locale_override: null,
        email: "SENTINEL-CONTACT@example.org",
      },
      {
        id: "m-fr",
        workspace_id: WORKSPACE,
        status: "active",
        is_admin: true,
        is_owner: false,
        user_id: "u-fr",
        preferred_locale_override: null,
        email: "SENTINEL-CONTACT@example.org",
      },
      {
        id: "m-it",
        workspace_id: WORKSPACE,
        status: "active",
        is_admin: false,
        is_owner: false,
        user_id: "u-it",
        preferred_locale_override: "it",
      },
    ],
    profiles: [
      { id: "u-fr", preferred_locale: "fr", full_name: "Alice Sentinel" },
      { id: "u-it", preferred_locale: "en" },
    ],
    events: [
      {
        id: "ev-1",
        workspace_id: WORKSPACE,
        type: "invoice_reminder",
        action: "sent",
        status: "done",
        actor_member_id: "m-actor",
        subject_member_id: "m-it",
        payload: {
          amount: "SENTINEL-AMOUNT-4242",
          note: "SENTINEL-MESSAGE-BODY",
        },
      },
      {
        id: "ev-2",
        workspace_id: WORKSPACE,
        type: "reservation",
        action: "cancelled",
        status: "done",
        actor_member_id: "m-actor",
        subject_member_id: "m-it",
        payload: { place: "Alice Sentinel's desk" },
      },
    ],
    member_notes: [
      {
        id: "note-1",
        workspace_id: WORKSPACE,
        from_member_id: "m-actor",
        to_member_id: "m-fr",
        conversation_id: null,
        body: "SENTINEL-MESSAGE-BODY SENTINEL-AMOUNT-4242",
      },
    ],
    push_endpoints: [
      { member_id: "m-fr", endpoint: "fcm:device-fr" },
      { member_id: "m-it", endpoint: "fcm:device-it" },
      { member_id: "m-actor", endpoint: "fcm:device-actor" },
    ],
  };
}

const SA = {
  client_email: "push@example.iam.gserviceaccount.com",
  private_key: "-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----",
  project_id: "demo-project",
};

/** Runs the real handler with FCM stubbed; returns every message sent. */
async function run(body: Record<string, string>) {
  resetTokenCacheForTests();
  await cachedAccessToken(SA, () => Promise.resolve("oauth-token"));
  Deno.env.set("FCM_SERVICE_ACCOUNT", JSON.stringify(SA));
  const sent: { message: Record<string, unknown> }[] = [];
  const original = globalThis.fetch;
  globalThis.fetch = ((_url: string, init?: RequestInit) => {
    sent.push(JSON.parse(String(init?.body)));
    return Promise.resolve(Response.json({ name: "ok" }));
  }) as typeof fetch;
  try {
    const res = await handle(
      new Request("http://localhost/send-push", {
        method: "POST",
        body: JSON.stringify(body),
      }),
      // deno-lint-ignore no-explicit-any
      fakeSupabase(tables()) as any,
    );
    return { res: await res.json(), sent };
  } finally {
    globalThis.fetch = original;
    Deno.env.delete("FCM_SERVICE_ACCOUNT");
  }
}

function only(sent: { message: Record<string, unknown> }[]) {
  assertEquals(sent.length, 1);
  return sent[0].message;
}

function assertNoSentinel(sent: unknown) {
  const raw = JSON.stringify(sent);
  for (const s of SENTINELS) {
    assert(!raw.includes(s), `a delivered message carries ${s}`);
  }
}

const ALLOWED_DATA_KEYS = [
  "inst",
  "kind",
  "ref_id",
  "ref_kind",
  "src",
  "v",
  "ws",
];

Deno.test("a direct message rings its recipient with generic text in their language and a qualified reference", async () => {
  const { res, sent } = await run({ note_id: "note-1" });
  assertEquals(res.sent, 1);
  const message = only(sent);
  assertEquals(message.notification, {
    title: "DesKilo",
    body: "Vous avez un nouveau message.",
  });
  assertEquals(message.data, {
    v: "1",
    kind: "member_note",
    src: "w",
    inst: INSTALLATION,
    ws: WORKSPACE,
    ref_kind: "note",
    ref_id: "note-1",
  });
  assertNoSentinel(sent);
});

Deno.test("a payment reminder names no amount; the member's own language override wins", async () => {
  const { res, sent } = await run({ event_id: "ev-1" });
  assertEquals(res.sent, 1);
  const message = only(sent);
  assertEquals(message.token, "device-it");
  assertEquals(message.notification, {
    title: "DesKilo",
    body: "La attende un promemoria di pagamento.",
  });
  assertEquals((message.data as Record<string, string>).ref_kind, "event");
  assertEquals((message.data as Record<string, string>).ref_id, "ev-1");
  assertNoSentinel(sent);
});

Deno.test("a removed reservation reaches the subject and the admins with the same generic title, never the actor", async () => {
  const { res, sent } = await run({ event_id: "ev-2" });
  assertEquals(res.sent, 2);
  assertEquals(sent.map((s) => s.message.token).sort(), [
    "device-fr",
    "device-it",
  ]);
  for (const { message } of sent) {
    assertEquals((message.notification as { title: string }).title, "DesKilo");
    assertEquals(Object.keys(message.data as object).sort(), ALLOWED_DATA_KEYS);
    for (const v of Object.values(message.data as Record<string, unknown>)) {
      assertEquals(typeof v, "string");
    }
  }
  assertNoSentinel(sent);
});

Deno.test("an unknown kind still rings, with the generic update line", () => {
  assertEquals(notificationText("some_future_kind", "es"), {
    title: "DesKilo",
    body: "Tiene una novedad.",
  });
  assertEquals(notificationText("pending_request", "de").title, "DesKilo");
});

Deno.test("language: override, then profile, then workspace, then English", () => {
  assertEquals(recipientLocale("it", "fr", "de"), "it");
  assertEquals(recipientLocale(null, "fr-FR", "de"), "fr");
  assertEquals(recipientLocale("", "", "DE"), "de");
  assertEquals(recipientLocale("pt", "", null), "en");
});

Deno.test("an unreadable installation id leaves no reference, never a partial one", () => {
  assertEquals(referenceData("member_note", null), {
    v: "1",
    kind: "member_note",
  });
  const built = buildMessage({
    token: "t",
    kind: "member_note",
    locale: "en",
    reference: null,
  });
  assertEquals(Object.keys(built.message).sort(), [
    "data",
    "notification",
    "token",
  ]);
});
