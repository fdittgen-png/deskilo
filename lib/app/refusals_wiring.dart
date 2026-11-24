// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4413 -- every feature's refusal words, registered with the core table
// (lib/core/trace/feature_refusals.dart). Composed here, where the features
// are; installed by main.dart before the first screen, and by the tests'
// own configuration (test/flutter_test_config.dart).
import '../features/money/presentation/money_refusal_words.dart';
import '../features/stock/presentation/stock_refusal_words.dart';

/// Registers the refusal words of every feature that owns codes.
void registerFeatureRefusals() {
  registerMoneyRefusals();
  registerStockRefusals();
}
