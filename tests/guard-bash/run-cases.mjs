// Pipes PreToolUse JSON into hooks/guard-bash.mjs, one process per case, and checks stdout,
// stderr and the exit code. Usage: node run-cases.mjs <empty temp dir>
import { spawnSync } from 'node:child_process';
import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const HOOK = resolve(HERE, '../../hooks/guard-bash.mjs');
const KIT_TOOLS_ENV = resolve(HERE, '../../templates/scripts/tools/tools.env');
const TMP = process.argv[2];
if (!TMP) {
  console.error('usage: node run-cases.mjs <empty temp dir>');
  process.exit(2);
}

// Fake projects: one whose tools.env allows writes to the phone (`: "${DEVICE_WRITE_OK:=1}"`), one with an
// `export DEVICE_WRITE_OK=1` line, one with the kit's own tools.env (DEVICE_WRITE_OK=0), one without a tools.env.
const project = (name, text) => {
  const dir = join(TMP, name);
  mkdirSync(join(dir, 'scripts', 'tools'), { recursive: true });
  if (text !== null) writeFileSync(join(dir, 'scripts', 'tools', 'tools.env'), text);
  return dir;
};
const OK = join(TMP, 'project-ok');
mkdirSync(join(OK, 'scripts', 'tools'), { recursive: true });
copyFileSync(join(HERE, 'fixtures', 'project-ok', 'scripts', 'tools', 'tools.env'),
  join(OK, 'scripts', 'tools', 'tools.env'));
const EXPORT = project('project-export', '# set by hand\nexport DEVICE_WRITE_OK=1\n');
const OFF = project('project-off',
  existsSync(KIT_TOOLS_ENV) ? readFileSync(KIT_TOOLS_ENV, 'utf8') : ': "${DEVICE_WRITE_OK:=0}"\n');
const EMPTY = project('project-empty', null);

// A clean environment, so a DEVICE_WRITE_OK in the caller's shell never leaks into a case.
const BASE = { PATH: process.env.PATH, HOME: TMP };
const ENVS = {
  none: { env: BASE, cwd: TMP },
  'ok-env': { env: { ...BASE, DEVICE_WRITE_OK: '1' }, cwd: TMP },
  'ok-file': { env: { ...BASE, CLAUDE_PROJECT_DIR: OK }, cwd: TMP },
  'ok-cwd': { env: BASE, cwd: OK },
  'ok-export': { env: { ...BASE, CLAUDE_PROJECT_DIR: EXPORT }, cwd: TMP },
  'file-off': { env: { ...BASE, CLAUDE_PROJECT_DIR: OFF }, cwd: OK },
  'env-off-file-on': { env: { ...BASE, CLAUDE_PROJECT_DIR: OK, DEVICE_WRITE_OK: '0' }, cwd: TMP },
  'project-empty': { env: { ...BASE, CLAUDE_PROJECT_DIR: EMPTY }, cwd: TMP },
};

// What each topic's note must contain, and the owner's one-line warning, word for word.
const MARKS = {
  'device-write': 'DEVICE_WRITE_OK=1 allows it',
  device: 'installs, runs or drives the app',
  memory: 'Memory note:',
  // An emulator and a `flutter run` stay out of the queue: queued, they would hold it for their whole life.
  run: 'Never queue it',
  emulator: 'shows nothing heavy, detached and outside the queue',
  clean: 'flutter clean note:',
};
const WARNINGS = {
  'device-write': 'Device: this command removes an app, its data or a setting on a phone (DEVICE_WRITE_OK=1).',
  device: 'Device: this command installs or runs the app on a phone or emulator.',
  memory: 'Memory: this command starts a build, which can take several GB.',
  run: 'Memory: this command builds the app and runs it until it is stopped, which can take several GB.',
  emulator: 'Emulator: this command starts an emulator, which takes 2 to 4 GB while it runs.',
};
const ORDER = ['device-write', 'device', 'memory', 'run', 'emulator', 'clean'];

const payload = (command, cwd, extra = {}) => JSON.stringify({
  session_id: 'test-session',
  transcript_path: join(TMP, 'test-session.jsonl'),
  cwd,
  permission_mode: 'default',
  hook_event_name: 'PreToolUse',
  tool_name: 'Bash',
  tool_input: { command, description: 'test case' },
  tool_use_id: 'toolu_test',
  ...extra,
});

