// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — importing one bank file: the person picks it, says which format
// it is (the recognised one is chosen already), maps the columns of a
// spreadsheet, and learns what the import did — or why the file was
// refused whole.
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_picker.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/bank_import_commands.dart';
import '../../domain/bank/bank_file.dart';
import '../../domain/bank/bank_statement.dart';
import '../../domain/bank/csv_statement.dart';
import '../../providers/bank_statement_providers.dart';
import '../bank_labels.dart';
import 'bank_csv_mapping_sheet.dart';

/// The file name endings the bank formats are delivered with.
const List<String> _bankFileExtensions = [
  'xml', 'camt', 'sta', 'mt940', 'txt', 'cod', 'coda', 'ofx', 'qfx', 'csv',
];

/// Picks, reads and imports one bank file into [workspaceId].
Future<void> importBankFile(
  BuildContext context,
  WidgetRef ref, {
  required String workspaceId,
}) async {
  final l10n = context.l10n;
  final file = await ref.read(filePickerProvider)(
    XTypeGroup(label: l10n.bankFileTypeLabel, extensions: _bankFileExtensions),
  );
  if (file == null || !context.mounted) return;
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
    builder: (_) => BankFormatDialog(detected: detectBankFormat(bytes)),
  );
  if (format == null || !context.mounted) return;
  BankCsvMapping? csv;
  if (format == BankFileFormat.csv) {
    csv = await showBankCsvMapping(
      context,
      bytes,
      currency: ref.read(currentWorkspaceProvider).value?.currencyCode ?? '',
    );
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
          csv: csv,
        ),
  );
  if (!ok || !context.mounted) return;
  final refused = outcome?.refused;
  if (refused != null) {
    AppSnack.error(
      context,
      bankFileRefusal(l10n, refused, format: format, maxLines: settings.maxLines),
    );
    return;
  }
  final result = outcome!.result!;
  ref.invalidate(bankStatementsProvider(workspaceId));
  AppSnack.success(
    context,
    result.repeated
        ? l10n.bankImportRepeated
        : l10n.bankImported(result.created, result.known, result.review),
  );
}

/// Which format a file is read as; the recognised one is chosen.
@visibleForTesting
class BankFormatDialog extends StatefulWidget {
  const BankFormatDialog({required this.detected, super.key});

  final BankFileFormat? detected;

  @override
  State<BankFormatDialog> createState() => _BankFormatDialogState();
}

class _BankFormatDialogState extends State<BankFormatDialog> {
  late BankFileFormat? _format = widget.detected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.bankFormatTitle),
      content: SingleChildScrollView(
        child: RadioGroup<BankFileFormat>(
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
