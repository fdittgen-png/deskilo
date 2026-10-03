---
description: Write or refresh the configuring owner's guide — configuration, master data, the floor plan and its images, in five languages, anchored per object, with its image slots.
---
# /doc-admin-user — Admin-Configuration-Guide

Argument: a module name, or `all`.

- **Files**: `Admin-Configuration-Guide.md` and its `.fr/.de/.es/.it.md` siblings under `docs/wiki/`.
- **Anchor family**: `config.<module>.<screen>.<object>`; images `config-<module>-<screen>--<object>.jpg`.
- **Scope**: the questionnaire's order, VAT groups and rate versions, tariffs and fee bands, services, packages, accessories, sites, closure days, documents, the plan (levels, offices, desks, seats, orientation, whole-booking, prices, tags), and the AI workflow that turns room photos into a plan image.

Follow the `deskilo-documentation` skill, section "Writing a guide section", for
the module: facts from the app, one anchor per object (with its `HelpAnchor`
constant and the screen's `HelpDot`), the text, image slots, five languages,
the checks, then one PR per module and `/doc-wiki` after the merge.

End with a report: the module, the new anchors, the image slots still empty
(`dart run tool/media.dart slots`).
