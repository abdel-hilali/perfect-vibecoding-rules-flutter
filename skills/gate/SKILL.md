---
name: gate
description: Runs the project's quality checks in two tiers - seconds-long targeted checks while working, and one full gate per batch right before a push or a release (verify, a debug build alone in the queue, device tests only on the owner's yes, the owner's check on a real phone) - with real numbers per leg, the release build steps and the Flutter traps built in. Use when about to push or release, when calling a screen or a wave done, or when asked to run the analyzer, the tests, a build or integration tests.
---

# The quality gate

## Rules first

1. **Two tiers.** A change is done when its targeted checks pass: seconds to a minute each. A batch is done when the
   ONE gate passes, run once, right before the push or the release, in a fresh session, after the review and fix
   round. Never twice for the same batch.
2. **No whole suite and no build between stages.** They take minutes and gigabytes that other agents need. Batches in
   flight share ONE gate at the very end.
3. **Order: verify → build → device tests → the owner's check.** Cheapest and safest first. If verify is red,
   nothing after it matters.
4. **A build runs alone and takes several GB.** Say it in the same message ("a build, about N minutes; the machine is
   slower meanwhile"). One Gradle build at a time on the machine.
5. **The owner's phone is theirs.** Device tests and installs only on the owner's yes (the device playbook:
   `/perfect-vibecoding-rules-flutter:device`, or `docs/playbooks/device/SKILL.md`).
6. **Report real numbers for every leg, and name each leg you skipped and why.** Never say "green" when only verify
   ran.
7. **The local gate may be the only gate.** CI may be off. Keep the tree buildable at every stop.

## Tier 1: targeted, while working

Run only what touches your change.

| Check | Command |
| --- | --- |
| Format the changed files | `dart format <files>` (never the whole tree while agents work) |
| The analyzer, queued | `scripts/tools/q-analyze.sh` (or given paths: `scripts/tools/q-analyze.sh lib/features/orders`) |
| The tests you touched | `scripts/tools/q-test.sh <test files>`: files, never a folder or the suite |
| Structure and sizes | `dart run tool/kit/check_structure.dart --files <the files you changed>` |
| The catalogs | `dart run tool/kit/check_l10n.dart` |

After an ARB change, run `flutter gen-l10n` first: the analyzer and the tests read the generated files. The `q-*`
tools run heavy jobs one at a time and wait for free memory (through the RAM plugin's `ram.sh run` when it is
installed). Their options: `/perfect-vibecoding-rules-flutter:tools`, or `docs/playbooks/tools/SKILL.md`.

## Tier 2: the full gate, once per batch

1. **Verify.** `scripts/tools/verify.sh` = `dart format --set-exit-if-changed lib test` → `flutter analyze` →
   `check_structure.dart` → `check_l10n.dart` → `flutter test` (the whole suite, queued). One line per leg with
   real numbers. A red leg: fix the code, then run verify again.
2. **The build, alone in the queue (say it first).** `scripts/tools/q-build.sh apk --debug`. It waits until no other
   heavy job runs, logs to `runs/build/<time>.log`, and prints the last 30 lines and the artifact's path
   (`build/app/outputs/flutter-apk/app-debug.apk`).
3. **Device tests, only on the owner's yes.** Integration tests (`integration_test/`) build the app, install it on a
   device and drive it: on the owner's phone that replaces the app they are testing. Prefer an emulator (also on
   the owner's yes: 2 to 4 GB). One file at a time, from the app folder, alone in the queue:
   `ram.sh run --alone --name device-test -- flutter test integration_test/<file>_test.dart -d <serial>` (without
   the RAM plugin: the same command without the prefix, once `scripts/tools/q-status.sh` shows nothing heavy). A
   device test that writes runs against fakes or a test project, never a live backend.
4. **The owner's check on a real phone.** The owner installs and looks; you never drive their phone. Give the
   where-to-look table (`/perfect-vibecoding-rules-flutter:working-rules`): the screen, the account, which build
   (debug from their IDE, the APK file at its path, or the store's internal test), what they see, what not to tap.

## Release builds

The owner releases. You prepare, and say what the release ships before they upload:

1. **The version** in `pubspec.yaml`: `version: x.y.z+build`. Raise `x.y.z` by what changed, and the build number
   above the last one uploaded: the store refuses an equal or lower one, and a phone refuses to install it over a
   higher one.
2. **The changelog.** In `docs/CHANGELOG.md`, the "Unreleased" section becomes `## x.y.z+build` with the date from
   `date`. The contract test that holds the version and the changelog together must pass.
3. **The build**, alone in the queue (signed with the upload key from `android/key.properties`, never in git; it is
   missing? stop and ask the owner, never sign a release with the debug key):

   ```bash
   scripts/tools/q-build.sh appbundle --release --obfuscate --split-debug-info=build/symbols/<x.y.z+build>
   ```

4. **Keep the symbols.** Copy `build/symbols/<x.y.z+build>/` out of `build/` (for example to
   `runs/release/<x.y.z+build>/`): `flutter clean` deletes `build/`, and without the symbols a crash trace from that
   release can never be read (`flutter symbolize`).
5. **What it ships:** every commit since the last release (`git log --oneline <last tag>..HEAD`), the changelog
   entry, and anything that must reach the backend first. The owner uploads to the internal test track first.

## Reporting

One line per leg, real numbers, skipped legs named. Example: "format: 0 changed · analyze: 0 issues · structure:
0 errors, 2 warnings · l10n: ok, 3 locales · tests: 214/214 · build: apk --debug ok, 4 min · device tests: skipped
(no yes for a device) · owner's check: waiting".

Before the owner stops for the day, say what a push would ship. When work must not ship yet, say so before they stop,
and offer to keep it on a side branch (`git push origin HEAD:wip-<topic>`, which the owner runs).

## Traps that cost real time

- **A debug build cannot replace a release-signed install** (the store's copy, or a release APK): the signatures
  differ, the install fails, and the only way past is an uninstall, which deletes the app's local data (the session,
  drafts, settings). `flutter run` does that uninstall by itself when its install fails, and `flutter install`
  uninstalls first every time. Ask the owner before any install on their phone.
- **Stale gen-l10n output.** The analyzer and the tests read `lib/core/l10n/generated/`. After an ARB change, run
  `flutter gen-l10n`, or the analyzer reports the new key as an undefined getter, or an old text ships.
- **The Gradle heap.** `flutter create` writes `-Xmx8G -XX:MaxMetaspaceSize=4G` in `android/gradle.properties`, and
  the Kotlin daemon copies that heap when `kotlin.daemon.jvmargs` is unset: two 8 GB daemons can freeze a 16 GB
  machine. Keep the lean heap (`-Xmx3g`, a Kotlin daemon heap, an idle timeout; the new-project playbook sets it on
  the owner's yes). After the gate, stop the idle daemons: `ram.sh free`, or `./gradlew --stop` in `android/` when
  no other build runs.
- **A test green alone but red in the suite.** Something leaks between tests. `SharedPreferences.setMockInitialValues`
  is global: set it in each `setUp`. Static state (a module's `instance`, a static cache) lives across the tests of
  a file: reset it in `tearDown`. A pending `Timer` fails a widget test ("A Timer is still pending"): cancel it in
  `dispose`, and pump a fixed duration instead of `pumpAndSettle` over an endless animation. Files running at the
  same time share the disk: give each test its own temp folder.
- **Obfuscation renames classes.** A release build breaks code that branches or logs on `runtimeType.toString()`.

In Claude Code: when a command builds the app, runs it on a device or starts an emulator (`flutter build`,
`flutter run`, `flutter install`, `flutter drive`, `adb install`, `emulator -avd`), the plugin's Bash hook shows the
owner a one-line notice as it starts and gives you a note (too late for that job: say it first, rule 4). It refuses
`adb uninstall`, `pm clear` and `settings put` unless `DEVICE_WRITE_OK=1`. Run long jobs with the Bash tool's
background option. Run the full gate in a new session that reads `docs/HANDOFF.md` first, never in the session that
built the batch.
