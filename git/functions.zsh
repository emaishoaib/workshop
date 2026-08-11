# git branch passthrough; custom subcommands:
# delete: fuzzy delete local branch; prompts to also delete remote if it exists
# rename <new-name>: rename current branch locally and remotely
gbra() {
  if [ "$1" = "delete" ]; then
    local branch
    branch=$(git branch | grep -v HEAD | fzf --query="$2")
    [ -z "$branch" ] && return
    branch=$(echo "$branch" | tr -d '[:space:]')
    git branch -D "$branch"

    if git ls-remote --exit-code --heads origin "$branch" > /dev/null 2>&1; then
      echo -n "Remote branch '$branch' exists. Delete it too? [y/N] "
      read -r answer
      if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        git push origin --delete "$branch"
        echo "Deleted remote branch '$branch'."
      fi
    fi

  elif [ "$1" = "rename" ]; then
    local new_name="$2"
    if [ -z "$new_name" ]; then
      echo "Usage: gbra rename <new-branch-name>"
      return 1
    fi

    local old_name
    old_name=$(git rev-parse --abbrev-ref HEAD)

    if [ "$old_name" = "HEAD" ]; then
      echo "Error: not on a branch (detached HEAD state)"
      return 1
    fi

    if [ "$old_name" = "$new_name" ]; then
      echo "Error: new name is the same as the current branch name"
      return 1
    fi

    echo "Renaming '$old_name' → '$new_name'..."

    git branch -m "$new_name"
    git push origin "$new_name" --set-upstream

    if git ls-remote --exit-code --heads origin "$old_name" > /dev/null 2>&1; then
      git push origin --delete "$old_name"
      echo "Deleted remote branch '$old_name'"
    else
      echo "(No remote branch '$old_name' to delete)"
    fi

    echo "Done. Now on '$new_name'."

  else
    git branch "$@"
  fi
}

# Checkout branch (default: local only; remote: local + remote; pr [number]: checkout PR)
gcko() {
  if [ "$1" = "pr" ]; then
    if [ -n "$2" ]; then
      gh pr checkout "$2"
    else
      local pr
      pr=$(gh pr list | fzf --preview='gh pr view {1} 2>/dev/null')
      [ -n "$pr" ] && gh pr checkout "$(echo "$pr" | awk '{print $1}')"
    fi
  elif [ "$1" = "remote" ]; then
    local branch
    branch=$(git branch --all | grep -v HEAD | sed 's/remotes\/origin\///' | sort -u | fzf --query="$2" --preview='git log --oneline --color=always {1} 2>/dev/null | head -10')
    [ -n "$branch" ] && git checkout "$(echo "$branch" | tr -d '[:space:]')"
  else
    local branch
    branch=$(git branch | grep -v HEAD | fzf --query="$1" --preview='git log --oneline --color=always {1} 2>/dev/null | head -10')
    [ -n "$branch" ] && git checkout "$(echo "$branch" | tr -d '[:space:]')"
  fi
}

# Commit helpers
# (no args or normal args): git commit passthrough
# fix:  fuzzy-pick a commit on the current branch and create a fixup commit for it
#       (git commit --fixup=<sha>) from whatever's currently staged
gcom() {
  if [ "$1" = "fix" ]; then
    local default_branch
    default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')

    local sha
    sha=$(git log --oneline --color=always HEAD "^origin/$default_branch" \
      | fzf --ansi --no-sort \
          --preview='git show --stat --color=always --format= {1} 2>/dev/null; echo; git show --color=always {1} 2>/dev/null' \
          --preview-window=right:60% \
          --prompt="Fixup > " \
          --header="Select commit to create a fixup for" \
      | awk '{print $1}')
    [ -z "$sha" ] && return

    git commit --fixup="$sha"
    return
  fi

  git commit "$@"
}

