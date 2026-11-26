// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4448 -- the tools a till layout places beside the keys: the numeric keypad, whose typed quantity goes with the next
// item key (or onto the last line with Quantity ×), and the calculator, whose result goes onto the last line as its
// quantity. Both are exact (till_keypad.dart); neither sets a price.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/till_keypad.dart';

/// The height of the line that shows what is typed or counted.
const double _shownHeight = 36;

const _digits = ['7', '8', '9', '4', '5', '6', '1', '2', '3'];

/// A grid of buttons laid out [columns] wide that fills its cell.
Widget _pad(List<Widget> buttons, {int columns = 3}) => LayoutBuilder(
  builder: (context, box) {
    final rows = (buttons.length / columns).ceil();
    return GridView.count(
      crossAxisCount: columns,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.xs,
      crossAxisSpacing: AppSpacing.xs,
      childAspectRatio: (box.maxWidth / columns) / ((box.maxHeight - 40) / rows).clamp(1, double.infinity),
      children: buttons,
    );
  },
);

class TillKeypadTool extends StatelessWidget {
  const TillKeypadTool({super.key, required this.typed, required this.separator});

  final ValueNotifier<TillKeypadEntry> typed;

  /// The reader's decimal mark: a comma in French, a point in English.
  final String separator;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: AppSpacing.xsAll,
      child: ValueListenableBuilder<TillKeypadEntry>(
        valueListenable: typed,
        builder: (context, entry, _) => Column(
          children: [
            SizedBox(height: _shownHeight, child: Center(child: Text(entry.text, key: const ValueKey('till-keypad-shown'), style: Theme.of(context).textTheme.titleLarge))),
            Expanded(
              child: _pad([
                for (final d in [..._digits, separator, '0'])
                  OutlinedButton(key: ValueKey('till-keypad-$d'), onPressed: () => typed.value = entry.type(d, separator: separator), child: Text(d)),
                IconButton(key: const ValueKey('till-keypad-back'), tooltip: MaterialLocalizations.of(context).deleteButtonTooltip, onPressed: () => typed.value = entry.back(), icon: const Icon(Icons.backspace_outlined)),
              ]),
            ),
          ],
        ),
      ),
    ),
  );
}

class TillCalculatorTool extends StatefulWidget {
  const TillCalculatorTool({super.key, required this.onQuantity});

  /// The result, as a quantity for the last line.
  final ValueChanged<String> onQuantity;

  @override
  State<TillCalculatorTool> createState() => _TillCalculatorToolState();
}

const _ops = {TillCalcOp.add: '+', TillCalcOp.subtract: '−', TillCalcOp.multiply: '×', TillCalcOp.divide: '÷', TillCalcOp.percent: '%'};

class _TillCalculatorToolState extends State<TillCalculatorTool> {
  TillKeypadEntry _entry = const TillKeypadEntry();
  int? _acc;
  TillCalcOp? _op;
  bool _failed = false;

  int? get _shown => _entry.isEmpty ? _acc : tillMillionths(_entry.text);

  void _apply(TillCalcOp? next) {
    final b = tillMillionths(_entry.text);
    setState(() {
      if (_acc != null && _op != null && b != null) {
        _acc = tillCalculate(_acc!, _op!, b);
        _failed = _acc == null;
      } else if (b != null) {
        _acc = b;
      }
      _op = next;
      _entry = const TillKeypadEntry();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = _shown;
    final text = _failed ? '—' : (shown == null ? '' : tillDecimalText(shown));
    return Card(
      child: Padding(
        padding: AppSpacing.xsAll,
        child: Column(
          children: [
            SizedBox(height: _shownHeight, child: Center(child: Text(text, key: const ValueKey('till-calc-shown'), style: Theme.of(context).textTheme.titleLarge))),
            Expanded(
              child: _pad(columns: 4, [
                for (final d in [..._digits, '.', '0'])
                  OutlinedButton(key: ValueKey('till-calc-$d'), onPressed: () => setState(() => _entry = _entry.type(d, separator: '.')), child: Text(d)),
                for (final e in _ops.entries)
                  FilledButton.tonal(key: ValueKey('till-calc-${e.key.name}'), onPressed: () => _apply(e.key), child: Text(e.value)),
                FilledButton(key: const ValueKey('till-calc-equals'), onPressed: () => _apply(null), child: const Icon(Icons.drag_handle)),
              ]),
            ),
            FilledButton(
              key: const ValueKey('till-calc-push'),
              onPressed: shown == null || shown <= 0 || _failed ? null : () => widget.onQuantity(tillDecimalText(shown)),
              child: Text(l10n.tillLayoutCalcPush),
            ),
          ],
        ),
      ),
    );
  }
}
