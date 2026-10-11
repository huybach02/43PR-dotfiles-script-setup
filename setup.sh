#!/usr/bin/env bash
# ==============================================================================
# Linux Post-Install & System Setup Framework
# Tác giả: Tạo tự động bởi Antigravity cho hệ thống Arch / CachyOS
#
# Cách dùng:
#   ./setup.sh              : Chạy tất cả các module theo thứ tự mặc định
#   ./setup.sh all          : Chạy tất cả các module
#   ./setup.sh <module>     : Chạy một hoặc nhiều module cụ thể (vd: ./setup.sh apps)
#   ./setup.sh --list       : Liệt kê danh sách các module có sẵn
#   ./setup.sh --help       : Xem hướng dẫn sử dụng chi tiết
# ==============================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
MODULES_DIR="$SCRIPT_DIR/modules"

# Nạp thư viện dùng chung
# shellcheck source=lib/common.sh
if [[ -f "$LIB_DIR/common.sh" ]]; then
    source "$LIB_DIR/common.sh"
else
    echo "Lỗi: Không tìm thấy $LIB_DIR/common.sh" >&2
    exit 1
fi

# Hiển thị banner
show_banner() {
    printf "${BOLD}${CYAN}"
    cat << "EOF"
   ___      _               ___      _               
  / __| ___| |_ _  _ _ __  / __|__ _| |_ ___ _ _ _  _
  \__ \/ -_)  _| || | '_ \ \__ \/ _` |  _/ -_) '_| || |
  |___/\___|\__|\_,_| .__/ |___/\__,_|\__\___|_|  \_, |
                    |_|                            |__/ 
EOF
    printf "${NC}\n"
    printf "  ${BOLD}Hệ thống thiết lập máy tự động (Arch Linux / CachyOS)${NC}\n"
    printf "  Thư mục: ${BLUE}%s${NC}\n\n" "$SCRIPT_DIR"
}

# Hiển thị hướng dẫn
show_help() {
    show_banner
    printf "${BOLD}CÁCH SỬ DỤNG:${NC}\n"
    printf "  %s [tùy chọn | tên_module...]\n\n" "$0"
    printf "${BOLD}CÁC TÙY CHỌN:${NC}\n"
    printf "  ${GREEN}-l, --list${NC}                Liệt kê tất cả các module hiện có\n"
    printf "  ${GREEN}-h, --help${NC}                Hiển thị hướng dẫn sử dụng này\n"
    printf "  ${GREEN}-m, --module <tên>${NC}        Chỉ định module cần chạy\n"
    printf "  ${GREEN}all${NC}                       Chạy toàn bộ các module (mặc định nếu không truyền tham số)\n\n"
    printf "${BOLD}VÍ DỤ:${NC}\n"
    printf "  ${CYAN}./setup.sh${NC}                # Chạy tất cả các module\n"
    printf "  ${CYAN}./setup.sh apps${NC}           # Chỉ chạy module cài đặt phần mềm (Edge, VSCode, Sublime, v.v.)\n"
    printf "  ${CYAN}./setup.sh defaults${NC}       # Chỉ chạy module thiết lập ứng dụng mặc định\n"
    printf "  ${CYAN}./setup.sh apps defaults${NC}  # Chạy module apps rồi đến module defaults\n"
    printf "  ${CYAN}./setup.sh --list${NC}         # Xem danh sách các module có sẵn\n\n"
}

# Lấy danh sách file module theo thứ tự bảng chữ cái/số
get_module_files() {
    find "$MODULES_DIR" -maxdepth 1 -type f -name "*.sh" | sort
}

# Tìm file module từ tên (hỗ trợ cả tên ngắn 'apps', tên đầy đủ '03-apps' hoặc MODULE_NAME bên trong)
resolve_module_file() {
    local target="$1"
    local found=""

    for file in $(get_module_files); do
        local basename
        basename="$(basename "$file" .sh)"
        # Xóa tiền tố số nếu có: "03-apps" -> "apps"
        local clean_name="${basename#[0-9]*-}"

        local mod_var=""
        mod_var="$(grep -E '^MODULE_NAME=' "$file" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '"'\''')"

        if [[ "$target" == "$basename" || "$target" == "$clean_name" || "$target" == "$mod_var" || "$clean_name" == *"$target"* ]]; then
            found="$file"
            break
        fi
    done

    echo "$found"
}

