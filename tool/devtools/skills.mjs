// SPDX-License-Identifier: AGPL-3.0-or-later
import { spawnSync } from 'node:child_process';
import { realpathSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const directory = fileURLToPath(new URL('.', import.meta.url));
export function checkSkills(path = resolve(directory, '../../.claude/skills')) {
  const result = spawnSync(process.env.DESKILO_DART || 'dart', ['run', 'skills_lint', '--ignore-config',
    '--skills-directory', path, '--check-relative-paths', '--format', 'json'],
  { cwd: resolve(directory, 'skills'), encoding: 'utf8', timeout: 60_000 });
  if (result.error) throw result.error;
  if (result.signal) throw new Error(`skills_lint terminated: ${result.signal}`);
  return result;
}

if (process.argv[1] && import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href) {
  if (process.argv.length !== 2) throw new Error('Usage: npm run skills');
  const result = checkSkills();
  process.stdout.write(result.stdout);
  process.stderr.write(result.stderr);
  process.exitCode = result.status;
}
