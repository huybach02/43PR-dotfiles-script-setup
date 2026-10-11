#!/usr/bin/env bash
# ==============================================================================
# Module: 14-cloudflare-warp
# Description: Cài đặt Cloudflare WARP (warp-cli), kích hoạt service warp-svc
#              và tích hợp icon bật/tắt nhanh lên thanh Bar (QuickShell).
# ==============================================================================

MODULE_NAME="warp"
MODULE_DESC="Cài đặt Cloudflare WARP (warp-cli) và tích hợp nút bật/tắt nhanh trên thanh Bar"

run_module() {
    header "MODULE: $MODULE_DESC"

    # 1. CÀI ĐẶT GÓI CLOUDFLARE WARP
    info "1/5. Kiểm tra và cài đặt gói cloudflare-warp-bin..."
    pkg_install cloudflare-warp-bin

    # 2. BẬT VÀ KHỞI CHẠY SYSTEMD SERVICE
    info "2/5. Kích hoạt và khởi chạy dịch vụ warp-svc.service..."
    if ! systemctl is-enabled --quiet warp-svc.service 2>/dev/null; then
        sudo systemctl enable warp-svc.service 2>/dev/null || true
    fi
    sudo systemctl restart warp-svc.service 2>/dev/null || true
    substep "Dịch vụ warp-svc.service đã được khởi chạy"

    # Chờ socket của warp daemon sẵn sàng
    local RETRIES=10
    while [[ $RETRIES -gt 0 ]]; do
        if warp-cli status >/dev/null 2>&1; then
            break
        fi
        sleep 1
        RETRIES=$((RETRIES - 1))
    done

    # 3. THIẾT LẬP ĐĂNG KÝ VÀ CHẾ ĐỘ WARP BAN ĐẦU
    info "3/5. Cấu hình ban đầu cho warp-cli..."
    warp-cli registration new 2>/dev/null || warp-cli register 2>/dev/null || true
    warp-cli mode warp 2>/dev/null || true
    substep "Trạng thái warp-cli: $(warp-cli status 2>/dev/null | grep -i 'Status update:' || echo 'Sẵn sàng')"

    # 4. THIẾT LẬP SCRIPTS ĐIỀU KHIỂN CHO QUICKSHELL
    info "4/5. Thiết lập scripts warp-status.sh và warp-toggle.sh cho QuickShell..."
    local QS_SCRIPTS_DIR="$HOME/.dotfiles/.config/quickshell/scripts"
    mkdir -p "$QS_SCRIPTS_DIR"

    cat << 'EOF' > "$QS_SCRIPTS_DIR/warp-status.sh"
#!/usr/bin/env bash
if ! command -v warp-cli >/dev/null 2>&1; then
    echo "uninstalled"
    exit 0
fi

STATUS_OUT="$(warp-cli status 2>/dev/null || true)"

if echo "$STATUS_OUT" | grep -qi "Status update: Connected"; then
    echo "connected"
elif echo "$STATUS_OUT" | grep -qi "Status update: Connecting"; then
    echo "connecting"
else
    echo "disconnected"
fi
EOF
    chmod +x "$QS_SCRIPTS_DIR/warp-status.sh"

    cat << 'EOF' > "$QS_SCRIPTS_DIR/warp-toggle.sh"
#!/usr/bin/env bash
if ! command -v warp-cli >/dev/null 2>&1; then
    notify-send -a "Cloudflare WARP" -i dialog-error "Cloudflare WARP" "Chưa cài đặt warp-cli! Vui lòng cài đặt cloudflare-warp-bin."
    exit 1
fi

if ! systemctl is-active --quiet warp-svc.service 2>/dev/null; then
    notify-send -a "Cloudflare WARP" -i dialog-warning "Cloudflare WARP" "Service warp-svc chưa được bật. Đang khởi động service..."
    pkexec systemctl start warp-svc.service 2>/dev/null || true
    sleep 1
fi

STATUS_OUT="$(warp-cli status 2>/dev/null || true)"

if echo "$STATUS_OUT" | grep -qi "Status update: Connected"; then
    warp-cli disconnect >/dev/null 2>&1 || true
    notify-send -a "Cloudflare WARP" -i network-vpn "Cloudflare WARP" "Đã ngắt kết nối WARP ✕"
else
    if echo "$STATUS_OUT" | grep -qi "Registration missing"; then
        warp-cli registration new >/dev/null 2>&1 || warp-cli register >/dev/null 2>&1 || true
        warp-cli mode warp >/dev/null 2>&1 || true
    fi
    warp-cli connect >/dev/null 2>&1 || true
    notify-send -a "Cloudflare WARP" -i network-vpn "Cloudflare WARP" "Đang kết nối Cloudflare WARP..."
fi
EOF
    chmod +x "$QS_SCRIPTS_DIR/warp-toggle.sh"
    substep "Đã cập nhật các script điều khiển trong $QS_SCRIPTS_DIR"

    # 5. CẬP NHẬT CẤU HÌNH BAR.QML VÀ BAR-STATE.JSON
    info "5/5. Kích hoạt hiển thị icon WARP trên thanh Bar..."
    local BAR_FILE="$HOME/.dotfiles/.config/quickshell/Bar.qml"
    if [[ -f "$BAR_FILE" ]] && ! grep -q "id: warpC" "$BAR_FILE"; then
        python3 - "$BAR_FILE" << 'PYEOF'
import sys, re
bar_file = sys.argv[1]
with open(bar_file, "r") as f:
    c = f.read()

if '"warp"' not in c:
    c = re.sub(r'("net",\s*)"notif"', r'\1"warp", "notif"', c)

if '{ id: "warp"' not in c:
    c = re.sub(r'(\{\s*id:\s*"net"[^}]*\},)', r'\1\n        { id: "warp", l: "Cloudflare WARP", k: "showWarp" },', c)

if 'case "warp":' not in c:
    c = re.sub(r'(case "net": return cfg\.showNet;)', r'\1\n        case "warp": return cfg.showWarp !== undefined ? cfg.showWarp : true;', c)

if 'case "warp": return warpC;' not in c:
    c = re.sub(r'(case "net": return netC;)', r'\1\n        case "warp": return warpC;', c)

if 'property string warpStatus' not in c:
    warp_proc = """    property string warpStatus: "disconnected"
    Process {
        id: warpProc
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/warp-status.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = text.trim();
                if (s !== "" && s !== root.warpStatus) root.warpStatus = s;
            }
        }
    }
    Timer {
        id: warpTimer
        interval: 2000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: if (!warpProc.running) warpProc.running = true
    }
"""
    c = re.sub(r'(\s*PwObjectTracker\s*\{)', r'\n' + warp_proc + r'\n\1', c)

if 'id: warpC' not in c:
    warp_comp = """    Component {
        id: warpC
        Mod {
            baseSize: root.sizeClock
            glyphSize: root.sizeVolIcon
            glyph: "\\uf0c2"
            vglyph: "\\uf0c2"
            text: root.warpStatus === "connected" ? "WARP" : (root.warpStatus === "connecting" ? "..." : "")
            vtext: root.warpStatus === "connected" ? "ON" : (root.warpStatus === "connecting" ? ".." : "OFF")
            color: root.warpStatus === "connected" ? Theme.ok
                 : root.warpStatus === "connecting" ? Theme.accent
                 : Theme.textDim
            bold: root.warpStatus === "connected"
            onClicked: {
                root.run(Quickshell.env("HOME") + "/.config/quickshell/scripts/warp-toggle.sh");
                warpTimer.restart();
            }
        }
    }
"""
    c = re.sub(r'(\s*Component\s*\{\s*id:\s*notifC)', r'\n' + warp_comp + r'\n\1', c)

with open(bar_file, "w") as f:
    f.write(c)
PYEOF
        substep "Đã tích hợp component WARP vào Bar.qml"
    fi

    local STATE_FILE="$HOME/.config/quickshell/state/bar-state.json"
    if [[ -f "$STATE_FILE" ]]; then
        python3 -c '
import json, os
path = os.path.expanduser("~/.config/quickshell/state/bar-state.json")
try:
    with open(path, "r") as f:
        data = json.load(f)
    end_mods = data.get("endMods", "")
    if "warp" not in end_mods:
        parts = [p.strip() for p in end_mods.split(",") if p.strip()]
        if "net" in parts:
            idx = parts.index("net") + 1
            parts.insert(idx, "warp")
        else:
            parts.append("warp")
        data["endMods"] = ",".join(parts)
    data["showWarp"] = True
    with open(path, "w") as f:
        json.dump(data, f, indent=4)
except Exception:
    pass
' 2>/dev/null || true
    fi

    # Khởi động lại QuickShell trong nền bằng cờ daemonize (-d)
    if pgrep -x qs >/dev/null 2>&1; then
        pkill -x qs 2>/dev/null || true
        sleep 0.3
    fi
    qs -d >/dev/null 2>&1 || true
    substep "Đã nạp lại QuickShell thành công"

    success "Hoàn tất cài đặt Cloudflare WARP và tích hợp thanh Bar!"
}
