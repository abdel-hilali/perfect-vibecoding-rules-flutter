#!/usr/bin/env node
// Installs the kit's project files into a Flutter app, for any AI coding tool.
//
// It copies templates/ into the app (AGENTS.md, CLAUDE.md, docs/, tool/kit/, scripts/tools/, analysis_options.yaml,
// .claude/skills/design-direction/) and the skills as plain playbooks into docs/playbooks/, so a tool without the
// Claude Code plugin can read them. A project that uses the plugin gets the skills from it: pass --no-playbooks.
// It also writes runs/.gitignore and a .gitattributes (the shell tools keep LF line endings in a Windows clone)
// when they are missing, and adds the lines .gitignore lacks (work files, saved chats, secrets, signing keys).
//
// It never overwrites anything that exists, file or link: it lists what it skipped, so a second run is safe.
// One exception, only with --with-boilerplate in a fresh app: the flutter create demo files that the boilerplate
// replaces (lib/main.dart, test/widget_test.dart, the two styles.xml) are moved into runs/kit-install/ first,
// and only when they still hold the demo's own text.
// It fills {{PROJECT_NAME}} (the name in pubspec.yaml) and {{TODAY}} (today's local date) in the copied
// templates, and leaves {{PURPOSE}} for the owner. It writes .sh, .env, .py and .mjs files with LF line endings,
// whatever the kit's checkout holds. Playbooks are copied byte for byte.
//
// Other parts of the kit may still be missing while it is built: a missing template is named, never an error.
// Node 18 or newer, no dependencies, and no shell commands, so it runs the same on macOS, Linux and Windows.

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const KIT = path.dirname(fileURLToPath(import.meta.url));
const TEMPLATES = path.join(KIT, "templates");
const SKILLS = path.join(KIT, "skills");
const BOILERPLATE = path.join(TEMPLATES, "boilerplate");
const USAGE = "usage: node install.mjs <app-dir> [--no-playbooks] [--with-boilerplate] [--dry-run]";
const HELP = `${USAGE}

  <app-dir>           the Flutter app's root folder (the one with pubspec.yaml); it must exist
  --no-playbooks      skip docs/playbooks/: the Claude Code plugin already provides the skills
  --with-boilerplate  also copy the kit's starter code (lib/, test/, l10n.yaml, assets/.env.example, the Android
                      styles): only into a fresh app, whose lib/ holds nothing but flutter create's main.dart
  --dry-run           print what would be created, write nothing

Never overwrites a file. Exit 0 when done, 1 when a file could not be written, 2 on wrong arguments or a folder
that is not a Flutter app.`;

// Caches that may sit in the kit checkout but are never part of the kit.
const SKIP_NAMES = new Set([".DS_Store", "Thumbs.db", "__pycache__", "node_modules", ".git", ".dart_tool"]);
const TEXT_EXTENSIONS = new Set([".md", ".mjs", ".js", ".py", ".sh", ".env", ".json", ".txt", ".yaml", ".yml"]);
// bash, env files and shebang lines break on CRLF, which a Windows clone of the kit may hold.
const LF_ONLY = new Set([".sh", ".env", ".py", ".mjs"]);
const RUNS_GITIGNORE =
  "# Working files of the AI-assisted work: briefs, reports, logs, backups. Kept out of git.\n*\n";
// A Windows clone checks text files out with CRLF by default, and bash rejects them.
const GITATTRIBUTES_LINES = ["*.sh text eol=lf", "*.py text eol=lf", "*.mjs text eol=lf", "*.dart text eol=lf",
  "scripts/tools/tools.env text eol=lf"];
const GITATTRIBUTES =
  "# Keep the shell tools runnable from a Windows clone (bash rejects CRLF), and Dart files diff-stable.\n" +
  `${GITATTRIBUTES_LINES.join("\n")}\n`;
// Work files, saved chats, the app's env file, signing keys and debug symbols never go into git.
const GITIGNORE_LINES = ["runs/", "claude-chats/", "assets/.env", "!assets/.env.example", "android/key.properties",
  "*.jks", "*.keystore", "build/symbols/"];
const GITIGNORE_HEADER =
  "# Added by perfect-vibecoding-rules-flutter: work files, saved chats (they can hold secrets), the app's env\n" +
  "# file, signing keys and debug symbols stay out of git.";
