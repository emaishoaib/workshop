WORKSHOP="${0:A:h:h}"

export PATH="$WORKSHOP/scripts:$WORKSHOP/git:$PATH"

# cmux installs its CLI inside the app bundle. It's only on PATH automatically
# inside shells launched by cmux itself — add it here so `cmux` also works
# from iTerm2, Terminal.app, etc.
CMUX_BIN="/Applications/cmux.app/Contents/Resources/bin"
[ -d "$CMUX_BIN" ] && export PATH="$CMUX_BIN:$PATH"

# Allow processes cmux didn't spawn itself (other terminals, Raycast, etc.) to
# use the cmux socket — needed for `cmux-goto` and the Raycast extension in
# raycast/. This only takes effect for apps launched AFTER it's set, so quit
# and relaunch cmux once after a fresh clone. See README's cmux/ section for
# the security tradeoff this implies.
if [ "$(launchctl getenv CMUX_SOCKET_MODE 2>/dev/null)" != "allowAll" ]; then
  launchctl setenv CMUX_SOCKET_MODE allowAll
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

source "$WORKSHOP/git/functions.zsh"
source "$WORKSHOP/cmux/functions.zsh"
source "$WORKSHOP/shell/aliases.zsh"
source "$WORKSHOP/shell/prompt.zsh"

# Not version controlled — see .gitignore
[ -f "$WORKSHOP/work_aliases.zsh" ] && source "$WORKSHOP/work_aliases.zsh"
