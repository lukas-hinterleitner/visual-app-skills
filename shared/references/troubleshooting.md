# Troubleshooting & pitfalls

The failure modes that trip up an agent doing visual verification, and how to
avoid each. Most are framework-agnostic; a few framework specifics live in the
per-framework reference instead.

## Capture

- **Multiple devices, no `-s`.** When more than one device is attached, every
  `adb` call must pass `-s <id>` or it errors / hits the wrong device. The
  bundled scripts refuse to guess and ask you to pin one — respect that.
- **PNG corruption.** Always `adb exec-out screencap -p`, never
  `adb shell screencap -p > file.png` — the shell layer can CR-LF-translate the
  binary and produce a broken PNG. `snap.sh` already uses `exec-out`.
- **Black/blank screenshot.** If shots come back black for >30s after the
  runtime is ready, the emulator's GPU may be hung (cold-boot wedge). Tell the
  user and stop — don't loop. A cold-booted emulator sometimes needs a
  `-no-snapshot` restart.

## Timing

- **Splash vs content.** Screenshotting during the splash is a false negative.
  Wait for the *first real frame*, not just "build done" — see the per-framework
  reference for the exact signal, then give it ~1–2s more.
- **Giving up on a cold build too early.** A cold Gradle build (fresh checkout,
  after a clean, or when dependencies re-download) routinely takes several
  minutes. If you bail at 2 minutes you abandon a build that was about to finish
  *and* the next attempt restarts from scratch. Use the `timeout 360 bash -c
  'until …'` poll from `capture-loop.md`; only treat it as failure once the
  timeout actually returns non-zero, then show the last log lines.

## Process hygiene

- **Orphaned children.** A plain `kill` on the launcher's pid leaves children
  (a bundler, a build daemon, the app-runner) alive and holding the device or a
  port. `launch.sh` uses `setsid` and `stop.sh` does `kill -- -<pgid>` to take
  out the whole group — use them, or replicate the process-group kill yourself.
- **Don't kill unrelated daemons.** Long-lived IDE/build daemons (a Gradle
  daemon, a `flutter_tools … daemon`, a shared Metro server) may be reused
  across runs. Only kill the process group you launched.
- **Log file growth.** A `--follow` logcat or a chatty run can produce a huge
  log. `capture-logs.sh` uses `-d` (dump-and-exit) and `-t <lines>` precisely to
  avoid this. If your run log balloons, stop the run, truncate, relaunch — don't
  `tail -f` a multi-hundred-MB file.

## Build staleness

- **Stale native build.** If the recent change touched native code, Gradle
  config, or the dependency manifest, an incremental run may not pick it up.
  When behavior is off in ways that don't match the diff, suggest a clean
  rebuild (the per-framework reference gives the exact command).

## Scope reminder

These skills are **Android-only** — they drive `adb` against a device or
emulator. They are not:

- pixel-perfect golden/screenshot-diff tests (use the framework's golden
  tooling),
- headless CI end-to-end tests (use the framework's instrumentation runner),
- iOS verification (that needs a Mac and `xcrun simctl`).

Use this for the fast, interactive "did my last change actually render
correctly" check.
