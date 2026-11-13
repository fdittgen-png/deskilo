// SPDX-License-Identifier: AGPL-3.0-or-later
//
// it_sdi — the Italian Sistema di Interscambio through an accredited
// intermediary's API, in the shape of the A-Cube "Italy e-invoicing"
// API (login on common.api.acubeapi.com, POST /invoices with the
// FatturaPA XML, GET /invoices/{uuid} and its notifications): the
// intermediary signs and transmits to the SdI and relays its
// notifications (RC ricevuta di consegna, NS notifica di scarto, MC
// mancata consegna, …).
//
// The live round-trip needs the sandbox account the owner creates with
// the intermediary; nothing here has been exchanged with one yet.

import {
  accepted,
  Config,
  Connector,
  ConnectorDocument,
  Fetch,
  join,
  noVerdictYet,
  parseJson,
  refused,
  Submission,
} from "./common.ts";

export async function login(
  cfg: Config,
  fetchImpl: Fetch,
): Promise<string | Response> {
  const res = await fetchImpl(cfg.login_url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: cfg.username, password: cfg.password }),
  });
  if (!res.ok) return res;
  const token = parseJson(await res.text()).token;
  return typeof token === "string" ? token : res;
}

export async function submitItSdi(
  cfg: Config,
  doc: ConnectorDocument,
  fetchImpl: Fetch,
): Promise<Submission> {
  const token = await login(cfg, fetchImpl);
  if (token instanceof Response) return refused(token);
  doc.onDispatch?.();
  const res = await fetchImpl(join(cfg.base_url, "invoices"), {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/xml",
      "Accept": "application/json",
    },
    body: doc.bytes,
  });
  if (!res.ok) return refused(res);
  const text = await res.text();
  const uuid = String(parseJson(text).uuid ?? "");
  return accepted(uuid, text, { uuid });
}

/** #3881 -- the SdI notifications that decide the document, and how: NS
 * refuses it; RC delivers it; MC (not delivered, made available to the
 * buyer in its fiscal drawer) and AT (the same for a public administration)
 * count it as issued. Any other notification (MT, EC, SE, NE, DT) follows an
 * outcome or is no outcome. */
export const SDI_OUTCOMES: Readonly<Record<string, "accepted" | "rejected">> = {
  NS: "rejected",
  RC: "accepted",
  MC: "accepted",
  AT: "accepted",
};

/** The SdI notifications the intermediary relayed. The SdI's outcome
 * notification is the verdict ([SDI_OUTCOMES]); before it, there is none. */
export async function statusItSdi(
  cfg: Config,
  uuid: string,
  fetchImpl: Fetch,
): Promise<Submission> {
  const token = await login(cfg, fetchImpl);
  if (token instanceof Response) return refused(token);
  const headers = {
    "Authorization": `Bearer ${token}`,
    "Accept": "application/json",
  };
  const id = encodeURIComponent(uuid);
  const res = await fetchImpl(join(cfg.base_url, `invoices/${id}`), {
    method: "GET",
    headers,
  });
  if (!res.ok) return refused(res);
  const invoice = parseJson(await res.text());
  const notes = await fetchImpl(
    join(cfg.base_url, `invoices/${id}/notifications`),
    { method: "GET", headers },
  );
  if (!notes.ok) return refused(notes);
  const notesText = await notes.text();
  let notifications: Array<Record<string, unknown>> = [];
  try {
    const parsed = JSON.parse(notesText);
    notifications = Array.isArray(parsed)
      ? parsed
      : Array.isArray(parsed?.["hydra:member"])
      ? parsed["hydra:member"]
      : [];
  } catch {
    notifications = [];
  }
  const type = notifications
    .map((n) => String(n?.type ?? ""))
    .find((t) => Object.hasOwn(SDI_OUTCOMES, t));
  const outcome = type === undefined ? undefined : SDI_OUTCOMES[type];
  if (outcome === undefined) {
    return noVerdictYet(uuid, notesText, {
      uuid,
      marking: invoice.marking ?? "",
      notifications,
    });
  }
  if (outcome === "rejected") {
    return {
      status: "rejected",
      externalId: uuid,
      detail: notesText.slice(0, 500),
      receipt: { uuid, marking: invoice.marking ?? "", notifications },
    };
  }
  return accepted(uuid, notesText, {
    uuid,
    marking: invoice.marking ?? "",
    notifications,
  });
}

/** The it_sdi connector record (#3337). */
export const itSdiConnector: Connector = {
  id: "it_sdi",
  requiredFields: ["base_url", "login_url", "username", "password"],
  acceptedFormats: ["fatturaPa"],
  sandbox: {
    base_url: "https://api-sandbox.acubeapi.com",
    login_url: "https://common-sandbox.api.acubeapi.com/login",
  },
  submit: submitItSdi,
  status: statusItSdi,
  testDocument: true,
};
