// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/getting_started_hint.dart';

/// Preserve uncertainty and cached-value freshness when adapting hub facts.
Fact<T> factOf<T>(AsyncValue<T> value) {
  if (value.hasError) return const Fact.offline();
  if (value.isLoading && !value.hasValue) return const Fact.loading();
  if (!value.hasValue) return const Fact.loading();
  return value.isLoading ? Fact.refreshing(value.value as T)
      : Fact.ready(value.value as T);
}

extension MapGettingStartedFact<T> on Fact<T> {
  Fact<R> map<R>(R Function(T value) convert) => switch (state) {
    FactState.ready => Fact.ready(convert(value as T)),
    FactState.refreshing => Fact.refreshing(convert(value as T)),
    FactState.stale => Fact.stale(convert(value as T)),
    FactState.loading => const Fact.loading(),
    FactState.offline => const Fact.offline(),
    FactState.refused => const Fact.refused(),
  };
}
