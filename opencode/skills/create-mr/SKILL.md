---
name: create-mr
description: >
  Open a GitLab merge request for the current branch with `glab` — push the
  branch, derive the title (with the OTP-XXXX Jira tag), pick the target
  branch, set yourself as the assignee, and create the MR. Use when the user
  says "create an MR", "open a merge request", "/create-mr", or
  pushes a branch and wants it turned into an MR. A second, OPTIONAL step
  assigns reviewers on GitLab and announces the MR to the Lark code-review
  chat in the OTP team format — that step is separate and can be triggered on
  its own ("ask Ryan for review", "send a CR request") without creating
  anything.
---

# Create Merge Request

Two independent steps. **Step 1 creates the MR. Step 2 (optional) assigns
reviewers and announces it.** Run Step 1 alone when the user just wants an MR;
run Step 2 alone when an MR already exists and they want reviewers + a Lark
ping; run both back-to-back only when the user explicitly asks to "create and
announce". Creating an MR does **not** imply announcing it — never auto-run
Step 2.

For the underlying `glab` mechanics see the `iris-gitlab` skill; for the Lark
delivery details see the `lark-im` and `lark-contact` skills.

---

## Step 1 — Create the MR

### 1a. Locate the repo and branch

`cd` into the working repo (a submodule under `~/otp/glints/...`, `~/otp/iris`,
`~/otp/api-v2-hub/...`, etc.), then check the current branch:

```bash
git symbolic-ref --short HEAD
```

If it's the default branch (`main` / `master` / `staging` / `develop`), stop and
tell the user — you don't open an MR from the default branch.

### 1b. Push the branch

```bash
git push -u origin HEAD     # first push (no upstream yet)
git push                    # otherwise, make sure the remote is up to date
```

(`glab mr create --fill` also pushes for you, but pushing explicitly keeps the
two steps decoupled and lets you build a proper title in 1d.)

### 1c. Pick the target branch

Default to the remote's default branch:

```bash
git symbolic-ref refs/remotes/origin/HEAD --short   # → origin/main, origin/staging, …
```

Strip the `origin/` prefix. If that ref isn't set locally, fall back to
`glab repo view -F json` (`default_branch`) or `git remote show origin`. Honour
an override if the user names a target branch.

### 1d. Draft the title and description

- **Title** — `[OTP-XXXX] <summary>`. The branch name is the source of truth
  for the ticket: if it contains `OTP-\d+` (case-insensitive; uppercase the
  prefix, e.g. `feature/otp-2733` → `OTP-2733`), use it. If the branch name
  doesn't follow that convention, there is no Jira ticket — drop the
  `[OTP-XXXX]` prefix and don't ask. (Still honour a ticket the user names
  explicitly.) `<summary>`: reuse the commit subject when there's one commit;
  write a one-line summary when there are several. Use the `iris-jira` skill to
  pull the ticket summary when you want a sharper title and a ticket is known.
- **Description** — follow the convention: a `## Summary`, a `## Key Changes`,
  and a `## Testing` section, in that order, with the `Jira:` link under the
  summary when there's a ticket.

  ```markdown
  ## Summary

  <1–3 sentences: what this MR does and why.>

  Jira: https://glints.atlassian.net/browse/OTP-XXXX

  ## Key Changes

  - <one bullet per notable change; seed from `git log <target>..HEAD --pretty='- %s'`, then tighten/group>

  ## Testing

  - <how it was verified: tests run, manual steps, screenshots>
  ```

  Keep each section tight; drop the `Jira:` line when there's no ticket.

Show the user the title + target branch + description you're about to use, then
create it.

### 1e. Create

```bash
glab mr create \
  --source-branch "$(git symbolic-ref --short HEAD)" \
  --target-branch <target> \
  --title "[OTP-XXXX] <summary>" \
  --description "<description>" \
  --assignee "$(glab api user | jq -r .username)" \
  --yes
```

