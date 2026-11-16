# Utils & alternatives
if type hub > /dev/null; then
  alias git='hub'
fi

alias info='info --vi-keys'
# GNU objdump supports these flags; Apple's objdump does not.
if [[ "$OSTYPE" == linux* ]] && command -v objdump >/dev/null 2>&1; then
  alias objdump='objdump --disassembler-color=extended --visualize-jumps=extended-color'
fi
alias rm="rm -i"

preview() {
  while true; do
    local file
    file=$(fzf --preview 'bat --color "always" {}' \
               --bind 'ctrl-j:preview-down,ctrl-k:preview-up')
    if [[ -n $file ]]; then
      nvim "$file"
    else
      break
    fi
  done
}

