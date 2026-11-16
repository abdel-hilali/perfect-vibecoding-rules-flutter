---
name: device
description: Works with the owner's phone and with emulators safely - list the devices first, never take the owner's phone without a yes, never uninstall, clear data, install a differently signed build or change settings on it, one flutter run per device, screenshots cropped, small and kept local, logcat filtered by the app's PID, emulators only on the owner's yes when memory allows, closed after. Use when running the app on a phone or an emulator, using adb, taking a screenshot, reading device logs, or when a device is "unauthorized" or "offline".
---

# The owner's phone and emulators

## Rules first

1. **List the devices first.** `adb devices -l` gives each serial, its state and its model; `flutter devices` gives
   the ids Flutter uses (iOS too). Pass the serial to every command (`adb -s <serial>`, `flutter run -d <serial>`):
   with two devices connected, a command without it lands on the wrong one.
2. **The owner's phone is theirs.** Never install on it, run on it or drive it (taps, `am start`, `am force-stop`)
   without the owner's yes, unless `docs/DECISIONS.md` allows it (`grep -n -i -E 'phone|device' docs/DECISIONS.md`).
   An install replaces the app they are testing.
3. **Never destroy the owner's data.** Never `adb uninstall`, `pm clear` or `pm uninstall` on their phone, and never
   install a differently signed build over their copy: the install fails, and the only way past is an uninstall. The
   app's local data dies with it: the session, drafts, settings, a pending upload.
4. **Never change phone settings:** no `settings put`, `cmd uimode`, `pm grant`, `pm revoke`, `wm size`,
   `wm density`, no `adb reboot`. Ask before `adb kill-server`: it cuts the owner's IDE from the phone.
5. **One `flutter run` per device.** The owner's IDE may run one already: look first (below). Two runs fight over the
   same app on the same device.
6. **Screenshots stay on this computer**, cropped and small, and are deleted after.
7. **Logs: the app's PID only, never the whole logcat.** The whole log holds other apps' data and costs many tokens.
8. **Emulators cost 2 to 4 GB.** Start one only on the owner's yes, when `scripts/tools/q-status.sh` shows nothing
   heavy, outside the queue (Emulators, step 3), without saving a snapshot, and close it when the task ends.
9. **Stop a process by PID, never by name.** Never `pkill`, `killall`, or `pgrep -f` fed to a kill.

## Before you touch a device

```bash
adb devices -l                                          # serial, state, model
ps -eo pid=,args= | grep -E '[f]lutter_tools[.]snapshot( .*)? (run|attach)( |$)'  # a run, and its -d or --device-id
grep -n 'applicationId' android/app/build.gradle*       # the app id
adb -s <serial> shell dumpsys package <app id> | grep -E 'versionName|versionCode|installerPackageName|DEBUGGABLE'
```

