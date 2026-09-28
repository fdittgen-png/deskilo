// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/link_launcher.dart';
import '../../../core/theme/app_radius.dart';
import '../domain/public_workspace.dart';

/// Sparkilo's selected pill/list relationship, representing workspaces instead
/// of fuel stations. No location permission or background tracking is needed.
class DirectoryMap extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final located = workspaces
        .where(
          (w) =>
              w.latitude != null &&
              w.longitude != null &&
              w.latitude!.isFinite &&
              w.longitude!.isFinite &&
              w.latitude!.abs() <= 90 &&
              w.longitude!.abs() <= 180,
        )
        .toList();
    return FlutterMap(
      options: MapOptions(
        initialCenter: located.isEmpty
            ? const LatLng(48.86, 2.35)
            : LatLng(located.first.latitude!, located.first.longitude!),
        initialZoom: located.isEmpty ? 4 : 10,
      ),
      children: [
        TileLayer(
          tileProvider: tileProvider,
          urlTemplate: const String.fromEnvironment(
            'MAP_TILE_URL',
            defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          userAgentPackageName: 'org.deskilo.app',
          maxNativeZoom: 19,
        ),
        MarkerLayer(
          markers: [
            for (final w in located)
              Marker(
                point: LatLng(w.latitude!, w.longitude!),
                width: 140,
                height: 42,
                child: Semantics(
                  label: w.name,
                  button: true,
                  selected: selected == '${w.source}/${w.id}',
                  child: Material(
                    color: selected == '${w.source}/${w.id}'
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: AppRadius.mdAll,
                    elevation: 3,
                    child: InkWell(
                      onTap: () => onSelect(w),
                      child: Center(
                        child: Text(
                          w.name,
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
    );
  }
}
