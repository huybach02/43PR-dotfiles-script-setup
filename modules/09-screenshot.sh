#!/usr/bin/env bash
# ==============================================================================
# Module: 09-screenshot
# Description: Cấu hình chụp ảnh màn hình Super+Shift+S (slurp + grim),
#              popup thông báo QuickShell và trình biên tập ảnh Satty (với đầy đủ
#              công cụ draw, shape, line, color palette hiển thị sẵn)
# ==============================================================================

MODULE_NAME="screenshot"
MODULE_DESC="Cấu hình chụp ảnh màn hình (Super + Shift + S), popup OSD và trình biên tập Satty"

run_module() {
    header "MODULE: $MODULE_DESC"

    # 1. CÀI ĐẶT CÁC CÔNG CỤ CẦN THIẾT
    info "1/5. Cài đặt các gói phụ thuộc: grim, slurp, satty, wl-clipboard..."
    pkg_install grim slurp satty wl-clipboard

    # 2. TẠO SCRIPT CHỤP ẢNH SCREENSHOT.SH
    info "2/5. Thiết lập script chụp ảnh màn hình tại ~/.config/hypr/scripts/screenshot.sh..."
    local SCRIPT_DIRS=("$HOME/.config/hypr/scripts")
    [[ -d "$HOME/.dotfiles/.config/hypr/scripts" ]] && SCRIPT_DIRS+=("$HOME/.dotfiles/.config/hypr/scripts")

    for sdir in "${SCRIPT_DIRS[@]}"; do
        mkdir -p "$sdir"
        local script_path="$sdir/screenshot.sh"
        cat << 'EOF' > "$script_path"
#!/usr/bin/env bash
# ==============================================================================
# Script: screenshot.sh
# Description: Chụp ảnh màn hình (vùng chọn hoặc toàn màn hình), sao chép vào
#              clipboard, lưu file và hiển thị popup QuickShell góc phải.
# ==============================================================================

MODE="${1:-area}"
SAVE_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SAVE_DIR"

TIMESTAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
FILEPATH="$SAVE_DIR/Screenshot_${TIMESTAMP}.png"

if [ "$MODE" = "area" ]; then
    # Cho phép người dùng kéo chọn vùng bằng slurp
    GEOM="$(slurp 2>/dev/null)"
    # Nếu người dùng hủy chọn (nhấn Esc), thoát không báo lỗi
    [ -z "$GEOM" ] && exit 0

    # Chụp vùng đã chọn
    if ! grim -g "$GEOM" "$FILEPATH"; then
        exit 1
    fi
else
    # Chụp toàn màn hình
    if ! grim "$FILEPATH"; then
        exit 1
    fi
fi

# Sao chép ảnh vào clipboard (Wayland)
wl-copy < "$FILEPATH"

# Gọi QuickShell hiển thị popup góc phải màn hình
qs ipc call screenshot notify "$FILEPATH" 2>/dev/null || true
EOF
        chmod +x "$script_path"
        substep "Đã cập nhật script có quyền thực thi: $script_path"
    done

    # Đảm bảo symlink từ ~/.config sang ~/.dotfiles nếu có
    if [[ -d "$HOME/.dotfiles/.config/hypr/scripts" && -f "$HOME/.dotfiles/.config/hypr/scripts/screenshot.sh" ]]; then
        mkdir -p "$HOME/.config/hypr/scripts"
        ln -sfn "$HOME/.dotfiles/.config/hypr/scripts/screenshot.sh" "$HOME/.config/hypr/scripts/screenshot.sh"
    fi

    # 3. CẤU HÌNH TRÌNH BIÊN TẬP ẢNH SATTY
    info "3/5. Thiết lập cấu hình Satty với đầy đủ công cụ và bảng màu..."
    local SATTY_DIRS=("$HOME/.config/satty")
    [[ -d "$HOME/.dotfiles/.config" ]] && SATTY_DIRS+=("$HOME/.dotfiles/.config/satty")

    for sdir in "${SATTY_DIRS[@]}"; do
        mkdir -p "$sdir"
        local satty_cfg="$sdir/config.toml"
        cat << 'EOF' > "$satty_cfg"
[general]
fullscreen = false
floating-hack = true
early-exit = ["copy"]
initial-tool = "brush"
copy-command = "wl-copy"
annotation-size-factor = 1.0
corner-roundness = 8
save-after-copy = false
default-hide-toolbars = false
actions-on-enter = ["save-to-clipboard", "exit"]
actions-on-escape = ["exit"]

[color-palette]
palette = [
    "#e74c3c",
    "#e67e22",
    "#f1c40f",
    "#2ecc71",
    "#3498db",
    "#9b59b6",
    "#ffffff",
    "#2c3e50",
]
EOF
        substep "Đã cấu hình Satty tại: $satty_cfg"
    done

    if [[ -d "$HOME/.dotfiles/.config/satty" && -f "$HOME/.dotfiles/.config/satty/config.toml" ]]; then
        mkdir -p "$HOME/.config/satty"
        ln -sfn "$HOME/.dotfiles/.config/satty/config.toml" "$HOME/.config/satty/config.toml"
    fi

    # 4. TÍCH HỢP POPUP VÀO QUICKSHELL
    info "4/5. Kiểm tra và tích hợp popup ScreenshotOsd vào QuickShell..."
    local QS_DIRS=("$HOME/.config/quickshell")
    [[ -d "$HOME/.dotfiles/.config/quickshell" ]] && QS_DIRS+=("$HOME/.dotfiles/.config/quickshell")

    for qdir in "${QS_DIRS[@]}"; do
        local osd_file="$qdir/ScreenshotOsd.qml"
        local shell_file="$qdir/shell.qml"

        if [[ -f "$shell_file" ]] && ! grep -q "ScreenshotOsd" "$shell_file"; then
            sed -i '/ShellRoot {/a \    ScreenshotOsd {}' "$shell_file"
            substep "Đã kích hoạt ScreenshotOsd trong $shell_file"
        fi

        if [[ ! -f "$osd_file" ]] || ! grep -q "satty" "$osd_file"; then
            cat << 'EOF' > "$osd_file"
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 150
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {
        item: root.showing ? flyout : null
    }

    property bool showing: false
    property string imagePath: ""

    function showOsd(path) {
        imagePath = path
        showing = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 5000
        repeat: false
        onTriggered: root.showing = false
    }

    IpcHandler {
        target: "screenshot"
        function notify(path: string): void {
            root.showOsd(path)
        }
    }

    Process {
        id: editorProc
    }

    Rectangle {
        id: flyout
        width: 330
        height: 84
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.top: parent.top
        anchors.topMargin: 36
        radius: 16
        color: Theme.alpha(Theme.bg, 0.92)
        border.width: 1
        border.color: clickArea.containsMouse ? Theme.accent : Theme.alpha(Theme.border, 0.6)
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.9

        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }

        MouseArea {
            id: clickArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: hideTimer.stop()
            onExited: hideTimer.restart()
            onClicked: {
                root.showing = false;
                if (root.imagePath) {
                    editorProc.command = ["satty", "-f", root.imagePath];
                    editorProc.running = true;
                }
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 14

            Rectangle {
                id: thumb
                width: 60
                height: 60
                radius: 10
                color: "#22ffffff"
                clip: true
                anchors.verticalCenter: parent.verticalCenter

                Image {
                    anchors.fill: parent
                    source: root.imagePath ? "file://" + root.imagePath : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 120
                    sourceSize.height: 120
                    asynchronous: false
                    cache: false
                }
                Text {
                    anchors.centerIn: parent
                    visible: !parent.children[0].status == Image.Ready
                    text: "\uf03e"
                    font.family: "Font Awesome 6 Free"
                    font.pixelSize: 22
                    color: Theme.fg
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    text: "Đã chụp ảnh màn hình"
                    color: Theme.fg
                    font.pixelSize: 13
                    font.bold: true
                }

                Text {
                    text: "Đã chép vào clipboard"
                    color: Theme.accent
                    font.pixelSize: 11
                }

                Text {
                    text: "Bấm để mở trình sửa ảnh"
                    color: Theme.alpha(Theme.fg, 0.5)
                    font.pixelSize: 11
                }
            }
        }
    }
}
EOF
            substep "Đã tạo/cập nhật ScreenshotOsd.qml tại: $osd_file"
        fi
    done

    # 5. CẤU HÌNH PHÍM TẮT VÀ WINDOW RULES CHO HYPRLAND
    info "5/5. Cấu hình phím tắt và window rule cho Hyprland..."
    local KEYBINDS_FILES=("$HOME/.config/hypr/keybinds.lua")
    [[ -f "$HOME/.dotfiles/.config/hypr/keybinds.lua" ]] && KEYBINDS_FILES+=("$HOME/.dotfiles/.config/hypr/keybinds.lua")

    for kfile in "${KEYBINDS_FILES[@]}"; do
        if [[ -f "$kfile" ]]; then
            # Xóa triệt để các bind cũ gán vào phím Delete (tránh việc bấm Delete bị chụp màn hình)
            sed -i '/hl\.bind("Delete"/d' "$kfile" 2>/dev/null || true
            sed -i '/hl\.bind("SHIFT + Delete"/d' "$kfile" 2>/dev/null || true
            sed -i '/-- Screenshot fullscreen (Delete)/d' "$kfile" 2>/dev/null || true

            # Đảm bảo phím tắt Super + Shift + S và PrintScreen chuẩn
            if ! grep -q 'screenshot\.sh area' "$kfile"; then
                cat << 'EOF' >> "$kfile"

