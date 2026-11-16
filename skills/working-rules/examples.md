# Working rules: message templates

Short templates for the messages the working rules ask for. Fill the angle brackets. Keep each message short: the
owner reads it between other work.

## Budget, before a launch

> **Recommended: A.** <one line: why>.
> - **A (recommended):** <what runs>. About <N> M tokens, <time range>. Stops cleanly at <point>.
> - **B:** <a smaller option>. About <N> M tokens. Stops cleanly at <point>.
> - **Stop here:** 0 tokens. The tree builds; left for later: <what>.
>
> What is your budget for today?

Estimate a task as its tool calls times its average context: every call re-sends the whole context. A package of 60
calls at about 80K tokens is about 5 M tokens, most of them cache reads (cheaper, but they count). Measure your own
from the transcripts.

## "How much is left?"

> Before the next boundary (<name>): <what is left>, about <N> M tokens, <time range>.
> Cheapest clean stop: <point>. There, <what is done>, and nothing runs.
> Say "stop" or "go".

## A stage update

> **<Stage> done** (<clock time from `date`>). <One line: what changed>.
> Next: <stage>, about <time range>. Next update at <milestone>, or in 20 minutes at the latest.
> Where to look: <the table below, or "nothing to see on the phone yet">.

When an estimate slips, say it at once:

> Slipping: <stage> needs about <new range> more (I said <old range>). Why: <one line>.

## Where to look

| Screen | Account | Build | What you see | Do not tap |
| --- | --- | --- | --- | --- |
| Orders tab | a test account with orders | debug on your phone: press R (hot restart) in your IDE | the status chip on every row, in both themes | "Cancel order" (cancels a real order) |
| Settings, then Theme | any account | the APK `<absolute path>/app-debug.apk`; installing it keeps your data | "System" is the default; your choice stays after a restart | nothing writes here |
| Members, then a member | a project owner | the store's internal test, 1.4.0 (52): update from the store | the role badge beside each name | "Remove" (removes a real member) |

Which build, in one line each:

- **Debug from your IDE:** "press r" (a widget changed), "press R" (a new route, a changed `main.dart`, a value set
  once at start), or "stop and run again" (a new plugin, a native file, a change in `pubspec.yaml`, the launcher
  icon, the splash).
- **An APK file:** its absolute path. Over a store or release copy, a debug APK needs an uninstall first, which
  deletes the app's data: say so and ask.
- **The store's internal test:** the version and build number, and that it can take some minutes to appear.

Plumbing only:

> Nothing to see on the phone yet: this stage is <entities / fakes / catalog keys>. The first visible change comes
> with <stage>.

A state the test account never reaches:

> The empty state and the error state do not show with this account. The widget tests prove them:
> `test/features/orders/presentation/pages/orders_page_test.dart` (four states, light and dark).

## A question

> **<Topic>?**
> 1. **<Option> (recommended).** <Why. Cost.>
> 2. <Option>. <Why not. Cost.>
> 3. <Option>. <Why not. Cost.>
>
> "Do the recommended" takes option 1.

## A conflict with the conception

> **Conflict: <topic>.** I settle it before I build.
> - The conception: <its reading, with the section>.
> - The backend contract: <its reading, with the endpoint or the doc section>.
> - The design: <its reading>.
>
> **Recommended: <keep the conception and file backend ask #N | amend the conception: a new line in
> docs/DECISIONS.md>.** Why: <one line>.

## Outside edits

Find what moved since the last session, across the whole workspace:

```bash
find . -newermt "<YYYY-MM-DD HH:MM>" -type f \
  -not -path './build/*' -not -path '*/.dart_tool/*' -not -path './.git/*' \
  -not -path './runs/*' -not -path './claude-chats/*'
```

Report each one, with what you did and why:

> Edits since the last session that are not mine:
> - `lib/features/orders/domain/usecases/get_orders.dart`: kept. Correct, and its new test fails when the code is
>   broken.
> - `lib/core/l10n/app_fr.arb`: corrected. One key was missing its placeholder. Backup: `<absolute path>`.
> - `lib/features/orders/presentation/pages/orders_page.dart`: undone. It broke the analyzer. Backup:
>   `<absolute path>`.

## A heavy job or the phone

> Running the debug build now, alone in the queue: about <N> minutes and 3 GB; the machine is slower meanwhile.

> May I install the debug build on your phone (<model>, serial <serial>)? It replaces the build you have; your data
> stays (same signature). **Recommended: yes.**

## A commit message

```text
feat(orders): show an empty state with a create button

The list was blank for new accounts, and people did not know what to do next.
```

Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `test`, `ci`. The scope is the feature or area. The summary is
imperative, lower case, without a final period, at most about 72 characters.

## A release

> Ready for release 1.4.0 (52), after the gate (verify 214/214, the build ok, your check on the phone):
> - Ships: <the changelog lines under "Unreleased">.
> - Needs first: <a backend change deployed, or "nothing">.
> - To upload: `build/app/outputs/bundle/release/app-release.aab`, to the internal test track first.
> - The symbols are kept in `runs/release/1.4.0+52/` (they decode crash traces from this release).

## Before the owner stops

> If you push now, this ships: <list>. Not ready yet: <list>.
> To save the work without shipping it: commit on a side branch first, then `git push origin HEAD:wip-<topic>`.

## A read-only probe of a live backend

One sign-in, reads only, everything in a temp folder. Print status codes and key names, never bodies. The test
account comes from the environment, never typed into the command; the token goes through a curl config file, so it
never shows in the process list. The token's field name (`accessToken` here) is your backend's.

```bash
dir="$(mktemp -d)"
printf '{"email":"%s","password":"%s"}' "$DEMO_EMAIL" "$DEMO_PASSWORD" |
  curl -s -o "$dir/signin" -w 'sign-in %{http_code}\n' \
    -H 'content-type: application/json' --data @- "$API_URL/auth/login"
python3 -I -c 'import json,sys; t=json.load(open(sys.argv[1]))["accessToken"]; open(sys.argv[2],"w").write("header = \"Authorization: Bearer %s\"\n" % t)' "$dir/signin" "$dir/curlrc"
curl -s -K "$dir/curlrc" -o "$dir/body" -w 'GET /orders %{http_code}\n' "$API_URL/orders"
python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); r=d[0] if isinstance(d,list) and d else d; print(sorted(r) if isinstance(r,dict) else type(r).__name__)' "$dir/body"
rm -rf "$dir"
```
