// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1280 S3 — what publishing this workspace as a template would carry, as
// the server's allow-list decides it (`template_publication_preview`, 0231).
import 'template_preview.dart';
import '../../../core/data/json_reader.dart';

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

  factory TemplatePublication.fromJson(Map<String, dynamic> json) {
    final r = JsonReader(json, context: 'template_publication');
    List<JsonReader> rows(String key) => [
      for (final raw in r.list(key))
        if (raw is Map) JsonReader.of(raw, context: '${r.context}.$key'),
    ];
    return TemplatePublication(
      published: [
        for (final row in rows('published'))
          PublishedEntity(
            entity: row.stringOr('entity'),
            group: TemplateGroup.fromWire(row.stringOrNull('group')),
            stripped: [for (final k in row.list('stripped')) '$k'],
          ),
      ],
      neverPublished: [
        for (final row in rows('never_published'))
          NeverPublished(
            entity: row.stringOr('entity'),
            reason: row.stringOr('reason'),
          ),
      ],
      planNames: [for (final n in r.list('plan_names')) '$n'],
    );
  }
}

/// #1658 — a publication request id reused with other arguments: the
/// first request already published; this one is not a retry of it.
class TemplatePublishConflict implements Exception {
  const TemplatePublishConflict();
  @override
  String toString() => 'this publication request was already used for another form';
}
