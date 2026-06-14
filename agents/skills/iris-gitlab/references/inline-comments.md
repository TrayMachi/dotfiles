# Inline MR Comments (Diff Notes)

Post code review comments on specific lines of a GitLab merge request diff.

## Use `glab api --input`, not `--raw-field`

`glab api --raw-field` flattens nested objects into form keys (`position[base_sha]=...`),
which GitLab silently ignores — the comment falls back to a general discussion with
`position: null`. Use `--input <file>` (or `--input -` for stdin) to send a raw JSON
body so the nested `position` object is preserved.

## Step 1: Get the MR diff refs

```bash
glab api projects/<encoded-path>/merge_requests/<mr-number> \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d['diff_refs'], indent=2))"
```

This returns three SHAs:

- `base_sha` — merge base between source and target
- `start_sha` — target branch HEAD
- `head_sha` — source branch HEAD

**Example output:**

```json
{
  "base_sha": "715fcb21f82d2c49d96e7fd6662f886d5a61e778",
  "head_sha": "490772c15b962dc4d58dab887d0b60127aacdc3b",
  "start_sha": "dfdf3517441f5a868e7e0633651e6abc5c10a398"
}
```

## Step 2: Find the correct line number

The `new_line` must be the line number **in the new version of the file on the source branch**,
and that line must appear in the diff (added or context line). For removed lines, use `old_line` instead.

```bash
# Check the file on the source branch to find the exact line number
git show origin/<source-branch>:<file-path> | grep -n "<search-term>"
```

## Step 3: Write the JSON body to a temp file

```bash
cat <<'PAYLOAD' > /tmp/mr_comment.json
{
  "body": "Your comment text here (supports **markdown**)",
  "position": {
    "position_type": "text",
    "base_sha": "<base_sha from diff_refs>",
    "start_sha": "<start_sha from diff_refs>",
    "head_sha": "<head_sha from diff_refs>",
    "old_path": "<file path>",
    "new_path": "<file path>",
    "new_line": <line-number>
  }
}
PAYLOAD
```

**Position field rules:**

- `new_line` — for added lines or unchanged context lines in the new file
- `old_line` — for removed lines (set `new_line` to null or omit it)
- Both `old_path` and `new_path` are required (same value unless the file was renamed)

## Step 4: Post with `glab api --input`

```bash
glab api \
  --method POST \
  --header "Content-Type: application/json" \
  --input /tmp/mr_comment.json \
  projects/<encoded-path>/merge_requests/<mr-number>/discussions
```

`glab` injects the auth token automatically — no need to extract `GITLAB_TOKEN` or call `curl`.

## Step 5: Verify the comment type

The response should have `"type": "DiffNote"` (not `"DiscussionNote"`). If `position` is `null`
in the response, the line number didn't match the diff — check your SHAs and line numbers.

## Multi-line comments

To highlight a range of lines, add `line_range` to the position:

```json
{
  "position": {
    "position_type": "text",
    "base_sha": "...",
    "start_sha": "...",
    "head_sha": "...",
    "old_path": "path/to/file.go",
    "new_path": "path/to/file.go",
    "new_line": 195,
    "line_range": {
      "start": { "type": "new", "new_line": 188 },
      "end": { "type": "new", "new_line": 195 }
    }
  }
}
```

## Common mistakes

| Mistake                                          | Result                                                   | Fix                                                                 |
| ------------------------------------------------ | -------------------------------------------------------- | ------------------------------------------------------------------- |
| Using `glab api --raw-field 'position[key]=val'` | Position is `null`, comment is general discussion        | Use `glab api --input <file>` (see "Use `--input`" above)           |
| Using `start_sha` as `base_sha`                  | Position doesn't match, falls back to general discussion | Use `diff_refs.base_sha` — it's the merge base, not the target HEAD |
| `new_line` points to a line not in the diff      | Position rejected                                        | Verify line appears in `git diff` output                            |
