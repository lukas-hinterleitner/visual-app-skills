---
name: react-native-test-android-visually
description: Run a React Native or Expo app on a connected Android device or emulator, capture real screenshots via adb, read the Metro + logcat logs, and verify the visible UI and runtime behavior match what a recent code change intended. Use whenever the user asks to "test the app", "run it on Android", "see the visual changes", "verify a UI fix", "check if my change works/renders", or otherwise wants empirical on-device confirmation that a React Native / Expo change rendered correctly — even when they don't say "screenshot" or "logs". Handles starting Metro and the native build, waiting for the bundle + first frame, navigating with adb input, capturing the screen, reading Metro/logcat output (ReactNative / ReactNativeJS, Hermes, red-box errors), and reporting a concrete verdict with evidence. Covers bare React Native and Expo (dev client + run:android). Optionally diffs against a Figma reference when one is provided. Android only (iOS needs a Mac).
license: Apache-2.0
metadata:
  author: Lukas Hinterleitner
  version: "0.1.0"
  platform: android
  framework: react-native
---

# React Native / Expo Android visual test

Interactive, on-device verification of a React Native or Expo Android app — the
"did my last change actually render correctly" check. Starts Metro and the
native build, runs the app on a device or emulator, captures real screenshots
via `adb`, reads the logs, and gives a concrete verdict.

Covers **bare React Native** (`npx react-native run-android`) and **Expo**
(`npx expo run:android` / dev client). Android only — iOS needs a Mac and
`xcrun simctl`, which is out of scope here.

## When to use

- "Test the app / run it on Android / see the visual changes."
- "Did my UI fix work? Does this screen render correctly now?"
- "Compare this screen to the Figma design." (optional Figma add-on)
- Any request for empirical, on-device confirmation of a visual or runtime
  change — even without the words "screenshot" or "logs".

## How it works

1. **Follow `references/capture-loop.md`** — the universal procedure: preflight,
   launch in the background, wait for the first real frame, screenshot, capture
   logs, analyze the PNG against the change, report a verdict.
2. **For the RN/Expo specifics** — the exact run command (bare RN vs Expo), the
   Metro bundler, the "bundle complete + first frame" signal, where RN logs
   (`ReactNative`/`ReactNativeJS`, Hermes, red-box), Fast Refresh, and the dev
   menu — read `references/react-native.md`.
3. **To navigate the UI** before screenshotting, see `references/driving-the-ui.md`.
4. **When something looks off**, see `references/troubleshooting.md`.
5. **(Optional) compare to a Figma design** → `references/figma-comparison.md`
   (requires the Figma MCP server; skip entirely if you don't use Figma).
6. Reached here with a **non-RN** Android app? See
   `references/other-frameworks.md` or use the matching skill.

## Bundled scripts

`scripts/check-devices.sh`, `launch.sh`, `snap.sh`, `capture-logs.sh`,
`stop.sh` wrap the common `adb`/run commands with device disambiguation.
`capture-loop.md` shows how they fit together. Note that Metro runs as part of
the launched command's process group, so `stop.sh` tears it down too.
