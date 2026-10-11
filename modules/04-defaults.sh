#!/usr/bin/env bash
# ==============================================================================
# Module: 04-defaults
# Description: Thiết lập Edge làm trình duyệt mặc định, Sublime Text làm editor mặc định
# ==============================================================================

MODULE_NAME="defaults"
MODULE_DESC="Thiết lập ứng dụng mặc định (Edge là trình duyệt, Sublime Text là editor)"

run_module() {
    header "MODULE: $MODULE_DESC"

    # --------------------------------------------------------------------------
    # 1. THIẾT LẬP MICROSOFT EDGE LÀM TRÌNH DUYỆT MẶC ĐỊNH
    # --------------------------------------------------------------------------
    info "Đang thiết lập Microsoft Edge làm trình duyệt web mặc định..."

    local EDGE_DESKTOP="microsoft-edge.desktop"

    if command -v xdg-settings >/dev/null 2>&1; then
        xdg-settings set default-web-browser "$EDGE_DESKTOP" 2>/dev/null || true
        substep "xdg-settings: Đã đặt default-web-browser -> $EDGE_DESKTOP"
    fi

    if command -v xdg-mime >/dev/null 2>&1; then
        local BROWSER_MIMES=(
            "x-scheme-handler/http"
            "x-scheme-handler/https"
            "text/html"
            "application/xhtml+xml"
            "x-scheme-handler/about"
            "x-scheme-handler/unknown"
        )
        for mime in "${BROWSER_MIMES[@]}"; do
            xdg-mime default "$EDGE_DESKTOP" "$mime" 2>/dev/null || true
        done
        substep "xdg-mime: Đã liên kết các giao thức web (http, https, html) sang Edge"
    fi

    # Cập nhật cấu hình phím tắt trình duyệt trong Hyprland (Super + B)
    local HYPR_CFG="$HOME/.config/hypr/hyprland.lua"
    if [[ -f "$HYPR_CFG" ]]; then
        if grep -q 'browser[[:space:]]*=' "$HYPR_CFG"; then
            sed -i 's/browser[[:space:]]*=.*/browser    = "microsoft-edge-stable"/' "$HYPR_CFG"
            substep "Hyprland: Đã cập nhật phím tắt Super + B mở Microsoft Edge"
        fi
    fi

    success "Microsoft Edge đã được đặt làm trình duyệt mặc định!"

    # --------------------------------------------------------------------------
    # 2. THIẾT LẬP SUBLIME TEXT LÀM TRÌNH EDITOR MẶC ĐỊNH
    # --------------------------------------------------------------------------
    info "Đang thiết lập Sublime Text làm trình soạn thảo văn bản / editor mặc định..."

    local SUBLIME_DESKTOP="sublime_text.desktop"

    if command -v xdg-mime >/dev/null 2>&1; then
        local EDITOR_MIMES=(
            "text/plain"
            "text/markdown"
            "text/x-c"
            "text/x-c++"
            "text/x-python"
            "text/x-shellscript"
            "application/x-shellscript"
            "application/json"
            "application/xml"
            "text/xml"
            "text/x-readme"
            "text/x-log"
        )
        for mime in "${EDITOR_MIMES[@]}"; do
            xdg-mime default "$SUBLIME_DESKTOP" "$mime" 2>/dev/null || true
        done
        substep "xdg-mime: Đã liên kết các định dạng văn bản & mã nguồn sang Sublime Text"
    fi

    # Cấu hình biến môi trường EDITOR và VISUAL trong shell (~/.zshrc và ~/.bashrc)
    local SHELL_FILES=("$HOME/.zshrc" "$HOME/.bashrc")
    for shfile in "${SHELL_FILES[@]}"; do
        if [[ -f "$shfile" ]]; then
            if ! grep -q 'export EDITOR=.*subl' "$shfile" 2>/dev/null; then
                printf '\n# Default Editor: Sublime Text\nexport EDITOR="subl -w"\nexport VISUAL="subl -w"\n' >> "$shfile"
                substep "Đã thêm export EDITOR=\"subl -w\" vào $shfile"
            else
                substep "EDITOR=\"subl -w\" đã có sẵn trong $shfile"
            fi
        fi
    done

    # Cập nhật desktop database nếu cần
    if [[ -d "$HOME/.local/share/applications" ]]; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi

    success "Sublime Text đã được đặt làm trình soạn thảo (editor) mặc định!"
}
