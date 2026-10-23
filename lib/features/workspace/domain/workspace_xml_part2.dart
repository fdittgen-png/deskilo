// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_xml.dart';


// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

/// Serializes the workspace configuration to schema-v2 XML. [levels]
/// pairs each level with its drawn plan; desks are nested under the
/// office whose id they reference and seats under their desk, so the
/// document carries no ids at all.
///
/// [accessories] is the WHOLE catalog (inactive included — a backup must
/// be complete, #180) and [seatAccessories] the seat id → accessory ids
/// assignments; both serialize id-free, seats referencing accessories by
/// name in catalog order.
///
/// v3 (#916): [configuration] is the server's configuration tree and
/// becomes the `<configuration>` section when given; [siteNames] (site
/// id → name) and [vatRateLabels] (rate id → label) resolve the plan's
/// references, which the document carries by name.
String buildWorkspaceXml({
  required Workspace workspace,
  required List<({Level level, FloorPlan plan})> levels,
  List<Accessory> accessories = const [],
  Map<String, Set<String>> seatAccessories = const {},
  Map<String, Object?>? configuration,
  Map<String, String> siteNames = const {},
  Map<String, String> vatRateLabels = const {},
}) {
  final sortedLevels = List.of(levels)
    ..sort((a, b) => a.level.sortOrder.compareTo(b.level.sortOrder));
  // Deterministic output: map-backed collections are emitted key-sorted,
  // the catalog in its display order (sort_order, then name — the order
  // the repository serves, re-established here for raw inputs).
  final flagKeys = workspace.featureFlags.keys.toList()..sort();
  final paymentKeys = workspace.paymentInstructions.keys.toList()..sort();
  final sortedAccessories = List.of(accessories)
    ..sort((a, b) {
      final bySortOrder = a.sortOrder.compareTo(b.sortOrder);
      return bySortOrder != 0 ? bySortOrder : a.name.compareTo(b.name);
    });

  final builder = XmlBuilder()
    ..declaration(encoding: 'UTF-8');
  builder.element(WorkspaceXmlSchema.rootElement, nest: () {
    builder.attribute(
        WorkspaceXmlSchema.versionAttr, '${WorkspaceXmlSchema.version}');
    _settingsXml(builder, workspace, flagKeys, paymentKeys);
    _accessoriesXml(builder, sortedAccessories, vatRateLabels);
    builder.element(WorkspaceXmlSchema.floorPlanElement, nest: () {
      for (final entry in sortedLevels) {
        _levelXml(builder, entry, siteNames, seatAccessories,
            sortedAccessories);
      }
    });
    if (configuration != null) writeConfigurationXml(builder, configuration);
  });
  return builder.buildDocument().toXmlString(pretty: true, indent: '  ');
}

void _settingsXml(XmlBuilder builder, Workspace workspace,
    List<String> flagKeys, List<String> paymentKeys) {
  builder.element(WorkspaceXmlSchema.settingsElement, nest: () {
    builder
      ..attribute(WorkspaceXmlSchema.nameAttr, workspace.name)
      ..attribute(
        WorkspaceXmlSchema.countryAttr, workspace.countryCode)
      ..attribute(
        WorkspaceXmlSchema.currencyAttr, workspace.currencyCode)
      ..attribute(WorkspaceXmlSchema.timezoneAttr, workspace.timezone);
    // #1289 — the brand seed, when the space chose one.
    if (WorkspaceBranding.fromJson(workspace.branding).seedArgb
        case final argb?) {
      builder.attribute(
          WorkspaceXmlSchema.brandColorAttr, hexOfColor(argb));
    }
    for (final key in flagKeys) {
      final value = workspace.featureFlags[key];
      if (value is! bool) continue; // defensive: only bools are flags
      builder.element(WorkspaceXmlSchema.featureElement, nest: () {
        builder
          ..attribute(WorkspaceXmlSchema.keyAttr, key)
          ..attribute(WorkspaceXmlSchema.enabledAttr, '$value');
      });
    }
    for (final key in paymentKeys) {
      final value = workspace.paymentInstructions[key];
      if (value is! String || value.trim().isEmpty) continue;
      builder.element(WorkspaceXmlSchema.paymentInstructionElement,
          nest: () {
        builder
          ..attribute(WorkspaceXmlSchema.keyAttr, key)
          ..attribute(WorkspaceXmlSchema.valueAttr, value);
      });
    }
  });
}

