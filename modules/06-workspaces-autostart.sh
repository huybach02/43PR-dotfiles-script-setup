#!/usr/bin/env bash
# ==============================================================================
# Module: 06-workspaces-autostart
# Description: Đặt tên, hiển thị tên workspace theo từng màn hình, cố định ứng dụng & Autostart
# ==============================================================================

MODULE_NAME="workspaces-autostart"
MODULE_DESC="Đặt tên, hiển thị tên workspace theo từng màn hình trên Bar, cố định ứng dụng & Autostart"

run_module() {
    header "MODULE: $MODULE_DESC"

    local RULES_FILE="$HOME/.config/hypr/rules.lua"
    local HYPR_FILE="$HOME/.config/hypr/hyprland.lua"
    local BAR_FILE="$HOME/.config/quickshell/Bar.qml"

    # 1. CẬP NHẬT RULES.LUA ĐỂ CỐ ĐỊNH ỨNG DỤNG VÀO WORKSPACE
    info "1/4. Cấu hình window rules để cố định ứng dụng vào Workspace..."
    if [[ -f "$RULES_FILE" ]]; then
        if ! grep -q "workspace-edge" "$RULES_FILE"; then
            cat << 'EOF' >> "$RULES_FILE"

-- Cố định ứng dụng vào Workspace tương ứng
hl.window_rule({
    name = "workspace-edge",
    match = { class = "^(microsoft-edge)$" },
    workspace = "1",
})

hl.window_rule({
    name = "workspace-firefox",
    match = { class = "^(firefox)$" },
    workspace = "2",
})

hl.window_rule({
    name = "workspace-vscode",
    match = { class = "^(com\\.microsoft\\.VSCode|code)$" },
    workspace = "3",
})
EOF
            substep "Đã thêm rules cố định Edge -> WS 1, Firefox -> WS 2, VSCode -> WS 3 vào rules.lua"
        else
            substep "Rules cố định ứng dụng đã có sẵn trong rules.lua"
        fi
    fi

    # 2. CẬP NHẬT TỰ ĐỘNG ĐẶT TÊN VÀ AUTOSTART TRONG HYPRLAND.LUA
    info "2/4. Cấu hình đặt tên và autostart trong hyprland.lua..."
    if [[ -f "$HYPR_FILE" ]]; then
        if ! grep -q "workspace\.rename" "$HYPR_FILE"; then
            sed -i '/hl\.on("hyprland\.start"/,/end)/ {
                /end)/ i \    -- Đặt tên định danh cho các workspace\n    hl.dispatch(hl.dsp.workspace.rename({ workspace = 1, name = "Edge" }))\n    hl.dispatch(hl.dsp.workspace.rename({ workspace = 2, name = "Firefox" }))\n    hl.dispatch(hl.dsp.workspace.rename({ workspace = 3, name = "VSCode" }))
            }' "$HYPR_FILE"
            substep "Đã thêm lệnh đặt tên workspace vào hyprland.lua"
        else
            substep "Lệnh đặt tên workspace đã có sẵn trong hyprland.lua"
        fi

        if ! grep -q "microsoft-edge-stable" "$HYPR_FILE"; then
            sed -i '/hl\.on("hyprland\.start"/,/end)/ {
                /end)/ i \    -- Tự động mở Edge, VSCode, Firefox khi khởi động\n    hl.exec_cmd("sleep 1 && microsoft-edge-stable")\n    hl.exec_cmd("sleep 1 && code")\n    hl.exec_cmd("sleep 1 && firefox")
            }' "$HYPR_FILE"
            substep "Đã thêm lệnh autostart Edge, VSCode, Firefox vào hyprland.lua"
        else
            substep "Lệnh autostart đã có sẵn trong hyprland.lua"
        fi

        # Cấu hình con trỏ chuột không tự nhảy khi chuyển workspace
        if ! grep -q "no_warps" "$HYPR_FILE"; then
            cat << 'EOF' >> "$HYPR_FILE"

