---
description: Write or refresh the environments guide — what dev and prod are, creating the pair, deploying between them, in five languages, anchored per object, with its image slots.
---
# /doc-envs — Environments-Guide

Argument: a module name, or `all`.

- **Files**: `Environments-Guide.md` and its `.fr/.de/.es/.it.md` siblings under `docs/wiki/`.
- **Anchor family**: `env.<module>.<screen>.<object>`; images `env-<module>-<screen>--<object>.jpg`.
- **Scope**: why a pair, creating it, the deploy permissions and the access rule, configuring and testing on the dev, the deployment form, what never travels, instance-level pairing.

Follow the `deskilo-documentation` skill, section "Writing a guide section", for
the module: facts from the app, one anchor per object (with its `HelpAnchor`
constant and the screen's `HelpDot`), the text, image slots, five languages,
the checks, then one PR per module and `/doc-wiki` after the merge.

End with a report: the module, the new anchors, the image slots still empty
(`dart run tool/media.dart slots`).
