---
description: Write or refresh the member's guide — every module, screen and field a member sees, in five languages, anchored per object, with its image slots.
---
# /doc-user — User-Guide

Argument: a module name, or `all`.

- **Files**: `User-Guide.md`, `Guide-utilisateur.md`, `Benutzerhandbuch.md`, `Guia-de-usuario.md`, `Guida-utente.md` under `docs/wiki/`.
- **Anchor family**: `user.<module>.<screen>.<object>`; images `user-<module>-<screen>--<object>.jpg`.
- **Scope**: reserve and the plan, calendar, messages, members and profiles, money, events and validations, kiosk and badges, settings.

Follow the `deskilo-documentation` skill, section "Writing a guide section", for
the module: facts from the app, one anchor per object (with its `HelpAnchor`
constant and the screen's `HelpDot`), the text, image slots, five languages,
the checks, then one PR per module and `/doc-wiki` after the merge.

End with a report: the module, the new anchors, the image slots still empty
(`dart run tool/media.dart slots`).
