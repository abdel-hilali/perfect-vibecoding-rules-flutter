// The static checks of the kit that need no shell: JSON files, the skill format, the hooks, the plugin manifest,
// full-match kills in scripts, and the scan for anything that looks real (hosts, e-mail addresses, IP addresses,
// absolute home folders). It scans by patterns only: it never holds a real name itself.
//
// A problem in a file of the plumbing package (this test's own package) fails. A problem in a file another
// package writes is a warning, so a half-built kit does not fail this area; --strict makes every problem fail.
// usage: node check.mjs <kit root> [--strict]
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { basename, dirname, join, relative, sep } from "node:path";

const args = process.argv.slice(2);
const strict = args.includes("--strict") || process.env.KIT_STRICT === "1";
const root = args.find((a) => !a.startsWith("--"));
if (!root || args.some((a) => a.startsWith("--") && a !== "--strict")) {
  console.error("usage: node check.mjs <kit root> [--strict]");
  process.exit(2);
}

const KIT_NAME = "perfect-vibecoding-rules-flutter";
// Written with escaped slashes, so this file holds no URL of its own for the scan to find.
const OWN_REPO = new RegExp(`^https:\\/\\/github\\.com\\/abdel-hilali\\/${KIT_NAME}(\\.git)?\\/?$`);
// The plumbing package's files. Everything else belongs to another package (or to the lead).
const OWN = [/^\.claude-plugin\//, /^hooks\/(?!token-guard\.mjs$)/, /^install\.mjs$/, /^README\.md$/, /^LICENSE$/,
  /^templates\/scripts\/tools\//, /^templates\/CLAUDE\.md$/, /^skills\/(tools|new-project)\//,
  /^tests\/(install|guard-bash|save-chat|tools|static|token-guard)\//, /^tests\/run-all\.sh$/];
// The ten skills the playbooks table of AGENTS.md names.
const SKILLS = ["code-rules", "recipes", "screen", "gate", "device", "tools", "multi-agent", "session-rules",
  "working-rules", "new-project"];
const ALLOWED_KEYS = new Set(["name", "description", "when_to_use", "argument-hint", "disable-model-invocation",
  "allowed-tools"]);
// Hosts that never point at a real project: the example domain, the local machine, and the XML namespaces that
// Android and SVG files must carry.
const HOSTS = [/^(.+\.)?example\.com$/, /^localhost$/, /^127\.0\.0\.1$/, /^app\.invalid$/, /^schemas\.android\.com$/,
  /^www\.w3\.org$/];
// Placeholder user names in an example home folder.
const HOME_PLACEHOLDERS = new Set(["user", "you", "me", "example", "name", "<user>", "<you>", "<name>", "$user",
  "${user}", "username"]);

const problems = [];
const warnings = [];
const notes = [];
let checks = 0;

const walk = (dir, out = []) => {
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    if ([".git", "node_modules", ".dart_tool", "__pycache__"].includes(entry.name)) continue;
    const full = join(dir, entry.name);
    if (entry.isDirectory()) walk(full, out);
    else if (entry.isFile()) out.push(full);
  }
  return out;
};
const files = walk(root);
const rel = (p) => relative(root, p).split(sep).join("/");
const own = (r) => OWN.some((re) => re.test(r));
// report <kit path> <message>: a problem in the plumbing files (or with --strict), else a warning.
const report = (r, message) => (strict || own(r) ? problems : warnings).push(`${r}: ${message}`);
// Test fixtures are broken on purpose.
const fixture = (p) => /^tests\/[^/]+\/fixtures\//.test(rel(p));

// Every JSON file parses, and so does every ARB catalog (gen-l10n reads them as JSON).
for (const file of files.filter((p) => /\.(json|arb)$/.test(p) && !fixture(p))) {
  checks += 1;
  try {
    JSON.parse(readFileSync(file, "utf8"));
  } catch (error) {
    report(rel(file), `invalid JSON: ${error.message}`);
  }
}

