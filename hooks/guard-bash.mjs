#!/usr/bin/env node
// PreToolUse hook for the Bash and PowerShell tools (wired in hooks/hooks.json).
//
// 1. Denies `pkill -f` and any kill fed by `pgrep -f`. Both match the pattern against the
//    full command line of every process. The shell that runs the command carries the same
//    pattern in its own command line, so the kill ends the tool call itself (exit 144).
// 2. Denies what deletes the owner's data or settings on a phone: `adb uninstall`,
//    `adb shell pm clear`, `pm uninstall`, `settings put`, `flutter install` (it removes an
//    installed copy first). DEVICE_WRITE_OK=1, in the environment or in the project's
//    scripts/tools/tools.env, allows them; an assignment inside the command never does.
//    On an emulator the command names (`adb -s emulator-5554`, `flutter install -d emulator-5554`,
//    `ANDROID_SERIAL=emulator-5554 adb ...`) they run without it: an emulator holds no one's data.
// 3. A command that takes a device or a lot of memory (flutter run, install, drive, build;
//    an integration test; adb install; an emulator; a Gradle build) gives Claude a note and shows the owner a
//    one-line warning as it starts (systemMessage). Claude reads a PreToolUse note with the
//    command's result, too late to warn first, so the warning goes to the owner.
//    `flutter clean` gets the note only.
//
// Input: the PreToolUse JSON on stdin. Output: one JSON object on stdout, or nothing.
// Always exits 0, and prints nothing on any error, so a bug here never blocks a command.
// It guards against accidents, not against a command written to slip past it.

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const MAX_DEPTH = 24; // how deep we follow $( ), backticks and `bash -c` strings
const MAX_INPUT = 2 * 1024 * 1024;

const ASSIGN = /^[A-Za-z_][A-Za-z0-9_]*(\[[^\]]*\])?\+?=/;
const OPS3 = [';;&', '<<<', '<<-', '&>>'];
const OPS2 = ['&&', '||', '|&', ';;', ';&', '<<', '>>', '&>', '>&', '<&', '>|', '<>'];
const OPS1 = [';', '&', '|', '<', '>'];
const REDIRS = new Set(['<<<', '<<-', '&>>', '<<', '>>', '&>', '>&', '<&', '>|', '<>', '<', '>']);
const META = new Set([' ', '\t', '\r', '\n', ';', '&', '|', '<', '>', '(', ')']);
const SEPARATORS = new Set([';', '\n', '&', '&&', '||', ';;', ';&', ';;&']);
const STRAY = new Set(['then', 'do', 'else', 'elif', 'fi', 'done', 'esac', '}', 'in']);

// ---------------------------------------------------------------- lexer

// Reads tokens from s[start..]. With untilParen, stops after the `)` that closes a `$(`.
function tokenize(s, start, depth, untilParen) {
  const toks = [];
  const waiting = []; // heredocs whose body starts after the next newline
  let expectDelim = null;
  let parens = 0;
  let i = start;
  while (i < s.length) {
    const c = s[i];
    if (c === ' ' || c === '\t' || c === '\r') { i++; continue; }
    if (c === '\\' && s[i + 1] === '\n') { i += 2; continue; }
    if (c === '\n') {
      toks.push({ t: 'op', v: '\n' });
      i++;
      if (waiting.length) i = readHeredocBodies(s, i, waiting.splice(0), depth);
      continue;
    }
    if (c === '#') { // a comment runs to the end of the line
      while (i < s.length && s[i] !== '\n') i++;
      continue;
    }
    if (c === ')') {
      if (untilParen && parens === 0) return { toks, end: i + 1 };
      if (parens > 0) parens--;
      toks.push({ t: 'op', v: ')' });
      i++;
      continue;
    }
    if (c === '(') { parens++; toks.push({ t: 'op', v: '(' }); i++; continue; }
    if ((c === '<' || c === '>') && s[i + 1] === '(') { // process substitution <( ) or >( )
      const r = readSub(s, i + 2, depth);
      toks.push({ t: 'word', text: s.slice(i, r.end), subs: r.sub ? [r.sub] : [], quoted: false });
      i = r.end;
      continue;
    }
    const op = OPS3.find((o) => s.startsWith(o, i)) || OPS2.find((o) => s.startsWith(o, i))
      || OPS1.find((o) => s.startsWith(o, i));
    if (op) {
      i += op.length;
      if (REDIRS.has(op)) {
        const tok = { t: 'redir', v: op };
        if (op === '<<' || op === '<<-') {
          tok.heredoc = { delim: null, quoted: false, strip: op === '<<-', body: '', subs: [] };
          expectDelim = tok.heredoc;
        }
        toks.push(tok);
      } else {
        toks.push({ t: 'op', v: op });
      }
      continue;
    }
    const w = readWord(s, i, depth);
    i = w.end;
    // Digits right before < or > name a file descriptor (2>&1), not an argument.
    if (/^\d+$/.test(w.text) && !w.quoted && (s[i] === '<' || s[i] === '>')) continue;
    if (expectDelim) {
      expectDelim.delim = w.text;
      expectDelim.quoted = w.quoted;
      waiting.push(expectDelim);
      expectDelim = null;
    }
    toks.push(w);
  }
  return { toks, end: i };
}

function readWord(s, i, depth) {
  let text = '';
  const subs = [];
  let quoted = false;
  while (i < s.length) {
    const c = s[i];
    if (META.has(c)) {
      if (c === '(' && /^[A-Za-z_][A-Za-z0-9_]*(\[[^\]]*\])?\+?=$/.test(text)) { // name=( array )
        const e = skipBalanced(s, i + 1, '(', ')');
        subs.push(...scanExpansions(s.slice(i + 1, e - 1), depth)); // P=($(pgrep -f x)) runs pgrep
        text += s.slice(i, e);
        i = e;
        continue;
      }
      break;
    }
    if (c === '\\') {
      if (s[i + 1] === '\n') { i += 2; continue; }
      if (i + 1 < s.length) text += s[i + 1];
      i += 2;
      quoted = true;
      continue;
    }
    if (c === "'") {
      const e = s.indexOf("'", i + 1);
      const end = e < 0 ? s.length : e;
      text += s.slice(i + 1, end);
      i = end + 1;
      quoted = true;
      continue;
    }
    if (c === '"') {
      const r = readDouble(s, i + 1, depth);
      text += r.text;
      subs.push(...r.subs);
      i = r.end;
      quoted = true;
      continue;
    }
    if (c === '`') {
      const r = readBacktick(s, i + 1, depth);
      text += r.raw;
      if (r.sub) subs.push(r.sub);
      i = r.end;
      continue;
    }
    if (c === '$') {
      if (s[i + 1] === "'") {
        const r = readAnsi(s, i + 2);
        text += r.text;
        i = r.end;
        quoted = true;
        continue;
      }
      const r = readDollar(s, i, depth);
      if (r) {
        text += r.raw;
        if (r.sub) subs.push(r.sub);
        i = r.end;
        continue;
      }
    }
    text += c;
    i++;
  }
  return { t: 'word', text, subs, quoted, end: Math.min(i, s.length) };
}

