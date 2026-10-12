// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1303 S3 — what a template sets up, before any workspace exists, as the
// server computed it (`template_outline`, 0239).
//
// It reads the same compatibility verdict and the same entity registry the
// creation applies, so the confirm step cannot promise a group the
// template will not bring, nor hide that this server refuses it.
import '../../../core/data/json_reader.dart';
import 'template_preview.dart';

class TemplateOutline {
  const TemplateOutline({
    required this.compatibility,
    required this.groups,
    this.reason,
  });

  final TemplateCompatibility compatibility;
  final String? reason;

  /// In registry order; a group a newer server names is [TemplateGroup.unknown].
  final List<TemplateGroup> groups;

  /// Creation with this template would be refused.
  bool get refused =>
      compatibility == TemplateCompatibility.notSupported;

  factory TemplateOutline.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'template_outline');
    return TemplateOutline(
      compatibility:
          TemplateCompatibility.fromWire(r.stringOrNull('compatibility')),
      reason: r.stringOrNull('reason'),
      groups: [
        for (final raw in r.list('groups'))
          if (raw is Map)
            TemplateGroup.fromWire(
              JsonReader.of(raw, context: r.context).stringOrNull('group'),
            ),
      ],
    );
  }
}
