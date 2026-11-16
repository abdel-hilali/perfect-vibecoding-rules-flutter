# {{PROJECT_NAME}}

{{PURPOSE}}

The always-on rules for every AI agent in this Flutter project, whatever the tool. "The owner" directs the work. Code
detail lives in `docs/RULES.md` (F1 to F18), how-tos in the playbooks (table at the end). This file loads on every
call: keep it short; product decisions go in `docs/DECISIONS.md`.

## Start of every session

1. Read `docs/HANDOFF.md` whole (it is short), and `docs/PROGRESS.md` only where the handoff points. Never read
   `docs/LOG.md` whole: `tail -n 60 docs/LOG.md`, or `grep -n` it.
2. Find what moved since the last session, across the whole workspace, not only `git status`:
   `find . -newermt "<last session's time>" -type f -not -path './build/*' -not -path '*/.dart_tool/*' -not -path './.git/*'
   -not -path './runs/*' -not -path './claude-chats/*'`. Judge every edit you did not make: read it, run its tests,
   then keep, correct or undo it (backup first) and report which and why; never ask who made it.
3. Before you start anything, check what runs: heavy jobs (`ram.sh status` or `scripts/tools/q-status.sh`), agents, an
   emulator, the owner's `flutter run` on their phone.

## Code: the rules that matter most

1. **Size limits, in counted lines:** a source file 350, a test file 450, a function or method 60, a `build` method 120.
   Over a limit: split by responsibility (a widget class, never a `_buildX()` method), never squeeze lines.
2. **Layers.** `lib/core/...` and `lib/features/<feature>/{data,domain,presentation}`. `domain` is plain Dart;
   `presentation` never imports `data/`; features never import each other's internals. Material comes from
   `package:material_ui/material_ui.dart`, never `package:flutter/material.dart` (deprecated).
3. **State.** `ChangeNotifier` controllers served by `NotifierProvider`, built by the feature's DI module. Controllers
   call use cases, guard `notifyListeners` after dispose, drop stale answers.
4. **Errors.** Data sources throw `ApiException`; repositories return `Result<T>` with a typed `Failure`. Branch on the
   type or the backend's `code`, never on a message. Never a swallowed failure, never a stack trace to the user.
5. **Network.** One `ApiClient` (dio) or one Supabase gateway, with timeouts, one shared token refresh, an
   `Idempotency-Key` on creates. Only data sources know URLs and tables.
6. **Theme.** Colours only from `context.colors` (`AppColors`, a `ThemeExtension` with `light` and `dark`). No
   `Color(0x...)` or `Colors.x` outside `lib/core/theme/`. Text from `AppTextStyles`, one bundled font.
7. **Edges.** Edge to edge; one `systemOverlayFor(colors)`; the status bar and the navigation bar take the page's colour;
   never one `SafeArea` around the app; bottom bars paint under the gesture bar; sheets through `showAppSheet`.
8. **Icons.** One family, through `AppIcons` and `AppIcon`; a label on every icon-only button.
9. **Text.** No literal user-facing text: ARB catalogs, `context.l10n`, every locale together by small edits,
   right-to-left safe layout (`EdgeInsetsDirectional`, `start`/`end`).
10. **Tests and comments.** Tests mirror `lib/`, with hand-written fakes of real shapes, a regression test for every bug
    fix and the four states of every screen, within the F17 budget: a test only for a bug it would catch, one table
    test for many inputs, no duplicates, tests smaller than the code. Comments say why, never cite a ticket, a report
    or an agent.

A change is done when its targeted checks pass (seconds each):

- `dart format <changed files>` (never the whole tree while agents work);
- `scripts/tools/q-analyze.sh`;
- `scripts/tools/q-test.sh <test files>` (never a folder or the suite);
- `dart run tool/kit/check_structure.dart --files <changed files>` and `dart run tool/kit/check_l10n.dart`.