function readDouble(s, i, depth) {
  let text = '';
  const subs = [];
  while (i < s.length && s[i] !== '"') {
    const c = s[i];
    if (c === '\\') {
      const n = s[i + 1];
      if (n === '\n') { i += 2; continue; }
      if (n === '"' || n === '\\' || n === '$' || n === '`') { text += n; i += 2; continue; }
      text += c;
      i++;
      continue;
    }
    if (c === '`') {
      const r = readBacktick(s, i + 1, depth);
      text += r.raw;
      if (r.sub) subs.push(r.sub);
      i = r.end;
      continue;
    }
    if (c === '$') {
      const r = readDollar(s, i, depth);
      if (r) {
        text += r.raw;
        if (r.sub) subs.push(r.sub);
        i = r.end;
        continue;
      }
    }
    text += c;
    i++;
  }
  return { text, subs, end: Math.min(i + 1, s.length) };
}

function readAnsi(s, i) { // $'...'
  let text = '';
  while (i < s.length && s[i] !== "'") {
    if (s[i] === '\\' && i + 1 < s.length) {
      const n = s[i + 1];
      text += n === 'n' ? '\n' : n === 't' ? '\t' : n;
      i += 2;
      continue;
    }
    text += s[i];
    i++;
  }
  return { text, end: Math.min(i + 1, s.length) };
}

// $( ) runs a command; $(( )) and ${ } do not. Returns null for a plain $name.
function readDollar(s, i, depth) {
  if (s.startsWith('$((', i)) {
    const e = skipBalanced(s, i + 3, '(', ')', 2);
    return { raw: s.slice(i, e), sub: null, end: e };
  }
  if (s[i + 1] === '(') {
    const r = readSub(s, i + 2, depth);
    return { raw: s.slice(i, r.end), sub: r.sub, end: r.end };
  }
  if (s[i + 1] === '{') {
    const e = skipBalanced(s, i + 2, '{', '}');
    return { raw: s.slice(i, e), sub: null, end: e };
  }
  return null;
}

function readSub(s, i, depth) {
  if (depth >= MAX_DEPTH) return { sub: null, end: skipBalanced(s, i, '(', ')') };
  const r = tokenize(s, i, depth + 1, true);
  return { sub: parse(r.toks, depth + 1), end: r.end };
}

function readBacktick(s, i, depth) {
  let body = '';
  while (i < s.length && s[i] !== '`') {
    if (s[i] === '\\' && i + 1 < s.length) {
      const n = s[i + 1];
      body += n === '`' || n === '\\' || n === '$' ? n : s[i] + n;
      i += 2;
      continue;
    }
    body += s[i];
    i++;
  }
  const sub = depth >= MAX_DEPTH ? null : parseString(body, depth + 1);
  return { raw: '`' + body + '`', sub, end: Math.min(i + 1, s.length) };
}

function skipBalanced(s, i, open, close, level = 1) {
  while (i < s.length && level > 0) {
    const c = s[i];
    if (c === '\\') { i += 2; continue; }
    if (c === open) level++;
    else if (c === close) level--;
    i++;
  }
  return Math.min(i, s.length);
}

function readHeredocBodies(s, i, docs, depth) {
  for (const doc of docs) {
    const lines = [];
    while (i < s.length) {
      let nl = s.indexOf('\n', i);
      if (nl < 0) nl = s.length;
      const raw = s.slice(i, nl);
      i = Math.min(nl + 1, s.length);
      const line = doc.strip ? raw.replace(/^\t+/, '') : raw;
      if (line === doc.delim) break;
      lines.push(line);
    }
    doc.body = lines.join('\n');
    // An unquoted delimiter means the shell expands $( ) and backticks in the body.
    if (!doc.quoted) doc.subs = scanExpansions(doc.body, depth);
  }
  return i;
}

function scanExpansions(t, depth) {
  const subs = [];
  let i = 0;
  while (i < t.length) {
    const c = t[i];
    if (c === '\\') { i += 2; continue; }
    if (c === '`') {
      const r = readBacktick(t, i + 1, depth);
      if (r.sub) subs.push(r.sub);
      i = r.end;
      continue;
    }
    if (c === '$') {
      const r = readDollar(t, i, depth);
      if (r) {
        if (r.sub) subs.push(r.sub);
        i = r.end;
        continue;
      }
    }
    i++;
  }
  return subs;
}

// ---------------------------------------------------------------- parser
// A script is a list of pipelines; a pipeline is a list of elements. An element is a
// simple command or a group: ( ), { }, if, while, until, for, case, or a function body.

function parseString(str, depth) {
  if (depth > MAX_DEPTH) return [];
  return parse(tokenize(str, 0, depth, false).toks, depth);
}

function parse(toks, depth) {
  return parseList({ toks, i: 0, depth }, new Set());
}

const isOp = (tk, v) => Boolean(tk) && tk.t === 'op' && tk.v === v;
const isBare = (tk) => Boolean(tk) && tk.t === 'word' && !tk.quoted && tk.subs.length === 0;
const isWord = (tk, v) => isBare(tk) && tk.text === v;
const isTerm = (tk, terms) => Boolean(tk) && (tk.t === 'op' ? terms.has(tk.v) : isBare(tk) && terms.has(tk.text));

function parseList(p, terms) {
  const list = [];
  while (p.i < p.toks.length) {
    const tk = p.toks[p.i];
    if (isTerm(tk, terms)) return list;
    if (tk.t === 'op' && (SEPARATORS.has(tk.v) || tk.v === ')')) { p.i++; continue; }
    const before = p.i;
    const pipe = parsePipeline(p, terms);
    if (pipe.length) list.push(pipe);
    if (p.i === before) p.i++;
  }
  return list;
}

