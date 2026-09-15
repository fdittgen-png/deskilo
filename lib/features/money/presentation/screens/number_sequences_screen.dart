// SPDX-License-Identifier: 0BSD
//
// #925 — every number series of the workspace, on one screen.
//
// The point of ONE screen is that the owner sees invoices and credit
// notes side by side and can tell at a glance that they are — or are
// not — sharing a series. Each row edits a format and previews the next
// number; the numbers themselves are drawn in the database when a
// document is issued, so nothing here can ever take one.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/number_sequence.dart';
import '../../providers/money_providers.dart';

class NumberSequencesScreen extends ConsumerWidget {
  const NumberSequencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sequences = ref.watch(numberSequencesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.numberSequencesTitle ?? 'Number sequences'),
      ),
      body: switch (sequences) {
        AsyncData(value: final rows) => ListView(
          padding: AppSpacing.lgAll,
          children: [
            Text(
              l10n?.numberSequencesIntro ??
                  'One series per journal, gapless: the number is taken in '
                      'the database the moment the document is issued.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final s in rows) _SequenceCard(sequence: s),
          ],
        ),
        AsyncError(:final error) => Center(child: Text(error.toString())),
        _ => const LoadingView(),
      },
    );
  }
}

class _SequenceCard extends ConsumerStatefulWidget {
  const _SequenceCard({required this.sequence});
  final NumberSequence sequence;
  @override
  ConsumerState<_SequenceCard> createState() => _SequenceCardState();
}

class _SequenceCardState extends ConsumerState<_SequenceCard> {
  // #1320 — a stored pair that restarts more often than it prints its date
  // opens as the finest restart the date can carry; Save repairs it.
  late NumberSequence _draft = widget.sequence.copyWith(
    reset: NumberSequence.effectiveReset(
      widget.sequence.datePart,
      widget.sequence.reset,
    ),
  );
  late final _prefix = TextEditingController(text: widget.sequence.prefix);
  late final _suffix = TextEditingController(text: widget.sequence.suffix);
  bool _saving = false;

