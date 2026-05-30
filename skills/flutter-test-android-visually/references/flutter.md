# Flutter on Android — run, launch, and logs

> Read `capture-loop.md` for the universal screenshot/log/iterate loop. This file only covers the Flutter-specific run command, app-id discovery, and log source — feed the run command below to `launch.sh`.

## Running the app

The base command is `flutter run -d <id>`. But on a real project you almost never run that bare form — discover the right flags FIRST (see below). Feed the full command to `launch.sh` with `--log` so stdout is captured:

```bash
launch.sh --log /tmp/flutter-run.log -- \
  flutter run -d <id> \
    --target=lib/main_android.dart \
    --dart-define-from-file=environments/.env.development
```

REQUIRED in many repos:
- `-d <id>` — pin the device serial. With multiple devices/emulators attached, `flutter run` otherwise prompts interactively and `launch.sh` hangs on the prompt.
- `--target=lib/main_xxx.dart` (`-t`) — mandatory in multi-entry apps. Many codebases ship several entrypoints (`main_dev.dart`, `main_prod.dart`, Android/iOS shells) and make bare `lib/main.dart::main()` `throw` by design so a forgotten target fails loudly instead of shipping the wrong build. If `lib/main.dart` throws on launch, you missed the target — read `CLAUDE.md`/`README` for the right one.

OPTIONAL but often expected:
- `--dart-define-from-file=environments/.env.<env>` — injects build-time config (`String.fromEnvironment`). Without it, `API_URL`-style values are empty and the app may fail to boot or hit a dead host.
- `--dart-define=KEY=VALUE` — individual defines (repeatable). Some repos require e.g. `--dart-define=IS_IOS=true` to pick a shell; on Android you usually omit it.
- `--flavor <name>` — only if the Gradle build declares product flavors. A wrong/absent flavor surfaces as a Gradle error, not a Dart one.
- `--debug` is the default and is what you want for the loop (hot reload only works in debug). Don't pass `--release` — it strips the VM Service and disables `r`/`R`.

**How to discover the exact command:** grep `CLAUDE.md`, `README*`, `Makefile`, `.vscode/launch.json`, and `melos.yaml`/`justfile` for `flutter run` / `--target` / `--dart-define`. The project's documented invocation is authoritative; do not guess the entrypoint.

## Finding the application id (package name)

Needed for `am start`, `am force-stop`, `pm grant`. Sources, in order of reliability:

```bash
# 1. Source of truth — the Gradle build script (Kotlin DSL or Groovy):
grep -R "applicationId" <project>/android/app/build.gradle.kts \
                        <project>/android/app/build.gradle
```

`applicationId "com.example.app"` (Groovy) or `applicationId = "com.example.app"` (Kotlin DSL). Note: `applicationId` can differ from the Kotlin/Java `namespace` and from the `package` in `AndroidManifest.xml`. The installed package = `applicationId` (+ any `applicationIdSuffix` from the active flavor/buildType — check those too).

```bash
# 2. Ask the device what third-party packages are installed.
#    NOTE: `pm list packages` is NOT ordered by install recency — the
#    output order is unspecified, so don't assume the first/last line is
#    "what Flutter just installed". Filter by the applicationId prefix
#    you found in step 1 instead of trusting position:
adb -s <id> shell pm list packages -3 | grep com.example
```

```bash
# 3. Whatever is in the foreground right now (most reliable if the app is
#    open on screen after a fresh launch):
adb -s <id> shell dumpsys activity activities | grep -m1 mResumedActivity
```

## Knowing when the first frame is up

Two stdout milestones in the captured log, in order:

1. Build/install done + VM up: a Dart VM Service line —
   `A Dart VM Service on <device> is available at: http://127.0.0.1:NNNNN/...`
   immediately followed by the interactive banner:
   ```
   Flutter run key commands.
   r Hot reload. 🔥🔥🔥
   R Hot restart.
   h List all available interactive commands.
   d Detach (terminate "flutter run" but leave application running).
   c Clear the screen
   q Quit (terminate the application on the device).
   ```
