// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/template_compare.dart';
import '../../domain/template_capabilities.dart';
import '../../domain/template_inspection.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_template.dart';
import '../feature_names.dart';
import 'template_compare_screen.dart';

/// The section a concrete path belongs to: `workspace.feature_flags`,
/// `workspace.booking_rules`, `tables.plans`, `floor_plan`, ...
String templateDetailSection(String path) {
  final table = RegExp(r'^tables\.([a-z_]+)').firstMatch(path);
  if (table != null) return 'tables.${table.group(1)}';
  final parts = path.split('.');
  if (parts.first == 'workspace' && parts.length > 1) {
    return 'workspace.${parts[1].split('[').first}';
  }
  return parts.first.split('[').first;
}

/// #1660 — what a template holds, read-only: every setting the server's
/// inspection found, grouped by section, each with its value or its state
/// in words (not only what is on), and a search that finds "refund" in
/// the validation section as easily as a feature by its name. Nothing
/// here writes a setting or opens an editor.
class TemplateDetailScreen extends ConsumerStatefulWidget {
  const TemplateDetailScreen({super.key, required this.template});
  final WorkspaceTemplate template;

  @override
  ConsumerState<TemplateDetailScreen> createState() =>
      _TemplateDetailScreenState();
}

class _TemplateDetailScreenState extends ConsumerState<TemplateDetailScreen> {
  String _filter = '';

  String _label(AppLocalizations? l10n, TemplateFieldRecord f) {
    const flag = 'workspace.feature_flags.';
    if (f.path.startsWith(flag)) {
      final key = f.path.substring(flag.length);
      final feature = WorkspaceFeature.values
          .where((w) => w.dbKey == key)
          .firstOrNull;
      if (feature != null) return featureName(l10n, feature);
    }
    return f.path
        .substring(templateDetailSection(f.path).length)
        .replaceFirst(RegExp(r'^\.'), '');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inspection = ref.watch(
      templateInspectionProvider(widget.template.id),
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.template.name)),
      body: inspection.when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(
          padding: AppSpacing.gutterAll,
          child: InlineBanner(
            key: const ValueKey('template-detail-unavailable'),
            icon: Icons.cloud_off_outlined,
            severity: InlineBannerSeverity.error,
            text: l10n?.compareUnavailable ?? 'These templates could not be read to compare them. Nothing is claimed either way.',
          ),
        ),
        data: (t) {
          final needle = _filter.trim().toLowerCase();
          final rows = <String, List<(String, String, String)>>{};
          for (final f in t.fields) {
            final label = _label(l10n, f);
            final value = comparisonCellText(
              l10n,
              ComparisonCell(
                value: f.value,
                disposition: f.disposition,
                absent: f.absent,
              ),
            );
            final hay = '$label ${f.path} $value'.toLowerCase();
            if (needle.isNotEmpty && !hay.contains(needle)) continue;
            (rows[templateDetailSection(f.path)] ??= []).add((
              f.path,
              label,
              value,
            ));
          }
          final sections = rows.keys.toList()..sort();
          return ListView(
            key: const ValueKey('template-detail'),
            padding: AppSpacing.gutterAll,
            children: [
              TextField(
                key: const ValueKey('template-detail-search'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText:
                      l10n?.templateDetailSearch ??
                      'Find a setting in this template',
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
              if (sections.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    key: const ValueKey('template-detail-none'),
                    l10n?.templateDetailNone ?? 'No setting matches.',
                  ),
                ),
              for (final section in sections) ...[
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    section,
                    key: ValueKey('template-detail-section-$section'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final (path, label, value) in rows[section]!)
                  ListTile(
                    key: ValueKey('template-detail-row-$path'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(label),
                    trailing: Text(value),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
