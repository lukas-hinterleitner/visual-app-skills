# Native Android (Kotlin/Java) — run, launch, and logs

> Read `capture-loop.md` for the universal launch → snap → log loop. This file only covers the native-Android-specific run command, applicationId discovery, and log source.

## Running the app

Gradle builds and installs but **does not launch** — you always need a separate `am start` / `monkey` step. Feed the build+install to `launch.sh`, then launch.

```bash
# Build the debug APK and install it on the connected device in one task.
# installDebug = assembleDebug + adb install -r under the hood.
./gradlew :app:installDebug
```

Equivalent two-step, useful when you want the APK artifact (e.g. to inspect with aapt2):

```bash
./gradlew :app:assembleDebug
adb -s <id> install -r app/build/outputs/apk/debug/app-debug.apk
```

Then launch (REQUIRED — install never starts the activity):

```bash
# Preferred: explicit component, deterministic.
adb -s <id> shell am start -n <applicationId>/<applicationId>.MainActivity

# Or by launcher intent when you don't know the activity class:
adb -s <id> shell monkey -p <applicationId> -c android.intent.category.LAUNCHER 1
```

`<.MainActivity>` may be a relative suffix (`-n com.foo.app/.MainActivity`) — the leading `.` is shorthand for the applicationId given before the `/`. If the activity's fully-qualified class lives under a different package prefix than the applicationId, give the fully-qualified name. Find the right launcher activity with `adb -s <id> shell cmd package resolve-activity --brief <applicationId> | tail -1`.

Common variants — list the install tasks instead of guessing:

```bash
./gradlew tasks --group=install            # all installXxx tasks for this project
./gradlew tasks --all | grep -i install    # fallback when no install group is registered
```

Flavored projects expose `installFreeDebug`, `installPaidDebug`, etc. (capitalized `install<Flavor><BuildType>`). Pick the variant that matches the applicationId you intend to launch — flavors usually carry a distinct `applicationIdSuffix`, so installing `freeDebug` then launching the `paid` package silently starts nothing.

## Finding the application id (package name)

The applicationId is the runtime package — it is NOT always the source `package`/`namespace`. Always resolve it, don't assume.

```bash
# 1. Source of truth: app/build.gradle(.kts), defaultConfig { applicationId = "..." }
#    plus any applicationIdSuffix on the build type/flavor.
grep -R "applicationId" app/build.gradle*

# 2. Ask Gradle (resolves suffixes for the default variant):
./gradlew :app:properties | grep -i applicationId

# 3. From the built APK (the leading dot-less token after package: name is the applicationId):
aapt2 dump badging app/build/outputs/apk/debug/app-debug.apk | grep "package:"
#   -> package: name='com.foo.app' versionCode='...'

# 4. From the device, after install (narrow with a known fragment):
adb -s <id> shell pm list packages | grep foo
```

You need this exact string for `am start`, `am force-stop`, and `pm grant <pkg> <permission>`.

## Knowing when the first frame is up

Two gates: the build, then the render.

1. Gradle prints `BUILD SUCCESSFUL in <n>s`. A **cold** build (clean checkout, cold daemon, no remote cache) is routinely 1–5 min and can exceed that on a large multi-module project; warm incremental builds are seconds. Do not start polling for a frame until you've seen `BUILD SUCCESSFUL` — installing/launching against a stale or failed build screenshots the previous version.

2. The window actually drew. ActivityTaskManager emits a `Displayed` line when the first frame is presented:

```bash
adb -s <id> logcat -d | grep "Displayed <applicationId>"
#   -> ActivityTaskManager: Displayed com.foo.app/.MainActivity: +812ms
```

Or poll the resumed activity directly:

```bash
adb -s <id> shell dumpsys activity activities | grep mResumedActivity
```

The classic mistake: snapping immediately after `am start`. You capture the splash screen (`windowBackground` / `windowSplashScreenAnimatedIcon`), not your UI. Wait for the `Displayed` line — the `+NNNms` suffix is the time-to-first-frame; only after it is the content laid out. For apps with an async splash (data load before first real screen), `Displayed` fires on the splash activity, so also wait for your home screen's own log marker before judging the UI.

