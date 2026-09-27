// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/supabase_template_search_repository.dart';
import '../domain/template_search_page.dart';

part 'template_search_providers.g.dart';

/// #1659 — the server's paged template search (0283).
@Riverpod(keepAlive: true)
TemplateSearchRepository templateSearchRepository(Ref ref) =>
    SupabaseTemplateSearchRepository(Supabase.instance.client);
