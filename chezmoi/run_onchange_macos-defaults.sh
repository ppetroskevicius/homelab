#!/bin/bash
# Runs whenever this file changes, applying macOS system defaults.
[ "$(uname)" = "Darwin" ] || exit 0

# Mouse: scaled up for large external monitors (43")
defaults write -g com.apple.mouse.scaling 8.0