# Force-push current HEAD to a remote branch (git push origin HEAD:<branch> --force-with-lease)
# force:           force-push current branch to its tracked upstream (--force-with-lease)
# head:            fuzzy-pick a remote branch to push HEAD to
# head:<branch>    push HEAD straight to <branch>, no prompt
# new:             push a newly created local branch to origin and set up tracking (git push -u origin HEAD)
gpush() {
  if [ "$1" = "force" ]; then
    shift
    git push --force-with-lease "$@"

  elif [ "$1" = "head" ]; then
    local branch
    branch=$(git branch -r | grep -v HEAD | sed 's/^[ *]*//;s#^origin/##' | sort -u | fzf --prompt="Push HEAD to > ")
    [ -z "$branch" ] && return
    branch=$(echo "$branch" | tr -d '[:space:]')
    git push origin HEAD:"$branch" --force-with-lease

  elif [[ "$1" == head:* ]]; then
    local branch="${1#head:}"
    if [ -z "$branch" ]; then
      echo "Usage: gpush head:<branch-name>"
      return 1
    fi
    git push origin HEAD:"$branch" --force-with-lease

  elif [ "$1" = "new" ]; then
    git push -u origin HEAD

  else
    git push "$@"
  fi
}

# Merge helpers
# (no args): fuzzy-pick a local branch (excluding current) and merge it into the current branch
# other args: git merge passthrough (e.g. --abort, --continue)
gmge() {
  if [ -z "$1" ]; then
    local current
    current=$(git branch --show-current)

    local branch
    branch=$(git branch | grep -v HEAD | sed 's/^[ *]*//' | grep -v "^$current$" \
      | fzf \
          --prompt="Merge into $current > " \
          --header="Select branch to merge into $current" \
          --preview='git log --oneline --color=always {1} 2>/dev/null | head -10')
    [ -z "$branch" ] && return
    branch=$(echo "$branch" | tr -d '[:space:]')

    git merge "$branch"
    return
  fi

  git merge "$@"
}

# Submodule helpers
# reset: sync all submodules to the commit pinned by the parent repo (git submodule update --init)
gsmod() {
  if [ "$1" = "reset" ]; then
    git submodule update --init
  else
    git submodule "$@"
  fi
}

