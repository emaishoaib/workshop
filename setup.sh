#!/bin/bash

WORKSHOP_DIR="$(cd "$(dirname "$0")" && pwd)"
ZSHRC="$HOME/.zshrc"
GITCONFIG="$HOME/.gitconfig"

# --- Output ---

# LIVE=1 when writing to a terminal: steps then get an animated spinner and
# their grey action lines appear as they happen. Redirected to a file, each
# step just prints its finished block, with no escape codes.
if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_FAIL=$'\033[31m'; C_WARN=$'\033[33m'
  C_DIM=$'\033[2m'; C_RESET=$'\033[0m'
  LIVE=1
else
  C_OK=""; C_FAIL=""; C_WARN=""; C_DIM=""; C_RESET=""
  LIVE=0
fi

STEPS_OK=0
STEPS_FAILED=0
STEP_DIR=""
STEP_PID=""
SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

# Each step runs as a background job (see run_step), so these write to files
# in STEP_DIR instead of setting variables -- a variable set inside the
# background job would never reach the main script that does the printing.
step_detail() { printf '%s' "$1" > "$STEP_DIR/detail"; }
step_warn() { printf '%s\n' "$1" >> "$STEP_DIR/warnings"; }
step_action() { printf '%s\n' "$1" >> "$STEP_DIR/actions"; }

# Call right before anything that may ask for your password -- a Homebrew
# cask install can, through sudo. From then on the spinner stops redrawing,
# so it can't overwrite or garble the password prompt. Waits until the main
# script has printed every action line so far, so none lands after the prompt.
step_pause_live() {
  : > "$STEP_DIR/paused"
  [ "$LIVE" -eq 1 ] || return 0
  while [ ! -f "$STEP_DIR/paused_ack" ]; do sleep 0.05; done
}

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

# Background jobs ignore Ctrl-C in a script, so without this an interrupted
# setup would leave the current step (and whatever brew/npm it started)
# running. Also puts the cursor back, since the spinner hides it.
on_exit() {
  if [ -n "$STEP_PID" ]; then
    pkill -TERM -P "$STEP_PID" 2>/dev/null
    kill "$STEP_PID" 2>/dev/null
  fi
  [ "$LIVE" -eq 1 ] && printf '\033[?25h'
}
trap on_exit EXIT
trap 'exit 130' INT TERM

# <mark> <label> [detail] -- the step's header line, without a newline.
print_header() {
  printf '%s %-24s %s%s%s' "$1" "$2" "$C_DIM" "$3" "$C_RESET"
}

# <connector> <color> <text> -- one indented line under a header.
print_sub() {
  printf '  %s%s %s%s\n' "$2" "$1" "$3" "$C_RESET"
}

