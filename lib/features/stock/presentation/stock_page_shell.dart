// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The shell of a stock page and the answer of one read on it. A stock page is
// a title and a body: the app bar with its help symbol, its own actions and
// its reload, the wait for the open business, and, for a read, the progress,
// the failure with Try again, the empty sentence and the content all come from
// here, never as a copy in the screen. (Named for what it is: the domain's
// `StockPage<T>` is a page of rows, not a screen.)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import '../../../core/help/help_dot.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/adaptive/page_measures.dart';
import '../../../core/ui/empty_state.dart';
import '../../../core/ui/kit/page_title.dart';
import '../../../core/ui/loading_view.dart';
import '../../workspace/providers/workspace_providers.dart';
import 'stock_read_failed.dart';

/// A stock screen: [title]; the help symbol of [anchor] named [helpTopic]
/// (the title when null); [actions] of the open business; a reload that reads
/// [reloads] again; and [body] once the open business is known, the progress
/// until then.
class StockPageShell extends ConsumerWidget {
  const StockPageShell({
    super.key,
    required this.title,
    required this.body,
    this.anchor,
    this.helpTopic,
    this.actions,
    this.reloads,
    this.reloadKey,
    this.bottom,
    this.floatingActionButton,
    this.reading = false,
  });

  final String title;

  /// The guide section the help symbol opens; no symbol when null.
  final String? anchor;

  /// What the help symbol is named; the title when null.
  final String? helpTopic;

  /// The page's own buttons in the app bar, before the reload.
  final List<Widget> Function(BuildContext context, String workspaceId)?
  actions;

  /// The reads the reload button repeats; no reload button when null.
  final List<ProviderOrFamily> Function(String workspaceId)? reloads;
  final Key? reloadKey;

  /// Below the title (the tabs of a page that has them).
  final PreferredSizeWidget? bottom;

  /// Shown once the open business is known.
  final Widget? Function(WidgetRef ref, String workspaceId)? floatingActionButton;

  /// The body is drawn in the reading column, centred.
  final bool reading;

  /// The page's content for the open business, built with this page's [WidgetRef] (what the body watches is the
  /// page's own dependency, not the screen's around it).
  final Widget Function(BuildContext context, WidgetRef ref, String workspaceId)
  body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceId = ref.watch(currentWorkspaceProvider).value?.id;
    final reloads = this.reloads;
    Widget? content;
    if (workspaceId != null) {
      content = body(context, ref, workspaceId);
      if (reading) {
        content = Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kReadingColumnWidth),
            child: content,
          ),
        );
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(title),
        bottom: bottom,
        actions: [
          if (anchor case final a?) HelpDot(helpTopic ?? title, anchor: a),
          if (workspaceId != null) ...?actions?.call(context, workspaceId),
          if (reloads != null && workspaceId != null)
            IconButton(
              key: reloadKey,
              icon: const Icon(Icons.refresh),
              tooltip: context.l10n.overviewLayoutReload,
              onPressed: () {
                for (final p in reloads(workspaceId)) {
                  ref.invalidate(p);
                }
              },
            ),
        ],
      ),
      floatingActionButton: workspaceId == null
          ? null
          : floatingActionButton?.call(ref, workspaceId),
      body: content ?? const LoadingView(),
    );
  }
}

/// The answer of one read that is a section of a page (it sizes to its
/// content, inside a list): the progress while there is no answer; the
/// failure with Try again, never drawn as an empty list; the [empty] sentence
/// under [emptyIcon] when [isEmpty]; and [data] otherwise, with the failure of
/// a refresh above the content it keeps. The keys are the section's own:
/// `<keyName>-failed`, `<keyName>-retry`, `<keyName>-empty`.
class StockRead<T> extends StatelessWidget {
  const StockRead({
    super.key,
    required this.keyName,
    required this.value,
    required this.onRetry,
    required this.data,
    this.isEmpty,
    this.empty,
    this.emptyIcon = Icons.inventory_2_outlined,
  });

  final String keyName;
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T value) data;

  /// Whether a value is the empty answer; with [empty], the sentence shown
  /// instead of [data].
  final bool Function(T value)? isEmpty;
  final String? empty;
  final IconData emptyIcon;

  @override
  Widget build(BuildContext context) {
    final empty = this.empty;
    if (value.hasValue) {
      final v = value.requireValue;
      final failure = value.hasError
          ? StockReadFailed(
              keyName: keyName,
              error: value.error!,
              onRetry: onRetry,
            )
          : null;
      if (empty != null && (isEmpty?.call(v) ?? false)) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?failure,
            EmptyState(
              key: ValueKey('$keyName-empty'),
              icon: emptyIcon,
              title: empty,
            ),
          ],
        );
      }
      if (failure == null) return data(v);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [failure, data(v)],
      );
    }
    if (value.hasError && !value.isLoading) {
      return StockReadFailed(
        keyName: keyName,
        error: value.error!,
        onRetry: onRetry,
      );
    }
    return const LoadingView();
  }
}
