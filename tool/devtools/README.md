# Local development tools

These tools supplement the gates in `docs/AGENT_RULES.md`. They do not grant
permissions, change the product, or make an unexecuted test pass.

## Install and verify

Use the repository's Flutter/Dart SDK and Node **24.22.1** (`.node-version`).
From the repository root:

```bash
npm ci --prefix tool/devtools
cd tool/devtools/skills
dart pub get --enforce-lockfile
cd ..
npm run skills
npm test
```

On Windows, point `DESKILO_DART` at Flutter's
`bin\cache\dart-sdk\bin\dart.exe` before the Node commands if `dart` on PATH
resolves to a batch launcher. The wrapper invokes the executable directly,
without a command shell. CI runs these controls on Linux.

The Node and Dart lockfiles are committed. No global install, automatic skill
fix, generated ignore baseline, paid provider or hosted tracing is involved.
Upgrades change the exact manifest pins and locks in a reviewed PR. This Dart
tool package is outside `worktree_prepare.py`'s app/package discovery; the
explicit resolution and tests above are required when changing this directory.
`CI · Developer tools` runs them for changes to this toolchain or project skills.

## Export focused context

From `tool/devtools`, run `npm run context -- forms`, `mcp` or `delivery`.
The named scopes in `context.mjs` select tracked files only. Symlinks and unknown
scope arguments are refused. Repomix's ignore and secret checks remain enabled;
source is not compressed. Output stays in an ignored
`.dart_tool/deskilo_quality/context/<scope>-*/` directory.

`context.xml` is the actual export; `provenance.json` records the revision,
committed tree, working-tree status, selected input hashes and output hash.
Selected inputs can be omitted by ignore/security rules: inspect the XML before
sharing. Inputs changed during packing cause failure and removal of that run's
partial output. No model call or remote repository upload occurs.

## Validate project skills

`npm run skills` executes pinned upstream `skills_lint` against `.claude/skills`,
including local Markdown links. The fixture test proves malformed YAML and a
missing linked file fail, then a corrected skill passes. This is structural
validation, not a benchmark of instruction quality or agent performance.

Remove this directory and its ignored outputs to uninstall. Source references:
[Repomix](https://github.com/yamadashy/repomix),
[skills_lint](https://github.com/google/skills_lint.dart).