# Runs one step. Its grey action lines (step_action) are shown as they
# happen, but the underlying tools' own output (brew, npm, swift...) goes to
# a log that's only printed if the step fails. A failed step never aborts
# the rest of the script.
#
# In LIVE mode the header is printed first with a spinner, and redrawn in
# place -- by moving the cursor up past the action lines printed since --
# until the step finishes and it becomes a ✓ or ✗.
#
# The action lines are only kept for a step that failed. A successful step
# collapses to its one header line (plus any warnings, which ask you to do
# something), so a finished run reads as one line per step.
run_step() {
  local label="$1" fn="$2"
  local shown=0 frame=0 paused=0 total status cols max detail_max line mark detail
  local trailing=() colors=()

  STEP_DIR="$(mktemp -d)"
  : > "$STEP_DIR/actions"

  # The header goes out before the step starts, so nothing the step prints
  # straight to the terminal (a password prompt) can land ahead of it.
  if [ "$LIVE" -eq 1 ]; then
    # Asks the terminal itself: `tput cols` inside $(...) sees a pipe, not
    # the terminal, and always falls back to 80.
    cols="$(stty size </dev/tty 2>/dev/null | awk '{print $2}')"
    [ -n "$cols" ] && [ "$cols" -gt 0 ] 2>/dev/null || cols=80
    # Action lines and the header's status text are cut to the terminal
    # width: a line that wrapped onto a second row would throw off the
    # cursor-up count used for the redraw. 28 = the mark, label column and
    # spaces before the status text.
    max=$((cols - 6))
    detail_max=$((cols - 28))
    [ "$detail_max" -lt 0 ] && detail_max=0
    printf '\033[?25l'
    print_header "${SPINNER_FRAMES[0]}" "$label"
    printf '\n'
  fi

  "$fn" >"$STEP_DIR/log" 2>&1 &
  STEP_PID=$!

  if [ "$LIVE" -eq 1 ]; then
    while :; do
      total=$(wc -l < "$STEP_DIR/actions")
      while [ "$shown" -lt "$total" ]; do
        shown=$((shown + 1))
        line="$(sed -n "${shown}p" "$STEP_DIR/actions")"
        print_sub '├─' "$C_DIM" "${line:0:$max}"
      done

      kill -0 "$STEP_PID" 2>/dev/null || break

      if [ "$paused" -eq 0 ] && [ -f "$STEP_DIR/paused" ]; then
        paused=1
        # Swap the spinner for a still marker, since it stops animating now.
        printf '\033[%dA\r' $((shown + 1))
        print_header "…" "$label"
        printf '\033[K\033[%dB\r' $((shown + 1))
        : > "$STEP_DIR/paused_ack"
      fi
      if [ "$paused" -eq 0 ]; then
        frame=$(( (frame + 1) % ${#SPINNER_FRAMES[@]} ))
        printf '\033[%dA\r' $((shown + 1))
        print_header "${SPINNER_FRAMES[$frame]}" "$label"
        printf '\033[K\033[%dB\r' $((shown + 1))
      fi
      sleep 0.1
    done
  fi

  wait "$STEP_PID"
  status=$?
  STEP_PID=""

  # A step can write its last action line and exit between the loop's final
  # read and its "still running?" check -- print any such stragglers now.
  if [ "$LIVE" -eq 1 ]; then
    total=$(wc -l < "$STEP_DIR/actions")
    while [ "$shown" -lt "$total" ]; do
      shown=$((shown + 1))
      line="$(sed -n "${shown}p" "$STEP_DIR/actions")"
      print_sub '├─' "$C_DIM" "${line:0:$max}"
    done
  fi

  detail="$(cat "$STEP_DIR/detail" 2>/dev/null)"
  if [ "$status" -eq 0 ]; then
    mark="${C_OK}✓${C_RESET}"
    STEPS_OK=$((STEPS_OK + 1))
  else
    mark="${C_FAIL}✗${C_RESET}"
    detail="${detail:-failed}"
    STEPS_FAILED=$((STEPS_FAILED + 1))
    while IFS= read -r line; do
      [ -n "$line" ] && trailing+=("$line") && colors+=("$C_DIM")
    done < "$STEP_DIR/log"
  fi
  if [ -f "$STEP_DIR/warnings" ]; then
    while IFS= read -r line; do
      trailing+=("! $line") && colors+=("$C_WARN")
    done < "$STEP_DIR/warnings"
  fi

  if [ "$LIVE" -eq 1 ] && [ "$paused" -eq 0 ] && [ "$status" -eq 0 ]; then
    # Back up to the header and clear everything from there down, taking the
    # action lines with it, then print the finished header in its place.
    printf '\033[%dA\r\033[J' $((shown + 1))
    print_header "$mark" "$label" "${detail:0:$detail_max}"
    printf '\n'
  elif [ "$LIVE" -eq 1 ] && [ "$paused" -eq 0 ]; then
    printf '\033[%dA\r' $((shown + 1))
    print_header "$mark" "$label" "${detail:0:$detail_max}"
    printf '\033[K\033[%dB\r' $((shown + 1))
    # The last action line was drawn as ├─ while more might follow. If
    # nothing else comes under it, redraw it as the closing └─.
    if [ "$shown" -gt 0 ] && [ "${#trailing[@]}" -eq 0 ]; then
      line="$(sed -n "${shown}p" "$STEP_DIR/actions")"
      printf '\033[1A\r'
      print_sub '└─' "$C_DIM" "${line:0:$max}"
    fi
  else
    # Not live, or paused: a password prompt may have been printed below the
    # header, so it can't safely be redrawn or cleared in place. Print the
    # finished header as a new line instead (plus, when not live and the
    # step failed, the action lines, which weren't printed while it ran).
    print_header "$mark" "$label" "$detail"
    printf '\n'
    if [ "$LIVE" -eq 0 ] && [ "$status" -ne 0 ]; then
      local i=0
      while IFS= read -r line; do
        i=$((i + 1))
        if [ "$i" -eq "$(wc -l < "$STEP_DIR/actions")" ] && [ "${#trailing[@]}" -eq 0 ]; then
          print_sub '└─' "$C_DIM" "$line"
        else
          print_sub '├─' "$C_DIM" "$line"
        fi
      done < "$STEP_DIR/actions"
    fi
  fi

  local n=${#trailing[@]} j
  for ((j = 0; j < n; j++)); do
    if [ "$j" -eq $((n - 1)) ]; then
      print_sub '└─' "${colors[$j]}" "${trailing[$j]}"
    else
      print_sub '├─' "${colors[$j]}" "${trailing[$j]}"
    fi
  done

  [ "$LIVE" -eq 1 ] && printf '\033[?25h'
  rm -rf "$STEP_DIR"
}

# --- Steps ---

# Only checks, never runs `xcode-select --install` itself -- that opens a
# macOS dialog, and the user should choose when to go through it.
# `xcode-select -p` just prints the install path (or fails), no dialog.
step_xcode_clt() {
  local path
  if path="$(xcode-select -p 2>/dev/null)"; then
    step_action "Checking for Xcode Command Line Tools: found at $path"
    step_detail "installed"
    return 0
  fi

  step_action "Checking for Xcode Command Line Tools: not found"
  step_detail "not installed"
  step_warn "run: xcode-select --install"
  step_warn "then re-run: bash setup.sh"
  return 1
}

# Installs <command> with brew if it isn't found, saying which it was either
# way. Adds it to the caller's `have` array (bash functions can see their
# caller's local variables) for the step's summary line.
brew_ensure() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then
    step_action "Checking for $cmd: installed"
    have+=("$cmd")
    return 0
  fi

  step_action "Checking for $cmd: not installed -- installing with brew"
  brew install "$cmd" || return 1
  have+=("$cmd (installed)")
}

step_prerequisites() {
  if ! command -v brew &>/dev/null; then
    step_action "Checking for Homebrew: not found"
    echo "Homebrew not found -- install it first: https://brew.sh"
    return 1
  fi
  step_action "Checking for Homebrew: found"

  local have=() failed=0

  if command -v fzf &>/dev/null; then
    step_action "Checking for fzf: installed"
    have+=("fzf")
  else
    step_action "Checking for fzf: not installed -- installing with brew"
    if brew install fzf; then
      step_action "Running fzf's own installer (adds its key bindings and completion to ~/.zshrc)"
      if "$(brew --prefix)/opt/fzf/install" --all --no-bash --no-fish; then
        have+=("fzf (installed)")
      else
        failed=1
      fi
    else
      failed=1
    fi
  fi

  brew_ensure gh || failed=1

  step_detail "$(join_words "${have[@]}")"
  [ "$failed" -eq 0 ]
}

# Pinned for the same reason as VIDEO_VISION_VERSION below: the install
# script runs straight from the network, so bump this only after reviewing
# what changed upstream (https://github.com/nvm-sh/nvm/releases).
NVM_VERSION="v0.40.7"

# nvm doesn't support being installed through Homebrew, so this uses nvm's
# own install script. That script also adds the lines that load nvm to
# ~/.zshrc. An existing default Node version is left alone -- only a machine
# with no default gets the current LTS.
step_node() {
  local installed=""

  if [ -s "$HOME/.nvm/nvm.sh" ]; then
    step_action "Checking for nvm: installed"
  else
    step_action "Checking for nvm: not installed -- running nvm's $NVM_VERSION install script (it also adds nvm to ~/.zshrc)"
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh" | bash || return 1
    installed="nvm installed, "
  fi

  # A subshell, so loading nvm here never changes the PATH of later steps.
  (
    export NVM_DIR="$HOME/.nvm"
    \. "$NVM_DIR/nvm.sh" || exit 1
    if [ "$(nvm version default)" = "N/A" ]; then
      step_action "Checking for a default Node version: none -- installing the current LTS with nvm"
      nvm install --lts || exit 1
      step_action "Making it nvm's default"
      nvm alias default 'lts/*' || exit 1
      step_detail "${installed}default node $(nvm version default) (installed)"
    else
      step_action "Checking for a default Node version: $(nvm version default)"
      step_detail "${installed}default node $(nvm version default)"
    fi
  )
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
    step_action "Checking ~/.zshrc for the workshop block: up to date"
    step_detail "already sourced"
    rm -f "$tmp"
  else
    step_action "Checking ~/.zshrc for the workshop block: missing or outdated -- rewriting it"
    mv "$tmp" "$ZSHRC"
    step_detail "~/.zshrc synced"
  fi
}

step_gitignore() {
  local global_gitignore
  global_gitignore="$(git config --global core.excludesfile)"
  if [ -z "$global_gitignore" ]; then
    global_gitignore="$HOME/.gitignore_global"
    step_action "Checking git for a global gitignore: none set -- registering ~/.gitignore_global"
    git config --global core.excludesfile "$global_gitignore"
  else
    step_action "Checking git for a global gitignore: $global_gitignore"
  fi
  global_gitignore="${global_gitignore/#\~/$HOME}"

  touch "$global_gitignore"
  if grep -qxF ".dbtoolsrc" "$global_gitignore" 2>/dev/null; then
    step_action "Checking it for .dbtoolsrc: already listed"
    step_detail ".dbtoolsrc already ignored"
  else
    step_action "Checking it for .dbtoolsrc: missing -- adding it"
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

step_hammerspoon() {
  local source="$WORKSHOP_DIR/hammerspoon"
  local target="$HOME/.hammerspoon"
  local installed=""

  if [ -d "/Applications/Hammerspoon.app" ]; then
    step_action "Checking for Hammerspoon: installed"
  else
    step_action "Checking for Hammerspoon: not installed -- installing with brew (it may ask for your password)"
    step_pause_live
    brew install --cask hammerspoon || return 1
    installed="installed, "
    step_warn "open Hammerspoon once and grant it Accessibility access (System Settings -> Privacy & Security) -- its hotkeys don't fire without it"
  fi

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    step_action "Checking ~/.hammerspoon: already linked to hammerspoon/"
    step_detail "${installed}already symlinked"
  elif [ -e "$target" ] && [ ! -L "$target" ]; then
    step_action "Checking ~/.hammerspoon: a real folder, not a link -- leaving it alone"
    step_detail "${installed}skipped linking -- see hammerspoon/README.md"
    step_warn "$target is a real directory, not a symlink -- migrate it into the repo first (hammerspoon/README.md)"
  else
    step_action "Linking ~/.hammerspoon to hammerspoon/"
    ln -sf "$source" "$target"
    step_detail "${installed}~/.hammerspoon linked"
  fi
}

BETTERMOUSE_CONFIG="$WORKSHOP_DIR/macos/bettermouse/better_mouse_config.plist"
BETTERMOUSE_PREFS="$HOME/Library/Preferences/com.naotanhaocan.BetterMouse.plist"

# True when every settings section in the repo export has the same value in
# BetterMouse's live preferences. The live file also holds things the export
# doesn't (window positions, update checks, the license key), so only the
# export's own keys are compared. Its "ver" key is skipped: the live file
# stores that as "version" instead.
bettermouse_config_applied() {
  python3 - "$BETTERMOUSE_CONFIG" "$BETTERMOUSE_PREFS" <<'PY'
import plistlib, sys
with open(sys.argv[1], "rb") as f:
    repo = plistlib.load(f)
try:
    with open(sys.argv[2], "rb") as f:
        live = plistlib.load(f)
except FileNotFoundError:
    sys.exit(1)
sys.exit(0 if all(k in live and live[k] == v for k, v in repo.items() if k != "ver") else 1)
PY
}

# BetterMouse has no command for importing settings, and writing its
# preferences file directly would risk the license key stored in it -- so,
# like the Chrome step, this only gets you to the one manual click.
step_bettermouse() {
  local installed=""

  if [ -d "/Applications/BetterMouse.app" ]; then
    step_action "Checking for BetterMouse: installed"
  else
    step_action "Checking for BetterMouse: not installed -- installing with brew (it may ask for your password)"
    step_pause_live
    brew install --cask bettermouse || return 1
    installed="installed, "
  fi

  if bettermouse_config_applied; then
    step_action "Comparing the repo's export with BetterMouse's live settings: they match"
    step_detail "${installed}config applied"
    return 0
  fi

  step_action "Comparing the repo's export with BetterMouse's live settings: they differ"
  step_action "Copying the export's path to the clipboard"
  printf '%s' "$BETTERMOUSE_CONFIG" | pbcopy 2>/dev/null
  step_action "Opening BetterMouse"
  open -a "BetterMouse" 2>/dev/null
  step_detail "${installed}config not imported -- path copied to clipboard"
  # The path is spelled out too, because a later step (Chrome) can replace
  # the clipboard before you get to this one.
  step_warn "BetterMouse: open its settings, choose import, press Cmd+Shift+G in the file picker and paste $BETTERMOUSE_CONFIG"
}

# The native installer typically lands the CLI in ~/.local/bin, which isn't
# guaranteed to be on this script's own PATH (setup.sh runs as bash, not
# through the interactive zsh init chain) -- so check that explicit location
# too, not just PATH.
find_claude_bin() {
  if command -v claude &>/dev/null; then
    command -v claude
  elif [ -x "$HOME/.local/bin/claude" ]; then
    echo "$HOME/.local/bin/claude"
  fi
}

# Either the CLI or the desktop app counts -- the desktop app's Code tab runs
# Claude Code underneath and reads the same ~/.claude folder. setup.sh never
# installs Claude itself; the Claude steps just skip when neither is present.
claude_installed() {
  local bin
  bin="$(find_claude_bin)"
  if [ -n "$bin" ]; then
    step_action "Checking for Claude: CLI found at $bin"
  elif [ -d "/Applications/Claude.app" ]; then
    step_action "Checking for Claude: desktop app found"
  else
    step_action "Checking for Claude: neither the CLI nor the desktop app found"
    return 1
  fi
}

claude_config() {
  mkdir -p "$HOME/.claude"
  if [ -L "$HOME/.claude/CLAUDE.md" ] && [ "$(readlink "$HOME/.claude/CLAUDE.md")" = "$WORKSHOP_DIR/ai/CLAUDE.md" ]; then
    step_action "Checking ~/.claude/CLAUDE.md: already linked to ai/CLAUDE.md"
  else
    step_action "Linking ~/.claude/CLAUDE.md to ai/CLAUDE.md"
    ln -sf "$WORKSHOP_DIR/ai/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  fi
}

claude_skills() {
  local source="$WORKSHOP_DIR/ai/skills"
  local target="$HOME/.claude/skills"

  mkdir -p "$HOME/.claude"

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    step_action "Checking ~/.claude/skills: already linked to ai/skills"
  elif [ -e "$target" ] && [ ! -L "$target" ]; then
    step_action "Checking ~/.claude/skills: a real folder, not a link -- leaving it alone"
    step_warn "$target already exists as a real directory, not a symlink -- move its contents into $source first, then re-run setup.sh"
  else
    step_action "Linking ~/.claude/skills to ai/skills"
    ln -sf "$source" "$target"
  fi
}

claude_permissions() {
  local have=()
  brew_ensure jq || return 1

  local claude_settings="$HOME/.claude/settings.json"
  local repo_settings="$WORKSHOP_DIR/ai/settings.json"
  local tmp

  if [ ! -f "$claude_settings" ]; then
    step_action "Creating an empty ~/.claude/settings.json"
    echo '{}' > "$claude_settings"
  fi

  step_action "Merging the $(jq '.permissions.allow | length' "$repo_settings") allowlist entries from ai/settings.json into ~/.claude/settings.json"
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
}

video_vision_prereqs() {
  local have=() failed=0

  brew_ensure ffmpeg || failed=1
  brew_ensure yt-dlp || failed=1

  [ "$failed" -eq 0 ]
}

# Pinned deliberately, not "@latest" -- bump this only after reviewing what
# changed upstream (https://github.com/jordanrendric/claude-video-vision),
# then re-run setup.sh. See ai/README.md for why this is pinned-and-local
# rather than npx-on-demand.
VIDEO_VISION_VERSION="1.3.2"
VIDEO_VISION_DIR="$HOME/.claude-video-vision/vendor/$VIDEO_VISION_VERSION"

# Downloads the exact published npm release (not upstream git -- npm's
# tarball ships pre-compiled JS, so this needs no TypeScript build step) and
# installs its runtime dependencies. Runs in a subshell that explicitly
# loads nvm, same reasoning as install_local_extension above: setup.sh's own
# PATH has no guarantee of finding node/npm otherwise.
fetch_video_vision() {
  if [ -f "$VIDEO_VISION_DIR/dist/index.js" ]; then
    step_action "Checking for claude-video-vision v$VIDEO_VISION_VERSION: already downloaded"
    return 0
  fi
  step_action "Checking for claude-video-vision v$VIDEO_VISION_VERSION: not downloaded -- fetching it from npm"

  local tmp
  tmp="$(mktemp -d)"

  (
    export NVM_DIR="$HOME/.nvm"
    if [ -s "$NVM_DIR/nvm.sh" ]; then
      \. "$NVM_DIR/nvm.sh"
      nvm use default &>/dev/null || nvm use --lts &>/dev/null || true
    fi
    command -v npm &>/dev/null || { echo "npm not found -- install Node.js first"; exit 1; }

    cd "$tmp" \
      && npm pack "claude-video-vision@$VIDEO_VISION_VERSION" --silent \
      && tar -xzf ./*.tgz \
      && mkdir -p "$VIDEO_VISION_DIR" \
      && cp -R package/. "$VIDEO_VISION_DIR/" \
      && cd "$VIDEO_VISION_DIR" \
      && step_action "Installing its dependencies with npm" \
      && npm install --omit=dev --silent
  )
  local status=$?
  rm -rf "$tmp"
  return $status
}

# claude mcp has no documented "does this exist" check this script relies
# on -- so it just removes any prior registration first (ignoring failure if
# there wasn't one) and re-adds, rather than trying to detect and diff a
# potentially-stale one (e.g. still pointing at the old npx-based command).
video_vision_mcp() {
  local claude_bin="$1"

  fetch_video_vision || return 1

  step_action "Removing any existing claude-video-vision registration"
  "$claude_bin" mcp remove claude-video-vision --scope user &>/dev/null || true
  step_action "Registering claude-video-vision with claude mcp add, at user scope"
  "$claude_bin" mcp add --transport stdio claude-video-vision --scope user \
    -- node "$VIDEO_VISION_DIR/dist/index.js"
}

video_vision_key() {
  local local_env="$WORKSHOP_DIR/ai/local.env"
  if [ -n "$GEMINI_API_KEY" ]; then
    step_action "Checking for GEMINI_API_KEY: set in your environment"
    return 0
  fi
  if [ -f "$local_env" ] && grep -q "^export GEMINI_API_KEY=" "$local_env"; then
    step_action "Checking for GEMINI_API_KEY: set in ai/local.env"
    return 0
  fi

  step_action "Checking for GEMINI_API_KEY: not set"
  step_warn "add GEMINI_API_KEY to $local_env (not version controlled) to enable the Gemini backend -- YouTube captions still work without it"
}

# Everything Claude-related, as one step. Nothing here runs unless Claude is
# installed (CLI or desktop app). The video-vision parts also need the CLI
# specifically, since registering an MCP server runs `claude mcp add`. A part
# that fails doesn't stop the parts after it.
step_claude() {
  if ! claude_installed; then
    step_detail "skipped -- Claude not installed"
    return 0
  fi

  local failed=() claude_bin
  claude_config || failed+=("CLAUDE.md")
  claude_skills || failed+=("skills")
  claude_permissions || failed+=("permissions")

  claude_bin="$(find_claude_bin)"
  if [ -z "$claude_bin" ]; then
    step_action "Skipping video-vision: it needs the Claude CLI, and only the desktop app is installed"
  else
    video_vision_prereqs || failed+=("video-vision prereqs")
    video_vision_mcp "$claude_bin" || failed+=("video-vision MCP")
    video_vision_key
  fi

  if [ "${#failed[@]}" -gt 0 ]; then
    step_detail "failed: $(join_words "${failed[@]}")"
    return 1
  fi
  if [ -z "$claude_bin" ]; then
    step_detail "configured, video-vision skipped (no CLI)"
  else
    step_detail "configured, video-vision v$VIDEO_VISION_VERSION"
  fi
}

VSCODE_APP="/Applications/Visual Studio Code.app"

vscode_settings() {
  local vscode_dir="$HOME/Library/Application Support/Code/User"
  mkdir -p "$vscode_dir"

  local file target source
  for file in settings.json keybindings.json; do
    target="$vscode_dir/$file"
    source="$WORKSHOP_DIR/vscode/$file"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
      step_action "Checking VS Code's $file: already linked to vscode/$file"
    else
      step_action "Linking VS Code's $file to vscode/$file"
      ln -sf "$source" "$target" || return 1
    fi
  done
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
  step_action "Installing $ext from the built .vsix"

  vsix="$(ls -t "$dir"/*.vsix 2>/dev/null | head -1)"
  [ -n "$vsix" ] || { echo "no .vsix produced for $ext"; return 1; }

  code --uninstall-extension "$ext" &>/dev/null || true
  code --install-extension "$vsix" --force &>/dev/null
}

# Sets the caller's `ext_result` (bash functions can see their caller's
# local variables) to a short summary for the VS Code step's status text.
vscode_extensions() {
  local extensions_file="$WORKSHOP_DIR/vscode/extensions.txt"

  if [ ! -f "$extensions_file" ]; then
    step_action "Checking for vscode/extensions.txt: not found -- skipping extensions"
    ext_result="no extension list"
    return 0
  fi

  if ! command -v code &>/dev/null; then
    step_action "Checking for the code command: not found -- skipping extensions"
    ext_result="extensions skipped (no code command)"
    step_warn "in VS Code, run \"Shell Command: Install 'code' command in PATH\" from the Command Palette, then re-run: bash setup.sh"
    return 0
  fi

  step_action "Checking for the code command: found"

  local already=0 newly=0 failed=0 ext installed_list local_dir exts
  # --show-versions so local extensions can be compared against their
  # package.json version below -- a bare id match would call a stale local
  # build "already present" and never rebuild it.
  installed_list="$(code --list-extensions --show-versions)"

  # Read every line up front instead of looping with `< "$extensions_file"`
  # held open on stdin -- a subprocess in the loop body (npm install, during
  # a local extension rebuild) inherits that same stdin, and if it so much
  # as peeks at it, the shared read position shifts and corrupts whichever
  # line the loop reads next.
  mapfile -t exts < "$extensions_file"
  step_action "Checking installed extensions against vscode/extensions.txt"

  for ext in "${exts[@]}"; do
    [ -z "$ext" ] && continue

    local_dir="$(vscode_local_extension_dir "$ext")"
    if [ -n "$local_dir" ]; then
      local installed_version local_version
      installed_version="$(echo "$installed_list" | grep -i "^$ext@" | sed -E 's/.*@//')"
      local_version="$(grep -m1 '"version"' "${local_dir}/package.json" | sed -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/')"

      if [ -n "$installed_version" ] && [ "$installed_version" = "$local_version" ]; then
        already=$((already + 1))
        continue
      fi

      step_action "$ext: custom build ${installed_version:-not installed}, repo has $local_version -- building it with npm"
      if install_local_extension "$ext" "$local_dir"; then
        newly=$((newly + 1))
      else
        failed=$((failed + 1))
        echo "failed to build/install local extension: $ext"
      fi
      continue
    fi

    if echo "$installed_list" | grep -qi "^$ext@"; then
      already=$((already + 1))
      continue
    fi

    step_action "$ext: not installed -- installing from the Marketplace"
    if code --install-extension "$ext" --force &>/dev/null; then
      newly=$((newly + 1))
    else
      failed=$((failed + 1))
      echo "failed to install extension: $ext"
    fi
  done

  step_action "$already already installed and up to date, left alone"
  ext_result="$newly extensions installed, $already already present"
  [ "$failed" -eq 0 ]
}

# Both VS Code parts, as one step. setup.sh never installs VS Code itself:
# when it's missing, the whole step is skipped with a single warning.
step_vscode() {
  if [ ! -d "$VSCODE_APP" ]; then
    step_action "Checking for VS Code: not installed"
    step_detail "skipped -- VS Code not installed"
    step_warn "install VS Code, then re-run: bash setup.sh"
    return 0
  fi
  step_action "Checking for VS Code: installed"

  local failed=() ext_result=""
  vscode_settings || failed+=("settings")
  vscode_extensions || failed+=("extensions")

  if [ "${#failed[@]}" -gt 0 ]; then
    step_detail "failed: $(join_words "${failed[@]}")"
    return 1
  fi
  step_detail "settings linked, $ext_result"
}

CHROME_EXT_DIR="$WORKSHOP_DIR/chrome/keepa-lookup"
# Unpacked extensions' filesystem paths live here, not in the plain
# "Preferences" file -- it's plain JSON (tamper-hashed, not encrypted), just
# a separate file from regular settings.
CHROME_PREFS="$HOME/Library/Application Support/Google/Chrome/Default/Secure Preferences"

# Chrome has no CLI for installing an unpacked extension (unlike `code
# --install-extension`), nor for reloading one -- both are deliberately
# click-only, the same protection that blocks silently sideloading one.
# Best available without turning the profile into an enterprise-managed one:
#
# - Not loaded at all: detected by the absolute path showing up verbatim in
#   the profile's Secure Preferences JSON. If missing, open the Load-unpacked
#   screen and put the path on the clipboard.
# - Loaded but stale: Chrome caches the version of the service worker it has
#   registered (service_worker_registration_info.version, next to that same
#   path) -- if that doesn't match manifest.json on disk, source has changed
#   since the last manual reload. Flagged, not fixed: nothing short of the
#   heavier options (a standing remote-debugging port, or a companion
#   extension carrying the broad "management" permission) can click the
#   reload button from a shell script.
step_chrome_keepa_lookup() {
  if [ ! -d "/Applications/Google Chrome.app" ]; then
    step_action "Checking for Google Chrome: not installed"
    step_detail "Chrome not installed, skipped"
    return 0
  fi
  step_action "Checking for Google Chrome: installed"

  if [ ! -f "$CHROME_PREFS" ] || ! grep -qF "$CHROME_EXT_DIR" "$CHROME_PREFS"; then
    step_action "Checking Chrome's profile for keepa-lookup: not loaded"
    step_action "Copying the extension's path to the clipboard"
    printf '%s' "$CHROME_EXT_DIR" | pbcopy 2>/dev/null
    step_action "Opening chrome://extensions"
    open -a "Google Chrome" "chrome://extensions" 2>/dev/null
    step_detail "not loaded yet -- path copied to clipboard"
    step_warn "Chrome: enable Developer mode, click \"Load unpacked\", paste the path (already on your clipboard)"
    return 0
  fi

  step_action "Checking Chrome's profile for keepa-lookup: loaded"

  if ! command -v jq &>/dev/null; then
    step_action "Skipping the version check: jq not installed"
    step_detail "already loaded"
    return 0
  fi

  local disk_version loaded_version
  disk_version="$(jq -r '.version' "$CHROME_EXT_DIR/manifest.json")"
  loaded_version="$(jq -r --arg path "$CHROME_EXT_DIR" '
    .extensions.settings
    | to_entries[]
    | select(.value.path == $path)
    | .value.service_worker_registration_info.version // empty
  ' "$CHROME_PREFS" | head -1)"

  if [ -n "$loaded_version" ] && [ "$loaded_version" != "$disk_version" ]; then
    step_action "Comparing the loaded version with manifest.json: v$loaded_version loaded, v$disk_version on disk"
    step_action "Opening chrome://extensions"
    open -a "Google Chrome" "chrome://extensions" 2>/dev/null
    step_detail "loaded v$loaded_version, disk has v$disk_version"
    step_warn "Chrome: keepa-lookup changed since it was last loaded -- click its reload icon on chrome://extensions"
  else
    step_action "Comparing the loaded version with manifest.json: both v$disk_version"
    step_detail "already loaded, up to date"
  fi
}

# Only checks, never installs: Docker Desktop is a large install, and its
# license needs a paid plan at larger companies -- that's the user's call.
# `docker compose version` works without the Docker daemon running, and
# running isn't needed until ddb/dmig are actually used.
step_docker() {
  if ! command -v docker &>/dev/null; then
    step_action "Checking for docker: not found"
  elif ! docker compose version &>/dev/null; then
    step_action "Checking for docker: found"
    step_action "Checking for docker compose: not found"
  else
    step_action "Checking for docker: found"
    step_action "Checking for docker compose: found"
    step_detail "installed"
    return 0
  fi

  step_detail "not installed"
  step_warn "install Docker (ddb and dmig in db/ need it), then re-run: bash setup.sh"
}

# --- Run ---

echo "${C_DIM}── workshop setup ─────────────────────────────────────${C_RESET}"
echo ""

# Stops here instead of carrying on like every other failed step: git and
# python3, which later steps call, are placeholder commands in /usr/bin until
# the tools are installed, and running one opens the same install dialog
# this check exists to avoid.
run_step "Xcode CLI tools"    step_xcode_clt
if [ "$STEPS_FAILED" -gt 0 ]; then
  echo ""
  echo "${C_DIM}─────────────────────────────────────────────────────────${C_RESET}"
  echo "${C_FAIL}Stopped: install Xcode Command Line Tools, then re-run setup.sh.${C_RESET}"
  exit 1
fi

run_step "Prerequisites"      step_prerequisites
run_step "Node"               step_node
run_step "Shell integration"  step_zshrc
run_step "Global gitignore"   step_gitignore
run_step "Hammerspoon"        step_hammerspoon
run_step "BetterMouse"        step_bettermouse
run_step "Claude"             step_claude
run_step "VS Code"            step_vscode
run_step "Chrome: keepa-lookup" step_chrome_keepa_lookup
run_step "Docker"             step_docker

echo ""
echo "${C_DIM}─────────────────────────────────────────────────────────${C_RESET}"
TOTAL=$((STEPS_OK + STEPS_FAILED))
if [ "$STEPS_FAILED" -eq 0 ]; then
  echo "${C_OK}${STEPS_OK}/${TOTAL} steps succeeded.${C_RESET} ${C_DIM}Reload your shell: source ~/.zshrc${C_RESET}"
else
  echo "${C_FAIL}${STEPS_OK}/${TOTAL} steps succeeded, ${STEPS_FAILED} failed.${C_RESET} ${C_DIM}See ✗ above. Reload your shell: source ~/.zshrc${C_RESET}"
fi
