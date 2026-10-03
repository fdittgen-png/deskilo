// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1879 — generate, watch, cancel and save a tutorial video.
//
// The preview strip draws the timeline's cues with the SAME FrameComposer
// the encoder is fed by, so what is previewed is what is encoded. While a
// job runs, progress is announced to screen readers and Cancel stays
// reachable by keyboard; a cancelled, failed or unsupported run says so
// and saves nothing. On success the MP4, its caption track and its
// transcript are saved locally and the saved name is shown.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_saver.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/edge_fade_scroll.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/task_recording.dart';
import '../export/task_document.dart';
import '../storyboard/storyboard.dart';
import 'frame_composer.dart';
import 'render_job.dart';
import 'video_export.dart';
import 'video_timeline.dart';

/// The localized sentence for a result reason key.
String videoReason(AppLocalizations l, String key) => switch (key) {
  'taskExportVideoEmpty' => l.taskExportVideoEmpty,
  'taskExportVideoTooLong' => l.taskExportVideoTooLong,
  'taskExportVideoBusy' => l.taskExportVideoBusy,
  'taskExportVideoUnsupported' => l.taskExportVideoUnsupported,
  _ => l.taskExportVideoFailed,
};

class VideoGenerationPanel extends ConsumerStatefulWidget {
  const VideoGenerationPanel({
    super.key,
    required this.recording,
    required this.storyboard,
  });

  final TaskRecording recording;
  final Storyboard storyboard;

  @override
  ConsumerState<VideoGenerationPanel> createState() =>
      _VideoGenerationPanelState();
}

class _VideoGenerationPanelState extends ConsumerState<VideoGenerationPanel> {
  VideoPreset _preset = VideoPreset.landscape;
  double? _progress;
  RenderCancel? _cancel;
  String? _message;

  Future<void> _generate() async {
    final l = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final exporter = ref.read(taskVideoExporterProvider);
    final cancel = RenderCancel();
    setState(() {
      _cancel = cancel;
      _progress = 0;
      _message = null;
    });
    final result = await exporter.generate(
      widget.recording,
      widget.storyboard,
      l,
      colors: colors,
      preset: _preset,
      cancel: cancel,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    String message;
    switch (result) {
      case VideoProduced():
        final saved = await exporter.save(
          result,
          widget.recording,
          recordingRevision(widget.recording),
        );
        message = switch (saved?.video) {
          SavedFile(:final path) => l.taskExportVideoSaved(path),
          SavedPrivately(:final path) => l.taskRecorderSavedPrivately(path),
          DownloadRequested() => l.taskRecorderSaveNoPath,
          SaveFailed() || null => l.taskExportVideoFailed,
        };
      case VideoCancelled():
        message = l.taskExportVideoCancelled;
      case VideoUnsupported(:final reasonKey) || VideoFailed(:final reasonKey):
        message = videoReason(l, reasonKey);
    }
    if (!mounted) return;
    setState(() {
      _progress = null;
      _cancel = null;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final running = _progress != null;
    final percent = ((_progress ?? 0) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimelineStrip(
          recording: widget.recording,
          storyboard: widget.storyboard,
          preset: _preset,
        ),
        const SizedBox(height: 12),
        SegmentedButton<VideoPreset>(
          segments: [
            ButtonSegment(
              value: VideoPreset.landscape,
              label: Text(l.taskExportVideoLandscape),
            ),
            ButtonSegment(
              value: VideoPreset.portrait,
              label: Text(l.taskExportVideoPortrait),
            ),
          ],
          selected: {_preset},
          onSelectionChanged: running
              ? null
              : (s) => setState(() => _preset = s.single),
        ),
        const SizedBox(height: 12),
        if (running) ...[
          Semantics(
            liveRegion: true,
            label: l.taskExportVideoGenerating(percent),
            child: LinearProgressIndicator(value: _progress),
          ),
          Text(l.taskExportVideoGenerating(percent)),
          TextButton(
            onPressed: () => _cancel?.cancel(),
            child: Text(l.taskExportVideoCancel),
          ),
        ] else
          FilledButton(
            onPressed: _generate,
            child: Text(l.taskExportVideoGenerate),
          ),
        if (_message != null)
          Semantics(liveRegion: true, child: Text(_message!)),
      ],
    );
  }
}

/// The cues of the timeline, drawn by the encoder's own composer.
class _TimelineStrip extends StatefulWidget {
  const _TimelineStrip({
    required this.recording,
    required this.storyboard,
    required this.preset,
  });

  final TaskRecording recording;
  final Storyboard storyboard;
  final VideoPreset preset;

  @override
  State<_TimelineStrip> createState() => _TimelineStripState();
}

class _TimelineStripState extends State<_TimelineStrip> {
  final List<ui.Image> _images = [];
  List<TimelineCue> _cues = const [];
  Object? _key;

  void _dispose() {
    for (final i in _images) {
      i.dispose();
    }
    _images.clear();
  }

  /// Redraws the strip when the revision, preset or theme changed. Runs
  /// after the current build, so it never sets state during one.
  void _schedule(AppLocalizations l, ColorScheme colors) {
    final key = (widget.storyboard.revision, widget.preset, colors.brightness);
    if (key == _key) return;
    _key = key;
    Future.microtask(() => _draw(l, colors, key));
  }

  Future<void> _draw(AppLocalizations l, ColorScheme colors, Object key) async {
    if (!mounted || key != _key) return;
    final VideoTimeline timeline;
    try {
      timeline = buildTimeline(
        widget.recording,
        widget.storyboard,
        l,
        preset: widget.preset,
      );
    } on TimelineException catch (e, st) {
      TraceLogger.instance.warn(
        'recorder',
        'video preview has no timeline',
        error: e,
        stackTrace: st,
      );
      setState(() {
        _dispose();
        _cues = const [];
      });
      return;
    }
    final composer = FrameComposer(
      colors,
      widget.preset,
      provenance: l.taskExportSceneProvenance,
    );
    final images = <ui.Image>[];
    for (final cue in timeline.cues) {
      final picture = composer.picture(cue);
      images.add(
        await picture.toImage(
          widget.preset.width ~/ 4,
          widget.preset.height ~/ 4,
        ),
      );
      picture.dispose();
    }
    if (!mounted || key != _key) {
      for (final i in images) {
        i.dispose();
      }
      return;
    }
    setState(() {
      _dispose();
      _images.addAll(images);
      _cues = timeline.cues;
    });
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _schedule(AppLocalizations.of(context)!, Theme.of(context).colorScheme);
    final height = widget.preset == VideoPreset.portrait ? 200.0 : 120.0;
    return SizedBox(
      height: height,
      child: EdgeFadeScroll.around(
        builder: (context, controller) => ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          itemCount: _images.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => Semantics(
            label: _cues[i].heading,
            image: true,
            child: RawImage(
              image: _images[i],
              height: height,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
