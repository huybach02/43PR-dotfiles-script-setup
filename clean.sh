#!/usr/bin/env bash
# ==============================================================================
# Script: clean.sh
# Description: Dọn dẹp Btrfs snapshots, cache, file tạm, gỡ gói rác & tối ưu dung lượng ổ đĩa
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
    info "1/6. Gỡ bỏ Android Studio IDE (giải phóng ~3.6 GB)..."
    sudo pacman -Rns --noconfirm android-studio
    rm -rf "$HOME/.config/Google/AndroidStudio"* "$HOME/.local/share/Google/AndroidStudio"* "$HOME/.cache/Google/AndroidStudio"* 2>/dev/null || true
    success "Đã gỡ bỏ Android Studio IDE thành công!"
else
    substep "1/6. Android Studio IDE không có trên hệ thống hoặc đã được gỡ."
fi

# 2. Xóa các gói thư viện mồ côi (orphans)
info "2/6. Kiểm tra và gỡ bỏ các gói thư viện mồ côi (orphans)..."
ORPHANS="$(pacman -Qtdq 2>/dev/null || true)"
if [[ -n "$ORPHANS" ]]; then
    sudo pacman -Rns --noconfirm $ORPHANS
    success "Đã gỡ bỏ các gói mồ côi: $ORPHANS"
else
    substep "Không có gói mồ côi nào cần gỡ."
fi

# 3. Dọn dẹp Btrfs Snapper Snapshots & gỡ bỏ tự động tạo snapshot (snap-pac)
info "3/6. Dọn dẹp Btrfs Snapshots & gỡ bỏ cơ chế tự động tạo snapshot (snap-pac)..."
if command -v snapper &>/dev/null && sudo snapper list &>/dev/null; then
    SNAPS="$(sudo snapper list 2>/dev/null | awk -F'│' '{gsub(/ /, "", $1); if ($1 ~ /^[0-9]+$/ && $1 > 0) print $1}' | tr '\n' ' ')"
    if [[ -n "$SNAPS" ]]; then
        info "Đang xóa các bản snapshot cũ: $SNAPS"
        sudo snapper delete $SNAPS 2>/dev/null || true
        success "Đã dọn dẹp sạch toàn bộ Btrfs snapshots!"
    else
        substep "Không có snapshot nào cần xóa."
    fi
fi

if pacman -Q snap-pac &>/dev/null; then
    info "Gỡ bỏ snap-pac và cachyos-snapper-support để tắt tự động tạo Btrfs snapshot..."
    sudo pacman -Rns --noconfirm grub-btrfs-support cachyos-snapper-support snap-pac grub-btrfs 2>/dev/null || true
    success "Đã gỡ bỏ snap-pac thành công!"
else
    substep "snap-pac không có trên hệ thống hoặc đã được gỡ bỏ."
fi

# 4. Dọn dẹp Cache Paru (AUR clone)
info "4/6. Dọn dẹp cache build AUR (Paru)..."
rm -rf "$HOME/.cache/paru/clone/"*
success "Đã dọn sạch cache build Paru!"

# 5. Dọn dẹp Cache Pacman
info "5/6. Dọn dẹp toàn bộ cache gói tải về của Pacman (/var/cache/pacman/pkg)..."
if command -v paccache &>/dev/null; then
    sudo paccache -r -k0 --quiet 2>/dev/null || true
fi
printf "y\ny\n" | sudo pacman -Scc >/dev/null 2>&1 || true
success "Đã dọn sạch cache Pacman!"

# 6. Dọn dẹp Cache trình duyệt & Thùng rác
info "6/6. Dọn dẹp cache trình duyệt (Edge, Firefox) & Thùng rác..."
rm -rf "$HOME/.cache/microsoft-edge/"* "$HOME/.cache/mozilla/"* 2>/dev/null || true
rm -rf "$HOME/.local/share/Trash/files/"* "/mnt/Data/.Trash-1000/files/"* 2>/dev/null || true
success "Đã dọn dẹp cache trình duyệt và thùng rác!"

# Báo cáo dung lượng
header "BÁO CÁO DUNG LƯỢNG SAU KHI DỌN DẸP"
df -h / /home /mnt/Data 2>/dev/null || df -h /

success "Toàn bộ các mục đã được dọn dẹp sạch sẽ!"
cleanup_sudo