function parsePipeline(p, terms) {
  const els = [];
  for (;;) {
    while (els.length && isOp(p.toks[p.i], '\n')) p.i++; // a newline may follow a pipe
    const el = parseElement(p, terms);
    if (el) els.push(el);
    if (isOp(p.toks[p.i], '|') || isOp(p.toks[p.i], '|&')) { p.i++; continue; }
    return els;
  }
}

function parseElement(p, terms) {
  for (;;) {
    const tk = p.toks[p.i];
    if (!tk || isTerm(tk, terms)) return null;
    if (tk.t === 'op') {
      if (tk.v !== '(') return null;
      p.i++;
      const body = parseList(p, new Set([')']));
      if (isOp(p.toks[p.i], ')')) p.i++;
      return finishGroup(p, { kind: 'group', body });
    }
    if (isBare(tk)) {
      const w = tk.text;
      if (w === '!') { p.i++; continue; }
      if (w === 'time') { p.i++; if (isWord(p.toks[p.i], '-p')) p.i++; continue; }
      if (STRAY.has(w)) { p.i++; continue; }
      if (w === '{') {
        p.i++;
        const body = parseList(p, new Set(['}']));
        if (isWord(p.toks[p.i], '}')) p.i++;
        return finishGroup(p, { kind: 'group', body });
      }
      if (w === 'if') return parseIf(p);
      if (w === 'while' || w === 'until') {
        p.i++;
        const cond = parseList(p, new Set(['do']));
        if (isWord(p.toks[p.i], 'do')) p.i++;
        const body = parseList(p, new Set(['done']));
        if (isWord(p.toks[p.i], 'done')) p.i++;
        return finishGroup(p, { kind: 'group', body: [...cond, ...body] });
      }
      if (w === 'for' || w === 'select') return parseFor(p);
      if (w === 'case') return parseCase(p);
      if (w === 'function') {
        p.i++;
        if (p.toks[p.i] && p.toks[p.i].t === 'word') p.i++;
        if (isOp(p.toks[p.i], '(') && isOp(p.toks[p.i + 1], ')')) p.i += 2;
        while (isOp(p.toks[p.i], '\n')) p.i++;
        continue;
      }
    }
    return parseSimple(p, terms);
  }
}

function parseIf(p) {
  p.i++;
  const body = [];
  for (;;) {
    body.push(...parseList(p, new Set(['then'])));
    if (isWord(p.toks[p.i], 'then')) p.i++;
    body.push(...parseList(p, new Set(['elif', 'else', 'fi'])));
    if (isWord(p.toks[p.i], 'elif')) { p.i++; continue; }
    if (isWord(p.toks[p.i], 'else')) { p.i++; body.push(...parseList(p, new Set(['fi']))); }
    if (isWord(p.toks[p.i], 'fi')) p.i++;
    return finishGroup(p, { kind: 'group', body });
  }
}

function parseFor(p) {
  p.i++;
  const header = { name: null, words: [] };
  if (isBare(p.toks[p.i])) { header.name = p.toks[p.i].text; p.i++; }
  while (p.i < p.toks.length && !isWord(p.toks[p.i], 'do')) {
    const tk = p.toks[p.i];
    if (tk.t === 'word' && !isWord(tk, 'in')) header.words.push(tk);
    p.i++;
  }
  if (isWord(p.toks[p.i], 'do')) p.i++;
  const body = parseList(p, new Set(['done']));
  if (isWord(p.toks[p.i], 'done')) p.i++;
  return finishGroup(p, { kind: 'group', header, body });
}

function parseCase(p) {
  p.i++;
  const subjectSubs = [];
  if (p.toks[p.i] && p.toks[p.i].t === 'word') { subjectSubs.push(...p.toks[p.i].subs); p.i++; }
  while (isOp(p.toks[p.i], '\n')) p.i++;
  if (isWord(p.toks[p.i], 'in')) p.i++;
  const body = [];
  const caseTerms = new Set([';;', ';&', ';;&', 'esac']);
  while (p.i < p.toks.length) {
    while (isOp(p.toks[p.i], '\n') || isOp(p.toks[p.i], ';')) p.i++;
    if (!p.toks[p.i] || isWord(p.toks[p.i], 'esac')) break;
    while (p.i < p.toks.length && !isOp(p.toks[p.i], ')')) p.i++; // the pattern
    p.i++;
    body.push(...parseList(p, caseTerms));
    const tk = p.toks[p.i];
    if (tk && tk.t === 'op' && caseTerms.has(tk.v)) p.i++;
  }
  if (isWord(p.toks[p.i], 'esac')) p.i++;
  const g = finishGroup(p, { kind: 'group', body });
  g.inputSubs.push(...subjectSubs);
  return g;
}

// Redirections after a group, such as `done < <(pgrep -f x)`, feed the group. inputTexts keeps
// what a here-string or an unquoted heredoc expands, such as `done <<< "$pids"`.
function finishGroup(p, g) {
  g.inputSubs = [];
  g.inputTexts = [];
  while (p.toks[p.i] && p.toks[p.i].t === 'redir') {
    const r = p.toks[p.i];
    p.i++;
    const target = p.toks[p.i];
    if (target && target.t === 'word') { p.i++; g.inputSubs.push(...target.subs); g.inputTexts.push(target.text); }
    if (r.heredoc) {
      g.inputSubs.push(...r.heredoc.subs);
      if (!r.heredoc.quoted) g.inputTexts.push(r.heredoc.body);
    }
  }
  return g;
}

function parseSimple(p, terms) {
  const cmd = { kind: 'simple', words: [], assigns: [], redirSubs: [], heredocs: [], herestrings: [], depth: p.depth };
  while (p.i < p.toks.length) {
    const tk = p.toks[p.i];
    if (tk.t === 'op') {
      if (tk.v === '(' && cmd.words.length === 1 && isOp(p.toks[p.i + 1], ')')) { // name() { body; }
        p.i += 2;
        while (isOp(p.toks[p.i], '\n')) p.i++;
        const body = parseElement(p, terms);
        return { kind: 'group', body: body ? [[body]] : [], inputSubs: [] };
      }
      break;
    }
    if (tk.t === 'redir') {
      p.i++;
      const target = p.toks[p.i];
      if (target && target.t === 'word') {
        p.i++;
        cmd.redirSubs.push(...target.subs);
        if (tk.v === '<<<') cmd.herestrings.push(target.text);
      }
      if (tk.heredoc) {
        cmd.heredocs.push(tk.heredoc);
        cmd.redirSubs.push(...tk.heredoc.subs);
      }
      continue;
    }
    if (cmd.words.length === 0 && ASSIGN.test(tk.text)) cmd.assigns.push(tk);
    else cmd.words.push(tk);
    p.i++;
  }
  return cmd;
}

