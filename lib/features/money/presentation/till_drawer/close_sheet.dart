// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4367 -- counting the drawer and closing the session. The person counts what is in the drawer, as a total or by
// denomination; when the business counts blind the expected cash is not given until the count is made, so the difference
// and its reason are asked for when the server says the count differs. Someone who may see the finances sees the expected
// cash and the difference as they type. The figures of the close are shown after it.
import 'package:flutter/material.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_choice_controls.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/till_drawer_commands.dart';
import '../../domain/cash_reason.dart';
import '../../domain/till_drawer.dart';
import '../../domain/till_drawer_rules.dart';
import 'cash_reason_text.dart';
import 'drawer_inputs.dart';
import 'drawer_text.dart';

/// What the close sheet is opened over: the session, its till, how the business counts and what the server gave as expected
/// (null while the count is blind).
class CloseSheetInput {
  const CloseSheetInput({
    required this.session,
    required this.tillName,
    required this.currency,
    required this.byDenomination,
    required this.expected,
    this.values = const [],
    this.reasons = const [],
  });

  /// #4514 -- the business's cash reasons; a difference is closed with an active count-difference one.
  final List<CashReason> reasons;

  /// #4511 -- the till's notes and coins, largest first; empty when its currency is counted with typed values.
  final List<int> values;

  final DrawerSession session;
  final String tillName;
  final String currency;
  final bool byDenomination;
  final DrawerCash? expected;
}

/// Opens the sheet over [input]; the figures of the close, or null when it was not closed.
Future<DrawerClosed?> showCloseTillSheet(BuildContext context, TillDrawerCommands commands, CloseSheetInput input) async {
  final form = _CloseForm(context, commands, input);
  final done = await showAppFormSheet(context, form.sheet());
  return done ? form.closed : null;
}

/// The state and the words of one close: what is typed, what it means, and what the server answered.
class _CloseForm {
  _CloseForm(this._context, this._commands, this._input)
    : _l10n = _context.l10n,
      _format = appFormatOf(_context);

  final BuildContext _context;
  final TillDrawerCommands _commands;
  final CloseSheetInput _input;
  final AppLocalizations _l10n;
  final AppFormat _format;
  final FormControllers _fields = FormControllers();
  late final DenominationRows _rows = DenominationRows(values: _input.values);
  final SameIntent _intent = SameIntent();
  DrawerClosed? closed;
  bool _askReason = false;
  String? _reason;
  VoidCallback _refreshSheet = () {};

  String get _currency => _input.currency;
  int? _read(String key) => _format.readAmount(_fields.text(key), currency: _currency, allowNegative: false).minor;
  Denominations? _counted() => _input.byDenomination ? _rows.read(_context) : null;
  int? _countedMinor() => _input.byDenomination ? _counted()?.totalMinor : _read('counted');
  int? _bankedMinor() => _fields.text('banked').isEmpty ? null : _read('banked');
  int? get _known => _input.expected?.expectedMinor;
  bool get _differs {
    final c = _countedMinor();
    final e = _known;
    return c != null && e != null && c != e;
  }

  AppFormSheet sheet() => AppFormSheet(
    title: _l10n.tillDrawerCloseTitle(_input.tillName),
    submitLabel: _l10n.tillDrawerCloseSubmit,
    submitKey: const ValueKey('drawer-close-submit'),
    onDispose: () {
      _fields.dispose();
      _rows.dispose();
    },
    validate: _validate,
    onSubmit: _submit,
    builder: (context, refresh) {
      _refreshSheet = refresh;
      return _body(context, refresh);
    },
  );

  Map<String, String> _validate() => drawerFieldErrors(
    _l10n,
    checkClose(
      countedMinor: _countedMinor(),
      bankedMinor: _fields.text('banked').isEmpty ? 0 : _bankedMinor() ?? -1,
      byDenomination: _input.byDenomination,
      denominations: _counted(),
      expectedMinor: _known,
      differenceReason: _reason ?? '',
    ),
  );

  Future<String?> _submit() async {
    final count = _countedMinor()!;
    final reason = _reason ?? '';
    final denominations = _counted();
    try {
      closed = await _commands.closeSession(
        requestId: _intent.idFor('${_input.session.id}|$count|${denominations?.toJson()}|$reason|${_bankedMinor()}'),
        sessionId: _input.session.id,
        count: DrawerCount(countedMinor: count, bankedMinor: _bankedMinor() ?? 0, denominations: denominations, differenceReason: reason.isEmpty ? null : reason),
      );
      return null;
    } on Object catch (e, st) {
      TraceLogger.instance.warn('money', 'the till drawer refused', error: e, stackTrace: st);
      if (drawerAsksDifferenceReason(e)) {
        _askReason = true;
        _refreshSheet();
      }
      return drawerProblemText(_l10n, e);
    }
  }

