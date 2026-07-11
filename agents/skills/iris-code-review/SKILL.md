---
name: iris-code-review
description: |
  Use this skill when the user asks for a code review, wants to review changes,
  or mentions reviewing code, diffs, commits, merge requests, or pull requests.
  Triggers on phrases like "review this code", "code review", "review my changes",
  "review this PR/MR", or when given commit hashes, branch names, or MR/PR references.
args: |
  [commit-hash|branch-name|MR-reference] - Optional target to review.
    If omitted, reviews uncommitted changes.
---

# iris-code-review

Teaches agents how to perform thorough code reviews using git and glab (GitLab CLI).

## When to Use

Trigger this skill when the user:

- Asks for a "code review" or "review this code"
- Mentions reviewing "changes", "diffs", or "my work"
- Provides a commit hash, branch name, or MR/PR reference
- Says "review this PR" or "review this MR"

## Input Detection

Determine what to review based on input:

| Input                     | Action                                                                        |
| ------------------------- | ----------------------------------------------------------------------------- |
| No arguments              | Review uncommitted changes (`git diff`, `git diff --cached`, untracked files) |
| 40-char SHA or short hash | Review that specific commit (`git show <hash>`)                               |
| Branch name               | Compare current branch to specified branch (`git diff <branch>...HEAD`)       |
| MR/PR URL or number       | Review the merge request (`glab mr view`, `glab mr diff`)                     |

## Review Workflow

### Step 1: Gather the Diff

Run the appropriate git/glab command based on input type to get changes.

### Step 2: Read Full Context

**Critical:** Diffs alone are insufficient. After identifying changed files:

- Read the complete file(s) being modified
- Understand existing patterns, control flow, and error handling
- Check for style guides (CONVENTIONS.md, AGENTS.md, .editorconfig)

### Step 3: Analyze

Review for:

**Bugs (Primary Focus):**

- Logic errors, off-by-one mistakes, incorrect conditionals
- Missing guards, incorrect branching, unreachable code
- Edge cases: null/empty inputs, error conditions, race conditions
- Security: injection risks, auth bypass, data exposure
- Broken error handling that swallows failures or throws unexpectedly

**Structure:**

- Follows existing codebase patterns and conventions
- Uses established abstractions appropriately
- Excessive nesting (consider early returns or extraction)

**Performance (Flag if Obvious):**

- O(n²) on unbounded data, N+1 queries, blocking I/O on hot paths

**Behavior Changes:**

- Flag unintentional behavioral changes
- Note when behavior intentionally changes

## Output Guidelines

1. **Be direct and clear** about bugs - explain why it's a bug
2. **Communicate severity clearly** - don't overstate
3. **Specify triggering conditions** - what inputs/scenarios cause the bug
4. **Matter-of-fact tone** - helpful without being accusatory or flattering
5. **Be certain** - only flag actual bugs in the changes, not pre-existing code
6. **No hypotheticals** - explain realistic scenarios where issues manifest

### What NOT to Flag

- Style preferences (unless violating established project conventions)
- Pre-existing code that wasn't modified
- Uncertain issues (say "I'm not sure about X" instead)
- Theoretical edge cases without realistic scenarios

## Verification Tools

Before claiming something doesn't fit:

- Use the explore agent to find how existing code handles similar problems
- Check patterns and conventions in the codebase
- Research best practices if unsure about a pattern

## Error Handling

The skill uses standard iris exit codes:

- `0` - Success, review completed
- `1` - Usage error (invalid input format)
- `2` - Runtime error (git/glab command failed)
- `3` - Auth error (glab authentication required)

## Dependencies

Requires on PATH:

- `git` - For local diff operations
- `glab` - For GitLab merge request reviews
