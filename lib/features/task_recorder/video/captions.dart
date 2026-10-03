// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — the caption track and the transcript, from the same timeline
// the frames are drawn from, so their timing cannot drift from the
// video. WebVTT text is plain: the characters that start markup or an
// entity are escaped, a cue's text can never contain the "-->" that
// ends a timing line, and blank lines (which end a cue) are folded.
import 'video_timeline.dart';

String _time(int ms) {
  final h = ms ~/ 3600000;
  final m = (ms ~/ 60000) % 60;
  final s = (ms ~/ 1000) % 60;
  final f = ms % 1000;
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}.${f.toString().padLeft(3, '0')}';
}

String _cueText(String raw) => raw
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll(RegExp(r'[\r\n]+'), ' ')
    .trim();

/// The UTF-8 WebVTT caption track of [t].
String buildVtt(VideoTimeline t) {
  final out = StringBuffer('WEBVTT\n\n');
  for (final (i, c) in t.cues.indexed) {
    final text = _cueText(c.caption);
    if (text.isEmpty) continue;
    out
      ..writeln('${i + 1}')
      ..writeln('${_time(c.startMs)} --> ${_time(c.endMs)}')
      ..writeln(text)
      ..writeln();
  }
  return out.toString();
}

/// A readable transcript of [t]: every cue's heading and lines.
String buildTranscript(VideoTimeline t) {
  final out = StringBuffer();
  for (final c in t.cues) {
    out.writeln('[${_time(c.startMs)}] ${c.heading}');
    for (final line in c.lines) {
      out.writeln('  $line');
    }
    out.writeln();
  }
  return out.toString();
}
