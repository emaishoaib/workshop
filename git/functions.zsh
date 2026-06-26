# List, delete, or rename branches
# (no args): list local branches
# -d / --delete: fuzzy delete local branch
# -dr / --remote-delete: fuzzy delete remote branch
# -re / --rename <new-name>: rename current branch locally and remotely
gbra() {
  if [ "$1" = "-d" ] || [ "$1" = "--delete" ]; then
    local branch
    branch=$(git branch | grep -v HEAD | fzf --query="$2")
    [ -n "$branch" ] && git branch -D "$(echo "$branch" | tr -d '[:space:]')"

  elif [ "$1" = "-dr" ] || [ "$1" = "--remote-delete" ]; then
    local branch
    branch=$(git branch -r | grep -v HEAD | sed 's/origin\///' | fzf --query="$2")
    [ -n "$branch" ] && git push origin --delete "$(echo "$branch" | tr -d '[:space:]')"

  elif [ "$1" = "-re" ] || [ "$1" = "--rename" ]; then
    local new_name="$2"
    if [ -z "$new_name" ]; then
      echo "Usage: gbra -re <new-branch-name>"
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
    git branch
  fi
}

# Checkout branch (default: local only; -r: local + remote; -pr [number]: checkout PR)
gcko() {
  if [ "$1" = "-pr" ]; then
    if [ -n "$2" ]; then
      gh pr checkout "$2"
    else
      local pr
      pr=$(gh pr list | fzf --preview='gh pr view {1} 2>/dev/null')
      [ -n "$pr" ] && gh pr checkout "$(echo "$pr" | awk '{print $1}')"
    fi
  elif [ "$1" = "-r" ]; then
    local branch
    branch=$(git branch --all | grep -v HEAD | sed 's/remotes\/origin\///' | sort -u | fzf --query="$2" --preview='git log --oneline --color=always {1} 2>/dev/null | head -10')
    [ -n "$branch" ] && git checkout "$(echo "$branch" | tr -d '[:space:]')"
  else
    local branch
    branch=$(git branch | grep -v HEAD | fzf --query="$1" --preview='git log --oneline --color=always {1} 2>/dev/null | head -10')
    [ -n "$branch" ] && git checkout "$(echo "$branch" | tr -d '[:space:]')"
  fi
}

# Amend the last commit
gcoma() {
  git commit --amend
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

# Show all custom git commands and functions
ghelp() {
  echo "  gbra      list all local branches"
  echo "  gbra -d   fuzzy delete local branch"
  echo "  gbra -dr  fuzzy delete remote branch"
  echo "  gbra -re  rename current branch locally and remotely"
  echo "  gcko      fuzzy checkout (local only)"
  echo "  gcko -r   fuzzy checkout (local + remote)"
  echo "  gcko -pr  checkout a PR by number or fuzzy-pick"
  echo "  gcoma     amend the last commit"
  echo "  glog      show commits on current branch"
  echo "  glog -p   show commits not in the branch it is based off (parent)"
  echo "  grbi      interactive rebase over current branch"
  echo "  grbi -f   fuzzy-pick a commit and list its changed files"
  echo "  grbi -c   fuzzy-pick a commit and surface its changes in VS Code"
  echo "  grbi -d   finish observing (abort rebase + restore stash)"
  echo "  grbc      continue an in-progress rebase"
  echo "  grbo      fuzzy-pick a branch and fork point (sha), then rebase onto it"
  echo "  gstash    multi-select files to stash with a name"
  echo "  ghelp     show this help"
}

# Show all commits introduced on current branch (default: vs default branch; -p: vs parent branch)
glog() {
  if [ "$1" = "-p" ]; then
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
  else
    local default_branch
    default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
    git log --oneline HEAD "^origin/$default_branch"
  fi
}

# Rebase current branch onto a fuzzy-picked local branch from a fuzzy-picked fork point SHA
grbo() {
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
        --header="Select fork point — commits after this will be replayed onto '$onto'" \
    | awk '{print $1}')
  [ -z "$sha" ] && return

  echo "Rebasing onto '$onto' from $sha..."
  git rebase --onto "$onto" "$sha"
}

# Interactive rebase over all commits on current branch
# -f / --files:   fuzzy-pick a commit and list its changed files
# -c / --changes: fuzzy-pick a commit and surface its changes in VS Code
# -d / --done:    finish a -c session (abort rebase + restore stash)
grbi() {
  local default_branch
  default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')

  if [ "$1" = "-f" ] || [ "$1" = "--files" ]; then
    local sha
    sha=$(
      git log --oneline --color=always HEAD "^origin/$default_branch" \
      | fzf --ansi --query="$2" \
          --preview='git show --name-status --format= {1}' \
          --preview-window=right:60% \
          --prompt="Select commit > " \
          --header="Enter: list files  |  Ctrl-C: cancel" \
      | awk '{print $1}'
    )
    [ -n "$sha" ] && git show --name-status --format= "$sha"
    return
  fi

  if [ "$1" = "-d" ] || [ "$1" = "--done" ]; then
    git rebase --abort
    if [ -f ".git/GRBI_DELTA_STASHED" ]; then
      rm -f ".git/GRBI_DELTA_STASHED"
      git stash pop
    fi
    return
  fi

  if [ "$1" = "-c" ] || [ "$1" = "--changes" ]; then
    local sha
    sha=$(
      git log --oneline --color=always HEAD "^origin/$default_branch" \
      | fzf --ansi --query="$2" \
          --preview='git show --stat --color=always {1}' \
          --preview-window=right:60% \
          --prompt="Select commit > " \
          --header="Enter: observe  |  Ctrl-C: cancel" \
      | awk '{print $1}'
    )

    [ -z "$sha" ] && return

    sha=$(git rev-parse "$sha")
    local short_sha
    short_sha=$(git rev-parse --short "$sha")

    echo ""
    echo "Note: this starts a rebase to surface the commit's changes — intended for observation only."
    echo "      To make edits to a commit, run 'grbi' instead."
    echo ""

    local stash_before stash_after
    stash_before=$(git rev-parse refs/stash 2>/dev/null || echo "none")
    git stash -u
    stash_after=$(git rev-parse refs/stash 2>/dev/null || echo "none")
    [ "$stash_before" != "$stash_after" ] && touch .git/GRBI_DELTA_STASHED

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
    echo "Run 'grbi -d' or 'grbi --done' when finished."
    return
  fi

  local base
  base=$(git merge-base HEAD "origin/$default_branch")
  [ -n "$base" ] && git rebase -i "$base"
}

# Continue an in-progress rebase
grbc() {
  git rebase --continue
}

