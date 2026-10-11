#!/usr/bin/env bash
# ==============================================================================
# Module: 05-monitors
# Description: Thiết lập cấu hình màn hình kép (Philips chính bên trái, AOC phụ bên phải @ 75Hz)
# ==============================================================================

MODULE_NAME="monitors"
MODULE_DESC="Thiết lập màn hình kép: Philips chính (0x0@75Hz) bên trái, AOC phụ (1920x0@75Hz) bên phải"

run_module() {
    header "MODULE: $MODULE_DESC"

    local TARGET_FILES=()
    [[ -f "$HOME/.config/hypr/monitors.lua" ]] && TARGET_FILES+=("$HOME/.config/hypr/monitors.lua")
    [[ -f "$HOME/.dotfiles/.config/hypr/monitors.lua" ]] && TARGET_FILES+=("$HOME/.dotfiles/.config/hypr/monitors.lua")

    # Loại bỏ file trùng nếu ~/.config/hypr/monitors.lua là symlink đến ~/.dotfiles
    local UNIQUE_TARGETS=()
    for file in "${TARGET_FILES[@]}"; do
        local real
        real="$(readlink -f "$file")"
        local exists=0
        for u in "${UNIQUE_TARGETS[@]}"; do
            [[ "$u" == "$real" ]] && exists=1 && break
        done
        [[ $exists -eq 0 ]] && UNIQUE_TARGETS+=("$real")
    done

    info "Đang cập nhật cấu hình monitors.lua cho Hyprland..."

    for cfg_file in "${UNIQUE_TARGETS[@]}"; do
        mkdir -p "$(dirname "$cfg_file")"
        cat << 'EOF' > "$cfg_file"
-- MONITORS.LUA
-- Cấu hình màn hình tự động tạo bởi script setup
-- Docs: https://wiki.hypr.land/Configuring/Monitors/

-- 1. Màn hình chính: Philips 241V8 bên trái (0x0@75Hz)
hl.monitor({
    output = "HDMI-A-2",
    mode = "1920x1080@74.97",
    position = "0x0",
    scale = 1,
})

-- 2. Màn hình phụ: AOC 24V2W1G5 bên phải (1920x0@75Hz)
hl.monitor({
    output = "DP-2",
    mode = "1920x1080@74.97",
    position = "1920x0",
    scale = 1,
})

-- Dự phòng tìm theo định danh thiết bị (Hardware Description) nếu đổi cổng cắm
hl.monitor({
    output = "desc:Philips Consumer Electronics Company PHL 241V8 UHB2245026774",
    mode = "1920x1080@74.97",
    position = "0x0",
    scale = 1,
})

hl.monitor({
    output = "desc:AOC 24V2W1G5 0x0000023C",
    mode = "1920x1080@74.97",
    position = "1920x0",
    scale = 1,
})

-- Fallback tự động nhận diện nếu có màn hình phụ khác
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

pcall(function()
    local path = os.getenv("HOME") .. "/.config/quickshell/state/display.lua"
    local f = io.open(path, "r")
    if f then
        f:close()
        dofile(path)
    end
end)

-- WORKSPACE RULES
-- Màn hình chính Philips (HDMI-A-2): Workspaces 1 (Edge), 3 (VSCode), 5, 6, 7
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-2", default = true, persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "6", monitor = "HDMI-A-2", persistent = true })
hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-2", persistent = true })

-- Màn hình phụ AOC (DP-2): Workspaces 2 (Firefox), 4, 8, 9
hl.workspace_rule({ workspace = "2", monitor = "DP-2", default = true, persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "DP-2", persistent = true })
hl.workspace_rule({ workspace = "8", monitor = "DP-2", persistent = true })
hl.workspace_rule({ workspace = "9", monitor = "DP-2", persistent = true })
EOF
        substep "Đã ghi cấu hình vào: $cfg_file"
    done

    # Nếu Hyprland đang chạy thì áp dụng ngay lập tức
    if pgrep -x Hyprland >/dev/null 2>&1; then
        info "Hyprland đang hoạt động. Đang áp dụng thiết lập màn hình ngay lập tức..."
        hyprctl eval 'hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@74.97", position = "0x0", scale = 1 })' >/dev/null 2>&1 || true
        hyprctl eval 'hl.monitor({ output = "DP-2", mode = "1920x1080@74.97", position = "1920x0", scale = 1 })' >/dev/null 2>&1 || true
        hyprctl reload >/dev/null 2>&1 || true

        # Đồng bộ hình nền hiển thị lại cho 2 màn hình
        if [[ -f "$HOME/.config/hypr/scripts/wallpaper-restore.sh" ]]; then
            bash "$HOME/.config/hypr/scripts/wallpaper-restore.sh" 2>/dev/null || true
        fi
        success "Đã áp dụng độ phân giải và vị trí màn hình lên phiên Hyprland hiện tại!"
    fi

    success "Module 05-monitors: Hoàn tất cấu hình màn hình kép!"
}
