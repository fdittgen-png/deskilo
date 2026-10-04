// SPDX-License-Identifier: AGPL-3.0-or-later
//
// get_place — the floor-plan picture an assistant shows ONLY when the
// person asked for one. The database hands over the level's geometry and
// the place to highlight (`render`, one compact string, no names and no
// people); this draws it as a small PNG: offices, desks and seats as the
// app's plan lays them out, the place in question in the accent colour.
// Pure and dependency-free: a raster buffer and a PNG encoder.

type Cell = [string, ...unknown[]];

export interface PlaceRender {
  highlight: { kind: "seat" | "desk" | "office" | "level"; id: string };
  offices: Cell[]; // [id, x, y, w, h, color]
  desks: Cell[]; // [id, office_id, x, y, w, h]
  seats: Cell[]; // [id, desk_id, x, y, orientation]
}

export const PLACE_IMAGE_MAX_PX = 720;
const MARGIN = 16;
// the normative seat footprint: 6 cells along the sitting edge x 4 deep
const SEAT_LONG = 6;
const SEAT_SHORT = 4;

const BG: Rgb = [250, 250, 248];
const OFFICE_FILL: Rgb = [232, 235, 240];
const OFFICE_LINE: Rgb = [150, 158, 170];
const DESK_FILL: Rgb = [205, 211, 221];
const SEAT_FILL: Rgb = [120, 130, 146];
const ACCENT: Rgb = [214, 69, 65];
const ACCENT_FILL: Rgb = [248, 213, 211];

type Rgb = [number, number, number];

/** The picture's parse: null for anything that is not a drawable plan. */
export function parseRender(raw: unknown): PlaceRender | null {
  try {
    const v = typeof raw === "string" ? JSON.parse(raw) : raw;
    if (v === null || typeof v !== "object") return null;
    const r = v as PlaceRender;
    if (!Array.isArray(r.offices) || !Array.isArray(r.desks) || !Array.isArray(r.seats)) return null;
    if (r.offices.length === 0 || !r.highlight || typeof r.highlight.id !== "string") return null;
    return r;
  } catch {
    return null;
  }
}

class Canvas {
  readonly data: Uint8Array;
  constructor(readonly w: number, readonly h: number) {
    this.data = new Uint8Array(w * h * 4);
    for (let i = 0; i < w * h; i++) this.px(i % w, Math.floor(i / w), BG);
  }
  px(x: number, y: number, c: Rgb) {
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    const o = (y * this.w + x) * 4;
    this.data[o] = c[0];
    this.data[o + 1] = c[1];
    this.data[o + 2] = c[2];
    this.data[o + 3] = 255;
  }
  rect(x: number, y: number, w: number, h: number, fill: Rgb) {
    const x0 = Math.round(x), y0 = Math.round(y), x1 = Math.round(x + w), y1 = Math.round(y + h);
    for (let yy = y0; yy < y1; yy++) for (let xx = x0; xx < x1; xx++) this.px(xx, yy, fill);
  }
  outline(x: number, y: number, w: number, h: number, line: Rgb, t = 2) {
    this.rect(x, y, w, t, line);
    this.rect(x, y + h - t, w, t, line);
    this.rect(x, y, t, h, line);
    this.rect(x + w - t, y, t, h, line);
  }
  disc(cx: number, cy: number, r: number, fill: Rgb) {
    for (let yy = Math.floor(cy - r); yy <= Math.ceil(cy + r); yy++) {
      for (let xx = Math.floor(cx - r); xx <= Math.ceil(cx + r); xx++) {
        if ((xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2 <= r * r) this.px(xx, yy, fill);
      }
    }
  }
}

const num = (v: unknown): number => (typeof v === "number" && Number.isFinite(v) ? v : 0);

/** The plan as an RGBA raster, scaled to fit [PLACE_IMAGE_MAX_PX]. */
export function drawPlace(r: PlaceRender): { width: number; height: number; rgba: Uint8Array } {
  const seatBox = (c: Cell) => {
    const horizontal = c[4] !== "e" && c[4] !== "w";
    return { x: num(c[2]), y: num(c[3]), w: horizontal ? SEAT_LONG : SEAT_SHORT, h: horizontal ? SEAT_SHORT : SEAT_LONG };
  };
  let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
  const grow = (x: number, y: number, w: number, h: number) => {
    minX = Math.min(minX, x);
    minY = Math.min(minY, y);
    maxX = Math.max(maxX, x + w);
    maxY = Math.max(maxY, y + h);
  };
  for (const o of r.offices) grow(num(o[1]), num(o[2]), num(o[3]), num(o[4]));
  for (const d of r.desks) grow(num(d[2]), num(d[3]), num(d[4]), num(d[5]));
  for (const s of r.seats) { const b = seatBox(s); grow(b.x, b.y, b.w, b.h); }
  const spanX = Math.max(1, maxX - minX), spanY = Math.max(1, maxY - minY);
  const scale = Math.min((PLACE_IMAGE_MAX_PX - 2 * MARGIN) / spanX, (PLACE_IMAGE_MAX_PX - 2 * MARGIN) / spanY);
  const width = Math.max(32, Math.round(spanX * scale + 2 * MARGIN));
  const height = Math.max(32, Math.round(spanY * scale + 2 * MARGIN));
  const sx = (x: number) => MARGIN + (x - minX) * scale;
  const sy = (y: number) => MARGIN + (y - minY) * scale;
  const cv = new Canvas(width, height);
  const { kind, id } = r.highlight;

  for (const o of r.offices) {
    const hot = (kind === "office" && o[0] === id) || kind === "level";
    cv.rect(sx(num(o[1])), sy(num(o[2])), num(o[3]) * scale, num(o[4]) * scale, hot && kind === "office" ? ACCENT_FILL : OFFICE_FILL);
    cv.outline(sx(num(o[1])), sy(num(o[2])), num(o[3]) * scale, num(o[4]) * scale, hot && kind === "office" ? ACCENT : OFFICE_LINE);
  }
  for (const d of r.desks) {
    const hot = kind === "desk" && d[0] === id;
    cv.rect(sx(num(d[2])), sy(num(d[3])), num(d[4]) * scale, num(d[5]) * scale, hot ? ACCENT_FILL : DESK_FILL);
    if (hot) cv.outline(sx(num(d[2])), sy(num(d[3])), num(d[4]) * scale, num(d[5]) * scale, ACCENT, 3);
  }
  for (const s of r.seats) {
    const b = seatBox(s);
    const hot = kind === "seat" && s[0] === id;
    const cx = sx(b.x + b.w / 2), cy = sy(b.y + b.h / 2);
    const radius = Math.max(3, (Math.min(b.w, b.h) / 2) * scale);
    if (hot) {
      cv.disc(cx, cy, radius * 1.9, ACCENT_FILL);
      cv.disc(cx, cy, radius * 1.25, ACCENT);
    } else {
      cv.disc(cx, cy, radius, SEAT_FILL);
    }
  }
  if (kind === "level") cv.outline(1, 1, width - 2, height - 2, ACCENT, 4);
  return { width, height, rgba: cv.data };
}

const crcTable = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c >>> 0;
  }
  return t;
})();