- `unauthorized`: the owner must accept the debugging prompt on the phone. `offline`: ask the owner to replug it.
- `installerPackageName=com.android.vending` (the store's copy) or no `DEBUGGABLE` line (a release build): a debug
  build cannot go over it without an uninstall. Stop and ask. Even your own release build cannot replace the store's
  copy: the store signs it with its own key.
- Write which serial is the owner's phone in `docs/HANDOFF.md`, so the next session does not have to guess.

## Run and install

- The safest way to show a change: the owner presses hot reload (`r`) or hot restart (`R`) in their own
  `flutter run`. Say which one (the screen playbook, step 4).
- On the owner's yes, run it yourself, detached, with its output in `runs/`:
  `flutter run -d <serial> --pid-file runs/<topic>/run.pid > runs/<topic>/run.log 2>&1 < /dev/null` (Linux: start
  it with `setsid nohup`). Hot reload: `kill -USR1 $(cat runs/<topic>/run.pid)`; hot restart: `kill -USR2 ...`;
  stop: `kill $(cat runs/<topic>/run.pid)`.
- `flutter run` installs over a same-signed debug copy and keeps its data. When the install fails (another
  signature, a lower version), it uninstalls by itself ("Uninstalling old version...") and the data dies. Check the
  installed copy first (above).
- Never `flutter install` on the owner's phone: it uninstalls first, every time. To hand over an APK, on the owner's
  yes: `adb -s <serial> install -r build/app/outputs/flutter-apk/app-debug.apk` keeps the data when the signature
  matches, and fails without harm when it does not. Never add `-d` (a downgrade) without asking: an older build may
  not read newer local data.
- An app bundle (`.aab`) does not install on a phone: it goes to the store, whose internal test track the owner uses.
- Integration tests (`integration_test/`) build, install and drive the app: the same yes as an install. One file at
  a time: `scripts/tools/q-test.sh -d <serial> integration_test/<file>_test.dart` (the gate playbook, tier 2, step 3).

## Screenshots

```bash
mkdir -p runs/<topic>/shots
adb -s <serial> exec-out screencap -p > runs/<topic>/shots/<name>.png
magick runs/<topic>/shots/<name>.png -gravity South -crop 100%x94%+0+0 +repage -resize 50% runs/<topic>/shots/<name>-small.png
```

- `exec-out`, not `shell`: `adb shell` can mangle the binary. `convert` instead of `magick` on ImageMagick 6.
- Crop the status bar: it shows the time and the owner's notifications, and a notification that drops at that moment
  shows a message. When you check the edges (F9), look at the full shot once, then delete it.
- Downscale before you look: half size is enough to judge a layout and costs a fraction of the tokens. Look only
  when the owner needs you to.
- Never put a shot in git, a report, a web service or a message to anyone. Delete the shots when the task ends.

## Logs

```bash
adb -s <serial> logcat -d --pid=$(adb -s <serial> shell pidof -s <app id>) | tail -n 80
adb -s <serial> logcat -d -b crash | grep -A 20 '<app id>' | tail -n 60   # after a native crash
```

- `-d` prints what is there and stops; without it logcat runs forever. No PID means the app is not running: start it,
  or read the output of `flutter run`.
- A log can hold tokens, e-mails and ids: it stays on this computer. The app itself never logs a token or a body
  (F6, F13).

## Emulators

1. Ask the owner: an emulator takes 2 to 4 GB while it runs.
2. Check the machine: `scripts/tools/q-status.sh`. Start only when no heavy job runs and at least 4 GB is free.
3. Start it detached, from outside the app folder, with its log in `runs/` (macOS: `nohup ... &`, then `disown`),
   and wait for the boot (the first emulator is `emulator-5554`; another one already up makes yours `emulator-5556`:
   check `adb devices -l`, and use your serial below, or you close someone else's):

   ```bash
   emulator -list-avds
   ( cd "$HOME" && setsid nohup emulator -avd <name> -no-snapshot-save -no-boot-anim -memory 2048 \
       > <project>/runs/<topic>/emulator.log 2>&1 < /dev/null & )
   adb -s emulator-5554 wait-for-device shell \
     'while [ "$(getprop sys.boot_completed)" != 1 ]; do sleep 2; done'
   ```

   Never wrap it in `ram.sh run` or a `q-*` tool: the queue would keep a slot and the app folder's lock for the
   emulator's whole life, and every analyzer, test and build would wait for it.
4. On an emulator you started, settings are yours: dark mode `adb -s emulator-5554 shell cmd uimode night yes`,
   large text `adb -s emulator-5554 shell settings put system font_scale 1.3` (`1.0` after). With the serial in the
   command, the hook lets them run without `DEVICE_WRITE_OK`. On the owner's phone they still need the owner's yes.
5. Close it when the task ends: `adb -s emulator-5554 emu kill`. If it hangs, find its PID
   (`ps -eo pid=,args= | grep -- '[-]avd <name>'`), check that it is the one you started, then `kill <pid>`.

`-no-snapshot-save` stops the emulator from writing a multi-GB snapshot on close. iOS (on a Mac): the same rules; a
simulator you started is yours like an emulator, the owner's iPhone is theirs.

In Claude Code: the plugin's Bash hook refuses `adb uninstall`, `pm clear`, `pm uninstall`, `settings put` and
`flutter install` (it uninstalls first) unless `DEVICE_WRITE_OK=1` is set in the environment or in
`scripts/tools/tools.env`: only on the owner's yes to that very command, and back to 0 right after. On an emulator
they run without it when the command names its serial: `adb -s emulator-5554 ...`, `flutter install -d emulator-5554`
or `ANDROID_SERIAL=emulator-5554 adb ...`. Each command counts alone: one with no serial or a phone's stays refused.
When a command takes a device or a lot of memory (`flutter run`, `flutter drive`, an integration test, `adb install`,
`emulator -avd`, `flutter build`), the hook shows the owner a one-line notice as it starts and gives you a note: say
it first. It blocks `pkill -f`. Start long processes with the Bash tool's background option or detached, and open a
screenshot only after you downscale it.