// ---------------------------------------------------------------- command words

const SHELLS = new Set(['bash', 'sh', 'zsh', 'dash', 'ksh', 'ash', 'mksh']);
const PMS = new Set(['pnpm', 'npm', 'yarn', 'bun']);
const PM_ARGS = {
  pnpm: new Set(['-C', '--dir', '--filter', '-F']),
  npm: new Set(['-w', '--workspace', '--prefix', '-C']),
  yarn: new Set(['--cwd']),
  bun: new Set(['--cwd', '--filter', '-F']),
};
const DECLARERS = new Set(['export', 'local', 'declare', 'readonly', 'typeset']);
const SUDO_ARGS = new Set(['-u', '-g', '-C', '-D', '-h', '-p', '-r', '-t', '-U', '-T', '--user', '--group',
  '--close-from', '--chdir', '--host', '--prompt', '--role', '--type', '--other-user', '--command-timeout']);
const XARGS_ARGS = new Set(['-I', '-d', '-E', '-a', '-L', '-n', '-P', '-s', '--arg-file', '--delimiter',
  '--max-args', '--max-procs', '--max-chars', '--process-slot-var']);
// The RAM plugin's queue: `ram.sh run [options] -- <command>` runs the command.
const RAM_ARGS = new Set(['--need', '--max', '--name', '--timeout', '--wait']);
// Scripts that `bash <script> ...` runs and whose own arguments say what runs: the queue, the queued build and tests.
const KNOWN_SCRIPTS = new Set(['ram.sh', 'q-build.sh', 'q-test.sh']);
const SHELL_ARGS = new Set(['-o', '-O', '--rcfile', '--init-file']);
const ADB_ARGS = new Set(['-s', '-t', '-H', '-P', '-L', '--one-device']);
const base = (t) => t.slice(t.lastIndexOf('/') + 1);

// Skips options from texts[k]; options in withArg take the next word. Stops after `--`.
function skipOptions(texts, k, withArg) {
  while (k < texts.length && texts[k].startsWith('-') && texts[k] !== '-') {
    if (texts[k] === '--') return k + 1;
    k += withArg.has(texts[k]) ? 2 : 1;
  }
  return k;
}

// Finds the real command behind wrappers (sudo, env, nohup, timeout, xargs, npx, fvm, ram.sh run ...) and
// the scripts it runs from a string (bash -c, eval, watch, a heredoc fed to a shell, adb shell).
function resolve(cmd) {
  if (cmd._r) return cmd._r;
  const words = cmd.words;
  const texts = words.map((w) => w.text);
  const r = { name: null, args: [], argv: [], nested: [], remote: [], assigns: [], stdinShell: false };
  cmd._r = r;
  const run = (str) => { if (cmd.depth < MAX_DEPTH) r.nested.push(parseString(str, cmd.depth + 1)); };
  const n = words.length;
  let k = 0;
  while (k < n) {
    const name = base(texts[k]);
    if (name === 'sudo' || name === 'doas') { k = skipOptions(texts, k + 1, SUDO_ARGS); continue; }
    if (name === 'env') {
      k++;
      while (k < n) {
        const a = texts[k];
        if (a === '--') { k++; break; }
        if (a === '-S' || a === '--split-string') { run(texts.slice(k + 1).join(' ')); return r; }
        if (a === '-u' || a === '-C' || a === '--unset' || a === '--chdir') { k += 2; continue; }
        if (a.startsWith('-')) { k++; continue; }
        if (ASSIGN.test(a)) { r.assigns.push(words[k]); k++; continue; }
        break;
      }
      continue;
    }
    if (name === 'nohup' || name === 'builtin') { k++; continue; }
    if (name === 'command') {
      k++;
      while (k < n && /^-[pvV]+$/.test(texts[k])) {
        if (/[vV]/.test(texts[k])) return r; // `command -v x` only looks x up
        k++;
      }
      continue;
    }
    if (name === 'exec') { k = skipOptions(texts, k + 1, new Set(['-a'])); continue; }
    if (name === 'time') { k = skipOptions(texts, k + 1, new Set(['-f', '-o', '--format', '--output'])); continue; }
    if (name === 'nice') { k = skipOptions(texts, k + 1, new Set(['-n', '--adjustment'])); continue; }
    if (name === 'timeout') {
      k = skipOptions(texts, k + 1, new Set(['-s', '-k', '--signal', '--kill-after'])) + 1;
      continue;
    }
    if (name === 'setsid') { k = skipOptions(texts, k + 1, new Set()); continue; }
    if (name === 'stdbuf') { k = skipOptions(texts, k + 1, new Set(['-i', '-o', '-e'])); continue; }
    if (name === 'ionice') { k = skipOptions(texts, k + 1, new Set(['-c', '-n'])); continue; }
    if (name === 'xargs') {
      k = skipOptions(texts, k + 1, XARGS_ARGS);
      if (k >= n) { r.name = 'echo'; return r; } // xargs with no command runs echo
      continue;
    }
    if (name === 'npx' || name === 'bunx' || name === 'pnpx') {
      k = skipOptions(texts, k + 1, new Set(['-p', '--package']));
      continue;
    }
    if (PMS.has(name)) { // pnpm exec, npm exec, yarn exec, pnpm dlx, yarn dlx, bun x
      const j = skipOptions(texts, k + 1, PM_ARGS[name]);
      if (texts[j] === 'exec' || texts[j] === 'dlx' || texts[j] === 'x') {
        k = j + 1;
        if (texts[k] === '--') k++;
        continue;
      }
    }
    if (name === 'fvm' && (texts[k + 1] === 'flutter' || texts[k + 1] === 'dart')) { k++; continue; }
    if (name === 'ram.sh' && texts[k + 1] === 'run') { k = skipOptions(texts, k + 2, RAM_ARGS); continue; }
    if (SHELLS.has(name)) { // `bash ram.sh run -- ...`, `bash scripts/tools/q-build.sh apk`
      const j = skipOptions(texts, k + 1, SHELL_ARGS);
      const opts = texts.slice(k + 1, j);
      if (j < n && KNOWN_SCRIPTS.has(base(texts[j])) && !opts.some((o) => /^-[A-Za-z]*[cns]/.test(o))) {
        k = j;
        continue;
      }
    }
    if (name === 'watch') { // watch hands its arguments to `sh -c`
      const j = skipOptions(texts, k + 1, new Set(['-n', '--interval', '-q', '--equexit']));
      r.name = 'watch';
      run(texts.slice(j).join(' '));
      return r;
    }
    break;
  }
  if (k >= n) return r;
  r.name = base(texts[k]);
  r.args = words.slice(k + 1);
  r.argv = texts.slice(k + 1);
  if (SHELLS.has(r.name)) shellScripts(cmd, r, run);
  else if (r.name === 'eval') run(r.argv.join(' '));
  else if (toolName(r.name) === 'adb') adbShell(cmd, r);
  return r;
}

