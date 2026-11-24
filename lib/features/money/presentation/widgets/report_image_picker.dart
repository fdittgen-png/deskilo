// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:file_selector/file_selector.dart' show XFile, XTypeGroup;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_drop.dart';
import '../../../../core/files/file_names.dart';
import '../../../../core/files/file_picker.dart';
import '../../../../core/images/report_picture_bytes.dart'
    show ReportPictureException;
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/loading_view.dart';
import '../../application/report_picture_library.dart';
import '../../providers/guest_pass_providers.dart' show currentWorkspaceProvider;
import '../../providers/money_providers.dart';
import 'report_image_notice.dart';
import 'report_image_print_size.dart';

/// The report-image LIBRARY picker (#488): the workspace's uploaded
/// images with an upload button. Pops with the chosen image's name, or
/// null when dismissed. Its own file since #822 — the visual editor
/// grew, and the library is a dialog of its own.
Future<String?> showReportImagePicker(
  BuildContext context,
  WidgetRef ref,
) =>
    showDialog<String>(
      context: context,
      builder: (context) => const _ReportImageDialog(),
    );

class _ReportImageDialog extends ConsumerStatefulWidget {
  const _ReportImageDialog();

  @override
  ConsumerState<_ReportImageDialog> createState() => _ReportImageDialogState();
}

class _ReportImageDialogState extends ConsumerState<_ReportImageDialog> {
  bool _uploading = false;

  XTypeGroup _types(BuildContext context) => XTypeGroup(
    label: context.l10n.editorToolImage,
    extensions: const ['jpg', 'jpeg', 'png', 'webp'],
    mimeTypes: const ['image/jpeg', 'image/png', 'image/webp'],
  );

  /// Uploads [dropped] — or, when null, the file the picker returns; the
  /// two meet the same read, the same name and the same upload (#3623).
  /// The picture is brought to print size before it is stored (#3984).
  Future<void> _upload(
    BuildContext context,
    WidgetRef ref, {
    XFile? dropped,
  }) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final pick = ref.read(filePickerProvider);
    final library = ref.read(reportPictureLibraryProvider);
    setState(() => _uploading = true);
    await runGuarded(
      context,
      domain: 'money',
      message: 'report image upload failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        final file = dropped ?? await pick(_types(context));
        if (file == null || !context.mounted) return;
        final bytes = await file.readAsBytes();
        if (!context.mounted ||
            ref.read(currentWorkspaceProvider).value?.id != workspace.id) {
          return;
        }
        final name = safeFileSlug(file.name);
        try {
          await library.add(workspace.id, name: name, bytes: bytes);
        } on ReportPictureException catch (caught, caughtStack) {
          TraceLogger.instance.log(TraceLevel.info, 'money', 'report_image_picker: ReportPictureException handled', error: caught, stackTrace: caughtStack);
          if (context.mounted) AppSnack.error(context, l10n.reportImageInvalid);
          return;
        }
        if (!context.mounted) return;
        ref
          ..invalidate(reportImageBytesProvider(name))
          ..invalidate(reportImagesProvider);
      },
    );
    if (!context.mounted) return;
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final library = ref.watch(reportImagesProvider);
    // #3680 — the library as read, or its failure: never "no images".
    final standIn = ReadsAnswer.of([library]).standIn(
      onRetry: () => ref.invalidate(reportImagesProvider),
    );
    if (standIn != null) return AlertDialog(content: standIn);
    return AlertDialog(
      title: Text(l10n.reportImagesTitle),
      content: FileDropZone(
        typeGroup: _types(context),
        enabled: !_uploading,
        onFile: (file) => _upload(context, ref, dropped: file),
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_uploading) const _Preparing(),
              const ReportImagePrintSize(),
              Flexible(child: _Images(library)),
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          key: const ValueKey('report-image-upload'),
          icon: const Icon(Icons.upload_outlined),
          label: Text(l10n.reportImageUpload),
          onPressed: _uploading ? null : () => _upload(context, ref),
        ),
        TextButton(
          key: const ValueKey('report-image-picker-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}

/// #3984 — said while a picture is brought to print size and stored.
class _Preparing extends StatelessWidget {
  const _Preparing();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Column(
      key: const ValueKey('report-image-preparing'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.reportImagePreparing),
        const LinearProgressIndicator(),
      ],
    ),
  );
}

/// The library's pictures, or why there are none to show.
class _Images extends ConsumerWidget {
  const _Images(this.library);

  final AsyncValue<List<String>> library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (library.isLoading) return const LoadingView();
    if (library.hasError) {
      return ReadFailureBanner(
        error: library.error!,
        retryKey: const ValueKey('report-images-retry'),
        onRetry: () => ref.invalidate(reportImagesProvider),
      );
    }
    final images = library.requireValue;
    if (images.isEmpty) return Text(l10n.reportImagesEmpty);
    return ListView(
      shrinkWrap: true,
      children: [for (final name in images) _ImageTile(name)],
    );
  }
}

class _ImageTile extends ConsumerWidget {
  const _ImageTile(this.name);

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bytes = ref.watch(reportImageBytesProvider(name));
    return ListTile(
      key: ValueKey('report-image-$name'),
      leading: SizedBox(
        width: 40,
        height: 40,
        // #4414 kept: one picture's mark in its tile; the tile retries it
        child: bytes.hasError
            ? Tooltip(
                message: reportImageReason(l10n, bytes.error!),
                child: Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            : bytes.value == null
            ? const Icon(Icons.image_outlined)
            : Image.memory(
                bytes.value!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) =>
                    const Icon(Icons.broken_image_outlined),
              ),
      ),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      // #4414 kept: one picture's own retry in its tile
      trailing: bytes.hasError
          ? IconButton(
              key: ValueKey('report-image-retry-$name'),
              tooltip: l10n.reportImageRetry,
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(reportImageBytesProvider(name)),
            )
          : null,
      onTap: () => Navigator.of(context).pop(name),
    );
  }
}
