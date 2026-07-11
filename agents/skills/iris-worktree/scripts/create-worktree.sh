#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: create-worktree.sh <branch-or-ticket> [options]

Create a git worktree from the current repository, optionally copying local-only
files and running a setup command in the new worktree.

Options:
  --base <branch>                     Base branch for new branches.
  --path <path>                       Worktree path. Overrides path template.
  --path-template <template>          Default: .worktrees/{branch_slug}.
  --copy <path>                       Path to copy from source checkout. Repeatable.
  --install-command <command>         Command to run in the new worktree.
  --config <path>                     JSON config. Default: .iris/worktree.json if present.
  -h, --help                          Show this help.

Template variables: {repo}, {branch}, {branch_slug}, {ticket}, {ticket_lower}.
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's#[^a-z0-9._-]+#-#g; s#^-+##; s#-+$##'
}

render_template() {
  local out="$1"
  out="${out//\{repo\}/$REPO_NAME}"
  out="${out//\{branch\}/$BRANCH}"
  out="${out//\{branch_slug\}/$BRANCH_SLUG}"
  out="${out//\{ticket\}/$TICKET}"
  out="${out//\{ticket_lower\}/$TICKET_LOWER}"
  printf '%s' "$out"
}

BRANCH_INPUT=""
BASE=""
WT_PATH=""
DEFAULT_PATH_TEMPLATE=".worktrees/{branch_slug}"
PATH_TEMPLATE="$DEFAULT_PATH_TEMPLATE"
INSTALL_COMMAND=""
TICKET_BRANCH_TEMPLATE=""
CONFIG_FILE=""
CLI_COPIES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --base) BASE="${2:?--base needs a value}"; shift 2 ;;
    --path) WT_PATH="${2:?--path needs a value}"; shift 2 ;;
    --path-template) PATH_TEMPLATE="${2:?--path-template needs a value}"; shift 2 ;;
    --copy) CLI_COPIES+=("${2:?--copy needs a value}"); shift 2 ;;
    --install-command) INSTALL_COMMAND="${2:?--install-command needs a value}"; shift 2 ;;
    --config) CONFIG_FILE="${2:?--config needs a value}"; shift 2 ;;
    --) shift; break ;;
    -*) die "unknown option: $1" ;;
    *)
      if [[ -z "$BRANCH_INPUT" ]]; then
        BRANCH_INPUT="$1"
        shift
      else
        die "unexpected positional argument: $1"
      fi
      ;;
  esac
done

[[ -n "$BRANCH_INPUT" ]] || { usage >&2; exit 2; }

git rev-parse --show-toplevel >/dev/null 2>&1 || die "not inside a git repository"
REPO_ROOT="$(git rev-parse --show-toplevel)"
REPO_NAME="$(basename "$REPO_ROOT")"

CONFIG_COPIES=()
if [[ -z "$CONFIG_FILE" && -f "$REPO_ROOT/.iris/worktree.json" ]]; then
  CONFIG_FILE="$REPO_ROOT/.iris/worktree.json"
fi

if [[ -n "$CONFIG_FILE" ]]; then
  [[ -f "$CONFIG_FILE" ]] || die "config file not found: $CONFIG_FILE"
  command -v jq >/dev/null 2>&1 || die "jq is required to read JSON config: $CONFIG_FILE"
  jq empty "$CONFIG_FILE" >/dev/null || die "invalid JSON config: $CONFIG_FILE"

  config_base="$(jq -r '.base // empty' "$CONFIG_FILE")"
  config_path_template="$(jq -r '.path_template // empty' "$CONFIG_FILE")"
  config_install="$(jq -r '.install_command // empty' "$CONFIG_FILE")"
  config_ticket_template="$(jq -r '.ticket_branch_template // empty' "$CONFIG_FILE")"

  [[ -n "$BASE" || -z "$config_base" ]] || BASE="$config_base"
  [[ "$PATH_TEMPLATE" != "$DEFAULT_PATH_TEMPLATE" || -z "$config_path_template" ]] || PATH_TEMPLATE="$config_path_template"
  [[ -n "$INSTALL_COMMAND" || -z "$config_install" ]] || INSTALL_COMMAND="$config_install"
  [[ -n "$TICKET_BRANCH_TEMPLATE" || -z "$config_ticket_template" ]] || TICKET_BRANCH_TEMPLATE="$config_ticket_template"

  while IFS= read -r p; do
    [[ -z "$p" ]] && continue
    CONFIG_COPIES+=("$p")
  done < <(jq -r '.copy[]?' "$CONFIG_FILE")
