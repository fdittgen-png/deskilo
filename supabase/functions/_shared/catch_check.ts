// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4412 -- a `catch` of an edge function must say what happened: call the structured
// logger (`logLine` / `fail`), rethrow, or carry `// handled: <reason>`. An empty catch, or
// one that only swallows, fails CI. The catches that predate the rule are counted per file
// in catch_baseline.json: a file may not gain one, and the count only falls (a fall asks
// for the baseline to be lowered, as the ratchets of the Dart lints do).
//
//   deno run -A supabase/functions/_shared/catch_check.ts            # check the tree
//   deno run -A supabase/functions/_shared/catch_check.ts --write    # write the baseline

/** [source] with its comments and strings blanked (same length, newlines kept): structure is read from this, never from text inside a string or a comment. */
export function mask(source: string): string {
  const out = source.split("");
  const blank = (from: number, to: number) => {
    for (let k = from; k < to && k < out.length; k++) if (out[k] !== "\n") out[k] = " ";
  };
  for (let i = 0; i < source.length; i++) {
    const c = source[i];
    if (c === "/" && source[i + 1] === "/") {
      const end = source.indexOf("\n", i);
      const stop = end < 0 ? source.length : end;
      blank(i, stop);
      i = stop;
    } else if (c === "/" && source[i + 1] === "*") {
      const end = source.indexOf("*/", i + 2);
      const stop = end < 0 ? source.length : end + 2;
      blank(i, stop);
      i = stop - 1;
    } else if (c === '"' || c === "'" || c === "`") {
      const end = skipString(source, i);
      blank(i + 1, end);
      i = end;
    }
  }
  return out.join("");
}

/** What a catch body, or a promise `.catch(...)` handler, is: the first 80 characters of it, for the message. */
const gist = (text: string) => text.replace(/\s+/g, " ").trim().slice(0, 80);

/** The `catch` blocks and `.catch(` handlers of [source] that neither log, rethrow nor say why they are handled. */
export function unaccountedCatches(source: string): string[] {
  const masked = mask(source);
  const found: string[] = [];
  const block = /\bcatch\b\s*(?:\([^)]*\))?\s*\{/g;
  let m: RegExpExecArray | null;
  while ((m = block.exec(masked)) !== null) {
    const open = m.index + m[0].length - 1;
    const close = matchingBrace(masked, open);
    if (close < 0) continue;
    if (!accounts(masked.slice(open + 1, close), source.slice(open + 1, close))) {
      found.push(gist(source.slice(open + 1, close)));
    }
    block.lastIndex = close;
  }
  const promise = /\.catch\s*\(/g;
  while ((m = promise.exec(masked)) !== null) {
    const open = m.index + m[0].length - 1;
    const close = matchingParen(masked, open);
    if (close < 0) continue;
    if (!accounts(masked.slice(open + 1, close), source.slice(open + 1, close))) {
      found.push(gist(source.slice(open + 1, close)));
    }
    promise.lastIndex = close;
  }
  return found;
}

/** Whether a body (its code, comments and strings blanked, and its raw text) logs through the shared logger, rethrows or states why it is handled. */
function accounts(code: string, raw: string): boolean {
  return /\b(logLine|fail)\s*\(/.test(code) || /\bthrow\b/.test(code) ||
    /\/\/\s*handled:\s*\S|\/\*\s*handled:\s*\S/.test(raw);
}

/** The index of the parenthesis closing the one at [open] (the source is masked). */
function matchingParen(src: string, open: number): number {
  let depth = 0;
  for (let i = open; i < src.length; i++) {
    if (src[i] === "(") depth++;
    else if (src[i] === ")") {
      depth--;
      if (depth === 0) return i;
    }
  }
  return -1;
}

/** The index of the brace closing the one at [open]; strings, template literals and comments are skipped. */
function matchingBrace(src: string, open: number): number {
  let depth = 0;
  for (let i = open; i < src.length; i++) {
    const c = src[i];
    if (c === "/" && src[i + 1] === "/") {
      const end = src.indexOf("\n", i);
      i = end < 0 ? src.length : end;
    } else if (c === "/" && src[i + 1] === "*") {
      const end = src.indexOf("*/", i + 2);
      i = end < 0 ? src.length : end + 1;
    } else if (c === '"' || c === "'" || c === "`") {
      i = skipString(src, i);
    } else if (c === "{") {
      depth++;
    } else if (c === "}") {
      depth--;
      if (depth === 0) return i;
    }
  }
  return -1;
}

function skipString(src: string, start: number): number {
  const quote = src[start];
  for (let i = start + 1; i < src.length; i++) {
    if (src[i] === "\\") i++;
    else if (src[i] === quote) return i;
  }
  return src.length;
}

/** The files the rule reads: a function's own code, not its tests or the test helpers. */
export function sourceFiles(root: string): string[] {
  const out: string[] = [];
  const walk = (dir: string) => {
    for (const entry of Deno.readDirSync(dir)) {
      const path = `${dir}/${entry.name}`;
      if (entry.isDirectory) {
        if (entry.name !== "testing" && entry.name !== "node_modules") walk(path);
      } else if (entry.name.endsWith(".ts") && !entry.name.endsWith("_test.ts")) {
        out.push(path);
      }
    }
  };
  walk(root);
  return out.sort();
}

/** What a tree owes: the per-file counts, and the messages of the rule it breaks against [baseline]. */
export function checkTree(
  root: string,
  baseline: Record<string, number>,
): { counts: Record<string, number>; problems: string[] } {
  const counts: Record<string, number> = {};
  for (const file of sourceFiles(root)) {
    const n = unaccountedCatches(Deno.readTextFileSync(file)).length;
    if (n > 0) counts[file.slice(root.length + 1)] = n;
  }
  const problems: string[] = [];
  for (const [file, n] of Object.entries(counts)) {
    const allowed = baseline[file] ?? 0;
    if (n > allowed) {
      problems.push(
        `${file}: ${n} catch block(s) neither log (logLine/fail), rethrow nor say '// handled: <reason>' (the baseline allows ${allowed})`,
      );
    }
  }
  for (const [file, allowed] of Object.entries(baseline)) {
    const n = counts[file] ?? 0;
    if (n < allowed) {
      problems.push(`${file}: it fell to ${n}: lower catch_baseline.json (it was ${allowed})`);
    }
  }
  return { counts, problems };
}

if (import.meta.main) {
  const root = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
  const baselinePath = new URL("./catch_baseline.json", import.meta.url).pathname;
  if (Deno.args.includes("--write")) {
    const { counts } = checkTree(root, {});
    Deno.writeTextFileSync(baselinePath, JSON.stringify(counts, null, 2) + "\n");
    console.log(`baseline written: ${Object.values(counts).reduce((a, b) => a + b, 0)} catch block(s) in ${Object.keys(counts).length} file(s)`);
  } else {
    const baseline = JSON.parse(Deno.readTextFileSync(baselinePath));
    const { problems } = checkTree(root, baseline);
    for (const p of problems) console.error(`::error::${p}`);
    Deno.exit(problems.length === 0 ? 0 : 1);
  }
}
