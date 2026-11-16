#!/usr/bin/env node
// Checks the recipes skill against the starter it quotes: every code block that names a starter file matches that
// file, and every recipe keeps its size.
//
// A code block whose first line is a comment naming a path (`// lib/x.dart`, `# l10n.yaml`, `<!-- android/x.xml -->`)
// is an excerpt. Its lines, cut at `...` comment lines, must appear in that file of the starter in the same order,
// each run of lines together. `pubspec.yaml` means the starter's pubspec.fragment.yaml. A header that says
// "(not in the starter" names code proven outside the starter: it is counted and listed, never failed. A block
// without such a header is counted as without a source. Every recipe but SKILL.md is 2 to 5 KB.
//
// usage: node tests/recipes/check.mjs [<recipes dir> <starter dir>]   (default: this kit's own)
// Exits 0 when every check passes, 1 on a problem, 2 on a usage error. No packages: node alone.

import { readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const USAGE = "usage: node tests/recipes/check.mjs [<recipes dir> <starter dir>]";
const HEADER = /^\s*(?:\/\/|#|<!--)\s*([A-Za-z0-9_./-]+\.(?:dart|yaml|arb|xml|properties|example))(?:\s|$)/;
const ELISION = /^\s*(?:\/\/|#|<!--)\s*\.\.\.\s*(?:-->)?\s*$/;
const FENCE = /^```/;
const NOT_IN_STARTER = /\(not in the starter\b/i;
const ALIASES = { "pubspec.yaml": "pubspec.fragment.yaml" };
const MIN_BYTES = 2048;
const MAX_BYTES = 5120;

const isFile = (path) => statSync(path, { throwIfNoEntry: false })?.isFile() ?? false;
const isDir = (path) => statSync(path, { throwIfNoEntry: false })?.isDirectory() ?? false;
const plural = (n, word) => `${n} ${word}${n === 1 ? "" : "s"}`;

// Each fenced block, with the line number of its first line (the header, when it has one).
function blocks(text) {
  const found = [];
  let open = null;
  text.split("\n").forEach((line, i) => {
    if (FENCE.test(line)) {
      if (open) {
        found.push(open);
        open = null;
      } else {
        open = { line: i + 2, lines: [] };
      }
    } else if (open) {
      open.lines.push(line.trimEnd());
    }
  });
  return { found, unclosed: open !== null };
}

function inStarter(starter, path) {
  for (const name of [path, ALIASES[path]]) {
    if (name && isFile(join(starter, name))) return join(starter, name);
  }
  return null;
}

function findChunk(lines, chunk, from) {
  for (let i = from; i + chunk.length <= lines.length; i++) {
    if (chunk.every((line, k) => lines[i + k] === line)) return i;
  }
  return -1;
}

function checkBlock(block, starter) {
  const header = HEADER.exec(block.lines[0] ?? "");
  if (!header) return { kind: "unchecked" };
  const path = header[1];
  if (NOT_IN_STARTER.test(block.lines[0])) {
    return { kind: "marked", path, stale: inStarter(starter, path) !== null };
  }
  const target = inStarter(starter, path);
  if (!target) return { kind: "checked", errors: [`${path}: no such file in the starter`] };
  const fileLines = readFileSync(target, "utf8").split("\n").map((line) => line.trimEnd());
  const chunks = [[]];
  for (const line of block.lines.slice(1)) {
    if (ELISION.test(line)) chunks.push([]);
    else chunks.at(-1).push(line);
  }
  const errors = [];
  let position = 0;
  for (const chunk of chunks) {
    while (chunk.length > 0 && chunk.at(-1) === "") chunk.pop();
    if (chunk.length === 0) continue;
    const at = findChunk(fileLines, chunk, position);
    if (at < 0) {
      errors.push(`${path}: lines not found in order, from: ${chunk[0].trim().slice(0, 70)}`);
      continue;
    }
    position = at + chunk.length;
  }
  return { kind: "checked", errors };
}

const args = process.argv.slice(2);
if (args.includes("-h") || args.includes("--help")) {
  console.log(USAGE);
  process.exit(0);
}
if (args.length !== 0 && args.length !== 2) {
  console.error(USAGE);
  process.exit(2);
}
const kit = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const [recipes, starter] =
  args.length === 2
    ? args.map((arg) => resolve(arg))
    : [join(kit, "skills/recipes"), join(kit, "templates/boilerplate")];
for (const dir of [recipes, starter]) {
  if (!isDir(dir)) {
    console.error(`recipes: no such folder: ${dir}`);
    process.exit(2);
  }
}

const problems = [];
const marked = [];
let checked = 0;
let unchecked = 0;
for (const name of readdirSync(recipes).filter((file) => file.endsWith(".md")).sort()) {
  const text = readFileSync(join(recipes, name), "utf8");
  const size = Buffer.byteLength(text, "utf8");
  if (name !== "SKILL.md" && (size < MIN_BYTES || size > MAX_BYTES)) {
    problems.push(`${name}: ${size} bytes (2 to 5 KB)`);
  }
  const { found, unclosed } = blocks(text);
  // An open fence turns the rest of the page into code, and hides its blocks from this check.
  if (unclosed) problems.push(`${name}: a code block is not closed`);
  for (const block of found) {
    const result = checkBlock(block, starter);
    if (result.kind === "unchecked") {
      unchecked++;
    } else if (result.kind === "marked") {
      const note = result.stale ? " (the starter has this file now: quote it)" : "";
      marked.push(`${name}:${block.line} ${result.path}${note}`);
    } else {
      checked++;
      problems.push(...result.errors.map((error) => `${name}:${block.line}: ${error}`));
    }
  }
}
for (const line of marked) console.log(`not in the starter: ${line}`);
for (const problem of problems) console.log(`FAIL ${problem}`);
console.log(
  `recipes: ${plural(checked, "excerpt")} checked against the starter, ${marked.length} not in the starter, ` +
    `${plural(unchecked, "block")} without a source, ${plural(problems.length, "problem")}`,
);
process.exit(problems.length > 0 ? 1 : 0);
