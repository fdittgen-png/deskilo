// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'link_launcher.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Injectable seam over `launchUrl` so widget tests can capture the exact
/// external link the app would open (#224) — the deep-link twin of the
/// share seam. Launch failures are traced HERE, once, instead of every
/// call site wrapping its own try/catch (formerly duplicated by the
/// PayPal link and the online-payment approval launch).

@ProviderFor(linkLauncher)
final linkLauncherProvider = LinkLauncherProvider._();

/// Injectable seam over `launchUrl` so widget tests can capture the exact
/// external link the app would open (#224) — the deep-link twin of the
/// share seam. Launch failures are traced HERE, once, instead of every
/// call site wrapping its own try/catch (formerly duplicated by the
/// PayPal link and the online-payment approval launch).

final class LinkLauncherProvider
    extends $FunctionalProvider<LinkLauncher, LinkLauncher, LinkLauncher>
    with $Provider<LinkLauncher> {
  /// Injectable seam over `launchUrl` so widget tests can capture the exact
  /// external link the app would open (#224) — the deep-link twin of the
  /// share seam. Launch failures are traced HERE, once, instead of every
  /// call site wrapping its own try/catch (formerly duplicated by the
  /// PayPal link and the online-payment approval launch).
  LinkLauncherProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'linkLauncherProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$linkLauncherHash();

  @$internal
  @override
  $ProviderElement<LinkLauncher> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LinkLauncher create(Ref ref) {
    return linkLauncher(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LinkLauncher value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LinkLauncher>(value),
    );
  }
}

String _$linkLauncherHash() => r'5735144e3069c4d50ebb4a0092ede3607c6f198a';
