#!/usr/bin/env bash
# ==============================================================================
# Module: 13-quickshell-tweaks
# Description: Tinh chỉnh giao diện và tương tác QuickShell:
#              1. Tắt hoàn toàn hiệu ứng trong suốt (nền đặc opaque 100%).
#              2. Tắt hiệu ứng lắc/nghiêng 3D khi hover chuột vào các góc (tiltStrength: 0).
#              3. Cơ chế đóng nhanh các popup QuickShell & cố định popup Notifications vào màn hình Philips.
#              4. Click CPU/RAM trên Bar mở popup btop nổi (floating, centered).
#              5. Popup Volume OSD nổi khi chỉnh âm lượng & định dạng ngày giờ trên Bar (HH:mm | dd-MM-yyyy).
# ==============================================================================

MODULE_NAME="quickshell-tweaks"
MODULE_DESC="Tắt trong suốt, rung lắc góc, click CPU/RAM mở btop, Volume OSD, ngày giờ Bar & popup Notifications màn hình Philips"

run_module() {
    header "MODULE: $MODULE_DESC"

    local QS_DIR="$HOME/.dotfiles/.config/quickshell"
    local USER_QS_DIR="$HOME/.config/quickshell"

    mkdir -p "$QS_DIR"
    mkdir -p "$USER_QS_DIR"

    # 1. CẤU HÌNH THEME.QML: TẮT TRONG SUỐT VÀ TẮT TILT
    info "1/5. Cấu hình Theme.qml: nền đặc 100% không trong suốt, tiltStrength = 0..."
    cat << 'EOF' > "$QS_DIR/Theme.qml"
// Theme.qml
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property int radius: 10
    readonly property real tiltStrength: 0
    readonly property string fontFamily: "JetBrains Mono"
    property string iconFont: "JetBrainsMono Nerd Font"
    readonly property int animFast: 120
    readonly property int animMed: 220
    readonly property int animSlow: 380

    property real bgAlpha: 1.0   
    property color _bgBase: palette.bg || '#000000'
    property color bg: _bgBase
    property real imageOpacity: 1.0
    property color text: palette.text || '#ffffff'
    property color textDim: palette.textDim || '#c2c2c2'
    property color danger: palette.danger || '#ff003c'
    property color accent: palette.accent || '#ffffff'
    property color accent2: palette.accent2 || '#ffffff'
    property color border: palette.border || '#151515'
    property color bgPanel: palette.bgPanel || '#050505'
    property color bgCard: palette.bgCard || '#0d0d0d'
    property color borderAccent: palette.borderAccent || '#2a2a2a'
    property color textFaint: palette.textFaint || '#4a4a4a'
    property color ok: palette.ok || '#00ff9c'
    property color trackBg: palette.trackBg || '#161616'

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    property var palette: ({})

    property FileView themeFile: FileView {
        path: Qt.resolvedUrl(Quickshell.env("HOME") + "/.cache/43pr/quickshell-theme.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.palette = JSON.parse(text())
            } catch (e) {
                console.warn("Theme.qml: malformed quickshell-theme.json: " + e)
            }
        }
    }
}
EOF
    ln -sfn "$QS_DIR/Theme.qml" "$USER_QS_DIR/Theme.qml"

    # Cập nhật cache quickshell-theme.json nếu có
    if [[ -f "$HOME/.cache/43pr/quickshell-theme.json" ]]; then
        python3 -c '
import json, os
path = os.path.expanduser("~/.cache/43pr/quickshell-theme.json")
try:
    with open(path, "r") as f:
        data = json.load(f)
    data["bgAlpha"] = 1.0
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
except Exception:
    pass
' 2>/dev/null || true
    fi
    substep "Đã thiết lập Theme.qml và cache theme: bgAlpha: 1.0, tiltStrength: 0"

    # 2. CẤU HÌNH PERSPECTIVEPANEL.QML: XÓA HIỆU ỨNG RUNG LẮC 3D (TILT/PARALLAX)
    info "2/5. Cấu hình PerspectivePanel.qml: loại bỏ lắc 3D, tối ưu animation mượt mà..."
    cat << 'EOF' > "$QS_DIR/PerspectivePanel.qml"
// PerspectivePanel.qml
import QtQuick

