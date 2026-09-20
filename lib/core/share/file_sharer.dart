// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:share_plus/share_plus.dart';

part 'file_sharer.g.dart';

/// Shares a FILE through the system share sheet — email, WhatsApp,
/// whatever the device offers (0060: invoice PDFs). Seam like
/// [TextSharer], so widget tests capture the bytes instead of opening a
/// real share sheet.
/// What the system share sheet reported (#1532).
///
/// The seam used to return `void`, which made a share the user CANCELLED
/// indistinguishable from one they sent. That mattered in exactly one
/// place — a dunning reminder recorded its level before the letter went
/// out, so cancelling the sheet still escalated the member, and the next
/// attempt sent a harsher level-2 for a level-1 nobody received.
enum FileShareOutcome {
  /// The user picked something. share_plus `ShareResultStatus.success`.
  sent,

  /// The user closed the sheet. `dismissed` — nothing left the device,
  /// and this is the case worth acting on because it is unambiguous.
  dismissed,

  /// The platform shared but cannot say what the user did
  /// (`unavailable`), or the seam has no way to tell.
  ///
  /// Treated as [sent] by callers today, deliberately and on the
  /// record: on a platform that always answers this, refusing to record
  /// would mean a dunning ladder that never advances at all. Whether
  /// that is the right trade is the open question on #1532.
  unknown,
}

typedef FileSharer = Future<FileShareOutcome> Function({
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
      final result = await SharePlus.instance.share(ShareParams(
        text: text,
        files: [
          XFile.fromData(bytes, name: fileName, mimeType: mimeType),
        ],
      ));
      return switch (result.status) {
        ShareResultStatus.success => FileShareOutcome.sent,
        ShareResultStatus.dismissed => FileShareOutcome.dismissed,
        ShareResultStatus.unavailable => FileShareOutcome.unknown,
      };
    };
