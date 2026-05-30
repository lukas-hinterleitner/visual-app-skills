# React Native + Expo on Android — run, launch, and logs

> Read `capture-loop.md` for the universal screenshot/log loop. This file only covers the RN/Expo-specific run command, app-id discovery, and log source — feed the command below to `launch.sh`, and point `capture-logs.sh` at the logcat tags noted under Reading logs.

## Running the app

Pick the path that matches the project. Check `package.json` deps: presence of `expo` → Expo path; otherwise bare RN.

**Bare React Native** (RN 0.73–0.77+, New Architecture is the default since 0.76):
```bash
# builds the debug APK, installs it, starts Metro on :8081, launches the app
npx react-native run-android
```
Common variants (flags are owned by `@react-native-community/cli-platform-android`, bundled as a dev dep — there is no global `react-native-cli` anymore):
```bash
npx react-native run-android --mode release          # release build (needs signing config)
npx react-native run-android --active-arch-only      # debug only: build one ABI → much faster cold build
npx react-native run-android --appIdSuffix debug     # disambiguate flavored installs
npx react-native run-android --device <id>           # target a specific adb serial (--deviceId is deprecated)
npx react-native run-android --no-packager           # build/install only; Metro already running elsewhere
```
REQUIRED: nothing beyond `run-android`. `--active-arch-only` is the single highest-value optional flag for iteration speed — never ship it to production.

**Expo** (use the LOCAL CLI via `npx expo`; the global `expo-cli` is deprecated and rejects most commands):
```bash
# managed/dev-client: prebuild native dirs (if absent) + native build + install + start bundler
npx expo run:android
npx expo run:android --variant release   # release variant
npx expo run:android --device <id>       # target a serial; --device with no value prompts a device picker
npx expo run:android --no-build-cache    # clear the native build cache before building
npx expo run:android --no-bundler        # build/install only; don't start Metro (Android equivalent of --no-packager)
```
Note: the `--device generic` build-only-no-launch trick is **iOS-Simulator-only** — it does not exist on Android. To produce just the binary on Android use `--output <dir>`; to skip the bundler use `--no-bundler`.

If the project ships a dev client (`expo-dev-client` in deps) you can skip the rebuild on JS-only changes and just run the bundler:
```bash
npx expo start --dev-client        # serves JS to an already-installed dev build
npx expo start --go                # force Expo Go (only works for pure-JS managed apps)
```
EAS Build (`eas build -p android --profile development`) is cloud compilation — out of scope for a local capture loop; only relevant if you can't build natively on this host.

## Finding the application id (package name)

Needed for `am start`, `am force-stop`, `pm grant`. Try in order:

```bash
# Bare RN — authoritative source:
grep -m1 applicationId android/app/build.gradle

# Expo (managed, before/after prebuild):
grep -A4 '"android"' app.json | grep '"package"'
# or for app.config.js / .ts, dump the resolved config:
npx expo config --type public --json | grep -i package
```
Fallback — ask the device what just installed (works regardless of source layout):
```bash
adb -s <id> shell pm list packages -3        # third-party packages only
adb -s <id> shell dumpsys window | grep -i mCurrentFocus   # foreground app while it's running
```
Expo prebuild copies `android.package` into `applicationId`, so the two agree post-prebuild. Note `--appIdSuffix`/release flavors append a suffix — the installed id may be `com.foo.debug`, not `com.foo`.

## Knowing when the first frame is up

Three signals must ALL land before you screenshot:
1. Gradle prints `BUILD SUCCESSFUL in …` (the native build finished).
2. Metro prints the bundle line: `info Done in …` / a `Bundling index.js … 100%` progress bar reaching 100%.
3. No red-box: the JS actually mounted. The first JS bundle is built **on demand** the first time the app requests it — so the app launches, shows a blank/splash screen, THEN Metro bundles, THEN the UI paints.

