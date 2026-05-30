# The universal capture loop

This is the framework-agnostic procedure every skill in this collection
follows. The only framework-specific pieces are **the run command** and
**where the app logs** — those live in `references/<framework>.md`. Everything
below is identical whether the app is Flutter, React Native, native Android, or
anything else that installs an APK.

The bundled scripts under `scripts/` wrap the fiddly commands with device
disambiguation. Prefer them; the raw `adb` commands are shown so you can run
them by hand when a script does not fit.

## Preflight

Run these before anything else. If preflight fails, **stop and tell the user** —
don't try to recover silently.

1. **Device check.** `scripts/check-devices.sh` must print a serial. If it
   reports none, tell the user "no Android device or emulator is connected".
   Don't auto-boot an emulator unless the user asks — booting is slow and may
   not be what they want.
2. **Toolchain check.** Confirm the build tool for this project is on PATH
   (`flutter --version`, `node --version` + the project's package manager,
   `./gradlew --version`, …). The per-framework reference says which.
3. **Run-command discovery.** This is where projects differ most:
   - Read `CLAUDE.md`, `AGENTS.md`, or `README` for a documented run command.
   - Open `references/<framework>.md` for the canonical invocation and the
     flags that matter (entry-point/target, build flavor, dart-defines, etc.).
   - Some projects have a **mandatory** entry flag (e.g. a multi-entry app whose
     default entry point throws by design). If unsure, ask the user once —
     "What's the dev run command for this project?" — rather than guessing wrong
     and burning a build.

If `check-devices.sh` lists more than one device, pin one with `-s <id>` for
**every** adb call. Forgetting `-s` is the single most common cause of
"works for me but not for you".

## The loop

1. **Launch** the app in the background with logs going to a file:
   ```bash
   scripts/launch.sh --log /tmp/run.log -- <the run command from references/<framework>.md>
   ```
   `launch.sh` runs the command under `setsid` and records the process group so
   `scripts/stop.sh` can later kill the whole tree (build daemon, bundler, and
   app-runner included).
2. **Wait for the first real frame** — not the splash. The per-framework
   reference names the exact log signal ("build done + app rendered") and the
   realistic wait, including cold builds. Poll the log with an until-loop rather
   than guessing an interval:
   ```bash
   timeout 360 bash -c 'until grep -q "<signal from references/<framework>.md>" /tmp/run.log 2>/dev/null; do sleep 5; done && echo READY'
   ```
   If `timeout` returns non-zero, tail the last ~30 log lines and show the user —
   it's usually a real build error worth surfacing, not a transient to retry.
3. **Navigate** to the screen under test if it isn't the entry screen. Use
   `adb input` (see `driving-the-ui.md`). If the change is on the first screen,
   skip this.
4. **Screenshot:**
   ```bash
   scripts/snap.sh /tmp/screen.png            # auto-picks the only device
   scripts/snap.sh -s <id> /tmp/screen.png    # pin when several are attached
   ```
5. **Capture logs** scoped to the app or to errors:
   ```bash
   scripts/capture-logs.sh --app <applicationId> /tmp/applog.txt
   ```
   plus the run log from step 1 (that's where `print`/`console.log`/`Log.d`
   output lands for most frameworks).
6. **Analyze** the PNG and the logs (next section), then either **iterate**
   (hot-reload per the framework reference and re-snap) or **stop**:
   ```bash
   scripts/stop.sh
   ```

## Analyzing the screenshot

Read the PNG with the `Read` tool — you are multimodal and will see the image.
Cross-check it against the change the user just made:

- **Layout.** Is the element you added/moved/resized actually where it should
  be? Are siblings still aligned? Any visible overflow or clipping?
- **Theme.** Do colors match the project's design tokens? Is the typographic
  hierarchy reasonable?
- **State.** Is data loaded (no stuck spinner, no error placeholder where
  content belongs)? Are interactive elements enabled when they should be?
- **Log signal.** Cross-reference the logs: overflow warnings, uncaught
  exceptions, red-box errors, failed network calls (4xx/5xx)?
- **Don't over-read benign noise.** A transport-level network timeout in the
  log is only a problem if the UI is *actually* showing an error state — many
  apps fall back to cached data and render fine. Flag a log line as a problem
  only when the screen confirms it.

## Reporting the verdict

End with a short, evidence-backed verdict the user can act on:

> **Change appears correct.** The new "Reset" button is visible top-right and
> uses the secondary brand color. Tapping it logs `Controller.reset`.
> Screenshot: `/tmp/screen.png`.
>
> **One concern:** it sits 4px under the safe area — likely needs top padding
> in `lib/.../header.dart`.

Be concrete: reference the screenshot path, quote the key log line, and if
something is wrong say *what* and *which file* likely needs editing. Don't pad
with hedging — if the change is correct, say so plainly.
