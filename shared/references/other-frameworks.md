# Generic Android (any framework) — run, launch, and logs

> Read `capture-loop.md` for the universal screenshot/log/iterate loop. This file only covers the framework-specific run command, application-id discovery, and log source for frameworks without a dedicated reference. The thesis: if it produces an APK that installs on a device/emulator, the universal adb capture core works — you supply three things: (1) a build+install+launch command, (2) the `applicationId`, (3) where it logs.

## Running the app

Pick the recipe matching the toolchain, then feed it to `launch.sh -- <command>`. All assume one device attached (`check-devices.sh`); set `ANDROID_SERIAL=<id>` in the env so every nested `adb`/Gradle/CLI call pins to it without per-tool flags.

Kotlin Multiplatform / Compose Multiplatform — the Android module name varies by template (`composeApp` from the JetBrains web wizard, `androidApp` from older KMM, `app` from a plain AS project). Check `settings.gradle.kts` for the real name.

```bash
# build + install debug APK, then launch (Gradle has no "run" task for Android)
./gradlew :composeApp:installDebug   # or :androidApp:installDebug / :app:installDebug
adb shell monkey -p <pkg> -c android.intent.category.LAUNCHER 1
```

Capacitor / Ionic — `cap run` syncs web assets, builds, and deploys in one shot:

```bash
npx cap sync android          # optional if run does it; required after web-asset changes
npx cap run android --target <id>      # --target pins the device; --no-sync to skip sync
```

Cordova:

```bash
cordova run android --device              # or --target=<avd-or-serial>, --emulator
```

NativeScript:

```bash
ns run android --device <id>     # prepare+build+deploy+watch; --no-hmr to disable fast refresh
```

.NET MAUI:

```bash
dotnet build -t:Run -f net9.0-android \
  -p:AdbTarget="-s <id>"      # AdbTarget passes raw flags to adb; -s <id> pins a specific device (use -d for the only USB device, -e for the only emulator)
```

`-t:Run` builds, deploys, and launches. Match `-f` to the TFM in the `.csproj` (`net8.0-android`/`net9.0-android`/`net10.0-android`).

Unity / Unreal / any prebuilt APK — these are export-then-install. Build the APK from the editor (Unity: Build Settings → Build; Unreal: Package Project → Android), then:

```bash
adb install -r -g path/to/app.apk         # -r reinstall, -g auto-grant runtime perms
adb shell monkey -p <pkg> -c android.intent.category.LAUNCHER 1
```

REQUIRED: the install step and a launch trigger. OPTIONAL: `-r`/`-g` flags, `--target` device pinning when only one device is attached.

## Finding the application id (package name)

The `applicationId` is what `am start`, `am force-stop`, `pm grant`, and `pidof` need — it is NOT the source package or the project name, and frameworks frequently rewrite it (Capacitor reads `appId` from `capacitor.config.*`, Unity from Player Settings, MAUI from `ApplicationId` in the `.csproj`). Don't guess it from the repo. Three reliable methods:

```bash
# 1) Diff the installed-package set across the install — framework-agnostic, always works
adb shell pm list packages | sort > /tmp/before.txt
# ...run the install command...
adb shell pm list packages | sort > /tmp/after.txt
comm -13 /tmp/before.txt /tmp/after.txt        # the new line(s) = your package

# 2) Read it straight out of the built APK (no device install needed)
aapt2 dump badging app-debug.apk | grep "package: name="

# 3) Most-recently-installed package (quick, but noisy if other installs happened)
adb shell pm list packages -3 | sed 's/package://'
```

`aapt2` ships in `$ANDROID_HOME/build-tools/<ver>/`; add it to `PATH` or call it by full path. APK locations by framework: Gradle `*/build/outputs/apk/debug/`, Capacitor/Cordova `android/app/build/outputs/apk/debug/`, MAUI `bin/Debug/net9.0-android/`.

## Knowing when the first frame is up

The universal "app actually rendered" signal is in logcat, emitted by the system regardless of framework:

```bash
adb logcat -d | grep "ActivityManager: Displayed <pkg>/"
```

`Displayed <pkg>/.MainActivity: +1s234ms` means the first frame painted. Watch for it instead of sleeping a fixed interval. Use `snap.sh` only after that line appears.

