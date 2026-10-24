// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2553 C2 -- the hosts My reservations reads, from the workspaces my
// personal account names (#2563): one source per installation, with the
// local ids and readable names of my workspaces on it. A reference saved
// on my home without any relationship there holds no booking of mine and
// is left out; a workspace on another installation is read there with
// that installation's own verified client.
import '../../reservations/domain/my_reservations.dart';
import '../domain/personal_workspace_refs.dart';

List<MyReservationsSource> myReservationSourcesOf(PersonalWorkspaceRefs refs) {
  final order = <String>[];
  final workspaces = <String, List<String>>{};
  final labels = <String, List<String>>{};
  final here = <String, bool>{};
  for (final ref in refs.refs) {
    if (ref.hostedHere && ref.status == null) continue;
    final installation = ref.installationId;
    if (!workspaces.containsKey(installation)) {
      order.add(installation);
      workspaces[installation] = [];
      labels[installation] = [];
      here[installation] = ref.hostedHere;
    }
    workspaces[installation]!.add(ref.workspaceId);
    final label = ref.label;
    if (label != null && label.isNotEmpty) labels[installation]!.add(label);
  }
  return List.unmodifiable([
    for (final installation in order)
      MyReservationsSource(
        installationId: installation,
        workspaceIds: List.unmodifiable(workspaces[installation]!),
        hostedHere: here[installation]!,
        labels: List.unmodifiable(labels[installation]!),
      ),
  ]);
}
