// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3308 — the pass part of a guest pass sale, shown inside THE identity
// form (PersonalInfoForm.extraSection) so one Save sends the guest and
// the pass together. The host keeps the draft; this only edits it.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/app_date_picker.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/guest_pass.dart';
import '../../domain/payment_method.dart';
import '../payment_method_labels.dart';

/// The sentence for a draft's first problem.
String guestPassProblemText(AppLocalizations l10n, GuestPassProblem p) =>
    switch (p) {
      GuestPassProblem.noOffer => l10n.guestPassProblemNoOffer,
      GuestPassProblem.noSeat => l10n.guestPassProblemNoSeat,
      GuestPassProblem.endBeforeStart => l10n.guestPassProblemEndBeforeStart,
      GuestPassProblem.daysOutOfRange => l10n.guestPassProblemDays,
      GuestPassProblem.hourlyOneDay => l10n.guestPassProblemHourlyOneDay,
    };

class GuestPassSaleSection extends StatelessWidget {
  const GuestPassSaleSection({
    super.key,
    required this.draft,
    required this.offers,
    required this.places,
    required this.currency,
    required this.onChanged,
  });

  final GuestPassDraft draft;
  final List<GuestPassOffer> offers;
  final List<GuestPassPlace> places;
  final MoneyFormat currency;
  final ValueChanged<GuestPassDraft> onChanged;

  GuestPassDraft _with({
    GuestPassOffer? offer,
    String? seatId,
    DateTime? day,
    int? startMinutes,
    int? endMinutes,
    int? days,
    bool? paid,
    String? method,
  }) {
    final o = offer ?? draft.offer;
    return GuestPassDraft(
      offer: o,
      seatId: seatId ?? draft.seatId,
      day: day ?? draft.day,
      startMinutes: startMinutes ?? draft.startMinutes,
      endMinutes: endMinutes ?? draft.endMinutes,
      days: o?.unit == GuestPassUnit.hour ? 1 : (days ?? draft.days),
      paid: paid ?? draft.paid,
      method: method ?? draft.method,
    );
  }

  Future<void> _pickTime(BuildContext context, {required bool start}) async {
    final minutes = start ? draft.startMinutes : draft.endMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    onChanged(start ? _with(startMinutes: m) : _with(endMinutes: m));
  }

  String _clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final offer = draft.offer;
    final problems = guestPassProblems(draft);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const ValueKey('guest-pass-offer'),
          initialValue: offer?.id,
          decoration: InputDecoration(labelText: l10n.guestPassChoose),
          items: [
            for (final o in offers.where((o) => o.active))
              DropdownMenuItem(
                value: o.id,
                child: Text('${o.name} · ${_price(l10n, o)}'),
              ),
          ],
          onChanged: (id) =>
              onChanged(_with(offer: offers.firstWhere((o) => o.id == id))),
        ),
        const FormGap(),
        DropdownButtonFormField<String>(
          key: const ValueKey('guest-pass-seat'),
          initialValue: draft.seatId,
          decoration: InputDecoration(labelText: l10n.guestPassSeat),
          items: [
            for (final p in places)
              DropdownMenuItem(value: p.seatId, child: Text(p.label)),
          ],
          onChanged: (id) => onChanged(_with(seatId: id)),
        ),
        const FormGap(),
        ListTile(
          key: const ValueKey('guest-pass-day'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.bookPeriodsFrom),
          subtitle: Text(isoDay(draft.day)),
          trailing: const Icon(Icons.calendar_today_outlined),
          onTap: () async {
            final picked = await showAppDatePicker(
              context: context,
              initialDate: draft.day,
              firstDate: DateTime(draft.day.year, draft.day.month, draft.day.day - 1),
              lastDate: DateTime(draft.day.year + 1, draft.day.month, draft.day.day),
            );
            if (picked != null) onChanged(_with(day: picked));
          },
        ),
        Row(
          children: [
            Expanded(
              child: ListTile(
                key: const ValueKey('guest-pass-from'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.guestPassFrom),
                subtitle: Text(_clock(draft.startMinutes)),
                onTap: () => _pickTime(context, start: true),
              ),
            ),
            Expanded(
              child: ListTile(
                key: const ValueKey('guest-pass-to'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.guestPassTo),
                subtitle: Text(_clock(draft.endMinutes)),
                onTap: () => _pickTime(context, start: false),
              ),
            ),
          ],
        ),
        if (offer?.unit != GuestPassUnit.hour)
          Row(
            children: [
              Expanded(child: Text(l10n.guestPassDays)),
              IconButton(
                key: const ValueKey('guest-pass-days-less'),
                tooltip: l10n.guestPassDays,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: draft.days > 1
                    ? () => onChanged(_with(days: draft.days - 1))
                    : null,
              ),
              Text('${draft.days}', key: const ValueKey('guest-pass-days')),
              IconButton(
                key: const ValueKey('guest-pass-days-more'),
                tooltip: l10n.guestPassDays,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: draft.days < guestPassMaxDays
                    ? () => onChanged(_with(days: draft.days + 1))
                    : null,
              ),
            ],
          ),
        SwitchListTile(
          key: const ValueKey('guest-pass-paid'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.guestPassPaid),
          value: draft.paid,
          onChanged: (v) => onChanged(_with(paid: v)),
        ),
        if (draft.paid)
          DropdownButtonFormField<PaymentMethod>(
            key: const ValueKey('guest-pass-method'),
            initialValue: PaymentMethod.values
                .where((m) => m.wireName == draft.method)
                .firstOrNull,
            decoration: InputDecoration(labelText: l10n.guestPassPaid),
            items: [
              for (final m in PaymentMethod.displayOrder)
                DropdownMenuItem(
                  value: m,
                  child: Text(paymentMethodLabel(l10n, m)),
                ),
            ],
            onChanged: (m) => onChanged(_with(method: m?.wireName ?? '')),
          ),
        const FormGap(),
        if (offer != null)
          Text(
            l10n.guestPassTotal(
              '${guestPassUnits(draft)}',
              currency.formatMinor(offer.priceCents),
              currency.formatMinor(guestPassAmountCents(draft)),
            ),
            key: const ValueKey('guest-pass-total'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        if (problems.isNotEmpty)
          Text(
            guestPassProblemText(l10n, problems.first),
            key: const ValueKey('guest-pass-problem'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  String _price(AppLocalizations l10n, GuestPassOffer o) {
    final p = currency.formatMinor(o.priceCents);
    return o.unit == GuestPassUnit.hour
        ? l10n.guestPassPerHour(p)
        : l10n.guestPassPerDay(p);
  }
}
