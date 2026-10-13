// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2357 — the filing-ready file of a prepared VAT return, where the
// workspace's country has one: the UStVA as ELSTER XML (Germany), the
// CA3 as an EDI-TVA interchange (France). The owner hands it to the
// channel that files it; nothing here transmits.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../application/save_vat_filing_file.dart';
import '../domain/vat_declaration.dart';
import '../domain/vat_filing_files.dart';

/// The button's label for [country], or null where no file exists.
String? vatFilingFileLabel(AppLocalizations l10n, String? country) =>
    switch (country) {
      'DE' => l10n.vatDeclElster,
      'FR' => l10n.vatDeclEdiTva,
      'GB' => l10n.vatDeclMtdCsv,
      _ => null,
    };

/// Asks what the file still needs, then lets [save] write it.
Future<void> exportVatFilingFile(
  BuildContext context,
  SaveVatFilingFile save,
  VatDeclaration declaration,
) async {
  final l10n = context.l10n;
  // The Steuernummer is not the VAT id a registered space keeps: asked
  // for the file, and not stored.
  final german = save.country == 'DE';
  final taxNumber = german
      ? await _askTaxNumber(context, l10n, save.party?.legalId ?? '')
      : '';
  if (taxNumber == null || !context.mounted) return;
  await runGuarded(
    context,
    domain: 'money',
    message: 'vat filing file failed',
    errorText: l10n.commonSaveFailed,
    action: () async {
      final String? path;
      try {
        path = await save(declaration, taxNumber: taxNumber);
      } on VatFilingFileException catch (e, st) {
        TraceLogger.instance.warn(
          'money',
          'vat filing file refused: ${e.problem.name}',
          stackTrace: st,
        );
        if (!context.mounted) return;
        AppSnack.error(context, switch (e.problem) {
          VatFilingFileProblem.period => l10n.vatDeclFilingPeriod,
          VatFilingFileProblem.taxNumber => l10n.vatDeclFilingTaxNumber,
          VatFilingFileProblem.vatNumber => l10n.vatDeclFilingVatNumber,
        });
        return;
      }
      if (!context.mounted) return;
      AppSnack.success(context, l10n.commonSavedTo(path ?? ''), replace: true);
    },
  );
}

/// Asks the Steuernummer the ELSTER file names; null when cancelled.
Future<String?> _askTaxNumber(
  BuildContext context,
  AppLocalizations l10n,
  String initial,
) => showDialog<String>(
  context: context,
  builder: (context) => _TaxNumberDialog(l10n: l10n, initial: initial),
);

class _TaxNumberDialog extends StatefulWidget {
  const _TaxNumberDialog({required this.l10n, required this.initial});

  final AppLocalizations l10n;
  final String initial;

  @override
  State<_TaxNumberDialog> createState() => _TaxNumberDialogState();
}

class _TaxNumberDialogState extends State<_TaxNumberDialog> {
  late final TextEditingController _number = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.vatDeclElster),
      content: AppTextField(
        key: const ValueKey('vat-filing-tax-number'),
        controller: _number,
        fieldKey: 'taxNumber',
        autofocus: true,
        label: l10n.vatDeclFilingTaxNumberField,
      ),
      actions: [
        TextButton(
          key: const ValueKey('vat-filing-tax-number-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('vat-filing-tax-number-ok'),
          onPressed: () => Navigator.of(context).pop(_number.text.trim()),
          child: Text(l10n.vatDeclElster),
        ),
      ],
    );
  }
}
