// SPDX-License-Identifier: 0BSD
//
// #842 — choosing what a message points at.
//
// Both original pickers were flat, unfiltered lists: seven days of every
// reservation in the workspace, every seat of a level. That is fine with
// four members and unusable with forty — the thing you want is somewhere
// in a list you have to scroll past. One sheet now serves every kind of
// reference, it filters as you type, and it says how much of the list
// you are looking at, so an empty result reads as "your words matched
// nothing" instead of "there is nothing here".
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';

/// One choosable target. [keywords] is what the filter matches on, so a
/// row can be findable by more than the words it shows.
typedef RefCandidate = ({
  String id,
  String label,
  String? detail,
  IconData icon,
  String keywords,
});

/// Builds a candidate whose searchable text is its own label and detail.
RefCandidate refCandidate({
  required String id,
  required String label,
  String? detail,
  required IconData icon,
  String extraKeywords = '',
}) =>
    (
      id: id,
      label: label,
      detail: detail,
      icon: icon,
      keywords: '$label ${detail ?? ''} $extraKeywords'.toLowerCase(),
    );

/// Asks which of [candidates] the message should point at. Returns the
/// chosen id, or null when the sheet is dismissed.
Future<String?> showRefPicker(
  BuildContext context, {
  required String title,
  required List<RefCandidate> candidates,
  required String keyPrefix,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RefPickerSheet(
        title: title,
        candidates: candidates,
        keyPrefix: keyPrefix,
      ),
    );

class _RefPickerSheet extends StatefulWidget {
  const _RefPickerSheet({
    required this.title,
    required this.candidates,
    required this.keyPrefix,
  });

  final String title;
  final List<RefCandidate> candidates;
  final String keyPrefix;

  @override
  State<_RefPickerSheet> createState() => _RefPickerSheetState();
}

class _RefPickerSheetState extends State<_RefPickerSheet> {
  String _query = '';

  /// Every word has to appear somewhere, in any order: typing a name and
  /// a date finds the one row carrying both.
  List<RefCandidate> get _visible {
    final words = _query.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (words.isEmpty) return widget.candidates;
    return [
      for (final candidate in widget.candidates)
        if (words.every(candidate.keywords.contains)) candidate,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final visible = _visible;
    // The filter earns its place only on a list long enough to hide
    // things; below that it is one more thing to look past.
    final filterable = widget.candidates.length > 6;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.xs),
              child: Text(widget.title, style: theme.textTheme.titleMedium),
            ),
            if (filterable)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: TextField(
                  key: Key('${widget.keyPrefix}-filter'),
                  autofocus: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    labelText: l10n?.noteRefFilterLabel ?? 'Filter',
                    helperText: l10n?.noteRefFilterCount(
                            visible.length, widget.candidates.length) ??
                        '${visible.length} of ${widget.candidates.length}',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
            Flexible(
              child: visible.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        l10n?.noteRefFilterEmpty ?? 'Nothing matches.',
                        key: Key('${widget.keyPrefix}-empty'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final candidate in visible)
                          ListTile(
                            key: Key('${widget.keyPrefix}-${candidate.id}'),
                            leading: Icon(candidate.icon),
                            title: Text(candidate.label),
                            subtitle: candidate.detail == null
                                ? null
                                : Text(candidate.detail!),
                            onTap: () =>
                                Navigator.of(context).pop(candidate.id),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
