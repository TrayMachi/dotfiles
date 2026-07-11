---
name: iris-worktree
description: |
  Create git worktrees for implementation work. Use this whenever the
  user asks for a worktree or wants to start feature work without disturbing
  their current branch. Supports repo-local configuration for copied dev files,
  branch shorthand, path naming, base branch, and install commands.
---

# Worktree

Use this skill to create a separate git worktree for implementation work. The
goal is to avoid colliding with the user's active checkout while still giving
the new checkout enough local-only files to be productive.

## Command

Use the bundled `scripts/create-worktree.sh` script from this skill. Resolve it
relative to the installed skill directory, then run that resolved script path
from inside the source repository.

In the examples below, `<create-worktree>` means that resolved bundled script
path. Do not look for `scripts/create-worktree.sh` inside the target repo unless
that repo also happens to provide its own wrapper.

```bash
<create-worktree> <branch-or-ticket> [options]
```

Run it from inside the source repository. The script creates the worktree from
the current repo and copies any configured local-only files from the source
checkout into the new checkout.

When the requested branch does not already exist, the bundled script must create
the branch as part of worktree creation rather than checking it out in the source
checkout first. This keeps the source checkout on its current branch and avoids
disrupting someone else who may be working there.

## Options

```text
--base <branch>                    Base branch for new branches.
--path <path>                      Worktree path. Default: .worktrees/{branch_slug}.
--path-template <template>         Template for default path.
--copy <path>                      Extra path to copy. Repeatable.
--install-command <command>        Command to run in the new worktree.
--config <path>                    JSON config file. Default: .iris/worktree.json if present.
```

Template variables:

- `{repo}`: current repository directory name.
- `{branch}`: resolved branch name.
- `{branch_slug}`: branch name normalized for paths.
- `{ticket}`: original ticket-like input, if any.
- `{ticket_lower}`: lowercase ticket-like input, if any.

## Repo-local config

Repos can add a gitignored or committed `.iris/worktree.json` when they need
consistent local setup:

```json
{
  "base": "master",
  "path_template": ".worktrees/{branch_slug}",
  "ticket_branch_template": "feature/{ticket_lower}",
  "copy": ["server/config/local.yml", ".husky/_"],
  "install_command": "yarn install"
}
```

Config values are defaults. Explicit CLI flags override or extend them:

- `--base`, `--path-template`, and `--install-command` replace config values.
- `--copy` appends to the configured `copy` list.
- `--path` bypasses the path template entirely.

JSON config parsing requires `jq`. The script does not require `jq` when no
config file is used.

## Ignore the worktree path

The default `.worktrees/{branch_slug}` path lives inside the source repo, so git
shows it as untracked in the parent checkout and a careless `git add -A` could
stage an entire worktree. Add the worktree root to `.gitignore` (or
`.git/info/exclude` if you do not want to commit the rule):

```gitignore
.worktrees/
```

If a repo's `path_template` points somewhere else, ignore that path instead.

## Workflow

1. Inspect `git status --short` in the source checkout. If it has unrelated
   dirty changes, do not copy or stash them unless the user asks.
2. Pick the branch and base branch. Honor user-provided branch and base names.
3. Run the script from the source repo. For new branches, let the script create
   the branch in the new worktree; do not pre-create it in the source checkout.
4. Report the new worktree path, branch, base, copied paths, skipped paths, and
   install command result.
5. Move future implementation, lint, test, commit, and MR work into the new
   worktree.

## Examples

Create a worktree for an existing branch:

```bash
<create-worktree> feature/my-change
```

Create a new branch from a non-default base:

```bash
<create-worktree> feature/my-change --base develop
```

Use ticket shorthand when the repo config defines `ticket_branch_template`:

```bash
<create-worktree> OTP-1234
```

Copy a one-off local file and run install:

```bash
<create-worktree> feature/my-change \
  --copy .env.local \
  --install-command "yarn install"
```

## Boundaries

- Do not invent repo-specific copied paths. Use config or user-provided
  `--copy` values.
- Do not run an install command unless config or the user asks for it.
- Do not stash, reset, or clean the source checkout as part of worktree setup.
- If the destination path exists, stop and ask for a different path.
