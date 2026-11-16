# {{PROJECT_NAME}}

{{PURPOSE}}

These are the always-on rules for every AI coding agent in this Flutter project, whatever the tool. "The owner" is the
person who directs the work. Code detail lives in `docs/RULES.md` (F1 to F18); how-tos live in the playbooks (table at
the end). This file is loaded on every call: keep it short, and put product decisions in `docs/DECISIONS.md`, not here.

## Start of every session

1. Read `docs/HANDOFF.md` whole (it is short). Read `docs/PROGRESS.md` only for the part the handoff points to. Never
   read `docs/LOG.md` whole: `tail -n 60 docs/LOG.md`, or `grep -n` it.
2. Find what moved since the last session, across the whole workspace, not only `git status`:
   `find . -newermt "<last session's time>" -type f -not -path './build/*' -not -path '*/.dart_tool/*' -not -path './.git/*'
   -not -path './runs/*' -not -path './claude-chats/*'`. Edits you did not make are yours to judge: read them, run their
   tests, then keep, correct or undo each one, with a backup first. Report which and why. Do not ask who made them.
3. Check what runs before you start anything: heavy jobs (`ram.sh status` or `scripts/tools/q-status.sh`), agents, an
   emulator, the owner's `flutter run` on their phone.

## Code: the rules that matter most

1. **Size limits, in counted lines:** a source file 350, a test file 450, a function or method 60, a `build` method 120.
   Over a limit: split by responsibility (a widget class, never a `_buildX()` method), never squeeze lines.
2. **Layers.** `lib/core/...` and `lib/features/<feature>/{data,domain,presentation}`. `domain` is plain Dart;
   `presentation` never imports `data/`; features never import each other's internals.
3. **State.** `ChangeNotifier` controllers served by `NotifierProvider`, built by the feature's module
   (`core/config/injection-modules/`). Controllers call use cases, guard `notifyListeners` after dispose, drop stale answers.
4. **Errors.** Data sources throw `ApiException`; repositories return `Result<T>` with a typed `Failure`. Branch on the
   type or the backend's `code`, never on a message. Never a swallowed failure, never a stack trace to the user.
5. **Network.** One `ApiClient` (dio) or one Supabase gateway, with timeouts, one shared token refresh, an
   `Idempotency-Key` on creates. Only data sources know URLs and tables.
6. **Theme.** Colours only from `context.colors` (`AppColors`, a `ThemeExtension` with `light` and `dark`). No
   `Color(0x...)` or `Colors.x` outside `lib/core/theme/`. Text from `AppTextStyles`, one bundled font.
7. **Edges.** Edge to edge; one `systemOverlayFor(colors)`; the status bar and the navigation bar take the page's colour;
   never one `SafeArea` around the app; bottom bars paint under the gesture bar; sheets through `showAppSheet`.
8. **Icons.** One family, through `AppIcons` and `AppIcon`; labels on icon-only buttons; launcher icon with a monochrome
   layer; a white `ic_stat_` notification icon.
9. **Text.** No literal user-facing text: ARB catalogs, `context.l10n`, every locale together by small edits,
   right-to-left safe layout (`EdgeInsetsDirectional`, `start`/`end`).
10. **Tests and comments.** Tests mirror `lib/`, hand-written fakes with real shapes, a regression test for every bug fix,
    the four states of every screen. Comments say why, never cite a ticket, a report or an agent.

A change is done when its targeted checks pass (seconds to a minute each):

- `dart format <the files you changed>` (never the whole tree while agents work);
- `scripts/tools/q-analyze.sh` (the analyzer, queued);
- `scripts/tools/q-test.sh <test files>` (files, never a folder or the suite);
- `dart run tool/kit/check_structure.dart --files <the files you changed>` and `dart run tool/kit/check_l10n.dart`.

