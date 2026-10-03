// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reminder_evidence_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reminderEvidence)
final reminderEvidenceProvider = ReminderEvidenceFamily._();

final class ReminderEvidenceProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ReminderEvidence>>,
          List<ReminderEvidence>,
          FutureOr<List<ReminderEvidence>>
        >
    with
        $FutureModifier<List<ReminderEvidence>>,
        $FutureProvider<List<ReminderEvidence>> {
  ReminderEvidenceProvider._({
    required ReminderEvidenceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reminderEvidenceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reminderEvidenceHash();

  @override
  String toString() {
    return r'reminderEvidenceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ReminderEvidence>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ReminderEvidence>> create(Ref ref) {
    final argument = this.argument as String;
    return reminderEvidence(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReminderEvidenceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reminderEvidenceHash() => r'3916dbee7db3dcb2504b0dcfc6648fce9954500b';

final class ReminderEvidenceFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ReminderEvidence>>, String> {
  ReminderEvidenceFamily._()
    : super(
        retry: null,
        name: r'reminderEvidenceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ReminderEvidenceProvider call(String invoiceId) =>
      ReminderEvidenceProvider._(argument: invoiceId, from: this);

  @override
  String toString() => r'reminderEvidenceProvider';
}
