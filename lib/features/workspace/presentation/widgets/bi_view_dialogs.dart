// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The two dialogs of the saved-views menu: a name, and a name with a scope.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/bi_query.dart';
import '../../domain/bi_saved_view.dart';
import 'bi_toolbar.dart';

class BiSaveAnswer {
  const BiSaveAnswer(this.name, this.scope, this.query);

  final String name;
  final BiViewScope scope;
  final BiQueryContext query;
}

class BiNameDialog extends StatefulWidget {
  const BiNameDialog({super.key, required this.initial});

  final String initial;

  @override
  State<BiNameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<BiNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      content: TextField(
        key: const ValueKey('bi-views-name'),
        controller: _name,
        autofocus: true,
        maxLength: 80,
        decoration: InputDecoration(labelText: l10n.biViewName),
      ),
      actions: [
        TextButton(
          key: const ValueKey('bi-view-save-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        TextButton(
          key: const ValueKey('bi-views-name-ok'),
          onPressed: () {
            final name = _name.text.trim();
            if (name.isNotEmpty) Navigator.of(context).pop(name);
          },
          child: Text(material.okButtonLabel),
        ),
      ],
    );
  }
}

class BiSaveDialog extends StatefulWidget {
  const BiSaveDialog({
    super.key,
    required this.query,
    required this.today,
    required this.canShare,
    required this.initialName,
  });

  final BiQueryContext query;
  final DateTime today;
  final bool canShare;
  final String initialName;

  @override
  State<BiSaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<BiSaveDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  var _scope = BiViewScope.private;
  var _fixed = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final relative = widget.query.period.isRelative;
    final current = widget.query.current(widget.today);
    return AlertDialog(
      title: Text(l10n.biViewSaveAs),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('bi-views-name'),
              controller: _name,
              autofocus: true,
              maxLength: 80,
              decoration: InputDecoration(labelText: l10n.biViewName),
            ),
            if (widget.canShare)
              SegmentedButton<BiViewScope>(
                key: const ValueKey('bi-views-scope'),
                segments: [
                  ButtonSegment(
                    value: BiViewScope.private,
                    label: Text(l10n.biViewScopePrivate),
                  ),
                  ButtonSegment(
                    value: BiViewScope.workspace,
                    label: Text(l10n.biViewScopeTeam),
                  ),
                ],
                selected: {_scope},
                onSelectionChanged: (s) => setState(() => _scope = s.first),
              ),
            if (relative) ...[
              const SizedBox(height: AppSpacing.sm),
              RadioGroup<bool>(
                key: const ValueKey('bi-view-relative-fixed'),
                groupValue: _fixed,
                onChanged: (v) => setState(() => _fixed = v ?? false),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<bool>(
                      key: const ValueKey('bi-views-period-moves'),
                      value: false,
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.biViewPeriodMoves),
                    ),
                    RadioListTile<bool>(
                      key: const ValueKey('bi-views-period-fixed'),
                      value: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        l10n.biViewPeriodFixed(
                          biPeriodLabel(current, l10n, locale),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('bi-view-share-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        TextButton(
          key: const ValueKey('bi-views-save-ok'),
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop(
              BiSaveAnswer(
                name,
                _scope,
                _fixed
                    ? widget.query.copyWith(period: BiPeriodRef.fixed(current))
                    : widget.query,
              ),
            );
          },
          child: Text(material.saveButtonLabel),
        ),
      ],
    );
  }
}
