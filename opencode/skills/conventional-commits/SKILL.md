---
name: conventional-commits
description: Craft conventional commit messages and handle pre-commit hooks safely. Trigger on `/commit`, `git commit`, when the user asks to commit changes, or when a pre-commit hook fails and the user needs help recovering. Handles autofix hooks, Dangerfile prefix rules, commitlint configs, and hook failures gracefully.
---

# Conventional Commits

This skill handles the full commit lifecycle: analyzing changes, crafting a compliant commit message, running pre-commit hooks, and recovering from failures.

## Step 1: Discover project conventions

Before committing, discover the project's commit rules. Run in parallel:

```bash
ls .commitlintrc* commitlint.config.* .dangerfile* Dangerfile* 2>/dev/null
ls .husky/commit-msg .husky/pre-commit .githooks/ 2>/dev/null
git config --local core.hooksPath 2>/dev/null
```

Also search for commit-lint related configs in `package.json` (`commitlint` key), `.lefthook.yml`, or `dangerfile.js`/`dangerfile.ts`.

### Interpreting what you find

- **commitlint config** (`extends`, `rules`, `header-max-length`, `type-enum`, `scope-enum`, etc.): These define which types/scopes are allowed and format rules. Read the config to know the exact allowed values.
- **Dangerfile**: Check for message pattern checks (e.g., `danger.git.commits`, regex patterns on commit messages). The Dangerfile may enforce prefixes like `[PROJ-123]` or specific type formats.
- **commit-msg hook**: Validates the commit message. If it exists, your message MUST pass it.
- **pre-commit hook**: Runs before committing. May auto-fix files. Always check its result.

## Step 2: Stage and analyze changes

```bash
git add -A
git diff --cached --stat
git diff --cached --name-only
```

Use `git diff --cached` if needed to understand the full nature of changes.

## Step 3: Craft the commit message

Follow the project's rules above all else. Fall back to Conventional Commits 1.0.0:

```
type(scope): description

body (optional)

footer (optional)
```

**Standard types** (if no project-specific enum): `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`, `build`, `revert`

**Rules for the description**:
- Start with lowercase, no trailing period
- Keep under the project's `header-max-length` (default 72)
- Use imperative mood ("add" not "added" or "adds")
- Be concise but descriptive

**For multi-file changes**: Determine the primary nature (feat, fix, refactor, etc.) and scope from the affected modules. If changes span unrelated areas, split into multiple commits.

## Step 4: Commit with live hook monitoring

Use this command pattern so you can see hook output:

```bash
git commit -m "$MSG" 2>&1
```

After `git commit`, inspect the output CAREFULLY:

### Pre-commit hook SUCCEEDED (exit 0)
- **If files were modified by autofix**: The commit proceeds but the autofix changes were NOT committed. You MUST:
  1. `git add -A` to stage the autofix changes
  2. `git commit --amend --no-edit` to include them in the same commit
  3. Run `git status` to verify clean

- **If nothing was modified**: Commit is done. Run `git status` to verify.

### Pre-commit hook FAILED (exit non-zero)
- Read the hook's stderr/stdout to understand WHY it failed
- **Common causes**:
  - Lint errors that can't be auto-fixed → Tell the user what failed and where
  - Tests failed → Report which tests failed
  - Missing required files or configs → Diagnose and suggest fixes
- **Recovery**:
  - Fix the reported issues
  - `git add -A` the fixes
  - Retry the commit: `git commit -m "$MSG" 2>&1`

### commit-msg hook FAILED
- The hook rejected the message format. Read the error to understand what violated.
- Adjust the message to comply and retry.

### No hooks or hooks don't exist
- Commit proceeds normally. Verify with `git status`.

## Step 5: Verify

Always run `git log -1 --oneline` after a successful commit to confirm the message looks right.

## Commit message examples

```
feat(auth): add JWT refresh token rotation
```

```
fix(db): resolve race condition in connection pool

The pool could return closed connections under high concurrency.
Added a mutex guard around the borrow path.

Closes #456
```

```
chore(deps): bump express from 4.18.2 to 4.19.2
```

## Multiple commit strategy

If changes span very different concerns (e.g., a bug fix + a new feature), use interactive staging:
```bash
git add -p          # stage only what belongs to commit 1
git commit -m "..." # commit 1
git add -A          # stage commit 2
git commit -m "..." # commit 2
```

## Edge cases

- **Amend after autofix**: If pre-commit autofix changes files, ALWAYS `git add -A && git commit --amend --no-edit`. The autofix changes are NOT in the commit otherwise.
- **Empty commit**: If `git diff --cached` is empty after staging, there's nothing to commit. Warn the user.
- **Secrets detection**: If the hook or Dangerfile flags secrets, DO NOT bypass. Warn the user explicitly.
- **Broken hooks**: If hooks hang or crash, you can skip with `--no-verify` but ALWAYS warn the user first and ask if they want to skip.
- **Merge conflicts during amend**: If `git commit --amend` fails with merge conflicts, the autofix conflicted with staged changes. This is rare but requires the user's attention — report the conflicted files.
