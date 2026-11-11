// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../domain/directory_location.dart';
import '../domain/discovery_view.dart';
import '../providers/directory_location_providers.dart';
import '../providers/discovery_view_providers.dart';
import '../providers/saved_places_providers.dart';
import 'map_disclosure_dialog.dart';

enum _Lookup { idle, searching, notFound, failed }

/// #3689 — where the business is on the map, stored with its public page.
///
/// The address is looked up only when the owner asks, behind the notice the
/// map shows before it first contacts the map services. The match is a
/// proposal until the owner uses it; a tap on the map moves the pin. A
/// lookup answers only the request it was made for: a newer lookup, an
/// edited address, a moved pin or another workspace ([scope]) discards it.
class PublicPagePlace extends ConsumerStatefulWidget {
  const PublicPagePlace({
    super.key,
    required this.place,
    required this.address,
    required this.scope,
    required this.onChanged,
    this.enabled = true,
  });

  /// The draft's pin; null when none is stored.
  final DirectoryLocation? place;

  /// The page's address as typed now.
  final String address;

  /// The workspace and account the draft belongs to.
  final Object? scope;
  final ValueChanged<DirectoryLocation?> onChanged;
  final bool enabled;

  @override
  ConsumerState<PublicPagePlace> createState() => _PlaceState();
}

class _PlaceState extends ConsumerState<PublicPagePlace> {
  int _generation = 0;
  _Lookup _lookup = _Lookup.idle;
  DirectoryLocation? _proposal;

  @override
  void didUpdateWidget(PublicPagePlace old) {
    super.didUpdateWidget(old);
    if (old.scope != widget.scope ||
        old.address.trim() != widget.address.trim() ||
        old.place != widget.place) {
      _generation++;
      _proposal = null;
      _lookup = _Lookup.idle;
    }
  }

  bool _accepted(MapServices services) =>
      ref.watch(discoveryViewProvider).value?.accepts(services.identity) ??
      false;

  Future<void> _find() async {
    final services = ref.read(mapServicesProvider);
    final view = await ref.read(discoveryViewProvider.future);
    if (!mounted) return;
    if (!view.accepts(services.identity)) {
      final accepted = await MapDisclosureDialog.ask(
        context,
        services: services,
        remembered: ref.read(savedPlacesNamespaceProvider).value != null,
      );
      if (!accepted || !mounted) return;
      await ref.read(discoveryViewProvider.notifier).acceptMap(show: false);
    }
    if (!mounted) return;
    final address = widget.address.trim();
    final generation = ++_generation;
    setState(() {
      _lookup = _Lookup.searching;
      _proposal = null;
    });
    DirectoryLocation? found;
    var failed = false;
    try {
      found = await ref.read(directoryGeocoderProvider).locate(address);
    } on Object catch (e, st) {
      failed = true;
      TraceLogger.instance.error(
        'directory',
        'public page place lookup failed',
        error: e.runtimeType,
        stackTrace: st,
      );
    }
    // A newer lookup, an edited address, a moved pin or another workspace
    // bumped the generation: this answer is for a request nobody holds.
    if (!mounted || generation != _generation) return;
    setState(() {
      _proposal = found;
      _lookup = failed
          ? _Lookup.failed
          : found == null
          ? _Lookup.notFound
          : _Lookup.idle;
    });
  }

  String _coordinates(DirectoryLocation p) => context.l10n.portalPlaceAt(
    p.latitude.toStringAsFixed(5),
    p.longitude.toStringAsFixed(5),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final services = ref.watch(mapServicesProvider);
    // Watched always: the consent it holds stays alive while the editor is.
    final accepted = _accepted(services);
    final place = widget.place;
    final proposal = _proposal;
    final shown = proposal ?? place;
    final theme = Theme.of(context);
    return Padding(
      padding: AppSpacing.smAll,
      child: Column(
        key: const ValueKey('public-page-place'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.portalPlaceTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            key: const ValueKey('public-page-place-state'),
            place == null ? l.portalPlaceNone : _coordinates(place),
          ),
          if (proposal != null)
            Text(
              key: const ValueKey('public-page-place-found'),
              l.portalPlaceFound(
                proposal.label.isEmpty
                    ? _coordinates(proposal)
                    : proposal.label,
              ),
            ),
          if (_lookup == _Lookup.searching) const LinearProgressIndicator(),
          if (_lookup == _Lookup.notFound)
            Text(
              key: const ValueKey('public-page-place-not-found'),
              l.portalPlaceNotFound,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          if (_lookup == _Lookup.failed)
            Text(
              key: const ValueKey('public-page-place-failed'),
              l.portalPlaceFailed,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          if (shown != null && accepted) ...[
            const SizedBox(height: AppSpacing.xs),
            SizedBox(height: 180, child: _map(services, shown)),
            Text(l.portalPlaceTapToMove, style: theme.textTheme.bodySmall),
          ],
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              OutlinedButton(
                key: const ValueKey('public-page-place-find'),
                onPressed:
                    !widget.enabled ||
                        widget.address.trim().isEmpty ||
                        _lookup == _Lookup.searching
                    ? null
                    : () => unawaited(_find()),
                child: Text(l.portalPlaceFind),
              ),
              if (proposal != null)
                FilledButton(
                  key: const ValueKey('public-page-place-use'),
                  onPressed: widget.enabled
                      ? () => widget.onChanged(proposal)
                      : null,
                  child: Text(l.portalPlaceUse),
                ),
              if (place != null)
                TextButton(
                  key: const ValueKey('public-page-place-remove'),
                  onPressed: widget.enabled
                      ? () => widget.onChanged(null)
                      : null,
                  child: Text(l.portalPlaceRemove),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _map(MapServices services, DirectoryLocation at) => FlutterMap(
    key: ValueKey('public-page-place-map-${at.latitude},${at.longitude}'),
    options: MapOptions(
      initialCenter: LatLng(at.latitude, at.longitude),
      initialZoom: 16,
      onTap: widget.enabled
          ? (_, point) => widget.onChanged(
              DirectoryLocation(point.latitude, point.longitude),
            )
          : null,
    ),
    children: [
      TileLayer(
        urlTemplate: services.tiles,
        userAgentPackageName: MapServices.appPackage,
        tileProvider: ref.watch(mapTileProviderProvider),
      ),
      MarkerLayer(
        markers: [
          Marker(
            point: LatLng(at.latitude, at.longitude),
            child: const Icon(
              Icons.place,
              key: ValueKey('public-page-place-pin'),
            ),
          ),
        ],
      ),
    ],
  );
}
