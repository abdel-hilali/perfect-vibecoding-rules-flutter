#!/usr/bin/env bash
# Tests for hooks/token-guard.mjs: pipes hook JSON on stdin with a fixture transcript (JSONL lines whose
# message.usage gives the context size), then checks stdout, stderr and the exit code.
# Silent below the budget; one notice per step (the budget, then every half budget more); silent for a subagent;
# silent when the option is off. Writes only inside a mktemp -d folder (the hook's state goes there too).
# Exits 0 only when every case passes.
set -u
if [ "$#" -gt 0 ]; then
  echo "usage: $0   (runs every token-guard case)" >&2
  exit 2
fi
command -v node >/dev/null 2>&1 || { echo "token-guard: node not found" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")" && pwd)"
HOOK="$HERE/../../hooks/token-guard.mjs"
FIX="$HERE/fixtures"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
# The session running these tests may set the hook's options: start from a clean slate.
unset CLAUDE_PLUGIN_OPTION_CONTEXT_BUDGET_K TOKEN_GUARD_BUDGET_K
export TOKEN_GUARD_STATE_DIR="$T/state"

pass=0
fail=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; [ -n "${2:-}" ] && printf '%s\n' "$2" | head -10 | sed 's/^/     | /'; }

# input <event> <session> <transcript> [extra JSON members]: the hook JSON Claude Code sends.
input() {
  printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","hook_event_name":"%s"%s}' "$2" "$3" "$T" "$1" "${4:-}"
}
# hook <input> [VAR=value ...]: runs the hook; stdout in $OUT, stderr in $ERR, exit code in $CODE.
hook() {
  local in=$1
  shift
  printf '%s' "$in" | env "$@" node "$HOOK" >"$T/stdout" 2>"$T/stderr"
  CODE=$?
  OUT="$(cat "$T/stdout")"
  ERR="$(cat "$T/stderr")"
}
# silent <name>: nothing on stdout or stderr, exit 0.
silent() {
  if [ "$CODE" -eq 0 ] && [ -z "$OUT" ] && [ -z "$ERR" ]; then ok "$1"; else bad "$1 (exit $CODE)" "$OUT$ERR"; fi
}
# notice <name> <event> <K> <budget K>: one JSON object naming the size and the budget, for Claude and the owner.
notice() {
  local name=$1 event=$2 k=$3 b=$4
  if [ "$CODE" -ne 0 ] || [ -n "$ERR" ]; then bad "$name (exit $CODE)" "$OUT$ERR"; return; fi
  if printf '%s' "$OUT" | node -e '
    let s = ""; process.stdin.on("data", (d) => (s += d)).on("end", () => {
      const [event, k, b] = process.argv.slice(1);
      const o = JSON.parse(s);
      const h = o.hookSpecificOutput || {};
      const fine = h.hookEventName === event && !("permissionDecision" in h) && !("decision" in o)
        && h.additionalContext.includes(`about ${k}K tokens (budget ${b}K)`) && h.additionalContext.includes("docs/HANDOFF.md")
        && h.additionalContext.includes("If you are a subagent, ignore this note")
        && o.systemMessage === `Context about ${k}K tokens (budget ${b}K): Claude hands off at the next clean point; a new session is cheaper.`;
      process.exit(fine ? 0 : 1);
    });' "$event" "$k" "$b"; then ok "$name"; else bad "$name" "$OUT"; fi
}
# grow <file> <total tokens>: appends one assistant call of that context size, as a session does.
grow() {
  printf '{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"step"}],"usage":{"input_tokens":10,"cache_creation_input_tokens":1000,"cache_read_input_tokens":%s,"output_tokens":50}}}\n' "$(($2 - 1010))" >>"$1"
}

check_syntax() { node --check "$HOOK"; }
if check_syntax; then ok "token-guard.mjs parses"; else bad "token-guard.mjs does not parse"; fi
printf '' | node "$HOOK" extra >"$T/stdout" 2>"$T/stderr"
code=$?
if [ "$code" -eq 2 ] && grep -q '^usage:' "$T/stderr"; then ok "an argument gives the usage line and exit 2"; else bad "an argument: exit $code"; fi

# 1. Below the budget: silent, so it costs no tokens.
hook "$(input UserPromptSubmit below "$FIX/session-150k.jsonl")"
silent "150K, budget 200K: silent"

# 2. Past the budget: one notice; the next call at the same step is silent.
S="$T/steps.jsonl"
cp "$FIX/session-210k.jsonl" "$S"
hook "$(input UserPromptSubmit steps "$S")"
notice "210K, budget 200K: a notice for Claude and a line for the owner" UserPromptSubmit 210 200
grow "$S" 230000
hook "$(input UserPromptSubmit steps "$S")"
silent "230K, the same step: silent"
grow "$S" 310000
hook "$(input UserPromptSubmit steps "$S")"
notice "310K: the next half-budget step, one more notice" UserPromptSubmit 310 200
grow "$S" 320000
hook "$(input UserPromptSubmit steps "$S")"
silent "320K, the same step: silent"
grow "$S" 405000
hook "$(input UserPromptSubmit steps "$S")"
notice "405K: twice the budget, one more notice" UserPromptSubmit 405 200
hook "$(input UserPromptSubmit steps "$S")"
silent "405K again: silent (every kit that ships the hook shares the state, so two never say it twice)"

