# {{PROJECT_NAME}}: the owner's decisions

The owner's product decisions, one numbered line each, newest last. **Grep it before you ask the owner anything:**
`grep -n -i '<word>' docs/DECISIONS.md`. The answer may already be here.

How to keep this file:
- One line per decision: `D<n> · <YYYY-MM-DD from date> · <the decision, in a few words> · "<the owner's words>"`.
  The owner's words go in verbatim, in quotes, even when short ("yes", "do the recommended").
- Numbers never change and are never reused. A changed decision is a new line that says `replaces D<n>`; the old
  line gets ` (replaced by D<m>)` at its end. That is the only edit allowed.
- Product decisions only: what the app does, shows and allows, for whom; what may be done on the owner's phone. The
  plan goes in `docs/PROGRESS.md`, the history in `docs/LOG.md`. Never put decisions in `AGENTS.md` or
  `CLAUDE.md`: those load on every call.
- Two examples of the form (not decisions):
  `D7 · 2031-03-04 · Members see e-mail addresses only for managers · "managers only, the others do not need it"`
  `D8 · 2031-03-05 · Debug builds may go on the owner's phone unasked; never uninstall · "install it, never delete it"`

---

## Decisions

None yet.
