# {{PROJECT_NAME}}: the plan

{{PURPOSE}}

Opened {{TODAY}}. The plan and the decisions, updated in place the day each stage lands. Never a log, never a
handoff. **A new session reads `docs/HANDOFF.md` first, whole, then only the sections here that the handoff names.**
The section numbers never change, so references hold.

How to keep this file:
- The current state for the next session goes in `docs/HANDOFF.md`, rewritten at each boundary. The history goes in
  `docs/LOG.md`, newest last: the owner's words, launches and their cost, checks with numbers. Neither goes here.
- The owner's product decisions go in `docs/DECISIONS.md`, one numbered line each. §1b here says only what each one
  changes in the plan.
- Clock times come from `date`, never from memory or an estimate.

---

## 0. State

- **Code:** branch `<branch>`, last commit `<sha>`; pushed: yes / no.
- **Released:** version `<x.y.z+build>` on `<the store's internal test / production / none>`.
- **Uncommitted:** none / `<n>` paths; backup: `runs/<topic>/backups/<name>/`.
- **Devices:** the owner's phone is serial `<serial>`; what we may do on it: see `docs/DECISIONS.md`.
- **Open risks:** none yet.

## 1. The brief (verbatim)

> Paste the owner's request here, exactly as written. Do not summarize it.

## 1b. The owner's decisions that shape the plan

The decisions themselves live in `docs/DECISIONS.md`. Here: one line per decision that changes this plan.

| Decision | What it changes in the plan |
| --- | --- |
| D1 | |

## 2. Rules

- The project rules: `AGENTS.md` and `docs/RULES.md`. Builders also follow `docs/BUILDER-RULES.md`.
- Rules for this work only: add them here, one line each, with the reason.

## 3. Stages

### 3.0 Order

1. `<stage>`: what it delivers, which packages, rough cost in tokens, status (planned / running / landed / gated /
   pushed / released).

### 3.1 Ownership

Each package (one agent's assignment) owns a list of files that no other package touches. Shared registration files
(`lib/core/router/app_router.dart`, a module in `lib/core/config/injection-modules/`, the ARB catalogs,
`pubspec.yaml`) have one owner per wave. Anything else goes in the package's report under "Needs from others". The
full rules: `docs/BUILDER-RULES.md`.

### 3.2 Interfaces frozen

Entities, repository interfaces, use cases, route paths, catalog keys and theme tokens that later packages read.
Add to them; never remove or narrow one.

## 4. Open questions for the owner

Each open question: the question in one line, the readings, **the recommendation (marked)**, what each option costs.
An answer becomes a line in `docs/DECISIONS.md`, and the question leaves this list.

### 4b. Calls taken without asking

Small calls the agent took on its own. The owner may veto any of them; each is cheap to change.

## 5. Screens

One row per screen this work touches.

| Screen | Route (`path`) | Status (planned / coming soon / built / gated) | Waits for | Left to do |
| --- | --- | --- | --- | --- |
| | | | | |

## 6. Asks, risks, traps

- **Backend asks:** each `docs/BACKEND-ASKS-<n>.md` part, sent or not, and its answer.
- **Risks:** the open risks, one line each, with what would show it.
- **Traps:** the ones that already cost time here, one line each, with the fix.
