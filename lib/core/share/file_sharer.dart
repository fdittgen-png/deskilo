// SPDX-License-Identifier: 0BSD
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'file_sharer.g.dart';

/// Shares a FILE through the system share sheet — email, WhatsApp,
/// whatever the device offers (0060: invoice PDFs). Seam like
/// [TextSharer], so widget tests capture the bytes instead of opening a
/// real share sheet.
typedef FileSharer = Future<void> Function({
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  String? text,
});

@Riverpod(keepAlive: true)
FileSharer fileSharer(Ref ref) => ({
      required Uint8List bytes,
      required String fileName,
      required String mimeType,
      String? text,
    }) async {
      await SharePlus.instance.share(ShareParams(
        text: text,
        files: [
          XFile.fromData(bytes, name: fileName, mimeType: mimeType),
        ],
      ));
    };
