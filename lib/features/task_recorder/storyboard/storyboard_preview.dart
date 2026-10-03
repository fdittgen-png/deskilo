// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1876 — the storyboard review: every frame, its illustration as it
// will be exported, its provenance, and the few edits a person may make
// (include or leave out, move, approve the illustration).
//
// Thumbnails are drawn by the same IllustrationRenderer the Word
// document and the video use, from the same frame, so what is approved
// here is what is exported. A thumbnail is cached by the frame's
// renderKey: an edit that changes the picture changes the key, so a
// stale picture is never shown for a newer revision, and a render that
// finishes after its frame changed is dropped. A failed render shows
// the step as text and says so.
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import 'illustration_renderer.dart';
import 'storyboard.dart';

/// Reviews [storyboard]; every edit is reported through [onChanged] as
/// the next revision.
class StoryboardPreview extends StatefulWidget {
  const StoryboardPreview({
    super.key,
    required this.storyboard,
    required this.onChanged,
    this.provenance,
  });

  final Storyboard storyboard;
  final ValueChanged<Storyboard> onChanged;

  /// The label drawn on recreated scenes; defaults to the localized one.
  final String? provenance;

  @override
  State<StoryboardPreview> createState() => _StoryboardPreviewState();
}

class _StoryboardPreviewState extends State<StoryboardPreview> {
  /// renderKey+brightness → PNG, or null while drawing / after a failure.
  final Map<(int, Brightness), Uint8List?> _cache = {};
  final Set<(int, Brightness)> _failed = {};

  void _ensure(StoryboardFrame f, ColorScheme colors, String provenance) {
    final key = (f.renderKey, colors.brightness);
    if (_cache.containsKey(key) || _failed.contains(key)) return;
    final scene = f.scene;
    if (scene == null) return;
    _cache[key] = null;
    IllustrationRenderer(colors)
        .renderScene(
          scene,
          provenance: provenance,
          redactions: f.redactions,
          preset: IllustrationPreset.thumbnail,
        )
        .then(
          (png) {
            if (!mounted) return;
            final live = widget.storyboard.frames.any(
              (x) => x.renderKey == key.$1,
            );
            setState(() => live ? _cache[key] = png : _cache.remove(key));
          },
          onError: (Object e, StackTrace st) {
            TraceLogger.instance.warn(
              'recorder',
              'illustration render failed',
              error: e,
              stackTrace: st,
            );
            if (!mounted) return;
            setState(() {
              _cache.remove(key);
              _failed.add(key);
            });
          },
        );
  }

  @override
  void didUpdateWidget(StoryboardPreview old) {
    super.didUpdateWidget(old);
    final live = {for (final f in widget.storyboard.frames) f.renderKey};
    _cache.removeWhere((k, _) => !live.contains(k.$1));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final provenance = widget.provenance ?? l.taskExportSceneProvenance;
    final sb = widget.storyboard;
    return ListView.builder(
      itemCount: sb.frames.length,
      itemBuilder: (context, i) {
        final f = sb.frames[i];
        _ensure(f, colors, provenance);
        final key = (f.renderKey, colors.brightness);
        return _FrameTile(
          key: ValueKey('storyboard-frame-${f.stepSeq}'),
          index: i,
          frame: f,
          png: _cache[key],
          failed: _failed.contains(key),
          last: i == sb.frames.length - 1,
          onChanged: (edit) {
            try {
              widget.onChanged(edit(sb));
            } on StoryboardEditException {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l.taskExportStoryboardOrderRefused)),
              );
            }
          },
        );
      },
    );
  }
}

class _FrameTile extends StatelessWidget {
  const _FrameTile({
    super.key,
    required this.index,
    required this.frame,
    required this.png,
    required this.failed,
    required this.last,
    required this.onChanged,
  });

  final int index;
  final StoryboardFrame frame;
  final Uint8List? png;
  final bool failed;
  final bool last;
  final void Function(Storyboard Function(Storyboard)) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final source = switch (frame.source) {
      IllustrationSource.recreatedScene => l.taskExportStoryboardSourceScene,
      IllustrationSource.textSlide => l.taskExportStoryboardSourceText,
      IllustrationSource.exclusionCard => l.taskExportStoryboardSourceExcluded,
    };
    final status = switch (frame.status) {
      FrameStatus.observed => null,
      FrameStatus.authored => l.taskExportAuthored,
      FrameStatus.gap => l.taskExportStoryboardGap,
      FrameStatus.excluded => null,
    };
    final picture = switch ((frame.scene, png, failed)) {
      (null, _, _) => null,
      (_, _, true) => Text(
        l.taskExportStoryboardRenderFailed,
        style: theme.textTheme.bodySmall,
      ),
      (_, final Uint8List bytes, _) => Image.memory(
        bytes,
        semanticLabel: frame.altText,
        gaplessPlayback: true,
      ),
      _ => const AspectRatio(
        aspectRatio: 1.6,
        child: Center(child: CircularProgressIndicator()),
      ),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. ${frame.title}',
              style: theme.textTheme.titleSmall,
            ),
            for (final d in frame.details)
              Text(d, style: theme.textTheme.bodySmall),
            if (status != null)
              Text(
                status,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 8),
            ?picture,
            Text(source, style: theme.textTheme.labelSmall),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: Text(l.taskExportStoryboardInclude),
                  selected: !frame.omitted,
                  onSelected: (v) => onChanged((s) => s.setOmitted(index, !v)),
                ),
                if (frame.source == IllustrationSource.recreatedScene)
                  FilterChip(
                    label: Text(l.taskExportStoryboardApprove),
                    selected: frame.approved,
                    onSelected: png == null
                        ? null
                        : (v) => onChanged((s) => s.setApproved(index, v)),
                  ),
                IconButton(
                  tooltip: l.taskExportStoryboardMoveUp,
                  icon: const Icon(Icons.arrow_upward),
                  onPressed: index == 0
                      ? null
                      : () => onChanged((s) => s.move(index, index - 1)),
                ),
                IconButton(
                  tooltip: l.taskExportStoryboardMoveDown,
                  icon: const Icon(Icons.arrow_downward),
                  onPressed: last
                      ? null
                      : () => onChanged((s) => s.move(index, index + 1)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
