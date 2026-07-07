// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';

/// Composition root of DesKilo.
///
/// Theme (#14), router/shell (#15) and localization (#13) are wired in here
/// by their respective Epic-#1 children; until then this boots a placeholder.
class DeskiloApp extends StatelessWidget {
  const DeskiloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DesKilo',
      theme: ThemeData(useMaterial3: true),
      home: const _PlaceholderScreen(),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('DesKilo')),
    );
  }
}