// The kit's parts, named when this checkout lacks one (the kit may be half built, or trimmed by hand).
const EXPECTED = ["AGENTS.md", "CLAUDE.md", "docs/RULES.md", "docs/HANDOFF.md", "docs/PROGRESS.md", "docs/LOG.md",
  "docs/DECISIONS.md", "docs/BACKEND-ASKS.md", "docs/BUILDER-RULES.md", "docs/CHANGELOG.md", "tool/kit/",
  "scripts/tools/", "analysis_options.yaml", ".claude/skills/design-direction/SKILL.md"];
// flutter create files the boilerplate replaces, and the text that shows the file is still the demo's own.
const DEMO_FILES = {
  "lib/main.dart": /class MyHomePage extends StatefulWidget[\s\S]*_incrementCounter/,
  "test/widget_test.dart": /Counter increments smoke test/,
  "android/app/src/main/res/values/styles.xml": /Flutter's Android embedding/,
  "android/app/src/main/res/values-night/styles.xml": /Flutter's Android embedding/,
};
// The boilerplate's package name, renamed to the app's in its Dart imports.
const BOILERPLATE_PACKAGE = "kit_app";

function fail(message) {
  process.stderr.write(`${message}\n${USAGE}\n`);
  process.exit(2);
}

function parseArgs(argv) {
  const opts = { dir: null, playbooks: true, boilerplate: false, dryRun: false };
  for (const arg of argv) {
    if (arg === "-h" || arg === "--help") {
      process.stdout.write(`${HELP}\n`);
      process.exit(0);
    } else if (arg === "--no-playbooks") {
      opts.playbooks = false;
    } else if (arg === "--with-boilerplate") {
      opts.boilerplate = true;
    } else if (arg === "--dry-run") {
      opts.dryRun = true;
    } else if (arg.startsWith("-")) {
      fail(`unknown option: ${arg}`);
    } else if (opts.dir === null) {
      opts.dir = arg;
    } else {
      fail(`one app folder only, got a second one: ${arg}`);
    }
  }
  if (opts.dir === null) fail("missing the app folder");
  return opts;
}

function isDir(p) {
  try {
    return fs.statSync(p).isDirectory();
  } catch {
    return false;
  }
}

// lstat, not stat: a link counts as "exists" even when it points nowhere, and is never followed.
function exists(p) {
  try {
    fs.lstatSync(p);
    return true;
  } catch {
    return false;
  }
}

function readText(p) {
  try {
    return fs.readFileSync(p, "utf8");
  } catch {
    return "";
  }
}

function today() {
  const now = new Date();
  const pad = (n) => String(n).padStart(2, "0");
  return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
}

function stamp() {
  return new Date().toISOString().replace(/[-:]/g, "").replace("T", "-").slice(0, 15);
}

// Every regular file under root, as paths relative to it, sorted so the output reads the same each run.
function listFiles(root, rel = "") {
  if (!isDir(path.join(root, rel))) return [];
  const out = [];
  const entries = fs.readdirSync(path.join(root, rel), { withFileTypes: true });
  entries.sort((a, b) => a.name.localeCompare(b.name));
  for (const entry of entries) {
    if (SKIP_NAMES.has(entry.name) || entry.name.endsWith(".pyc")) continue;
    const child = path.join(rel, entry.name);
    if (entry.isDirectory()) out.push(...listFiles(root, child));
    else if (entry.isFile()) out.push(child);
  }
  return out;
}

const slash = (rel) => rel.split(path.sep).join("/");