# Liệt kê tất cả module
list_modules() {
    show_banner
    printf "${BOLD}DANH SÁCH CÁC MODULE HIỆN CÓ:${NC}\n\n"
    printf "  %-15s %-20s %s\n" "MÃ SỐ / TÊN" "TÊN GỌI GỌN" "MÔ TẢ CHI TIẾT"
    printf "  %-15s %-20s %s\n" "---------------" "--------------------" "----------------------------------------------------"

    for file in $(get_module_files); do
        local basename
        basename="$(basename "$file" .sh)"
        local clean_name="${basename#[0-9]*-}"

        # Đọc mô tả từ biến MODULE_DESC trong file nếu có
        local desc
        desc="$(grep '^MODULE_DESC=' "$file" | head -n1 | cut -d'=' -f2- | tr -d '"' || echo "Không có mô tả")"

        local opt_in=""
        opt_in="$(awk -F'=' '/^MODULE_OPT_IN=/ {gsub(/["\047 ]/, "", $2); print $2}' "$file" 2>/dev/null || true)"
        if [[ "$opt_in" == "true" ]]; then
            desc="${YELLOW}[CHỈ CHẠY RIÊNG]${NC} $desc"
        fi

        printf "  ${CYAN}%-15s${NC} ${GREEN}%-20s${NC} %b\n" "$basename" "$clean_name" "$desc"
    done
    printf "\n"
}

# Chạy một module cụ thể
execute_single_module() {
    local mod_file="$1"
    local mod_name
    mod_name="$(basename "$mod_file" .sh)"

    info "Bắt đầu chạy module: ${BOLD}${mod_name}${NC}..."
    local start_time
    start_time="$(date +%s)"

    # Subshell để cô lập các biến cục bộ của module
    (
        # shellcheck disable=SC1090
        source "$mod_file"
        if declare -F run_module >/dev/null; then
            run_module
        else
            error "Module $mod_name không có hàm run_module()!"
            exit 1
        fi
    )

    local end_time
    end_time="$(date +%s)"
    local duration=$((end_time - start_time))
    success "Hoàn tất module ${BOLD}${mod_name}${NC} trong ${duration}s.\n"
}

# ------------------------------------------------------------------------------
# MAIN LOGIC
# ------------------------------------------------------------------------------
main() {
    check_non_root

    local modules_to_run=()

    # Phân tích tham số dòng lệnh
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                list_modules
                exit 0
                ;;
            -m|--module)
                shift
                if [[ -z "${1:-}" ]]; then
                    error "Thiếu tên module sau -m/--module!"
                    exit 1
                fi
                modules_to_run+=("$1")
                shift
                ;;
            all)
                # Chạy tất cả
                modules_to_run=()
                shift
                ;;
            *)
                # Cho phép truyền tên module trực tiếp dưới dạng đối số vị trí
                modules_to_run+=("$1")
                shift
                ;;
        esac
    done

    show_banner

    # Khởi tạo quyền sudo một lần duy nhất
    init_sudo

    # Nếu không truyền module nào hoặc truyền 'all', lấy tất cả các module
    if [[ ${#modules_to_run[@]} -eq 0 ]]; then
        info "Chế độ: ${BOLD}CHẠY TẤT CẢ CÁC MODULE${NC} theo thứ tự mặc định."
        for file in $(get_module_files); do
            local opt_in=""
            opt_in="$(awk -F'=' '/^MODULE_OPT_IN=/ {gsub(/["\047 ]/, "", $2); print $2}' "$file" 2>/dev/null || true)"
            if [[ "$opt_in" == "true" ]]; then
                local skip_name
                skip_name="$(basename "$file" .sh)"
                warn "Bỏ qua module '${skip_name}' (được cấu hình chỉ chạy khi gọi riêng)."
                continue
            fi
            execute_single_module "$file"
        done
    else
        info "Chế độ: ${BOLD}CHẠY MODULE ĐƯỢC CHỈ ĐỊNH${NC} (${#modules_to_run[@]} module)."
        for target in "${modules_to_run[@]}"; do
            local mod_file
            mod_file="$(resolve_module_file "$target")"

            if [[ -z "$mod_file" ]]; then
                error "Không tìm thấy module nào có tên: '$target'!"
                info "Dùng './setup.sh --list' để xem danh sách các module có sẵn."
                exit 1
            fi

            execute_single_module "$mod_file"
        done
    fi

    header "TẤT CẢ CÁC BƯỚC ĐÃ HOÀN TẤT THÀNH CÔNG!"
    info "Hệ thống của bạn đã được thiết lập đầy đủ."
    cleanup_sudo
}

main "$@"
