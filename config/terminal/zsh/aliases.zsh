# Utils & alternatives
if type hub > /dev/null; then
  alias git='hub'
fi

alias info='info --vi-keys'
alias zed='zeditor'
# GNU objdump supports these flags; Apple's objdump does not.
if [[ "$OSTYPE" == linux* ]] && command -v objdump >/dev/null 2>&1; then
  alias objdump='objdump --disassembler-color=extended --visualize-jumps=extended-color'
fi
alias rm="rm -i"
alias sl='ls'

# Linux system diagnostics.
if [[ "$OSTYPE" == linux* ]]; then
  alias jerr='journalctl -p err -b'
  alias ports='ss -tulpen'
  alias mem='free -h'
  alias myip='ip -brief address'
fi

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
