// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'help_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The compiled help markdown for [languageCode] (see tool/build_help.dart).
/// A seam so widget tests can inject small content instead of decoding the
/// full bundled guide with its screenshots.

@ProviderFor(helpContent)
final helpContentProvider = HelpContentFamily._();

/// The compiled help markdown for [languageCode] (see tool/build_help.dart).
/// A seam so widget tests can inject small content instead of decoding the
/// full bundled guide with its screenshots.

final class HelpContentProvider
    extends $FunctionalProvider<AsyncValue<String>, String, FutureOr<String>>
    with $FutureModifier<String>, $FutureProvider<String> {
  /// The compiled help markdown for [languageCode] (see tool/build_help.dart).
  /// A seam so widget tests can inject small content instead of decoding the
  /// full bundled guide with its screenshots.
  HelpContentProvider._({
    required HelpContentFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'helpContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$helpContentHash();

  @override
  String toString() {
    return r'helpContentProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<String> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String> create(Ref ref) {
    final argument = this.argument as String;
    return helpContent(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HelpContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$helpContentHash() => r'6d5efa58fedf8e7ed74a1ce8d946ca3eac75adfa';

/// The compiled help markdown for [languageCode] (see tool/build_help.dart).
/// A seam so widget tests can inject small content instead of decoding the
/// full bundled guide with its screenshots.

final class HelpContentFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<String>, String> {
  HelpContentFamily._()
    : super(
        retry: null,
        name: r'helpContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The compiled help markdown for [languageCode] (see tool/build_help.dart).
  /// A seam so widget tests can inject small content instead of decoding the
  /// full bundled guide with its screenshots.

  HelpContentProvider call(String languageCode) =>
      HelpContentProvider._(argument: languageCode, from: this);

  @override
  String toString() => r'helpContentProvider';
}
