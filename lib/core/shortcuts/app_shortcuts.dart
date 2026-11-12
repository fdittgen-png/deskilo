// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3610 — the one list of the app's keys. Every key the app answers is a
// line here: what it does (its label in five languages), the keys that
// press it (Ctrl on Windows, Linux and the web, ⌘ on a Mac — both are
// accepted everywhere, the one shown is the platform's) and where it
// works. The keys overlay (`?`) reads this list, so what it shows is what
// the app does; pages bind their keys through ShortcutScope, and the few
// widgets with keys of their own (the message composer, a wizard, the
// report editor, a date field) take their activators from here.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// What a key does.
enum AppShortcutId {
  /// Ctrl/⌘+K: find a page, an action or a record.
  search,

  /// `/`: the page's filter or search field.
  filter,

  /// N: the page's New.
  newRecord,

  /// Escape: close what is open (the record beside a list, a wizard's step).
  close,

  /// Ctrl/⌘+S: save.
  save,

  /// Ctrl/⌘+Enter: save, or send a message.
  submit,

  /// Ctrl/⌘+P: the page's document (print or PDF).
  print,

  /// `?`: the keys of this page.
  keys,

  /// Alt+Down on a date field: its calendar.
  openCalendar,

  /// Ctrl/⌘+Z in an editor.
  undo,

  /// Ctrl/⌘+Shift+Z or Ctrl+Y in an editor.
  redo,
}

/// Where a key works.
enum ShortcutReach {
  /// Everywhere in a business, from the app itself.
  app,

  /// On a page that offers it (through ShortcutScope).
  page,

  /// On the focused field.
  field,

  /// Inside an editor (the report editor).
  editor,
}

/// One combination of keys.
@immutable
class KeyChord {
  /// [key] with Ctrl (⌘ on a Mac) when [primary], Shift, Alt.
  const KeyChord(
    this.key, {
    this.primary = false,
    this.shift = false,
    this.alt = false,
    this.control = false,
  }) : character = null;

  /// A typed character (`?`, `/`), whatever keys produce it.
  const KeyChord.char(String this.character)
    : key = null,
      primary = false,
      shift = false,
      alt = false,
      control = false;

  final LogicalKeyboardKey? key;
  final String? character;

  /// Ctrl, or ⌘ on a Mac.
  final bool primary;

  /// Ctrl on every platform (Ctrl+Y).
  final bool control;
  final bool shift;
  final bool alt;

  /// Whether the chord holds Ctrl or ⌘: such a key works while a text
  /// field has the focus; a bare key never does.
  bool get modified => primary || control || alt;

  /// The activators that press it: both Ctrl and ⌘ for a [primary] chord.
  List<ShortcutActivator> get activators {
    final c = character;
    if (c != null) return [CharacterActivator(c)];
    final k = key!;
    if (!primary) {
      return [SingleActivator(k, control: control, shift: shift, alt: alt)];
    }
    return [
      SingleActivator(k, control: true, shift: shift, alt: alt),
      SingleActivator(k, meta: true, shift: shift, alt: alt),
    ];
  }

  /// How it is written on [platform]: "Ctrl+K", "⌘K", "?", "Alt+↓".
  String label(TargetPlatform platform) {
    final c = character;
    if (c != null) return c;
    final mac = _usesCommandKey(platform);
    final parts = [
      if (control && mac) '⌃' else if (control) 'Ctrl',
      if (primary && mac) '⌘' else if (primary) 'Ctrl',
      if (alt && mac) '⌥' else if (alt) 'Alt',
      if (shift && mac) '⇧' else if (shift) 'Shift',
      _keyName(key!),
    ];
    return mac ? parts.join() : parts.join('+');
  }
}

String _keyName(LogicalKeyboardKey key) => switch (key) {
  LogicalKeyboardKey.enter => '↵',
  LogicalKeyboardKey.escape => 'Esc',
  LogicalKeyboardKey.arrowDown => '↓',
  _ => key.keyLabel.toUpperCase(),
};