A batch is done when the ONE gate passes (verify, a build, the owner's check on a phone), run once, right before the
push or the release, in a fresh session. A check fails? Fix the code, not the check. A rule is wrong for this project?
Say so to the owner, then change `docs/RULES.md` and the check together, on purpose.

## Working with the owner

1. **Budget first.** Before you launch agents, give the cost of each option in tokens, your recommendation first, and
   wait for the owner's word. Name the cheapest clean stopping point. Never let a stage start by itself across a decision.
2. **Build first, never go quiet.** Update the owner at each stage and at least every 20 minutes. Time estimates are
   ranges; say so the moment one slips.
3. **Say where to look.** A UI change comes with a "where to look" table: the screen, the account, the build or device,
   what the owner sees, what not to tap (it writes real data). Plumbing: "nothing to see on the phone yet".
4. **Short questions.** One decision each, the recommendation first and marked. "Do the recommended" means take every
   recommended option. When the owner must run something, the code block holds only what they paste.
5. **The conception wins** over the backend contract and the design. Settle a conflict before you build: a short question
   with the readings and a recommendation. What the conception does not name is built only on the owner's yes.
6. **A live backend may hold real users' data.** Read-only: reads and sign-in. Prove every write on fakes or a test
   project. One self-contained `docs/BACKEND-ASKS-<n>.md` per part for the backend team; a sent part is never edited.
7. **The owner's phone is theirs.** Never uninstall the app or clear its data on it (local data dies with it), never
   change phone settings, never install on it or drive it without the owner's yes (unless `docs/DECISIONS.md` allows it).
   Screenshots stay on this computer and are deleted after.
8. **The owner pushes and releases.** You prepare the commit message, the changelog entry and the gate. Keep the tree
   buildable at every stop, and say what a push or a release would ship.

## Sessions, tokens and the record

- `docs/HANDOFF.md`: the current state, at most 80 lines, rewritten at each boundary (its old text goes to the end of
  `docs/LOG.md` first). `docs/PROGRESS.md`: the plan and the decisions. `docs/LOG.md`: append-only, never read whole.
- Change session at every stage boundary (a wave lands, a review ends, before the gate, after a push, the end of a day)
  AND once the context passes about 200K tokens, at the next clean point: write the handoff, confirm nothing runs, then
  say "This is a session boundary. The handoff is written. Open a new session." Mid-wave is not a clean point.
- Every call re-sends the whole context, so a long session costs many times a short one. Read with `grep -n` and line
  ranges; never read a file over 400 lines whole; never re-read what you already read; cap tool output (`| tail -n 40`,
  `flutter test -r failures-only`); open images only when the owner needs you to look, and downscale them first.
- Clock times in the record come from `date`. The owner's words go in the log verbatim.
- Keep scripts, reports, logs and backups in `runs/<topic>/`, never only in `/tmp` or `~/.claude`. Each agent creates its
  report at the start and appends as it goes. Run long processes detached (`setsid nohup`, or `nohup` on macOS).
- "Stop everything": stop agents and heavy jobs at once; back up the uncommitted tree (`git diff HEAD --binary` and a tar
  of untracked files, into `runs/<topic>/backups/` by its absolute path); write the handoff; nothing else.
- Chat transcripts can hold secrets: keep them in a folder that ignores itself in git; never commit or share it.

## Processes and memory

- Heavy jobs (the analyzer, tests, builds, `build_runner`, an emulator) run one at a time, through the queued tools in
  `scripts/tools/`. With the RAM plugin installed they go through `ram.sh run`, which waits for memory and caps the job.
- Never `pkill -f`, never feed `pgrep -f` to a kill, never kill by name (`pkill <name>`, `killall`). Find the PID, check
  its working directory (`/proc/<pid>/cwd`, or `lsof -a -d cwd -p <pid>` on macOS), then `kill <pid>`.
- One Gradle build at a time on the machine. Keep `android/gradle.properties` lean (`-Xmx3g`, a Kotlin daemon heap, an
  idle timeout): the template's 8 GB heap can freeze a 16 GB machine.

## Several agents in one working tree

- Each builder writes only the files its brief lists; anything else goes in its report under "Needs from others". Never
  remove or narrow a public class, a member or a catalog key that another file reads: add, do not change.
- While agents work, never `git checkout`, `switch`, `stash`, `restore`, `reset`, `clean`, `add`, `commit`, `mv` or `rm`,
  never `flutter clean`, never `dart format` or `dart fix` on the whole tree.
- Builders never run a build, `flutter run`, an emulator, the whole suite, or anything on the network.
- A refused tool call: wait 30 seconds, retry once, then go on without it and say so in the report.
- Every builder follows `docs/BUILDER-RULES.md`.

## Playbooks

Open the one that fits the task, and read it whole before you start.

| When | Read |
| --- | --- |
| Writing or reviewing app code; "is this allowed?"; the analyzer or a check fails | `docs/playbooks/code-rules/SKILL.md` |
| "How do we do X here": theme, system bars, icons, text, network, errors, routing, state, storage, media, tests | `docs/playbooks/recipes/SKILL.md` |
| Add or change a screen, a tab or an endpoint | `docs/playbooks/screen/SKILL.md` |
| Before a push or a release, or asked to run the tests or a build | `docs/playbooks/gate/SKILL.md` |
| Running the app on a phone or an emulator, adb, screenshots, the owner's device | `docs/playbooks/device/SKILL.md` |
| Running the analyzer or tests while agents work, configuring `scripts/tools` | `docs/playbooks/tools/SKILL.md` |
| Several agents or builders in one working tree | `docs/playbooks/multi-agent/SKILL.md` |
| A stage ends, the context is large, "stop everything", "where were we", after a crash | `docs/playbooks/session-rules/SKILL.md` |
| Planning work, reporting progress, asking the owner, writing to the backend team | `docs/playbooks/working-rules/SKILL.md` |
| Setting up or repairing this kit | `docs/playbooks/new-project/SKILL.md` |
| Changing a colour, a font, the top bar, the bottom bar or the icons | `.claude/skills/design-direction/SKILL.md` |

Without the plugin, a playbook that names `/perfect-vibecoding-rules-flutter:<name>` means
`docs/playbooks/<name>/SKILL.md`. Claude Code with the plugin `perfect-vibecoding-rules-flutter` has these playbooks as
skills and loads them by itself (only `new-project` waits for the owner's command).
