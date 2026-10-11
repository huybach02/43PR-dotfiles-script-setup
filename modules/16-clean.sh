#!/usr/bin/env bash
# ==============================================================================
# Module: 16-clean
# Description: Dọn dẹp cache Paru/Pacman, gỡ gói mồ côi & tối ưu dung lượng ổ đĩa.
#
# Lưu ý: Module này có MODULE_OPT_IN=true nên mặc định sẽ BỎ QUA khi chạy
#        './setup.sh' hoặc './setup.sh all'. Chỉ chạy khi gọi riêng:
#        './setup.sh clean' hoặc './setup.sh 16-clean'.
# ==============================================================================

MODULE_NAME="clean"
MODULE_DESC="Dọn dẹp cache Paru/Pacman, gỡ gói mồ côi & tối ưu dung lượng ổ đĩa"
MODULE_OPT_IN=true

run_module() {
    header "MODULE: $MODULE_DESC"

    # 1. GỠ BỎ ANDROID STUDIO IDE (NẾU ĐANG CÓ VÀ KHÔNG DÙNG)
    if pacman -Q android-studio &>/dev/null; then
        info "1/4. Gỡ bỏ Android Studio IDE (giải phóng ~3.6 GB)..."
        sudo pacman -Rns --noconfirm android-studio
        rm -rf "$HOME/.config/Google/AndroidStudio"* "$HOME/.local/share/Google/AndroidStudio"* "$HOME/.cache/Google/AndroidStudio"* 2>/dev/null || true
        success "Đã gỡ bỏ Android Studio IDE thành công!"
    else
        substep "Android Studio IDE không có trên hệ thống hoặc đã được gỡ."
    fi

    # 2. XÓA CÁC GÓI THƯ VIỆN MỒ CÔI (ORPHANS)
    info "2/4. Kiểm tra và gỡ bỏ các gói thư viện mồ côi (orphans)..."
    local ORPHANS
    ORPHANS="$(pacman -Qtdq 2>/dev/null || true)"
    if [[ -n "$ORPHANS" ]]; then
        sudo pacman -Rns --noconfirm $ORPHANS
        success "Đã gỡ bỏ các gói mồ côi: $ORPHANS"
    else
        substep "Không có gói mồ côi nào cần gỡ."
    fi

    # 3. DỌN DẸP CACHE PARU (AUR BUILD)
    info "3/4. Dọn dẹp cache build AUR (Paru)..."
    rm -rf "$HOME/.cache/paru/clone/"*
    success "Đã dọn sạch cache build Paru!"

    # 4. DỌN DẸP CACHE PACMAN
    info "4/4. Dọn dẹp toàn bộ cache gói tải về của Pacman (/var/cache/pacman/pkg)..."
    if command -v paccache &>/dev/null; then
        sudo paccache -r -k0 --quiet 2>/dev/null || true
    fi
    printf "y\ny\n" | sudo pacman -Scc >/dev/null 2>&1 || true
    success "Đã dọn sạch cache Pacman!"

    # Báo cáo dung lượng
    header "BÁO CÁO DUNG LƯỢNG SAU KHI DỌN DẸP"
    df -h / /home /mnt/Data

    success "Module 16-clean hoàn tất thành công!"
}
