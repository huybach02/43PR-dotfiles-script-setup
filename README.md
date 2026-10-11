# Hệ Thống Script Tự Động Thiết Lập Máy (Arch Linux / CachyOS)

Bộ script thiết lập máy tự động dạng mô-đun hóa (modular), được xây dựng để giúp bạn tự động hóa toàn bộ quá trình cài đặt lại hệ điều hành một cách nhanh chóng, sạch sẽ và không cần thao tác thủ công.

---

## 📁 Cấu Trúc Thư Mục

```text
~/setup/
├── setup.sh                 # File thực thi chính (CLI runner)
├── README.md                # Tài liệu hướng dẫn sử dụng
├── lib/
│   └── common.sh            # Thư viện dùng chung (màu sắc, cơ chế sudo 1 lần duy nhất, pacman, paru/yay)
└── modules/
    ├── 01-system.sh         # Module 1: Cập nhật hệ thống, base-devel, cấu hình paru
    ├── 02-dotfiles.sh       # Module 2: Cài đặt Hyprland + bộ dotfiles 43PR
    ├── 03-apps.sh           # Module 3: Cài đặt Edge, VS Code, LibreOffice, Sublime Text, AppImageLauncher
    ├── 04-defaults.sh       # Module 4: Đặt Edge làm trình duyệt mặc định, Sublime Text làm editor mặc định
    ├── 05-monitors.sh       # Module 5: Thiết lập màn hình kép (Philips chính 0x0@75Hz bên trái, AOC phụ 1920x0@75Hz bên phải)
    ├── 06-workspaces-autostart.sh # Module 6: Cố định ứng dụng vào Workspace (Edge->1, Firefox->2, VSCode->3) & Autostart
    ├── 07-skey.sh                 # Module 7: Cài đặt bộ gõ tiếng Việt skey (fcitx5-skey), phím tắt Alt + Left Shift
    ├── 08-dev.sh                  # Module 8: Môi trường phát triển: PHP 8.5 (+ extensions), Composer, Node.js 24 LTS, npm, Symfony CLI
    ├── 09-screenshot.sh           # Module 9: Chụp ảnh màn hình (Super + Shift + S), popup QuickShell OSD, trình sửa ảnh Satty
    ├── 10-terminal-image-paste.sh # Module 10: Tự động đính kèm ảnh từ clipboard vào terminal AI agent (agy, claude) khi bấm Ctrl + Shift + V
    ├── 11-mount-data.sh           # Module 11: Tự động mount phân vùng Data (NTFS) vào /mnt/Data, cấu hình hiển thị Thunar/VSCode, bookmark GTK, tạo symlink ~/Data, /DATA và /run/media/...
    ├── 12-clipboard-preview.sh    # Module 12: Lịch sử clipboard Super + V QuickShell chia 6/4 (thumbnail mini, preview ảnh to bên phải, cuộn chuẩn)
    ├── 13-quickshell-tweaks.sh    # Module 13: Tắt trong suốt, tắt rung lắc góc, click CPU/RAM mở btop, Volume OSD & ngày giờ Bar
    ├── 14-warp.sh                 # Module 14: Cài đặt Cloudflare WARP (warp-cli) và nút bật/tắt nhanh trên thanh Bar
    ├── 15-flutter.sh              # Module 15: [Opt-in] Cài đặt môi trường Flutter, Android SDK (dùng VS Code) & tự động bám Toolbar máy ảo
    └── 16-clean.sh                # Module 16: [Opt-in] Dọn dẹp cache Paru/Pacman, gỡ gói mồ côi & tối ưu dung lượng ổ đĩa
```

---

## 🚀 Cách Sử Dụng

### 1. Cấp quyền thực thi (nếu cần)
```bash
chmod +x ~/setup/setup.sh ~/setup/modules/*.sh
```

### 2. Chạy toàn bộ các module (Mặc định khi cài mới máy)
Chỉ cần chạy lệnh sau mà không truyền tham số (hoặc truyền `all`):
```bash
cd ~/setup
./setup.sh
# Hoặc: ./setup.sh all
```
> *Lưu ý:*
> - *Script chỉ yêu cầu nhập mật khẩu `sudo` 1 lần duy nhất lúc bắt đầu chạy thông qua cơ chế sudoers tạm thời (`/etc/sudoers.d/99-setup-installer-temp`) và keep-alive nền, tự động dọn dẹp sạch khi kết thúc.*
> - *Các module có cờ `MODULE_OPT_IN=true` (như `15-flutter`, `16-clean`) sẽ tự động được bỏ qua khi chạy chế độ này để tiết kiệm thời gian và tài nguyên.*

---

### 3. Chạy từng module riêng biệt khi cần

Bạn có thể truyền tên module (rút gọn hoặc đầy đủ) vào dòng lệnh:

- **Cài đặt môi trường Flutter & Android SDK (Chạy riêng):**
  ```bash
  ./setup.sh flutter
  # hoặc: ./setup.sh 15-flutter
  ```

- **Dọn dẹp hệ thống, cache Paru/Pacman & gói rác (Chạy riêng):**
  ```bash
  ./setup.sh clean
  # hoặc chạy trực tiếp: ~/setup/clean.sh
  ```

- **Chỉ cài đặt các ứng dụng phần mềm (Edge, VSCode, Sublime, v.v.):**
  ```bash
  ./setup.sh apps
  # hoặc: ./setup.sh 03-apps
  ```

- **Chỉ thiết lập ứng dụng mặc định (Edge, Sublime Text):**
  ```bash
  ./setup.sh defaults
  ```

- **Chạy kết hợp nhiều module theo thứ tự:**
  ```bash
  ./setup.sh apps defaults flutter
  ```

- **Xem danh sách các module hiện có:**
  ```bash
  ./setup.sh --list
  ```

- **Xem hướng dẫn chi tiết:**
  ```bash
  ./setup.sh --help
  ```

---

## ➕ Cách Thêm Module Mới

Khi muốn thêm tính năng hoặc cấu hình mới trong tương lai (ví dụ: `05-gaming.sh`, `06-dev-tools.sh`), bạn chỉ cần tạo một file script trong thư mục `modules/` với cấu trúc sau:

```bash
#!/usr/bin/env bash
MODULE_NAME="gaming"
MODULE_DESC="Cài đặt Steam, Lutris và tối ưu hiệu năng game"
# (Tùy chọn) Đặt MODULE_OPT_IN=true nếu muốn module này mặc định bị bỏ qua khi chạy './setup.sh all'
# MODULE_OPT_IN=true

run_module() {
    header "MODULE: $MODULE_DESC"
    
    # Dùng hàm pkg_install cho repo chính thức
    pkg_install steam gamemode
    
    # Dùng hàm aur_install cho AUR
    aur_install mangohud
    
    success "Hoàn tất module Gaming!"
}
```

Script `setup.sh` sẽ tự động nhận diện và liệt kê module mới trong `./setup.sh --list` mà không cần sửa bất kỳ dòng code nào ở file chính. Nếu bạn khai báo `MODULE_OPT_IN=true`, runner sẽ tự động gắn nhãn `[CHỈ CHẠY RIÊNG]` và chỉ thực thi khi bạn truyền đúng tên module vào dòng lệnh.

