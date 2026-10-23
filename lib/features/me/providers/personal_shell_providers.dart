// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Whether Me is the five-destination personal shell: ONE evaluation point.
//
// The `personalShell` flag is a platform-tier WorkspaceFeature, and the
// person's layer is an installation's decision, never a space's: it is read
// from the feature set the installation serves — the registry's own defaults
// when no space is selected, which is all a personal-only home has. In a
// combined deployment that set is the selected space's, so the shell, its
// routes and the layer's theme read this provider and nothing else; the day
// the personal home's own registry feeds it, this line moves and they do not.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';

part 'personal_shell_providers.g.dart';

@Riverpod(keepAlive: true)
bool personalShellEnabled(Ref ref) => ref
    .watch(enabledFeaturesSyncProvider)
    .contains(WorkspaceFeature.personalShell);
