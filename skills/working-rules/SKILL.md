---
name: working-rules
description: Rules for working with the project owner - the budget in tokens before any launch, build first and report often, a where-to-look table for the phone (screen, account, which build, what not to tap), short questions with the recommendation first, outside edits judged, conflicts settled with the conception first, one asks file per part for the backend, read-only on a live backend, the owner's phone is theirs, the owner pushes and releases. Use when planning or launching work, reporting progress, asking the owner something, writing to the backend, or preparing a commit or a release.
---

# Working rules

How you work with the owner: their budget, time, attention, data, phone and releases. These rules hold for every
task. Code rules live in `docs/RULES.md`.

## The rules, short

1. **Budget first.** Before you launch agents, give the cost in tokens of each option, your recommendation first,
   then wait for the owner's word. Never let a stage start by itself across a decision.
2. **Build first, never go quiet.** Launch builders before long checks. Update the owner at each stage and at least
   every 20 minutes.
3. **Say where to look.** A UI change comes with a "where to look" table for the phone. Plumbing comes with
   "nothing to see on the phone yet".
4. **Short questions.** One decision each, the recommendation first and marked. "Do the recommended" means take
   every recommended option.
5. **Outside edits are yours to judge.** Find what moved, judge it, keep, correct or undo it with a backup first,
   report. Do not ask who made it.
6. **The conception wins.** Settle a conflict with the backend contract or the design before you build. Never pick
   silently.
7. **One asks file per part.** The backend team gets one self-contained `docs/BACKEND-ASKS-<n>.md`. A sent part is
   never edited.
8. **A live backend may hold real users' data.** Read-only: reads and sign-in. Prove every write on fakes or a test
   project.
9. **Two tiers of checks.** Targeted checks while you work; ONE full gate, right before a push or a release.
10. **The owner's phone and the machine are shared.** Never uninstall, clear data, change settings, install or drive
    the phone without the owner's yes. Say it before a build or an emulator takes gigabytes. Kill by PID only.
11. **The owner pushes and releases.** You prepare the commit message, the changelog entry and the gate.

## 1. Budget before any launch

- The owner sees the usage meter; you do not. Before a launch, say what each option costs, recommendation first,
  and wait. Name the cheapest clean stopping point: the work is whole, the tree builds, nothing runs.
- Measured on real projects: sessions ran to a median of 420K tokens of context per call, and subagents cost 4 to 6
  times the main session (125 to 195 calls each at about 210K). Every call re-sends the whole context, so a task
  costs about its number of calls times its average context. Estimate that way, and measure your own.
- Keep the session lean: grep and line ranges, never a file over 400 lines whole, never re-read a file, cap tool
  output, open images only when needed. Change session at the next clean point once the context passes about 200K
  tokens (`/perfect-vibecoding-rules-flutter:session-rules`). Keep agents cheap
  (`/perfect-vibecoding-rules-flutter:multi-agent`).
- When asked "how much is left?", give what is left before the next boundary, its rough cost and the cheapest clean
  stop. Then wait. When a stop is likely, launch one stage per workflow, so a stop never cuts an agent mid-way.

## 2. Build first, keep the owner updated

- The owner judges progress by files changing and by the app on the phone. A long check with nothing to show reads
  as nothing done. When builders can start, launch them first.
- Update the owner at each stage (first pass, finish, review, fixes, landed) and at least every 20 minutes
  (`scripts/tools/wait-milestone.sh` wakes you). Time estimates are ranges; say so the moment one slips.
- Digest agents' results with a script or a grep, never by reading them whole.

## 3. Show visible changes: where to look

- The owner judges UI work by looking at the phone. If a still screen does not show it, for the owner it did not
  happen. Each UI change gets a table: the screen (and how to reach it), the account, which build, what the owner
  sees, what not to tap (anything that writes real data).
- **Which build**, always named: debug on the owner's phone from their IDE (say: hot reload, hot restart, or a new
  run), an APK file (its absolute path, and whether installing it keeps their data), or the store's internal test
  (the version and build number).
- A state the test account cannot reach (empty, error): say so, and point to the widget test that shows it.
- Plumbing only: "nothing to see on the phone yet; the first visible change comes with <stage>".
- Visible is not loud: the settled design direction still bounds every change.

## 4. Questions

- Short, one decision each. The recommendation first, marked "(recommended)", each option with its cost.
- Grep `docs/DECISIONS.md` first: the owner may have answered it. Each answer becomes a numbered line there, with
  the date and the owner's words.
- Read terse messages for intent. Reply plainly: short sentences, concrete next steps, no jargon walls. When the
  owner delegates ("do what is best"), decide, say what you chose, and go on.
