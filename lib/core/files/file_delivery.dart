// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/context_l10n.dart';
import '../share/file_sharer.dart';
import '../trace/trace_logger.dart';
import '../ui/app_sheet.dart';
import '../ui/form_sheet.dart';
import 'file_saver.dart';

/// What delivering a file to the person achieved, as the platform reported
/// it — never more. A screen announces it through `announceFileDelivery`
/// (file_delivery_notice.dart); a flow that must know whether the bytes
/// left the device reads the case.
sealed class FileDelivery {
  const FileDelivery();
}

/// The local saver answered: a file the person can find, a private copy, a
/// browser's request, or a failure — see [outcome].
final class LocalSave extends FileDelivery {
  const LocalSave(this.outcome);
  final SaveOutcome outcome;
}

/// The person chose Share… and the system sheet took the bytes. [confirmed]
/// is the sheet's own report that something was picked; false when the
/// platform cannot say. Neither is a receipt: where the file went is up to
/// the app the person chose.
final class HandedToShareSheet extends FileDelivery {
  const HandedToShareSheet(this.fileName, {required this.confirmed});
  final String fileName;
  final bool confirmed;
}

/// The person backed out — closed the Export… choice or the system sheet.
/// Nothing was written and nothing left the app.
final class DeliveryCancelled extends FileDelivery {
  const DeliveryCancelled();
}

/// The share path could not open the system sheet; the bytes stayed here.
final class DeliveryFailed extends FileDelivery {
  const DeliveryFailed(this.reason);
  final SaveFailure reason;
}

enum _ExportChoice { keep, share }

/// Delivers [bytes] as [fileName] the way this platform can be truthful
/// about: the local saver where downloads have a place (Android, desktop,
/// browser), the Export… choice on an iPhone. A local save never opens a
/// share sheet on its own: the sheet is reached only by the person's choice.
Future<FileDelivery> deliverFile(
  BuildContext context,
  WidgetRef ref, {
  required Uint8List bytes,
  required String fileName,
}) async {
  final save = ref.read(typedFileSaverProvider);
  if (ref.read(fileDeliveryModeProvider) == FileDeliveryMode.direct) {
    return LocalSave(await save(bytes: bytes, fileName: fileName));
  }
  final choice = await showAppSheet<_ExportChoice>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ExportSheet(),
  );
  return switch (choice) {
    null => const DeliveryCancelled(),
    _ExportChoice.keep => LocalSave(
      await save(bytes: bytes, fileName: fileName),
    ),
    _ExportChoice.share => await _share(ref, bytes: bytes, fileName: fileName),
  };
}

Future<FileDelivery> _share(
  WidgetRef ref, {
  required Uint8List bytes,
  required String fileName,
}) async {
  try {
    final report = await ref.read(fileSharerProvider)(
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeTypeFor(fileName),
    );
    return switch (report) {
      FileShareOutcome.sent => HandedToShareSheet(fileName, confirmed: true),
      FileShareOutcome.unknown => HandedToShareSheet(
        fileName,
        confirmed: false,
      ),
      FileShareOutcome.dismissed => const DeliveryCancelled(),
    };
  } on Object catch (e, st) {
    TraceLogger.instance.error(
      'files',
      'share sheet unavailable',
      error: e,
      stackTrace: st,
    );
    return const DeliveryFailed(SaveFailure.shareUnavailable);
  }
}

/// The iPhone's Export… choice. Both rows act at once (one writes, one
/// opens the system sheet), so neither carries a chevron; the subtitle
/// says what happens.
class _ExportSheet extends StatelessWidget {
  const _ExportSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SheetShell(
      title: l10n.fileExportTitle,
      children: [
        ListTile(
          key: const ValueKey('file-export-keep'),
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(l10n.fileExportKeep),
          subtitle: Text(l10n.fileExportKeepHint),
          onTap: () => Navigator.of(context).pop(_ExportChoice.keep),
        ),
        ListTile(
          key: const ValueKey('file-export-share'),
          leading: const Icon(Icons.ios_share),
          title: Text(l10n.fileExportShare),
          subtitle: Text(l10n.fileExportShareHint),
          onTap: () => Navigator.of(context).pop(_ExportChoice.share),
        ),
      ],
    );
  }
}