2. First frame: the banner means the engine is up, but the Dart UI may still be one frame behind. Wait ~2s after the banner before the first `snap.sh`, or grep the log for the app's own startup print/route log.

Timing reality: a warm rebuild reaches the banner in seconds. A COLD run (fresh checkout, `flutter clean`, or first build after a dependency/Gradle/Kotlin change) runs Gradle from scratch — **2–6 minutes**, sometimes more on a slow host or first AGP download. Common mistake: screenshotting at 10s and capturing the OS launcher or a white/splash frame. Poll the log for the banner; don't assume a fixed sleep.

## Reading logs

Two complementary streams:

- **`flutter run` stdout** (the `--log` file from `launch.sh`): this is your primary source. It carries Dart `print`, `debugPrint`, and `dart:developer` `log()` output, plus framework exceptions (`══╡ EXCEPTION CAUGHT BY …╞══`, `RenderFlex overflowed`, `setState() called after dispose`).
- **logcat** for native/engine errors that never reach Dart stdout (crashes, `pm grant` denials, GL/Skia, plugin JNI):

```bash
capture-logs.sh -s <id> --filter "*:E flutter:V"   # bundled helper, or raw:
adb -s <id> logcat -d '*:E' flutter:V               # quote *:E so the shell doesn't glob it
```

In a logcat filterspec, each later `tag:priority` pair overrides earlier ones, so `*:E flutter:V` sets the default for all tags to Error-and-above while keeping the engine's `flutter` tag verbose. Benign noise to ignore: `OpenGLRenderer`/`eglMakeCurrent`/`Davey! duration` jank warnings, `Choreographer skipped frames`, `mali`/`adreno` driver chatter, `BufferQueueProducer` notices, and a single `D/EGL_emulation` block on emulators. A real problem is a `FATAL EXCEPTION` / `AndroidRuntime` block or a Dart stack in the run log.

## Stopping & iterating

In an interactive terminal you'd press `r` (hot reload) / `R` (hot restart). Under `launch.sh` the process is detached and has no attached TTY, so those keystrokes aren't available — **re-iterate by restarting the run** via `stop.sh` then a fresh `launch.sh`. (If you need true hot reload you can drive the Dart VM Service URL printed in the log, but a clean restart is simpler and more reliable for the loop.)

```bash
stop.sh                                   # kills the recorded flutter-run PGID
adb -s <id> shell am force-stop <app-id>  # also clear the app off the device
```

`stop.sh` ends the host `flutter run` process group; `am force-stop` removes the still-resident app from the device (Flutter often leaves it running after the host process dies — `q`'s job, which you can't send here).

## Pitfalls specific to Flutter

- **Don't abort a cold build early.** No banner after 30–60s on a fresh build is normal, not a hang. Gradle is downloading/compiling. Watch the log for `Running Gradle task 'assembleDebug'…`; only treat it as stuck if that line sits unchanged for minutes with no CPU.
- **Gradle/Kotlin/`pubspec.yaml`/plugin changes need a clean.** Symptoms: stale `R.java`, "Execution failed for task ':app:…'", duplicate-class, or a UI that doesn't reflect a new dependency. Fix: `flutter clean && flutter pub get` then re-run (this forces another cold build — budget the time).
- **`--release`/`--profile` kill the loop.** No VM Service, no hot reload, no Dart `print` over the run channel. Always loop in debug.
- **Interactive device prompt deadlock.** Omitting `-d <id>` with >1 device makes `flutter run` block on a "Please choose a device" prompt that never gets input under `launch.sh`. Always pin `-d <id>`.
- **Wrong/missing `--target`.** A `StateError`/`UnsupportedError` thrown immediately at launch (visible in the run log, app closes instantly) usually means bare `lib/main.dart` ran. Supply the documented `--target`.
- **Empty `--dart-define` config.** If the app boots but can't reach its backend or shows a config-missing screen, you likely forgot `--dart-define-from-file`. These values are compile-time — changing the `.env` file requires a full restart, not a hot reload.
- **`pm grant` before first frame can be rejected** for runtime permissions until the app is installed and has declared them; grant after the install line appears in the log, or the device shows the OS permission dialog over your screenshot.
