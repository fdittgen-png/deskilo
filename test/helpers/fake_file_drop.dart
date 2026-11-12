// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3623 — a drop source a widget test drives by hand: the platform's
// drag-and-drop is replaced by [FakeFileDrop.hover] and [FakeFileDrop.drop].
import 'dart:typed_data';

import 'package:deskilo/core/files/file_drop_backend.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';

/// A dropped file with a name and bytes in memory (an `XFile.fromData`
/// keeps no name on the desktop implementation).
class FakeDroppedFile extends XFile {
  FakeDroppedFile(this._name, {Uint8List? bytes, super.mimeType})
    : super.fromData(bytes ?? Uint8List.fromList([1, 2, 3]));

  final String _name;

  @override
  String get name => _name;
}

class FakeFileDrop {
  ValueChanged<bool>? _onHover;
  ValueChanged<DroppedItems>? _onDrop;
  bool _enabled = true;

  /// The overrides that make the app a desktop with this drop source.
  /// [available] false stands for a phone.
  List<Override> overrides({bool available = true}) => [
    fileDropAvailableProvider.overrideWithValue(available),
    fileDropBackendProvider.overrideWithValue(({
      required child,
      required enabled,
      required onHover,
      required onDrop,
    }) {
      _onHover = onHover;
      _onDrop = onDrop;
      _enabled = enabled;
      return child;
    }),
  ];

  /// Whether a zone is on the screen at all.
  bool get present => _onDrop != null;

  void hover({required bool over}) => _onHover?.call(over);

  /// A drop; ignored, as the platform widget does, when the zone is disabled.
  void drop(DroppedItems items) {
    if (_enabled) _onDrop?.call(items);
  }
}
