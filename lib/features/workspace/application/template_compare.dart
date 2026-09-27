// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1660 — comparing a shortlist: each template's inspection (#1655), read
// once, turned into #1659's comparison rows. The screen only shows them.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/template_capabilities.dart';
import '../providers/workspace_providers.dart';

part 'template_compare.g.dart';

/// The rows comparing [templateIds] (comma-joined, in shortlist order).
@riverpod
Future<List<ComparisonRow>> templateComparison(
  Ref ref,
  String templateIds,
) async {
  final repository = ref.watch(workspaceRepositoryProvider);
  final ids = templateIds.split(',').where((s) => s.isNotEmpty).toList();
  final inspections = [
    for (final id in ids) await repository.inspectWorkspaceTemplate(id),
  ];
  return compareTemplates(inspections);
}
