# Design — visual-app-skills

Status: initial build (v0.1.0). This document records the decisions behind the
repo so they're reviewable and don't have to be reverse-engineered later.

## Purpose

Give a coding agent the ability to **visually verify that a code change rendered
correctly** on a real Android device or emulator: launch the app → wait for the
first frame → screenshot via `adb` → read the logs → compare against the change
→ report an evidence-backed verdict. Optionally diff against a Figma design.

This generalizes a skill that originally lived inside one Flutter app
(`flutter-test-android-visually`) and was hardcoded to that app's run command.

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| License | **Apache-2.0** (whole repo) | True open source for maximum adoption; the author keeps copyright and required attribution; patent grant included. Copyright is retained under any license — the real axis was commercial use, and the goal is wide use. |
| Repo name | **`visual-app-skills`** | Stacks the highest-traffic search tokens (visual + app + skills); framework-neutral so it can grow beyond Android/Flutter. |
| Scope | **Android, framework-agnostic** — Flutter, React Native/Expo, native Android, generic fallback for any APK | Matches "any Flutter, native Android, React Native, etc." iOS deferred (needs a Mac + `xcrun simctl`); repo laid out to accept an iOS skill later. |
| Structure | **Per-framework skills, shared core via symlinks** | Each skill is separately triggered and separately discoverable on skill directories; the common adb core lives once and is symlinked in, so nothing is duplicated. |
| Packaging | **One repo, both install paths** — drop-in *and* Claude plugin/marketplace | The `anthropics/skills` pattern (`source: "./"` + `strict:false` + explicit `skills:[…]`) serves both with zero duplication. |
| Figma | **Optional add-on**, gated on the Figma MCP server | Figma is one team's workflow, not core; the skills are fully useful with no Figma setup. |

## Architecture

The capture loop is identical across frameworks — only the **run command** and
**log source** differ. So:

- `shared/` holds the single source of truth: the five `adb`/run scripts and the
  five universal references (`capture-loop`, `driving-the-ui`, `troubleshooting`,
  `figma-comparison`, `other-frameworks`).
- Each `skills/<framework>-…/` contains only what's unique — a thin `SKILL.md`
  (framework-specific trigger + intent), `references/<framework>.md` (run/log
  specifics), and `evals/` — and **symlinks** the shared scripts and references
  in (relative targets, so they're portable in git).

### The symlink trade-off (and mitigation)

- Plugin install and full `git clone` resolve the symlinks natively (whole repo
  present → targets exist).
- Single-folder drop-in must dereference. `install.sh` does this (`cp -RL`);
  manual copy must use `cp -RL`; Windows needs `core.symlinks`.
- `SKILL.md` and each framework reference are **always real files** (never
  symlinked), so triggering, directory-crawling, and portability of the primary
  artifact are unaffected.

Considered and rejected: (a) one mega-skill that detects the framework — loses
per-framework triggering/discoverability the user wanted; (b) generating
self-contained folders via a build step — more machinery and on-disk
duplication than symlinks, with a CI drift check to maintain.

## Repository layout

```
visual-app-skills/
├── .claude-plugin/marketplace.json
├── shared/{scripts,references}/…
├── skills/
│   ├── flutter-test-android-visually/
│   ├── react-native-test-android-visually/
│   └── native-android-test-visually/
├── docs/DESIGN.md
├── README.md  CONTRIBUTING.md  LICENSE  NOTICE  install.sh  .gitignore
```

## Verification performed

- All scripts: `bash -n` clean; error paths (no device, no command, missing
  args) behave correctly; `launch.sh` → `stop.sh` process-group lifecycle works.
- All 18 skill symlinks resolve (no dangling); scripts run and references read
  through the symlinked paths.
- `install.sh` deref-installs a skill as 14 real files, 0 symlinks.
- `claude plugin validate . --strict` → passes.
- Framework run/log commands drafted from current docs and adversarially
  fact-checked (caught deprecated `--deviceId`, wrong Expo `--device generic`,
  the `pm list packages` ordering myth, etc.).

## Known limitations / future work

- **iOS** is out of scope (needs macOS). The collection name and layout leave
  room for an iOS sibling skill.
- **Live end-to-end capture** of a real app was not run during the build (no
  device was connected at build time); the scripts were verified at the logic
  level. A live smoke test against a Flutter app is the recommended final check
  once an emulator is booted.
- The third-party run commands are version-sensitive; treat the per-framework
  references as living docs and re-verify on major toolchain releases.