Timing: a COLD native build (fresh clone, empty Gradle cache, New Arch codegen) is routinely **5–15 min** on first run; warm incremental rebuilds are 20–90 s; a JS-only change with Metro already up is a sub-second reload. The classic mistake is screenshotting after `BUILD SUCCESSFUL` while Metro is still bundling — you capture the splash or a white screen. Wait for the Metro bundle to hit 100% AND poll the screen until it changes from splash.

## Reading logs

Two independent streams — capture both:

- **Metro** (the bundler process started by `run:android`/`run-android`): bundling progress, transform errors, and the red-box stack. This is the launch.sh log target — point `--log` at the run command's stdout.
- **Native + JS via logcat**. Metro JS log *forwarding* was deprecated in RN 0.76 and **removed in 0.77** (in favor of the Chrome DevTools Protocol / React Native DevTools), so it no longer streams JS `console.log` to the Metro terminal. `npx react-native log-android` still exists (it spawns logkitty for prettified Android logs) but is a thin, unreliable wrapper on New Arch — go straight to logcat:
```bash
adb -s <id> logcat *:S ReactNative:V ReactNativeJS:V
```
`ReactNativeJS` carries `console.log` output (Hermes routes JS logs here). Add `AndroidRuntime:E` to catch native crashes:
```bash
adb -s <id> logcat *:S ReactNative:V ReactNativeJS:V AndroidRuntime:E
```
`capture-logs.sh` already dumps logcat — pass it those tag filters so the dump isn't swamped.

Benign noise to ignore: `ReactNativeJS: Running "AppName" with appParams`, Hermes `Loading … bytecode`, `Choreographer: Skipped N frames` during the first paint, `OpenGLRenderer` / `eglCreateContext` chatter, and `Metro waiting on …` reconnect lines.

## Stopping & iterating

- **Fast Refresh** is on by default — saving a JS/TS file re-bundles and patches the running app, no rebuild. Native (Kotlin/Java/Gradle) or `app.json` changes require a full `run-android` / `run:android`.
- **Manual reload**: `adb -s <id> shell input keyevent 82` opens the dev menu; from there you can tap Reload. Simpler is to press `r` in the Metro terminal.
- **Stop the run**: use `stop.sh` to kill the recorded process group (this takes down Metro + the Gradle/launch chain together — they're in one PGID under launch.sh).
- **Force-stop the app on device** (without killing Metro):
```bash
adb -s <id> shell am force-stop <applicationId>
adb -s <id> shell am start -n <applicationId>/.MainActivity   # relaunch
```

## Pitfalls specific to React Native / Expo

- **Metro is a separate long-lived process from the build.** `run-android` spawns Metro in a new terminal/daemon; if you kill only the Gradle build, Metro lingers on :8081, and the next run reuses it. If port 8081 is occupied by a stale Metro from a different project, the app loads the wrong bundle — kill it: `lsof -ti:8081 | xargs kill`.
- **No Metro = no JS.** A debug build with Metro down shows "Unable to load script / Could not connect to development server." Metro must be running and reachable. On a physical device set up the reverse tunnel: `adb -s <id> reverse tcp:8081 tcp:8081` (emulators get this for free).
- **`a`/`i` Metro shortcuts are gone** (removed in RN 0.77) — you can't press `a` in the Metro terminal to launch Android anymore; invoke `run-android` directly.
- **Release vs debug bundle.** `--mode release` / `--variant release` bundles the JS into the APK and does NOT need Metro — but it needs a signing config and won't Fast-Refresh. For an iteration loop you almost always want debug.
- **Cold-build patience.** New Architecture codegen + first Gradle run is slow; don't interpret a long-running build as a hang. Watch the Gradle task lines advance before assuming it's stuck.
- **Expo managed apps regenerate `android/`.** `npx expo prebuild --clean` (and sometimes `run:android`) overwrites the native project from config plugins — never hand-edit `android/` in a managed Expo app; the edits vanish on the next prebuild.
- **Expo Go vs dev client mismatch.** `expo start --go` only loads pure-JS apps; if the project has custom native modules it must run a dev build (`run:android` once, then `start --dev-client`). Launching Expo Go against a native-module app silently loads a stale or broken bundle.
