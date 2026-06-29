WORKSHOP="${0:A:h:h}"

export PATH="$WORKSHOP/scripts:$WORKSHOP/git:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

source "$WORKSHOP/git/functions.zsh"
source "$WORKSHOP/shell/aliases.zsh"
source "$WORKSHOP/docker/aliases.zsh"
