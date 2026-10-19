// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/book_period.dart';
import '../../providers/book_period_providers.dart';
import 'premises_lease_dialogs.dart';

Future<void> _showBookPeriodsSheet(
  BuildContext context,
  String workspaceId, {
  required bool isOwner,
}) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => BookPeriodsView(workspaceId: workspaceId, isOwner: isOwner),
);

/// The Money door to the periods of the books and the export log.
class BookPeriodsButton extends StatelessWidget {
  const BookPeriodsButton({
    required this.workspaceId,
    required this.isOwner,
    super.key,
  });

  final String workspaceId;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: const ValueKey('book-periods-button'),
      onPressed: () =>
          _showBookPeriodsSheet(context, workspaceId, isOwner: isOwner),
      icon: const Icon(Icons.lock_clock_outlined),
      label: Text(context.l10n.bookPeriodsTitle),
    );
  }
}

/// The closed periods with the doors to close and reopen (for an owner), and
/// the log of the files handed to the accountant.
@visibleForTesting
class BookPeriodsView extends ConsumerWidget {
  const BookPeriodsView({
    required this.workspaceId,
    required this.isOwner,
    super.key,
  });

  final String workspaceId;
  final bool isOwner;

  Future<void> _change(
    BuildContext context,
    WidgetRef ref,
    Future<bool?> Function() dialog,
  ) async {
    if (await dialog() != true) return;
    ref.invalidate(bookPeriodsProvider(workspaceId));
    if (context.mounted) AppSnack.success(context, context.l10n.bookPeriodsSaved);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final overview = ref.watch(bookPeriodsProvider(workspaceId));
    return SheetShell(
      title: l10n.bookPeriodsTitle,
      children: [
        Text(l10n.bookPeriodsIntro, style: Theme.of(context).textTheme.bodySmall),
        if (isOwner)
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('book-period-close'),
              onPressed: () => _change(
                context,
                ref,
                () => _showCloseDialog(context, workspaceId),
              ),
              icon: const Icon(Icons.lock_outline),
              label: Text(l10n.bookPeriodsClose),
            ),
          ),
        overview.when(
          loading: () => const LoadingView(),
          error: (_, _) => Text(l10n.bookPeriodsLoadFailed),
          data: (o) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (o.periods.isEmpty)
                Text(l10n.bookPeriodsEmpty, key: const ValueKey('book-periods-empty')),
              for (final p in o.periods)
                Card(
                  key: ValueKey('book-period-${p.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${material.formatMediumDate(p.from)} – ${material.formatMediumDate(p.to)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          p.closed
                              ? (p.reason == BookPeriodReason.vatFiled
                                    ? l10n.bookPeriodsClosedVat
                                    : l10n.bookPeriodsClosedOwner)
                              : l10n.bookPeriodsReopened(p.reopenReason),
                          key: ValueKey('book-period-state-${p.id}'),
                        ),
                        if (isOwner && p.closed)
                          TextButton(
                            key: ValueKey('book-period-reopen-${p.id}'),
                            onPressed: () => _change(
                              context,
                              ref,
                              () => _showReopenDialog(context, workspaceId, p),
                            ),
                            child: Text(l10n.bookPeriodsReopen),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.bookPeriodsExports, style: Theme.of(context).textTheme.titleSmall),
              if (o.exports.isEmpty)
                Text(l10n.bookPeriodsNoExports, key: const ValueKey('book-exports-empty')),
              for (final e in o.exports)
                ListTile(
                  key: ValueKey('book-export-${e.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    l10n.bookPeriodsExportLine(
                      e.formatId.toUpperCase(),
                      material.formatMediumDate(e.from),
                      material.formatMediumDate(e.to),
                    ),
                  ),
                  subtitle: Text(
                    '${material.formatMediumDate(e.exportedAt)} · '
                    '${e.sha256.substring(0, 12)}…'
                    '${e.closedPeriod ? ' · ${l10n.bookPeriodsExportClosed}' : ''}',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Closes a period of the books: its first and last day, both before today.
Future<bool?> _showCloseDialog(BuildContext context, String workspaceId) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _CloseDialog(workspaceId: workspaceId),
    );

class _CloseDialog extends ConsumerStatefulWidget {
  const _CloseDialog({required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<_CloseDialog> createState() => _CloseDialogState();
}

class _CloseDialogState extends ConsumerState<_CloseDialog> {
  DateTime? _from;
  DateTime? _to;
  var _invalid = false;

  void _edit(VoidCallback change) => setState(change);

  Future<void> _save() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null) {
      _edit(() => _invalid = true);
      return;
    }
    final navigator = Navigator.of(context);
    var accepted = false;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'close book period failed',
      errorText: context.l10n.bookPeriodsRefused,
      action: () async {
        accepted =
            await ref
                .read(bookPeriodCommandProvider)
                .close(widget.workspaceId, from, to, ref.read(clockProvider).now()) !=
            null;
      },
    );
    if (ok && accepted && mounted) {
      navigator.pop(true);
    } else if (ok && mounted) {
      _edit(() => _invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = ref.read(clockProvider).now();
    return AlertDialog(
      title: Text(l10n.bookPeriodsClose),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.bookPeriodsCloseBody),
            LeaseDateButton(
              fieldKey: 'book-period-from',
              label: l10n.bookPeriodsFrom,
              value: _from,
              first: DateTime(now.year - 20),
              last: now,
              onPicked: (d) => _edit(() => _from = d),
            ),
            LeaseDateButton(
              fieldKey: 'book-period-to',
              label: l10n.bookPeriodsTo,
              value: _to,
              first: _from ?? DateTime(now.year - 20),
              last: now,
              onPicked: (d) => _edit(() => _to = d),
            ),
            if (_invalid)
              Text(
                l10n.bookPeriodsInvalid,
                key: const ValueKey('book-period-invalid'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('book-period-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('book-period-close-save'),
          onPressed: _save,
          child: Text(l10n.bookPeriodsClose),
        ),
      ],
    );
  }
}

/// Reopens a closed period; the reason is kept with it.
Future<bool?> _showReopenDialog(
  BuildContext context,
  String workspaceId,
  BookPeriod period,
) => showDialog<bool>(
  context: context,
  builder: (_) => _ReopenDialog(workspaceId: workspaceId, period: period),
);

class _ReopenDialog extends ConsumerStatefulWidget {
  const _ReopenDialog({required this.workspaceId, required this.period});

  final String workspaceId;
  final BookPeriod period;

  @override
  ConsumerState<_ReopenDialog> createState() => _ReopenDialogState();
}

class _ReopenDialogState extends ConsumerState<_ReopenDialog> {
  final _reason = TextEditingController();
  var _invalid = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    var accepted = false;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'reopen book period failed',
      errorText: context.l10n.bookPeriodsRefused,
      action: () async {
        accepted =
            await ref
                .read(bookPeriodCommandProvider)
                .reopen(widget.workspaceId, widget.period, _reason.text) !=
            null;
      },
    );
    if (ok && accepted && mounted) {
      navigator.pop(true);
    } else if (ok && mounted) {
      setState(() => _invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.bookPeriodsReopen),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.bookPeriodsReopenBody),
            AppTextField(
              key: const ValueKey('book-period-reason'),
              controller: _reason,
              label: l10n.bookPeriodsReason,
              maxLength: 300,
            ),
            if (_invalid)
              Text(
                l10n.bookPeriodsInvalid,
                key: const ValueKey('book-period-reopen-invalid'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('book-period-reopen-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('book-period-reopen-save'),
          onPressed: _save,
          child: Text(l10n.bookPeriodsReopen),
        ),
      ],
    );
  }
}