-- CURSOR (Giữ nguyên vị trí con trỏ chuột khi chuyển workspace, không tự nhảy)
hl.config({
    cursor = {
        no_warps = true,
        warp_on_change_workspace = 0,
    },
})
EOF
            substep "Đã thêm cấu hình cursor không tự nhảy vị trí vào hyprland.lua"
        fi
    fi

    # 3. HIỂN THỊ TÊN WORKSPACE THEO TỪNG MÀN HÌNH TRÊN THANH BAR (QUICKSHELL)
    info "3/4. Cấu hình hiển thị tên workspace theo từng màn hình trên thanh Bar (QuickShell)..."
    if [[ -f "$BAR_FILE" ]]; then
        # Cập nhật barScreen cho Slot nếu chưa có
        if ! grep -q "barScreen: bar.screen" "$BAR_FILE"; then
            sed -i 's/component Slot: Loader {/component Slot: Loader {\n        property var barScreen: null/' "$BAR_FILE"
            sed -i '/id: startLane/,/Repeater {/ s/delegate: Slot {}/delegate: Slot { barScreen: bar.screen }/' "$BAR_FILE"
            sed -i '/id: clockLane/,/Repeater {/ s/delegate: Slot { clockComp: clockC }/delegate: Slot { clockComp: clockC; barScreen: bar.screen }/' "$BAR_FILE"
            sed -i '/id: endLane/,/Repeater {/ s/delegate: Slot {}/delegate: Slot { barScreen: bar.screen }/' "$BAR_FILE"
            substep "Đã liên kết barScreen vào các Slot trong Bar.qml"
        fi

        # Cập nhật wsC delegate để lọc workspace theo màn hình và hiển thị tên
        if ! grep -q "targetScreenName" "$BAR_FILE"; then
            python3 - "$BAR_FILE" << 'PYEOF'
import sys, re
bar_file = sys.argv[1]
with open(bar_file, "r") as f:
    content = f.read()

pattern = r"    Component \{\s+id: wsC\s+Item \{[\s\S]*?WheelHandler \{[\s\S]*?\}\s+\}\s+\}"

replacement = """    Component {
        id: wsC
        Item {
            id: wsRoot
            readonly property var targetScreen: parent && parent.barScreen ? parent.barScreen : null
            readonly property string targetScreenName: targetScreen && targetScreen.name ? targetScreen.name : ""

            implicitWidth: root.vertical ? root.panelThick : wsLane.implicitWidth + 12
            implicitHeight: wsLane.implicitHeight + (root.vertical ? 12 : 0)

            Lane {
                id: wsLane
                anchors.centerIn: parent
                gap: 8

                Repeater {
                    model: Hyprland.workspaces
                    delegate: Rectangle {
                        id: dot
                        required property var modelData

                        readonly property string monitorName: {
                            if (modelData.monitor && modelData.monitor.name) return modelData.monitor.name;
                            if (modelData.lastIpcObject && modelData.lastIpcObject.monitor) return modelData.lastIpcObject.monitor;
                            const philipsWs = [1, 3, 5, 6, 7];
                            const aocWs = [2, 4, 8, 9];
                            if (philipsWs.indexOf(modelData.id) !== -1) return "HDMI-A-2";
                            if (aocWs.indexOf(modelData.id) !== -1) return "DP-2";
                            return "";
                        }

                        // Chỉ hiển thị workspace thuộc về màn hình này
                        visible: {
                            if (modelData.id <= 0) return false;
                            if (wsRoot.targetScreenName === "") return true;
                            return dot.monitorName === wsRoot.targetScreenName;
                        }

                        Layout.alignment: Qt.AlignCenter

                        readonly property string wsTitle: {
                            if (modelData.name && modelData.name !== "" && modelData.name !== ("" + modelData.id)) {
                                return modelData.id + ": " + modelData.name;
                            }
                            switch (modelData.id) {
                                case 1: return "1: Edge";
                                case 2: return "2: Firefox";
                                case 3: return "3: VSCode";
                                default: return "" + modelData.id;
                            }
                        }

                        implicitWidth: visible ? (root.vertical ? (root.panelThick - 8) : Math.max(22, wsLabel.implicitWidth + 12)) : 0
                        implicitHeight: visible ? (root.vertical ? 22 : 18) : 0
                        radius: 4

                        color: modelData.urgent ? Theme.danger
                             : modelData.focused ? Qt.alpha(Theme.accent, 0.25)
                             : dotMa.containsMouse ? Qt.alpha(Theme.accent2, 0.2)
                             : Qt.alpha(Theme.bgCard, 0.6)

                        border.width: visible ? 1 : 0
                        border.color: modelData.urgent ? Theme.danger
                                    : modelData.focused ? Theme.accent
                                    : dotMa.containsMouse ? Theme.accent2
                                    : Qt.alpha(Theme.border, 0.4)

                        Behavior on implicitWidth { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }
                        Behavior on implicitHeight { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutQuad } }

                        Text {
                            id: wsLabel
                            visible: dot.visible
                            anchors.centerIn: parent
                            text: dot.wsTitle
                            color: dot.modelData.urgent ? "#ffffff"
                                 : dot.modelData.focused ? Theme.accent
                                 : dotMa.containsMouse ? Theme.text
                                 : Theme.textDim
                            font.family: Theme.fontFamily
                            font.pixelSize: 10
                            font.bold: dot.modelData.focused
                        }

                        MouseArea {
                            id: dotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dot.modelData.activate()
                        }
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => root.run(e.angleDelta.y < 0
                    ? "hyprctl dispatch \'hl.dsp.focus({workspace=\\\"m+1\\\"})\'"
                    : "hyprctl dispatch \'hl.dsp.focus({workspace=\\\"m-1\\\"})\'")
            }
        }
    }"""

