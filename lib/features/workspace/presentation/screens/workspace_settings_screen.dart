// SPDX-License-Identifier: MIT
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/share/share_launcher.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../plan/domain/floor_plan.dart';
import '../../../plan/domain/level.dart';
import '../../../plan/providers/floor_plan_providers.dart';
import '../../domain/payment_instructions.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_xml.dart';
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
  // #155 — payment instructions members see on an unpaid statement.
  final _iban = TextEditingController();
  final _paypalMe = TextEditingController();
  final _reference = TextEditingController();
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
        ),
      );
      // Every money surface watches the workspace chain — invalidating it
      // re-renders all amounts in the new currency immediately.
      ref.invalidate(myWorkspacesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.workspaceSettingsSaved ?? 'Workspace saved.'),
        ),
      );
    } catch (e, st) {
      debugPrint('update workspace locale failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'update workspace locale failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
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
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.workspaceSettingsTitle ?? 'Workspace'),
      ),
      body: workspace == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
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
                ],
              ),
            ),
    );
  }
}
