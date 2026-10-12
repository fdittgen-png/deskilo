// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The smallest DER reader that finds a certificate's public key. KSeF
// publishes its encryption keys as X.509 certificates; WebCrypto imports
// a SubjectPublicKeyInfo, not a certificate, so the SPKI is cut out of
// the certificate here instead of pulling in an ASN.1 library.

export interface Tlv {
  tag: number;
  /** Offset of the tag byte in the source. */
  start: number;
  /** Offset of the first content byte. */
  contentStart: number;
  /** Offset just past the content. */
  end: number;
}

/** Reads the TLV at [at]. Single-byte tags only — X.509 uses no others
 * on the path to the SPKI. */
export function readTlv(der: Uint8Array, at: number): Tlv {
  if (at + 2 > der.length) throw new Error("DER: truncated");
  const tag = der[at];
  let length = der[at + 1];
  let contentStart = at + 2;
  if (length & 0x80) {
    const count = length & 0x7f;
    if (count === 0 || count > 4) throw new Error("DER: unsupported length");
    length = 0;
    for (let i = 0; i < count; i++) {
      length = length * 256 + der[contentStart + i];
    }
    contentStart += count;
  }
  const end = contentStart + length;
  if (end > der.length) throw new Error("DER: truncated");
  return { tag, start: at, contentStart, end };
}

/** The TLVs directly inside a constructed one. */
export function children(der: Uint8Array, parent: Tlv): Tlv[] {
  const out: Tlv[] = [];
  let at = parent.contentStart;
  while (at < parent.end) {
    const child = readTlv(der, at);
    out.push(child);
    at = child.end;
  }
  return out;
}

const SEQUENCE = 0x30;
const EXPLICIT_VERSION = 0xa0;

/** Certificate ::= SEQUENCE { tbsCertificate, signatureAlgorithm,
 * signature }; tbsCertificate ::= SEQUENCE { [0] version OPTIONAL,
 * serialNumber, signature, issuer, validity, subject,
 * subjectPublicKeyInfo, … } (RFC 5280 §4.1). */
export function spkiOfCertificate(der: Uint8Array): Uint8Array<ArrayBuffer> {
  const cert = readTlv(der, 0);
  if (cert.tag !== SEQUENCE) throw new Error("DER: not a certificate");
  const tbs = children(der, cert)[0];
  if (!tbs || tbs.tag !== SEQUENCE) throw new Error("DER: no tbsCertificate");
  let fields = children(der, tbs);
  if (fields[0]?.tag === EXPLICIT_VERSION) fields = fields.slice(1);
  const spki = fields[5];
  if (!spki || spki.tag !== SEQUENCE) throw new Error("DER: no public key");
  return der.slice(spki.start, spki.end);
}
