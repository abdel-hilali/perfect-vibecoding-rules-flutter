---
name: multi-agent
description: Runs several AI builder agents in one Flutter working tree without losing work and without wasting tokens - disjoint file ownership, one owner per wave for shared registration files (the router, a module, the ARB catalogs, pubspec.yaml), frozen interfaces, no destructive git or tree-wide format, one queued analyzer or test at a time, small lean packages, reports from the start, md5 and ownership sweeps, and recovery of an interrupted wave. Use when planning a wave, writing builder briefs, launching agents that write code in parallel, or when a wave stopped half way.
---

# Several builders in one working tree

Parallel builders share one uncommitted tree. There is no safety net: one wrong command destroys the others' work.
These rules keep a wave safe, cheap to check and easy to resume. Give every builder `docs/BUILDER-RULES.md`: it
holds the same rules, from the builder's side.

## The rules

1. **Disjoint ownership.** Each brief lists the exact files its builder may write. Two builders never own the same
   file. Anything else a builder needs goes in its report under "Needs from others": the file, the exact text, why.
2. **Shared registration files get ONE owner per wave:** `lib/core/router/app_router.dart`, a module in
   `lib/core/config/injection-modules/`, the ARB catalogs (`lib/core/l10n/*.arb`, every locale together),
   `pubspec.yaml` (and its lock). A file several waves need is handed on in a fixed order, one owner at a time.
3. **Interfaces land first, then freeze.** Entities, repository interfaces, use case signatures, route paths
   (`static const path`), catalog keys and theme tokens are written and checked before the builders that use them
   start. After that: add, never change. Never remove or narrow a class, a member or a catalog key another file reads.
4. **No destructive git, no tree-wide rewrite.** Never `git checkout`, `switch`, `stash`, `restore`, `reset`,
   `clean`, `add`, `commit`, `mv` or `rm`. Never `flutter clean` (it deletes `build/` and `.dart_tool/` under every
   other agent), `dart format .`, `dart fix --apply` or `flutter pub upgrade`. Read-only git is fine.
5. **One heavy check at a time.** Nobody calls `flutter analyze`, `dart analyze` or `flutter test` directly while
   builders run. Use `scripts/tools/q-analyze.sh` and `scripts/tools/q-test.sh <test files>`: they wait in line and
   for free memory. Test FILES only, never a folder or the suite.
6. **Builders stay off shared resources.** No build, no `flutter run`, no emulator, no device, no whole suite,
   nothing on the network. A new dependency needs the owner's yes; the orchestrator runs `flutter pub get` once,
   queued, before the builders that need it start.
7. **Absolute, unique backup paths.** Each package backs up into its own absolute folder, for example
   `<project>/runs/<topic>/backups/<package>/`. A relative path resolves against the agent's current folder.
8. **Reports on disk from the start.** Each builder creates its report at the START (title and a five-line plan) and
   appends as it goes. A stop then keeps what was done.
9. **A refused tool call:** wait 30 seconds, retry once, then go on without it and say so in the report.

## Keep each agent cheap

Measured: subagents cost 4 to 6 times the main session (125 to 195 calls each at about 210K tokens of context), and
every call re-sends the whole context. So:

- Small packages: at most about 8 files, done in at most about 60 tool calls. Bigger work is two packages.
- The brief gives the exact paths and what to read (a section, a line range): nothing left to discover.
- Grep before reading; a file over 400 lines by line ranges, never whole; never re-read a file already read.
- Cap tool output (`| tail -n 40`; `q-test.sh` prints failures only). No images or PDFs unless the brief says.
- Read-only searches go to a search-type agent. Never spawn an agent for what three tool calls do.
- One review round, at most three lanes, unless the owner buys more.
- Agents use the session's model, never a more expensive one without the owner's yes.

## Plan a wave

