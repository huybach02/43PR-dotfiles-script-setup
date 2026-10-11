#!/usr/bin/env bash
# ==============================================================================
# Module: 01-system
# Description: Cập nhật hệ thống, cài đặt công cụ nền tảng và cấu hình AUR helper
# ==============================================================================

MODULE_NAME="system"
MODULE_DESC="Hệ thống cơ bản, mirror, base-devel và cấu hình AUR helper (paru)"

run_module() {
    header "MODULE: $MODULE_DESC"

    info "Kiểm tra hệ thống Arch Linux / CachyOS..."
    if [[ ! -f /etc/os-release ]]; then
        error "Không thể xác định hệ điều hành!"
        return 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    if [[ "${ID:-}" != "arch" && "${ID_LIKE:-}" != *arch* ]]; then
        error "Script này chỉ dành cho bản phân phối dựa trên Arch Linux (Arch, CachyOS, EndeavourOS, v.v.)."
        return 1
    fi
    success "Phát hiện hệ điều hành: ${PRETTY_NAME:-Arch Linux}"

    info "Đang đồng bộ cơ sở dữ liệu package..."
    sudo pacman -Sy --noconfirm

    info "Cài đặt các gói công cụ cốt lõi (base-devel, git, curl, wget, jq)..."
    pkg_install base-devel git curl wget jq unzip

    info "Đảm bảo AUR helper sẵn sàng..."
    ensure_aur_helper

    # Cấu hình paru bỏ qua prompt review PKGBUILD để cài đặt tự động
    if [[ "$AUR_HELPER" == "paru" ]]; then
        mkdir -p "$HOME/.config/paru"
        if ! grep -q "SkipReview" "$HOME/.config/paru/paru.conf" 2>/dev/null; then
            printf "[options]\nSkipReview\n" >> "$HOME/.config/paru/paru.conf"
            info "Đã cấu hình paru SkipReview để tự động hóa cài đặt."
        fi
    fi

    success "Module 01-system hoàn tất!"
}
