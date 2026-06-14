---
name: iris-qa
description: |
  Send a QA endorsement request to otp-endorsement with rich text formatting (clickable links, styled sections), then create a QA subtask in Jira for Andi Khaerul Awwal. Requires glab CLI for direct MR links and acli for Jira. Tags author + Andi, conditionally tags UX based on audience (EMP/CDD). Trigger this skill when the user mentions "qa endorsement", "send to qa", "request qa review", or provides review app URLs.
args: |
  [review_app_url...] - Optional review app URLs (space/comma/newline separated).
    When provided, includes them in the message as clickable links.
    Supports multiple URLs: iris-qa https://android.app https://ios.app
---

# QA Endorsement

Send a structured QA endorsement request to the `otp-endorsement` Lark channel using **rich text formatting** for better readability and clickable links, then create a Jira `QA subtask` for Andi Khaerul Awwal under the appropriate parent ticket.

## Usage

```
iris-qa [review_app_url...]
```

## Arguments

| Argument         | Required | Description                                                                                                |
| ---------------- | -------- | ---------------------------------------------------------------------------------------------------------- |
| `review_app_url` | No       | One or more review app URLs (space, comma, or newline separated). Can be Android, iOS, or web review apps. |

**Example invocations:**

- `iris-qa` - Run without URLs (review apps section will show "Not provided")
- `iris-qa https://review.glints.com/android/abc123` - Single review app
- `iris-qa https://review.glints.com/android/abc123 https://review.glints.com/ios/abc123` - Multiple review apps
- `iris-qa "https://app1.com, https://app2.com"` - Comma-separated in quotes

Environment variables:

- `JIRA_REGEX` - Pattern to extract ticket IDs (default: `[A-Z]+-[0-9]+`)
- `JIRA_BASE_URL` - Jira ticket URL prefix (default: `https://glints.atlassian.net/browse`)

## Prerequisites

