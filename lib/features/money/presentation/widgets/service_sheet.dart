// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #123/#3552 — the one service editor, opened from the services screen and
// from the setup guide's services step: name, price, VAT rate and place of
// supply, and what the service says about itself — a description, how long
// it takes, its category (the workspace's existing categories proposed) and
// whether it is shown on the public page.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/service_item.dart';
import '../../providers/money_providers.dart';
import 'vat_rate_field.dart';

/// The shortest and the longest duration a service may name (0711's check).
const int serviceMinMinutes = 5;
const int serviceMaxMinutes = 1440;

/// Opens and saves the service editor.
abstract final class ServiceEditor {
  /// Edits [service], or creates one when it is null, in the current
  /// workspace; [categories] are proposed for the category field.
  static Future<void> open(
    BuildContext context,
    WidgetRef ref, {
    ServiceItem? service,
    Iterable<String> categories = const [],
  }) async {
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final l10n = context.l10n;
    // AWAIT the rates: a cached `.value` is null the first time the sheet
    // opens, which would hide the VAT field exactly when it is needed.
    List<VatRate> rates;
    try {
      rates = await ref.read(vatRatesProvider.future);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'vat rates fetch failed',
        error: e,
        stackTrace: st,
      );
      rates = const [];
    }
    if (!context.mounted) return;
    final result = await showAppSheet<_ServiceDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ServiceSheet(
        service: service,
        rates: rates,
        categories: {
          for (final c in categories)
            if (c.trim().isNotEmpty) c.trim(),
        }.toList()..sort(),
      ),
    );
    if (result == null || !context.mounted) return;
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'service save failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        final repo = ref.read(commercialTermsProvider);
        if (service == null) {
          await repo.createService(
            workspace.id,
            name: result.name,
            priceCents: result.priceCents,
            vatRateId: result.vatRateId,
            supplyClass: result.supplyClass,
            details: result.details,
          );
        } else {
          await repo.updateService(
            service.id,
            name: result.name,
            priceCents: result.priceCents,
            active: result.active,
            vatRateId: result.vatRateId,
            supplyClass: result.supplyClass,
            details: result.details,
          );
        }
      },
    )) {
      return;
    }
    ref
      ..invalidate(allServicesProvider)
      ..invalidate(servicesProvider);
  }
}

/// The duration typed into the field: null when blank, else the minutes;
/// the error to show when it is not a whole number in range.
({int? minutes, bool valid}) parseServiceDuration(String text) {
  final t = text.trim();
  if (t.isEmpty) return (minutes: null, valid: true);
  final n = int.tryParse(t);
  final ok = n != null && n >= serviceMinMinutes && n <= serviceMaxMinutes;
  return (minutes: ok ? n : null, valid: ok);
}

class _ServiceDraft {
  const _ServiceDraft({
    required this.name,
    required this.priceCents,
    required this.active,
    required this.vatRateId,
    required this.supplyClass,
    required this.details,
  });

  final String name;
  final int priceCents;
  final bool active;

  /// '' = the workspace's default rate.
  final String vatRateId;

  /// #2354 — where the service is supplied for VAT.
  final SupplyClass supplyClass;

  /// #3552 — what the service says about itself.
  final ServiceDetails details;
}

class _ServiceSheet extends StatefulWidget {
  const _ServiceSheet({
    this.service,
    this.rates = const [],
    this.categories = const [],
  });

  final ServiceItem? service;
  final List<VatRate> rates;
  final List<String> categories;

