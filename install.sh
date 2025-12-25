#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
ask() { echo -e "${BLUE}[?]${NC} $1"; }

# Run command as root (works whether already root or needs sudo)
as_root() {
    if [[ $EUID -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# Configuration
DOTFILES_REPO="https://github.com/AhmedElazony/dotfiles.git"
DOTFILES_DIR="$HOME/src/hyprland"

# ============================================
# Installation Options (set to true/false)
# ============================================
INSTALL_DEVELOPMENT=true
INSTALL_BROWSERS=true
INSTALL_MEDIA=true
INSTALL_GAMING=false
INSTALL_OFFICE=true
INSTALL_COMMUNICATION=true

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
    
    read -p "Install Media Apps (VLC, OBS, GIMP, Spotify)? [Y/n]: " choice
    [[ "$choice" =~ ^[Nn]$ ]] && INSTALL_MEDIA=false || INSTALL_MEDIA=true
    
    read -p "Install Gaming (Steam, Lutris, Wine)? [y/N]: " choice
    [[ "$choice" =~ ^[Yy]$ ]] && INSTALL_GAMING=true || INSTALL_GAMING=false
    
    read -p "Install Office Apps (LibreOffice, Obsidian, Notion)? [Y/n]: " choice
    [[ "$choice" =~ ^[Nn]$ ]] && INSTALL_OFFICE=false || INSTALL_OFFICE=true
    
    read -p "Install Communication (Discord, Telegram, Slack)? [Y/n]: " choice
    [[ "$choice" =~ ^[Nn]$ ]] && INSTALL_COMMUNICATION=false || INSTALL_COMMUNICATION=true
    
    echo ""
    log "Selected packages:"
    echo "  - Development: $INSTALL_DEVELOPMENT"
    echo "  - Browsers: $INSTALL_BROWSERS"
    echo "  - Media: $INSTALL_MEDIA"
    echo "  - Gaming: $INSTALL_GAMING"
    echo "  - Office: $INSTALL_OFFICE"
    echo "  - Communication: $INSTALL_COMMUNICATION"
    echo ""
    
    read -p "Continue with installation? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        exit 0
    fi
}

# ============================================
# 1. Install Required Packages
# ============================================
install_packages() {
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
        rofi-wayland
        swww
        wlogout
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
        dolphin
        brightnessctl
        playerctl
        wl-clipboard
        clipse
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
    )
    
    # Development & build tools (REQUIRED for building modules)
    local dev_pkgs=(
        base-devel
        git
        cmake
        nlohmann-json
        curl
        libnotify
    )
    
    # Fonts (REQUIRED)
    local font_pkgs=(
        ttf-jetbrains-mono-nerd
        ttf-fira-code
        ttf-inter
        noto-fonts
        noto-fonts-emoji
        noto-fonts-cjk
    )
    
    # AUR packages (REQUIRED)
    local aur_pkgs=(
        hyprpolkitagent
        waypaper
        rofi-calc
        rofi-emoji
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
            visual-studio-code-bin  # VS Code from AUR (alternative)
            github-cli
            lazydocker
            postman-bin
            dbeaver
        )
    fi

    # Browsers
    local browser_pkgs=()
    local browser_aur=()
    if [[ "$INSTALL_BROWSERS" == true ]]; then
        browser_pkgs=(
            firefox
            chromium
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
            mpv
            obs-studio
            gimp
            kdenlive
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
            okular              # PDF viewer
            evince              # Another PDF viewer
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
    )

    # Install official packages
    log "Installing official packages..."
    sudo pacman -S --needed --noconfirm "${all_pacman_pkgs[@]}"
    
    # Install AUR helper if not present
    if ! command -v yay &> /dev/null; then
        log "Installing yay..."
        git clone https://aur.archlinux.org/yay.git "$HOME/src/yay"
        cd "$HOME/src/yay" && makepkg -si --noconfirm
        cd - > /dev/null
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
# 2. Clone/Update Dotfiles
# ============================================
setup_dotfiles() {
    log "Setting up dotfiles..."
    
    if [[ -d "$DOTFILES_DIR" ]]; then
        log "Updating existing dotfiles..."
        cd "$DOTFILES_DIR" && git pull
    else
        log "Cloning dotfiles..."
        mkdir -p "$(dirname "$DOTFILES_DIR")"
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
        cd "$DOTFILES_DIR"
        git checkout hyprland
        cd - > /dev/null
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
        #"dunst:$HOME/.config/dunst"
        "swaync:$HOME/.config/swaync"
        "wlogout:$HOME/.config/wlogout"
        "waypaper:$HOME/.config/waypaper"
        "swappy:$HOME/.config/swappy"
        "nvim:$HOME/.config/nvim"
        "wofi:$HOME/.config/wofi"
    )
    
    for config in "${configs[@]}"; do
        local src="${DOTFILES_DIR}/${config%%:*}"
        local dest="${config##*:}"
        
        if [[ -e "$dest" && ! -L "$dest" ]]; then
            warn "Backing up existing $dest"
            mv "$dest" "${dest}.backup.$(date +%Y%m%d%H%M%S)"
        fi
        
        if [[ -d "$src" ]]; then
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
            sed "s|/home/ahmedelazony|$HOME|g" "$service" > "$HOME/.config/systemd/user/$service_name"
            log "Installed $service_name"
        done
    fi
    
    systemctl --user daemon-reload
    
    # Enable specific services
    systemctl --user enable --now hypr-monitor-resume.service 2>/dev/null || true
    systemctl --user enable --now spotlight-wallpaper.timer 2>/dev/null || true
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
        cd - > /dev/null
    fi
}

# ============================================
# 6. Create Required Directories, Copy Bin Scripts
# ============================================

create_directories() {
    log "Creating required directories..."
    
    mkdir -p "$HOME/.local/share/wallpapers/spotlight"
    mkdir -p "$HOME/.local/share/IslamicPrayerTimings"
    mkdir -p "$HOME/.config/IslamicPrayerTimings"
    mkdir -p "$HOME/.cache"
    mkdir -p "$HOME/.cache/swww"
    mkdir -p "$HOME/bin"
    mkdir -p "$HOME/Pictures/Screenshots"
    mkdir -p "$HOME/wallpapers"
    mkdir -p "$HOME/src"
}

copy_bin_scripts() {
    log "Copying bin scripts..."
    
    if [[ -d "$DOTFILES_DIR/bin" ]]; then
        cp -r "$DOTFILES_DIR/bin/"* "$HOME/bin/"
    fi
}

# ============================================
# 7. Fix Permissions
# ============================================
fix_permissions() {
    log "Fixing script permissions..."
    
    find "$DOTFILES_DIR" -name "*.sh" -exec chmod +x {} \;
    chmod +x "$HOME/bin/"* 2>/dev/null || true
}

# ============================================
# 8. Post-Install Configuration
# ============================================

post_install() {
    log "Running post-install configuration..."
    
    # Set ZSH as default shell
    if [[ "$SHELL" != *"zsh"* ]]; then
        log "Setting ZSH as default shell..."
        chsh -s /bin/zsh
    fi
    
    # Add bin to PATH in .zshrc if not present
    if ! grep -q 'export PATH="$HOME/bin:$PATH"' "$HOME/.zshrc" 2>/dev/null; then
        echo 'export PATH="$HOME/bin:$PATH"' >> "$HOME/.zshrc"
        log "Added ~/bin to PATH in .zshrc"
    fi
    
    # Initialize swww cache directory
    mkdir -p "$HOME/.cache/swww"
    
    # Enable systemd user services
    systemctl --user daemon-reload
    systemctl --user enable --now hypr-monitor-resume.service 2>/dev/null || true
    systemctl --user enable --now spotlight-wallpaper.service 2>/dev/null || true
    systemctl --user enable --now spotlight-wallpaper.timer 2>/dev/null || true
    
    log "Setup complete! Please log out and log back in to Hyprland."
}

# ============================================
# Main
# ============================================
main() {
    log "Starting Hyprland environment setup..."

    # Handle command line arguments
    if [[ "$1" == "--minimal" ]]; then
        log "Running minimal installation (core packages only)..."
        INSTALL_DEVELOPMENT=false
        INSTALL_BROWSERS=false
        INSTALL_MEDIA=false
        INSTALL_GAMING=false
        INSTALL_OFFICE=false
        INSTALL_COMMUNICATION=false
    elif [[ "$1" == "--full" ]]; then
        log "Running full installation (all packages)..."
        INSTALL_DEVELOPMENT=true
        INSTALL_BROWSERS=true
        INSTALL_MEDIA=true
        INSTALL_GAMING=true
        INSTALL_OFFICE=true
        INSTALL_COMMUNICATION=true
    elif [[ "$1" == "--help" || "$1" == "-h" ]]; then
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
    
    install_packages || error "Failed to install packages"
    setup_dotfiles || error "Failed to setup dotfiles"
    create_directories || error "Failed to create directories"
    copy_bin_scripts || error "Failed to copy bin scripts"
    create_symlinks || error "Failed to create symlinks"
    setup_services || error "Failed to setup services"
    build_modules || error "Failed to build modules"
    fix_permissions || error "Failed to fix permissions"
    post_install || error "Failed to run post-install"
    
    echo ""
    log "=========================================="
    log "Setup completed successfully!"
    log "=========================================="
    echo ""
    warn "Next steps:"
    echo "  1. Edit $DOTFILES_DIR/hypr/hyprland.conf for your monitors"
    echo "  2. Update ~/.config/IslamicPrayerTimings/config with your city"
    echo "  3. Add wallpapers to ~/.local/share/wallpapers/spotlight/"
    echo "  4. Log out and select Hyprland from your display manager"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi