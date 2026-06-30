# Delete or rename branches
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

# Show all custom git commands and functions
ghelp() {
  echo "  gbra delete              fuzzy delete local branch (prompts to delete remote if it exists)"
  echo "  gbra rename              rename current branch locally and remotely"
  echo "  gcko                     fuzzy checkout (local only)"
  echo "  gcko remote              fuzzy checkout (local + remote)"
  echo "  gcko pr                  checkout a PR by number or fuzzy-pick"
  echo "  glog                     show commits on current branch (or -N for last N, e.g. glog -5)"
  echo "  glog branch              fuzzy-pick a branch to compare against"
  echo "  grbe int                 interactive rebase over current branch (or int -N, e.g. grbe int -5)"
  echo "  grbe int branch          fuzzy-pick a branch, interactive rebase commits not in that branch"
  echo "  grbe int preview         fuzzy-pick a commit, preview files, surface in VS Code on select (or int preview -N)"
  echo "  grbe int branch preview  fuzzy-pick a branch, then fuzzy-pick a commit from it, surface in VS Code"
  echo "  grbe onto                fuzzy-pick a branch and fork point (sha), then rebase onto it"
  echo "  grbe continue            continue an in-progress rebase"
  echo "  grbe done                finish observing (abort rebase + restore stash)"
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
# int:                 interactive rebase over current branch; accepts -N to rebase last N commits
# int branch:          fuzzy-pick a branch, interactive rebase commits not in that branch
# int preview:         fuzzy-pick a commit, preview changed files, surface in VS Code; accepts -N to limit picker
# int branch preview:  fuzzy-pick a branch, then fuzzy-pick a commit from those commits, surface in VS Code
# continue:            continue an in-progress rebase
# done:                finish an int preview session (abort rebase + restore stash)
# onto:                fuzzy-pick a branch and fork point (sha), then rebase onto it
grbe() {
  local default_branch
  default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')

  if [ "$1" = "int" ] && [ "$2" = "branch" ] && [ "$3" = "preview" ]; then
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
    echo "      To make edits to a commit, run 'grbe int' instead."
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

    GIT_SEQUENCE_EDITOR="$seq_editor" git rebase -i "${sha}~1"
    rm -f "$seq_editor"

    git reset HEAD~1

    echo ""
    echo "Observing $short_sha — changed files are now visible in VS Code."
    echo "Run 'grbe done' when finished."
    return
  fi

  if [ "$1" = "int" ] && [ "$2" = "branch" ]; then
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
    [ -n "$base" ] && git rebase -i "$base"
    return
  fi

  if [ "$1" = "int" ] && [ "$2" = "preview" ]; then
    local log_args query
    if [[ "$3" =~ ^-[0-9]+$ ]]; then
      log_args="$3"
      query="$4"
    else
      log_args="HEAD \"^origin/$default_branch\""
      query="$3"
    fi

    local sha
    sha=$(
      eval "git log --oneline --color=always $log_args" \
      | fzf --ansi --no-sort --query="$query" \
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
    echo "      To make edits to a commit, run 'grbe int' instead."
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

    GIT_SEQUENCE_EDITOR="$seq_editor" git rebase -i "${sha}~1"
    rm -f "$seq_editor"

    git reset HEAD~1

    echo ""
    echo "Observing $short_sha — changed files are now visible in VS Code."
    echo "Run 'grbe done' when finished."
    return
  fi

  if [ "$1" = "int" ]; then
    if [[ "$2" =~ ^-[0-9]+$ ]]; then
      git rebase -i "HEAD~${2#-}"
    else
      local base
      base=$(git merge-base HEAD "origin/$default_branch")
      [ -n "$base" ] && git rebase -i "$base"
    fi
    return
  fi

  if [ "$1" = "continue" ]; then
    git rebase --continue
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
    git rebase --onto "$onto" "${sha}~1"
    return
  fi
}
