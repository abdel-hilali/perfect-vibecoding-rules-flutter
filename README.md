# perfect-vibecoding-rules-flutter

Battle-tested rules for building Flutter apps with an AI coding agent, usually beside a separate backend API. One
developer's working rules, learned the hard way on real products, packed so that any developer can drop them into
any Flutter project.

It is a Claude Code plugin and its own marketplace. It also works with any other AI coding tool: the rules live in
plain files (`AGENTS.md`, `docs/RULES.md` and the playbooks).

Built for Flutter 3 (stable channel) and Dart 3, on Android and iOS. The architecture is feature first
(`lib/core/` and `lib/features/<feature>/{data,domain,presentation}`), with `ChangeNotifier` controllers, hand-written
modules for dependency injection, a sealed `Result` and `Failure`, go_router, dio, flutter_dotenv,
flutter_secure_storage, gen-l10n catalogs and a `ThemeExtension` with light and dark tokens. The boilerplate ships
all of it, working, with tests.

You need: Flutter; Node 18 or newer (the installer and the hooks); Python 3 (the ownership sweep); bash for the tools
in `scripts/tools/` (macOS, Linux, or WSL on Windows); Claude Code for the plugin. Details:
[Where it runs](#where-it-runs), below.

In the kit's texts, "the owner" is you: the person who directs the AI in the project.

## What is inside

| Part | What it gives you |
| --- | --- |
| 10 skills | The rules and how-tos, loaded by Claude when a task matches (see the table below). |
| 3 hooks | A shell guard (blocks self-killing commands and writes to your phone; warns you when a command takes a device or a lot of memory), a token guard (says when the session should hand off) and a chat saver. |
| Project templates | `AGENTS.md`, `CLAUDE.md`, the code rules (F1 to F18), the handoff, the plan, the log, the decisions, the backend-asks form, the builder rules. |
| Check scripts | `tool/kit/check_structure.dart` (sizes, layers, names, imports, colours, icons, literal text) and `tool/kit/check_l10n.dart` (the text catalogs: missing and extra keys, placeholders, duplicates), plus the kit's `analysis_options.yaml`. Dart, no packages. |
| Shell tools | A queued analyzer, test and build runner for parallel agents, the gate script, a view of what runs, a waiter for agent waves and an ownership sweep. |
| A boilerplate | The starter code of a fresh app: theme, system bars, icons, router and tab shell, network, errors, storage, text catalogs and one example feature, with its tests. |
| An installer | `install.mjs` copies the project files into an app, for any AI tool. |

The skills, as commands (`/perfect-vibecoding-rules-flutter:<skill>`):

| Skill | Use it for |
| --- | --- |
| `code-rules` | The code rules: size limits, layers, state, errors, network, theme tokens, edge to edge, icons, text, tests, and what each check enforces. |
| `recipes` | Working code for each rule, excerpted from the boilerplate, with the Flutter traps that cost real time. |
| `screen` | Adding or changing a screen, a tab or an endpoint, the project's way. |
| `gate` | The checks: targeted while working, one gate (verify, a build, your check on the phone) right before a push or a release. |
| `device` | Running the app on your phone or an emulator safely: adb, screenshots, logs, never your data. |
| `tools` | The shell tools in `scripts/tools/` and their settings. |
| `multi-agent` | Several builder agents in one working tree without losing work. |
| `session-rules` | Session boundaries, the handoff, the context budget, surviving restarts, "stop everything", saving chats. |
| `working-rules` | Budget, progress updates, "where to look", short questions, outside edits, the backend asks. |
| `new-project` | Sets the kit up in an app. Only you start it; Claude never runs it by itself. |

## Install as a Claude Code plugin

Run this once in each project, from the project's folder:

```bash
claude plugin install perfect-vibecoding-rules-flutter --marketplace abdel-hilali/perfect-vibecoding-rules-flutter --scope project
```

It adds the marketplace to your user settings and turns the plugin on for the project in `.claude/settings.json`.
Commit that file: teammates then run the same command once. This one-step form needs a recent Claude Code. On an
older one, add the marketplace first:

```bash
claude plugin marketplace add abdel-hilali/perfect-vibecoding-rules-flutter
claude plugin install perfect-vibecoding-rules-flutter@perfect-vibecoding-rules-flutter --scope project
```

The shell install may end with "3 userConfig options not yet set": that is fine, the defaults apply (chats saved
into `claude-chats/`, a context budget of 200K tokens). To change them, see [Plugin options](#plugin-options).

Prefer to click? Inside a Claude Code session:

```text
/plugin marketplace add abdel-hilali/perfect-vibecoding-rules-flutter
/plugin install perfect-vibecoding-rules-flutter@perfect-vibecoding-rules-flutter
```

The second command opens the plugin's page. It lists what the plugin adds, the three hooks included: read it, since
hooks run commands on your machine. Then pick a scope: for you in every project, for all collaborators on this
repository, or for you in this repository only.

### Start a new project

1. Create the app first: `flutter create --org com.example --platforms android,ios my_app` (your own organization
   in place of `com.example`). The kit comes after it: the installer needs the folder with `pubspec.yaml`.
2. In `my_app`, install the plugin (above) and start Claude Code.
3. Run `/perfect-vibecoding-rules-flutter:new-project`, or `/perfect-vibecoding-rules-flutter:new-project boilerplate`
   to start the fresh app from the kit's boilerplate.

Claude asks for the app's purpose in one line, then copies the rules, the docs, the checks, the tools and the
design-direction template into the app. It never overwrites a file. It adds the `.gitignore` lines the app lacks,
says how to bring the kit's analyzer rules into your `analysis_options.yaml`, offers a lean Gradle heap (with your
yes), runs the checks once and writes the first entry of `docs/LOG.md`. With the boilerplate, the flutter create
demo files move into `runs/kit-install/` and Claude shows you the pubspec lines to merge. You review with
`git status`, commit, and open a new session, so Claude Code loads the new `CLAUDE.md` and `AGENTS.md`. An existing
app works the same way, without the boilerplate.

What the app gets:

| Path | What it is |
| --- | --- |
| `AGENTS.md` | Every always-on rule, for every AI tool. Most tools read it by themselves. |
| `CLAUDE.md` | `@AGENTS.md` (Claude Code imports it), then the Claude Code notes. |
| `docs/RULES.md` | The code rules, F1 to F18, with the reasons. |
| `docs/HANDOFF.md` | The current state, at most 80 lines, rewritten at each session boundary. |
| `docs/PROGRESS.md` | The plan and the decisions. |
| `docs/LOG.md` | The append-only record: your words, decisions, launches, check results. Never read whole. |
| `docs/DECISIONS.md` | Product decisions, kept out of the always-loaded files. |
| `docs/BACKEND-ASKS.md` | The form for one self-contained asks file per part (`docs/BACKEND-ASKS-<n>.md`). |
| `docs/BUILDER-RULES.md` | The rules every parallel builder agent follows. |
| `docs/CHANGELOG.md` | User-visible changes under "Unreleased", for the store's "what's new" at a release. |
| `tool/kit/` | The Dart check scripts and their settings (`kit_config.json`). |
| `analysis_options.yaml` | The kit's analyzer rules. Copied only when the app has none; otherwise Claude merges them. |
| `scripts/tools/` | The shell tools, set up in `scripts/tools/tools.env`. |
| `.claude/skills/design-direction/SKILL.md` | A form for the settled visual direction, to fill. |
| `docs/playbooks/` | The skills as plain files, for other AI tools. `new-project` adds them only when teammates use another AI tool. |
| `runs/` | Working files: briefs, reports, logs, backups. It ignores itself in git. |
| `claude-chats/` | Saved chat transcripts, made by the hook. It ignores itself in git. |
| `.gitattributes` | Keeps the shell tools' LF line endings in a Windows clone. Written only when the app has none. |
| `.gitignore` lines | `runs/`, `claude-chats/`, `assets/.env` (and `!assets/.env.example`), `android/key.properties`, `*.jks`, `*.keystore`, `build/symbols/`: added when missing. |

With the boilerplate, also: `lib/`, `test/`, `l10n.yaml`, `assets/.env.example` and the Android styles for edge to
edge (`values`, `values-night`, `values-v31`, `values-night-v31`).

### Plugin options

| Option | Default | What it does |
| --- | --- | --- |
| `save_chats` | `true` | Copy each session's transcript into the project. Set it to `false` to stop. |
| `chats_dir` | `claude-chats` | The folder, relative to the project root, that receives the copies. `~` and variables such as `$HOME` are not expanded. |
| `context_budget_k` | `200` | Once the context passes this many thousand tokens, Claude writes the handoff and asks for a new session at the next clean point. `0` turns the notice off. |

Change them in `/config` (each option is a row there), or in `/plugin` > Installed > the plugin > Configure options.
Claude Code saves the values under `pluginConfigs` in your user settings.

### Saved chats and your privacy

Claude Code keeps each session's transcript in your home folder, and deletes it after a while. The save-chat hook
keeps a copy inside the project, so the reasoning behind the work survives.

- When: each time Claude finishes a reply, before each compaction and at the end of the session.
- What: `<session-id>.jsonl` first, then the session's folder (subagent transcripts, tool results), only the
  files that changed. One line per run goes to `claude-chats/copies.log`.
- Where: `claude-chats/`, created with mode 700 and a `.gitignore` holding `*`, so the folder ignores itself.
- A tool that uploads the project folder and ignores `.gitignore` (some CI and deploy tools): list `claude-chats/`
  and `runs/` in its own ignore file.
- An absolute or `..` `chats_dir` falls back to `claude-chats`. The hook never writes into an existing folder that
  holds other files and has no `.gitignore` with `*`, so transcripts can never land in a tracked folder.
- The hook never prints, always exits 0, and stays inside the short time Claude Code gives hooks at session end.

**Transcripts are plain text and can hold secrets**: tokens, passwords, personal data, anything you pasted. Never
commit the folder, never share it, never paste from it. Back it up only to storage you control. To stop saving,
set `save_chats` to `false`.

**Keep Claude Code's own copies longer.** Claude Code deletes transcripts after `cleanupPeriodDays`, 30 days by
default. Put a large value in `~/.claude/settings.json` (the minimum is 1; 0 is rejected):

```json
{ "cleanupPeriodDays": 3650 }
```

### The hooks

All three need `node` on PATH. They never fail a call: on any error they print nothing and exit 0.

- **The Bash guard** (`hooks/guard-bash.mjs`, on the Bash and PowerShell tools) blocks the full-match `pkill -f`,
  and any kill fed by a full-match `pgrep -f`, because both kill the calling shell itself: the pattern is also in
  that shell's command line. It blocks what deletes your data or settings on a phone: `adb uninstall`,
  `adb shell pm clear`, `pm uninstall`, `settings put`, and `flutter install` (it removes an installed copy before
  it installs). Only you allow those, with `DEVICE_WRITE_OK=1` in the environment or in `scripts/tools/tools.env`.
  A command that names an emulator's serial (`adb -s emulator-5554 ...`, `flutter install -d emulator-5554`, or
  `ANDROID_SERIAL=emulator-5554` right before `adb`) runs them without it: an emulator holds no one's real data.
  When a command takes a device or a lot of memory (`flutter run`, `flutter drive`, `flutter build`, `adb install`,
  an emulator, a Gradle build), it shows you a one-line warning as the command starts and gives Claude a note.
  Announcing such a job first stays Claude's rule (`AGENTS.md`). `flutter clean` gets a note only.
