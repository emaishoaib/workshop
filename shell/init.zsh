WORKSHOP="${0:A:h:h}"

export PATH="$WORKSHOP/git:$PATH"

# nvm's default alias is set but plain shells don't act on it on their own —
# without this, new shells silently fall back to whatever version nvm
# happens to have last left on PATH instead of the one you set as default.
command -v nvm &>/dev/null && nvm use default --silent

# AI-tooling secrets (e.g. GEMINI_API_KEY) — not version controlled, see
# ai/README.md and .gitignore
[ -f "$WORKSHOP/ai/local.env" ] && source "$WORKSHOP/ai/local.env"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

source "$WORKSHOP/git/functions.zsh"
source "$WORKSHOP/shell/aliases.zsh"
source "$WORKSHOP/shell/prompt.zsh"
source "$WORKSHOP/db/db-tools.zsh"

# Machine-specific hook implementations — not version controlled, see
# db/README.md and .gitignore
[ -f "$WORKSHOP/db/local.zsh" ] && source "$WORKSHOP/db/local.zsh"
