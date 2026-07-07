// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeApp();
  runApp(const ProviderScope(child: DeskiloApp()));
}
