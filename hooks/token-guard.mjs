#!/usr/bin/env node
// token-guard: tells Claude (and the owner) when the session's context passes its budget, so the work
// moves to a fresh session at the next clean point instead of paying for a huge context on every call.
// Wired on UserPromptSubmit and PostToolUse. Reads the hook JSON on stdin.
//
// Why: every model call re-sends the whole context. Measured on real projects, sessions that ran to
// 400K-900K tokens spent most of their tokens in those late calls; a handoff and a new session cost a
// few thousand tokens once.
//
// Rules this file keeps:
// - Silent below the budget: no output, so it costs no tokens.
// - One notice per step (the budget, then every half budget more), per session. The state file is shared
//   by every plugin that ships this hook, and one marker folder per step lets only one copy speak, so two
//   kits never say it twice.
// - Never blocks, never fails the call: any error ends it quietly with exit 0.
// - Quiet inside subagents: a subagent finishes its brief; only the lead session hands off.
//
// Options:
//   CLAUDE_PLUGIN_OPTION_CONTEXT_BUDGET_K  the budget in thousands of tokens (default 200; 0 or off = disabled)
//   TOKEN_GUARD_BUDGET_K                   the same, for use without the plugin
//   TOKEN_GUARD_STATE_DIR                  where the per-session state lives (tests)

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const TAIL_BYTES = 768 * 1024;
const POST_TOOL_EVERY_MS = 20 * 1000;
const OFF = new Set(["0", "off", "false", "no"]);
const USAGE = "usage: echo '<hook JSON>' | node token-guard.mjs   (a Claude Code hook: UserPromptSubmit, PostToolUse)";

process.on("uncaughtException", () => process.exit(0));
process.on("unhandledRejection", () => process.exit(0));

function budgetK() {
  const raw = (process.env.CLAUDE_PLUGIN_OPTION_CONTEXT_BUDGET_K ?? process.env.TOKEN_GUARD_BUDGET_K ?? "").trim();
  if (raw === "") return 200;
  if (OFF.has(raw.toLowerCase())) return 0;
  const n = Number(raw);
  return Number.isFinite(n) && n > 0 ? n : 200;
}

function readStdin() {
  try {
    return JSON.parse(fs.readFileSync(0, "utf8"));
  } catch {
    return null;
  }
}

// The context size of the last model call: its input, cache writes and cache reads together.
export function lastContextTokens(file) {
  const size = fs.statSync(file).size;
  const start = Math.max(0, size - TAIL_BYTES);
  const fd = fs.openSync(file, "r");
  try {
    const buf = Buffer.alloc(size - start);
    fs.readSync(fd, buf, 0, buf.length, start);
    const lines = buf.toString("utf8").split("\n");
    for (let i = lines.length - 1; i >= 0; i--) {
      const line = lines[i];
      if (!line.includes('"usage"') || !line.includes('"assistant"')) continue;
      let o;
      try {
        o = JSON.parse(line);
      } catch {
        continue; // the first line of the tail is usually cut
      }
      const u = o?.message?.usage;
      if (o?.type !== "assistant" || !u) continue;
      return (u.input_tokens ?? 0) + (u.cache_creation_input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0);
    }
  } finally {
    fs.closeSync(fd);
  }
  return 0;
}

// Steps: 1.0, 1.5, 2.0, ... times the budget. 0 below the budget.
export function stepFor(tokens, budget) {
  if (budget <= 0 || tokens < budget) return 0;
  return Math.floor((tokens / budget) * 2) / 2;
}

function stateFile(sessionId) {
  const dir = process.env.TOKEN_GUARD_STATE_DIR || path.join(os.tmpdir(), `token-guard-${os.userInfo().uid}`);
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
  return path.join(dir, `${String(sessionId).replace(/[^A-Za-z0-9_-]/g, "_")}.json`);
}

function readState(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return { step: 0, checked: 0 };
  }
}

function main() {
  if (process.argv.length > 2) {
    console.error(USAGE);
    process.exit(2);
  }
  const input = readStdin();
  if (!input || typeof input !== "object") return;
  if (input.agent_id || input.agent_type) return; // a subagent's call
  const event = input.hook_event_name;
  if (event !== "UserPromptSubmit" && event !== "PostToolUse") return;
  const budget = budgetK() * 1000;
  if (budget <= 0 || !input.session_id || typeof input.transcript_path !== "string") return;

  const sfile = stateFile(input.session_id);
  const state = readState(sfile);
  const now = Date.now();
  if (event === "PostToolUse" && now - (state.checked ?? 0) < POST_TOOL_EVERY_MS) return;
  state.checked = now;

  const tokens = lastContextTokens(input.transcript_path);
  const step = stepFor(tokens, budget);
  if (step <= (state.step ?? 0)) {
    fs.writeFileSync(sfile, JSON.stringify(state));
    return;
  }
  state.step = step;
  fs.writeFileSync(sfile, JSON.stringify(state));
  // Two kits that ship this hook run it at the same moment and can both read the old step: only the one that
  // creates this step's marker folder speaks (mkdir fails when the folder exists).
  try {
    fs.mkdirSync(`${sfile}.${step}`);
  } catch {
    return;
  }

  const k = Math.round(tokens / 1000);
  const b = Math.round(budget / 1000);
  const note =
    `Context is about ${k}K tokens (budget ${b}K). Every call re-sends it, so each further step of this ` +
    `session costs more than the last. At the next clean point (the current step done, no agent running), ` +
    `write the handoff (docs/HANDOFF.md, the session-rules playbook), confirm nothing runs, then tell the owner: ` +
    `"This is a session boundary. The handoff is written. Open a new session." Never stop mid-step or while ` +
    `agents run. If you are a subagent, ignore this note and finish your brief.`;
  const out = {
    hookSpecificOutput: { hookEventName: event, additionalContext: note },
    systemMessage: `Context about ${k}K tokens (budget ${b}K): Claude hands off at the next clean point; a new session is cheaper.`,
  };
  process.stdout.write(JSON.stringify(out));
}

main();
