# Comparing the screenshot to a Figma reference (optional)

> **Prerequisite — skip this whole file if it doesn't apply.** This is an
> optional add-on for teams who design in Figma. It requires the **Figma MCP
> server** to be configured in the agent (it exposes a `get_screenshot`-style
> tool). The core skill is fully useful with **no Figma and no setup** — only
> reach for this when the user pastes a `figma.com/design/...` link or asks you
> to compare the UI to a design.

When the user references a Figma design, fetch it and compare side by side with
the device screenshot you captured.

1. Extract `fileKey` and `nodeId` from the URL:
   `figma.com/design/:fileKey/:fileName?node-id=:nodeId` — and replace the `-`
   in the node id with `:` (so `1-2` becomes `1:2`).
2. Call the Figma MCP screenshot tool with those (e.g.
   `mcp__...figma...__get_screenshot`). The exact tool name depends on which
   Figma MCP server is installed.
3. Save the returned image and `Read` both PNGs.

Compare in prose, not pixels:

- **Layout & alignment** — same elements in roughly the same positions?
- **Color** — primary, secondary, accent, text close enough?
- **Typography** — similar size/weight hierarchy?
- **Spacing** — comparable rhythm of paddings and gaps?
- **Content** — same labels, icons, ordering?

A **density mismatch is expected**: Figma exports at 1× or 2×, while an Android
emulator renders at 2.75× DPI or higher, so absolute pixel counts differ. Judge
*relative proportions*, not raw dimensions, and don't flag sub-pixel rendering
or font-hinting drift as bugs.

If no Figma MCP tool is available, say so plainly and fall back to verifying the
change against the user's stated intent and the code diff — don't block on it.
