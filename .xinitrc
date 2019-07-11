#!/bin/sh

[ -f "$HOME/.xprofile" ] && . ~/.xprofile
[[ -f ~/.Xresources ]] && xrdb -merge -I$HOME ~/.Xresources

exec i3
