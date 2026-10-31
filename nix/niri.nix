{ pkgs, ... }:

{
  # Keep display-manager selection in the host configuration. This module
  # only enables the Niri session and installs its companion applications.
  programs.niri.enable = true;

  security.polkit.enable = true;
  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    brightnessctl
    jq
    kitty
    libnotify
    mako
    playerctl
    polkit_gnome
    pavucontrol
    rofi
    swww
    waybar
    wl-clipboard
    xwayland-satellite
  ];
}
