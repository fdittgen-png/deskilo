// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- what the drawer's sheets share: a count by denomination typed row by row (the business's notes and coins are
// not a list this app invents: a person types the value of each), and the request id one intent keeps until it changes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/till_drawer.dart';
import '../../domain/till_drawer_rules.dart';

/// The request id of one intent: the same typed values keep the id (a retry after a lost answer is answered, not made
/// twice), another value is another intent.
class SameIntent {
  String? _key;
  String? _id;

  String idFor(String key) {
    if (key != _key || _id == null) {
      _key = key;
      _id = newRequestId();
    }
    return _id!;
  }
}

/// The rows of a count by denomination: a value and a number of pieces each, added and removed by the person.
class DenominationRows extends ChangeNotifier {
  DenominationRows() {
    add();
  }

  final List<({TextEditingController value, TextEditingController count})> rows = [];

  void add() {
    rows.add((value: TextEditingController(), count: TextEditingController()));
    notifyListeners();
  }

  /// A typed value changed: the total under the rows is read again.
  void changed() => notifyListeners();

  void removeAt(int index) {
    final gone = rows.removeAt(index);
    gone.value.dispose();
    gone.count.dispose();
    if (rows.isEmpty) add();
    notifyListeners();
  }

  /// The typed rows as a count, or null when one is not complete; read with the person's own number format.
  Denominations? read(BuildContext context) {
    final format = appFormatOf(context);
    return denominationsOfRows([
      for (final r in rows) (value: format.parseMinor(r.value.text), count: int.tryParse(r.count.text.trim())),
    ]);
  }

  @override
  void dispose() {
    for (final r in rows) {
      r.value.dispose();
      r.count.dispose();
    }
    super.dispose();
  }
}

/// The rows as fields, with the total counted so far under them.
class DenominationFields extends StatelessWidget {
  const DenominationFields({super.key, required this.rows, required this.currency});

  final DenominationRows rows;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: rows,
      builder: (context, _) {
        final total = rows.read(context)?.totalMinor;
        final error = FormErrorsScope.maybeOf(context)?.errors['amount'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        key: ValueKey('drawer-denom-value-$i'),
                        controller: rows.rows[i].value,
                        label: l10n.tillDrawerDenomValue,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                        onChanged: (_) => rows.changed(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        key: ValueKey('drawer-denom-count-$i'),
                        controller: rows.rows[i].count,
                        label: l10n.tillDrawerDenomCount,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (_) => rows.changed(),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('drawer-denom-remove-$i'),
                      tooltip: l10n.tillDrawerDenomRemove,
                      icon: const Icon(Icons.close),
                      onPressed: () => rows.removeAt(i),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('drawer-denom-add'),
                onPressed: rows.add,
                icon: const Icon(Icons.add),
                label: Text(l10n.tillDrawerDenomAdd),
              ),
            ),
            if (total != null)
              Text(
                l10n.tillDrawerDenomTotal(appFormatOf(context).moneyIn(currency).formatMinor(total)),
                key: const ValueKey('drawer-denom-total'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            if (error != null) Text(error, key: const ValueKey('drawer-denom-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        );
      },
    );
  }
}