Timing reality: the `installDebug`/`cap run`/`dotnet build` step does a full toolchain build on first run. COLD builds are slow — Gradle/KMP 2–8 min on first invocation (daemon warmup, dependency resolution), Unreal cooking can be 10 min+, MAUI restore + AOT a few minutes. Warm incremental builds drop to 10–40s. The single most common mistake is screenshotting during this window and capturing the launcher, a splash logo, or a white pre-render frame — then "verifying" against nothing. Always gate on the `Displayed` line, and for web-shell frameworks (Capacitor/Cordova) wait an extra beat: `Displayed` fires when the WebView is up, but the JS bundle/first DOM paint lands a few hundred ms later.

## Reading logs

There is no framework-specific log daemon to attach to — everything funnels through logcat. The cleanest stream is filtered to the app's pid (avoids the firehose of system noise):

```bash
adb logcat --pid=$(adb shell pidof -s <pkg>)
```

`pidof -s` returns a single pid; if the app runs multiple processes (`:remote` services), drop `-s` and pass each. `capture-logs.sh` does a `logcat` dump — narrow it the same way by piping through the pid filter, or grep your framework's tag:

| Framework | Useful tag(s) |
|-----------|---------------|
| KMP / Compose | app's own `Log.*` tags; Compose has no special tag |
| Capacitor / Cordova | `Capacitor`, `Console` (JS `console.log` is bridged here), `chromium` (WebView) |
| NativeScript | `JS` (all JS logs), `NativeScript` |
| MAUI | `DOTNET`, `mono-rt`, `monodroid` |
| Unity | `Unity` |
| Unreal | `UE4`/`UE5`, `Unreal` |

Benign noise to ignore: `Accessing hidden API`, `OpenGLRenderer`/`eglDestroy`, `Choreographer: Skipped N frames`, `StrictMode`, `Gralloc`/`hwui` chatter, `E/...` lines from `cutils`/`audio`. JS web-shell frameworks dump `chromium: [INFO:CONSOLE]` for every `console.log` — that's expected, not an error.

## Stopping & iterating

Hot reload / fast refresh, by framework:

- KMP / Compose / Unity / Unreal / MAUI prebuilt APK: no JS-style live reload over adb — re-run the install command. (MAUI has XAML Hot Reload, but only inside a VS/`dotnet` debug session, not this flow.)
- Capacitor: no native hot reload; for web-asset iteration use `ionic cap run android -l --external` (live-reload server) or just re-`npx cap sync && npx cap run`.
- Cordova: re-run `cordova run android`.
- NativeScript: `ns run android` watches the source tree and HMR-patches automatically — leave it running; press `Ctrl+C` to stop, `R` in the terminal to restart the app, `A` to rebuild Android.

Stop the watcher/build process via `stop.sh` (kills the recorded PGID). Force-stop the app on the device independently of the build process:

```bash
adb shell am force-stop <pkg>
```

To wipe state between runs (clears caches, granted perms, WebView storage): `adb shell pm clear <pkg>`.

## Pitfalls specific to generic frameworks

- `applicationId != namespace`. Suffix flavors (`com.foo.app.debug`, `.dev`) silently break `pidof`/`am`. Always re-derive the package from the pm-diff after install, not from config files.
- WebView shells (Capacitor/Cordova) render inside a single `MainActivity`; the `Displayed` line fires before your JS app paints. A screenshot taken on `Displayed` may show a blank WebView. Wait for the first `chromium: [INFO:CONSOLE]` from your bundle, or add a fixed extra delay.
- `cap run`/`cordova run` prompt interactively to pick a target when several are attached, which hangs under `launch.sh`. Pass `--target <id>` (Capacitor) / `--target=<id>` (Cordova) or attach exactly one device.
- KMP `installDebug` installs but does NOT launch — unlike `flutter run`/`react-native run-android`. You must `monkey ... LAUNCHER 1` or `am start` afterward, or you'll screenshot the home screen.
- Unity/Unreal builds are not produced by an adb-driven command; the export happens in the editor. The capture loop only owns `adb install` + launch + screenshot — don't try to drive the engine build from here.
- MAUI `-f` TFM mismatch (`net8` vs `net9` vs `net10`) fails the build with a confusing restore error rather than a clear "wrong framework" message. Read the actual TFM out of the `.csproj`.
- `aapt` (v1) is removed from current build-tools; use `aapt2 dump badging`. If `aapt2` isn't on `PATH`, invoke `$ANDROID_HOME/build-tools/<latest>/aapt2`.
- Multi-process apps (common in Unity/Unreal with `:GameActivity` or services) defeat `pidof -s`; the crash you want may be in a child process pid you filtered out.
