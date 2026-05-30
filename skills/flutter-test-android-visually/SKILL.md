---
name: flutter-test-android-visually
description: Run a Flutter app on a connected Android device or emulator, capture real screenshots via adb, read the Dart + logcat logs, and verify the visible UI and runtime behavior match what a recent code change intended. Use whenever the user asks to "test the app", "run it on Android", "see the visual changes", "verify a UI fix", "check if my change works/renders", or otherwise wants empirical on-device confirmation that a Flutter change rendered correctly — even when they don't say "screenshot" or "logs". Handles launching with the right entry point and flags, waiting for the first real frame, navigating with adb input, capturing the screen, reading flutter + logcat output, and reporting a concrete verdict with evidence. Optionally diffs against a Figma reference when one is provided. Android only (iOS needs a Mac).
license: Apache-2.0
metadata:
  author: Lukas Hinterleitner
  version: "0.1.0"
  platform: android
  framework: flutter
---

# Flutter Android visual test

Interactive, on-device verification of a Flutter Android app — the "did my last
change actually render correctly" check you'd otherwise do by squinting at an
emulator. Builds and runs the app on a device or emulator, captures real
screenshots via `adb`, reads the logs, and gives you enough evidence to answer
**did the change render correctly**.

Works for **any** Flutter app, including multi-entry apps where the default
entry point throws by design and a `--target` flag is mandatory. Android only —
iOS needs a Mac and `xcrun simctl`, which is out of scope here.

## When to use

- "Test the app / run it on Android / see the visual changes."
- "Did my UI fix work? Does this screen render correctly now?"
- "Compare the capture screen to this Figma design." (optional Figma add-on)
- Any request for empirical, on-device confirmation of a visual or runtime
  change — even without the words "screenshot" or "logs".

## How it works

1. **Follow `references/capture-loop.md`** — the universal procedure: preflight,
   launch in the background, wait for the first real frame, screenshot, capture
   logs, analyze the PNG against the change, report a verdict.
2. **For the Flutter specifics** — the exact `flutter run` command and flags,
   the first-frame log signal, where Flutter logs, hot reload, and cold-build
   timing — read `references/flutter.md`.
3. **To navigate the UI** before screenshotting, see `references/driving-the-ui.md`.
4. **When something looks off**, see `references/troubleshooting.md`.
5. **(Optional) compare to a Figma design** → `references/figma-comparison.md`
   (requires the Figma MCP server; skip entirely if you don't use Figma).
6. Reached here with a **non-Flutter** Android app? See
   `references/other-frameworks.md` or use the matching skill.

## Bundled scripts

`scripts/check-devices.sh`, `launch.sh`, `snap.sh`, `capture-logs.sh`,
`stop.sh` wrap the common `adb`/run commands with device disambiguation.
`capture-loop.md` shows how they fit together.
