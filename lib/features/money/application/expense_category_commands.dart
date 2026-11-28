// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4512 -- what an owner does to the expense categories of a business: add, rename, put in order, retire, bring back. The server
// decides; what it refused is told by one of three reasons, never by its sentence.
import '../../../core/data/server_error.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/trace/guarded.dart';
import '../domain/expense_category.dart';

/// Why a change of a category was not made.
enum ExpenseCategoryProblem {
  /// Another active category already has the name.
  nameTaken,

  /// A category that is not built in needs a name.
  nameRequired,

  /// Anything else: no right, no connection, a category that is not the business's.
  failed,
}

// the reasons the server names in the detail of its refusal (DKX01, 0998)
const _taken = 'label_taken';
const _required = 'label_required';

class ExpenseCategoryCommands {
  const ExpenseCategoryCommands(this._repository);

  final ExpenseCategoryRepository _repository;

  /// Every category of [workspaceId], active and retired.
  Future<List<ExpenseCategory>> categories(String workspaceId) => _repository.categories(workspaceId);

  /// A new category (no [id]) or the new name of [id]; an empty [label] on a built-in one gives the app's words back.
  Future<ExpenseCategoryProblem?> save(String workspaceId, {String? id, required String label}) => _do(
    'save expense category failed',
    () async {
      await _repository.save(workspaceId, id: id, label: label.trim(), requestId: newRequestId());
    },
  );

  /// Retires [id], or brings it back.
  Future<ExpenseCategoryProblem?> setRetired(String workspaceId, String id, {required bool retired}) => _do(
    'retire expense category failed',
    () async {
      await _repository.setRetired(workspaceId, id, retired: retired, requestId: newRequestId());
    },
  );

  /// Moves the category at [from] of the active [active] to [to]: each one that is not at its place is saved with it.
  Future<ExpenseCategoryProblem?> move(String workspaceId, List<ExpenseCategory> active, int from, int to) => _do(
    'order expense categories failed',
    () async {
      final moved = [...active];
      moved.insert(to, moved.removeAt(from));
      for (final (i, c) in moved.indexed) {
        if (c.sortOrder != (i + 1) * 10) {
          await _repository.save(workspaceId, id: c.id, label: c.label, sortOrder: (i + 1) * 10, requestId: newRequestId());
        }
      }
    },
  );

  Future<ExpenseCategoryProblem?> _do(String message, Future<void> Function() action) async {
    final problem = await guardSave(
      domain: 'money',
      message: message,
      action: action,
      problem: (e) => switch (serverErrorDetails(e)) {
        _taken => ExpenseCategoryProblem.nameTaken.name,
        _required => ExpenseCategoryProblem.nameRequired.name,
        _ => ExpenseCategoryProblem.failed.name,
      },
    );
    return problem == null ? null : ExpenseCategoryProblem.values.byName(problem);
  }
}
