// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../../core/country/country_catalog.dart';
import '../../../../core/files/file_picker.dart';
import '../../../../core/share/share_launcher.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../domain/payment_instructions.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_import.dart';
import '../../domain/workspace_xml.dart';
import '../../providers/workspace_import_providers.dart';
import '../../providers/workspace_providers.dart';
import '../country_names.dart';

/// Owner-only workspace settings (#153): country, currency and time zone
/// become editable after creation. Picking a country re-defaults the
/// currency and time zone from [CountryCatalog] — exactly the onboarding
/// behaviour — but a manual currency override typed AFTER the country
/// pick is persisted verbatim (spec §3: owner-overridable).
class WorkspaceSettingsScreen extends ConsumerStatefulWidget {
  const WorkspaceSettingsScreen({super.key});

  @override
  ConsumerState<WorkspaceSettingsScreen> createState() =>
      _WorkspaceSettingsScreenState();
}

class _WorkspaceSettingsScreenState
    extends ConsumerState<WorkspaceSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currency = TextEditingController();
  final _timezone = TextEditingController();
  // #155/#192 — payment instructions members see on an unpaid statement.
  final _iban = TextEditingController();
  final _paypalMe = TextEditingController();
  final _reference = TextEditingController();
  final _wero = TextEditingController();
  final _lydia = TextEditingController();
  final _wise = TextEditingController();
  String? _countryCode;
  bool _busy = false;

  /// Seed the form ONCE from the loaded workspace; later rebuilds must
  /// not clobber the owner's in-progress edits.
  bool _seeded = false;

  @override
  void dispose() {
    _currency.dispose();
    _timezone.dispose();
    _iban.dispose();
    _paypalMe.dispose();
    _reference.dispose();
    _wero.dispose();
    _lydia.dispose();
    _wise.dispose();
    super.dispose();
  }

  void _onCountryPicked(String? code) {
    if (code == null) return;
    final country = CountryCatalog.byCode(code);
    setState(() {
      _countryCode = code;
      // Re-default both from the catalog (spec §3); the owner can still
      // override the currency before saving.
      _currency.text = country.currencyCode;
      _timezone.text = country.defaultTimezone;
    });
  }

  Future<void> _save(String workspaceId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final code = _countryCode;
    if (code == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final repository = ref.read(workspaceRepositoryProvider);
      await repository.updateWorkspaceLocale(
        workspaceId,
        countryCode: code,
        currencyCode: _currency.text.trim().toUpperCase(),
        timezone: _timezone.text.trim(),
      );
      // #155 — the how-to-pay blob rides the same Save.
      await repository.setPaymentInstructions(
        workspaceId,
        PaymentInstructions(
          iban: _iban.text,
          paypalMe: _paypalMe.text,
          reference: _reference.text,
          wero: _wero.text,
          lydia: _lydia.text,
          wise: _wise.text,
        ),
      );
      // Every money surface watches the workspace chain — invalidating it
      // re-renders all amounts in the new currency immediately.
      ref.invalidate(myWorkspacesProvider);
      if (!mounted) return;
      AppSnack.success(
        context,
        l10n?.workspaceSettingsSaved ?? 'Workspace saved.',
      );
    } catch (e, st) {
      debugPrint('update workspace locale failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'update workspace locale failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Serializes the workspace settings + every level's floor plan to the
  /// versioned XML format (#164) and hands it to the system share sheet
  /// as a `.xml` file — same seam the bill PDF export uses (#133).
  Future<void> _exportXml(Workspace workspace) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final levels = await ref.read(levelsProvider.future);
      final plans = <({Level level, FloorPlan plan})>[];
      for (final level in levels) {
        plans.add((
          level: level,
          plan: await ref.read(floorPlanProvider(level.id).future),
        ));
      }
      final xml = buildWorkspaceXml(workspace: workspace, levels: plans);
      final share = ref.read(shareLauncherProvider);
      await share(
        ShareParams(
          files: [
            XFile.fromData(utf8.encode(xml), mimeType: 'application/xml'),
          ],
          fileNameOverrides: [workspaceXmlFileName(workspace.name)],
        ),
      );
    } catch (e, st) {
      debugPrint('workspace XML export failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'workspace XML export failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// User-facing message for a typed parse failure (#164/#165). The
  /// technical [WorkspaceXmlException.detail] goes to the trace log only.
  String _xmlErrorMessage(AppLocalizations? l10n, WorkspaceXmlError error) =>
      switch (error) {
        WorkspaceXmlError.malformed =>
          l10n?.workspaceXmlErrorMalformed ?? 'The file is not readable XML.',
        WorkspaceXmlError.wrongRoot => l10n?.workspaceXmlErrorWrongRoot ??
            'This is not a DesKilo workspace file.',
        WorkspaceXmlError.unsupportedVersion =>
          l10n?.workspaceXmlErrorUnsupportedVersion ??
              'The file was exported by a newer version of DesKilo and '
                  'cannot be imported.',
        WorkspaceXmlError.missingElement =>
          l10n?.workspaceXmlErrorMissingElement ??
              'The file is incomplete — a required section is missing.',
        WorkspaceXmlError.missingAttribute =>
          l10n?.workspaceXmlErrorMissingAttribute ??
              'The file is incomplete — a required value is missing.',
        WorkspaceXmlError.invalidValue =>
          l10n?.workspaceXmlErrorInvalidValue ??
              'The file contains an invalid value and cannot be imported.',
      };

  /// Owner-only XML import (#165): pick file → parse (typed errors) →
  /// client-side placement validation → preview + destructive confirm →
  /// transactional replace via the import RPC, settings via the existing
  /// owner writers.
  Future<void> _importXml(Workspace workspace) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final pick = ref.read(filePickerProvider);
      final file = await pick(XTypeGroup(
        // Acronym identical in every locale (IBAN precedent, #155); the
        // key exists so the parity gate covers the whole set.
        label: l10n?.workspaceXmlFileTypeLabel ?? 'XML',
        extensions: const ['xml'],
        mimeTypes: const ['application/xml', 'text/xml'],
      ));
      if (file == null) return; // cancelled
      // Explicit UTF-8 decode: the export declares UTF-8 (#164), and
      // XFile.readAsString is not UTF-8-safe for data-backed files.
      final content = utf8.decode(await file.readAsBytes());
      if (!mounted) return;

      final WorkspaceXmlData data;
      try {
        data = parseWorkspaceXml(content);
      } on WorkspaceXmlException catch (e, st) {
        TraceLogger.instance.error(
            'workspace', 'workspace XML import rejected: ${e.detail}',
            error: e, stackTrace: st);
        if (!mounted) return;
        AppSnack.error(context, _xmlErrorMessage(l10n, e.error));
        return;
      }

      // The editor's placement rules (spec §10) gate the preview: a file
      // whose plan the editor could never have drawn is rejected here.
      final invalid = validateWorkspaceXmlPlan(data);
      if (invalid != null) {
        TraceLogger.instance.error(
            'workspace',
            'workspace XML import plan invalid '
            '(${invalid.problem.name}): ${invalid.detail}');
        if (!mounted) return;
        AppSnack.error(
          context,
          l10n?.workspaceXmlErrorInvalidPlan ??
              'The floor plan in the file is invalid: rooms, desks or seats '
                  'overlap or extend outside their parent.',
        );
        return;
      }

      final counts = workspaceXmlPlanCounts(data);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          return AlertDialog(
            title: Text(l10n?.workspaceXmlImportPreviewTitle ??
                'Replace floor plan?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n?.workspaceXmlImportPreviewCounts(counts.levels,
                          counts.offices, counts.desks, counts.seats) ??
                      'Levels: ${counts.levels} · '
                          'Offices: ${counts.offices} · '
                          'Desks: ${counts.desks} · '
                          'Seats: ${counts.seats}',
                ),
                const SizedBox(height: 12),
                Text(
                  l10n?.workspaceXmlImportPreviewWarning ??
                      'The current floor plan will be deleted and replaced, '
                          'and the workspace settings will be overwritten. '
                          'This cannot be undone.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.error),
                ),
              ],
            ),
            actions: [
              TextButton(
                key: const Key('workspaceXmlImportCancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n?.commonCancel ?? 'Cancel'),
              ),
              FilledButton(
                key: const Key('workspaceXmlImportConfirm'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                    l10n?.workspaceXmlImportConfirm ?? 'Replace and import'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
      if (!mounted) return;

      // Floor plan first — the RPC is the step that can refuse (owner
      // check, reservations); nothing else is touched when it does.
      await ref
          .read(workspaceImportRepositoryProvider)
          .importFloorPlan(workspace.id, data);
      // Settings ride the EXISTING owner writers (#153/#155/#146). The
      // workspace NAME has no update path yet and is deliberately skipped.
      final repository = ref.read(workspaceRepositoryProvider);
      await repository.updateWorkspaceLocale(
        workspace.id,
        countryCode: data.settings.countryCode,
        currencyCode: data.settings.currencyCode,
        timezone: data.settings.timezone,
      );
      await repository.setPaymentInstructions(
        workspace.id,
        PaymentInstructions.fromDb(data.settings.paymentInstructions),
      );
      await repository.setFeatureFlags(workspace.id, data.settings.featureFlags);

      ref.invalidate(myWorkspacesProvider);
      ref.invalidate(levelsProvider);
      ref.invalidate(floorPlanProvider);
      ref.invalidate(targetNamesProvider);
      if (!mounted) return;
      // Re-seed the form so the imported settings show immediately.
      setState(() => _seeded = false);
      AppSnack.success(
        context,
        l10n?.workspaceXmlImportSuccess ?? 'Workspace imported.',
      );
    } on PostgrestException catch (e, st) {
      debugPrint('workspace XML import failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'workspace XML import failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        e.message.contains(kWorkspaceHasReservationsError)
            ? (l10n?.workspaceXmlImportReservationsError ??
                'This workspace already has reservations, so its floor plan '
                    'cannot be replaced. Imports are only possible before '
                    'the first booking.')
            : (l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.'),
      );
    } catch (e, st) {
      debugPrint('workspace XML import failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'workspace XML import failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (workspace != null && !_seeded) {
      _seeded = true;
      _countryCode = workspace.countryCode;
      _currency.text = workspace.currencyCode;
      _timezone.text = workspace.timezone;
      final instructions =
          PaymentInstructions.fromDb(workspace.paymentInstructions);
      _iban.text = instructions.iban;
      _paypalMe.text = instructions.paypalMe;
      _reference.text = instructions.reference;
      _wero.text = instructions.wero;
      _lydia.text = instructions.lydia;
      _wise.text = instructions.wise;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.workspaceSettingsTitle ?? 'Workspace'),
      ),
      body: workspace == null
          ? const LoadingView()
          : Form(
              key: _formKey,
              child: ListView(
                padding: AppSpacing.gutterAll,
                children: [
                  Text(
                    workspace.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    key: const Key('workspaceSettingsCountry'),
                    initialValue: _countryCode,
                    decoration: InputDecoration(
                      labelText: l10n?.workspaceCountryLabel ?? 'Country',
                    ),
                    items: [
                      for (final country in CountryCatalog.countries)
                        DropdownMenuItem(
                          value: country.code,
                          child:
                              Text(localizedCountryName(l10n, country.code)),
                        ),
                    ],
                    onChanged: _busy ? null : _onCountryPicked,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsCurrency'),
                    controller: _currency,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: l10n?.workspaceCurrencyLabel ?? 'Currency',
                      helperText: l10n?.workspaceSettingsCurrencyHelper ??
                          'Defaults from the country — override if your '
                              'community bills in another currency.',
                    ),
                    // Same 3-letter shape check (and shared "Required"
                    // copy) as the onboarding form; the 0001 column check
                    // re-validates server-side.
                    validator: (value) =>
                        RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')
                            ? null
                            : (l10n?.authFieldRequired ?? 'Required'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsTimezone'),
                    controller: _timezone,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n?.workspaceTimezoneLabel ?? 'Time zone',
                    ),
                    validator: (value) =>
                        (value?.trim().isNotEmpty ?? false)
                            ? null
                            : (l10n?.authFieldRequired ?? 'Required'),
                  ),
                  const SizedBox(height: 24),
                  // #155 — payment instructions members see on an unpaid
                  // statement. All optional; empty = no card renders.
                  Text(
                    l10n?.paymentInstructionsTitle ?? 'Payment instructions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.paymentInstructionsHelper ??
                        'Shown to members on an unpaid statement. Leave '
                            'empty to show nothing.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsIban'),
                    controller: _iban,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      // The acronym is identical in every locale; the key
                      // exists so the parity gate covers the whole set.
                      labelText:
                          l10n?.paymentInstructionsIbanTitle ?? 'IBAN',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsPaypalMe'),
                    controller: _paypalMe,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n?.paymentInstructionsPaypalLabel ??
                          'PayPal.me link or handle',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // #192 — Wero / Lydia / Wise ride the same blob; the
                  // labels carry the expected value shape (phone number,
                  // username, Wisetag/link).
                  TextFormField(
                    key: const Key('workspaceSettingsWero'),
                    controller: _wero,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n?.paymentInstructionsWeroLabel ??
                          'Wero phone number',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsLydia'),
                    controller: _lydia,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n?.paymentInstructionsLydiaLabel ??
                          'Lydia phone number or username',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsWise'),
                    controller: _wise,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n?.paymentInstructionsWiseLabel ??
                          'Wisetag or Wise payment link',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('workspaceSettingsReference'),
                    controller: _reference,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: l10n?.paymentInstructionsReferenceLabel ??
                          'Payment reference hint',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('workspaceSettingsSave'),
                    onPressed: _busy ? null : () => _save(workspace.id),
                    child: Text(l10n?.commonSave ?? 'Save'),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  // #164 — versioned XML snapshot of settings + floor
                  // plan; the whole screen is owner-only already.
                  ListTile(
                    key: const Key('workspaceSettingsExportXml'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload_file_outlined),
                    title: Text(
                      l10n?.workspaceXmlExport ?? 'Export workspace (XML)',
                    ),
                    subtitle: Text(
                      l10n?.workspaceXmlExportSubtitle ??
                          'Settings and floor plan as a shareable file. '
                              'No members, bookings or money data.',
                    ),
                    enabled: !_busy,
                    onTap: () => _exportXml(workspace),
                  ),
                  // #165 — restore from an exported file. Replaces the
                  // floor plan (guarded by preview + destructive confirm);
                  // the whole screen is owner-only already.
                  ListTile(
                    key: const Key('workspaceSettingsImportXml'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.file_open_outlined),
                    title: Text(
                      l10n?.workspaceXmlImport ?? 'Import workspace (XML)',
                    ),
                    subtitle: Text(
                      l10n?.workspaceXmlImportSubtitle ??
                          'Restore settings and floor plan from an exported '
                              'file. Replaces the current floor plan.',
                    ),
                    enabled: !_busy,
                    onTap: () => _importXml(workspace),
                  ),
                ],
              ),
            ),
    );
  }
}
