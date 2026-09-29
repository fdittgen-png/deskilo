// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — Me › Messages. Today it is the account messenger that lived
// behind the globe icon; the unified inbox (#1824) replaces this body.
import 'package:flutter/material.dart';

import '../../directory/presentation/account_messenger_screen.dart';

class MeMessagesTab extends StatelessWidget {
  const MeMessagesTab({super.key});

  @override
  Widget build(BuildContext context) => const AccountMessengerScreen();
}