/// Whether [platform] writes Ctrl as ⌘ (a Mac, outside a browser).
bool _usesCommandKey(TargetPlatform platform) =>
    !kIsWeb &&
    (platform == TargetPlatform.macOS || platform == TargetPlatform.iOS);

/// One key of the app.
@immutable
class AppShortcut {
  const AppShortcut(this.id, this.reach, this.chords);

  final AppShortcutId id;
  final ShortcutReach reach;

  /// The first is the one shown.
  final List<KeyChord> chords;

  /// Every activator of every chord.
  List<ShortcutActivator> get activators => [
    for (final c in chords) ...c.activators,
  ];

  /// Whether it works while a text field has the focus.
  bool get whileTyping => chords.first.modified;
}

/// The app's keys, in the order the keys overlay lists them.
const List<AppShortcut> appShortcuts = [
  AppShortcut(AppShortcutId.search, ShortcutReach.app, [
    KeyChord(LogicalKeyboardKey.keyK, primary: true),
  ]),
  AppShortcut(AppShortcutId.keys, ShortcutReach.app, [KeyChord.char('?')]),
  AppShortcut(AppShortcutId.filter, ShortcutReach.page, [KeyChord.char('/')]),
  AppShortcut(AppShortcutId.newRecord, ShortcutReach.page, [
    KeyChord(LogicalKeyboardKey.keyN),
  ]),
  AppShortcut(AppShortcutId.close, ShortcutReach.page, [
    KeyChord(LogicalKeyboardKey.escape),
  ]),
  AppShortcut(AppShortcutId.save, ShortcutReach.page, [
    KeyChord(LogicalKeyboardKey.keyS, primary: true),
  ]),
  AppShortcut(AppShortcutId.submit, ShortcutReach.page, [
    KeyChord(LogicalKeyboardKey.enter, primary: true),
    KeyChord(LogicalKeyboardKey.numpadEnter, primary: true),
  ]),
  AppShortcut(AppShortcutId.print, ShortcutReach.page, [
    KeyChord(LogicalKeyboardKey.keyP, primary: true),
  ]),
  AppShortcut(AppShortcutId.openCalendar, ShortcutReach.field, [
    KeyChord(LogicalKeyboardKey.arrowDown, alt: true),
  ]),
  AppShortcut(AppShortcutId.undo, ShortcutReach.editor, [
    KeyChord(LogicalKeyboardKey.keyZ, primary: true),
  ]),
  AppShortcut(AppShortcutId.redo, ShortcutReach.editor, [
    KeyChord(LogicalKeyboardKey.keyZ, primary: true, shift: true),
    KeyChord(LogicalKeyboardKey.keyY, control: true),
  ]),
];

/// The registry's line for [id].
AppShortcut appShortcut(AppShortcutId id) =>
    appShortcuts.firstWhere((s) => s.id == id);

/// The bindings of [handlers] by the registry's activators, for a widget's
/// own CallbackShortcuts.
Map<ShortcutActivator, VoidCallback> shortcutBindings(
  Map<AppShortcutId, VoidCallback> handlers,
) => {
  for (final MapEntry(key: id, value: run) in handlers.entries)
    for (final a in appShortcut(id).activators) a: run,
};

/// What [id] does, in the reader's language.
String shortcutLabel(AppLocalizations l10n, AppShortcutId id) => switch (id) {
  AppShortcutId.search => l10n.shortcutSearch,
  AppShortcutId.filter => l10n.shortcutFilter,
  AppShortcutId.newRecord => l10n.shortcutNew,
  AppShortcutId.close => l10n.shortcutClose,
  AppShortcutId.save => l10n.shortcutSave,
  AppShortcutId.submit => l10n.shortcutSubmit,
  AppShortcutId.print => l10n.shortcutPrint,
  AppShortcutId.keys => l10n.shortcutKeys,
  AppShortcutId.openCalendar => l10n.shortcutOpenCalendar,
  AppShortcutId.undo => l10n.shortcutUndo,
  AppShortcutId.redo => l10n.shortcutRedo,
};
