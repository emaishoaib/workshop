# git/

Fzf-powered git functions. Replaces tedious branch/file picking with fuzzy search.

## Prerequisites

```bash
brew install fzf && $(brew --prefix)/opt/fzf/install
brew install gh && gh auth login
```

## Functions

| Command | Description |
|---------|-------------|
| `gbra` | `git branch` — passes all arguments through directly |
| `gbra delete` | Fuzzy delete local branch; if the branch also exists remotely, prompts to delete it there too |
| `gbra rename <new-name>` | Rename current branch locally and remotely |
| `gchy` | `git cherry-pick` — passes all arguments through directly |
| `gchy branch` | Fuzzy-pick a branch, then multi-select (Tab) from the commits unique to that branch, and cherry-pick them onto the current branch, oldest first |
| `gcko` | Fuzzy checkout — local branches only |
| `gcko remote` | Fuzzy checkout — all branches (local + remote) |
| `gcko pr [number]` | Checkout a PR by number, or fuzzy-pick from open PRs |
| `gcom` | `git commit` — passes all arguments through directly |
| `gcom fix` | Fuzzy-pick a commit on the current branch and create a fixup commit for it (`git commit --fixup=<sha>`) from whatever's currently staged |
| `glog` | Show all commits introduced on current branch (or `-N` for last N, e.g. `glog -5`) |
| `glog branch` | Fuzzy-pick a local branch to compare against; shows commits on current branch not in the selection |
| `gmge` | Fuzzy-pick a local branch and merge it into the current branch |
| `gmge <args>` | `git merge` — passes all arguments through directly (e.g. `gmge --abort`, `gmge --continue`) |
| `gpush` | `git push` — passes all arguments through directly |
| `gpush force` | Force-push current branch to its tracked upstream (`git push --force-with-lease`) |
| `gpush head` | Fuzzy-pick a remote branch, then force-push HEAD to it (`git push origin HEAD:<branch> --force-with-lease`) |
| `gpush head:<branch>` | Force-push HEAD straight to `<branch>`, no prompt |
| `gpush new` | Push a newly created local branch to origin and set up tracking (`git push -u origin HEAD`) |
| `gres` | Fuzzy-pick a commit and `git reset` to it (default mode) — other args pass through directly |
| `gres mixed` | Fuzzy-pick a commit and `git reset --mixed` to it |
| `gres hard` | Fuzzy-pick a commit and `git reset --hard` to it |
| `gsmod` | `git submodule` — passes all arguments through directly |
| `gsmod reset` | Sync all submodules to the commit pinned by the parent repo (`git submodule update --init`) — fixes the "S" (submodule with new commits) indicator in VS Code |
| `grbe` | `git rebase` — passes all arguments through directly |
| `grbe branch` | Fuzzy-pick a local branch, then interactive rebase over commits on current branch not in that branch |
| `grbe preview` | Fuzzy-pick a commit from those on the current branch vs the default branch, and surface it in VS Code for observation |
| `grbe onto` | Fuzzy-pick a local branch to rebase onto, then fuzzy-pick the fork point SHA from commits on the current branch |
| `grbe all` | Interactive rebase over every commit on the current branch vs the default branch — no guessing a commit count |
| `grbe fix` | Non-interactively squash every `fixup!` commit into its target vs the default branch. On conflict, squashes as many as it safely can and reports the first `fixup!` commit that actually conflicts, leaving the rest untouched. Bails out (no merge commits supported) if the branch has any |
| `grbe -N` | Interactive rebase over the last N commits (`HEAD~N`), regardless of whether they've been pushed to origin — e.g. `grbe -3`. Mirrors `glog -N` |
| `gtools` | Interactive GitHub + SSH helper — fzf-pick to create repos, list repos, clone, manage SSH keys |
| `greset` | Remove stale git locks (`index.lock`, `refs/stash.lock`) — fixes "Another git process seems to be running" or "Cannot save the current status" after a crashed/killed git process or interrupted stash |
| `ghelp` | Print all available commands and aliases |

## `gtools`

Interactive GitHub + SSH helper. Run `gtools` from anywhere — fzf picks the action, then walks through any inputs:

- **Create new repo** — pick personal or org account, name, visibility, optional README, optional local clone
- **List repos** — pick account, shows name, visibility, description, and URL
- **Clone a repo** — pick account, fzf over all repos, clone into a named directory
- **List SSH keys** — shows all public keys with fingerprints, agent-loaded keys, and optionally adds a key to the agent

Requires `gh` (installed by `setup.sh`).