## Reading logs

Logcat is the only stream. Filter by the live PID so you see just this app:

```bash
adb -s <id> logcat --pid=$(adb -s <id> shell pidof -s <applicationId>)
```

`pidof -s` returns a single PID; if the app spawns a `:remote` process, drop `-s` and pass multiple `--pid` flags. The PID changes on every relaunch and on a crash-restart — re-resolve it after each launch. `capture-logs.sh` (logcat dump) captures the same stream; pass it the applicationId/PID filter so the dump isn't system-wide noise.

Tag-based filtering when you control the source (`Log.d("MyTag", …)`):

```bash
adb -s <id> logcat -d MyTag:D '*:S'     # only MyTag at debug+, silence the rest
adb -s <id> logcat -d '*:E'             # all errors, fast triage
```

Crashes surface under the `AndroidRuntime` tag (`FATAL EXCEPTION`) and in `DEBUG`/`tombstoned` for native crashes — grep those first.

Benign noise to ignore: `Choreographer: Skipped N frames` (jank, not a crash), `OpenGLRenderer`/`HWUI` chatter, `StrictMode` policy logs, `Accessing hidden API` greylist warnings, and `Davey! duration=…`. None indicate a build/launch failure.

## Stopping & iterating

There is no hot reload for native Android — every code change needs a rebuild + reinstall. Compose has **Live Edit** (literal edits to `@Composable` bodies) and Layout Inspector live updates, but those only work from Android Studio's instrumentation, not from a CLI loop; from the command line, treat each iteration as a fresh `installDebug` + relaunch.

```bash
# Stop the current foreground run cleanly (kills recorded process group):
stop.sh

# Force-stop the app on the device (kills all its processes; next launch is cold):
adb -s <id> shell am force-stop <applicationId>

# Re-run the loop:
./gradlew :app:installDebug && \
  adb -s <id> shell am start -n <applicationId>/<applicationId>.MainActivity
```

Keep the Gradle daemon warm between iterations (don't `--no-daemon`); it's the single biggest factor in incremental rebuild speed.

## Pitfalls specific to native Android

- **Install without launch.** The number-one omission: `installDebug` exits 0 and nothing is on screen. Always follow with `am start` / `monkey`.
- **Wrong variant launched.** `installDebug` on a flavored project may install a different applicationId than the one you `am start`. Resolve the variant's actual applicationId (suffixes included) and launch that exact string.
- **`namespace` ≠ `applicationId`.** AGP separates the source package (`namespace`) from the shipped `applicationId`. Grepping `namespace` and launching it starts nothing. Use the applicationId methods above.
- **minSdk / device mismatch.** `INSTALL_FAILED_OLDER_SDK` (device API < `minSdk`) or `INSTALL_FAILED_NO_MATCHING_ABI` (e.g. arm-only native libs on an x86 emulator) make install fail — read the `adb install` stderr, don't assume the launch step is the problem.
- **Stale install after a signing/applicationId change.** `INSTALL_FAILED_UPDATE_INCOMPATIBLE` means a previously-installed build has a different signature. `adb -s <id> uninstall <applicationId>` then reinstall.
- **Runtime permissions block first render.** If the app gates its first screen on a permission, pre-grant it so the UI renders for the screenshot: `adb -s <id> shell pm grant <applicationId> android.permission.CAMERA` (etc.). `pm grant` only works for `dangerous`/runtime permissions declared in the manifest, and grants one at a time. Otherwise you snap a permission dialog. (You can also pre-grant all manifest runtime permissions at install time with `adb -s <id> install -g <apk>`.)
- **Compose vs Views is irrelevant to capture.** Both render into the same surface; `snap.sh` (screencap) treats them identically. Don't reach for Compose-specific tooling just to take a screenshot.
- **Predictive-back / edge-to-edge splash.** On API 31+ (Android 12+) the framework splash (`windowSplashScreenBackground`) shows before `Displayed`; capturing too early grabs it. Gate on the `Displayed` log line, not a fixed sleep.
