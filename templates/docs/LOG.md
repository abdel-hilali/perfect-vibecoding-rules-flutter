# {{PROJECT_NAME}}: the log

Append-only, newest entry last. **Never read this file whole:** `tail -n 60 docs/LOG.md` shows the newest entries;
`grep -n '<word>' docs/LOG.md` finds an older one, then read that part by line range. Every call re-sends what you
read, so a whole log costs tokens on every call that follows.

How to keep this file:
- One heading per session or per stage, with the clock time from `date`: `### YYYY-MM-DD HH:MM: <what>`.
- In each: the owner's words verbatim, in quotes, with the time; every decision and its reason (a product decision
  also gets its line in `docs/DECISIONS.md`); what was launched and what it cost; what landed; the checks with real
  numbers; what was installed on which device.
- Never edit an old entry. A correction is a new entry that names the old one.
- At each session boundary, the old `docs/HANDOFF.md` comes here first, whole, under its own heading.
- Over 1,500 lines: move the older entries, whole, to `docs/log/LOG-<YYYY-MM>.md` (the month of the move), keep about
  the newest 200 lines here, and add the moved file to the line below.

Older entries: none yet.

---

### {{TODAY}}: the record opened

- The record created from the template.
