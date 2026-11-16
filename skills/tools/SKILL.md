---
name: tools
description: Explains the shell tools in scripts/tools/ and their settings in tools.env - queued analyzer, test and build wrappers that use the RAM plugin's machine-wide queue when it is installed, the gate script, a status view of what runs, a waiter that wakes on finished agents, and an ownership sweep. Use when running flutter analyze, flutter test or flutter build while other agents work, running the gate, checking what runs, waiting on a wave, sweeping what a wave changed, or installing and configuring the tools.
---

# The project tools (`scripts/tools/`)

Small bash and Python tools for one shared machine: several agents, the owner's phone, limited memory. Each bash
tool reads its settings from `scripts/tools/tools.env` through `scripts/tools/lib.sh`. `sweep-owners.py` reads only
`APP_DIR`, the same way: from the environment, else from `tools.env`.

## Rules first

- While other agents work, never call `flutter analyze`, `flutter test` or `flutter build` directly. Use the
  `q-*` wrappers: one heavy job runs at a time, the others wait in line. A wait of minutes is normal.
- Test FILES only. `q-test.sh` refuses a folder, an option, a file that is not `*_test.dart`, and integration tests
  (they install and drive the app on a phone: the device playbook). One integration test runs, on the owner's yes,
  with `q-test.sh -d <serial> integration_test/<file>_test.dart`: alone in the queue, since it builds the app.
- The whole suite and a build belong to the gate: `verify.sh` and `q-build.sh`, once, right before a push or a
  release, in a fresh session. A builder never runs either.
- Look before you start anything heavy: `scripts/tools/q-status.sh` says what runs and how much memory is free.
- Stop a process by PID, never by name. Find the PID (`ps -eo pid=,args=` in a script file, or `ss -lptn` for a
  port; `lsof -nP -iTCP:<port> -sTCP:LISTEN` on macOS), check its working directory (`/proc/<pid>/cwd`; on macOS
  `lsof -a -d cwd -p <pid>`), then `kill <pid>`. Never `pkill -f` or `pgrep -f`: the pattern also matches the shell
  that runs it. Never `pkill <name>` or `killall`: a name also matches other projects and the editor's helpers.
  Idle Gradle daemons stop with `./gradlew --stop` in `android/`.
- Run the tools from anywhere: relative paths are read from `APP_DIR`.

## The tools

| Tool | What it does | When | Arguments | Settings |
|---|---|---|---|---|
| `q-analyze.sh` | `flutter analyze` in the queue; prints the tail and `analyze exit: N` | After a change; once at the end of a package | `[<file or folder>...]` (none = the whole app; no option) | `ANALYZE_MIN_FREE_MB` |
| `q-test.sh` | `flutter test --concurrency=N -r failures-only <files>` in the queue; prints `test exit: N` | On the tests you wrote, or whose subject you changed | `<test file>...` (`*_test.dart`), or `-d <serial>` and one file under `integration_test/` | `TEST_CONCURRENCY`, `TEST_MIN_FREE_MB` (with `-d`: `BUILD_MIN_FREE_MB`) |
| `q-build.sh` | `flutter build <target> [options]` alone in the queue; the full log in `RUNS_DIR/build/`; prints the last 30 lines, the artifact path and `build exit: N`. Adds `--dart-define=APP_VERSION=<the build's version>` (sent as `X-App-Version`) unless you define `APP_VERSION` | The gate or a release, on the owner's yes | `<target> [flutter build options]` (apk, appbundle, ipa, ios, web, ...) | `BUILD_MIN_FREE_MB` |
| `verify.sh` | The gate: `dart format` check (it writes nothing), `flutter analyze`, `check_structure`, `check_l10n`, the whole test suite; one line per leg with its numbers (the tests leg: how many ran, passed, failed); logs in `RUNS_DIR/verify/`; `verify exit: N`, then `check_structure`'s `budget:` line (test/ against lib/). A missing check fails the gate | Once, right before a push or a release | none | all of the above |
| `q-status.sh` | With the RAM plugin: `ram.sh status`. Without: free memory, the queue's lock, this user's heavy processes (Flutter tools, test runners, the analysis server, Gradle and Kotlin daemons, emulators) | Before anything heavy; when the machine is slow | none | `HEAVY_LOCK` |
| `wait-milestone.sh` | Waits for the next finished agent in a journal, or the timer; then prints the agents, the changed paths, the report sizes and free memory | In the background while a wave runs, so you update the owner at least every 20 minutes | `<journal.jsonl> [seconds=1200] [report files...]` | `WAIT_POLL_S` |
| `sweep-owners.py` | Read-only. Every path git sees changed must be claimed by exactly one agent's result; lists unclaimed paths, double claims, paths touched outside a list. Exit 1 when something is wrong | After a wave's finish pass, before the review; pass the journals of every run since the last commit | `[--repo DIR] <journal.jsonl>...` | `APP_DIR` when no `--repo` |
| `lib.sh` | Shared helpers: `mem_free_mb`, `wait_for_memory`, `find_ram_sh`, `run_heavy`, `with_heavy_lock` | Sourced by every tool; never run it | none | all |

