// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
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
  String? _countryCode;
  bool _busy = false;

  /// Seed the form ONCE from the loaded workspace; later rebuilds must
  /// not clobber the owner's in-progress edits.
  bool _seeded = false;

  @override
  void dispose() {
    _currency.dispose();
    _timezone.dispose();
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
      await ref.read(workspaceRepositoryProvider).updateWorkspaceLocale(
            workspaceId,
            countryCode: code,
            currencyCode: _currency.text.trim().toUpperCase(),
            timezone: _timezone.text.trim(),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (workspace != null && !_seeded) {
      _seeded = true;
      _countryCode = workspace.countryCode;
      _currency.text = workspace.currencyCode;
      _timezone.text = workspace.timezone;
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
                  FilledButton(
                    key: const Key('workspaceSettingsSave'),
                    onPressed: _busy ? null : () => _save(workspace.id),
                    child: Text(l10n?.commonSave ?? 'Save'),
                  ),
                ],
              ),
            ),
    );
  }
}
