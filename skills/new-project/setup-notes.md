# Setup notes

Details for steps 4 to 7 of the new-project playbook.

## analysis_options.yaml (step 4)

- The flutter create file holds one `include: package:flutter_lints/flutter.yaml`, an empty `linter: rules:` and
  comments. The kit's file includes the same package, so a replacement loses nothing:
  `cp <kit>/templates/analysis_options.yaml analysis_options.yaml`, with the owner's yes.
- A file the team changed: keep its `include:` and its own rules. Add the kit's `analyzer:` block (the strict
  language modes, the `exclude:` list of generated files) and the kit's `linter: rules:` that the file lacks. A
  rule the team turned off on purpose stays off: ask, and record the answer in `docs/DECISIONS.md`.
- The analyzer reads only the app's root file. A nested `analysis_options.yaml` (in a package of a monorepo) gets
  the same merge when that package should follow the rules.

## The boilerplate (step 5)

- The installer moved the flutter create demo files it replaced (`lib/main.dart`, `test/widget_test.dart`,
  `android/app/src/main/res/values/styles.xml` and `values-night/styles.xml`) into `runs/kit-install/<time>/`. A
  demo file that no longer held the demo's own text was kept: its note names the kit file to merge by hand.
- The pubspec fragment goes into three places of `pubspec.yaml`: its packages under `dependencies:` (and
  `dev_dependencies:`), `generate: true` under `flutter:` (gen-l10n needs it), and its `assets:` and `fonts:` lists
  under `flutter:`. A package the app already has keeps the app's version unless the owner says otherwise.
- Run `flutter pub get`, then `flutter gen-l10n`: the generated catalog lands in `lib/core/l10n/generated/`, which
  the size limits and the checks skip. Then `dart fix --apply --code=directives_ordering` and `dart format lib test`
  (step 5): the renamed imports sort in another place.
- To undo the boilerplate before the first commit: delete what it added and move the files in
  `runs/kit-install/<time>/` back.

## The Gradle heap (step 6)

The lean settings, with the reasons, are in `<kit>/templates/boilerplate/android/gradle.properties`. The three lines
that matter, in place of the template's `org.gradle.jvmargs` line:

```properties
org.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=1g -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
kotlin.daemon.jvmargs=-Xmx1g
org.gradle.daemon.idletimeout=900000
```

- `-Xmx3g`: a Flutter release build fits; the 8 GB of the template can freeze a 16 GB machine beside the editor, a
  browser and the agents.
- `kotlin.daemon.jvmargs`: the Kotlin daemon is a second JVM; without a cap it takes as much as Gradle.
- `org.gradle.daemon.idletimeout`: an idle daemon leaves after 15 minutes instead of 3 hours.
- Keep the file's other lines (`android.useAndroidX` and the like). With the RAM plugin, `ram.sh doctor <app-dir>`
  names this setting and the others that make a machine run out of memory.

## Line endings and ignores (step 7)

- `.gitattributes`: `*.sh text eol=lf`, `*.py text eol=lf`, `*.mjs text eol=lf`, `*.dart text eol=lf` and
  `scripts/tools/tools.env text eol=lf`. A Windows clone checks text out with CRLF by default, and bash rejects it.
- `.gitignore`: a line in another form counts (`/runs` for `runs/`, `**/*.jks` for `*.jks`, `/build/` for
  `build/symbols/`). The installer appends what is missing under one comment line and never removes a line.
- `android/.gitignore` from flutter create already ignores `key.properties` and the keystores inside `android/`; the
  root lines also cover a keystore saved anywhere else in the app.
