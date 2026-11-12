// SPDX-License-Identifier: AGPL-3.0-or-later
// #3622 -- compares a first-load trace and the build folder with the ceilings
// in tool/web/size_budget.json. Exits 1 on a breach and says which number.
//
//   node tool/web/first_load_trace.mjs --json trace.json
//   node tool/web/size_budget_check.mjs --trace trace.json [--dir build/web]
import {readFile, readdir, stat} from 'node:fs/promises';
import {join, resolve} from 'node:path';

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : fallback;
};
const dir = resolve(opt('--dir', 'build/web'));
const budgetFile = new URL('./size_budget.json', import.meta.url);
const trace = JSON.parse(await readFile(opt('--trace', 'trace.json'), 'utf8'));
const {budgets} = JSON.parse(await readFile(budgetFile, 'utf8'));

async function folderBytes(path) {
  let total = 0;
  for (const entry of await readdir(path, {withFileTypes: true})) {
    const full = join(path, entry.name);
    total += entry.isDirectory() ? await folderBytes(full) : (await stat(full)).size;
  }
  return total;
}

const actual = {
  first_load_wire_bytes: trace.first_frame_bytes,
  settled_wire_bytes: trace.settled_bytes,
  on_demand_asset_bytes: await folderBytes(join(dir, 'assets', 'assets')),
  deployment_bytes: await folderBytes(dir),
};
let failed = false;
for (const [key, rule] of Object.entries(budgets)) {
  const value = actual[key];
  const over = value > rule.max;
  failed ||= over;
  const slack = ((rule.max - value) / rule.max * 100).toFixed(1);
  console.log(`${over ? 'FAIL' : 'ok  '} ${key}: ${value} / ${rule.max} (${slack}% headroom)`);
  if (over) console.log(`     measures: ${rule.measures}\n     raise: ${rule.raise}`);
  else if (value < rule.max * 0.95) console.log('     note: 5% or more below the ceiling -- lower it in tool/web/size_budget.json');
}
process.exit(failed ? 1 : 0);