function shellScripts(cmd, r, run) {
  const a = r.argv;
  let j = 0;
  let hasC = false;
  while (j < a.length) {
    const t = a[j];
    if (t === '--' || t === '-') { j++; break; }
    if (/^[-+][A-Za-z]+$/.test(t)) {
      if (t[0] === '-' && t.includes('c')) hasC = true;
      j += /[oO]/.test(t) ? 2 : 1; // -o pipefail, -O extglob
      continue;
    }
    if (t.startsWith('--')) { j += t === '--rcfile' || t === '--init-file' ? 2 : 1; continue; }
    break;
  }
  if (hasC) { if (j < a.length) run(a[j]); return; }
  if (j < a.length) return; // runs a script file
  r.stdinShell = true; // reads its commands from stdin
  for (const h of cmd.heredocs) run(h.body);
  for (const s of cmd.herestrings) run(s);
}

// Where adb's own command starts: after its options and any `wait-for-device` (or `wait-for-usb-recovery`...),
// which only waits for the device, then runs the command that follows it.
function adbCommand(a) {
  let j = skipOptions(a, 0, ADB_ARGS);
  while (j < a.length && a[j].startsWith('wait-for-')) j++;
  return j;
}

// `adb shell <command>` (and `adb exec-out`) runs the command on the phone: it is read as a script of its own,
// marked remote, so `pm clear` counts there and nowhere else. Without a command, adb reads it from stdin.
function adbShell(cmd, r) {
  const a = r.argv;
  const j = adbCommand(a);
  if (a[j] !== 'shell' && a[j] !== 'exec-out') return;
  const k = skipOptions(a, j + 1, new Set(['-e']));
  const remote = (str) => { if (cmd.depth < MAX_DEPTH) r.remote.push(parseString(str, cmd.depth + 1)); };
  if (k < a.length) { remote(a.slice(k).join(' ')); return; }
  r.stdinShell = true;
  for (const h of cmd.heredocs) remote(h.body);
  for (const s of cmd.herestrings) remote(s);
}

// True when pkill or pgrep options include -f / --full (also inside a group like -fx).
const PG_ARG_SHORT = new Set(['d', 'g', 'G', 'O', 'P', 's', 't', 'u', 'U', 'F', 'r', 'q']);
const PG_ARG_LONG = new Set(['delimiter', 'pgroup', 'group', 'older', 'parent', 'session', 'terminal', 'euid',
  'uid', 'pidfile', 'runstates', 'ns', 'nslist', 'signal', 'env', 'cgroup', 'queue']);
function usesFull(argv) {
  for (let k = 0; k < argv.length; k++) {
    const a = argv[k];
    if (a === '--') return false;
    if (a.startsWith('--')) {
      const name = a.slice(2).split('=')[0];
      if (name && 'full'.startsWith(name)) return true; // getopt accepts --fu, --ful
      if (PG_ARG_LONG.has(name) && !a.includes('=')) k++;
      continue;
    }
    if (a.length < 2 || a[0] !== '-') continue;
    for (let c = 1; c < a.length; c++) {
      if (a[c] === 'f') return true;
      if (PG_ARG_SHORT.has(a[c])) { if (c === a.length - 1) k++; break; } // -F pidfile, -u user
    }
  }
  return false;
}

// ---------------------------------------------------------------- analysis

function scriptHas(script, pred) {
  return script.some((pipe) => pipe.some((el) => elementHas(el, pred)));
}

function elementHas(el, pred) {
  const inSubs = (subs) => subs.some((s) => scriptHas(s, pred));
  if (el.kind === 'group') {
    return scriptHas(el.body, pred) || inSubs(el.inputSubs)
      || (el.header ? el.header.words.some((w) => inSubs(w.subs)) : false);
  }
  if (pred(el)) return true;
  const r = resolve(el);
  return r.nested.some((s) => scriptHas(s, pred)) || inSubs(el.redirSubs)
    || el.assigns.some((w) => inSubs(w.subs)) || el.words.some((w) => inSubs(w.subs));
}

const isPgrepFull = (cmd) => { const r = resolve(cmd); return r.name === 'pgrep' && usesFull(r.argv); };
const isKill = (cmd) => {
  const r = resolve(cmd);
  if (r.name !== 'kill') return false;
  // `kill -0` only tests that a PID exists; `kill -l` lists signal names.
  return !r.argv.some((a, k) => a === '-0' || a === '-l' || a === '-L' || (a === '-s' && r.argv[k + 1] === '0'));
};
const subsHavePgrepFull = (w) => w.subs.some((s) => scriptHas(s, isPgrepFull));
const varName = (text) => (text.match(/^[A-Za-z_][A-Za-z0-9_]*/) || [''])[0];
const refsVar = (text, names) => [...names].some((v) => new RegExp(`\\$\\{?[#!]?${v}(?![A-Za-z0-9_])`).test(text));
// A word carries pgrep -f PIDs when it runs pgrep -f or reads a variable that holds them.
const carries = (w, ctx) => subsHavePgrepFull(w) || (ctx.taint.size > 0 && refsVar(w.text, ctx.taint));

function deny(ctx, kind) { if (!ctx.deny) ctx.deny = kind; }

function analyze(script, ctx) {
  for (const pipe of script) {
    for (const el of pipe) visit(el, ctx);
    let fed = false; // an earlier element of this pipeline prints pgrep -f PIDs
    for (let e = 0; e < pipe.length; e++) {
      const el = pipe[e];
      if (fed && elementHas(el, isKill)) deny(ctx, 'pgrep');
      if (e > 0 && el.kind === 'simple' && resolve(el).stdinShell) feedShell(pipe[e - 1], el, ctx);
      // `echo $pids | xargs kill` passes the PIDs on as well as `pgrep -f x | xargs kill`.
      if (elementHas(el, isPgrepFull) || (el.kind === 'simple' && el.words.some((w) => carries(w, ctx)))) fed = true;
    }
  }
}

