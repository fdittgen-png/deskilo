// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/report_picture_library.dart';
import '../../providers/guest_pass_providers.dart'
    show currentWorkspaceProvider;
import '../../providers/money_providers.dart';

/// #3984 — the library's line when stored pictures are over the weight a
/// picture is stored at, with the one action that brings them to print size.
///
/// Nothing happens by itself: the stored pictures are found from the storage
/// listing's sizes (no download), and each is replaced only when the person
/// asks, one by one, after its new version is written. A picture that cannot
/// be replaced is left as it was stored and named.
class ReportImagePrintSize extends ConsumerStatefulWidget {
  const ReportImagePrintSize({super.key});

  @override
  ConsumerState<ReportImagePrintSize> createState() =>
      _ReportImagePrintSizeState();
}

class _ReportImagePrintSizeState extends ConsumerState<ReportImagePrintSize> {
  List<String> _over = const [];
  List<String> _failed = const [];
  bool _working = false;

  @override
  void initState() {
    super.initState();
    unawaited(_find());
  }

  Future<void> _find() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    List<String> over;
    try {
      over = await ref
          .read(reportPictureLibraryProvider)
          .overWeight(workspace.id);
    } on Object {
      // trace-exempt: the line is an offer; the library's own list shows a
      // failed read with its retry.
      over = const [];
    }
    if (mounted) setState(() => _over = over);
  }

  Future<void> _bring() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() {
      _working = true;
      _failed = const [];
    });
    final failed = await ref
        .read(reportPictureLibraryProvider)
        .bringToPrint(
          workspace.id,
          _over,
          onReplaced: (name) {
            if (mounted) ref.invalidate(reportImageBytesProvider(name));
          },
        );
    if (!mounted) return;
    ref.invalidate(reportImagesProvider);
    setState(() {
      _working = false;
      _failed = failed;
    });
    await _find();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_over.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Column(
              key: const ValueKey('report-images-print-size'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.reportImagesOversized(_over.length)),
                if (_working) ...[
                  Text(l10n.reportImagesBringing),
                  const LinearProgressIndicator(),
                ] else
                  TextButton.icon(
                    key: const ValueKey('report-images-bring-to-print'),
                    icon: const Icon(Icons.compress_outlined),
                    label: Text(l10n.reportImagesBringToPrint),
                    onPressed: _bring,
                  ),
              ],
            ),
          ),
        if (_failed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              l10n.reportImagesBringFailed(_failed.join(', ')),
              key: const ValueKey('report-images-bring-failed'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
      ],
    );
  }
}
