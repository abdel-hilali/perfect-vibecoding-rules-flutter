---
name: new-project
description: Sets up this kit in a Flutter app. Copies AGENTS.md, CLAUDE.md, the docs templates, the Dart check scripts, the queued tools and the analyzer rules without overwriting anything, fills the project name and date, adds the missing .gitignore lines, and on the owner's yes starts a fresh app from the kit's boilerplate and offers a lean Gradle heap. Use when the owner says "new project", "set up the kit", "install the rules in this project", or starts a Flutter app that should follow these rules.
disable-model-invocation: true
argument-hint: "[boilerplate]"
---

# Set up the kit in a Flutter app

## Rules first

1. **Never overwrite a file.** The installer skips every file that exists and lists it. Its own edits are small
   additions: the missing `.gitignore` lines and a `.gitattributes` when there is none. Any other merge into an
   existing file (`AGENTS.md`, `analysis_options.yaml`, `pubspec.yaml`, `android/gradle.properties`) needs the
   owner's yes and a diff first.
2. **Ask once, up front, with defaults:** the app's purpose in one line; whether teammates use other AI tools (then
   the app keeps the playbooks); for a fresh app, whether to start from the kit's boilerplate (recommended); the
   owner's yes to the setup edits. The word `boilerplate` given with the command is the yes to the boilerplate.
3. **The app comes first.** The project root is the folder with `pubspec.yaml`. No app yet: `flutter create` first.
4. **The setup builds nothing.** No `flutter build`, no `flutter run`, no emulator, nothing on the owner's phone.
5. **The owner commits.** End with `git status` and a proposed commit message.

## 1. Check the ground

- Find the app's root: `pubspec.yaml` beside `lib/`. In a monorepo, the Flutter app's own folder.
- No app yet: recommend `flutter create --org com.example --platforms android,ios <name>` (a snake_case name; the
  owner gives the real organization, their domain reversed). Then continue inside the new folder.
- Tools: Flutter (or fvm), Node 18+ for the installer, git, python3, bash (macOS, Linux, or WSL on Windows). Say
  what is missing. Never install system packages yourself.
- Read `git status` first, so the setup's changes stay easy to review apart from earlier work.

## 2. Run the installer

```bash
node <kit>/install.mjs <app-dir>        # add --with-boilerplate for a fresh app, on the owner's yes
```

- It copies `AGENTS.md`, `CLAUDE.md`, `docs/` (`RULES.md`, `HANDOFF.md`, `PROGRESS.md`, `LOG.md`, `DECISIONS.md`,
  `BACKEND-ASKS.md`, `BUILDER-RULES.md`, `CHANGELOG.md`), `tool/kit/` (`check_structure.dart`, `check_l10n.dart`,
  `kit_config.json`), `scripts/tools/`, `analysis_options.yaml` to the root (when the app has one: merge by hand,
  section 4), `.claude/skills/design-direction/SKILL.md` and the playbooks (`docs/playbooks/`).
  It writes `runs/.gitignore` and `.gitattributes` when they are missing, and adds the missing `.gitignore` lines.
- It fills the project name (the `name` in `pubspec.yaml`) and today's date, keeps the tools' execute bits and
  writes them with LF line endings. `--dry-run` shows the plan and writes nothing. `--no-playbooks` leaves out
  `docs/playbooks/`: only when everyone works in Claude Code with the plugin.
- `--with-boilerplate` adds the kit's starter code (`lib/`, `test/`, `l10n.yaml`, `assets/.env.example`, the
  Android styles), only into a fresh app: `lib/` holding nothing but flutter create's `main.dart`. The demo files it
  replaces move to `runs/kit-install/<time>/` first. Its imports take the app's package name. It prints the pubspec
  fragment to merge (step 5).

Read its output and report each skipped file, warning and note. These need action:

- `AGENTS.md` was there already: offer to merge the kit's sections into it. Show the diff first.
- `CLAUDE.md` was there without an `@AGENTS.md` line: add that line at its top, or Claude Code never reads the rules.
- `.gitattributes` was there and lacks lines: add the lines the warning names.
- `runs/` already held files: check that `.gitignore` now holds `runs/`.

## 3. Fill what the installer cannot

- `{{PURPOSE}}`: the owner's one line, in each file the installer named.
- `scripts/tools/tools.env`: `FLUTTER="fvm flutter"` when the app has `.fvmrc` or `.fvm/`. `APP_DIR` stays empty:
  the tools take the app as the folder two levels above them. `DEVICE_WRITE_OK` stays `0`: only the owner changes it.
- `tool/kit/kit_config.json`: an app with `lib/features/*/presentation/bloc/` gets `"controllersDir": "bloc"`
  rather than every file moved; write why in `docs/DECISIONS.md`.
- `.claude/skills/design-direction/SKILL.md`: leave its prompts for the owner, or fill them from a design the owner
  points to. Never invent a direction.

