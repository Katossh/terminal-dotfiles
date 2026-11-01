# Initialize Starship with the configuration linked by dots.
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
else
    # Keep config-only installs usable until Starship is installed.
    PROMPT='%F{blue}%1~%f %F{%(?.green.red)}❯%f '
fi