- **The token guard** (`hooks/token-guard.mjs`) reads the size of the last model call from the transcript. Past
  `context_budget_k`, it tells Claude, once per step (the budget, then every half budget more), to hand off at the
  next clean point, and shows you one line. It stays silent below the budget and inside subagents.
- **The chat saver** (`hooks/save-chat.mjs`): see above.

### Memory and tokens

Every model call re-sends the whole context, so a long session costs many times a short one: measured on real
projects, sessions that ran to 400K tokens and more spent most of their tokens in those late calls. The kit's
answer is a context budget (the token guard), a short `docs/HANDOFF.md`, a log that is never read whole, and lean
agents (the session-rules and multi-agent playbooks).

Memory is the other limit: an analyzer, a test run, a Gradle build and an emulator at once can freeze a 16 GB
machine. The tools in `scripts/tools/` run one heavy job at a time. For one machine-wide queue across every project
and agent, a memory cap per job and a watchdog, install the separate RAM plugin:

```bash
claude plugin install perfect-vibecoding-ram-management --marketplace abdel-hilali/perfect-vibecoding-ram-management --scope user
```

The tools find its `ram.sh` by themselves and run through `ram.sh run`; without it they use their own lock. A
build and a device test (`q-test.sh -d <serial>`) run alone in the queue.

