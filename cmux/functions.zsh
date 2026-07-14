# Fuzzy-pick a cmux workspace and switch to it.
# Lists workspaces via `cmux list-workspaces`, lets you pick one with fzf
# (same pattern as the git/ functions), then switches with
# `cmux select-workspace --workspace <ref>`.
cmux-goto() {
  local line
  line=$(cmux list-workspaces | fzf --prompt="Workspace > " --header="Select a workspace to switch to")
  [ -z "$line" ] && return

  local ref
  ref=$(echo "$line" | sed -E 's/^\* //' | awk '{print $1}')
  cmux select-workspace --workspace "$ref"
}
