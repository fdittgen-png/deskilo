// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3798 — on the desk the frame constrains the PAGE, not the navigator. The
// root navigator spans the whole page area beside the navigation, so what a
// page opens over itself (a dialog, a sheet, a side panel, their scrim)
// stands in the page area; each page is laid in its own measure here, by
// its own address, as its route builds it (theme.dart wraps every page
// transition with [framedOnDesk]). Off the desk nothing changes: the app's
// builder frames the window as before.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../page_frame.dart';

/// The widest a dialog stands on the desk: the 960 column it stood in
/// before (#3798) less Material's two 40 insets, so a dialog keeps the
/// width it had now that the column no longer bounds it.
const double deskDialogMaxWidth = 880;

/// The desk's page area: the pages under it frame themselves, and a dialog
/// opened from them keeps its own maximum width.
class DeskPageFrame extends StatelessWidget {
  const DeskPageFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        dialogTheme: theme.dialogTheme.copyWith(
          constraints: const BoxConstraints(maxWidth: deskDialogMaxWidth),
        ),
      ),
      child: _Mark(child: child),
    );
  }
}

/// Marks the desk's page area for [framedOnDesk].
class _Mark extends InheritedWidget {
  const _Mark({required super.child});

  static bool on(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Mark>() != null;

  @override
  bool updateShouldNotify(_Mark old) => false;
}

/// [child], a route's page, in the measure its address declares when it
/// stands in the desk's page area; unchanged anywhere else.
Widget framedOnDesk(Widget child) => Builder(
  builder: (context) {
    if (!_Mark.on(context)) return child;
    return framePage(_pathOf(context), child, inside: true);
  },
);

/// The address of the page [context] is in: its own route's, or the
/// router's for a page pushed without one.
String _pathOf(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.path;
  } on GoError {
    return GoRouter.maybeOf(context)?.routeInformationProvider.value.uri.path ??
        '';
  }
}
