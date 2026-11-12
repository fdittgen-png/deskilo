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

/// The name the top page's own bar gives it, for the desk's crumbs and the
/// window title (#3789): "Settings › Colours". The app holds one for its
/// address and forgets it when the address changes; the top route's
/// [PageTitle] tells it the name after its frame.
class PageNameScope extends StatefulWidget {
  const PageNameScope({required this.path, required this.child, super.key});

  /// The app's address: a new one forgets the name of the page before.
  final String path;
  final Widget child;

  /// The name of the top page, for a widget that shows it (and rebuilds when
  /// it changes).
  static String? nameOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_PageNameInherited>()
      ?.notifier
      ?.name;

  static _PageName? _of(BuildContext context) => context
      .getInheritedWidgetOfExactType<_PageNameInherited>()
      ?.notifier;

  @override
  State<PageNameScope> createState() => _PageNameScopeState();
}

class _PageNameScopeState extends State<PageNameScope> {
  final _name = _PageName();

  @override
  void didUpdateWidget(PageNameScope old) {
    super.didUpdateWidget(old);
    // Forgotten without a notice: everything under is built again for the
    // new address, and its page tells its own name after the frame.
    if (old.path != widget.path) _name.forget();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _PageNameInherited(
    notifier: _name,
    child: _ScopePath(path: widget.path, child: widget.child),
  );
}

/// The address the name belongs to: a [PageTitle] depends on it, so a new
/// address (even one set after the page was built) has the top page tell
/// its name again.
class _ScopePath extends InheritedWidget {
  const _ScopePath({required this.path, required super.child});

  final String path;

  @override
  bool updateShouldNotify(_ScopePath old) => old.path != path;
}

class _PageName extends ChangeNotifier {
  String? name;

  void forget() => name = null;

  void tell(String next) {
    if (name == next) return;
    name = next;
    notifyListeners();
  }
}

class _PageNameInherited extends InheritedNotifier<_PageName> {
  const _PageNameInherited({required super.notifier, required super.child});
}

/// A page bar's title: silent on the desk when it repeats the place's name.
/// The top route's title is also the page's name for the crumbs.
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
  Widget build(BuildContext context) {
    // The top route's title names the page; the route below takes over
    // when this one is popped (its isCurrent changes, this builds again).
    context.dependOnInheritedWidgetOfExactType<_ScopePath>();
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      final scope = PageNameScope._of(context);
      if (scope != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => scope.tell(text));
      }
    }
    return repeatsPlace(context, text)
        ? const SizedBox.shrink()
        : Text(text, overflow: overflow);
  }
}