- Run inside a git repository
- [glab](https://glab.readthedocs.io/) CLI installed and authenticated (`glab auth login`)
- `acli` installed and authenticated against `glints.atlassian.net` (`acli jira auth status`)
- `jq` installed for extracting Jira fields and building the create payload
- lark-cli configured with a bot app that has `im:message:send_as_bot` scope
- Bot must be added as a member of the `otp-endorsement` chat
- Open merge request exists for the current branch

## Routing Rules

Always tagged:

- Author (resolved from git config + Lark contact lookup)
- Andi Khaerul Awwal (QA)

Conditionally tagged (requires UX review + audience confidence ≥ 0.60):

- `EMP` audience → Tung An (UX)
- `CDD` audience → Ogant Biru Samudera (UX)

## Contact Resolution

Use `lark-contact` skill to search for contacts by name or email. All contacts must be resolved dynamically - do not use hardcoded IDs.

## Jira Rules

- `ticket_id` is the original dev/source Jira ticket extracted from the branch or recent commits.
- The Lark message must keep linking to the original dev/source Jira ticket, not the new QA ticket.
- The QA Jira summary is `"[QA]" + source_summary` with no inserted space.
- The QA Jira type is `QA subtask`.
- If the source ticket is already a subtask, create the QA ticket under the source ticket's parent.
- Otherwise create the QA ticket under the source ticket itself.
- Set both assignee and reporter to `andi.awwaal@glints.com`.
- Leave the QA Jira description empty.
- Transition the QA Jira ticket to `To Do` after creation.

## Workflow

### 1. Parse Review App URLs from Arguments

Extract review app URLs from positional arguments (`$@`):

```bash
review_app_urls=()
for token in "$@"; do
  # Handle comma-separated URLs within a single argument
  IFS=',' read -ra url_parts <<< "$token"
  for part in "${url_parts[@]}"; do
    # Trim whitespace and check if valid URL
    trimmed=$(echo "$part" | xargs)
    [[ "$trimmed" =~ ^https?:// ]] && review_app_urls+=("$trimmed")
  done
done
```

### 2. Collect Git Context

```bash
repo_name=$(basename "$(git rev-parse --show-toplevel)")
current_branch=$(git branch --show-current)
origin_url=$(git remote get-url origin 2>/dev/null || true)

# Convert origin URL to web URL
if [[ "$origin_url" =~ ^git@ ]]; then
  gitlab_repo_url=$(printf '%s' "$origin_url" | sed -E 's#^git@([^:]+):#https://\1/#; s#\.git$##')
else
  gitlab_repo_url=$(printf '%s' "$origin_url" | sed -E 's#\.git$##')
fi

# Get MR IID via glab (supports both table and json output)
mr_info=$(glab mr list --source-branch="$current_branch" --per-page=1 2>/dev/null)
mr_iid=$(printf '%s' "$mr_info" | grep -oE '^![0-9]+' | head -1 | tr -d '!')
# Fallback: try to extract from "!1234" format in any position
[[ -z "$mr_iid" ]] && mr_iid=$(printf '%s' "$mr_info" | grep -oE '!\s*[0-9]+' | head -1 | tr -d '! ')
mr_url="$gitlab_repo_url/-/merge_requests/$mr_iid"

# Extract the original dev/source Jira ticket ID
branch_ticket=$(printf '%s' "$current_branch" | grep -oE '[A-Z]+-[0-9]+' | head -1)
commit_ticket=$(git log --oneline -n 50 --no-merges | grep -oE '[A-Z]+-[0-9]+' | head -1)
ticket_id="${branch_ticket:-$commit_ticket}"
jira_url="${JIRA_BASE_URL:-https://glints.atlassian.net/browse}/$ticket_id"
```

### 3. Fetch Source Jira Details

Read the source Jira so the QA subtask can inherit the title and parentage correctly:

```bash
source_ticket_json=$(acli jira workitem view "$ticket_id" \
  --fields "key,summary,issuetype,parent,status" \
  --json)

source_summary=$(jq -r '.fields.summary' <<<"$source_ticket_json")
source_is_subtask=$(jq -r '.fields.issuetype.subtask' <<<"$source_ticket_json")
source_parent_ticket_id=$(jq -r '.fields.parent.key // empty' <<<"$source_ticket_json")
source_parent_issue_id=$(jq -r '.fields.parent.id // empty' <<<"$source_ticket_json")

if [[ "$source_is_subtask" == "true" ]]; then
  qa_parent_ticket_id="$source_parent_ticket_id"
  qa_parent_issue_id="$source_parent_issue_id"
else
  qa_parent_ticket_id="$ticket_id"
  qa_parent_issue_id=$(jq -r '.id' <<<"$source_ticket_json")
fi

qa_summary="[QA]$source_summary"
```

### 4. Classify Changes

Produce a classification JSON for internal routing:

```json
{
  "audience": "EMP",
  "audience_confidence": 0.85,
  "requires_ux_review": true,
  "testing_scope": "new_feature",
  "overview": ["Brief description of change"],
  "manual_qa_steps": ["Step 1", "Step 2", "Step 3"]
}
```

**Classification heuristics:**

| Aspect            | Signal → Decision                                                                           |
| ----------------- | ------------------------------------------------------------------------------------------- |
| **Audience**      | Repo/path contains: `emp/employer/internal` → EMP; `cdd/customer/merchant/public` → CDD     |
| **UX Review**     | UI files changed (tsx, jsx, css, html, dart, .ui, .widget) → `true`; backend-only → `false` |
| **Testing Scope** | New feature/screen/endpoint/widget → `new_feature`; Bug fix/refactor → `regression`         |

### 5. Resolve Contacts

Use the `lark-contact` skill for contact lookup and `lark-im` skill for chat lookup.

**Contacts to resolve:**

- **Author** (required): Search by git config email using `lark contact +search-user`
- **Andi Khaerul Awwal** (QA): Search by name
- **UX Designer** (conditional): Only if `requires_ux_review && audience_confidence >= 0.60`
  - EMP audience → Search for "Tung An"
  - CDD audience → Search for "Ogant Biru Samudera"

**Chat lookup:**

- Use `lark im +chat-search` to find "OTP Endorsement" chat

### 6. Compose & Send Message

Use the `lark-im` skill to send a **rich text post** message as bot. Rich text provides:

- Clickable links for MR, Jira, and Review Apps
- Styled headers and sections
- Better formatting for QA checklists

The Jira line in this message must still point to the original dev/source ticket via `ticket_id` and `jira_url`.

**Command format:**

```bash
lark-cli im +messages-send \
  --as bot \
  --chat-id "<chat_id>" \
  --msg-type post \
  --content '<json_content>'
```

**Message JSON structure:**

```json
{
  "zh_cn": {
    "title": "QA Endorsement Request",
    "content": [
      [
        { "tag": "text", "text": "Mentions: " },
        { "tag": "at", "user_id": "<author_id>" },
        { "tag": "text", "text": " " },
        { "tag": "at", "user_id": "<andi_id>" },
        { "tag": "text", "text": " " },
        { "tag": "at", "user_id": "<ux_id>" }
      ],
      [{ "tag": "text", "text": "" }],
      [{ "tag": "text", "text": "📋 Context", "style": ["bold"] }],
      [{ "tag": "text", "text": "• Repo: <repo_name>" }],
      [
        { "tag": "text", "text": "• Branch: " },
        { "tag": "a", "text": "<current_branch>", "href": "<mr_url>" }
      ],
      [
        { "tag": "text", "text": "• Jira: " },
        { "tag": "a", "text": "<ticket_id>", "href": "<jira_url>" }
      ],
      [{ "tag": "text", "text": "• Testing Scope: <New Feature|Regression>" }],
      [{ "tag": "text", "text": "• UX Review: <yes|no|uncertain_not_tagged>" }],
      [{ "tag": "text", "text": "" }],
      [{ "tag": "text", "text": "📱 Review Apps", "style": ["bold"] }],
      [
        { "tag": "text", "text": "• URL 1: " },
        { "tag": "a", "text": "Open Review App", "href": "<url_1>" }
      ],
      [
        { "tag": "text", "text": "• URL 2: " },
        { "tag": "a", "text": "Open Review App", "href": "<url_2>" }
      ],
      [{ "tag": "text", "text": "" }],
      [{ "tag": "text", "text": "📝 Change Overview", "style": ["bold"] }],
      [{ "tag": "text", "text": "• <bullet_1>" }],
      [{ "tag": "text", "text": "• <bullet_2>" }],
      [{ "tag": "text", "text": "" }],
      [{ "tag": "text", "text": "✅ QA Checklist", "style": ["bold"] }],
      [{ "tag": "text", "text": "• <step_1>" }],
      [{ "tag": "text", "text": "• <step_2>" }]
    ]
  }
}
```

**Key formatting rules:**

- Use `"style": ["bold"]` for section headers
- Use `"tag": "a"` with `"href"` for clickable links
- Use `"tag": "at"` with `"user_id"` for mentions
- Each line is a separate array element
- Empty lines use `[{"tag": "text", "text": ""}]`
- The `content` array contains arrays of text elements (each inner array = one line)

**Review Apps section behavior:**

- **No URLs provided** (`review_app_urls` is empty): Show single line "• Review App: Not provided"
- **Single URL provided**: Show "• URL 1: [Open Review App](url)"
- **Multiple URLs provided**: Show numbered list "• URL N: [Open Review App](url)" for each URL

**UX Review line:**

- `yes` if UX was tagged
- `no` if no UX changes
- `uncertain_not_tagged` if confidence < 0.60

### 7. Create the QA Jira Ticket

After the Lark message is sent successfully, create the QA Jira ticket for Andi.

If you need to confirm the accepted JSON shape in your environment, check `acli jira workitem create --generate-json` before creating the QA ticket.

Build the JSON payload without a `description` field so the QA ticket stays empty:

```bash
create_payload_file=$(mktemp)

jq -n \
  --arg projectKey "OTP" \
  --arg summary "$qa_summary" \
  --arg type "QA subtask" \
  --arg assignee "andi.awwaal@glints.com" \
  --arg reporter "andi.awwaal@glints.com" \
  --arg parentIssueId "$qa_parent_issue_id" \
  '{
    projectKey: $projectKey,
    summary: $summary,
    type: $type,
    assignee: $assignee,
    reporter: $reporter,
    parentIssueId: $parentIssueId
  }' >"$create_payload_file"

qa_create_output=$(acli jira workitem create --from-json "$create_payload_file")
rm -f "$create_payload_file"
qa_ticket_id=$(printf '%s' "$qa_create_output" | grep -oE 'OTP-[0-9]+' | head -1)
qa_ticket_url="${JIRA_BASE_URL:-https://glints.atlassian.net/browse}/$qa_ticket_id"

acli jira workitem transition --key "$qa_ticket_id" --status "To Do" --yes
```

If `acli` rejects one of the JSON keys, re-run `acli jira workitem create --generate-json` and match the current template instead of guessing.

### 8. Recall Incorrect Messages (Optional)

If a message was sent with incorrect formatting, recall it before sending the corrected version:

```bash
lark-cli im messages delete \
  --as bot \
  --params '{"message_id": "<message_id_to_recall>"}'
```

### 9. Return Result

```json
{
  "chat": "otp-endorsement",
  "chat_id": "oc_xxx",
  "author_open_id": "ou_xxx",
  "base_branch": "origin/main",
  "repo_name": "example-repo",
  "current_branch": "feature/ABC-123",
  "mr_url": "https://gitlab.example.com/group/project/-/merge_requests/123",
  "ticket_id": "ABC-123",
  "qa_parent_ticket_id": "ABC-100",
  "qa_ticket_id": "ABC-124",
  "qa_ticket_url": "https://glints.atlassian.net/browse/ABC-124",
  "testing_scope": "new_feature",
  "review_app_urls": ["https://review.example.com"],
  "ux_tagged": true,
  "message_id": "om_xxx"
}
```

## Errors

| Error                    | Resolution                                                                |
| ------------------------ | ------------------------------------------------------------------------- |
| Not a git repo           | Run from a git repository                                                 |
| glab not found           | Install: `brew install glab` or see <https://glab.readthedocs.io/>        |
| glab auth failed         | Run `glab auth login`                                                     |
| MR not found             | Create an MR for the current branch                                       |
| Source Jira not found    | Ensure the branch or recent commits contain the original Jira key         |
| `acli` auth failed       | Run `acli jira auth status` and authenticate against `glints.atlassian.net` |
| Author not found in Lark | Check git config email matches Lark profile; try searching by email       |
| Contact lookup fails     | Verify names/emails are correct; check lark-cli auth                      |
| `SCOPE_ERROR`            | Bot needs `im:message:send_as_bot` scope in Lark Developer Console        |
| Bot not in channel       | Add bot to `otp-endorsement` chat; bot must be a chat member to send      |
| QA Jira creation failed  | Re-run `acli jira workitem create --generate-json` and match its schema   |
| QA Jira transition failed  | Check the ticket's reachable statuses, then re-run the transition        |
| Recall failed            | Bot may not have permission to recall that message; continue with new msg |
| Invalid URL              | Ensure URLs start with http:// or https://                                |

## Related Skills

- `lark-contact` - Contact lookup (`+search-user` command)
- `lark-im` - Message sending (`+messages-send`, `+chat-search`, `messages delete` commands)
- `iris-jira` - Jira work item creation and transitions via `acli`