  @override
  State<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<_ServiceSheet> {
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _description;
  late final TextEditingController _duration;
  late final TextEditingController _category;
  late bool _active;
  late bool _public;
  late String _vatRateId;
  late SupplyClass _supplyClass;
  String? _durationError;

  @override
  void initState() {
    super.initState();
    final service = widget.service;
    _name = TextEditingController(text: service?.name ?? '');
    _price = TextEditingController(
      text: service == null ? '' : centsToMajor(service.priceCents),
    );
    _description = TextEditingController(text: service?.description ?? '');
    _duration = TextEditingController(
      text: service?.durationMinutes?.toString() ?? '',
    );
    _category = TextEditingController(text: service?.category ?? '');
    _active = service?.active ?? true;
    _public = service?.isPublic ?? false;
    _vatRateId = service?.vatRateId ?? '';
    _supplyClass = service?.supplyClass ?? SupplyClass.property;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _description.dispose();
    _duration.dispose();
    _category.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    final price = appFormatOf(context).parseMinor(_price.text);
    final duration = parseServiceDuration(_duration.text);
    setState(
      () => _durationError = duration.valid
          ? null
          : context.l10n.servicesDurationRange(
              serviceMinMinutes,
              serviceMaxMinutes,
            ),
    );
    if (name.isEmpty || price == null || !duration.valid) return;
    Navigator.of(context).pop(
      _ServiceDraft(
        name: name,
        priceCents: price,
        active: _active,
        vatRateId: _vatRateId,
        supplyClass: _supplyClass,
        details: ServiceDetails(
          description: _description.text,
          durationMinutes: duration.minutes,
          category: _category.text,
          isPublic: _public,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  widget.service == null
                      ? (l10n.servicesNew)
                      : (l10n.servicesEdit),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                HelpDot(
                  l10n.helpHintMoneyPaymentsTipSupplyTopic,
                  anchor: HelpAnchor.serviceOverview,
                ),
              ],
            ),
            const FormGap(),
            AppTextField(
              key: const ValueKey('services-name'),
              controller: _name,
              label: l10n.servicesName,
              autofocus: widget.service == null,
              maxLength: 80,
            ),
            AppTextField(
              key: const ValueKey('services-price'),
              controller: _price,
              label: l10n.servicesPrice,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // #537 — kill the net-or-gross ambiguity at the input.
              helper: l10n.priceGrossHint,
            ),
            const FormGap(),
            AppTextField(
              key: const ValueKey('services-description'),
              controller: _description,
              label: l10n.servicesDescription,
              maxLines: 3,
              maxLength: 2000,
            ),
            AppTextField(
              key: const ValueKey('services-duration'),
              controller: _duration,
              label: l10n.servicesDuration,
              helper: l10n.servicesDurationHint,
              error: _durationError,
              keyboardType: TextInputType.number,
            ),
            const FormGap(),
            _CategoryField(
              controller: _category,
              categories: widget.categories,
            ),
            SwitchListTile(
              key: const ValueKey('services-public'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.servicesPublic),
              value: _public,
              onChanged: (v) => setState(() => _public = v),
            ),
            // The price stays what the member pays; the rate only decides
            // how much of it is tax.
            VatRateField(
              key: const ValueKey('services-vat-rate-field'),
              rates: widget.rates,
              value: _vatRateId,
              onChanged: (id) => setState(() => _vatRateId = id),
            ),
            // #2354 — the place of supply: a desk is taxed where it stands.
            SupplyClassField(
              key: const ValueKey('services-supply-class-field'),
              value: _supplyClass,
              onChanged: (supply) => setState(() => _supplyClass = supply),
            ),
            if (widget.service != null)
              SwitchListTile(
                key: const ValueKey('services-active'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.servicesActive),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
            const FormGap(),
            FilledButton(
              key: const ValueKey('services-save'),
              onPressed: _submit,
              child: Text(l10n.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}

/// The category, with the workspace's existing categories proposed as the
/// owner types (free text: a new category is just a new word).
class _CategoryField extends StatefulWidget {
  const _CategoryField({required this.controller, required this.categories});

  final TextEditingController controller;
  final List<String> categories;

  @override
  State<_CategoryField> createState() => _CategoryFieldState();
}

class _CategoryFieldState extends State<_CategoryField> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RawAutocomplete<String>(
    textEditingController: widget.controller,
    focusNode: _focus,
    optionsBuilder: (value) {
      final typed = value.text.trim().toLowerCase();
      return [
        for (final c in widget.categories)
          if (typed.isEmpty || c.toLowerCase().contains(typed)) c,
      ];
    },
    fieldViewBuilder: (context, controller, focusNode, onSubmit) =>
        AppTextField(
          key: const ValueKey('services-category'),
          controller: controller,
          focusNode: focusNode,
          label: context.l10n.servicesCategory,
          maxLength: 40,
        ),
    optionsViewBuilder: (context, onSelected, options) => Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final o in options)
                ListTile(
                  key: ValueKey('services-category-option-$o'),
                  title: Text(o),
                  onTap: () => onSelected(o),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
