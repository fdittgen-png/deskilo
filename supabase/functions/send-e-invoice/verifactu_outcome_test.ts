// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3932 -- the AEAT's answer decides the record only through its own clean
// acceptance. The documents are written from the response schema of the
// reviewed contract (not observed from the AEAT: that evidence is NOT RUN).
import { assertEquals } from "jsr:@std/assert@1";
import {
  readVerifactuResponse,
  VERIFACTU_STATES,
} from "./verifactu_outcome.ts";

const envelope = (body: string) =>
  `<?xml version="1.0"?><env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/"><env:Body>${body}</env:Body></env:Envelope>`;
const line = (state: string, code = "", description = "") =>
  `<tikR:RespuestaLinea><tikR:IDFactura><tikLRRC:NumSerieFactura>TEST-1</tikLRRC:NumSerieFactura></tikR:IDFactura>` +
  `<tikR:Operacion><tik:TipoOperacion>Alta</tik:TipoOperacion></tikR:Operacion>` +
  `<tikR:EstadoRegistro>${state}</tikR:EstadoRegistro>` +
  (code ? `<tikR:CodigoErrorRegistro>${code}</tikR:CodigoErrorRegistro>` : "") +
  (description
    ? `<tikR:DescripcionErrorRegistro>${description}</tikR:DescripcionErrorRegistro>`
    : "") +
  `</tikR:RespuestaLinea>`;
const answer = (state: string, lines: string, csv = "CSV-1") =>
  envelope(
    `<tikR:RespuestaRegFactuSistemaFacturacion xmlns:tikR="urn:r">` +
      (csv ? `<tikR:CSV>${csv}</tikR:CSV>` : "") +
      `<tikR:TiempoEsperaEnvio>60</tikR:TiempoEsperaEnvio>` +
      (state ? `<tikR:EstadoEnvio>${state}</tikR:EstadoEnvio>` : "") +
      `${lines}</tikR:RespuestaRegFactuSistemaFacturacion>`,
  );

Deno.test("#3932 a clean acceptance of the one record accepts", () => {
  const r = readVerifactuResponse(answer("Correcto", line("Correcto")));
  assertEquals(r.verdict, "accepted");
  assertEquals(r.submissionState, "Correcto");
  assertEquals(r.csv, "CSV-1");
  assertEquals(r.lines.map((l) => l.state), ["Correcto"]);
});

Deno.test("#3932 a refused record refuses, with the AEAT's own words", () => {
  const r = readVerifactuResponse(
    answer(
      "Incorrecto",
      line("Incorrecto", "1100", "Valor o formato incorrecto"),
    ),
  );
  assertEquals(r.verdict, "rejected");
  assertEquals(r.reason, "Valor o formato incorrecto");
  assertEquals(r.lines[0].code, "1100");
});

Deno.test("#3932 everything else is no verdict yet", () => {
  const cases: [string, string][] = [
    [
      "a record kept with errors",
      answer("ParcialmenteCorrecto", line("AceptadoConErrores", "2000", "x")),
    ],
    [
      "accepted with errors under a clean submission",
      answer("Correcto", line("AceptadoConErrores", "2000", "x")),
    ],
    ["a partial submission", answer("ParcialmenteCorrecto", line("Correcto"))],
    ["a clean submission without a record line", answer("Correcto", "")],
    [
      "two records for a submission of one",
      answer("Correcto", line("Correcto") + line("Correcto")),
    ],
    ["no submission state", answer("", line("Correcto"))],
    [
      "an empty submission state",
      answer("", line("Correcto")).replace(
        "<tikR:TiempoEsperaEnvio>",
        "<tikR:EstadoEnvio></tikR:EstadoEnvio><tikR:TiempoEsperaEnvio>",
      ),
    ],
    ["another submission state", answer("Aceptado", line("Correcto"))],
    ["another record state", answer("Correcto", line("Pendiente"))],
    ["states in another case", answer("correcto", line("correcto"))],
    [
      "a record without a state",
      answer("Correcto", "<tikR:RespuestaLinea></tikR:RespuestaLinea>"),
    ],
    [
      "a SOAP fault",
      envelope(
        "<env:Fault><faultcode>env:Server</faultcode><faultstring>Error interno</faultstring></env:Fault>",
      ),
    ],
    ["an HTML page", "<html><body>Servicio no disponible</body></html>"],
    ["another XML shape", "<respuesta><estado>Correcto</estado></respuesta>"],
    ["an empty answer", ""],
    ["a blank answer", "  \n "],
  ];
  for (const [name, xml] of cases) {
    assertEquals(readVerifactuResponse(xml).verdict, "unknown", name);
  }
});

Deno.test("#3932 a refusal needs the record's own state, not the submission's alone", () => {
  assertEquals(
    readVerifactuResponse(answer("Incorrecto", line("Pendiente"))).verdict,
    "unknown",
  );
  assertEquals(
    readVerifactuResponse(answer("Correcto", line("Incorrecto", "9", "x")))
      .verdict,
    "rejected",
  );
});

Deno.test("#3932 the states are the contract's", () => {
  assertEquals(VERIFACTU_STATES.record, {
    accepted: "Correcto",
    withErrors: "AceptadoConErrores",
    refused: "Incorrecto",
  });
});

Deno.test("#3932 the reader never throws on what it was not given", () => {
  for (const odd of [null, undefined, 42, {}] as unknown[]) {
    assertEquals(readVerifactuResponse(odd as string).verdict, "unknown");
  }
});