function runHook(input, env) {
  const t0 = Date.now();
  const r = spawnSync('node', [HOOK], { input, env, encoding: 'utf8', timeout: 15000 });
  return { ...r, ms: Date.now() - t0 };
}

let passed = 0;
const failures = [];
let slowest = 0;

function checkDenyReason(reason, kind, problems) {
  if (kind === 'device') {
    const parts = ['Ask the owner first', 'DEVICE_WRITE_OK=1', 'scripts/tools/tools.env', 'flutter run',
      'adb install -r', 'adb -s emulator-5554'];
    for (const part of parts) {
      if (!reason.includes(part)) problems.push(`device deny reason lacks "${part}"`);
    }
    return;
  }
  if (!/PID/.test(reason) || !/exit 144/.test(reason)) problems.push('deny reason lacks the self-match or the PID way');
  if (kind && !reason.includes(`${kind} -f`)) problems.push(`deny reason should name ${kind} -f`);
  // Kill by PID: find it, check its working directory, then kill it. A kill by name is only ever forbidden.
  for (const step of ['/proc/<pid>/cwd', 'lsof -a -d cwd -p <pid>', 'kill <pid>']) {
    if (!reason.includes(step)) problems.push(`deny reason lacks the PID step ${step}`);
  }
  for (const line of reason.split('\n')) {
    if (/pkill <name>|pkill -x|killall/.test(line) && !/\bNever\b/.test(line)) {
      problems.push(`deny reason offers a kill by name: ${line.trim()}`);
    }
  }
}

function check(name, r, expect, extra = {}) {
  const problems = [];
  slowest = Math.max(slowest, r.ms);
  if (r.error) problems.push(`spawn error: ${r.error.message}`);
  if (r.status !== 0) problems.push(`exit ${r.status}, want 0`);
  if ((r.stderr || '').trim()) problems.push(`stderr: ${r.stderr.trim().slice(0, 200)}`);
  const out = (r.stdout || '').trim();
  let json = null;
  if (out) {
    try { json = JSON.parse(out); } catch { problems.push(`stdout is not one JSON object: ${out.slice(0, 200)}`); }
  }
  const hso = json && json.hookSpecificOutput;
  if (expect === 'none' && out) problems.push(`want no output, got ${out.slice(0, 200)}`);
  if (expect === 'deny') {
    if (!hso || hso.hookEventName !== 'PreToolUse' || hso.permissionDecision !== 'deny') {
      problems.push(`want a deny, got ${out.slice(0, 200) || 'nothing'}`);
    } else {
      checkDenyReason(hso.permissionDecisionReason || '', extra.kind, problems);
    }
    if (json && 'systemMessage' in json) problems.push('a deny must not also carry a warning');
  }
  if (expect === 'note' || expect === 'warn') {
    const topics = extra.topics || [];
    if (!topics.length) problems.push('a "note" or "warn" case needs its topics');
    if (!hso || hso.hookEventName !== 'PreToolUse' || typeof hso.additionalContext !== 'string') {
      problems.push(`want a note, got ${out.slice(0, 200) || 'nothing'}`);
    } else {
      if ('permissionDecision' in hso) problems.push('a note must not carry a decision');
      const has = (t) => hso.additionalContext.includes(MARKS[t]);
      for (const t of topics) if (!has(t)) problems.push(`the note lacks the ${t} part`);
      for (const t of ORDER) if (!topics.includes(t) && has(t)) problems.push(`the note has an unwanted ${t} part`);
    }
    const want = ORDER.filter((t) => topics.includes(t)).map((t) => WARNINGS[t]).filter(Boolean).join(' ');
    if (expect === 'warn' && (!json || json.systemMessage !== want)) {
      problems.push(`want the owner warning "${want}", got ${JSON.stringify(json && json.systemMessage)}`);
    }
    if (expect === 'note' && json && 'systemMessage' in json) problems.push('a note-only case must not warn the owner');
  }
  if (expect === 'any' && out && !json) problems.push('output is not JSON');
  if (extra.maxMs && r.ms > extra.maxMs) problems.push(`took ${r.ms} ms, limit ${extra.maxMs} ms`);
  if (problems.length) failures.push(`${name}: ${problems.join('; ')}`);
  else passed++;
}