// Reads a script that runs on the phone (`adb shell ...`): its `pm clear` and `settings put` count there.
// onEmulator: the adb command named an emulator, where they run freely.
function analyzeRemote(script, ctx, onEmulator) {
  const was = { remote: ctx.remote, emulator: ctx.emulator };
  ctx.remote = true;
  ctx.emulator = onEmulator;
  analyze(script, ctx);
  ctx.remote = was.remote;
  ctx.emulator = was.emulator;
}

// `echo 'cmd' | bash` runs the echoed text as a script; `echo 'cmd' | adb shell` runs it on the phone.
function feedShell(prev, shell, ctx) {
  if (prev.kind !== 'simple' || shell.depth >= MAX_DEPTH) return;
  const r = resolve(prev);
  let text = null;
  if (r.name === 'echo') text = r.argv.filter((a) => !/^-[neE]+$/.test(a)).join(' ');
  if (r.name === 'printf') text = r.argv.slice(1).join('\n');
  // `cat <<'EOF' | bash` (or `cat -`) runs the heredoc's text as a script.
  if (r.name === 'cat' && r.argv.every((a) => a === '-')) {
    text = [...prev.heredocs.map((h) => h.body), ...prev.herestrings].join('\n');
  }
  if (text === null) return;
  const script = parseString(text, shell.depth + 1);
  if (toolName(resolve(shell).name || '') === 'adb') analyzeRemote(script, ctx, adbOnEmulator(shell));
  else analyze(script, ctx);
}

function visit(el, ctx) {
  if (el.kind === 'group') {
    for (const s of el.inputSubs) analyze(s, ctx);
    if (el.header) {
      for (const w of el.header.words) for (const s of w.subs) analyze(s, ctx);
      if (varName(el.header.name || '') && el.header.words.some((w) => carries(w, ctx))) {
        ctx.taint.add(varName(el.header.name));
      }
    }
    analyze(el.body, ctx);
    const groupFed = el.inputSubs.some((s) => scriptHas(s, isPgrepFull))
      || (ctx.taint.size > 0 && (el.inputTexts || []).some((t) => refsVar(t, ctx.taint)));
    if (groupFed && scriptHas(el.body, isKill)) deny(ctx, 'pgrep');
    return;
  }
  for (const w of [...el.assigns, ...el.words]) for (const s of w.subs) analyze(s, ctx);
  for (const s of el.redirSubs) analyze(s, ctx);
  const r = resolve(el);
  for (const s of r.nested) analyze(s, ctx);
  for (const s of r.remote) analyzeRemote(s, ctx, adbOnEmulator(el));
  const declared = DECLARERS.has(r.name) ? r.args.filter((w) => ASSIGN.test(w.text)) : [];
  const assigns = [...el.assigns, ...r.assigns, ...declared];
  for (const a of assigns) if (subsHavePgrepFull(a)) ctx.taint.add(varName(a.text));
  if (r.name === 'pkill' && usesFull(r.argv)) deny(ctx, 'pkill');
  // Stdin fed by pgrep -f: `read P < <(pgrep -f x)`, `xargs kill <<< "$pids"`, a heredoc holding $pids.
  const fedTexts = [...el.herestrings, ...el.heredocs.filter((h) => !h.quoted).map((h) => h.body)];
  const fedIn = el.redirSubs.some((s) => scriptHas(s, isPgrepFull))
    || (ctx.taint.size > 0 && fedTexts.some((t) => refsVar(t, ctx.taint)));
  if (fedIn && (r.name === 'read' || r.name === 'mapfile' || r.name === 'readarray')) {
    for (const t of r.argv) if (/^[A-Za-z_][A-Za-z0-9_]*$/.test(t)) ctx.taint.add(t);
  }
  if (fedIn && isKill(el)) deny(ctx, 'pgrep');
  if (isKill(el)) {
    if (r.args.some(subsHavePgrepFull)) deny(ctx, 'pgrep');
    else if (ctx.taint.size && r.argv.some((t) => refsVar(t, ctx.taint))) deny(ctx, 'pgrep');
  }
  if (r.name) checkDevice(toolName(r.name), r.argv, ctx, el);
}

// ---------------------------------------------------------------- devices and memory

// `adb.exe`, `C:\sdk\platform-tools\adb.exe` and `flutter.bat` are adb and flutter too.
const toolName = (name) => name.slice(name.lastIndexOf('\\') + 1).replace(/\.(exe|bat|cmd)$/i, '');
const FLUTTER_ARGS = new Set(['-d', '--device-id', '--local-engine', '--local-engine-src-path', '--local-engine-host',
  '--local-web-sdk', '--wrap-column']);
const SETTINGS_WRITES = new Set(['put', 'delete', 'reset']);
const GRADLE = new Set(['gradlew', 'gradle']);
const firstPositional = (a, withArg = new Set()) => a[skipOptions(a, 0, withArg)];
const NOT_A_PHONE = new Set(['chrome', 'edge', 'web-server', 'linux', 'macos', 'windows']);
// The devices a flutter command names: `-d <id>`, `-d<id>`, `--device-id <id>` or `--device-id=<id>`.
function deviceIds(a) {
  const ids = [];
  for (let k = 0; k < a.length; k++) {
    const t = a[k];
    if (t === '-d' || t === '--device-id') ids.push(a[++k] || '');
    else if (t.startsWith('--device-id=')) ids.push(t.slice('--device-id='.length));
    else if (/^-d[^-]/.test(t)) ids.push(t.slice(2));
  }
  return ids;
}

// An emulator's serial is `emulator-<port>`; a phone's never is.
const isEmulator = (serial) => /^emulator-\d+$/.test(serial);

// True when an adb command names an emulator: by every `-s`, else by ANDROID_SERIAL set right before adb.
// adb reads ANDROID_SERIAL only without -s, -d and -e, and sudo or another wrapper may drop it on the way.
// -t picks a device by its transport id, over any serial.
function adbOnEmulator(cmd) {
  const r = resolve(cmd);
  const a = r.argv;
  const serials = [];
  let byKind = false; // -d (the USB device) or -e (the TCP one)
  for (let k = 0; k < a.length && a[k].startsWith('-') && a[k] !== '--'; k += ADB_ARGS.has(a[k]) ? 2 : 1) {
    if (a[k].startsWith('-t')) return false;
    if (a[k] === '-s') serials.push(a[k + 1] || '');
    if (a[k] === '-d' || a[k] === '-e') byKind = true;
  }
  if (serials.length) return serials.every(isEmulator);
  const adbIsFirst = cmd.words.length === r.args.length + 1; // no sudo, env or other wrapper before it
  if (byKind || !adbIsFirst) return false;
  const set = 'ANDROID_SERIAL=';
  const fromEnv = cmd.assigns.filter((w) => w.text.startsWith(set)).map((w) => w.text.slice(set.length));
  return fromEnv.length > 0 && fromEnv.every(isEmulator);
}

