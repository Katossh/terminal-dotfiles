{ lib, pkgs, ... }:

let
  # These wallpapers are fetched and packaged by nixpkgs. They are not
  # copied into this repository: the source package records their licences.
  wallpaperFiles = {
    "binary-black.png" = pkgs.nixos-artwork.wallpapers.binary-black.gnomeFilePath;
    "binary-blue.png" = pkgs.nixos-artwork.wallpapers.binary-blue.gnomeFilePath;
    "catppuccin-mocha.png" = pkgs.nixos-artwork.wallpapers.catppuccin-mocha.gnomeFilePath;
    "nineish-catppuccin-mocha.png" = pkgs.nixos-artwork.wallpapers.nineish-catppuccin-mocha.gnomeFilePath;
    "simple-dark-gray.png" = pkgs.nixos-artwork.wallpapers.simple-dark-gray.gnomeFilePath;
    "waterfall.png" = pkgs.nixos-artwork.wallpapers.waterfall.gnomeFilePath;
    "moonscape.png" = pkgs.nixos-artwork.wallpapers.moonscape.gnomeFilePath;
  };
in
{
  # NixOS supplies the Niri session, its systemd integration, and portal defaults.
  # Keep display-manager selection in the host configuration.
  programs.niri.enable = true;

  security.polkit.enable = true;
  security.rtkit.enable = true;
  programs.dconf.enable = true;

  # WirePlumber is needed by wpctl for the volume OSD and media controls.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = with pkgs; [
    alacritty
    brightnessctl
    imagemagick
    jq
    kitty
    libnotify
    mako
    papirus-icon-theme
    playerctl
    pavucontrol
    polkit_gnome
    rofi
    swww
    waybar
    wl-clipboard
    xwayland-satellite
  ];

  # The picker scans this directory in addition to personal wallpaper folders.
  # CC-BY-SA wallpapers: binary-black, binary-blue, Catppuccin Mocha,
  # Nineish Catppuccin Mocha, Waterfall, and Moonscape.
  # simple-dark-gray is CC0.
  environment.etc = lib.mapAttrs'
    (filename: source:
      lib.nameValuePair "niri/wallpapers/${filename}" { inherit source; })
    wallpaperFiles;
}
