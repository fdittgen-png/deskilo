// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-e -- what the Invoice-the-month screen holds while it works: who is
// ticked, what is known of each customer, which line is issuing, whether
// something is running and how it ended. One object the screen listens to, so
// the screen itself keeps no scattered state.
import 'package:flutter/foundation.dart';

import '../../application/issue_month.dart';
import '../../application/issue_month_readiness.dart';

class MonthFlowState extends ChangeNotifier {
  MonthFlowState(Iterable<String> memberIds) : _selected = {...memberIds};

  final Set<String> _selected;
  final Map<String, MonthLineProgress> _progress = {};
  MonthReadiness _readiness = const MonthReadiness({});
  MonthIssueReport? _report;
  bool _busy = false;

  bool isSelected(String memberId) => _selected.contains(memberId);
  Set<String> get selected => Set.unmodifiable(_selected);
  MonthLineProgress? progressOf(String memberId) => _progress[memberId];
  MonthReadiness get readiness => _readiness;
  MonthIssueReport? get report => _report;
  bool get busy => _busy;

  /// One customer's readiness arrived. A customer who needs a fix cannot be
  /// ticked; one who no longer does is ticked again; an unknown read changes
  /// nothing.
  void readinessArrived(String memberId, LineReadiness readiness) {
    _readiness = _readiness.with_(memberId, readiness);
    if (_readiness.needsFix(memberId)) {
      _selected.remove(memberId);
    } else if (readiness is! ReadinessUnknown) {
      _selected.add(memberId);
    }
    notifyListeners();
  }

  /// Ticks or unticks a customer; a customer who needs a fix stays unticked.
  void toggle(String memberId, {required bool on}) {
    if (_busy || _readiness.needsFix(memberId)) return;
    on ? _selected.add(memberId) : _selected.remove(memberId);
    notifyListeners();
  }

  /// Ticks every free customer, or none when they all were ticked.
  void toggleAll(Iterable<String> free) {
    if (_busy) return;
    final ids = free.toList();
    final all = ids.isNotEmpty && ids.every(_selected.contains);
    _selected
      ..clear()
      ..addAll(all ? const <String>[] : ids);
    notifyListeners();
  }

  void progress(String memberId, MonthLineProgress p) {
    _progress[memberId] = p;
    notifyListeners();
  }

  void started() {
    _busy = true;
    notifyListeners();
  }

  void finished(MonthIssueReport report) {
    _report = report;
    _busy = false;
    _progress.clear();
    notifyListeners();
  }
}
