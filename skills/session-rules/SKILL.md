---
name: session-rules
description: Keeps long AI-assisted work cheap and resumable across sessions, crashes and restarts - when to change session (every stage boundary, and at the next clean point once the context passes about 200K tokens), the record in docs/HANDOFF.md, docs/PROGRESS.md and docs/LOG.md, where scripts, reports and backups live, what "stop everything" means, and saving every chat. Use when a stage or wave ends, the context is large or the token guard speaks, before the gate, after a push, at the end of a day, on "change session", "stop everything", "where were we", or after a crash or power cut.
---

# Session rules

The rules first. The details follow.

1. **Change session at every stage boundary, and at the next clean point once the context passes about 200K
   tokens**, whichever comes first. Write the handoff, confirm nothing runs, then say it first, unasked: "This is a
   session boundary. The handoff is written. Open a new session." Mid-wave is not a clean point.
2. **The record is three files.** `docs/HANDOFF.md` is the current state, rewritten whole at each boundary; a new
   session reads it whole, first. `docs/PROGRESS.md` is the plan and the decisions. `docs/LOG.md` is the history,
   append-only, never read whole. The owner's product decisions go in `docs/DECISIONS.md`.
3. **Everything that must survive lives in the project**, under `runs/<topic>/`. Never only in `~/.claude` or `/tmp`.
4. **"Stop everything" means at once:** stop the agents and the heavy jobs, back up the uncommitted tree, write the
   handoff. Nothing else.
5. **Save every chat:** the owner's words and every decision go in `docs/LOG.md`, and the transcripts are copied
   into the project.

## 1. Session boundaries

A boundary is: a wave (a batch of agents launched together) lands, a review round ends, right before the full gate,
right after a push or a release, the end of a day, and the first clean point after the context passes about 200K
tokens. A clean point: no agent running, no heavy job of yours running, the handoff written.

At a boundary, in this order:

1. Copy the old `docs/HANDOFF.md` to the end of `docs/LOG.md`, under a heading with the time from `date`. Then
   rewrite the handoff whole: the state, what runs, what is open for the owner, NEXT in order, what to read next, a
   paste-ready prompt.
2. Confirm nothing runs: agents, queued jobs (`scripts/tools/q-status.sh`), a build, an emulator or a `flutter run`
   you started. Name anything you leave running on purpose, and why. The owner's own `flutter run` is theirs.
3. Say it first, without being asked: "This is a session boundary. The handoff is written. Open a new session."

**The context budget.** Measured on real projects: sessions ran to a median of 420K tokens of context per call, and
85% of their tokens were spent above 300K, because every call re-sends the whole context. A handoff and a new
session cost a few thousand tokens once. So once the context passes about 200K tokens, finish the step in hand,
reach the next clean point, and hand off.

- **Mid-wave is not a clean point.** If builders are running and the owner asks to switch, answer "not yet: when
  the wave lands, at about HH:MM". Switching now abandons the running agents. Past the budget mid-wave, keep the
  handoff current and change session the moment the wave lands.
- Keep the handoff resumable at all times anyway: the owner may close the session at any moment. A compaction (the
  tool summarizing the chat to go on) is not a handoff: it keeps a summary and loses what the next step needs.
- **The full gate never runs in the session that built the batch.** A fresh session reads the record and judges the
  work cold (`/perfect-vibecoding-rules-flutter:gate`, or `docs/playbooks/gate/SKILL.md`).
- **A new session cannot resume an old session's workflow run or its agents.** Relaunch the missing stages from the
  script saved in `runs/<topic>/` and the reports on disk. Tell each relaunched agent: "half applied: verify each
  item against the tree, finish what is missing".

## 2. The record

| File | Holds | How to read it |
| --- | --- | --- |
| `docs/HANDOFF.md` | The current state only, at most 80 lines: state, runs or not, open for the owner, NEXT, read next, the prompt. | Whole, first, at every session start. |
| `docs/PROGRESS.md` | The plan and the decisions: §0 state, §1 the brief verbatim, §1b the owner's decisions that shape the plan, §2 rules, §3 stages, §4 open questions, §5 screens, §6 asks, risks, traps. Never a log. | Only the sections the handoff names. |
| `docs/LOG.md` | The history, newest last: the owner's words verbatim, decisions and their reasons, launches and their cost, what landed, checks with real numbers, the old handoffs. | Never whole: `tail -n 60 docs/LOG.md`, or `grep -n` and then a line range. |
| `docs/DECISIONS.md` | The owner's product decisions, numbered, one line each with the date and the owner's words. | `grep -n -i '<word>' docs/DECISIONS.md` before you ask the owner anything. |

Rules for every entry:

- **Clock times come from `date`, never from an estimate.** The next session orders events by them, and guessed
  times drift by most of an hour.
- **Update in place, the day a stage lands.** The handoff never lags behind the tree.
- **The log only grows.** Never edit an old entry: a correction is a new entry that names the old one. Over 1,500
  lines, the older part moves to `docs/log/LOG-<YYYY-MM>.md`.