// A write to the phone's apps, data or settings: denied unless the owner allowed it with DEVICE_WRITE_OK=1.
// On an emulator the command names, it runs freely: an emulator holds no one's real data.
function deviceWrite(ctx, onEmulator) {
  if (onEmulator) return;
  if (ctx.deviceOk) ctx.notes.add('device-write');
  else deny(ctx, 'device');
}

function checkDevice(name, a, ctx, cmd) {
  if (ctx.remote) { // runs on the phone, through `adb shell`
    const sub = firstPositional(a, new Set(['--user']));
    if ((name === 'pm' && (sub === 'clear' || sub === 'uninstall'))
      || (name === 'settings' && SETTINGS_WRITES.has(sub))
      || (name === 'cmd' && a[0] === 'package' && (a[1] === 'clear' || a[1] === 'uninstall'))
      || (name === 'cmd' && a[0] === 'settings' && SETTINGS_WRITES.has(a[1]))) deviceWrite(ctx, ctx.emulator);
    return;
  }
  if (name === 'adb') {
    const sub = a[adbCommand(a)];
    if (sub === 'uninstall') deviceWrite(ctx, adbOnEmulator(cmd));
    if (sub === 'install' || sub === 'install-multiple' || sub === 'install-multi-package') ctx.notes.add('device');
    return;
  }
  if (name === 'flutter') {
    const j = skipOptions(a, 0, FLUTTER_ARGS);
    const sub = a[j];
    const rest = a.slice(j + 1);
    // `flutter install` removes an installed copy before it installs: the app's local data goes with it.
    // Flutter takes its device from -d alone (never ANDROID_SERIAL), the last one given: each must be an emulator.
    if (sub === 'install') {
      const ids = deviceIds(a);
      const onEmulator = ids.length > 0 && ids.every(isEmulator);
      deviceWrite(ctx, onEmulator);
      if (onEmulator) ctx.notes.add('device');
    }
    // On the web or the desktop it only takes memory; anywhere else it takes a phone or an emulator.
    // A drive ends like a build; a run holds its memory until it is stopped, so it never goes in the queue.
    if (sub === 'run' || sub === 'drive') {
      const where = NOT_A_PHONE.has(deviceIds(a)[0]) ? 'memory' : 'device';
      ctx.notes.add(where === 'memory' && sub === 'run' ? 'run' : where);
    }
    if (sub === 'test' && rest.some((t) => /^(\.\/)?integration_test(\/|$)/.test(t))) ctx.notes.add('device');
    if (sub === 'build') ctx.notes.add('memory');
    if (sub === 'emulators' && rest.some((t) => t === '--launch' || t.startsWith('--launch='))) {
      ctx.notes.add('emulator');
    }
    if (sub === 'clean') ctx.notes.add('clean');
    return;
  }
  if (name === 'emulator') {
    if (a.some((t) => t === '-avd' || t.startsWith('@'))) ctx.notes.add('emulator');
    return;
  }
  if (GRADLE.has(name)) {
    const tasks = a.filter((t) => !t.startsWith('-')).map((t) => t.slice(t.lastIndexOf(':') + 1));
    if (tasks.some((t) => /^uninstall/i.test(t))) deviceWrite(ctx);
    if (tasks.some((t) => /^install/i.test(t))) ctx.notes.add('device');
    if (tasks.some((t) => /^(assemble|bundle|build|install)/i.test(t))) ctx.notes.add('memory');
    return;
  }
  if (name === 'q-build.sh') ctx.notes.add('memory');
  // `q-test.sh -d <serial> <file>` runs an integration test: it installs and drives the app on that device.
  if (name === 'q-test.sh' && a.includes('-d')) ctx.notes.add('device');
}

