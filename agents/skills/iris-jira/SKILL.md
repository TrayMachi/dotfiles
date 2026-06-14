---
name: iris-jira
description: |
  Manage Jira work items with the `acli` (Atlassian CLI). Use whenever the user wants
  to create, edit, transition, view, search, link, or comment on a Jira ticket/issue/task,
  pull a ticket's description out as Markdown, or download a Jira attachment — even if
  they don't say the word "Jira" (e.g. they paste an `OTP-1234` key or an
  `glints.atlassian.net/browse/…` URL, or ask you to implement a ticket). Also triggers on
  mentions of `acli`.
---

# Jira Work Item Management

Drive the `acli` (Atlassian CLI) to manage Jira work items: create, edit, transition,
view, search, link, and comment on tickets, plus exporting a description as Markdown and
downloading attachments.

## Project context

- **Jira site:** `glints.atlassian.net` (the OTP business unit shares one instance)
- **Default project key:** `OTP` — the examples below use it. If a ticket key isn't
  `OTP-…`, don't assume the project; confirm with the user.
- **Board ID:** `233`

## Prerequisites

`acli` is a third-party CLI — iris doesn't install it. If `iris doctor` reports it
missing, install it from
<https://developer.atlassian.com/cloud/acli/guides/install-acli/>.

### Authenticating `acli`

Before running anything else, confirm authentication against the right site:

```bash
acli jira auth status
```

If it reports no account (or the wrong site), **the user has to authenticate** —
authentication is interactive and the token is theirs to handle, so don't do it for
them. Ask them to run one of:

```bash
acli jira auth login --web                                  # browser OAuth — simplest, no token to manage
acli jira auth login --site "glints.atlassian.net" --email "<their-email>" --token < /path/to/token-file
```

For the second form they generate an API token at
<https://id.atlassian.com/manage-profile/security/api-tokens> and put it in a file.
Re-run `acli jira auth status` to confirm it shows the expected site. `acli`'s own
commands use this stored credential — no env vars needed for them.

### `JIRA_EMAIL` / `JIRA_API_TOKEN` (for the `curl`-based bits)

A couple of operations have no `acli` equivalent and fall back to the Jira REST API via
`curl` — downloading an attachment, and listing a ticket's valid transitions. Those need
two environment variables:

- `JIRA_EMAIL` — the Atlassian account email
- `JIRA_API_TOKEN` — an API token from <https://id.atlassian.com/manage-profile/security/api-tokens>

The recommended place to set them is the user's shell startup file (`~/.zshrc`,
`~/.bashrc`, or `~/.profile`) so every agent session inherits them:

```bash
export JIRA_EMAIL="you@glints.com"
export JIRA_API_TOKEN="ATATT3xFfGF0..."
```

