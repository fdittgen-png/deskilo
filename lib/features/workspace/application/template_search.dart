// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1659 — the gallery's capability search: which of the listed templates
// is SET UP to do what the person asked, by each template's inspected
// configuration (#1655). The words-to-capabilities parse and the ranking
// are pure (domain/template_capabilities.dart); this is where the
// inspections come from, once per template per session, and where a
// failure to read them becomes an explicit "could not check" — never an
// empty result that reads as "no template does this".
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/trace/trace_logger.dart';
import '../domain/template_capabilities.dart';
import '../domain/template_inspection.dart';
import '../domain/template_search_page.dart';
import '../domain/workspace_repository.dart';
import '../domain/workspace_template.dart';
import '../providers/template_search_providers.dart';
import '../providers/workspace_providers.dart';

part 'template_search.g.dart';

class TemplateSearchResult {
  const TemplateSearchResult({
    required this.capabilities,
    this.matched = const [],
    this.unavailable = false,
  });

  /// The capabilities the words were read as.
  final List<String> capabilities;

  /// The templates that satisfy them, ranked, with their evidence.
  final List<TemplateMatch> matched;

  /// The inspections could not be read: nothing is claimed either way.
  final bool unavailable;

  Set<String> get matchedIds => {for (final m in matched) m.inspection.templateId};
}

class TemplateSearch {
  TemplateSearch(this._workspaces, [this._server]);

  final WorkspaceRepository _workspaces;

  /// #1659 — the server narrows the candidates first (0283): a template
  /// that switches a required feature OFF is never inspected. Without it
  /// every listed template is.
  final TemplateSearchRepository? _server;

  /// At most this many server pages are read for one search.
  static const maxPages = 5;

  Future<Set<String>?> _candidates(List<String> capabilities) async {
    final server = _server;
    final features = [
      for (final c in capabilities)
        if (c.startsWith('feature.')) c.substring('feature.'.length),
    ];
    if (server == null || features.isEmpty) return null;
    final ids = <String>{};
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final result = await server.search(required: features, limit: 100, cursor: cursor);
      ids.addAll(result.templates.map((t) => t.id));
      cursor = result.nextCursor;
      if (cursor == null) return ids;
    }
    return null; // more than we page through: inspect the listed ones
  }
  final _inspections = <String, TemplateInspection>{};

  /// Every capability in [capabilities] is REQUIRED; [freeWords] rank.
  Future<TemplateSearchResult> run({
    required List<String> capabilities,
    required List<String> freeWords,
    required List<WorkspaceTemplate> templates,
  }) async {
    final inspections = <TemplateInspection>[];
    try {
      final candidates = await _candidates(capabilities);
      for (final t in templates) {
        if (candidates != null && !candidates.contains(t.id)) continue;
        inspections.add(_inspections[t.id] ??=
            await _workspaces.inspectWorkspaceTemplate(t.id));
      }
    } catch (e, st) {
      TraceLogger.instance.warn('templates', 'capability search could not inspect',
          error: e, stackTrace: st);
      return TemplateSearchResult(capabilities: capabilities, unavailable: true);
    }
    return TemplateSearchResult(
      capabilities: capabilities,
      matched: matchTemplates(
        inspections,
        CapabilityQuery(required: capabilities, freeWords: freeWords),
      ),
    );
  }
}

@riverpod
TemplateSearch templateSearch(Ref ref) => TemplateSearch(
      ref.watch(workspaceRepositoryProvider),
      ref.watch(templateSearchRepositoryProvider),
    );
