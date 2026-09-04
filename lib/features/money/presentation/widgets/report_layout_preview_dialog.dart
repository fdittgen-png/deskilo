// SPDX-License-Identifier: 0BSD
//
// #875 — the page-true quick preview of a positioned layout.
//
// Renders the CURRENT (unsaved) layout XML against the same data the
// band preview uses, resolves the images it names from the library, and
// shows one A4 sheet through the mirror. A layout that cannot be read
// says where and why, in the dialog — the same message `check` prints —
// rather than showing a blank page.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/report_layout/layout_model.dart';
import '../../domain/report_layout/layout_render.dart';
import '../../domain/report_layout/layout_units.dart';
import '../../providers/money_providers.dart';
import 'report_layout_preview.dart';
import 'report_page_style.dart';

Future<void> showLayoutQuickPreview(
  BuildContext context,
  WidgetRef ref, {
  required String layoutXml,
  required Map<String, Object?> data,
}) async {
  final l10n = AppLocalizations.of(context);
  LayoutDocument document;
  try {
    document = renderLayoutDocument(layoutXml, data);
  } on LayoutException catch (e, st) {
    // trace-exempt: an unreadable layout is shown to the designer with
    // its element path — the same words `check` prints — not traced.
    assert(st.toString().isNotEmpty);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n?.reportLayoutTitle ?? 'Positioned layout (XML)'),
        content: Text(_describe(e)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.commonClose ?? 'Close'),
          ),
        ],
      ),
    );
    return;
  }
  final images = <String, Uint8List>{};
  for (final name in layoutImageNames(document)) {
    final bytes = await ref.read(reportImageBytesProvider(name).future);
    if (bytes != null) images[name] = bytes;
  }
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 900),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Text(
                l10n?.reportLayoutPreview ?? 'Page preview',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: Container(
                color: ReportPage.backdrop,
                padding: const EdgeInsets.all(AppSpacing.md),
                child: InteractiveViewer(
                  minScale: 0.4,
                  maxScale: 2.5,
                  constrained: false,
                  child: LayoutPageView(
                    document: document,
                    data: data,
                    images: images,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n?.commonClose ?? 'Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// The refusal, worded as `check` prints it: the error class, the
/// element path, and the cause when there is one.
String _describe(LayoutException e) =>
    '${e.error.name}: ${e.detail}${e.cause == null ? '' : '\n\n${e.cause}'}';
