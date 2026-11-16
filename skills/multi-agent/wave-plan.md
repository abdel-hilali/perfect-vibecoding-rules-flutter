# Wave plan: the form

Write the plan in `runs/<topic>/PLAN.md` (or in `docs/PROGRESS.md`, section 3) before any builder starts. Builders get
their own package plus sections 1 and 2. Replace the example lines; keep the headings.

## 1. Ownership rules (tell every builder)

Number them, so a brief or a review can cite "O3".

- **O1** A package writes ONLY its listed files. Anything else goes in its report under "Needs from others"; the
  finish pass applies it.
- **O2** The interfaces in section 2 are frozen after wave 1: later waves may ADD members, never change or remove one.
- **O3** The ARB catalogs are written by ONE package per wave, every locale together. The others name the keys they
  need, with the English text and the placeholders, under "Needs from others".
- **O4** Shared registration files are handed on in this order, one owner at a time:
  `lib/core/router/app_router.dart` = A1 (wave 1), then B2 (wave 2, the invoices branch only);
  `lib/core/config/injection-modules/invoices_module.dart` = A1 (wave 1), then B1 (wave 2, `createInvoiceController`
  only).
- **O5** Import by file path, never through a barrel file (a `<feature>.dart` that exports everything): a barrel
  would be one file every package edits.
- **O6** `pubspec.yaml` and `pubspec.lock` are not touched in this wave. The dependencies were added on the owner's
  yes and fetched once (`flutter pub get`, queued) before the launch.
- **O7** Only the orchestrator writes the record (`docs/HANDOFF.md`, `docs/PROGRESS.md`, `docs/LOG.md`,
  `docs/DECISIONS.md`). Packages write their own report.

## 2. Interfaces frozen at the end of wave 1

One row per shared class or key. "Shape" says exactly what another package may rely on.

| interface | file (owner) | shape · rule |
| --- | --- | --- |
| `Invoice`, `InvoiceStatus` | `lib/features/invoices/domain/entities/invoice.dart` (A1) | `status` is `draft`, `sent` or `paid`; `paidAt` is null until paid |
| `InvoicesRepository` | `lib/features/invoices/domain/repositories/invoices_repository.dart` (A1) | `Future<Result<List<Invoice>>> list({required String projectId})`; never sends an empty filter |
| `GetInvoices` | `lib/features/invoices/domain/usecases/get_invoices.dart` (A1) | `call({required String projectId})`, returns the repository's `Result` unchanged |
| `InvoicesPage.path` | `lib/features/invoices/presentation/pages/invoices_page.dart` (A1) | `'/invoices'`; the route and a "coming soon" body exist first, B1 builds the page in wave 2 |
| `invoicesEmptyTitle`, `invoicesErrorRetry` | `lib/core/l10n/app_*.arb` (A2) | in every locale; no placeholders |
| `context.colors.invoiceOverdue` | `lib/core/theme/app_colors.dart` (A2) | a token in both `light` and `dark` |

## 3. Packages

Per package, at most about 8 files:

**A1: invoices contract layer (wave 1).** Reads: the spec sections it needs, `docs/RULES.md` F2 to F5.
- **Owns (new):** `lib/features/invoices/domain/entities/invoice.dart`,
  `lib/features/invoices/domain/repositories/invoices_repository.dart`,
  `lib/features/invoices/domain/usecases/get_invoices.dart`, `lib/features/invoices/data/models/invoice_model.dart`,
  `lib/features/invoices/data/repositories/invoices_repository_impl.dart` (+ their tests).
- **Owns (changed):** `lib/core/router/app_router.dart` (adds `invoicesRoutes()`).
- **Builds:** section 2 exactly.
- **Tests:** the model (a good row, a bad row), the repository over a fake data source (success and each failure).
- **Report:** `<project>/runs/<topic>/reports/A1.md` · **Backups:** `<project>/runs/<topic>/backups/A1/` (absolute).

## 4. Launch checklist

- [ ] Every file appears in at most one "Owns" list of this wave; each shared registration file has one owner.
- [ ] Every frozen interface exists, and the analyzer and its tests pass.
- [ ] `pubspec.yaml` changes are in and fetched, or none are needed.
- [ ] Each package has at most about 8 files and names exactly what to read.
- [ ] Each brief names its report path and backup folder, both absolute and unique.
- [ ] Each brief points to `docs/BUILDER-RULES.md` and asks for the structured result.
- [ ] The launch script is saved in `runs/<topic>/`.
- [ ] The owner knows the cost estimate and where to look when the first package lands.

## 5. Sweeps after the wave

**md5 sweep.** Run it the moment the wave lands, before the finish pass writes anything. Each builder ends its report
with the md5 of each file it wrote. Collect those lines into `runs/<topic>/md5-owners.txt`, one line per file as the
builder's command printed it (`<md5>  <path>`, paths from the app root). Then, from the app root:

```bash
md5sum -c --quiet runs/<topic>/md5-owners.txt             # Linux: prints only the files that changed
# macOS: md5 -r prints one space where md5sum prints two, so compare the two fields, not the raw lines
md5 -r $(awk '{print $2}' runs/<topic>/md5-owners.txt) | diff <(awk '{print $1, $2}' runs/<topic>/md5-owners.txt) -
```

A file listed there was rewritten after its owner finished. Read its diff, keep the right version, and find out who
wrote it (the ownership sweep usually tells).

**Ownership sweep**, after the finish pass. Every changed path must be claimed by exactly one agent. Pass the
journals of every run since the last commit (earlier waves, the finish pass):

```bash
python3 -I scripts/tools/sweep-owners.py <journal.jsonl> [<journal.jsonl> ...]
# --repo <app folder> when APP_DIR (the environment, else tools.env) is not the app
# exit 1 = an unclaimed path or a same-run conflict
```

Generated files (`lib/core/l10n/generated/`, `*.g.dart`) show as unclaimed when someone regenerated them: claim them
for the package that changed their source.

No journal (builders started by hand, or a tool that keeps none)? Save each builder's structured result as one JSON
line in `runs/<topic>/results.jsonl`, then sweep that file:

```json
{"type":"result","agentId":"A1","result":{"files_changed":["lib/core/router/app_router.dart"],"files_created":["lib/features/invoices/domain/entities/invoice.dart"],"files_deleted":[],"touched_outside_list":[]}}
```
