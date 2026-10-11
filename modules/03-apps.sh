#!/usr/bin/env bash
# ==============================================================================
# Module: 03-apps
# Description: Cài đặt các ứng dụng phần mềm theo yêu cầu người dùng
# ==============================================================================

MODULE_NAME="apps"
MODULE_DESC="Cài đặt phần mềm: Microsoft Edge, VS Code, LibreOffice, Sublime Text, AppImageLauncher"

run_module() {
    header "MODULE: $MODULE_DESC"

    # 1. LibreOffice (Repo chính thức)
    info "1/5. Cài đặt LibreOffice..."
    pkg_install libreoffice-fresh

    # 2. Microsoft Edge (AUR)
    info "2/5. Cài đặt Microsoft Edge..."
    aur_install microsoft-edge-stable-bin

    # 3. Visual Studio Code (AUR official binary)
    info "3/5. Cài đặt Visual Studio Code..."
    aur_install visual-studio-code-bin

    # 4. Sublime Text (AUR)
    info "4/5. Cài đặt Sublime Text 4..."
    aur_install sublime-text-4

    # 5. AppImageLauncher (AUR)
    info "5/5. Cài đặt AppImageLauncher..."
    aur_install appimagelauncher-beta-bin

    success "Module 03-apps: Đã cài đặt đầy đủ tất cả các ứng dụng phần mềm!"
}
