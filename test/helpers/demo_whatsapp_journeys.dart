// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3963 — the WhatsApp group of the reference business: the owner stores the
// space's group link, and a member reads it where members read it (the
// directory's group tile reads the workspace's `whatsappGroupUri`).
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';

Workspace _space(DemoFixture f) =>
    f.workspaces.workspaces.firstWhere((w) => w.id == 'ws-1');

/// The group link stored on the reference business.
String whatsappGroupOf(DemoFixture f) => _space(f).whatsappGroup;

/// The group link as a member's directory reads it.
Uri? whatsappGroupUriOf(DemoFixture f) => _space(f).whatsappGroupUri;

/// Ada stores a new group link (the settings form accepts only an invite
/// link); the member then reads it, and a link that is not an invite is not
/// accepted by the rule the form and the server share.
Future<bool> whatsappJourney() async {
  final f = DemoFixture.build()..becomePersona(DemoPersona.owner);
  const link = '${WhatsappGroupRules.linkPrefix}DemoGroupInvite2';
  final accepted =
      WhatsappGroupRules.isValid(link) &&
      !WhatsappGroupRules.isValid('https://example.test/group');
  await f.workspaces.setWhatsappGroup('ws-1', link);
  f.becomePersona(DemoPersona.member);
  return accepted &&
      whatsappGroupOf(f) == link &&
      whatsappGroupUriOf(f)?.host == 'chat.whatsapp.com' &&
      whatsappGroupUriOf(f)?.path == '/DemoGroupInvite2';
}
