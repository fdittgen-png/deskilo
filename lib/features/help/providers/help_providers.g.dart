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

/// #1016 — anchor -> heading text for [languageCode], compiled from the
/// guide's `<!-- anchor: … -->` comments.
///
/// Never throws: a bundle without the asset (a widget test injecting its
/// own guide) answers an empty map, and the screen falls back to the
/// substring jump that predates anchors.

@ProviderFor(helpAnchors)
final helpAnchorsProvider = HelpAnchorsFamily._();

/// #1016 — anchor -> heading text for [languageCode], compiled from the
/// guide's `<!-- anchor: … -->` comments.
///
/// Never throws: a bundle without the asset (a widget test injecting its
/// own guide) answers an empty map, and the screen falls back to the
/// substring jump that predates anchors.

final class HelpAnchorsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, String>>,
          Map<String, String>,
          FutureOr<Map<String, String>>
        >
    with
        $FutureModifier<Map<String, String>>,
        $FutureProvider<Map<String, String>> {
  /// #1016 — anchor -> heading text for [languageCode], compiled from the
  /// guide's `<!-- anchor: … -->` comments.
  ///
  /// Never throws: a bundle without the asset (a widget test injecting its
  /// own guide) answers an empty map, and the screen falls back to the
  /// substring jump that predates anchors.
  HelpAnchorsProvider._({
    required HelpAnchorsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'helpAnchorsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$helpAnchorsHash();

  @override
  String toString() {
    return r'helpAnchorsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, String>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, String>> create(Ref ref) {
    final argument = this.argument as String;
    return helpAnchors(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is HelpAnchorsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$helpAnchorsHash() => r'0ba8dcd35dd383bb1f78af535a6e20a6928e89a7';

/// #1016 — anchor -> heading text for [languageCode], compiled from the
/// guide's `<!-- anchor: … -->` comments.
///
/// Never throws: a bundle without the asset (a widget test injecting its
/// own guide) answers an empty map, and the screen falls back to the
/// substring jump that predates anchors.

final class HelpAnchorsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Map<String, String>>, String> {
  HelpAnchorsFamily._()
    : super(
        retry: null,
        name: r'helpAnchorsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// #1016 — anchor -> heading text for [languageCode], compiled from the
  /// guide's `<!-- anchor: … -->` comments.
  ///
  /// Never throws: a bundle without the asset (a widget test injecting its
  /// own guide) answers an empty map, and the screen falls back to the
  /// substring jump that predates anchors.

  HelpAnchorsProvider call(String languageCode) =>
      HelpAnchorsProvider._(argument: languageCode, from: this);

  @override
  String toString() => r'helpAnchorsProvider';
}
