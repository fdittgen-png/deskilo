// SPDX-License-Identifier: 0BSD
//
// #875 — where a positioned layout takes over from the bands.
//
// Two documents can carry a layout: the invoice (and the proforma that
// borrows it) and every letter document. Both paths do the same three
// things — run the design against the data, fetch the images it names,
// draw it — and both fall back to the bands on a failure, with a trace
// that names the document, the element path and the cause. Kept out of
// invoice_actions.dart, which is at its budget and about the invoice.
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/trace/trace_logger.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/report_layout/layout_render.dart';
import '../domain/report_layout/layout_units.dart';
import '../providers/money_providers.dart';
import 'report_layout_defaults.dart';
import '../../../l10n/app_localizations.dart';
import 'invoice_actions.dart';

/// Renders [layoutXml] against [data] into a PDF, or returns null after
/// tracing why — the #470 contract that a broken design never blocks a
/// document. [what] names the document in the trace ("INV-2026-0047",
/// "Financial agreement Guilhem"), because a trace that cannot say which
/// document failed is a trace someone has to reproduce.
Future<Uint8List?> tryLayoutPdf({
  required String layoutXml,
  required Map<String, Object?> data,
  required String what,
  required String documentTitle,
  required String pageLabel,
  required Future<pw.Font> Function(String asset) font,
  Future<Uint8List?> Function(String name)? image,
  String watermark = '',
  String signatureLabel = '',
  String signature = '',
}) async {
  try {
    final document = renderLayoutDocument(layoutXml, data);
    final images = <String, Uint8List>{};
    if (image != null) {
      for (final name in layoutImageNames(document)) {
        final bytes = await image(name);
        if (bytes != null) images[name] = bytes;
      }
    }
    return await buildLayoutPdf(
      document: document,
      data: data,
      documentTitle: documentTitle,
      pageLabel: pageLabel,
      images: images,
      watermark: watermark,
      signatureLabel: signatureLabel,
      signature: signature,
      baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
      boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
    );
  } on LayoutException catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'report layout for $what failed at ${e.detail} (${e.error.name}) '
          '— rendering the bands instead',
      error: e.cause ?? e,
      stackTrace: e.stackTrace ?? st,
    );
    return null;
  } catch (e, st) {
    // #874 — an image store or font that cannot be reached must not
    // block a legal document either: the bands still render.
    TraceLogger.instance.warn(
      'money',
      'report layout for $what could not be built — rendering the bands instead',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

/// The positioned layout for letter [docId] in [language], or null when
/// that document still uses its bands (or the feature is off).
String? letterLayoutXml(
  WidgetRef ref, {
  required String docId,
  String language = '',
  AppLocalizations? l10n,
}) {
  final features = ref.read(enabledFeaturesSyncProvider);
  if (!features.contains(WorkspaceFeature.reportLayouts)) return null;
  // #874 — no design → the letter standard's default for a person-facing kind.
  return resolveLayoutXmlFor(
    template: invoicePdfTemplateFor(ref).forLocale(language),
    kindId: docId,
    letterStandard: features.contains(WorkspaceFeature.letterStandard),
    l10n: l10n,
  );
}

/// The library image named [name], for a layout rendered with a [ref].
Future<Uint8List?> layoutImage(WidgetRef ref, String name) async {
  final exact = await ref.read(reportImageBytesProvider(name).future);
  if (exact != null) return exact;
  // #920 — the SHIPPED layouts ask for an image called `logo`, because a
  // default cannot know what the owner called theirs. Nobody uploads a
  // file named exactly "logo": theirs is "coworking-logo-1-jpg" or
  // whatever the phone produced, so the letter came out without it while
  // the banded template — which references the real name — showed it.
  //
  // So `logo` is a ROLE, not a file name: the library's own logo is the
  // one named after it, else the only image there is. Anything else
  // stays an exact lookup, because a design that names a picture means
  // that picture.
  if (name != _logoRole) return null;
  final names = await ref.read(reportImagesProvider.future);
  final named = names.firstWhere(
    (n) => n.toLowerCase().contains(_logoRole),
    orElse: () => names.length == 1 ? names.first : '',
  );
  if (named.isEmpty) return null;
  return ref.read(reportImageBytesProvider(named).future);
}

/// The name the shipped layouts use for "the workspace's own mark".
const String _logoRole = 'logo';
