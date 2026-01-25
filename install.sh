#!/bin/bash

# Ensure safe shell options
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}
ask() { echo -e "${BLUE}[?]${NC} $1"; }

if [[ $EUID -eq 0 ]]; then
  error "Please run this script as a regular user (not root)."
fi

if ! sudo -v; then
  error "This script requires sudo privileges"
fi

# Configuration
DOTFILES_REPO="https://github.com/AhmedElazony/dotfiles.git"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================
# Installation Options (set to true/false)
# ============================================
INSTALL_DEVELOPMENT=true
INSTALL_THEME=true
INSTALL_BROWSERS=true
INSTALL_MEDIA=true
INSTALL_GAMING=false
INSTALL_OFFICE=false
INSTALL_COMMUNICATION=true
INSTALL_NVIDIA=false
INSTALL_AMD=false

# ============================================
# Interactive Selection
# ============================================
select_packages() {
  echo ""
  echo "============================================"
  echo "  Select Optional Package Groups to Install"
  echo "============================================"
  echo ""

  read -p "Install Development Tools (VS Code, Neovim, Docker, etc.)? [Y/n]: " choice
  [[ "$choice" =~ ^[Nn]$ ]] && INSTALL_DEVELOPMENT=false || INSTALL_DEVELOPMENT=true

  read -p "Install Browsers (Firefox, Zen, Brave, Chrome)? [Y/n]: " choice
  [[ "$choice" =~ ^[Nn]$ ]] && INSTALL_BROWSERS=false || INSTALL_BROWSERS=true

  read -p "Install Media Apps (VLC, OBS, GIMP)? [Y/n]: " choice
  [[ "$choice" =~ ^[Nn]$ ]] && INSTALL_MEDIA=false || INSTALL_MEDIA=true

  read -p "Install Gaming (Steam, Lutris, Wine)? [y/N]: " choice
  [[ "$choice" =~ ^[Yy]$ ]] && INSTALL_GAMING=true || INSTALL_GAMING=false

  read -p "Install Office Apps (LibreOffice, Obsidian, Notion)? [Y/n]: " choice
  [[ "$choice" =~ ^[Nn]$ ]] && INSTALL_OFFICE=false || INSTALL_OFFICE=true

  read -p "Install Communication (Discord, Telegram, Slack)? [Y/n]: " choice
  [[ "$choice" =~ ^[Nn]$ ]] && INSTALL_COMMUNICATION=false || INSTALL_COMMUNICATION=true

  # GPU Detection
  echo ""
  log "Detecting GPU..."
  if command -v lspci &>/dev/null; then
    if lspci | grep -i nvidia &>/dev/null; then
      read -p "NVIDIA GPU detected. Install NVIDIA drivers? [Y/n]: " choice
      [[ "$choice" =~ ^[Nn]$ ]] && INSTALL_NVIDIA=false || INSTALL_NVIDIA=true
    fi

    if lspci | grep -i "amd\|radeon" &>/dev/null; then
      read -p "AMD GPU detected. Install AMD drivers? [Y/n]: " choice
      [[ "$choice" =~ ^[Nn]$ ]] && INSTALL_AMD=false || INSTALL_AMD=true
    fi
  else
    warn "lspci not found; skipping automatic GPU detection. Install 'pciutils' or run script after installing it."
  fi

  echo ""
  log "Selected packages:"
  echo "  - Development: $INSTALL_DEVELOPMENT"
  echo "  - Browsers: $INSTALL_BROWSERS"
  echo "  - Media: $INSTALL_MEDIA"
  echo "  - Gaming: $INSTALL_GAMING"
  echo "  - Office: $INSTALL_OFFICE"
  echo "  - Communication: $INSTALL_COMMUNICATION"
  echo "  - NVIDIA Drivers: $INSTALL_NVIDIA"
  echo "  - AMD Drivers: $INSTALL_AMD"
  echo ""

  read -p "Continue with installation? [Y/n]: " confirm
  if [[ "$confirm" =~ ^[Nn]$ ]]; then
    exit 0
  fi
}

check_dependencies() {
  local deps=(git curl sudo)
  for dep in "${deps[@]}"; do
    command -v "$dep" &>/dev/null || error "Missing required command: $dep"
  done
}

# ============================================
# 1. Create Required Directories, Copy Bin Scripts
# ============================================

