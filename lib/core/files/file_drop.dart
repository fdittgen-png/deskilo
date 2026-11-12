// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/context_l10n.dart';
import '../theme/app_radius.dart';
import '../trace/trace_logger.dart';
import '../ui/app_snack.dart';
import 'file_drop_backend.dart';

/// Why a drop was not taken.
enum _DropRefusal { severalFiles, folder, wrongKind }

/// What one drop comes to: the one file to hand on, or the reason none is.
typedef _DropVerdict = ({XFile? file, _DropRefusal? refusal});

/// Judges a drop against what the place takes (#3623): exactly one file,
/// not a folder, of a kind [group] lists. Only the NAME is judged here;
/// size and content are the place's own checks, which the dropped file
/// goes through exactly as a picked one does.
_DropVerdict _judgeDrop(DroppedItems dropped, XTypeGroup group) {
  if (dropped.hasFolder) return (file: null, refusal: _DropRefusal.folder);
  if (dropped.files.length != 1) {
    return (file: null, refusal: _DropRefusal.severalFiles);
  }
  final file = dropped.files.single;
  return dropTakes(file, group)
      ? (file: file, refusal: null)
      : (file: null, refusal: _DropRefusal.wrongKind);
}

/// Whether [file] is of a kind [group] lists: by the ending of its name,
/// or by its declared type. A group that lists nothing takes any file.
@visibleForTesting
bool dropTakes(XFile file, XTypeGroup group) {
  final extensions = group.extensions ?? const <String>[];
  final mimeTypes = group.mimeTypes ?? const <String>[];
  if (extensions.isEmpty && mimeTypes.isEmpty) return true;
  final name = file.name.toLowerCase();
  final ending = name.contains('.') ? name.split('.').last : '';
  if (extensions.any((e) => e.toLowerCase().replaceFirst('.', '') == ending)) {
    return true;
  }
  final mime = file.mimeType?.toLowerCase();
  return mime != null && mimeTypes.any((m) => m.toLowerCase() == mime);
}

/// The endings a group takes, as part of a sentence: ".xml, .csv".
@visibleForTesting
String dropKindsOf(XTypeGroup group) => (group.extensions ?? const <String>[])
    .map((e) => '.${e.replaceFirst('.', '')}')
    .join(', ');

/// #3623 — a place that takes a file ALSO takes one dropped onto it, on the
/// desktop apps and the desktop web. [onFile] is the very handler the
/// picker's result goes to, so a dropped file meets the same type, size
/// and content checks and the same refusal messages. The picker button
/// stays where it is: this adds a way in and replaces none (keyboard and
/// screen-reader users keep the button). On a phone the zone is its child
/// and nothing else.
///
/// While a file is being processed a second drop is refused in words, so
/// one import runs at a time; [enabled] false (a place that cannot take a
/// file right now) ignores drops.
class FileDropZone extends ConsumerStatefulWidget {
  const FileDropZone({
    required this.typeGroup,
    required this.onFile,
    required this.child,
    this.enabled = true,
    this.wrongKindMessage,
    super.key,
  });

  /// What the place takes — the same group its picker is given.
  final XTypeGroup typeGroup;

  /// The handler the picker's result goes to.
  final Future<void> Function(XFile file) onFile;

  final Widget child;
  final bool enabled;

  /// The place's own sentence for a file of another kind, when it has one;
  /// otherwise the generic one naming what the place takes.
  final String? wrongKindMessage;

  @override
  ConsumerState<FileDropZone> createState() => _FileDropZoneState();
}

class _FileDropZoneState extends ConsumerState<FileDropZone> {
  bool _hover = false;
  bool _busy = false;

  Future<void> _dropped(DroppedItems dropped) async {
    if (mounted) setState(() => _hover = false);
    if (!widget.enabled || !mounted) return;
    final l10n = context.l10n;
    if (_busy) {
      AppSnack.error(context, l10n.fileDropBusy);
      return;
    }
    final verdict = _judgeDrop(dropped, widget.typeGroup);
    final refusal = verdict.refusal;
    if (refusal != null) {
      AppSnack.error(
        context,
        switch (refusal) {
          _DropRefusal.severalFiles => l10n.fileDropSeveral,
          _DropRefusal.folder => l10n.fileDropFolder,
          _DropRefusal.wrongKind =>
            widget.wrongKindMessage ??
                l10n.fileDropWrongKind(dropKindsOf(widget.typeGroup)),
        },
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onFile(verdict.file!);
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'files',
        'a dropped file could not be taken',
        error: e,
        stackTrace: st,
      );
      if (mounted) AppSnack.error(context, l10n.fileDropReadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(fileDropAvailableProvider)) return widget.child;
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final showing = _hover && widget.enabled && !_busy;
    return ref.watch(fileDropBackendProvider)(
      enabled: widget.enabled,
      onHover: (over) {
        if (mounted && over != _hover) setState(() => _hover = over);
      },
      onDrop: _dropped,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (showing)
            Positioned.fill(
              child: IgnorePointer(
                child: Semantics(
                  liveRegion: true,
                  child: DecoratedBox(
                    key: const ValueKey('file-drop-overlay'),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.85,
                      ),
                      border: Border.all(
                        color: theme.colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: AppRadius.lgAll,
                    ),
                    child: Center(
                      child: Text(
                        l10n.fileDropOverlay(dropKindsOf(widget.typeGroup)),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