`TAIL_LINES=N` makes a `q-*` wrapper print more or fewer lines, for one call.

```bash
scripts/tools/q-status.sh
scripts/tools/q-analyze.sh lib/features/orders
scripts/tools/q-test.sh test/features/orders/presentation/controllers/orders_controller_test.dart
scripts/tools/verify.sh
scripts/tools/q-build.sh appbundle --release
scripts/tools/wait-milestone.sh runs/<topic>/journal.jsonl 1200 runs/<topic>/reports/A1.md
python3 -I scripts/tools/sweep-owners.py runs/<topic>/journal.jsonl
```

## The queue

- **With the RAM plugin** (`perfect-vibecoding-ram-management`, a separate plugin): every heavy job runs as
  `ram.sh run --name <label> -- <command>` (a build and a device test add `--alone`), from `APP_DIR`. That is one
  queue for every project and agent on the machine, a memory cap per job, one job per folder, and a watchdog.
  `lib.sh` finds `ram.sh` in this order: `RAM_SH`, `ram.sh` on PATH, `~/.local/share/perfect-vibecoding-ram/ram.sh`,
  then the newest copy in Claude Code's plugin cache. `RAM_SH=off` never uses it.
- **Without it:** one `flock` lock for every app of this user, then a wait for free memory (`*_MIN_FREE_MB`, at
  most `MEM_WAIT_ROUNDS` rounds of 15 seconds, then the job runs anyway). The job runs with the lock's descriptor
  closed, so a Gradle daemon it starts never keeps the queue locked. Stock macOS has no `flock`: the tools warn and
  run unqueued until it is installed (for example `brew install flock`).

## Install and configure

1. **Copy.** The `new-project` playbook, or `node <kit>/install.mjs <app-dir>` (the installer at the kit's root),
   copies the kit's `templates/scripts/tools/` into the app's `scripts/tools/` with their execute bits. By hand:
   copy the folder, then `chmod +x scripts/tools/*.sh scripts/tools/*.py` and `chmod -x scripts/tools/lib.sh`.
2. **Set the settings once** in `scripts/tools/tools.env`. Each line only sets a default: a variable set in the
   environment wins, for one call (`TEST_CONCURRENCY=1 scripts/tools/q-test.sh <file>`).

   | Setting | Default | Meaning |
   |---|---|---|
   | `APP_DIR` | the folder two levels above `scripts/tools/` | the Flutter app (the folder with `pubspec.yaml`) |
   | `FLUTTER` | `flutter` | `fvm flutter` when the project pins its Flutter version with fvm |
   | `DART` | from `FLUTTER` | `fvm dart` with fvm; the `dart` beside a `FLUTTER` path |
   | `TEST_CONCURRENCY` | `2` | test files that run at once |
   | `ANALYZE_MIN_FREE_MB`, `TEST_MIN_FREE_MB`, `BUILD_MIN_FREE_MB` | `1500`, `2000`, `4000` | free memory a job waits for, without the RAM plugin |
   | `MEM_WAIT_ROUNDS` | `40` | rounds of 15 s a job waits for memory before it runs anyway |
   | `DEVICE_WRITE_OK` | `0` | `1` lets the plugin's Bash hook allow uninstalls, data wipes and settings changes on a phone; only the owner sets it |
   | `RUNS_DIR` | `$APP_DIR/runs` | logs, reports, backups |
   | `RAM_SH` | empty: search | the RAM plugin's `ram.sh`; `off` never uses it |
   | `HEAVY_LOCK` | a file in the runtime folder, one per user | the lock of the tools' own queue |

3. **What they need:** bash (3.2 is enough), Flutter on PATH (or `FLUTTER`), python3 for `sweep-owners.py` and the
   agent list of `wait-milestone.sh`, git for the sweep, and `flock` for the tools' own queue. They run on Linux and
   macOS; on Windows, inside WSL.
4. **Check:** `scripts/tools/q-status.sh` names the queue; `scripts/tools/q-analyze.sh` ends with `analyze exit: 0`.

In Claude Code: with the plugin, the tools ship at `${CLAUDE_PLUGIN_ROOT}/templates/scripts/tools/`, and
`/perfect-vibecoding-rules-flutter:new-project` copies them into the app. Run `wait-milestone.sh` with the Bash
tool's background option: its exit wakes you. A workflow run's journal is the `journal.jsonl` in the session's
`subagents/workflows/<run>/` folder under `~/.claude/projects/`. The plugin's Bash hook blocks `pkill -f`, and
`adb uninstall`, `pm clear`, `pm uninstall`, `settings put` and `flutter install` unless `DEVICE_WRITE_OK=1` (it
reads `scripts/tools/tools.env`) or the command names an emulator (`emulator-NNNN`). When a command takes a device
or a lot of memory (`flutter run`, `flutter build`, `q-build.sh`, `q-test.sh -d`, `adb install`, an emulator), it
shows the owner a one-line warning as the command starts and gives you a note with its result: say it before such a
command. `flutter clean` gets a note only.
