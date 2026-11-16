@AGENTS.md

# Claude Code notes for {{PROJECT_NAME}}

The rules are in `AGENTS.md`, imported above. These notes add only what is specific to Claude Code.

- **Skills.** With the plugin `perfect-vibecoding-rules-flutter`, the playbooks of `AGENTS.md` are skills that
  load by themselves; run one with `/perfect-vibecoding-rules-flutter:<skill>`: `code-rules`, `recipes`,
  `screen`, `gate`, `device`, `tools`, `multi-agent`, `session-rules`, `working-rules`, `new-project`.
  `.claude/skills/design-direction/SKILL.md` holds the settled design direction: keep it current.
- **Hooks.** The Bash guard denies `pkill -f`, kills fed by `pgrep -f`, and writes to a phone (`adb uninstall`,
  `pm clear`, `settings put`, `flutter install`) unless the owner set `DEVICE_WRITE_OK=1` or the command names an
  emulator (`emulator-NNNN`). `flutter run`, `flutter build`, `adb install` or an emulator show the owner a one-line
  warning as they start: say it before. The token guard says when the context passes the budget: hand off at the
  next clean point. The save-chat hook copies each transcript into `claude-chats/`, which ignores itself in git:
  never commit or share it.
- **Plugin options** (`/config`): `save_chats` (on), `chats_dir` (`claude-chats`), `context_budget_k` (`200`;
  `0` turns the notice off).
- **Keep the transcripts.** Claude Code deletes them after `cleanupPeriodDays` (30 by default): set
  `{ "cleanupPeriodDays": 3650 }` in `~/.claude/settings.json`.
- **Long runs.** Start long commands and `scripts/tools/wait-milestone.sh` with the Bash tool's background
  option, so their end wakes you. Copy each workflow script into `runs/<topic>/` at launch: a new session cannot
  resume an old run.
- **Memory.** With the RAM plugin `perfect-vibecoding-ram-management`, the queued tools share one machine-wide
  queue with memory caps (`ram.sh status`); without it, their own lock.
- **Bash calls** sent together share one working directory: use absolute paths.
