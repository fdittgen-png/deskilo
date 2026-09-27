// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/workspace/domain/template_search_page.dart';
import '../../../features/workspace/domain/workspace_template.dart';

/// #1659 — the server search for tests and Demo: every template given,
/// one page at [pageSize], honouring the query words like the server.
class FakeTemplateSearchRepository implements TemplateSearchRepository {
  FakeTemplateSearchRepository({
    this._templates = const [],
    this.pageSize = 100,
    this.source,
  });
  final List<WorkspaceTemplate> _templates;

  /// Where the templates come from when they live in another fake (the
  /// workspace repository's), read at each search.
  final List<WorkspaceTemplate> Function()? source;
  List<WorkspaceTemplate> get templates => source?.call() ?? _templates;
  final int pageSize;
  final calls = <({String query, List<String> required, String? cursor})>[];

  @override
  Future<TemplateSearchPage> search({
    String query = '',
    List<String> required = const [],
    List<String> excluded = const [],
    int limit = 25,
    String? cursor,
  }) async {
    calls.add((query: query, required: required, cursor: cursor));
    final start = int.tryParse(cursor ?? '') ?? 0;
    final page = templates.skip(start).take(pageSize).toList();
    final next = start + pageSize < templates.length
        ? '${start + pageSize}'
        : null;
    return TemplateSearchPage(templates: page, nextCursor: next);
  }
}
