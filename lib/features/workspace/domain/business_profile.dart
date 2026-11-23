// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3549 -- what kind of business a workspace is, as its settings say. The
// kinds are data (public.business_kinds, 0703); this reads the two registry
// settings and nothing else reads them directly.
import 'package:meta/meta.dart';

import '../../../core/settings/setting_defaults.g.dart';
import '../../../core/settings/settings.dart';

/// The setting holding the primary kind.
const String businessKindKey = 'business.kind';

/// #4365 -- the type of shop a business of the kind shop is.
const String businessShopTypeKey = 'business.shop_type';

/// The types of shop, in the order the owner is offered them.
const List<String> shopTypes = ['grocery', 'bakery', 'butcher', 'florist', 'corner_shop'];

/// The setting holding the further kinds, comma-separated.
const String businessMoreKindsKey = 'business.more_kinds';

@immutable
class BusinessProfile {
  const BusinessProfile({required this.kind, this.moreKinds = const [], this.shopType = SettingDefaults.businessShopType});

  /// The profile [settings] state. A registry that predates the keys (an
  /// older server) reads as the default kind, so nothing changes for it.
  factory BusinessProfile.fromSettings(SettingsSet? settings) {
    String read(String key, String fallback) =>
        settings != null && settings.definitions.containsKey(key)
        ? settings.read<String>(key)
        : fallback;
    final kind = read(businessKindKey, SettingDefaults.businessKind).trim();
    final primary = kind.isEmpty ? SettingDefaults.businessKind : kind;
    return BusinessProfile(
      kind: primary,
      moreKinds: [
        for (final code in read(businessMoreKindsKey, SettingDefaults.businessMoreKinds).split(','))
          if (code.trim().isNotEmpty && code.trim() != primary) code.trim(),
      ],
      shopType: read(businessShopTypeKey, SettingDefaults.businessShopType),
    );
  }

  /// The primary kind's code (`coworking`, `studio`, `practice`, `salon`,
  /// `service`, or any code a later migration adds).
  final String kind;

  /// The further kinds' codes, never the primary one.
  final List<String> moreKinds;

  /// The type of shop (#4365): words and examples only; meaningful for a business that is a shop.
  final String shopType;

  /// Every kind of the business, the primary one first.
  List<String> get kinds => [kind, ...moreKinds];

  /// Whether the business is, among other things, of [code].
  bool isA(String code) => kinds.contains(code);
}
