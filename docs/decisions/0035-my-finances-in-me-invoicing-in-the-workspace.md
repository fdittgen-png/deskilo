# ADR 0035 — My finances live in Me; invoicing stays a workspace process

**Status:** accepted · **Date:** 2026-10-05

## Context
A member's own invoices and the workspace's invoicing process shared screens and
words, so an admin could not tell "what I must do to invoice" from "what I owe".

## Decision
Me › Finances shows a person's outstanding and paid invoices, payments and
reminders across all their workspaces (read `my_finance_overview`, 0380; own
documents only). Invoicing — issuing, reminding, registering payments,
correcting — stays in the workspace, restricted by permission. The function ×
place × role × document matrix is docs/design/MONEY_MATRIX.md.

## Consequences
- One server read gives the cross-workspace view without exposing other
  members' documents.
- The invoicing screens are redesigned around the process (next change).
