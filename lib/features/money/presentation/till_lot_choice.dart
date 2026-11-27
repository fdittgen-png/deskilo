// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 / #4436 -- the seller chooses the lot a line is sold from: the lots on hand where the sale takes from, the first
// to expire first, each with its code, its date and what is on hand; one past its date is shown and not offered. "The
// first to expire" leaves the choice to the server again. An item with no lot says so.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show ExactQuantity;
import 'package:flutter/material.dart';

import '../../../core/i18n/format_controller.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/app_snack.dart';
import '../domain/counter_till.dart';
import 'till_session.dart';
import 'till_text.dart';

/// The lot of line [index] chosen through [port] and set on [session]; nothing when the seller goes back.
Future<void> chooseTillLot(BuildContext context, TillLotsPort? port, TillSession session, int index) async {
  final l10n = context.l10n;
  final lines = session.state.value.lines;
  if (port == null || index < 0 || index >= lines.length) return;
  final line = lines[index];
  final List<TillLot> lots;
  try {
    lots = await port.lots(session.workspaceId, line.itemId, tillId: session.tillId);
  } on Object catch (e, st) {
    TraceLogger.instance.error('money', 'the lots of a till line could not be read', error: e, stackTrace: st);
    if (context.mounted) AppSnack.error(context, tillProblemText(l10n, e));
    return;
  }
  if (!context.mounted) return;
  if (lots.isEmpty) {
    AppSnack.info(context, l10n.tillLotNone(line.name));
    return;
  }
  final format = appFormatOf(context);
  final chosen = await showAppSheet<(TillLot?,)>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(line.name, style: Theme.of(sheet).textTheme.titleMedium)),
          ListTile(
            key: const ValueKey('till-lot-first'),
            leading: Icon(line.lot == null ? Icons.radio_button_checked : Icons.radio_button_unchecked),
            title: Text(l10n.tillLotFirstToExpire),
            onTap: () => Navigator.of(sheet).pop((null,)),
          ),
          for (final lot in lots)
            ListTile(
              key: ValueKey('till-lot-${lot.id}'),
              enabled: !lot.expired,
              leading: Icon(line.lot?.id == lot.id ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              title: Text(lot.code),
              subtitle: Text([
                if (lot.expiresOn case final d? when lot.expired) l10n.tillLotExpired(format.date(d)) else if (lot.expiresOn case final d?) l10n.tillLotExpires(format.date(d)),
                l10n.tillLotOnHand(switch (ExactQuantity.tryParse(lot.quantity).value) { final q? => format.quantity(q), null => lot.quantity }, line.unit),
              ].join(' · ')),
              onTap: lot.expired ? null : () => Navigator.of(sheet).pop((lot,)),
            ),
        ],
      ),
    ),
  );
  if (chosen != null) await session.setLot(index, chosen.$1);
}
