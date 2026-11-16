---
name: design-direction
description: Holds the settled visual direction of this Flutter app and the owner's corrections that produced it - identity, register, the palette tokens in both themes, the font and its weights, the top bar, the bottom bar, the icon family, radius, motion, the system bars, the launcher icon and the splash, and the traps. It exists so settled corrections are never re-litigated. Use when starting any design work, using a design tool for a screen, or changing a colour, a token, the font, the top bar, the bottom bar, the icons, the launcher icon or the splash.
---

# Design direction: settled

**Status: not filled yet.** Until the owner fills this file, nothing below is settled: the "Example:" lines are
samples, not this project's direction, so never apply one. Follow the tokens and widgets already in the code, and ask
the owner before you set anything new that fixes the look (a colour, the font, a bar, the icon family). Delete this
status line when the file is filled.

Once filled, everything below is settled by the owner. Do not reopen it, and do not re-derive it from the full design
spec. A new idea that contradicts a line here goes to the owner as a question, never straight into code.

When the owner corrects the direction, add the correction here the same day, in their words, with what it replaced.
A correction that arrives after the code is built costs a rebuild. Written here, it is made only once.

> How to fill this file: under each heading, replace the prompt (the quoted line) with your project's answer.
> Keep the example line's shape: short, concrete, with exact values. Delete the prompts and examples when done.

## Fixed, never changes

> The identity no redesign may touch: the brand colour (exact values, light and dark), the logo, the brand feel.

Example: the brand colour is `#2563EB` in light and `#60A5FA` in dark; the logo and the brand feel are fixed.

## Latitude you have

> What you may tune without asking, and the one thing inside it you may not move.

Example: the spacing inside cards, the radius scale, the chart colours. Not the 4 dp grid of `AppSpacing`.

## The register

> The feel the owner wants, in their own words, and the feel that was tried and rejected.

Example: quiet and dense, like a ledger: hairlines, no shadows, no gradients. A rounded, playful look was tried and
rejected. Keep the role tokens: they are how dark mode stays consistent.

## Palette: the tokens, in both themes

> Each role token of `AppColors` with its light and dark value, and where the accent may and may not appear.

Example:

| Token | Light | Dark | Role |
| --- | --- | --- | --- |
| `surface` | `#FAFAFA` | `#0B0B0C` | the page; also the status bar, the top bar and the bottom bar |
| `surfaceRaised` | `#FFFFFF` | `#161618` | cards and sheets |
| `onSurface` | `#111113` | `#F2F2F3` | text and active icons |
| `onSurfaceMuted` | `#6B6B70` | `#9A9AA0` | secondary text, inactive tabs |
| `primary` / `onPrimary` | `#2563EB` / `#FFFFFF` | `#60A5FA` / `#0B0B0C` | the one primary button of a screen, the active tab, links |
| `outline` | `#E4E4E7` | `#2A2A2E` | hairlines and field borders |
| `danger` | `#DC2626` | `#F87171` | errors and destructive actions only |

The accent marks the primary action and the active tab, nothing else. A new token goes in both themes, on the
owner's yes (`lib/core/theme/app_colors.dart`).

## Type: the font and its weights

> The one bundled font family, the weights declared in `pubspec.yaml`, the scale, the fallback for other scripts.

Example: Inter, bundled in `assets/fonts/`, weights 400, 500 and 600 declared in `pubspec.yaml` (never `google_fonts`
at run time: it downloads on first start). `AppTextStyles`: title 20/600, body 15/400, label 13/500, caption 12/400.
Arabic falls back to a bundled Noto Sans Arabic.

## The top bar

> Its colour, title style and place, what it holds, and each first instinct the owner corrected.

Example: the app's own top bar in `surface`, painted under the status bar; the title 17/600 at the start, never
centred; a back button only on pushed pages; at most two actions, icons with tooltips. No shadow: a hairline appears
when content scrolls under it (a shadow was tried and rejected).

## The bottom bar

> The tabs and their order, icons only or with labels, the active style, badges.

Example: four tabs (Home, Orders, Messages, Profile), icons with labels, always shown (icons only was tried and
rejected: people did not know the third icon). Active: the `_active.svg` icon and its label in `primary`; inactive:
`onSurfaceMuted`. A hairline in `outline` on top; 180 ms change; a selection click; the bar in `surface` runs under
the gesture bar. Badges are a dot, or a count clamped to text scale 1.15.

## Icons

> The one family, where the files live, the sizes.

Example: Lucide until the designer's set arrives, through `AppIcons` and `AppIcon`, sizes 16, 20 and 24
(`AppIconSize`). The designer's SVGs go in `assets/icons/common/` and `assets/icons/nav/` (`orders.svg`,
`orders_active.svg`), single colour. Never Material icons beside them.

## Radius and motion

> The radius of each kind of surface; the durations and curves.

Example: `AppRadius` 8 for fields and buttons, 12 for cards, 20 for the top corners of sheets. `AppMotion` 150 to
300 ms (400 ms for a sheet), `Curves.easeOutCubic`; none when animations are disabled.

## System bars and edges

> The rule below is fixed for every app (`docs/RULES.md` F9). Write here only what this app adds.

The rule: edge to edge; the status bar and the navigation bar take the page's colour through `systemOverlayFor`,
with icons opposite to the page; never one `SafeArea` around the app; bottom bars paint under the gesture bar.

Example: the camera and the media viewer are always dark (their own `AnnotatedRegion`, light icons). The splash and
the first frame share `surface`, so the start never flashes.

## The launcher icon and the splash

> The source art, the icon background, the monochrome layer, the splash colours in both themes.

Example: the mark from `assets/branding/icon_foreground.png`, inside the 66 dp safe zone, on `#2563EB`, with a
monochrome layer for Android 13 themed icons; iOS without alpha. The splash: the mark centred on `#FAFAFA` in light
and `#0B0B0C` in dark, with a matching `android_12` block. Both show only after a new install, never on hot reload.

## Traps that already bit

> Each trap in two lines: what broke, and the rule that prevents it.

Example: a colour kept as a static constant stayed light after the switch to dark mode. Read `context.colors`, never
a static colour.

## Restraint

> The limits on the register: what the app must never look like, and the test for any effect.

Example: motion is felt, not watched: it explains a change of state, and it runs once. Nothing bounces for attention,
no confetti, no custom page transitions. The test for any effect: does it belong in a serious work tool?

## Where the detail lives

> The full spec and the token files, with the section to open for each kind of change. Never read the whole spec.

Example: `docs/UI-SPEC.md`: §1 Shell, §2 Tokens, §3 Widgets, §4 Screens, §5 Motion. Tokens:
`lib/core/theme/app_colors.dart`, `app_text_styles.dart`; icons: `lib/core/theme/app_icons.dart`.

## Using a design tool

> When a design canvas or tool is worth it, and what to read before you open it.

Example: read this file first, then open the design tool, so the mockups start from the settled direction. Frames at
360x800 and 320x640, in both themes, with the status bar and the gesture bar drawn, so the edges are designed too.

In Claude Code: this file is a project skill, so it loads by itself when a design task starts.
