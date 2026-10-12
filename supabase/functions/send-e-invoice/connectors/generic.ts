// SPDX-License-Identifier: AGPL-3.0-or-later
//
// generic — any platform that accepts an HTTP upload with a bearer or
// basic credential: the adapter every workspace used before the named
// connectors (0071). Its behaviour is unchanged: multipart POST, the file
// under `field_name` (default `file`), the credential under `auth_header`
// (default `Authorization`), the platform's id read from the usual names.

import {
  accepted,
  Config,
  ConnectorDocument,
  Fetch,
  refused,
  Submission,
} from "./common.ts";

export async function submitGeneric(
  cfg: Config,
  doc: ConnectorDocument,
  fetchImpl: Fetch,
): Promise<Submission> {
  const form = new FormData();
  form.append(
    cfg.field_name || "file",
    new Blob([doc.bytes], { type: doc.mimeType }),
    doc.fileName,
  );
  const res = await fetchImpl(cfg.endpoint, {
    method: "POST",
    headers: { [cfg.auth_header || "Authorization"]: cfg.auth_value },
    body: form,
  });
  if (!res.ok) return refused(res);
  const text = await res.text();
  // Most platforms answer JSON with an id under one of these names.
  let externalId = "";
  try {
    const body = JSON.parse(text);
    externalId = String(
      body.id ?? body.documentId ?? body.document_id ?? body.guid ??
        body.transmissionId ?? "",
    );
  } catch {
    // A plain-text acknowledgement is still an acknowledgement.
    externalId = text.trim().slice(0, 120);
  }
  return accepted(externalId, text);
}