function crc32(bytes: Uint8Array): number {
  let c = 0xffffffff;
  for (const b of bytes) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type: string, body: Uint8Array): Uint8Array {
  const out = new Uint8Array(12 + body.length);
  const dv = new DataView(out.buffer);
  dv.setUint32(0, body.length);
  for (let i = 0; i < 4; i++) out[4 + i] = type.charCodeAt(i);
  out.set(body, 8);
  dv.setUint32(8 + body.length, crc32(out.subarray(4, 8 + body.length)));
  return out;
}

async function zlib(raw: Uint8Array): Promise<Uint8Array> {
  const stream = new Blob([raw as unknown as BlobPart]).stream().pipeThrough(new CompressionStream("deflate"));
  return new Uint8Array(await new Response(stream).arrayBuffer());
}

/** An RGBA raster as a PNG file. */
export async function encodePng(width: number, height: number, rgba: Uint8Array): Promise<Uint8Array> {
  const stride = width * 4;
  const scan = new Uint8Array((stride + 1) * height);
  for (let y = 0; y < height; y++) {
    scan[y * (stride + 1)] = 0; // filter: none
    scan.set(rgba.subarray(y * stride, (y + 1) * stride), y * (stride + 1) + 1);
  }
  const ihdr = new Uint8Array(13);
  const dv = new DataView(ihdr.buffer);
  dv.setUint32(0, width);
  dv.setUint32(4, height);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  const parts = [
    new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", ihdr),
    chunk("IDAT", await zlib(scan)),
    chunk("IEND", new Uint8Array(0)),
  ];
  const out = new Uint8Array(parts.reduce((n, p) => n + p.length, 0));
  let at = 0;
  for (const p of parts) { out.set(p, at); at += p.length; }
  return out;
}

export function toBase64(bytes: Uint8Array): string {
  let s = "";
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}

/** The picture for a `render` string: base64 PNG, or null when it cannot be drawn. */
export async function placeImageBase64(raw: unknown): Promise<string | null> {
  const r = parseRender(raw);
  if (r === null) return null;
  const { width, height, rgba } = drawPlace(r);
  return toBase64(await encodePng(width, height, rgba));
}