// DEVICE_WRITE_OK from the environment, else from the project's scripts/tools/tools.env (the folder where Claude
// Code started, then the command's folder). An assignment inside the command itself never counts.
function deviceWriteOk(env, payload) {
  const v = env.DEVICE_WRITE_OK;
  if (v !== undefined && v !== '') return v === '1';
  for (const dir of [env.CLAUDE_PROJECT_DIR, typeof payload.cwd === 'string' ? payload.cwd : '']) {
    if (!dir) continue;
    let text;
    try { text = readFileSync(join(dir, 'scripts', 'tools', 'tools.env'), 'utf8'); } catch { continue; }
    const m = text.match(/^[ \t]*:[ \t]*["']?\$\{DEVICE_WRITE_OK:?=([^}"'\s]*)\}/m)
      || text.match(/^[ \t]*(?:export[ \t]+)?DEVICE_WRITE_OK=["']?([^"'\s#;]*)/m);
    return Boolean(m) && m[1] === '1';
  }
  return false;
}

// ---------------------------------------------------------------- output

const KILL_BY_PID = [
  'Kill by PID instead, never by name:',
  '1. Find the PID. The process on a port: `ss -lptn "sport = :<port>"` (macOS: `lsof -nP -iTCP:<port> -sTCP:LISTEN`).',
  '   A process by its arguments: list `ps -eo pid=,args=` inside a script file and match there, skipping your own',
  '   PID and its parent.',
  '2. Check its working directory: `readlink /proc/<pid>/cwd` (macOS: `lsof -a -d cwd -p <pid>`).',
  '   Leave it alone when it belongs to another project or to the editor.',
  '3. Then `kill <pid>`.',
  'Idle Gradle daemons stop with `./gradlew --stop` in `android/`; the RAM plugin\'s `ram.sh free` stops idle build',
  'daemons and orphaned test runners.',
  "Never `pkill <name>`, `pkill -x <name>` or `killall <name>`: a name also matches other projects' processes",
  "and the editor's own helpers.",
].join('\n');

const REASONS = {
  pkill: [
    'Blocked: `pkill -f` matches the pattern against the full command line of every process.',
    'The shell that runs this command has the same pattern in its own command line, so pkill kills this very call',
    '(exit 144) and the commands after it never run.',
    KILL_BY_PID,
  ].join('\n'),
  pgrep: [
    'Blocked: these PIDs come from `pgrep -f`, which matches the full command line of every process.',
    'The shell that runs this command has the same pattern in its own command line, so the list includes that shell,',
    'and the kill ends this very call (exit 144) before the commands after it run.',
    KILL_BY_PID,
  ].join('\n'),
  device: [
    'Blocked: this command removes an app, clears an app\'s data or changes a setting on a phone or emulator',
    '(`adb uninstall`, `adb shell pm clear`, `pm uninstall`, `settings put`, a Gradle uninstall task, or',
    '`flutter install`, which removes an installed copy before it installs). The device may be the owner\'s own',
    'phone: the app\'s local data dies with it, and the settings are theirs.',
    'Ask the owner first, in one short question that says what it deletes. Only the owner allows it, never you:',
    'they set DEVICE_WRITE_OK=1 in scripts/tools/tools.env or in the environment, then you run the command again.',
    'An emulator needs no yes when the command names its serial, as in `adb -s emulator-5554 ...`,',
    '`flutter install -d emulator-5554` or `ANDROID_SERIAL=emulator-5554 adb ...` (`adb devices -l` lists them).',
    'To put a new build on the phone and keep its data, use `flutter run` or `adb install -r <apk>`: both keep the',
    'data while the signing key stays the same.',
  ].join('\n'),
};

// Claude reads these notes with the command's result, so they state what happened and what comes next.
const NOTES = {
  'device-write': [
    'Device note: this command removes an app, clears its data or changes a setting on a phone or emulator.',
    'DEVICE_WRITE_OK=1 allows it: the owner set it. When this job is done, tell the owner what it removed and',
    'remind them to set DEVICE_WRITE_OK back to 0 in scripts/tools/tools.env.',
  ].join('\n'),
  device: [
    'Device note: this command installs, runs or drives the app on a phone or emulator. The owner\'s phone is',
    'theirs: only with the owner\'s yes (or a rule in docs/DECISIONS.md), and never while the owner tests on it.',
    'When the copy on the phone was signed with another key (a store or release build), the install fails or',
    '`flutter run` removes that copy first, and its local data is lost: ask before a debug build goes over a',
    'release one. The owner saw a one-line warning when it started. The project rule is to say it in the message',
    'before the command.',
  ].join('\n'),
  memory: [
    'Memory note: this command starts a build, which can take several GB of memory for minutes.',
    'Run one at a time on the machine, through the queue (`scripts/tools/q-build.sh`, which uses the RAM plugin\'s',
    '`ram.sh run` when it is installed), never while other agents run their checks. The owner saw a one-line',
    'warning when it started. The project rule is to say it in the message before the command.',
  ].join('\n'),
  // Not the queue: a run lives until it is stopped, and a queued one would block every other job all that time.
  run: [
    'Run note: `flutter run` builds the app, then holds several GB until it is stopped. Never queue it (a queued',
    'run holds the queue and the folder lock for its whole life): start it when `scripts/tools/q-status.sh` shows',
    'nothing heavy, detached with its output in `runs/` (the device playbook), and stop it by its PID when done. The',
    'owner saw a one-line warning when it started. The project rule is to say it in the message before the command.',
  ].join('\n'),
  // Not the queue: no queued tool runs an emulator, and a queued one would block every other job while it runs.
  emulator: [
    'Emulator note: an emulator takes 2 to 4 GB for as long as it runs. Start it only on the owner\'s yes, when',
    '`scripts/tools/q-status.sh` shows nothing heavy, detached and outside the queue (a queued emulator holds the',
    'queue and the folder lock for its whole life). Close it after: `adb -s <serial> emu kill`.',
  ].join('\n'),
  clean: [
    'flutter clean note: it deletes build/ and .dart_tool/. Never run it while other agents work: their analyzer and',
    'tests lose their files, and the next build or test run starts from nothing.',
  ].join('\n'),
};

// Shown to the owner as the command starts: one line.
const WARNINGS = {
  'device-write': 'Device: this command removes an app, its data or a setting on a phone (DEVICE_WRITE_OK=1).',
  device: 'Device: this command installs or runs the app on a phone or emulator.',
  memory: 'Memory: this command starts a build, which can take several GB.',
  run: 'Memory: this command builds the app and runs it until it is stopped, which can take several GB.',
  emulator: 'Emulator: this command starts an emulator, which takes 2 to 4 GB while it runs.',
};
const TOPICS = ['device-write', 'device', 'memory', 'run', 'emulator', 'clean'];
// Cheap first test: a command that names none of these needs no parsing.
const WORTH_A_LOOK = /pkill|pgrep|adb|flutter|emulator|gradle|q-build|q-test/;

function decide(payload, env) {
  if (!payload || typeof payload !== 'object') return null;
  // On Windows, Claude Code may run shell commands through its PowerShell tool instead of Bash.
  if (payload.tool_name && payload.tool_name !== 'Bash' && payload.tool_name !== 'PowerShell') return null;
  const command = payload.tool_input && payload.tool_input.command;
  if (typeof command !== 'string' || !command.trim() || command.length > MAX_INPUT) return null;
  if (!WORTH_A_LOOK.test(command)) return null;
  const deviceOk = deviceWriteOk(env, payload);
  const ctx = { deny: null, taint: new Set(), notes: new Set(), remote: false, emulator: false, deviceOk };
  analyze(parseString(command, 0), ctx);
  if (ctx.deny) {
    return {
      hookSpecificOutput: {
        hookEventName: 'PreToolUse', permissionDecision: 'deny', permissionDecisionReason: REASONS[ctx.deny],
      },
    };
  }
  const topics = TOPICS.filter((t) => ctx.notes.has(t));
  if (!topics.length) return null;
  // Never a decision here: a note for Claude, plus a one-line warning for the owner when a device or memory is taken.
  const additionalContext = topics.map((t) => NOTES[t]).join('\n');
  const out = { hookSpecificOutput: { hookEventName: 'PreToolUse', additionalContext } };
  const warnings = topics.map((t) => WARNINGS[t]).filter(Boolean);
  if (warnings.length) out.systemMessage = warnings.join(' ');
  return out;
}

let input = '';
process.on('uncaughtException', () => { process.exitCode = 0; });
process.stdin.setEncoding('utf8');
process.stdin.on('data', (d) => { input += d; });
process.stdin.on('error', () => { process.exitCode = 0; });
process.stdin.on('end', () => {
  try {
    const out = decide(JSON.parse(input), process.env);
    if (out) process.stdout.write(JSON.stringify(out));
  } catch {
    // Print nothing: a bug in this guard must never block or break a command.
  }
  process.exitCode = 0;
});
