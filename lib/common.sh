#!/usr/bin/env bash
# ==============================================================================
# Setup Framework - Common Utilities & Helpers
# ==============================================================================

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Output formatting helpers
header() {
    printf "\n${BOLD}${CYAN}================================================================${NC}\n"
    printf "${BOLD}${CYAN}  %s${NC}\n" "$1"
    printf "${BOLD}${CYAN}================================================================${NC}\n\n"
}

info() {
    printf "${BLUE}[INFO]${NC} %s\n" "$1"
}

success() {
    printf "${GREEN}[DONE]${NC} %s\n" "$1"
}

warn() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

substep() {
    printf "  ${PURPLE}➜${NC} %s\n" "$1"
}

# Ensure script is NOT run as root directly
check_non_root() {
    if [[ "${EUID}" -eq 0 ]]; then
        error "Vui lòng KHÔNG chạy script trực tiếp bằng root hoặc sudo!"
        error "Hãy chạy với user thường: ./setup.sh"
        error "Script sẽ tự động yêu cầu sudo khi cần thao tác hệ thống."
        exit 1
    fi
}

# Sudo privilege management
SETUP_SUDOERS_FILE="/etc/sudoers.d/99-setup-installer-temp"

cleanup_sudo() {
    if [[ -f "$SETUP_SUDOERS_FILE" ]]; then
        sudo rm -f "$SETUP_SUDOERS_FILE" 2>/dev/null || true
    fi
    if [[ -n "${SUDO_PID:-}" ]]; then
        kill "$SUDO_PID" 2>/dev/null || true
    fi
}

init_sudo() {
    info "Đang kiểm tra quyền quản trị (sudo)..."
    if ! sudo -v; then
        error "Không thể xác thực quyền sudo."
        exit 1
    fi

    # Đăng ký dọn dẹp an toàn khi thoát script (bình thường, lỗi, hoặc bị ngắt Ctrl+C)
    trap cleanup_sudo EXIT INT TERM HUP

    # 1. Tạo file cấu hình tạm thời trong /etc/sudoers.d để miễn nhập mật khẩu sudo trong suốt quá trình chạy script
    local CURRENT_USER
    CURRENT_USER="$(id -un)"
    local TMP_SUDO_CONF
    TMP_SUDO_CONF="$(mktemp)"
    printf "%s ALL=(ALL) NOPASSWD: ALL\n" "$CURRENT_USER" > "$TMP_SUDO_CONF"
    chmod 0440 "$TMP_SUDO_CONF"

    # Kiểm tra cú pháp bằng visudo trước khi nạp vào /etc/sudoers.d
    if sudo visudo -cf "$TMP_SUDO_CONF" >/dev/null 2>&1; then
        sudo cp -f "$TMP_SUDO_CONF" "$SETUP_SUDOERS_FILE"
        sudo chmod 0440 "$SETUP_SUDOERS_FILE"
        rm -f "$TMP_SUDO_CONF"
        substep "Đã thiết lập phiên sudo đặc quyền (chỉ cần nhập mật khẩu 1 lần duy nhất)."
    else
        rm -f "$TMP_SUDO_CONF"
        warn "Không thể tạo file sudoers tạm. Sẽ dùng keep-alive nền để duy trì phiên."
    fi

    # 2. Tiến trình keep-alive song song trong nền dự phòng
    (while true; do
        sudo -v -n 2>/dev/null || true
        sleep 25
        kill -0 "$$" 2>/dev/null || exit
    done) &
    SUDO_PID=$!

    success "Đã xác thực quyền sudo thành công."
}

# Detect or install AUR helper (paru / yay)
detect_aur_helper() {
    if command -v paru >/dev/null 2>&1; then
        AUR_HELPER="paru"
    elif command -v yay >/dev/null 2>&1; then
        AUR_HELPER="yay"
    else
        AUR_HELPER=""
    fi
}

ensure_aur_helper() {
    detect_aur_helper
    if [[ -n "$AUR_HELPER" ]]; then
        info "Đã phát hiện AUR helper: ${BOLD}$AUR_HELPER${NC}"
        return 0
    fi

    info "Chưa có AUR helper (paru/yay). Đang kiểm tra và cài đặt paru..."
    if pacman -Si paru >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm paru
        AUR_HELPER="paru"
    else
        info "Đang build yay từ AUR..."
        sudo pacman -S --needed --noconfirm git base-devel
        local TMP_YAY
        TMP_YAY="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay.git "$TMP_YAY/yay"
        (cd "$TMP_YAY/yay" && makepkg -si --noconfirm)
        rm -rf "$TMP_YAY"
        AUR_HELPER="yay"
    fi

    # Configure paru skip review & SudoLoop if paru is used
    if [[ "$AUR_HELPER" == "paru" ]]; then
        mkdir -p "$HOME/.config/paru"
        if ! grep -q "SkipReview" "$HOME/.config/paru/paru.conf" 2>/dev/null; then
            printf "[options]\nSkipReview\n" >> "$HOME/.config/paru/paru.conf"
        fi
        if ! grep -q "SudoLoop" "$HOME/.config/paru/paru.conf" 2>/dev/null; then
            printf "SudoLoop\n" >> "$HOME/.config/paru/paru.conf"
        fi
    fi

    success "Đã chuẩn bị xong AUR helper: $AUR_HELPER"
}

# Check if a package is installed
is_installed() {
    pacman -Q "$1" >/dev/null 2>&1
}

# Install official repo packages
pkg_install() {
    local to_install=()
    for pkg in "$@"; do
        if ! is_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Đang cài đặt các gói repo chính thức: ${to_install[*]}"
        sudo pacman -S --needed --noconfirm "${to_install[@]}"
        success "Đã cài đặt: ${to_install[*]}"
    else
        substep "Các gói đã có sẵn: $*"
    fi
}

# Install AUR packages
aur_install() {
    ensure_aur_helper
    local to_install=()
    for pkg in "$@"; do
        if ! is_installed "$pkg"; then
            to_install+=("$pkg")
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Đang cài đặt các gói AUR qua $AUR_HELPER: ${to_install[*]}"
        "$AUR_HELPER" -S --needed --noconfirm "${to_install[@]}"
        success "Đã cài đặt từ AUR: ${to_install[*]}"
    else
        substep "Các gói AUR đã có sẵn: $*"
    fi
}
