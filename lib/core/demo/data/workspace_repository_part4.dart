// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'workspace_repository.dart';

// #2386 — part 4 of FakeWorkspaceRepository, split out of workspace_repository.dart so no
// file holds the whole class.
extension _FakeWorkspaceRepositoryPart4 on FakeWorkspaceRepository {

  Future<String?> _fetchDefaultWorkspaceIdImpl() async =>
      serverDefaultWorkspaceId;

  Future<void> _setDefaultWorkspaceIdImpl(String? workspaceId) async {
    serverDefaultWorkspaceId = workspaceId;
  }

  Future<WorkHours> _fetchWorkHoursImpl(String workspaceId) async =>
      workHours[workspaceId] ?? WorkHours.defaults;

  Future<void> _setWorkHoursImpl(String workspaceId, WorkHours hours) async {
    workHours[workspaceId] = hours;
  }

  Future<WorkHoursProvenance> _fetchWorkHoursProvenanceImpl(String workspaceId) async =>
      workHoursProvenance[workspaceId] ?? WorkHoursProvenance.productDefault;

  Future<void> _resetWorkHoursToDefaultImpl(String workspaceId) async {
    workHoursResets.add(workspaceId);
    workHours.remove(workspaceId);
    workHoursProvenance[workspaceId] = WorkHoursProvenance.productDefault;
  }

  Future<List<ClosureDay>> _fetchClosureDaysImpl(String workspaceId) async =>
      closureDays.where((c) => c.workspaceId == workspaceId).toList()
        ..sort((a, b) => a.day.compareTo(b.day));

  Future<HolidayGeneration> _generateClosureDaysImpl(
    String workspaceId, {
    required String country,
    required int year,
    bool apply = false,
  }) async {
    holidayCalls.add((country: country, year: year, apply: apply));
    if (!apply) {
      return HolidayGeneration(
        days: holidayGeneration.days,
        lockedMonths: holidayGeneration.lockedMonths,
        created: 0,
      );
    }
    var created = 0;
    for (final d in holidayGeneration.creatable) {
      closureDays.add(ClosureDay(
        id: 'closure-${_nextId++}',
        workspaceId: workspaceId,
        day: d.day,
        reason: d.key,
      ));
      created++;
    }
    return HolidayGeneration(
      days: holidayGeneration.days,
      lockedMonths: holidayGeneration.lockedMonths,
      created: created,
    );
  }

  Future<HolidayGeneration> _importClosureDaysImpl(
    String workspaceId, {
    required List<({DateTime day, String name})> days,
    bool apply = false,
  }) async {
    holidayImportCalls.add((days: List.of(days), apply: apply));
    String month(DateTime d) => yearMonth(d.year, d.month);
    bool present(DateTime d) => closureDays.any(
        (c) => c.workspaceId == workspaceId && c.day == d);
    final answer = [
      for (final d in days)
        (
          day: d.day,
          key: d.name,
          locked: invoicedMonths.contains(month(d.day)),
          present: present(d.day),
        ),
    ];
    var created = 0;
    if (apply) {
      for (final d in answer.where((d) => !d.locked && !d.present)) {
        closureDays.add(ClosureDay(
          id: 'closure-${_nextId++}',
          workspaceId: workspaceId,
          day: d.day,
          reason: d.key,
        ));
        created++;
      }
    }
    return HolidayGeneration(
      days: answer,
      lockedMonths: {
        for (final d in answer)
          if (d.locked) month(d.day),
      }.toList()
        ..sort(),
      created: created,
    );
  }

  Future<ClosureDay> _addClosureDayImpl(
    String workspaceId,
    DateTime day,
    String reason,
  ) async {
    final closure = ClosureDay(
      id: 'closure-${_nextId++}',
      workspaceId: workspaceId,
      day: DateTime(day.year, day.month, day.day),
      reason: reason,
    );
    closureDays.add(closure);
    return closure;
  }

