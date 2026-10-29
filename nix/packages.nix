{ pkgs, ... }:

{
  # This module is optional. Import it from your own NixOS configuration.
  # Configure users.users.<name>.shell separately if you want Zsh as the login shell.
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    zsh
    git
    tmux
    starship
    fzf
    ripgrep
    bat
    fd
    neovim
    less
    curl
    unzip
    zip
    xdg-utils
    btop
    fastfetch
    eza
    lazygit
  ];
}
