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
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/shortcuts/app_shortcuts.dart';
import '../../../../core/shortcuts/shortcut_scope.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/adaptive/page_measures.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/personal_info.dart';
import '../../../profile/presentation/widgets/personal_info_form.dart';
import '../../domain/guest_pass.dart';
import '../../providers/guest_pass_providers.dart';
import '../widgets/guest_pass_records.dart';
import '../widgets/guest_pass_sale_section.dart';

/// The most of the page the offers take above the passes sold.
const double _offersShare = 0.45;

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
      appBar: AppBar(title: PageTitle(l10n.guestPassesTitle)),
      body: workspace == null
          ? const LoadingView()
          : _body(l10n, workspace),
    );
  }

  Widget _body(AppLocalizations l10n, Workspace workspace) {
    final offers = ref.watch(guestPassOffersProvider(workspace.id));
    final held = {for (final p in ref.watch(myPermissionsProvider)) p.wireName};
    final currency = appFormatOf(context).moneyIn(workspace.currencyCode);
    final list = offers.value;
    if (list == null) return const LoadingView();
    final draft = _draft;
    if (draft != null) return _sale(l10n, workspace, list, draft, currency);
    // #3614 — who may read the sales sees them as records under the offers.
    final readsSales =
        held.contains('viewFinances') || held.contains('issueInvoices');
    final offersPart = ListView(
      key: const ValueKey('guest-passes'),
      shrinkWrap: true,
      padding: AppSpacing.gutterAll,
      children: [
        // #3614 — words in a reading measure, beside the full-width table.
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kReadingColumnWidth),
            child: Text(l10n.guestPassesIntro),
          ),
        ),
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
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (held.contains('manageServices'))
              OutlinedButton.icon(
                key: const ValueKey('guest-pass-add'),
                icon: const Icon(Icons.add),
                label: Text(l10n.guestPassAdd),
                onPressed: () => _editOffer(workspace, currency, null),
              ),
            if (held.contains('issueInvoices') && list.any((o) => o.active))
              FilledButton.icon(
                key: const ValueKey('guest-pass-sell'),
                icon: const Icon(Icons.confirmation_number_outlined),
                label: Text(l10n.guestPassSell),
                onPressed: () => _startSale(list),
              ),
          ],
        ),
      ],
    );
    if (!readsSales) return offersPart;
    return ShortcutScope(
      // #3614 — N: sell a pass.
      handlers: {
        if (held.contains('issueInvoices') && list.any((o) => o.active))
          AppShortcutId.newRecord: () => _startSale(list),
      },
      child: LayoutBuilder(
        builder: (context, box) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The offers take at most this share of the page; the passes
            // sold the rest.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: box.maxHeight * _offersShare,
              ),
              child: offersPart,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
              ),
              child: Text(
                l10n.guestPassesSoldTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: GuestPassRecords(
                workspaceId: workspace.id,
                offers: list,
                currency: currency,
                canRevoke: held.contains('issueInvoices'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startSale(List<GuestPassOffer> offers) => setState(() {
    _draft = _fresh(offers);
    _requestId = newRequestId();
  });

  Widget _sale(
    AppLocalizations l10n,
    Workspace workspace,
    List<GuestPassOffer> offers,
    GuestPassDraft draft,
    MoneyFormat currency,
  ) {
    // #3680 — the places a pass is sold for, as read.
    final placesRead = ref.watch(guestPassPlacesProvider(workspace.id));
    final placesStandIn = ReadsAnswer.of([placesRead]).standIn(
      onRetry: () => ref.invalidate(guestPassPlacesProvider(workspace.id)),
    );
    if (placesStandIn != null) return placesStandIn;
    final places = placesRead.requireValue;
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
        appFormatOf(context).parseMinor(fields['price'].text),
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
                  priceCents: appFormatOf(context).parseMinor(fields['price'].text)!,
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