# 3. A subagent finishes its brief: silent whatever its size.
hook "$(input UserPromptSubmit sub "$FIX/subagent-500k.jsonl" ',"agent_id":"a1","agent_type":"general-purpose"')"
silent "a subagent's call at 500K: silent"
hook "$(input PostToolUse sub2 "$FIX/subagent-500k.jsonl" ',"agent_id":"a1","tool_name":"Bash"')"
silent "a subagent's tool call at 500K: silent"

# 4. The option off, or another budget.
for v in 0 off; do
  hook "$(input UserPromptSubmit "off-$v" "$FIX/subagent-500k.jsonl")" CLAUDE_PLUGIN_OPTION_CONTEXT_BUDGET_K="$v"
  silent "context_budget_k=$v: silent at 500K"
done
hook "$(input UserPromptSubmit budget100 "$FIX/session-150k.jsonl")" CLAUDE_PLUGIN_OPTION_CONTEXT_BUDGET_K=100
notice "context_budget_k=100: a notice at 150K" UserPromptSubmit 150 100
hook "$(input UserPromptSubmit budget300 "$FIX/session-210k.jsonl")" TOKEN_GUARD_BUDGET_K=300
silent "TOKEN_GUARD_BUDGET_K=300 (without the plugin): silent at 210K"
hook "$(input UserPromptSubmit budgetbad "$FIX/session-210k.jsonl")" CLAUDE_PLUGIN_OPTION_CONTEXT_BUDGET_K=lots
notice "a budget that is not a number falls back to 200K" UserPromptSubmit 210 200

# 5. PostToolUse: checked at most every 20 seconds, so a burst of tool calls costs one read.
P="$T/post.jsonl"
cp "$FIX/session-210k.jsonl" "$P"
hook "$(input PostToolUse post "$P" ',"tool_name":"Read"')"
notice "PostToolUse at 210K: a notice" PostToolUse 210 200
grow "$P" 320000
hook "$(input PostToolUse post "$P" ',"tool_name":"Read"')"
silent "PostToolUse again within 20 s, at the next step: silent until the next check"
hook "$(input UserPromptSubmit post "$P")"
notice "...and the next prompt says it" UserPromptSubmit 320 200

# 6. Other events and bad input: silent, exit 0, never a failed call.
hook "$(input Stop stop "$FIX/session-210k.jsonl")"
silent "a Stop event: silent"
hook "not json"
silent "not JSON: silent"
hook "$(input UserPromptSubmit gone "$T/missing.jsonl")"
silent "a transcript that does not exist: silent"
hook '{"hook_event_name":"UserPromptSubmit","session_id":"x"}'
silent "no transcript path: silent"

# 7. A long transcript: only its tail is read, and the size comes from the last assistant call.
L="$T/long.jsonl"
cp "$FIX/session-150k.jsonl" "$L"
pad=$(printf '%0900d' 0)
i=0
while [ "$i" -lt 1500 ]; do printf '{"type":"user","message":{"role":"user","content":"%s"}}\n' "$pad"; i=$((i + 1)); done >>"$L"
grow "$L" 260000
printf '{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"tail"}]}}\n' >>"$L"
hook "$(input UserPromptSubmit long "$L")"
notice "a 1.4 MB transcript: the last call's size, read from the tail" UserPromptSubmit 260 200

# 8. Two kits ship this hook and Claude Code runs both copies at once: one notice, never two.
mkdir -p "$TOKEN_GUARD_STATE_DIR/twokits.json.1"
hook "$(input UserPromptSubmit twokits "$FIX/session-210k.jsonl")"
silent "the other kit's copy already spoke at this step (its marker exists): silent"
doubles=0
i=0
while [ "$i" -lt 10 ]; do
  json="$(input UserPromptSubmit "pair-$i" "$FIX/session-210k.jsonl")"
  printf '%s' "$json" | node "$HOOK" >"$T/pair-a" 2>/dev/null &
  printf '%s' "$json" | node "$HOOK" >"$T/pair-b" 2>/dev/null &
  wait
  [ "$(cat "$T/pair-a" "$T/pair-b" | grep -c additionalContext)" -eq 1 ] || doubles=$((doubles + 1))
  i=$((i + 1))
done
if [ "$doubles" -eq 0 ]; then ok "two copies at once, 10 times: one notice each time"; else bad "two copies at once: $doubles of 10 pairs did not give exactly one notice"; fi

echo
echo "token-guard: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