if re.search(pattern, content):
    content = re.sub(pattern, replacement, content)
    with open(bar_file, "w") as f:
        f.write(content)
PYEOF
            substep "Đã cấu hình Bar.qml chỉ hiển thị workspace theo màn hình tương ứng"
        else
            substep "Bar.qml đã được lọc workspace theo từng màn hình"
        fi
    fi

    # 4. CẤU HÌNH PHÍM TẮT CON LĂN CHUỘT (SUPER + SCROLL) ĐỔI WORKSPACE
    info "4/5. Cấu hình phím tắt Super + Scroll con lăn chuột chuyển đổi workspace..."
    local KEYBINDS_FILES=("$HOME/.config/hypr/keybinds.lua")
    [[ -f "$HOME/.dotfiles/.config/hypr/keybinds.lua" ]] && KEYBINDS_FILES+=("$HOME/.dotfiles/.config/hypr/keybinds.lua")

    for kfile in "${KEYBINDS_FILES[@]}"; do
        if [[ -f "$kfile" ]]; then
            python3 - "$kfile" << 'PYEOF'
import sys, re
path = sys.argv[1]
with open(path, "r") as f:
    content = f.read()

# Xóa bind cũ mouse_down / mouse_up zoom
content = re.sub(r'hl\.bind\(mainMod\s*\.\.\s*"\s*\+\s*mouse_down"[^\n]*\n', "", content)
content = re.sub(r'hl\.bind\(mainMod\s*\.\.\s*"\s*\+\s*mouse_up"[^\n]*\n', "", content)

# Thêm bind mới chuyển đổi workspace
new_binds = """-- Chuyển đổi workspace bằng con lăn chuột: Cuộn xuống -> workspace tiếp theo (m+1), Cuộn lên -> workspace trước đó (m-1)
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "m-1" }))
"""

if 'workspace = "m+1"' not in content:
    if "-- Zoom" in content:
        content = content.replace("-- Zoom", new_binds + "\n-- Zoom")
    else:
        content += "\n" + new_binds

with open(path, "w") as f:
    f.write(content)
PYEOF
            substep "Đã cập nhật phím tắt Super + Scroll vào $kfile"
        fi
    done

    # 5. ÁP DỤNG TRỰC TIẾP NẾU HYPRLAND VÀ QUICKSHELL ĐANG CHẠY
    info "5/5. Áp dụng thay đổi trực tiếp..."
    if pgrep -x Hyprland >/dev/null 2>&1; then
        hyprctl eval '
hl.dispatch(hl.dsp.workspace.rename({ workspace = 1, name = "Edge" }))
hl.dispatch(hl.dsp.workspace.rename({ workspace = 2, name = "Firefox" }))
hl.dispatch(hl.dsp.workspace.rename({ workspace = 3, name = "VSCode" }))
' >/dev/null 2>&1 || true
        hyprctl reload >/dev/null 2>&1 || true

        # Khởi động lại QuickShell qua Hyprland daemon
        killall qs 2>/dev/null || true
        hyprctl eval 'hl.dispatch(hl.dsp.exec_cmd("qs"))' >/dev/null 2>&1 || true
        substep "Đã áp dụng cấu hình và reload QuickShell thành công"
    fi

    success "Module 06-workspaces-autostart: Hoàn tất cấu hình!"
}
