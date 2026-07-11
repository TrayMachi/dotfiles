---
name: iris-branch
description: |
  Create Jira-backed git branches for OTP implementation work. Use whenever the
  user asks to create or check out a branch from a Jira ticket, says "branch
  OTP-1234" or "branch from Jira", shares a glints.atlassian.net/browse URL, or
  wants to start durable MR-bound work that should first get a Jira ticket and a
  conventional `feature/<lowercase-ticket>` branch name.
---

# Branch

Use this skill to turn a Jira ticket or work description into a conventional git
branch. It owns the ticket-to-branch workflow; Jira command details live in
`iris-jira`, and isolated checkout setup lives in `iris-worktree`.

This skill is for durable work that will likely become an MR. For throwaway or
experimental branches, plain git is fine and no Jira ticket is required.

## OTP defaults

The OTP repos share the same branch convention, so this skill does not need a
repo-local branch config file.

- Jira site: `glints.atlassian.net`.
- Jira project: `OTP`.
- Default work item type for newly created tickets: `Developer Task`.
- Branch name: `feature/{ticket_lower}`, e.g. `feature/otp-1234`.
- Base branch: detect from `origin/HEAD` unless the user names another base.
- Ticket transition after branch creation: `In Progress`.

Review-app URL derivation remains repo-local and belongs in the local repo's MR
or ship workflow, not in this shared branch skill.

## Workflow

### 1. Inspect the repository

Run from the repo where the user wants the branch:

```bash
git status --short
git branch --show-current
git remote -v
```

If this is not a git repo, stop with a clear error. If the worktree has dirty
changes, ask before stashing or carrying them onto a new branch. Do not reset,
clean, or discard user changes.

### 2. Resolve the Jira ticket

Use `iris-jira` for all `acli` commands.

If the user gave a Jira key or URL, extract the key with a case-insensitive
`[A-Z][A-Z0-9]+-[0-9]+` pattern. Support raw keys like `OTP-1234` and browse URLs
like `https://glints.atlassian.net/browse/OTP-1234`. Canonicalize the key to
uppercase for Jira commands and lowercase only for branch names.

Verify explicit keys rather than silently replacing typos:

```bash
acli jira workitem view OTP-1234
```

If the lookup fails, stop and report that the provided key could not be verified.
Do not create a different ticket unless the user explicitly asks.

If the user described work but gave no key, create an OTP `Developer Task` first.
Summarize the user's requested work into a concise ticket title. Use a rich ADF
description only when the user provided enough structured detail to justify it;
otherwise a plain summary is enough.

Typical command shape:

```bash
acli jira workitem create \
  --summary "Short task summary" \
  --project "OTP" \
  --type "Developer Task" \
  --assignee "@me"
```

Report the new key and URL before creating the branch.

### 3. Derive the branch name and base

Lowercase the Jira key and prepend `feature/`, e.g. `OTP-1234` becomes
`feature/otp-1234`. Do not add a summary slug. The Jira ticket number keeps the
branch short enough for the OTP deployment constraints.

Use the base branch named by the user, or detect the remote default branch:

```bash
git symbolic-ref refs/remotes/origin/HEAD --short
```

Strip the `origin/` prefix. If that ref is unavailable, use `git remote show
origin` and read the `HEAD branch` line. If the remote default cannot be
determined, ask the user for the base branch.

### 4. Create the branch or delegate to a worktree

If the user asked for both a branch and a worktree, do not create or check out
the branch in the source checkout. Resolve the ticket, branch name, and base
branch, then hand off directly to `iris-worktree` with the resolved branch and
base. The worktree skill owns the bundled script invocation and must create the
branch as part of worktree creation, preserving the source checkout's current
branch.

Only use the commands below for branch-only requests.

Fetch the base branch before creating from it:

```bash
git fetch origin <base>
```

Check for existing local and remote branches:

```bash
git show-ref --verify --quiet refs/heads/<branch-name>
git ls-remote --exit-code --heads origin <branch-name>
```

If the branch already exists locally, ask whether to check it out or abort. If it
exists on origin but not locally, ask whether to check out a tracking branch:

```bash
git checkout -b <branch-name> --track origin/<branch-name>
```

For a new branch:

```bash
git checkout -b <branch-name> origin/<base>
```

### 5. Transition the ticket

After the branch or worktree exists, transition the ticket to `In Progress`:

```bash
acli jira workitem transition --key OTP-1234 --status "In Progress"
```

If the transition fails because the status is not reachable, report the failure
without undoing the branch. Use `iris-jira` if you need to inspect valid
transitions.

### 6. Report the result

Use concise plain prose with these fields:

- Ticket key and URL, and whether it was existing or created.
- Branch name.
- Base branch.
- Whether the branch was created, checked out locally, checked out from origin, or delegated to a worktree.
- Ticket transition result, if attempted.
- Current path when a worktree was created.

## Examples

Create the default feature branch from a ticket:

```bash
# User: create branch OTP-1234
# Branch: feature/otp-1234
```

Create from a Jira URL:

```bash
# User: branch https://glints.atlassian.net/browse/OTP-1234
# Branch: feature/otp-1234
```

Create the ticket first when the user describes MR-bound work:

```bash
# User: start a branch to add retry handling to invoice sync
# Action: create an OTP Developer Task, then branch from the new key
```

## Boundaries

- Do not create a Jira ticket to replace an explicit key that failed lookup.
- Do not assume a non-OTP project key or branch convention without user confirmation.
- Do not stash, reset, clean, or discard dirty changes unless the user explicitly approves.
- Do not create review-app URLs here; that derivation belongs in repo-local skills or MR reporting.
- Do not push the branch or create an MR unless the user asks; use `iris-merge-request` for that workflow.
