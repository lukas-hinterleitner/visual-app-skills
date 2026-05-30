---
name: native-android-test-visually
description: Build, install, and run a native Android app (Kotlin or Java, Jetpack Compose or Views, Gradle) on a connected device or emulator, capture real screenshots via adb, read logcat, and verify the visible UI and runtime behavior match what a recent code change intended. Use whenever the user asks to "test the app", "run it on the emulator", "see the visual changes", "verify a UI fix", "check if my change works/renders", or otherwise wants empirical on-device confirmation that a native Android change rendered correctly — even when they don't say "screenshot" or "logs". Handles the Gradle install task (and build variants/flavors), launching the activity, waiting for the first frame, navigating with adb input, capturing the screen, reading logcat scoped to the app, and reporting a concrete verdict with evidence. Optionally diffs against a Figma reference when one is provided.
license: Apache-2.0
metadata:
  author: Lukas Hinterleitner
  version: "0.1.0"
  platform: android
  framework: native-android
---

# Native Android visual test

Interactive, on-device verification of a native Android app (Kotlin/Java,
Jetpack Compose or classic Views) — the "did my last change actually render
correctly" check. Installs the app via Gradle, launches the activity, captures
real screenshots via `adb`, reads logcat, and gives a concrete verdict.

## When to use

- "Test the app / run it on the emulator / see the visual changes."
- "Did my Compose/layout fix work? Does this screen render correctly now?"
- "Compare this screen to the Figma design." (optional Figma add-on)
- Any request for empirical, on-device confirmation of a visual or runtime
  change — even without the words "screenshot" or "logs".

## How it works

1. **Follow `references/capture-loop.md`** — the universal procedure: preflight,
   launch in the background, wait for the first real frame, screenshot, capture
   logs, analyze the PNG against the change, report a verdict.
2. **For the native-Android specifics** — the Gradle `installDebug` task and how
   to pick a build variant/flavor, launching the activity with `am start` /
   `monkey`, finding the `applicationId`, the "activity displayed" signal, and
   logcat scoped to the app's pid — read `references/native-android.md`.
3. **To navigate the UI** before screenshotting, see `references/driving-the-ui.md`.
4. **When something looks off**, see `references/troubleshooting.md`.
5. **(Optional) compare to a Figma design** → `references/figma-comparison.md`
   (requires the Figma MCP server; skip entirely if you don't use Figma).
6. App built with a cross-platform framework instead? See
   `references/other-frameworks.md` or use the matching skill.

## Bundled scripts

`scripts/check-devices.sh`, `launch.sh`, `snap.sh`, `capture-logs.sh`,
`stop.sh` wrap the common `adb`/Gradle commands with device disambiguation.
`capture-loop.md` shows how they fit together. Note that a native Gradle install
does not launch the app — see the framework reference for the `am start` step.