void _accessoriesXml(XmlBuilder builder, List<Accessory> sortedAccessories,
    Map<String, String> vatRateLabels) {
  builder.element(WorkspaceXmlSchema.accessoriesElement, nest: () {
    for (final accessory in sortedAccessories) {
      builder.element(WorkspaceXmlSchema.accessoryElement, nest: () {
        builder
          ..attribute(WorkspaceXmlSchema.nameAttr, accessory.name)
          ..attribute(WorkspaceXmlSchema.supplementCentsAttr,
            '${accessory.supplementCents}')
          ..attribute(
            WorkspaceXmlSchema.activeAttr, '${accessory.active}')
          ..attribute(
            WorkspaceXmlSchema.sortOrderAttr, '${accessory.sortOrder}');
        final vatRate = vatRateLabels[accessory.vatRateId];
        if (vatRate != null && vatRate.isNotEmpty) {
          builder.attribute(WorkspaceXmlSchema.vatRateAttr, vatRate);
        }
      });
    }
  });
}

void _levelXml(
    XmlBuilder builder,
    ({Level level, FloorPlan plan}) entry,
    Map<String, String> siteNames,
    Map<String, Set<String>> seatAccessories,
    List<Accessory> sortedAccessories) {
  builder.element(WorkspaceXmlSchema.levelElement, nest: () {
    builder
      ..attribute(WorkspaceXmlSchema.nameAttr, entry.level.name)
      ..attribute(
        WorkspaceXmlSchema.sortOrderAttr, '${entry.level.sortOrder}');
    _priceAttributes(builder, entry.level.priceCents,
        bookableAsWhole: entry.level.bookableAsWhole);
    final site = siteNames[entry.level.siteId];
    if (site != null && site.isNotEmpty) {
      builder.attribute(WorkspaceXmlSchema.siteAttr, site);
    }
    final plan = entry.plan;
    for (final office in plan.offices) {
      builder.element(WorkspaceXmlSchema.officeElement, nest: () {
        builder
          ..attribute(WorkspaceXmlSchema.nameAttr, office.name)
          ..attribute(
            WorkspaceXmlSchema.colorAttr, '${office.color}')
          ..attribute(WorkspaceXmlSchema.bookableAsWholeAttr,
            '${office.bookableAsWhole}');
        _rectAttributes(builder, office.rect);
        _priceAttributes(builder, office.priceCents);
        if (office.areaKind.name != 'workspace') {
          builder.attribute(
              WorkspaceXmlSchema.areaKindAttr, office.areaKind.name);
        }
        for (final desk in plan.desksOf(office.id)) {
          builder.element(WorkspaceXmlSchema.deskElement, nest: () {
            builder.attribute(WorkspaceXmlSchema.nameAttr, desk.name);
            _rectAttributes(builder, desk.rect);
            _priceAttributes(builder, desk.priceCents,
                bookableAsWhole: desk.bookableAsWhole);
            _seatsXml(builder, plan, desk.id, seatAccessories,
                sortedAccessories);
          });
        }
      });
    }
  });
}

void _seatsXml(XmlBuilder builder, FloorPlan plan, String deskId,
    Map<String, Set<String>> seatAccessories,
    List<Accessory> sortedAccessories) {
  for (final seat in plan.seatsOf(deskId)) {
    // Assigned catalog entries, referenced by NAME in
    // catalog order — ids never enter the document.
    final assignedIds = seatAccessories[seat.id] ?? const <String>{};
    _seatElement(builder, seat, [
      for (final accessory in sortedAccessories)
        if (assignedIds.contains(accessory.id)) accessory.name,
    ]);
  }
}