### Updates

A marketplace that is not Anthropic's does not update by itself. Update the plugin when you want:

```bash
claude plugin update perfect-vibecoding-rules-flutter@perfect-vibecoding-rules-flutter
```

Or turn on auto-update: `/plugin` > Marketplaces > `perfect-vibecoding-rules-flutter` > Enable auto-update. A
running session keeps the old version: start a new session, or run `/reload-plugins`.

An update never touches the files already copied into your project: they are yours. To add template files that
are new in the kit, run `/perfect-vibecoding-rules-flutter:new-project` again: the installer adds only missing
files. For a changed template, compare by hand.

### Uninstall

```bash
claude plugin uninstall perfect-vibecoding-rules-flutter@perfect-vibecoding-rules-flutter --scope project
claude plugin marketplace remove perfect-vibecoding-rules-flutter
```

The files copied into the project stay. Delete what you no longer want. `claude-chats/` holds transcripts: delete
it, or keep it somewhere private.

## Without the plugin: copy the skills and wire the hooks by hand

Use this when you want the skills in every project on your machine, without a marketplace.

1. Get the kit, into a folder you keep (or download the ZIP):
   `git clone https://github.com/abdel-hilali/perfect-vibecoding-rules-flutter.git`.
2. Copy the skills: `mkdir -p ~/.claude/skills && cp -R perfect-vibecoding-rules-flutter/skills/* ~/.claude/skills/`.
   They then run as `/code-rules`, `/gate` and so on, without the prefix. Where a skill names
   `/perfect-vibecoding-rules-flutter:gate`, read `/gate`. Paths written as `${CLAUDE_PLUGIN_ROOT}` mean your copy of
   the kit. A skill of yours with the same folder name is replaced: check `~/.claude/skills/` first.
