// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3259 — The deployment base and callback stay scoped on both platforms;
// the browser run exercises real startup independently of the VM shard.
import 'deployment_base_vm.dart'
    if (dart.library.js_interop) 'deployment_base_browser.dart' as platform;

void main() => platform.runDeploymentBaseTests();
