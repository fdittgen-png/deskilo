// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — the browser encoder: WebCodecs (H.264 'avc') through the
// bundled Mediabunny muxer (MPL-2.0, mediabunny.min.mjs beside this file,
// version 1.61.0, licence in MEDIABUNNY_LICENSE). Nothing is fetched: the
// muxer ships in the app's assets, and the codec is the browser's own.
// One session per encode; frames are held one behind so each sample is
// given its true duration, and the last one ends at finish(endMs).
import {
  BufferTarget,
  Mp4OutputFormat,
  Output,
  VideoSample,
  VideoSampleSource,
  canEncodeVideo,
} from './mediabunny.min.mjs';

const sessions = new Map();
let nextId = 1;

export async function probe(width, height, bitrate) {
  if (typeof VideoEncoder === 'undefined') return false;
  try {
    return await canEncodeVideo('avc', { width, height, bitrate });
  } catch (_) {
    return false;
  }
}

export async function start(width, height, bitrate, keyframeIntervalMs) {
  const output = new Output({
    format: new Mp4OutputFormat({ fastStart: 'in-memory' }),
    target: new BufferTarget(),
  });
  const source = new VideoSampleSource({
    codec: 'avc',
    bitrate,
    keyFrameInterval: keyframeIntervalMs / 1000,
  });
  output.addVideoTrack(source, { frameRate: 10 });
  await output.start();
  const id = nextId++;
  sessions.set(id, { output, source, width, height, held: null });
  return id;
}

async function emit(s, held, endMs) {
  const sample = new VideoSample(held.rgba, {
    format: 'RGBA',
    codedWidth: s.width,
    codedHeight: s.height,
    timestamp: held.ptsMs / 1000,
    duration: (endMs - held.ptsMs) / 1000,
  });
  try {
    await s.source.add(sample);
  } finally {
    sample.close();
  }
}

export async function addFrame(id, rgba, ptsMs) {
  const s = sessions.get(id);
  if (!s) throw new Error('no_session');
  if (rgba.length !== s.width * s.height * 4) throw new Error('bad_args');
  if (s.held && ptsMs <= s.held.ptsMs) throw new Error('bad_args');
  if (s.held) await emit(s, s.held, ptsMs);
  s.held = { rgba: rgba.slice(), ptsMs };
}

export async function finish(id, endMs) {
  const s = sessions.get(id);
  if (!s) throw new Error('no_session');
  sessions.delete(id);
  if (s.held) await emit(s, s.held, Math.max(endMs, s.held.ptsMs + 1));
  s.held = null;
  await s.output.finalize();
  return new Uint8Array(s.output.target.buffer);
}

export async function cancel(id) {
  const s = sessions.get(id);
  if (!s) return;
  sessions.delete(id);
  s.held = null;
  try {
    await s.output.cancel();
  } catch (_) {
    // already finished or failed: nothing left to release
  }
}
