// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What one drop delivered: the files, and whether a folder was among
/// them (a folder is never a file the place can take).
@immutable
class DroppedItems {
  const DroppedItems(this.files, {this.hasFolder = false});

  final List<XFile> files;
  final bool hasFolder;
}

/// The seam over the platform's drag-and-drop (#3623): a widget that
/// reports the drag entering and leaving its area and hands over what was
/// dropped. The default rides `desktop_drop`; widget tests override it
/// with a fake that fires drops by hand.
typedef FileDropBackend = Widget Function({
  required Widget child,
  required bool enabled,
  required ValueChanged<bool> onHover,
  required ValueChanged<DroppedItems> onDrop,
});

/// Whether a file can be dropped onto this app at all: the desktop apps
/// and a desktop browser. A phone (and a phone's browser) keeps the
/// picker only. `defaultTargetPlatform` names the operating system on the
/// web too, so one rule covers both.
final fileDropAvailableProvider = Provider<bool>(
  (ref) => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  },
);

/// The platform drop target; see [FileDropBackend].
final fileDropBackendProvider = Provider<FileDropBackend>(
  (ref) => ({
    required child,
    required enabled,
    required onHover,
    required onDrop,
  }) => DropTarget(
    enable: enabled,
    onDragEntered: (_) => onHover(true),
    onDragExited: (_) => onHover(false),
    onDragDone: (details) => onDrop(
      DroppedItems(
        details.files,
        hasFolder: details.files.any((f) => f is DropItemDirectory),
      ),
    ),
    child: child,
  ),
);
