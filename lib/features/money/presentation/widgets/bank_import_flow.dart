// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — importing one bank file: the person picks it, says which format
// it is (the recognised one is chosen already), maps the columns of a
// spreadsheet, and learns what the import did — or why the file was
// refused whole.
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_drop.dart';
import '../../../../core/files/file_picker.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/bank_import_commands.dart';
import '../../domain/bank/bank_file.dart';
import '../../domain/bank/bank_records.dart';
import '../../domain/bank/bank_statement.dart';
import '../../domain/bank/csv_statement.dart';
import '../../providers/bank_statement_providers.dart';
import '../bank_account_words.dart';
import '../bank_labels.dart';
import 'bank_csv_mapping_sheet.dart';

/// The file name endings the bank formats are delivered with.
const List<String> _bankFileExtensions = [
  'xml', 'camt', 'sta', 'mt940', 'txt', 'cod', 'coda', 'ofx', 'qfx', 'csv',
];

/// Picks, reads and imports one bank file into [workspaceId]; a
/// spreadsheet's currency defaults to the space's [currency].
class BankImportFlow {
  const BankImportFlow(this._ref, {required this.workspaceId, required this.currency});

  final WidgetRef _ref;
  final String workspaceId;
  final String currency;

  /// What the place takes: the picker's filter and the drop zone's.
  static XTypeGroup typeGroup(AppLocalizations l10n) =>
      XTypeGroup(label: l10n.bankFileTypeLabel, extensions: _bankFileExtensions);

  Future<void> run(BuildContext context) async {
    final file = await _ref.read(filePickerProvider)(typeGroup(context.l10n));
    if (file == null || !context.mounted) return;
    await importFile(context, file);
  }

  /// Reads and imports [file] — the picked one or a dropped one alike
  /// (#3623): the same size bound, format choice and refusals.
  Future<void> importFile(BuildContext context, XFile file) async {
    final ref = _ref;
    final l10n = context.l10n;
    final settings = ref.read(bankImportSettingsProvider);
    // A file over the bound is refused before its bytes are read.
    if (await file.length() > settings.maxBytes) {
      if (!context.mounted) return;
      AppSnack.error(context, l10n.bankRefusedTooLarge);
      return;
    }
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;
    final format = await showDialog<BankFileFormat>(
      context: context,
      builder: (_) => _BankFormatDialog(detected: detectBankFormat(bytes)),
    );
    if (format == null || !context.mounted) return;
    // #4496 -- every statement is imported into one of the business's bank accounts
    final account = await _pickAccount(context);
    if (account == null || !context.mounted) return;
    BankCsvMapping? csv;
    if (format == BankFileFormat.csv) {
      csv = await showBankCsvMapping(context, bytes, account: account);
      if (csv == null || !context.mounted) return;
    }
    BankImportOutcome? outcome;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'bank statement import failed',
      errorText: l10n.bankImportFailed,
      action: () async => outcome = await ref
          .read(bankImportCommandsProvider)
          .importFile(
            workspaceId,
            bytes: bytes,
            fileName: file.name,
            format: format,
            settings: settings,
            into: (bankAccountId: account.id, csv: csv),
          ),
    );
    if (!ok || !context.mounted) return;
    final accountRefused = outcome?.accountRefused;
    if (accountRefused != null) {
      AppSnack.error(context, bankAccountRefusalText(l10n, accountRefused, account: account));
      return;
    }
    final refused = outcome?.refused;
    if (refused != null) {
      AppSnack.error(
        context,
        bankFileRefusal(l10n, refused, format: format, maxLines: settings.maxLines),
      );
      return;
    }
    final result = outcome!.result!;
    ref
      ..invalidate(bankStatementsProvider(workspaceId))
      ..invalidate(unattachedBankNamesProvider(workspaceId));
    AppSnack.success(
      context,
      result.repeated
          ? l10n.bankImportRepeated
          : l10n.bankImported(result.created, result.known, result.review),
    );
  }

  /// The account the file is imported into: the only active one, else the one the person picks; none, and the person
  /// is told to add one under Master data.
  Future<BankAccount?> _pickAccount(BuildContext context) async {
    final l10n = context.l10n;
    final List<BankAccount> all;
    try {
      all = await _ref.read(bankAccountsProvider(workspaceId).future);
    } on Object catch (e, st) {
      TraceLogger.instance.log(TraceLevel.info, 'money', 'the bank accounts could not be read', error: e, stackTrace: st);
      if (context.mounted) AppSnack.error(context, l10n.bankImportFailed);
      return null;
    }
    final active = [for (final a in all) if (!a.archived) a];
    if (!context.mounted) return null;
    if (active.isEmpty) {
      AppSnack.error(context, l10n.bankImportNeedsAccount);
      return null;
    }
    if (active.length == 1) return active.single;
    return showDialog<BankAccount>(context: context, builder: (_) => _BankAccountDialog(accounts: active));
  }
}

