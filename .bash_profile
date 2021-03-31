#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

# Adds `~/.scripts` and all subdirectories to $PATH
export PATH="$PATH:$(du "$HOME/.local/bin/" | cut -f2 | tr '\n' ':' | sed 's/:*$//')"
export EDITOR="nvim"
export SYSTEMD_EDITOR="nvim"
export TERMINAL="st"
export BROWSER="tabbed -r 2 surf -pe x"
#export BROWSER= "$HOME/.local/bin/surf-open.sh"
export READER="zathura"
export FILE="vifm"
export SUDO_ASKPASS="$HOME/.local/bin/tools/dmenupass"
export GTK2_RC_FILES="$HOME/.config/gtk-2.0/gtkrc-2.0"
export PICO_SDK_PATH="/usr/share/pico-sdk"


[ "$(tty)" = "/dev/tty1" ] && ! pgrep -x i3 >/dev/null && exec startx

# switch escape and caps if tty
sudo -n loadkeys ~/.local/bin/ttymaps.kmap 2>/dev/null
