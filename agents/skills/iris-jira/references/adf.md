# ADF (Atlassian Document Format), rich descriptions & Markdown export

`acli` accepts plain text for descriptions via `--description`, but anything with
structure — headings, lists, links, code blocks — has to go in as **ADF**, the JSON
document model Jira stores rich text in. This file covers writing ADF into a ticket and
pulling it back out as Markdown.

## Contents

- [Creating a ticket with a rich (ADF) description](#creating-a-ticket-with-a-rich-adf-description)
- [The parent-epic + rich-description two-step](#the-parent-epic--rich-description-two-step)
- [Editing a description with ADF](#editing-a-description-with-adf)
- [ADF cheat sheet](#adf-cheat-sheet)
- [Exporting a ticket as Markdown (`adf2md.py`)](#exporting-a-ticket-as-markdown-adf2mdpy)

## Creating a ticket with a rich (ADF) description

Pass `--from-json <file>` instead of `--summary/--type/...`:

```bash
acli jira workitem create --from-json "workitem.json"
```

`workitem.json`:

```json
{
  "assignee": "@me",
  "projectKey": "OTP",
  "summary": "Task title",
  "type": "Developer Task",
  "description": {
    "type": "doc",
    "version": 1,
    "content": [
      {
        "type": "paragraph",
        "content": [{ "type": "text", "text": "Description text here" }]
      }
    ]
  }
}
```

Leave these out of the JSON — `acli` rejects them:

- `additionalAttributes` — not supported
- `labels` — and don't create labels unless the user explicitly asks
- `parent` — not supported in `--from-json` (use the two-step below)

## The parent-epic + rich-description two-step

`--from-json` can't set `parent`, and `create --parent` can't take a rich description —
so do it in two calls:

1. Create with the parent epic (plain summary is fine here):

   ```bash
   acli jira workitem create --summary "Task summary" --project "OTP" \
     --type "Developer Task" --assignee "@me" --parent "OTP-1816"
   # Returns: Work item OTP-XXXX created
   ```

2. Replace the description with `edit --from-json`, passing the new key in an `issues`
   array:

   ```bash
   acli jira workitem edit --from-json "edit-description.json" --yes
   ```

   `edit-description.json`:

   ```json
   {
     "issues": ["OTP-XXXX"],
     "description": {
       "type": "doc",
       "version": 1,
       "content": [
         {
           "type": "heading",
           "attrs": { "level": 3 },
           "content": [{ "type": "text", "text": "Section heading" }]
         },
         {
           "type": "paragraph",
           "content": [{ "type": "text", "text": "Rich description here" }]
         }
       ]
     }
   }
   ```

`--yes` skips the confirmation prompt — needed for non-interactive use.

## Editing a description with ADF

Same shape as step 2 above. Note: `--description-file` does **not** work for editing
descriptions (it returns `INVALID_INPUT`); always use `--from-json` with the `issues`
array for ADF edits.

```bash
acli jira workitem edit --from-json "edit-description.json" --yes
# edit-description.json: { "issues": ["OTP-123"], "description": { ...ADF doc... } }
```

## ADF cheat sheet

A minimal document with a paragraph (mixing plain, bold, and italic runs) and a bullet
list:

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "paragraph",
      "content": [
        { "type": "text", "text": "Normal text" },
        { "type": "text", "text": "Bold text", "marks": [{ "type": "strong" }] },
        { "type": "text", "text": "Italic text", "marks": [{ "type": "em" }] }
      ]
    },
    {
      "type": "bulletList",
      "content": [
        {
          "type": "listItem",
          "content": [
            { "type": "paragraph", "content": [{ "type": "text", "text": "List item 1" }] }
          ]
        },
        {
          "type": "listItem",
          "content": [
            { "type": "paragraph", "content": [{ "type": "text", "text": "List item 2" }] }
          ]
        }
      ]
    }
  ]
}
```

Common building blocks:

| Want                | Node / mark                                                              |
| ------------------- | ------------------------------------------------------------------------ |
| Heading             | `{ "type": "heading", "attrs": { "level": 1-6 }, "content": [text] }`     |
| Paragraph           | `{ "type": "paragraph", "content": [text...] }`                          |
| Bold / italic / code| `marks: [{ "type": "strong" }]` / `{ "type": "em" }` / `{ "type": "code" }` |
| Link                | `marks: [{ "type": "link", "attrs": { "href": "https://..." } }]`        |
| Bullet list         | `{ "type": "bulletList", "content": [listItem...] }`                     |
| Numbered list       | `{ "type": "orderedList", "content": [listItem...] }`                    |
| Code block          | `{ "type": "codeBlock", "attrs": { "language": "go" }, "content": [text] }` |
| Divider             | `{ "type": "rule" }`                                                     |

Full schema: <https://developer.atlassian.com/cloud/jira/platform/apis/document/structure/>.

## Exporting a ticket as Markdown (`adf2md.py`)

`acli jira workitem view OTP-123` flattens the description — headings, bullet lists,
bold, and link URLs are all stripped. When you want the structure preserved (e.g. to
drop into a spec file or a Lark doc), render the ADF yourself with the bundled
`scripts/adf2md.py` helper. It reads `acli`'s `--json` output on stdin and writes
`fields.description` as Markdown to stdout:

```bash
acli jira workitem view OTP-2733 --fields "*all" --json \
  | python3 scripts/adf2md.py \
  > OTP-2733.md
```

To prepend a header (key, summary, type, status, assignee, URL) above the body, capture
the JSON once and feed it to both `jq` and the helper:

```bash
TMP=$(mktemp)
acli jira workitem view OTP-2733 --fields "*all" --json > "$TMP"

{
  jq -r '"# \(.key) — \(.fields.summary)\n\n- **Type**: \(.fields.issuetype.name)\n- **Status**: \(.fields.status.name)\n- **Assignee**: \(.fields.assignee.emailAddress // .fields.assignee.displayName // "unassigned")\n- **URL**: https://glints.atlassian.net/browse/\(.key)\n\n---\n"' "$TMP"
  python3 scripts/adf2md.py < "$TMP"
} > OTP-2733.md
```

The helper renders headings, paragraphs, bullet/ordered lists (with nesting),
bold/italic/code/strike/link marks, hard breaks, inline cards, mentions, code blocks,
block quotes, panels, rules, and simple tables. Media nodes become `_[media]_`. It only
touches `fields.description` — the header is your job, hence the `jq` line above.
