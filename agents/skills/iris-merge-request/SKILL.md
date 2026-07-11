---
name: iris-merge-request
description: |
  Create or update GitLab merge requests with `glab`. Use whenever the user asks
  to open, create, update, or prepare an MR, push a branch for review, or turn
  current branch changes into a GitLab MR. This skill also contains an optional
  code review request follow-up, but do not assign reviewers or send Lark code
  review requests unless the user explicitly asks to do that.
---

# Merge Request

Use this skill to create or update a GitLab merge request from the current git
branch. It owns the end-to-end MR workflow; lower-level `glab` commands and CI
inspection details live in `iris-gitlab`.

Creating or updating an MR is separate from requesting review. Do the MR work by
default. Only run the review follow-up section when the user explicitly asks to
assign reviewers, ask for review, send a CR request, or similar.

## Inputs

- Source branch: default to the current branch.
- Target branch: default to the remote default branch, unless the user names a
  target or the branch is stacked on another feature branch.
- Optional Jira key or URL: derive from branch, commits, or user input.
- Optional reviewer or code review request: opt-in only.

## Workflow

### 1. Inspect the repo

Run from the repo containing the branch:

```bash
git status --short
git branch --show-current
git log --oneline -10
```

Do not open an MR from a default branch such as `main`, `master`, `develop`, or
`staging`.

If the worktree has unrelated dirty changes, stop and ask before including them.
If the user asked you to commit first, use the appropriate repo commit skill or
the generic commit workflow before creating the MR.

### 2. Push the source branch

Push explicitly so the MR creation step is predictable:

```bash
git push -u origin HEAD
```

If the branch already has an upstream, `git push` is enough.

### 3. Check for an existing MR

```bash
glab mr list --source-branch "$(git branch --show-current)"
```

If an MR already exists, update it only as needed: title, description, target
branch, draft state, assignee, or reviewer fields requested by the user. Do not
create a duplicate MR.

### 4. Choose the target branch

Default to the remote default branch:

```bash
git symbolic-ref refs/remotes/origin/HEAD --short
```

Strip `origin/` from that value. If it is unavailable, use `glab repo view -F
json` or `git remote show origin` to find the default branch.

For stacked branches, target the parent feature branch instead of the remote
default. If the stack relationship is ambiguous, ask; do not flatten a stack by
guessing.

### 5. Draft title and description

Prefer a title that is useful outside the local repo context:

```text
[JIRA-123] concise summary
```

If no Jira key is known, omit the prefix. Derive Jira keys from the branch name,
commit messages, MR description, or explicit user input. Use `iris-jira` when
you need to verify or fetch ticket details.

Use this description shape unless the repo has a stricter local template:

```markdown
## Summary

<1-3 sentences explaining what changed and why.>

Jira: https://glints.atlassian.net/browse/<KEY>

## Key Changes

- <one bullet per notable change>

## Testing

- <commands run, manual checks, or why no tests were run>
```

Omit the Jira line when there is no ticket.

### 6. Create or update the MR

Single-commit branches can use `--fill` when the commit message is already a
good title and description:

```bash
glab mr create --fill --target-branch <target> --assignee @me
```

Multi-commit branches, unclear commit messages, or Jira-prefixed titles should
use explicit fields:

```bash
glab mr create \
  --source-branch "$(git branch --show-current)" \
  --target-branch <target> \
  --title "<title>" \
  --description "<description>" \
  --assignee @me \
  --remove-source-branch \
  --yes
```

Set yourself as assignee unless the user says otherwise. Add `--draft`,
`--squash-before-merge`, or reviewers only when requested.

### 7. Report the result

Return:

- MR URL.
- Source branch.
- Target branch.
- Whether it was created or updated.
- Pipeline URL/status if available.
- Testing or verification summary used in the MR description.

## Optional Review Follow-up

This section uses MR metadata, but it is still opt-in. Do not run it just
because an MR was created.

Run this section only when the user explicitly asks to assign reviewers, ask for
review, send a code review request, or similar.

### Assign GitLab reviewers

GitLab reviewers are GitLab usernames, not Lark display names. If the user only
gave a first name and you cannot infer the username confidently, ask.

```bash
glab mr update <mr> --reviewer user1,user2
```

### Send Message in Lark

Use `lark-contact` to resolve mentions and `lark-im` to send the message. Do
not hardcode Lark `open_id`s. If a user cannot be resolved unambiguously, send
plain text for that person and warn that they may not be pinged.

Use the local repo's configured chat and message template when one exists. For
OTP code reviews, the default shape is:

```text
📝 {Repo}
Assignee <assignee mention>
Reviewer <reviewer mention>
MR: [{MR_TITLE}]({MR_URL})
Jira: [{TICKET}](https://glints.atlassian.net/browse/{TICKET})
```

Send as bot using a text payload so `<at user_id="...">Name</at>` tags are not
rewritten:

```bash
lark-cli im +messages-send --as bot --chat-id <chat-id> --content '{"text":"..."}'
```

The user's explicit request to send the message is the authorization; do
not stop for a preview unless they asked for a draft.

## Boundaries

- Do not create MRs from default branches.
- Do not create duplicate MRs for the same source branch.
- Do not force-push, rebase, or rewrite history unless the user explicitly asks.
- Do not invent Jira keys, MR URLs, GitLab usernames, reviewers, or Lark IDs.
- Do not send a code review request or assign reviewers by default.
