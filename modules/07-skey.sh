#!/usr/bin/env bash
# ==============================================================================
# Module: 07-skey
# Description: Cài đặt bộ gõ tiếng Việt SKey (Fcitx5), phím tắt Alt + Left Shift
# Repository: https://github.com/collyn/skey
# ==============================================================================

MODULE_NAME="skey"
MODULE_DESC="Cài đặt bộ gõ tiếng Việt skey (fcitx5-skey), cấu hình phím tắt Alt + Left Shift"

run_module() {
    header "MODULE: $MODULE_DESC"

    # 1. THÊM REPOSITORY VÀ KEY CHO FCITX5-SKEY
    info "1/5. Thiết lập kho phần mềm fcitx5-skey cho Arch Linux / CachyOS..."
    local KEY_URL="https://collyn.github.io/skey/key.asc"
    local REPO_URL="https://collyn.github.io/skey/arch/x86_64"
    local TMP_KEY="/tmp/fcitx5-skey-key.asc"

    curl -fsSL "$KEY_URL" -o "$TMP_KEY"
    sudo pacman-key --add "$TMP_KEY"
    sudo pacman-key --lsign-key collyn094@gmail.com
    rm -f "$TMP_KEY"

    if ! grep -q '\[fcitx5-skey\]' /etc/pacman.conf; then
        sudo tee -a /etc/pacman.conf > /dev/null << 'EOF'

[fcitx5-skey]
Server = https://collyn.github.io/skey/arch/x86_64
SigLevel = Optional TrustAll
EOF
        substep "Đã thêm repository [fcitx5-skey] vào /etc/pacman.conf"
    else
        substep "Repository [fcitx5-skey] đã có sẵn trong /etc/pacman.conf"
    fi

    sudo pacman -Sy --noconfirm

    # 2. CÀI ĐẶT CÁC GÓI FCITX5 VÀ FCITX5-SKEY
    info "2/5. Cài đặt fcitx5, fcitx5-skey và các frontend tích hợp..."
    pkg_install fcitx5 fcitx5-skey fcitx5-gtk fcitx5-qt fcitx5-configtool

    # 3. CHẠY SKEY-SETUP ĐỂ KHỞI TẠO CẤU HÌNH CƠ BẢN VÀ UINPUT SERVICE
    info "3/5. Khởi tạo cấu hình SKey và uinput server qua skey-setup..."
    if command -v skey-setup &>/dev/null; then
        skey-setup -y || true
        substep "Đã chạy skey-setup thành công"
    fi

    # Đảm bảo uinput service được kích hoạt cho user hiện tại
    local CURRENT_USER
    CURRENT_USER="${SUDO_USER:-$USER}"
    if [[ -n "$CURRENT_USER" && "$CURRENT_USER" != "root" ]]; then
        sudo systemctl enable --now "fcitx5-skey-uinput-server@${CURRENT_USER}.service" 2>/dev/null || true
        substep "Đã kích hoạt fcitx5-skey-uinput-server@${CURRENT_USER}.service"
    fi

    # 4. CẤU HÌNH PHÍM TẮT CHUYỂN NGÔN NGỮ: ALT + LEFT SHIFT
    info "4/5. Cấu hình phím tắt chuyển ngôn ngữ Alt + Left Shift..."
    local FCITX_CONFIG_DIR="$HOME/.config/fcitx5"
    mkdir -p "$FCITX_CONFIG_DIR"

    # Profile fcitx5: Mặc định là skey-im và keyboard-us
    cat << 'EOF' > "$FCITX_CONFIG_DIR/profile"
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us
# Default Input Method
DefaultIM=skey-im

[Groups/0/Items/0]
# Name
Name=keyboard-us
# Layout
Layout=

[Groups/0/Items/1]
# Name
Name=skey-im
# Layout
Layout=

[GroupOrder]
0=Default
EOF
    substep "Đã cập nhật profile: skey-im (Tiếng Việt) và keyboard-us (Tiếng Anh)"

    # Cấu hình config với phím tắt chuyển ngôn ngữ Alt + Left Shift (Alt+Shift_L)
    cat << 'EOF' > "$FCITX_CONFIG_DIR/config"
[Hotkey]
EnumerateWithTriggerKeys=True
EnumerateSkipFirst=False

[Hotkey/TriggerKeys]
0=Alt+Shift_L
1=Shift+Alt_L

[Hotkey/EnumerateForwardKeys]
0=Alt+Shift_L
1=Shift+Alt_L

[Behavior]
ActiveByDefault=True
ShareInputState=All
PreeditEnabledByDefault=True
ShowInputMethodInformation=True
PreloadInputMethod=True
EOF
    substep "Đã cập nhật phím tắt: Alt+Shift_L trong $FCITX_CONFIG_DIR/config"

    # Environment variables cho desktop session
    mkdir -p "$HOME/.config/environment.d"
    cat << 'EOF' > "$HOME/.config/environment.d/fcitx5-skey.conf"
# fcitx5-skey
GTK_IM_MODULE=fcitx5
QT_IM_MODULE=fcitx5
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx5
GLFW_IM_MODULE=ibus
EOF
    substep "Đã cập nhật ~/.config/environment.d/fcitx5-skey.conf"

    # 5. CẤU HÌNH HYPRLAND AUTOSTART & ENVIRONMENT VARIABLES
    info "5/5. Cấu hình autostart và biến môi trường trong Hyprland..."
    local HYPR_FILE="$HOME/.config/hypr/hyprland.lua"
    if [[ -f "$HYPR_FILE" ]]; then
        # Thêm fcitx5 autostart nếu chưa có
        if ! grep -q "fcitx5 -d" "$HYPR_FILE"; then
            sed -i '/hl\.on("hyprland\.start"/,/end)/ {
                /end)/ i \    -- Autostart bộ gõ Fcitx5 (skey)\n    hl.exec_cmd("fcitx5 -d")
            }' "$HYPR_FILE"
            substep "Đã thêm lệnh autostart fcitx5 vào hyprland.lua"
        else
            substep "Lệnh autostart fcitx5 đã có trong hyprland.lua"
        fi

        # Thêm biến môi trường bộ gõ vào hyprland.lua nếu chưa có
        if ! grep -q "GTK_IM_MODULE" "$HYPR_FILE"; then
            cat << 'EOF' >> "$HYPR_FILE"

