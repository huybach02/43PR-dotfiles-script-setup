#!/usr/bin/env bash
# ==============================================================================
# Module: 10-terminal-image-paste
# Description: Tự động đính kèm ảnh từ clipboard vào terminal của các AI agent
#              (antigravity-cli / agy, claude) hoặc dán đường dẫn file trong shell
#              thông qua phím tắt Ctrl + Shift + V trong Kitty.
# ==============================================================================

MODULE_NAME="terminal-image-paste"
MODULE_DESC="Tự động đính kèm ảnh từ clipboard vào terminal AI agent (agy, claude) khi bấm Ctrl+Shift+V"

run_module() {
    header "MODULE: $MODULE_DESC"

    # 1. CÀI ĐẶT CÁC GÓI PHỤ THUỘC
    info "1/4. Kiểm tra các gói phụ thuộc: kitty, wl-clipboard, python..."
    pkg_install kitty wl-clipboard python

    # 2. THIẾT LẬP KITTEN SCRIPT PASTE_IMAGE.PY
    info "2/4. Thiết lập kitten script thông minh paste_image.py trong Kitty..."
    local KITTY_DIRS=("$HOME/.config/kitty")
    [[ -d "$HOME/.dotfiles/.config/kitty" ]] && KITTY_DIRS+=("$HOME/.dotfiles/.config/kitty")

    local PRIMARY_KITTEN_PATH="$HOME/.config/kitty/paste_image.py"
    if [[ -d "$HOME/.dotfiles/.config/kitty" ]]; then
        PRIMARY_KITTEN_PATH="$HOME/.dotfiles/.config/kitty/paste_image.py"
    fi

    mkdir -p "$(dirname "$PRIMARY_KITTEN_PATH")"
    cat << 'EOF' > "$PRIMARY_KITTEN_PATH"
#!/usr/bin/env python3
"""
Kitty Kitten: Smart Clipboard Paste for AI Agents and Terminal
- Khi clipboard chứa ảnh:
  - Nếu đang ở trong AI agent (agy / antigravity-cli / claude): gửi tín hiệu Ctrl+V (\x16)
    để kích hoạt tính năng đính kèm đa phương tiện trực tiếp (media attachment).
  - Nếu ở trong terminal thông thường (shell, aider, python, v.v.): tự động lưu ảnh vào
    ~/Pictures/Screenshots/ và dán đường dẫn file tuyệt đối.
- Khi clipboard chứa văn bản thông thường:
  - Dán văn bản bình thường như mặc định của Kitty.
"""

import os
import subprocess
import time
from datetime import datetime
from typing import Any, List

from kittens.tui.handler import result_handler
from kitty.boss import Boss


def main(args: List[str]) -> None:
    pass


def get_clipboard_image_types() -> List[str]:
    try:
        proc = subprocess.run(
            ["wl-paste", "--list-types"],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            timeout=1,
            check=True,
        )
        types = proc.stdout.decode("utf-8", errors="ignore").splitlines()
        return [t.strip() for t in types if t.strip().startswith("image/")]
    except Exception:
        return []


def is_ai_agent(w: Any) -> bool:
    try:
        exe = (w.get_exe_of_child() or "").lower()
    except Exception:
        exe = ""

    try:
        cmdline_list = getattr(w.child, "foreground_cmdline", []) or []
        cmdline = " ".join(cmdline_list).lower()
    except Exception:
        cmdline = ""

    agent_keywords = ("agy", "antigravity", "claude")
    if any(k in exe or k in cmdline for k in agent_keywords):
        return True

    # Kiểm tra tiến trình con nếu chạy qua subshell/wrapper/tmux
    try:
        pid = getattr(w.child, "pid", None)
        if pid:
            out = subprocess.check_output(
                ["pgrep", "-P", str(pid)],
                stderr=subprocess.DEVNULL,
                timeout=0.5,
            ).decode()
            for cpid in out.split():
                try:
                    with open(f"/proc/{cpid}/cmdline", "rb") as f:
                        c_cmd = f.read().replace(b"\x00", b" ").decode(errors="ignore").lower()
                        if any(k in c_cmd for k in agent_keywords):
                            return True
                except Exception:
                    pass
    except Exception:
        pass

    return False


def get_or_save_image_path(img_type: str) -> str:
    screenshots_dir = os.path.expanduser("~/Pictures/Screenshots")
    os.makedirs(screenshots_dir, exist_ok=True)

    # 1. Kiểm tra ảnh chụp màn hình vừa được tạo gần đây (trong 15s)
    try:
        files = [
            os.path.join(screenshots_dir, f)
            for f in os.listdir(screenshots_dir)
            if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp"))
        ]
        if files:
            newest = max(files, key=os.path.getmtime)
            if (time.time() - os.path.getmtime(newest)) < 15:
                return newest
    except Exception:
        pass

    # 2. Nếu là ảnh copy từ web/ứng dụng khác, lưu file mới
    ext = "png"
    if "jpeg" in img_type or "jpg" in img_type:
        ext = "jpg"
    elif "webp" in img_type:
        ext = "webp"

    filepath = os.path.join(
        screenshots_dir,
        f"Clipboard_{datetime.now().strftime('%Y-%m-%d_%H-%M-%S')}.{ext}",
    )
    try:
        with open(filepath, "wb") as f:
            subprocess.run(
                ["wl-paste", "--type", img_type],
                stdout=f,
                stderr=subprocess.DEVNULL,
                timeout=2,
                check=True,
            )
        return filepath
    except Exception:
        return ""


@result_handler(no_ui=True)
def handle_result(args: List[str], answer: Any, target_window_id: int, boss: Boss) -> None:
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return

    image_types = get_clipboard_image_types()

    if not image_types:
        # Clipboard là văn bản -> Dán chữ bình thường
        boss.paste_from_clipboard()
        return

    # Clipboard là ảnh!
    if is_ai_agent(w):
        # AI agent: Gửi Ctrl+V (\x16) để agent tự động đính kèm file media vào prompt
        w.write_to_child(b"\x16")
    else:
        # Shell hoặc ứng dụng khác: Lấy hoặc lưu ảnh và dán đường dẫn file
        path = get_or_save_image_path(image_types[0])
        if path:
            w.paste_with_actions(path)
        else:
            boss.paste_from_clipboard()
EOF
    chmod +x "$PRIMARY_KITTEN_PATH"
    substep "Đã tạo script: $PRIMARY_KITTEN_PATH"

    # Đảm bảo symlink từ ~/.config/kitty sang ~/.dotfiles/.config/kitty nếu có dotfiles
    if [[ -d "$HOME/.dotfiles/.config/kitty" && "$PRIMARY_KITTEN_PATH" != "$HOME/.config/kitty/paste_image.py" ]]; then
        mkdir -p "$HOME/.config/kitty"
        ln -sfn "$PRIMARY_KITTEN_PATH" "$HOME/.config/kitty/paste_image.py"
        substep "Đã tạo symlink ~/.config/kitty/paste_image.py -> $PRIMARY_KITTEN_PATH"
    fi

    # 3. CẬU HÌNH PHÍM TẮT TRONG KITTY.CONF
    info "3/4. Cấu hình phím tắt Ctrl + Shift + V trong kitty.conf..."
    local CONFIG_FILES=()
    [[ -f "$HOME/.dotfiles/.config/kitty/kitty.conf" ]] && CONFIG_FILES+=("$HOME/.dotfiles/.config/kitty/kitty.conf")
    [[ -f "$HOME/.config/kitty/kitty.conf" ]] && CONFIG_FILES+=("$HOME/.config/kitty/kitty.conf")

    for cfg in "${CONFIG_FILES[@]}"; do
        # Tránh trùng lặp nếu là symlink cùng một file thực
        local real_cfg
        real_cfg="$(realpath "$cfg")"

        if grep -q "paste_image.py" "$real_cfg"; then
            substep "Phím tắt đã tồn tại trong $(basename "$cfg"): map ctrl+shift+v kitten paste_image.py"
        else
            printf "\n# Smart paste: auto-attach clipboard image in AI agents (agy / claude) or paste image path\nmap ctrl+shift+v kitten paste_image.py\n" >> "$real_cfg"
            substep "Đã thêm phím tắt vào: $cfg"
        fi
    done

    # 4. TẢI LẠI CẤU HÌNH KITTY ĐANG CHẠY
    info "4/4. Tải lại cấu hình cho các cửa sổ Kitty đang hoạt động..."
    local KITTY_PIDS
    KITTY_PIDS="$(pgrep -x kitty || true)"
    if [[ -n "$KITTY_PIDS" ]]; then
        kill -SIGUSR1 $KITTY_PIDS 2>/dev/null || true
        substep "Đã gửi tín hiệu SIGUSR1 reload cấu hình tới Kitty (PIDs: $KITTY_PIDS)"
    else
        substep "Không có tiến trình Kitty nào đang chạy."
    fi

    success "Hoàn tất module Terminal AI Image Paste!"
}
