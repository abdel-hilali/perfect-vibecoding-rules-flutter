# Rules for every builder: {{PROJECT_NAME}}

You build ONE package of a wave. Several builders work in the SAME working tree at the same time, each on its own
files. Nothing is committed while you work, so there is no safety net: one wrong command destroys the others' work.
The owner may run the app from this tree on their phone (`flutter run` with hot reload), so a broken file can show on
their screen at the next reload.

Your brief adds what is yours: the package id, your file list, what to read, the frozen interfaces, the absolute path
of your report and of your backup folder. The brief wins over this file where they differ.

## 1. Read first, and keep your context small

1. `AGENTS.md`, then the sections of `docs/RULES.md` your brief names (`grep -n '^## ' docs/RULES.md` lists them).
   They are hard constraints.
2. Your brief, then the spec of EACH of your items.
3. Each file you are about to change, as it is NOW. Other builders are editing other files right now, and line
   numbers in the specs may have moved: find each place by its words. If the spec and the code disagree, follow the
   spec's intent with the smallest faithful change, and say so in your report.

The context diet. Every call re-sends your whole context, so what you read is paid again on every call after it:

- Read what your brief names, nothing more. Grep before you read (`grep -n`, `grep -rln`).
- A file over 400 lines: by line ranges, never whole. Never re-read a file you already read or wrote.
- Cap every command's output (`| tail -n 40`); `q-test.sh` prints the failures only.
- No images or PDFs unless your brief says so.
- Aim to finish in about 60 tool calls. Past that, finish the item in hand and report the rest as partial.

## 2. Ownership: hard

- Write ONLY the files in your brief's list, plus the new files your items name. Nothing else.
- A change you need in a file you do not own goes in your report under "Needs from others": the file, the exact
  text, the item it serves. Do not make it yourself, even if it is one line.
- Shared registration files (`lib/core/router/app_router.dart`, a module in `lib/core/config/injection-modules/`,
  the ARB catalogs, `pubspec.yaml`) have ONE owner per wave. Not yours? Name what you need under "Needs from others".
- Never remove or narrow a public class, a member, a route path, a theme token or a catalog key that another file
  reads. Add; do not change. The interfaces in your brief's frozen table are fixed: code against them as written.
  The analyzer covers the tests too, so a "tidy" deletion turns another builder's test red.
- ARB catalogs (when they are yours): small targeted edits, every locale together, the `@key` metadata and the same
  placeholders in each, never a whole-file rewrite. No key twice: such JSON still parses, and the last key wins
  silently. Then `flutter gen-l10n`.
- You never run the app. Put what a run on a phone must prove in your report under "Device checks for later".
- Backups: before a risky edit, copy the file into the ABSOLUTE backup folder your brief gives (unique to your
  package). A relative path resolves against whatever folder you are in, and lands in the wrong place.

## 3. Never

- `git checkout`, `switch`, `stash`, `restore`, `reset`, `clean`, `add`, `commit`, `mv`, `rm`. They rewrite files
  other builders are editing. Read-only git is fine: `status`, `diff`, `log`, `show`, `grep`.
- `flutter clean`: it deletes `build/` and `.dart_tool/` under every other builder and the owner's `flutter run`.
- `dart format .` or `dart format` on a folder, `dart fix --apply`: they rewrite other builders' files.
- `flutter pub upgrade`, and `flutter pub get` or `build_runner` unless your brief says so: they rewrite
  `pubspec.lock` and generated files for everyone.
- `flutter build`, `flutter run`, `flutter install`, `flutter drive`, an emulator, `adb` on any device, the whole
  test suite, `scripts/tools/verify.sh`, a test run on a folder. They take minutes and gigabytes, or the owner's phone.
- `flutter analyze`, `dart analyze`, `flutter test` or `dart test` called directly. Use the queued tools below.
- Anything on the network: `curl`, `wget`, signing in, calling the backend. A live backend may hold real users' data.
- `pkill -f` or `pgrep -f` (the pattern also matches the shell that runs it), `pkill <name>` or `killall` (a name also
  matches other projects' processes). Stop a process by its PID, after you check its working directory
  (`/proc/<pid>/cwd` on Linux, `lsof -a -d cwd -p <pid>` on macOS).
- A new dependency, colour, font, icon, layout or motion your spec does not name.
- A comment that cites a ticket, a decision id, a report, an agent or a job. Comments say why, in the code's terms.
- Any file outside the repository, except your report.

## 4. Build first, check once

1. Build ALL your items, with the tests each spec lists and no more (the test budget of F17; your report gives the
   number of tests you added). Keep every file valid as you go: the owner's hot reload and the other builders'
   analyzer runs read this tree while you work.
2. Then, once, at the end of your package. Each queued tool waits in line behind the other builders (one heavy job at
   a time on this machine), so a wait of several minutes is normal:
   - `dart format <the files you changed>`
   - `scripts/tools/q-analyze.sh` (the whole project). An issue in a file you do not own is not yours: report it.
   - `scripts/tools/q-test.sh <the test FILES you wrote or whose subject you changed>`: files, never a folder.
   - `dart run tool/kit/check_structure.dart --files <the files you changed>`
   - `dart run tool/kit/check_l10n.dart`, when you changed a catalog.
3. Fix what is yours and re-run only what failed. At most three rounds; then report what is still red, and why.

## 5. Your report

Create it at the START, at the absolute path your brief gives: a title and your plan in five lines. Then APPEND as
you go, so a stop loses nothing. At the end it holds:

- per item: done, partial or skipped, and why;
- the files you changed, created and deleted;
- every new or changed catalog key, with its text in each locale; every new theme token (both themes) or icon;
- each deviation from the spec, and its reason;
- **Needs from others**: file, exact text, the item it serves;
- **Device checks for later**: what a run on a phone must prove;
- **Where the owner sees it**: the screen and how to reach it, the account, what the owner sees in one sentence, and
  what not to tap because it would write real data. Or "nothing to see on the phone yet";
- each check of section 4 with its real numbers (analyzer issues, tests passed and failed, findings);
- the md5 of each file you wrote (`md5sum <files>`; on macOS `md5 -r <files>`), so a later sweep can tell whether
  another agent overwrote it.

A refused tool call: wait 30 seconds, retry once, then go on without it and say so in the report.

## 6. Your structured result

Return these keys, even when a list is empty. The ownership sweep reads the first four: a path you changed but did
not list shows up as unclaimed, and someone has to find out why.

```json
{
  "id": "<package>",
  "status": "done | partial",
  "files_changed": ["lib/core/router/app_router.dart"],
  "files_created": ["lib/features/invoices/domain/usecases/get_invoices.dart"],
  "files_deleted": [],
  "touched_outside_list": ["<path> - why"],
  "checks": [{ "command": "scripts/tools/q-analyze.sh", "result": "analyze exit: 0" }],
  "needs_from_others": [{ "file": "<path>", "text": "<exact text>", "why": "<the item it serves>" }],
  "deviations": ["<what and why>"],
  "report": "<absolute path of your report>"
}
```