-- Screenshot area select (Super + Shift + S) & fullscreen (Print)
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/screenshot.sh area"))
hl.bind("Print", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/screenshot.sh full"))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/screenshot.sh area"))
EOF
                substep "Đã cập nhật phím tắt chụp màn hình (Super + Shift + S & Print) vào $kfile"
            else
                # Đảm bảo có bind Print nếu chưa có
                if ! grep -q 'hl\.bind("Print"' "$kfile"; then
                    sed -i '/hl\.bind(mainMod \.\. " + SHIFT + S"/a hl.bind("Print", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/screenshot.sh full"))\nhl.bind("SHIFT + Print", hl.dsp.exec_cmd(home .. "/.config/hypr/scripts/screenshot.sh area"))' "$kfile"
                fi
                substep "Đã dọn dẹp phím Delete và chuẩn hóa phím chụp ảnh trong $kfile"
            fi
        fi
    done

    local RULES_FILES=("$HOME/.config/hypr/rules.lua")
    [[ -f "$HOME/.dotfiles/.config/hypr/rules.lua" ]] && RULES_FILES+=("$HOME/.dotfiles/.config/hypr/rules.lua")

    for rfile in "${RULES_FILES[@]}"; do
        if [[ -f "$rfile" ]] && ! grep -q 'float-satty' "$rfile"; then
            cat << 'EOF' >> "$rfile"

hl.window_rule({
    name = "float-satty",
    match = { class = "^(com\\.gabm\\.satty|satty)$" },
    float = true,
    center = true,
})
EOF
            substep "Đã thêm window rule float/center cho Satty vào $rfile"
        fi
    done

    # Reload Hyprland nếu đang chạy
    if command -v hyprctl &>/dev/null && pgrep -x Hyprland &>/dev/null; then
        hyprctl reload &>/dev/null || true
    fi

    success "Hoàn tất cấu hình module Screenshot & Satty!"
}