  Future<void> _removeClosureDayImpl(String closureDayId) async {
    closureDays.removeWhere((c) => c.id == closureDayId);
  }

  Future<void> _resetWorkspaceImpl(String workspaceId) async {
    resetWorkspaceCalls.add(workspaceId);
  }

  Future<Workspace> _saveWorkspaceSettingsImpl(
      String workspaceId, WorkspaceSettingsSave save) async {
    settingsSaves.add(save);
    if (settingsConflictNext) {
      settingsConflictNext = false;
      throw const WorkspaceSettingsConflict();
    }
    if (settingsFailure case final failure?) throw failure;
    // One transaction on the server; here the setters the older tests pin.
    await updateWorkspaceLocale(workspaceId,
        countryCode: save.countryCode,
        currencyCode: save.currencyCode,
        timezone: save.timezone);
    await setWhatsappGroup(workspaceId, save.whatsappGroup.trim());
    await setWorkspaceAddress(workspaceId, save.address.trim());
    await setInvitationTemplates(workspaceId, save.invitationTemplates);
    await setInvitationTemplate(workspaceId, '');
    await setWorkspaceLanguage(workspaceId, save.defaultLocale);
    await setDeskOpacity(workspaceId, save.deskOpacity);
    if (save.newMemberDefaults case final d?) await setNewMemberDefaults(workspaceId, d); // #1563 — absent means "never loaded": the server leaves the key alone
    return workspaces.firstWhere((w) => w.id == workspaceId);
  }

  Future<void> _setDeskOpacityImpl(String workspaceId, int opacity) async {
    lastDeskOpacity = opacity;
    final i = workspaces.indexWhere((w) => w.id == workspaceId);
    if (i >= 0) workspaces[i] = workspaces[i].copyWith(deskOpacity: opacity);
  }

  Future<void> _updateMemberStatusImpl(
    String memberId,
    MemberStatus status,
  ) async {
    if (myMember.id == memberId) {
      myMember = myMember.copyWith(status: status);
      return;
    }
    final i = otherMembers.indexWhere((m) => m.id == memberId);
    if (i >= 0) otherMembers[i] = otherMembers[i].copyWith(status: status);
  }

  Future<List<WorkspaceTemplate>> _fetchWorkspaceTemplatesImpl() async =>
      List.of(templates); // #1656 next apply's report

  Future<TemplateApplyResult> _applyWorkspaceTemplateImpl(String workspaceId, String templateId,
      {List<String>? groups, int? expectedVersion, String? requestId}) async {
    if (!templates.any((t) => t.id == templateId)) {
      throw Exception('unknown template');
    }
    appliedTemplates.add(
        (workspaceId: workspaceId, templateId: templateId, groups: groups));
    return templateApplyResult;
  }

  Future<TemplatePublication> _templatePublicationPreviewImpl(String workspaceId,
      {List<String>? groups}) async {
    if (groups == null) return publication;
    return TemplatePublication(
      published: [
        for (final p in publication.published)
          if (groups.contains(p.group.wire)) p,
      ],
      neverPublished: publication.neverPublished,
      planNames: groups.contains('space') ? publication.planNames : const [],
    );
  }

  Future<TemplatePreview> _previewWorkspaceTemplateImpl(
      String workspaceId, String templateId, {List<String>? groups}) async {
    final set = templatePreviews[templateId];
    if (set != null) return set;
    final t = templates.firstWhere((x) => x.id == templateId,
        orElse: () => throw Exception('unknown template'));
    return TemplatePreview(
      compatibility: TemplateCompatibility.supported,
      groups: [
        if (t.entities.contains('floor_plan'))
          TemplateGroupPreview(
            group: TemplateGroup.space,
            wire: 'space',
            state: TemplateGroupState.isNew,
            itemCount: t.counts.seats + t.counts.desks + t.counts.levels,
          ),
      ],
    );
  }