/// v3 plan attributes, written only when they say something: a v3 file
/// of a plain plan reads like a v2 file.
void _priceAttributes(XmlBuilder builder, int priceCents,
    {bool? bookableAsWhole}) {
  if (priceCents != 0) {
    builder.attribute(WorkspaceXmlSchema.priceCentsAttr, '$priceCents');
  }
  if (bookableAsWhole == true) {
    builder.attribute(WorkspaceXmlSchema.bookableAsWholeAttr, 'true');
  }
}

/// `deskilo-<slugified name>.xml` — the file name handed to the share
/// sheet; pure so tests can pin it.
String workspaceXmlFileName(String workspaceName) {
  final slug = workspaceName
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '-')
      .replaceAll(RegExp('^-+|-+\$'), '');
  return 'deskilo-${slug.isEmpty ? 'workspace' : slug}.xml';
}

void _rectAttributes(XmlBuilder builder, GridRect rect) {
  builder
    ..attribute(WorkspaceXmlSchema.xAttr, '${rect.x}')
    ..attribute(WorkspaceXmlSchema.yAttr, '${rect.y}')
    ..attribute(WorkspaceXmlSchema.wAttr, '${rect.w}')
    ..attribute(WorkspaceXmlSchema.hAttr, '${rect.h}');
}

void _seatElement(
    XmlBuilder builder, Seat seat, List<String> accessoryNames) {
  builder.element(WorkspaceXmlSchema.seatElement, nest: () {
    builder
      ..attribute(WorkspaceXmlSchema.nameAttr, seat.name)
      ..attribute(WorkspaceXmlSchema.xAttr, '${seat.x}')
      ..attribute(WorkspaceXmlSchema.yAttr, '${seat.y}')
      ..attribute(
        WorkspaceXmlSchema.orientationAttr, seat.orientation.name)
      ..attribute(WorkspaceXmlSchema.chairAttr, seat.chair);
    final nfcUid = seat.nfcUid;
    if (nfcUid != null && nfcUid.isNotEmpty) {
      builder.attribute(WorkspaceXmlSchema.nfcUidAttr, nfcUid);
    }
    // v4 (#2860) — written only when they differ from a plain seat, so a
    // plan of desk seats reads exactly as it did in v3.
    if (seat.resourceKind != ResourceKind.seat) {
      builder.attribute(
          WorkspaceXmlSchema.resourceKindAttr, seat.resourceKind.name);
    }
    for (final (attribute, value) in [
      (WorkspaceXmlSchema.capacityAttr, seat.capacity),
      (WorkspaceXmlSchema.slotMinutesAttr, seat.slotMinutes),
    ]) {
      if (value != null) builder.attribute(attribute, '$value');
    }
    final parkingKind = seat.parkingKind;
    if (parkingKind != null) {
      builder.attribute(
          WorkspaceXmlSchema.parkingKindAttr, parkingKind.name);
    }
    final from = seat.blockedFrom;
    if (from != null) {
      builder.attribute(WorkspaceXmlSchema.blockedFromAttr,
          from.toUtc().toIso8601String());
    }
    final to = seat.blockedTo;
    if (to != null) {
      builder.attribute(
          WorkspaceXmlSchema.blockedToAttr, to.toUtc().toIso8601String());
    }
    // Legacy amenities keep exporting verbatim (fidelity of the
    // seats.amenities column) ALONGSIDE the v2 catalog references.
    for (final amenity in seat.amenities) {
      builder.element(WorkspaceXmlSchema.amenityElement, nest: () {
        builder.attribute(WorkspaceXmlSchema.nameAttr, amenity);
      });
    }
    for (final name in accessoryNames) {
      builder.element(WorkspaceXmlSchema.accessoryElement, nest: () {
        builder.attribute(WorkspaceXmlSchema.nameAttr, name);
      });
    }
  });
}

// ---------------------------------------------------------------------------
// Import (the parser ships with #164 so round-trip tests pin the schema;
// the import UI is #165)
// ---------------------------------------------------------------------------

