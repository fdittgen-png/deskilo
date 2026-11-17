// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/money/application/finance_selection_commands.dart';
import '../../features/money/providers/finance_selection_provider.dart';
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/providers/workspace_providers.dart';
import '../session/session_source.dart';
import 'data/workspace_repository.dart' show FakeWorkspaceMembership;
import 'demo_fixture.dart';
import 'demo_space_routing.dart' show kDemoInstallationId;
import 'demo_spaces.dart';

/// A personal finance command keeps the chosen Demo store through dialogs.
Override demoFinanceCommands(DemoFixture fixture) =>
    financeWorkspaceEntryProvider.overrideWith((ref) {
      final principal = ref.watch(sessionStateProvider).value;
      return (target) async {
        if (target.installationId != kDemoInstallationId) return null;
        final key = DemoSpaceKey.values
            .where((k) => k.id == target.workspaceId)
            .singleOrNull;
        if (key == null) return null;
        final space = fixture.space(key);
        final member = await space.workspaces.fetchMyMember(target.workspaceId);
        bool current() =>
            ref.mounted &&
            ref.read(sessionStateProvider).value == principal &&
            member != null &&
            space.workspaces.memberOf(member.id)?.status == MemberStatus.active;
        if (!current()) return null;
        return FinanceCommandTarget(
          target: target,
          memberId: member!.id,
          currency: key.currency,
          commands: space.money.accountCommands,
          gateway: space.money.paymentGateway,
          isCurrent: current,
          release: () {},
          open: () async {
            if (!current()) return false;
            await ref
                .read(activeWorkspaceIdProvider.notifier)
                .select(target.workspaceId);
            return current();
          },
        );
      };
    });