- **Point, never copy.** The handoff names the PROGRESS sections and the LOG headings to read; it never repeats
  them. A handoff over 80 lines has become a log: move the history out.

An older project may keep its handoff on top of `docs/PROGRESS.md` and its log at the end: at the next boundary,
move them into `docs/HANDOFF.md` and `docs/LOG.md`. A good handoff, in full: [handoff-example.md](handoff-example.md).

## 3. Survive restarts

Power cuts, reboots, a wiped home folder and killed sessions all happen. Plan for them.

- Run long processes detached, with output in a file:
  `setsid nohup <command> > runs/<topic>/<name>.log 2>&1 < /dev/null &` (macOS has no `setsid`: `nohup ... &`,
  then `disown`). A reboot still stops them: restart them after one, an emulator included.
- Keep scripts, workflow scripts, briefs, reports, logs and backups in `runs/<topic>/` inside the project.
  `~/.claude` and `/tmp` can vanish (on some machines `/tmp` lives in memory and dies with every reboot). `runs/`
  is ignored by git, so copy what matters elsewhere too.
- **Each agent creates its report at the START** (title and plan), then appends each finding as it goes. "Write the
  report before returning" is too late: an agent stopped mid-way leaves nothing behind.
- **Copy each workflow script into `runs/<topic>/` right after you launch it.**
- After a crash, read `git status`, the file dates and the reports before you assume work is lost. An agent cut
  mid-way keeps its file edits and loses only its final answer. A half-written generated file: run
  `flutter gen-l10n` again.

## 4. "Stop everything"

It means now, all of it, and nothing else:

1. Stop the agents and the heavy jobs at once: queued analyzers and tests, a build, a `flutter run` or an emulator
   you started (`adb -s <serial> emu kill`). Kill by PID, never by name: list `ps -eo pid=,args=`, match the
   arguments, check the working directory (`/proc/<pid>/cwd` on Linux, `lsof -a -d cwd -p <pid>` on macOS), then
   `kill <pid>`. Never `pkill -f`, `pkill <name>` or `killall`. The owner's IDE and their own `flutter run` stay.
2. Back up the uncommitted tree, with absolute paths: a relative one lands in whatever folder you are in, and
   misses the files above it. In a monorepo the project is the app's folder, not the repo root.

   ```bash
   P="<project>"   # the project folder, absolute: where AGENTS.md and runs/ sit
   R="$(git -C "$P" rev-parse --show-toplevel)"; B="$P/runs/<topic>/backups/stop-$(date +%Y%m%d-%H%M)"; mkdir -p "$B"
   git -C "$R" diff HEAD --binary > "$B/tracked.diff"
   git -C "$R" ls-files --others --exclude-standard -z | tar -C "$R" --null -T - -czf "$B/untracked.tgz"
   ```

3. Write the handoff, with the backup path.

Do not run a last check "to be sure". Do not start anything new. To restore, on the same commit, from the repo root
(`$R`): `git apply "$B/tracked.diff"` and `tar -xzf "$B/untracked.tgz"`.

## 5. Save every chat

- **The record:** `docs/LOG.md` keeps the owner's words verbatim and every decision. This works with any AI tool.
- **The transcripts:** keep a copy of each session's full chat inside the project, in a folder that git ignores. If
  your tool can export its chat history, export it there.
- **Privacy:** transcripts are plain text and can hold secrets (tokens, passwords, private data). Give the folder its
  own `.gitignore` holding `*`, so it ignores itself in git. Never commit it, never share it, never paste from it. A
  copy made without git (a zip for a reviewer, a cloud build upload) ignores `.gitignore`: leave `claude-chats/` and
  `runs/` out of it.

In Claude Code: the `perfect-vibecoding-rules-flutter` plugin's token-guard hook gives you a note, and the owner a
one-line message, when the context passes the budget (option `context_budget_k`, default 200; again at every half
budget more; quiet inside subagents; 0 turns it off): hand off at the next clean point. Its save-chat hook does the
copying, each time Claude finishes a reply, before each compaction and at session end. It copies
`<session-id>.jsonl` first, then the session's folder of subagent transcripts and tool results, only the files that
changed, into `claude-chats/` (mode 700, with a `.gitignore` holding `*`), and logs one line per run in
`claude-chats/copies.log`. Options: `save_chats` (default on) and `chats_dir` (default `claude-chats`, relative to
the project; an absolute path, `..`, `~` or a variable such as `$HOME` falls back to the default). Change them in
`/config`, or in `/plugin` > Installed > Configure options. Claude Code deletes its own transcripts after
`cleanupPeriodDays` (30 days by default): set `{ "cleanupPeriodDays": 3650 }` in `~/.claude/settings.json` (0 is
not accepted). The example file is `${CLAUDE_SKILL_DIR}/handoff-example.md`.
