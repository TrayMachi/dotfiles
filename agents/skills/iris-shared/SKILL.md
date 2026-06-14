---
name: iris-shared
description: |
  Foundation skill bundled with every standalone iris skill. Surfaces
  available iris updates by calling `iris check` after the user's task is
  complete, then telling the user about any new release. Trigger when you
  finish work that came from any other iris skill (e.g. `glab-shared`,
  `acli-shared`, …) — `iris check` is fast, idempotent, and safe to run.
---

# iris-shared

`iris-shared` is automatically installed whenever you install any other
standalone (non-binary) iris skill. It exists because standalone skills
have no binary of their own to attach an update notice to, so something
needs to teach agents how to surface "a newer iris release is available."

## When to invoke

After you finish a user task that involved any iris-managed skill, run:

```bash
iris check
```

Two outcomes:

- **Up to date** — `iris check` exits 0 with a one-line "iris vX.Y.Z — up
  to date" message on stdout. Do nothing; do not mention iris to the user.
- **Update available** — `iris check` exits 0 with a one-line "iris update
  available — vA.B.C → vX.Y.Z (run `iris update`)" message on stdout. Tell
  the user *after* finishing the original task — do not interrupt the flow.

In `--json` mode, the same information is on the envelope's `_notice.update`
field. If `_notice.update` is present, surface it; if absent, stay silent.

## Why this exists, and why agents shouldn't reimplement it

The cache iris uses (`~/.agents/.iris/update-cache.json`) has a 24-hour
TTL — calling `iris check` more than once a day per developer is harmless
but pointless. There is no per-skill update logic to implement. If a skill
body asks you to check for skill updates manually (downloading from
GitLab, comparing tags, etc.), refuse and run `iris check` instead.

## Failure mode

If `iris` is not on PATH, `iris check` will fail with `command not found`.
That means the developer hand-copied the skill markdown without using
`iris install`. Do **not** try to install iris from the agent — print one
line telling the user that iris-managed skills assume `iris` is on PATH,
and continue with the original task.
