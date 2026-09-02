// SPDX-License-Identifier: 0BSD
import 'package:file_selector/file_selector.dart' show XTypeGroup;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_names.dart';
import '../../../../core/files/file_picker.dart';
import '../../../../core/trace/guarded.dart';
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

class _ReportImageDialog extends ConsumerWidget {
  const _ReportImageDialog();

  Future<void> _upload(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final pick = ref.read(filePickerProvider);
    final file = await pick(XTypeGroup(
      label: l10n?.profilePhotoFileType ?? 'Image',
      extensions: const ['jpg', 'jpeg', 'png', 'webp'],
      mimeTypes: const ['image/jpeg', 'image/png', 'image/webp'],
    ));
    if (file == null || !context.mounted) return;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    await runGuarded(
      context,
      domain: 'money',
      message: 'report image upload failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref.read(moneyRepositoryProvider).uploadReportImage(
            workspace.id,
            name: safeFileSlug(file.name),
            bytes: bytes,
            contentType: file.mimeType ?? 'image/png',
          ),
    );
    ref.invalidate(reportImagesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final images = ref.watch(reportImagesProvider).value ?? const [];
    return AlertDialog(
      title: Text(l10n?.reportImagesTitle ?? 'Report images'),
      content: SizedBox(
        width: 360,
        child: images.isEmpty
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
          onPressed: () => _upload(context, ref),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
      ],
    );
  }
}
