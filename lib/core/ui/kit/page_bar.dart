// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3927 — a page's own bar, drawn only when it has something to show. On the
// desk the top bar's crumbs already say the page's name: a bar holding only
// that name would be an empty strip under them. [pageBar] then gives the
// page a bar of no height that still tells the desk the name ([PageTitle]),
// so the crumbs and the window's title keep it. A bar with a control (a
// leading, an action, the back of a pushed page, a tab bar) or a title that
// is not the place's name is drawn as before; off the desk, always.
import 'package:flutter/material.dart';

import 'page_title.dart';

/// The bar of a page titled [title], for [Scaffold.appBar].
PreferredSizeWidget pageBar(
  BuildContext context, {
  required String title,
  Widget? leading,
  List<Widget> actions = const [],
  PreferredSizeWidget? bottom,
}) {
  final impliedBack =
      leading == null &&
      (ModalRoute.of(context)?.impliesAppBarDismissal ?? false);
  final nothingToShow =
      PageTitle.repeatsPlace(context, title) &&
      leading == null &&
      actions.isEmpty &&
      bottom == null &&
      !impliedBack;
  if (nothingToShow) return QuietPageBar(title: title);
  return AppBar(
    title: PageTitle(title),
    leading: leading,
    actions: actions,
    bottom: bottom,
  );
}

/// A page's bar on the desk when it would show nothing but the place's
/// name: no height, the name told to the desk.
class QuietPageBar extends StatelessWidget implements PreferredSizeWidget {
  const QuietPageBar({required this.title, super.key});

  /// The page's name, told to the desk's crumbs and the window's title.
  final String title;

  @override
  Size get preferredSize => Size.zero;

  @override
  Widget build(BuildContext context) => PageTitle(title);
}
