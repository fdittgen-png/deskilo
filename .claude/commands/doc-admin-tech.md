---
description: Write or refresh the technical administrator's guide — reports and the designer, the CLI, e-invoicing, exports, integrations, instances, migrations, the trace, in five languages, anchored per object, with its image slots.
---
# /doc-admin-tech — Admin-Technical-Guide

Read the `deskilo-documentation` skill first. Argument: a module name, or
`all`. Scope of this guide: report kinds and presets, bands versus positioned layouts, every element/attribute/unit/operator/filter/loop/placeholder, the window-envelope contract, tool/report.dart, CII and UBL and Factur-X, FEC and SAF-T and DATEV, payment and e-invoice providers, instances and migrations, the trace.

## 1. Take the facts from the app, not from memory
For the module at hand, read: its screens under `lib/features/<module>/presentation`,
its ARB fragments (`lib/l10n/_fragments/*_en.arb` — every label verbatim,
and the four translations for the four other guides), its registries
(`workspace_feature.dart`, `workspace_permission.dart`, the placeholder
list, the validation domains), and the migrations that define what the
server allows. A guide never invents a label or a rule.

## 2. One anchor per documented object
Every field, every action, every group gets
`admin.<module>.<screen>.<object>` on its heading:
```md
### <Heading exactly as the screen calls it> {#admin.<module>.<screen>.<object>}
```
Add the anchor to `lib/core/help/help_anchors.dart` and point the screen's
`HelpDot`/`HelpDotTitle` at it in the same PR — a documented object with
no symbol, or a symbol with no anchor, is what the lint refuses.

## 3. Write it
- What the object is, in one sentence, then what it decides, then what
  happens if it is left alone (the default), then the rule that is easy
  to get wrong. Say the consequence, not the mechanism.
- The label appears exactly as the app shows it, in that guide's language.
- An image slot per screen and per explained object:
  ```md
  <p><img src="images/admin-<module>-<screen>--<object>.jpg" width="240"></p>
  ```
  A stitched whole form goes inside `<details>`. If the image does not
  exist yet, write the slot anyway and list it at the end of your report:
  `/doc-shots` fills it later without touching a word of the text.

## 4. Five languages, structurally parallel
Same headings, same anchors, same image names; the prose is translated,
not transliterated. Then:
```
dart run tool/build_help.dart
dart run tool/media.dart check
flutter test test/lint test/features/help test/core/help
```

## 5. Ship
One PR per module — the repo's PR budget is small and a guide is long.
Body: which module, which anchors are new, which image slots are still
empty. Then `deskilo-ci-release`, and the wiki mirror with `/doc-wiki`.
