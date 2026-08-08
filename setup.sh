#!/bin/bash

WORKSHOP_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
GITCONFIG="$HOME/.gitconfig"

# --- Output ---

if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_FAIL=$'\033[31m'; C_WARN=$'\033[33m'
  C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
else
  C_OK=""; C_FAIL=""; C_WARN=""; C_DIM=""; C_RESET=""
fi

STEPS_OK=0
STEPS_FAILED=0
STEP_DETAIL=""
STEP_WARNINGS=()

step_detail() { STEP_DETAIL="$1"; }
step_warn() { STEP_WARNINGS+=("$1"); }

# "${arr[*]}" with IFS=', ' only ever uses IFS's first character to join
# (a bash quirk, not a typo) -- so this exists to actually get ", " between
# items.
join_words() {
  local result="" item
  for item in "$@"; do
    result="${result:+$result, }$item"
  done
  printf '%s' "$result"
}

# Runs one step's function with its own stdout/stderr captured, so a
# successful step prints one clean line instead of whatever the underlying
# tool (brew, pip, swift...) feels like printing. On failure the captured
# output is shown indented below the step, and the run keeps going --
# nothing here ever aborts the rest of the script.
run_step() {
  local label="$1" fn="$2" log line
  STEP_DETAIL=""
  STEP_WARNINGS=()
  log="$(mktemp)"

  if "$fn" >"$log" 2>&1; then
    printf '%s✓%s %-24s %s%s%s\n' "$C_OK" "$C_RESET" "$label" "$C_DIM" "$STEP_DETAIL" "$C_RESET"
    STEPS_OK=$((STEPS_OK + 1))
  else
    printf '%s✗%s %-24s %s%s%s\n' "$C_FAIL" "$C_RESET" "$label" "$C_DIM" "${STEP_DETAIL:-failed}" "$C_RESET"
    while IFS= read -r line; do
      [ -n "$line" ] && printf '  %s└─ %s%s\n' "$C_DIM" "$line" "$C_RESET"
    done < "$log"
    STEPS_FAILED=$((STEPS_FAILED + 1))
  fi

  for line in "${STEP_WARNINGS[@]}"; do
    printf '  %s└─ ! %s%s\n' "$C_WARN" "$line" "$C_RESET"
  done

  rm -f "$log"
}

# --- Steps ---

step_prerequisites() {
  if ! command -v brew &>/dev/null; then
    echo "Homebrew not found -- install it first: https://brew.sh"
    return 1
  fi

  local have=() failed=0

  if command -v fzf &>/dev/null; then
    have+=("fzf")
  elif brew install fzf && "$(brew --prefix)/opt/fzf/install" --all --no-bash --no-fish; then
    have+=("fzf (installed)")
  else
    failed=1
  fi

  if command -v gh &>/dev/null; then
    have+=("gh")
  elif brew install gh; then
    have+=("gh (installed)")
  else
    failed=1
  fi

  step_detail "$(join_words "${have[@]}")"
  [ "$failed" -eq 0 ]
}

step_zshrc() {
  touch "$ZSHRC"

  local marker_start="# >>> workshop >>>"
  local marker_end="# <<< workshop <<<"
  local source_line="source \"$WORKSHOP_DIR/shell/init.zsh\""
  local before tmp

  # Strip any prior workshop registration -- both the old unmarked
  # "# workshop" + source-line pairs (which may point at a since-moved
  # checkout) and any previous marker block -- then re-append the canonical
  # one. Keeps re-running this after the repo moves from piling up stale
  # duplicates.
  before="$(cat "$ZSHRC")"
  tmp="$(mktemp)"
  sed -e '/^# workshop$/d' \
      -e '/^source ".*\/shell\/init\.zsh"$/d' \
      -e "/^$marker_start\$/,/^$marker_end\$/d" \
      "$ZSHRC" > "$tmp"
  printf '\n%s\n%s\n%s\n' "$marker_start" "$source_line" "$marker_end" >> "$tmp"

  if [ "$before" = "$(cat "$tmp")" ]; then
    step_detail "already sourced"
    rm -f "$tmp"
  else
    mv "$tmp" "$ZSHRC"
    step_detail "~/.zshrc synced"
  fi
}

