#!/usr/bin/env bash
# SPDX-License-Identifier: AGPL-3.0-or-later
# Findings are a review report; unreadable inputs or tool failures still fail.
set -euo pipefail
scanner=${1:?path to the pinned zizmor executable required}
out=${2:-report/workflow-security}
mkdir -p "$out"
rm -f "$out/summary.md" "$out/findings.json"
"$scanner" --version > "$out/version.txt"
git rev-parse HEAD > "$out/revision.txt"
git status --porcelain > "$out/working-tree.txt"
"$scanner" --offline --strict-collection --persona=regular --no-exit-codes \
  --format=json-v1 . > "$out/findings.json"
python3 - "$out" <<'PY'
import collections
import json
import pathlib
import sys

out = pathlib.Path(sys.argv[1])
findings = json.loads((out / 'findings.json').read_text())
counts = collections.Counter((f['ident'], f['determinations']['severity'],
                              f['determinations']['confidence']) for f in findings)
with (out / 'summary.md').open('w') as report:
    report.write('# Workflow security report\n\n')
    report.write(f"Revision: `{(out / 'revision.txt').read_text().strip()}`  \n")
    report.write(f"Scanner: `{(out / 'version.txt').read_text().strip()}`  \n")
    state = 'modified (see working-tree.txt)' if (out / 'working-tree.txt').read_text() else 'clean'
    report.write(f'Working tree: {state}\n\n')
    report.write('Report only: findings do not block merging; scanner/input errors fail.\n\n')
    report.write('| Rule | Severity | Confidence | Findings |\n| --- | --- | --- | --- |\n')
    for (rule, severity, confidence), count in sorted(counts.items()):
        report.write(f'| [{rule}](https://docs.zizmor.sh/audits/#{rule}) | {severity} | {confidence} | {count} |\n')
    report.write('\n`unpinned-uses` includes first-party tags permitted by the existing '
                 'workflow hygiene policy; it is not a regression count. Other findings '
                 'require review, including release permissions and inherited secrets. '
                 'The raw JSON retains locations and confidence. Offline analysis does '
                 'not check live advisories or scripts called by workflows.\n')
PY
