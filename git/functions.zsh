# Checkout branch (all: local + remote)
gck() {
  local branch
  branch=$(git branch --all | grep -v HEAD | sed 's/remotes\/origin\///' | sort -u | fzf --query="$1" --preview='git log --oneline --color=always {1} 2>/dev/null | head -10')
  [ -n "$branch" ] && git checkout "$(echo "$branch" | tr -d '[:space:]')"
}

# Checkout branch (local only)
gckl() {
  local branch
  branch=$(git branch | grep -v HEAD | fzf --query="$1" --preview='git log --oneline --color=always {1} 2>/dev/null | head -10')
  [ -n "$branch" ] && git checkout "$(echo "$branch" | tr -d '[:space:]')"
}

# Checkout a PR by number, or fuzzy-pick from open PRs
gckpr() {
  if [ -n "$1" ]; then
    gh pr checkout "$1"
  else
    local pr
    pr=$(gh pr list | fzf --query="$2" --preview='gh pr view {1} 2>/dev/null')
    [ -n "$pr" ] && gh pr checkout "$(echo "$pr" | awk '{print $1}')"
  fi
}

# Amend the last commit
gcoma() {
  git commit --amend
}

# Delete local branch
gdel() {
  local branch
  branch=$(git branch | grep -v HEAD | fzf --query="$1")
  [ -n "$branch" ] && git branch -D "$(echo "$branch" | tr -d '[:space:]')"
}

# Delete remote branch
gdelr() {
  local branch
  branch=$(git branch -r | grep -v HEAD | sed 's/origin\///' | fzf --query="$1")
  [ -n "$branch" ] && git push origin --delete "$(echo "$branch" | tr -d '[:space:]')"
}

# Multi-select files to stash with a name
gstash() {
  local name="$1"
  if [ -z "$name" ]; then
    echo "Usage: gstash <stash-name>"
    return 1
  fi

  local files
  files=$(
    { git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard; } \
    | sort -u \
    | fzf -m \
        --preview='git diff HEAD -- {} 2>/dev/null | head -50' \
        --preview-window=right:60% \
        --prompt="Select files to stash > " \
        --header="Tab: select/deselect  |  Enter: confirm  |  Ctrl-C: cancel"
  )

  if [ -z "$files" ]; then
    echo "No files selected."
    return 0
  fi

  git stash push -u -m "$name" -- ${(f)files}
  echo "Stashed as: '$name'"
}

# Rename current branch locally and remotely
grem() {
  local new_name="$1"
  if [ -z "$new_name" ]; then
    echo "Usage: grem <new-branch-name>"
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
}

# Show all custom git commands and functions
ghelp() {
  echo "── git aliases ──────────────────────────────"
  echo "  git blog  oneline log of commits on current branch"
  echo "  git rbi   interactive rebase from branch point"
  echo ""
  echo "── zsh functions ────────────────────────────"
  echo "  gck       fuzzy checkout (local + remote)"
  echo "  gckl      fuzzy checkout (local only)"
  echo "  gckpr     checkout a PR by number or fuzzy-pick"
  echo "  gcoma     amend the last commit"
  echo "  gdel      fuzzy delete local branch"
  echo "  gdelr     fuzzy delete remote branch"
  echo "  gfiles    fuzzy-pick a commit, list its files + status"
  echo "  glog      show commits on current branch"
  echo "  glogp     show commits on current branch relative to parent branch"
  echo "  grbi      interactive rebase over current branch"
  echo "  grem      rename current branch locally and remotely"
  echo "  gstash    multi-select files to stash with a name"
  echo "  ghelp     show this help"
}

# Show commits on current branch relative to the branch it was branched from
glogp() {
  local current=$(git branch --show-current)

  local parent
  parent=$(git for-each-ref --format='%(refname:short)' refs/heads \
    | grep -v "^$current$" \
    | while read b; do
        mb=$(git merge-base HEAD "$b" 2>/dev/null) || continue
        count=$(git rev-list --count "$mb")
        echo "$count $b"
      done \
    | sort -rn | head -1 | awk '{print $2}')

  if [ -z "$parent" ]; then
    echo "Could not determine parent branch"
    return 1
  fi

  echo "(parent: $parent)"
  git log --oneline HEAD "^$parent"
}

# Show all commits introduced on current branch
glog() {
  local default_branch
  default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
  git log --oneline HEAD "^origin/$default_branch"
}

# Fuzzy-pick a commit on the current branch and list its files
gfiles() {
  local default_branch
  default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')

  local sha
  sha=$(
    git log --oneline --color=always HEAD "^origin/$default_branch" \
    | fzf --ansi --query="$1" \
        --preview='git show --name-status --format= {1}' \
        --preview-window=right:60% \
        --prompt="Select commit > " \
        --header="Enter: list files  |  Ctrl-C: cancel" \
    | awk '{print $1}'
  )

  [ -n "$sha" ] && git show --name-status --format= "$sha"
}

# Interactive rebase over all commits on current branch
grbi() {
  local default_branch
  default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
  local base
  base=$(git merge-base HEAD "origin/$default_branch")
  [ -n "$base" ] && git rebase -i "$base"
}

