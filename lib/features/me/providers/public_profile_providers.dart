// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/instance/instance_builder.dart';
import '../../auth/providers/auth_providers.dart';
import '../domain/public_person.dart';
import 'me_providers.dart';

/// Whether I published a public profile; false while signed out.
final myPublicProfileProvider = FutureProvider.autoDispose<bool>((ref) {
  if (ref.watch(authStateProvider).value == null) return false;
  return ref.watch(meRepositoryProvider).myPublicProfile();
});

/// What anyone may read of [userId]; null when it is not public.
final publicPersonProvider = FutureProvider.autoDispose
    .family<PublicPerson?, String>(
      (ref, userId) => ref.watch(meRepositoryProvider).publicPerson(userId),
    );

/// The link that opens [userId]'s public profile on the web app.
String publicProfileLink(String userId) =>
    '${InstanceAuthConfig.siteUrl}#/p/$userId';
