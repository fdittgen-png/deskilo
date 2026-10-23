// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "name, country and time zone": the settings screen's own
// country, currency, time zone and language pickers, prefilled from the
// workspace, confirmed through [SaveWorkspaceBasics]. Beside them a date,
// a time and an amount as members will read them in the chosen locale,
// currency and time zone, redrawn as the owner picks.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/i18n/country_names.dart';
import '../../../../core/i18n/workspace_locale_fields.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../application/save_workspace_basics.dart';
import '../../domain/feature_countries.dart';
import '../../domain/workspace.dart';
import '../../providers/workspace_providers.dart';
import '../country_change_confirm.dart';
import 'invite_sheet.dart';
import 'setup_basics_preview.dart';

class SetupBasicsStep extends ConsumerStatefulWidget {
  const SetupBasicsStep({super.key, required this.workspace});
  final Workspace workspace;

  @override
  ConsumerState<SetupBasicsStep> createState() => _SetupBasicsStepState();
}

class _SetupBasicsStepState extends ConsumerState<SetupBasicsStep> {
  final _formKey = GlobalKey<FormState>();
  late final _country = ValueNotifier<String>(widget.workspace.countryCode);
  late final _currency = TextEditingController(
    text: widget.workspace.currencyCode,
  );
  late final _timezone = TextEditingController(text: widget.workspace.timezone);
  late final _language = ValueNotifier<String>(widget.workspace.defaultLocale);
  final _busy = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _country.dispose();
    _currency.dispose();
    _timezone.dispose();
    _language.dispose();
    _busy.dispose();
    super.dispose();
  }

  /// As on the settings screen (#2454): a country that does not offer a
  /// feature that is on asks first; the currency and the zone re-default
  /// from the catalogue, and the owner can still change them.
  Future<void> _pickCountry(String? code) async {
    if (code == null) return;
    final lost = featuresLostInCountry(
      ref.read(enabledFeaturesSyncProvider),
      code,
    );
    if (lost.isNotEmpty && !await confirmCountryChange(context, code, lost)) {
      return;
    }
    final country = CountryCatalog.byCode(code);
    _country.value = code;
    _currency.text = country.currencyCode;
    _timezone.text = country.defaultTimezone;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = context.l10n;
    _busy.value = true;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'setup basics save failed',
      errorText: l10n.setupBasicsSaveFailed,
      action: () => ref
          .read(saveWorkspaceBasicsProvider)
          .save(
            widget.workspace,
            WorkspaceBasics(
              countryCode: _country.value,
              currencyCode: _currency.text,
              timezone: _timezone.text,
              language: _language.value,
            ),
          ),
    );
    // Every surface that formats money or time watches the workspace
    // chain: it reads the row again whether or not both writes landed.
    ref.invalidate(myWorkspacesProvider);
    if (!mounted) return;
    _busy.value = false;
    if (ok) AppSnack.success(context, l10n.workspaceSettingsSaved);
  }

  @override
  Widget build(BuildContext context) {
    final preview = ListenableBuilder(
      listenable: Listenable.merge([_country, _currency, _timezone, _language]),
      builder: (context, _) => SetupBasicsPreview(
        countryCode: _country.value,
        currencyCode: _currency.text.trim(),
        timezone: _timezone.text.trim(),
        language: _language.value,
      ),
    );
    return SetupStepLayout(
      form: Form(
        key: _formKey,
        child: ValueListenableBuilder<bool>(
          valueListenable: _busy,
          builder: (context, busy, _) => _BasicsForm(
            name: widget.workspace.name,
            country: _country,
            currency: _currency,
            timezone: _timezone,
            language: _language,
            busy: busy,
            onCountry: _pickCountry,
            onSave: _save,
          ),
        ),
      ),
      preview: preview,
    );
  }
}

class _BasicsForm extends StatelessWidget {
  const _BasicsForm({
    required this.name,
    required this.country,
    required this.currency,
    required this.timezone,
    required this.language,
    required this.busy,
    required this.onCountry,
    required this.onSave,
  });

  final String name;
  final ValueNotifier<String> country;
  final TextEditingController currency;
  final TextEditingController timezone;
  final ValueNotifier<String> language;
  final bool busy;
  final ValueChanged<String?> onCountry;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupStepHint('basics')),
        const SizedBox(height: AppSpacing.lg),
        Text(
          name,
          key: const ValueKey('setup-basics-name'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        // Re-keyed on the code: a form field reads its initial value once,
        // and a declined change must show the stored country again.
        ValueListenableBuilder<String>(
          valueListenable: country,
          builder: (context, code, _) => DropdownButtonFormField<String>(
            key: ValueKey('setup-basics-country-$code'),
            isExpanded: true,
            initialValue: CountryCatalog.countries.any((c) => c.code == code)
                ? code
                : null,
            decoration: InputDecoration(labelText: l10n.workspaceCountryLabel),
            items: [
              for (final c in CountryCatalog.countries)
                DropdownMenuItem(
                  value: c.code,
                  child: Text(localizedCountryName(l10n, c.code)),
                ),
            ],
            onChanged: busy ? null : onCountry,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        WorkspaceLocaleFields(
          currency: currency,
          timezone: timezone,
          enabled: !busy,
          onTimezonePicked: (zone) => timezone.text = zone,
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          key: const ValueKey('setup-basics-language'),
          isExpanded: true,
          initialValue: inviteLanguages.containsKey(language.value)
              ? language.value
              : '',
          decoration: InputDecoration(
            labelText: l10n.workspaceLanguageLabel,
            helperMaxLines: 3,
            helperText: l10n.workspaceLanguageHelper,
          ),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(l10n.workspaceLanguageUnset),
            ),
            for (final entry in inviteLanguages.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: busy ? null : (value) => language.value = value ?? '',
        ),
        const SizedBox(height: AppSpacing.lg),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton(
            key: const ValueKey('setup-basics-save'),
            onPressed: busy ? null : onSave,
            child: Text(l10n.commonSave),
          ),
        ),
      ],
    );
  }
}
