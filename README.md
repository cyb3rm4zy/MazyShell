# MazyShell
A powerful yet simple UI overlay made for Hyprland &amp; Niri using Quickshell

>[!WARNING]
>This project is in early stage development

>[!NOTE]
> This project has only been tested on Arch Linux running Hyprland & Niri, however other distros should work (if you can figure out dependencies) but are not officially supported.

# Dependencies
- quickshell-git (AUR)
- hyprland OR niri
- hyprsunset
- hyprlock OR swaylock
- brightnessctl
- wireguard-tools
- networkmanager
- bluez
- btop OR htop
- upower
- power-profiles-daemon (for power mode switching)
- ttf-jetbrains-mono-nerd (for icons)
- pipewire
- pipewire-pulse
- wireplumber
- xdgdesktopportal
`paru -S quickshell-git`
`sudo pacman -S hyprland hyprsunset hyprlock brightnessctl wireguard-tools networkmanager bluez btop upower power-profiles-daemon ttf-jetbrains-mono-nerd pipewire pipewire-pulse wireplumber xdgdesktopportal`
`sudo systemctl enable --now power-profiles-daemon bluetooth

# Installation (After Dependencies)
1. Create new quickshell directory:
`mkdir ~/.config/quickshell`
2. Move into directory:
`cd ~/.config/quickshell`
3. Clone the repo:
`git clone https://github.com/cyb3rm4zy/MazyShell.git`
4. Run quickshell with MazyShell config:
`QT_QPA_PLATFORMTHEME=xdgdesktopportal qs -c MazyShell`
5. Add to hyprland config:
`exec-once = QT_QPA_PLATFORMTHEME=xdgdesktopportal qs -c MazyShell`