## 4. analysis_options.yaml

The installer never replaces it; its note says which case you are in.

- **The flutter create default:** nothing of the owner's is in it. With the owner's yes, replace it with the kit's
  file (it includes the same `flutter_lints` and adds the kit's analyzer settings and rules).
- **A file the team changed:** merge the kit's `analyzer:` and `linter: rules:` sections into it and keep the
  project's own rules. Show the diff. How: [setup-notes.md](setup-notes.md).

An existing app may then show new analyzer issues: report the count. Fixing them is a task the owner schedules.

## 5. The boilerplate (a fresh app, on the owner's yes)

Copy it by the ten steps of `<kit>/templates/boilerplate/README.md`, section "How the new-project skill copies
it", in their order. `--with-boilerplate` does steps 2 to 4 and the styles of step 6. Merge the printed pubspec
fragment by hand (step 5), keeping the app's own lines; show the diff. A skipped step breaks the app silently:

- The package rename (`package:kit_app/` to `package:<name>/`, in `lib/` and `test/`) and the deletion of
  `lib/main.dart` and `test/widget_test.dart`: without them the app or its tests do not compile.
- `cp assets/.env.example assets/.env`, and `assets/.env` in `.gitignore`: `pubspec.yaml` declares the file, so the
  build fails without it. Public values only: anyone who has the APK can read them.
- `flutter pub get` (it uses the network: say so), `flutter gen-l10n`, then
  `dart fix --apply --code=directives_ordering` and `dart format lib test`: the imports now name the app's package,
  which sorts in another place than `kit_app`, and the analyzer fails on the order.
- On iOS, the languages in `ios/Runner/Info.plist` (`CFBundleLocalizations`: en, fr, ar): iOS offers the app only
  the languages declared there, so a French phone opens it in English.

Then rename what the README names (the app's title in the ARB catalogs, the example feature). More:
[setup-notes.md](setup-notes.md).

## 6. The Gradle heap

`flutter create` writes `org.gradle.jvmargs=-Xmx8G -XX:MaxMetaspaceSize=4G` in `android/gradle.properties`: one
build can then take more than 8 GB and freeze a 16 GB machine. Offer the owner the kit's lean settings, with the
diff; change the file only on their yes. The lines and why: [setup-notes.md](setup-notes.md).

## 7. Keep secrets and work files out of git

- The installer added the lines `.gitignore` lacked: `runs/`, `claude-chats/`, `assets/.env`,
  `!assets/.env.example`, `android/key.properties`, `*.jks`, `*.keystore`, and `build/symbols/` when `build/` was
  not ignored yet. Check them in its output.
- `runs/` and the saved-chats folder also ignore themselves: each holds a `.gitignore` with `*`.
- Never commit `assets/.env`, a keystore, `key.properties`, chat transcripts or `runs/`.

## 8. Check that it works

From the app's root, after `flutter pub get`:

```bash
dart run tool/kit/check_structure.dart
dart run tool/kit/check_l10n.dart
scripts/tools/q-analyze.sh
```

Each ends with one summary line. A fresh app with the boilerplate passes all three. An existing app may have
findings: report the real numbers, failures included; fixing them is a task for the owner to schedule, never a
silent edit.

## 9. Record and hand over

- `docs/LOG.md`: the first entry, with the time from `date`: what the installer created, skipped and replaced, what
  you changed by hand, and the check results with their numbers.
- `docs/HANDOFF.md`: the current state: the kit installed, what is left.
- Tell the owner what changed, what is left for them (the purpose line, the design direction, the Gradle heap, the
  commit), and how to work from now on: every AI tool reads `AGENTS.md` first.
- End with the boundary line of `AGENTS.md`: "This is a session boundary. The handoff is written. Open a new
  session." The new session is the first that starts with the new `AGENTS.md`.

In Claude Code: `<kit>` is `${CLAUDE_PLUGIN_ROOT}`, so run
`node "${CLAUDE_PLUGIN_ROOT}/install.mjs" "${CLAUDE_PROJECT_DIR}" --no-playbooks` (add `--with-boilerplate` for a
fresh app on the owner's yes; in a monorepo, give the app's folder). The plugin provides the skills, so the app gets
no playbooks; drop `--no-playbooks` when teammates use other AI tools. Start Claude Code in the app's folder: its
`CLAUDE.md` (with `@AGENTS.md`) then loads, and the Bash hook finds `scripts/tools/tools.env`. The hooks work as soon
as the plugin is enabled; `CLAUDE.md` and `AGENTS.md` apply from the next session. Recommend
`{ "cleanupPeriodDays": 3650 }` in `~/.claude/settings.json` (Claude Code deletes transcripts after 30 days by
default), name the plugin options `save_chats`, `chats_dir` and `context_budget_k` (in `/config`), and the separate
RAM plugin `perfect-vibecoding-ram-management`: one machine-wide queue for the tools, memory caps and a watchdog.
