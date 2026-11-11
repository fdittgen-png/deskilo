// SPDX-License-Identifier: AGPL-3.0-or-later
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { lstatSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const directory = fileURLToPath(new URL('.', import.meta.url));
const repository = resolve(directory, '../..');
const common = ['CLAUDE.md', 'docs/AGENT_RULES.md'];
const scopes = {
  forms: [...common, '.claude/skills/deskilo-forms', '.claude/skills/deskilo-widget-test-gotchas',
    'lib/core/ui/form_kit.dart', 'lib/core/ui/form_sheet.dart', 'lib/core/ui/kit',
    'test/helpers/pump_app.dart', 'test/ux/experience_guards.dart', 'test/core/ui/kit'],
  mcp: [...common, 'contracts/mcp', 'supabase/functions/deskilo-mcp',
    'supabase/functions/_shared/delegated.ts', 'supabase/functions/_shared/local_jwt.ts',
    'supabase/functions/_shared/mcp_validate.ts', 'supabase/functions/_shared/mcp_contract.ts',
    'lib/features/mcp/domain', 'tool/build_mcp_contract.dart', 'tool/mcp_contract'],
  delivery: [...common, '.github/workflows', '.github/dependabot.yml',
    'scripts/worktree_prepare.py', 'tool/preflight.dart', 'tool/preflight',
    'test/lint/workflow_hygiene_test.dart'],
};
const hash = (value) => createHash('sha256').update(value).digest('hex');
const git = (root, ...args) => execFileSync('git', args, { cwd: root, encoding: 'utf8' }).trimEnd();

export function inputs(scope, root = repository) {
  if (!Object.hasOwn(scopes, scope)) throw new Error(`Choose a scope: ${Object.keys(scopes).join(', ')}`);
  const files = git(root, 'ls-files', '-z', '--', ...scopes[scope]).split('\0').filter(Boolean).sort();
  if (!files.length) throw new Error('The selected scope contains no tracked files');
  const canonicalRoot = realpathSync(root);
  for (const file of files) {
    const path = join(root, file);
    if (/[\r\n]/.test(file) || lstatSync(path).isSymbolicLink() || realpathSync(path) !== join(canonicalRoot, file)) {
      throw new Error(`Unsafe context path: ${file}`);
    }
  }
  return files;
}

export function capture(scope, root = repository) {
  const files = inputs(scope, root);
  const snapshot = () => ({
    revision: git(root, 'rev-parse', 'HEAD'),
    tree: git(root, 'rev-parse', 'HEAD^{tree}'),
    workingTree: git(root, 'status', '--porcelain'),
    selectedInputs: Object.fromEntries(files.map((file) => [file, hash(readFileSync(join(root, file)))])),
  });
  const before = snapshot();
  const parent = join(root, '.dart_tool/deskilo_quality/context');
  mkdirSync(parent, { recursive: true });
  const output = mkdtempSync(join(parent, `${scope}-`));
  try {
    const config = join(output, 'repomix.json');
    writeFileSync(config, JSON.stringify({ security: { enableSecurityCheck: true } }));
    const packed = join(output, 'context.xml');
    execFileSync(process.execPath, [join(directory, 'node_modules/repomix/bin/repomix.cjs'),
      '--config', config, '--stdin', '--output', packed, '--style', 'xml', '--parsable-style',
      '--ignore', '**/.env*,**/*.pem,**/*.key,**/node_modules/**', '--quiet'],
    { cwd: root, input: files.join('\n'), timeout: 120_000, stdio: ['pipe', 'pipe', 'pipe'] });
    if (JSON.stringify(before) !== JSON.stringify(snapshot())) throw new Error('Inputs changed while packing; retry on a stable tree');
    writeFileSync(join(output, 'provenance.json'), JSON.stringify({
      scope, capturedAt: new Date().toISOString(), repomix: '1.19.0', ...before,
      outputSha256: hash(readFileSync(packed)),
      note: 'Selected tracked inputs; Repomix ignore/security rules may omit files. Inspect context.xml before sharing.',
    }, null, 2) + '\n');
    return output;
  } catch (error) {
    rmSync(output, { recursive: true, force: true });
    throw error;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href) {
  if (process.argv.length !== 3) throw new Error('Usage: npm run context -- forms|mcp|delivery');
  console.log(capture(process.argv[2]));
}
