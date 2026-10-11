#!/usr/bin/env bash
# ==============================================================================
# Module: 15-flutter
# Description: Cài đặt Flutter SDK, Android SDK, Android Studio, chấp nhận license
#              và thiết lập cơ chế tự động đồng bộ Toolbar bám sát cạnh phải máy ảo.
#
# Lưu ý: Module này có MODULE_OPT_IN=true nên mặc định sẽ BỎ QUA khi chạy
#        './setup.sh' hoặc './setup.sh all'. Chỉ chạy khi gọi riêng:
#        './setup.sh flutter' hoặc './setup.sh 15-flutter'.
# ==============================================================================

MODULE_NAME="flutter"
MODULE_DESC="Cài đặt Flutter SDK, Android SDK (dùng VS Code) & tự động bám Toolbar máy ảo"
MODULE_OPT_IN=true

run_module() {
    header "MODULE: $MODULE_DESC"

    # 1. CÀI ĐẶT CÁC GÓI PHỤ THUỘC TỪ REPO CHÍNH THỨC
    info "1/6. Cài đặt OpenJDK 17 LTS, công cụ Android và thư viện build Flutter Desktop..."
    local PKGS=(
        jdk17-openjdk
        clang
        cmake
        ninja
        pkgconf
        gtk3
        unzip
        zip
        curl
        git
    )
    pkg_install "${PKGS[@]}"

    # Thiết lập OpenJDK 17 làm Java mặc định
    if command -v archlinux-java &>/dev/null; then
        info "Thiết lập OpenJDK 17 làm phiên bản Java mặc định của hệ thống..."
        sudo archlinux-java set java-17-openjdk 2>/dev/null || true
        substep "Đã đặt default java: $(archlinux-java get 2>/dev/null || echo 'java-17-openjdk')"
    fi

    # 2. CÀI ĐẶT FLUTTER SDK (STABLE BRANCH) VÀO /opt/flutter
    info "2/6. Cài đặt Flutter SDK (kênh stable) vào /opt/flutter..."
    local FLUTTER_DIR="/opt/flutter"
    if [[ ! -d "$FLUTTER_DIR" ]]; then
        info "Đang tải mã nguồn Flutter SDK từ GitHub (nhánh stable)..."
        sudo git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_DIR"
        sudo chown -R "$USER:$USER" "$FLUTTER_DIR"
        substep "Đã tải Flutter SDK thành công vào $FLUTTER_DIR"
    else
        substep "Thư mục Flutter SDK đã tồn tại tại $FLUTTER_DIR"
        sudo chown -R "$USER:$USER" "$FLUTTER_DIR" 2>/dev/null || true
    fi

    # Tạo symlink vào /usr/local/bin để gọi trực tiếp ở mọi nơi
    if [[ -x "$FLUTTER_DIR/bin/flutter" ]]; then
        sudo ln -sf "$FLUTTER_DIR/bin/flutter" /usr/local/bin/flutter
        sudo ln -sf "$FLUTTER_DIR/bin/dart" /usr/local/bin/dart
        substep "Đã tạo symlink /usr/local/bin/flutter và /usr/local/bin/dart"
    fi

    # 3. CÀI ĐẶT ANDROID SDK & COMMAND-LINE TOOLS
    info "3/6. Cấu hình Android SDK và Command-line Tools tại $HOME/Android/Sdk..."
    local ANDROID_SDK_DIR="$HOME/Android/Sdk"
    local CMDLINE_DIR="$ANDROID_SDK_DIR/cmdline-tools/latest"
    mkdir -p "$ANDROID_SDK_DIR"

    if [[ ! -x "$CMDLINE_DIR/bin/sdkmanager" ]]; then
        info "Đang tải Android SDK Command-line Tools từ Google Developer..."
        local TMP_CMDLINE
        TMP_CMDLINE="$(mktemp -d)"
        local CMDLINE_ZIP="$TMP_CMDLINE/cmdline-tools.zip"
        local CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"

        curl -fSL "$CMDLINE_URL" -o "$CMDLINE_ZIP"
        unzip -q "$CMDLINE_ZIP" -d "$TMP_CMDLINE"

        mkdir -p "$ANDROID_SDK_DIR/cmdline-tools"
        rm -rf "$CMDLINE_DIR"
        mv "$TMP_CMDLINE/cmdline-tools" "$CMDLINE_DIR"
        rm -rf "$TMP_CMDLINE"
        substep "Đã cài đặt Android SDK Command-line Tools vào $CMDLINE_DIR"
    else
        substep "Android SDK Command-line Tools đã có sẵn tại $CMDLINE_DIR"
    fi

    # Cài đặt platform-tools, platforms, build-tools, emulator qua sdkmanager
    local SDKMANAGER="$CMDLINE_DIR/bin/sdkmanager"
    if [[ -x "$SDKMANAGER" ]]; then
        info "Tự động chấp nhận giấy phép SDK licenses..."
        yes 2>/dev/null | "$SDKMANAGER" --sdk_root="$ANDROID_SDK_DIR" --licenses >/dev/null 2>&1 || true

        info "Cài đặt các gói thành phần cốt lõi: platform-tools, platforms;android-36/34, build-tools;36/34/28, emulator, system-images..."
        "$SDKMANAGER" --sdk_root="$ANDROID_SDK_DIR" \
            "platform-tools" \
            "platforms;android-36" \
            "platforms;android-34" \
            "build-tools;36.0.0" \
            "build-tools;34.0.0" \
            "build-tools;28.0.3" \
            "emulator" \
            "system-images;android-34;google_apis;x86_64" || true
        substep "Hoàn tất cài đặt các thành phần Android SDK"

        # Tạo máy ảo Android AVD mặc định nếu chưa tồn tại
        local AVDMANAGER="$CMDLINE_DIR/bin/avdmanager"
        local DEFAULT_AVD_NAME="Pixel_API_34"
        if [[ -x "$AVDMANAGER" ]]; then
            info "Kiểm tra danh sách máy ảo Android (AVD)..."
            if ! "$AVDMANAGER" list avd 2>/dev/null | grep -q "Name: $DEFAULT_AVD_NAME"; then
                info "Đang tạo máy ảo mặc định '$DEFAULT_AVD_NAME'..."
                echo "no" | "$AVDMANAGER" create avd \
                    --name "$DEFAULT_AVD_NAME" \
                    --package "system-images;android-34;google_apis;x86_64" \
                    --device "pixel_7" \
                    --force || true

                # Tối ưu cấu hình máy ảo (bật hardware keyboard, GPU host/auto, tăng RAM & core)
                local AVD_CONFIG="$HOME/.android/avd/${DEFAULT_AVD_NAME}.avd/config.ini"
                if [[ -f "$AVD_CONFIG" ]]; then
                    sed -i 's/^hw.gpu.enabled=no/hw.gpu.enabled=yes/' "$AVD_CONFIG"
                    sed -i 's/^hw.keyboard=no/hw.keyboard=yes/' "$AVD_CONFIG"
                    sed -i 's/^hw.ramSize=1536M/hw.ramSize=2048M/' "$AVD_CONFIG"
                    sed -i 's/^hw.cpu.ncore=2/hw.cpu.ncore=4/' "$AVD_CONFIG"
                fi
                substep "Đã tạo và tối ưu máy ảo: $DEFAULT_AVD_NAME"
            else
                substep "Máy ảo $DEFAULT_AVD_NAME đã tồn tại."
            fi
        fi

        # Tạo wrapper cho emulator để fix lỗi Qt Wayland (code -6 crash trên Wayland/Hyprland)
        local EMU_BIN="$ANDROID_SDK_DIR/emulator/emulator"
        local EMU_ORIG="$ANDROID_SDK_DIR/emulator/emulator-original"
        if [[ -f "$EMU_BIN" && ! -f "$EMU_ORIG" ]]; then
            mv "$EMU_BIN" "$EMU_ORIG"
            cat << 'EOF' > "$EMU_BIN"
#!/usr/bin/env bash
# Force XCB for Android Emulator on Wayland
export QT_QPA_PLATFORM=xcb
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec -a "$0" "$DIR/emulator-original" "$@"
EOF
            chmod +x "$EMU_BIN"
            substep "Đã tạo wrapper tương thích Wayland cho Android Emulator"
        fi
    fi

    # 4. THIẾT LẬP BIẾN MÔI TRƯỜNG HỆ THỐNG VÀ USER SHELL
    info "4/6. Thiết lập biến môi trường cho Android SDK, Java, trình duyệt và Flutter..."
    # Profile toàn hệ thống
    sudo tee /etc/profile.d/flutter.sh > /dev/null << 'EOF'
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
export CHROME_EXECUTABLE="/usr/bin/microsoft-edge-stable"
export PATH="/opt/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
EOF
    substep "Đã ghi file biến môi trường toàn hệ thống /etc/profile.d/flutter.sh"

    # User shell rc (.zshrc và .bashrc)
    local ENV_BLOCK='
# Flutter & Android SDK Environment Variables
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
export CHROME_EXECUTABLE="/usr/bin/microsoft-edge-stable"
export PATH="/opt/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"'

    for rc_file in "$HOME/.zshrc" "$HOME/.bashrc"; do
        if [[ -f "$rc_file" ]]; then
            if ! grep -q "ANDROID_HOME" "$rc_file"; then
                echo "$ENV_BLOCK" >> "$rc_file"
                substep "Đã bổ sung biến môi trường vào $rc_file"
            else
                if ! grep -q "CHROME_EXECUTABLE" "$rc_file"; then
                    echo 'export CHROME_EXECUTABLE="/usr/bin/microsoft-edge-stable"' >> "$rc_file"
                fi
                substep "Biến môi trường đã có sẵn trong $rc_file"
            fi
        fi
    done

    # Export ngay cho phiên chạy hiện tại
    export ANDROID_HOME="$HOME/Android/Sdk"
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
    export CHROME_EXECUTABLE="/usr/bin/microsoft-edge-stable"
    export PATH="/opt/flutter/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"

    # 5. CẤU HÌNH FLUTTER & CHẤP NHẬN BẢN QUYỀN ANDROID
    info "5/6. Cấu hình Flutter kết nối Android SDK & chấp nhận licenses..."
    if command -v flutter &>/dev/null; then
        flutter config --android-sdk "$HOME/Android/Sdk" >/dev/null 2>&1 || true
        info "Tự động chấp nhận licenses của Flutter..."
        yes 2>/dev/null | flutter doctor --android-licenses >/dev/null 2>&1 || true
        substep "Đã đồng bộ đường dẫn Android SDK vào Flutter"
    fi

    # 6. CẤU HÌNH HYPRLAND: TỰ ĐỘNG ĐỒNG BỘ TOOLBAR MÁY ẢO BÁM SÁT CẠNH PHẢI
    info "6/6. Cấu hình Hyprland tự động đồng bộ Toolbar luôn bám sát cạnh phải máy ảo..."
    local DOT_HYPR="$HOME/.dotfiles/.config/hypr"
    local USER_HYPR="$HOME/.config/hypr"
    mkdir -p "$DOT_HYPR" "$USER_HYPR"

    # Quy tắc floating cho máy ảo và toolbar trong rules.lua
    local RULES_FILE="$DOT_HYPR/rules.lua"
    if [[ -f "$RULES_FILE" ]]; then
        if ! grep -q "float-android-emulator" "$RULES_FILE"; then
            cat << 'EOF' >> "$RULES_FILE"

-- Quy tắc floating cho Android Emulator & Toolbar
hl.window_rule({
    name = "float-android-emulator",
    match = { class = "^(Emulator|qemu-system-x86_64)$" },
    float = true,
})

hl.window_rule({
    name = "float-android-toolbar",
    match = { title = "^(Android Emulator.*)$" },
    float = true,
})
EOF
            substep "Đã thêm rules floating cho máy ảo và toolbar vào rules.lua"
        else
            substep "Rules floating cho máy ảo đã có trong rules.lua"
        fi
    fi

    # Tạo script emulator-sync.lua
    cat << 'EOF' > "$DOT_HYPR/emulator-sync.lua"
-- ~/.config/hypr/emulator-sync.lua
-- Tự động đồng bộ thanh công cụ (Toolbar) luôn bám sát cạnh phải máy ảo Android

local M = {}

-- Hàm kiểm tra xem cửa sổ có thuộc về máy ảo Android không
local function is_emulator_window(w)
    if not w then return false end
    local class = w.class or ""
    local title = w.title or ""

    -- Loại trừ chính IDE Android Studio
    if class == "jetbrains-studio" or class == "android-studio" or class:find("jetbrains") ~= nil then
        return false
    end

    -- Nhận diện tiến trình Emulator của Android SDK / QEMU
    if class == "Emulator" or class == "qemu-system-x86_64" then
        return true
    end

    if title:find("^Android Emulator") ~= nil or title:find("^Emulator") ~= nil then
        return true
    end

    return false
end

function M.sync()
    local ok, err = pcall(function()
        local wins = hl.get_windows()
        if not wins or #wins == 0 then return end

        local emulators = {}
        local toolbars = {}

        for _, w in ipairs(wins) do
            if is_emulator_window(w) then
                -- Phân biệt màn hình máy ảo (rộng >= 150px) và Toolbar (hẹp < 120px)
                local w_width = (w.size and w.size.x) or 0
                if w_width > 0 and w_width < 120 then
                    table.insert(toolbars, w)
                elseif w_width >= 150 then
                    table.insert(emulators, w)
                end
            end
        end

        -- Nếu không có máy ảo hoặc không có toolbar nào, kết thúc nhanh
        if #emulators == 0 or #toolbars == 0 then
            return
        end

        -- Ghép cặp toolbar với emulator (ưu tiên cùng PID)
        for _, emu in ipairs(emulators) do
            local matched_tb = nil
            for _, tb in ipairs(toolbars) do
                if tb.pid == emu.pid then
                    matched_tb = tb
                    break
                end
            end

            -- Dự phòng: nếu chỉ có 1 emu và 1 tb
            if not matched_tb and #emulators == 1 and #toolbars == 1 then
                matched_tb = toolbars[1]
            end

            if matched_tb then
                -- Đảm bảo cả hai cửa sổ đều floating
                if not matched_tb.floating then
                    hl.dispatch(hl.dsp.exec_raw("setfloating address:" .. matched_tb.address))
                end

                -- Đồng bộ Workspace nếu lệch nhau
                if matched_tb.workspace and emu.workspace and matched_tb.workspace.id ~= emu.workspace.id then
                    local ws_name = tostring(emu.workspace.name or emu.workspace.id)
                    hl.dispatch(hl.dsp.exec_raw("movetoworkspacesilent " .. ws_name .. ",address:" .. matched_tb.address))
                end

                -- Tính tọa độ bám sát cạnh phải của máy ảo
                local target_x = (emu.at.x or 0) + (emu.size.x or 0)
                local target_y = (emu.at.y or 0)

                local curr_x = matched_tb.at.x or 0
                local curr_y = matched_tb.at.y or 0

                -- Di chuyển nếu lệch quá 2px
                if math.abs(curr_x - target_x) > 2 or math.abs(curr_y - target_y) > 2 then
                    hl.dispatch(hl.dsp.exec_raw("movewindowpixel exact " .. target_x .. " " .. target_y .. ",address:" .. matched_tb.address))
                end
            end
        end
    end)
end

-- Đăng ký timer chạy mỗi 50ms trong Hyprland
hl.timer(M.sync, { timeout = 50, type = "repeat" })

return M
EOF
    substep "Đã tạo $DOT_HYPR/emulator-sync.lua"

    # Symlink vào ~/.config/hypr/ nếu cần
    ln -sf "$DOT_HYPR/emulator-sync.lua" "$USER_HYPR/emulator-sync.lua"

    # Nạp emulator-sync vào hyprland.lua
    local HYPR_LUA="$DOT_HYPR/hyprland.lua"
    if [[ -f "$HYPR_LUA" ]]; then
        if ! grep -q 'require("emulator-sync")' "$HYPR_LUA"; then
            sed -i '/require("rules")/a require("emulator-sync")' "$HYPR_LUA"
            substep "Đã thêm require(\"emulator-sync\") vào hyprland.lua"
        else
            substep "require(\"emulator-sync\") đã có sẵn trong hyprland.lua"
        fi
    fi

    # Reload cấu hình Hyprland
    if command -v hyprctl &>/dev/null; then
        hyprctl reload config-only >/dev/null 2>&1 || true
        substep "Đã reload cấu hình Hyprland thành công"
    fi

    # TỔNG KẾT VÀ BÁO CÁO TRẠNG THÁI FLUTTER DOCTOR
    header "TỔNG KẾT MÔI TRƯỜNG FLUTTER & ANDROID"
    if command -v flutter &>/dev/null; then
        flutter doctor || true
    fi

    success "Module 15-flutter hoàn tất thành công!"
}
