# Contributing

Thanks for your interest. This repo is a small collection of Agent Skills for
visually testing Android apps. Issues and pull requests are welcome.

## Ground rules

1. **Never commit third-party binaries.** No SDKs, no `adb`, no Figma server, no
   vendored CLI. These stay user-installed prerequisites — bundling them would
   add license obligations and bloat. This is the one non-negotiable rule.
2. **Inbound = outbound.** Contributions are accepted under the repo's
   [Apache License 2.0](./LICENSE). By opening a PR you agree your contribution
   is licensed under it.
3. **Keep the WYSIWYG/honesty bar.** Every command in a reference must be one a
   current toolchain actually accepts. If you can't verify it, say so in the PR.

## How the repo is structured (edit the shared core once)

The framework skills share their entire common core via symlinks:

- Shared, single source of truth lives in **`shared/`** (`shared/scripts/*.sh`
  and `shared/references/*.md`).
- Each `skills/<name>/` symlinks those in; only its `SKILL.md`,
  `references/<framework>.md`, and `evals/evals.json` are real, skill-specific
  files.

So: **fix a shared bug once in `shared/`** and every skill gets it. Don't edit a
symlinked file through a skill folder — edit the real file under `shared/`.

## Adding a new framework skill

1. Create `skills/<framework>-test-<...>-visually/` with a real `SKILL.md`
   (frontmatter `name` MUST equal the directory name; lowercase, hyphens, ≤64
   chars), a real `references/<framework>.md`, and `evals/evals.json`.
2. Symlink the shared core in (relative targets, so they stay portable):
   ```bash
   cd skills/<new-skill>
   ln -s ../../shared/scripts scripts
   cd references
   for r in capture-loop driving-the-ui troubleshooting figma-comparison other-frameworks; do
     ln -s "../../../shared/references/$r.md" "$r.md"
   done
   ```
3. Add the skill path to the `skills` array in
   `.claude-plugin/marketplace.json`.
4. Validate (see below).

## Validating before you push

```bash
claude plugin validate . --strict          # marketplace + bundled skills
bash -n shared/scripts/*.sh                 # script syntax
./install.sh <new-skill> /tmp/inst-test     # drop-in deref must yield 0 symlinks
find /tmp/inst-test/<new-skill> -type l     # → should print nothing
```

## Style

- Terse, imperative, expert-to-expert. Explain the non-obvious *why*; don't
  restate the obvious.
- Keep each `SKILL.md` lean (well under ~500 lines / 5k tokens) and push detail
  into `references/`.
- Shell: `set -euo pipefail`, `bash -n`-clean, SPDX header
  (`# SPDX-License-Identifier: Apache-2.0`).