create_directories() {
  log "Creating required directories..."

  mkdir -p "$HOME/.local/share/wallpapers/spotlight"
  mkdir -p "$HOME/.local/share/IslamicPrayerTimings"
  mkdir -p "$HOME/.config/IslamicPrayerTimings"
  mkdir -p "$HOME/.cache"
  mkdir -p "$HOME/.cache/swww"
  mkdir -p "$HOME/bin"
  mkdir -p "$HOME/Pictures"
  mkdir -p "$HOME/Pictures/Screenshots"
  mkdir -p "$HOME/Pictures/Wallpapers"
  mkdir -p "$HOME/src"
  mkdir -p "$HOME/.config/tmux"
}

copy_bin_scripts() {
  log "Copying bin scripts..."

  if [[ -d "$DOTFILES_DIR/bin" ]]; then
    cp -r "$DOTFILES_DIR/bin/"* "$HOME/bin/"
  fi
}

add_conf_files() {
  log "Adding configuration files..."

  # Copy Electron flags config
  if [[ -f "$DOTFILES_DIR/electron/electron-flags.conf" ]]; then
    cp "$DOTFILES_DIR/electron/electron-flags.conf" "$HOME/.config/"
  fi
}

copy_default_wallpapers() {
  log "Copying default wallpapers..."

  local default_wallpapers_dir="$DOTFILES_DIR/wallpapers"
  local target_dir="$HOME/Pictures/Wallpapers"

  if [[ -d "$default_wallpapers_dir" ]]; then
    cp -r "$default_wallpapers_dir/"* "$target_dir/"
    log "Default wallpapers copied to $target_dir"
  else
    warn "Default wallpapers directory not found at $default_wallpapers_dir"
  fi
}

