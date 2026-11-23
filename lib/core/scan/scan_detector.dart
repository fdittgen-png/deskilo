// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4359 (G10) -- a barcode scanner in keyboard mode types the code and presses Enter (or Tab), far faster than
// a person types. This detector tells the two apart from the time between keys alone: characters are collected
// while each follows the last within the inter-key interval, a gap longer than that starts the collection
// again (a person typing), and a terminator that ends a collection of at least a few characters is a scan.
// It is pure -- it is given each key with its time -- so the timing rules are tested on recorded timings, and
// it never looks at which widget has the focus: the scope that feeds it decides that.

/// How a scanner ends the code it typed.
enum ScanTerminator {
  /// Enter or Tab (what a scanner is usually set up to send).
  either('either'),
  enter('enter'),
  tab('tab');

  const ScanTerminator(this.wire);

  final String wire;

  static ScanTerminator fromWire(String? wire) => values.firstWhere((t) => t.wire == wire, orElse: () => either);
}

/// Recognises a scan in a stream of keys.
class ScanDetector {
  ScanDetector({this.maxInterval = const Duration(milliseconds: 50), this.minLength = 4});

  /// The longest gap between two keys of one scan; a longer gap is a person typing.
  final Duration maxInterval;

  /// The fewest characters a scan has (a shorter burst is not taken for one).
  final int minLength;

  final StringBuffer _buffer = StringBuffer();
  Duration? _last;

  /// The characters collected so far, for a test or a banner.
  String get pending => _buffer.toString();

  /// A character at [at]: collected when it follows the last within [maxInterval], else it starts a new collection.
  void character(String ch, Duration at) {
    final last = _last;
    if (last != null && at - last > maxInterval) _buffer.clear();
    _buffer.write(ch);
    _last = at;
  }

  /// A terminator at [at]: the scanned code when the collection is one (fast enough, long enough), else null.
  /// Either way the collection ends.
  String? terminator(Duration at) {
    final last = _last;
    final fast = last != null && at - last <= maxInterval;
    final code = _buffer.toString();
    reset();
    return fast && code.length >= minLength ? code : null;
  }

  /// Forgets what was collected.
  void reset() {
    _buffer.clear();
    _last = null;
  }
}
