# ADR 0001 — Flutter with the Sparkilo stack

**Status:** accepted · **Date:** 2026-07-07

## Context

DesKilo must ship on Android (Play + F-Droid) and iOS from one codebase, and the maintainer already runs the tankstellen/Sparkilo Flutter app with a proven toolchain, CI, and set of conventions.

## Decision

Use Flutter (pinned stable) with the same stack as Sparkilo: Riverpod 3 with codegen for state, freezed + json_serializable for models, go_router with a `StatefulShellRoute` shell, flex_color_scheme (Material 3) for theming, Hive (encrypted) for local storage, Dio behind the service-chain pattern for HTTP. Feature-first architecture with a strict `core/`.

## Consequences

Conventions, lint tests, l10n pipeline, and CI workflows can be carried over nearly 1:1; contributors move between the two repos without relearning. The cost is inheriting Sparkilo's constraints (codegen discipline, ARB pipeline) from day one — accepted, they are the point.