# ============================================
# 2. Install Required Packages
# ============================================
install_packages() {
  log "Updating system..."
  if [[ ! -d /etc/pacman.d/gnupg ]]; then
    sudo pacman-key --init
    sudo pacman-key --populate archlinux
  fi
  sudo pacman -Syu --noconfirm

  log "Installing packages..."
  # Core Hyprland packages (REQUIRED)
  local hyprland_pkgs=(
    hyprland
    hyprlock
    hypridle
    hyprshot
    xdg-desktop-portal-hyprland
  )

  # Wayland essentials (REQUIRED)
  local wayland_pkgs=(
    waybar
    wofi
    rofi
    swww
    swaync
  )

  # Audio (PipeWire stack - REQUIRED for wpctl)
  local audio_pkgs=(
    pipewire
    pipewire-alsa
    pipewire-pulse
    pipewire-jack
    wireplumber
    pavucontrol
  )

  # Terminal & utilities (REQUIRED)
  local utils_pkgs=(
    alacritty
    zsh
    tmux
    dolphin
    brightnessctl
    playerctl
    wl-clipboard
    networkmanager
    network-manager-applet
    blueman
    jq
    file
    imagemagick
    pacman-contrib
    kdeconnect
    unzip
    zip
    p7zip
    htop
    btop
    fastfetch
    man-db
    less
    tree
    tree-sitter
    ripgrep
    fd
    fzf
    swappy
    grim
    slurp
    polkit-kde-agent
    sddm
    qt5-graphicaleffects
    qt5-quickcontrols
  )

  # Development & build tools (REQUIRED for building modules)
  local dev_pkgs=(
    base-devel
    git
    cmake
    nlohmann-json
    curl
    libnotify
    pciutils
    composer
  )

  # Fonts (REQUIRED)
  local font_pkgs=(
    ttf-jetbrains-mono-nerd
    ttf-fira-code
    noto-fonts
    noto-fonts-emoji
    noto-fonts-cjk
  )

  # AUR packages (REQUIRED)
  local aur_pkgs=(
    lxqt-policykit
    waypaper
    wlogout
    rofi-calc
    rofi-emoji
    tree-sitter-cli
    clipse
  )

  # ============================================
  # OPTIONAL PACKAGE GROUPS
  # ============================================

  # Development Tools
  local dev_tools_pkgs=()
  local dev_tools_aur=()
  if [[ "$INSTALL_DEVELOPMENT" == true ]]; then
    dev_tools_pkgs=(
      neovim
      lazygit
      docker
      docker-compose
      nodejs
      npm
      python
      python-pip
    )
    dev_tools_aur=(
      visual-studio-code-bin # VS Code from AUR (alternative)
      github-cli
      lazydocker
      postman-bin
      dbeaver
    )
  fi

  # Theme packages
  local theme_pkgs=()
  if [[ "$INSTALL_THEME" == true ]]; then
    theme_pkgs=(
      gtk3
      qt5ct
      qt6ct
      qt5
      qt6
      kvantum
      kvantum-theme-materia
      materia-gtk-theme
      breeze-icons
      papirus-icon-theme
      capitaine-cursors
    )
  fi

  # Browsers
  local browser_pkgs=()
  local browser_aur=()
  if [[ "$INSTALL_BROWSERS" == true ]]; then
    browser_pkgs=(
      firefox
    )
    browser_aur=(
      zen-browser-bin
      brave-bin
    )
  fi

  # Media & Entertainment
  local media_pkgs=()
  local media_aur=()
  if [[ "$INSTALL_MEDIA" == true ]]; then
    media_pkgs=(
      vlc
      obs-studio
      gimp
      audacity
    )
  fi

  # Gaming
  local gaming_pkgs=()
  local gaming_aur=()
  if [[ "$INSTALL_GAMING" == true ]]; then
    gaming_pkgs=(
      steam
      lutris
      gamemode
      lib32-gamemode
      mangohud
      lib32-mangohud
      wine
      wine-gecko
      wine-mono
      winetricks
    )
    gaming_aur=(
      heroic-games-launcher-bin
      protonup-qt
      bottles
    )
  fi

  # Office & Productivity
  local office_pkgs=()
  local office_aur=()
  if [[ "$INSTALL_OFFICE" == true ]]; then
    office_pkgs=(
      libreoffice-fresh
      thunderbird
      okular # PDF viewer
      evince # Another PDF viewer
    )
    office_aur=(
      obsidian
      logseq-desktop-bin
    )
  fi

  # Communication
  local comm_pkgs=()
  local comm_aur=()
  if [[ "$INSTALL_COMMUNICATION" == true ]]; then
    comm_pkgs=(
      telegram-desktop
    )
    comm_aur=(
      discord
      teams-for-linux
    )
  fi

  # GPU Drivers
  local gpu_pkgs=()
  if [[ "$INSTALL_NVIDIA" == true ]]; then
    gpu_pkgs+=(
      nvidia
      nvidia-utils
      nvidia-settings
      lib32-nvidia-utils
      egl-wayland
    )
    log "NVIDIA drivers will be installed"
  fi

  if [[ "$INSTALL_AMD" == true ]]; then
    gpu_pkgs+=(
      mesa
      lib32-mesa
      vulkan-radeon
      lib32-vulkan-radeon
      libva-mesa-driver
      lib32-libva-mesa-driver
    )
    log "AMD drivers will be installed"
  fi

  # ============================================
  # Install all packages
  # ============================================

  # Combine all pacman packages
  local all_pacman_pkgs=(
    "${hyprland_pkgs[@]}"
    "${wayland_pkgs[@]}"
    "${audio_pkgs[@]}"
    "${utils_pkgs[@]}"
    "${dev_pkgs[@]}"
    "${font_pkgs[@]}"
    "${dev_tools_pkgs[@]}"
    "${browser_pkgs[@]}"
    "${media_pkgs[@]}"
    "${gaming_pkgs[@]}"
    "${office_pkgs[@]}"
    "${comm_pkgs[@]}"
    "${gpu_pkgs[@]}"
  )

  # Install official packages
  log "Installing official packages..."
  sudo pacman -S --needed --noconfirm "${all_pacman_pkgs[@]}"

  # Install AUR helper if not present
  if ! command -v yay &>/dev/null; then
    log "Installing yay..."
    if [[ ! -d "$HOME/src/yay" ]]; then
      git clone https://aur.archlinux.org/yay.git "$HOME/src/yay"
    fi
    cd "$HOME/src/yay" && makepkg -si --noconfirm
    cd - >/dev/null
  fi

  # Combine all AUR packages
  local all_aur_pkgs=(
    "${aur_pkgs[@]}"
    "${dev_tools_aur[@]}"
    "${browser_aur[@]}"
    "${media_aur[@]}"
    "${gaming_aur[@]}"
    "${office_aur[@]}"
    "${comm_aur[@]}"
  )

  # Install AUR packages
  if [[ ${#all_aur_pkgs[@]} -gt 0 ]]; then
    log "Installing AUR packages..."
    yay -S --needed --noconfirm "${all_aur_pkgs[@]}"
  fi
}

# ============================================
# 3. Create Symlinks
# ============================================
create_symlinks() {
  log "Creating symlinks..."

  local configs=(
    "hypr:$HOME/.config/hypr"
    "waybar:$HOME/.config/waybar"
    "alacritty:$HOME/.config/alacritty"
    "rofi:$HOME/.config/rofi"
    "swaync:$HOME/.config/swaync"
    "wlogout:$HOME/.config/wlogout"
    "waypaper:$HOME/.config/waypaper"
    "swappy:$HOME/.config/swappy"
    "nvim:$HOME/.config/nvim"
    "wofi:$HOME/.config/wofi"
    "gtk/gtk-3.0:$HOME/.config/gtk-3.0"
    "qt/qt5ct:$HOME/.config/qt5ct/"
    "qt/qt6ct:$HOME/.config/qt6ct"
    "kvantum:$HOME/.config/Kvantum"
  )

  for config in "${configs[@]}"; do
    local src="${DOTFILES_DIR}/${config%%:*}"
    local dest="${config##*:}"

    if [[ -e "$dest" && ! -L "$dest" ]]; then
      warn "Backing up existing $dest"
      mv "$dest" "${dest}.backup.$(date +%Y%m%d%H%M%S)"
    fi

    if [[ -d "$src" ]]; then
      mkdir -p "$(dirname "$dest")"
      ln -sfn "$src" "$dest"
      log "Linked $src -> $dest"
    else
      warn "Source $src does not exist, skipping..."
    fi
  done
}

# ============================================
# 4. Setup User Services
# ============================================
setup_services() {
  log "Setting up systemd user services..."

  mkdir -p "$HOME/.config/systemd/user"

  # Copy and enable services
  local services_dir="$DOTFILES_DIR/systemd/user"
  if [[ -d "$services_dir" ]]; then
    for service in "$services_dir"/*.{service,timer}; do
      [[ -f "$service" ]] || continue

      # Replace hardcoded paths with $HOME
      local service_name=$(basename "$service")
      sed "s|/home/[^/]*|$HOME|g" "$service" >"$HOME/.config/systemd/user/$service_name"
      log "Installed $service_name"
    done
  fi
}

# ============================================
# 5. Build Custom Modules
# ============================================
build_modules() {
  log "Building custom modules..."

  # Islamic Prayer Timings module
  local ipt_dir="$DOTFILES_DIR/waybar/modules/Islamic-Prayer-Timings"
  if [[ -d "$ipt_dir" ]]; then
    log "Building Islamic Prayer Timings..."
    mkdir -p "$ipt_dir/build"
    cd "$ipt_dir/build"
    cmake ..
    make -j$(nproc)
    cd - >/dev/null
  fi
}

# ============================================
# 6. Fix Permissions
# ============================================
fix_permissions() {
  log "Fixing script permissions..."

  find "$DOTFILES_DIR" -name "*.sh" -exec chmod +x {} \;
  chmod +x "$HOME/bin/"* 2>/dev/null || true
}

# ============================================
# 7. Setup Tmux
# ============================================
setup_tmux() {
  log "Setting up Tmux configuration..."

  local tmux_src="$DOTFILES_DIR/tmux"
  local tmux_dest="$HOME/.config/tmux"

  if [[ ! -d "$tmux_src" ]]; then
    warn "Tmux config not found at $tmux_src, skipping..."
    return 0
  fi

  if [[ -e "$tmux_dest" && ! -L "$tmux_dest" ]]; then
    warn "Backing up existing $tmux_dest"
    mv "$tmux_dest" "${tmux_dest}.backup.$(date +%Y%m%d%H%M%S)"
  fi

  mkdir -p "$(dirname "$tmux_dest")"
  ln -sfn "$tmux_src" "$tmux_dest"
  log "Linked $tmux_src -> $tmux_dest"
}

# ============================================
# 8. Post-Install Configuration
# ============================================

post_install() {
  log "Running post-install configuration..."

  # Enable lingering for user
  sudo loginctl enable-linger "$USER" || true

  # Set ZSH as default shell
  if [[ "$SHELL" != *"zsh"* ]]; then
    log "Setting ZSH as default shell..."
    if command -v zsh &>/dev/null && [[ "$SHELL" != "$(which zsh)" ]]; then
      chsh -s "$(which zsh)" || warn "Failed to set ZSH as default shell"
    fi
  fi

  # Add bin to PATH in .zshrc if not present
  if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
    echo 'export PATH="$HOME/bin:$PATH"' >>"$HOME/.zshrc"
    log "Added ~/bin to PATH in .zshrc"
  fi

  # Initialize swww cache directory
  mkdir -p "$HOME/.cache/swww"

  # initialize .zshrc
  cp "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"

  # Enable systemd user services
  systemctl --user daemon-reload
  systemctl --user enable hypr-monitor-resume.service 2>/dev/null || true
  systemctl --user enable spotlight-wallpaper.service 2>/dev/null || true
  systemctl --user enable spotlight-wallpaper.timer 2>/dev/null || true

  # Enable system services
  log "Enabling system services..."
  sudo systemctl enable NetworkManager.service 2>/dev/null || true
  sudo systemctl enable bluetooth.service 2>/dev/null || true
  sudo systemctl enable docker.service || true

  # Add user to required groups
  log "Adding user to required groups..."
  sudo usermod -aG video,audio,input,docker "$USER" 2>/dev/null || true

  # Setup NVIDIA environment variables if NVIDIA is installed
  if [[ "$INSTALL_NVIDIA" == true ]] || pacman -Qs nvidia-utils &>/dev/null; then
    log "NVIDIA detected - configuring Hyprland for NVIDIA..."
    mkdir -p "$HOME/.config/hypr"
    if ! grep -q 'LIBVA_DRIVER_NAME' "$HOME/.config/hypr/env.conf" 2>/dev/null; then
      cat >>"$HOME/.config/hypr/env.conf" <<'EOF'

# NVIDIA Configuration
env = LIBVA_DRIVER_NAME,nvidia
env = XDG_SESSION_TYPE,wayland
env = GBM_BACKEND,nvidia-drm
env = __GLX_VENDOR_LIBRARY_NAME,nvidia
env = NVD_BACKEND,direct
EOF
    fi
  fi

  log "Setup complete! Please reboot to start using Hyprland."
}

# ============================================
# 9. Setup SDDM Theme
# ============================================
setup_sddm() {
  log "Setting up SDDM theme..."

  local sddm_theme_dir="/usr/share/sddm/themes/corners"
  local sddm_config_dir="/etc/sddm.conf.d"

  # Install theme
  if [[ -d "$DOTFILES_DIR/sddm/themes/corners" ]]; then
    sudo mkdir -p "$sddm_theme_dir"
    sudo cp -r "$DOTFILES_DIR/sddm/themes/corners/"* "$sddm_theme_dir/"
    log "Installed Corners SDDM theme"
  fi

  # Install config
  if [[ -f "$DOTFILES_DIR/sddm/sddm.conf" ]]; then
    sudo mkdir -p "$sddm_config_dir"
    sudo cp "$DOTFILES_DIR/sddm/sddm.conf" "$sddm_config_dir/sddm.conf"
    log "Installed SDDM config"
  fi

  # Enable SDDM
  sudo systemctl enable sddm.service
  log "SDDM enabled"
}

# ============================================
# Main
# ============================================
main() {
  log "Starting Hyprland environment setup..."
  local arg="${1:-interactive}"

  # Handle command line arguments
  if [[ "${1:-}" == "--minimal" ]]; then
    log "Running minimal installation (core packages only)..."
    INSTALL_DEVELOPMENT=false
    INSTALL_BROWSERS=false
    INSTALL_MEDIA=false
    INSTALL_GAMING=false
    INSTALL_OFFICE=false
    INSTALL_COMMUNICATION=false
  elif [[ "${1:-}" == "--full" ]]; then
    log "Running full installation (all packages)..."
    INSTALL_DEVELOPMENT=true
    INSTALL_BROWSERS=true
    INSTALL_MEDIA=true
    INSTALL_GAMING=true
    INSTALL_OFFICE=true
    INSTALL_COMMUNICATION=true
  elif [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --minimal    Install only core Hyprland packages"
    echo "  --full       Install all packages without prompts"
    echo "  --help, -h   Show this help message"
    echo ""
    echo "Without options, runs interactive mode."
    exit 0
  else
    # Interactive mode
    select_packages
  fi

  check_dependencies || error "Missing required dependencies"
  create_directories || error "Failed to create directories"
  add_conf_files || error "Failed to add configuration files"
  copy_default_wallpapers || error "Failed to copy default wallpapers"
  install_packages || error "Failed to install packages"
  copy_bin_scripts || error "Failed to copy bin scripts"
  create_symlinks || error "Failed to create symlinks"
  setup_services || error "Failed to setup services"
  build_modules || error "Failed to build modules"
  fix_permissions || error "Failed to fix permissions"
  setup_tmux || error "Failed to setup Tmux"
  post_install || error "Failed to run post-install"
  setup_sddm || error "Failed to setup SDDM"

  echo ""
  log "=========================================="
  log "Setup completed successfully!"
  log "=========================================="
  echo ""
  warn "Next steps:"
  echo "  1. Reboot your system: sudo reboot"
  echo "  2. At SDDM login screen, select 'Hyprland' session"
  echo "  3. Edit $DOTFILES_DIR/hypr/hyprland.conf for your monitors"
  echo "  4. Update ~/.config/IslamicPrayerTimings/config with your city"
  echo "  5. Add wallpapers to ~/.local/share/wallpapers/spotlight/"
  echo ""
  if [[ "$INSTALL_NVIDIA" == true ]]; then
    warn "NVIDIA Users: You may need to add 'nvidia_drm.modeset=1' to kernel parameters"
  fi
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
