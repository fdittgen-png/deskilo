// SPDX-License-Identifier: 0BSD
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_saver.g.dart';

/// Writes [bytes] to a local file named [fileName] on the device and returns
/// its full path (null on failure). Deliberately a LOCAL save — the file
/// lands in the device's own storage, never handed to the system share sheet
/// or another app.
typedef FileSaver = Future<String?> Function({
  required Uint8List bytes,
  required String fileName,
});

/// Injectable local-save seam (mirrors [shareLauncher]'s pattern) so widget
/// tests capture the write instead of touching the filesystem. Picks a
/// device-local directory: the app's external files dir on Android (visible
/// in a file manager, no runtime permission), the Downloads dir on
/// desktop/iOS, falling back to the app documents dir.
@Riverpod(keepAlive: true)
FileSaver fileSaver(Ref ref) => _saveLocally;

Future<String?> _saveLocally({
  required Uint8List bytes,
  required String fileName,
}) async {
  Directory? dir;
  if (Platform.isAndroid) {
    dir = await getExternalStorageDirectory();
  }
  dir ??= await getDownloadsDirectory();
  dir ??= await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