- **Always set `--assignee` to the current user** — the MR author owns it.
  Resolve your GitLab username with `glab api user | jq -r .username`.
- Add `--draft`, `--squash-before-merge`, or `--remove-source-branch` only if
  the user asks.
- `--fill` (uses commit info, auto-pushes) is a fine quick fallback when the
  user gives no details — but it won't add the `[OTP-XXXX]` tag, so prefer the
  explicit form above.
- **Do not pass `--reviewer` here.** Reviewer assignment is Step 2; only the
  assignee (you) is set at create time.

If an MR already exists for the branch, `glab` will say so — surface that, then
move to Step 2 if the user wanted reviewers / an announcement.

Print the MR URL when done. Stop here unless the user asked for Step 2.

---

## Step 2 — Assign reviewers + announce (optional, standalone)

Trigger this when the user says "assign <reviewer>", "ping for review", "send the
CR request", etc. — whether or not Step 1 just ran. If no MR number / URL is in
context, resolve it from the current branch:

```bash
glab mr view --output json     # the current branch's MR
```

The two sub-steps below are independent — do whichever the user asked for; doing
2a without 2b (or vice versa) is fine.

### 2a. Assign reviewers on GitLab

GitLab wants **GitLab usernames**, which are not the Lark display names. Ask the
user for the reviewer(s) if not given, and ask for the username if you only have
a first name and can't infer it.

```bash
glab mr update <number> --reviewer user1,user2
```

(Use `--assignee` too only if the user wants a specific assignee; otherwise the
MR author is the assignee.)

### 2b. Announce in the Lark code-review chat

Post to the **`OTP-CodeReviews`** chat (override if the user names another) in
this exact format — the same one the OTP `cr-request` skill uses:

```
📝 {Repo}
Assignee @{assignee}
Reviewer @{reviewer}
MR: [{MR_TITLE}]({MR_URL})
Jira: [{TICKET}](https://glints.atlassian.net/browse/{TICKET})
```

- **{Repo}** — map `git remote get-url origin`'s slug to a display name:
  `glints-employers` → Employers, `glints-api` → API, `api-v2` → API v2,
  `glints-dst` → DST, `houston` → Houston, `iris` → Iris. Unknown slug → ask the
  user; don't guess.
- **Assignee** — the MR's assignee, i.e. the current user (the one Step 1
  assigned). Get the display name from `glab api user | jq -r .name`; don't
  hardcode a name. Override only if the user explicitly names someone else.
- **Reviewer** — the reviewer(s) from 2a.
- **{TICKET}** — the `OTP-XXXX` from the title / branch. Omit the `Jira:` line
  entirely when there's no ticket.
- **@ mentions do not auto-convert in Lark.** Resolve each person's `open_id`
  via the `lark-contact` skill — the current user via its "my info" lookup,
  reviewers via `lark-cli contact +search-user <name>` — and wrap each as
  `<at user_id="ou_xxx">Name</at>`. If a name is ambiguous or not found, fall
  back to literal `@name` and warn the user afterwards that that person won't be
  pinged.

Send via the `lark-im` skill — `lark-cli im +messages-send --as bot
--chat-id oc_xxx --content '{"text":"…"}'`. Use `--content` with a `text`
payload, **not** `--markdown` (which rewrites content and can mangle the `<at>`
tags). Send immediately — the user asking for the announcement is the
authorisation; don't preview it first. Confirm with the chat name and the
returned `message_id`. If the send fails, surface the error and stop — don't
retry.

---

## Don'ts

- Don't open an MR from the default branch, and don't fabricate a Jira ticket,
  an MR URL, or a GitLab username — derive them from git / `glab` / the user.
- Don't bundle _reviewer_ assignment or the Lark announcement into the create
  step (setting yourself as the MR assignee in Step 1 is expected), and don't
  run Step 2 unless the user asked for it. They're separate by design.
- Don't use `--markdown` for the Lark message — use a `text` payload so the
  `<at>` tags survive.
- Don't force-push or push branches other than the current one.
