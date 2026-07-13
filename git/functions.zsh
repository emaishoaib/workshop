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

# Submodule helpers
# reset: sync all submodules to the commit pinned by the parent repo (git submodule update --init)
gsmod() {
  if [ "$1" = "reset" ]; then
    git submodule update --init
  else
    git submodule "$@"
  fi
}

# Remove a stale git index lock (git process crashed/killed mid-operation)
# If no lock is found relative to the cwd, search upward for the nearest one
# and confirm before deleting it.
gunlock() {
  local lockfile=""

  # Preferred path: ask git itself where the current repo's git dir is
  # (handles worktrees/submodules correctly).
  local gitdir
  gitdir=$(git rev-parse --absolute-git-dir 2>/dev/null)
  if [[ -n "$gitdir" && -f "$gitdir/index.lock" ]]; then
    lockfile="$gitdir/index.lock"
  fi

  # Fallback: not inside a recognized repo (or no lock there) — walk up
  # parent directories looking for any .git/index.lock.
  if [[ -z "$lockfile" ]]; then
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
      if [[ -f "$dir/.git/index.lock" ]]; then
        lockfile="$dir/.git/index.lock"
        break
      fi
      dir=$(dirname "$dir")
    done
  fi

  if [[ -z "$lockfile" ]]; then
    echo "gunlock: no index.lock found in $PWD or any parent directory."
    return 1
  fi

  if [[ "$lockfile" != "$PWD/.git/index.lock" ]]; then
    echo "gunlock: no lock file at $PWD/.git/index.lock"
    echo "gunlock: found one at $lockfile"
    read "confirm?Delete this lock file instead? [y/N] "
    if [[ "$confirm" != [yY] ]]; then
      echo "gunlock: aborted."
      return 1
    fi
  fi

  rm -f "$lockfile"
  echo "gunlock: removed $lockfile"
}

# Show all custom git commands and functions
ghelp() {
  echo "  gbra                     git branch"
  echo "  gbra delete              fuzzy delete local branch (prompts to delete remote if it exists)"
  echo "  gbra rename              rename current branch locally and remotely"
  echo "  gcko                     fuzzy checkout (local only)"
  echo "  gcko remote              fuzzy checkout (local + remote)"
  echo "  gcko pr                  checkout a PR by number or fuzzy-pick"
  echo "  glog                     show commits on current branch (or -N for last N, e.g. glog -5)"
  echo "  glog branch              fuzzy-pick a branch to compare against"
  echo "  gpush                    git push"
  echo "  gpush force              force-push current branch to its tracked upstream (--force-with-lease)"
  echo "  gpush head               fuzzy-pick a remote branch, force-push HEAD to it (--force-with-lease)"
  echo "  gpush head:<branch>      force-push HEAD straight to <branch>, no prompt"
  echo "  gpush new                push a new local branch to origin and set upstream tracking (-u origin HEAD)"
  echo "  gsmod                    git submodule"
  echo "  gsmod reset              sync all submodules to the commit pinned by the parent repo (git submodule update --init)"
  echo "  gunlock                  remove a stale git index lock; if not found in cwd, searches upward and confirms before deleting"
  echo "  grbe                     git rebase"
  echo "  grbe branch              fuzzy-pick a branch, interactive rebase commits not in that branch"
  echo "  grbe branch preview      fuzzy-pick a branch, then fuzzy-pick a commit to observe in VS Code"
  echo "  grbe onto                fuzzy-pick a branch and fork point (sha), then rebase onto it"
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
# branch preview:  fuzzy-pick a branch, then fuzzy-pick a commit to observe in VS Code
# done:            finish a branch preview session (abort rebase + restore stash)
# onto:            fuzzy-pick a branch and fork point (sha), then rebase onto it
grbe() {
  local default_branch
  default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')

  if [ "$1" = "branch" ] && [ "$2" = "preview" ]; then
    local current
    current=$(git branch --show-current)

    local selected
    selected=$(git branch | grep -v HEAD | sed 's/^[ *]*//' | grep -v "^$current$" \
      | fzf \
          --prompt="Compare against > " \
          --header="Select branch — commits on $current not in selection will be shown")
    [ -z "$selected" ] && return
    selected=$(echo "$selected" | tr -d '[:space:]')

    local sha
    sha=$(
      git log --oneline --color=always HEAD "^$selected" \
      | fzf --ansi --no-sort \
          --preview='git show --name-status --format= {1}' \
          --preview-window=right:60% \
          --prompt="Select commit > " \
          --header="Enter: observe in VS Code  |  Ctrl-C: cancel" \
      | awk '{print $1}'
    )
    [ -z "$sha" ] && return

    sha=$(git rev-parse "$sha")
    local short_sha
    short_sha=$(git rev-parse --short "$sha")

    echo ""
    echo "Note: this starts a rebase to surface the commit's changes — intended for observation only."
    echo "      To make edits to a commit, run 'grbe branch' instead."
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

    echo ""
    echo "Observing $short_sha — changed files are now visible in VS Code."
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

  if [ "$1" = "done" ]; then
    git rebase --abort
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