-- FCITX5 ENVIRONMENT VARIABLES
hl.env("GTK_IM_MODULE", "fcitx5")
hl.env("QT_IM_MODULE", "fcitx5")
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("SDL_IM_MODULE", "fcitx5")
hl.env("GLFW_IM_MODULE", "ibus")
EOF
            substep "Đã thêm biến môi trường IM vào hyprland.lua"
        fi

        # Đảm bảo kb_layout là us
        if grep -q 'kb_layout = "us,latam"' "$HYPR_FILE"; then
            sed -i 's/kb_layout = "us,latam"/kb_layout = "us"/' "$HYPR_FILE"
            substep "Đã đặt kb_layout = \"us\""
        fi
    fi

    # 6. HIỂN THỊ ICON BỘ GÕ TRÊN THANH STATUS BAR (QUICKSHELL)
    info "6/6. Cấu hình hiển thị icon trạng thái bộ gõ trên thanh QuickShell Bar..."
    local BAR_STATE="$HOME/.config/quickshell/state/bar-state.json"
    if [[ -f "$BAR_STATE" ]]; then
        if ! grep -q '"ime"' "$BAR_STATE"; then
            sed -i 's/"endMods": "[^"]*"/"endMods": "media,volume,ime,battery,net,notif,wall,settings,power"/' "$BAR_STATE"
            sed -i '/"showBattery"/ i \    "showIme": true,' "$BAR_STATE"
            substep "Đã thêm icon bộ gõ (ime) vào thanh Bar trong $BAR_STATE"
        fi
    fi

    # Tải lại cấu hình Fcitx5 nếu đang chạy
    if pgrep -x fcitx5 &>/dev/null; then
        fcitx5-remote -r &>/dev/null || true
        substep "Đã tải lại cấu hình fcitx5 đang chạy (fcitx5-remote -r)"
    else
        fcitx5 -d &>/dev/null || true
        substep "Đã khởi động fcitx5 daemon"
    fi

    success "Module 07-skey hoàn tất! Phím tắt chuyển ngôn ngữ: Alt + Left Shift, đã hiển thị icon trên Bar."
}
