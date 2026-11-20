// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3932 -- what the AEAT's answer to a Verifactu submission says about the
// record. The answer is the SOAP `RespuestaRegFactuSistemaFacturacion` of the
// reviewed contract (SuministroInformacion / RespuestaSuministro): one
// `EstadoEnvio` for the whole submission and one `RespuestaLinea` with an
// `EstadoRegistro` for each record in it.
//
// A test submission carries exactly one record, and only the platform's own
// clean acceptance of that record decides it: `EstadoEnvio` Correcto and its
// one line Correcto. A record the AEAT refused (Incorrecto) refuses it. Every
// other answer is no verdict yet -- including AceptadoConErrores and
// ParcialmenteCorrecto (the record was kept with errors: not a clean
// acceptance, and for the owner to read), a missing or another state, a SOAP
// fault, a successful HTTP answer of another shape, and a answer for another
// number of records. The reader never throws: an unreadable answer is unknown.

export type VerifactuVerdict = "accepted" | "rejected" | "unknown";

export interface VerifactuLine {
  state: string;
  code: string;
  description: string;
}

export interface VerifactuOutcome {
  verdict: VerifactuVerdict;
  /** Why, in a sentence a person can read. */
  reason: string;
  /** The submission's state as the answer named it ("" when it did not). */
  submissionState: string;
  lines: VerifactuLine[];
  /** The secure verification code of the answer, when it carried one. */
  csv: string;
}

/** The states the reviewed contract names. */
export const VERIFACTU_STATES = {
  submission: {
    accepted: "Correcto",
    partial: "ParcialmenteCorrecto",
    refused: "Incorrecto",
  },
  record: {
    accepted: "Correcto",
    withErrors: "AceptadoConErrores",
    refused: "Incorrecto",
  },
} as const;

const element = (xml: string, name: string): string => {
  const found = new RegExp(
    `<(?:[\\w.-]+:)?${name}\\b[^>]*>([^<]*)</(?:[\\w.-]+:)?${name}>`,
  ).exec(xml)?.[1];
  return found === undefined ? "" : found.trim();
};

const blocks = (xml: string, name: string): string[] =>
  [...xml.matchAll(
    new RegExp(
      `<(?:[\\w.-]+:)?${name}\\b[^>]*>[\\s\\S]*?</(?:[\\w.-]+:)?${name}>`,
      "g",
    ),
  )].map((m) => m[0]);

const unknown = (
  reason: string,
  extra: Partial<VerifactuOutcome> = {},
): VerifactuOutcome => ({
  verdict: "unknown",
  reason,
  submissionState: "",
  lines: [],
  csv: "",
  ...extra,
});

/** Reads the AEAT's answer to a submission of ONE record. */
export function readVerifactuResponse(xml: string): VerifactuOutcome {
  if (typeof xml !== "string" || xml.trim() === "") {
    return unknown("the answer is empty");
  }
  const submissionState = element(xml, "EstadoEnvio");
  const csv = element(xml, "CSV");
  const lines: VerifactuLine[] = blocks(xml, "RespuestaLinea").map((b) => ({
    state: element(b, "EstadoRegistro"),
    code: element(b, "CodigoErrorRegistro"),
    description: element(b, "DescripcionErrorRegistro"),
  }));
  const read = { submissionState, lines, csv };
  if (/<(?:[\w.-]+:)?Fault\b/.test(xml) && submissionState === "") {
    return unknown("the exchange answered with a fault, not a verdict", read);
  }
  if (submissionState === "") {
    return unknown("the answer names no submission state", read);
  }
  if (lines.length !== 1) {
    return unknown(
      `the answer holds ${lines.length} records for a submission of one`,
      read,
    );
  }
  const [line] = lines;
  const { submission, record } = VERIFACTU_STATES;
  if (line.state === record.refused) {
    return {
      verdict: "rejected",
      reason: line.description || "the AEAT refused the record",
      ...read,
    };
  }
  if (
    submissionState === submission.accepted && line.state === record.accepted
  ) {
    return {
      verdict: "accepted",
      reason: "the AEAT accepted the record",
      ...read,
    };
  }
  if (
    line.state === record.withErrors || submissionState === submission.partial
  ) {
    return unknown(
      "the AEAT kept the record with errors: not a clean acceptance",
      read,
    );
  }
  return unknown(
    "the answer's states are not an outcome of the contract",
    read,
  );
}
