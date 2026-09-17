// SPDX-License-Identifier: 0BSD
//
// #1303 S3 — what a template sets up, before any workspace exists, as the
// server computed it (`template_outline`, 0239).
//
// It reads the same compatibility verdict and the same entity registry the
// creation applies, so the confirm step cannot promise a group the
// template will not bring, nor hide that this server refuses it.
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

  factory TemplateOutline.fromJson(Map<String, dynamic> json) =>
      TemplateOutline(
        compatibility:
            TemplateCompatibility.fromWire(json['compatibility'] as String?),
        reason: json['reason'] as String?,
        groups: [
          for (final raw in json['groups'] as List? ?? const <Object?>[])
            if (raw is Map) TemplateGroup.fromWire(raw['group'] as String?),
        ],
      );
}
