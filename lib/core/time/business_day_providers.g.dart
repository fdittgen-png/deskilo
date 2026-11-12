// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_day_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dayBoundaryScheduler)
final dayBoundarySchedulerProvider = DayBoundarySchedulerProvider._();

final class DayBoundarySchedulerProvider
    extends
        $FunctionalProvider<
          DayBoundaryScheduler,
          DayBoundaryScheduler,
          DayBoundaryScheduler
        >
    with $Provider<DayBoundaryScheduler> {
  DayBoundarySchedulerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dayBoundarySchedulerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dayBoundarySchedulerHash();

  @$internal
  @override
  $ProviderElement<DayBoundaryScheduler> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DayBoundaryScheduler create(Ref ref) {
    return dayBoundaryScheduler(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DayBoundaryScheduler value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DayBoundaryScheduler>(value),
    );
  }
}

String _$dayBoundarySchedulerHash() =>
    r'5c8d36eb7e1646cf2f72ec55cedc03359320c308';

/// The business day in [timezone], kept current: it recomputes at the zone's
/// next midnight and whenever the app comes back to the front.

@ProviderFor(businessToday)
final businessTodayProvider = BusinessTodayFamily._();

/// The business day in [timezone], kept current: it recomputes at the zone's
/// next midnight and whenever the app comes back to the front.

final class BusinessTodayProvider
    extends $FunctionalProvider<BusinessToday, BusinessToday, BusinessToday>
    with $Provider<BusinessToday> {
  /// The business day in [timezone], kept current: it recomputes at the zone's
  /// next midnight and whenever the app comes back to the front.
  BusinessTodayProvider._({
    required BusinessTodayFamily super.from,
    required String? super.argument,
  }) : super(
         retry: null,
         name: r'businessTodayProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$businessTodayHash();

  @override
  String toString() {
    return r'businessTodayProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<BusinessToday> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  BusinessToday create(Ref ref) {
    final argument = this.argument as String?;
    return businessToday(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BusinessToday value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BusinessToday>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BusinessTodayProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$businessTodayHash() => r'a4902adc2e232a14fead0550166d32b7d45d59fe';

/// The business day in [timezone], kept current: it recomputes at the zone's
/// next midnight and whenever the app comes back to the front.

final class BusinessTodayFamily extends $Family
    with $FunctionalFamilyOverride<BusinessToday, String?> {
  BusinessTodayFamily._()
    : super(
        retry: null,
        name: r'businessTodayProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The business day in [timezone], kept current: it recomputes at the zone's
  /// next midnight and whenever the app comes back to the front.

  BusinessTodayProvider call(String? timezone) =>
      BusinessTodayProvider._(argument: timezone, from: this);

  @override
  String toString() => r'businessTodayProvider';
}
