#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="mcc-choices"
HOST_SUFFIX=".mcc-choices.localhost"
BASE_BRANCH="${WORKSPACE_BASE_BRANCH:-master}"
TRACK_REMOTE=0
PORT_START=3000
PORT_END=3999
SERVER_WAIT_SECONDS=60
CATALOG_PATH="data/available_choices.json"
CATALOG_NAME="NEET PG Medical Counselling 2026"
CATALOG_SLUG="neet-pg-2026"
DEV_ADMIN_EMAIL="${WORKSPACE_ADMIN_EMAIL:-hey@fazzle.dev}"

die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
info() { printf '==> %s\n' "$*"; }

usage() {
  cat <<'EOF'
Usage:
  bin/workspace.sh <slug>            Create a workspace, set it up, launch it
  bin/workspace.sh --track <slug>    Check out an existing remote branch (e.g. a PR)
  bin/workspace.sh destroy [--force] <slug>
                                     Tear down a workspace created by this script;
                                     refuses uncommitted changes unless --force
  bin/workspace.sh -h, --help        Show this help

<slug>: letters, digits, dashes, underscores, and / (for prefixed branches).
        Must not start with `-`, end with `/`, or contain `//` or `.`.

Each workspace is a sibling worktree <main>--<slug> on branch <slug>, with its
own SQLite files, the catalog imported, an admin user, and the server running
in tmux session mcc-choices--<slug> at http://<slug>.mcc-choices.localhost:<port>.

Sign-in links in development are written to tmp/mails/<email> in the workspace.

Environment overrides:
  WORKSPACE_BASE_BRANCH   Branch the new workspace is based on. Default: master.
  WORKSPACE_ADMIN_EMAIL   Admin user created in the workspace. Default: hey@fazzle.dev.
EOF
}

