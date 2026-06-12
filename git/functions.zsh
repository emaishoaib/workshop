# Checkout branch (all: local + remote)
gco() {
  local branch
  branch=$(git branch --all | grep -v HEAD | sed 's/remotes\/origin\///' | sort -u | fzf --query="$1" --preview='git log --oneline --color=always {1} 2>/dev/null | head -10')
  [ -n "$branch" ] && git checkout "$(echo "$branch" | tr -d '[:space:]')"
}

# Checkout branch (local only)
gcol() {
  local branch
  branch=$(git branch | grep -v HEAD | fzf --query="$1" --preview='git log --oneline --color=always {1} 2>/dev/null | head -10')
  [ -n "$branch" ] && git checkout "$(echo "$branch" | tr -d '[:space:]')"
}

# Delete local branch
gbd() {
  local branch
  branch=$(git branch | grep -v HEAD | fzf --query="$1")
  [ -n "$branch" ] && git branch -D "$(echo "$branch" | tr -d '[:space:]')"
}

# Delete remote branch
gbdr() {
  local branch
  branch=$(git branch -r | grep -v HEAD | sed 's/origin\///' | fzf --query="$1")
  [ -n "$branch" ] && git push origin --delete "$(echo "$branch" | tr -d '[:space:]')"
}

# Fuzzy git add
gadd() {
  local files
  files=$(git status --short | fzf --multi --query="$1" | awk '{print $2}')
  [ -n "$files" ] && echo "$files" | xargs git add
}

# Fuzzy git restore (unstage or discard changes)
gres() {
  local files
  files=$(git status --short | fzf --multi --query="$1" | awk '{print $2}')
  [ -n "$files" ] && echo "$files" | xargs git restore
}

# Fuzzy git stash pop/apply
gstash() {
  local entry
  entry=$(git stash list | fzf --query="$1" --preview='git stash show -p {1} 2>/dev/null | head -20' | cut -d: -f1)
  [ -n "$entry" ] && git stash pop "$entry"
}

# Fuzzy checkout a specific commit (detached HEAD)
gsha() {
  local commit
  commit=$(git log --oneline --all | fzf --query="$1" --preview='git show --stat --color=always {1}')
  [ -n "$commit" ] && git checkout "$(echo "$commit" | awk '{print $1}')"
}

# Checkout a PR by number, or fuzzy-pick from open PRs
gpr() {
  if [ -n "$1" ]; then
    gh pr checkout "$1"
  else
    local pr
    pr=$(gh pr list | fzf --query="$2" --preview='gh pr view {1} 2>/dev/null')
    [ -n "$pr" ] && gh pr checkout "$(echo "$pr" | awk '{print $1}')"
  fi
}

# Interactive rebase over all commits on current branch
grbi() {
  local default_branch
  default_branch=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
  local base
  base=$(git merge-base HEAD "origin/$default_branch")
  [ -n "$base" ] && git rebase -i "$base"
}