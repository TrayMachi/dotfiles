---
name: iris
description: |
  Teaches agents when to drive the `iris` launcher — installing or removing
  iris-managed CLI tools and skills, listing what's available, running
  `iris check` for update notices, and `iris doctor` for diagnostics. Use
  when the user asks to add or remove an iris-managed tool/skill, asks
  what's installable, asks "is iris up to date", or asks why an iris-managed
  command is missing or misbehaving.
args: |
  iris install <name>            - install a tool or skill
  iris install --local <name>    - install from on-disk source (developer loop)
  iris uninstall <name>          - remove an installed artifact
  iris list                      - show installable entries
  iris check                     - report whether iris is behind the latest release
  iris doctor                    - report installed tools, runtimes, and third-party probes
  iris --json <subcommand>       - emit the standard JSON envelope on stdout
  iris --version                 - print the installed iris version
---

`iris` is the single entry point for managing the iris artifact set. It
installs CLI tools and skills, removes them, lists what's available, runs
update checks, and reports diagnostics.

## Installing

```bash
# From a release (Phase 7 onwards):
iris install figma

# From an on-disk source checkout (current developer loop):
iris install --local --from-source ~/otp/iris figma
```

`iris install` does three things for a tool:

1. Builds the tool's binary and copies it to `$BINDIR` (default `~/.local/bin`).
2. Drops the tool's bundled skill files into the canonical
   `~/.agents/skills/<name>/`.
3. Creates per-skill symlinks into `~/.claude/skills/<name>/` and
   `~/.config/opencode/skills/<name>/` so Claude and OpenCode see the same
   skill the canonical Codex root holds.

Standalone skills go through the same skill steps and skip the binary.

## Refusing to overwrite manual edits

If a runtime root already has a non-symlink directory at
`<runtime>/skills/<name>/`, `iris install` refuses to clobber it and asks
for `--migrate` to confirm. This is what protects skills the developer
hand-installed before adopting `iris`.

## Uninstalling

```bash
iris uninstall figma
```

`iris uninstall` reads `~/.agents/.iris/installed.json` and removes only
the binary, canonical directories, and symlinks `iris` itself created.
Anything else (manual edits, hand-copied skills, stray binaries) is left
alone.

## Listing

```bash
iris list --local --from-source ~/otp/iris
iris --json list --local --from-source ~/otp/iris | jq '.data[].name'
```

Recommended entries are flagged with a leading `*`. The `--json` envelope
mirrors the rest of the iris tools — `{"ok":true,"data":[…]}`.

## Diagnostics — `iris doctor`

```bash
iris doctor                    # human-readable summary on stdout
iris --json doctor | jq '.data'
```

`iris doctor` produces a single status document covering: which iris-managed
tools and skills are recorded as installed (and whether each tool's binary
still answers `--version`), which agent runtimes are configured on disk
(Claude / Codex / OpenCode), and every third-party CLI declared by an
installed tool's `tool.yaml` (`glab`, `acli`, …) with the install URL when
one is missing.

The doctor never installs anything. When a probe reports `present: false`,
read the `install_url` field and tell the user how to install the missing
CLI; do not try to install it on their behalf.

The schema is documented in `docs/conventions.md` (`iris doctor` report
schema).

## Exit codes

The launcher follows the iris convention:

| Code | Meaning         |
| ---- | --------------- |
| `0`  | success         |
| `1`  | usage error     |
| `2`  | runtime error   |
| `3`  | auth error      |