step_gitignore() {
  local global_gitignore
  global_gitignore="$(git config --global core.excludesfile)"
  if [ -z "$global_gitignore" ]; then
    global_gitignore="$HOME/.gitignore_global"
    git config --global core.excludesfile "$global_gitignore"
  fi
  global_gitignore="${global_gitignore/#\~/$HOME}"

  touch "$global_gitignore"
  if grep -qxF ".dbtoolsrc" "$global_gitignore" 2>/dev/null; then
    step_detail ".dbtoolsrc already ignored"
  else
    # A file with no trailing newline (common — many editors don't force
    # one) would otherwise get our new line glued onto its last line
    # instead of starting a fresh one, silently corrupting an existing
    # pattern.
    if [ -s "$global_gitignore" ] && [ -n "$(tail -c1 "$global_gitignore")" ]; then
      echo "" >> "$global_gitignore"
    fi
    echo ".dbtoolsrc" >> "$global_gitignore"
    step_detail ".dbtoolsrc added to $global_gitignore"
  fi
}

step_claude_config() {
  mkdir -p "$HOME/.claude"
  if [ -L "$HOME/.claude/CLAUDE.md" ] && [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$WORKSHOP_DIR/ai/CLAUDE.md" ]; then
    step_detail "already symlinked"
  else
    ln -sf "$WORKSHOP_DIR/ai/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    step_detail "~/.claude/CLAUDE.md linked"
  fi
}

step_hammerspoon() {
  local source="$WORKSHOP_DIR/hammerspoon"
  local target="$HOME/.hammerspoon"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    step_detail "already symlinked"
  elif [ -e "$target" ] && [ ! -L "$target" ]; then
    step_detail "skipped -- see hammerspoon/README.md"
    step_warn "$target is a real directory, not a symlink -- migrate it into the repo first (hammerspoon/README.md)"
  else
    ln -sf "$source" "$target"
    step_detail "~/.hammerspoon linked"
  fi
}

step_claude_permissions() {
  if ! command -v jq &>/dev/null; then
    brew install jq || return 1
  fi

  local claude_settings="$HOME/.claude/settings.json"
  local repo_settings="$WORKSHOP_DIR/ai/settings.json"
  local tmp

  [ -f "$claude_settings" ] || echo '{}' > "$claude_settings"

  tmp="$(mktemp)"
  jq -s '
    .[0] * {
      "permissions": (
        (.[0].permissions // {}) * {
          "allow": ((.[0].permissions.allow // []) + (.[1].permissions.allow // []) | unique)
        }
      )
    }
  ' "$claude_settings" "$repo_settings" > "$tmp" && mv "$tmp" "$claude_settings"

  step_detail "$(jq '.permissions.allow | length' "$repo_settings") allowlist entries merged"
}

step_vscode_settings() {
  local vscode_dir="$HOME/Library/Application Support/Code/User"
  mkdir -p "$vscode_dir"

  local linked=() file target source
  for file in settings.json keybindings.json; do
    target="$vscode_dir/$file"
    source="$WORKSHOP_DIR/vscode/$file"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
      linked+=("$file")
    else
      ln -sf "$source" "$target"
      linked+=("$file (linked)")
    fi
  done

  step_detail "$(join_words "${linked[@]}")"
}

# Extensions with a matching folder under vscode/extensions/ are custom,
# unpublished builds (see vscode/README.md) -- `code --install-extension`
# can't resolve them by id since they're not on the Marketplace, they need
# building and packaging into a local .vsix first. Echoes the folder path
# if <publisher>.<name> from its package.json matches; nothing otherwise.
vscode_local_extension_dir() {
  local ext="$1" dir pub name
  for dir in "$WORKSHOP_DIR"/vscode/extensions/*/; do
    [ -f "${dir}package.json" ] || continue
    pub="$(grep -m1 '"publisher"' "${dir}package.json" | sed -E 's/.*"publisher"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
    name="$(grep -m1 '"name"' "${dir}package.json" | sed -E 's/.*"name"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"
    if [ "$pub.$name" = "$ext" ]; then
      printf '%s' "${dir%/}"
      return 0
    fi
  done
  return 1
}

# Mirrors the manual steps documented per-extension in vscode/README.md.
install_local_extension() {
  local ext="$1" dir="$2" vsix

  # @vscode/vsce's dependency chain needs Node 18+ (crashes on Node 16 with
  # "ReadableStream is not defined"); switching via nvm inside this subshell
  # only affects this build, never the shell's or script's own Node version.
  (
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
      \. "$NVM_DIR/nvm.sh"
      nvm use 20 &>/dev/null || nvm use --lts &>/dev/null || true
    fi
    command -v npm &>/dev/null || { echo "npm not found -- install Node.js to build $ext"; exit 1; }
    cd "$dir" && npm install && npm run compile && npm run package
  ) || return 1

  vsix="$(ls -t "$dir"/*.vsix 2>/dev/null | head -1)"
  [ -n "$vsix" ] || { echo "no .vsix produced for $ext"; return 1; }

  code --uninstall-extension "$ext" &>/dev/null || true
  code --install-extension "$vsix" --force &>/dev/null
}

step_vscode_extensions() {
  local extensions_file="$WORKSHOP_DIR/vscode/extensions.txt"

  if [ ! -f "$extensions_file" ]; then
    step_detail "vscode/extensions.txt not found, skipped"
    return 0
  fi

  if ! command -v code &>/dev/null; then
    step_detail "'code' CLI not found"
    return 1
  fi

  local already=0 newly=0 failed=0 ext installed_list local_dir
  installed_list="$(code --list-extensions)"

  while IFS= read -r ext || [ -n "$ext" ]; do
    [ -z "$ext" ] && continue

    if echo "$installed_list" | grep -qi "^$ext$"; then
      already=$((already + 1))
      continue
    fi

    local_dir="$(vscode_local_extension_dir "$ext")"
    if [ -n "$local_dir" ]; then
      if install_local_extension "$ext" "$local_dir"; then
        newly=$((newly + 1))
      else
        failed=$((failed + 1))
        echo "failed to build/install local extension: $ext"
      fi
    elif code --install-extension "$ext" --force &>/dev/null; then
      newly=$((newly + 1))
    else
      failed=$((failed + 1))
      echo "failed to install extension: $ext"
    fi
  done < "$extensions_file"

  step_detail "$newly installed, $already already present"
  [ "$failed" -eq 0 ]
}

step_cmux() {
  local was_missing=0

  if [ ! -d "/Applications/cmux.app" ]; then
    was_missing=1
    brew tap manaflow-ai/cmux || return 1
    brew install --cask cmux || return 1
  fi

  mkdir -p "$HOME/.config/cmux" "$HOME/.config/ghostty"

  # Two fixed links -- not worth an associative array, which the stock
  # macOS /bin/bash (3.2, no Homebrew bash installed) doesn't support: it
  # errors on `declare -A` and silently carries on with a bogus scalar,
  # so a loop over "${!arr[@]}" here would run once with garbage values.
  local target source
  for target in "$HOME/.config/cmux/cmux.json" "$HOME/.config/ghostty/config"; do
    case "$target" in
      *cmux.json) source="$WORKSHOP_DIR/cmux/cmux.json" ;;
      *) source="$WORKSHOP_DIR/cmux/ghostty/config" ;;
    esac
    if ! { [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; }; then
      ln -sf "$source" "$target"
    fi
  done

  if [ "$was_missing" -eq 1 ]; then
    step_detail "installed, config linked"
    step_warn "launch cmux once to finish installing its CLI, then reload your shell"
  else
    step_detail "cmux.json, ghostty config linked"
  fi
}

ALTTAB_DIR="$WORKSHOP_DIR/macos/alt-tab"
ALTTAB_CHECKSUM_FILE="$ALTTAB_DIR/.last-build-checksum"
ALTTAB_LABEL="com.mustafa.alttab-headless"
ALTTAB_PLIST="$HOME/Library/LaunchAgents/$ALTTAB_LABEL.plist"
ALTTAB_EXPECTED_BIN="$ALTTAB_DIR/AltTab.app/Contents/MacOS/AltTab"
# Only these paths feed the build (source, resources, the SwiftPM manifest/dependency, and the
# few loose files build.sh reads directly) -- everything else in this flattened directory
# (README.md, CHANGELOG.md, build.sh, install.sh, AltTab.app, .build/) is docs/scripts/output,
# not build input, and shouldn't trigger a rebuild on its own.
ALTTAB_SOURCE_PATHS=(src resources vendor Sources Package.swift Info.plist alt_tab_macos.entitlements alt-tab-macos-Bridging-Header.h)

alttab_checksum() {
  ( cd "$ALTTAB_DIR" && find "${ALTTAB_SOURCE_PATHS[@]}" -type f ! -name ".DS_Store" \
    -exec shasum {} \; 2>/dev/null | sort | shasum | awk '{print $1}' )
}

# The path baked into the installed LaunchAgent -- a directory move (nothing
# about the source itself) is invisible to alttab_checksum, so this catches
# it: if the running job points at a binary path that no longer matches
# where this repo lives now, that's grounds to reinstall on its own.
alttab_installed_bin() {
  plutil -extract ProgramArguments.0 raw -o - "$ALTTAB_PLIST" 2>/dev/null
}

step_alttab() {
  if ! command -v swift &>/dev/null; then
    step_detail "rebuild failed"
    echo "swift not found -- install the Xcode Command Line Tools (xcode-select --install), then re-run setup.sh"
    return 1
  fi

  local reason=""
  if ! launchctl list | grep -q "$ALTTAB_LABEL"; then
    reason="not installed"
  elif [ "$(alttab_installed_bin)" != "$ALTTAB_EXPECTED_BIN" ]; then
    reason="path changed"
  else
    local current stored
    current="$(alttab_checksum)"
    stored="$(cat "$ALTTAB_CHECKSUM_FILE" 2>/dev/null || echo "")"
    [ "$current" != "$stored" ] && reason="source changed"
  fi

  if [ -z "$reason" ]; then
    step_detail "already up to date"
  else
    if [ "$reason" = "path changed" ] && [ -d "$ALTTAB_DIR/.build" ]; then
      # SwiftPM's module cache bakes in the absolute path it was built at --
      # after a move, that path is gone, so every precompiled module fails
      # with a "compiled with module cache path X but the path is currently
      # Y" error. A stale cache from the old location can't be salvaged.
      echo "repo moved -- clearing stale Swift build cache before rebuilding"
      rm -rf "$ALTTAB_DIR/.build"
    fi

    if (cd "$ALTTAB_DIR" && ./build.sh && ./install.sh); then
      alttab_checksum > "$ALTTAB_CHECKSUM_FILE"
      step_detail "rebuilt -- $reason"
    else
      step_detail "rebuild failed"
      echo "build/install failed -- AltTab not (re)installed"
      return 1
    fi
  fi

  # A separate "open at login" LaunchAgent that macOS/the app itself
  # registers under its real bundle id -- distinct from the one managed
  # above, and not something this repo creates or owns, so it's flagged
  # rather than silently rewritten or deleted.
  local lwouis_plist="$HOME/Library/LaunchAgents/com.lwouis.alt-tab-macos.plist"
  if [ -f "$lwouis_plist" ]; then
    local lwouis_bin
    lwouis_bin="$(plutil -extract Program raw -o - "$lwouis_plist" 2>/dev/null)"
    if [ -n "$lwouis_bin" ] && [ "$lwouis_bin" != "$ALTTAB_EXPECTED_BIN" ]; then
      step_warn "$lwouis_plist points at a stale path -- launchctl unload \"$lwouis_plist\" && rm \"$lwouis_plist\""
    fi
  fi
}

step_scripts() {
  local have=()

  if python3 -c "import pypdf" &>/dev/null 2>&1; then
    have+=("pypdf")
  else
    pip3 install pypdf --quiet || return 1
    have+=("pypdf (installed)")
  fi

  if python3 -c "import send2trash" &>/dev/null 2>&1; then
    have+=("send2trash")
  else
    pip3 install send2trash --quiet || return 1
    have+=("send2trash (installed)")
  fi

  # Executable bits are tracked in git (core.fileMode), so there's nothing
  # to chmod here.
  step_detail "$(join_words "${have[@]}")"
}

# --- Run ---

echo "${C_DIM}── workshop setup ─────────────────────────────────────${C_RESET}"
echo ""

run_step "Prerequisites"      step_prerequisites
run_step "Shell integration"  step_zshrc
run_step "Global gitignore"   step_gitignore
run_step "Claude config"      step_claude_config
run_step "Hammerspoon"        step_hammerspoon
run_step "Claude permissions" step_claude_permissions
run_step "VS Code settings"   step_vscode_settings
run_step "VS Code extensions" step_vscode_extensions
run_step "cmux"                step_cmux
run_step "AltTab (headless)"  step_alttab
run_step "Scripts"             step_scripts

echo ""
echo "${C_DIM}─────────────────────────────────────────────────────────${C_RESET}"
TOTAL=$((STEPS_OK + STEPS_FAILED))
if [ "$STEPS_FAILED" -eq 0 ]; then
  echo "${C_OK}${STEPS_OK}/${TOTAL} steps succeeded.${C_RESET} ${C_DIM}Reload your shell: source ~/.zshrc${C_RESET}"
else
  echo "${C_FAIL}${STEPS_OK}/${TOTAL} steps succeeded, ${STEPS_FAILED} failed.${C_RESET} ${C_DIM}See ✗ above. Reload your shell: source ~/.zshrc${C_RESET}"
fi