// The ten skills exist, and every SKILL.md follows the skill format.
for (const skill of SKILLS) {
  checks += 1;
  const r = `skills/${skill}/SKILL.md`;
  if (!existsSync(join(root, r))) report(r, "is missing");
}
for (const file of files.filter((p) => basename(p) === "SKILL.md" && !fixture(p))) {
  checks += 1;
  const r = rel(file);
  const lines = readFileSync(file, "utf8").split("\n");
  const end = lines.indexOf("---", 1);
  if (lines[0] !== "---" || end < 0) {
    report(r, "the frontmatter must open with --- on line 1 and close with ---");
    continue;
  }
  const fm = {};
  for (const line of lines.slice(1, end)) {
    if (!line.trim()) continue;
    const m = /^([A-Za-z_-]+):\s*(.*)$/.exec(line);
    if (!m) {
      report(r, `not a "key: value" line: ${line}`);
      continue;
    }
    let value = m[2].trim();
    if (/^[>|]/.test(value)) report(r, `${m[1]}: write the value on one line`);
    if (/^(".*"|'.*')$/.test(value)) value = value.slice(1, -1);
    fm[m[1]] = value;
  }
  for (const key of Object.keys(fm)) if (!ALLOWED_KEYS.has(key)) report(r, `frontmatter key not allowed: ${key}`);
  const folder = basename(dirname(file));
  if (fm.name !== folder) report(r, `name "${fm.name}" differs from its folder "${folder}"`);
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(fm.name ?? "")) report(r, "name must be lowercase kebab-case");
  const description = fm.description ?? "";
  if (!description.includes("Use when")) report(r, 'the description needs a "Use when ..." part');
  if (description.length > 600) report(r, `the description has ${description.length} characters (600 at most)`);
  if ((description + (fm.when_to_use ?? "")).length > 1536) report(r, "description + when_to_use over 1,536 characters");
  const body = lines.slice(end + 1).join("\n").trim().split("\n").length;
  if (body > 150) report(r, `the body has ${body} lines: move detail into a supporting file`);
  else if (body > 120) notes.push(`${r}: the body has ${body} lines (about 120 is the target)`);
  // In a SKILL.md, "!" right before a backtick runs a shell command when Claude Code loads the skill.
  lines.forEach((line, n) => {
    if (/(^|\s)!`/.test(line) || /^\s*```!/.test(line)) report(r, `line ${n + 1}: "!" before a backtick runs a command`);
  });
}

// Every file a hook points to exists, and every hook script is wired.
const hooksFile = join(root, "hooks", "hooks.json");
let wired = new Set();
checks += 1;
if (!existsSync(hooksFile)) {
  report("hooks/hooks.json", "is missing");
} else {
  let hooks = {};
  try {
    hooks = JSON.parse(readFileSync(hooksFile, "utf8")).hooks ?? {};
  } catch {
    // Reported by the JSON check.
  }
  for (const [event, groups] of Object.entries(hooks)) {
    for (const hook of (Array.isArray(groups) ? groups : []).flatMap((group) => group.hooks ?? [])) {
      for (const part of [hook.command, ...(hook.args ?? [])]) {
        if (typeof part === "string" && part.includes("${CLAUDE_PLUGIN_ROOT}")) {
          const target = part.replace("${CLAUDE_PLUGIN_ROOT}", root);
          if (!existsSync(target)) report("hooks/hooks.json", `${event}: ${part} not found`);
          wired.add(rel(target));
        }
      }
    }
  }
  for (const file of files.filter((p) => /^hooks\/[^/]+\.mjs$/.test(rel(p)))) {
    checks += 1;
    if (!wired.has(rel(file))) report(rel(file), "no entry in hooks/hooks.json runs it");
  }
}

// The manifest: the kit's name and repository, and every option is read by a hook.
const manifest = join(root, ".claude-plugin", "plugin.json");
checks += 1;
if (!existsSync(manifest)) {
  report(".claude-plugin/plugin.json", "is missing");
} else {
  let plugin = null;
  try {
    plugin = JSON.parse(readFileSync(manifest, "utf8"));
  } catch {
    // Reported by the JSON check.
  }
  if (plugin) {
    if (plugin.name !== KIT_NAME) report(".claude-plugin/plugin.json", `name is "${plugin.name}", not ${KIT_NAME}`);
    if (!OWN_REPO.test(plugin.repository ?? "")) report(".claude-plugin/plugin.json", "repository is not the kit's own");
    const hookText = files.filter((p) => /^hooks\/[^/]+\.mjs$/.test(rel(p))).map((p) => readFileSync(p, "utf8")).join("\n");
    for (const key of Object.keys(plugin.userConfig ?? {})) {
      checks += 1;
      const env = `CLAUDE_PLUGIN_OPTION_${key.toUpperCase()}`;
      if (!hookText.includes(env)) report(".claude-plugin/plugin.json", `option ${key}: no hook reads ${env}`);
    }
  }
  const market = join(root, ".claude-plugin", "marketplace.json");
  try {
    const m = JSON.parse(readFileSync(market, "utf8"));
    checks += 1;
    if (!(m.plugins ?? []).some((p) => p.name === KIT_NAME && p.source === "./")) {
      report(".claude-plugin/marketplace.json", `lists no plugin ${KIT_NAME} with source ./`);
    }
  } catch {
    report(".claude-plugin/marketplace.json", "is missing or not JSON");
  }
}