/// #3623 — a bank file dropped onto [child] is imported exactly as a picked
/// one: the same size bound, format choice and refusals.
class BankImportDropZone extends ConsumerWidget {
  const BankImportDropZone({
    required this.workspaceId,
    required this.currency,
    required this.child,
    super.key,
  });

  final String workspaceId;
  final String currency;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FileDropZone(
    typeGroup: BankImportFlow.typeGroup(context.l10n),
    onFile: (file) => BankImportFlow(
      ref,
      workspaceId: workspaceId,
      currency: currency,
    ).importFile(context, file),
    child: child,
  );
}

/// Which format a file is read as; the recognised one is chosen.
class _BankFormatDialog extends StatefulWidget {
  const _BankFormatDialog({required this.detected});

  final BankFileFormat? detected;

  @override
  State<_BankFormatDialog> createState() => _BankFormatDialogState();
}

class _BankFormatDialogState extends State<_BankFormatDialog> {
  late BankFileFormat? _format = widget.detected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.bankFormatTitle),
      content: SingleChildScrollView(
        child: RadioGroup<BankFileFormat>(
          key: const ValueKey('bank-format-group'),
          groupValue: _format,
          onChanged: (f) => setState(() => _format = f),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final f in BankFileFormat.values)
                RadioListTile<BankFileFormat>(
                  key: ValueKey('bank-format-${f.name}'),
                  value: f,
                  contentPadding: EdgeInsets.zero,
                  title: Text(bankFormatLabel(l10n, f)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('bank-format-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('bank-format-read'),
          onPressed: _format == null
              ? null
              : () => Navigator.of(context).pop(_format),
          child: Text(l10n.bankFormatRead),
        ),
      ],
    );
  }
}

/// #4496 -- the account a statement is imported into, one of the business's active accounts.
class _BankAccountDialog extends StatefulWidget {
  const _BankAccountDialog({required this.accounts});

  final List<BankAccount> accounts;

  @override
  State<_BankAccountDialog> createState() => _BankAccountDialogState();
}

class _BankAccountDialogState extends State<_BankAccountDialog> {
  BankAccount? _account;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.bankImportAccountTitle),
      content: SingleChildScrollView(
        child: RadioGroup<String>(
          key: const ValueKey('bank-account-group'),
          groupValue: _account?.id,
          onChanged: (id) => setState(() => _account = widget.accounts.firstWhere((a) => a.id == id)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final a in widget.accounts)
                RadioListTile<String>(
                  key: ValueKey('bank-account-${a.id}'),
                  value: a.id,
                  contentPadding: EdgeInsets.zero,
                  title: Text(a.name),
                  subtitle: Text(a.iban.isEmpty ? a.currency : '${a.iban} · ${a.currency}'),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('bank-account-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('bank-account-pick'),
          onPressed: _account == null ? null : () => Navigator.of(context).pop(_account),
          child: Text(l10n.bankImportAccountPick),
        ),
      ],
    );
  }
}
