// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1659 — a page of the server's template search (0283): compact cards
// the caller may read, and the cursor for the next page.
import 'workspace_template.dart';

class TemplateSearchPage {
  const TemplateSearchPage({this.templates = const [], this.nextCursor});
  final List<WorkspaceTemplate> templates;
  final String? nextCursor;

  factory TemplateSearchPage.fromJson(Object? json) {
    final m = json is Map ? json : const <String, Object?>{};
    return TemplateSearchPage(
      templates: [
        for (final row in m['items'] is List ? m['items'] as List : const [])
          if (row is Map && row['id'] is String)
            WorkspaceTemplate.fromRow(Map<String, dynamic>.from(row)),
      ],
      nextCursor: m['next_cursor'] is String
          ? m['next_cursor'] as String
          : null,
    );
  }
}

abstract interface class TemplateSearchRepository {
  /// One page. [required] and [excluded] are feature flag names; a
  /// required flag drops only templates that switch it off.
  Future<TemplateSearchPage> search({
    String query = '',
    List<String> required = const [],
    List<String> excluded = const [],
    int limit = 25,
    String? cursor,
  });
}
