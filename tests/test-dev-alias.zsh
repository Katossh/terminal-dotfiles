#!/usr/bin/env zsh

set -euo pipefail

: "${NIX_ARGS_FILE:?NIX_ARGS_FILE must point to a temporary output file}"

setopt aliases
source "${0:A:h}/../config/terminal/zsh/aliases.zsh"

nix() {
  print -rl -- "$@" > "$NIX_ARGS_FILE"
}

dev

expected=$'develop\ngithub:Katossh/shiny-rotary-phone#general'
actual=$(< "$NIX_ARGS_FILE")

if [[ "$actual" != "$expected" ]]; then
  print -u2 -- "Unexpected arguments passed by dev alias:"
  print -u2 -- "$actual"
  exit 1
fi

print -- "Zsh dev alias passes the flake reference as one literal argument."
