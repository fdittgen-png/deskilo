// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3789 — a page's name, as its own bar's PageTitle holds it. The desk does
// not draw it a second time under its breadcrumb (PageTitle is silent there)
// and a phone shows it: a test that asks for the page's name asks this,
// never for a painted Text in the bar, so it holds at every window size.
import 'package:deskilo/core/ui/kit/page_title.dart';
import 'package:flutter_test/flutter_test.dart';

/// The PageTitle whose text is [text], under [within] when given.
Finder findPageName(String text, {Finder? within}) {
  final name = find.byWidgetPredicate(
    (w) => w is PageTitle && w.text == text,
    description: 'the page name "$text"',
  );
  return within == null ? name : find.descendant(of: within, matching: name);
}
