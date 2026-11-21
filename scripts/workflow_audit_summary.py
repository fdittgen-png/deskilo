#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
"""Summarise a zizmor report and compare it with the stored baseline.

    workflow_audit_summary.py <report-dir> <baseline.json> [--write-baseline]

The report directory holds findings.json, version.txt, revision.txt and
working-tree.txt (scripts/workflow_audit.sh). The summary is a review report:
it never fails on findings, only on unreadable input. The baseline stores the
count of findings per (rule, severity, confidence) at a revision, for ONE scanner
version. A count above its baseline is "new", below it "resolved"; a baseline
written by another scanner version is shown, not compared, because a different
scanner finds different things.
"""
import collections
import json
import pathlib
import sys


def counts_of(findings):
    return collections.Counter(
        (f['ident'], f['determinations']['severity'], f['determinations']['confidence'])
        for f in findings)


def load_baseline(path):
    if not path.exists():
        return None
    data = json.loads(path.read_text())
    return {
        'scanner': data['scanner'],
        'revision': data['revision'],
        'counts': {(c['rule'], c['severity'], c['confidence']): c['count']
                   for c in data['counts']},
    }


def compare(counts, baseline):
    """(new, resolved) as {key: change}; both empty when nothing can be compared."""
    if baseline is None:
        return {}, {}
    keys = set(counts) | set(baseline['counts'])
    new, resolved = {}, {}
    for key in keys:
        delta = counts.get(key, 0) - baseline['counts'].get(key, 0)
        if delta > 0:
            new[key] = delta
        elif delta < 0:
            resolved[key] = -delta
    return new, resolved


def main(argv):
    out = pathlib.Path(argv[1])
    baseline_path = pathlib.Path(argv[2])
    write = '--write-baseline' in argv[3:]
    findings = json.loads((out / 'findings.json').read_text())
    scanner = (out / 'version.txt').read_text().strip()
    revision = (out / 'revision.txt').read_text().strip()
    counts = counts_of(findings)
    if write:
        baseline_path.write_text(json.dumps({
            'scanner': scanner, 'revision': revision,
            'counts': [{'rule': r, 'severity': s, 'confidence': c, 'count': n}
                       for (r, s, c), n in sorted(counts.items())],
        }, indent=2) + '\n')
    baseline = load_baseline(baseline_path)
    comparable = baseline is not None and baseline['scanner'] == scanner
    new, resolved = compare(counts, baseline if comparable else None)
    with (out / 'summary.md').open('w') as report:
        report.write('# Workflow security report\n\n')
        report.write(f'Revision: `{revision}`  \n')
        report.write(f'Scanner: `{scanner}`  \n')
        state = 'modified (see working-tree.txt)' if (out / 'working-tree.txt').read_text() else 'clean'
        report.write(f'Working tree: {state}\n\n')
        report.write('Report only: findings do not block merging; scanner/input errors fail.\n\n')
        if baseline is None:
            report.write('Baseline: none stored; no difference is computed.\n\n')
        elif not comparable:
            report.write(f"Baseline: `{baseline['scanner']}` at `{baseline['revision']}`; "
                         f'this run uses `{scanner}`, so no difference is computed. '
                         'Record a new baseline in a reviewed change.\n\n')
        else:
            report.write(f"Baseline: `{baseline['scanner']}` at `{baseline['revision']}`. "
                         f'**New findings: {sum(new.values())}**, resolved: {sum(resolved.values())}.\n\n')
        report.write('| Rule | Severity | Confidence | Findings | Baseline | Change |\n'
                     '| --- | --- | --- | --- | --- | --- |\n')
        for key in sorted(set(counts) | (set(baseline['counts']) if comparable else set())):
            rule, severity, confidence = key
            now = counts.get(key, 0)
            was = baseline['counts'].get(key, 0) if comparable else None
            change = '' if was is None else ('new' if key in new else 'resolved' if key in resolved else '=')
            report.write(f'| [{rule}](https://docs.zizmor.sh/audits/#{rule}) | {severity} | '
                         f"{confidence} | {now} | {'' if was is None else was} | "
                         f"{change}{'' if not change or change == '=' else ' ' + str((new.get(key) or resolved.get(key)))} |\n")
        if new:
            report.write('\n**New findings need a look** (the raw JSON holds their locations): ')
            report.write(', '.join(f'{r} {s}/{c} +{n}' for (r, s, c), n in sorted(new.items())) + '.\n')
        report.write('\n`unpinned-uses` includes first-party tags permitted by the existing '
                     'workflow hygiene policy; it is not a regression count. Other findings '
                     'require review, including release permissions and inherited secrets. '
                     'The raw JSON retains locations and confidence. Offline analysis does '
                     'not check live advisories or scripts called by workflows.\n')


if __name__ == '__main__':
    main(sys.argv)
