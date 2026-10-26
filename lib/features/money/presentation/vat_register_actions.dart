// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The buttons that save the registers and the annual summary of a Spanish
// or an Italian space beside its returns (`application/vat_register_files.dart`
// writes them). Each is a file for the owner or the adviser; nothing here
// transmits.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../application/vat_register_files.dart';
import '../domain/vat_filing_terms.dart';
import '../domain/vat_form_catalogue.dart';
import '../domain/vat_register_es.dart' show isEsActivity;
import '../domain/vat_registers.dart';
import '../providers/vat_declaration_providers.dart';
import 'invoice_actions.dart';
import 'vat_filing_file_actions.dart';

/// The buttons of the period `[start, end]` (its last day included) for
/// the workspace's country: the registers when [registers] (the VAT report
/// is on), the annual summary always beside the declarations.
class VatCountryRegisters extends ConsumerWidget {
  const VatCountryRegisters({
    super.key,
    required this.start,
    required this.end,
    required this.registers,
  });

  final DateTime start;
  final DateTime end;
  final bool registers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final country =
        ref.watch(vatRegisterFilesProvider).party?.countryCode ?? '';
    final kinds = registers
        ? vatRegistersFor(country)
        : const <VatRegisterKind>[];
    final annual = vatAnnualSummaryName(country);
    if (kinds.isEmpty && annual == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final kind in kinds)
            switch (kind) {
              VatRegisterKind.esLibro => OutlinedButton.icon(
                key: const ValueKey('vat-register-es-libro'),
                onPressed: () => _esLibro(context, ref),
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(l10n.vatRegisterEsLibro),
              ),
              VatRegisterKind.esSii => OutlinedButton.icon(
                key: const ValueKey('vat-register-es-sii'),
                onPressed: () => _deliver(
                  context,
                  ref,
                  () => ref
                      .read(vatRegisterFilesProvider)
                      .esSii(start: start, end: end),
                ),
                icon: const Icon(Icons.code_outlined),
                label: Text(l10n.vatRegisterEsSii),
              ),
              VatRegisterKind.es347 => OutlinedButton.icon(
                key: const ValueKey('vat-register-es-347'),
                onPressed: () => _es347(context, ref),
                icon: const Icon(Icons.groups_outlined),
                label: Text(l10n.vatRegisterEs347('${end.year}')),
              ),
              VatRegisterKind.itRegistro => OutlinedButton.icon(
                key: const ValueKey('vat-register-it-registro'),
                onPressed: () => _deliver(
                  context,
                  ref,
                  () => ref
                      .read(vatRegisterFilesProvider)
                      .itRegistro(start: start, end: end),
                ),
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(l10n.vatRegisterItRegistro),
              ),
            },
          if (annual != null)
            OutlinedButton.icon(
              key: const ValueKey('vat-annual-summary'),
              onPressed: () => _deliver(
                context,
                ref,
                () => ref
                    .read(vatRegisterFilesProvider)
                    .annualSummary(
                      year: end.year,
                      header: [
                        l10n.vatAnnualSummaryBox,
                        l10n.vatAnnualSummaryLabel,
                        l10n.vatAnnualSummaryBase,
                        l10n.vatAnnualSummaryTax,
                      ],
                    ),
                empty: l10n.vatAnnualSummaryEmpty('${end.year}'),
              ),
              icon: const Icon(Icons.calendar_view_month_outlined),
              label: Text(l10n.vatAnnualSummaryButton(annual, '${end.year}')),
            ),
        ],
      ),
    );
  }

  Future<void> _esLibro(BuildContext context, WidgetRef ref) async {
    final activity = await showDialog<String>(
      context: context,
      builder: (context) => _ActivityDialog(l10n: context.l10n),
    );
    if (activity == null || !context.mounted) return;
    await _deliver(
      context,
      ref,
      () => ref
          .read(vatRegisterFilesProvider)
          .esLibro(end: end, activity: activity),
    );
  }

  Future<void> _es347(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final sii = await showDialog<bool>(
      context: context,
      builder: (context) => _SiiDialog(l10n: l10n),
    );
    if (sii == null || !context.mounted) return;
    await _deliver(
      context,
      ref,
      () => ref
          .read(vatRegisterFilesProvider)
          .es347(year: end.year, immediateSupply: sii),
      empty: l10n.vatRegister347Empty('${end.year}'),
    );
  }

  /// Writes the file [build] answers and hands it over; says so when the
  /// period holds nothing ([empty], else the register's own words) or the
  /// file is refused (the space's NIF, an invoice the schema cannot hold, a
  /// space in SII asking for a modelo 347).
  Future<void> _deliver(
    BuildContext context,
    WidgetRef ref,
    Future<VatRegisterFile?> Function() build, {
    String? empty,
  }) async {
    final l10n = context.l10n;
    final VatRegisterFile? file;
    try {
      file = await build();
    } on VatFilingFileException catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'vat register refused: ${e.problem.name}',
        stackTrace: st,
      );
      if (context.mounted) {
        // A register names the space's NIF, not a UK VAT number.
        AppSnack.error(
          context,
          e.problem == VatFilingFileProblem.vatNumber
              ? l10n.vatRegisterNif
              : vatFilingProblemText(l10n, e.problem),
        );
      }
      return;
    }
    if (!context.mounted) return;
    if (file == null) {
      AppSnack.info(context, empty ?? l10n.vatRegisterEmpty);
      return;
    }
    await savePdfToDownloads(
      context,
      ref,
      bytes: file.bytes,
      fileName: file.fileName,
    );
  }
}

class _ActivityDialog extends StatefulWidget {
  const _ActivityDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_ActivityDialog> createState() => _ActivityDialogState();
}

class _ActivityDialogState extends State<_ActivityDialog> {
  final _fields = FormControllers({'activity': ''});
  String? _error;

  @override
  void dispose() {
    _fields.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _fields.text('activity');
    if (!isEsActivity(value)) {
      setState(() => _error = widget.l10n.vatRegisterActivityInvalid);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      title: Text(l10n.vatRegisterEsLibro),
      content: AppTextField(
        key: const ValueKey('vat-register-activity'),
        controller: _fields['activity'],
        fieldKey: 'activity',
        autofocus: true,
        label: l10n.vatRegisterActivity,
        helper: l10n.vatRegisterActivityHelp,
        error: _error,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      actions: [
        TextButton(
          key: const ValueKey('vat-register-activity-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('vat-register-activity-ok'),
          onPressed: _submit,
          child: Text(l10n.vatRegisterEsLibro),
        ),
      ],
    );
  }
}

/// Asks whether the space keeps its books through SII; null when cancelled.
class _SiiDialog extends StatefulWidget {
  const _SiiDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_SiiDialog> createState() => _SiiDialogState();
}

class _SiiDialogState extends State<_SiiDialog> {
  var _sii = false;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return AlertDialog(
      content: SwitchListTile(
        key: const ValueKey('vat-register-347-sii'),
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.vatDeclFilingEsSii),
        value: _sii,
        onChanged: (v) => setState(() => _sii = v),
      ),
      actions: [
        TextButton(
          key: const ValueKey('vat-register-347-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('vat-register-347-ok'),
          onPressed: () => Navigator.of(context).pop(_sii),
          child: Text(l10n.commonOk),
        ),
      ],
    );
  }
}