# Remove stale git locks (git process crashed/killed mid-operation, or a
# stash pop/drop that died partway through). Checks index.lock and
# refs/stash.lock. If none are found relative to the cwd, search upward
# for the nearest repo with one and confirm before deleting it.
greset() {
  local -a lock_names=("index.lock" "refs/stash.lock")
  local -a found=()

  # Preferred path: ask git itself where the current repo's git dir is
  # (handles worktrees/submodules correctly).
  local gitdir
  gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null)
  if [[ -n "$gitdir" ]]; then
    local name
    for name in "${lock_names[@]}"; do
      [[ -f "$gitdir/$name" ]] && found+=("$gitdir/$name")
    done
  fi

  # Fallback: not inside a recognized repo (or no locks there) — walk up
  # parent directories looking for any matching lock under .git.
  if [[ ${#found[@]} -eq 0 ]]; then
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
      local name
      for name in "${lock_names[@]}"; do
        [[ -f "$dir/.git/$name" ]] && found+=("$dir/.git/$name")
      done
      [[ ${#found[@]} -gt 0 ]] && break
      dir=$(dirname "$dir")
    done
  fi

  if [[ ${#found[@]} -eq 0 ]]; then
    echo "greset: no index.lock or refs/stash.lock found in $PWD or any parent directory."
    return 1
  fi

  if [[ -z "$gitdir" || "${found[1]}" != "$gitdir"/* ]]; then
    echo "greset: no lock file at $PWD/.git"
    echo "greset: found:"
    printf '  %s\n' "${found[@]}"
    read "confirm?Delete these lock file(s) instead? [y/N] "
    if [[ "$confirm" != [yY] ]]; then
      echo "greset: aborted."
      return 1
    fi
  fi

  local f
  for f in "${found[@]}"; do
    rm -f "$f"
    echo "greset: removed $f"
  done
}

# Reset helpers
# (no args): fuzzy-pick a commit from history and reset to it (default mode)
# mixed:     fuzzy-pick a commit and reset to it with --mixed
# hard:      fuzzy-pick a commit and reset to it with --hard
# other args: git reset passthrough
gres() {
  local mode=""
  case "$1" in
    mixed) mode="--mixed"; shift ;;
    hard)  mode="--hard"; shift ;;
    "") ;;
    *) git reset "$@"; return ;;
  esac

  local sha
  sha=$(git log --oneline --color=always \
    | fzf --ansi --no-sort \
        --preview='git show --stat --color=always --format= {1} 2>/dev/null; echo; git show --color=always {1} 2>/dev/null' \
        --preview-window=right:60% \
        --prompt="Reset to > " \
        --header="Select commit to reset to${mode:+ ($mode)}" \
    | awk '{print $1}')
  [ -z "$sha" ] && return

  echo "git reset ${mode:+$mode }$sha"
  git reset $mode "$sha"
}

# Cherry-pick helpers
# (no args): git cherry-pick
# branch:    fuzzy-pick a source branch, then multi-select (Tab) from the
#            commits that belong to that branch alone (i.e. not already on
#            the current branch), and cherry-pick them onto the current
#            branch, oldest first.
gchy() {
  if [ "$1" = "branch" ]; then
    local current
    current=$(git branch --show-current)

    local branch
    branch=$(git branch | sed 's/^[ *]*//' | sort -u | grep -v "^$current$" \
      | fzf \
          --prompt="Cherry-pick from > " \
          --header="Select branch to cherry-pick commits from" \
          --preview='git log --oneline --color=always {1} 2>/dev/null | head -10')
    [ -z "$branch" ] && return
    branch=$(echo "$branch" | tr -d '[:space:]')

    local shas
    shas=$(git log --oneline --color=always "$branch" "^$current" \
      | fzf --ansi -m --no-sort \
          --preview='git show --name-status --format= {1}' \
          --preview-window=right:60% \
          --prompt="Cherry-pick commits > " \
          --header="Tab: select multiple  |  Enter: cherry-pick onto $current" \
      | awk '{print $1}')
    [ -z "$shas" ] && return

    # fzf's multi-select output order follows the order items were tabbed in,
    # NOT their position in the list -- so it can't be trusted for ordering.
    # Resolve the selection to full hashes, then re-derive the true
    # oldest -> newest order straight from git history.
    local selected_full sha
    selected_full=$(for sha in ${(f)shas}; do git rev-parse "$sha"; done)

    local ordered
    ordered=$(git rev-list --reverse "$branch" "^$current" \
      | grep -Fx -f <(echo "$selected_full"))
    [ -z "$ordered" ] && return

    echo "Cherry-picking onto '$current':"
    echo "$ordered"
    git cherry-pick $(echo "$ordered")
    return
  fi

  git cherry-pick "$@"
}

# Show all custom git commands and functions
ghelp() {
  echo "  gbra                     git branch"
  echo "  gbra delete              fuzzy delete local branch (prompts to delete remote if it exists)"
  echo "  gbra rename              rename current branch locally and remotely"
  echo "  gcko                     fuzzy checkout (local only)"
  echo "  gcko remote              fuzzy checkout (local + remote)"
  echo "  gcko pr                  checkout a PR by number or fuzzy-pick"
  echo "  gcom                     git commit"
  echo "  gcom fix                 fuzzy-pick a commit and create a fixup commit for it (git commit --fixup=<sha>)"
  echo "  gchy                     git cherry-pick"
  echo "  gchy branch              fuzzy-pick a branch, multi-select its unique commits, cherry-pick them onto the current branch"
  echo "  glog                     show commits on current branch (or -N for last N, e.g. glog -5)"
  echo "  glog branch              fuzzy-pick a branch to compare against"
  echo "  gpush                    git push"
  echo "  gpush force              force-push current branch to its tracked upstream (--force-with-lease)"
  echo "  gpush head               fuzzy-pick a remote branch, force-push HEAD to it (--force-with-lease)"
  echo "  gpush head:<branch>      force-push HEAD straight to <branch>, no prompt"
  echo "  gpush new                push a new local branch to origin and set upstream tracking (-u origin HEAD)"
  echo "  gmge                     fuzzy-pick a branch and merge it into the current branch"
  echo "  gres                     fuzzy-pick a commit and git reset to it (default mode)"
  echo "  gres mixed               fuzzy-pick a commit and git reset --mixed to it"
  echo "  gres hard                fuzzy-pick a commit and git reset --hard to it"
  echo "  gsmod                    git submodule"
  echo "  gsmod reset              sync all submodules to the commit pinned by the parent repo (git submodule update --init)"
  echo "  greset                   remove stale git locks (index.lock, refs/stash.lock); if not found in cwd, searches upward and confirms before deleting"
  echo "  grbe                     git rebase"
  echo "  grbe branch              fuzzy-pick a branch, interactive rebase commits not in that branch"
  echo "  grbe edit                fuzzy-pick a commit (vs default branch) to edit in VS Code"
  echo "  grbe done                finish a grbe edit session: commits your changes and continues if you made"
  echo "                           any, otherwise discards and aborts (same as making no changes)"
  echo "  grbe onto                fuzzy-pick a branch and fork point (sha), then rebase onto it"
  echo "  grbe all                 interactive rebase over every commit on the current branch vs the default branch"
  echo "  grbe fix                 non-interactively squash all fixup! commits vs the default branch; on conflict, squashes as many as it safely can and reports the first one that conflicts (no merge commits)"
  echo "  grbe -N                  interactive rebase over the last N commits, pushed or not (e.g. grbe -3)"
  echo "  ghelp                    show this help"
}

# Show all commits introduced on current branch (default: vs default branch; branch: fuzzy-pick a branch to compare against; -N: last N commits)
glog() {
  if [ "$1" = "branch" ]; then
    local current
    current=$(git branch --show-current)

    local selected
    selected=$(git branch | grep -v HEAD | sed 's/^[ *]*//' | grep -v "^$current$" \
      | fzf \
          --prompt="Compare against > " \
          --header="Select branch — commits on $current not in selection will be shown")
    [ -z "$selected" ] && return

    selected=$(echo "$selected" | tr -d '[:space:]')
    git log --oneline HEAD "^$selected"

  elif [[ "$1" =~ ^-[0-9]+$ ]]; then
    git log --oneline "$1"

  else
    local default_branch
    default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
    git log --oneline HEAD "^origin/$default_branch"
  fi
}

# Rebase helpers
# (no args):       git rebase
# branch:          fuzzy-pick a branch, interactive rebase commits not in that branch
# edit:            fuzzy-pick a commit (vs default branch) to edit in VS Code
# done:            finish a grbe edit session — if you changed anything, commits those changes
#                  (reusing the original commit's message) and continues the rebase; if you
#                  didn't, discards and aborts, restoring the stash if one was made
# onto:            fuzzy-pick a branch and fork point (sha), then rebase onto it
# all:              interactive rebase over every commit on the current branch vs the default branch
# -N:               interactive rebase over the last N commits (HEAD~N), pushed or not — e.g. grbe -3

# Compares the working tree against a commit's snapshot for exactly the paths
# that commit touched (relative to its parent $2). Used by `grbe done` to tell
# whether you actually edited anything during a `grbe edit` session.
_grbe_worktree_matches() {
  local sha="$1" base="$2"
  local chg_status fpath fpath2
  while IFS=$'\t' read -r chg_status fpath fpath2; do
    case "$chg_status" in
      D*)
        [ -e "$fpath" ] && return 1
        ;;
      R*)
        [ -e "$fpath" ] && return 1
        [ -e "$fpath2" ] || return 1
        cmp -s <(git cat-file -p "${sha}:${fpath2}" 2>/dev/null) "$fpath2" || return 1
        ;;
      *)
        [ -e "$fpath" ] || return 1
        cmp -s <(git cat-file -p "${sha}:${fpath}" 2>/dev/null) "$fpath" || return 1
        ;;
    esac
  done < <(git diff --name-status "$base" "$sha")
  return 0
}

# git rebase --abort refuses to run if any untracked file would be overwritten
# restoring orig-head — which happens any time the commit you were observing/
# editing added a new file (it's untracked in the working tree post-split).
# Before aborting, clear away only the untracked files that are byte-identical
# to what orig-head already has at that path, since abort would recreate them
# unchanged anyway. Anything that doesn't match is left alone, so a genuine
# conflict still fails loudly instead of silently discarding real work.
_grbe_safe_abort() {
  local rebase_dir=".git/rebase-merge"
  [ -d "$rebase_dir" ] || rebase_dir=".git/rebase-apply"
  local orig_head
  orig_head=$(cat "$rebase_dir/orig-head" 2>/dev/null)

  if [ -n "$orig_head" ]; then
    local line fpath
    git status --porcelain | while IFS= read -r line; do
      case "$line" in
        '?? '*)
          fpath="${line#\?\? }"
          if git cat-file -e "${orig_head}:${fpath}" 2>/dev/null; then
            cmp -s <(git cat-file -p "${orig_head}:${fpath}" 2>/dev/null) "$fpath" 2>/dev/null \
              && rm -f "$fpath"
          fi
          ;;
      esac
    done
  fi

  git rebase --abort
}

grbe() {
  local default_branch
  default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')

  if [ "$1" = "edit" ]; then
    local sha
    sha=$(
      git log --oneline --color=always HEAD "^origin/$default_branch" \
      | fzf --ansi --no-sort \
          --preview='git show --name-status --format= {1}' \
          --preview-window=right:60% \
          --prompt="Select commit > " \
          --header="Enter: edit in VS Code  |  Ctrl-C: cancel" \
      | awk '{print $1}'
    )
    [ -z "$sha" ] && return

    sha=$(git rev-parse "$sha")
    local short_sha
    short_sha=$(git rev-parse --short "$sha")

    echo ""
    echo "Note: this starts a rebase to surface the commit's changes in VS Code."
    echo "      Edit them if you want to, then run 'grbe done': if you changed"
    echo "      anything it's committed back in and the rebase continues; if not,"
    echo "      it's discarded and the rebase is aborted."
    echo ""

    local stash_before stash_after
    stash_before=$(git rev-parse refs/stash 2>/dev/null || echo "none")
    git stash -u
    stash_after=$(git rev-parse refs/stash 2>/dev/null || echo "none")
    [ "$stash_before" != "$stash_after" ] && touch .git/GRBE_DELTA_STASHED

    local seq_editor
    seq_editor=$(mktemp)
    cat > "$seq_editor" << SCRIPT
#!/bin/sh
sed -i '' "s/^pick $short_sha/edit $short_sha/" "\$1"
SCRIPT
    chmod +x "$seq_editor"

    GIT_SEQUENCE_EDITOR="$seq_editor" git rebase -i --rebase-merges "${sha}~1"
    rm -f "$seq_editor"

    git reset HEAD~1
    echo "$sha" > .git/GRBE_EDIT_SHA

    echo ""
    echo "Editing $short_sha — changed files are now visible in VS Code."
    echo "Run 'grbe done' when finished."
    return
  fi

  if [ "$1" = "branch" ]; then
    local current
    current=$(git branch --show-current)

    local selected
    selected=$(git branch | grep -v HEAD | sed 's/^[ *]*//' | grep -v "^$current$" \
      | fzf \
          --prompt="Compare against > " \
          --header="Select branch — commits on $current not in selection will be rebased")
    [ -z "$selected" ] && return

    selected=$(echo "$selected" | tr -d '[:space:]')
    local base
    base=$(git merge-base HEAD "$selected")
    [ -n "$base" ] && git rebase -i --rebase-merges "$base"
    return
  fi

  if [ "$1" = "all" ]; then
    local base
    base=$(git merge-base HEAD "origin/$default_branch")
    [ -n "$base" ] && git rebase -i --rebase-merges "$base"
    return
  fi

  if [ "$1" = "fix" ]; then
    local base
    base=$(git merge-base HEAD "origin/$default_branch")
    if [ -z "$base" ]; then
      echo "grbe fix: could not determine merge-base with origin/$default_branch"
      return 1
    fi

    local original_head
    original_head=$(git rev-parse HEAD)

    # Fast path: try to autosquash every fixup! commit in one shot, no editor.
    if GIT_SEQUENCE_EDITOR=true GIT_EDITOR=true git rebase --autosquash --rebase-merges "$base" > /dev/null 2>&1; then
      echo "grbe fix: all fixup! commits squashed cleanly."
      return 0
    fi
    git rebase --abort > /dev/null 2>&1

    if [ -n "$(git log --merges --format='%H' "$base..HEAD")" ]; then
      echo "grbe fix: this branch has merge commits vs origin/$default_branch."
      echo "The conflict fallback can't safely rebuild history around merges — resolve it manually via 'grbe all'."
      return 1
    fi

    # Capture git's own autosquash-reordered todo (without running it) purely
    # to learn the order it applies fixup! commits in, and which commit each
    # one targets (the line immediately above it in that reordered todo).
    local capture_file capture_editor
    capture_file=$(mktemp)
    capture_editor=$(mktemp)
    cat > "$capture_editor" << 'SCRIPT'
#!/bin/sh
cp "$1" "$GRBE_FIX_CAPTURE"
exit 1
SCRIPT
    chmod +x "$capture_editor"
    GRBE_FIX_CAPTURE="$capture_file" GIT_SEQUENCE_EDITOR="$capture_editor" \
      git rebase -i --autosquash --rebase-merges "$base" > /dev/null 2>&1
    rm -f "$capture_editor"

    local -a fixup_order
    local -A target_of
    local prev_sha="" line action short_sha full_sha
    while IFS= read -r line; do
      case "$line" in
        pick\ *|fixup\ *)
          action="${line%% *}"
          short_sha="${line#* }"
          short_sha="${short_sha%% *}"
          full_sha=$(git rev-parse "$short_sha" 2> /dev/null)
          [ -z "$full_sha" ] && continue
          if [ "$action" = "fixup" ]; then
            fixup_order+=("$full_sha")
            target_of[$full_sha]="$prev_sha"
          fi
          prev_sha="$full_sha"
          ;;
      esac
    done < "$capture_file"
    rm -f "$capture_file"

    local total=${#fixup_order[@]}
    if [ "$total" -eq 0 ]; then
      echo "grbe fix: rebase failed, but no fixup! commits were found — this isn't a fixup conflict."
      echo "Resolve it manually (e.g. via 'grbe all')."
      return 1
    fi

    local -a chron_shas
    chron_shas=("${(@f)$(git log --reverse --format='%H' "$base..HEAD")}")

    # Reusable sequence editor: fully replaces git's todo with the one we
    # precompute below for each candidate k.
    local apply_editor
    apply_editor=$(mktemp)
    cat > "$apply_editor" << 'SCRIPT'
#!/bin/sh
cp "$GRBE_FIX_TODO" "$1"
SCRIPT
    chmod +x "$apply_editor"

    local todo_file
    todo_file=$(mktemp)

    # Build the rebase todo for squashing the first $1 fixups (by
    # application order). Every other commit — including any not-yet-tested
    # fixup! commit — is left exactly where it originally was, so it can
    # never be dragged into a spurious reorder conflict.
    _grbe_fix_build_todo() {
      local keep="$1"
      local -a wl_sha wl_action
      wl_sha=("${chron_shas[@]}")
      local i
      for ((i = 1; i <= ${#wl_sha[@]}; i++)); do
        wl_action+=("pick")
      done

      local j fsha tgt idx_f idx_t
      for ((j = 1; j <= keep; j++)); do
        fsha="${fixup_order[$j]}"
        tgt="${target_of[$fsha]}"
        idx_f=${wl_sha[(i)$fsha]}
        wl_sha[$idx_f]=()
        wl_action[$idx_f]=()
        idx_t=${wl_sha[(i)$tgt]}
        wl_sha[$idx_t,$idx_t]=("${wl_sha[$idx_t]}" "$fsha")
        wl_action[$idx_t,$idx_t]=("${wl_action[$idx_t]}" "fixup")
      done

      : > "$todo_file"
      for ((i = 1; i <= ${#wl_sha[@]}; i++)); do
        echo "${wl_action[$i]} ${wl_sha[$i]}" >> "$todo_file"
      done
    }

    local k succeeded_k=0
    for ((k = 1; k <= total; k++)); do
      _grbe_fix_build_todo "$k"
      if GRBE_FIX_TODO="$todo_file" GIT_SEQUENCE_EDITOR="$apply_editor" \
          git rebase -i "$base" > /dev/null 2>&1; then
        succeeded_k=$k
        git reset --hard "$original_head" > /dev/null 2>&1
      else
        git rebase --abort > /dev/null 2>&1
        break
      fi
    done

    if [ "$succeeded_k" -gt 0 ]; then
      _grbe_fix_build_todo "$succeeded_k"
      GRBE_FIX_TODO="$todo_file" GIT_SEQUENCE_EDITOR="$apply_editor" \
        git rebase -i "$base" > /dev/null 2>&1
    fi
    rm -f "$apply_editor" "$todo_file"
    unfunction _grbe_fix_build_todo 2> /dev/null

    if [ "$succeeded_k" -eq "$total" ]; then
      echo "grbe fix: all fixup! commits squashed cleanly."
      return 0
    fi

    echo ""
    if [ "$succeeded_k" -gt 0 ]; then
      echo "grbe fix: squashed $succeeded_k fixup! commit(s) cleanly:"
      local i
      for ((i = 1; i <= succeeded_k; i++)); do
        echo "  - $(git log -1 --format='%h %s' "${fixup_order[$i]}" 2> /dev/null)"
      done
    else
      echo "grbe fix: no fixup! commits could be squashed automatically."
    fi

    local problem_sha
    problem_sha="${fixup_order[$((succeeded_k + 1))]}"
    echo ""
    echo "grbe fix: stopped — conflicts squashing fixup! commit: $(git log -1 --format='%h %s' "$problem_sha" 2> /dev/null)"
    echo "Resolve it manually (e.g. via 'grbe all') before continuing."
    return 1
  fi

  if [[ "$1" =~ ^-[0-9]+$ ]]; then
    local n="${1#-}"
    git rebase -i --rebase-merges "HEAD~$n"
    return
  fi

  if [ "$1" = "done" ]; then
    if [ -f ".git/GRBE_EDIT_SHA" ]; then
      local edit_sha edit_base
      edit_sha=$(cat .git/GRBE_EDIT_SHA)
      edit_base="${edit_sha}~1"
      rm -f .git/GRBE_EDIT_SHA

      if _grbe_worktree_matches "$edit_sha" "$edit_base"; then
        _grbe_safe_abort || return 1
      else
        git add -A
        git commit -C "$edit_sha"
        git rebase --continue
        if [ -d ".git/rebase-merge" ] || [ -d ".git/rebase-apply" ]; then
          echo ""
          echo "grbe done: your edit was committed, but the rebase stopped while"
          echo "           replaying later commits — resolve it, then run"
          echo "           'git rebase --continue' yourself. (stash left in place)"
          return 1
        fi
      fi
    else
      _grbe_safe_abort || return 1
    fi

    if [ -f ".git/GRBE_DELTA_STASHED" ]; then
      rm -f ".git/GRBE_DELTA_STASHED"
      git stash pop
    fi
    return
  fi

  if [ "$1" = "onto" ]; then
    local current
    current=$(git branch --show-current)

    local onto
    onto=$(git branch | grep -v HEAD | sed 's/^[ *]*//' | grep -v "^$current$" \
      | fzf \
          --prompt="Rebase onto > " \
          --header="Select branch to rebase onto")
    [ -z "$onto" ] && return
    onto=$(echo "$onto" | tr -d '[:space:]')

    local sha
    sha=$(git log --oneline HEAD "^$onto" \
      | fzf \
          --no-sort \
          --reverse \
          --prompt="Fork point > " \
          --header="Select fork point — commits starting from this will be replayed onto '$onto'" \
      | awk '{print $1}')
    [ -z "$sha" ] && return

    echo "Rebasing onto '$onto' from $sha..."
    git rebase --onto "$onto" --rebase-merges "${sha}~1"
    return
  fi

  git rebase "$@"
}
