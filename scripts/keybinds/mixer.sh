#!/bin/bash

#-------------------------------------------------------
# Script to toggle Pavucontrol
# Window rules handle floating, sizing, and centering
#-------------------------------------------------------

if pgrep -x "pavucontrol-qt" >/dev/null; then
    killall pavucontrol-qt
else
    pavucontrol-qt &
fi