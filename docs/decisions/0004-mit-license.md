# ADR 0004 — MIT license

**Status:** superseded by [ADR 0009](0009-relicense-0bsd.md) · **Date:** 2026-07-07

## Context

The sibling project Sparkilo is MIT-licensed; the maintainer wants maximum reuse with minimal friction, and F-Droid requires a free license.

## Decision

MIT, © 2026 Florian DITTGEN. SPDX headers (`// SPDX-License-Identifier: MIT`) in every source file. No GPL dependencies (MIT-compatibility rule), matching Sparkilo.

## Consequences

Anyone may fork, including commercially. Copyleft-only libraries are excluded from the dependency set.
