// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/images/report_picture_bytes.dart';
import '../../../../core/images/report_picture_sizes.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../workspace/providers/workspace_providers.dart';
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

  /// The stored pictures over the weight, from the listing's sizes.
  Future<void> _find() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    try {
      final weights = await ref
          .read(reportTemplateRepositoryProvider)
          .reportImageWeights(workspace.id);
      if (!mounted) return;
      setState(
        () => _over = [
          for (final e in weights.entries)
            if (e.value > reportPictureMaxBytes) e.key,
        ]..sort(),
      );
    } on Object {
      // trace-exempt: the line is an offer; the library's own list shows
      // a failed read with its retry.
      if (mounted) setState(() => _over = const []);
    }
  }

  /// Replaces [_over] one by one; a picture whose new version could not be
  /// written stays as it was stored.
  Future<void> _bring() async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final repository = ref.read(reportTemplateRepositoryProvider);
    setState(() {
      _working = true;
      _failed = const [];
    });
    final failed = <String>[];
    for (final name in _over) {
      try {
        final stored = await repository.fetchReportImage(workspace.id, name);
        if (stored == null) {
          failed.add(name);
          continue;
        }
        final made = await reportPictureForPrint(stored);
        if (made.bytes.lengthInBytes >= stored.lengthInBytes) {
          failed.add(name);
          continue;
        }
        await repository.uploadReportImage(
          workspace.id,
          name: name,
          bytes: made.bytes,
          contentType: made.contentType,
        );
        if (!mounted) return;
        ref.invalidate(reportImageBytesProvider(name));
      } on Object {
        // trace-exempt: a picture that cannot be replaced is named below and
        // stays as it was stored.
        failed.add(name);
      }
    }
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_over.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              key: const ValueKey('report-images-print-size'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.reportImagesOversized(_over.length)),
                if (_working)
                  Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l10n.reportImagesBringing)),
                    ],
                  )
                else
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
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l10n.reportImagesBringFailed(_failed.join(', ')),
              key: const ValueKey('report-images-bring-failed'),
              style: TextStyle(color: scheme.error),
            ),
          ),
      ],
    );
  }
}