// No script runs the full-match process killers (they match their own shell). Prose and the guard may name them.
const FULL_MATCH = /\bp(?:kill|grep)\s+(?:-[A-Za-z]*f[A-Za-z]*\b|--full\b)/;
for (const file of files.filter((p) => /\.(sh|mjs|py|dart)$/.test(p) && /^(templates|install)/.test(rel(p)))) {
  checks += 1;
  readFileSync(file, "utf8").split("\n").forEach((line, n) => {
    if (!/^\s*(#|\/\/|\*)/.test(line) && FULL_MATCH.test(line)) report(rel(file), `line ${n + 1}: a full-match kill`);
  });
}

// Real names (the owner's apps, people, a company) are never written in the kit, not even in this file: they come
// at run time, as one case-insensitive regular expression in KIT_PRIVATE_PATTERN (for example "name1|\bname2\b").
let PRIVATE = null;
if (process.env.KIT_PRIVATE_PATTERN) {
  try {
    PRIVATE = new RegExp(process.env.KIT_PRIVATE_PATTERN, "i");
  } catch (error) {
    console.error(`static: KIT_PRIVATE_PATTERN is not a regular expression: ${error.message}`);
    process.exit(2);
  }
}

// Nothing from a real project or person: URLs stay on example.com (the kit's own repository is the one exception,
// that exact address), e-mail addresses on example.com, no IP address but the local ones, and no absolute home
// folder but a placeholder (/home/user, /Users/you, C:\Users\<name>).
for (const file of files) {
  if (statSync(file).size > 2_000_000) continue;
  const text = readFileSync(file, "utf8");
  if (text.includes("\u0000")) continue;
  const r = rel(file);
  checks += 1;
  if (PRIVATE) {
    // The line number only: the output never repeats the name.
    if (PRIVATE.test(r)) report(r, "its path matches KIT_PRIVATE_PATTERN");
    text.split("\n").forEach((line, n) => {
      if (PRIVATE.test(line)) report(r, `line ${n + 1} matches KIT_PRIVATE_PATTERN`);
    });
  }
  for (const m of text.matchAll(/https?:\/\/([^\s/"'`<>)\]},;]+)[^\s"'`<>)\]},;]*/g)) {
    if (OWN_REPO.test(m[0].replace(/\.+$/, ""))) continue;
    const host = m[1].replace(/:.*$/, "").toLowerCase();
    if (!HOSTS.some((re) => re.test(host))) report(r, `URL host "${host}" (use example.com)`);
  }
  for (const m of text.matchAll(/[A-Za-z0-9._%+-]+@([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,})\b/g)) {
    if (!/^(.+\.)?example\.com$/i.test(m[1])) report(r, `e-mail address at "${m[1]}" (use example.com)`);
  }
  for (const m of text.matchAll(/(?<![\d.])(?:\d{1,3}\.){3}\d{1,3}(?![\d.])/g)) {
    if (!["127.0.0.1", "0.0.0.0"].includes(m[0])) report(r, `IP address ${m[0]}`);
  }
  // Only a path that starts there: $T/home/x or ~/home/x is not a home folder.
  for (const m of text.matchAll(/(?:(?<![\w$}.~/-])\/home\/|(?<![\w$}.~/-])\/Users\/|[A-Za-z]:\\Users\\)([^\s/\\"'`),;:.]+)/g)) {
    if (!HOME_PLACEHOLDERS.has(m[1].toLowerCase())) report(r, `an absolute home folder (${m[0].slice(0, m[0].length - m[1].length)}<name>): use ~ or a placeholder`);
  }
}

// The always-loaded files stay small: every call re-sends them.
for (const [r, target] of [["templates/AGENTS.md", 9 * 1024], ["templates/CLAUDE.md", 2 * 1024]]) {
  if (!existsSync(join(root, r))) continue;
  const size = statSync(join(root, r)).size;
  notes.push(`${r}: ${size} bytes (target about ${target / 1024} KB)${size > target * 1.1 ? ": over the target" : ""}`);
}

for (const note of notes) console.log(`note: ${note}`);
for (const warning of warnings) console.log(`warn ${warning}`);
for (const problem of problems) console.log(`FAIL ${problem}`);
console.log(`static: ${checks} checks, ${problems.length} problem(s), ${warnings.length} warning(s) in other packages' files` +
  `${strict ? " (strict)" : ""}`);
process.exit(problems.length ? 1 : 0);
