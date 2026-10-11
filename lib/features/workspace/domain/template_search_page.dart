// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1659 — a page of the server's template search (0283): compact cards
// the caller may read, and the cursor for the next page.
import '../../../core/data/json_reader.dart';
import 'workspace_template.dart';

class TemplateSearchPage {
  const TemplateSearchPage({this.templates = const [], this.nextCursor});
  final List<WorkspaceTemplate> templates;
  final String? nextCursor;

  factory TemplateSearchPage.fromJson(Object? json) {
    // Fail-closed (#2387): a malformed field reads as absent, and a row
    // without an id is left out.
    final r = JsonReader.of(
      json is Map ? json : const <String, Object?>{},
      context: 'template_search_page',
    );
    return TemplateSearchPage(
      templates: [
        for (final row in r.listOrAbsent('items'))
          if (row is Map && row['id'] is String)
            WorkspaceTemplate.fromRow(Map<String, dynamic>.from(row)),
      ],
      nextCursor: r.textOrAbsent('next_cursor'),
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
