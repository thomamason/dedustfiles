#!/bin/sh

#this script fixes the x220's jumpy trackpad using commands from the arch wiki
#i think run this from .xprofile ??

sudo udevadm hwdb --update && sudo udevadm control --reload-rules && sudo udevadm trigger
