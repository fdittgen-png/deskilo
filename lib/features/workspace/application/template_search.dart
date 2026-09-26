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
import '../domain/workspace_repository.dart';
import '../domain/workspace_template.dart';
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
  TemplateSearch(this._workspaces);

  final WorkspaceRepository _workspaces;
  final _inspections = <String, TemplateInspection>{};

  /// Every capability in [capabilities] is REQUIRED; [freeWords] rank.
  Future<TemplateSearchResult> run({
    required List<String> capabilities,
    required List<String> freeWords,
    required List<WorkspaceTemplate> templates,
  }) async {
    final inspections = <TemplateInspection>[];
    try {
      for (final t in templates) {
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
TemplateSearch templateSearch(Ref ref) =>
    TemplateSearch(ref.watch(workspaceRepositoryProvider));
