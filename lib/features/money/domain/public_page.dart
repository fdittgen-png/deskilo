// SPDX-License-Identifier: AGPL-3.0-or-later
import 'service_item.dart';

/// #4318 — how many public services the public page, its Discover card and
/// the search by service carry. The server's `public_page_service_limit()`
/// (supabase/migrations/0864_public_page_service_limit.sql) is the source;
/// test/lint/public_page_service_limit_test.dart keeps this value equal to it.
const publicPageServiceLimit = 12;

/// #4318 — which of [services] the public page carries. Active, public
/// services are taken in the services list's order (category, then sort
/// order, then name: [groupServicesByCategory]), the same order the server
/// projection uses, and the first [limit] are shown.
({int publicCount, Set<String> beyondPage}) publicPageReach(
  Iterable<ServiceItem> services, {
  int limit = publicPageServiceLimit,
}) {
  final public = [
    for (final group in groupServicesByCategory(services))
      for (final s in group.services)
        if (s.active && s.isPublic) s,
  ];
  return (
    publicCount: public.length,
    beyondPage: {for (final s in public.skip(limit)) s.id},
  );
}