3. Wire the hooks in `~/.claude/settings.json` (every project) or in a project's `.claude/settings.json`. Use the
   absolute path of your copy, and merge with the hooks you already have:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|PowerShell",
        "hooks": [
          { "type": "command", "command": "node", "args": ["/ABSOLUTE/PATH/perfect-vibecoding-rules-flutter/hooks/guard-bash.mjs"], "timeout": 10 }
        ]
      }
    ],
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "node", "args": ["/ABSOLUTE/PATH/perfect-vibecoding-rules-flutter/hooks/token-guard.mjs"], "timeout": 5 }] }
    ],
    "PostToolUse": [
      { "matcher": "*", "hooks": [{ "type": "command", "command": "node", "args": ["/ABSOLUTE/PATH/perfect-vibecoding-rules-flutter/hooks/token-guard.mjs"], "timeout": 5 }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "node", "args": ["/ABSOLUTE/PATH/perfect-vibecoding-rules-flutter/hooks/save-chat.mjs"], "async": true }] }
    ],
    "PreCompact": [
      { "hooks": [{ "type": "command", "command": "node", "args": ["/ABSOLUTE/PATH/perfect-vibecoding-rules-flutter/hooks/save-chat.mjs"], "timeout": 30 }] }
    ],
    "SessionEnd": [
      { "hooks": [{ "type": "command", "command": "node", "args": ["/ABSOLUTE/PATH/perfect-vibecoding-rules-flutter/hooks/save-chat.mjs"] }] }
    ]
  }
}
```

Without the plugin there are no plugin options: the save-chat hook saves into `claude-chats/`, and the token guard
reads its budget from `TOKEN_GUARD_BUDGET_K` (default 200; `0` turns it off), for example in the `env` block of the
same settings file. To stop a hook, leave out its entries.

4. Copy the project files into each app with the installer (next section).

To update: `git pull` in your copy of the kit, then copy the skills again (step 2). The hooks run from your copy,
so they update with the pull.

## Use it with any AI tool

The rules do not depend on Claude Code. Get the kit once, into a folder you keep:
`git clone https://github.com/abdel-hilali/perfect-vibecoding-rules-flutter.git`. Then, from the folder that holds it:

```bash
node perfect-vibecoding-rules-flutter/install.mjs path/to/my_app
```

The installer copies `AGENTS.md`, `CLAUDE.md`, `docs/`, `tool/kit/`, `scripts/tools/`, the analyzer rules, the
design-direction form, and the skills as plain playbooks in `docs/playbooks/`. It adds the `.gitignore` lines the app
lacks and writes a `.gitattributes` when the app has none. It fills the project name (the `name` in `pubspec.yaml`)
and today's date, and leaves the one-line purpose for you. It never overwrites a file: it lists what it skipped, so
running it twice is safe. Options: `--no-playbooks` (the Claude Code plugin already provides the skills),
`--with-boilerplate` (the starter code, only into a fresh app), `--dry-run` (show the plan, write nothing). Then ask
your AI tool to follow `docs/playbooks/new-project/SKILL.md`.

