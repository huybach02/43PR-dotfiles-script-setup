#!/usr/bin/env bash
# ==============================================================================
# Module: 11-mount-data
# Description: Tự động mount phân vùng Data (NTFS) vào /mnt/Data khi khởi động,
#              tạo symlink /run/media/... giữ tương thích ngược và ~/Data tiện lợi.
# ==============================================================================

MODULE_NAME="mount-data"
MODULE_DESC="Tự động mount phân vùng Data (NTFS) vào /mnt/Data, tạo symlink ~/Data và /run/media/..."

DATA_UUID="8E3A42193A41FEA9"
MOUNT_POINT="/mnt/Data"

run_module() {
    header "MODULE: $MODULE_DESC"

    local CURRENT_USER
    CURRENT_USER="$(id -un)"
    local USER_UID
    USER_UID="$(id -u)"
    local USER_GID
    USER_GID="$(id -g)"

    # 1. CÀI ĐẶT CÁC CÔNG CỤ NTFS CẦN THIẾT
    info "1/5. Kiểm tra và cài đặt công cụ hỗ trợ NTFS (ntfs-3g)..."
    pkg_install ntfs-3g

    # 2. TẠO THƯ MỤC MOUNT VÀ THIẾT LẬP QUYỀN HẠN
    info "2/5. Chuẩn bị thư mục đích $MOUNT_POINT..."
    if [[ ! -d "$MOUNT_POINT" ]]; then
        sudo mkdir -p "$MOUNT_POINT"
        sudo chown -R "$CURRENT_USER:$CURRENT_USER" "$MOUNT_POINT"
        substep "Đã tạo thư mục: $MOUNT_POINT"
    else
        substep "Thư mục $MOUNT_POINT đã tồn tại."
    fi

    # 3. UNMOUNT ĐIỂM MOUNT CŨ NẾU ĐANG CHẠY TRÊN /RUN/MEDIA
    local OLD_MOUNT="/run/media/$CURRENT_USER/$DATA_UUID"
    if mountpoint -q "$OLD_MOUNT" 2>/dev/null; then
        info "Đang unmount phân vùng tại điểm mount tạm thời $OLD_MOUNT..."
        sudo umount "$OLD_MOUNT" 2>/dev/null || true
        substep "Đã unmount $OLD_MOUNT"
    fi

    # 4. CẤU HÌNH /ETC/FSTAB ĐỂ TỰ ĐỘNG MOUNT KHI BOOT
    info "3/5. Cấu hình tự động mount trong /etc/fstab..."
    local FSTAB_ENTRY="UUID=$DATA_UUID $MOUNT_POINT ntfs3 defaults,noatime,uid=$USER_UID,gid=$USER_GID,dmask=022,fmask=022,iocharset=utf8,windows_names,nofail,x-systemd.device-timeout=10s 0 0"

    if grep -q "UUID=$DATA_UUID" /etc/fstab; then
        substep "Đã phát hiện UUID=$DATA_UUID trong /etc/fstab, đang cập nhật lại dòng cấu hình..."
        sudo sed -i "\|UUID=$DATA_UUID|c\\$FSTAB_ENTRY" /etc/fstab
    elif grep -q "[[:space:]]$MOUNT_POINT[[:space:]]" /etc/fstab; then
        substep "Đã phát hiện mount point $MOUNT_POINT trong /etc/fstab, đang cập nhật lại..."
        sudo sed -i "\|[[:space:]]$MOUNT_POINT[[:space:]]|c\\$FSTAB_ENTRY" /etc/fstab
    else
        sudo cp /etc/fstab /etc/fstab.bak."$(date +%Y%m%d%H%M%S)"
        echo -e "\n# Phân vùng Data (NTFS)\n$FSTAB_ENTRY" | sudo tee -a /etc/fstab >/dev/null
        substep "Đã thêm cấu hình mount vào /etc/fstab"
    fi

    # Reload systemd và mount phân vùng ngay lập tức
    info "Đang nạp lại systemd daemon và mount phân vùng..."
    sudo systemctl daemon-reload
    if ! mountpoint -q "$MOUNT_POINT"; then
        sudo mount "$MOUNT_POINT"
    else
        sudo mount -o remount "$MOUNT_POINT" 2>/dev/null || true
    fi
    substep "Đã mount thành công phân vùng Data vào $MOUNT_POINT"

    # 5. TẠO SYMLINK TIỆN LỢI TẠI ~/Data
    info "4/5. Tạo symlink tiện lợi tại $HOME/Data..."
    ln -sfn "$MOUNT_POINT" "$HOME/Data"
    substep "Đã tạo symlink: $HOME/Data -> $MOUNT_POINT"

    # 6. TẠO SYMLINK TƯƠNG THÍCH CHO /RUN/MEDIA/...
    info "5/5. Tạo symlink tương thích ngược cho $OLD_MOUNT..."
    sudo mkdir -p "/run/media/$CURRENT_USER"
    sudo ln -sfn "$MOUNT_POINT" "$OLD_MOUNT"
    substep "Đã tạo symlink hiện tại: $OLD_MOUNT -> $MOUNT_POINT"

    # Cấu hình systemd-tmpfiles để duy trì symlink trong /run/media qua mỗi lần reboot
    local TMPFILES_CONF="/etc/tmpfiles.d/data-compat-symlink.conf"
    info "Thiết lập cấu hình systemd-tmpfiles tại $TMPFILES_CONF để duy trì symlink sau khi reboot..."
    cat << EOF | sudo tee "$TMPFILES_CONF" >/dev/null
# Duy trì symlink tương thích cho phân vùng Data trong /run/media sau mỗi lần khởi động
d /run/media/$CURRENT_USER 0755 $CURRENT_USER $CURRENT_USER -
L+ /run/media/$CURRENT_USER/$DATA_UUID - - - - $MOUNT_POINT
EOF
    sudo systemd-tmpfiles --create "$TMPFILES_CONF" 2>/dev/null || true
    substep "Đã áp dụng systemd-tmpfiles: $TMPFILES_CONF"

    success "Hoàn tất module Mount Data!"
}
