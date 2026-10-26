// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bi_report_editor.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BiReportEditor)
final biReportEditorProvider = BiReportEditorFamily._();

final class BiReportEditorProvider
    extends $NotifierProvider<BiReportEditor, BiEditorState> {
  BiReportEditorProvider._({
    required BiReportEditorFamily super.from,
    required BiReportEditorSeed super.argument,
  }) : super(
         retry: null,
         name: r'biReportEditorProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$biReportEditorHash();

  @override
  String toString() {
    return r'biReportEditorProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  BiReportEditor create() => BiReportEditor();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BiEditorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BiEditorState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is BiReportEditorProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$biReportEditorHash() => r'cde339ce4ed003e8441e0d655aee980aaaa99f5a';

final class BiReportEditorFamily extends $Family
    with
        $ClassFamilyOverride<
          BiReportEditor,
          BiEditorState,
          BiEditorState,
          BiEditorState,
          BiReportEditorSeed
        > {
  BiReportEditorFamily._()
    : super(
        retry: null,
        name: r'biReportEditorProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BiReportEditorProvider call(BiReportEditorSeed seed) =>
      BiReportEditorProvider._(argument: seed, from: this);

  @override
  String toString() => r'biReportEditorProvider';
}

abstract class _$BiReportEditor extends $Notifier<BiEditorState> {
  late final _$args = ref.$arg as BiReportEditorSeed;
  BiReportEditorSeed get seed => _$args;

  BiEditorState build(BiReportEditorSeed seed);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BiEditorState, BiEditorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BiEditorState, BiEditorState>,
              BiEditorState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
