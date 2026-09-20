// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1280 S3 — what publishing this workspace as a template would carry, as
// the server's allow-list decides it (`template_publication_preview`, 0231).
import 'template_preview.dart';

/// An entity the chosen groups would publish, and the keys removed from it.
class PublishedEntity {
  const PublishedEntity({
    required this.entity,
    required this.group,
    this.stripped = const [],
  });

  final String entity;
  final TemplateGroup group;
  final List<String> stripped;
}

/// An entity that never leaves this workspace, whatever is chosen.
class NeverPublished {
  const NeverPublished({required this.entity, required this.reason});

  final String entity;

  /// The server's own sentence — shown only when this build has no words
  /// of its own for [entity].
  final String reason;
}

class TemplatePublication {
  const TemplatePublication({
    required this.published,
    required this.neverPublished,
    required this.planNames,
  });

  final List<PublishedEntity> published;
  final List<NeverPublished> neverPublished;

  /// Level, room, desk and seat names the plan would publish: names are
  /// merge keys and cannot be stripped, so the publisher sees them.
  final List<String> planNames;

  /// The groups that have something to publish, in the server's order.
  List<TemplateGroup> get groups => <TemplateGroup>{
        for (final p in published)
          if (p.group != TemplateGroup.unknown) p.group,
      }.toList();

  factory TemplatePublication.fromJson(Map<String, dynamic> json) =>
      TemplatePublication(
        published: [
          for (final raw in json['published'] as List? ?? const <Object?>[])
            if (raw is Map)
              PublishedEntity(
                entity: raw['entity'] as String? ?? '',
                group: TemplateGroup.fromWire(raw['group'] as String?),
                stripped: [
                  for (final k in raw['stripped'] as List? ?? const <Object?>[])
                    '$k'
                ],
              ),
        ],
        neverPublished: [
          for (final raw
              in json['never_published'] as List? ?? const <Object?>[])
            if (raw is Map)
              NeverPublished(
                entity: raw['entity'] as String? ?? '',
                reason: raw['reason'] as String? ?? '',
              ),
        ],
        planNames: [
          for (final n in json['plan_names'] as List? ?? const <Object?>[]) '$n'
        ],
      );
}
