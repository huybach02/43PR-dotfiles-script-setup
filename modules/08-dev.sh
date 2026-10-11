#!/usr/bin/env bash
# ==============================================================================
# Module: 08-dev
# Description: Cài đặt môi trường phát triển: PHP 8.5 (+ extensions), Composer,
#              Node.js 24 LTS, npm, Symfony CLI
# ==============================================================================

MODULE_NAME="dev"
MODULE_DESC="Cài đặt PHP 8.5 (+ extensions), Composer, Node.js 24 LTS, npm, Symfony CLI"

run_module() {
    header "MODULE: $MODULE_DESC"

    # 1. CÀI ĐẶT PHP 8.5, EXTENSIONS, COMPOSER, NODE.JS 24 LTS & NPM
    info "1/4. Cài đặt PHP 8.5, các extension thông dụng, Composer, Node.js 24 LTS và npm..."
    local PKGS=(
        php
        php-fpm
        php-gd
        php-sqlite
        php-pgsql
        php-sodium
        php-apcu
        php-redis
        php-imagick
        php-tidy
        php-xsl
        composer
        nodejs-lts-krypton
        npm
    )

    pkg_install "${PKGS[@]}"

    # 2. BẬT CÁC EXTENSION PHP TRONG /etc/php/php.ini VÀ conf.d
    info "2/4. Cấu hình và kích hoạt các extension PHP cần thiết cho Web / Symfony / Laravel..."
    local PHP_INI="/etc/php/php.ini"
    local EXTENSIONS=(
        bcmath
        bz2
        calendar
        curl
        exif
        ftp
        gd
        gettext
        iconv
        intl
        mysqli
        pdo_mysql
        pdo_sqlite
        sqlite3
        pdo_pgsql
        pgsql
        sockets
        sodium
        tidy
        xsl
        zip
    )

    if [[ -f "$PHP_INI" ]]; then
        for ext in "${EXTENSIONS[@]}"; do
            sudo sed -i "s/^;extension=$ext\$/extension=$ext/" "$PHP_INI"
        done

        # Tăng memory_limit lên 512M cho Composer & Symfony
        sudo sed -i 's/^memory_limit = .*/memory_limit = 512M/' "$PHP_INI"
        substep "Đã kích hoạt các extension cốt lõi & đặt memory_limit = 512M trong $PHP_INI"
    fi

    # Kích hoạt các extension trong /etc/php/conf.d
    if [[ -d "/etc/php/conf.d" ]]; then
        [[ -f /etc/php/conf.d/apcu.ini ]] && sudo sed -i "s/^;extension=apcu.so/extension=apcu.so/" /etc/php/conf.d/apcu.ini
        [[ -f /etc/php/conf.d/igbinary.ini ]] && sudo sed -i "s/^;extension=igbinary.so/extension=igbinary.so/" /etc/php/conf.d/igbinary.ini
        [[ -f /etc/php/conf.d/imagick.ini ]] && sudo sed -i "s/^;[[:space:]]*extension[[:space:]]*=[[:space:]]*imagick/extension = imagick/" /etc/php/conf.d/imagick.ini
        [[ -f /etc/php/conf.d/redis.ini ]] && sudo sed -i "s/^;extension=redis/extension=redis/" /etc/php/conf.d/redis.ini
        substep "Đã kích hoạt apcu, igbinary, imagick, redis trong /etc/php/conf.d"
    fi

    # 3. CÀI ĐẶT SYMFONY CLI
    info "3/4. Cài đặt Symfony CLI..."
    if ! command -v symfony &>/dev/null; then
        ensure_aur_helper
        if aur_install symfony-cli-bin; then
            substep "Đã cài đặt symfony-cli-bin từ AUR thành công"
        else
            info "Cài đặt symfony-cli-bin từ AUR không thành công, thử dùng script cài đặt chính thức..."
            curl -sS https://get.symfony.com/cli/installer | bash
            if [[ -f "$HOME/.symfony5/bin/symfony" ]]; then
                sudo mv "$HOME/.symfony5/bin/symfony" /usr/local/bin/symfony
                substep "Đã cài đặt Symfony CLI vào /usr/local/bin/symfony"
            fi
        fi
    else
        substep "Symfony CLI đã được cài đặt sẵn: $(symfony -V 2>/dev/null | head -n1)"
    fi

    # 4. KIỂM TRA PHIÊN BẢN VÀ YÊU CẦU CỦA HỆ THỐNG
    info "4/4. Kiểm tra các phiên bản đã cài đặt..."
    printf "  • PHP:     ${GREEN}%s${NC}\n" "$(php -r 'echo PHP_VERSION;' 2>/dev/null || echo 'Chưa cài')"
    printf "  • Composer:${GREEN}%s${NC}\n" "$(composer --version 2>/dev/null | head -n1 | cut -d' ' -f3 || echo 'Chưa cài')"
    printf "  • Node.js: ${GREEN}%s${NC}\n" "$(node -v 2>/dev/null || echo 'Chưa cài')"
    printf "  • npm:     ${GREEN}%s${NC}\n" "$(npm -v 2>/dev/null || echo 'Chưa cài')"
    printf "  • Symfony: ${GREEN}%s${NC}\n" "$(symfony -V 2>/dev/null | head -n1 || echo 'Chưa cài')"

    if command -v symfony &>/dev/null; then
        info "Kiểm tra Symfony requirements..."
        symfony check:requirements 2>/dev/null || true
    fi

    success "Module 08-dev hoàn tất! Môi trường PHP 8.5, Composer, Node.js 24 LTS, npm và Symfony CLI đã sẵn sàng."
}