  Future<TemplateInspection> _inspectWorkspaceTemplateImpl(String templateId) async {
    final set = templateInspections[templateId];
    if (set != null) return set;
    final t = templates.firstWhere((x) => x.id == templateId,
        orElse: () => throw Exception('unknown template'));
    // A seeded outline refusal (#1303 tests) refuses here too.
    final outline = await workspaceTemplateOutline(templateId);
    return TemplateInspection(
      templateId: t.id,
      key: t.key,
      name: t.name,
      entities: t.entities,
      status: TemplateInspectionStatus.ok,
      profile: t.carriesConfiguration ? TemplateProfile.partial : TemplateProfile.legacy,
      compatibility: outline.compatibility,
      outline: outline,
    );
  }

  Future<TemplateOutline> _workspaceTemplateOutlineImpl(String templateId) async {
    final set = templateOutlines[templateId];
    if (set != null) return set;
    final t = templates.firstWhere((x) => x.id == templateId,
        orElse: () => throw Exception('unknown template'));
    return TemplateOutline(
      compatibility: TemplateCompatibility.supported,
      groups: [
        if (t.entities.contains('floor_plan')) TemplateGroup.space,
      ],
    );
  }

  Future<String> _saveWorkspaceAsTemplateImpl(
    String workspaceId, {
    required String key,
    required String name,
    String description = '',
    TemplateVisibility visibility = TemplateVisibility.private,
    List<String> tags = const [],
    List<String>? groups,
    String? requestId,
  }) async {
    // #1658 — the same request again is a retry, not a second publication.
    final args = '$key|$name|$description|${visibility.name}|$tags|$groups';
    if (requestId != null) {
      final prior = publishRequests[requestId];
      if (prior != null) {
        if (prior.args != args) throw const TemplatePublishConflict();
        return prior.id;
      }
    }
    savedTemplateGroups.add(groups);
    if (visibility == TemplateVisibility.builtin) {
      throw Exception('a workspace cannot publish a builtin template');
    }
    templates.removeWhere((t) => t.ownerWorkspaceId == workspaceId && t.key == key);
    final id = 'tpl-$key';
    templates.add(WorkspaceTemplate(
      id: id, key: key, name: name, description: description,
      visibility: visibility, ownerWorkspaceId: workspaceId, tags: tags,
      floorPlan: const <Object?>[<String, Object?>{'name': 'Snapshot', 'offices': <Object?>[]}],
    ));
    if (requestId != null) publishRequests[requestId] = (args: args, id: id);
    if (loseNextPublishResponse) {
      loseNextPublishResponse = false;
      throw Exception('ClientException: Connection reset');
    }
    return id;
  }

  Future<void> _setWorkspaceTemplateVisibilityImpl(
      String templateId, TemplateVisibility visibility) async {
    final i = templates.indexWhere((t) => t.id == templateId);
    if (i < 0) throw Exception('unknown template');
    final t = templates[i];
    templates[i] = WorkspaceTemplate(
      id: t.id, key: t.key, name: t.name, description: t.description,
      visibility: visibility, ownerWorkspaceId: t.ownerWorkspaceId, floorPlan: t.floorPlan,
    );
  }

  Future<void> _deleteWorkspaceTemplateImpl(String templateId) async {
    templates.removeWhere((t) => t.id == templateId);
    templateGrants.remove(templateId);
  }

  Future<void> _grantWorkspaceTemplateImpl(String templateId, String email) async {
    final list = templateGrants.putIfAbsent(templateId, () => []);
    final e = email.trim().toLowerCase();
    if (!list.contains(e)) list.add(e);
  }

  Future<void> _revokeWorkspaceTemplateGrantImpl(String templateId, String email) async {
    templateGrants[templateId]?.remove(email.trim().toLowerCase());
  }

  Future<List<String>> _workspaceTemplateGranteesImpl(String templateId) async =>
      List.of(templateGrants[templateId] ?? const []);
}