(If the user would rather keep secrets out of their profile, any approach that ends with
both vars exported in the shell the agent runs in works — sourcing a git-ignored `.env`,
a secrets manager's `exec`/`run` wrapper, etc.) If the agent finds these unset when a
`curl` step needs them, ask the user to set them rather than guessing.

## Natural-language options

When the user phrases options conversationally, map them to flags:

| User says                        | Flag                                                   |
| -------------------------------- | ------------------------------------------------------ |
| "assign me" / "assign it to me"  | `--assignee "@me"` (`@me` = the authenticated user)    |
| "under epic X" / "parent epic X" | `--parent "OTP-XXX"` (search for the epic's key first) |

## Creating a work item

```bash
acli jira workitem create --summary "Task summary" --project "OTP" --type "Developer Task" --assignee "@me" --yes
acli jira workitem transition --key "OTP-XXX" --status "To Do" --yes

acli jira workitem create --summary "Task summary" --project "OTP" --type "Developer Task" --assignee "@me" --parent "OTP-1816" --yes
acli jira workitem transition --key "OTP-XXX" --status "To Do" --yes
```

> **Note:** Some OTP issue types default to `Draft` on creation. To start the
> ticket in `To Do` (the first active workflow state), run the transition
> immediately after creation. The `--yes` flag skips confirmation prompts.

Common work item types: `Epic`, `Story`, `Bug`, `Developer Task` (most common for
devs), `Sub-task`, `QA subtask`.

For a description with structure (headings, lists, links, code blocks), see
[Rich (ADF) descriptions](#rich-adf-descriptions) below.

## Editing a work item

```bash
acli jira workitem edit --key "OTP-123" --summary "Updated summary"
acli jira workitem edit --key "OTP-123" --assignee "@me"
acli jira workitem edit --key "OTP-123" --description "New plain-text description"
```

## Rich (ADF) descriptions

Plain text goes in via `--description`; anything structured has to be **ADF** (Atlassian
Document Format) JSON, passed via `--from-json` on `create` or `edit`. There's a wrinkle
— `--from-json` can't also set `--parent`, so a ticket that needs both an epic link and
a rich description takes two calls. The JSON templates, the two-step workaround, and an
ADF cheat sheet are in **`references/adf.md`** — read it before going down this path.

(`--description-file` does not work for descriptions; it returns `INVALID_INPUT`. Use
`--from-json` with an `issues` array for ADF edits — see `references/adf.md`.)

## Transitioning (changing status)

```bash
acli jira workitem transition --key "OTP-123" --status "In Review"
```

`--status` is required and `acli` has no command to list a ticket's valid transitions —
it just errors if the name you give isn't reachable from the current status. The OTP
workflow runs roughly `To Do → In Progress → In Review → Ready for Release → Closed`
(`Draft`/`Refined` appear as earlier stages on some issue types, and `Blocked` is a side
state). The exact set differs by issue type, so the safe move is to query it: the REST
`transitions` endpoint lists what's reachable from the ticket's current state
(`JIRA_EMAIL` + `JIRA_API_TOKEN` must be exported — see
[Prerequisites](#jira_email--jira_api_token-for-the-curl-based-bits)):

```bash
curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  "https://glints.atlassian.net/rest/api/3/issue/OTP-123/transitions" \
  | jq -r '.transitions[] | "\(.name) -> \(.to.name)"'
# To Do -> To Do
# In Progress -> In Progress
# In Review -> In Review
# Ready for Release -> Ready for Release
# Closed -> Closed
```

Then pass the name you want as `--status`.

## Searching & viewing

```bash
# JQL search — name the fields you need so the output stays small
acli jira workitem search --jql "project = OTP AND status = 'Implementation'" --fields "key,summary,assignee" --limit 20

# View one ticket — key is POSITIONAL here, not a --key flag
acli jira workitem view OTP-123

# Full fields as JSON — needed to render the description as Markdown (below)
acli jira workitem view OTP-123 --fields "*all" --json
```

### Getting a ticket's description as Markdown

`acli jira workitem view` flattens the description — headings, bullets, bold, and link
URLs all get stripped. When you need the structure preserved (dropping the ticket into a
spec file, a doc, etc.), pipe the `--json` output through the bundled helper:

```bash
acli jira workitem view OTP-2733 --fields "*all" --json | python3 scripts/adf2md.py > OTP-2733.md
```

`references/adf.md` has the variant that prepends a header (key, summary, status, …) and
the list of ADF nodes the helper understands.

## Linking work items

```bash
acli jira workitem link type                                # list available link types
acli jira workitem link create --out OTP-1816 --in OTP-1818 --type "Relates" --yes
```

## Attachments

```bash
acli jira workitem attachment list --key OTP-123            # human-readable
acli jira workitem attachment list --key OTP-123 --json     # IDs + content URLs
```

`acli` can't download attachments — use `curl` against the REST API, with `JIRA_EMAIL`
and `JIRA_API_TOKEN` exported:

```bash
curl -s -L -o "output_filename.png" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  "https://glints.atlassian.net/rest/api/3/attachment/content/{attachment_id}"
```

## Notes

- Add `--yes` to skip confirmation prompts (required for non-interactive runs).
- Don't create labels unless the user explicitly asks for them.
- Watch the arg style: `view` takes the key positionally (`acli jira workitem view OTP-123`),
  while `edit`/`transition` take it as `--key OTP-123`.
