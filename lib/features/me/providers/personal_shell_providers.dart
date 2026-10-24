// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Whether Me is the five-destination personal shell: ONE evaluation point.
//
// The `personalShell` flag is a platform-tier WorkspaceFeature, and the
// person's layer is an installation's decision, never a selected space's: it
// is read from the registry the installation serves, exactly as the server
// choice reads its features before any space exists — never from the
// workspace the person happens to be in. Entering or leaving a space
// therefore never flips the shell, and never rebuilds the route table the
// router composes from it (app/routes/me_routes.dart). The day the personal
// home publishes its own platform values, this line reads them and nothing
// downstream changes.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../workspace/domain/workspace_feature.dart';

part 'personal_shell_providers.g.dart';

@Riverpod(keepAlive: true)
bool personalShellEnabled(Ref ref) =>
    effectiveFeatures(resolveEnabledFeatures(platformFeaturesOnByDefault))
        .contains(WorkspaceFeature.personalShell);