  @override
  void dispose() {
    _prefix.dispose();
    _suffix.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _saving = true);
    final saved = await runGuarded(
      context,
      domain: 'money',
      message: 'number sequence save failed',
      errorText:
          l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref
          .read(moneyRepositoryProvider)
          .setNumberSequence(
            workspace.id,
            _draft.copyWith(
              prefix: _prefix.text.trim(),
              suffix: _suffix.text.trim(),
            ),
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ref.invalidate(numberSequencesProvider);
    if (saved) {
      AppSnack.success(context, l10n?.numberSequenceSaved ?? 'Sequence saved.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final preview = _draft
        .copyWith(prefix: _prefix.text, suffix: _suffix.text)
        .format(widget.sequence.nextValue, ref.watch(clockProvider).now());
    // #1320 — the two refusals of set_number_sequence, shown before Save.
    final removalBlocked = _draft
        .copyWith(prefix: _prefix.text.trim(), suffix: _suffix.text.trim())
        .removesDateFrom(widget.sequence);
    final repairedPair = !widget.sequence.isValidPair;
    final journalLabel = switch (_draft.journal) {
      'invoice' => l10n?.numberSequenceJournalInvoice ?? 'Invoices',
      'credit_note' => l10n?.numberSequenceJournalCreditNote ?? 'Credit notes',
      'vat_declaration' =>
        l10n?.numberSequenceJournalVatDeclaration ?? 'VAT declarations',
      'member' => l10n?.numberSequenceJournalMember ?? 'Members',
      'payment' => l10n?.numberSequenceJournalPayment ?? 'Payments',
      _ => _draft.journal,
    };
    return Card(
      key: ValueKey('number-sequence-${_draft.journal}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(journalLabel, style: theme.textTheme.titleMedium),
                ),
                Chip(
                  label: Text(
                    l10n?.numberSequenceGapless ?? 'Gapless — guaranteed',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // The live preview is the reason the screen exists.
            Text(
              '${l10n?.numberSequenceNext ?? 'Next number'} · $preview',
              key: ValueKey('number-sequence-preview-${_draft.journal}'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('number-sequence-prefix-${_draft.journal}'),
                    controller: _prefix,
                    enabled: !_saving,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n?.numberSequencePrefix ?? 'Prefix',
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextField(
                    key: ValueKey('number-sequence-suffix-${_draft.journal}'),
                    controller: _suffix,
                    enabled: !_saving,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n?.numberSequenceSuffix ?? 'Suffix',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<NumberDatePart>(
                    key: ValueKey('number-sequence-date-${_draft.journal}'),
                    initialValue: _draft.datePart,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n?.numberSequenceDatePart ?? 'Date',
                      errorText: removalBlocked
                          ? l10n?.numberSequenceDateRemovalBlocked ??
                              'Numbers were already issued with the date. '
                                  'Removing it could repeat one — change the '
                                  'prefix or suffix too.'
                          : null,
                      errorMaxLines: 4,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: NumberDatePart.none,
                        child: Text(l10n?.numberSequenceDateNone ?? 'None'),
                      ),
                      DropdownMenuItem(
                        value: NumberDatePart.year,
                        child: Text(l10n?.numberSequenceDateYear ?? 'Year'),
                      ),
                      DropdownMenuItem(
                        value: NumberDatePart.yearMonth,
                        child: Text(
                          l10n?.numberSequenceDateYearMonth ?? 'Year-month',
                        ),
                      ),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(
                            () => _draft = v == null
                                ? _draft
                                : _draft.copyWith(
                                    datePart: v,
                                    // #1320 — a restart the new date cannot
                                    // carry becomes the finest one it can.
                                    reset: NumberSequence.effectiveReset(
                                      v,
                                      _draft.reset,
                                    ),
                                  ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('number-sequence-digits-${_draft.journal}'),
                    initialValue: _draft.digits,
                    decoration: InputDecoration(
                      labelText: l10n?.numberSequenceDigits ?? 'Digits',
                    ),
                    items: [
                      for (var d = 1; d <= 9; d++)
                        DropdownMenuItem(value: d, child: Text(d.toString())),
                    ],
                    onChanged: _saving
                        ? null
                        : (v) => setState(
                            () => _draft = _draft.copyWith(digits: v),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<NumberReset>(
              // Keyed by the date part: the restarts on offer change with
              // it, and a form field keeps its initial value otherwise.
              key: ValueKey(
                'number-sequence-reset-${_draft.journal}-${_draft.datePart.name}',
              ),
              initialValue: _draft.reset,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n?.numberSequenceReset ?? 'Restart',
                helperText: _draft.datePart == NumberDatePart.yearMonth
                    ? null
                    : l10n?.numberSequenceResetLimited ??
                        'A number restarts at most as often as it shows its '
                            'date — otherwise it would print an earlier '
                            'number again.',
                helperMaxLines: 4,
                errorText: repairedPair
                    ? l10n?.numberSequenceResetWasInvalid ??
                        'This series restarted more often than it shows its '
                            'date. Save to keep a restart that cannot repeat '
                            'a number.'
                    : null,
                errorMaxLines: 4,
              ),
              items: [
                for (final reset in NumberSequence.resetsFor(_draft.datePart))
                  DropdownMenuItem(
                    value: reset,
                    child: Text(switch (reset) {
                      NumberReset.never =>
                        l10n?.numberSequenceResetNever ?? 'Never',
                      NumberReset.yearly =>
                        l10n?.numberSequenceResetYearly ?? 'Every year',
                      NumberReset.monthly =>
                        l10n?.numberSequenceResetMonthly ?? 'Every month',
                    }),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _draft = _draft.copyWith(reset: v)),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: ValueKey('number-sequence-save-${_draft.journal}'),
              onPressed: _saving || removalBlocked ? null : _save,
              child: Text(l10n?.commonSave ?? 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
