---
description: Write or refresh the technical administrator's guide — reports and the designer, the CLI, e-invoicing, exports, integrations, instances, migrations, the trace, in five languages, anchored per object, with its image slots.
---
# /doc-admin-tech — Admin-Technical-Guide

Argument: a module name, or `all`.

- **Files**: `Admin-Technical-Guide.md` and its `.fr/.de/.es/.it.md` siblings under `docs/wiki/`.
- **Anchor family**: `admin.<module>.<screen>.<object>`; images `admin-<module>-<screen>--<object>.jpg`.
- **Scope**: report kinds and presets, bands versus positioned layouts, every element/attribute/unit/operator/filter/loop/placeholder, the window-envelope contract, tool/report.dart, CII and UBL and Factur-X, FEC and SAF-T and DATEV, payment and e-invoice providers, instances and migrations, the trace.

Follow the `deskilo-documentation` skill, section "Writing a guide section", for
the module: facts from the app, one anchor per object (with its `HelpAnchor`
constant and the screen's `HelpDot`), the text, image slots, five languages,
the checks, then one PR per module and `/doc-wiki` after the merge.

End with a report: the module, the new anchors, the image slots still empty
(`dart run tool/media.dart slots`).
