// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:file_selector/file_selector.dart' show XTypeGroup;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_names.dart';
import '../../../../core/files/file_picker.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../providers/money_providers.dart';

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

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final pick = ref.read(filePickerProvider);
    final repository = ref.read(moneyRepositoryProvider);
    setState(() => _uploading = true);
    await runGuarded(
      context,
      domain: 'money',
      message: 'report image upload failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final file = await pick(XTypeGroup(
          label: l10n?.profilePhotoFileType ?? 'Image',
          extensions: const ['jpg', 'jpeg', 'png', 'webp'],
          mimeTypes: const ['image/jpeg', 'image/png', 'image/webp'],
        ));
        if (file == null || !context.mounted) return;
        final bytes = await file.readAsBytes();
        if (!context.mounted ||
            ref.read(currentWorkspaceProvider).value?.id != workspace.id) {
          return;
        }
        final name = safeFileSlug(file.name);
        final extension = file.name.toLowerCase().split('.').last;
        await repository.uploadReportImage(
          workspace.id,
          name: name,
          bytes: bytes,
          contentType: switch (extension) {
            'jpg' || 'jpeg' => 'image/jpeg',
            'webp' => 'image/webp',
            _ => 'image/png',
          },
        );
        if (!context.mounted) return;
        ref.invalidate(reportImageBytesProvider(name));
        ref.invalidate(reportImagesProvider);
      },
    );
    if (!context.mounted) return;
    setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(reportImagesProvider);
    final images = library.value ?? const [];
    return AlertDialog(
      title: Text(l10n?.reportImagesTitle ?? 'Report images'),
      content: SizedBox(
        width: 360,
        child: library.isLoading
            ? const LoadingView()
            : library.hasError
                ? TextButton.icon(
                    key: const ValueKey('report-images-retry'),
                    onPressed: () => ref.invalidate(reportImagesProvider),
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n?.reportImagesLoadFailed ??
                        'Could not load report images. Try again.'),
                  )
            : images.isEmpty
            ? Text(l10n?.reportImagesEmpty ??
                'No image yet — upload your logo, a stamp or a '
                    'signature and reference it with ![name].')
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final name in images)
                    ListTile(
                      key: ValueKey('report-image-$name'),
                      leading: SizedBox(
                        width: 40,
                        height: 40,
                        child: ref
                                    .watch(reportImageBytesProvider(name))
                                    .value ==
                                null
                            ? const Icon(Icons.image_outlined)
                            : Image.memory(
                                ref
                                    .watch(reportImageBytesProvider(name))
                                    .value!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                      ),
                      title: Text(name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.of(context).pop(name),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton.icon(
          key: const ValueKey('report-image-upload'),
          icon: const Icon(Icons.upload_outlined),
          label: Text(l10n?.reportImageUpload ?? 'Upload image'),
          onPressed: _uploading ? null : () => _upload(context, ref),
        ),
        TextButton(
          key: const ValueKey('report-image-picker-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
      ],
    );
  }
}
