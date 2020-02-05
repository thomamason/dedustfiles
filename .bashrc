#!/bin/bash
stty -ixon # Disable ctrl-s and ctrl-q.
shopt -s autocd #Allows you to cd into directory merely by typing the directory name.
HISTSIZE= HISTFILESIZE= # Infinite history.
export PS1="\[$(tput bold)\]\[$(tput setaf 2)\][\[$(tput setaf 9)\]\u\[$(tput setaf 3)\]@\[$(tput setaf 9)\]\h \[$(tput setaf 4)\]\W\[$(tput setaf 2)\]]\[$(tput setaf 9)\]\\$ \[$(tput sgr0)\]"

function _update_ps1() 

if [[ $TERM != linux && ! $PROMPT_COMMAND =~ _update_ps1 ]]; then
    PROMPT_COMMAND="_update_ps1; $PROMPT_COMMAND"
fi

[ -f "$HOME/.config/shortcutrc" ] && source "$HOME/.config/shortcutrc" # Load shortcut aliases
[ -f "$HOME/.config/aliasrc" ] && source "$HOME/.config/aliasrc"

[[ -f ~/.Xresources ]] && xrdb -merge -I$HOME ~/.Xresources

cat .config/skull
