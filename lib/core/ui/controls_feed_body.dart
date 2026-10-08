// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

/// Caps tall controls so that the activity feed always remains usable.
/// Short controls keep their natural height, leaving the rest for the feed.
class ControlsFeedBody extends StatelessWidget {
  const ControlsFeedBody({
    super.key,
    required this.controls,
    required this.feed,
  });

  final List<Widget> controls;
  final Widget feed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: constraints.maxHeight * 2 / 3),
          child: SingleChildScrollView(
            primary: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: controls),
          ),
        ),
        Expanded(child: feed),
      ],
    ),
  );
}