validate_slug() {
  local slug=$1
  [[ -n "$slug" ]] || die "slug is required"
  [[ "$slug" != -* ]]    || die "slug must not start with '-' (got: $slug)"
  [[ "$slug" != */ ]]    || die "slug must not end with '/' (got: $slug)"
  [[ "$slug" != *//* ]]  || die "slug must not contain '//' (got: $slug)"
  [[ "$slug" != *.* ]]   || die "slug must not contain '.' (got: $slug)"
  printf '%s' "$slug" | LC_ALL=C grep -Eq '^[A-Za-z0-9_-]+(/[A-Za-z0-9_-]+)*$' || \
    die "slug must match [A-Za-z0-9_/-]+ per segment (ASCII only; got: $slug)"
  [[ "$slug" != "main" && "$slug" != "master" ]] || die "refusing to use slug '$slug'"
  case "$slug" in
    HEAD|FETCH_HEAD|ORIG_HEAD|MERGE_HEAD|CHERRY_PICK_HEAD) die "refusing to use git-magic ref name '$slug'" ;;
    refs/*) die "slug must not start with 'refs/' (got: $slug)" ;;
  esac
}

path_slug_of() {
  local s=${1//\//-}
  printf '%s\n' "${s,,}"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

resolve_main_worktree() {
  local out
  out=$(git worktree list --porcelain 2>/dev/null | awk -v base="$BASE_BRANCH" '
    /^worktree / { w = substr($0, 10) }
    $0 == "branch refs/heads/" base { print w; exit }
  ')
  if [[ -z "$out" || ! -d "$out" ]]; then
    die "could not find '$BASE_BRANCH' checked out in any worktree.
Check out $BASE_BRANCH in your primary tree before running bin/workspace.sh:
  git -C <main-tree> checkout $BASE_BRANCH"
  fi
  printf '%s\n' "$out"
}

pick_free_port() {
  local start=$1 end=$2 port listening
  listening=$(ss -tlnH 2>/dev/null | awk '{print $4}' | sed 's/.*://') || true
  for (( port = start; port <= end; port++ )); do
    if ! grep -qxF "$port" <<<"$listening"; then
      printf '%s\n' "$port"
      return 0
    fi
  done
  die "no free port available in range $start-$end"
}

wait_for_server() {
  local primary=$1 fallback=$2 timeout=$3 i url code
  for (( i = 0; i < timeout; i++ )); do
    for url in "$primary" "$fallback"; do
      code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 1 --max-time 2 "$url" 2>/dev/null) || code='000'
      if [[ "$code" != "000" && "$code" != "502" && "$code" != "503" ]]; then
        return 0
      fi
    done
    sleep 1
  done
  return 1
}

_WT_CLEANUP_SLUG=""

_cleanup_on_failure() {
  local ec=$?
  trap '' ERR INT TERM HUP
  set +e
  if [[ -n "$_WT_CLEANUP_SLUG" ]]; then
    local slug_snapshot="$_WT_CLEANUP_SLUG"
    _WT_CLEANUP_SLUG=""
    printf '\n' >&2
    warn "setup interrupted (exit $ec); auto-destroying partial state for '$slug_snapshot'..."
    warn "(cleanup running; further interrupts ignored. Use 'kill -9' if truly stuck.)"
    cmd_destroy "$slug_snapshot" force 2>&1 | sed 's/^/  [cleanup] /' || \
      warn "auto-destroy also failed; manual cleanup may be needed"
  fi
  exit "$ec"
}

cmd_create() {
  local slug=$1
  validate_slug "$slug"

  require_cmd git
  require_cmd tmux
  require_cmd curl
  require_cmd ss

  local main_tree new_tree branch session host_domain path_slug
  path_slug=$(path_slug_of "$slug")
  main_tree=$(resolve_main_worktree)
  new_tree="${main_tree%/}--${path_slug}"
  branch="$slug"
  session="${REPO_NAME}--${path_slug}"
  host_domain="${path_slug}${HOST_SUFFIX}"

  if [[ -e "$new_tree" ]]; then
    if [[ -e "$new_tree/.git" ]]; then
      local existing_branch
      existing_branch=$(git -C "$new_tree" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "<unknown>")
      if [[ "$existing_branch" == "$branch" ]]; then
        die "path already exists: $new_tree (branch: $existing_branch)
An active workspace is there. To start fresh: bin/workspace.sh destroy $slug"
      else
        die "path already exists: $new_tree (branch: $existing_branch)
This path belongs to a DIFFERENT slug than '$slug' (both collapse to
path-slug '$path_slug'). To destroy the existing workspace:
  bin/workspace.sh destroy $existing_branch
Or pick a slug that doesn't collapse to '$path_slug'."
      fi
    else
      die "path already exists: $new_tree
This looks like a stale orphan (no .git). To remove it: bin/workspace.sh destroy $slug"
    fi
  fi
  if git -C "$main_tree" show-ref --verify --quiet "refs/heads/$branch"; then
    die "branch '$branch' already exists locally.
To reuse it manually: git -C \"$main_tree\" branch -D \"$branch\"
Or pick a different slug."
  fi
  if tmux has-session -t "=${session}" 2>/dev/null; then
    die "tmux session '$session' already exists (unexpected; try: tmux kill-session -t =${session})"
  fi

  local base_ref has_origin=0
  git -C "$main_tree" remote get-url origin >/dev/null 2>&1 && has_origin=1
  if [[ "$TRACK_REMOTE" -eq 1 ]]; then
    [[ "$has_origin" -eq 1 ]] || die "--track needs an 'origin' remote, and this repo has none."
    info "Fetching origin/$branch..."
    GIT_TERMINAL_PROMPT=0 git -C "$main_tree" fetch origin "$branch" --quiet 2>/dev/null || \
      die "could not fetch origin/$branch (offline, creds, or the branch does not exist)."
    git -C "$main_tree" show-ref --verify --quiet "refs/remotes/origin/$branch" || \
      die "remote branch 'origin/$branch' not found after fetch. Check the slug matches the PR branch name."
    base_ref="origin/$branch"
  else
    base_ref="$BASE_BRANCH"
    if [[ "$has_origin" -eq 1 ]]; then
      info "Fetching origin/$BASE_BRANCH..."
      if GIT_TERMINAL_PROMPT=0 git -C "$main_tree" fetch origin "$BASE_BRANCH" --quiet 2>/dev/null; then
        base_ref="origin/$BASE_BRANCH"
        local ahead
        ahead=$(git -C "$main_tree" rev-list --count "origin/$BASE_BRANCH..$BASE_BRANCH" 2>/dev/null || echo 0)
        if [[ "$ahead" -gt 0 ]]; then
          warn "local $BASE_BRANCH is $ahead commit(s) ahead of origin/$BASE_BRANCH"
          warn "new branch will be based on origin/$BASE_BRANCH and will NOT include those commits."
        fi
      else
        warn "could not fetch origin/$BASE_BRANCH (offline, creds, or network); basing on local $BASE_BRANCH."
      fi
      if git -C "$main_tree" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        die "remote branch 'origin/$branch' already exists.
To check out and track it: bin/workspace.sh --track $slug
Or pick a different slug."
      fi
    fi
  fi

  info "main tree:  $main_tree"
  info "new tree:   $new_tree"
  info "branch:     $branch (from $base_ref)"
  info "tmux:       $session"

  _WT_CLEANUP_SLUG="$slug"
  trap _cleanup_on_failure ERR INT TERM HUP

  info "Creating git worktree..."
  if [[ "$TRACK_REMOTE" -eq 1 ]]; then
    git -C "$main_tree" worktree add --track -b "$branch" "$new_tree" "$base_ref"
  else
    git -C "$main_tree" worktree add -b "$branch" "$new_tree" "$base_ref"
  fi

  if [[ -f "$main_tree/.env" ]]; then
    info "Copying .env from main tree..."
    cp "$main_tree/.env" "$new_tree/.env"
  fi
  if [[ -f "$main_tree/config/master.key" ]]; then
    info "Copying config/master.key from main tree..."
    cp "$main_tree/config/master.key" "$new_tree/config/master.key"
  fi
  if [[ -f "$new_tree/mise.toml" ]] && command -v mise >/dev/null 2>&1; then
    info "Trusting mise config..."
    mise trust "$new_tree/mise.toml"
  fi

  info "Checking bundle..."
  ( cd "$new_tree" && ( bundle check >/dev/null 2>&1 || bundle install ) )

  info "Preparing database (db:prepare)..."
  ( cd "$new_tree" && RAILS_ENV=development bin/rails db:prepare )

  info "Importing catalog and creating admin $DEV_ADMIN_EMAIL..."
  ( cd "$new_tree" && RAILS_ENV=development bin/rails \
      "planner:import_catalog[$CATALOG_PATH,$CATALOG_NAME,$CATALOG_SLUG]" \
      "planner:admin[$DEV_ADMIN_EMAIL]" )

  local port url
  port=$(pick_free_port "$PORT_START" "$PORT_END")
  url="http://${host_domain}:${port}"
  info "host:       $url"

  info "Starting tmux session '$session' with bin/dev..."
  local window
  window=$(tmux new-session -d -P -F '#{window_id}' -s "$session" -c "$new_tree")
  tmux send-keys -t "$window" \
    "export PORT=${port} RAILS_DEVELOPMENT_HOSTS='${host_domain}' APP_DEV_HOST='${host_domain}'; ( bin/dev -p ${port} ); ec=\$?; printf '\\n--- bin/dev exited with status %d; press Enter to close ---\\n' \"\$ec\"; read" Enter

  info "Waiting up to ${SERVER_WAIT_SECONDS}s for server..."
  if wait_for_server "$url" "http://127.0.0.1:${port}/" "$SERVER_WAIT_SECONDS"; then
    info "Server is up."
  else
    warn "server did not respond within ${SERVER_WAIT_SECONDS}s."
    warn "check the tmux session for errors: tmux attach -t =${session}"
  fi

  _WT_CLEANUP_SLUG=""
  trap - ERR INT TERM HUP

  cat <<EOF

Workspace ready.

  path:     $new_tree
  branch:   $branch
  url:      $url
  sign-in:  links land in $new_tree/tmp/mails/<email>
  tmux:     tmux attach -t =${session}
  destroy:  bin/workspace.sh destroy ${slug}

EOF
}

cmd_destroy() {
  local slug=$1 force=${2:-}
  validate_slug "$slug"

  require_cmd git

  local main_tree new_tree session path_slug
  path_slug=$(path_slug_of "$slug")
  main_tree=$(resolve_main_worktree)
  new_tree="${main_tree%/}--${path_slug}"
  session="${REPO_NAME}--${path_slug}"

  [[ "$new_tree" != "$main_tree" ]] || die "refusing to destroy the main worktree"

  local actual_branch=""
  if [[ -e "$new_tree/.git" ]]; then
    actual_branch=$(git -C "$new_tree" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [[ -n "$actual_branch" && "${actual_branch,,}" != "${slug,,}" ]]; then
      die "refusing to destroy: workspace at $new_tree tracks branch '$actual_branch', not '$slug'.
If you meant the workspace at that path, run:
  bin/workspace.sh destroy $actual_branch"
    fi
  fi

  if [[ -z "$force" && -e "$new_tree/.git" ]]; then
    local dirty
    dirty=$(git -C "$new_tree" status --porcelain 2>&1) || \
      die "cannot check $new_tree for uncommitted changes; rerun with: bin/workspace.sh destroy --force $slug"
    if [[ -n "$dirty" ]]; then
      die "refusing to destroy: $new_tree has uncommitted changes:
$dirty
Commit or stash them, or run: bin/workspace.sh destroy --force $slug"
    fi
  fi

  info "Target workspace: $new_tree"
  info "Target tmux:      $session"

  if command -v tmux >/dev/null 2>&1 && tmux has-session -t "=${session}" 2>/dev/null; then
    info "Killing tmux session..."
    tmux kill-session -t "=${session}"
    sleep 1
  else
    info "No tmux session '$session' to kill."
  fi

  if [[ -d "$new_tree" ]]; then
    info "Removing workspace..."
    local remove_err
    if ! remove_err=$(git -C "$main_tree" worktree remove --force "$new_tree" 2>&1); then
      warn "'git worktree remove --force' failed: ${remove_err}; removing manually..."
      rm -rf "$new_tree"
      git -C "$main_tree" worktree prune
    fi
  else
    info "No workspace at $new_tree."
    git -C "$main_tree" worktree prune
  fi

  if [[ -n "$actual_branch" ]]; then
    info "Done. The git branch '$actual_branch' is left intact; delete it manually if you want:"
    info "  git -C \"$main_tree\" branch -D \"$actual_branch\""
  else
    info "Done. If this slug ever had a branch, delete it manually:"
    info "  git -C \"$main_tree\" branch -D \"$slug\""
  fi
}

main() {
  case "${1:-}" in
    -h|--help|"")
      usage; exit 0 ;;
    destroy)
      shift
      if [[ "${1:-}" == "--force" ]]; then
        shift
        [[ $# -eq 1 ]] || { usage; die "destroy --force requires one argument: <slug>"; }
        cmd_destroy "$1" force
      else
        [[ $# -eq 1 ]] || { usage; die "destroy requires one argument: <slug>"; }
        cmd_destroy "$1"
      fi ;;
    --track)
      shift
      [[ $# -eq 1 ]] || { usage; die "--track requires one argument: <slug>"; }
      TRACK_REMOTE=1
      cmd_create "$1" ;;
    *)
      [[ $# -eq 1 ]] || { usage; die "expected one argument: <slug>"; }
      cmd_create "$1" ;;
  esac
}

main "$@"
