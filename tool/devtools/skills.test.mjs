// SPDX-License-Identifier: AGPL-3.0-or-later
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { checkSkills } from './skills.mjs';

test('official linter accepts valid skills and rejects metadata and reference defects', (t) => {
  const root = mkdtempSync(join(tmpdir(), 'deskilo-skills-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const skill = join(root, 'fixture-skill');
  mkdirSync(skill);
  const path = join(skill, 'SKILL.md');
  const valid = '---\nname: fixture-skill\ndescription: Validate a synthetic fixture.\n---\n# Fixture\n';
  writeFileSync(path, valid);
  assert.equal(checkSkills(root).status, 0);
  const alias = join(root, 'skill-entry.mjs');
  symlinkSync(fileURLToPath(new URL('./skills.mjs', import.meta.url)), alias);
  const cli = spawnSync(process.execPath, [alias, '--unexpected'], { encoding: 'utf8' });
  assert.notEqual(cli.status, 0);
  assert.match(cli.stderr, /Usage/);
  writeFileSync(path, valid + '[Missing reference](missing.md)\n');
  const missing = checkSkills(root);
  assert.notEqual(missing.status, 0);
  assert.match(missing.stdout, /check-relative-paths/);
  writeFileSync(path, valid.replace('name: fixture-skill', 'name: [broken'));
  assert.notEqual(checkSkills(root).status, 0);
  writeFileSync(path, valid);
  assert.equal(checkSkills(root).status, 0);
});
