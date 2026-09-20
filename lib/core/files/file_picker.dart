// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:file_selector/file_selector.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_picker.g.dart';

/// Opens the platform file picker filtered to [typeGroup]; null when the
/// user cancels.
typedef FilePicker = Future<XFile?> Function(XTypeGroup typeGroup);

/// Injectable seam over `file_selector`'s [openFile] so widget tests can
/// hand the flow a canned file — the same pattern [shareLauncher] uses
/// for the share sheet (#133). file_selector rides the Storage Access
/// Framework on Android.
@Riverpod(keepAlive: true)
FilePicker filePicker(Ref ref) =>
    (typeGroup) => openFile(acceptedTypeGroups: [typeGroup]);