  List<Widget> _body(BuildContext context, VoidCallback refresh) {
    final counted = _countedMinor();
    final known = _known;
    final difference = counted != null && known != null ? counted - known : null;
    final money = _format.moneyIn(_currency);
    return [
      if (_input.expected != null) ..._expectedLines(context, _input.expected!),
      _countField(refresh),
      if (difference != null) ...[
        const FormGap.small(),
        Text(_l10n.tillDrawerDifferenceLive(money.formatMinor(difference)), key: const ValueKey('drawer-close-difference')),
      ],
      if (_askReason || _differs) ..._reasonField(),
      const FormGap(),
      AppAmountField(
        key: const ValueKey('drawer-banked'),
        controller: _fields['banked'],
        fieldKey: 'banked',
        label: _l10n.tillDrawerBanked,
        helper: _l10n.tillDrawerBankedHelp,
        currency: _currency,
        allowNegative: false,
      ),
    ];
  }

  List<Widget> _expectedLines(BuildContext context, DrawerCash expected) {
    final money = _format.moneyIn(_currency);
    return [
      Text(_l10n.tillDrawerExpected(money.formatMinor(expected.expectedMinor)), key: const ValueKey('drawer-close-expected'), style: Theme.of(context).textTheme.titleMedium),
      Text(
        _l10n.tillDrawerBreakdown(
              money.formatMinor(expected.floatMinor),
              money.formatMinor(expected.cashSalesMinor - expected.cashRefundsMinor),
              money.formatMinor(expected.paidInMinor),
              money.formatMinor(expected.paidOutMinor),
            )
           ,
        key: const ValueKey('drawer-close-breakdown'),
      ),
      const FormGap(),
    ];
  }

  Widget _countField(VoidCallback refresh) => _input.byDenomination
      ? DenominationFields(rows: _rows, currency: _currency)
      : AppAmountField(
          key: const ValueKey('drawer-counted'),
          controller: _fields['counted'],
          fieldKey: 'amount',
          label: _l10n.tillDrawerCounted,
          helper: (_input.expected == null ? _l10n.tillDrawerCountedHelpBlind : _l10n.tillDrawerCountedHelp),
          currency: _currency,
          allowNegative: false,
          autofocus: true,
          onChanged: (_) => refresh(),
        );

  List<Widget> _reasonField() => [
    const FormGap(),
    Text(_l10n.tillDrawerDifferenceReason, style: Theme.of(_context).textTheme.titleSmall),
    if (_askReason) Text(_l10n.tillDrawerDifferenceAsked),
    const FormGap.small(),
    AppChoiceChips<String>(
      key: const ValueKey('drawer-close-reasons'),
      choices: [
        for (final r in cashReasonsFor(_input.reasons, CashReasonProcess.countDifference))
          AppChoice(value: r.code, key: ValueKey('drawer-close-reason-${r.code}'), label: cashReasonLabel(_l10n, r)),
      ],
      selected: _reason,
      onSelected: (r) {
        _reason = r;
        _refreshSheet();
      },
    ),
    Builder(
      builder: (c) {
        final error = FormErrorsScope.maybeOf(c)?.errors['differenceReason'];
        return error == null
            ? const SizedBox.shrink()
            : Text(error, key: const ValueKey('drawer-close-reason-error'), style: TextStyle(color: Theme.of(c).colorScheme.error));
      },
    ),
  ];
}

/// The figures of a close, said after it: what the drawer should have held, what was counted and the difference.
Future<void> showDrawerClosedDialog(BuildContext context, DrawerClosed closed, {required String currency}) {
  final l10n = context.l10n;
  final money = appFormatOf(context).moneyIn(currency);
  final difference = closed.differenceMinor;
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      scrollable: true,
      title: Text(l10n.tillDrawerClosedTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.tillDrawerClosedCounts(money.formatMinor(closed.expectedMinor), money.formatMinor(closed.countedMinor)), key: const ValueKey('drawer-closed-counts')),
          Text(
            difference == 0
                ? l10n.tillDrawerClosedSame
                : difference < 0
                ? l10n.tillDrawerClosedShort(money.formatMinor(-difference))
                : l10n.tillDrawerClosedOver(money.formatMinor(difference)),
            key: const ValueKey('drawer-closed-difference'),
          ),
          if (closed.bankedMinor > 0) Text(l10n.tillDrawerClosedBanked(money.formatMinor(closed.bankedMinor))),
          if (closed.unresolvedCardMinor > 0) Text(l10n.tillDrawerClosedCard(money.formatMinor(closed.unresolvedCardMinor))),
        ],
      ),
      actions: [TextButton(key: const ValueKey('drawer-closed-ok'), onPressed: () => Navigator.of(c).pop(), child: Text(MaterialLocalizations.of(c).okButtonLabel))],
    ),
  );
}
