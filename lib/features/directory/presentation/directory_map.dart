// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/links/link_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/directory_location.dart';
import '../domain/discovery_view.dart';
import '../domain/public_workspace.dart';
import '../providers/directory_location_providers.dart';
import '../providers/discovery_view_providers.dart';
import 'directory_map_notices.dart';
import 'directory_map_pins.dart';

typedef _Point = ({PublicWorkspace workspace, DirectoryLocation location});

/// What the camera follows: the selected place, every loaded place, or
/// where the person moved it. A manual pan or zoom holds until the person
/// asks for a place or for all of them; later results never undo it.
enum _Camera { selection, all, manual }

/// Sparkilo's selected pill/list relationship, representing workspaces instead
/// of fuel stations. No location permission or background tracking is needed.
class DirectoryMap extends ConsumerStatefulWidget {
  const DirectoryMap({
    super.key,
    required this.workspaces,
    required this.selected,
    required this.onSelect,
    this.tileProvider,
  });
  final List<PublicWorkspace> workspaces;
  final String? selected;
  final TileProvider? tileProvider;
  final ValueChanged<PublicWorkspace> onSelect;
  @override
  ConsumerState<DirectoryMap> createState() => _DirectoryMapState();
}

class _DirectoryMapState extends ConsumerState<DirectoryMap>
    with SingleTickerProviderStateMixin {
  final _controller = MapController();
  VoidCallback? _tick;
  late final AnimationController _glide = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 650));
  String? _view;
  String? _selectedSeen;
  _Camera _camera = _Camera.selection;
  bool _ready = false;
  static const _detailZoom = 16.0;

  /// Addresses geocoded per page; the cards beyond stay unpinned. Only a
  /// place that has an address and no stored coordinates uses one.
  static const _maxLookups = 20;

  /// #3684 -- how many background tiles may fail before the map says so:
  /// one missing tile at the edge of the world is not worth a line, a
  /// background that does not load at all is.
  static const _tileFailureThreshold = 3;

  /// A line over the map keeps clear of the camera buttons on its right:
  /// their 48 dp column and its margins.
  static const _clearOfControls = 64.0;

  int _tileFailures = 0;
  bool _tilesFailed = false;

  /// A new attempt is a new tile layer: every tile is asked again.
  int _tileAttempt = 0;
  final _failedTiles = <ImageProvider>[];

  /// Whether the map has been drawn: once shown, it stays, so its camera
  /// and controller are never rebuilt under the person.
  bool _shown = false;

  /// A tile could not be loaded. Called while the layer lays out its
  /// tiles, so the line is set after the current frame's work.
  void _tileFailed(TileImage tile, Object error, StackTrace? stackTrace) {
    _failedTiles.add(tile.imageProvider);
    if (_tilesFailed || ++_tileFailures < _tileFailureThreshold) return;
    _tilesFailed = true;
    scheduleMicrotask(() {
      if (mounted) setState(() {});
    });
  }

  /// Try again: the failed tiles are forgotten and every tile is asked
  /// again.
  void _reloadTiles() {
    for (final image in _failedTiles) {
      unawaited(image.evict());
    }
    _failedTiles.clear();
    setState(() {
      _tileFailures = 0;
      _tilesFailed = false;
      _tileAttempt++;
    });
  }

  @override
  void dispose() {
    _glide.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// The camera glides to [center] and [zoom] instead of jumping: the eye
  /// follows where the selection went, and nothing teleports.
  void _glideTo(LatLng center, double zoom) {
    final camera = _controller.camera;
    final from = camera.center;
    final fromZoom = camera.zoom;
    final reduce = MediaQuery.of(context).disableAnimations;
    _glide
      ..stop()
      ..reset();
    if (reduce) {
      _controller.move(center, zoom);
      return;
    }
    final curve = CurvedAnimation(parent: _glide, curve: Curves.easeInOutCubic);
    final old = _tick;
    if (old != null) _glide.removeListener(old);
    void tick() {
      final t = curve.value;
      _controller.move(
        LatLng(from.latitude + (center.latitude - from.latitude) * t,
            from.longitude + (center.longitude - from.longitude) * t),
        fromZoom + (zoom - fromZoom) * t,
      );
    }
    _tick = tick;
    _glide
      ..addListener(tick)
      ..forward();
  }

  void _focus(List<_Point> points, PublicWorkspace? target,
      {bool animate = true}) {
    if (!_ready || points.isEmpty) return;
    final selected = points.where((p) => p.workspace == target).firstOrNull;
    if (selected != null || points.length == 1) {
      final point = (selected ?? points.first).location;
      final at = LatLng(point.latitude, point.longitude);
      if (animate) {
        _glideTo(at, _detailZoom);
      } else {
        _controller.move(at, _detailZoom);
      }
    } else {
      final fit = CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          for (final p in points) LatLng(p.location.latitude, p.location.longitude),
        ]), padding: const EdgeInsets.all(64), maxZoom: _detailZoom,
      );
      if (animate) {
        final next = fit.fit(_controller.camera);
        _glideTo(next.center, next.zoom);
      } else {
        _controller.fitCamera(fit);
      }
    }
  }

  /// Moves the camera after the selection or the loaded places changed,
  /// only as far as the person left it to follow. A place selected while
  /// the map is where the person moved it is brought into view at the
  /// zoom they chose; new or late places move nothing.
  void _follow(List<_Point> located, PublicWorkspace? target) {
    final view = '${widget.selected}:${located.map((p) =>
        '${p.workspace.source}/${p.workspace.id}:${p.location.latitude},${p.location.longitude}').join('|')}';
    if (_view == view) return;
    _view = view;
    final chosen = _selectedSeen != widget.selected && target != null;
    _selectedSeen = widget.selected;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _view != view) return;
      if (chosen && _camera == _Camera.manual) return _reveal(located, target);
      if (chosen) _camera = _Camera.selection;
      switch (_camera) {
        case _Camera.selection:
          _focus(located, target);
        case _Camera.all:
          _focus(located, null);
        case _Camera.manual:
          break;
      }
    });
  }

  /// Pans to [target] at the current zoom when it is out of view.
  void _reveal(List<_Point> located, PublicWorkspace target) {
    final point =
        located.where((p) => p.workspace == target).firstOrNull?.location;
    if (!_ready || point == null) return;
    final at = LatLng(point.latitude, point.longitude);
    final camera = _controller.camera;
    if (!camera.visibleBounds.contains(at)) _glideTo(at, camera.zoom);
  }

  /// A gesture of the person's own: the camera is theirs from now on, and
  /// a glide still running stops where it is.
  void _moved(MapCamera _, bool hasGesture) {
    if (!hasGesture) return;
    _camera = _Camera.manual;
    _glide.stop();
  }

  /// Back to the selection, or every loaded place fitted in view: the two
  /// explicit ways out of a manual camera.
  Widget _controls(List<_Point> located, PublicWorkspace? target) {
    final l = context.l10n;
    void follow(_Camera camera) {
      _camera = camera;
      _focus(located, camera == _Camera.all ? null : target);
    }
    final none = located.isEmpty;
    return Positioned(top: 8, right: 8, child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          key: const ValueKey('directory-map-recenter'),
          tooltip: l.directoryLocate,
          onPressed: none ? null : () => follow(_Camera.selection),
          icon: const Icon(Icons.center_focus_strong),
        ),
        const SizedBox(height: AppSpacing.xs),
        IconButton.filledTonal(
          key: const ValueKey('directory-map-show-all'),
          tooltip: l.discoveryShowAllLoaded,
          onPressed: none ? null : () => follow(_Camera.all),
          icon: const Icon(Icons.zoom_out_map),
        ),
      ],
    ));
  }

  /// Says how many cards have no pin and why: no address, or a lookup
  /// that failed, with Try again for every failed one. A place still being
  /// looked up is not counted yet, nor the selected place: unplaced, it
  /// has its own status line. Nothing when all are placed.
  Widget _pinsMissing(_Pins pins) {
    final l = context.l10n;
    if (pins.unplaced == 0) return const SizedBox.shrink();
    final failed = pins.failed;
    return DirectoryMapNotice(
      icon: Icons.location_off_outlined,
      lines: [
        (const ValueKey('directory-pins-missing'), l.directoryPinsMissing(pins.unplaced)),
        if (pins.noAddress > 0)
          (const ValueKey('directory-pins-no-address'), l.directoryPinsNoAddress(pins.noAddress)),
        if (failed.isNotEmpty)
          (const ValueKey('directory-pins-failed'), l.directoryPinsLookupFailed(failed.length)),
      ],
      retryKey: const ValueKey('directory-pins-retry'),
      onRetry: failed.isEmpty
          ? null
          : () {
              for (final address in failed) {
                ref.invalidate(directoryAddressLocationProvider(address));
              }
            },
    );
  }

  /// Where each loaded place stands: placed, still being looked up, or
  /// unplaced and why. [target] is looked up apart, uncounted by the cap.
  _Pins _place(PublicWorkspace? target, AsyncValue<DirectoryLocation?>? lookup) {
    var lookups = 0;
    final pins = _Pins();
    for (final w in widget.workspaces) {
      if (w.location case final at?) {
        pins.located.add((workspace: w, location: at));
        continue;
      }
      final address = w.text('address').trim();
      final own = w == target;
      if (address.isEmpty) {
        if (!own) {
          pins
            ..noAddress += 1
            ..unplaced += 1;
        }
        continue;
      }
      final answer = own
          ? lookup
          : lookups++ < _maxLookups
              ? ref.watch(directoryAddressLocationProvider(address))
              : null;
      if (answer?.value case final at?) {
        pins.located.add((workspace: w, location: at));
      } else if (answer != null && answer.isLoading) {
        pins.waiting++;
      } else if (!own) {
        pins.unplaced++;
        if (answer != null && answer.hasError) pins.failed.add(address);
      }
    }
    return pins;
  }

  /// The camera the map first opens on: every located place in view, or
  /// the selected one up close.
  /// Taken once, when the map is first drawn: the map applies an initial
  /// fit whenever one appears, so a later one would undo the person's own
  /// camera.
  ({LatLng center, CameraFit? fit})? _initial;

  MapOptions _options(List<_Point> located, PublicWorkspace? target) {
    final initial = _initial ??= () {
      final own = located.where((p) => p.workspace == target).firstOrNull;
      final first = (own ?? located.first).location;
      return (
        center: LatLng(first.latitude, first.longitude),
        fit: own != null || located.length == 1
            ? null
            : CameraFit.bounds(
                bounds: LatLngBounds.fromPoints([
                  for (final p in located)
                    LatLng(p.location.latitude, p.location.longitude),
                ]),
                padding: const EdgeInsets.all(64),
                maxZoom: _detailZoom,
              ),
      );
    }();
    return MapOptions(
      interactionOptions: const InteractionOptions(
        keyboardOptions: KeyboardOptions(autofocus: false),
      ),
      initialCenter: initial.center,
      initialZoom: _detailZoom,
      initialCameraFit: initial.fit,
      onPositionChanged: _moved,
      onMapReady: () {
        _ready = true;
        _focus(located, target, animate: false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final target = widget.workspaces.where((w) =>
        widget.selected == '${w.source}/${w.id}').firstOrNull ??
        (widget.workspaces.length == 1 ? widget.workspaces.first : null);
    final address = target?.text('address').trim() ?? '';
    final needsLookup = target != null && target.location == null;
    final lookup = needsLookup && address.isNotEmpty
        ? ref.watch(directoryAddressLocationProvider(address)) : null;
    // #2473 — every workspace is a pin: a card without coordinates is placed
    // from its public address (one cached lookup per address); a failed one stays a card.
    final pins = _place(target, lookup);
    final located = pins.located;
    _follow(located, target);
    final show = _shown || located.isNotEmpty;
    _shown = show;
    return Column(children: [
      if (needsLookup)
        Padding(
          padding: AppSpacing.smAll,
          child: Row(children: [
            Icon(lookup?.isLoading == true ? Icons.hourglass_top : Icons.location_on_outlined,
              size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(
              lookup?.isLoading == true
                  ? (l.directoryLocating)
                  : lookup?.value != null
                      ? '${l.directoryApproximate} · ${lookup!.value!.label}'
                      : (l.directoryLocationMissing),
              key: const ValueKey('directory-location-status'),
              style: Theme.of(context).textTheme.bodySmall,
            )),
            if (lookup?.hasError == true)
              IconButton(key: const ValueKey('directory-map-retry'), onPressed: () => ref.invalidate(directoryAddressLocationProvider(address)),
                tooltip: l.commonRetry, icon: const Icon(Icons.refresh)),
          ]),
        ),
      _pinsMissing(pins),
      Expanded(
        child: show
            ? _map(located, target)
            : widget.workspaces.isEmpty
                ? const SizedBox.expand()
                : DirectoryMapPlaceholder(
                    key: const ValueKey('directory-map-nothing'),
                    busy: pins.waiting > 0,
                    text: pins.waiting > 0
                        ? l.directoryLocating
                        : l.directoryNothingToPin,
                  ),
      ),
    ]);
  }

  Widget _map(List<_Point> located, PublicWorkspace? target) => Stack(children: [
    FlutterMap(
      mapController: _controller,
      options: _options(located, target),
      children: [
        TileLayer(
          key: ValueKey('directory-map-tiles-$_tileAttempt'),
          tileProvider: widget.tileProvider,
          urlTemplate: ref.watch(mapServicesProvider).tiles,
          userAgentPackageName: MapServices.appPackage,
          errorTileCallback: _tileFailed,
        ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            // The pill is ~130 px wide: cluster before two of them overlap.
            maxClusterRadius: 120,
            size: const Size(48, 48),
            markers: [
              for (final p in located)
                Marker(
                  point: LatLng(p.location.latitude, p.location.longitude),
                  width: p.workspace == target ? 168 : 132,
                  height: p.workspace == target ? 66 : 56,
                  alignment: Alignment.topCenter,
                  child: DirectoryMapPin(
                    key: ValueKey('directory-pin-${p.workspace.source}/${p.workspace.id}'),
                    name: p.workspace.name,
                    selected: p.workspace == target,
                    onTap: () => widget.onSelect(p.workspace),
                  ),
                ),
            ],
            builder: (context, markers) =>
                DirectoryClusterBubble(count: markers.length),
          ),
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              key: const ValueKey('directory-map-text-source-attribution'),
              'OpenStreetMap contributors',
              onTap: () => ref.read(linkLauncherProvider)(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
          ],
        ),
      ],
    ),
    _controls(located, target),
    if (_tilesFailed)
      Positioned(
        top: AppSpacing.sm,
        left: AppSpacing.sm,
        right: _clearOfControls,
        child: DirectoryMapNotice(
          key: const ValueKey('directory-map-tiles-failed'),
          icon: Icons.cloud_off_outlined,
          elevated: true,
          lines: [
            (
              const ValueKey('directory-map-tiles-failed-text'),
              context.l10n.directoryTilesFailed,
            ),
          ],
          retryKey: const ValueKey('directory-map-tiles-retry'),
          onRetry: _reloadTiles,
        ),
      ),
  ]);
}

/// Where the loaded places stand on the map.
class _Pins {
  final located = <_Point>[];

  /// Places still being looked up, or waiting their turn: not counted yet.
  int waiting = 0;

  /// Places without a pin, the selected one aside.
  int unplaced = 0;

  /// Of those: places that have no address at all.
  int noAddress = 0;

  /// Of those: the addresses whose lookup failed, for Try again.
  final failed = <String>[];
}
