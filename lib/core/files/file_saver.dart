// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'file_saver_io.dart'
    if (dart.library.js_interop) 'file_saver_web.dart' as impl;
import 'file_types.dart';

export 'file_saver_io.dart'
    if (dart.library.js_interop) 'file_saver_web.dart';
export 'file_types.dart';

part 'file_saver.g.dart';

/// Injectable local-save seam (mirrors [shareLauncher]'s pattern) so widget
/// tests capture the write instead of touching the filesystem.
///
/// Which implementation answers depends on where the app runs: on a device
/// the export lands in the user's Downloads (MediaStore on Android, the
/// Downloads directory elsewhere); in a browser it goes through the
/// download machinery, since a page has no folder to write to. Both return
/// a handle the UI can name in a snackbar.
@Riverpod(keepAlive: true)
FileSaver fileSaver(Ref ref) => impl.saveToDownloads;
