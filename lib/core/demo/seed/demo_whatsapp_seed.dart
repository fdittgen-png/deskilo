// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3963 — the reference business has its WhatsApp group: the invite link the
// owner set, which every member reads as the directory's group tile. The
// link has the shape the settings form and the server accept; its code is
// invented.
import '../data/workspace_repository.dart';

const _groupLink = 'https://chat.whatsapp.com/DemoGroupInvite1';

/// Stores the group link on the main space.
void seedDemoWhatsappGroup(FakeWorkspaceRepository workspaces) {
  final i = workspaces.workspaces.indexWhere((w) => w.id == 'ws-1');
  if (i < 0) return;
  workspaces.workspaces[i] = workspaces.workspaces[i].copyWith(
    whatsappGroup: _groupLink,
  );
}
