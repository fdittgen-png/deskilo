// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — Me > Account: whether an assistant built into this browser may
// use the page's tools. Off by default, on this device only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/webmcp/webmcp_device_switch.dart';

class WebMcpDeviceSwitchTile extends ConsumerWidget {
  const WebMcpDeviceSwitchTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final on = ref.watch(webMcpDeviceSwitchProvider).value ?? false;
    return SwitchListTile(
      key: const ValueKey('settings-webmcp-device-switch'),
      secondary: const Icon(Icons.smart_toy_outlined),
      title: Text(l10n.webMcpDeviceSwitch),
      subtitle: Text(l10n.webMcpDeviceSwitchHint),
      value: on,
      onChanged: (value) => runGuarded(
        context,
        domain: 'webmcp',
        message: 'device switch failed',
        errorText: l10n.privacyPushOnDeviceFailed,
        action: () =>
            ref.read(webMcpDeviceSwitchProvider.notifier).set(on: value),
      ),
    );
  }
}