- When the owner must run something, the code block holds ONLY what they paste: one step at a time, real paths, no
  placeholder left. Say the expected output in one sentence of prose.

## 5. Outside edits are yours to judge

- At the start of a session, find what moved since the last close with `find -newermt` across the whole workspace,
  not only `git status` (it misses ignored files and folders outside git).
- Judge each edit on its merits: read it, run its tests, prove a new test can fail (break the code, see red, restore
  it byte for byte). Keep, correct or undo it, with a backup first under `runs/<topic>/backups/` (absolute path).
- Report which and why, in `docs/LOG.md` and in your reply. Do not ask who made it. Small corrections are yours;
  rewriting the owner's intent needs their yes.

## 6. The conception wins

- Three sources can disagree: the conception (the product rules), the backend contract and the design. The
  conception wins unless the owner amends it.
- Settle a conflict before you build: a short question with the readings and a recommendation. Then record a
  numbered line in `docs/DECISIONS.md`, or file a backend ask, and say which. What the conception does not name is
  built only on the owner's yes.

## 7. One asks file per part for the backend

- ONE self-contained file per part, `docs/BACKEND-ASKS-<n>.md`, made from `docs/BACKEND-ASKS.md`: what to do first
  on top, confirmations of the previous part, the full text of older asks they never received, the new asks.
- Plain text that reads well in a chat app. Written fast from what is already verified, by one writer.
- A sent part is never edited: corrections go in the next part. Ask numbers run across parts, never reused.

## 8. A live backend may hold real users' data

- Read-only: reads and sign-in. Never a seed, a migration, a write, a key rotation or an export against it, from a
  script, a test or a tap on the phone. Prove every write on the fake data source or a test project.
- Sign-in throttles are shared with real users: sign in rarely. Never put a service key (one that bypasses the
  access rules) in the app or in a script against the live project.

## 9. Two tiers of checks

- Targeted checks while you work, seconds each; the full gate once per batch, right before a push or a release, in
  a fresh session (`/perfect-vibecoding-rules-flutter:gate`). No build and no suite between stages.

## 10. The owner's phone and the machine

- Never uninstall the app or clear its data on the owner's phone (local data dies with it), never change its
  settings, never install on it or drive it without the owner's yes, unless `docs/DECISIONS.md` allows it.
  Screenshots stay on this computer and are deleted after. Details: `/perfect-vibecoding-rules-flutter:device`.
- Say it before a heavy job, in the same message: "a debug build, alone in the queue, about 4 minutes and 3 GB".
- Kill by PID, never by name (`pkill -f` kills your own call; a name also matches other projects): list
  `ps -eo pid=,args=`, match the arguments, check the working directory (`/proc/<pid>/cwd`), then `kill <pid>`.

## 11. The owner pushes and releases

- You prepare; the owner pushes, tags and uploads. Keep the tree buildable at every stop: the analyzer clean, every
  agent's checks green.
- Commit messages follow Conventional Commits: `<type>(<scope>): <what, in the imperative>`, types `feat`, `fix`,
  `refactor`, `docs`, `chore`, `test`, `ci`; the scope is the feature or area (`orders`, `router`, `theme`, `l10n`,
  `android`). The body says why.
- Each user-visible change gets a plain line in `docs/CHANGELOG.md` under "Unreleased" (`## Unreleased`; start the
  file with it when it is missing), the day it lands: the owner pastes these into the store's "what's new".
- Before the owner stops, say what a push or a release would ship. If something must not ship yet, say so and offer a
  side-branch push (`git push origin HEAD:wip-<topic>`, which the owner runs).

## Templates

Messages for each rule (budget, update, where to look, question, conflict, outside edits, a heavy job, a commit, a
release, end of day, a read-only backend probe): [examples.md](examples.md).

In Claude Code: the plugin's Bash hook (`hooks/guard-bash.mjs`) denies `pkill -f` and a kill fed by `pgrep -f`, and
refuses `adb uninstall`, `pm clear`, `pm uninstall`, `settings put` and `flutter install` unless `DEVICE_WRITE_OK=1`
or the command names an emulator (`emulator-NNNN`). When a command takes a device or a lot of memory (a build,
`flutter run`, `flutter drive`, an integration test, `adb install`, `emulator -avd`), it shows the owner a one-line
notice as it starts and gives you a note: too late for that job, so say it first. Arm the 20-minute waiter as a
background Bash command. A workflow run belongs to its session: a new session relaunches what is missing from the
saved script and the reports on disk. The message templates are at `${CLAUDE_SKILL_DIR}/examples.md`.
