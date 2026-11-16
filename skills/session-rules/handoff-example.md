# A good handoff

Write `docs/HANDOFF.md` like this at every boundary, whole, after the old one went to the end of `docs/LOG.md`. Each
line answers a question the next session would otherwise have to dig for. The names, numbers and dates below are
made up.

```markdown
# Example app: the handoff

**State (2031-03-04 17:42, from `date`): wave 2 landed. This session ends here. READ THIS FIRST.**
- **State:** wave 2 (invoices list, invoice detail, members page) is built and uncommitted on `main`.
  `main` = `origin/main` = `4f2c9e1` = release 1.3.0+41 on the store's internal test. 31 changed paths, each
  claimed by one package. Targeted checks at 17:31: analyze 0 issues; check_structure 0 errors on the changed
  files; check_l10n ok, 3 locales. Backup of the uncommitted tree: `runs/wave-2/backups/landed-0304/`.
- **Runs or not:** nothing of ours runs. The emulator was closed at 17:40 (`emu kill`); the queue is empty.
  The owner's phone (serial `ABC123XYZ`) has the debug build of 15:10; their IDE runs `flutter run` on it.
- **Not run, on purpose:** no full suite, no build, no device test. The gate runs once, before the push.
- **Open for the owner:**
  1. The members page shows e-mail addresses to every role. Keep it, or managers only?
     **Recommended: managers only.** The answer becomes a line in `docs/DECISIONS.md`.
  2. Do not push before the gate. To save the work without shipping it: commit on a side branch, new files
     included, then `git push origin HEAD:wip-wave-2`. Until then the only copy is the backup above.
- **Known and left on purpose:** the invoice PDF opens in the system viewer, not in the app (wave 3).
- **NEXT, in order:**
  1. The owner's answer to question 1: a one-line change in `appRedirect()` and its test (about 50K tokens).
  2. One review round and a fixer over wave 2 (about 2M tokens).
  3. A NEW session for the full gate: verify, the debug build, the owner's check on the phone. Then the owner pushes.
- **Read next:** `docs/PROGRESS.md` §3.0 and §5; `grep -n '2031-03-04' docs/LOG.md` for today's entries.
- **Paste-ready prompt for the next session:** *"Continue the project. Read docs/HANDOFF.md whole first, then
  tail -n 60 docs/LOG.md. My answer to question 1: ..."*
```

## Why it works

- The time comes from `date`, and "this session ends here" tells the reader it is the last word.
- It says where the code is: branch, commit, pushed or not, which release is out, and where the backup is.
- It says what runs, or "nothing runs", and what is on the owner's phone.
- It says what was **not** run, so nobody reads "done" as "tested".
- Each question carries the recommendation, marked.
- NEXT is in order, with costs, and says which step needs a new session.
- "Read next" names the exact sections and log entries, so the next session reads a few lines, not the record.

## Gaps that cost the next session an hour

- "Tests pass", with no numbers and no time.
- Uncommitted work and no backup path.
- "Continue where we left off" as the prompt.
- A time written from memory.
- A handoff that copies whole sections of `docs/PROGRESS.md`, or grows past 80 lines with history: that is the log.
- No word on what is installed on the owner's phone, so the next session installs over it.
