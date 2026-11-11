// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../../core/text/collation.dart';

part 'service_item.freezed.dart';

/// A consumable service of the workspace catalog (#123) — coffee,
/// printing, meeting room, ... Owner-priced; deactivated, never deleted.
@freezed
sealed class ServiceItem with _$ServiceItem implements SystemStamped {
  const factory ServiceItem({
    required String id,
    required String workspaceId,
    required String name,
    required int priceCents,
    required bool active,

    /// Which VAT rate this service is taxed at (0072); '' = the
    /// workspace's default rate. The price stays VAT-INCLUSIVE either way.
    @Default('') String vatRateId,
    /// #731 — units on the shelf; null = not tracked (a service, not a
    /// supply).
    int? stock,
    /// #2354 — where the service is supplied for VAT: connected with the
    /// premises (the default) or a general service.
    @Default(SupplyClass.property) SupplyClass supplyClass,
    /// #3552 — what a stranger reads about the service; '' = none.
    @Default('') String description,
    /// #3552 — how long it takes, in minutes; null = not time-based.
    int? durationMinutes,
    /// #3552 — the group it is listed under; '' = none.
    @Default('') String category,
    /// #3552 — shown on the public page only when the business says so.
    @Default(false) bool isPublic,
    /// #3552 — the order within its category.
    @Default(0) int sortOrder,
    /// #992 — the server's stamp on this row.
    @Default(SystemColumns.none) SystemColumns system,
  }) = _ServiceItem;
}

/// The bounds public.services checks (0711): a duration of 5 to 1440 minutes,
/// a description of at most 2000 characters, a category of at most 40. The
/// name's 80 is the editor's own length for one line of a catalogue.
abstract final class ServiceLimits {
  static const int minMinutes = 5;
  static const int maxMinutes = 1440;
  static const int nameMaxLength = 80;
  static const int descriptionMaxLength = 2000;
  static const int categoryMaxLength = 40;

  /// Whether [minutes] is a duration the server accepts (null = none).
  static bool durationAccepted(int? minutes) =>
      minutes == null || (minutes >= minMinutes && minutes <= maxMinutes);
}

/// #3552 — what a service says about itself, written together: its
/// description ('' = none), its duration in minutes (null = not time-based),
/// its category ('' = none) and whether it is shown on the public page.
@immutable
class ServiceDetails {
  const ServiceDetails({
    this.description = '',
    this.durationMinutes,
    this.category = '',
    this.isPublic = false,
  });

  /// The details [service] carries now.
  factory ServiceDetails.of(ServiceItem service) => ServiceDetails(
    description: service.description,
    durationMinutes: service.durationMinutes,
    category: service.category,
    isPublic: service.isPublic,
  );

  final String description;
  final int? durationMinutes;
  final String category;
  final bool isPublic;

  /// The columns of public.services (0711); '' is stored as null.
  Map<String, Object?> toRow() => {
    'description': description.trim().isEmpty ? null : description.trim(),
    'duration_minutes': durationMinutes,
    'category': category.trim().isEmpty ? null : category.trim(),
    'is_public': isPublic,
  };
}

/// #3552 — what an update of a service changes; a null field stays as it is.
@immutable
class ServiceChange {
  const ServiceChange({
    this.name,
    this.priceCents,
    this.active,
    this.vatRateId,
    this.supplyClass,
    this.details,
  });

  final String? name;
  final int? priceCents;
  final bool? active;

  /// '' = back to the workspace's default rate.
  final String? vatRateId;
  final SupplyClass? supplyClass;
  final ServiceDetails? details;
}

/// #3552 — services grouped by their category, categories in alphabetical
/// order and the uncategorised ('' category) last; within a group by
/// sortOrder, then by name.
List<({String category, List<ServiceItem> services})> groupServicesByCategory(
  Iterable<ServiceItem> services,
) {
  final groups = <String, List<ServiceItem>>{};
  for (final s in services) {
    (groups[s.category.trim()] ??= []).add(s);
  }
  final keys = groups.keys.toList()
    ..sort((a, b) {
      if (a.isEmpty != b.isEmpty) return a.isEmpty ? 1 : -1;
      return compareNames(a, b);
    });
  return [
    for (final k in keys)
      (
        category: k,
        services: groups[k]!
          ..sort((a, b) {
            final byOrder = a.sortOrder.compareTo(b.sortOrder);
            return byOrder != 0
                ? byOrder
                : compareNames(a.name, b.name);
          }),
      ),
  ];
}
