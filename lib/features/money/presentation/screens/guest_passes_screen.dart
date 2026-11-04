// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — guest passes at the desk: the passes the space sells, and the
// sale of one to a guest who is not a member. The guest is typed in THE
// identity form (PersonalInfoForm), the pass in its extra section, and
// one Save sells: the server books the place, charges and invoices the
// pass, and records the payment when the money was taken.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/personal_info.dart';
import '../../../profile/presentation/widgets/personal_info_form.dart';
import '../../domain/guest_pass.dart';
import '../../providers/guest_pass_providers.dart';
import '../widgets/guest_pass_sale_section.dart';

class GuestPassesScreen extends ConsumerStatefulWidget {
  const GuestPassesScreen({super.key});

  @override
  ConsumerState<GuestPassesScreen> createState() => _GuestPassesScreenState();
}

class _GuestPassesScreenState extends ConsumerState<GuestPassesScreen> {
  GuestPassDraft? _draft;
  String _requestId = newRequestId();
  bool _saving = false;

  GuestPassDraft _fresh(List<GuestPassOffer> offers) {
    final now = ref.read(clockProvider).now();
    return GuestPassDraft(
      offer: offers.where((o) => o.active).firstOrNull,
      seatId: null,
      day: DateTime(now.year, now.month, now.day),
      startMinutes: 9 * 60,
      endMinutes: 18 * 60,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.guestPassesTitle)),
      body: workspace == null
          ? const LoadingView()
          : _body(l10n, workspace),
    );
  }

  Widget _body(AppLocalizations l10n, Workspace workspace) {
    final offers = ref.watch(guestPassOffersProvider(workspace.id));
    final held = {for (final p in ref.watch(myPermissionsProvider)) p.wireName};
    final currency = MoneyFormat(workspace.currencyCode);
    final list = offers.value;
    if (list == null) return const LoadingView();
    final draft = _draft;
    if (draft != null) return _sale(l10n, workspace, list, draft, currency);
    return ListView(
      key: const ValueKey('guest-passes'),
      padding: AppSpacing.gutterAll,
      children: [
        Text(l10n.guestPassesIntro),
        const FormGap(),
        if (list.isEmpty) Text(l10n.guestPassesEmpty),
        for (final o in list)
          ListTile(
            key: ValueKey('guest-pass-offer-${o.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(o.name),
            subtitle: Text(_price(l10n, o, currency)),
            trailing: held.contains('manageServices')
                ? IconButton(
                    key: ValueKey('guest-pass-edit-${o.id}'),
                    tooltip: l10n.guestPassEdit,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editOffer(workspace, currency, o),
                  )
                : null,
          ),
        const FormGap(),
        if (held.contains('manageServices'))
          OutlinedButton.icon(
            key: const ValueKey('guest-pass-add'),
            icon: const Icon(Icons.add),
            label: Text(l10n.guestPassAdd),
            onPressed: () => _editOffer(workspace, currency, null),
          ),
        const FormGap(),
        if (held.contains('issueInvoices') && list.any((o) => o.active))
          FilledButton.icon(
            key: const ValueKey('guest-pass-sell'),
            icon: const Icon(Icons.confirmation_number_outlined),
            label: Text(l10n.guestPassSell),
            onPressed: () => setState(() {
              _draft = _fresh(list);
              _requestId = newRequestId();
            }),
          ),
      ],
    );
  }

  Widget _sale(
    AppLocalizations l10n,
    Workspace workspace,
    List<GuestPassOffer> offers,
    GuestPassDraft draft,
    MoneyFormat currency,
  ) {
    final places = ref.watch(guestPassPlacesProvider(workspace.id)).value ?? const [];
    return PersonalInfoForm(
      key: ValueKey('guest-pass-form-$_requestId'),
      managed: true,
      initial: PersonalInfo.empty,
      workspaceCountry: workspace.countryCode,
      saving: _saving,
      intro: l10n.guestPassSaleIntro,
      extraSection: GuestPassSaleSection(
        key: const ValueKey('guest-pass-section'),
        draft: draft,
        offers: offers,
        places: places,
        currency: currency,
        onChanged: (d) => setState(() => _draft = d),
      ),
      onSave: (info) => _sell(workspace, info, currency),
    );
  }

  Future<void> _sell(
    Workspace workspace,
    PersonalInfo info,
    MoneyFormat currency,
  ) async {
    final l10n = context.l10n;
    final draft = _draft;
    if (draft == null) return;
    final problems = guestPassProblems(draft);
    if (problems.isNotEmpty) {
      AppSnack.error(context, guestPassProblemText(l10n, problems.first));
      return;
    }
    final guest = info.normalized();
    if (guest.personName.isEmpty) {
      AppSnack.error(context, l10n.guestPassNameRequired);
      return;
    }
    setState(() => _saving = true);
    GuestPassSale? sale;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'guest pass sale failed',
      errorText: l10n.guestPassSaleFailed,
      action: () async {
        sale = await ref.read(guestPassCommandsProvider).sell(
              workspace.id,
              draft: draft,
              guest: guest.toDb(),
              requestId: _requestId,
            );
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final done = sale;
    if (!ok || done == null) return;
    AppSnack.success(
      context,
      l10n.guestPassSold(currency.formatMinor(done.amountCents), guest.personName),
    );
    setState(() => _draft = null);
  }

  Future<void> _editOffer(
    Workspace workspace,
    MoneyFormat currency,
    GuestPassOffer? offer,
  ) async {
    final l10n = context.l10n;
    final fields = FormControllers({
      'name': offer?.name ?? '',
      'price': offer == null ? '' : centsToMajor(offer.priceCents),
    });
    var unit = offer?.unit ?? GuestPassUnit.day;
    var active = offer?.active ?? true;
    FieldErrors check() {
      final problems = guestPassOfferProblems(
        fields['name'].text,
        parseCentsInput(fields['price'].text),
      );
      return {
        if (problems.contains(GuestPassOfferProblem.name))
          'name': l10n.guestPassNameRequired,
        if (problems.contains(GuestPassOfferProblem.price))
          'price': l10n.guestPassPriceInvalid,
      };
    }

    await showAppFormSheet(
      context,
      AppFormSheet(
        title: offer == null ? l10n.guestPassAdd : l10n.guestPassEdit,
        submitLabel: l10n.commonSave,
        submitKey: const ValueKey('guest-pass-offer-save'),
        onDispose: fields.dispose,
        validate: check,
        onSubmit: () async {
          final ok = await runGuarded(
            context,
            domain: 'money',
            message: 'guest pass save failed',
            errorText: l10n.guestPassSaveFailed,
            action: () => ref.read(guestPassCommandsProvider).saveOffer(
                  workspace.id,
                  id: offer?.id,
                  name: fields['name'].text.trim(),
                  unit: unit,
                  priceCents: parseCentsInput(fields['price'].text)!,
                  vatRateId: offer?.vatRateId,
                  active: active,
                ),
          );
          if (!ok) return l10n.guestPassSaveFailed;
          ref.invalidate(guestPassOffersProvider(workspace.id));
          return null;
        },
        builder: (context, refresh) => [
          AppTextField(
            controller: fields['name'],
            fieldKey: 'name',
            label: l10n.guestPassName,
          ),
          const FormGap(),
          SegmentedButton<GuestPassUnit>(
            key: const ValueKey('guest-pass-unit'),
            segments: [
              ButtonSegment(
                value: GuestPassUnit.day,
                label: Text(l10n.guestPassUnitDay),
              ),
              ButtonSegment(
                value: GuestPassUnit.hour,
                label: Text(l10n.guestPassUnitHour),
              ),
            ],
            selected: {unit},
            onSelectionChanged: (s) {
              unit = s.first;
              refresh();
            },
          ),
          const FormGap(),
          AppTextField(
            controller: fields['price'],
            fieldKey: 'price',
            label: l10n.guestPassPrice,
            suffixText: workspace.currencyCode,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          SwitchListTile(
            key: const ValueKey('guest-pass-active'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.guestPassActive),
            value: active,
            onChanged: (v) {
              active = v;
              refresh();
            },
          ),
        ],
      ),
    );
  }

  String _price(AppLocalizations l10n, GuestPassOffer o, MoneyFormat currency) {
    final p = currency.formatMinor(o.priceCents);
    return o.unit == GuestPassUnit.hour
        ? l10n.guestPassPerHour(p)
        : l10n.guestPassPerDay(p);
  }
}
