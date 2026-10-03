// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/link_launcher.dart';
import '../../../core/theme/app_radius.dart';
import '../domain/public_workspace.dart';
import '../domain/directory_location.dart';
import '../providers/directory_location_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_spacing.dart';

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

class _DirectoryMapState extends ConsumerState<DirectoryMap> {
  final _controller = MapController();
  String? _view;
  bool _ready = false;
  static const _detailZoom = 16.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _focus(List<({PublicWorkspace workspace, DirectoryLocation location})> points,
      PublicWorkspace? target) {
    if (!_ready || points.isEmpty) return;
    final selected = points.where((p) => p.workspace == target).firstOrNull;
    if (selected != null || points.length == 1) {
      final point = (selected ?? points.first).location;
      _controller.move(LatLng(point.latitude, point.longitude), _detailZoom);
    } else {
      _controller.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints([
          for (final p in points) LatLng(p.location.latitude, p.location.longitude),
        ]), padding: const EdgeInsets.all(64), maxZoom: _detailZoom,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final target = widget.workspaces.where((w) =>
        widget.selected == '${w.source}/${w.id}').firstOrNull ??
        (widget.workspaces.length == 1 ? widget.workspaces.first : null);
    final address = target?.text('address').trim() ?? '';
    final needsLookup = target != null && target.location == null;
    final lookup = needsLookup && address.isNotEmpty
        ? ref.watch(directoryAddressLocationProvider(address)) : null;
    final located = [
      for (final w in widget.workspaces)
        if ((w.location ?? (w == target ? lookup?.value : null)) case final point?)
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
                  ? (l?.directoryLocating ?? 'Locating the public address…')
                  : lookup?.value != null
                      ? '${l?.directoryApproximate ?? 'Approximate address location'} · ${lookup!.value!.label}'
                      : (l?.directoryLocationMissing ?? 'Location unavailable. The owner can publish precise map coordinates.'),
              key: const ValueKey('directory-location-status'),
              style: Theme.of(context).textTheme.bodySmall,
            )),
            if (lookup?.hasError == true)
              IconButton(onPressed: () => ref.invalidate(directoryAddressLocationProvider(address)),
                tooltip: l?.commonRetry ?? 'Try again', icon: const Icon(Icons.refresh)),
          ]),
        ),
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
        onMapReady: () { _ready = true; _focus(located, target); },
      ),
      children: [
        TileLayer(
          tileProvider: widget.tileProvider,
          urlTemplate: const String.fromEnvironment(
            'MAP_TILE_URL',
            defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          userAgentPackageName: 'org.deskilo.app',
          maxNativeZoom: 19,
        ),
        MarkerLayer(
          markers: [
            for (final p in located)
              Marker(
                point: LatLng(p.location.latitude, p.location.longitude),
                width: 140,
                height: 42,
                child: Semantics(
                  label: p.workspace.name,
                  button: true,
                  selected: p.workspace == target,
                  child: Material(
                    color: p.workspace == target
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: AppRadius.mdAll,
                    elevation: 3,
                    child: InkWell(
                      onTap: () => widget.onSelect(p.workspace),
                      child: Center(
                        child: Text(
                          p.workspace.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
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
        tooltip: l?.directoryLocate ?? 'Locate on map',
        onPressed: located.isEmpty ? null : () => _focus(located, target),
        icon: const Icon(Icons.center_focus_strong),
      )),
    ])),
    ]);
  }
}