/// Parses and validates a schema-v1 OR schema-v2 document (#180). Throws
/// [WorkspaceXmlException] on anything suspicious — never returns a
/// half-valid structure. A v1 document (no `<accessories>`, no seat
/// `<accessory>` refs) parses to an empty catalog; version 3+ →
/// [WorkspaceXmlError.unsupportedVersion].
WorkspaceXmlData parseWorkspaceXml(String input) {
  final XmlElement root;
  try {
    // rootElement throws StateError on a rootless (comments-only) doc.
    root = XmlDocument.parse(input).rootElement;
    // Both catches only translate to the typed error, carrying the original
    // stack; the caller (#165 UI) traces the typed exception.
  } on XmlException catch (e, st) {
    Error.throwWithStackTrace(
      WorkspaceXmlException(WorkspaceXmlError.malformed, e.message),
      st,
    );
  } on StateError catch (e, st) {
    Error.throwWithStackTrace(
      WorkspaceXmlException(WorkspaceXmlError.malformed, e.message),
      st,
    );
  }
  if (root.name.local != WorkspaceXmlSchema.rootElement) {
    throw WorkspaceXmlException(WorkspaceXmlError.wrongRoot,
        'expected <${WorkspaceXmlSchema.rootElement}>, got <${root.name.local}>');
  }
  final rawVersion =
      _requireAttribute(root, WorkspaceXmlSchema.versionAttr);
  final version = int.tryParse(rawVersion);
  if (version == null ||
      !WorkspaceXmlSchema.supportedVersions.contains(version)) {
    throw WorkspaceXmlException(WorkspaceXmlError.unsupportedVersion,
        'unsupported ${WorkspaceXmlSchema.versionAttr}="$rawVersion"');
  }

  final settingsElement =
      _requireElement(root, WorkspaceXmlSchema.settingsElement);
  final floorPlanElement =
      _requireElement(root, WorkspaceXmlSchema.floorPlanElement);
  // Optional in BOTH versions: absent in every v1 file, and a v2 export
  // of a catalog-less workspace round-trips through an empty element.
  final accessoriesElement =
      root.getElement(WorkspaceXmlSchema.accessoriesElement);

  final configurationElement =
      root.getElement(WorkspaceXmlSchema.configurationElement);

  final data = WorkspaceXmlData(
    settings: _parseSettings(settingsElement),
    configuration: configurationElement == null
        ? null
        : parseConfigurationXml(configurationElement),
    accessories: [
      if (accessoriesElement != null)
        for (final accessory in accessoriesElement
            .findElements(WorkspaceXmlSchema.accessoryElement))
          _parseAccessory(accessory),
    ],
    levels: [
      for (final level
          in floorPlanElement.findElements(WorkspaceXmlSchema.levelElement))
        _parseLevel(level),
    ],
  );
  _validateAccessoryRefs(data);
  return data;
}

/// Cross-checks the v2 accessory references (#180): catalog names must be
/// unique (the DB upserts by (workspace_id, name)) and every seat ref
/// must resolve to a catalog entry — the server would raise 'malformed
/// plan: unknown accessory', but a typed client error is clearer.
void _validateAccessoryRefs(WorkspaceXmlData data) {
  final catalogNames = <String>{};
  for (final accessory in data.accessories) {
    if (!catalogNames.add(accessory.name)) {
      throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
          'duplicate <${WorkspaceXmlSchema.accessoryElement}> '
          '${WorkspaceXmlSchema.nameAttr}="${accessory.name}" in the catalog');
    }
  }
  for (final level in data.levels) {
    for (final office in level.offices) {
      for (final desk in office.desks) {
        for (final seat in desk.seats) {
          for (final name in seat.accessoryNames) {
            if (!catalogNames.contains(name)) {
              throw WorkspaceXmlException(WorkspaceXmlError.invalidValue,
                  'seat "${seat.name}" references unknown accessory "$name"');
            }
          }
        }
      }
    }
  }
}

