#!/usr/bin/env bash
# ==============================================================================
# Module: 02-dotfiles
# Description: Tải và thiết lập môi trường Hyprland từ 43PR/dotfiles
# ==============================================================================

MODULE_NAME="dotfiles"
MODULE_DESC="Thiết lập giao diện Hyprland, QuickShell và bộ cấu hình 43PR/dotfiles"

DOTFILES_REPO="https://github.com/43PR/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"

run_module() {
    header "MODULE: $MODULE_DESC"

    info "Kiểm tra mã nguồn dotfiles tại $DOTFILES_DIR..."
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        info "Đang clone repository $DOTFILES_REPO..."
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    else
        substep "Thư mục $DOTFILES_DIR đã tồn tại."
    fi

    if [[ ! -f "$DOTFILES_DIR/install.sh" ]]; then
        error "Không tìm thấy file install.sh trong $DOTFILES_DIR!"
        return 1
    fi

    # Đảm bảo các gói phụ thuộc cần thiết cho Hyprland 43PR
    info "Đang kiểm tra và cài đặt các phụ thuộc chính cho Hyprland..."
    pkg_install hyprland hyprlock hyprpolkitagent quickshell rofi qt6-wayland \
                xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xorg-xwayland \
                awww grim slurp swappy satty imagemagick matugen pipewire pipewire-pulse wireplumber \
                pavucontrol playerctl cliphist wl-clipboard kitty zsh starship eza \
                thunar thunar-volman thunar-archive-plugin gvfs tumbler ffmpegthumbnailer \
                ncdu gtk3 gtk4 adw-gtk-theme papirus-icon-theme gnome-themes-extra nwg-look \
                power-profiles-daemon ttf-jetbrains-mono-nerd ttf-iosevka-nerd ttf-roboto-mono \
                otf-font-awesome

    # Cài đặt gói AUR của 43PR dotfiles
    aur_install papirus-folders hyprmod

    # Chạy script cài đặt của 43PR dotfiles
    info "Đang chạy script cài đặt chính của 43PR dotfiles..."
    (cd "$DOTFILES_DIR" && bash ./install.sh)

    # Đảm bảo hyprpolkitagent service được bật
    systemctl --user enable hyprpolkitagent.service 2>/dev/null || true

    # Đảm bảo SDDM lưu session mặc định là Hyprland
    if [[ -d /var/lib/sddm ]]; then
        info "Cấu hình SDDM chọn phiên đăng nhập Hyprland..."
        sudo bash -c 'printf "[Last]\nSession=hyprland\nUser=%s\n" "$1" > /var/lib/sddm/state.conf' _ "$USER" 2>/dev/null || true
    fi

    # Tự động đồng bộ các tinh chỉnh QuickShell (tắt trong suốt, tắt rung lắc, click outside)
    local SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    if [[ -f "$SETUP_DIR/modules/13-quickshell-tweaks.sh" ]]; then
        info "Áp dụng các tinh chỉnh giao diện QuickShell..."
        bash "$SETUP_DIR/modules/13-quickshell-tweaks.sh" || true
    fi

    success "Module 02-dotfiles hoàn tất!"
}