1. Give the owner the cost first (tokens per option, your recommendation first) and wait for the word.
2. Write the plan in `runs/<topic>/`: the ownership rules, the frozen interfaces table, and each package with its
   files (new and changed), what it builds and its tests. Use the form in [wave-plan.md](wave-plan.md).
3. Check that ownership is disjoint: each file appears in at most one list of the wave.
4. New interfaces land first: one builder (or a first wave) writes them, its checks pass, then they freeze.
5. Each brief names: the package id, its files, what to read, the absolute report path, the absolute backup
   folder, the result keys below, and `docs/BUILDER-RULES.md`.
6. Launch the builders. Keep the launch script in `runs/<topic>/`. While they run, keep
   `scripts/tools/wait-milestone.sh <journal.jsonl> 1200 <reports...>` running in the background: it returns on the
   next finished agent or after 20 minutes. Update the owner at each return, then start it again.

Worktrees only when two packages must touch the same files. Each one costs a `pub get`, a `build/` folder and an
analyzer of its own; put it outside the project folder (the editor watches and indexes what is inside) and remove it
when its work is merged.

## What every builder returns

A **report** at the path its brief gives: per item done, partial or skipped, and why · files changed, created and
deleted · deviations and why · **Needs from others** (file, exact text, why) · **Device checks for later** (what a
run on a phone must prove; builders never run on a device) · **Where the owner sees it** (screen, account, build or
device, what the owner sees, what not to tap) · each check with real numbers · the md5 of each file it wrote.

A **structured result** with the same keys for every builder: `files_changed`, `files_created`, `files_deleted`,
`touched_outside_list` (each with a reason), `checks`, `needs_from_others`, `deviations`, `report`. The ownership
sweep reads the first four. The full shape is in `docs/BUILDER-RULES.md`, section 6.

## After the wave

1. **md5 sweep, the moment the wave lands.** Compare each file's md5 with the md5 its owner reported. A different
   sum means another agent wrote the file after its owner finished: read the diff and keep the right version.
2. **Finish pass.** Assume the wave is half applied. Verify each item of each brief against the tree as it is now,
   finish what is missing, apply the "Needs from others" (the catalog keys, the routes, the module lines). One
   agent, owning every file the wave touched, in its own run with its own journal.
3. **Ownership sweep.** `python3 -I scripts/tools/sweep-owners.py <journal.jsonl>...`, with the journal of EVERY
   run since the last commit. Every changed path must be claimed by exactly one agent. Unclaimed: someone wrote
   outside its list, or a journal is missing (your own edits to the record show too: name them).
4. Then one review round, fixes per package, and the full gate once, right before a push
   (`/perfect-vibecoding-rules-flutter:gate`, or `docs/playbooks/gate/SKILL.md`). No build and no suite between
   stages. The commands for both sweeps are in [wave-plan.md](wave-plan.md).

## Recover an interrupted wave

A crash, a power cut or a stop mid-wave leaves files half edited. Snapshot first (`git diff HEAD --binary` and a tar
of the untracked files, into `runs/<topic>/backups/`); fix syntax errors first (a half-written method makes the
analyzer report a cascade of false errors); regenerate generated files (`flutter gen-l10n`); hunt "new line added,
old line not removed" (duplicate ARB keys still parse: `check_l10n.dart` finds them); then finish, review, fix. Step
by step, with commands: [recovery.md](recovery.md).

In Claude Code: builders are subagents or workflow agents. Give each the result keys above as its output schema. A
workflow run writes its events to a `journal.jsonl` in the session's `subagents/workflows/<run>/` folder under
`~/.claude/projects/`: that is the file `wait-milestone.sh` and `sweep-owners.py` read. Copy the workflow script
into `runs/<topic>/` right after launch: a new session cannot resume an old run, only relaunch it. Run the waiter
with the Bash tool's background option, so its exit wakes you. The token guard stays quiet inside subagents (a
builder finishes its brief; only the lead session hands off). The plugin's Bash hook blocks `pkill -f`.
