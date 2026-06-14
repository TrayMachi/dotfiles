---
name: iris-gitlab
description: |
  GitLab CLI (`glab`) operations for merge requests, CI/CD pipelines, job logs, and MR comments.
  Use when asked to: list/view/create MRs, check pipeline status, view CI job logs,
  retry failed jobs, comment on MR code, post review comments, or interact with GitLab repositories.
  Also triggers on: "what's the pipeline doing", "check CI", "is CI green", "create an MR",
  "post comments on the MR", any gitlab.glints.com URL, or mentions of glab commands.
---

# GitLab CLI

Use `glab` for GitLab operations. Always `cd` into the repo directory first — the GitLab host
is resolved from the local git remote, so glab commands fail outside a repo.

## Prerequisites

`glab` is a third-party CLI; iris does not install it. If `iris doctor` reports `glab` as
missing, follow the upstream install instructions:

<https://gitlab.com/gitlab-org/cli/#installation>

### Authenticating with a Personal Access Token

`glab` needs a PAT to talk to `gitlab.glints.com`. Before running any other `glab`
command in this skill, check whether the user is already authenticated:

```bash
glab auth status --hostname gitlab.glints.com
```

If that command exits non-zero or prints "not logged in", **stop** and walk the user
through these steps — do not try to generate or paste a token on their behalf:

1. Open the PAT page in a browser:
   <https://gitlab.glints.com/-/user_settings/personal_access_tokens>
2. Create a token with the scopes `api`, `read_repository`, and `write_repository`.
   (`api` is required for MR / CI / discussion endpoints; the repository scopes are
   needed for `glab mr create` to push.)
3. Copy the token, then run the following in their shell — `glab` will prompt for
   the token interactively and store it in its own config:

   ```bash
   glab auth login --hostname gitlab.glints.com --token
   ```

Reference: <https://gitlab.com/gitlab-org/cli#personal-access-token>.

Re-run `glab auth status --hostname gitlab.glints.com` to confirm. Once it reports
`Logged in to gitlab.glints.com`, you can proceed with the rest of this skill.

## Quick Reference

Pick the right section based on what you need:

| Goal                                    | Section                                             |
| --------------------------------------- | --------------------------------------------------- |
| List or view MRs                        | [Common Commands](#common-commands)                 |
| Get MR branches, description, diff refs | [Fetching MR Metadata](#fetching-mr-metadata)       |
| Create a new MR                         | [Creating Merge Requests](#creating-merge-requests) |
| Check CI status or read job logs        | [CI/CD & Job Logs](#cicd--job-logs)                 |
| Post inline code review comments        | Read `references/inline-comments.md`                |

In the snippets below, `<repo-path>` is the absolute path to the local repo on disk
and `<encoded-path>` is the URL-encoded GitLab project path
(e.g. `group%2Fsubgroup%2Fproject`). Both are project-specific — read the
project's `AGENTS.md` (or ask the user) for the right values.

The host is `gitlab.glints.com`.

## Common Commands

```bash
cd <repo-path> && glab mr list
```

**Example output:**

```
Showing 18 open merge requests on group/project. (Page 1)

!787  group/project!787  feat: short summary           (master) ← (feature/my-branch)
!784  group/project!784  Resolve slow query            (feature/parent) ← (feature/child)
!780  group/project!780  fix: workflow timeout         (master) ← (feature/another-branch)
```

Other common commands:

```bash
glab mr view <mr-number>        # View MR details
glab mr create                  # Create new MR (interactive)
glab ci status                  # Pipeline status for current branch
```

## Fetching MR Metadata

Use the GitLab API to get structured MR data. This is the entry point for code review,
CI checks, or any operation that needs MR context.

### Get source/target branches and description

```bash
cd <repo-path> && glab api "projects/<encoded-path>/merge_requests/<mr-number>" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('source:', d['source_branch'])
print('target:', d['target_branch'])
print('description:', d.get('description', ''))
print('author:', d['author']['username'])
print('state:', d['state'])
"
```

**Example output:**

```
source: feature/my-branch
target: master
description: ## Summary
- ...
author: someuser
state: opened
```

### Get diff refs (for inline comments or accurate diffs)

```bash
cd <repo-path> && glab api "projects/<encoded-path>/merge_requests/<mr-number>" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
refs = d.get('diff_refs', {})
print('base_sha:', refs.get('base_sha'))
print('head_sha:', refs.get('head_sha'))
print('start_sha:', refs.get('start_sha'))
"
```

**Example output:**

```
base_sha: 715fcb21f82d2c49d96e7fd6662f886d5a61e778
head_sha: 490772c15b962dc4d58dab887d0b60127aacdc3b
start_sha: dfdf3517441f5a868e7e0633651e6abc5c10a398
```

### Fetch branches and diff locally

After getting the source and target branches from the API:

```bash
# Fetch both branches
git fetch origin <source-branch> <target-branch>

# Diff using the merge base (three-dot diff, same as GitLab MR view)
git diff origin/<target-branch>...origin/<source-branch>

# Or use the exact SHAs from diff_refs for precise diffs
git diff <base-sha>..<head-sha>
```

## Creating Merge Requests

`glab mr create` supports two authoring modes — auto-fill from git or manual. They are
mutually exclusive because `--fill` reads the commit message to populate title and description,
while `--title`/`--description` provide them explicitly. Combining both causes an error:
`Usage of --title and --description overrides --fill.`

**Rule of thumb**:

- **Single commit** → use `--fill` (title/description auto-populated from the commit message)
- **Multiple commits** → use `--title`/`--description` (write a custom summary)

```bash
# Single commit: auto-fill from the commit message
glab mr create --fill --target-branch <target-branch> --assignee @me

# Multiple commits: custom title and description (do NOT use --fill)
glab mr create --target-branch <target-branch> --assignee @me \
  --title "fix(scope): short description" \
  --description "$(cat <<'EOF'
## Summary
...
EOF
)"
```

## CI/CD & Job Logs

### Check pipeline status

```bash
cd <repo-path> && glab ci status
```

**Example output:**

```
(manual) • not started  deploy    deploy-production
(success) • 00m 06s     deploy    deploy-staging
(success) • 11m 55s     test      test-go
(success) • 01m 45s     test      format-go
(success) • 12m 38s     build     build-unified

https://gitlab.example.com/group/project/-/pipelines/386130
SHA: dfdf3517441f5a868e7e0633651e6abc5c10a398
Pipeline state: success
```

### View job logs

To read a job's trace output, you need the numeric job ID. Find it from the pipeline:

```bash
# List jobs in a pipeline
glab api "projects/<encoded-path>/pipelines/<pipeline-id>/jobs" \
  | python3 -c "
import sys, json
for j in json.load(sys.stdin):
    print(f'{j[\"id\"]}  {j[\"name\"]:25s}  {j[\"status\"]:10s}  {j[\"stage\"]}')
"
```

**Example output:**

```
1740321  deploy-production          manual      deploy
1740320  deploy-staging             success     deploy
1740319  test-go                    success     test
1740318  format-go                  success     test
1740317  build-unified              success     build
```

Then fetch the trace:

```bash
# View job logs (URL-encode project path: / becomes %2F)
glab api projects/<encoded-path>/jobs/<job-id>/trace | tail -200

# Retry a failed job
glab ci retry <job-id>
```

## Inline MR Comments

To post inline code review comments on an MR, read and follow `references/inline-comments.md`.

The key thing to know: use `glab api --input <file>` (not `--raw-field`) so the nested
`position` object survives — `--raw-field` flattens it to form keys and GitLab silently
falls back to a general discussion with `position: null`.