fi

if [[ -z "$BASE" ]]; then
  if git symbolic-ref refs/remotes/origin/HEAD --short >/dev/null 2>&1; then
    BASE="$(git symbolic-ref refs/remotes/origin/HEAD --short)"
    BASE="${BASE#origin/}"
  else
    BASE="main"
  fi
fi

TICKET=""
TICKET_LOWER=""
BRANCH="$BRANCH_INPUT"
if [[ "$BRANCH_INPUT" =~ ^[A-Za-z]+-[0-9]+$ && -n "$TICKET_BRANCH_TEMPLATE" ]]; then
  TICKET="$BRANCH_INPUT"
  TICKET_LOWER="$(printf '%s' "$TICKET" | tr '[:upper:]' '[:lower:]')"
  BRANCH_SLUG="$(slugify "$BRANCH_INPUT")"
  BRANCH="$(render_template "$TICKET_BRANCH_TEMPLATE")"
fi

BRANCH_SLUG="$(slugify "$BRANCH")"
if [[ -z "$WT_PATH" ]]; then
  WT_PATH="$(render_template "$PATH_TEMPLATE")"
fi

case "$WT_PATH" in
  /*) WT_PATH_ABS="$WT_PATH" ;;
  *)
    WT_PARENT="$(dirname "$WT_PATH")"
    WT_BASENAME="$(basename "$WT_PATH")"
    if [[ -d "$REPO_ROOT/$WT_PARENT" ]]; then
      WT_PATH_ABS="$(cd "$REPO_ROOT/$WT_PARENT" && pwd)/$WT_BASENAME"
    else
      WT_PATH_ABS="$REPO_ROOT/$WT_PATH"
    fi
    ;;
esac

ALL_COPIES=("${CONFIG_COPIES[@]+"${CONFIG_COPIES[@]}"}" "${CLI_COPIES[@]+"${CLI_COPIES[@]}"}")

cat <<EOF
Worktree plan:
  repo:    $REPO_ROOT
  branch:  $BRANCH
  base:    $BASE
  path:    $WT_PATH_ABS
  config:  ${CONFIG_FILE:-none}
EOF

if [[ ${#ALL_COPIES[@]} -gt 0 ]]; then
  printf '  copy:\n'
  for item in "${ALL_COPIES[@]}"; do
    printf '    - %s\n' "$item"
  done
else
  printf '  copy:    none\n'
fi
printf '  install: %s\n' "${INSTALL_COMMAND:-none}"

[[ ! -e "$WT_PATH_ABS" ]] || die "$WT_PATH_ABS already exists"

cd "$REPO_ROOT"
HAS_ORIGIN=0
if git remote get-url origin >/dev/null 2>&1; then
  HAS_ORIGIN=1
fi

if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git worktree add "$WT_PATH_ABS" "$BRANCH"
elif [[ "$HAS_ORIGIN" -eq 1 ]] && git ls-remote --exit-code --heads origin "$BRANCH" >/dev/null 2>&1; then
  git fetch origin "$BRANCH"
  git worktree add -B "$BRANCH" "$WT_PATH_ABS" "origin/$BRANCH"
else
  if [[ "$HAS_ORIGIN" -eq 1 ]]; then
    git fetch origin "$BASE" || true
  fi
  BASE_REF="$BASE"
  if git rev-parse --verify --quiet "origin/$BASE" >/dev/null; then
    BASE_REF="origin/$BASE"
  fi
  git worktree add -b "$BRANCH" "$WT_PATH_ABS" "$BASE_REF"
fi

if [[ ${#ALL_COPIES[@]} -gt 0 ]]; then
  printf 'Copying local files:\n'
  for item in "${ALL_COPIES[@]}"; do
    src="$REPO_ROOT/$item"
    dst="$WT_PATH_ABS/$item"
    if [[ ! -e "$src" ]]; then
      printf '  skip %s (not present)\n' "$item"
      continue
    fi
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
    printf '  copy %s\n' "$item"
  done
fi

if [[ -n "$INSTALL_COMMAND" ]]; then
  printf 'Running install command in %s:\n  %s\n' "$WT_PATH_ABS" "$INSTALL_COMMAND"
  (cd "$WT_PATH_ABS" && bash -lc "$INSTALL_COMMAND")
fi

cat <<EOF

Worktree ready:
  path:   $WT_PATH_ABS
  branch: $BRANCH
EOF
