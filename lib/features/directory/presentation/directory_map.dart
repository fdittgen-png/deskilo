// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/links/link_launcher.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/directory_location.dart';
import '../domain/public_workspace.dart';
import '../providers/directory_location_providers.dart';

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
  bool _ready = false;
  static const _detailZoom = 16.0;

  /// Addresses geocoded per page; the cards beyond stay unpinned.
  static const _maxLookups = 20;

  /// The lookup of an unselected workspace; [failed] counts the ones that
  /// errored so the map can say that some cards have no pin (#2473).
  static DirectoryLocation? _lookedUp(
      PublicWorkspace w, WidgetRef ref, bool allowed, List<Object> failed) {
    if (!allowed || w.location != null) return null;
    final address = w.text('address').trim();
    if (address.isEmpty) return null;
    final answer = ref.watch(directoryAddressLocationProvider(address));
    if (answer.hasError) failed.add(w);
    return answer.value;
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

  void _focus(List<({PublicWorkspace workspace, DirectoryLocation location})> points,
      PublicWorkspace? target, {bool animate = true}) {
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

  /// #2473 — says that some cards have no pin; nothing when all are placed.
  static Widget _pinsMissing(BuildContext context, int count) => count == 0
      ? const SizedBox.shrink()
      : Padding(
          padding: AppSpacing.smAll,
          child: Text(
            context.l10n.directoryPinsMissing(count),
            key: const ValueKey('directory-pins-missing'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );

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
    var lookups = 0;
    final failed = <Object>[];
    final located = [
      for (final w in widget.workspaces)
        if (w.location ??
                (w == target
                    ? lookup?.value
                    : _lookedUp(w, ref, lookups++ < _maxLookups, failed))
            case final point?)
          (workspace: w, location: point),
    ];
    final view = '${widget.selected}:${located.map((p) =>
        '${p.workspace.source}/${p.workspace.id}:${p.location.latitude},${p.location.longitude}').join('|')}';
    if (_view != view) {
      _view = view;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _view == view) _focus(located, target);
      });
    }
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
      _pinsMissing(context, failed.length),
      Expanded(child: Stack(children: [FlutterMap(
      mapController: _controller,
      options: MapOptions(
        interactionOptions: const InteractionOptions(
          keyboardOptions: KeyboardOptions(autofocus: false),
        ),
        initialCenter: located.isEmpty
            ? const LatLng(48.86, 2.35)
            : LatLng(located.first.location.latitude, located.first.location.longitude),
        initialZoom: located.isEmpty ? 4 : _detailZoom,
        onMapReady: () { _ready = true; _focus(located, target, animate: false); },
      ),
      children: [
        TileLayer(
          tileProvider: widget.tileProvider,
          urlTemplate: const String.fromEnvironment(
            'MAP_TILE_URL',
            defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          userAgentPackageName: 'org.deskilo.app',
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
                  child: _Pin(
                    key: ValueKey('directory-pin-${p.workspace.source}/${p.workspace.id}'),
                    name: p.workspace.name,
                    selected: p.workspace == target,
                    onTap: () => widget.onSelect(p.workspace),
                  ),
                ),
            ],
            builder: (context, markers) => _ClusterBubble(count: markers.length),
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
      Positioned(top: 8, right: 8, child: IconButton.filledTonal(
        key: const ValueKey('directory-map-recenter'),
        tooltip: l.directoryLocate,
        onPressed: located.isEmpty ? null : () => _focus(located, target),
        icon: const Icon(Icons.center_focus_strong),
      )),
    ])),
    ]);
  }
}

/// A workspace on the map: a pill with its name. The selected one grows,
/// takes the accent and points at its place; the others stay quiet.
class _Pin extends StatelessWidget {
  const _Pin({super.key, required this.name, required this.selected, required this.onTap});

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: name,
      button: true,
      selected: selected,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surface,
            borderRadius: AppRadius.mdAll,
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: selected ? 0.35 : 0.2),
                blurRadius: selected ? 10 : 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: key == null ? null : ValueKey('${(key! as ValueKey<String>).value}-tap'),
              borderRadius: AppRadius.mdAll,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected ? scheme.onPrimary : scheme.onSurface,
                      ),
                ),
              ),
            ),
          ),
        ),
        // The little tail that points at the place.
        Icon(
          Icons.arrow_drop_down,
          size: 18,
          color: selected ? scheme.primary : scheme.surface,
        ),
      ]),
    );
  }
}

/// Several workspaces close together: one round bubble with how many.
class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$count',
      button: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 3),
          boxShadow: [
            BoxShadow(color: scheme.shadow.withValues(alpha: 0.25), blurRadius: 6),
          ],
        ),
        child: Center(
          child: Text(
            '$count',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: scheme.onTertiaryContainer,
                ),
          ),
        ),
      ),
    );
  }
}
