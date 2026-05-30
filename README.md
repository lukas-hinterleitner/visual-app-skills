# visual-app-skills

> Agent skills that give a coding agent **eyes on your running app**. Run a
> Flutter, React Native, or native Android app on an emulator or device, capture
> real screenshots via `adb`, read the logs, and verify that a code change
> rendered correctly. Works with Claude Code and other agents that support the
> [Agent Skills](https://agentskills.io) format.

[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](./LICENSE)
[![Agent Skills](https://img.shields.io/badge/format-Agent_Skills-6E56CF.svg)](https://agentskills.io)

This is the open, generalized version of a skill that started life inside a
single Flutter app. It answers the question you'd otherwise answer by squinting
at an emulator: **did my last change actually render correctly?** — on a real
device, with screenshot and log evidence, not guesswork.

Each skill drives the same loop: launch the app → wait for the first real frame
→ screenshot via `adb` → read the logs → compare against what the change
intended → report a concrete verdict. Optionally, diff the screen against a
Figma design.

> **Scope:** Android only — these skills drive `adb` against a device or
> emulator. iOS verification needs a Mac and `xcrun simctl`, which is out of
> scope (the repo is laid out to accept an iOS skill later).

## The skills

| Skill | For | Fires on prompts like |
|-------|-----|-----------------------|
| [`flutter-test-android-visually`](skills/flutter-test-android-visually) | Flutter apps (incl. multi-entry / `--target`) | "test my Flutter app on Android", "see the visual changes" |
| [`react-native-test-android-visually`](skills/react-native-test-android-visually) | React Native **and** Expo | "run my RN/Expo app and check this screen" |
| [`native-android-test-visually`](skills/native-android-test-visually) | Native Android — Kotlin/Java, Jetpack Compose or Views, Gradle | "build and run my Android app", "verify the Compose screen" |

Anything else that produces an Android APK — Kotlin/Compose Multiplatform,
Capacitor/Ionic, Cordova, NativeScript, .NET MAUI, Unity — is covered by the
generic recipe in [`other-frameworks.md`](shared/references/other-frameworks.md):
if it installs and runs on a device, the `adb` capture core works; you just
supply the run command, the application id, and where it logs.

## Requirements

- **Android SDK Platform-Tools** (`adb`) on `PATH`, and a connected device or a
  running emulator.
- The **toolchain for your app**: the Flutter SDK, or Node + your package
  manager (React Native/Expo), or the Gradle wrapper (native Android).
- A coding agent that supports the **Agent Skills** format (e.g. Claude Code).
- *(Optional)* a **Figma MCP server**, only if you want the Figma-diff step.

None of these are bundled — they're prerequisites you already have for building
your app.

## Install

### Option A — Claude Code plugin (recommended)

```text
/plugin marketplace add lukas-hinterleitner/visual-app-skills
/plugin install visual-app-skills@visual-app-skills
```

This clones the whole repo, so the shared core resolves automatically. The
three skills become available as `visual-app-skills:<skill-name>`.

### Option B — drop-in via the installer (any agent)

```bash
git clone https://github.com/lukas-hinterleitner/visual-app-skills.git
cd visual-app-skills
./install.sh flutter-test-android-visually   # or: ./install.sh all
# custom destination (e.g. project scope):
./install.sh flutter-test-android-visually .claude/skills
```

`install.sh` **dereferences** the shared symlinks, so each installed skill
folder is fully self-contained and works with no dependency on this repo.

### Option C — manual copy

```bash
cp -RL visual-app-skills/skills/flutter-test-android-visually ~/.claude/skills/
```

> ⚠️ Use `cp -R**L**` (capital L — dereference symlinks). A plain `cp -r` would
> copy the shared files as dangling symlinks, because the skills share their
> common core via symlinks (see below). Options A and B handle this for you.

## How it works

The bulk of each skill is identical — the `adb` capture loop, UI driving, and
troubleshooting are framework-agnostic. Only the **run command** and **where the
app logs** differ per framework. So each skill's `SKILL.md` is a thin,
framework-specific shell that points to:

- `references/capture-loop.md` — the universal procedure (shared)
- `references/<framework>.md` — the run/launch/log specifics (unique per skill)
- `references/driving-the-ui.md`, `troubleshooting.md`, `figma-comparison.md`,
  `other-frameworks.md` — shared
- `scripts/` — `check-devices.sh`, `launch.sh`, `snap.sh`, `capture-logs.sh`,
  `stop.sh` (shared, framework-agnostic)

The agent only loads a reference when it needs it (progressive disclosure), so
each invocation stays lightweight.

## Repository layout & the no-duplication design

```text
visual-app-skills/
├── .claude-plugin/marketplace.json     # makes the repo an installable plugin
├── shared/                             # the single source of truth
│   ├── scripts/*.sh
│   └── references/{capture-loop,driving-the-ui,troubleshooting,figma-comparison,other-frameworks}.md
└── skills/
    └── <framework>-test-android-visually/
        ├── SKILL.md                    # real, framework-specific
        ├── references/<framework>.md   # real, framework-specific
        ├── references/<shared>.md      # symlink → ../../../shared/references/…
        ├── scripts/                    # symlink → ../../shared/scripts
        └── evals/evals.json
```

The shared core lives in `shared/` **once** and is symlinked into each skill, so
there is zero duplication to keep in sync. The trade-offs:

- **Plugin install (Option A)** and a full `git clone` resolve the symlinks
  natively — the whole repo is present, so the targets exist.
- **Drop-in (Options B/C)** must dereference the symlinks. `install.sh` does
  this; for a manual copy use `cp -RL`.
- **Windows:** enable symlinks in git (`git config --global core.symlinks true`,
  plus Developer Mode) before cloning, or just use `install.sh`, which writes
  real files.

## Optional: Figma comparison

If your team designs in Figma and you have the **Figma MCP server** configured,
paste a `figma.com/design/...` link and the skill will fetch the design and
compare it to the live screen (layout, color, typography, spacing — by relative
proportion, not pixels). Without Figma, everything else works unchanged — see
[`figma-comparison.md`](shared/references/figma-comparison.md).

## Trademarks & affiliation

"Android", "Flutter", and "Jetpack Compose" are trademarks of Google LLC;
"React Native" of Meta; "Expo" of Expo (650 Industries); "Figma" of Figma, Inc.;
"Claude" / "Claude Code" of Anthropic. This is an independent community project,
**not affiliated with or endorsed by** any of them; the names are used only to
describe interoperability. See [`NOTICE`](./NOTICE).

## License

[Apache License 2.0](./LICENSE) © 2026 Lukas Hinterleitner. You may use, modify,
and redistribute these skills — including commercially — provided you keep the
copyright/license notices and state your changes. See [`NOTICE`](./NOTICE) for
attribution and the third-party-tool disclosures.

## Contributing

Issues and PRs welcome — see [`CONTRIBUTING.md`](./CONTRIBUTING.md). The one hard
rule: **never commit third-party binaries** (an SDK, `adb`, a Figma server).
They stay user-installed prerequisites.
