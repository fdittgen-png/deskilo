// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3789 — the desk names a place once. Its top bar already says where the
// page is (the breadcrumb: the group and the entry the navigation selects);
// a page's own bar under it does not say the entry's name a second time.
// [PageTitle] is the title of a page's own bar: on the desk, when its text is
// the selected entry's label, it draws nothing and says nothing to a screen
// reader; anywhere else (a phone, a medium window, a page whose name is not
// its place's, such as an open invoice) it is the plain text, as before.
import 'package:flutter/widgets.dart';

/// The label of the entry the desk's navigation selects, provided by the
/// desk around its pages; absent off the desk.
class DeskPlaceLabel extends InheritedWidget {
  const DeskPlaceLabel({required this.label, required super.child, super.key});

  /// The selected entry's label; null when nothing is selected.
  final String? label;

  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DeskPlaceLabel>()?.label;

  @override
  bool updateShouldNotify(DeskPlaceLabel old) => old.label != label;
}

/// A page bar's title: silent on the desk when it repeats the place's name.
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {this.overflow, super.key});

  final String text;
  final TextOverflow? overflow;

  /// Whether [text] is the name the desk already shows for the place.
  static bool repeatsPlace(BuildContext context, String text) {
    final place = DeskPlaceLabel.of(context);
    return place != null && place == text;
  }

  @override
  Widget build(BuildContext context) => repeatsPlace(context, text)
      ? const SizedBox.shrink()
      : Text(text, overflow: overflow);
}
