WORKSHOP="${0:A:h:h}"

export PATH="$WORKSHOP/scripts:$WORKSHOP/git:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

source "$WORKSHOP/git/functions.zsh"
source "$WORKSHOP/shell/aliases.zsh"
source "$WORKSHOP/shell/prompt.zsh"

# Not version controlled — see .gitignore
[ -f "$WORKSHOP/work_aliases.zsh" ] && source "$WORKSHOP/work_aliases.zsh"
