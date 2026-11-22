// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- the one shared input listener for a scanner in keyboard mode. A scope listens to the hardware
// keyboard while it is mounted and enabled, feeds each key with its time to a [ScanDetector], and calls
// [onScan] with the code when a terminator ends a burst typed faster than a person types. A focused text field
// keeps its own typing: while one has the focus the scope forgets what it collected and lets every key through,
// so typing in a field is never taken for a scan. Whether scanning is on at all is decided by whoever mounts the
// scope (`enabled`); the timing and the terminator are the device's (`scanPrefsProvider`).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'scan_detector.dart';
import 'scan_prefs.dart';

class ScanScope extends ConsumerStatefulWidget {
  const ScanScope({required this.onScan, required this.child, this.enabled = true, super.key});

  /// Called with the scanned code (never empty).
  final void Function(String code) onScan;
  final bool enabled;
  final Widget child;

  @override
  ConsumerState<ScanScope> createState() => _ScanScopeState();
}

class _ScanScopeState extends ConsumerState<ScanScope> {
  ScanDetector _detector = ScanDetector();
  ScanTerminator _terminator = ScanTerminator.either;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  /// A text field has the focus: it keeps its own typing.
  bool get _typing => FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() != null;

  bool _ends(LogicalKeyboardKey key) => switch (_terminator) {
    ScanTerminator.enter => key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter,
    ScanTerminator.tab => key == LogicalKeyboardKey.tab,
    ScanTerminator.either =>
      key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter || key == LogicalKeyboardKey.tab,
  };

  bool _onKey(KeyEvent event) {
    if (!widget.enabled || event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (_typing) {
      _detector.reset();
      return false;
    }
    if (_ends(event.logicalKey)) {
      final code = _detector.terminator(event.timeStamp);
      if (code == null) return false;
      widget.onScan(code);
      return true;
    }
    final ch = event.character;
    if (ch != null && ch.length == 1 && ch.codeUnitAt(0) >= 0x20) _detector.character(ch, event.timeStamp);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(scanPrefsProvider).value ?? const ScanPrefs(); // empty-ok: the device's defaults until its own are read
    if (prefs.interval != _detector.maxInterval) _detector = ScanDetector(maxInterval: prefs.interval);
    _terminator = prefs.terminator;
    return widget.child;
  }
}