Item {
    id: root

    default property alias content: contentContainer.data
    property bool open: false
    property real tiltStrength: 0

    opacity: open ? 1 : 0
    visible: opacity > 0.01

    Behavior on opacity {
        NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic }
    }

    transform: [
        Scale {
            origin.x: root.width / 2
            origin.y: root.height / 2
            xScale: root.open ? 1 : 0.96
            yScale: root.open ? 1 : 0.96

            Behavior on xScale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
            Behavior on yScale { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutCubic } }
        }
    ]

    Item {
        id: contentContainer
        anchors.fill: parent
    }
}
EOF
    ln -sfn "$QS_DIR/PerspectivePanel.qml" "$USER_QS_DIR/PerspectivePanel.qml"
    substep "Đã cập nhật PerspectivePanel.qml: đã xóa hoàn toàn hiệu ứng lắc 3D"

    # 3. ĐỒNG BỘ VÀ LIÊN KẾT CÁC COMPONENT GIAO DIỆN QUICKSHELL
    info "3/5. Kiểm tra cấu hình liên kết các component QuickShell..."
    for f in "$QS_DIR"/*.qml; do
        local bname
        bname="$(basename "$f")"
        if [[ ! -e "$USER_QS_DIR/$bname" || -L "$USER_QS_DIR/$bname" ]]; then
            ln -sfn "$f" "$USER_QS_DIR/$bname"
        fi
    done
    substep "Đã liên kết toàn bộ component QuickShell từ .dotfiles sang ~/.config"

    # Cấu hình định dạng ngày giờ trên Bar: HH:mm | dd-MM-yyyy
    local BAR_FILE="$QS_DIR/Bar.qml"
    if [[ -f "$BAR_FILE" ]]; then
        if grep -q 'Qt.formatDateTime(clk.date, "HH:mm")' "$BAR_FILE"; then
            sed -i 's/Qt.formatDateTime(clk.date, "HH:mm")/Qt.formatDateTime(clk.date, "HH:mm | dd-MM-yyyy")/g' "$BAR_FILE"
            substep "Đã cập nhật định dạng đồng hồ trên Bar: HH:mm | dd-MM-yyyy"
        else
            substep "Định dạng đồng hồ trên Bar đã chuẩn (HH:mm | dd-MM-yyyy)"
        fi
    fi

    # Sửa lỗi popup notification: cố định hiển thị ở màn hình Philips bên trái (HDMI-A-2), tự đóng sau 3s và bổ sung thanh progress đếm ngược
    local NOTIF_FILE="$QS_DIR/Notifications.qml"
    if [[ -f "$NOTIF_FILE" ]]; then
        if ! grep -q 'progTrack' "$NOTIF_FILE" || grep -q 'return 5000;' "$NOTIF_FILE" || grep -q 'expireTimeout \* 1000' "$NOTIF_FILE" || ! grep -q 'findTargetScreen' "$NOTIF_FILE"; then
            python3 -c '
path = "'"$NOTIF_FILE"'"
with open(path, "r") as f:
    content = f.read()

# 1. Cố định vị trí popup hiển thị trên màn hình Philips bên trái (HDMI-A-2)
if "findTargetScreen" not in content and "PanelWindow {" in content:
    screen_patch = """PanelWindow {
    id: root

    function findTargetScreen() {
        const screens = Quickshell.screens;
        if (!screens || screens.length === 0) return null;
        const target = screens.find(s => s.name === "HDMI-A-2" || (s.model && (s.model.includes("241V8") || s.model.toLowerCase().includes("philips"))));
        return target || screens[0];
    }

    screen: root.findTargetScreen()

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.screen = root.findTargetScreen();
        }
    }"""
    content = content.replace("PanelWindow {\n    id: root", screen_patch)

# 2. Cấu hình thời gian tự đóng và thanh progress đếm ngược
old_timer = """Timer {
                    interval: wrapper.modelData.expireTimeout > 0 ? wrapper.modelData.expireTimeout * 1000 : 6000
                    running: !wrapper.critical && !hover.containsMouse && !wrapper.leaving
                    onTriggered: wrapper.close(true)
                }"""
old_timer2 = """Timer {
                    interval: {
                        const to = wrapper.modelData.expireTimeout;
                        if (to > 0) {
                            return to <= 60 ? to * 1000 : to;
                        }
                        return 5000;
                    }
                    running: !wrapper.critical && !hover.containsMouse && !wrapper.leaving
                    onTriggered: wrapper.close(true)
                }"""

new_timer = """Timer {
                    id: autoCloseTimer
                    interval: wrapper.timeoutMs
                    running: !wrapper.critical && !hover.containsMouse && !wrapper.leaving
                    onTriggered: wrapper.close(true)
                }

                NumberAnimation {
                    id: progAnim
                    target: wrapper
                    property: "progress"
                    from: 1.0
                    to: 0.0
                    duration: wrapper.timeoutMs
                    running: !wrapper.critical && !hover.containsMouse && !wrapper.leaving
                }"""

if "timeoutMs:" not in content and "readonly property bool critical: modelData.urgency === NotificationUrgency.Critical" in content:
    content = content.replace(
        "readonly property bool critical: modelData.urgency === NotificationUrgency.Critical",
        """readonly property bool critical: modelData.urgency === NotificationUrgency.Critical
                readonly property int timeoutMs: {
                    const to = wrapper.modelData.expireTimeout;
                    if (to > 0) {
                        return to <= 60 ? to * 1000 : to;
                    }
                    return 3000;
                }
                property real progress: 1.0"""
    )

if old_timer in content:
    content = content.replace(old_timer, new_timer)
elif old_timer2 in content:
    content = content.replace(old_timer2, new_timer)

if "return 5000;" in content:
    content = content.replace("return 5000;", "return 3000;")

if "progTrack" not in content:
    prog_block = """                    // Thanh process đếm ngược thời gian tự đóng
                    Rectangle {
                        id: progTrack
                        visible: !wrapper.critical
                        anchors {
                            bottom: parent.bottom
                            bottomMargin: root.px(5)
                            left: parent.left
                            leftMargin: root.px(14)
                            right: parent.right
                            rightMargin: root.px(14)
                        }
                        height: root.px(3)
                        radius: root.px(1.5)
                        color: Theme.alpha(Theme.text, 0.08)

                        Rectangle {
                            id: progFill
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                            }
                            radius: parent.radius
                            width: Math.round(parent.width * Math.max(0.0, Math.min(1.0, wrapper.progress)))
                            color: hover.containsMouse ? Theme.accent : Theme.alpha(Theme.accent, 0.8)

                            Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        }
                    }
                }"""
    content = content.replace("                }\n            }\n        }\n    }\n\n    Item {\n        id: dragHandle", prog_block + "\n            }\n        }\n    }\n\n    Item {\n        id: dragHandle")

with open(path, "w") as f:
    f.write(content)
'
            substep "Đã cấu hình cố định màn hình Philips, thời gian tự đóng 3s và thanh process trong Notifications.qml"
        else
            substep "Cấu hình cố định màn hình Philips, thời gian tự đóng 3s và thanh process trong Notifications.qml đã chuẩn"
        fi
    fi

    # 4. CẤU HÌNH CLICK CPU/RAM TRÊN BAR MỞ POPUP BTOP NỔI
    info "4/5. Cấu hình popup btop nổi khi click CPU/RAM trên Bar..."
    pkg_install btop

    local HYPR_DIR="$HOME/.dotfiles/.config/hypr"
    local USER_HYPR_DIR="$HOME/.config/hypr"
    local HYPR_SCRIPTS="$HYPR_DIR/scripts"
    local USER_HYPR_SCRIPTS="$USER_HYPR_DIR/scripts"
    mkdir -p "$HYPR_SCRIPTS" "$USER_HYPR_SCRIPTS"

    # 4.1 Script toggle-btop.sh
    cat << 'EOF' > "$HYPR_SCRIPTS/toggle-btop.sh"
#!/usr/bin/env bash
# ==============================================================================
# Script: toggle-btop.sh
# Description: Bật/tắt popup btop nổi lên trên màn hình khi click CPU/RAM trên Bar
# ==============================================================================

if hyprctl clients -j | grep -q '"class": "btop-floating"'; then
    pkill -f "btop-floating"
else
    kitty --class btop-floating --title "btop" \
        -o remember_window_size=no \
        -o initial_window_width=1050 \
        -o initial_window_height=680 \
        -e btop &
fi
EOF
    chmod +x "$HYPR_SCRIPTS/toggle-btop.sh"
    cp -f "$HYPR_SCRIPTS/toggle-btop.sh" "$USER_HYPR_SCRIPTS/toggle-btop.sh"
    chmod +x "$USER_HYPR_SCRIPTS/toggle-btop.sh"

    # 4.2 Thêm window rule float-btop vào rules.lua nếu chưa có
    local RULES_FILE="$HYPR_DIR/rules.lua"
    if [[ -f "$RULES_FILE" ]]; then
        if ! grep -q "float-btop" "$RULES_FILE"; then
            cat << 'EOF' >> "$RULES_FILE"

-- Quy tắc popup floating cho btop khi click CPU/RAM trên Bar
hl.window_rule({
    name = "float-btop",
    match = { class = "^(btop-floating)$" },
    float = true,
    center = true,
    size = { 1050, 680 },
})
EOF
            substep "Đã thêm rule float-btop vào rules.lua"
        else
            substep "Rule float-btop đã có sẵn trong rules.lua"
        fi
    fi

    # 4.3 Cấu hình phím tắt âm lượng gọi Volume OSD
    local KEYBINDS_FILE="$HYPR_DIR/keybinds.lua"
    if [[ -f "$KEYBINDS_FILE" ]]; then
        if ! grep -q "qs ipc call volume show" "$KEYBINDS_FILE"; then
            sed -i 's/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+/wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+ \&\& qs ipc call volume show/g' "$KEYBINDS_FILE"
            sed -i 's/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- \&\& qs ipc call volume show/g' "$KEYBINDS_FILE"
            sed -i 's/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle \&\& qs ipc call volume show/g' "$KEYBINDS_FILE"
            substep "Đã tích hợp hiển thị Volume OSD vào phím tắt âm lượng trong keybinds.lua"
        else
            substep "Phím tắt âm lượng đã được tích hợp gọi Volume OSD"
        fi
    fi

    # 5. NẠP LẠI QUICKSHELL VÀ HYPRLAND
    info "5/5. Nạp lại tiến trình QuickShell và Hyprland config..."
    if command -v hyprctl &>/dev/null; then
        hyprctl reload config-only >/dev/null 2>&1 || true
    fi

    if pgrep -x qs >/dev/null; then
        pkill -x qs || true
        sleep 0.3
        qs -d >/dev/null 2>&1 || true
        substep "Đã khởi động lại QuickShell trong nền"
    else
        substep "QuickShell chưa chạy, sẽ được kích hoạt khi khởi động Hyprland"
    fi

    success "Module QuickShell Tweaks hoàn tất!"
}
