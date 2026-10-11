#!/usr/bin/env bash
# ==============================================================================
# Script: clean.sh
# Description: Dọn dẹp cache, file tạm, gỡ gói rác & tối ưu dung lượng ổ đĩa
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

# Nạp thư viện dùng chung
if [[ -f "$LIB_DIR/common.sh" ]]; then
    # shellcheck source=lib/common.sh
    source "$LIB_DIR/common.sh"
else
    echo "Lỗi: Không tìm thấy $LIB_DIR/common.sh" >&2
    exit 1
fi

header "DỌN DẸP VÀ TỐI ƯU DUNG LƯỢNG HỆ THỐNG"

check_non_root
init_sudo

# 1. Gỡ bỏ Android Studio IDE (nếu người dùng chỉ code trên VS Code)
if pacman -Q android-studio &>/dev/null; then
    info "1/4. Gỡ bỏ Android Studio IDE (giải phóng ~3.6 GB)..."
    sudo pacman -Rns --noconfirm android-studio
    rm -rf "$HOME/.config/Google/AndroidStudio"* "$HOME/.local/share/Google/AndroidStudio"* "$HOME/.cache/Google/AndroidStudio"* 2>/dev/null || true
    success "Đã gỡ bỏ Android Studio IDE thành công!"
else
    substep "Android Studio IDE không có trên hệ thống hoặc đã được gỡ."
fi

# 2. Xóa các gói thư viện mồ côi (orphans)
info "2/4. Kiểm tra và gỡ bỏ các gói thư viện mồ côi (orphans)..."
local ORPHANS
ORPHANS="$(pacman -Qtdq 2>/dev/null || true)"
if [[ -n "$ORPHANS" ]]; then
    sudo pacman -Rns --noconfirm $ORPHANS
    success "Đã gỡ bỏ các gói mồ côi: $ORPHANS"
else
    substep "Không có gói mồ côi nào cần gỡ."
fi

# 3. Dọn dẹp Cache Paru (AUR clone)
info "3/4. Dọn dẹp cache build AUR (Paru)..."
rm -rf "$HOME/.cache/paru/clone/"*
success "Đã dọn sạch cache build Paru!"

# 4. Dọn dẹp Cache Pacman
info "4/4. Dọn dẹp toàn bộ cache gói tải về của Pacman (/var/cache/pacman/pkg)..."
if command -v paccache &>/dev/null; then
    sudo paccache -r -k0 --quiet 2>/dev/null || true
fi
printf "y\ny\n" | sudo pacman -Scc >/dev/null 2>&1 || true
success "Đã dọn sạch cache Pacman!"

# Báo cáo dung lượng
header "BÁO CÁO DUNG LƯỢNG SAU KHI DỌN DẸP"
df -h / /home /mnt/Data

success "Toàn bộ các mục đã được dọn dẹp sạch sẽ!"
cleanup_sudo
