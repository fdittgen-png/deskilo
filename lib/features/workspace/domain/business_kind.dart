// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3549/#3550 — a kind of business the platform knows (public.business_kinds):
// its code, where it sorts, and the features it proposes (flag key → on/off,
// an empty profile proposing nothing). Pure Dart.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:meta/meta.dart';

/// One kind of business.
@immutable
class BusinessKind {
  const BusinessKind({
    required this.code,
    required this.sortOrder,
    this.profile = const {},
  });

  /// A row of public.business_kinds; a non-boolean profile value is skipped.
  factory BusinessKind.fromJson(Map<String, Object?> row) {
    final r = JsonReader(row, context: 'business kind');
    return BusinessKind(
      code: r.string('code'),
      sortOrder: r.intOrNull('sort_order') ?? 0,
      profile: {
        for (final e in r.objectOrEmpty('feature_profile').entries)
          if (e.value is bool) e.key: e.value! as bool,
      },
    );
  }

  final String code;
  final int sortOrder;
  final Map<String, bool> profile;
}

/// Reads the kinds the platform knows, in their order.
abstract interface class BusinessKindRepository {
  Future<List<BusinessKind>> kinds();

  /// Says that [workspaceId] is a [kind], and also [moreKinds]
  /// (`set_business_kind`, 0710: manageConfiguration, both keys at once).
  Future<void> setKind(
    String workspaceId, {
    required String kind,
    required List<String> moreKinds,
  });
}
