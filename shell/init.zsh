WORKSHOP="${0:A:h:h}"

export PATH="$WORKSHOP/git:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

source "$WORKSHOP/git/functions.zsh"
source "$WORKSHOP/shell/aliases.zsh"
source "$WORKSHOP/shell/prompt.zsh"

# Not version controlled — see .gitignore
[ -f "$WORKSHOP/local_aliases.zsh" ] && source "$WORKSHOP/local_aliases.zsh"
