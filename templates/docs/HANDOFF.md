# {{PROJECT_NAME}}: the handoff

The current state only, for the next session. **A new session reads this file whole, first.** At most 80 lines.

How to keep this file:
- Rewrite it whole at every session boundary; never append to it. First copy the old text to the end of
  `docs/LOG.md`, under a heading with the time from `date`.
- Clock times come from `date`, never from memory or an estimate.
- Write it before you say "This is a session boundary. The handoff is written. Open a new session." Keep it
  resumable at all times: the owner may close the session at any moment.
- Point to the plan (`docs/PROGRESS.md`), the owner's decisions (`docs/DECISIONS.md`) and the history
  (`docs/LOG.md`); never copy them here.

---

**State ({{TODAY}}): the record is open. READ THIS FIRST.**
- **State:** nothing built yet. Nothing is uncommitted.
- **Runs or not:** nothing runs. No emulator. Nothing installed on the owner's phone by us.
- **Open for the owner:** paste the brief into `docs/PROGRESS.md` §1, word for word.
- **NEXT, in order:**
  1. Fill §1 (the brief) and §2 (the rules this work follows) of `docs/PROGRESS.md`.
  2. Plan the stages in §3 and put each open question in §4, the recommendation first.
  3. Start stage 1 after the owner's yes and their budget.
- **Read next:** `docs/PROGRESS.md` §1 to §4.
- **Paste-ready prompt for the next session:**
  *"Continue {{PROJECT_NAME}}. Read docs/HANDOFF.md whole first, then tail -n 60 docs/LOG.md, then the parts of
  docs/PROGRESS.md the handoff names."*

<!-- The shape of each new handoff (it replaces the block above, whole):
**State (YYYY-MM-DD HH:MM, from `date`): <one line>. READ THIS FIRST.**
- **State:** what is built, committed, pushed, released (version x.y.z+build, which track). What is uncommitted,
  and its backup path. The last checks with their numbers and times.
- **Runs or not:** "nothing runs", or each process left running on purpose, and why. What is on the owner's phone
  (its serial, which build, from when) and whether their IDE runs `flutter run` on it. Emulators: none, or which.
- **Not run, on purpose:** the legs of the gate not run yet, and why.
- **Open for the owner:** each question or action waiting on them, the recommendation first and marked.
- **Known and left on purpose:** small issues you chose not to fix now, one line each.
- **NEXT, in order:** numbered steps, each with its rough cost and where its inputs are. Say which needs a new session.
- **Read next:** the docs/PROGRESS.md sections and the docs/LOG.md headings (grep -n) that NEXT needs.
- **Paste-ready prompt for the next session:** *"Continue <work>. Read docs/HANDOFF.md whole first ..."*
-->