// The name in pubspec.yaml: the Dart package name the app's own imports use.
function pubspecName(target) {
  const m = /^name:\s*["']?([A-Za-z0-9_]+)/m.exec(readText(path.join(target, "pubspec.yaml")));
  return m ? m[1] : null;
}

// A fresh app: lib/ holds nothing but main.dart, as flutter create leaves it.
function libExtras(target) {
  return listFiles(path.join(target, "lib")).map(slash).filter((rel) => rel !== "main.dart");
}

// Where a boilerplate file lands in the app, or null when it stays in the kit (its README, the pubspec fragment,
// the lean gradle.properties: those are merged or offered by hand).
function boilerplateDest(rel) {
  const r = slash(rel);
  if (r === "android/gradle.properties" || r === "pubspec.fragment.yaml" || r === "README.md") return null;
  if (r.startsWith("android/res/")) return `android/app/src/main/${r.slice("android/".length)}`;
  if (/^(lib|test|assets|android)\//.test(r) || r === "l10n.yaml") return r;
  return null;
}

function textItem(item, text) {
  let data = text;
  if (LF_ONLY.has(path.extname(item.rel)) || path.basename(item.rel) === "tools.env") {
    data = data.replace(/\r\n/g, "\n");
  }
  item.data = data;
  return item;
}

function buildPlan(target, opts, name) {
  const values = { "{{PROJECT_NAME}}": name, "{{TODAY}}": today() };
  const fill = (text) => Object.entries(values).reduce((acc, [token, value]) => acc.split(token).join(value), text);
  const plan = [];
  const warnings = [];
  const notes = [];
  const kitFiles = listFiles(TEMPLATES).map(slash);

  for (const want of EXPECTED) {
    const there = want.endsWith("/") ? kitFiles.some((f) => f.startsWith(want)) : kitFiles.includes(want);
    if (!there) warnings.push(`this kit has no templates/${want} yet: it was not copied`);
  }

  for (const rel of kitFiles) {
    if (rel.startsWith("boilerplate/")) continue;
    const src = path.join(TEMPLATES, rel);
    const item = { rel, src, dest: path.join(target, rel), mode: fs.statSync(src).mode & 0o777 };
    // The kit's own file (from an earlier run, or put there on the note's advice) is only skipped: no merge note.
    const lf = (text) => text.replace(/\r\n/g, "\n");
    if (rel === "analysis_options.yaml" && exists(item.dest) && lf(readText(item.dest)) !== lf(readText(src))) {
      notes.push(analysisNote(item.dest, src));
      continue;
    }
    if (TEXT_EXTENSIONS.has(path.extname(rel)) || rel.endsWith(".gitignore")) {
      textItem(item, fill(fs.readFileSync(src, "utf8")));
    }
    plan.push(item);
  }

  if (opts.playbooks) {
    for (const rel of listFiles(SKILLS)) {
      const src = path.join(SKILLS, rel);
      plan.push({ rel: path.join("docs", "playbooks", rel), src, dest: path.join(target, "docs", "playbooks", rel),
        mode: fs.statSync(src).mode & 0o777 });
    }
  }

  // runs/ holds logs and backups. It must stay out of git, and the ownership sweep reads git status. A folder
  // that ignores itself needs no edit of the project's .gitignore.
  const runs = path.join(target, "runs");
  const runsIgnore = path.join(runs, ".gitignore");
  if (!exists(runs) || (isDir(runs) && fs.readdirSync(runs).length === 0)) {
    plan.unshift({ rel: path.join("runs", ".gitignore"), dest: runsIgnore, mode: 0o644, data: RUNS_GITIGNORE });
  } else if (!exists(runsIgnore)) {
    warnings.push("runs/ already holds files and no .gitignore: the .gitignore line runs/ keeps it out of git");
  }

  const gitattributes = path.join(target, ".gitattributes");
  if (!exists(gitattributes)) {
    plan.push({ rel: ".gitattributes", dest: gitattributes, mode: 0o644, data: GITATTRIBUTES });
  } else {
    const lines = readText(gitattributes).split(/\r?\n/);
    const missing = GITATTRIBUTES_LINES.filter((line) => !keepsLf(lines, line));
    if (missing.length) {
      warnings.push([".gitattributes was already there and lacks these lines (bash rejects the CRLF line endings " +
        "of a Windows clone). Add them by hand:", ...missing.map((line) => `      ${line}`)].join("\n"));
    }
  }

  if (opts.boilerplate) planBoilerplate(target, name, plan, notes);
  return { plan, warnings, notes };
}

function planBoilerplate(target, name, plan, notes) {
  const backups = path.join("runs", "kit-install", stamp());
  for (const rel of listFiles(BOILERPLATE).map(slash)) {
    const src = path.join(BOILERPLATE, rel);
    const to = boilerplateDest(rel);
    if (to === null) continue;
    const item = { rel: to, src, dest: path.join(target, to), mode: fs.statSync(src).mode & 0o777 };
    if (to.endsWith(".dart")) {
      // The boilerplate is the package kit_app: its imports take the app's own package name.
      textItem(item, fs.readFileSync(src, "utf8").split(`package:${BOILERPLATE_PACKAGE}/`).join(`package:${name}/`));
    }
    const demo = DEMO_FILES[to];
    if (demo && exists(item.dest)) {
      if (demo.test(readText(item.dest))) item.replace = path.join(target, backups, to);
      else notes.push(`${to} is not the flutter create demo any more: it was kept. Merge ${src} by hand.`);
    }
    plan.push(item);
  }
  // The demo's widget test drives the demo's counter: once lib/main.dart is the boilerplate's, it cannot compile.
  const demoTest = "test/widget_test.dart";
  const dest = path.join(target, demoTest);
  if (!plan.some((item) => slash(item.rel) === demoTest) && exists(dest) && DEMO_FILES[demoTest].test(readText(dest))) {
    plan.push({ rel: demoTest, dest, mode: 0o644, moveOnly: true, replace: path.join(target, backups, demoTest) });
  }
  const lean = path.join(BOILERPLATE, "android", "gradle.properties");
  if (exists(lean)) {
    notes.push(`android/gradle.properties: flutter create asks for an 8 GB Gradle heap, which can freeze a 16 GB ` +
      `machine. Offer the owner the kit's lean settings (${lean}) and change it only with their yes.`);
  }
}

// analysis_options.yaml exists: never overwritten. Say how to bring the kit's rules in.
function analysisNote(dest, src) {
  const text = readText(dest);
  const fromCreate = /include:\s*package:flutter_lints\/flutter\.yaml/.test(text) &&
    // Flutter 3.50's create also writes an analyzer: exclude: block of build/** and the platform folders.
    text.split(/\r?\n/).every((line) =>
      /^\s*(#.*)?$|include:|^\s*(linter|rules|analyzer|exclude):\s*$/.test(line) ||
      /^\s*-\s*["']?(build|android|ios|linux|macos|web|windows)\/\*\*["']?\s*(#.*)?$/.test(line));
  return fromCreate
    ? `analysis_options.yaml is the flutter create default: the kit's file includes the same lints and adds the ` +
      `kit's rules. Replace it with ${src} (nothing of yours is in it), with the owner's yes.`
    : `analysis_options.yaml was already there: merge the kit's analyzer and linter sections from ${src} into it ` +
      `by hand, and keep the project's own rules.`;
}

// The same pattern with eol=lf, or a "*" line with eol=lf, keeps those files LF.
function keepsLf(lines, wanted) {
  const pattern = wanted.split(/\s+/)[0];
  return lines.some((line) => {
    const [first, ...attributes] = line.trim().split(/\s+/);
    return (first === pattern || first === "*") && attributes.includes("eol=lf");
  });
}

// "runs", "runs/", "/runs" and "/runs/" ignore the same folder; build/ covers build/symbols/; a bare file name
// ignores the file at any depth.
function ignores(lines, wanted) {
  const norm = (line) => line.trim().replace(/^\//, "").replace(/\/$/, "").replace(/^\*\*\//, "");
  const set = new Set(lines.map(norm).filter(Boolean));
  const w = norm(wanted);
  if (set.has(w)) return true;
  if (w === "build/symbols" && set.has("build")) return true;
  if (!w.startsWith("!") && w.includes("/") && set.has(w.slice(w.lastIndexOf("/") + 1))) return true;
  return false;
}

function gitignorePlan(target) {
  const file = path.join(target, ".gitignore");
  const text = readText(file);
  const missing = GITIGNORE_LINES.filter((line) => !ignores(text.split(/\r?\n/), line));
  return { file, text, missing };
}

function writeGitignore({ file, text, missing }) {
  const lead = text === "" || text.endsWith("\n") ? "" : "\n";
  const gap = text === "" ? "" : "\n";
  fs.appendFileSync(file, `${lead}${gap}${GITIGNORE_HEADER}\n${missing.join("\n")}\n`);
}

function writeItem(item) {
  fs.mkdirSync(path.dirname(item.dest), { recursive: true });
  if (item.replace) {
    // The flutter create demo goes to runs/kit-install/ first: moved, never deleted.
    fs.mkdirSync(path.dirname(item.replace), { recursive: true });
    fs.copyFileSync(item.dest, item.replace, fs.constants.COPYFILE_EXCL);
    fs.unlinkSync(item.dest);
    if (item.moveOnly) return;
  }
  // "wx" fails when anything exists at the path, even a dangling link: the last guard against an overwrite.
  if (item.data !== undefined) fs.writeFileSync(item.dest, item.data, { flag: "wx", mode: item.mode });
  else fs.copyFileSync(item.src, item.dest, fs.constants.COPYFILE_EXCL);
  try {
    fs.chmodSync(item.dest, item.mode); // keeps the tools executable whatever the umask
  } catch {
    // Windows has no execute bit: nothing to keep.
  }
}

function nextSteps(opts, purposeFiles, analysisToDo) {
  const setup = opts.playbooks
    ? "docs/playbooks/new-project/SKILL.md (in Claude Code: /perfect-vibecoding-rules-flutter:new-project)"
    : "/perfect-vibecoding-rules-flutter:new-project in Claude Code";
  const steps = [];
  if (purposeFiles.length) {
    steps.push(`Write the app's purpose, one line, where {{PURPOSE}} stands: ${purposeFiles.join(", ")}.`);
  }
  if (analysisToDo) steps.push("Bring the kit's analyzer rules into analysis_options.yaml (see the note above).");
  if (opts.boilerplate) {
    steps.push("Merge the pubspec fragment below into pubspec.yaml, copy assets/.env.example to assets/.env, then " +
      "run flutter pub get, flutter gen-l10n, dart fix --apply --code=directives_ordering and dart format lib test " +
      "(the imports now name the app's package, which sorts in another place than kit_app). On iOS, list en, fr " +
      "and ar under CFBundleLocalizations in ios/Runner/Info.plist.");
  }
  steps.push("Check it works: dart run tool/kit/check_structure.dart, dart run tool/kit/check_l10n.dart and " +
    "scripts/tools/q-analyze.sh.");
  steps.push(`The rest of the setup (the purpose line, the analyzer merge, the Gradle heap): ${setup}.`);
  steps.push("Review the new files with `git status`, then commit them.");
  return steps.map((step, n) => `  ${n + 1}. ${step}`).join("\n");
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const target = path.resolve(opts.dir);
  if (!isDir(target)) fail(`not a folder: ${opts.dir} (create the app first: flutter create <name>)`);
  const fromKit = path.relative(KIT, target);
  if (fromKit === "" || (!fromKit.startsWith("..") && !path.isAbsolute(fromKit))) {
    fail(`refused: ${target} is the kit itself, or inside it. Give the app's folder.`);
  }
  if (!exists(path.join(target, "pubspec.yaml"))) {
    fail(`refused: ${target} has no pubspec.yaml, so it is not a Flutter app's root. Create the app first ` +
      "(flutter create --org com.example <name>), then run the installer on its folder.");
  }
  const name = pubspecName(target) || path.basename(target);
  if (opts.boilerplate) {
    if (listFiles(BOILERPLATE).length === 0) {
      fail("refused: this kit has no templates/boilerplate/ yet: install without --with-boilerplate.");
    }
    const extras = libExtras(target);
    if (extras.length) {
      fail("refused: --with-boilerplate is only for a fresh app (lib/ holding nothing but flutter create's " +
        `main.dart). lib/ also holds: ${extras.slice(0, 5).join(", ")}${extras.length > 5 ? ", ..." : ""}. ` +
        "Install without it; the recipes playbook shows each part.");
    }
  }

  const { plan, warnings, notes } = buildPlan(target, opts, name);
  const gitignore = gitignorePlan(target);
  const verb = opts.dryRun ? "would create" : "created";
  console.log(`perfect-vibecoding-rules-flutter: ${opts.dryRun ? "dry run for" : "installing into"} ${target}`);
  const yes = (on) => (on ? "yes" : "no");
  console.log(`  project name: ${name}, playbooks: ${yes(opts.playbooks)}, boilerplate: ${yes(opts.boilerplate)}`);
  for (const warning of warnings) console.log(`  warning: ${warning}`);

  const counts = { created: 0, skipped: 0, replaced: 0, failed: 0 };
  const skipped = new Set();
  const purposeFiles = [];
  for (const item of plan) {
    const shown = slash(item.rel);
    if (exists(item.dest) && !item.replace) {
      counts.skipped += 1;
      skipped.add(shown);
      console.log(`  skipped  ${shown} (already exists, left as it is)`);
      continue;
    }
    const kept = item.replace
      ? ` (the flutter create demo moves to ${slash(path.relative(target, item.replace))})`
      : "";
    const done = item.moveOnly ? "moved" : item.replace ? "replaced" : verb;
    if (opts.dryRun) {
      counts[item.replace ? "replaced" : "created"] += 1;
      console.log(`  ${item.moveOnly ? "would move" : item.replace ? "would replace" : verb}  ${shown}${kept}`);
      if (item.data && item.data.includes("{{PURPOSE}}")) purposeFiles.push(shown);
      continue;
    }
    try {
      writeItem(item);
      counts[item.replace ? "replaced" : "created"] += 1;
      console.log(`  ${done}  ${shown}${kept}`);
      if (item.data && item.data.includes("{{PURPOSE}}")) purposeFiles.push(shown);
    } catch (error) {
      // EEXIST for the file itself: it appeared since the check. EEXIST for a folder on the way (a file named
      // like the folder) is a real failure.
      if (error && error.code === "EEXIST" && exists(item.dest) && !item.replace) {
        counts.skipped += 1;
        skipped.add(shown);
        console.log(`  skipped  ${shown} (already exists, left as it is)`);
      } else {
        counts.failed += 1;
        const code = error && error.code ? error.code : String(error);
        const why = code === "EEXIST" || code === "ENOTDIR" ? `a file stands where a folder must go (${code})` : code;
        console.log(`  FAILED   ${shown}: ${why}`);
      }
    }
  }

  if (gitignore.missing.length) {
    const how = opts.dryRun ? "would add to" : "added to";
    try {
      if (!opts.dryRun) writeGitignore(gitignore);
      console.log(`  ${how} .gitignore: ${gitignore.missing.join(" ")}`);
    } catch (error) {
      counts.failed += 1;
      console.log(`  FAILED   .gitignore: ${error && error.code ? error.code : String(error)}`);
    }
  }

  const replaced = counts.replaced
    ? `, ${counts.replaced} flutter create demo file(s) replaced (moved to runs/kit-install/)`
    : "";
  console.log(`\n${counts.created} ${verb}, ${counts.skipped} skipped (they already existed; nothing was overwritten)` +
    `${replaced}, ${counts.failed} failed.`);
  for (const note of [...notes, ...mergeNotes(target, skipped)]) console.log(`  note: ${note}`);
  if (counts.created + counts.replaced > 0) {
    const analysisToDo = notes.some((n) => n.startsWith("analysis_options.yaml"));
    const after = opts.dryRun ? " (after a real run)" : "";
    console.log(`\nNext steps${after}:\n${nextSteps(opts, purposeFiles, analysisToDo)}`);
  }
  if (opts.boilerplate) printFragment();
  process.exitCode = counts.failed > 0 ? 1 : 0;
}

// The boilerplate's dependencies and flutter: entries, to merge into pubspec.yaml by hand: a merge by script
// would lose the app's own comments and order.
function printFragment() {
  const file = path.join(BOILERPLATE, "pubspec.fragment.yaml");
  const text = readText(file);
  if (!text) {
    console.log("\nThe kit has no templates/boilerplate/pubspec.fragment.yaml: add the boilerplate's packages " +
      "by hand.");
    return;
  }
  console.log(`\nMerge into pubspec.yaml by hand (keep the app's own lines), then run flutter pub get (${file}):\n`);
  console.log(text.replace(/\s+$/, "").split(/\r?\n/).map((line) => `    ${line}`).join("\n"));
}

// The two files every tool reads first. A project's own copy is kept, so say what it still lacks.
function mergeNotes(target, skipped) {
  const notes = [];
  // The kit's AGENTS.md ends with the playbooks table: a file without it never got the kit's rules.
  const agents = readText(path.join(target, "AGENTS.md"));
  if (skipped.has("AGENTS.md") && !agents.includes("docs/playbooks/code-rules/SKILL.md")) {
    notes.push("AGENTS.md was already there: merge the kit's rules into it by hand " +
      `(${path.join(TEMPLATES, "AGENTS.md")}).`);
  }
  // With a CLAUDE.md present, Claude Code reads it instead of AGENTS.md, unless CLAUDE.md imports AGENTS.md.
  if (skipped.has("CLAUDE.md") && !/^@AGENTS\.md\s*$/m.test(readText(path.join(target, "CLAUDE.md")))) {
    notes.push("CLAUDE.md was already there and does not import AGENTS.md: add the line @AGENTS.md at its top.");
  }
  return notes;
}

main();
