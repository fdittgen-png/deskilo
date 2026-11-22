// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4170 -- the Stock page as an address opens it: `/stock?item=<id>` shows the
// stock of that one item (a sale refused for what the main store holds links
// here), `/stock` shows all of it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/stock_view.dart';
import 'stock_screen.dart';

class StockEntry extends ConsumerStatefulWidget {
  const StockEntry({super.key, this.itemId});

  /// The item the address names, or null.
  final String? itemId;

  @override
  ConsumerState<StockEntry> createState() => _StockEntryState();
}

class _StockEntryState extends ConsumerState<StockEntry> {
  @override
  void initState() {
    super.initState();
    final id = widget.itemId;
    if (id != null && id.isNotEmpty) {
      // the screen watches the view, so it is alive by the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(stockViewProvider.notifier).filter(itemId: id);
      });
    }
  }

  @override
  Widget build(BuildContext context) => const StockScreen();
}
