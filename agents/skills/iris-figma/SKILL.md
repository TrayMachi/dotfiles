---
name: iris-figma
description: |
  Use the `figma` binary to interact with the Figma REST API:
  (1) download a node as a PNG file, (2) fetch file comments as text or JSON, or
  (3) build a node map — list descendant node IDs, layer names, and (optionally)
  the rendered text content of TEXT nodes at a bounded depth without pulling the
  full document. Trigger on any figma.com URL paired with intent to save to disk,
  read comments, map the node/layer structure, or extract layer names + their
  rendered copy (e.g. "create a figma node map for the first 2 layers", "list
  every text layer's name and content under this frame").
args: |
  <figma-url-or-file-key> - A Figma design URL, or a raw file key
  [--out=dir]             - Output directory for screenshots (default: cwd)
  [--name=prefix]         - Filename prefix for screenshots
  [--depth=N]             - Descendant levels for `nodes` (default: 2)
  [--with-text]           - Append rendered text on TEXT nodes (`nodes` only)
  [--json]                - Emit machine-readable JSON envelope on stdout
---

# figma

Use the `figma` binary for three tasks:

1. **`screenshot`** — download a Figma node as a PNG file on disk.
2. **`comments`** — list the comments on a Figma file, optionally as JSON.
3. **`nodes`** — list descendant node IDs and names at a bounded depth (first layer, first + second layer, etc.) without loading the full document.

All commands accept the same URL format and read the same Figma credential. Use the global `--json` flag when you want a machine-parseable envelope on stdout; without it, human-readable text goes to stdout and progress info goes to stderr.

## CLI vs. Figma MCP — pick the right tool

If the user has the Figma MCP server installed as well, the CLI and MCP solve different problems — mixing them up wastes time and tokens.

| Task                                                    | Use                                     |
| ------------------------------------------------------- | --------------------------------------- |
| Save a PNG to disk for later use, handoff, or embedding | **CLI** `figma screenshot`          |
| View a design in the conversation to reason about it    | **MCP** `get_screenshot`                |
| Generate code from a design                             | **MCP** `get_design_context`            |
| Read variable defs, metadata, Code Connect mappings     | **MCP** (`get_variable_defs`, etc.)     |
| List comments on a file                                 | **CLI** `figma comments` (MCP has none) |
| Enumerate child node IDs/names at a bounded depth       | **CLI** `figma nodes` (MCP floods)  |
| Extract layer names + rendered copy (e.g. i18n keys)    | **CLI** `figma nodes -with-text` (MCP `get_metadata` collapses instances; `get_design_context` returns JSX, not text) |
| Create/edit designs, diagrams, Code Connect             | **MCP** write tools                     |

Rule of thumb: **the CLI writes bytes to the filesystem; the MCP pulls design data into the conversation.** If the user wants a file they can open, attach, or reference later, use the CLI. If they want you to look at the design and act on it, use the MCP.

## Prerequisites

- `figma` binary on `PATH` (install via `iris install figma`)
- A Figma Personal Access Token resolved via one of:
  - `--figma-token` flag
  - `FIGMA_TOKEN` env var
  - `~/.config/iris/secrets.toml` with a `[figma]` table (`token = "figd_..."`) — fastest setup is `iris secrets set figma` and pasting the token at the prompt

## URL format

The CLI accepts standard Figma design URLs:

```
https://www.figma.com/design/{fileKey}/{fileName}?node-id={nodeId}
```

- `fileKey` is extracted from the path
- `nodeId` is taken from `node-id` (dashes are converted to colons for the API)
- `comments` only needs the `fileKey` — `node-id` is optional and ignored
- `comments` also accepts a bare file key (e.g., `6SbVVyzfyXOIEHS7N47R9S`)
- `nodes` requires both `fileKey` and `node-id` (it scopes to a specific subtree)

## screenshot

Download a Figma node as a PNG file.

```
figma screenshot [flags] <figma-url>

flags:
  -out string    output directory (default ".")
  -name string   filename without extension (defaults to node ID, e.g. "2814_64554")
  -scale int     export scale, 1..4 (default 2)
```

### When to use

- User asks to save/download/export a Figma screen as a file
- User wants to attach a design PNG to a doc, ticket, or message
- You're assembling a local screen inventory on disk

For just _seeing_ the design inline in the conversation, use the Figma MCP `get_screenshot` instead — it's faster and doesn't clutter the filesystem.

### Examples

```bash
# Single screenshot — saves ./2814_64554.png
figma screenshot "https://www.figma.com/design/bXxOIuqvsb6bxhBri7zXxR/File?node-id=2814-64554"

# Custom output directory and filename
figma screenshot -out ~/screenshots -name roles_table \
  "https://www.figma.com/design/bXxOIuqvsb6bxhBri7zXxR/File?node-id=2814-64554"
```

### Multiple screenshots

When the user gives you several URLs, run them as **parallel Bash tool calls** in a single turn — they're independent, and parallelizing cuts wall time significantly:

```bash
figma screenshot -out ./screens -name login     "https://www.figma.com/design/abc/F?node-id=1-1"
figma screenshot -out ./screens -name dashboard "https://www.figma.com/design/abc/F?node-id=2-1"
figma screenshot -out ./screens -name settings  "https://www.figma.com/design/abc/F?node-id=3-1"
```

### Naming rules

- `--name` provided + one URL → use it verbatim
- `--name` provided + multiple URLs → use it as a prefix with a numeric suffix (`prefix_1.png`, `prefix_2.png`)
- `--name` omitted → CLI uses the node ID (e.g., `2814_64554.png`)

## comments

List comments on a Figma file via `GET /v1/files/:file_key/comments`.

```
figma comments [flags] <figma-url-or-file-key>

flags:
  -md              request comment messages as Markdown
  -unresolved      only include unresolved threads
  -since string    only include threads with root created at or after this date (YYYY-MM-DD or RFC3339)
  -until string    only include threads with root created at or before this date (YYYY-MM-DD or RFC3339)
```

`-unresolved`, `-since`, and `-until` filter at the thread level: when a root comment matches, its replies come along (even if a reply falls outside the date range). `-until` with `YYYY-MM-DD` is inclusive through end-of-day UTC. Filters work in both default (text) and `--json` output modes.

### When to use

- User wants to read what designers/reviewers said on a file
- User asks to summarize, triage, or act on design feedback
- User wants to pipe comments through `jq` or save them for processing

The Figma MCP does **not** expose comments, so the CLI is the only path.

### Default text output

Default output prints threaded text — root comments with indented replies — and is the right choice when the agent itself needs to read the comments:

```bash
figma comments "https://www.figma.com/design/6SbVVyzfyXOIEHS7N47R9S/File?node-id=3841-63757"
```

Sample output:

```
file: 6SbVVyzfyXOIEHS7N47R9S  (206 comments)
- @Francis Goh  2026-04-13T07:23:30Z
  minor: are there icon names labelled on the design...
  - @Tung An  2026-04-13T07:36:37Z
    haha okay okay
- @Clarissa Chua  2026-04-10T07:27:04Z [resolved]
  the current notif has "View Chat"...
```

Resolved threads show `[resolved]` next to the timestamp.

### JSON output

Use the global `--json` flag when the user wants structured data — for filtering, piping to `jq`, or writing to a file. Output is wrapped in the iris envelope: `{"ok":true,"data":{"comments":[...]}}`.

```bash
# Count comments
figma --json comments <file-key> | jq '.data.comments | length'

# Unresolved threads from the last week (filter applied by CLI)
figma --json comments -unresolved -since 2026-04-13 <file-key>

# Group by author
figma --json comments <file-key> \
  | jq '[.data.comments[] | .user.handle] | group_by(.) | map({author: .[0], count: length})'
```

### Markdown mode

Pass `-md` when the user plans to render the messages (e.g., posting to Lark or a doc). It asks the API to return messages as Markdown instead of plain text with mention objects.

## nodes

List descendant node IDs and layer names under a target node via `GET /v1/files/:key/nodes?ids=...&depth=N`. The depth cap is what makes this useful — Figma's MCP `get_metadata` has no depth parameter and returns the entire subtree, which regularly exceeds the tool-result size limit on large files.

```
figma nodes [flags] <figma-url>

flags:
  -depth int     descendant levels below the target
                 (1=children, 2=+grandchildren, 3=+great-grandchildren, 0=full subtree)
                 (default 2)
  -with-text     append the rendered text content of TEXT nodes
                 (Go-quoted, escapes embedded newlines and quotes)
```

### When to use

- User asks "what are the top-level sections/frames" in a canvas
- User asks for node IDs to feed into `figma screenshot`, the Figma MCP, or another tool
- User wants to map the structure of a design without generating code
- User wants to extract i18n keys, message IDs, or any layer-name → rendered-copy mapping — pair `-with-text` with a deep `-depth` (often `-depth 0`) and parse the `[TEXT]` lines
- The Figma MCP `get_metadata` call fails with a "result exceeds maximum allowed tokens" error — switch to `figma nodes -depth N` with a small N and expand only the branches you need

Depth counts descendant levels below the target. `-depth 1` gives just the direct children (first layer). `-depth 2` (the default) gives first + second layer. Prefer the smallest depth that answers the question; re-run against a specific child node when you need to drill deeper.

### Text output

Produces an indented tree annotated with Figma node types (`SECTION`, `FRAME`, `INSTANCE`, `TEXT`, …):

```bash
figma nodes -depth 1 "https://www.figma.com/design/6SbVVyzfyXOIEHS7N47R9S/File?node-id=3693-13899"
```

```
file: 6SbVVyzfyXOIEHS7N47R9S  node: 3693:13899  (depth=1)
- [CANVAS] 3693:13899  1004 In Review
  - [SECTION] 3693:13900  Job Posted - AS IS
  - [SECTION] 3693:16883  Job Posted - TO BE
  - [SECTION] 3696:30024  Dashboard - AS IS
  ...
```

### Surfacing text content

Add `-with-text` to append the rendered string on every `[TEXT]` line, separated from the layer name by two spaces and Go-quoted (so embedded newlines and quotes don't break the line format). Other node types are unaffected.

```bash
figma nodes -with-text -depth 0 \
  "https://www.figma.com/design/6SbVVyzfyXOIEHS7N47R9S/File?node-id=4295-11220"
```

```
file: 6SbVVyzfyXOIEHS7N47R9S  node: 4295:11220  (depth=full)
- [INSTANCE] 4295:11220  Outline/ Outline basic button
  - [FRAME] I4295:11220;4835:52362  Auto layout button
    - [TEXT] I4295:11220;4835:52364  interactive-boost-job-now  "Boost Job Now"
```

This is the right output shape for translation-key extraction — the layer `name` is the i18n key (`interactive-boost-job-now`), the quoted value is the default message ("Boost Job Now"), and instances are traversed inline so master-defined keys are not lost.

### JSON output

Use `--json` for scripting — e.g., to feed node IDs into parallel `figma screenshot` calls:

```bash
# All first-layer child IDs
figma --json nodes -depth 1 "<url>" | jq -r '.data.nodes[].document.children[].id'

# First-layer IDs filtered to sections only
figma --json nodes -depth 1 "<url>" \
  | jq -r '.data.nodes[].document.children[] | select(.type=="SECTION") | .id'
```

### Drilling down iteratively

For a large file, rather than requesting `-depth 5` on the root (expensive, noisy), start shallow and recurse into the branches of interest:

1. `figma nodes -depth 1 <root-url>` → pick the relevant section ID
2. Rebuild the URL with that section's `node-id` and run again at `-depth 2`
3. Repeat until you've located the specific frame

This pattern keeps each response small and lets you skip subtrees the user doesn't care about.

## Exit codes

The CLI follows the iris convention:

| Code | Meaning         |
| ---- | --------------- |
| `0`  | success         |
| `1`  | usage error     |
| `2`  | runtime error   |
| `3`  | auth error      |

In `--json` mode, errors are also emitted on stdout as `{"ok":false,"error":"..."}`, so agents can branch on either the exit code or the envelope.

## Error handling

| Error                                                                    | Cause                             | Resolution                                                      |
| ------------------------------------------------------------------------ | --------------------------------- | --------------------------------------------------------------- |
| `no credential found: set --figma-token, FIGMA_TOKEN, or [figma].token`  | Missing Figma PAT                 | Ask the user to `export FIGMA_TOKEN=figd_...` or run `iris secrets set figma` |
| `figma: command not found`                                           | CLI not installed                 | Run `iris install figma`                                    |
| `HTTP 403`                                                               | Invalid or expired token          | Ask the user to regenerate their Figma PAT                      |
| `HTTP 404`                                                               | File key wrong, or no access      | Double-check the URL; the PAT owner must have access to the file|
| `missing figma URL argument`                                             | No URL provided                   | Ask the user for the Figma URL                                  |
| `invalid URL`                                                            | URL doesn't match expected format | Verify the URL contains `/design/` (and `node-id=` for screenshot/nodes) |
| `node ... not found in response`                                         | `nodes` couldn't resolve the node | Check the `node-id` is correct and the PAT has file access      |

## Extending the CLI

The CLI source lives under `tools/figma/` in the iris repo. Subcommands are registered in `cmd/figma/main.go` and implemented under `internal/cmd/<name>/`. Shared API logic is in `internal/figma/client.go`. If the user asks for a new Figma operation that doesn't fit `screenshot`, `comments`, or `nodes`, add a subcommand there rather than shelling out to `curl` — it keeps auth, URL parsing, and output formatting consistent.