A batch is done when the ONE gate passes (verify, a build, the owner's check on a phone), run once before the push or
the release, in a fresh session. A check fails? Fix the code, not the check. A rule is wrong for this project? Tell the
owner, then change `docs/RULES.md` and the check together.

## Working with the owner (detail: the working-rules playbook)

1. **Budget first.** Before you launch agents, give the cost of each option in tokens, your recommendation first, and
   wait for the owner's word. Name the cheapest clean stopping point. A stage never starts by itself across a decision.
2. **Build first, never go quiet.** Update the owner at each stage and at least every 20 minutes; say so the moment an
   estimate slips.
3. **Say where to look** after a UI change: the screen, the account, the build, what not to tap (it writes real data).
4. **Short questions.** One decision each, the recommendation first and marked. "Do the recommended" means take every
   recommended option. When the owner must run something, the code block holds only what they paste.
5. **The conception wins** over the backend contract and the design: settle a conflict before you build. What the
   conception does not name is built only on the owner's yes.
6. **A live backend may hold real users' data.** Read-only (reads and sign-in); prove every write on fakes or a test
   project. The backend team gets one self-contained `docs/BACKEND-ASKS-<n>.md` per part; a sent part is never edited.
7. **The owner's phone is theirs.** Never uninstall the app or clear its data (local data dies with it), never change
   its settings, never install on it or drive it without the owner's yes (unless `docs/DECISIONS.md` allows it).
   Screenshots stay on this computer and are deleted after.
8. **The owner pushes and releases.** You prepare the commit message, the changelog entry and the gate, keep the tree
   buildable at every stop, and say what a push or a release would ship.

## Sessions, tokens and the record (detail: the session-rules playbook)

- `docs/HANDOFF.md`: the current state, at most 80 lines, rewritten at each boundary (its old text goes to the end of
  `docs/LOG.md` first). `docs/PROGRESS.md`: the plan and the decisions. `docs/LOG.md`: append-only.
- Change session at every stage boundary (a wave lands, a review ends, before the gate, after a push, the end of a day)
  AND once the context passes about 200K tokens, at the next clean point: write the handoff, confirm nothing runs, then
  say "This is a session boundary. The handoff is written. Open a new session." Mid-wave is not a clean point.
- Every call re-sends the whole context. Read with `grep -n` and line ranges; never read a file over 400 lines whole or
  re-read what you read; cap tool output (`| tail -n 40`, `flutter test -r failures-only`); open images only when the
  owner needs you to look, downscaled.
- Clock times come from `date`; the owner's words go in the log verbatim. Scripts, reports, logs and backups live in
  `runs/<topic>/`, never only in `/tmp` or `~/.claude`. Long processes run detached (`setsid nohup`, `nohup` on macOS).
- "Stop everything": stop agents and heavy jobs at once, back up the uncommitted tree into `runs/<topic>/backups/`,
  write the handoff, nothing else.

## Processes and memory

- Heavy jobs (the analyzer, tests, builds) run one at a time through the queued tools in `scripts/tools/`; with the RAM
  plugin they go through `ram.sh run`, which waits for memory and caps the job (run `build_runner` that way too). An
  emulator or a `flutter run` stays out of the queue (it would hold it for its whole life): start one only when
  `scripts/tools/q-status.sh` shows nothing heavy.
- Never kill by name or pattern (`pkill`, `killall`, a kill fed by `pgrep -f`): find the PID, check its working
  directory (`/proc/<pid>/cwd`; `lsof -a -d cwd -p <pid>` on macOS), then `kill <pid>`.
- One Gradle build at a time on the machine. Keep `android/gradle.properties` lean (`-Xmx3g`, a Kotlin daemon heap, an
  idle timeout): the template's 8 GB heap can freeze a 16 GB machine.

## Several agents in one working tree

- Every builder follows `docs/BUILDER-RULES.md` and writes only the files its brief lists; anything else goes in its
  report under "Needs from others". Never remove or narrow a public class, a member or a catalog key that another file
  reads: add, do not change.
- While agents work, never `git checkout`, `switch`, `stash`, `restore`, `reset`, `clean`, `add`, `commit`, `mv` or `rm`,
  never `flutter clean`, never `dart format` or `dart fix` on the whole tree.
- Builders never run a build, `flutter run`, an emulator, the whole suite, or anything on the network.

## Playbooks

Open the one that fits the task, and read it whole before you start.

| When | Read |
| --- | --- |
| Writing or reviewing code; "is this allowed?"; a check fails | `docs/playbooks/code-rules/SKILL.md` |
| "How do we do X here": theme, bars, icons, text, network, errors, routing, state, storage, media | `docs/playbooks/recipes/SKILL.md` |
| Add or change a screen, a tab or an endpoint | `docs/playbooks/screen/SKILL.md` |
| Before a push or a release; the whole suite or a build | `docs/playbooks/gate/SKILL.md` |
| A phone or an emulator, adb, screenshots | `docs/playbooks/device/SKILL.md` |
| The queued tools in `scripts/tools` | `docs/playbooks/tools/SKILL.md` |
| Several agents or builders in one working tree | `docs/playbooks/multi-agent/SKILL.md` |
| A stage ends, a large context, "stop everything", "where were we", a crash | `docs/playbooks/session-rules/SKILL.md` |
| Planning, reporting, asking the owner, the backend team | `docs/playbooks/working-rules/SKILL.md` |
| Setting up or repairing this kit | `docs/playbooks/new-project/SKILL.md` |
| A colour, the font, the top or bottom bar, the icons | `.claude/skills/design-direction/SKILL.md` |

Without the plugin, `/perfect-vibecoding-rules-flutter:<name>` in a playbook means `docs/playbooks/<name>/SKILL.md`.
