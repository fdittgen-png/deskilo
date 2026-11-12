// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — how the app's keys reach a page. The app holds one ShortcutHost
// above its navigator: it answers the app-wide keys (Ctrl/⌘+K, `?`) and
// hands a page's keys to the ShortcutScope of the page on top, wherever the
// keyboard is in it. A bare key (`/`, N, Escape, `?`) never fires while a
// text field has the focus — it is typing; the Ctrl/⌘ ones do.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/context_l10n.dart';
import 'app_shortcuts.dart';

/// Whether a text field has the keyboard's focus.
bool typingInTextField() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>() !=
    null;

/// The registry's shortcut [event] presses among [ids], if any.
AppShortcut? _pressed(KeyEvent event, Iterable<AppShortcutId> ids) {
  if (event is KeyUpEvent) return null;
  final keyboard = HardwareKeyboard.instance;
  for (final id in ids) {
    final s = appShortcut(id);
    if (s.activators.any((a) => a.accepts(event, keyboard))) return s;
  }
  return null;
}

/// Runs [handlers]' key for [event]: handled when one fired. A bare key
/// is left to a focused text field.
KeyEventResult runShortcuts(
  KeyEvent event,
  Map<AppShortcutId, VoidCallback> handlers,
) {
  final s = _pressed(event, handlers.keys);
  if (s == null) return KeyEventResult.ignored;
  if (!s.whileTyping && typingInTextField()) return KeyEventResult.ignored;
  if (event is KeyDownEvent) handlers[s.id]!();
  return KeyEventResult.handled;
}

/// The app-wide keys, above the navigator. [enabled] off (signed out, the
/// kiosk, a public page): no key is answered here.
class ShortcutHost extends StatefulWidget {
  const ShortcutHost({
    required this.enabled,
    required this.dialogContext,
    required this.child,
    this.onSearch,
    super.key,
  });

  final bool enabled;

  /// Opens search from a control (the bar's button): what Ctrl/⌘+K does.
  static void openSearch(BuildContext context) => searchOf(context)?.call();

  /// What opens search, read before [context] goes (a drawer closing).
  static VoidCallback? searchOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<_HostScope>()
      ?.host
      .widget
      .onSearch;

  /// Where the keys overlay opens (the router's navigator).
  final BuildContext? Function() dialogContext;

  /// Ctrl/⌘+K; null when search is off.
  final VoidCallback? onSearch;
  final Widget child;

  @override
  State<ShortcutHost> createState() => _ShortcutHostState();
}

class _ShortcutHostState extends State<ShortcutHost> {
  final List<_ShortcutScopeState> _scopes = [];

  /// The page keys of the page on top, innermost scope first.
  Map<AppShortcutId, VoidCallback> get _pageHandlers {
    final out = <AppShortcutId, VoidCallback>{};
    for (final s in _scopes.reversed) {
      if (!s.current) continue;
      for (final MapEntry(:key, :value) in s.widget.handlers.entries) {
        out.putIfAbsent(key, () => value);
      }
    }
    return out;
  }

  /// The keys a person can press here: the app's, the page's and a
  /// field's, in the registry's order.
  List<AppShortcutId> get shown {
    final page = _pageHandlers.keys.toSet();
    return [
      for (final s in appShortcuts)
        if ((s.reach == ShortcutReach.app &&
                (s.id != AppShortcutId.search || widget.onSearch != null)) ||
            s.reach == ShortcutReach.field ||
            page.contains(s.id))
          s.id,
    ];
  }

  void _showKeys() {
    final at = widget.dialogContext();
    if (at == null) return;
    // A second `?` while the list is open is typed into nothing.
    if (ModalRoute.of(at)?.isCurrent == false) return;
    showShortcutKeys(at, shown);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!widget.enabled) return KeyEventResult.ignored;
    final search = widget.onSearch;
    return runShortcuts(event, {
      ..._pageHandlers,
      AppShortcutId.keys: _showKeys,
      AppShortcutId.search: ?search,
    });
  }

  @override
  Widget build(BuildContext context) => _HostScope(
    host: this,
    child: Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: widget.child,
    ),
  );
}

class _HostScope extends InheritedWidget {
  const _HostScope({required this.host, required super.child});

  final _ShortcutHostState host;

  @override
  bool updateShouldNotify(_HostScope old) => old.host != host;
}

/// A page's keys: [handlers] by what they do. They fire wherever the
/// keyboard is on the page, while the page is the one on top.
class ShortcutScope extends StatefulWidget {
  const ShortcutScope({required this.handlers, required this.child, super.key});

  final Map<AppShortcutId, VoidCallback> handlers;
  final Widget child;

  /// The keys a person can press at [context] (the keys overlay's list).
  static List<AppShortcutId> shownAt(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_HostScope>()?.host.shown ??
      const [];

  @override
  State<ShortcutScope> createState() => _ShortcutScopeState();
}

class _ShortcutScopeState extends State<ShortcutScope> {
  _ShortcutHostState? _host;
  ModalRoute<Object?>? _route;

  bool get current => mounted && (_route?.isCurrent ?? true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
    final host = context.getInheritedWidgetOfExactType<_HostScope>()?.host;
    if (host == _host) return;
    _host?._scopes.remove(this);
    _host = host?.._scopes.add(this);
  }

  @override
  void dispose() {
    _host?._scopes.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: (node, event) => runShortcuts(event, widget.handlers),
    child: widget.child,
  );
}

/// The keys overlay: what each of [ids] does and the key that does it.
void showShortcutKeys(BuildContext context, List<AppShortcutId> ids) {
  final platform = Theme.of(context).platform;
  unawaited(
    showDialog<void>(
      context: context,
      builder: (context) {
        final l10n = context.l10n;
        return AlertDialog(
          key: const ValueKey('shortcut-keys'),
          title: Text(l10n.shortcutKeysTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final id in ids)
                  ListTile(
                    key: ValueKey('shortcut-row-${id.name}'),
                    dense: true,
                    title: Text(shortcutLabel(l10n, id)),
                    trailing: Text(
                      appShortcut(id).chords.first.label(platform),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('shortcut-keys-close'),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).closeButtonLabel),
            ),
          ],
        );
      },
    ),
  );
}
