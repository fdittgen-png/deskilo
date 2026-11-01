// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../help/help_dot.dart';

/// #3215 — the help symbol of a settings row sits in a FIXED column.
///
/// [HelpDotTitle] puts the symbol inside the title area, so its x position
/// follows the width of whatever trails the row (a switch, a chevron, a
/// value): on a list the symbols zig-zag. A [HelpRow] is a `ListTile` whose
/// trailing side is two slots of constant width, in this order:
///
///  1. the help slot ([helpSlotWidth], the 48 dp target of [HelpDot]);
///  2. the row's own trailing slot ([trailingSlotWidth]): a switch, a chevron
///     or nothing. It is always reserved, so the symbol keeps its x when the
///     row has no trailing widget and when the next row has a switch.
///
/// Every row of a list that uses it therefore has its symbol at the same x,
/// at any window width. A row with no [topic] draws no symbol but keeps both
/// slots, so its chevron lines up with the others.
///
/// ## The rule for a wrapped title
///
/// The symbol is centred vertically on the whole row (it is the tile's
/// trailing, #3201), also when the title wraps onto several lines; the title
/// wraps inside the space the slots leave and is never truncated. The column
/// rule wins over #1185 ("the symbol stays with the first line"), which
/// remains the behaviour of the legacy [HelpDotTitle] and is not touched.
///
/// ## The value row
///
/// A row that shows a current value puts it in [subtitle]; the trailing slot
/// holds a control (switch, chevron), not text, because its width is fixed.
class HelpRow extends StatelessWidget {
  const HelpRow({
    required this.title,
    this.leading,
    this.subtitle,
    this.topic,
    this.anchor,
    this.trailing,
    this.onTap,
    this.contentPadding,
    super.key,
  });

  /// A row whose trailing control is a switch; a tap anywhere on the row
  /// flips it, like a `SwitchListTile`.
  HelpRow.toggle({
    required this.title,
    required bool value,
    required ValueChanged<bool>? onChanged,
    this.leading,
    this.subtitle,
    this.topic,
    this.anchor,
    this.contentPadding,
    super.key,
  })  : trailing = _RowSwitch(title: title, value: value, onChanged: onChanged),
        onTap = onChanged == null ? null : (() => onChanged(!value));

  /// Width of the slot that holds the help symbol: its tap target.
  static const double helpSlotWidth = 48;

  /// Width of the slot after it: a switch (52 dp) or a chevron.
  static const double trailingSlotWidth = 52;

  /// The end inset a Material 3 `ListTile` puts after its trailing widget; a
  /// [HelpColumn] beside a tile that is not a [HelpRow] is padded by it to
  /// land on the same x.
  static const double tileEndInset = 24;

  final String title;
  final Widget? leading;
  final Widget? subtitle;

  /// The localized name of what the symbol documents (see [HelpDot.topic]);
  /// without one the row draws no symbol.
  final String? topic;

  /// The guide section the symbol opens (see [HelpDot.anchor]).
  final String? anchor;

  /// The row's own trailing widget (a chevron); the switch of
  /// [HelpRow.toggle].
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: contentPadding,
        leading: leading,
        title: Text(title),
        subtitle: subtitle,
        trailing: HelpColumn(topic: topic, anchor: anchor, child: trailing),
        onTap: onTap,
      );
}

/// The two trailing slots of a [HelpRow], for a row that is not a `ListTile`
/// (a tile with a help symbol beside it): the symbol, then [child] in the
/// trailing slot.
class HelpColumn extends StatelessWidget {
  const HelpColumn({this.topic, this.anchor, this.child, super.key});

  final String? topic;
  final String? anchor;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: HelpRow.helpSlotWidth,
            child: topic == null
                ? null
                : Center(child: HelpDot(topic!, anchor: anchor)),
          ),
          SizedBox(
            width: HelpRow.trailingSlotWidth,
            child: Align(alignment: AlignmentDirectional.centerEnd, child: child),
          ),
        ],
      );
}

class _RowSwitch extends StatelessWidget {
  const _RowSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
        label: title,
        container: true,
        child: Switch(value: value, onChanged: onChanged),
      );
}
