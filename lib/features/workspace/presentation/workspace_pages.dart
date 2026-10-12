// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2388 — the template library's pages, as routes with paths (they were
// `Navigator.push`es the router did not know). A link without the
// template lands on the library.
import '../../../core/navigation/page_spec.dart';
import 'screens/template_compare_screen.dart';
import 'screens/template_detail_screen.dart';

T _same<T>(T page) => page;

/// The templates on the shortlist, side by side.
const templateComparePage = PageSpec<TemplateCompareScreen>(
  '/templates/compare',
  _same,
  fallback: '/onboarding',
);

/// One template, in full.
const templateDetailPage = PageSpec<TemplateDetailScreen>(
  '/templates/detail',
  _same,
  fallback: '/onboarding',
);

/// Every page above, for the router.
final workspacePages = <PageSpec<Object?>>[
  templateComparePage,
  templateDetailPage,
];
