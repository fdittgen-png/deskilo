// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3917 -- an in-memory stand-in for the service client the payment webhooks
// use: payment_intents rows the queries really filter (eq, in, like
// 'prefix%') and update, the stored credentials, and every rpc recorded with
// its arguments, so a test sees which order id was written and settled.
// `afterRead` runs once after read number `afterReadAt` (1 by default) of
// payment_intents: the place a test puts the order request's own late write.
// `readError` makes every read of payment_intents fail.

type Row = Record<string, unknown>;

export type IntentsFake = {
  rows: Row[];
  rpcCalls: Array<{ name: string; args: Row }>;
  reads: number;
  // deno-lint-ignore no-explicit-any
  admin: any;
};

export function intentsFake(opts: {
  rows: Row[];
  credentials: Row;
  afterRead?: (rows: Row[]) => void;
  afterReadAt?: number;
  readError?: boolean;
  rpcErrors?: Record<string, string>;
}): IntentsFake {
  const fake: IntentsFake = {
    rows: opts.rows,
    rpcCalls: [],
    reads: 0,
    admin: null,
  };
  let lateWriteDone = false;
  fake.admin = {
    from(table: string) {
      const filters: Array<(r: Row) => boolean> = [];
      let update: Row | null = null;
      let selected = false;
      const matching = () =>
        fake.rows.filter((r) => filters.every((f) => f(r)));
      const run = () => {
        if (table === "payment_credentials") {
          return { data: { config: opts.credentials }, error: null };
        }
        if (update) {
          const hit = matching();
          for (const r of hit) Object.assign(r, update);
          return {
            data: selected ? hit.map((r) => ({ ...r })) : null,
            error: null,
          };
        }
        fake.reads++;
        if (opts.readError) {
          return { data: null, error: { message: "read failed" } };
        }
        const hit = matching();
        if (
          fake.reads === (opts.afterReadAt ?? 1) && opts.afterRead &&
          !lateWriteDone
        ) {
          lateWriteDone = true;
          opts.afterRead(fake.rows);
        }
        return { data: hit.length ? { ...hit[0] } : null, error: null };
      };
      const chain = {
        select: () => {
          if (update) selected = true;
          return chain;
        },
        update: (values: Row) => {
          update = values;
          return chain;
        },
        eq: (c: string, v: unknown) => {
          filters.push((r) => r[c] === v);
          return chain;
        },
        in: (c: string, v: unknown[]) => {
          filters.push((r) => v.includes(r[c]));
          return chain;
        },
        like: (c: string, pattern: string) => {
          const prefix = pattern.replace(/%$/, "");
          filters.push((r) => String(r[c] ?? "").startsWith(prefix));
          return chain;
        },
        maybeSingle: () => Promise.resolve(run()),
        then: (
          resolve: (v: unknown) => unknown,
          reject?: (e: unknown) => unknown,
        ) => Promise.resolve(run()).then(resolve, reject),
      };
      return chain;
    },
    rpc(name: string, args: Row) {
      fake.rpcCalls.push({ name, args });
      const message = opts.rpcErrors?.[name];
      return Promise.resolve({
        data: null,
        error: message ? { message } : null,
      });
    },
  };
  return fake;
}
