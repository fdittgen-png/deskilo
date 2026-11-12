// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3611 -- a row's actions, declared once. The ⋯ button, a right click,
// a long press, the context-menu key and Shift+F10 all open the same
// menu with the same entries, so nothing a phone reaches by a gesture is
// out of reach of a mouse or a keyboard. A swipe on the same row calls
// the same [RowAction.onSelected]: there is one definition of what an
// action does, whichever way it is started.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../mouse_presence.dart';

/// One entry of a row's menu.
@immutable
class RowAction {
  const RowAction({
    required this.id,
    required this.label,
    required this.onSelected,
    this.icon,
    this.destructive = false,
    this.disabledReason,
  });

  /// Stable within the row; the entry's key is `<keyPrefix>-<id>`.
  final String id;
  final String label;
  final IconData? icon;

  /// Drawn in the error colour: the action destroys something.
  final bool destructive;

  /// Why the action is not allowed here. Non-null disables the entry and
  /// says so under its label, rather than hiding it: a missing entry
  /// leaves the person searching, a greyed one with its reason does not.
  final String? disabledReason;

  /// What the action does. A swipe on the same row calls this too.
  final FutureOr<void> Function() onSelected;

  bool get enabled => disabledReason == null;
}

/// When the row shows its ⋯ button.
enum RowMenuButton {
  /// Always: the row has room and its actions are worth seeing.
  always,

  /// While a mouse hovers the row or the keyboard focus is inside it. A
  /// phone sees no button; the long press opens the same menu.
  onHover,
}

/// Wraps a row so every way of asking for its actions opens one menu.
class RowMenu extends StatefulWidget {
  const RowMenu({
    super.key,
    required this.actions,
    required this.keyPrefix,
    required this.child,
    this.buttonKey,
    this.button = RowMenuButton.always,
    this.buttonFirst = false,
    this.expand = true,
    this.focusable = false,
    this.tooltip,
  });

  /// The row's actions, in menu order.
  final List<RowAction> actions;

  /// Entry keys are `<keyPrefix>-<action id>`.
  final String keyPrefix;
  final Widget child;

  /// The ⋯ button's key; `<keyPrefix>-more` when null.
  final Key? buttonKey;
  final RowMenuButton button;

  /// The button before the row instead of after it (a message of mine,
  /// whose free side is the leading one).
  final bool buttonFirst;

  /// The row fills the width (a list row); false keeps it as wide as its
  /// content (a chat bubble).
  final bool expand;

  /// The row itself takes keyboard focus. A row whose child is already
  /// focusable (a `ListTile` with `onTap`) leaves this false: the keys
  /// reach the menu from the focused child.
  final bool focusable;

  /// The button's tooltip; the platform's "More options" when null.
  final String? tooltip;

  @override
  State<RowMenu> createState() => RowMenuState();
}

class RowMenuState extends State<RowMenu> {
  bool _hovered = false;
  bool _focused = false;

  /// The row keeps its state when the button comes and goes.
  final GlobalKey _row = GlobalKey();

  /// Opens the menu: under [at] (a global position) for a click or a
  /// press, over [anchor] for the button or a key.
  Future<void> open({Offset? at, BuildContext? anchor}) async {
    if (widget.actions.isEmpty) return;
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final Rect rect;
    if (at != null) {
      rect = overlay.globalToLocal(at) & Size.zero;
    } else {
      final box = (anchor ?? context).findRenderObject()! as RenderBox;
      rect = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    }
    final chosen = await showMenu<RowAction>(
      context: context,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      items: [for (final action in widget.actions) _entry(action)],
    );
    if (chosen == null || !chosen.enabled) return;
    await chosen.onSelected();
  }

  PopupMenuItem<RowAction> _entry(RowAction action) {
    final theme = Theme.of(context);
    final color = !action.enabled
        ? theme.disabledColor
        : action.destructive
        ? theme.colorScheme.error
        : null;
    final reason = action.disabledReason;
    return PopupMenuItem<RowAction>(
      key: ValueKey('${widget.keyPrefix}-${action.id}'),
      value: action,
      enabled: action.enabled,
      child: Row(
        children: [
          if (action.icon != null) ...[
            Icon(action.icon, color: color),
            const SizedBox(width: RowMenuMetrics.iconGap),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action.label, style: TextStyle(color: color)),
                if (reason != null)
                  Text(
                    reason,
                    key: ValueKey('${widget.keyPrefix}-${action.id}-reason'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final asked =
        key == LogicalKeyboardKey.contextMenu ||
        (key == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed);
    if (!asked) return KeyEventResult.ignored;
    unawaited(open());
    return KeyEventResult.handled;
  }

  Widget _moreButton() => Builder(
    builder: (buttonContext) => IconButton(
      key: widget.buttonKey ?? ValueKey('${widget.keyPrefix}-more'),
      tooltip:
          widget.tooltip ?? MaterialLocalizations.of(context).moreButtonTooltip,
      visualDensity: VisualDensity.compact,
      iconSize: RowMenuMetrics.buttonIcon,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      onPressed: () => unawaited(open(anchor: buttonContext)),
      icon: const Icon(Icons.more_horiz),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final row = GestureDetector(
      onSecondaryTapUp: (details) =>
          unawaited(open(at: details.globalPosition)),
      // parity: ${widget.keyPrefix}-more
      onLongPressStart: (details) =>
          unawaited(open(at: details.globalPosition)),
      child: widget.child,
    );
    final semantic = Semantics(
      customSemanticsActions: {
        for (final action in widget.actions)
          if (action.enabled)
            CustomSemanticsAction(label: action.label): () =>
                unawaited(Future.sync(action.onSelected)),
      },
      child: row,
    );
    final kept = KeyedSubtree(key: _row, child: semantic);
    final withButton = MousePresence(
      builder: (context, mouse, _) {
        final show = switch (widget.button) {
          RowMenuButton.always => true,
          RowMenuButton.onHover => (mouse && _hovered) || _focused,
        };
        if (!show) return kept;
        final body = widget.expand
            ? Expanded(child: kept)
            : Flexible(child: kept);
        return Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          children: widget.buttonFirst
              ? [_moreButton(), body]
              : [body, _moreButton()],
        );
      },
    );
    return Focus(
      canRequestFocus: widget.focusable,
      skipTraversal: !widget.focusable,
      onFocusChange: (focused) => setState(() => _focused = focused),
      onKeyEvent: _onKey,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: withButton,
      ),
    );
  }
}

/// The menu's layout numbers.
abstract final class RowMenuMetrics {
  /// Between an entry's icon and its label.
  static const double iconGap = 12;

  /// The ⋯ glyph: smaller than a toolbar icon, it sits beside content.
  static const double buttonIcon = 18;
}