- **`AGENTS.md` holds every always-on rule.** Most AI coding tools read it at the project root by themselves.
- **A tool that reads only its own rules file** (such as `GEMINI.md`, `.cursor/rules/`, `.clinerules` or
  `.github/copilot-instructions.md`): point that file at `AGENTS.md`, with an import where the tool has one, or
  one line: "Read and follow AGENTS.md at the project root before any task."
- **The skills follow the open Agent Skills format** (a folder with a `SKILL.md` and its frontmatter). Nine load
  as they are in any tool that loads Agent Skills. `new-project` also uses two Claude Code fields
  (`disable-model-invocation`, `argument-hint`): delete those two lines before you load it elsewhere, since a
  strict loader rejects unknown keys. Any other tool finds the skills through the "Playbooks" table at the end of
  `AGENTS.md`.
- **The three hooks are Claude Code only.** Their rules are also written in `AGENTS.md`: never `pkill -f`, kill by
  PID, never uninstall the app or clear its data on your phone, announce a job that takes a device or a lot of
  memory, change session past the context budget, keep chat transcripts in a folder that ignores itself in git.

To update: `git pull` in your copy of the kit, delete `docs/playbooks/`, and run the installer again. It never
overwrites a file, so only what you deleted is refreshed; compare a changed template by hand.

## Where it runs

| Part | macOS | Linux | Windows |
| --- | --- | --- | --- |
| The hooks and `install.mjs` (Node 18 or newer) | yes | yes | yes |
| The Dart checks in `tool/kit/` (`dart run`) | yes | yes | yes |
| The shell tools in `scripts/tools/` (bash) | yes | yes | inside WSL only |
| `sweep-owners.py` (Python 3) | yes | yes | yes; the command may be `py` instead of `python3` |

- The shell tools need bash (3.2 is enough), Flutter on PATH (or `FLUTTER` in `tools.env`), git, Python 3, and
  `flock` for their own queue (Linux has it; on macOS install it, or the queued tools warn and run without the
  queue). With the RAM plugin installed they use its queue instead.
- iOS builds and simulators need a Mac; everything else runs on Linux too.

## Contribute

Issues and pull requests are welcome. Keep the kit generic and plain:

- No name, host, account or date from a real project. Code examples use neutral names (`orders`, `invoices`,
  `members`) and `example.com`.
- Plain English, short sentences, imperative voice. Say what to do and why.
- A skill: a `SKILL.md` with `name` (the folder's name) and `description` (what it does, then "Use when ...", at
  most 600 characters). The most important rules go at the top; the body stays near 120 lines, and detail goes in
  supporting files. The body is tool-neutral; Claude Code mechanics go in one paragraph that starts with
  "In Claude Code:".
- Scripts: Node 18 ESM without dependencies; Dart with only `dart:` imports, run as `dart run tool/kit/<x>.dart`;
  Python standard library run with `python3 -I`; bash with `set -u` that works on Linux and macOS (bash 3.2). Each
  prints a usage line on wrong arguments and never needs the network. Comments say why. Never `pkill -f` or
  `pgrep -f` as a command.
- Each area has its tests in `tests/<area>/run.sh`, with fixtures in `tests/<area>/fixtures/`.

Run every test before a pull request, from any folder:

```bash
bash tests/run-all.sh                  # every area, strict: a problem in any part of the kit fails
bash tests/run-all.sh install static   # some areas only
bash tests/run-all.sh --lenient        # problems in files another part of the kit writes only warn (KIT_STRICT=0)
```

The `checks` area runs Dart; on a busy machine, run it through the RAM plugin's queue:
`ram.sh run -- bash tests/run-all.sh`. An area whose `run.sh` is missing is listed as skipped, never as passed.

The `static` area checks the syntax of every script, every JSON and ARB file, the skill format, the hooks and the
plugin manifest, and scans for anything that looks like a real host, e-mail address, IP address or home folder (the
kit's own repository URL is the one exception). Real names (your apps, your company) are never written in the kit,
not even in the test: give them at run time, `KIT_PRIVATE_PATTERN='name1|name2' bash tests/run-all.sh static`, and
the scan fails on every line that holds one. `KIT_CLAUDE_VALIDATE=1` also runs `claude plugin validate .`. The
tests never run `flutter`: the tools are tested against stub commands.

## License

MIT. See [LICENSE](LICENSE).