// 1. The cases in fixtures/cases.json. A case with no env (the kill cases) runs both without and with
// DEVICE_WRITE_OK=1: allowing writes to the phone never allows a self-matching kill.
// expect: "deny", "none", "note" (a note for Claude only) or "warn" (the note plus the owner's warning).
const cases = JSON.parse(readFileSync(join(HERE, 'fixtures', 'cases.json'), 'utf8'));
for (const c of cases) {
  for (const envName of c.env ? [c.env] : ['none', 'ok-env']) {
    const { env, cwd } = ENVS[envName];
    const r = runHook(payload(c.command, cwd), env);
    check(`${c.name} [${envName}]`, r, c.expect, { kind: c.kind, topics: c.topics });
  }
}

// 2. Bad or unexpected input: print nothing, exit 0.
const raw = [
  ['empty stdin', ''],
  ['not JSON', 'pkill -f worker'],
  ['a JSON array', '[]'],
  ['no tool_input', JSON.stringify({ tool_name: 'Bash' })],
  ['command is a number', JSON.stringify({ tool_name: 'Bash', tool_input: { command: 42 } })],
  ['another tool',
    JSON.stringify({ tool_name: 'Read', tool_input: { command: 'adb uninstall com.example.app', file_path: '/x' } })],
  ['blank command', payload('   ', TMP)],
];
for (const [name, input] of raw) check(`input: ${name}`, runHook(input, ENVS.none.env), 'none');

// 2b. On Windows, Claude Code may run commands through its PowerShell tool: the same rules apply there.
const ps = (command) => payload(command, TMP, { tool_name: 'PowerShell' });
check('PowerShell: a build warns', runHook(ps('flutter build apk'), ENVS.none.env), 'warn', { topics: ['memory'] });
check('PowerShell: adb.exe uninstall is denied', runHook(ps('adb.exe uninstall com.example.app'), ENVS.none.env),
  'deny', { kind: 'device' });
check('PowerShell: the full-match kill is denied', runHook(ps('pkill -f worker'), ENVS.none.env), 'deny',
  { kind: 'pkill' });
const psEscapes = 'Write-Host "a`tb"; Get-Process | Where-Object { $_.Name -eq "adb" }';
check('PowerShell: backtick escapes do not crash', runHook(ps(psEscapes), ENVS.none.env), 'none');

// 3. Size and nesting: never crash, stay fast.
const long = `${'echo a; '.repeat(100000)}pkill -f worker`;
check('800 KB command ending in pkill -f', runHook(payload(long, TMP), ENVS.none.env), 'deny', { maxMs: 5000 });
const longAdb = `${'echo a; '.repeat(100000)}adb uninstall com.example.app`;
check('800 KB command ending in adb uninstall', runHook(payload(longAdb, TMP), ENVS.none.env), 'deny',
  { kind: 'device', maxMs: 5000 });
const nested10 = `echo ${'$('.repeat(10)}pkill -f worker${')'.repeat(10)}`;
check('10 nested $( ) still read', runHook(payload(nested10, TMP), ENVS.none.env), 'deny');
const nested300 = `echo ${'$('.repeat(300)}pkill -f worker${')'.repeat(300)}`;
check('300 nested $( ) does not crash', runHook(payload(nested300, TMP), ENVS.none.env), 'any', { maxMs: 5000 });
const remote300 = `${'adb shell '.repeat(300)}pm clear com.example.app`;
check('300 nested adb shell does not crash', runHook(payload(remote300, TMP), ENVS.none.env), 'any', { maxMs: 5000 });
const parens = `${'('.repeat(20000)}pkill -f worker${')'.repeat(20000)}`;
check('20000 nested ( ) does not crash', runHook(payload(parens, TMP), ENVS.none.env), 'any', { maxMs: 5000 });
const quotes = `pkill -f ${'"a'.repeat(5000)}`;
check('5000 unbalanced quotes', runHook(payload(quotes, TMP), ENVS.none.env), 'any', { maxMs: 5000 });

for (const f of failures) console.log(`FAIL ${f}`);
console.log(`guard-bash: ${passed} passed, ${failures.length} failed (slowest case ${slowest} ms)`);
process.exit(failures.length ? 1 : 0);