WorkspaceXmlAccessory _parseAccessory(XmlElement element) =>
    WorkspaceXmlAccessory(
      name: _requireAttribute(element, WorkspaceXmlSchema.nameAttr),
      supplementCents: _requireInt(
          element, WorkspaceXmlSchema.supplementCentsAttr, min: 0),
      active: _requireBool(element, WorkspaceXmlSchema.activeAttr),
      sortOrder:
          _requireInt(element, WorkspaceXmlSchema.sortOrderAttr, min: 0),
      vatRate: element.getAttribute(WorkspaceXmlSchema.vatRateAttr) ?? '',
    );

WorkspaceXmlSettings _parseSettings(XmlElement element) {
  final featureFlags = <String, bool>{};
  for (final feature
      in element.findElements(WorkspaceXmlSchema.featureElement)) {
    featureFlags[_requireAttribute(feature, WorkspaceXmlSchema.keyAttr)] =
        _requireBool(feature, WorkspaceXmlSchema.enabledAttr);
  }
  final paymentInstructions = <String, String>{};
  for (final instruction in element
      .findElements(WorkspaceXmlSchema.paymentInstructionElement)) {
    paymentInstructions[
            _requireAttribute(instruction, WorkspaceXmlSchema.keyAttr)] =
        _requireAttribute(instruction, WorkspaceXmlSchema.valueAttr);
  }
  return WorkspaceXmlSettings(
    name: _requireAttribute(element, WorkspaceXmlSchema.nameAttr),
    countryCode: _requireAttribute(element, WorkspaceXmlSchema.countryAttr),
    currencyCode: _requireAttribute(element, WorkspaceXmlSchema.currencyAttr),
    timezone: _requireAttribute(element, WorkspaceXmlSchema.timezoneAttr),
    featureFlags: featureFlags,
    paymentInstructions: paymentInstructions,
    brandColor: switch (element.getAttribute(WorkspaceXmlSchema.brandColorAttr)) {
      final v? when v.trim().isNotEmpty => v.trim(),
      _ => null,
    },
  );
}

WorkspaceXmlLevel _parseLevel(XmlElement element) => WorkspaceXmlLevel(
      name: _requireAttribute(element, WorkspaceXmlSchema.nameAttr),
      sortOrder:
          _requireInt(element, WorkspaceXmlSchema.sortOrderAttr, min: 0),
      priceCents: _optionalInt(element, WorkspaceXmlSchema.priceCentsAttr),
      bookableAsWhole:
          _optionalBool(element, WorkspaceXmlSchema.bookableAsWholeAttr),
      site: element.getAttribute(WorkspaceXmlSchema.siteAttr) ?? '',
      offices: [
        for (final office
            in element.findElements(WorkspaceXmlSchema.officeElement))
          _parseOffice(office),
      ],
    );

WorkspaceXmlOffice _parseOffice(XmlElement element) => WorkspaceXmlOffice(
      name: _requireAttribute(element, WorkspaceXmlSchema.nameAttr),
      color: _requireInt(element, WorkspaceXmlSchema.colorAttr, min: 0),
      bookableAsWhole:
          _requireBool(element, WorkspaceXmlSchema.bookableAsWholeAttr),
      rect: _parseRect(element),
      priceCents: _optionalInt(element, WorkspaceXmlSchema.priceCentsAttr),
      areaKind:
          element.getAttribute(WorkspaceXmlSchema.areaKindAttr) ?? 'workspace',
      desks: [
        for (final desk
            in element.findElements(WorkspaceXmlSchema.deskElement))
          _parseDesk(desk),
      ],
    );

WorkspaceXmlDesk _parseDesk(XmlElement element) => WorkspaceXmlDesk(
      name: _requireAttribute(element, WorkspaceXmlSchema.nameAttr),
      rect: _parseRect(element),
      priceCents: _optionalInt(element, WorkspaceXmlSchema.priceCentsAttr),
      bookableAsWhole:
          _optionalBool(element, WorkspaceXmlSchema.bookableAsWholeAttr),
      seats: [
        for (final seat
            in element.findElements(WorkspaceXmlSchema.seatElement))
          _parseSeat(seat),
      ],
    );
