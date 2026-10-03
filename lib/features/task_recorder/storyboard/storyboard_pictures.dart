// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1866 B — the approved pictures of one storyboard revision.
//
// Only a frame a person approved, still included, with a recreated scene
// is drawn; nothing else becomes a picture. The pictures are rendered
// from the frame (its scene and its redactions) by the same renderer the
// preview used, so the document holds what was approved. A render that
// fails leaves that frame without a picture and says so; the export does
// not pretend a blank image is an illustration.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/trace/trace_logger.dart';
import 'illustration_renderer.dart';
import 'storyboard.dart';

/// A storyboard revision with the pictures drawn for its approved frames.
class StoryboardPictures {
  StoryboardPictures(
    this.storyboard,
    Map<int, Uint8List> pictures, {
    Set<int> failed = const {},
  }) : pictures = Map.unmodifiable(pictures),
       failed = Set.unmodifiable(failed);

  final Storyboard storyboard;

  /// Step seq → metadata-free PNG.
  final Map<int, Uint8List> pictures;

  /// Step seqs whose approved picture could not be drawn.
  final Set<int> failed;
}

/// Draws the approved frames of [storyboard] with [colors].
Future<StoryboardPictures> renderApprovedPictures(
  Storyboard storyboard, {
  required ColorScheme colors,
  required String provenance,
  IllustrationPreset preset = IllustrationPreset.landscape,
}) async {
  final renderer = IllustrationRenderer(colors);
  final pictures = <int, Uint8List>{};
  final failed = <int>{};
  for (final f in storyboard.included) {
    final scene = f.scene;
    if (!f.approved || scene == null) continue;
    try {
      pictures[f.stepSeq] = await renderer.renderScene(
        scene,
        provenance: provenance,
        redactions: f.redactions,
        preset: preset,
      );
    } catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'approved illustration not drawn',
        error: e,
        stackTrace: st,
      );
      failed.add(f.stepSeq);
    }
  }
  return StoryboardPictures(storyboard, pictures, failed: failed);
}
