// SPDX-License-Identifier: AGPL-3.0-or-later
//
// send-e-invoice -- the actions of the handler (#4400), by the name a client
// sends in `action`. A request that names none is a send. `live` says that the
// action talks to the outside world: a development workspace refuses it and an
// overdue dispatch is settled before it runs.

import type { Action } from "../common.ts";
import { config } from "./config.ts";
import { resolve } from "./resolve.ts";
import { send } from "./send.ts";
import { status } from "./status.ts";
import { test } from "./test.ts";
import { test_state } from "./test_state.ts";

export interface Registered {
  run: Action;
  live: boolean;
  /** a sandbox test document: asked about by whoever manages the integrations (#3883) */
  manage: boolean;
}

export const SEND: Registered = { run: send, live: true, manage: false };

export const ACTIONS: Record<string, Registered> = {
  config: { run: config, live: false, manage: false },
  test_state: { run: test_state, live: true, manage: true },
  test: { run: test, live: true, manage: true },
  status: { run: status, live: true, manage: true },
  resolve: { run: resolve, live: true, manage: false },
};

/** The action a request names; a name the table does not hold (and no member of Object.prototype) is a send. */
export function actionFor(name: string | undefined): Registered {
  return name !== undefined && Object.hasOwn(ACTIONS, name) ? ACTIONS[name] : SEND;
}
